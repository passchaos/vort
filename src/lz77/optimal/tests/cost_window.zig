const std = @import("std");

fn equal(comptime Token: type, expected: anytype, actual: @TypeOf(expected)) !void {
    try std.testing.expectEqualSlices(usize, expected.costs.items, actual.costs.items);
    try std.testing.expectEqualSlices(Token, expected.steps.items, actual.steps.items);
    try std.testing.expectEqualSlices(Token, expected.tokens.items, actual.tokens.items);
}

fn fill(input: []u8, kind: usize) void {
    var state: u32 = 0x937514ef;
    for (input, 0..) |*byte, pos| {
        state = state *% 1664525 +% 1013904223;
        byte.* = switch (kind) {
            0 => 0,
            1 => @intCast(pos % 7),
            2 => if (pos % 31 < 24) @intCast(pos / 31 % 256) else @truncate(state >> 24),
            else => @truncate(state >> 24),
        };
    }
}

pub fn compare(comptime Options: type, comptime Scratch: type, comptime Token: type, comptime reference: anytype, comptime parse: anytype) !void {
    var expected: Scratch = .{};
    defer expected.deinit(std.testing.allocator);
    var actual: Scratch = .{};
    defer actual.deinit(std.testing.allocator);
    var input: [1027]u8 = undefined;
    for (0..4) |kind| {
        fill(&input, kind);
        for ([_]usize{ 0, 1, 258, 259, 511, 512, 513, 1027 }) |len| {
            for ([_]usize{ 3, 4, 5, 13, 129, 258 }) |minimum| {
                for ([_]usize{ 3, 32, 114, 115, 130, 131, 257, 258 }) |maximum| {
                    if (minimum > maximum) continue;
                    const options: Options = .{ .window_len = 32768, .min_match = minimum, .max_match = maximum, .max_chain = 16, .max_candidates = 8 };
                    const before = try reference(&expected, std.testing.allocator, input[0..len], options, false);
                    const after = try parse(&actual, std.testing.allocator, input[0..len], options, true);
                    try std.testing.expectEqual(before, after);
                    try equal(Token, &expected, &actual);
                }
            }
        }
    }
}

pub fn dense(comptime Options: type, comptime Scratch: type, comptime Token: type, comptime reference: anytype, comptime parse: anytype) !void {
    var expected: Scratch = .{};
    defer expected.deinit(std.testing.allocator);
    var actual: Scratch = .{};
    defer actual.deinit(std.testing.allocator);
    var input: [4097]u8 = undefined;
    for (0..4) |kind| {
        fill(&input, kind);
        for ([_]usize{ 0, 1, 15, 16, 64 }) |chain| {
            for ([_]usize{ 1, 7, 8, 16, 256 }) |limit| {
                const options: Options = .{ .max_chain = chain, .max_candidates = limit };
                const before = try reference(&expected, std.testing.allocator, &input, options, false);
                const after = try parse(&actual, std.testing.allocator, &input, options, true);
                try std.testing.expectEqual(before, after);
                try equal(Token, &expected, &actual);
            }
        }
    }
    const wide = try std.testing.allocator.alloc(u8, 65539);
    defer std.testing.allocator.free(wide);
    fill(wide, 2);
    const options: Options = .{ .max_chain = 32, .max_candidates = 8, .max_match = 128 };
    const before = try reference(&expected, std.testing.allocator, wide, options, false);
    const after = try parse(&actual, std.testing.allocator, wide, options, true);
    try std.testing.expectEqual(before, after);
    try equal(Token, &expected, &actual);
}

pub fn ownership(comptime Options: type, comptime Scratch: type, comptime Token: type, comptime reference: anytype, comptime allocate: anytype) !void {
    const Check = struct {
        fn run(allocator: std.mem.Allocator, source: []const u8) !void {
            const options: Options = .{ .max_chain = 32, .max_candidates = 8 };
            var expected: Scratch = .{};
            defer expected.deinit(std.testing.allocator);
            const stats = try reference(&expected, std.testing.allocator, source, options, false);
            const actual = try allocate(allocator, source, options);
            defer actual.deinit(allocator);
            try std.testing.expectEqual(stats, actual.stats);
            try std.testing.expectEqualSlices(Token, expected.tokens.items, actual.tokens);
        }
    };
    var input: [2049]u8 = undefined;
    fill(&input, 2);
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Check.run, .{&input});
}

pub fn modeled(comptime Options: type, comptime Scratch: type, comptime Token: type, comptime Model: type, comptime reference: anytype, comptime parse: anytype) !void {
    var expected: Scratch = .{};
    defer expected.deinit(std.testing.allocator);
    var actual: Scratch = .{};
    defer actual.deinit(std.testing.allocator);
    var input: [1027]u8 = undefined;
    var literals: [256]u16 = undefined;
    var lengths: [259]u16 = undefined;
    var distances: [32769]u16 = undefined;
    for (&literals, 0..) |*value, i| value.* = @intCast(257 + i * 13);
    for (&lengths, 0..) |*value, i| value.* = @intCast(111 + (i % 17) * 29);
    for (&distances, 0..) |*value, i| value.* = @intCast(31 + i % 257);
    const model: Model = .{ .literal = &literals, .length = &lengths, .distance = &distances };
    for (0..4) |kind| {
        fill(&input, kind);
        for ([_]usize{ 3, 4, 5, 13, 129, 258 }) |minimum| {
            const options: Options = .{ .min_match = minimum, .max_match = 258, .max_chain = 32, .max_candidates = 8 };
            const before = try reference(&expected, std.testing.allocator, &input, options, model);
            const after = try parse(&actual, std.testing.allocator, &input, options, model);
            try std.testing.expectEqual(before, after);
            try equal(Token, &expected, &actual);
        }
    }
}
