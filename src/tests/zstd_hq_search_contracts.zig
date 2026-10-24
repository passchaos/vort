const std = @import("std");
const zstd = @import("../zstd.zig");
const parser = @import("../zstd/match/hq_parser.zig");
const h = @import("zstd_hq_search_helpers.zig");
const a = std.testing.allocator;

test {
    _ = h;
}

test "Zstd HQ search controls default bounded sampled paths keep the independently archived wire" {
    const dictionary: zstd.NativeDictionary = .{ .id = 42, .content = h.prefix };
    for (h.frozen_wires) |sample| {
        const expected = try h.frozenAlloc(a, sample);
        defer a.free(expected);
        const actual = switch (sample.name) {
            .native_default => try zstd.encodeNativeFrameAlloc(a, h.plain),
            .level18 => try zstd.encodeFrameWithLevelAlloc(a, h.plain, 18),
            .level21 => try zstd.encodeFrameWithLevelAlloc(a, h.plain, 21),
            .level22 => try zstd.encodeFrameWithLevelAlloc(a, h.plain, 22),
            .btopt, .btultra, .btultra2 => block: {
                const strategy: zstd.Strategy = switch (sample.name) {
                    .btopt => .btopt,
                    .btultra => .btultra,
                    .btultra2 => .btultra2,
                    else => unreachable,
                };
                break :block (try zstd.encodeNativeFrameWithOptionsAlloc(a, h.plain, .{ .strategy = strategy })).frame;
            },
            .dictionary => (try zstd.encodeNativeFrameWithDictionaryAlloc(a, h.plain, .{ .strategy = .btopt }, dictionary)).frame,
            .reusable => block: {
                var encoder = zstd.NativeFrameEncoder.init(a);
                defer encoder.deinit();
                break :block (try encoder.encodeWithOptionsAlloc(h.plain, .{ .strategy = .btultra })).frame;
            },
            .incremental => block: {
                var encoder = try zstd.NativeIncrementalFrameEncoder.initExactSize(a, .{ .strategy = .btopt }, h.plain.len);
                defer encoder.deinit();
                break :block try h.drive(a, &encoder, h.plain, 31, 17);
            },
            .seekable => try zstd.encodeNativeSeekableStreamAlloc(a, h.plain, .{ .frame_size = 64, .frame_options = .{ .strategy = .btopt } }),
        };
        defer a.free(actual);
        try std.testing.expectEqualSlices(u8, expected, actual);
        if (sample.name == .btopt or sample.name == .btultra or sample.name == .btultra2) {
            const strategy: zstd.Strategy = switch (sample.name) {
                .btopt => .btopt,
                .btultra => .btultra,
                .btultra2 => .btultra2,
                else => unreachable,
            };
            var profile: zstd.EncoderControlProfile = .{};
            const explicit = try zstd.encodeNativeFrameWithOptionsAlloc(a, h.plain, .{ .strategy = strategy, .hq = .{ .parse_mode = .bounded, .match_lengths = .sampled }, .control_profile = &profile });
            defer a.free(explicit.frame);
            try std.testing.expectEqualSlices(u8, expected, explicit.frame);
            try std.testing.expectEqual(@as(u64, 0), profile.baseline_searches);
        }
    }
}

test "Zstd HQ search controls complete interior lengths beat sampled paths under independent exact symbol costs" {
    for ([_]struct { length: usize, strategy: zstd.Strategy, bits: u64 }{ .{ .length = 50, .strategy = .btopt, .bits = 33 }, .{ .length = 75, .strategy = .btultra, .bits = 35 } }) |sample| {
        const fixture = try h.interior(a, sample.length);
        defer fixture.deinit(a);
        var model: parser.EntropyModel = .{ .initialized = true };
        @memset(&model.literal_prices, 64 * 256);
        @memset(model.literal_prices[200..250], 0);
        model.literal_prices[sample.length] = 8 * 256;
        @memset(&model.ll_prices, 64 * 256);
        @memset(&model.ml_prices, 64 * 256);
        @memset(&model.of_prices, 64 * 256);
        model.ll_prices[24] = 0;
        model.ll_prices[1] = 0;
        model.ml_prices[if (sample.length == 50) 37 else 40] = 0;
        model.ml_prices[42] = 0;
        model.of_prices[7] = 0;
        const second_value: u32 = @intCast(154 + sample.length);
        const expected = h.sequencePrice(&model, 50, sample.length, 253) + @as(u64, 8 * 256) + h.sequencePrice(&model, 1, 100, second_value);
        try std.testing.expectEqual(sample.bits * 256, expected);
        var best: u64 = std.math.maxInt(u64);
        var best_length: usize = 0;
        // The only cheap second100-byte match starts at the unique secondary
        // prefix. Enumerate every first length and the resulting pending run.
        for (3..sample.length + 2) |length| {
            var literal_cost: u64 = 0;
            for (fixture.input[50 + length .. 50 + sample.length + 1]) |byte| literal_cost += model.literal_prices[byte];
            const cost = h.sequencePrice(&model, 50, length, 253) + literal_cost + h.sequencePrice(&model, sample.length + 1 - length, 100, second_value);
            if (cost < best) {
                best = cost;
                best_length = length;
            }
        }
        try std.testing.expectEqual(sample.length, best_length);
        try std.testing.expectEqual(expected, best);
        const source = parser.Source.init(&fixture.dictionary, "", fixture.input, 1024);
        var profile: zstd.EncoderControlProfile = .{};
        var parameters: parser.Parameters = .{ .strategy = sample.strategy, .hq_options = .{ .parse_mode = .whole_block, .match_lengths = .sampled }, .entropy = &model, .profile = &profile };
        const sampled = try parser.planAlloc(a, source, parameters);
        defer sampled.deinit(a);
        try std.testing.expect(sampled.estimated_cost > expected);
        profile.reset();
        parameters.hq_options.match_lengths = .complete;
        const full = try parser.planAlloc(a, source, parameters);
        defer full.deinit(a);
        try std.testing.expectEqual(expected, full.estimated_cost);
        try std.testing.expectEqual(@as(usize, 2), full.records.len);
        try std.testing.expectEqual(sample.length, full.records[0].match_len);
        try std.testing.expectEqual(@as(u32, 253), full.offset_values[0]);
        try std.testing.expectEqual(second_value, full.offset_values[1]);
        try std.testing.expect(profile.complete_length_passes > 0);
        try std.testing.expectEqual(fixture.input.len, profile.max_parse_positions);
        try h.replay(a, &fixture.dictionary, fixture.input, .{ 1, 4, 8 }, &model, full);
    }
}

test "Zstd HQ search controls whole 4098 plan crosses the old horizon with independently priced sequence benefit" {
    const input = try h.boundaryInput(a);
    defer a.free(input);
    var model: parser.EntropyModel = .{ .initialized = true };
    @memset(&model.literal_prices, 8 * 256);
    @memset(&model.ll_prices, 64 * 256);
    @memset(&model.ml_prices, 64 * 256);
    @memset(&model.of_prices, 64 * 256);
    model.ll_prices[30] = 0;
    model.ml_prices[1] = 0;
    model.of_prices[12] = 0;
    const expected = h.boundaryMinimum(input, &model);
    try std.testing.expectEqual(@as(u64, 32775 * 256), expected);
    const source = parser.Source.init("", "", input, 8192);
    var profile: zstd.EncoderControlProfile = .{};
    var parameters: parser.Parameters = .{ .strategy = .btopt, .hq_options = .{ .parse_mode = .bounded }, .entropy = &model, .profile = &profile };
    const bounded = try parser.planAlloc(a, source, parameters);
    defer bounded.deinit(a);
    try std.testing.expectEqual(@as(u64, 32784 * 256), bounded.estimated_cost);
    try h.replay(a, "", input, .{ 1, 4, 8 }, &model, bounded);
    parameters.hq_options.parse_mode = .whole_block;
    profile.reset();
    const whole = try parser.planAlloc(a, source, parameters);
    defer whole.deinit(a);
    try std.testing.expectEqual(expected, whole.estimated_cost);
    try std.testing.expectEqual(input.len, profile.max_parse_positions);
    try std.testing.expectEqual(@as(u64, 1), profile.whole_block_passes);
    try std.testing.expectEqual(@as(usize, 1), whole.records.len);
    try std.testing.expectEqual(@as(usize, 4094), whole.records[0].literal_len);
    try std.testing.expectEqual(@as(usize, 4), whole.records[0].match_len);
    try h.replay(a, "", input, .{ 1, 4, 8 }, &model, whole);
}

test "Zstd HQ search controls tiny sufficient beam paths agree with independent repeat and entropy recurrence" {
    var model: parser.EntropyModel = .{ .initialized = true };
    @memset(&model.literal_prices, 8 * 256);
    @memset(&model.ll_prices, 3 * 256);
    @memset(&model.ml_prices, 3 * 256);
    @memset(&model.of_prices, 2 * 256);
    for ([_][]const u8{ "", "x", "abcd", "abcabc", "abcdabcd" }) |input| {
        const expected = h.finiteCost("abcd", input, &model, 0, 0, .{ 1, 4, 8 });
        const source = parser.Source.init("abcd", "", input, 1024);
        for ([_]zstd.Strategy{ .btopt, .btultra }) |strategy| {
            const plan = try parser.planAlloc(a, source, .{ .strategy = strategy, .hq_options = .{ .parse_mode = .whole_block, .match_lengths = .complete }, .entropy = &model });
            defer plan.deinit(a);
            try std.testing.expectEqual(expected, plan.estimated_cost);
            try h.replay(a, "abcd", input, .{ 1, 4, 8 }, &model, plan);
        }
    }
}

test "Zstd HQ search controls direct and repeated offset aliases retain distinct exact state" {
    const initial: [3]usize = .{ 3, 3, 8 };
    const source = parser.Source.init("abcabc", "", "abc", 1024);
    for ([_]u32{ 1, 6 }) |wanted| {
        var model: parser.EntropyModel = .{ .initialized = true };
        @memset(&model.literal_prices, 64 * 256);
        @memset(&model.ll_prices, 0);
        @memset(&model.ml_prices, 0);
        @memset(&model.of_prices, 64 * 256);
        model.of_prices[if (wanted == 1) 0 else 2] = 0;
        const plan = try parser.planAlloc(a, source, .{ .strategy = .btopt, .hq_options = .{ .parse_mode = .whole_block, .match_lengths = .complete }, .initial_repeated_offsets = initial, .entropy = &model });
        defer plan.deinit(a);
        try std.testing.expectEqual(@as(usize, 1), plan.records.len);
        try std.testing.expectEqual(wanted, plan.offset_values[0]);
        try std.testing.expectEqual(h.repeat(0, wanted, initial).?.repeats, plan.final_repeated_offsets);
        try h.replay(a, "abcabc", "abc", initial, &model, plan);
    }
}

test "Zstd HQ search controls public whole frame safeguards execute requested modes and preserve profiled bytes" {
    for ([_]zstd.Strategy{ .btopt, .btultra, .btultra2 }) |strategy| {
        for ([_]zstd.HqOptions{
            .{ .parse_mode = .whole_block },
            .{ .match_lengths = .complete },
            .{ .parse_mode = .whole_block, .match_lengths = .complete },
        }) |search| {
            var profile: zstd.EncoderControlProfile = .{};
            const options: zstd.NativeFrameOptions = .{ .strategy = strategy, .hq = search, .control_profile = &profile, .content_checksum = true };
            const guarded = try zstd.encodeNativeFrameWithOptionsAlloc(a, h.plain, options);
            defer a.free(guarded.frame);
            try std.testing.expect(profile.baseline_searches > 0);
            try std.testing.expect(profile.guarded_frames > 0);
            if (search.parse_mode == .whole_block) try std.testing.expect(profile.whole_block_passes > 0);
            if (search.match_lengths == .complete) try std.testing.expect(profile.complete_length_passes > 0);
            try std.testing.expectEqual(h.plain.len, profile.max_parse_positions);
            try std.testing.expectEqual(@as(?@TypeOf(search.parse_mode), search.parse_mode), profile.effective_hq_parse_mode);
            try std.testing.expectEqual(@as(?@TypeOf(search.match_lengths), search.match_lengths), profile.effective_hq_match_lengths);
            var unprofiled = options;
            unprofiled.control_profile = null;
            const same = try zstd.encodeNativeFrameWithOptionsAlloc(a, h.plain, unprofiled);
            defer a.free(same.frame);
            try std.testing.expectEqualSlices(u8, guarded.frame, same.frame);
            var baseline = unprofiled;
            baseline.hq.?.parse_mode = .bounded;
            baseline.hq.?.match_lengths = .sampled;
            const original = try zstd.encodeNativeFrameWithOptionsAlloc(a, h.plain, baseline);
            defer a.free(original.frame);
            try std.testing.expect(guarded.frame.len <= original.frame.len);
            const decoded = try zstd.decodeFrameAlloc(a, guarded.frame);
            defer a.free(decoded);
            try std.testing.expectEqualSlices(u8, h.plain, decoded);
            var reusable = zstd.NativeFrameEncoder.init(a);
            defer reusable.deinit();
            const reused = try reusable.encodeWithOptionsAlloc(h.plain, unprofiled);
            defer a.free(reused.frame);
            try std.testing.expectEqualSlices(u8, guarded.frame, reused.frame);
        }
    }
}

test "Zstd HQ search controls dictionary incremental and seekable safeguards keep their documented scopes" {
    const dictionary: zstd.NativeDictionary = .{ .id = 42, .content = h.prefix };
    var profile: zstd.EncoderControlProfile = .{};
    const options: zstd.NativeFrameOptions = .{ .strategy = .btopt, .hq = .{ .parse_mode = .whole_block, .match_lengths = .complete }, .control_profile = &profile, .content_checksum = true };
    const attached = try zstd.encodeNativeFrameWithDictionaryAlloc(a, h.plain, options, dictionary);
    defer a.free(attached.frame);
    try std.testing.expect(profile.whole_block_passes > 0 and profile.complete_length_passes > 0);
    const decoded = try zstd.decodeFrameAllocWithDictionary(a, attached.frame, dictionary);
    defer a.free(decoded);
    try std.testing.expectEqualSlices(u8, h.plain, decoded);
    profile.reset();
    var streaming = options;
    streaming.block_size_max = 64;
    var encoder = try zstd.NativeIncrementalFrameEncoder.initExactSize(a, streaming, h.plain.len);
    defer encoder.deinit();
    const fragmented = try h.drive(a, &encoder, h.plain, 1, 1);
    defer a.free(fragmented);
    try std.testing.expect(profile.whole_block_passes > 0 and profile.baseline_searches > 0);
    try std.testing.expect(profile.max_parse_positions <= 64);
    const streamed = try zstd.decodeFrameAlloc(a, fragmented);
    defer a.free(streamed);
    try std.testing.expectEqualSlices(u8, h.plain, streamed);
    // Incremental arbitration is per block from committed state. It need not
    // equal a fresh one-shot frame, whose safeguard compares complete frames.
    profile.reset();
    const seekable = try zstd.encodeNativeSeekableStreamAlloc(a, h.plain, .{ .frame_size = 64, .frame_options = options });
    defer a.free(seekable);
    try std.testing.expect(profile.guarded_frames > 0);
    try std.testing.expect(profile.max_parse_positions <= 64);
    const all = try zstd.decodeFrameAlloc(a, seekable);
    defer a.free(all);
    try std.testing.expectEqualSlices(u8, h.plain, all);
    const level = try zstd.encodeFrameWithLevelAndOptionsAlloc(a, h.plain, 18, .{ .strategy = .btopt, .hq = options.hq, .content_checksum = true });
    defer a.free(level);
    const level_decoded = try zstd.decodeFrameAlloc(a, level);
    defer a.free(level_decoded);
    try std.testing.expectEqualSlices(u8, h.plain, level_decoded);
}
