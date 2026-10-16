const std = @import("std");
const api = @import("api.zig");
const archive_records = @import("archive_records.zig");
const records = @import("../records.zig");

pub const Record = struct {
    name: []u8,
    comment: []u8 = &.{},
    method: api.CompressionMethod,
    flags: u16,
    crc32: u32 = 0,
    compressed_size: usize = 0,
    uncompressed_size: usize = 0,
    local_header_offset: usize,
    zip64_local: bool,
    uses_descriptor: bool,
    modified: api.DosTimestamp,
    extended_timestamp: ?api.ExtendedTimestamp = null,
    ntfs_timestamp: ?api.NtfsTimestamp = null,
    version_made_by: u16 = 0,
    internal_attributes: u16 = 0,
    external_attributes: u32 = 0,
    winzip_aes: ?api.WinZipAesInfo = null,
    pkware_strong_encryption: ?api.PkwareStrongEncryptionInfo = null,
    complete: bool = false,
    central_seen: bool = false,

    pub fn info(self: *const Record) api.EntryInfo {
        return .{
            .name = self.name,
            .comment = if (self.central_seen) self.comment else null,
            .method = self.method,
            .flags = self.flags,
            .local_header_offset = self.local_header_offset,
            .uses_descriptor = self.uses_descriptor,
            .zip64_local = self.zip64_local,
            .modified = self.modified,
            .extended_timestamp = self.extended_timestamp,
            .ntfs_timestamp = self.ntfs_timestamp,
            .version_made_by = if (self.central_seen) self.version_made_by else null,
            .internal_attributes = if (self.central_seen) self.internal_attributes else null,
            .external_attributes = if (self.central_seen) self.external_attributes else null,
            .winzip_aes = self.winzip_aes,
            .pkware_strong_encryption = self.pkware_strong_encryption,
            .crc32 = if (self.complete or !self.uses_descriptor) self.crc32 else null,
            .compressed_size = if (self.complete or !self.uses_descriptor) self.compressed_size else null,
            .uncompressed_size = if (self.complete or !self.uses_descriptor) self.uncompressed_size else null,
        };
    }
};

/// Retained local-entry index plus central-directory/end-record invariants.
/// Payload decoding stays in the parent reader; this state owns entry names.
pub const State = struct {
    records: std.ArrayList(Record) = .empty,
    retained_metadata_size: usize = 0,
    completed_entries: usize = 0,
    central_started: bool = false,
    central_ended: bool = false,
    central_offset: usize = 0,
    central_size: usize = 0,
    central_entries: usize = 0,

    const Self = @This();

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.reset(allocator);
        self.records.deinit(allocator);
        self.* = undefined;
    }

    pub fn reset(self: *Self, allocator: std.mem.Allocator) void {
        for (self.records.items) |entry| {
            allocator.free(entry.name);
            if (entry.comment.len != 0) allocator.free(entry.comment);
        }
        self.records.clearRetainingCapacity();
        self.retained_metadata_size = 0;
        self.completed_entries = 0;
        self.central_started = false;
        self.central_ended = false;
        self.central_offset = 0;
        self.central_size = 0;
        self.central_entries = 0;
    }

    pub fn complete(self: *Self, index: usize) error{ InvalidZipArchive, IntegerOverflow }!void {
        if (index >= self.records.items.len or self.records.items[index].complete)
            return error.InvalidZipArchive;
        self.records.items[index].complete = true;
        self.completed_entries = std.math.add(usize, self.completed_entries, 1) catch
            return error.IntegerOverflow;
    }

    pub fn validateCentral(
        self: *Self,
        allocator: std.mem.Allocator,
        central: archive_records.CentralHeader,
        absolute_end: usize,
        max_central_size: usize,
        max_metadata_size: usize,
    ) (std.mem.Allocator.Error || error{ InvalidZipArchive, OutputLimitExceeded, IntegerOverflow })!void {
        var matched: ?*Record = null;
        for (self.records.items) |*local| {
            if (!local.central_seen and local.local_header_offset == central.local_header_offset) {
                matched = local;
                break;
            }
        }
        const local = matched orelse return error.InvalidZipArchive;
        const extended_timestamp = try records.mergeExtendedTimestamps(
            local.extended_timestamp,
            central.extended_timestamp,
        );
        const ntfs_timestamp = try records.mergeNtfsTimestamps(
            local.ntfs_timestamp,
            central.ntfs_timestamp,
        );
        if (!local.complete or
            !std.mem.eql(u8, local.name, central.name) or
            local.method != central.method or
            local.flags != central.flags or
            local.crc32 != central.crc32 or
            local.compressed_size != central.compressed_size or
            local.uncompressed_size != central.uncompressed_size or
            !std.meta.eql(local.modified, central.modified) or
            !std.meta.eql(local.winzip_aes, central.winzip_aes) or
            !std.meta.eql(local.pkware_strong_encryption, central.pkware_strong_encryption))
            return error.InvalidZipArchive;
        const central_entries = std.math.add(usize, self.central_entries, 1) catch
            return error.IntegerOverflow;
        const central_size = absolute_end - self.central_offset;
        if (central_size > max_central_size) return error.OutputLimitExceeded;
        const retained_metadata_size = std.math.add(
            usize,
            self.retained_metadata_size,
            central.comment.len,
        ) catch return error.IntegerOverflow;
        if (retained_metadata_size > max_metadata_size)
            return error.OutputLimitExceeded;
        var comment: []u8 = &.{};
        if (central.comment.len != 0)
            comment = try allocator.dupe(u8, central.comment);
        local.comment = comment;
        local.extended_timestamp = extended_timestamp;
        local.ntfs_timestamp = ntfs_timestamp;
        local.version_made_by = central.version_made_by;
        local.internal_attributes = central.internal_attributes;
        local.external_attributes = central.external_attributes;
        local.central_seen = true;
        self.central_entries = central_entries;
        self.central_size = central_size;
        self.retained_metadata_size = retained_metadata_size;
    }

    pub fn beginEnding(
        self: *Self,
        record_offset: usize,
        max_central_size: usize,
    ) error{ InvalidZipArchive, OutputLimitExceeded }!void {
        if (!self.central_ended) {
            if (!self.central_started) {
                self.central_started = true;
                self.central_offset = record_offset;
                self.central_size = 0;
            } else {
                self.central_size = record_offset - self.central_offset;
            }
            self.central_ended = true;
        }
        if (self.central_size > max_central_size) return error.OutputLimitExceeded;
        if (self.central_entries != self.records.items.len)
            return error.InvalidZipArchive;
        for (self.records.items) |entry|
            if (!entry.central_seen) return error.InvalidZipArchive;
    }

    pub fn validateZip64End(
        self: *const Self,
        parsed: archive_records.Zip64End,
    ) error{ InvalidZipArchive, UnsupportedZipFeature }!void {
        if (parsed.disk != 0 or parsed.central_disk != 0 or
            parsed.entries_on_disk != parsed.entry_count)
            return error.UnsupportedZipFeature;
        if (parsed.entry_count != self.records.items.len or
            parsed.central_size != self.central_size or
            parsed.central_offset != self.central_offset)
            return error.InvalidZipArchive;
    }

    pub fn validateEnd(
        self: *const Self,
        parsed: archive_records.End,
        zip64_end: ?archive_records.Zip64End,
        zip64_locator_seen: bool,
    ) error{ InvalidZipArchive, UnsupportedZipFeature }!void {
        if (parsed.disk != 0 or parsed.central_disk != 0)
            return error.UnsupportedZipFeature;
        if (zip64_end) |zip64| {
            if (!zip64_locator_seen) return error.InvalidZipArchive;
            try validateLegacyU16(parsed.entries_on_disk, zip64.entries_on_disk);
            try validateLegacyU16(parsed.entry_count, zip64.entry_count);
            try validateLegacyU32(parsed.central_size, zip64.central_size);
            try validateLegacyU32(parsed.central_offset, zip64.central_offset);
        } else {
            if (parsed.entries_on_disk != parsed.entry_count or
                parsed.entry_count != self.records.items.len or
                parsed.central_size != self.central_size or
                parsed.central_offset != self.central_offset)
                return error.InvalidZipArchive;
        }
    }
};

fn validateLegacyU16(value: u16, actual: u64) error{InvalidZipArchive}!void {
    if (value != std.math.maxInt(u16) and value != actual)
        return error.InvalidZipArchive;
}

fn validateLegacyU32(value: u32, actual: u64) error{InvalidZipArchive}!void {
    if (value != std.math.maxInt(u32) and value != actual)
        return error.InvalidZipArchive;
}
