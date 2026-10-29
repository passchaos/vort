//! Match-field staging shared by the linear and sink semantic decoders.
const std = @import("std");
const bitstream = @import("../../bitstream.zig");

pub inline fn distanceBudget(comptime rle1: bool, comptime single: bool, decoder: anytype) usize {
    if (comptime rle1) return 1;
    if (comptime single)
        return (decoder.single_distance & 0x3f) + ((decoder.single_distance >> 8) & 0x3f);
    return @as(usize, decoder.compact_distance.max_bits) + 13;
}

/// False selects the checked tail reader without consuming the length code.
/// A refill may stage bytes before selecting the tail; the logical cursor is
/// unchanged. The fast loop must retain eight input bytes for its next refill.
pub inline fn stage(input: []const u8, byte_index: *usize, buffer: *u64, count: *usize, required: usize) bool {
    std.debug.assert(required <= 48);
    if (count.* >= required) return true;
    if (input.len - byte_index.* < 8) return false;
    const bytes = (63 - count.*) / 8;
    buffer.* |= std.mem.readInt(u64, input[byte_index.*..][0..8], .little) << @intCast(count.*);
    count.* += bytes * 8;
    byte_index.* += bytes;
    return input.len - byte_index.* >= 8;
}

test "semantic match staging preserves logical bits and both input tail boundaries" {
    const input = [_]u8{ 0xa5, 0x3c, 0x57, 0x9c, 0x82, 0xe1, 0x44, 0x16, 0x7a, 0xc3, 0x25, 0xf0, 0xb9, 0x61, 0x0d, 0x48, 0x39, 0x80, 0xfe, 0x62, 0x41, 0x72, 0xcc, 0x5b };
    for ([_]usize{ 16, 24 }) |length| {
        var byte_index: usize = 7;
        var count: usize = 34;
        var buffer = std.mem.readInt(u64, input[0..8], .little) >> 22;
        var checked = bitstream.BitReader.init(input[0..length]);
        try checked.skipBits(22);
        try std.testing.expectEqual(length == 24, stage(input[0..length], &byte_index, &buffer, &count, 47));
        try std.testing.expectEqual(@as(usize, 22), byte_index * 8 - count);
        try std.testing.expectEqual(try checked.readBits(u64, 47), buffer & ((@as(u64, 1) << 47) - 1));
    }
    var byte_index: usize = 0;
    var count: usize = 0;
    var buffer: u64 = 0;
    try std.testing.expect(!stage(input[0..7], &byte_index, &buffer, &count, 47));
    try std.testing.expectEqual(@as(usize, 0), byte_index);
    try std.testing.expectEqual(@as(usize, 0), count);
    try std.testing.expectEqual(@as(u64, 0), buffer);
}
