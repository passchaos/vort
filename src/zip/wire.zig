const std = @import("std");
const checksum = @import("../checksum.zig");
const types = @import("types.zig");

pub const CompressionMethod = types.CompressionMethod;

pub const local_file_signature: u32 = 0x0403_4b50;
pub const central_file_signature: u32 = 0x0201_4b50;
pub const data_descriptor_signature: u32 = 0x0807_4b50;
pub const archive_extra_data_signature: u32 = 0x0806_4b50;
pub const end_of_central_signature: u32 = 0x0605_4b50;
pub const zip64_end_of_central_signature: u32 = 0x0606_4b50;
pub const zip64_end_of_central_locator_signature: u32 = 0x0706_4b50;
pub const central_directory_digital_signature: u32 = 0x0505_4b50;
pub const zip64_extra_id: u16 = 0x0001;
pub const ntfs_timestamp_extra_id: u16 = 0x000a;
pub const extended_timestamp_extra_id: u16 = 0x5455;
pub const unicode_comment_extra_id: u16 = 0x6375;
pub const unicode_path_extra_id: u16 = 0x7075;
pub const pkware_strong_extra_id: u16 = 0x0017;
pub const winzip_aes_extra_id: u16 = 0x9901;

pub const local_file_header_len: usize = 30;
pub const central_file_header_len: usize = 46;
pub const data_descriptor_len: usize = 16;
pub const zip64_data_descriptor_len: usize = 24;
pub const end_of_central_len: usize = 22;
pub const zip64_end_of_central_len: usize = 56;
pub const zip64_end_of_central_locator_len: usize = 20;
pub const central_directory_digital_signature_len: usize = 6;
pub const archive_extra_data_header_len: usize = 8;

pub const version_10: u16 = 10;
pub const version_20: u16 = 20;
pub const version_21: u16 = 21;
pub const version_45: u16 = 45;
pub const version_46: u16 = 46;
pub const version_51: u16 = 51;
pub const version_63: u16 = 63;

pub const deterministic_dos_time: u16 = 0;
pub const deterministic_dos_date: u16 = 0x0021;
pub const encrypted_flag: u16 = 1 << 0;
pub const strong_encryption_flag: u16 = 1 << 6;
pub const descriptor_flag: u16 = 1 << 3;
pub const lzma_end_marker_flag: u16 = 1 << 1;
pub const utf8_flag: u16 = 1 << 11;

/// Format metadata shared by one-shot and streaming ZIP writers.
pub const EncodedEntry = struct {
    name: []const u8,
    comment: []const u8,
    unicode_name: ?[]const u8 = null,
    unicode_comment: ?[]const u8 = null,
    method: CompressionMethod,
    flags: u16,
    crc32: u32,
    compressed_size: u64,
    uncompressed_size: u64,
    local_header_offset: u64,
    zip64: bool,
    modified: types.DosTimestamp = .deterministic,
    extended_timestamp: ?types.ExtendedTimestamp = null,
    ntfs_timestamp: ?types.NtfsTimestamp = null,
    creator_system: types.CreatorSystem = .fat,
    internal_attributes: u16 = 0,
    external_attributes: ?u32 = null,
    winzip_aes: ?types.WinZipAesInfo = null,
    pkware_strong_encryption: ?types.PkwareStrongEncryptionInfo = null,
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
    try appendU16(allocator, out, requiredVersionForEntry(entry));
    try appendU16(allocator, out, entry.flags);
    try appendU16(
        allocator,
        out,
        @intFromEnum(if (entry.winzip_aes != null) CompressionMethod.aes else entry.method),
    );
    try appendU16(allocator, out, entry.modified.time);
    try appendU16(allocator, out, entry.modified.date);
    try appendU32(allocator, out, if (descriptor) 0 else entry.crc32);
    try appendU32(allocator, out, if (entry.zip64) std.math.maxInt(u32) else if (descriptor) 0 else @intCast(entry.compressed_size));
    try appendU32(allocator, out, if (entry.zip64) std.math.maxInt(u32) else if (descriptor) 0 else @intCast(entry.uncompressed_size));
    try appendU16(allocator, out, @intCast(entry.name.len));
    try appendU16(allocator, out, @intCast(localExtraLen(entry)));
    try out.appendSlice(allocator, entry.name);
    if (entry.zip64) {
        try appendU16(allocator, out, zip64_extra_id);
        try appendU16(allocator, out, 16);
        try appendU64(allocator, out, if (options.zip64_size_placeholders) 0 else entry.uncompressed_size);
        try appendU64(allocator, out, if (options.zip64_size_placeholders) 0 else entry.compressed_size);
    }
    if (entry.winzip_aes) |aes| try appendWinZipAesExtra(allocator, out, aes, entry.method);
    if (entry.extended_timestamp) |timestamp|
        try appendExtendedTimestampExtra(allocator, out, timestamp, .local);
    if (entry.ntfs_timestamp) |timestamp|
        try appendNtfsTimestampExtra(allocator, out, timestamp);
    if (entry.unicode_name) |unicode_name|
        try appendUnicodeExtra(
            allocator,
            out,
            unicode_path_extra_id,
            entry.name,
            unicode_name,
        );
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

pub fn appendArchiveExtraData(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    data: []const u8,
) !void {
    if (data.len == 0) return;
    try appendU32(allocator, out, archive_extra_data_signature);
    try appendU32(allocator, out, @intCast(data.len));
    try out.appendSlice(allocator, data);
}

pub fn appendCentralHeader(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    entry: EncodedEntry,
) !void {
    try appendU32(allocator, out, central_file_signature);
    try appendU16(
        allocator,
        out,
        (@as(u16, @intFromEnum(entry.creator_system)) << 8) |
            requiredVersionForEntry(entry),
    );
    try appendU16(allocator, out, requiredVersionForEntry(entry));
    try appendU16(allocator, out, entry.flags);
    try appendU16(
        allocator,
        out,
        @intFromEnum(if (entry.winzip_aes != null) CompressionMethod.aes else entry.method),
    );
    try appendU16(allocator, out, entry.modified.time);
    try appendU16(allocator, out, entry.modified.date);
    try appendU32(allocator, out, entry.crc32);
    try appendU32(allocator, out, if (entry.zip64) std.math.maxInt(u32) else @intCast(entry.compressed_size));
    try appendU32(allocator, out, if (entry.zip64) std.math.maxInt(u32) else @intCast(entry.uncompressed_size));
    try appendU16(allocator, out, @intCast(entry.name.len));
    try appendU16(allocator, out, @intCast(centralExtraLen(entry)));
    try appendU16(allocator, out, @intCast(entry.comment.len));
    try appendU16(allocator, out, 0);
    try appendU16(allocator, out, entry.internal_attributes);
    const external_attributes = entry.external_attributes orelse
        if (std.mem.endsWith(u8, entry.name, "/")) @as(u32, 0x10) else 0;
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
    if (entry.winzip_aes) |aes| try appendWinZipAesExtra(allocator, out, aes, entry.method);
    if (entry.pkware_strong_encryption) |strong|
        try appendPkwareStrongEncryptionExtra(allocator, out, strong);
    if (entry.extended_timestamp) |timestamp|
        if (timestamp.modified != null)
            try appendExtendedTimestampExtra(allocator, out, timestamp, .central);
    if (entry.ntfs_timestamp) |timestamp|
        try appendNtfsTimestampExtra(allocator, out, timestamp);
    if (entry.unicode_name) |unicode_name|
        try appendUnicodeExtra(
            allocator,
            out,
            unicode_path_extra_id,
            entry.name,
            unicode_name,
        );
    if (entry.unicode_comment) |unicode_comment|
        try appendUnicodeExtra(
            allocator,
            out,
            unicode_comment_extra_id,
            entry.comment,
            unicode_comment,
        );
    try out.appendSlice(allocator, entry.comment);
}

pub fn localExtraLen(entry: EncodedEntry) usize {
    return (if (entry.zip64) @as(usize, 20) else 0) +
        (if (entry.winzip_aes != null) @as(usize, 11) else 0) +
        localTimestampExtraLen(entry.extended_timestamp, entry.ntfs_timestamp) +
        unicodeExtraLen(entry.unicode_name);
}

pub fn centralExtraLen(entry: EncodedEntry) usize {
    return (if (entry.zip64) @as(usize, 28) else 0) +
        (if (entry.winzip_aes != null) @as(usize, 11) else 0) +
        (if (entry.pkware_strong_encryption != null) @as(usize, 12) else 0) +
        centralTimestampExtraLen(entry.extended_timestamp, entry.ntfs_timestamp) +
        unicodeExtraLen(entry.unicode_name) +
        unicodeExtraLen(entry.unicode_comment);
}

pub fn unicodeExtraLen(value: ?[]const u8) usize {
    return if (value) |text| 9 + text.len else 0;
}

pub fn localTimestampExtraLen(
    extended: ?types.ExtendedTimestamp,
    ntfs: ?types.NtfsTimestamp,
) usize {
    return (if (extended) |timestamp|
        5 + 4 * extendedTimestampFieldCount(timestamp)
    else
        0) + (if (ntfs != null) @as(usize, 36) else 0);
}

pub fn centralTimestampExtraLen(
    extended: ?types.ExtendedTimestamp,
    ntfs: ?types.NtfsTimestamp,
) usize {
    return (if (extended) |timestamp|
        if (timestamp.modified != null) @as(usize, 9) else 0
    else
        0) + (if (ntfs != null) @as(usize, 36) else 0);
}

const TimestampLocation = enum { local, central };

fn appendExtendedTimestampExtra(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    timestamp: types.ExtendedTimestamp,
    location: TimestampLocation,
) !void {
    const flags = extendedTimestampFlags(timestamp);
    const payload_len: u16 = if (location == .central)
        5
    else
        @intCast(1 + 4 * extendedTimestampFieldCount(timestamp));
    try appendU16(allocator, out, extended_timestamp_extra_id);
    try appendU16(allocator, out, payload_len);
    try out.append(allocator, flags);
    if (location == .central) {
        try appendExtendedTimestampValue(allocator, out, timestamp.modified.?);
    } else {
        inline for (.{ timestamp.modified, timestamp.accessed, timestamp.created }) |value| {
            if (value) |seconds|
                try appendExtendedTimestampValue(allocator, out, seconds);
        }
    }
}

fn appendExtendedTimestampValue(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    seconds: i64,
) !void {
    try appendU32(allocator, out, @bitCast(@as(i32, @intCast(seconds))));
}

fn appendNtfsTimestampExtra(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    timestamp: types.NtfsTimestamp,
) !void {
    try appendU16(allocator, out, ntfs_timestamp_extra_id);
    try appendU16(allocator, out, 32);
    try appendU32(allocator, out, 0);
    try appendU16(allocator, out, 0x0001);
    try appendU16(allocator, out, 24);
    try appendU64(allocator, out, timestamp.modified);
    try appendU64(allocator, out, timestamp.accessed);
    try appendU64(allocator, out, timestamp.created);
}

fn appendUnicodeExtra(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    field_id: u16,
    raw_text: []const u8,
    unicode_text: []const u8,
) !void {
    try appendU16(allocator, out, field_id);
    try appendU16(allocator, out, @intCast(5 + unicode_text.len));
    try out.append(allocator, 1);
    try appendU32(allocator, out, checksum.crc32Best(raw_text));
    try out.appendSlice(allocator, unicode_text);
}

fn extendedTimestampFlags(timestamp: types.ExtendedTimestamp) u8 {
    return (if (timestamp.modified != null) @as(u8, 1 << 0) else 0) |
        (if (timestamp.accessed != null) @as(u8, 1 << 1) else 0) |
        (if (timestamp.created != null) @as(u8, 1 << 2) else 0);
}

fn extendedTimestampFieldCount(timestamp: types.ExtendedTimestamp) usize {
    return @as(usize, @intFromBool(timestamp.modified != null)) +
        @as(usize, @intFromBool(timestamp.accessed != null)) +
        @as(usize, @intFromBool(timestamp.created != null));
}

fn appendPkwareStrongEncryptionExtra(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    strong: types.PkwareStrongEncryptionInfo,
) !void {
    try appendU16(allocator, out, pkware_strong_extra_id);
    try appendU16(allocator, out, 8);
    try appendU16(allocator, out, 2);
    try appendU16(allocator, out, switch (strong.strength) {
        .aes128 => 0x660e,
        .aes192 => 0x660f,
        .aes256 => 0x6610,
    });
    try appendU16(allocator, out, @intCast(strong.strength.keyLen() * 8));
    try appendU16(allocator, out, 0x0001);
}

fn appendWinZipAesExtra(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    aes: types.WinZipAesInfo,
    actual_method: CompressionMethod,
) !void {
    try appendU16(allocator, out, winzip_aes_extra_id);
    try appendU16(allocator, out, 7);
    try appendU16(allocator, out, @intFromEnum(aes.version));
    try out.appendSlice(allocator, "AE");
    try out.append(allocator, @intFromEnum(aes.strength));
    try appendU16(allocator, out, @intFromEnum(actual_method));
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
    if (method == .aes) return version_51;
    if (method == .deflate64) return if (zip64) version_45 else version_21;
    if (method == .bzip2) return version_46;
    if (method == .lzma or method == .xz or method == .ppmd or isZstandardMethod(method)) return version_63;
    return if (zip64) version_45 else version_20;
}

pub fn requiredVersionForEntry(entry: EncodedEntry) u16 {
    const codec_version = requiredVersion(entry.method, entry.zip64);
    return if (entry.winzip_aes != null or entry.pkware_strong_encryption != null)
        @max(codec_version, version_51)
    else
        codec_version;
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
