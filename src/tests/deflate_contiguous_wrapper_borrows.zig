//! Public package wrapper aliases reject unread payload overwrite before decode.
const std = @import("std");

pub fn contracts(comptime R: type) !void {
    const raw = [_]u8{ 0, 3, 0, 0xfc, 0xff, 'a', 'b', 'c', 1, 3, 0, 0xfc, 0xff, 'd', 'e', 'f' };
    const z = [_]u8{ 0x78, 1 } ++ raw ++ [_]u8{ 8, 0x1e, 2, 0x56 };
    const g = [_]u8{ 0x1f, 0x8b, 8, 0, 0, 0, 0, 0, 0, 3 } ++ raw ++ [_]u8{ 0xef, 0x39, 0x8e, 0x4b, 6, 0, 0, 0 };
    var output: [6]u8 = undefined;
    var backing: [64]u8 = @splat(0xa5);
    @memcpy(backing[0..z.len], &z);
    const before_z = backing;
    try std.testing.expectError(error.InvalidBlockPlan, R.decodeZlib(backing[0..z.len], backing[15..21]));
    try std.testing.expectEqualSlices(u8, &before_z, &backing);
    try std.testing.expectError(error.InvalidBlockPlan, R.decodeZlibWithOptions(backing[0..z.len], backing[15..21], .{ .ignore_adler = true }));
    try std.testing.expectEqualSlices(u8, &before_z, &backing);
    try std.testing.expectEqual(@as(usize, 6), try R.decodeZlib(backing[0..z.len], &output));
    try std.testing.expectEqualSlices(u8, "abcdef", &output);
    @memcpy(backing[0..g.len], &g);
    const before_g = backing;
    try std.testing.expectError(error.InvalidBlockPlan, R.decodeGzip(backing[0..g.len], backing[23..29]));
    try std.testing.expectEqualSlices(u8, &before_g, &backing);
    try std.testing.expectError(error.InvalidBlockPlan, R.decodeGzipWithOptions(backing[0..g.len], backing[23..29], .{ .ignore_crc32 = true }));
    try std.testing.expectEqualSlices(u8, &before_g, &backing);
    try std.testing.expectEqual(@as(usize, 6), try R.decodeGzip(backing[0..g.len], &output));
    try std.testing.expectEqualSlices(u8, "abcdef", &output);
}
