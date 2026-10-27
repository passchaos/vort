const std = @import("std");
const lazy = @import("../lazy.zig");
const Index = @import("../byte_index.zig").Index;
const PrefixIndex = @import("../prefix_index.zig").Index;

pub fn candidates(comptime Options: type, comptime Context: type) !void {
    var index = Index{};
    const prefix = try std.testing.allocator.create(PrefixIndex);
    defer std.testing.allocator.destroy(prefix);
    var input: [257]u8 = undefined;
    var state: u32 = 0x9c49ffb3;
    for (0..4) |kind| {
        index = .{};
        prefix.* = .{};
        for (&input, 0..) |*byte, pos| {
            state = state *% 1664525 +% 1013904223;
            byte.* = switch (kind) {
                0 => 0,
                1 => @intCast(pos % 7),
                2 => if (pos < 192) 0 else @truncate(state >> 24),
                else => @truncate(state >> 24),
            };
        }
        for (0..input.len + 1) |pos| {
            index.advance(&input, pos);
            prefix.advance(&input, pos);
            for ([_]usize{ 0, 1, 31, 32, 33, 256, 32768, 65536 }) |window| {
                for ([_]usize{ 0, 1, 6, 128 }) |chain| {
                    for ([_]usize{ 0, 3, 4, 258, 1000 }) |minimum| {
                        for ([_]usize{ 3, 32, 258 }) |maximum| {
                            for ([_]usize{ 0, 4, 16, 80 }) |nice| {
                                const options = Options{ .window_len = window, .max_chain = chain, .min_match = minimum, .max_match = maximum, .nice_len = nice };
                                try std.testing.expectEqual(Context.reverse(&input, pos, options), Context.indexed(&index, &input, pos, options));
                                try std.testing.expectEqual(Context.reverse(&input, pos, options), Context.prefixed(prefix, &input, pos, options));
                            }
                        }
                    }
                }
            }
        }
    }
}

pub fn plans(comptime Token: type, comptime Stats: type, comptime Options: type, comptime Context: type) !void {
    var original: std.ArrayList(Token) = .empty;
    defer original.deinit(std.testing.allocator);
    var indexed: std.ArrayList(Token) = .empty;
    defer indexed.deinit(std.testing.allocator);
    var prefixed: std.ArrayList(Token) = .empty;
    defer prefixed.deinit(std.testing.allocator);
    var input: [65539]u8 = undefined;
    var state: u32 = 0x604ec19d;
    const policies = [_]Options{
        .{},
        .{ .window_len = 0 },
        .{ .max_chain = 0 },
        .{ .window_len = 31, .max_chain = 1, .lazy_min_gain = 0 },
        .{ .max_chain = 6, .nice_len = 16, .min_match = 4, .max_match = 32, .min_savings_bits = 8 },
        .{ .window_len = 65536, .max_chain = 160, .nice_len = 80, .min_savings_bits = 32 },
    };
    for (0..4) |kind| {
        for (&input, 0..) |*byte, pos| {
            state = state *% 1664525 +% 1013904223;
            byte.* = switch (kind) {
                0 => 0,
                1 => @intCast(pos % 7),
                2 => if (pos % 97 < 64) 0 else @truncate(state >> 24),
                else => @truncate(state >> 24),
            };
        }
        for ([_]usize{ 0, 1, 2, 3, 31, 32, 33, 511, 1024, 2047, 2048, 4097, 8192, 65539 }) |length| {
            if (length > 8192 and kind > 1) continue;
            for (policies) |options| {
                const expected = try lazy.reverse(&original, std.testing.allocator, input[0..length], options, Stats{}, Context);
                const actual = try lazy.indexed(&indexed, std.testing.allocator, input[0..length], options, Stats{}, Context);
                try std.testing.expectEqual(expected, actual);
                try std.testing.expectEqualSlices(Token, original.items, indexed.items);
                const prefix_stats = try lazy.prefixed(&prefixed, std.testing.allocator, input[0..length], options, Stats{}, Context);
                try std.testing.expectEqual(expected, prefix_stats);
                try std.testing.expectEqualSlices(Token, original.items, prefixed.items);
            }
        }
    }
}

pub fn failures(comptime Token: type, comptime Stats: type, comptime Options: type, comptime Context: type) !void {
    var input: [4097]u8 = undefined;
    var state: u32 = 0x7949b037;
    for (&input) |*byte| {
        state = state *% 1664525 +% 1013904223;
        byte.* = @truncate(state >> 24);
    }
    const Check = struct {
        fn run(allocator: std.mem.Allocator, source: []const u8) !void {
            var expected: std.ArrayList(Token) = .empty;
            defer expected.deinit(std.testing.allocator);
            var actual: std.ArrayList(Token) = .empty;
            defer actual.deinit(allocator);
            var prefix_tokens: std.ArrayList(Token) = .empty;
            defer prefix_tokens.deinit(allocator);
            const options = Options{ .max_chain = 6 };
            const before = try lazy.reverse(&expected, std.testing.allocator, source, options, Stats{}, Context);
            const after = try lazy.indexed(&actual, allocator, source, options, Stats{}, Context);
            try std.testing.expectEqual(before, after);
            try std.testing.expectEqualSlices(Token, expected.items, actual.items);
            const prefixed = try lazy.prefixed(&prefix_tokens, allocator, source, options, Stats{}, Context);
            try std.testing.expectEqual(before, prefixed);
            try std.testing.expectEqualSlices(Token, expected.items, prefix_tokens.items);
            // Independent reuse resets heads and retains exactly the token owner.
            const reused = try lazy.indexed(&actual, allocator, source[0..33], options, Stats{}, Context);
            const control = try lazy.reverse(&expected, std.testing.allocator, source[0..33], options, Stats{}, Context);
            try std.testing.expectEqual(control, reused);
            try std.testing.expectEqualSlices(Token, expected.items, actual.items);
            const prefix_reused = try lazy.prefixed(&prefix_tokens, allocator, source[0..33], options, Stats{}, Context);
            try std.testing.expectEqual(control, prefix_reused);
            try std.testing.expectEqualSlices(Token, expected.items, prefix_tokens.items);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Check.run, .{&input});
}

fn collision(query: [3]u8, same_first: bool) [3]u8 {
    const prefix = @import("../prefix_index.zig");
    for (0..65536) |suffix| {
        const bytes = [3]u8{
            if (same_first) query[0] else query[0] +% 1,
            @truncate(suffix >> 8),
            @truncate(suffix),
        };
        if (bytes[1] == query[0] or bytes[2] == query[0]) continue;
        if (!std.mem.eql(u8, &bytes, &query) and prefix.bucket(&bytes) == prefix.bucket(&query)) return bytes;
    }
    unreachable;
}

pub fn collisions(comptime Options: type, comptime Context: type) !void {
    const index = try std.testing.allocator.create(PrefixIndex);
    defer std.testing.allocator.destroy(index);
    const query = [3]u8{ 42, 13, 24 };
    for ([_]bool{ false, true }) |same_first| {
        var input: [24]u8 = @splat(0);
        const collided = collision(query, same_first);
        @memcpy(input[0..3], &query);
        @memcpy(input[8..11], &collided);
        @memcpy(input[16..19], &query);
        index.* = .{};
        index.advance(&input, 16);
        for ([_]usize{ 1, 2, 3 }) |chain| {
            const options = Options{ .max_chain = chain };
            const expected = Context.reverse(&input, 16, options);
            const actual = Context.prefixed(index, &input, 16, options);
            try std.testing.expectEqual(expected, actual);
            if (chain == 1 and same_first) try std.testing.expectEqual(@as(usize, 0), actual.length);
            if (chain == 1 and !same_first) try std.testing.expect(actual.length >= 3);
        }
    }
    // The oldest full-window candidate is reached only after every newer
    // first-byte anchor spent its slot, including prefixes absent from the hash.
    var input: [32772]u8 = @splat(42);
    @memcpy(input[0..3], &query);
    @memcpy(input[32768..32771], &query);
    index.* = .{};
    index.advance(&input, 32768);
    for ([_]usize{ 32765, 32766, 32767 }) |chain| {
        const options = Options{ .max_chain = chain };
        const expected = Context.reverse(&input, 32768, options);
        const actual = Context.prefixed(index, &input, 32768, options);
        try std.testing.expectEqual(expected, actual);
        if (chain == 32765) try std.testing.expectEqual(@as(usize, 0), actual.length);
        if (chain == 32766) try std.testing.expectEqual(@as(usize, 32768), actual.distance);
    }
}
