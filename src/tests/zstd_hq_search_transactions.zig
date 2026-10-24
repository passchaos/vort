const std = @import("std");
const zstd = @import("../zstd.zig");
const parser = @import("../zstd/match/hq_parser.zig");
const h = @import("zstd_hq_search_helpers.zig");
const a = std.testing.allocator;

test "Zstd HQ search controls limits refuse requested work instead of publishing a baseline fallback" {
    var profile: zstd.EncoderControlProfile = .{};
    var options: zstd.NativeFrameOptions = .{ .strategy = .btopt, .hq = .{ .parse_mode = .whole_block, .match_lengths = .complete }, .control_profile = &profile };
    const baseline = try zstd.encodeNativeFrameWithOptionsAlloc(a, h.plain, options);
    defer a.free(baseline.frame);
    const cap = profile.max_plan_price_evaluations;
    try std.testing.expect(cap > 0 and profile.price_evaluations > cap);
    const emitted = profile.emitted();
    options.hq.?.max_price_evaluations = 0;
    var output: [1024]u8 = @splat(0xa5);
    try std.testing.expectError(error.SearchLimitExceeded, zstd.encodeNativeFrameIntoSlice(a, h.plain, options, &output));
    try h.untouched(&output);
    try std.testing.expectEqualDeep(emitted, profile.emitted());
    options.hq.?.max_price_evaluations = cap - 1;
    try std.testing.expectError(error.SearchLimitExceeded, zstd.encodeNativeFrameWithOptionsAlloc(a, h.plain, options));
    try std.testing.expectEqualDeep(emitted, profile.emitted());
    options.hq.?.max_price_evaluations = cap;
    const exact = try zstd.encodeNativeFrameWithOptionsAlloc(a, h.plain, options);
    defer a.free(exact.frame);
    try std.testing.expectEqualSlices(u8, baseline.frame, exact.frame);
    try std.testing.expect(profile.price_evaluations > cap);
    try std.testing.expect(profile.price_limit_refusals > 0);
}

test "Zstd HQ search controls cold ultra2 counts each warmup plan separately under the same cap" {
    var profile: zstd.EncoderControlProfile = .{};
    var parameters: parser.Parameters = .{ .strategy = .btultra2, .hq_options = .{ .parse_mode = .whole_block, .match_lengths = .complete }, .profile = &profile };
    const source = parser.Source.init("", "", h.plain, 1024);
    const baseline = try parser.planAlloc(a, source, parameters);
    defer baseline.deinit(a);
    const cap = profile.max_plan_price_evaluations;
    try std.testing.expectEqual(@as(u8, 2), baseline.passes);
    try std.testing.expect(profile.price_evaluations > cap and cap > 0);
    parameters.hq_options.max_price_evaluations = cap;
    const original_total = profile.price_evaluations;
    const exact = try parser.planAlloc(a, source, parameters);
    defer exact.deinit(a);
    try std.testing.expectEqual(baseline.estimated_cost, exact.estimated_cost);
    try std.testing.expectEqual(@as(u8, 2), exact.passes);
    try std.testing.expect(profile.price_evaluations > original_total);
    parameters.hq_options.max_price_evaluations = cap - 1;
    try std.testing.expectError(error.SearchLimitExceeded, parser.planAlloc(a, source, parameters));
}

test "Zstd HQ search controls incremental refusal preserves block state and reset retries requested policy" {
    var profile: zstd.EncoderControlProfile = .{};
    var options: zstd.NativeFrameOptions = .{ .strategy = .btopt, .hq = .{ .parse_mode = .whole_block, .match_lengths = .complete, .max_price_evaluations = 0 }, .control_profile = &profile };
    var encoder = try zstd.NativeIncrementalFrameEncoder.initExactSize(a, options, h.plain.len);
    defer encoder.deinit();
    var header: [64]u8 = undefined;
    _ = try encoder.step("", &header);
    const accepted = try encoder.step(h.plain, &.{});
    try std.testing.expectEqual(h.plain.len, accepted.progress.input_read);
    encoder.finish();
    const before = encoder.snapshot();
    const pending = try a.dupe(u8, encoder.pending.items);
    defer a.free(pending);
    for (0..2) |_| {
        var destination: [64]u8 = @splat(0xa5);
        try std.testing.expectError(error.SearchLimitExceeded, encoder.step("", &destination));
        try h.untouched(&destination);
        try std.testing.expectEqualDeep(before, encoder.snapshot());
        try std.testing.expectEqualSlices(u8, pending, encoder.pending.items);
        try std.testing.expectEqual(@as(u64, 0), profile.compressed_blocks + profile.raw_blocks + profile.rle_blocks);
    }
    options.hq.?.max_price_evaluations = null;
    encoder.options = options;
    encoder.reset();
    const wire = try h.drive(a, &encoder, h.plain, 31, 7);
    defer a.free(wire);
    try std.testing.expect(profile.whole_block_passes > 0 and profile.complete_length_passes > 0);
    const decoded = try zstd.decodeFrameAlloc(a, wire);
    defer a.free(decoded);
    try std.testing.expectEqualSlices(u8, h.plain, decoded);
}

test "Zstd HQ search controls total heap cap includes safeguard candidate wires and releases failures" {
    var tracked = h.TrackingAllocator.init(a);
    tracked.force_copy_reallocation = true;
    var memory: zstd.EncodeMemoryProfile = .{};
    var controls: zstd.EncoderControlProfile = .{};
    var options: zstd.NativeFrameOptions = .{ .strategy = .btopt, .hq = .{ .parse_mode = .whole_block, .match_lengths = .complete }, .control_profile = &controls, .memory_profile = &memory };
    const base = try zstd.encodeNativeFrameWithOptionsAlloc(tracked.allocator(), h.plain, options);
    const expected = try a.dupe(u8, base.frame);
    defer a.free(expected);
    const peak = tracked.peak;
    try std.testing.expectEqual(peak, memory.peak_requested_bytes);
    try std.testing.expectEqual(@as(usize, 0), memory.live_requested_bytes);
    try std.testing.expect(controls.guarded_frames > 0);
    tracked.allocator().free(base.frame);
    memory.reset();
    tracked.beginMeasurement();
    options.max_total_working_memory = peak;
    const exact = try zstd.encodeNativeFrameWithOptionsAlloc(tracked.allocator(), h.plain, options);
    try std.testing.expectEqualSlices(u8, expected, exact.frame);
    tracked.allocator().free(exact.frame);
    options.max_total_working_memory = peak - 1;
    const emitted = controls.emitted();
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, zstd.encodeNativeFrameWithOptionsAlloc(tracked.allocator(), h.plain, options));
    try std.testing.expectEqualDeep(emitted, controls.emitted());
    try std.testing.expectEqual(@as(usize, 0), tracked.live);
    try std.testing.expectEqual(@as(usize, 0), memory.live_requested_bytes);
}

const FailureGraph = struct {
    pub fn run(backing: std.mem.Allocator) !void {
        var tracked = h.TrackingAllocator.init(backing);
        tracked.force_copy_reallocation = true;
        var controls: zstd.EncoderControlProfile = .{};
        const result = zstd.encodeNativeFrameWithOptionsAlloc(tracked.allocator(), h.plain[0..64], .{ .strategy = .btopt, .hq = .{ .parse_mode = .whole_block, .match_lengths = .complete }, .control_profile = &controls }) catch |err| {
            try std.testing.expectEqual(@as(usize, 0), tracked.live);
            try std.testing.expectEqualDeep(zstd.EncoderControlProfile.Emitted{}, controls.emitted());
            return err;
        };
        tracked.allocator().free(result.frame);
        try std.testing.expectEqual(@as(usize, 0), tracked.live);
    }
};

test "Zstd HQ search controls tiny allocation graph preserves emission and both safeguard owners" {
    try std.testing.checkAllAllocationFailures(a, FailureGraph.run, .{});
}

test "Zstd HQ search controls aliases keep retained prefix and dictionary safe through guarded frame construction" {
    const input = h.plain[0..64];
    const dictionary: zstd.NativeDictionary = .{ .id = 42, .content = input[0..32] };
    const options: zstd.NativeFrameOptions = .{ .strategy = .btopt, .hq = .{ .parse_mode = .whole_block, .match_lengths = .complete } };
    const expected = try zstd.encodeNativeFrameWithDictionaryAlloc(a, input, options, dictionary);
    defer a.free(expected.frame);
    var tracked = h.TrackingAllocator.init(a);
    tracked.force_copy_reallocation = true;
    tracked.poison_before_free = true;
    const backing = tracked.allocator();
    {
        var encoder = zstd.NativeFrameEncoder.init(backing);
        defer encoder.deinit();
        try encoder.output_scratch.resize(backing, input.len);
        @memcpy(encoder.output_scratch.items, input);
        const result = try encoder.encodeScratchWithDictionary(encoder.output_scratch.items, options, .{ .id = 42, .content = encoder.output_scratch.items[0..32] });
        try std.testing.expectEqualSlices(u8, expected.frame, result.frame);
    }
    {
        var output = std.ArrayList(u8).fromOwnedSlice(try backing.dupe(u8, input));
        defer output.deinit(backing);
        _ = try zstd.encodeNativeFrameAppendWithDictionary(backing, &output, output.items, options, .{ .id = 42, .content = output.items[0..32] });
        try std.testing.expectEqualSlices(u8, input, output.items[0..input.len]);
        try std.testing.expectEqualSlices(u8, expected.frame, output.items[input.len..]);
    }
    try std.testing.expectEqual(@as(usize, 0), tracked.live);
    try std.testing.expectEqual(tracked.allocated_bytes, tracked.freed_bytes);
}
