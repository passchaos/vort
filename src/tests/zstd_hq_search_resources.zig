const std = @import("std");
const zstd = @import("../zstd.zig");
const parser = @import("../zstd/match/hq_parser.zig");
const h = @import("zstd_hq_search_helpers.zig");
const a = std.testing.allocator;

test "Zstd HQ search controls lazy engines reject unsupported expansion before allocation or output" {
    for ([_]zstd.Strategy{ .lazy2, .btlazy2 }) |strategy| {
        for ([_]zstd.HqOptions{
            .{ .parse_mode = .whole_block }, .{ .match_lengths = .complete }, .{ .max_price_evaluations = 0 },
        }) |hq| {
            var tracked = h.TrackingAllocator.init(a);
            tracked.fail_alloc_after = 0;
            const options: zstd.NativeFrameOptions = .{ .strategy = strategy, .hq = hq };
            try std.testing.expectError(error.InvalidBlockPlan, zstd.encodeNativeFrameWithOptionsAlloc(tracked.allocator(), h.plain, options));
            try std.testing.expectEqual(@as(usize, 0), tracked.alloc_attempts);
            var destination: [1024]u8 = @splat(0xa5);
            try std.testing.expectError(error.InvalidBlockPlan, zstd.encodeNativeFrameIntoSlice(a, h.plain, options, &destination));
            try h.untouched(&destination);
        }
    }
}

test "Zstd HQ search controls two legal offset prices enforce per DP quota independently of accumulated profile" {
    const source = parser.Source.init("abcd", "", "abc", 1024);
    var model: parser.EntropyModel = .{ .initialized = true };
    @memset(&model.literal_prices, 64 * 256);
    @memset(&model.ll_prices, 0);
    @memset(&model.ml_prices, 0);
    @memset(&model.of_prices, 0);
    var profile: zstd.EncoderControlProfile = .{};
    var parameters: parser.Parameters = .{ .strategy = .btopt, .entropy = &model, .hq_options = .{ .parse_mode = .whole_block, .match_lengths = .complete, .max_price_evaluations = 0 }, .profile = &profile };
    try std.testing.expectError(error.SearchLimitExceeded, parser.planAlloc(a, source, parameters));
    try std.testing.expectEqual(@as(u64, 0), profile.max_plan_price_evaluations);
    try std.testing.expectEqual(@as(u64, 0), profile.price_evaluations);
    try std.testing.expectEqual(@as(usize, 0), profile.max_match_length_considered);
    // With zero literals, repeat1 selects physical4; regular offBase7 is the
    // second and only other legal representation of this one three-byte match.
    parameters.hq_options.max_price_evaluations = 2;
    profile.reset();
    const first = try parser.planAlloc(a, source, parameters);
    defer first.deinit(a);
    try std.testing.expectEqual(@as(u64, 2), profile.max_plan_price_evaluations);
    try std.testing.expectEqual(@as(u64, 2), profile.price_evaluations);
    const next = try parser.planAlloc(a, source, parameters);
    defer next.deinit(a);
    try std.testing.expectEqual(@as(u64, 4), profile.price_evaluations);
    try std.testing.expectEqual(@as(u64, 2), profile.max_plan_price_evaluations);
    parameters.hq_options.max_price_evaluations = 1;
    profile.reset();
    try std.testing.expectError(error.SearchLimitExceeded, parser.planAlloc(a, source, parameters));
    try std.testing.expectEqual(@as(u64, 1), profile.price_evaluations);
    try std.testing.expectEqual(@as(u64, 1), profile.max_plan_price_evaluations);
    try std.testing.expectEqual(@as(u64, 1), profile.price_limit_refusals);
}

test "Zstd HQ search controls actual full block trace exceeds sixteen bit predecessors in one DP" {
    const input = try a.alloc(u8, 128 * 1024);
    defer a.free(input);
    var random = std.Random.DefaultPrng.init(0x1935_aa2e);
    random.random().bytes(input);
    for (input) |*byte| byte.* %= 100;
    @memcpy(input[0..4], "txyz");
    @memcpy(input[input.len - 4 ..], "txyz");
    var model: parser.EntropyModel = .{ .initialized = true };
    @memset(&model.literal_prices, 0);
    for ("txyz") |byte| model.literal_prices[byte] = 64 * 256;
    @memset(&model.ll_prices, 64 * 256);
    @memset(&model.ml_prices, 64 * 256);
    @memset(&model.of_prices, 64 * 256);
    model.ll_prices[35] = 0;
    model.ml_prices[1] = 0;
    model.of_prices[16] = 0;
    var profile: zstd.EncoderControlProfile = .{};
    const initial: [3]usize = .{ 1, 4, 8 };
    const source = parser.Source.init("", "", input, input.len);
    const plan = try parser.planAlloc(a, source, .{ .strategy = .btopt, .hq_options = .{ .parse_mode = .whole_block, .search_depth = 64, .nice_len = 4 }, .initial_repeated_offsets = initial, .entropy = &model, .profile = &profile });
    defer plan.deinit(a);
    // The first4 needle bytes are unavoidable literals (256bits). A copy4
    // after131068 literals costs LL16extra+OF16extra=32bits and saves the only
    // other four costly bytes. Random0..99 data contains none of 'txyz'.
    const expected = @as(u64, 4 * 64 * 256) + h.sequencePrice(&model, input.len - 4, 4, @intCast(input.len - 1));
    try std.testing.expectEqual(@as(u64, 288 * 256), expected);
    try std.testing.expectEqual(expected, plan.estimated_cost);
    try std.testing.expectEqual(input.len, profile.max_parse_positions);
    try std.testing.expectEqual(@as(u64, 1), profile.whole_block_passes);
    try std.testing.expectEqual(@as(usize, 1), plan.records.len);
    try std.testing.expectEqual(input.len - 4, plan.records[0].literal_len);
    try std.testing.expectEqual(@as(usize, 4), plan.records[0].match_len);
    try std.testing.expectEqual(input.len, plan.records[0].match_end);
    try h.replay(a, "", input, initial, &model, plan);
}

test "Zstd HQ search controls full span resource denial rejects metadata before reads or allocation" {
    const fake = @as([*]const u8, @ptrFromInt(4096))[0 .. 128 * 1024];
    const source = parser.Source.init("", "", fake, fake.len);
    const model: parser.EntropyModel = .{ .initialized = true };
    var tracked = h.TrackingAllocator.init(a);
    tracked.fail_alloc_after = 0;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, parser.planAlloc(tracked.allocator(), source, .{ .strategy = .btopt, .entropy = &model, .hq_options = .{ .parse_mode = .whole_block, .match_lengths = .complete, .max_working_memory = 0 } }));
    try std.testing.expectEqual(@as(usize, 0), tracked.alloc_attempts);
    try std.testing.expectEqual(@as(usize, 0), tracked.live);
}

test "Zstd HQ search controls measured workspace exact and one below differ from edge search limits" {
    const source = parser.Source.init("abcd", "", "abcdabcdXabcd", 1024);
    const model: parser.EntropyModel = .{ .initialized = true };
    var tracked = h.TrackingAllocator.init(a);
    tracked.force_copy_reallocation = true;
    var profile: zstd.EncoderControlProfile = .{};
    var parameters: parser.Parameters = .{ .strategy = .btopt, .entropy = &model, .hq_options = .{ .parse_mode = .whole_block, .match_lengths = .complete }, .profile = &profile };
    const plan = try parser.planAlloc(tracked.allocator(), source, parameters);
    const peak = tracked.peak;
    const cap = profile.max_plan_price_evaluations;
    const cost = plan.estimated_cost;
    try std.testing.expectEqual(peak, plan.peak_working_memory);
    plan.deinit(tracked.allocator());
    parameters.hq_options.max_working_memory = peak;
    parameters.hq_options.max_price_evaluations = cap;
    tracked.beginMeasurement();
    const exact = try parser.planAlloc(tracked.allocator(), source, parameters);
    try std.testing.expectEqual(cost, exact.estimated_cost);
    exact.deinit(tracked.allocator());
    try std.testing.expectEqual(peak, tracked.peak);
    parameters.hq_options.max_working_memory = peak - 1;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, parser.planAlloc(tracked.allocator(), source, parameters));
    parameters.hq_options.max_working_memory = std.math.maxInt(usize);
    parameters.hq_options.max_price_evaluations = cap - 1;
    try std.testing.expectError(error.SearchLimitExceeded, parser.planAlloc(tracked.allocator(), source, parameters));
    try std.testing.expectEqual(@as(usize, 0), tracked.live);
    try std.testing.expectEqual(tracked.allocated_bytes, tracked.freed_bytes);
}

test "Zstd HQ search controls a cap alone preserves the original single path and its requested heap" {
    var tracked = h.TrackingAllocator.init(a);
    tracked.force_copy_reallocation = true;
    var profile: zstd.EncoderControlProfile = .{};
    var memory: zstd.EncodeMemoryProfile = .{};
    var options: zstd.NativeFrameOptions = .{ .strategy = .btopt, .control_profile = &profile, .memory_profile = &memory };
    const baseline = try zstd.encodeNativeFrameWithOptionsAlloc(tracked.allocator(), h.plain, options);
    const expected = try a.dupe(u8, baseline.frame);
    defer a.free(expected);
    const peak = tracked.peak;
    const cap = profile.max_plan_price_evaluations;
    try std.testing.expect(cap > 0);
    try std.testing.expectEqual(@as(u64, 0), profile.baseline_searches);
    try std.testing.expectEqual(@as(u64, 0), profile.guarded_frames);
    tracked.allocator().free(baseline.frame);
    profile.reset();
    memory.reset();
    tracked.beginMeasurement();
    options.hq = .{ .max_price_evaluations = cap };
    const exact = try zstd.encodeNativeFrameWithOptionsAlloc(tracked.allocator(), h.plain, options);
    defer tracked.allocator().free(exact.frame);
    try std.testing.expectEqualSlices(u8, expected, exact.frame);
    try std.testing.expectEqual(peak, tracked.peak);
    try std.testing.expectEqual(tracked.peak, memory.peak_requested_bytes);
    try std.testing.expectEqual(@as(u64, 0), profile.baseline_searches);
    try std.testing.expectEqual(@as(u64, 0), profile.guarded_frames);
}
