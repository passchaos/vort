const std = @import("std");
const archive_format = @import("archive.zig");
const decoder = @import("decoder.zig");
const deflate = @import("../deflate.zig");
const lzx = @import("lzx.zig");
const quantum = @import("quantum.zig");
const types = @import("types.zig");

pub const Error = archive_format.Error || deflate.Error || lzx.Error || quantum.Error;
pub const Archive = archive_format.Archive;
pub const Entry = types.Entry;
pub const ExtractOptions = decoder.ExtractOptions;

pub const SetEntry = struct {
    archive_index: usize,
    entry: Entry,
};

/// A complete, caller-ordered cabinet set. Archives and all borrowed entry
/// strings remain owned by the caller.
pub const CabinetSet = struct {
    archives: []const Archive,

    pub fn init(archives: []const Archive) Error!CabinetSet {
        if (archives.len == 0) return error.IncompleteCabinetSet;
        const set_id = archives[0].set_id;
        for (archives, 0..) |archive, index| {
            if (archive.set_id != set_id or archive.cabinet_index != index)
                return error.CabinetSetMismatch;
            if (archive.hasPrevious() != (index != 0) or
                archive.hasNext() != (index + 1 != archives.len))
                return error.IncompleteCabinetSet;
            if (index != 0) try validateBoundary(archives[index - 1], archive);
        }
        return .{ .archives = archives };
    }

    pub fn find(self: CabinetSet, name: []const u8) Error!?SetEntry {
        for (self.archives, 0..) |archive, archive_index| {
            var entries = archive.iterator();
            while (try entries.next()) |entry| {
                if (!entry.continuation.startsBefore() and std.mem.eql(u8, entry.name, name))
                    return .{ .archive_index = archive_index, .entry = entry };
            }
        }
        return null;
    }

    pub fn extractByNameAllocWithOptions(
        self: CabinetSet,
        allocator: std.mem.Allocator,
        name: []const u8,
        options: ExtractOptions,
    ) ![]u8 {
        const set_entry = (try self.find(name)) orelse return error.CabinetEntryNotFound;
        return self.extractAllocWithOptions(allocator, set_entry, options);
    }

    pub fn extractByNameAllocLimited(
        self: CabinetSet,
        allocator: std.mem.Allocator,
        name: []const u8,
        max_output_len: usize,
    ) ![]u8 {
        return self.extractByNameAllocWithOptions(allocator, name, .{
            .max_file_size = max_output_len,
            .max_folder_size = max_output_len,
        });
    }

    pub fn extractByNameAlloc(
        self: CabinetSet,
        allocator: std.mem.Allocator,
        name: []const u8,
    ) ![]u8 {
        return self.extractByNameAllocWithOptions(allocator, name, .{});
    }

    pub fn extractAllocWithOptions(
        self: CabinetSet,
        allocator: std.mem.Allocator,
        supplied: SetEntry,
        options: ExtractOptions,
    ) ![]u8 {
        if (supplied.archive_index >= self.archives.len) return error.InvalidCabinet;
        const archive = self.archives[supplied.archive_index];
        const entry = try archive.canonicalEntry(supplied.entry);
        if (entry.continuation.startsBefore()) return error.InvalidCabinet;
        if (entry.size > options.max_file_size) return error.OutputLimitExceeded;

        const folder = try decodeFolderAllocLimited(
            allocator,
            self,
            supplied.archive_index,
            entry.folder_index,
            options.max_folder_size,
        );
        defer allocator.free(folder);
        const end = std.math.add(usize, entry.folder_offset, entry.size) catch
            return error.IntegerOverflow;
        if (end > folder.len) return error.InvalidCabinet;
        return allocator.dupe(u8, folder[entry.folder_offset..end]);
    }
};

const LogicalBlockEnd = struct {
    compressed_end: usize,
    uncompressed_size: usize,
};

fn decodeFolderAllocLimited(
    allocator: std.mem.Allocator,
    set: CabinetSet,
    start_archive_index: usize,
    start_folder_index: usize,
    max_output_len: usize,
) ![]u8 {
    var compressed: std.ArrayList(u8) = .empty;
    defer compressed.deinit(allocator);
    var block_ends: std.ArrayList(LogicalBlockEnd) = .empty;
    defer block_ends.deinit(allocator);

    var archive_index = start_archive_index;
    var folder_index = start_folder_index;
    const first_folder = try set.archives[archive_index].folderAt(folder_index);
    const compression = first_folder.compression;
    const type_compress = first_folder.type_compress;
    switch (compression) {
        .none, .mszip, .quantum, .lzx => {},
        else => return error.UnsupportedCabinetCompression,
    }
    if ((compression == .none or compression == .mszip) and type_compress & 0xfff0 != 0)
        return error.UnsupportedCabinetFeature;

    var decoded_size: usize = 0;
    while (true) {
        const archive = set.archives[archive_index];
        const folder = try archive.folderAt(folder_index);
        if (folder.compression != compression or folder.type_compress != type_compress)
            return error.CabinetSetMismatch;

        var continues = false;
        var blocks = archive.dataBlockIterator(folder);
        while (try blocks.next()) |block| {
            try compressed.appendSlice(allocator, block.compressed);
            if (block.uncompressed_size == 0) {
                if (blocks.remaining != 0) return error.InvalidCabinet;
                continues = true;
                continue;
            }
            decoded_size = std.math.add(usize, decoded_size, block.uncompressed_size) catch
                return error.IntegerOverflow;
            if (decoded_size > max_output_len) return error.OutputLimitExceeded;
            if (compression == .quantum) try compressed.append(allocator, 0xff);
            try block_ends.append(allocator, .{
                .compressed_end = compressed.items.len,
                .uncompressed_size = block.uncompressed_size,
            });
        }
        if (!continues) break;
        if (archive_index + 1 >= set.archives.len) return error.IncompleteCabinetSet;
        archive_index += 1;
        folder_index = 0;
    }

    const window_bits: u5 = @intCast((type_compress >> 8) & 0x1f);
    return switch (compression) {
        .lzx => lzx.decodeAlloc(allocator, compressed.items, decoded_size, window_bits),
        .quantum => quantum.decodeAlloc(allocator, compressed.items, decoded_size, window_bits),
        .none, .mszip => decodeSimpleBlocks(
            allocator,
            compression,
            compressed.items,
            block_ends.items,
            decoded_size,
        ),
        else => unreachable,
    };
}

fn decodeSimpleBlocks(
    allocator: std.mem.Allocator,
    compression: types.Compression,
    compressed: []const u8,
    block_ends: []const LogicalBlockEnd,
    decoded_size: usize,
) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    try output.ensureTotalCapacity(allocator, decoded_size);
    var compressed_start: usize = 0;
    for (block_ends) |block| {
        if (block.compressed_end < compressed_start or block.compressed_end > compressed.len)
            return error.InvalidCabinet;
        const payload = compressed[compressed_start..block.compressed_end];
        switch (compression) {
            .none => {
                if (payload.len != block.uncompressed_size) return error.InvalidCabinet;
                output.appendSliceAssumeCapacity(payload);
            },
            .mszip => {
                if (payload.len < 2 or !std.mem.eql(u8, payload[0..2], "CK"))
                    return error.InvalidCabinet;
                const history_start = output.items.len -| (32 * 1024);
                const decoded = try deflate.decodeRawAutoAllocWithDictionaryExactSize(
                    allocator,
                    payload[2..],
                    output.items[history_start..],
                    block.uncompressed_size,
                );
                defer allocator.free(decoded);
                output.appendSliceAssumeCapacity(decoded);
            },
            else => unreachable,
        }
        compressed_start = block.compressed_end;
    }
    if (compressed_start != compressed.len or output.items.len != decoded_size)
        return error.SizeMismatch;
    return output.toOwnedSlice(allocator);
}

fn validateBoundary(previous: Archive, current: Archive) Error!void {
    var has_forward_entries = false;
    var previous_entries = previous.iterator();
    while (try previous_entries.next()) |entry| {
        if (!entry.continuation.continuesAfter()) continue;
        has_forward_entries = true;
        const counterpart = (try current.find(entry.name)) orelse return error.CabinetSetMismatch;
        if (!counterpart.continuation.startsBefore() or !sameFile(entry, counterpart))
            return error.CabinetSetMismatch;
    }
    var has_backward_entries = false;
    var current_entries = current.iterator();
    while (try current_entries.next()) |entry| {
        if (!entry.continuation.startsBefore()) continue;
        has_backward_entries = true;
        const counterpart = (try previous.find(entry.name)) orelse return error.CabinetSetMismatch;
        if (!counterpart.continuation.continuesAfter() or !sameFile(entry, counterpart))
            return error.CabinetSetMismatch;
    }

    if (previous.folder_count == 0 or current.folder_count == 0) return;
    const previous_folder = try previous.folderAt(previous.folder_count - 1);
    var blocks = previous.dataBlockIterator(previous_folder);
    var split = false;
    while (try blocks.next()) |block| split = block.uncompressed_size == 0;
    if ((has_forward_entries or has_backward_entries) and !split)
        return error.CabinetSetMismatch;
    if (split) {
        const current_folder = try current.folderAt(0);
        if (previous_folder.type_compress != current_folder.type_compress)
            return error.CabinetSetMismatch;
    }
}

fn sameFile(a: Entry, b: Entry) bool {
    return a.size == b.size and
        a.folder_offset == b.folder_offset and
        a.date == b.date and
        a.time == b.time and
        a.attributes == b.attributes and
        std.mem.eql(u8, a.name, b.name);
}
