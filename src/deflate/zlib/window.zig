//! RFC 1950 framing geometry. Generic DEFLATE parser options remain separate.
const std = @import("std");
const checksum = @import("../../checksum.zig");

pub const Error = error{InvalidZlibWindow};
pub const default_bits: u8 = 15;
pub const min_bits: u8 = 9;
pub const max_bits: u8 = 15;

pub fn validate(bits: u8) Error!void {
    if (bits < min_bits or bits > max_bits) return error.InvalidZlibWindow;
}

pub fn windowLen(bits: u8) Error!usize {
    try validate(bits);
    return @as(usize, 1) << @as(std.math.Log2Int(usize), @intCast(bits));
}

pub fn headerLen(dictionary: ?[]const u8) usize {
    return if (dictionary == null) 2 else 6;
}

/// FLEVEL retains the library's established zero hint. DICTID covers the full
/// caller dictionary, independently of the suffix retained by a match finder.
pub fn writeHeader(output: []u8, dictionary: ?[]const u8, bits: u8) (Error || error{OutputTooSmall})!void {
    try validate(bits);
    if (output.len < headerLen(dictionary)) return error.OutputTooSmall;
    const cmf: u8 = ((bits - 8) << 4) | 8;
    const base_flg: u8 = if (dictionary == null) 0 else 0x20;
    const pair = (@as(u16, cmf) << 8) | base_flg;
    const fcheck: u8 = @intCast((31 - pair % 31) % 31);
    output[0] = cmf;
    output[1] = base_flg | fcheck;
    if (dictionary) |dict|
        std.mem.writeInt(u32, output[2..][0..4], checksum.adler32(dict), .big);
}

test "zlib window headers preserve default bytes and encode every declared cap" {
    var header: [6]u8 = undefined;
    for (min_bits..max_bits + 1) |wide| {
        const bits: u8 = @intCast(wide);
        try writeHeader(&header, null, bits);
        try std.testing.expectEqual(bits - 8, header[0] >> 4);
        try std.testing.expectEqual(@as(u16, 0), std.mem.readInt(u16, header[0..2], .big) % 31);
        try std.testing.expectEqual(@as(usize, 1) << @as(std.math.Log2Int(usize), @intCast(bits)), try windowLen(bits));
        try writeHeader(&header, "dictionary", bits);
        try std.testing.expect(header[1] & 0x20 != 0);
        try std.testing.expectEqual(@as(u16, 0), std.mem.readInt(u16, header[0..2], .big) % 31);
        try std.testing.expectEqual(checksum.adler32("dictionary"), std.mem.readInt(u32, header[2..6], .big));
    }
    try writeHeader(&header, null, default_bits);
    try std.testing.expectEqualSlices(u8, &.{ 0x78, 0x01 }, header[0..2]);
    try writeHeader(&header, "", default_bits);
    try std.testing.expectEqualSlices(u8, &.{ 0x78, 0x20, 0, 0, 0, 1 }, &header);
    for ([_]u8{ 0, 8, 16, 255 }) |bits| {
        header = @splat(0xa5);
        try std.testing.expectError(error.InvalidZlibWindow, writeHeader(&header, "dict", bits));
        try std.testing.expectEqualSlices(u8, &@as([6]u8, @splat(0xa5)), &header);
    }
}
