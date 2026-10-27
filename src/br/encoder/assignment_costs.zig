//! Exact context-to-tree assignment with contiguous costs for adjacent trees.
//! Each sparse frequency is loaded once per four-tree group. Widening before
//! multiplication preserves the scalar u64 arithmetic on every target.
const std = @import("std");

pub const max_trees = 64;
pub const Costs = [256][max_trees]u16;
pub const Choice = struct { tree: usize, cost: u64 };
const lanes = 4;

pub fn choose(sparse: anytype, costs: *const Costs, tree_count: usize) Choice {
    std.debug.assert(tree_count != 0 and tree_count <= max_trees);
    var best: Choice = .{ .tree = 0, .cost = std.math.maxInt(u64) };
    var tree: usize = 0;
    while (tree + lanes <= tree_count) : (tree += lanes) {
        var totals: @Vector(lanes, u64) = @splat(0);
        for (sparse.symbols[0..sparse.len], sparse.frequencies[0..sparse.len]) |symbol, frequency| {
            const row: @Vector(lanes, u16) = costs[symbol][tree..][0..lanes].*;
            const widened: @Vector(lanes, u64) = @intCast(row);
            totals += @as(@Vector(lanes, u64), @splat(frequency)) * widened;
        }
        const values: [lanes]u64 = totals;
        for (values, 0..) |cost, lane| {
            if (cost < best.cost) best = .{ .tree = tree + lane, .cost = cost };
        }
    }
    while (tree < tree_count) : (tree += 1) {
        var cost: u64 = 0;
        for (sparse.symbols[0..sparse.len], sparse.frequencies[0..sparse.len]) |symbol, frequency|
            cost += @as(u64, frequency) * costs[symbol][tree];
        if (cost < best.cost) best = .{ .tree = tree, .cost = cost };
    }
    return best;
}

const Fixture = struct { symbols: [256]u8, frequencies: [256]u32, len: usize };

fn reference(sparse: *const Fixture, costs: *const Costs, tree_count: usize) Choice {
    var best: Choice = .{ .tree = 0, .cost = std.math.maxInt(u64) };
    for (0..tree_count) |tree| {
        var cost: u64 = 0;
        for (sparse.symbols[0..sparse.len], sparse.frequencies[0..sparse.len]) |symbol, frequency|
            cost += @as(u64, frequency) * costs[symbol][tree];
        if (cost < best.cost) best = .{ .tree = tree, .cost = cost };
    }
    return best;
}

test "assignment grouped integer costs match independent scalar and strict ties" {
    var costs: Costs = undefined;
    var sparse: Fixture = undefined;
    var state: u32 = 0x9e37_79b9;
    for (0..256) |symbol| {
        sparse.symbols[symbol] = @intCast(255 - symbol);
        state = state *% 1664525 +% 1013904223;
        sparse.frequencies[symbol] = state;
        for (0..max_trees) |tree| {
            state = state *% 1664525 +% 1013904223;
            costs[symbol][tree] = @truncate(state >> 13);
        }
    }
    for ([_]usize{ 0, 1, 3, 4, 7, 16, 63, 127, 255, 256 }) |len| {
        sparse.len = len;
        for (1..max_trees + 1) |tree_count|
            try std.testing.expectEqualDeep(reference(&sparse, &costs, tree_count), choose(&sparse, &costs, tree_count));
    }
    @memset(&costs, @splat(std.math.maxInt(u16)));
    @memset(&sparse.frequencies, std.math.maxInt(u32));
    sparse.len = 256;
    for (1..max_trees + 1) |tree_count| {
        const result = choose(&sparse, &costs, tree_count);
        try std.testing.expectEqual(@as(usize, 0), result.tree);
        try std.testing.expectEqual(@as(u64, 256) * std.math.maxInt(u32) * std.math.maxInt(u16), result.cost);
    }
    // A tie across vector groups keeps the earliest tree. Inactive cells are
    // left undefined to check that neither inactive symbols nor tail trees read.
    costs = undefined;
    sparse.len = 1;
    sparse.symbols[0] = 255;
    sparse.frequencies[0] = 17;
    for ([_]usize{ 3, 4, 5, 7, 8, 9, 63, 64 }) |count| {
        @memset(costs[255][0..count], 19);
        costs[255][2] = 3;
        costs[255][count - 1] = 3;
        try std.testing.expectEqualDeep(Choice{ .tree = 2, .cost = 51 }, choose(&sparse, &costs, count));
    }
}
