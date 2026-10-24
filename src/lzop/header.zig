const std = @import("std");
const checksum = @import("../checksum.zig");
const core = @import("../core.zig");

pub const Error = core.Error || error{
    InvalidLzopHeader,
    UnsupportedLzopFeature,
};

pub const magic = [_]u8{ 0x89, 'L', 'Z', 'O', 0, '\r', '\n', 0x1a, '\n' };
pub const current_version: u16 = 0x1040;
pub const current_lzo_version: u16 = 0x20a0;

pub const Flag = struct {
    pub const adler32_data: u32 = 0x0000_0001;
    pub const adler32_compressed: u32 = 0x0000_0002;
    pub const stdin: u32 = 0x0000_0004;
    pub const stdout: u32 = 0x0000_0008;
    pub const name_default: u32 = 0x0000_0010;
    pub const dosish: u32 = 0x0000_0020;
    pub const extra_field: u32 = 0x0000_0040;
    pub const header_gmt_difference: u32 = 0x0000_0080;
    pub const crc32_data: u32 = 0x0000_0100;
    pub const crc32_compressed: u32 = 0x0000_0200;
    pub const multipart: u32 = 0x0000_0400;
    pub const filter: u32 = 0x0000_0800;
    pub const header_crc32: u32 = 0x0000_1000;
    pub const path: u32 = 0x0000_2000;
    pub const known: u32 = 0xfff0_3fff;
};

pub const Method = enum(u8) {
    lzo1x_1 = 1,
    lzo1x_1_15 = 2,
    lzo1x_999 = 3,
};

pub const Header = struct {
    version: u16,
    library_version: u16,
    version_needed: u16,
    method: Method,
    level: u8,
    flags: u32,
    filter: ?u32,
    mode: u32,
    modified_time: u64,
    filename: []const u8,
    encoded_size: usize,
};

pub const WriteOptions = struct {
    flags: u32,
    filename: []const u8,
    mode: u32,
    modified_time: u64,
};

pub const SizeProbe = union(enum) {
    need_more: usize,
    complete: usize,
};

/// Report the exact encoded header length once enough structural bytes are
/// available. `need_more` is the next total prefix length required, allowing
/// incremental callers to stop before consuming the first block header.
pub fn probeEncodedSize(input: []const u8) Error!SizeProbe {
    const magic_prefix_len = @min(input.len, magic.len);
    if (!std.mem.eql(u8, input[0..magic_prefix_len], magic[0..magic_prefix_len]))
        return error.InvalidMagic;
    if (input.len < magic.len) return .{ .need_more = magic.len };

    var offset: usize = magic.len;
    if (try needBytes(input.len, offset, 2)) |needed| return .{ .need_more = needed };
    const version = std.mem.readInt(u16, input[offset..][0..2], .big);
    offset += 2;
    if (version < 0x0900) return error.InvalidLzopHeader;

    if (try needBytes(input.len, offset, 2)) |needed| return .{ .need_more = needed };
    offset += 2; // LZO library version.
    if (version >= 0x0940) {
        if (try needBytes(input.len, offset, 2)) |needed| return .{ .need_more = needed };
        const version_needed = std.mem.readInt(u16, input[offset..][0..2], .big);
        if (version_needed < 0x0900) return error.InvalidLzopHeader;
        if (version_needed > current_version) return error.UnsupportedVersion;
        offset += 2;
    }

    if (try needBytes(input.len, offset, 1)) |needed| return .{ .need_more = needed };
    offset += 1; // Method.
    if (version >= 0x0940) {
        if (try needBytes(input.len, offset, 1)) |needed| return .{ .need_more = needed };
        offset += 1; // Level.
    }

    if (try needBytes(input.len, offset, 4)) |needed| return .{ .need_more = needed };
    const flags = std.mem.readInt(u32, input[offset..][0..4], .big);
    if (flags & ~Flag.known != 0) return error.InvalidLzopHeader;
    if (flags & Flag.adler32_compressed != 0 and flags & Flag.adler32_data == 0)
        return error.InvalidLzopHeader;
    if (flags & Flag.crc32_compressed != 0 and flags & Flag.crc32_data == 0)
        return error.InvalidLzopHeader;
    offset += 4;
    if (flags & Flag.filter != 0) {
        if (try needBytes(input.len, offset, 4)) |needed| return .{ .need_more = needed };
        offset += 4;
    }

    if (try needBytes(input.len, offset, 8)) |needed| return .{ .need_more = needed };
    offset += 8; // Mode and low modified time.
    if (version >= 0x0940) {
        if (try needBytes(input.len, offset, 4)) |needed| return .{ .need_more = needed };
        offset += 4; // High modified time.
    }

    if (try needBytes(input.len, offset, 1)) |needed| return .{ .need_more = needed };
    const name_len = input[offset];
    offset += 1;
    if (try needBytes(input.len, offset, name_len)) |needed| return .{ .need_more = needed };
    offset += name_len;
    if (try needBytes(input.len, offset, 4)) |needed| return .{ .need_more = needed };
    offset += 4; // Header checksum.

    if (flags & Flag.extra_field != 0) {
        if (try needBytes(input.len, offset, 4)) |needed| return .{ .need_more = needed };
        const extra_len = std.mem.readInt(u32, input[offset..][0..4], .big);
        offset += 4;
        if (try needBytes(input.len, offset, extra_len)) |needed| return .{ .need_more = needed };
        offset += extra_len;
        if (try needBytes(input.len, offset, 4)) |needed| return .{ .need_more = needed };
        offset += 4; // Extra-field checksum.
    }
    return .{ .complete = offset };
}

fn needBytes(input_len: usize, offset: usize, count: anytype) Error!?usize {
    const needed = std.math.add(usize, offset, @intCast(count)) catch
        return error.IntegerOverflow;
    return if (input_len < needed) needed else null;
}

pub fn parse(input: []const u8) Error!Header {
    if (input.len < magic.len) return error.TruncatedFrame;
    if (!std.mem.eql(u8, input[0..magic.len], &magic)) return error.InvalidMagic;
    var offset = magic.len;
    const checksum_start = offset;
    const version = try readU16(input, &offset);
    if (version < 0x0900) return error.InvalidLzopHeader;
    const library_version = try readU16(input, &offset);
    const version_needed = if (version >= 0x0940) try readU16(input, &offset) else 0x0900;
    if (version_needed < 0x0900) return error.InvalidLzopHeader;
    if (version_needed > current_version) return error.UnsupportedVersion;

    const method_value = try readU8(input, &offset);
    const method = std.enums.fromInt(Method, method_value) orelse
        return error.UnsupportedLzopFeature;
    var level = if (version >= 0x0940) try readU8(input, &offset) else 0;
    if (level == 0) level = switch (method) {
        .lzo1x_1 => 3,
        .lzo1x_1_15 => 1,
        .lzo1x_999 => 9,
    };
    if (level < 1 or level > 9) return error.InvalidLzopHeader;

    const flags = try readU32(input, &offset);
    if (flags & ~Flag.known != 0) return error.InvalidLzopHeader;
    if (flags & Flag.adler32_compressed != 0 and flags & Flag.adler32_data == 0)
        return error.InvalidLzopHeader;
    if (flags & Flag.crc32_compressed != 0 and flags & Flag.crc32_data == 0)
        return error.InvalidLzopHeader;
    const filter = if (flags & Flag.filter != 0) try readU32(input, &offset) else null;
    if (filter) |value| if (value > 16) return error.UnsupportedLzopFeature;

    const mode = try readU32(input, &offset);
    const modified_low = try readU32(input, &offset);
    const modified_high = if (version >= 0x0940) try readU32(input, &offset) else 0;
    const name_len = try readU8(input, &offset);
    const name_end = std.math.add(usize, offset, name_len) catch
        return error.IntegerOverflow;
    if (name_end > input.len) return error.TruncatedFrame;
    const filename = input[offset..name_end];
    offset = name_end;

    const checksum_end = offset;
    const expected_header_checksum = try readU32(input, &offset);
    const actual_header_checksum = if (flags & Flag.header_crc32 != 0)
        checksum.crc32Best(input[checksum_start..checksum_end])
    else
        checksum.adler32(input[checksum_start..checksum_end]);
    if (actual_header_checksum != expected_header_checksum) return error.ChecksumMismatch;

    if (flags & Flag.extra_field != 0) {
        const extra_start = offset;
        const extra_len = try readU32(input, &offset);
        const extra_end = std.math.add(usize, offset, extra_len) catch
            return error.IntegerOverflow;
        if (extra_end > input.len) return error.TruncatedFrame;
        offset = extra_end;
        const expected_extra_checksum = try readU32(input, &offset);
        const actual_extra_checksum = if (flags & Flag.header_crc32 != 0)
            checksum.crc32Best(input[extra_start..extra_end])
        else
            checksum.adler32(input[extra_start..extra_end]);
        if (actual_extra_checksum != expected_extra_checksum) return error.ChecksumMismatch;
    }

    return .{
        .version = version,
        .library_version = library_version,
        .version_needed = version_needed,
        .method = method,
        .level = level,
        .flags = flags,
        .filter = filter,
        .mode = mode,
        .modified_time = @as(u64, modified_low) | (@as(u64, modified_high) << 32),
        .filename = filename,
        .encoded_size = offset,
    };
}

pub fn append(allocator: std.mem.Allocator, output: *std.ArrayList(u8), options: WriteOptions) !void {
    if (options.filename.len > std.math.maxInt(u8)) return error.InvalidLzopHeader;
    if (options.flags & ~Flag.known != 0 or options.flags & Flag.filter != 0 or
        options.flags & Flag.extra_field != 0)
        return error.UnsupportedLzopFeature;

    try output.appendSlice(allocator, &magic);
    const checksum_start = output.items.len;
    try appendU16(allocator, output, current_version);
    try appendU16(allocator, output, current_lzo_version);
    try appendU16(allocator, output, if (options.flags & Flag.header_crc32 != 0) 0x1001 else 0x0940);
    try output.append(allocator, @intFromEnum(Method.lzo1x_1));
    try output.append(allocator, 5);
    try appendU32(allocator, output, options.flags);
    try appendU32(allocator, output, options.mode);
    try appendU32(allocator, output, @truncate(options.modified_time));
    try appendU32(allocator, output, @truncate(options.modified_time >> 32));
    try output.append(allocator, @intCast(options.filename.len));
    try output.appendSlice(allocator, options.filename);
    const header_checksum = if (options.flags & Flag.header_crc32 != 0)
        checksum.crc32Best(output.items[checksum_start..])
    else
        checksum.adler32(output.items[checksum_start..]);
    try appendU32(allocator, output, header_checksum);
}

fn readU8(input: []const u8, offset: *usize) Error!u8 {
    if (offset.* >= input.len) return error.TruncatedFrame;
    const value = input[offset.*];
    offset.* += 1;
    return value;
}

fn readU16(input: []const u8, offset: *usize) Error!u16 {
    if (input.len -| offset.* < 2) return error.TruncatedFrame;
    const value = std.mem.readInt(u16, input[offset.*..][0..2], .big);
    offset.* += 2;
    return value;
}

pub fn readU32(input: []const u8, offset: *usize) Error!u32 {
    if (input.len -| offset.* < 4) return error.TruncatedFrame;
    const value = std.mem.readInt(u32, input[offset.*..][0..4], .big);
    offset.* += 4;
    return value;
}

pub fn appendU32(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: u32) !void {
    var bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &bytes, value, .big);
    try output.appendSlice(allocator, &bytes);
}

fn appendU16(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: u16) !void {
    var bytes: [2]u8 = undefined;
    std.mem.writeInt(u16, &bytes, value, .big);
    try output.appendSlice(allocator, &bytes);
}

test "lzop header round trips deterministic metadata and checksums" {
    var bytes: std.ArrayList(u8) = .empty;
    defer bytes.deinit(std.testing.allocator);
    try append(std.testing.allocator, &bytes, .{
        .flags = Flag.crc32_data | Flag.header_crc32,
        .filename = "payload.bin",
        .mode = 0o100640,
        .modified_time = 0x1020_3040_5060_7080,
    });
    const parsed = try parse(bytes.items);
    try std.testing.expectEqual(Method.lzo1x_1, parsed.method);
    try std.testing.expectEqual(@as(u8, 5), parsed.level);
    try std.testing.expectEqual(@as(u32, 0o100640), parsed.mode);
    try std.testing.expectEqual(@as(u64, 0x1020_3040_5060_7080), parsed.modified_time);
    try std.testing.expectEqualStrings("payload.bin", parsed.filename);
    try std.testing.expectEqual(bytes.items.len, parsed.encoded_size);

    bytes.items[10] ^= 1;
    try std.testing.expectError(error.ChecksumMismatch, parse(bytes.items));
}

test "lzop header accepts pre-0.940 field layout" {
    var bytes: std.ArrayList(u8) = .empty;
    defer bytes.deinit(std.testing.allocator);
    try bytes.appendSlice(std.testing.allocator, &magic);
    const checksum_start = bytes.items.len;
    try appendU16(std.testing.allocator, &bytes, 0x0930);
    try appendU16(std.testing.allocator, &bytes, 0x1030);
    try bytes.append(std.testing.allocator, @intFromEnum(Method.lzo1x_1));
    try appendU32(std.testing.allocator, &bytes, Flag.adler32_data);
    try appendU32(std.testing.allocator, &bytes, 0o100600);
    try appendU32(std.testing.allocator, &bytes, 1234);
    try bytes.append(std.testing.allocator, 0);
    try appendU32(std.testing.allocator, &bytes, checksum.adler32(bytes.items[checksum_start..]));

    const parsed = try parse(bytes.items);
    try std.testing.expectEqual(@as(u16, 0x0900), parsed.version_needed);
    try std.testing.expectEqual(@as(u8, 3), parsed.level);
    try std.testing.expectEqual(@as(u64, 1234), parsed.modified_time);
    try std.testing.expectEqual(bytes.items.len, parsed.encoded_size);
}
