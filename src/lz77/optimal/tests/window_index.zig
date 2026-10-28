const std = @import("std");
const policy = @import("../prefix_jumps.zig");
const empty = std.math.maxInt(u32);

fn fill(input: []u8, kind: usize, collision: [3]u8) void {
    var state: u32 = 0x721c8d31;
    for (input, 0..) |*byte, pos| {
        state = state *% 1664525 +% 1013904223;
        byte.* = switch (kind) {
            0 => 0,
            1 => @intCast(pos % 7),
            2 => if (pos % 97 < 89) @intCast(pos / 97 % 256) else @truncate(state >> 24),
            3 => @truncate(state >> 24),
            else => if (pos / 3 % 5 == 0) 0 else collision[pos % 3],
        };
    }
}

pub fn verify(comptime Window: type, comptime buildFull: anytype, comptime hashAt: anytype) !void {
    var collision: [3]u8 = undefined;
    const zero = [3]u8{ 0, 0, 0 };
    const bucket = hashAt(&zero, 0).?;
    for (1..1 << 24) |value| {
        collision = .{ @truncate(value >> 16), @truncate(value >> 8), @truncate(value) };
        if (hashAt(&collision, 0).? == bucket) break;
    } else return error.NoHashCollision;
    var head: std.ArrayList(u32) = .empty;
    defer head.deinit(std.testing.allocator);
    var previous: std.ArrayList(u32) = .empty;
    defer previous.deinit(std.testing.allocator);
    var initialized: [512]u64 = undefined;
    var ordinals: policy.Index = .{};
    defer ordinals.deinit(std.testing.allocator);
    const input = try std.testing.allocator.alloc(u8, 196611);
    defer std.testing.allocator.free(input);

    for (0..5) |kind| {
        fill(input, kind, collision);
        for ([_]usize{ 0, 1, 2, 1027, input.len }) |length| {
            const source = input[0..length];
            try buildFull(std.testing.allocator, source, &head, &previous, &initialized);
            try ordinals.build(std.testing.allocator, source, previous.items);
            for ([_]usize{ 1, 257, 258, 32767, 32768, 32769, 65536, 131072 }) |chunk| {
                if (length > 1027 and chunk < 32767) continue;
                var window = try Window.init(std.testing.allocator, source, chunk);
                defer window.deinit(std.testing.allocator);
                const view = window.view();
                try std.testing.expectEqual(policy.useful(source, previous.items), policy.useful(source, view));
                try std.testing.expectEqual(policy.sparseLinearUseful(source, previous.items), policy.sparseLinearUseful(source, view));
                try view.activate(std.testing.allocator, true);
                var pos = length -| 2;
                while (pos > 0) {
                    pos -= 1;
                    view.prepare(pos);
                    const expected = previous.items[pos];
                    const reachable = expected == empty or expected >= window.base;
                    try std.testing.expectEqual(if (reachable) expected else @as(u32, @intCast(window.base - 1)), view.get(pos));
                    var candidate = expected;
                    var count: usize = 0;
                    while (candidate != empty and pos - candidate <= 32768 and count < 8) : (count += 1) {
                        try std.testing.expectEqual(ordinals.rawCount(pos, candidate), view.rawCount(pos, candidate));
                        if (std.mem.readInt(u24, source[pos..][0..3], .little) == std.mem.readInt(u24, source[candidate..][0..3], .little))
                            try std.testing.expectEqual(ordinals.prefixCount(pos, candidate), view.prefixCount(pos, candidate));
                        candidate = previous.items[candidate];
                    }
                }
            }
        }
    }
}

pub fn parser(comptime Options: type, comptime Scratch: type, comptime Token: type, comptime reference: anytype, comptime bounded: anytype) !void {
    var expected: Scratch = .{};
    defer expected.deinit(std.testing.allocator);
    var actual: Scratch = .{};
    defer actual.deinit(std.testing.allocator);
    const input = try std.testing.allocator.alloc(u8, 65539);
    defer std.testing.allocator.free(input);
    for (0..4) |kind| {
        fill(input, kind, .{ 0, 0, 0 });
        for ([_]usize{ 0, 1, 259, 4099, 65539 }) |length| {
            for ([_]usize{ 1, 257, 32768, 32769 }) |chunk| {
                if (length > 4099 and chunk < 32768) continue;
                for ([_]Options{
                    .{ .max_chain = 0 },
                    .{ .max_chain = 15, .max_candidates = 7 },
                    .{ .max_chain = 16, .max_candidates = 8 },
                    .{ .max_chain = 64, .max_candidates = 16 },
                    .{ .min_match = 5, .max_chain = 64, .max_candidates = 8 },
                    .{ .max_match = 129, .window_len = 256, .max_chain = 32 },
                }) |options| {
                    const before = try reference(&expected, std.testing.allocator, input[0..length], options, true);
                    const after = try bounded(&actual, std.testing.allocator, input[0..length], options, chunk);
                    try std.testing.expectEqual(before, after);
                    try std.testing.expectEqualSlices(usize, expected.costs.items, actual.costs.items);
                    try std.testing.expectEqualSlices(Token, expected.steps.items, actual.steps.items);
                    try std.testing.expectEqualSlices(Token, expected.tokens.items, actual.tokens.items);
                }
            }
        }
    }
}

pub fn ownership(comptime allocate: anytype) !void {
    const Check = struct {
        fn run(allocator: std.mem.Allocator, input: []const u8) !void {
            const result = try allocate(allocator, input, .{ .max_chain = 32, .max_candidates = 8 });
            defer result.deinit(allocator);
            try std.testing.expect(result.tokens.len > 0);
        }
    };
    const input = try std.testing.allocator.alloc(u8, 256 * 1024 + 1);
    defer std.testing.allocator.free(input);
    @memset(input, 0);
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Check.run, .{input});
}

pub fn geometry(comptime Window: type) !void {
    try std.testing.expectError(error.InvalidBlockPlan, Window.init(std.testing.allocator, "abc", 0));
    try std.testing.expectError(error.InvalidBlockPlan, Window.init(std.testing.allocator, "abc", std.math.maxInt(usize)));
    const input = try std.testing.allocator.alloc(u8, 4 * 1024 * 1024);
    defer std.testing.allocator.free(input);
    @memset(input, 0);
    var short = try Window.init(std.testing.allocator, input[0 .. 256 * 1024], 128 * 1024);
    defer short.deinit(std.testing.allocator);
    var long = try Window.init(std.testing.allocator, input, 128 * 1024);
    defer long.deinit(std.testing.allocator);
    try short.view().activate(std.testing.allocator, true);
    try long.view().activate(std.testing.allocator, true);
    try std.testing.expectEqual(short.view().bytes(), long.view().bytes());
    try std.testing.expect(long.view().bytes() < 2 * 1024 * 1024);
}
