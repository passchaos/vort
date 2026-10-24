const std = @import("std");
const zstd = @import("../../zstd.zig");
const h = @import("hq_test_helpers.zig");
const allocator = std.testing.allocator;
const parser = @import("../match/hq_parser.zig");
const strategies = [_]zstd.Strategy{ .lazy2, .btlazy2, .btopt, .btultra, .btultra2 };

fn plainRoundTrip(frame: []const u8, input: []const u8) !void {
    const actual = try zstd.decodeNativeFrameAlloc(allocator, frame);
    defer allocator.free(actual);
    try std.testing.expectEqualSlices(u8, input, actual);
    const independent = try h.stdDecode(allocator, frame);
    defer allocator.free(independent);
    try std.testing.expectEqualSlices(u8, input, independent);
}

test "Zstd HQ contracts preserve frozen old auto and five strategy complete wires" {
    for (h.legacy_wires) |sample| {
        const input = try h.corpusAlloc(allocator, sample.corpus);
        defer allocator.free(input);
        const expected = try h.decodeHex(allocator, sample.hex);
        defer allocator.free(expected);
        const strategy = std.meta.stringToEnum(zstd.Strategy, sample.strategy) orelse unreachable;
        if (sample.native) {
            const result = try zstd.encodeNativeFrameWithOptionsAlloc(allocator, input, .{ .strategy = strategy });
            defer allocator.free(result.frame);
            try std.testing.expectEqualSlices(u8, expected, result.frame);
        } else {
            const frame = try zstd.encodeFrameWithOptionsAlloc(allocator, input, .{ .strategy = strategy });
            defer allocator.free(frame);
            try std.testing.expectEqualSlices(u8, expected, frame);
        }
    }
}

test "Zstd HQ contracts cold refinement prices use actual first statistics and same model cost" {
    const input = try h.corpusAlloc(allocator, .repetitive);
    defer allocator.free(input);
    var profile: zstd.EncoderControlProfile = .{};
    const source = parser.Source.init("", "", input, 1024);
    const plan = try parser.planAlloc(allocator, source, .{ .strategy = .btultra2, .profile = &profile });
    defer plan.deinit(allocator);
    try std.testing.expectEqual(@as(u8, 2), plan.passes);
    try std.testing.expect(plan.used_refinement);
    try std.testing.expect(plan.estimated_cost <= plan.refined_first_pass_cost);
    try std.testing.expectEqual(@as(u64, 2), profile.hq_passes);
    try std.testing.expectEqual(@as(u64, 1), profile.refinement_passes);
    try std.testing.expect(profile.price_evaluations > 0);
    try h.verifyPlan(allocator, "", input, .{ 1, 4, 8 }, plan);
    var initialized: parser.EntropyModel = .{ .initialized = true, .origin = .previous_block };
    profile.reset();
    const continued = try parser.planAlloc(allocator, source, .{ .strategy = .btultra2, .entropy = &initialized, .profile = &profile });
    defer continued.deinit(allocator);
    try std.testing.expectEqual(@as(u8, 1), continued.passes);
    try std.testing.expect(!continued.used_refinement);
    try std.testing.expectEqual(@as(u64, 1), profile.hq_passes);
    try std.testing.expectEqual(@as(u64, 0), profile.refinement_passes);
}

test "Zstd HQ contracts duplicate reps preserve exact cheaper offset values for positive and zero literals" {
    var model: parser.EntropyModel = .{ .initialized = true };
    @memset(&model.of_prices, 12 * 256);
    model.of_prices[2] = 0;
    const dictionary = "a" ** 128;
    for ([_][]const u8{ h.ll0_plain, h.positive_ll_plain }) |input| {
        const plan = try parser.planAlloc(allocator, parser.Source.init(dictionary, "", input, 1024), .{ .strategy = .btopt, .initial_repeated_offsets = .{ 1, 1, 8 }, .entropy = &model });
        defer plan.deinit(allocator);
        try std.testing.expect(plan.records.len > 0);
        var saw_direct = false;
        for (plan.records) |record| {
            if (record.distance == 1) {
                try std.testing.expectEqual(@as(?usize, 4), record.offset_value);
                saw_direct = true;
            }
        }
        try std.testing.expect(saw_direct);
        try h.verifyPlan(allocator, dictionary, input, .{ 1, 1, 8 }, plan);
    }
}

test "Zstd HQ contracts all five engines publish real work and standard native identical frames" {
    const input = try h.corpusAlloc(allocator, .repetitive);
    defer allocator.free(input);
    for (strategies) |strategy| {
        var profile: zstd.EncoderControlProfile = .{};
        const frame_options: zstd.FrameOptions = .{ .strategy = strategy, .content_checksum = true, .hq = .{ .search_depth = 8, .nice_len = 32, .min_match = 3 }, .control_profile = &profile };
        const options = try zstd.resolveFrameOptionsForLevel(3, frame_options);
        try std.testing.expectEqualDeep(frame_options.hq, try options.effectiveHq());
        const result = try zstd.encodeNativeFrameWithOptionsAlloc(allocator, input, options);
        defer allocator.free(result.frame);
        try plainRoundTrip(result.frame, input);
        try std.testing.expect(profile.available and profile.controls_used and profile.hq_used);
        try std.testing.expectEqual(strategy, profile.resolved_strategy);
        try std.testing.expectEqual(@as(u32, 8), profile.effective_hq_search_depth);
        try std.testing.expectEqual(@as(u32, 32), profile.effective_hq_nice_len);
        try std.testing.expect(profile.parser_matches > 0 and profile.byte_comparisons > 0);
        if (strategy != .lazy2) try std.testing.expect(profile.tree_nodes > 0);
        if (strategy == .btopt or strategy == .btultra or strategy == .btultra2) try std.testing.expect(profile.price_evaluations > 0);
        try std.testing.expectEqual(if (strategy == .btultra2) @as(u64, 2) else 1, profile.hq_passes);
        try std.testing.expectEqual(if (strategy == .btultra2) @as(u64, 1) else 0, profile.refinement_passes);
        const standard = try zstd.encodeFrameWithLevelAndOptionsAlloc(allocator, input, 3, frame_options);
        defer allocator.free(standard);
        try std.testing.expectEqualSlices(u8, result.frame, standard);
        var unprofiled = options;
        unprofiled.control_profile = null;
        const repeat = try zstd.encodeNativeFrameWithOptionsAlloc(allocator, input, unprofiled);
        defer allocator.free(repeat.frame);
        try std.testing.expectEqualSlices(u8, result.frame, repeat.frame);
    }
}

test "Zstd HQ contracts representative ultra2 handles seven small corpora and header tails" {
    for (h.corpora) |corpus| {
        const input = try h.corpusAlloc(allocator, corpus);
        defer allocator.free(input);
        const result = try zstd.encodeNativeFrameWithOptionsAlloc(allocator, input, .{ .strategy = .btultra2, .include_content_size = false, .content_checksum = true, .hq = .{ .min_match = 3 } });
        defer allocator.free(result.frame);
        try plainRoundTrip(result.frame, input);
        const header = try zstd.inspectNativeFrameHeader(result.frame);
        try std.testing.expectEqual(@as(?u64, null), header.content_size);
    }
}

test "Zstd HQ contracts raw and full dictionaries keep offsets and skip cold refinement" {
    const bytes = try h.farDictionary(allocator);
    defer allocator.free(bytes);
    const input = bytes[16..528];
    const raw = zstd.NativeDictionary.initRawContent(bytes);
    var profile: zstd.EncoderControlProfile = .{};
    const options: zstd.NativeFrameOptions = .{ .strategy = .btultra2, .include_content_size = false, .window_log = 17, .control_profile = &profile };
    const result = try zstd.encodeNativeFrameWithDictionaryAlloc(allocator, input, options, raw);
    defer allocator.free(result.frame);
    const decoded = try zstd.decodeNativeFrameAllocWithDictionary(allocator, result.frame, raw);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
    try std.testing.expect(profile.dictionary_sequences > 0 and profile.max_distance > 65535);
    try std.testing.expectEqual(@as(u64, 1), profile.hq_passes);
    try std.testing.expectEqual(@as(u64, 0), profile.refinement_passes);
    const full_bytes = try h.fullDictionary(allocator);
    defer allocator.free(full_bytes);
    const full = (try zstd.NativeDictionary.initFromStandardDictionary(full_bytes)).dictionary;
    try std.testing.expectEqual(zstd.DictionaryKind.standard_full, full.kind());
    const set = zstd.NativeDictionarySet.init(&.{full});
    for ([_][]const u8{ h.ll0_plain, h.positive_ll_plain }) |plain| {
        profile.reset();
        const encoded = try zstd.encodeNativeFrameWithDictionarySetAlloc(allocator, plain, options, set, full.id);
        defer allocator.free(encoded.frame);
        const actual = try zstd.decodeNativeFrameAllocWithDictionarySet(allocator, encoded.frame, set);
        defer allocator.free(actual);
        try std.testing.expectEqualSlices(u8, plain, actual);
        try std.testing.expectEqual(full.id, (try zstd.inspectNativeFrameHeader(encoded.frame)).dictionary_id);
        try std.testing.expectEqual(@as(u64, 1), profile.hq_passes);
        try std.testing.expectEqual(@as(u64, 0), profile.refinement_passes);
    }
}

test "Zstd HQ contracts full 128 KiB block reaches beyond 32 KiB and sixteen bit distance" {
    const input = try h.fullBlock(allocator);
    defer allocator.free(input);
    var profile: zstd.EncoderControlProfile = .{};
    const result = try zstd.encodeNativeFrameWithOptionsAlloc(allocator, input, .{ .strategy = .btopt, .window_log = 17, .control_profile = &profile });
    defer allocator.free(result.frame);
    try plainRoundTrip(result.frame, input);
    const summary = try zstd.summarizeNativeFrameBlocks(result.frame);
    try std.testing.expectEqual(@as(usize, 1), summary.block_count);
    try std.testing.expect(profile.max_distance > 65535);
    try std.testing.expect(profile.tree_nodes > 0 and profile.price_evaluations > 0);
}

test "Zstd HQ contracts reusable dictionary set and seekable entries preserve selected options" {
    const dictionary = zstd.NativeDictionary.init(93, "abcQcdefgh");
    const set = zstd.NativeDictionarySet.init(&.{dictionary});
    const input = "abcdefgh" ** 16;
    const options: zstd.NativeFrameOptions = .{ .strategy = .lazy2, .window_log = 10, .include_content_size = false };
    const expected = try zstd.encodeNativeFrameWithDictionarySetAlloc(allocator, input, options, set, 93);
    defer allocator.free(expected.frame);
    var encoder = zstd.NativeFrameEncoder.init(allocator);
    defer encoder.deinit();
    const scratch = try encoder.encodeScratchWithDictionarySet(input, options, set, 93);
    try std.testing.expectEqualSlices(u8, expected.frame, scratch.frame);
    var output: [1024]u8 = @splat(0xa5);
    const written = try encoder.encodeIntoSliceWithDictionarySet(input, options, set, 93, &output);
    try std.testing.expectEqualSlices(u8, expected.frame, output[0..written.written]);
    const decoded = try zstd.decodeNativeFrameAllocWithDictionarySet(allocator, expected.frame, set);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
    var stream_options = options;
    stream_options.dictionary_id = dictionary.id;
    var incremental = try zstd.NativeIncrementalFrameEncoder.initWithPresetDictionary(allocator, stream_options, dictionary);
    defer incremental.deinit();
    const streamed = try h.driveEncoder(allocator, &incremental, input, 1, 1, null);
    defer allocator.free(streamed);
    try std.testing.expectEqualSlices(u8, expected.frame, streamed);
    const seek_input = try h.corpusAlloc(allocator, .repetitive);
    defer allocator.free(seek_input);
    const seek_options: zstd.NativeSeekableOptions = .{ .frame_size = 128, .frame_options = .{ .strategy = .btopt }, .seek_checksums = true };
    const seekable = try zstd.encodeNativeSeekableStreamAlloc(allocator, seek_input, seek_options);
    defer allocator.free(seekable);
    const table = try zstd.inspectNativeSeekTable(seekable);
    const expected_frames = (seek_input.len + seek_options.frame_size - 1) / seek_options.frame_size;
    try std.testing.expectEqual(@as(u32, @intCast(expected_frames)), table.entry_count);
    for (0..expected_frames) |index| {
        const entry = try table.entry(@intCast(index));
        const start: usize = @intCast(entry.compressed_offset);
        const length: usize = @intCast(entry.compressed_size);
        const plain = seek_input[index * seek_options.frame_size ..][0..@min(seek_options.frame_size, seek_input.len - index * seek_options.frame_size)];
        const frame = try zstd.encodeNativeFrameWithOptionsAlloc(allocator, plain, seek_options.frame_options);
        defer allocator.free(frame.frame);
        try std.testing.expectEqualSlices(u8, frame.frame, seekable[start..][0..length]);
        try plainRoundTrip(frame.frame, plain);
    }
}

test "Zstd HQ contracts prior blocks and explicit flush retain history but suppress warm second pass" {
    var input: [8192]u8 = undefined;
    h.fillRandom(input[0..4096], 0x476311a9);
    @memcpy(input[4096..], input[0..4096]);
    var profile: zstd.EncoderControlProfile = .{};
    const options: zstd.NativeFrameOptions = .{ .strategy = .btultra2, .window_log = 13, .block_size_max = 4096, .control_profile = &profile };
    const expected = try zstd.encodeNativeFrameWithOptionsAlloc(allocator, &input, options);
    defer allocator.free(expected.frame);
    try std.testing.expect(profile.history_sequences > 0 and profile.history_seed_positions > 0);
    try std.testing.expectEqual(@as(u64, 3), profile.hq_passes);
    try std.testing.expectEqual(@as(u64, 1), profile.refinement_passes);
    try plainRoundTrip(expected.frame, &input);
    profile.reset();
    var encoder = try zstd.NativeIncrementalFrameEncoder.initExactSize(allocator, options, input.len);
    defer encoder.deinit();
    const actual = try h.driveEncoder(allocator, &encoder, &input, 1, 31, 4096);
    defer allocator.free(actual);
    try std.testing.expectEqualSlices(u8, expected.frame, actual);
    try std.testing.expectEqual(@as(u64, 3), profile.hq_passes);
    try std.testing.expectEqual(@as(u64, 1), profile.refinement_passes);
}

test "Zstd HQ contracts independently framed concatenation resets repeat and entropy state" {
    const first = try h.corpusAlloc(allocator, .source);
    defer allocator.free(first);
    const second = try h.corpusAlloc(allocator, .json);
    defer allocator.free(second);
    var encoder = zstd.NativeFrameEncoder.init(allocator);
    defer encoder.deinit();
    const options: zstd.NativeFrameOptions = .{ .strategy = .btultra2 };
    var joined: std.ArrayList(u8) = .empty;
    defer joined.deinit(allocator);
    const one = try encoder.encodeScratch(first, options);
    try joined.appendSlice(allocator, one.frame);
    const two = try encoder.encodeScratch(second, options);
    try joined.appendSlice(allocator, two.frame);
    const decoded = try h.stdDecode(allocator, joined.items);
    defer allocator.free(decoded);
    try std.testing.expectEqual(first.len + second.len, decoded.len);
    try std.testing.expectEqualSlices(u8, first, decoded[0..first.len]);
    try std.testing.expectEqualSlices(u8, second, decoded[first.len..]);
}
