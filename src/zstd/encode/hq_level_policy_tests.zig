//! Public contracts for the opt-in Vort HQ level policy.
const std = @import("std");
const zstd = @import("../../zstd.zig");
const controls = @import("controls.zig");
const fixtures = @import("controls_test_helpers.zig");
const h = @import("hq_test_helpers.zig");
const allocator = std.testing.allocator;

test "Zstd HQ level policy preserves lower levels and resolves all HQ levels without work" {
    var profile: zstd.EncoderControlProfile = .{ .tree_nodes = 7, .compressed_blocks = 2 };
    var before = profile;
    const options: zstd.FrameOptions = .{
        .hq_auto = true,
        .control_profile = &profile,
        .window_log = 13,
        .max_match_history_len = 4096,
        .max_total_working_memory = 12345,
        .include_content_size = false,
        .include_dictionary_id = false,
        .content_checksum = true,
    };
    for ([_]c_int{ -131072, -8, -1, 0, 1, 3, 8 }) |level| {
        var legacy = options;
        legacy.hq_auto = false;
        try std.testing.expectEqualDeep(
            try zstd.resolveFrameOptionsForLevel(level, legacy),
            try zstd.resolveFrameOptionsForLevel(level, options),
        );
    }
    for (9..23) |raw_level| {
        const level: c_int = @intCast(raw_level);
        const expected: zstd.Strategy = if (level >= 19) .btultra2 else if (level >= 16) .btultra else .btopt;
        const native = try zstd.resolveFrameOptionsForLevel(level, options);
        try std.testing.expectEqual(expected, native.strategy);
        try std.testing.expectEqualDeep(try controls.resolvedHqDefaults(expected, level), native.hq.?);
        try std.testing.expectEqual(zstd.NativeFrameSelection.fast_compressed, native.selection);
        try std.testing.expectEqual(controls.legacy_search_budget, native.match_search_budget);
        try std.testing.expect(!native.rep_beam_search);
        try std.testing.expectEqual(@as(?u6, 13), native.window_log);
        try std.testing.expectEqual(@as(?usize, 4096), native.max_match_history_len);
        try std.testing.expectEqual(@as(?usize, 12345), native.max_total_working_memory);
        try std.testing.expect(native.content_checksum and !native.include_content_size and !native.include_dictionary_id);
    }
    // The public resolver records window metadata during native validation;
    // it performs no parser work or emission.
    before.recordWindowPolicy(8192, 4096);
    try std.testing.expectEqualDeep(before, profile);
}

test "Zstd HQ level policy explicit strategy HQ and fast controls retain precedence" {
    const requests = [_]zstd.FrameOptions{
        .{ .strategy = .lazy },
        .{ .strategy = .btopt },
        .{ .strategy = .btultra2, .hq = .{ .search_depth = 12, .nice_len = 33, .max_working_memory = 4096 } },
        .{ .fast_acceleration = 8 },
        .{ .fast_long_matches = true },
        .{ .strategy = .double_fast, .fast_acceleration = 4 },
    };
    for (requests) |request| {
        var policy = request;
        policy.hq_auto = true;
        try std.testing.expectEqualDeep(
            try zstd.resolveFrameOptionsForLevel(19, request),
            try zstd.resolveFrameOptionsForLevel(19, policy),
        );
    }
    // HQ settings still require an explicit HQ strategy; opting in must not
    // silently reinterpret an invalid request or discard caller limits.
    try std.testing.expectError(error.InvalidBlockPlan, zstd.resolveFrameOptionsForLevel(19, .{ .hq_auto = true, .hq = .{} }));
    try std.testing.expectError(error.InvalidBlockPlan, zstd.resolveFrameOptionsForLevel(19, .{ .hq_auto = true, .strategy = .btopt, .fast_acceleration = 8 }));
}

test "Zstd HQ level policy matches explicit HQ wires across seven input families" {
    for ([_]c_int{ 9, 16, 19 }) |level| {
        const native = try zstd.resolveFrameOptionsForLevel(level, .{ .hq_auto = true });
        for (h.corpora) |corpus| {
            const input = try h.corpusAlloc(allocator, corpus);
            defer allocator.free(input);
            var profile: zstd.EncoderControlProfile = .{};
            const actual = try zstd.encodeFrameWithLevelAndOptionsAlloc(allocator, input, level, .{ .hq_auto = true, .control_profile = &profile });
            defer allocator.free(actual);
            const explicit = try zstd.encodeFrameWithLevelAndOptionsAlloc(allocator, input, level, .{ .strategy = native.strategy, .hq = native.hq });
            defer allocator.free(explicit);
            try std.testing.expectEqualSlices(u8, explicit, actual);
            try fixtures.roundTrip(actual, input);
            try std.testing.expect(profile.controls_used and profile.hq_used);
            try std.testing.expectEqual(native.strategy, profile.resolved_strategy);
        }
    }
    const input = fixtures.legacyInput();
    for ([_]c_int{ 0, 1, 3, 8 }) |level| {
        const legacy = try zstd.encodeFrameWithLevelAlloc(allocator, &input, level);
        defer allocator.free(legacy);
        const policy = try zstd.encodeFrameWithLevelAndOptionsAlloc(allocator, &input, level, .{ .hq_auto = true });
        defer allocator.free(policy);
        try std.testing.expectEqualSlices(u8, legacy, policy);
        try fixtures.expectLegacy(level, policy);
    }
}

test "Zstd HQ level policy reusable append into and incremental blocks share exact wires" {
    const input = fixtures.crossBlock();
    var reusable = zstd.LevelFrameEncoder.init(allocator);
    defer reusable.deinit();
    for ([_]c_int{ 9, 16, 19 }) |level| {
        const frame_options: zstd.FrameOptions = .{ .hq_auto = true, .window_log = 13, .content_checksum = true };
        const expected = try zstd.encodeFrameWithLevelAndOptionsAlloc(allocator, &input, level, frame_options);
        defer allocator.free(expected);
        try std.testing.expectEqualSlices(u8, expected, try reusable.encodeScratchWithOptions(&input, level, frame_options));
        var output: [12 * 1024]u8 = @splat(0xa5);
        const count = try zstd.encodeFrameIntoSliceWithLevelAndOptions(allocator, &input, level, frame_options, &output);
        try std.testing.expectEqualSlices(u8, expected, output[0..count]);
        try h.sentinel(output[count..]);
        var appended: std.ArrayList(u8) = .empty;
        defer appended.deinit(allocator);
        try appended.appendSlice(allocator, "prefix");
        _ = try zstd.encodeFrameAppendWithLevelAndOptions(allocator, &appended, &input, level, frame_options);
        try std.testing.expectEqualSlices(u8, "prefix", appended.items[0..6]);
        try std.testing.expectEqualSlices(u8, expected, appended.items[6..]);

        var native = try zstd.resolveFrameOptionsForLevel(level, frame_options);
        native.block_size_max = 4096;
        var profile: zstd.EncoderControlProfile = .{};
        native.control_profile = &profile;
        const split = try zstd.encodeNativeFrameWithOptionsAlloc(allocator, &input, native);
        defer allocator.free(split.frame);
        try std.testing.expectEqual(@as(usize, 2), (try zstd.summarizeNativeFrameBlocks(split.frame)).block_count);
        try std.testing.expect(profile.history_sequences != 0);
        const fragmented = try fixtures.incremental(allocator, native, &input, 31, 17, 4096, null);
        defer allocator.free(fragmented);
        try std.testing.expectEqualSlices(u8, split.frame, fragmented);
        try fixtures.roundTrip(fragmented, &input);
    }
}

test "Zstd HQ level policy raw and full dictionaries share set reusable and incremental wires" {
    const raw_bytes = try h.farDictionary(allocator);
    defer allocator.free(raw_bytes);
    const full_bytes = try h.fullDictionary(allocator);
    defer allocator.free(full_bytes);
    const dictionaries = [_]zstd.NativeDictionary{
        zstd.NativeDictionary.initRawContent(raw_bytes),
        (try zstd.NativeDictionary.initFromStandardDictionary(full_bytes)).dictionary,
    };
    for (dictionaries, 0..) |dictionary, index| {
        const input = if (index == 0) raw_bytes[16..528] else h.positive_ll_plain;
        const set = zstd.NativeDictionarySet.init(&.{dictionary});
        var profile: zstd.EncoderControlProfile = .{};
        const frame_options: zstd.FrameOptions = .{ .hq_auto = true, .window_log = 17, .include_content_size = false, .control_profile = &profile };
        const native = try zstd.resolveFrameOptionsForLevel(19, frame_options);
        const expected = try zstd.encodeFrameWithLevelAndOptionsAndDictionaryAlloc(allocator, input, 19, frame_options, dictionary);
        defer allocator.free(expected);
        if (dictionary.id != 0) {
            const selected = try zstd.encodeFrameWithLevelAndOptionsAndDictionarySetAlloc(allocator, input, 19, frame_options, set, dictionary.id);
            defer allocator.free(selected);
            try std.testing.expectEqualSlices(u8, expected, selected);
        }
        var encoder = zstd.NativeFrameEncoder.init(allocator);
        defer encoder.deinit();
        try std.testing.expectEqualSlices(u8, expected, (try encoder.encodeScratchWithDictionary(input, native, dictionary)).frame);
        const fragmented = try fixtures.incremental(allocator, native, input, 11, 7, null, dictionary);
        defer allocator.free(fragmented);
        try std.testing.expectEqualSlices(u8, expected, fragmented);
        const decoded = try zstd.decodeNativeFrameAllocWithDictionary(allocator, fragmented, dictionary);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
        try std.testing.expect(profile.dictionary_sequences != 0);
        if (index == 0) try std.testing.expect(profile.max_distance > 65535);
    }
}

test "Zstd HQ level policy validation and memory refusals preserve caller output" {
    var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    var output: [4096]u8 = @splat(0xa5);
    for ([_]c_int{ -131073, 23, std.math.minInt(c_int), std.math.maxInt(c_int) }) |level| {
        try std.testing.expectError(error.InvalidBlockPlan, zstd.encodeFrameIntoSliceWithLevelAndOptions(failing.allocator(), "ABCD" ** 64, level, .{ .hq_auto = true }, &output));
        try h.sentinel(&output);
    }
    try std.testing.expectEqual(@as(usize, 0), failing.allocated_bytes);
    var profile: zstd.EncoderControlProfile = .{};
    const limited: zstd.FrameOptions = .{ .hq_auto = true, .max_total_working_memory = 0, .control_profile = &profile };
    // A wire bound remains a scalar query even when the encoder heap cap is zero.
    _ = try zstd.encodedFrameBoundWithLevelAndOptions(256, 19, limited);
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, zstd.encodeFrameIntoSliceWithLevelAndOptions(allocator, "ABCD" ** 64, 19, limited, &output));
    try h.sentinel(&output);
    try std.testing.expectEqualDeep(zstd.EncoderControlProfile.Emitted{}, profile.emitted());
    const retry = try zstd.encodeFrameIntoSliceWithLevelAndOptions(allocator, "ABCD" ** 64, 19, .{ .hq_auto = true }, &output);
    try fixtures.roundTrip(output[0..retry], "ABCD" ** 64);
}

test "Zstd HQ level policy seekable and parallel jobs retain resolved HQ settings" {
    const input = fixtures.crossBlock();
    var profile: zstd.EncoderControlProfile = .{};
    const native = try zstd.resolveFrameOptionsForLevel(19, .{ .hq_auto = true, .window_log = 13, .control_profile = &profile });
    const seek_options: zstd.NativeSeekableOptions = .{ .frame_size = 2048, .frame_options = native };
    const serial = try zstd.encodeNativeSeekableStreamAlloc(allocator, &input, seek_options);
    defer allocator.free(serial);
    const parallel = try zstd.encodeNativeSeekableStreamParallelAlloc(allocator, &input, seek_options, 2);
    defer allocator.free(parallel);
    try std.testing.expectEqualSlices(u8, serial, parallel);
    const table = try zstd.inspectNativeSeekTable(serial);
    try std.testing.expectEqual(@as(u32, 4), table.entry_count);
    for (0..4) |index| {
        const entry = try table.entry(@intCast(index));
        const plain = input[index * 2048 ..][0..2048];
        const expected = try zstd.encodeNativeFrameWithOptionsAlloc(allocator, plain, native);
        defer allocator.free(expected.frame);
        try std.testing.expectEqualSlices(u8, expected.frame, serial[@intCast(entry.compressed_offset)..][0..entry.compressed_size]);
        try fixtures.roundTrip(expected.frame, plain);
    }
    profile.reset();
    const limits: zstd.ParallelOptions = .{ .io = std.testing.io, .worker_count = 2, .job_size = 4096 };
    const frame = try zstd.encodeNativeParallelFrameAlloc(allocator, &input, native, limits);
    defer allocator.free(frame);
    try fixtures.roundTrip(frame, &input);
    try std.testing.expect(profile.controls_used and profile.hq_used);
    try std.testing.expectEqual(zstd.Strategy.btultra2, profile.resolved_strategy);
    try std.testing.expectEqual(@as(u32, 256), profile.effective_hq_search_depth);
    try std.testing.expectEqual(@as(u32, 512), profile.effective_hq_nice_len);
    try std.testing.expect(profile.hq_passes != 0);
    try std.testing.expect(frame.len <= try zstd.encodedNativeParallelFrameBound(input.len, native, limits));
    var synchronous = limits;
    synchronous.worker_count = 1;
    const fallback = try zstd.encodeNativeParallelFrameAlloc(allocator, &input, native, synchronous);
    defer allocator.free(fallback);
    try std.testing.expectEqualSlices(u8, frame, fallback);
}
