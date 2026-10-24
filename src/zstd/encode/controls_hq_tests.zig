const std = @import("std");
const controls = @import("controls.zig");
const HqOptions = controls.HqOptions;

const Native = struct {
    content_checksum: bool = true,
    include_content_size: bool = true,
    window_log: ?u6 = null,
    max_match_history_len: ?usize = null,
    strategy: controls.Strategy = .auto,
    fast_acceleration: ?u32 = null,
    control_profile: ?*controls.Profile = null,
    hq: ?HqOptions = null,
    selection: enum { auto, fast_compressed, raw_or_rle, compressed } = .auto,
    match_search_budget: usize = controls.legacy_search_budget,
    rep_beam_search: bool = false,
};

test "Zstd HQ controls bounds and enum preserve legacy scalar contracts without heap" {
    const failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    const defaults: HqOptions = .{};
    try defaults.validate();
    try std.testing.expectEqual(@as(u32, 64), defaults.search_depth);
    try std.testing.expectEqual(@as(u32, 128), defaults.nice_len);
    try std.testing.expectEqual(@as(u8, 3), defaults.min_match);
    try std.testing.expectEqual(std.math.maxInt(usize), defaults.max_working_memory);
    try (HqOptions{ .search_depth = 1, .nice_len = 7, .min_match = 7, .max_working_memory = 0 }).validate();
    try (HqOptions{ .search_depth = 65536, .nice_len = 131072 }).validate();
    for ([_]HqOptions{
        .{ .search_depth = 0 },             .{ .search_depth = 65537 }, .{ .nice_len = 2 },
        .{ .nice_len = 131073 },            .{ .min_match = 2 },        .{ .min_match = 8 },
        .{ .nice_len = 3, .min_match = 4 },
    }) |invalid| try std.testing.expectError(error.InvalidBlockPlan, invalid.validate());
    inline for (.{ controls.Strategy.auto, .fast, .double_fast, .greedy, .lazy, .optimal, .lazy2, .btlazy2, .btopt, .btultra, .btultra2 }, 0..) |strategy, index| {
        const typed: controls.Strategy = strategy;
        try std.testing.expectEqual(@as(usize, index), @as(usize, @intFromEnum(typed)));
    }
    try std.testing.expectEqual(@as(usize, 0), failing.allocated_bytes);
}

test "Zstd HQ controls resolve dedicated defaults and explicit overrides without mutating profile" {
    var profile: controls.Profile = .{ .tree_nodes = 9, .compressed_blocks = 2, .peak_working_memory = 4096 };
    const before = profile;
    for ([_]controls.Strategy{ .lazy2, .btlazy2, .btopt, .btultra, .btultra2 }) |strategy| {
        const low = try controls.resolve(Native, 1, Native{ .strategy = strategy, .control_profile = &profile });
        const high = try controls.resolve(Native, 22, Native{ .strategy = strategy });
        try std.testing.expectEqual(strategy, low.strategy);
        try std.testing.expectEqual(.fast_compressed, low.selection);
        try std.testing.expectEqual(controls.legacy_search_budget, low.match_search_budget);
        try std.testing.expect(!low.rep_beam_search);
        try std.testing.expectEqualDeep(try controls.resolvedHqDefaults(strategy, 1), low.hq.?);
        try std.testing.expect(high.hq.?.search_depth >= low.hq.?.search_depth);
        try std.testing.expect(high.hq.?.nice_len >= low.hq.?.nice_len);
        const native_defaults = try controls.effectiveHq(Native{ .strategy = strategy });
        try std.testing.expectEqualDeep(try controls.resolvedHqDefaults(strategy, null), native_defaults.?);
        const explicit: HqOptions = .{ .search_depth = 123, .nice_len = 345, .min_match = 4, .max_working_memory = 6789 };
        const resolved = try controls.resolve(Native, 9, Native{ .strategy = strategy, .hq = explicit, .control_profile = &profile });
        try std.testing.expectEqualDeep(explicit, resolved.hq.?);
        try std.testing.expectEqualDeep(explicit, (try controls.effectiveHq(resolved)).?);
    }
    try std.testing.expectEqualDeep(before, profile);
    const lazy = try controls.resolvedHqDefaults(.lazy2, 3);
    const tree = try controls.resolvedHqDefaults(.btlazy2, 3);
    const optimal = try controls.resolvedHqDefaults(.btopt, 3);
    const ultra = try controls.resolvedHqDefaults(.btultra, 3);
    const ultra2 = try controls.resolvedHqDefaults(.btultra2, 3);
    try std.testing.expect(lazy.search_depth < tree.search_depth);
    try std.testing.expect(tree.search_depth < optimal.search_depth);
    try std.testing.expect(optimal.search_depth < ultra.search_depth);
    try std.testing.expect(ultra.search_depth < ultra2.search_depth);
}

test "Zstd HQ controls reject old strategy conflicts signed levels raw mode and ignored knobs" {
    var profile: controls.Profile = .{ .hq_passes = 8, .raw_blocks = 1 };
    const before = profile;
    for ([_]controls.Strategy{ .auto, .fast, .double_fast, .greedy, .lazy, .optimal }) |strategy| {
        const invalid: Native = .{ .strategy = strategy, .hq = .{}, .control_profile = &profile };
        try std.testing.expectError(error.InvalidBlockPlan, controls.validateNative(invalid));
        try std.testing.expectError(error.InvalidBlockPlan, controls.resolve(Native, 3, invalid));
    }
    for ([_]c_int{ std.math.minInt(c_int), -131073, -131072, -1, 0, 23, std.math.maxInt(c_int) }) |level| {
        try std.testing.expectError(error.InvalidBlockPlan, controls.resolve(Native, level, Native{ .strategy = .btopt }));
    }
    for ([_]Native{
        .{ .strategy = .btopt, .fast_acceleration = 1 },
        .{ .strategy = .btopt, .selection = .raw_or_rle },
        .{ .strategy = .btopt, .selection = .compressed },
        .{ .strategy = .btopt, .rep_beam_search = true },
        .{ .strategy = .btopt, .match_search_budget = 0 },
        .{ .strategy = .btopt, .match_search_budget = 513 },
        .{ .strategy = .btopt, .hq = .{ .search_depth = 0 } },
    }) |invalid| try std.testing.expectError(error.InvalidBlockPlan, controls.validateNative(invalid));
    try std.testing.expectEqualDeep(before, profile);
    try std.testing.expectError(error.InvalidBlockPlan, controls.resolvedHqDefaults(.auto, 3));
    try std.testing.expectError(error.InvalidBlockPlan, controls.resolvedHqDefaults(.btopt, 0));
}

test "Zstd HQ controls legacy auto levels and explicit old controls retain parameter schedules" {
    const levels = [_]c_int{ 0, 1, 2, 3, 4, 5, 6, 9, 22 };
    const budgets = [_]usize{ 0, 16, 32, 64, 96, 128, 96, 96, 96 };
    for (levels, budgets) |level, budget| {
        const native = try controls.resolve(Native, level, Native{});
        try std.testing.expectEqual(controls.Strategy.auto, native.strategy);
        try std.testing.expectEqual(budget, native.match_search_budget);
        try std.testing.expect(native.hq == null);
        try std.testing.expect(!controls.active(native));
    }
    const negative = try controls.resolve(Native, -8, Native{});
    try std.testing.expectEqual(controls.Strategy.fast, negative.strategy);
    try std.testing.expectEqual(@as(u32, 8), negative.fast_acceleration.?);
    try std.testing.expectEqual(controls.legacy_search_budget, negative.match_search_budget);
    const old = try controls.resolve(Native, 3, Native{ .strategy = .optimal });
    try std.testing.expect(old.hq == null);
    try std.testing.expectEqual(@as(usize, 64), old.match_search_budget);
}

test "Zstd HQ controls profile merge saturates work and takes max peaks while emissions roll back" {
    var profile: controls.Profile = .{ .tree_nodes = std.math.maxInt(u64) - 1, .peak_working_memory = 900, .compressed_blocks = 2, .max_distance = 30 };
    const emission = controls.EmissionTransaction.init(&profile);
    profile.add("tree_nodes", 10);
    profile.add("byte_comparisons", 20);
    profile.add("hq_passes", 2);
    profile.add("refinement_passes", 1);
    profile.add("compressed_blocks", 3);
    profile.max_distance = 100;
    profile.recordPeakWorkingMemory(1000);
    emission.rollback();
    try std.testing.expectEqual(std.math.maxInt(u64), profile.tree_nodes);
    try std.testing.expectEqual(@as(u64, 20), profile.byte_comparisons);
    try std.testing.expectEqual(@as(u64, 2), profile.compressed_blocks);
    try std.testing.expectEqual(@as(usize, 30), profile.max_distance);
    var other: controls.Profile = .{ .available = true, .controls_used = true, .resolved_strategy = .btultra2, .tree_nodes = 10, .byte_comparisons = 5, .depth_stops = 3, .nice_stops = 4, .price_evaluations = 7, .hq_passes = 2, .refinement_passes = 1, .shared_seed_reuses = 2, .peak_working_memory = 2000, .compressed_blocks = 9, .max_distance = 999 };
    other.recordEffectiveHq(.{ .search_depth = 256, .nice_len = 512, .min_match = 4, .max_working_memory = 3000 });
    profile.mergeWork(other);
    try std.testing.expectEqual(@as(usize, 2000), profile.peak_working_memory);
    try std.testing.expectEqual(@as(u64, 25), profile.byte_comparisons);
    try std.testing.expectEqual(@as(u64, 4), profile.hq_passes);
    try std.testing.expectEqual(@as(u64, 2), profile.refinement_passes);
    try std.testing.expectEqual(@as(u64, 2), profile.compressed_blocks);
    try std.testing.expectEqual(@as(usize, 30), profile.max_distance);
    try std.testing.expectEqual(@as(u32, 256), profile.effective_hq_search_depth);
    profile.mergeEmitted(other.emitted());
    try std.testing.expectEqual(@as(u64, 11), profile.compressed_blocks);
    try std.testing.expectEqual(@as(usize, 999), profile.max_distance);
    profile.merge(.{ .controls_used = true, .resolved_strategy = .fast, .peak_working_memory = 1 });
    try std.testing.expectEqual(@as(usize, 2000), profile.peak_working_memory);
    try std.testing.expect(!profile.hq_used);
    profile.reset();
    try std.testing.expectEqualDeep(controls.Profile{}, profile);
}
