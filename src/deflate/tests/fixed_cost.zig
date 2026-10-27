const std = @import("std");
const BitWriter = @import("../../bitstream.zig").BitWriter;

pub fn verify(comptime Token: type, comptime fixedCost: anytype, comptime writeFixed: anytype) !void {
    // Check symbol emission directly; history validity is covered by round trips.
    for (3..259) |length| {
        for ([_]usize{ 1, 4, 5, 8, 9, 16, 17, 32768 }) |distance| {
            const tokens = [_]Token{
                .{ .literal = 0 },
                .{ .match = .{ .length = @intCast(length), .distance = @intCast(distance) } },
            };
            var writer = BitWriter{};
            defer writer.deinit(std.testing.allocator);
            try writeFixed(std.testing.allocator, &writer, &tokens, true);
            const actual = writer.bytes.items.len * 8 + writer.bit_index;
            try std.testing.expectEqual(actual, fixedCost(&tokens));
        }
    }
}
