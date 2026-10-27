const std = @import("std");

pub fn compare(comptime Options: type, comptime Scratch: type, comptime Token: type, comptime parse: anytype) !void {
    var control = Scratch{};
    defer control.deinit(std.testing.allocator);
    var actual = Scratch{};
    defer actual.deinit(std.testing.allocator);
    var input: [513]u8 = undefined;
    var state: u32 = 0x515904ec;
    for (0..4) |kind| {
        for (&input, 0..) |*byte, pos| {
            state = state *% 1664525 +% 1013904223;
            byte.* = switch (kind) {
                0 => 0,
                1 => @intCast(pos % 7),
                2 => if (pos % 31 < 24) @intCast(pos / 31 % 256) else @truncate(state >> 24),
                else => @truncate(state >> 24),
            };
        }
        for ([_]usize{ 3, 4, 5, 13, 129, 258 }) |minimum| {
            for ([_]usize{ 3, 32, 114, 115, 130, 131, 257, 258 }) |maximum| {
                if (minimum > maximum) continue;
                for ([_]usize{ 0, 1, 8, 128 }) |chain| {
                    const options = Options{ .window_len = input.len, .min_match = minimum, .max_match = maximum, .max_chain = chain, .max_candidates = 8 };
                    const expected = try parse(&control, std.testing.allocator, &input, options, false);
                    const got = try parse(&actual, std.testing.allocator, &input, options, true);
                    try std.testing.expectEqual(expected, got);
                    try std.testing.expectEqualSlices(usize, control.costs.items, actual.costs.items);
                    try std.testing.expectEqualSlices(Token, control.steps.items, actual.steps.items);
                    try std.testing.expectEqualSlices(Token, control.tokens.items, actual.tokens.items);
                }
            }
        }
    }
}
