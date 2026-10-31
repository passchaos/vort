//! Exact assignment under frozen joint histogram prices.
const std = @import("std");
const Histogram = @import("../histogram_model.zig").Histogram(256);
pub const Choice = struct { tree: usize, cost: u64 };
const Sparse = struct {
    symbols: [256]u8 = undefined,
    frequencies: [256]u32 = undefined,
    len: usize = 0,
    fn init(context: *const Histogram) Sparse {
        var result: Sparse = .{};
        for (&context.counts, 0..) |frequency, symbol| {
            if (frequency == 0) continue;
            result.symbols[result.len] = @intCast(symbol);
            result.frequencies[result.len] = frequency;
            result.len += 1;
        }
        return result;
    }
};

pub fn prepare(trees: []const Histogram, costs: []u16, stride: usize) void {
    std.debug.assert(trees.len <= stride and costs.len == 256 * stride);
    for (trees, 0..) |*tree, index| {
        const row = tree.symbolCostsQ8();
        for (row, 0..) |cost, symbol| costs[symbol * stride + index] = cost;
    }
}

pub fn chooseGrouped(context: *const Histogram, costs: []const u16, tree_count: usize, stride: usize) Choice {
    std.debug.assert(tree_count != 0 and tree_count <= stride and stride <= 256);
    std.debug.assert(costs.len == 256 * stride);
    const sparse = Sparse.init(context);
    var best: Choice = .{ .tree = 0, .cost = std.math.maxInt(u64) };
    var tree: usize = 0;
    while (tree + 4 <= tree_count) : (tree += 4) {
        var totals: @Vector(4, u64) = @splat(0);
        for (sparse.symbols[0..sparse.len], sparse.frequencies[0..sparse.len]) |symbol, frequency| {
            const row: @Vector(4, u16) = costs[@as(usize, symbol) * stride + tree ..][0..4].*;
            const widened: @Vector(4, u64) = @intCast(row);
            totals += @as(@Vector(4, u64), @splat(frequency)) * widened;
        }
        const values: [4]u64 = totals;
        for (values, 0..) |cost, lane| {
            if (cost < best.cost) best = .{ .tree = tree + lane, .cost = cost };
        }
    }
    while (tree < tree_count) : (tree += 1) {
        var cost: u64 = 0;
        for (sparse.symbols[0..sparse.len], sparse.frequencies[0..sparse.len]) |symbol, frequency|
            cost += @as(u64, frequency) * costs[@as(usize, symbol) * stride + tree];
        if (cost < best.cost) best = .{ .tree = tree, .cost = cost };
    }
    return best;
}
