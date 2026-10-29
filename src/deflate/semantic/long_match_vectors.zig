//! Independent long-code vectors accepted by zlib and image-png.
const std = @import("std");
pub const encoded = @embedFile("testdata/long-match.deflate");
pub const history_len = 32768;
pub const output_len = 33292;
pub const symbol_stream = [_]u8{ 0xef, 0x7b, 0xdf, 0xff, 0xef, 0xff, 0xff, 0xff, 0xff, 0x7d, 0xef, 0xfb, 0xff, 0xfd, 0xff, 0xff, 0xff, 0xbf, 0x6f };
pub const literal_lengths: [286]u4 = blk: {
    var lengths: [286]u4 = @splat(0);
    const symbols = [_]usize{ 0, 1, 256, 2, 65, 66, 3, 4, 5, 6, 7, 8, 9, 284, 10 };
    for (symbols, 0..) |symbol, index| lengths[symbol] = @intCast(@min(index + 1, 14));
    break :blk lengths;
};
pub const distance_lengths: [30]u4 = blk: {
    var lengths: [30]u4 = @splat(0);
    for (0..14) |index| lengths[index] = @intCast(index + 1);
    lengths[28] = 15;
    lengths[29] = 15;
    break :blk lengths;
};
pub fn expectedAlloc(allocator: std.mem.Allocator) ![]u8 {
    const output = try allocator.alloc(u8, output_len);
    output[0] = 0;
    for (1..history_len) |index| output[index] = @truncate(index * 19 + index / 17);
    var position: usize = history_len;
    for (0..2) |_| {
        @memcpy(output[position..][0..4], "ABAB");
        position += 4;
        @memcpy(output[position..][0..257], output[position - history_len ..][0..257]);
        position += 257;
    }
    @memcpy(output[position..][0..2], "AB");
    return output;
}
