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

pub fn denseComparisons(comptime Options: type, comptime Scratch: type, comptime Token: type, comptime parse: anytype) !void {
    var reference = Scratch{};
    defer reference.deinit(std.testing.allocator);
    var actual = Scratch{};
    defer actual.deinit(std.testing.allocator);
    var input: [4097]u8 = undefined;
    var state: u32 = 0x83070f54;
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
        for ([_]usize{ 1, 7, 8, 16, 256 }) |limit| {
            for ([_]usize{ 15, 16, 64, 512 }) |chain| {
                const options = Options{ .window_len = 32768, .max_chain = chain, .max_candidates = limit };
                const expected = try parse(&reference, std.testing.allocator, &input, options, false);
                const got = try parse(&actual, std.testing.allocator, &input, options, true);
                try std.testing.expectEqual(expected, got);
                try std.testing.expectEqualSlices(usize, reference.costs.items, actual.costs.items);
                try std.testing.expectEqualSlices(Token, reference.steps.items, actual.steps.items);
                try std.testing.expectEqualSlices(Token, reference.tokens.items, actual.tokens.items);
            }
        }
    }
}

pub fn ownership(comptime Options: type, comptime Scratch: type, comptime Token: type, comptime parse: anytype) !void {
    var input: [2048]u8 = undefined;
    for (&input, 0..) |*byte, pos| byte.* = if (pos % 97 < 89) 0 else @intCast(pos % 256);
    const Check = struct {
        fn run(allocator: std.mem.Allocator, source: []const u8) !void {
            var actual = Scratch{};
            defer actual.deinit(allocator);
            var reference = Scratch{};
            defer reference.deinit(std.testing.allocator);
            const options = Options{ .max_chain = 128, .max_candidates = 32 };
            const expected = try parse(&reference, std.testing.allocator, source, options, false);
            const got = try parse(&actual, allocator, source, options, true);
            try std.testing.expectEqual(expected, got);
            try std.testing.expectEqualSlices(usize, reference.costs.items, actual.costs.items);
            try std.testing.expectEqualSlices(Token, reference.steps.items, actual.steps.items);
            try std.testing.expectEqualSlices(Token, reference.tokens.items, actual.tokens.items);
            try std.testing.expectEqual(@as(usize, source.len * 4), actual.prefix_jumps.bytes());
            const capacities = .{ actual.prefix_jumps.raw_ranks.capacity, actual.prefix_jumps.prefix_ranks.capacity };
            _ = try parse(&actual, allocator, source, options, true);
            try std.testing.expectEqual(capacities, .{ actual.prefix_jumps.raw_ranks.capacity, actual.prefix_jumps.prefix_ranks.capacity });
            const small = try parse(&actual, allocator, source[0..33], options, true);
            const small_reference = try parse(&reference, std.testing.allocator, source[0..33], options, false);
            try std.testing.expectEqual(small_reference, small);
            try std.testing.expectEqualSlices(Token, reference.tokens.items, actual.tokens.items);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Check.run, .{&input});
}

pub fn widePositions(comptime Options: type, comptime Scratch: type, comptime Token: type, comptime parse: anytype) !void {
    const input = try std.testing.allocator.alloc(u8, 65539);
    defer std.testing.allocator.free(input);
    var state: u32 = 0x854037b1;
    for (input, 0..) |*byte, pos| {
        state = state *% 1664525 +% 1013904223;
        byte.* = if (pos % 97 < 89) 0 else @truncate(state >> 24);
    }
    var reference = Scratch{};
    defer reference.deinit(std.testing.allocator);
    var actual = Scratch{};
    defer actual.deinit(std.testing.allocator);
    const options = Options{ .max_chain = 128, .max_candidates = 32, .max_match = 128 };
    const before = try parse(&reference, std.testing.allocator, input, options, false);
    const after = try parse(&actual, std.testing.allocator, input, options, true);
    try std.testing.expectEqual(before, after);
    try std.testing.expectEqualSlices(usize, reference.costs.items, actual.costs.items);
    try std.testing.expectEqualSlices(Token, reference.steps.items, actual.steps.items);
    try std.testing.expectEqualSlices(Token, reference.tokens.items, actual.tokens.items);
    try std.testing.expectEqual(input.len * 4, actual.prefix_jumps.bytes());
}
