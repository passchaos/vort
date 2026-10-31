const std = @import("std");
const lz = @import("../lz77.zig");

test "modeled optimal zero window validates prices and returns literal-only plans" {
    const a = std.testing.allocator;
    const literals: [256]u16 = @splat(8);
    const lengths: [259]u16 = @splat(7);
    const unused = [_]u16{0};
    const model: lz.OptimalCostModel = .{ .literal = &literals, .length = &lengths, .distance = &unused };
    var scratch: lz.OptimalScratch = .{};
    defer scratch.deinit(a);
    for ([_][]const u8{ "", "x", "abcabcabcabc" }) |input| {
        const options: lz.GreedyOptions = .{ .window_len = 0 };
        const plan = try lz.optimalPlanAllocWithCostModel(a, input, options, model);
        defer plan.deinit(a);
        try std.testing.expectEqual(@as(usize, 0), plan.stats.matches);
        try std.testing.expectEqual(input.len, plan.stats.literals);
        const bytes = try lz.replayAlloc(a, plan.tokens);
        defer a.free(bytes);
        try std.testing.expectEqualSlices(u8, input, bytes);
        const reused = try lz.optimalPlanReuseWithCostModel(&scratch, a, input, options, model);
        try std.testing.expectEqualDeep(plan.stats, reused);
        try std.testing.expectEqualSlices(lz.Token, plan.tokens, scratch.tokens.items);
        var prepared = try lz.PreparedOptimal.init(a, input, options);
        defer prepared.deinit(a);
        const staged = try prepared.planModeledAlloc(a, model);
        defer staged.deinit(a);
        try std.testing.expectEqualDeep(plan.stats, staged.stats);
        try std.testing.expectEqualSlices(lz.Token, plan.tokens, staged.tokens);
    }
    var invalid = model;
    invalid.distance = &.{};
    try std.testing.expectError(error.InvalidBlockPlan, lz.optimalPlanAllocWithCostModel(a, "", .{ .window_len = 0 }, invalid));
    var invalid_literals = literals;
    invalid_literals[0] = 0;
    invalid = model;
    invalid.literal = &invalid_literals;
    try std.testing.expectError(error.InvalidBlockPlan, lz.optimalPlanAllocWithCostModel(a, "", .{ .window_len = 0 }, invalid));
}
