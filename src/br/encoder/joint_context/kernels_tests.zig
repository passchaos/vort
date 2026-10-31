const std = @import("std");
const kernels = @import("kernels.zig");
const Histogram = @import("../histogram_model.zig").Histogram(256);

fn referenceDot(histogram: *const Histogram, costs: *const [256]u16) u64 {
    var result: u64 = 0;
    for (0..256) |symbol| result +|= @as(u64, histogram.counts[symbol]) * costs[symbol];
    return result;
}

test "joint kernels immutable score preserves exact extreme and sparse sums" {
    var histogram: Histogram = .{};
    var costs: [256]u16 = undefined;
    var random: u32 = 0x98271634;
    for (0..48) |seed| {
        for (&histogram.counts, &costs, 0..) |*frequency, *cost, symbol| {
            random = random *% 1664525 +% 1013904223;
            frequency.* = if (symbol % (seed + 1) == 0) random else 0;
            random = random *% 1664525 +% 1013904223;
            cost.* = @truncate(random >> 13);
        }
        const before = histogram;
        const prices = costs;
        try std.testing.expectEqual(referenceDot(&histogram, &costs), kernels.assignmentCost(&histogram, &costs));
        try std.testing.expectEqualDeep(before, histogram);
        try std.testing.expectEqualSlices(u16, &prices, &costs);
    }
    histogram.counts = @splat(std.math.maxInt(u32));
    costs = @splat(std.math.maxInt(u16));
    const maximum = @as(u64, 256) * std.math.maxInt(u32) * std.math.maxInt(u16);
    try std.testing.expectEqual(maximum, kernels.assignmentCost(&histogram, &costs));
}

fn compareMerge(contexts: []const Histogram, assignment: []const u8, count: usize, total: usize) !void {
    var actual: [256]Histogram = undefined;
    var expected: [256]Histogram = undefined;
    @memset(expected[0..count], .{});
    for (contexts, assignment) |*context, tree| {
        if (context.total == 0) continue;
        try expected[tree].addHistogram(context);
    }
    kernels.aggregateTrees(contexts, assignment, count, &actual, total);
    try std.testing.expectEqualDeep(expected[0..count], actual[0..count]);
}

test "joint kernels disjoint partition merge matches checked sums and u32 boundary" {
    var contexts: [8]Histogram = @splat(.{});
    const assignment = [_]u8{ 0, 1, 0, 3, 1, 3, 0, 255 };
    var total: usize = 0;
    for (&contexts, 0..) |*context, index| {
        try context.addCount(index * 17, @intCast(index * 23));
        total += @intCast(context.total);
    }
    try compareMerge(&contexts, &assignment, 256, total);
    contexts = @splat(.{});
    try contexts[0].addCount(0, std.math.maxInt(u32) - 20);
    try contexts[0].addCount(1, 7);
    try contexts[2].addCount(0, 13);
    try compareMerge(&contexts, &assignment, 256, std.math.maxInt(u32));
    if (comptime @bitSizeOf(usize) > 32) {
        contexts = @splat(.{});
        try contexts[0].addCount(0, std.math.maxInt(u32));
        try contexts[2].addCount(1, std.math.maxInt(u32));
        try compareMerge(&contexts, &assignment, 256, @as(usize, std.math.maxInt(u32)) * 2);
    }
}

test {
    _ = @import("assignment_tests.zig");
    _ = @import("initialization_tests.zig");
}
