const std = @import("std");
const lz77 = @import("../../lz77.zig");

fn expectReplay(dict: []const u8, input: []const u8, tokens: []const lz77.Token) !void {
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(std.testing.allocator);
    for (tokens) |token| switch (token) {
        .literal => |byte| try output.append(std.testing.allocator, byte),
        .match => |match| {
            try std.testing.expect(match.distance > 0 and match.distance <= dict.len + output.items.len);
            for (0..match.length) |_| {
                const source = dict.len + output.items.len - match.distance;
                const byte = if (source < dict.len) dict[source] else output.items[source - dict.len];
                try output.append(std.testing.allocator, byte);
            }
        },
    };
    try std.testing.expectEqualSlices(u8, input, output.items);
}

pub fn replay() !void {
    const Check = struct {
        fn run(allocator: std.mem.Allocator, input: []const u8) !void {
            const options: lz77.GreedyOptions = .{ .max_chain = 1024, .nice_len = 258, .lazy_min_gain = 1, .min_savings_bits = 0, .lazy_tuning = .{ .good_length = 32, .max_lazy = 128 } };
            const plan = try lz77.lazyGreedyPlanAlloc(allocator, input, options);
            defer plan.deinit(allocator);
            try expectReplay("", input, plan.tokens);
            try std.testing.expectEqual(input.len, plan.stats.literals + plan.stats.matched_bytes);
        }
    };
    var input: [1024]u8 = undefined;
    var state: u32 = 0x0538d270;
    for (0..2) |kind| {
        for (&input, 0..) |*byte, pos| {
            state = state *% 1664525 +% 1013904223;
            byte.* = if (kind == 0) @intCast(pos % 7) else @truncate(state >> 24);
        }
        try std.testing.checkAllAllocationFailures(std.testing.allocator, Check.run, .{&input});
    }
}

pub fn dictionary() !void {
    const Check = struct {
        fn run(allocator: std.mem.Allocator) !void {
            const dict = "dictionary-value-pattern" ** 16;
            const input = "dictionary-value-pattern-extended" ** 32;
            const options: lz77.GreedyOptions = .{ .max_chain = 1024, .nice_len = 258, .lazy_min_gain = 1, .lazy_tuning = .{ .good_length = 32, .max_lazy = 128 } };
            const plan = try lz77.lazyGreedyPlanAllocWithDictionary(allocator, input, dict, options);
            defer plan.deinit(allocator);
            try expectReplay(dict, input, plan.tokens);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Check.run, .{});
}

pub fn reuse() !void {
    var input: [65539]u8 = undefined;
    var random: u32 = 0xabc753;
    for (&input, 0..) |*byte, pos| {
        random = random *% 1664525 +% 1013904223;
        byte.* = if (pos % 97 < 89) @intCast(pos % 7) else @truncate(random >> 24);
    }
    var tokens: std.ArrayList(lz77.Token) = .empty;
    defer tokens.deinit(std.testing.allocator);
    var scratch: lz77.DictionaryGreedyScratch = .{};
    defer scratch.deinit(std.testing.allocator);
    const options: lz77.GreedyOptions = .{ .max_chain = 1024, .nice_len = 258, .lazy_min_gain = 1, .min_savings_bits = 0, .lazy_tuning = .{ .good_length = 32, .max_lazy = 128 } };
    for ([_]usize{ 0, 1, 2, 3, 4, 32, 128, 258, 1024, 32768, 65539 }) |length| {
        const expected = try lz77.lazyGreedyPlanAlloc(std.testing.allocator, input[0..length], options);
        defer expected.deinit(std.testing.allocator);
        const actual = try lz77.lazyGreedyPlanWithDictionaryReuse(&tokens, &scratch, std.testing.allocator, input[0..length], "", options);
        try std.testing.expectEqual(expected.stats, actual);
        try std.testing.expectEqualSlices(lz77.Token, expected.tokens, tokens.items);
        if (length <= 32768) {
            const tiny = try lz77.lazyGreedyPlanTinyReuse(&tokens, std.testing.allocator, input[0..length], options);
            try std.testing.expectEqual(expected.stats, tiny);
            try std.testing.expectEqualSlices(lz77.Token, expected.tokens, tokens.items);
        }
    }
}
