const std = @import("std");
const core = @import("core.zig");
const checksum = @import("checksum.zig");
const deflate = @import("deflate.zig");

pub const Error = core.Error || error{
    InvalidZipArchive,
    UnsupportedZipFeature,
    EncryptedZipEntry,
    UnsupportedZipCompressionMethod,
    ZipEntryNotFound,
};

const local_file_signature: u32 = 0x0403_4b50;
const central_file_signature: u32 = 0x0201_4b50;
const end_of_central_signature: u32 = 0x0605_4b50;
const end_of_central_len: usize = 22;
const max_comment_len: usize = std.math.maxInt(u16);

pub const CompressionMethod = enum(u16) {
    stored = 0,
    deflate = 8,
    _,
};

pub const Entry = struct {
    name: []const u8,
    method: CompressionMethod,
    flags: u16,
    crc32: u32,
    compressed_size: usize,
    uncompressed_size: usize,
    local_header_offset: usize,
    central_header_offset: usize,

    pub fn isDirectory(self: Entry) bool {
        return self.name.len != 0 and self.name[self.name.len - 1] == '/';
    }

    pub fn isEncrypted(self: Entry) bool {
        return self.flags & 1 != 0;
    }
};

pub const Archive = struct {
    bytes: []const u8,
    entry_count: usize,
    central_directory_offset: usize,
    central_directory_size: usize,
    comment: []const u8,

    pub fn iterator(self: Archive) Iterator {
        return .{
            .archive = self,
            .offset = self.central_directory_offset,
            .remaining = self.entry_count,
        };
    }

    pub fn entryAt(self: Archive, index: usize) Error!Entry {
        if (index >= self.entry_count) return error.RangeOutOfBounds;
        var it = self.iterator();
        var current: usize = 0;
        while (try it.next()) |entry| : (current += 1)
            if (current == index) return entry;
        return error.InvalidZipArchive;
    }

    pub fn find(self: Archive, name: []const u8) Error!?Entry {
        var it = self.iterator();
        while (try it.next()) |entry|
            if (std.mem.eql(u8, entry.name, name)) return entry;
        return null;
    }

    pub fn entriesAlloc(self: Archive, allocator: std.mem.Allocator) ![]Entry {
        const entries = try allocator.alloc(Entry, self.entry_count);
        errdefer allocator.free(entries);
        var it = self.iterator();
        var index: usize = 0;
        while (try it.next()) |entry| : (index += 1) entries[index] = entry;
        if (index != entries.len) return error.InvalidZipArchive;
        return entries;
    }

    pub fn extractInto(self: Archive, entry: Entry, output: []u8) Error!usize {
        const parsed = try parseCentralEntry(self, entry.central_header_offset);
        const canonical = parsed.entry;
        if (output.len < canonical.uncompressed_size) return error.OutputTooSmall;
        if (canonical.isEncrypted()) return error.EncryptedZipEntry;

        const compressed = try localCompressedData(self, canonical);
        const target = output[0..canonical.uncompressed_size];
        switch (canonical.method) {
            .stored => {
                if (canonical.compressed_size != canonical.uncompressed_size) return error.InvalidZipArchive;
                @memcpy(target, compressed);
            },
            .deflate => {
                const decoded = try deflate.decodeRawAuto(compressed, target);
                if (decoded.input_read != compressed.len) return error.InvalidZipArchive;
                if (decoded.output_written != target.len) return error.SizeMismatch;
            },
            else => return error.UnsupportedZipCompressionMethod,
        }
        if (checksum.crc32Best(target) != canonical.crc32) return error.ChecksumMismatch;
        return target.len;
    }

    pub fn extractAlloc(self: Archive, allocator: std.mem.Allocator, entry: Entry) ![]u8 {
        return self.extractAllocLimited(allocator, entry, std.math.maxInt(usize));
    }

    pub fn extractAllocLimited(self: Archive, allocator: std.mem.Allocator, entry: Entry, max_output_len: usize) ![]u8 {
        if (entry.uncompressed_size > max_output_len) return error.OutputLimitExceeded;
        const output = try allocator.alloc(u8, entry.uncompressed_size);
        errdefer allocator.free(output);
        const written = try self.extractInto(entry, output);
        if (written != output.len) return error.SizeMismatch;
        return output;
    }

    pub fn extractByNameAlloc(self: Archive, allocator: std.mem.Allocator, name: []const u8) ![]u8 {
        return self.extractByNameAllocLimited(allocator, name, std.math.maxInt(usize));
    }

    pub fn extractByNameAllocLimited(self: Archive, allocator: std.mem.Allocator, name: []const u8, max_output_len: usize) ![]u8 {
        const entry = (try self.find(name)) orelse return error.ZipEntryNotFound;
        return self.extractAllocLimited(allocator, entry, max_output_len);
    }
};

pub const Iterator = struct {
    archive: Archive,
    offset: usize,
    remaining: usize,

    pub fn next(self: *Iterator) Error!?Entry {
        if (self.remaining == 0) return null;
        const parsed = try parseCentralEntry(self.archive, self.offset);
        self.offset = parsed.next_offset;
        self.remaining -= 1;
        return parsed.entry;
    }
};

pub fn parse(bytes: []const u8) Error!Archive {
    const eocd_offset = findEndOfCentralDirectory(bytes) orelse return error.InvalidZipArchive;
    const disk_number = try readU16(bytes, eocd_offset + 4);
    const central_disk = try readU16(bytes, eocd_offset + 6);
    const entries_on_disk = try readU16(bytes, eocd_offset + 8);
    const entry_count_u16 = try readU16(bytes, eocd_offset + 10);
    const central_size_u32 = try readU32(bytes, eocd_offset + 12);
    const central_offset_u32 = try readU32(bytes, eocd_offset + 16);
    const comment_len: usize = try readU16(bytes, eocd_offset + 20);
    if (disk_number != 0 or central_disk != 0 or entries_on_disk != entry_count_u16)
        return error.UnsupportedZipFeature;
    if (entry_count_u16 == std.math.maxInt(u16) or
        central_size_u32 == std.math.maxInt(u32) or
        central_offset_u32 == std.math.maxInt(u32)) return error.UnsupportedZipFeature;

    const comment_start = eocd_offset + end_of_central_len;
    const comment_end = try checkedEnd(comment_start, comment_len, bytes.len);
    if (comment_end != bytes.len) return error.InvalidZipArchive;
    const central_offset: usize = central_offset_u32;
    const central_size: usize = central_size_u32;
    const central_end = try checkedEnd(central_offset, central_size, bytes.len);
    if (central_end > eocd_offset) return error.InvalidZipArchive;

    return .{
        .bytes = bytes,
        .entry_count = entry_count_u16,
        .central_directory_offset = central_offset,
        .central_directory_size = central_size,
        .comment = bytes[comment_start..comment_end],
    };
}

pub fn extractEntryInto(bytes: []const u8, index: usize, output: []u8) Error!usize {
    const archive = try parse(bytes);
    return archive.extractInto(try archive.entryAt(index), output);
}

pub fn extractEntryAlloc(allocator: std.mem.Allocator, bytes: []const u8, index: usize) ![]u8 {
    const archive = try parse(bytes);
    return archive.extractAlloc(allocator, try archive.entryAt(index));
}

pub fn extractEntryAllocLimited(allocator: std.mem.Allocator, bytes: []const u8, index: usize, max_output_len: usize) ![]u8 {
    const archive = try parse(bytes);
    return archive.extractAllocLimited(allocator, try archive.entryAt(index), max_output_len);
}

pub fn extractByNameAlloc(allocator: std.mem.Allocator, bytes: []const u8, name: []const u8) ![]u8 {
    return (try parse(bytes)).extractByNameAlloc(allocator, name);
}

pub fn extractByNameAllocLimited(allocator: std.mem.Allocator, bytes: []const u8, name: []const u8, max_output_len: usize) ![]u8 {
    return (try parse(bytes)).extractByNameAllocLimited(allocator, name, max_output_len);
}

const ParsedCentralEntry = struct { entry: Entry, next_offset: usize };

fn parseCentralEntry(archive: Archive, offset: usize) Error!ParsedCentralEntry {
    const central_end = try checkedEnd(archive.central_directory_offset, archive.central_directory_size, archive.bytes.len);
    if (offset < archive.central_directory_offset or offset >= central_end) return error.InvalidZipArchive;
    if (try readU32(archive.bytes, offset) != central_file_signature) return error.InvalidZipArchive;
    _ = try checkedEnd(offset, 46, central_end);

    const flags = try readU16(archive.bytes, offset + 8);
    const method_raw = try readU16(archive.bytes, offset + 10);
    const crc = try readU32(archive.bytes, offset + 16);
    const compressed_u32 = try readU32(archive.bytes, offset + 20);
    const uncompressed_u32 = try readU32(archive.bytes, offset + 24);
    const name_len: usize = try readU16(archive.bytes, offset + 28);
    const extra_len: usize = try readU16(archive.bytes, offset + 30);
    const comment_len: usize = try readU16(archive.bytes, offset + 32);
    const disk_start = try readU16(archive.bytes, offset + 34);
    const local_offset_u32 = try readU32(archive.bytes, offset + 42);
    if (disk_start != 0) return error.UnsupportedZipFeature;
    if (compressed_u32 == std.math.maxInt(u32) or
        uncompressed_u32 == std.math.maxInt(u32) or
        local_offset_u32 == std.math.maxInt(u32)) return error.UnsupportedZipFeature;

    const name_start = offset + 46;
    const name_end = try checkedEnd(name_start, name_len, central_end);
    const extra_end = try checkedEnd(name_end, extra_len, central_end);
    const next_offset = try checkedEnd(extra_end, comment_len, central_end);
    const local_offset: usize = local_offset_u32;
    if (local_offset >= archive.central_directory_offset) return error.InvalidZipArchive;

    return .{
        .entry = .{
            .name = archive.bytes[name_start..name_end],
            .method = @enumFromInt(method_raw),
            .flags = flags,
            .crc32 = crc,
            .compressed_size = compressed_u32,
            .uncompressed_size = uncompressed_u32,
            .local_header_offset = local_offset,
            .central_header_offset = offset,
        },
        .next_offset = next_offset,
    };
}

fn localCompressedData(archive: Archive, entry: Entry) Error![]const u8 {
    const offset = entry.local_header_offset;
    if (try readU32(archive.bytes, offset) != local_file_signature) return error.InvalidZipArchive;
    _ = try checkedEnd(offset, 30, archive.central_directory_offset);
    const local_flags = try readU16(archive.bytes, offset + 6);
    const local_method = try readU16(archive.bytes, offset + 8);
    const local_crc = try readU32(archive.bytes, offset + 14);
    const local_compressed = try readU32(archive.bytes, offset + 18);
    const local_uncompressed = try readU32(archive.bytes, offset + 22);
    const name_len: usize = try readU16(archive.bytes, offset + 26);
    const extra_len: usize = try readU16(archive.bytes, offset + 28);
    if (local_method != @intFromEnum(entry.method)) return error.InvalidZipArchive;
    if ((local_flags ^ entry.flags) & 0x0009 != 0) return error.InvalidZipArchive;
    if (local_flags & 1 != 0) return error.EncryptedZipEntry;

    const name_start = offset + 30;
    const name_end = try checkedEnd(name_start, name_len, archive.central_directory_offset);
    if (!std.mem.eql(u8, archive.bytes[name_start..name_end], entry.name)) return error.InvalidZipArchive;
    const data_start = try checkedEnd(name_end, extra_len, archive.central_directory_offset);
    const data_end = try checkedEnd(data_start, entry.compressed_size, archive.central_directory_offset);
    if (local_flags & 0x0008 == 0) {
        if (local_crc != entry.crc32 or local_compressed != entry.compressed_size or local_uncompressed != entry.uncompressed_size)
            return error.InvalidZipArchive;
    }
    return archive.bytes[data_start..data_end];
}

fn findEndOfCentralDirectory(bytes: []const u8) ?usize {
    if (bytes.len < end_of_central_len) return null;
    const search_len = @min(bytes.len, end_of_central_len + max_comment_len);
    const lower = bytes.len - search_len;
    var offset = bytes.len - end_of_central_len;
    while (true) {
        if (std.mem.readInt(u32, bytes[offset..][0..4], .little) == end_of_central_signature) {
            const comment_len = std.mem.readInt(u16, bytes[offset + 20 ..][0..2], .little);
            if (offset + end_of_central_len + @as(usize, comment_len) == bytes.len) return offset;
        }
        if (offset == lower) break;
        offset -= 1;
    }
    return null;
}

fn readU16(bytes: []const u8, offset: usize) Error!u16 {
    _ = try checkedEnd(offset, 2, bytes.len);
    return std.mem.readInt(u16, bytes[offset..][0..2], .little);
}

fn readU32(bytes: []const u8, offset: usize) Error!u32 {
    _ = try checkedEnd(offset, 4, bytes.len);
    return std.mem.readInt(u32, bytes[offset..][0..4], .little);
}

fn checkedEnd(start: usize, len: usize, limit: usize) Error!usize {
    const end = std.math.add(usize, start, len) catch return error.InvalidZipArchive;
    if (end > limit) return error.InvalidZipArchive;
    return end;
}

const TestEntry = struct {
    name: []const u8,
    payload: []const u8,
    compressed: []const u8,
    method: u16,
    flags: u16,
    local_offset: usize,
};

fn appendU16(out: *std.ArrayList(u8), allocator: std.mem.Allocator, value: u16) !void {
    var bytes: [2]u8 = undefined;
    std.mem.writeInt(u16, &bytes, value, .little);
    try out.appendSlice(allocator, &bytes);
}

fn appendU32(out: *std.ArrayList(u8), allocator: std.mem.Allocator, value: u32) !void {
    var bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &bytes, value, .little);
    try out.appendSlice(allocator, &bytes);
}

fn appendTestLocal(out: *std.ArrayList(u8), allocator: std.mem.Allocator, entry: *TestEntry) !void {
    entry.local_offset = out.items.len;
    const descriptor = entry.flags & 0x0008 != 0;
    try appendU32(out, allocator, local_file_signature);
    try appendU16(out, allocator, 20);
    try appendU16(out, allocator, entry.flags);
    try appendU16(out, allocator, entry.method);
    try appendU16(out, allocator, 0);
    try appendU16(out, allocator, 0);
    try appendU32(out, allocator, if (descriptor) 0 else checksum.crc32(entry.payload));
    try appendU32(out, allocator, if (descriptor) 0 else @intCast(entry.compressed.len));
    try appendU32(out, allocator, if (descriptor) 0 else @intCast(entry.payload.len));
    try appendU16(out, allocator, @intCast(entry.name.len));
    try appendU16(out, allocator, 0);
    try out.appendSlice(allocator, entry.name);
    try out.appendSlice(allocator, entry.compressed);
    if (descriptor) {
        try appendU32(out, allocator, 0x0807_4b50);
        try appendU32(out, allocator, checksum.crc32(entry.payload));
        try appendU32(out, allocator, @intCast(entry.compressed.len));
        try appendU32(out, allocator, @intCast(entry.payload.len));
    }
}

fn appendTestCentral(out: *std.ArrayList(u8), allocator: std.mem.Allocator, entry: TestEntry) !void {
    try appendU32(out, allocator, central_file_signature);
    try appendU16(out, allocator, 20);
    try appendU16(out, allocator, 20);
    try appendU16(out, allocator, entry.flags);
    try appendU16(out, allocator, entry.method);
    try appendU16(out, allocator, 0);
    try appendU16(out, allocator, 0);
    try appendU32(out, allocator, checksum.crc32(entry.payload));
    try appendU32(out, allocator, @intCast(entry.compressed.len));
    try appendU32(out, allocator, @intCast(entry.payload.len));
    try appendU16(out, allocator, @intCast(entry.name.len));
    try appendU16(out, allocator, 0);
    try appendU16(out, allocator, 0);
    try appendU16(out, allocator, 0);
    try appendU16(out, allocator, 0);
    try appendU32(out, allocator, 0);
    try appendU32(out, allocator, @intCast(entry.local_offset));
    try out.appendSlice(allocator, entry.name);
}

test "ZIP parses and extracts stored and descriptor-backed deflate entries" {
    const allocator = std.testing.allocator;
    const stored_payload = "hello zip";
    const deflated_payload = "deflated payload " ** 32;
    const compressed = try deflate.encodeRawFixedAlloc(allocator, deflated_payload);
    defer allocator.free(compressed);
    var entries = [_]TestEntry{
        .{ .name = "hello.txt", .payload = stored_payload, .compressed = stored_payload, .method = 0, .flags = 0, .local_offset = 0 },
        .{ .name = "data.bin", .payload = deflated_payload, .compressed = compressed, .method = 8, .flags = 0x0008, .local_offset = 0 },
    };
    var bytes: std.ArrayList(u8) = .empty;
    defer bytes.deinit(allocator);
    for (&entries) |*entry| try appendTestLocal(&bytes, allocator, entry);
    const central_offset = bytes.items.len;
    for (entries) |entry| try appendTestCentral(&bytes, allocator, entry);
    const central_size = bytes.items.len - central_offset;
    try appendU32(&bytes, allocator, end_of_central_signature);
    try appendU16(&bytes, allocator, 0);
    try appendU16(&bytes, allocator, 0);
    try appendU16(&bytes, allocator, entries.len);
    try appendU16(&bytes, allocator, entries.len);
    try appendU32(&bytes, allocator, @intCast(central_size));
    try appendU32(&bytes, allocator, @intCast(central_offset));
    try appendU16(&bytes, allocator, 4);
    try bytes.appendSlice(allocator, "test");

    const archive = try parse(bytes.items);
    try std.testing.expectEqual(@as(usize, 2), archive.entry_count);
    try std.testing.expectEqualStrings("test", archive.comment);
    const listed = try archive.entriesAlloc(allocator);
    defer allocator.free(listed);
    try std.testing.expectEqualStrings("hello.txt", listed[0].name);
    try std.testing.expectEqual(CompressionMethod.stored, listed[0].method);
    try std.testing.expectEqualStrings("data.bin", listed[1].name);
    try std.testing.expectEqual(CompressionMethod.deflate, listed[1].method);

    var stored_output: [stored_payload.len]u8 = undefined;
    try std.testing.expectEqual(stored_payload.len, try archive.extractInto(listed[0], &stored_output));
    try std.testing.expectEqualSlices(u8, stored_payload, &stored_output);
    const decoded = try archive.extractByNameAlloc(allocator, "data.bin");
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, deflated_payload, decoded);
    try std.testing.expectError(error.OutputTooSmall, archive.extractInto(listed[1], stored_output[0..]));
    try std.testing.expectError(error.OutputLimitExceeded, archive.extractAllocLimited(allocator, listed[1], deflated_payload.len - 1));
    try std.testing.expectError(error.ZipEntryNotFound, archive.extractByNameAlloc(allocator, "missing"));
    try std.testing.expectError(error.RangeOutOfBounds, archive.entryAt(2));

    var corrupt = try allocator.dupe(u8, bytes.items);
    defer allocator.free(corrupt);
    corrupt[listed[1].central_header_offset + 16] ^= 1;
    const corrupt_archive = try parse(corrupt);
    const corrupt_entry = try corrupt_archive.entryAt(1);
    var corrupt_output: [deflated_payload.len]u8 = undefined;
    try std.testing.expectError(error.ChecksumMismatch, corrupt_archive.extractInto(corrupt_entry, &corrupt_output));

    var encrypted = try allocator.dupe(u8, bytes.items);
    defer allocator.free(encrypted);
    encrypted[entries[0].local_offset + 6] |= 1;
    encrypted[listed[0].central_header_offset + 8] |= 1;
    const encrypted_archive = try parse(encrypted);
    const encrypted_entry = try encrypted_archive.entryAt(0);
    var encrypted_output: [stored_payload.len]u8 = undefined;
    try std.testing.expectError(error.EncryptedZipEntry, encrypted_archive.extractInto(encrypted_entry, &encrypted_output));

    var unsupported = try allocator.dupe(u8, bytes.items);
    defer allocator.free(unsupported);
    std.mem.writeInt(u16, unsupported[entries[0].local_offset + 8 ..][0..2], 12, .little);
    std.mem.writeInt(u16, unsupported[listed[0].central_header_offset + 10 ..][0..2], 12, .little);
    const unsupported_archive = try parse(unsupported);
    const unsupported_entry = try unsupported_archive.entryAt(0);
    try std.testing.expectError(error.UnsupportedZipCompressionMethod, unsupported_archive.extractInto(unsupported_entry, &encrypted_output));

    var zip64 = try allocator.dupe(u8, bytes.items);
    defer allocator.free(zip64);
    std.mem.writeInt(u32, zip64[listed[0].central_header_offset + 20 ..][0..4], std.math.maxInt(u32), .little);
    const zip64_archive = try parse(zip64);
    try std.testing.expectError(error.UnsupportedZipFeature, zip64_archive.entryAt(0));

    var mismatched_name = try allocator.dupe(u8, bytes.items);
    defer allocator.free(mismatched_name);
    mismatched_name[entries[0].local_offset + 30] ^= 1;
    const mismatch_archive = try parse(mismatched_name);
    const mismatch_entry = try mismatch_archive.entryAt(0);
    try std.testing.expectError(error.InvalidZipArchive, mismatch_archive.extractInto(mismatch_entry, &encrypted_output));
}

test "ZIP rejects unsupported archive and entry features" {
    try std.testing.expectError(error.InvalidZipArchive, parse("not a zip"));

    var empty: [end_of_central_len]u8 = @splat(0);
    std.mem.writeInt(u32, empty[0..4], end_of_central_signature, .little);
    const archive = try parse(&empty);
    try std.testing.expectEqual(@as(usize, 0), archive.entry_count);

    std.mem.writeInt(u16, empty[4..6], 1, .little);
    try std.testing.expectError(error.UnsupportedZipFeature, parse(&empty));
}
