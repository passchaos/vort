const std = @import("std");
const types = @import("types.zig");

pub const CompressionMethod = types.CompressionMethod;

pub const local_file_signature: u32 = 0x0403_4b50;
pub const central_file_signature: u32 = 0x0201_4b50;
pub const data_descriptor_signature: u32 = 0x0807_4b50;
pub const end_of_central_signature: u32 = 0x0605_4b50;
pub const zip64_end_of_central_signature: u32 = 0x0606_4b50;
pub const zip64_end_of_central_locator_signature: u32 = 0x0706_4b50;
pub const central_directory_digital_signature: u32 = 0x0505_4b50;
pub const zip64_extra_id: u16 = 0x0001;

pub const local_file_header_len: usize = 30;
pub const central_file_header_len: usize = 46;
pub const data_descriptor_len: usize = 16;
pub const zip64_data_descriptor_len: usize = 24;
pub const end_of_central_len: usize = 22;
pub const zip64_end_of_central_len: usize = 56;
pub const zip64_end_of_central_locator_len: usize = 20;
pub const central_directory_digital_signature_len: usize = 6;

pub const version_10: u16 = 10;
pub const version_20: u16 = 20;
pub const version_21: u16 = 21;
pub const version_45: u16 = 45;
pub const version_46: u16 = 46;
pub const version_63: u16 = 63;

pub const deterministic_dos_time: u16 = 0;
pub const deterministic_dos_date: u16 = 0x0021;
pub const encrypted_flag: u16 = 1 << 0;
pub const descriptor_flag: u16 = 1 << 3;
pub const lzma_end_marker_flag: u16 = 1 << 1;
pub const utf8_flag: u16 = 1 << 11;

/// Format metadata shared by one-shot and streaming ZIP writers.
pub const EncodedEntry = struct {
    name: []const u8,
    comment: []const u8,
    method: CompressionMethod,
    flags: u16,
    crc32: u32,
    compressed_size: u64,
    uncompressed_size: u64,
    local_header_offset: u64,
    zip64: bool,
};

pub const LocalHeaderOptions = struct {
    /// Write zero sizes in the ZIP64 extra field for an entry whose sizes are
    /// not known until its data descriptor is emitted. The legacy size fields
    /// remain ZIP64 sentinels. One-shot writers should keep the default.
    zip64_size_placeholders: bool = false,
};

pub fn appendLocalHeader(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    entry: EncodedEntry,
    options: LocalHeaderOptions,
) !void {
    const descriptor = entry.flags & descriptor_flag != 0;
    try appendU32(allocator, out, local_file_signature);
    try appendU16(allocator, out, requiredVersion(entry.method, entry.zip64));
    try appendU16(allocator, out, entry.flags);
    try appendU16(allocator, out, @intFromEnum(entry.method));
    try appendU16(allocator, out, deterministic_dos_time);
    try appendU16(allocator, out, deterministic_dos_date);
    try appendU32(allocator, out, if (descriptor) 0 else entry.crc32);
    try appendU32(allocator, out, if (entry.zip64) std.math.maxInt(u32) else if (descriptor) 0 else @intCast(entry.compressed_size));
    try appendU32(allocator, out, if (entry.zip64) std.math.maxInt(u32) else if (descriptor) 0 else @intCast(entry.uncompressed_size));
    try appendU16(allocator, out, @intCast(entry.name.len));
    try appendU16(allocator, out, if (entry.zip64) 20 else 0);
    try out.appendSlice(allocator, entry.name);
    if (entry.zip64) {
        try appendU16(allocator, out, zip64_extra_id);
        try appendU16(allocator, out, 16);
        try appendU64(allocator, out, if (options.zip64_size_placeholders) 0 else entry.uncompressed_size);
        try appendU64(allocator, out, if (options.zip64_size_placeholders) 0 else entry.compressed_size);
    }
}

pub fn appendDataDescriptor(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    entry: EncodedEntry,
) !void {
    try appendU32(allocator, out, data_descriptor_signature);
    try appendU32(allocator, out, entry.crc32);
    if (entry.zip64) {
        try appendU64(allocator, out, entry.compressed_size);
        try appendU64(allocator, out, entry.uncompressed_size);
    } else {
        try appendU32(allocator, out, @intCast(entry.compressed_size));
        try appendU32(allocator, out, @intCast(entry.uncompressed_size));
    }
}

pub fn appendCentralHeader(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    entry: EncodedEntry,
) !void {
    try appendU32(allocator, out, central_file_signature);
    try appendU16(allocator, out, requiredVersion(entry.method, entry.zip64));
    try appendU16(allocator, out, requiredVersion(entry.method, entry.zip64));
    try appendU16(allocator, out, entry.flags);
    try appendU16(allocator, out, @intFromEnum(entry.method));
    try appendU16(allocator, out, deterministic_dos_time);
    try appendU16(allocator, out, deterministic_dos_date);
    try appendU32(allocator, out, entry.crc32);
    try appendU32(allocator, out, if (entry.zip64) std.math.maxInt(u32) else @intCast(entry.compressed_size));
    try appendU32(allocator, out, if (entry.zip64) std.math.maxInt(u32) else @intCast(entry.uncompressed_size));
    try appendU16(allocator, out, @intCast(entry.name.len));
    try appendU16(allocator, out, if (entry.zip64) 28 else 0);
    try appendU16(allocator, out, @intCast(entry.comment.len));
    try appendU16(allocator, out, 0);
    try appendU16(allocator, out, 0);
    const external_attributes: u32 = if (std.mem.endsWith(u8, entry.name, "/")) 0x10 else 0;
    try appendU32(allocator, out, external_attributes);
    try appendU32(allocator, out, if (entry.zip64) std.math.maxInt(u32) else @intCast(entry.local_header_offset));
    try out.appendSlice(allocator, entry.name);
    if (entry.zip64) {
        try appendU16(allocator, out, zip64_extra_id);
        try appendU16(allocator, out, 24);
        try appendU64(allocator, out, entry.uncompressed_size);
        try appendU64(allocator, out, entry.compressed_size);
        try appendU64(allocator, out, entry.local_header_offset);
    }
    try out.appendSlice(allocator, entry.comment);
}

pub fn appendZip64End(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    archive_base: usize,
    entry_count: u64,
    central_size: u64,
    central_offset: u64,
    comment: []const u8,
) !void {
    const record_offset = try absoluteOffset(archive_base, out.items.len);
    try appendZip64EndAtOffset(
        allocator,
        out,
        record_offset,
        entry_count,
        central_size,
        central_offset,
        comment,
    );
}

/// Append ZIP64 end records when the caller already tracks the absolute
/// offset independently of `out`, as a streaming writer normally does.
pub fn appendZip64EndAtOffset(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    zip64_record_offset: u64,
    entry_count: u64,
    central_size: u64,
    central_offset: u64,
    comment: []const u8,
) !void {
    try appendU32(allocator, out, zip64_end_of_central_signature);
    try appendU64(allocator, out, 44);
    try appendU16(allocator, out, version_45);
    try appendU16(allocator, out, version_45);
    try appendU32(allocator, out, 0);
    try appendU32(allocator, out, 0);
    try appendU64(allocator, out, entry_count);
    try appendU64(allocator, out, entry_count);
    try appendU64(allocator, out, central_size);
    try appendU64(allocator, out, central_offset);

    try appendU32(allocator, out, zip64_end_of_central_locator_signature);
    try appendU32(allocator, out, 0);
    try appendU64(allocator, out, zip64_record_offset);
    try appendU32(allocator, out, 1);
    try appendLegacyEnd(
        allocator,
        out,
        std.math.maxInt(u16),
        std.math.maxInt(u32),
        std.math.maxInt(u32),
        comment,
    );
}

pub fn appendLegacyEnd(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    entry_count: u16,
    central_size: u32,
    central_offset: u32,
    comment: []const u8,
) !void {
    try appendU32(allocator, out, end_of_central_signature);
    try appendU16(allocator, out, 0);
    try appendU16(allocator, out, 0);
    try appendU16(allocator, out, entry_count);
    try appendU16(allocator, out, entry_count);
    try appendU32(allocator, out, central_size);
    try appendU32(allocator, out, central_offset);
    try appendU16(allocator, out, @intCast(comment.len));
    try out.appendSlice(allocator, comment);
}

pub fn requiredVersion(method: CompressionMethod, zip64: bool) u16 {
    if (method == .deflate64) return if (zip64) version_45 else version_21;
    if (method == .bzip2) return version_46;
    if (method == .lzma or method == .xz or method == .ppmd or isZstandardMethod(method)) return version_63;
    return if (zip64) version_45 else version_20;
}

pub fn selectEntryZip64(
    always: bool,
    compressed_size: u64,
    uncompressed_size: u64,
    local_header_offset: u64,
) bool {
    return always or compressed_size >= std.math.maxInt(u32) or
        uncompressed_size >= std.math.maxInt(u32) or
        local_header_offset >= std.math.maxInt(u32);
}

pub fn selectArchiveZip64(
    always: bool,
    entries: []const EncodedEntry,
    entry_count: u64,
    central_size: u64,
    central_offset: u64,
) bool {
    return always or anyZip64Entry(entries) or
        entry_count >= std.math.maxInt(u16) or
        central_size >= std.math.maxInt(u32) or
        central_offset >= std.math.maxInt(u32);
}

pub fn anyZip64Entry(entries: []const EncodedEntry) bool {
    for (entries) |entry| if (entry.zip64) return true;
    return false;
}

pub fn absoluteOffset(base: usize, relative: usize) error{IntegerOverflow}!u64 {
    const value = std.math.add(usize, base, relative) catch return error.IntegerOverflow;
    return usizeToU64(value);
}

pub fn zip32Value(value: usize) error{Zip32LimitExceeded}!u32 {
    if (value >= std.math.maxInt(u32)) return error.Zip32LimitExceeded;
    return @intCast(value);
}

pub fn usizeToU64(value: usize) error{IntegerOverflow}!u64 {
    return std.math.cast(u64, value) orelse error.IntegerOverflow;
}

pub fn appendU16(allocator: std.mem.Allocator, out: *std.ArrayList(u8), value: u16) !void {
    var bytes: [2]u8 = undefined;
    std.mem.writeInt(u16, &bytes, value, .little);
    try out.appendSlice(allocator, &bytes);
}

pub fn appendU32(allocator: std.mem.Allocator, out: *std.ArrayList(u8), value: u32) !void {
    var bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &bytes, value, .little);
    try out.appendSlice(allocator, &bytes);
}

pub fn appendU64(allocator: std.mem.Allocator, out: *std.ArrayList(u8), value: u64) !void {
    var bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, &bytes, value, .little);
    try out.appendSlice(allocator, &bytes);
}

fn isZstandardMethod(method: CompressionMethod) bool {
    return method == .zstandard_legacy or method == .zstandard;
}

test "ZIP wire serializer matches stored-entry golden bytes" {
    const allocator = std.testing.allocator;
    var actual: std.ArrayList(u8) = .empty;
    defer actual.deinit(allocator);

    const entry = EncodedEntry{
        .name = "a",
        .comment = "",
        .method = .stored,
        .flags = 0,
        .crc32 = 0x8cdc_1683,
        .compressed_size = 1,
        .uncompressed_size = 1,
        .local_header_offset = 0,
        .zip64 = false,
    };
    try appendLocalHeader(allocator, &actual, entry, .{});
    try actual.append(allocator, 'x');
    try appendCentralHeader(allocator, &actual, entry);
    try appendLegacyEnd(allocator, &actual, 1, 47, 32, "");

    const expected_hex =
        "504b0304140000000000000021008316dc8c0100000001000000010000006178" ++
        "504b01021400140000000000000021008316dc8c010000000100000001000000" ++
        "000000000000000000000000000061" ++
        "504b050600000000010001002f000000200000000000";
    var expected: [expected_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&expected, expected_hex);
    try std.testing.expectEqualSlices(u8, &expected, actual.items);
}

test "ZIP wire data descriptors preserve ZIP32 and ZIP64 layouts" {
    const allocator = std.testing.allocator;
    var actual: std.ArrayList(u8) = .empty;
    defer actual.deinit(allocator);

    var entry = EncodedEntry{
        .name = "payload",
        .comment = "",
        .method = .stored,
        .flags = descriptor_flag,
        .crc32 = 0x1234_5678,
        .compressed_size = 2,
        .uncompressed_size = 3,
        .local_header_offset = 0,
        .zip64 = false,
    };
    try appendDataDescriptor(allocator, &actual, entry);
    entry.zip64 = true;
    try appendDataDescriptor(allocator, &actual, entry);

    const expected_hex =
        "504b0708785634120200000003000000" ++
        "504b07087856341202000000000000000300000000000000";
    var expected: [expected_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&expected, expected_hex);
    try std.testing.expectEqualSlices(u8, &expected, actual.items);
}

test "ZIP wire supports unknown ZIP64 local sizes without changing sentinels" {
    const allocator = std.testing.allocator;
    var actual: std.ArrayList(u8) = .empty;
    defer actual.deinit(allocator);

    const entry = EncodedEntry{
        .name = "payload",
        .comment = "",
        .method = .stored,
        .flags = descriptor_flag,
        .crc32 = 0x1234_5678,
        .compressed_size = 2,
        .uncompressed_size = 3,
        .local_header_offset = 0,
        .zip64 = true,
    };
    try appendLocalHeader(allocator, &actual, entry, .{ .zip64_size_placeholders = true });

    try std.testing.expectEqual(local_file_header_len + entry.name.len + 20, actual.items.len);
    try std.testing.expectEqual(@as(u32, 0), std.mem.readInt(u32, actual.items[14..][0..4], .little));
    try std.testing.expectEqual(std.math.maxInt(u32), std.mem.readInt(u32, actual.items[18..][0..4], .little));
    try std.testing.expectEqual(std.math.maxInt(u32), std.mem.readInt(u32, actual.items[22..][0..4], .little));
    const extra_offset = local_file_header_len + entry.name.len;
    try std.testing.expectEqual(zip64_extra_id, std.mem.readInt(u16, actual.items[extra_offset..][0..2], .little));
    try std.testing.expectEqual(@as(u64, 0), std.mem.readInt(u64, actual.items[extra_offset + 4 ..][0..8], .little));
    try std.testing.expectEqual(@as(u64, 0), std.mem.readInt(u64, actual.items[extra_offset + 12 ..][0..8], .little));
}

test "ZIP64 end serializer accepts a caller-tracked absolute offset" {
    const allocator = std.testing.allocator;
    var complete_archive: std.ArrayList(u8) = .empty;
    defer complete_archive.deinit(allocator);
    var streaming_tail: std.ArrayList(u8) = .empty;
    defer streaming_tail.deinit(allocator);

    try complete_archive.appendSlice(allocator, "central");
    try appendZip64End(allocator, &complete_archive, 13, 2, 47, 32, "comment");
    try appendZip64EndAtOffset(allocator, &streaming_tail, 20, 2, 47, 32, "comment");

    try std.testing.expectEqualSlices(u8, complete_archive.items["central".len..], streaming_tail.items);
    const locator_offset = zip64_end_of_central_len;
    try std.testing.expectEqual(
        @as(u64, 20),
        std.mem.readInt(u64, streaming_tail.items[locator_offset + 8 ..][0..8], .little),
    );
}
