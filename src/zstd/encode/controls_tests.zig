const std = @import("std");
const zstd = @import("../../zstd.zig");
const controls = @import("controls.zig");
const fixtures = @import("controls_test_helpers.zig");
const allocator = fixtures.allocator;
const strategies = [_]controls.Strategy{ .fast, .double_fast, .greedy, .lazy, .optimal };

test "Zstd encode controls positive auto null and profile only preserve every legacy level wire" {
    const input = fixtures.legacyInput();
    for (0..23) |raw_level| {
        const level: c_int = @intCast(raw_level);
        const plain = try zstd.encodeFrameWithLevelAlloc(allocator, &input, level);
        defer allocator.free(plain);
        try fixtures.expectLegacy(level, plain);
        var profile: controls.Profile = .{};
        const profiled = try zstd.encodeFrameWithLevelAndOptionsAlloc(allocator, &input, level, .{ .strategy = .auto, .fast_acceleration = null, .control_profile = &profile });
        defer allocator.free(profiled);
        try std.testing.expectEqualSlices(u8, plain, profiled);
        try std.testing.expect(!profile.available and !profile.controls_used);
    }
}

test "Zstd encode controls negative magnitude changes actual parser work and matching wire" {
    const input = fixtures.matchFree();
    const levels = [_]c_int{ -1, -2, -8, -131072 };
    var profiles: [levels.len]controls.Profile = @splat(.{});
    for (levels, 0..) |level, index| {
        const encoded = try zstd.encodeFrameWithLevelAndOptionsAlloc(allocator, &input, level, .{ .control_profile = &profiles[index] });
        defer allocator.free(encoded);
        try fixtures.roundTrip(encoded, &input);
        const profile = profiles[index];
        try std.testing.expect(profile.available and profile.controls_used);
        try std.testing.expectEqual(controls.Strategy.fast, profile.resolved_strategy);
        try std.testing.expect(profile.positions_tested != 0 and profile.short_hash_probes != 0);
        try std.testing.expectEqual(@as(u64, 0), profile.long_hash_probes);
        try std.testing.expectEqual(@as(u64, 0), profile.parser_matches);
        try std.testing.expectEqual(@as(u64, 0), profile.parser_matched_bytes);
    }
    for (1..levels.len) |index| {
        try std.testing.expect(profiles[index - 1].positions_tested > profiles[index].positions_tested);
        try std.testing.expect(profiles[index - 1].short_hash_probes > profiles[index].short_hash_probes);
        try std.testing.expect(profiles[index - 1].skipped_positions < profiles[index].skipped_positions);
    }
    const mixed = fixtures.legacyInput();
    var regular: controls.Profile = .{};
    var sparse: controls.Profile = .{};
    const matched = try zstd.encodeFrameWithLevelAndOptionsAlloc(allocator, &mixed, -1, .{ .control_profile = &regular });
    defer allocator.free(matched);
    const skipped = try zstd.encodeFrameWithLevelAndOptionsAlloc(allocator, &mixed, -131072, .{ .control_profile = &sparse });
    defer allocator.free(skipped);
    try std.testing.expect(regular.parser_matches != 0);
    try std.testing.expectEqual(@as(u64, 0), sparse.parser_matches);
    try std.testing.expect(matched.len < skipped.len);
    try fixtures.roundTrip(matched, &mixed);
    try fixtures.roundTrip(skipped, &mixed);
}

test "Zstd encode controls all five engines execute distinct search or lookahead work" {
    const input = fixtures.lazyTrap();
    var profiles: [strategies.len]controls.Profile = @splat(.{});
    for (strategies, 0..) |strategy, index| {
        const encoded = try zstd.encodeNativeFrameWithOptionsAlloc(allocator, &input, .{ .strategy = strategy, .control_profile = &profiles[index] });
        defer allocator.free(encoded.frame);
        try fixtures.roundTrip(encoded.frame, &input);
        try std.testing.expect(profiles[index].available and profiles[index].controls_used);
        try std.testing.expectEqual(strategy, profiles[index].resolved_strategy);
        try std.testing.expect(profiles[index].positions_tested != 0);
    }
    try std.testing.expectEqual(@as(u64, 0), profiles[0].long_hash_probes);
    try std.testing.expect(profiles[1].long_hash_probes != 0);
    try std.testing.expect(profiles[2].parser_matches != profiles[3].parser_matches or profiles[2].candidate_checks != profiles[3].candidate_checks);
    try std.testing.expectEqual(@as(u64, 0), profiles[2].optimal_transitions);
    try std.testing.expectEqual(@as(u64, 0), profiles[3].optimal_transitions);
    try std.testing.expect(profiles[4].optimal_transitions != 0);
    var zero: controls.Profile = .{};
    const no_search = try zstd.encodeNativeFrameWithOptionsAlloc(allocator, &input, .{ .strategy = .greedy, .match_search_budget = 0, .control_profile = &zero });
    defer allocator.free(no_search.frame);
    try fixtures.roundTrip(no_search.frame, &input);
    try std.testing.expectEqual(@as(u64, 0), zero.parser_matches);
    try std.testing.expect(zero.candidate_checks < profiles[2].candidate_checks);
}

test "Zstd encode controls every engine uses IDless dictionary content beyond sixteen bit distances" {
    const bytes = fixtures.dictionary();
    const dictionary = zstd.NativeDictionary.initRawContent(&bytes);
    const input = bytes[16..528];
    for (strategies) |strategy| {
        var profile: controls.Profile = .{};
        const options = try zstd.resolveFrameOptionsForLevel(3, .{ .strategy = strategy, .include_content_size = false, .content_checksum = true, .window_log = 17, .control_profile = &profile });
        const result = try zstd.encodeNativeFrameWithDictionaryAlloc(allocator, input, options, dictionary);
        defer allocator.free(result.frame);
        try std.testing.expectEqual(@as(u32, 0), (try zstd.inspectNativeFrameHeader(result.frame)).dictionary_id);
        const decoded = try zstd.decodeNativeFrameAllocWithDictionary(allocator, result.frame, dictionary);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
        try std.testing.expect(profile.dictionary_seed_positions != 0 and profile.dictionary_sequences != 0);
        try std.testing.expect(profile.max_distance > 65535);
        if (zstd.decodeNativeFrameAlloc(allocator, result.frame)) |unexpected| {
            allocator.free(unexpected);
            return error.TestUnexpectedResult;
        } else |err| try std.testing.expect(err == error.InvalidMatch or err == error.CorruptFrame);
        profile.reset();
        const capped = try zstd.encodeNativeFrameWithDictionaryAlloc(allocator, input, try zstd.resolveFrameOptionsForLevel(3, .{ .strategy = strategy, .include_content_size = false, .window_log = 10, .max_match_history_len = 1024, .control_profile = &profile }), dictionary);
        defer allocator.free(capped.frame);
        try std.testing.expectEqual(@as(u64, 0), profile.dictionary_sequences);
        try fixtures.roundTrip(capped.frame, input);
    }
}

test "Zstd encode controls history matches survive normal split and block boundary flush schedules" {
    const input = fixtures.crossBlock();
    for (strategies) |strategy| {
        var profile: controls.Profile = .{};
        var options = try zstd.resolveFrameOptionsForLevel(3, .{ .strategy = strategy, .content_checksum = true, .window_log = 13, .control_profile = &profile });
        options.block_size_max = 4096;
        const expected = try zstd.encodeNativeFrameWithOptionsAlloc(allocator, &input, options);
        defer allocator.free(expected.frame);
        try fixtures.roundTrip(expected.frame, &input);
        try std.testing.expect(profile.history_seed_positions != 0 and profile.history_sequences != 0);
        const detached = try fixtures.standaloneSecond(expected.frame);
        defer allocator.free(detached);
        if (zstd.decodeNativeFrameAlloc(allocator, detached)) |unexpected| {
            allocator.free(unexpected);
            return error.TestUnexpectedResult;
        } else |err| try std.testing.expect(err == error.InvalidMatch or err == error.CorruptFrame);
        const normal = try fixtures.incremental(allocator, options, &input, input.len, 257, null, null);
        defer allocator.free(normal);
        const split = try fixtures.incremental(allocator, options, &input, 1, 37, null, null);
        defer allocator.free(split);
        const flushed = try fixtures.incremental(allocator, options, &input, 257, 13, 4096, null);
        defer allocator.free(flushed);
        try std.testing.expectEqualSlices(u8, expected.frame, normal);
        try std.testing.expectEqualSlices(u8, expected.frame, split);
        try std.testing.expectEqualSlices(u8, expected.frame, flushed);
    }
}

test "Zstd encode controls dictionary sets reusable APIs and seekable entries share resolved settings" {
    const bytes = fixtures.dictionary();
    const input = bytes[16..528];
    const dictionary = zstd.NativeDictionary.init(73, &bytes);
    const set = zstd.NativeDictionarySet.init(&.{dictionary});
    var profile: controls.Profile = .{};
    const frame_options: zstd.FrameOptions = .{ .strategy = .double_fast, .include_content_size = false, .window_log = 17, .control_profile = &profile };
    const options = try zstd.resolveFrameOptionsForLevel(-2, frame_options);
    const expected = try zstd.encodeFrameWithLevelAndOptionsAndDictionaryAlloc(allocator, input, -2, frame_options, dictionary);
    defer allocator.free(expected);
    const selected = try zstd.encodeFrameWithLevelAndOptionsAndDictionarySetAlloc(allocator, input, -2, frame_options, set, 73);
    defer allocator.free(selected);
    try std.testing.expectEqualSlices(u8, expected, selected);
    var encoder = zstd.NativeFrameEncoder.init(allocator);
    defer encoder.deinit();
    try std.testing.expectEqualSlices(u8, expected, (try encoder.encodeScratchWithDictionarySet(input, options, set, 73)).frame);
    var buffer: [4096]u8 = @splat(0xa5);
    const into = try zstd.encodeFrameIntoSliceWithLevelAndOptionsAndDictionarySet(allocator, input, -2, frame_options, set, 73, &buffer);
    try std.testing.expectEqualSlices(u8, expected, buffer[0..into]);
    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(allocator);
    try appended.appendSlice(allocator, "prefix");
    const len = try zstd.encodeFrameAppendWithLevelAndOptionsAndDictionarySet(allocator, &appended, input, -2, frame_options, set, 73);
    try std.testing.expectEqual(expected.len, len);
    try std.testing.expectEqualSlices(u8, expected, appended.items[6..]);
    const incremental = try fixtures.incremental(allocator, options, input, 31, 17, null, dictionary);
    defer allocator.free(incremental);
    try std.testing.expectEqualSlices(u8, expected, incremental);
    try std.testing.expect(profile.dictionary_sequences != 0);
    const mixed = fixtures.legacyInput();
    const seek_options: zstd.NativeSeekableOptions = .{ .frame_size = 2048, .frame_options = try zstd.resolveFrameOptionsForLevel(-8, .{ .strategy = .fast, .content_checksum = true, .window_log = 13 }), .seek_checksums = true };
    const stream = try zstd.encodeNativeSeekableStreamAlloc(allocator, &mixed, seek_options);
    defer allocator.free(stream);
    const table = try zstd.inspectNativeSeekTable(stream);
    try std.testing.expectEqual(@as(u32, 2), table.entry_count);
    for (0..2) |index| {
        const entry = try table.entry(@intCast(index));
        const first: usize = @intCast(entry.compressed_offset);
        const end = first + entry.compressed_size;
        const expected_frame = try zstd.encodeNativeFrameWithOptionsAlloc(allocator, mixed[index * 2048 ..][0..2048], seek_options.frame_options);
        defer allocator.free(expected_frame.frame);
        try std.testing.expectEqualSlices(u8, expected_frame.frame, stream[first..@intCast(end)]);
        try fixtures.roundTrip(expected_frame.frame, mixed[index * 2048 ..][0..2048]);
    }
    try std.testing.expect(stream.len <= try zstd.encodedNativeSeekableStreamBound(mixed.len, seek_options));
}

test "Zstd encode controls optimal normal large input is split into bounded interoperable blocks" {
    const input = try allocator.alloc(u8, 96 * 1024);
    defer allocator.free(input);
    fixtures.fillRandom(input[0 .. input.len / 2], 0x613785ac);
    @memcpy(input[input.len / 2 ..], input[0 .. input.len / 2]);
    var profile: controls.Profile = .{};
    const options: zstd.FrameOptions = .{ .strategy = .optimal, .window_log = 17, .content_checksum = true, .control_profile = &profile };
    const encoded = try zstd.encodeFrameWithLevelAndOptionsAlloc(allocator, input, 3, options);
    defer allocator.free(encoded);
    try fixtures.roundTrip(encoded, input);
    const summary = try zstd.summarizeNativeFrameBlocks(encoded);
    try std.testing.expect(summary.block_count >= 3);
    var offset = (try zstd.inspectNativeFrameHeader(encoded)).payload_offset;
    while (true) {
        const block = try zstd.inspectNativeFrameBlockAt(encoded, offset);
        try std.testing.expect(block.payload_len <= 32 * 1024);
        if (block.last) break;
        offset = block.next_header_offset;
    }
    try std.testing.expect(profile.optimal_transitions != 0);
    try std.testing.expect(profile.history_sequences != 0);
    try std.testing.expect(encoded.len <= try zstd.encodedFrameBoundWithLevelAndOptions(input.len, 3, options));
}

test "Zstd encode controls every engine accepts empty known size explicit window frames" {
    for (strategies) |strategy| {
        var profile: controls.Profile = .{};
        const options = try zstd.resolveFrameOptionsForLevel(3, .{ .strategy = strategy, .window_log = 14, .include_content_size = true, .control_profile = &profile });
        const encoded = try zstd.encodeNativeFrameWithOptionsAlloc(allocator, &.{}, options);
        defer allocator.free(encoded.frame);
        try fixtures.roundTrip(encoded.frame, &.{});
        try std.testing.expectEqual(@as(?u64, 0), (try zstd.inspectNativeFrameHeader(encoded.frame)).content_size);
        const incremental = try fixtures.incremental(allocator, options, &.{}, 1, 3, null, null);
        defer allocator.free(incremental);
        try std.testing.expectEqualSlices(u8, encoded.frame, incremental);
        try std.testing.expectEqual(@as(u64, 0), profile.positions_tested);
        try std.testing.expectEqual(@as(u64, 0), profile.dictionary_sequences + profile.history_sequences);
    }
    const negative = try zstd.encodeFrameWithLevelAndOptionsAlloc(allocator, &.{}, -1, .{ .window_log = 14, .include_content_size = true });
    defer allocator.free(negative);
    try fixtures.roundTrip(negative, &.{});
}
