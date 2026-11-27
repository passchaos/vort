const std = @import("std");
const phase = @import("phase.zig");
const Sparse = struct { symbols: [256]u8, frequencies: [256]u32, len: usize, total: u32 };
const Contexts = [64]Sparse;
const sentinel: phase.Choice = .{ .tree = 99, .cost = 999 };
const a = std.testing.allocator;

fn oracle(sparse: *const Sparse, costs: *const phase.Costs, tree_count: usize) phase.Choice {
    var best: phase.Choice = .{ .tree = 0, .cost = std.math.maxInt(u64) };
    for (0..tree_count) |tree| {
        var sum: u64 = 0;
        for (sparse.symbols[0..sparse.len], sparse.frequencies[0..sparse.len]) |symbol, frequency| {
            if (frequency != 0) sum += @as(u64, frequency) * costs[symbol][tree];
        }
        if (sum < best.cost) best = .{ .tree = tree, .cost = sum };
    }
    return best;
}

fn prices(costs: *phase.Costs, tree_count: usize) u16 {
    costs.* = undefined;
    var maximum: u16 = 0;
    for (0..256) |symbol| for (0..tree_count) |tree| {
        const value: u16 = @intCast((symbol * 17 + tree * 31) % 251);
        costs[symbol][tree] = value;
        maximum = @max(maximum, value);
    };
    return maximum;
}

fn fill(contexts: *Contexts) void {
    const lengths = [_]usize{ 0, 1, 3, 8, 31, 64, 127, 256 };
    for (contexts, 0..) |*sparse, context| {
        sparse.len = lengths[context % lengths.len];
        sparse.total = 0; // Deliberately unrelated to the initialized frequencies.
        for (0..sparse.len) |index| {
            sparse.symbols[index] = @intCast(255 - index);
            sparse.frequencies[index] = @intCast(1 + (context + index) % 7);
        }
    }
}

fn compare(contexts: *const Contexts, populated: []const u8, costs: *const phase.Costs, tree_count: usize, maximum: u16) !phase.Stats {
    var actual: [64]phase.Choice = @splat(sentinel);
    const stats = phase.chooseAll(contexts, populated, costs, tree_count, maximum, &actual);
    var written: [64]bool = @splat(false);
    for (populated) |context| {
        written[context] = true;
        try std.testing.expectEqualDeep(oracle(&contexts[context], costs, tree_count), actual[context]);
        try std.testing.expect(actual[context].tree < tree_count);
    }
    for (written, actual) |expected_write, choice| {
        if (!expected_write) try std.testing.expectEqualDeep(sentinel, choice);
    }
    try std.testing.expectEqual(populated.len, stats.narrow_contexts + stats.wide_contexts + stats.light_contexts);
    return stats;
}

test "assignment phase all active tree counts match independent u64 sparse oracle" {
    const contexts = try a.create(Contexts);
    defer a.destroy(contexts);
    const costs = try a.create(phase.Costs);
    defer a.destroy(costs);
    fill(contexts);
    var populated: [64]u8 = undefined;
    for (&populated, 0..) |*context, index| context.* = @intCast(index);
    for (1..65) |tree_count| {
        const maximum = prices(costs, tree_count);
        const stats = try compare(contexts, &populated, costs, tree_count, maximum);
        try std.testing.expectEqual(@as(usize, 0), stats.wide_contexts);
        try std.testing.expectEqual(@as(usize, if (tree_count < 8) 64 else 0), stats.light_contexts);
        try std.testing.expectEqual(@as(usize, if (tree_count >= 8) 64 else 0), stats.narrow_contexts);
    }
}

test "assignment phase all populated counts preserve inactive choices and light tile tails" {
    const contexts = try a.create(Contexts);
    defer a.destroy(contexts);
    const costs = try a.create(phase.Costs);
    defer a.destroy(costs);
    fill(contexts);
    const maximum = prices(costs, 17);
    var populated: [64]u8 = undefined;
    for (&populated, 0..) |*context, index| context.* = @intCast(63 - index);
    for (0..65) |count| {
        const stats = try compare(contexts, populated[0..count], costs, 17, maximum);
        try std.testing.expectEqual(count % 4, stats.light_contexts);
        try std.testing.expectEqual(count - count % 4, stats.narrow_contexts);
        try std.testing.expectEqual(@as(usize, 0), stats.wide_contexts);
    }
}

test "assignment phase u32 product boundary and unsigned large costs activate exact wide fallback" {
    const contexts = try a.create(Contexts);
    defer a.destroy(contexts);
    const costs = try a.create(phase.Costs);
    defer a.destroy(costs);
    costs.* = undefined;
    @memset(costs[5][0..17], 2);
    costs[5][9] = 1;
    for (contexts[0..4]) |*sparse| {
        sparse.len = 1;
        sparse.symbols[0] = 5;
        sparse.total = 0;
    }
    contexts[0].frequencies[0] = std.math.maxInt(u32) / 2;
    contexts[1].frequencies[0] = std.math.maxInt(u32) / 2 + 1;
    contexts[2].len = 2;
    contexts[2].symbols[1] = 5;
    contexts[2].frequencies[0] = std.math.maxInt(u32);
    contexts[2].frequencies[1] = 1;
    contexts[3].frequencies[0] = 1_300_000_000;
    const stats = try compare(contexts, &.{ 0, 1, 2, 3 }, costs, 17, 2);
    try std.testing.expectEqual(@as(usize, 2), stats.narrow_contexts);
    try std.testing.expectEqual(@as(usize, 2), stats.wide_contexts);
    try std.testing.expect(oracle(&contexts[3], costs, 17).cost < std.math.maxInt(i32));
    try std.testing.expect(@as(u64, contexts[3].frequencies[0]) * costs[5][0] > std.math.maxInt(i32));
}

test "assignment phase exact u32 maximum and duplicate frequencies remain safe" {
    const contexts = try a.create(Contexts);
    defer a.destroy(contexts);
    const costs = try a.create(phase.Costs);
    defer a.destroy(costs);
    costs.* = undefined;
    @memset(costs[2][0..8], 1);
    for (contexts[0..4], 0..) |*sparse, index| {
        sparse.len = 2;
        sparse.symbols[0] = 2;
        sparse.symbols[1] = 2;
        sparse.frequencies[0] = std.math.maxInt(u32) - @as(u32, @intCast(index));
        sparse.frequencies[1] = @intCast(index);
        sparse.total = 1;
    }
    const stats = try compare(contexts, &.{ 0, 1, 2, 3 }, costs, 8, 1);
    try std.testing.expectEqual(@as(usize, 4), stats.narrow_contexts);
    try std.testing.expectEqual(@as(usize, 0), stats.wide_contexts);
    try std.testing.expectEqual(@as(u64, std.math.maxInt(u32)), oracle(&contexts[0], costs, 8).cost);
}

test "assignment phase mixed duplicate symbols and poisoned inactive rows preserve exact costs" {
    const contexts = try a.create(Contexts);
    defer a.destroy(contexts);
    const costs = try a.create(phase.Costs);
    defer a.destroy(costs);
    costs.* = undefined;
    for ([_]usize{ 2, 3 }) |symbol| {
        @memset(costs[symbol][0..9], 19);
        costs[symbol][8] = 3;
    }
    const populated = [_]u8{ 2, 5, 7, 9 };
    for (populated) |context| {
        const sparse = &contexts[context];
        sparse.len = 4;
        sparse.symbols[0..4].* = .{ 3, 2, 3, 3 };
        sparse.frequencies[0..4].* = .{ 100, 400, 100, 800 };
        sparse.total = std.math.maxInt(u32);
    }
    contexts[7].frequencies[0] = std.math.maxInt(u32);
    const stats = try compare(contexts, &populated, costs, 9, 19);
    try std.testing.expectEqual(@as(usize, 3), stats.narrow_contexts);
    try std.testing.expectEqual(@as(usize, 1), stats.wide_contexts);
}

test "assignment phase strict ties keep the earliest tree across vector groups and tails" {
    const contexts = try a.create(Contexts);
    defer a.destroy(contexts);
    const costs = try a.create(phase.Costs);
    defer a.destroy(costs);
    for (contexts[0..4], 0..) |*sparse, index| {
        sparse.len = 1;
        sparse.symbols[0] = 255;
        sparse.frequencies[0] = @intCast(index + 1);
        sparse.total = 0;
    }
    for ([_]usize{ 8, 9, 15, 16, 17, 31, 32, 63, 64 }) |count| {
        costs.* = undefined;
        @memset(costs[255][0..count], 19);
        costs[255][2] = 3;
        costs[255][count - 1] = 3;
        _ = try compare(contexts, &.{ 0, 1, 2, 3 }, costs, count, 19);
        try std.testing.expectEqual(@as(usize, 2), oracle(&contexts[0], costs, count).tree);
    }
}

test "assignment phase maximum frequency and price products retain u64 oracle range" {
    const contexts = try a.create(Contexts);
    defer a.destroy(contexts);
    const costs = try a.create(phase.Costs);
    defer a.destroy(costs);
    @memset(costs, @splat(std.math.maxInt(u16)));
    for (contexts[0..4]) |*sparse| {
        sparse.len = 256;
        sparse.total = 0;
        for (0..256) |index| {
            sparse.symbols[index] = @intCast(index);
            sparse.frequencies[index] = std.math.maxInt(u32);
        }
    }
    const stats = try compare(contexts, &.{ 0, 1, 2, 3 }, costs, 64, std.math.maxInt(u16));
    try std.testing.expectEqual(@as(usize, 4), stats.wide_contexts);
    try std.testing.expectEqual(@as(u64, 256) * std.math.maxInt(u32) * std.math.maxInt(u16), oracle(&contexts[0], costs, 64).cost);
}

test "assignment phase valid zero price bound chooses tree zero without trusting total or packing" {
    const contexts = try a.create(Contexts);
    defer a.destroy(contexts);
    const costs = try a.create(phase.Costs);
    defer a.destroy(costs);
    for (contexts, 0..) |*sparse, index| {
        sparse.len = if (index % 2 == 0) 256 else 0;
        sparse.total = std.math.maxInt(u32);
        for (0..sparse.len) |symbol| {
            sparse.symbols[symbol] = 3;
            sparse.frequencies[symbol] = std.math.maxInt(u32);
        }
    }
    for (1..65) |count| {
        costs.* = undefined;
        @memset(costs[3][0..count], 0);
        const stats = try compare(contexts, &.{ 0, 1, 2, 3 }, costs, count, 0);
        try std.testing.expectEqual(@as(usize, 4), stats.narrow_contexts);
        try std.testing.expectEqual(@as(usize, 0), stats.wide_contexts + stats.light_contexts);
    }
}

test "assignment phase light and wide skip zero frequency poisoned price rows" {
    const contexts = try a.create(Contexts);
    defer a.destroy(contexts);
    const costs = try a.create(phase.Costs);
    defer a.destroy(costs);
    costs.* = undefined;
    @memset(costs[3][0..7], 5);
    costs[3][4] = 3;
    for (contexts[0..4]) |*sparse| {
        sparse.len = 3;
        sparse.symbols[0..3].* = .{ 3, 200, 3 };
        sparse.frequencies[0..3].* = .{ 8, 0, 7 };
        sparse.total = 1;
    }
    const light = try compare(contexts, &.{ 0, 1, 2, 3 }, costs, 7, 5);
    try std.testing.expectEqual(@as(usize, 4), light.light_contexts);
    @memset(costs[3][0..9], 5);
    costs[3][8] = 3;
    for (contexts[0..4]) |*sparse| sparse.frequencies[0..3].* = .{ std.math.maxInt(u32), 0, 1 };
    const wide = try compare(contexts, &.{ 0, 1, 2, 3 }, costs, 9, 5);
    try std.testing.expectEqual(@as(usize, 4), wide.wide_contexts);
    try std.testing.expectEqual(@as(usize, 0), wide.narrow_contexts + wide.light_contexts);
}

test "assignment phase conservative price bound keeps exact narrow and wide decisions" {
    const contexts = try a.create(Contexts);
    defer a.destroy(contexts);
    const costs = try a.create(phase.Costs);
    defer a.destroy(costs);
    costs.* = undefined;
    @memset(costs[9][0..15], 2);
    costs[9][11] = 1;
    const frequencies = [_]u32{ 100_000, 65_537, 65_538, 1 };
    for (contexts[0..4], frequencies) |*sparse, frequency| {
        sparse.len = 1;
        sparse.symbols[0] = 9;
        sparse.frequencies[0] = frequency;
        sparse.total = 0;
    }
    const stats = try compare(contexts, &.{ 0, 1, 2, 3 }, costs, 15, std.math.maxInt(u16));
    try std.testing.expectEqual(@as(usize, 2), stats.narrow_contexts);
    try std.testing.expectEqual(@as(usize, 2), stats.wide_contexts);
    try std.testing.expectEqual(@as(usize, 11), oracle(&contexts[0], costs, 15).tree);
}
