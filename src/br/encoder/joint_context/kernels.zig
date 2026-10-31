//! Exact kernels for validated joint literal-context histograms.
const std = @import("std");
const Histogram = @import("../histogram_model.zig").Histogram(256);

pub fn assignmentCost(context: *const Histogram, costs: *const [256]u16) u64 {
    // 256 * max(u32) * max(u16) is below 2^56; saturation cannot occur.
    var result: u64 = 0;
    for (&context.counts, costs) |frequency, cost|
        result += @as(u64, frequency) * cost;
    return result;
}

/// The contexts are a disjoint partition with this total population. Trees
/// and contexts are disjoint allocations. Larger populations retain the
/// original checked merge rather than relying on a u32 population bound.
pub fn aggregateTrees(contexts: []const Histogram, assignment: []const u8, tree_count: usize, trees: []Histogram, literal_count: usize) void {
    if (literal_count > std.math.maxInt(u32)) {
        for (trees[0..tree_count]) |*tree| tree.* = Histogram.init();
        for (contexts, assignment) |*context, tree| {
            if (context.total != 0) trees[tree].addHistogram(context) catch unreachable;
        }
        return;
    }
    // A nonempty context makes total positive, so zero marks an unused tree.
    // The first contribution overwrites every count instead of adding to zeros.
    for (trees[0..tree_count]) |*tree| tree.total = 0;
    for (contexts, assignment) |*context, tree| {
        if (context.total == 0) continue;
        if (trees[tree].total == 0) {
            trees[tree] = context.*;
        } else {
            for (&trees[tree].counts, &context.counts) |*count, value| count.* += value;
            trees[tree].total += context.total;
        }
    }
    // Empty requested trees still return fully initialized histograms.
    for (trees[0..tree_count]) |*tree| if (tree.total == 0) {
        tree.* = Histogram.init();
    };
}

test {
    _ = @import("kernels_tests.zig");
}
