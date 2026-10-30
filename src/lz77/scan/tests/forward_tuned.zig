const std = @import("std");
const lazy = @import("../lazy.zig");

pub fn compare(comptime Token: type, comptime Stats: type, comptime Options: type, comptime Context: type) !void {
    var reference: std.ArrayList(Token) = .empty;
    defer reference.deinit(std.testing.allocator);
    var indexed: std.ArrayList(Token) = .empty;
    defer indexed.deinit(std.testing.allocator);
    var prefixed: std.ArrayList(Token) = .empty;
    defer prefixed.deinit(std.testing.allocator);
    var input: [4097]u8 = undefined;
    var state: u32 = 0x650dd971;
    for (0..4) |kind| {
        for (&input, 0..) |*byte, pos| {
            state = state *% 1664525 +% 1013904223;
            byte.* = switch (kind) {
                0 => 0,
                1 => @intCast(pos % 7),
                2 => if (pos % 97 < 89) 0 else @truncate(state >> 24),
                else => @truncate(state >> 24),
            };
        }
        for ([_]usize{ 0, 1, 2, 3, 31, 32, 33, 127, 128, 129, 257, 258, 259, 513, 4097 }) |length| {
            const options = Options{ .max_chain = 1024, .nice_len = 258, .lazy_min_gain = 1, .min_savings_bits = 0, .lazy_tuning = .{ .good_length = 32, .max_lazy = 128 } };
            const expected = try lazy.reverse(&reference, std.testing.allocator, input[0..length], options, Stats{}, Context);
            const actual = try lazy.indexed(&indexed, std.testing.allocator, input[0..length], options, Stats{}, Context);
            const prefix = try lazy.prefixed(&prefixed, std.testing.allocator, input[0..length], options, Stats{}, Context);
            try std.testing.expectEqual(expected, actual);
            try std.testing.expectEqual(expected, prefix);
            try std.testing.expectEqualSlices(Token, reference.items, indexed.items);
            try std.testing.expectEqualSlices(Token, reference.items, prefixed.items);
        }
    }
}
