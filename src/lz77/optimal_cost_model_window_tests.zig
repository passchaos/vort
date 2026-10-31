const std = @import("std");
const lz77 = @import("../lz77.zig");

test "modeled optimal window must fit token distance even with complete prices" {
    const input = "abcdefghijklmnop";
    const literal: [256]u16 = @splat(1);
    const length: [lz77.max_match_len + 1]u16 = @splat(1);
    const distances = try std.testing.allocator.alloc(u16, lz77.max_window_len + 2);
    defer std.testing.allocator.free(distances);
    @memset(distances, 1);
    const model: lz77.OptimalCostModel = .{
        .literal = &literal,
        .length = &length,
        .distance = distances,
    };
    const invalid: lz77.GreedyOptions = .{ .window_len = lz77.max_window_len + 1 };
    try std.testing.expectError(error.InvalidBlockPlan, lz77.optimalPlanAllocWithCostModel(std.testing.allocator, input, invalid, model));
    var scratch: lz77.OptimalScratch = .{};
    defer scratch.deinit(std.testing.allocator);
    try std.testing.expectError(error.InvalidBlockPlan, lz77.optimalPlanReuseWithCostModel(&scratch, std.testing.allocator, input, invalid, model));
    var prepared = try lz77.PreparedOptimal.init(std.testing.allocator, input, invalid);
    defer prepared.deinit(std.testing.allocator);
    try std.testing.expectError(error.InvalidBlockPlan, prepared.planModeledAlloc(std.testing.allocator, model));

    // The full u16 window remains accepted. This short input has no copies,
    // so acceptance does not depend on reaching a narrowing cast in the loop.
    const valid: lz77.GreedyOptions = .{ .window_len = lz77.max_window_len };
    const plan = try lz77.optimalPlanAllocWithCostModel(std.testing.allocator, input, valid, model);
    defer plan.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 0), plan.stats.matches);
    try std.testing.expectEqual(input.len, plan.stats.literals);
    const replay = try lz77.replayAlloc(std.testing.allocator, plan.tokens);
    defer std.testing.allocator.free(replay);
    try std.testing.expectEqualStrings(input, replay);
}
