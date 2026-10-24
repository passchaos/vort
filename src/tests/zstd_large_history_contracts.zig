const std = @import("std");
const zstd = @import("../zstd.zig");
const h = @import("zstd_large_history_helpers.zig");
const a = std.testing.allocator;

test {
    _ = h;
}

test "Zstd large history default and old valid explicit policies preserve independently frozen wires" {
    const dictionary: zstd.NativeDictionary = .{ .id = 42, .content = h.prefix };
    for (h.frozen_wires) |sample| {
        const expected = try h.frozenAlloc(a, sample);
        defer a.free(expected);
        for ([_]bool{ false, true }) |tracked| {
            var memory: zstd.EncodeMemoryProfile = .{};
            const profile: ?*zstd.EncodeMemoryProfile = if (tracked) &memory else null;
            const actual = switch (sample.api) {
                .native_default => (try zstd.encodeNativeFrameWithOptionsAlloc(a, h.plain, .{ .memory_profile = profile })).frame,
                .native_legacy_window => (try zstd.encodeNativeFrameWithOptionsAlloc(a, h.plain, .{ .include_content_size = false, .memory_profile = profile })).frame,
                .native_explicit_default => (try zstd.encodeNativeFrameWithOptionsAlloc(a, h.plain, .{ .include_content_size = false, .window_log = 27, .memory_profile = profile })).frame,
                .native_explicit_sixty_four => (try zstd.encodeNativeFrameWithOptionsAlloc(a, h.plain, .{ .include_content_size = false, .window_log = 27, .max_match_history_len = 64 * 1024 * 1024, .memory_profile = profile })).frame,
                .level_fast => try zstd.encodeFrameWithLevelAndOptionsAlloc(a, h.plain, -3, .{ .memory_profile = profile }),
                .level_default => try zstd.encodeFrameWithLevelAndOptionsAlloc(a, h.plain, 3, .{ .memory_profile = profile }),
                .level_lazy => try zstd.encodeFrameWithLevelAndOptionsAlloc(a, h.plain, 5, .{ .memory_profile = profile }),
                .level_hq => try zstd.encodeFrameWithLevelAndOptionsAlloc(a, h.plain, 18, .{ .memory_profile = profile }),
                .native_dictionary => (try zstd.encodeNativeFrameWithDictionaryAlloc(a, h.plain, .{ .memory_profile = profile }, dictionary)).frame,
                .reusable_explicit => block: {
                    var encoder = zstd.NativeFrameEncoder.init(a);
                    defer encoder.deinit();
                    break :block (try encoder.encodeWithOptionsAlloc(h.plain, .{ .include_content_size = false, .window_log = 27, .memory_profile = profile })).frame;
                },
                .incremental_explicit => block: {
                    var encoder = try zstd.NativeIncrementalFrameEncoder.init(a, .{ .include_content_size = false, .window_log = 27, .memory_profile = profile });
                    defer encoder.deinit();
                    break :block try h.drive(a, &encoder, h.plain, 31, 17);
                },
                .incremental_dictionary => block: {
                    var encoder = try zstd.NativeIncrementalFrameEncoder.initExactSizeWithPresetDictionary(a, .{ .dictionary_id = 42, .memory_profile = profile }, h.plain.len, dictionary);
                    defer encoder.deinit();
                    break :block try h.drive(a, &encoder, h.plain, 31, 17);
                },
            };
            defer a.free(actual);
            try std.testing.expectEqualSlices(u8, expected, actual);
            if (tracked) try std.testing.expect(memory.available);
            // One-shot native encoding knows this 980-byte input even when
            // content size is omitted, so its legacy advertised window rounds
            // to the minimum1KiB. The native matching policy remains8MiB.
            if (sample.api == .native_legacy_window) try std.testing.expectEqual(@as(u64, 1024), (try h.header(actual)).window_size);
            if (sample.api == .native_explicit_default) try std.testing.expectEqual(@as(u64, 128 * 1024 * 1024), (try h.header(actual)).window_size);
        }
    }
}

test "Zstd large history hundred twenty eight and two hundred fifty six MiB requests keep tiny real work bounded" {
    for ([_]struct { log: u6, history: usize }{
        .{ .log = 27, .history = 128 * 1024 * 1024 },
        .{ .log = 28, .history = 256 * 1024 * 1024 },
    }) |window| {
        for ([_]zstd.Strategy{ .fast, .lazy, .btopt }) |strategy| {
            var tracked = h.TrackingAllocator.init(a);
            tracked.force_copy_reallocation = true;
            var controls: zstd.EncoderControlProfile = .{};
            const options: zstd.NativeFrameOptions = .{ .include_content_size = false, .window_log = window.log, .max_match_history_len = window.history, .strategy = strategy, .control_profile = &controls };
            const encoded = try zstd.encodeNativeFrameWithOptionsAlloc(tracked.allocator(), h.plain, options);
            const info = try h.header(encoded.frame);
            try std.testing.expect(!info.single_segment and info.content_size == null);
            try std.testing.expectEqual(@as(u64, window.history), info.window_size);
            try std.testing.expect(controls.available and controls.controls_used);
            try std.testing.expectEqual(strategy, controls.resolved_strategy);
            try std.testing.expectEqual(@as(?u64, window.history), controls.requested_window_size);
            try std.testing.expectEqual(window.history, controls.effective_match_history_len);
            try std.testing.expect(tracked.peak < 64 * 1024 * 1024);
            const decoded = try zstd.decodeFrameAlloc(a, encoded.frame);
            defer a.free(decoded);
            try std.testing.expectEqualSlices(u8, h.plain, decoded);
            tracked.allocator().free(encoded.frame);
            try std.testing.expectEqual(@as(usize, 0), tracked.live);
            try std.testing.expectEqual(tracked.allocated_bytes, tracked.freed_bytes);
        }
    }
}

test "Zstd large history known content uses a tight advertised window without changing requested policy" {
    try std.testing.expectEqual(@as(?u64, null), try zstd.configuredWindowSize(.{}));
    try std.testing.expectEqual(@as(usize, 8 * 1024 * 1024), try zstd.effectiveMatchHistoryLen(.{}));
    try std.testing.expectEqual(@as(usize, 16 * 1024 * 1024), try zstd.effectiveMatchHistoryLen(.{ .window_log = 27 }));
    try std.testing.expectEqual(@as(usize, 64 * 1024 * 1024), try zstd.effectiveMatchHistoryLen(.{ .window_log = 26, .max_match_history_len = 128 * 1024 * 1024 }));
    for ([_]u6{ 27, 28, 32, 41 }) |window_log| {
        var profile: zstd.EncoderControlProfile = .{};
        var options: zstd.NativeFrameOptions = .{ .window_log = window_log, .max_match_history_len = 128 * 1024 * 1024, .strategy = .fast, .control_profile = &profile };
        try std.testing.expectEqual(@as(?u64, @as(u64, 1) << window_log), try zstd.configuredWindowSize(options));
        const encoded = try zstd.encodeNativeFrameWithOptionsAlloc(a, h.plain, options);
        defer a.free(encoded.frame);
        const info = try h.header(encoded.frame);
        try std.testing.expect(info.single_segment);
        try std.testing.expectEqual(@as(?u64, h.plain.len), info.content_size);
        try std.testing.expectEqual(@as(u64, h.plain.len), info.window_size);
        try std.testing.expectEqual(@as(?u64, @as(u64, 1) << window_log), profile.requested_window_size);
        try std.testing.expectEqual(@as(usize, 128 * 1024 * 1024), profile.effective_match_history_len);
        options.include_content_size = false;
        const no_size = try zstd.encodeNativeFrameWithOptionsAlloc(a, h.plain, options);
        defer a.free(no_size.frame);
        try std.testing.expectEqual(@as(u64, 1) << window_log, (try h.header(no_size.frame)).window_size);
    }
}

test "Zstd large history maximum public match window reserves one full block and rejects excess metadata" {
    const expected: usize = @as(usize, std.math.maxInt(u32)) - 1 - 128 * 1024;
    try std.testing.expectEqual(expected, zstd.native_explicit_window_match_len_max);
    var tracked = h.TrackingAllocator.init(a);
    tracked.fail_alloc_after = 0;
    try std.testing.expectError(error.InvalidBlockPlan, zstd.encodeNativeFrameWithOptionsAlloc(tracked.allocator(), h.plain, .{ .window_log = 32, .max_match_history_len = expected + 1 }));
    try std.testing.expectEqual(@as(usize, 0), tracked.alloc_attempts);
    try std.testing.expectError(error.InvalidBlockPlan, zstd.encodeNativeFrameWithOptionsAlloc(tracked.allocator(), h.plain, .{ .max_match_history_len = expected }));
    try std.testing.expectEqual(@as(usize, 0), tracked.alloc_attempts);
    const encoded = try zstd.encodeNativeFrameWithOptionsAlloc(a, h.plain, .{ .include_content_size = false, .window_log = 32, .max_match_history_len = expected, .strategy = .fast });
    defer a.free(encoded.frame);
    try std.testing.expectEqual(@as(u64, 1) << 32, (try h.header(encoded.frame)).window_size);
    const decoded = try zstd.decodeFrameAlloc(a, encoded.frame);
    defer a.free(decoded);
    try std.testing.expectEqualSlices(u8, h.plain, decoded);
}

test "Zstd large history dictionaries and fragmented reusable APIs propagate the same large window" {
    const dictionary: zstd.NativeDictionary = .{ .id = 42, .content = h.prefix };
    const options: zstd.NativeFrameOptions = .{ .include_content_size = false, .window_log = 27, .max_match_history_len = 128 * 1024 * 1024, .strategy = .fast };
    const expected = try zstd.encodeNativeFrameWithOptionsAlloc(a, h.plain, options);
    defer a.free(expected.frame);
    var reusable = zstd.NativeFrameEncoder.init(a);
    defer reusable.deinit();
    const reused = try reusable.encodeWithOptionsAlloc(h.plain, options);
    defer a.free(reused.frame);
    try std.testing.expectEqualSlices(u8, expected.frame, reused.frame);
    var incremental = try zstd.NativeIncrementalFrameEncoder.init(a, options);
    defer incremental.deinit();
    const fragmented = try h.drive(a, &incremental, h.plain, 1, 1);
    defer a.free(fragmented);
    try std.testing.expectEqualSlices(u8, expected.frame, fragmented);
    for ([_]zstd.Strategy{ .fast, .lazy, .btopt }) |strategy| {
        var attached_options = options;
        attached_options.dictionary_id = 42;
        attached_options.strategy = strategy;
        var profile: zstd.EncoderControlProfile = .{};
        attached_options.control_profile = &profile;
        const attached = try zstd.encodeNativeFrameWithDictionaryAlloc(a, h.plain, attached_options, dictionary);
        defer a.free(attached.frame);
        try std.testing.expectEqual(strategy, profile.resolved_strategy);
        try std.testing.expectEqual(@as(usize, 128 * 1024 * 1024), profile.effective_match_history_len);
        const decoded = try zstd.decodeFrameAllocWithDictionary(a, attached.frame, dictionary);
        defer a.free(decoded);
        try std.testing.expectEqualSlices(u8, h.plain, decoded);
        var dict_incremental = try zstd.NativeIncrementalFrameEncoder.initWithPresetDictionary(a, attached_options, dictionary);
        defer dict_incremental.deinit();
        const dict_stream = try h.drive(a, &dict_incremental, h.plain, 31, 17);
        defer a.free(dict_stream);
        const streamed = try zstd.decodeFrameAllocWithDictionary(a, dict_stream, dictionary);
        defer a.free(streamed);
        try std.testing.expectEqualSlices(u8, h.plain, streamed);
        try std.testing.expectEqual(@as(u64, 128 * 1024 * 1024), (try h.header(dict_stream)).window_size);
    }
}
