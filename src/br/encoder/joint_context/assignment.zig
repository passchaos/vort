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

/// Sparse symbol list for one context. The counts themselves stay in the
/// histogram, so repeated assignment passes reuse one scan per context instead
/// of rescanning all 256 bins for every tree-count/seed/iteration candidate.
pub const SparseView = struct {
    symbols: [256]u8 = undefined,
    len: usize = 0,
};

pub fn sparseView(context: *const Histogram) SparseView {
    var result: SparseView = .{};
    for (&context.counts, 0..) |frequency, symbol| {
        if (frequency == 0) continue;
        result.symbols[result.len] = @intCast(symbol);
        result.len += 1;
    }
    return result;
}

pub fn chooseGroupedView(context: *const Histogram, sparse: *const SparseView, costs: []const u16, tree_count: usize, stride: usize) Choice {
    std.debug.assert(tree_count != 0 and tree_count <= stride and stride <= 256);
    std.debug.assert(costs.len == 256 * stride);
    var best: Choice = .{ .tree = 0, .cost = std.math.maxInt(u64) };
    var tree: usize = 0;
    while (tree + 4 <= tree_count) : (tree += 4) {
        var totals: @Vector(4, u64) = @splat(0);
        for (sparse.symbols[0..sparse.len]) |symbol| {
            const frequency: u32 = context.counts[symbol];
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
        for (sparse.symbols[0..sparse.len]) |symbol|
            cost += @as(u64, context.counts[symbol]) * costs[@as(usize, symbol) * stride + tree];
        if (cost < best.cost) best = .{ .tree = tree, .cost = cost };
    }
    return best;
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

test "sparse view assignment matches the histogram scan" {
    var histogram: Histogram = .{};
    var state: u32 = 0x9e3779b9;
    for (0..256) |symbol| {
        state = state *% 1664525 +% 1013904223;
        const count: u32 = (state >> 16) % 11;
        histogram.counts[symbol] = count;
        histogram.total += count;
    }
    var trees: [8]Histogram = @splat(.{});
    for (&trees, 0..) |*tree, tree_index| {
        for (0..256) |symbol| {
            state = state *% 1664525 +% 1013904223;
            const count: u32 = (state >> 13) % 17 + @as(u32, @intCast((symbol + tree_index) % 3));
            tree.counts[symbol] = count;
            tree.total += count;
        }
    }
    var costs: [8 * 256]u16 = undefined;
    prepare(trees[0..8], &costs, 8);
    const view = sparseView(&histogram);
    for ([_]usize{ 2, 3, 4, 7, 8 }) |tree_count| {
        const expected = chooseGrouped(&histogram, costs[0 .. tree_count * 256], tree_count, tree_count);
        const actual = chooseGroupedView(&histogram, &view, costs[0 .. tree_count * 256], tree_count, tree_count);
        try std.testing.expectEqual(expected, actual);
    }
}
