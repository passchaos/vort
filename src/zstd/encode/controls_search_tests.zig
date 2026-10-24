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
    selection: enum { auto, fast_compressed, raw_or_rle } = .auto,
    match_search_budget: usize = controls.legacy_search_budget,
    rep_beam_search: bool = false,
};

test "Zstd HQ search options preserve defaults and reject unconsumed controls" {
    const defaults: HqOptions = .{};
    try std.testing.expectEqual(controls.HqParseMode.bounded, defaults.parse_mode);
    try std.testing.expectEqual(controls.HqMatchLengthPolicy.sampled, defaults.match_lengths);
    try std.testing.expectEqual(@as(?u64, null), defaults.max_price_evaluations);
    try std.testing.expect(!defaults.hasSearchControls());
    for ([_]HqOptions{
        .{ .parse_mode = .whole_block },
        .{ .match_lengths = .complete },
        .{ .max_price_evaluations = 0 },
        .{ .max_price_evaluations = std.math.maxInt(u64) },
    }) |selected| {
        try selected.validate();
        try std.testing.expect(selected.hasSearchControls());
        for ([_]controls.Strategy{ .btopt, .btultra, .btultra2 }) |strategy| {
            const options: Native = .{ .strategy = strategy, .hq = selected };
            const resolved = try controls.resolve(Native, 22, options);
            try std.testing.expectEqualDeep(selected, resolved.hq.?);
            try std.testing.expectEqualDeep(selected, (try controls.effectiveHq(options)).?);
        }
        for ([_]controls.Strategy{ .lazy2, .btlazy2 }) |strategy| {
            const options: Native = .{ .strategy = strategy, .hq = selected };
            try std.testing.expectError(error.InvalidBlockPlan, controls.validateNative(options));
            try std.testing.expectError(error.InvalidBlockPlan, controls.effectiveHq(options));
            try std.testing.expectError(error.InvalidBlockPlan, controls.resolve(Native, 22, options));
        }
    }
    for ([_]controls.Strategy{ .lazy2, .btlazy2 }) |strategy|
        try controls.validateNative(Native{ .strategy = strategy, .hq = .{} });
}

test "Zstd HQ search profiles separate actual work maxima from emitted safeguards" {
    const max = std.math.maxInt(u64);
    var profile: controls.Profile = .{ .whole_block_passes = max - 1, .price_evaluations = max - 1 };
    const options: HqOptions = .{ .parse_mode = .whole_block, .match_lengths = .complete, .max_price_evaluations = 7 };
    profile.recordEffectiveHq(options);
    profile.recordHqSearch(options, 131072);
    // Starting a plan does not report its allocated position capacity as work.
    try std.testing.expectEqual(@as(usize, 0), profile.max_parse_positions);
    profile.recordParsePositions(11);
    profile.recordMatchLengthConsidered(75);
    profile.recordMaxPlanPrice(7);
    profile.add("price_evaluations", 3);
    const transaction = controls.EmissionTransaction.init(&profile);
    profile.add("baseline_searches", 1);
    profile.add("guarded_frames", 1);
    profile.add("price_limit_refusals", 1);
    profile.add("baseline_selected_frames", 1);
    profile.add("baseline_selected_blocks", 1);
    profile.add("compressed_blocks", 1);
    transaction.rollback();
    try std.testing.expectEqual(@as(u64, 0), profile.baseline_selected_frames);
    try std.testing.expectEqual(@as(u64, 0), profile.baseline_selected_blocks);
    try std.testing.expectEqual(@as(u64, 0), profile.compressed_blocks);
    try std.testing.expectEqual(@as(u64, 1), profile.price_limit_refusals);
    try std.testing.expectEqual(@as(u64, 1), profile.baseline_searches);
    var other: controls.Profile = .{};
    other.recordEffectiveHq(options);
    other.controls_used = true;
    other.recordHqSearch(options, 30);
    other.recordParsePositions(30);
    other.recordMatchLengthConsidered(80);
    other.recordMaxPlanPrice(6);
    other.baseline_selected_frames = 1;
    profile.mergeWork(other);
    try std.testing.expectEqual(@as(u64, 0), profile.baseline_selected_frames);
    try std.testing.expectEqual(max, profile.whole_block_passes);
    try std.testing.expectEqual(max, profile.price_evaluations);
    try std.testing.expectEqual(@as(usize, 30), profile.max_parse_positions);
    try std.testing.expectEqual(@as(usize, 80), profile.max_match_length_considered);
    try std.testing.expectEqual(@as(u64, 7), profile.max_plan_price_evaluations);
    try std.testing.expectEqual(@as(?u64, 7), profile.effective_hq_max_price_evaluations);
    profile.mergeEmitted(other.emitted());
    try std.testing.expectEqual(@as(u64, 1), profile.baseline_selected_frames);
    profile.reset();
    try std.testing.expectEqualDeep(controls.Profile{}, profile);
}
