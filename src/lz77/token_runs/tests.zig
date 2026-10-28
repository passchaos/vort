const std = @import("std");

pub fn compare(comptime Options: type, comptime Token: type, comptime actual: anytype, comptime reference: anytype) !void {
    const input = try std.testing.allocator.alloc(u8, 256 * 1024 + 259);
    defer std.testing.allocator.free(input);
    var state: u32 = 0x6317af29;
    for (0..4) |kind| {
        for (input, 0..) |*value, position| {
            state = state *% 1664525 +% 1013904223;
            value.* = switch (kind) {
                0 => 0,
                1 => @intCast(position % 7),
                2 => if (position % 97 < 89) 0 else @truncate(state >> 24),
                else => @truncate(state >> 24),
            };
        }
        for ([_]Options{
            .{ .max_chain = 0 },
            .{ .max_chain = 16, .max_candidates = 8 },
            .{ .min_match = 5, .max_chain = 8, .max_candidates = 2, .max_match = 129 },
        }) |options| {
            const before = try reference(std.testing.allocator, input, options);
            defer before.deinit(std.testing.allocator);
            const after = try actual(std.testing.allocator, input, options);
            defer after.deinit(std.testing.allocator);
            try std.testing.expectEqualDeep(before.stats, after.stats);
            try std.testing.expectEqualSlices(Token, before.tokens, after.tokens);
        }
    }
}
