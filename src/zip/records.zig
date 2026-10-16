const std = @import("std");
const checksum = @import("../checksum.zig");
const types = @import("types.zig");
const wire = @import("wire.zig");

pub const Error = error{
    InvalidZipArchive,
    UnsupportedZipFeature,
};

const end_of_central_signature: u32 = 0x0605_4b50;
const zip64_end_of_central_signature: u32 = 0x0606_4b50;
const zip64_end_of_central_locator_signature: u32 = 0x0706_4b50;
const end_of_central_len: usize = 22;
const zip64_end_of_central_min_len: usize = 56;
const zip64_locator_len: usize = 20;
const max_comment_len: usize = std.math.maxInt(u16);
const zip64_extra_id: u16 = 0x0001;
const pkware_strong_extra_id: u16 = 0x0017;
const winzip_aes_extra_id: u16 = 0x9901;

pub const ParsedWinZipAes = struct {
    info: types.WinZipAesInfo,
    actual_method: types.CompressionMethod,
};

pub fn parseWinZipAesExtra(extra: []const u8) Error!?ParsedWinZipAes {
    const payload = (try findExtra(extra, winzip_aes_extra_id)) orelse return null;
    if (payload.len != 7 or !std.mem.eql(u8, payload[2..4], "AE"))
        return error.InvalidZipArchive;
    const version: types.WinZipAesVendorVersion = switch (std.mem.readInt(u16, payload[0..2], .little)) {
        1 => .ae1,
        2 => .ae2,
        else => return error.UnsupportedZipFeature,
    };
    const strength: types.WinZipAesStrength = switch (payload[4]) {
        1 => .aes128,
        2 => .aes192,
        3 => .aes256,
        else => return error.UnsupportedZipFeature,
    };
    const actual_method: types.CompressionMethod = @enumFromInt(
        std.mem.readInt(u16, payload[5..7], .little),
    );
    if (actual_method == .aes) return error.InvalidZipArchive;
    return .{
        .info = .{ .version = version, .strength = strength },
        .actual_method = actual_method,
    };
}

pub fn parsePkwareStrongEncryptionExtra(
    extra: []const u8,
) Error!?types.PkwareStrongEncryptionInfo {
    const payload = (try findExtra(extra, pkware_strong_extra_id)) orelse return null;
    if (payload.len != 8) return error.InvalidZipArchive;
    if (std.mem.readInt(u16, payload[0..2], .little) != 2)
        return error.InvalidZipArchive;
    const strength: types.PkwareStrongEncryptionStrength = switch (std.mem.readInt(u16, payload[2..4], .little)) {
        0x660e => .aes128,
        0x660f => .aes192,
        0x6610 => .aes256,
        else => return error.UnsupportedZipFeature,
    };
    if (std.mem.readInt(u16, payload[4..6], .little) != strength.keyLen() * 8)
        return error.InvalidZipArchive;
    const flags = std.mem.readInt(u16, payload[6..8], .little);
    if (flags != 0x0001) return error.UnsupportedZipFeature;
    return .{ .strength = strength };
}

pub const ExtraLocation = enum { local, central };

pub fn parseExtendedTimestampExtra(
    extra: []const u8,
    location: ExtraLocation,
) Error!?types.ExtendedTimestamp {
    const payload = (try findExtra(extra, wire.extended_timestamp_extra_id)) orelse
        return null;
    if (payload.len == 0) return error.InvalidZipArchive;
    const flags = payload[0];
    if (flags & 0xf8 != 0 or flags & 0x07 == 0)
        return error.InvalidZipArchive;
    if (location == .central and flags & (1 << 0) == 0)
        return error.InvalidZipArchive;
    var cursor: usize = 1;
    const result: types.ExtendedTimestamp = .{
        .modified = try readExtendedTimestampValue(
            payload,
            &cursor,
            flags & (1 << 0) != 0,
            location,
        ),
        .accessed = try readExtendedTimestampValue(
            payload,
            &cursor,
            flags & (1 << 1) != 0,
            location,
        ),
        .created = try readExtendedTimestampValue(
            payload,
            &cursor,
            flags & (1 << 2) != 0,
            location,
        ),
    };
    if (cursor != payload.len) return error.InvalidZipArchive;
    return result;
}

fn readExtendedTimestampValue(
    payload: []const u8,
    cursor: *usize,
    present: bool,
    location: ExtraLocation,
) Error!?i64 {
    if (!present) return null;
    if (payload.len - cursor.* < 4) {
        if (location == .central) return null;
        return error.InvalidZipArchive;
    }
    const raw = std.mem.readInt(u32, payload[cursor.*..][0..4], .little);
    cursor.* += 4;
    return @as(i32, @bitCast(raw));
}

pub fn parseNtfsTimestampExtra(extra: []const u8) Error!?types.NtfsTimestamp {
    const payload = (try findExtra(extra, wire.ntfs_timestamp_extra_id)) orelse
        return null;
    if (payload.len < 4) return error.InvalidZipArchive;
    var cursor: usize = 4;
    var result: ?types.NtfsTimestamp = null;
    while (cursor < payload.len) {
        const header_end = try checkedEnd(cursor, 4, payload.len);
        const tag = std.mem.readInt(u16, payload[cursor..][0..2], .little);
        const size: usize = std.mem.readInt(u16, payload[cursor + 2 ..][0..2], .little);
        const attribute_end = try checkedEnd(header_end, size, payload.len);
        if (tag == 0x0001) {
            if (result != null or size != 24) return error.InvalidZipArchive;
            result = .{
                .modified = std.mem.readInt(u64, payload[header_end..][0..8], .little),
                .accessed = std.mem.readInt(u64, payload[header_end + 8 ..][0..8], .little),
                .created = std.mem.readInt(u64, payload[header_end + 16 ..][0..8], .little),
            };
        }
        cursor = attribute_end;
    }
    return result;
}

pub fn parseUnicodePathExtra(
    extra: []const u8,
    raw_name: []const u8,
) Error!?[]const u8 {
    return parseUnicodeExtra(
        extra,
        wire.unicode_path_extra_id,
        raw_name,
        false,
    );
}

pub fn parseUnicodeCommentExtra(
    extra: []const u8,
    raw_comment: []const u8,
) Error!?[]const u8 {
    return parseUnicodeExtra(
        extra,
        wire.unicode_comment_extra_id,
        raw_comment,
        false,
    );
}

fn parseUnicodeExtra(
    extra: []const u8,
    field_id: u16,
    raw_text: []const u8,
    allow_empty: bool,
) Error!?[]const u8 {
    const payload = (try findExtra(extra, field_id)) orelse return null;
    if (payload.len < 5) return error.InvalidZipArchive;
    if (payload[0] != 1) return null;
    const expected_crc = std.mem.readInt(u32, payload[1..5], .little);
    if (expected_crc != checksum.crc32Best(raw_text)) return null;
    const unicode_text = payload[5..];
    if ((!allow_empty and unicode_text.len == 0) or
        !std.unicode.utf8ValidateSlice(unicode_text))
    {
        return error.InvalidZipArchive;
    }
    return unicode_text;
}

pub fn mergeUnicodeText(
    local: ?[]const u8,
    central: ?[]const u8,
) Error!?[]const u8 {
    if (local == null) return central;
    if (central == null) return local;
    if (!std.mem.eql(u8, local.?, central.?)) return error.InvalidZipArchive;
    return local;
}

pub fn mergeExtendedTimestamps(
    local: ?types.ExtendedTimestamp,
    central: ?types.ExtendedTimestamp,
) error{InvalidZipArchive}!?types.ExtendedTimestamp {
    if (local == null) return central;
    if (central == null) return local;
    const local_value = local.?;
    const central_value = central.?;
    inline for (.{ "modified", "accessed", "created" }) |field_name| {
        const central_field = @field(central_value, field_name);
        if (central_field != null and @field(local_value, field_name) != central_field)
            return error.InvalidZipArchive;
    }
    return local_value;
}

pub fn mergeNtfsTimestamps(
    local: ?types.NtfsTimestamp,
    central: ?types.NtfsTimestamp,
) error{InvalidZipArchive}!?types.NtfsTimestamp {
    if (local == null) return central;
    if (central == null) return local;
    if (!std.meta.eql(local.?, central.?)) return error.InvalidZipArchive;
    return local;
}

pub const Directory = struct {
    entry_count: usize,
    central_directory_offset: usize,
    central_directory_size: usize,
    comment: []const u8,
    zip64: bool,
};

pub fn parseDirectory(bytes: []const u8) Error!Directory {
    const eocd_offset = findEndOfCentralDirectory(bytes) orelse return error.InvalidZipArchive;
    const disk_number = try readU16(bytes, eocd_offset + 4);
    const central_disk = try readU16(bytes, eocd_offset + 6);
    const entries_on_disk = try readU16(bytes, eocd_offset + 8);
    const entry_count = try readU16(bytes, eocd_offset + 10);
    const central_size = try readU32(bytes, eocd_offset + 12);
    const central_offset = try readU32(bytes, eocd_offset + 16);
    const comment_len: usize = try readU16(bytes, eocd_offset + 20);
    const comment_start = eocd_offset + end_of_central_len;
    const comment_end = try checkedEnd(comment_start, comment_len, bytes.len);
    if (comment_end != bytes.len) return error.InvalidZipArchive;

    const has_zip64_sentinel = disk_number == std.math.maxInt(u16) or
        central_disk == std.math.maxInt(u16) or
        entries_on_disk == std.math.maxInt(u16) or
        entry_count == std.math.maxInt(u16) or
        central_size == std.math.maxInt(u32) or
        central_offset == std.math.maxInt(u32);

    if (!has_zip64_sentinel) {
        if (disk_number != 0 or central_disk != 0 or entries_on_disk != entry_count)
            return error.UnsupportedZipFeature;
        return finishDirectory(
            bytes,
            entry_count,
            central_offset,
            central_size,
            eocd_offset,
            bytes[comment_start..comment_end],
            false,
        );
    }

    if ((disk_number != 0 and disk_number != std.math.maxInt(u16)) or
        (central_disk != 0 and central_disk != std.math.maxInt(u16)))
        return error.UnsupportedZipFeature;
    if (eocd_offset < zip64_locator_len) return error.InvalidZipArchive;
    const locator_offset = eocd_offset - zip64_locator_len;
    if (try readU32(bytes, locator_offset) != zip64_end_of_central_locator_signature)
        return error.InvalidZipArchive;
    if (try readU32(bytes, locator_offset + 4) != 0 or
        try readU32(bytes, locator_offset + 16) != 1)
        return error.UnsupportedZipFeature;

    const zip64_offset = try u64ToUsize(try readU64(bytes, locator_offset + 8));
    _ = try checkedEnd(zip64_offset, zip64_end_of_central_min_len, locator_offset);
    if (try readU32(bytes, zip64_offset) != zip64_end_of_central_signature)
        return error.InvalidZipArchive;
    const record_payload_len = try u64ToUsize(try readU64(bytes, zip64_offset + 4));
    if (record_payload_len < 44) return error.InvalidZipArchive;
    const record_end = try checkedEnd(zip64_offset, try checkedAdd(12, record_payload_len), locator_offset);
    if (record_end != locator_offset) return error.InvalidZipArchive;
    if (try readU16(bytes, zip64_offset + 14) < 45) return error.InvalidZipArchive;

    const zip64_disk = try readU32(bytes, zip64_offset + 16);
    const zip64_central_disk = try readU32(bytes, zip64_offset + 20);
    const zip64_entries_on_disk = try readU64(bytes, zip64_offset + 24);
    const zip64_entry_count = try readU64(bytes, zip64_offset + 32);
    const zip64_central_size = try readU64(bytes, zip64_offset + 40);
    const zip64_central_offset = try readU64(bytes, zip64_offset + 48);
    if (zip64_disk != 0 or zip64_central_disk != 0 or
        zip64_entries_on_disk != zip64_entry_count)
        return error.UnsupportedZipFeature;

    try validateLegacyU16(entries_on_disk, zip64_entries_on_disk);
    try validateLegacyU16(entry_count, zip64_entry_count);
    try validateLegacyU32(central_size, zip64_central_size);
    try validateLegacyU32(central_offset, zip64_central_offset);

    return finishDirectory(
        bytes,
        try u64ToUsize(zip64_entry_count),
        try u64ToUsize(zip64_central_offset),
        try u64ToUsize(zip64_central_size),
        zip64_offset,
        bytes[comment_start..comment_end],
        true,
    );
}

fn finishDirectory(
    bytes: []const u8,
    entry_count: usize,
    central_offset: usize,
    central_size: usize,
    directory_limit: usize,
    comment: []const u8,
    zip64: bool,
) Error!Directory {
    const central_end = try checkedEnd(central_offset, central_size, bytes.len);
    if (central_end > directory_limit) return error.InvalidZipArchive;
    return .{
        .entry_count = entry_count,
        .central_directory_offset = central_offset,
        .central_directory_size = central_size,
        .comment = comment,
        .zip64 = zip64,
    };
}

fn validateLegacyU16(value: u16, actual: u64) Error!void {
    if (value != std.math.maxInt(u16) and @as(u64, value) != actual)
        return error.InvalidZipArchive;
}

fn validateLegacyU32(value: u32, actual: u64) Error!void {
    if (value != std.math.maxInt(u32) and @as(u64, value) != actual)
        return error.InvalidZipArchive;
}

pub const CentralEntryValues = struct {
    compressed_size: usize,
    uncompressed_size: usize,
    local_header_offset: usize,
    zip64: bool,
};

pub fn resolveCentralEntry(
    extra: []const u8,
    compressed_size: u32,
    uncompressed_size: u32,
    local_header_offset: u32,
    disk_start: u16,
) Error!CentralEntryValues {
    const needs_uncompressed = uncompressed_size == std.math.maxInt(u32);
    const needs_compressed = compressed_size == std.math.maxInt(u32);
    const needs_offset = local_header_offset == std.math.maxInt(u32);
    const needs_disk = disk_start == std.math.maxInt(u16);
    const needs_zip64 = needs_uncompressed or needs_compressed or needs_offset or needs_disk;
    if (!needs_zip64) {
        if (disk_start != 0) return error.UnsupportedZipFeature;
        return .{
            .compressed_size = compressed_size,
            .uncompressed_size = uncompressed_size,
            .local_header_offset = local_header_offset,
            .zip64 = false,
        };
    }

    const payload = (try findZip64Extra(extra)) orelse return error.InvalidZipArchive;
    var cursor: usize = 0;
    const resolved_uncompressed = if (needs_uncompressed)
        try readPayloadU64(payload, &cursor)
    else
        uncompressed_size;
    const resolved_compressed = if (needs_compressed)
        try readPayloadU64(payload, &cursor)
    else
        compressed_size;
    const resolved_offset = if (needs_offset)
        try readPayloadU64(payload, &cursor)
    else
        local_header_offset;
    const resolved_disk = if (needs_disk)
        try readPayloadU32(payload, &cursor)
    else
        disk_start;
    if (resolved_disk != 0) return error.UnsupportedZipFeature;
    return .{
        .compressed_size = try u64ToUsize(resolved_compressed),
        .uncompressed_size = try u64ToUsize(resolved_uncompressed),
        .local_header_offset = try u64ToUsize(resolved_offset),
        .zip64 = true,
    };
}

pub const LocalSizes = struct {
    compressed_size: usize,
    uncompressed_size: usize,
};

pub fn resolveLocalSizes(extra: []const u8, compressed_size: u32, uncompressed_size: u32) Error!LocalSizes {
    const needs_uncompressed = uncompressed_size == std.math.maxInt(u32);
    const needs_compressed = compressed_size == std.math.maxInt(u32);
    if (!needs_uncompressed and !needs_compressed) return .{
        .compressed_size = compressed_size,
        .uncompressed_size = uncompressed_size,
    };

    const payload = (try findZip64Extra(extra)) orelse return error.InvalidZipArchive;
    var cursor: usize = 0;
    const resolved_uncompressed = if (needs_uncompressed)
        try readPayloadU64(payload, &cursor)
    else
        uncompressed_size;
    const resolved_compressed = if (needs_compressed)
        try readPayloadU64(payload, &cursor)
    else
        compressed_size;
    return .{
        .compressed_size = try u64ToUsize(resolved_compressed),
        .uncompressed_size = try u64ToUsize(resolved_uncompressed),
    };
}

fn findZip64Extra(extra: []const u8) Error!?[]const u8 {
    return findExtra(extra, zip64_extra_id);
}

pub fn findExtra(extra: []const u8, wanted_id: u16) Error!?[]const u8 {
    var offset: usize = 0;
    var result: ?[]const u8 = null;
    while (offset < extra.len) {
        const header_end = try checkedEnd(offset, 4, extra.len);
        const id = std.mem.readInt(u16, extra[offset..][0..2], .little);
        const size: usize = std.mem.readInt(u16, extra[offset + 2 ..][0..2], .little);
        const payload_end = try checkedEnd(header_end, size, extra.len);
        if (id == wanted_id) {
            if (result != null) return error.InvalidZipArchive;
            result = extra[header_end..payload_end];
        }
        offset = payload_end;
    }
    return result;
}

fn readPayloadU32(payload: []const u8, cursor: *usize) Error!u32 {
    const end = try checkedEnd(cursor.*, 4, payload.len);
    const value = std.mem.readInt(u32, payload[cursor.*..][0..4], .little);
    cursor.* = end;
    return value;
}

fn readPayloadU64(payload: []const u8, cursor: *usize) Error!u64 {
    const end = try checkedEnd(cursor.*, 8, payload.len);
    const value = std.mem.readInt(u64, payload[cursor.*..][0..8], .little);
    cursor.* = end;
    return value;
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

fn u64ToUsize(value: u64) Error!usize {
    return std.math.cast(usize, value) orelse error.UnsupportedZipFeature;
}

fn readU16(bytes: []const u8, offset: usize) Error!u16 {
    _ = try checkedEnd(offset, 2, bytes.len);
    return std.mem.readInt(u16, bytes[offset..][0..2], .little);
}

fn readU32(bytes: []const u8, offset: usize) Error!u32 {
    _ = try checkedEnd(offset, 4, bytes.len);
    return std.mem.readInt(u32, bytes[offset..][0..4], .little);
}

fn readU64(bytes: []const u8, offset: usize) Error!u64 {
    _ = try checkedEnd(offset, 8, bytes.len);
    return std.mem.readInt(u64, bytes[offset..][0..8], .little);
}

fn checkedAdd(a: usize, b: usize) Error!usize {
    return std.math.add(usize, a, b) catch error.InvalidZipArchive;
}

fn checkedEnd(start: usize, len: usize, limit: usize) Error!usize {
    const end = try checkedAdd(start, len);
    if (end > limit) return error.InvalidZipArchive;
    return end;
}

test "ZIP64 extra fields resolve ordered central and local sentinel values" {
    var extra: [28]u8 = @splat(0);
    std.mem.writeInt(u16, extra[0..2], zip64_extra_id, .little);
    std.mem.writeInt(u16, extra[2..4], 24, .little);
    std.mem.writeInt(u64, extra[4..12], 123, .little);
    std.mem.writeInt(u64, extra[12..20], 77, .little);
    std.mem.writeInt(u64, extra[20..28], 9, .little);

    const central = try resolveCentralEntry(
        &extra,
        std.math.maxInt(u32),
        std.math.maxInt(u32),
        std.math.maxInt(u32),
        0,
    );
    try std.testing.expect(central.zip64);
    try std.testing.expectEqual(@as(usize, 77), central.compressed_size);
    try std.testing.expectEqual(@as(usize, 123), central.uncompressed_size);
    try std.testing.expectEqual(@as(usize, 9), central.local_header_offset);

    const local = try resolveLocalSizes(&extra, std.math.maxInt(u32), std.math.maxInt(u32));
    try std.testing.expectEqual(@as(usize, 77), local.compressed_size);
    try std.testing.expectEqual(@as(usize, 123), local.uncompressed_size);
}

test "ZIP64 extra field parser rejects missing truncated and duplicate records" {
    try std.testing.expectError(
        error.InvalidZipArchive,
        resolveCentralEntry(&.{}, std.math.maxInt(u32), 1, 2, 0),
    );
    try std.testing.expectError(
        error.InvalidZipArchive,
        resolveCentralEntry(&.{ 1, 0, 8, 0, 0 }, std.math.maxInt(u32), 1, 2, 0),
    );
    try std.testing.expectError(
        error.InvalidZipArchive,
        resolveCentralEntry(&.{ 1, 0, 0, 0, 1, 0, 0, 0 }, std.math.maxInt(u32), 1, 2, 0),
    );
}
