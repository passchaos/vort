const std = @import("std");
const kernels = @import("kernels.zig");
const Histogram = @import("../histogram_model.zig").Histogram(256);
const allocator = std.testing.allocator;

fn poisoned(index: usize) Histogram {
    var result: Histogram = undefined;
    for (&result.counts, 0..) |*count, symbol|
        count.* = 0xa5a5a5a5 ^ @as(u32, @intCast(index * 257 + symbol));
    result.total = 0xfedcba9876543210 ^ @as(u64, @intCast(index));
    return result;
}

fn checkedReference(contexts: []const Histogram, assignment: []const u8, tree_count: usize, trees: []Histogram) !void {
    for (trees[0..tree_count]) |*tree| tree.* = Histogram.init();
    for (contexts, assignment) |*context, tree| {
        if (context.total != 0) try trees[tree].addHistogram(context);
    }
}

fn expectTrees(expected: []const Histogram, actual: []const Histogram) !void {
    for (expected, actual) |left, right| {
        try std.testing.expectEqualSlices(u32, &left.counts, &right.counts);
        try std.testing.expectEqual(left.total, right.total);
    }
}

fn compare(contexts: []const Histogram, assignment: []const u8, tree_count: usize, population: usize) !void {
    var total: u64 = 0;
    for (contexts, assignment) |context, tree| {
        try std.testing.expect(tree < tree_count);
        // Collection may leave stale bins in its private lazy-empty contexts.
        // Only nonempty sources require exact bins; aggregation skips the rest.
        if (context.total == 0) continue;
        var sum: u64 = 0;
        for (context.counts) |count| sum += count;
        try std.testing.expectEqual(sum, context.total);
        total += sum;
    }
    try std.testing.expectEqual(@as(u64, @intCast(population)), total);
    const frozen = try allocator.dupe(Histogram, contexts);
    defer allocator.free(frozen);
    const frozen_assignment = try allocator.dupe(u8, assignment);
    defer allocator.free(frozen_assignment);
    const expected = try allocator.alloc(Histogram, tree_count + 2);
    defer allocator.free(expected);
    const actual = try allocator.alloc(Histogram, expected.len);
    defer allocator.free(actual);
    for (expected, actual, 0..) |*left, *right, index| {
        left.* = poisoned(index);
        right.* = poisoned(index);
    }

    try checkedReference(contexts, assignment, tree_count, expected);
    kernels.aggregateTrees(contexts, assignment, tree_count, actual, population);
    try expectTrees(expected, actual);
    // The same caller-owned storage must be reusable without clearing counts.
    kernels.aggregateTrees(contexts, assignment, tree_count, actual, population);
    try expectTrees(expected, actual);

    const reassigned = try allocator.alloc(u8, assignment.len);
    defer allocator.free(reassigned);
    for (assignment, reassigned) |tree, *destination|
        destination.* = @intCast((@as(usize, tree) + tree_count - 1) % tree_count);
    try checkedReference(contexts, reassigned, tree_count, expected);
    kernels.aggregateTrees(contexts, reassigned, tree_count, actual, population);
    try expectTrees(expected, actual);
    try std.testing.expectEqualDeep(frozen, contexts);
    try std.testing.expectEqualSlices(u8, frozen_assignment, assignment);
    // Both comparison arrays retain poison beyond the requested tree slice.
    for (tree_count..actual.len) |index|
        try expectTrees(&.{poisoned(index)}, actual[index..][0..1]);
}

test "joint initialization preserves every tree count empty poison and reassigned storage" {
    var contexts: [12]Histogram = undefined;
    var assignment: [12]u8 = undefined;
    for (1..257) |tree_count| {
        for (0..3) |density| for (0..3) |mode| {
            @memset(&contexts, Histogram.init());
            var population: usize = 0;
            for (&contexts, &assignment, 0..) |*context, *tree, index| {
                tree.* = @intCast(switch (mode) {
                    0 => index % tree_count,
                    1 => tree_count - 1,
                    else => (index * 73 + 19) % tree_count,
                });
                if (density == 0 or (density == 1 and index != 7)) continue;
                try context.addCount(index * 17, @intCast(index * 23 + 1));
                try context.addCount(255 - index, @intCast(index + 3));
                population += @intCast(context.total);
            }
            try compare(&contexts, &assignment, tree_count, population);
        };
    }
}

test "joint initialization preserves u32 population boundaries and large checked merges" {
    const maximum = std.math.maxInt(u32);
    for (1..257) |tree_count| {
        var contexts: [4]Histogram = @splat(.{});
        var assignment: [4]u8 = @splat(0);
        assignment[3] = @intCast(tree_count - 1);
        for ([_]usize{ 1, maximum - 1, maximum }) |population| {
            @memset(&contexts, Histogram.init());
            try contexts[0].addCount(0, @intCast(population / 3));
            try contexts[2].addCount(0, @intCast(population - population / 3));
            try compare(&contexts, &assignment, tree_count, population);
        }
        @memset(&contexts, Histogram.init());
        try contexts[0].addCount(0, maximum - 20);
        try contexts[0].addCount(1, 7);
        try contexts[2].addCount(0, 13);
        try compare(&contexts, &assignment, tree_count, maximum);
        if (comptime @bitSizeOf(usize) > 32) {
            @memset(&contexts, Histogram.init());
            try contexts[0].addCount(0, maximum);
            try contexts[2].addCount(1, 1);
            try compare(&contexts, &assignment, tree_count, @as(usize, maximum) + 1);
            try contexts[2].addCount(1, maximum - 1);
            try compare(&contexts, &assignment, tree_count, @as(usize, maximum) * 2);
            try contexts[3].addCount(255, maximum);
            try compare(&contexts, &assignment, tree_count, @as(usize, maximum) * 3);
        }
    }
}

test "joint initialization skips poisoned lazy empty contexts and returns initialized trees" {
    var contexts: [8]Histogram = undefined;
    var assignment: [8]u8 = undefined;
    for (1..257) |tree_count| {
        for (&contexts, &assignment, 0..) |*context, *tree, index| {
            context.* = poisoned(index);
            context.total = 0;
            tree.* = @intCast(index % tree_count);
        }
        // The all-empty case must not copy poisoned bins into any output.
        try compare(&contexts, &assignment, tree_count, 0);
        contexts[1] = Histogram.init();
        contexts[6] = Histogram.init();
        try contexts[1].addCount(17, 3);
        try contexts[6].addCount(17, 5);
        assignment[1] = 0;
        assignment[6] = @intCast(tree_count - 1);
        try compare(&contexts, &assignment, tree_count, 8);
    }
}
