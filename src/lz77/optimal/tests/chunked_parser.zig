const std = @import("std");

pub fn compare(comptime Options: type, comptime Scratch: type, comptime Token: type, comptime full: anytype, comptime coded: anytype) !void {
    var expected: Scratch = .{};
    defer expected.deinit(std.testing.allocator);
    var actual: Scratch = .{};
    defer actual.deinit(std.testing.allocator);
    const input = try std.testing.allocator.alloc(u8, 65539);
    defer std.testing.allocator.free(input);
    var state: u32 = 0x817dc271;
    for (0..4) |kind| {
        for (input, 0..) |*byte, pos| {
            state = state *% 1664525 +% 1013904223;
            byte.* = switch (kind) {
                0 => 0,
                1 => @intCast(pos % 7),
                2 => if (pos % 97 < 89) 0 else @truncate(state >> 24),
                else => @truncate(state >> 24),
            };
        }
        for ([_]usize{ 0, 1, 2, 259, 1027, 65539 }) |length| {
            for ([_]usize{ 127, 257, 32768, 65536 }) |chunk| {
                if (length > 1027 and chunk < 32768) continue;
                for ([_]Options{
                    .{ .max_chain = 0 },
                    .{ .max_chain = 16, .max_candidates = 8 },
                    .{ .max_chain = 64, .max_candidates = 16 },
                    .{ .min_match = 5, .max_chain = 32, .max_candidates = 2 },
                    .{ .min_match = 129, .max_chain = 32, .max_match = 258 },
                    .{ .window_len = 256, .max_match = 129, .max_chain = 32 },
                }) |options| {
                    const before = try full(&expected, std.testing.allocator, input[0..length], options, true);
                    const after = try coded(&actual, std.testing.allocator, input[0..length], options, chunk);
                    try std.testing.expectEqual(before, after);
                    try std.testing.expectEqualSlices(usize, expected.costs.items, actual.costs.items);
                    try std.testing.expectEqualSlices(Token, expected.steps.items, actual.steps.items);
                    try std.testing.expectEqualSlices(Token, expected.tokens.items, actual.tokens.items);
                }
            }
        }
    }
}
