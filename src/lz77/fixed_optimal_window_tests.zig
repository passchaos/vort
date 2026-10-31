const std = @import("std");
const lz77 = @import("../lz77.zig");

const Snapshot = struct {
    costs: []usize,
    steps: []lz77.Token,
    tokens: []lz77.Token,
    pointers: [4]usize,
    lengths: [4]usize,
    capacities: [4]usize,

    fn capture(scratch: *const lz77.OptimalScratch) !Snapshot {
        const allocator = std.testing.allocator;
        const costs = try allocator.dupe(usize, scratch.costs.items);
        errdefer allocator.free(costs);
        const steps = try allocator.dupe(lz77.Token, scratch.steps.items);
        errdefer allocator.free(steps);
        const tokens = try allocator.dupe(lz77.Token, scratch.tokens.items);
        return .{
            .costs = costs,
            .steps = steps,
            .tokens = tokens,
            .pointers = .{ @intFromPtr(scratch.costs.items.ptr), @intFromPtr(scratch.steps.items.ptr), @intFromPtr(scratch.tokens.items.ptr), @intFromPtr(scratch.compact_prev.items.ptr) },
            .lengths = .{ scratch.costs.items.len, scratch.steps.items.len, scratch.tokens.items.len, scratch.compact_prev.items.len },
            .capacities = .{ scratch.costs.capacity, scratch.steps.capacity, scratch.tokens.capacity, scratch.compact_prev.capacity },
        };
    }

    fn deinit(self: Snapshot) void {
        std.testing.allocator.free(self.costs);
        std.testing.allocator.free(self.steps);
        std.testing.allocator.free(self.tokens);
    }

    fn expectUnchanged(self: Snapshot, scratch: *const lz77.OptimalScratch) !void {
        try std.testing.expectEqualSlices(usize, self.costs, scratch.costs.items);
        try std.testing.expectEqualSlices(lz77.Token, self.steps, scratch.steps.items);
        try std.testing.expectEqualSlices(lz77.Token, self.tokens, scratch.tokens.items);
        const pointers = [_]usize{ @intFromPtr(scratch.costs.items.ptr), @intFromPtr(scratch.steps.items.ptr), @intFromPtr(scratch.tokens.items.ptr), @intFromPtr(scratch.compact_prev.items.ptr) };
        const lengths = [_]usize{ scratch.costs.items.len, scratch.steps.items.len, scratch.tokens.items.len, scratch.compact_prev.items.len };
        const capacities = [_]usize{ scratch.costs.capacity, scratch.steps.capacity, scratch.tokens.capacity, scratch.compact_prev.capacity };
        try std.testing.expectEqualSlices(usize, &self.pointers, &pointers);
        try std.testing.expectEqualSlices(usize, &self.lengths, &lengths);
        try std.testing.expectEqualSlices(usize, &self.capacities, &capacities);
    }
};

test "fixed optimal window rejects unsupported options before any allocation" {
    for ([_]usize{ lz77.default_window_len + 1, lz77.max_window_len, lz77.max_window_len + 1, std.math.maxInt(usize) }) |window| {
        for ([_][]const u8{ "", "a", "abcdefghabcdefgh" }) |input| {
            var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
            const allocator = failing.allocator();
            const options: lz77.GreedyOptions = .{ .window_len = window };
            try std.testing.expectError(error.InvalidBlockPlan, lz77.optimalPlanAlloc(allocator, input, options));
            var scratch: lz77.OptimalScratch = .{};
            defer scratch.deinit(allocator);
            try std.testing.expectError(error.InvalidBlockPlan, lz77.optimalPlanReuse(&scratch, allocator, input, options));
            var profile: lz77.OptimalSearchProfile = .{};
            try std.testing.expectError(error.InvalidBlockPlan, lz77.optimalPlanAllocProfiled(allocator, input, options, std.testing.io, &profile));
            try std.testing.expectError(error.InvalidBlockPlan, lz77.optimalPlanReuseProfiled(&scratch, allocator, input, options, std.testing.io, &profile));
            try std.testing.expectEqual(@as(usize, 0), failing.alloc_index);
            try std.testing.expectEqual(@as(usize, 0), failing.resize_index);
        }
    }
}

test "fixed optimal window rejection preserves reusable and prepared initialized state" {
    const input = "abcdefghijklmnopabcdefghijklmnop" ** 8;
    const options: lz77.GreedyOptions = .{ .window_len = lz77.default_window_len };
    var scratch: lz77.OptimalScratch = .{};
    defer scratch.deinit(std.testing.allocator);
    const expected_stats = try lz77.optimalPlanReuse(&scratch, std.testing.allocator, input, options);
    const snapshot = try Snapshot.capture(&scratch);
    defer snapshot.deinit();
    var prepared = try lz77.PreparedOptimal.init(std.testing.allocator, input, options);
    defer prepared.deinit(std.testing.allocator);
    const seed = try prepared.planFixedAlloc(std.testing.allocator);
    defer seed.deinit(std.testing.allocator);
    const prepared_snapshot = try Snapshot.capture(&prepared.scratch);
    defer prepared_snapshot.deinit();
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    for ([_]usize{ lz77.default_window_len + 1, lz77.max_window_len, std.math.maxInt(usize) }) |window| {
        var invalid = options;
        invalid.window_len = window;
        try std.testing.expectError(error.InvalidBlockPlan, lz77.optimalPlanReuse(&scratch, failing.allocator(), input, invalid));
        var profile: lz77.OptimalSearchProfile = .{};
        try std.testing.expectError(error.InvalidBlockPlan, lz77.optimalPlanReuseProfiled(&scratch, failing.allocator(), input, invalid, std.testing.io, &profile));
        try snapshot.expectUnchanged(&scratch);
        prepared.options = invalid;
        try std.testing.expectError(error.InvalidBlockPlan, prepared.planFixedAlloc(failing.allocator()));
        try prepared_snapshot.expectUnchanged(&prepared.scratch);
    }
    try std.testing.expectEqual(@as(usize, 0), failing.alloc_index);
    try std.testing.expectEqual(@as(usize, 0), failing.resize_index);
    try std.testing.expectEqualDeep(expected_stats, try lz77.optimalPlanReuse(&scratch, std.testing.allocator, input, options));
    try snapshot.expectUnchanged(&scratch);
    prepared.options = options;
    const retry = try prepared.planFixedAlloc(std.testing.allocator);
    defer retry.deinit(std.testing.allocator);
    try std.testing.expectEqualSlices(lz77.Token, seed.tokens, retry.tokens);
    try std.testing.expectEqualDeep(seed.stats, retry.stats);
}

test "fixed optimal zero and maximum windows replay while prepared wide modeled remains supported" {
    const input = "abcdefghabcdefghabcdefgh";
    for ([_]usize{ 0, 1, lz77.default_window_len }) |window| {
        const plan = try lz77.optimalPlanAlloc(std.testing.allocator, input, .{ .window_len = window });
        defer plan.deinit(std.testing.allocator);
        const replay = try lz77.replayAlloc(std.testing.allocator, plan.tokens);
        defer std.testing.allocator.free(replay);
        try std.testing.expectEqualStrings(input, replay);
        if (window <= 1) try std.testing.expectEqual(@as(usize, 0), plan.stats.matches);
    }
    const literal: [256]u16 = @splat(8);
    const lengths: [lz77.max_match_len + 1]u16 = @splat(1);
    const distances = try std.testing.allocator.alloc(u16, lz77.max_window_len + 1);
    defer std.testing.allocator.free(distances);
    @memset(distances, 1);
    const model: lz77.OptimalCostModel = .{ .literal = &literal, .length = &lengths, .distance = distances };
    var wide = try lz77.PreparedOptimal.init(std.testing.allocator, input, .{ .window_len = lz77.max_window_len });
    defer wide.deinit(std.testing.allocator);
    const modeled = try wide.planModeledAlloc(std.testing.allocator, model);
    defer modeled.deinit(std.testing.allocator);
    const snapshot = try Snapshot.capture(&wide.scratch);
    defer snapshot.deinit();
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.InvalidBlockPlan, wide.planFixedAlloc(failing.allocator()));
    try snapshot.expectUnchanged(&wide.scratch);
    try std.testing.expectEqual(@as(usize, 0), failing.alloc_index);
    const replay = try lz77.replayAlloc(std.testing.allocator, modeled.tokens);
    defer std.testing.allocator.free(replay);
    try std.testing.expectEqualStrings(input, replay);
}
