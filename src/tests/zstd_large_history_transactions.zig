const std = @import("std");
const zstd = @import("../zstd.zig");
const h = @import("zstd_large_history_helpers.zig");
const a = std.testing.allocator;

test "Zstd large history total denial leaves Into and Append caller output and emission counters unchanged" {
    var controls: zstd.EncoderControlProfile = .{};
    var memory: zstd.EncodeMemoryProfile = .{};
    var options: zstd.NativeFrameOptions = .{ .window_log = 27, .max_match_history_len = 128 * 1024 * 1024, .strategy = .fast, .max_total_working_memory = 0, .memory_profile = &memory, .control_profile = &controls };
    const emitted = controls.emitted();
    var output: [2048]u8 = @splat(0xa5);
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, zstd.encodeNativeFrameIntoSlice(a, h.plain, options, &output));
    try h.untouched(&output);
    try std.testing.expectEqualDeep(emitted, controls.emitted());
    var appended = std.ArrayList(u8).fromOwnedSlice(try a.dupe(u8, "caller prefix"));
    defer appended.deinit(a);
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, zstd.encodeNativeFrameAppend(a, &appended, h.plain, options));
    try std.testing.expectEqualSlices(u8, "caller prefix", appended.items);
    try std.testing.expectEqualDeep(emitted, controls.emitted());
    options.max_total_working_memory = null;
    const encoded = try zstd.encodeNativeFrameWithOptionsAlloc(a, h.plain, options);
    defer a.free(encoded.frame);
    const result = try zstd.encodeNativeFrameIntoSlice(a, h.plain, options, &output);
    try std.testing.expectEqualSlices(u8, encoded.frame, output[0..result.written]);
}

test "Zstd large history warm retained quota refusal keeps reusable bytes and returned wire ownership" {
    var tracked = h.TrackingAllocator.init(a);
    tracked.force_copy_reallocation = true;
    const backing = tracked.allocator();
    var encoder = zstd.NativeFrameEncoder.init(backing);
    var destroyed = false;
    defer if (!destroyed) encoder.deinit();
    const options: zstd.NativeFrameOptions = .{ .window_log = 27, .max_match_history_len = 128 * 1024 * 1024, .strategy = .fast };
    const old = try encoder.encodeScratch(h.plain, options);
    const expected = try a.dupe(u8, old.frame);
    defer a.free(expected);
    const retained = tracked.live;
    try std.testing.expect(retained > 0);
    var limited = options;
    var memory: zstd.EncodeMemoryProfile = .{};
    limited.memory_profile = &memory;
    limited.max_total_working_memory = retained - 1;
    const calls = tracked.alloc_attempts;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, encoder.encodeScratch(h.plain, limited));
    try std.testing.expectEqual(retained, tracked.live);
    try std.testing.expectEqual(calls, tracked.alloc_attempts);
    try std.testing.expectEqualSlices(u8, expected, encoder.output_scratch.items);
    limited.max_total_working_memory = null;
    memory.reset();
    tracked.beginMeasurement();
    const owned = try encoder.encodeWithOptionsAlloc(h.plain, limited);
    try std.testing.expectEqualSlices(u8, expected, owned.frame);
    try std.testing.expectEqual(tracked.peak, memory.peak_requested_bytes);
    encoder.deinit();
    destroyed = true;
    try std.testing.expectEqual(owned.frame.len, tracked.live);
    const decoded = try zstd.decodeFrameAlloc(a, owned.frame);
    defer a.free(decoded);
    try std.testing.expectEqualSlices(u8, h.plain, decoded);
    backing.free(owned.frame);
    try std.testing.expectEqual(@as(usize, 0), tracked.live);
}

test "Zstd large history reusable input and preset dictionary alias survive moving output memory" {
    const input = h.plain[0..128];
    const dictionary: zstd.NativeDictionary = .{ .id = 42, .content = input[0..64] };
    const options: zstd.NativeFrameOptions = .{ .window_log = 27, .max_match_history_len = 128 * 1024 * 1024, .strategy = .fast };
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
        var profiled = options;
        var memory: zstd.EncodeMemoryProfile = .{};
        profiled.memory_profile = &memory;
        const frame = try encoder.encodeScratchWithDictionary(encoder.output_scratch.items, profiled, .{ .id = 42, .content = encoder.output_scratch.items[0..64] });
        try std.testing.expectEqualSlices(u8, expected.frame, frame.frame);
        try std.testing.expectEqual(tracked.peak, memory.peak_requested_bytes);
    }
    try std.testing.expectEqual(@as(usize, 0), tracked.live);
}

test "Zstd large history incremental budget failure retry next frame and reset preserve frame state" {
    var tracked = h.TrackingAllocator.init(a);
    tracked.force_copy_reallocation = true;
    var memory: zstd.EncodeMemoryProfile = .{};
    var controls: zstd.EncoderControlProfile = .{};
    var options: zstd.NativeFrameOptions = .{ .include_content_size = false, .window_log = 27, .max_match_history_len = 128 * 1024 * 1024, .strategy = .fast, .memory_profile = &memory, .control_profile = &controls };
    var encoder = try zstd.NativeIncrementalFrameEncoder.init(tracked.allocator(), options);
    defer encoder.deinit();
    var prefix: [64]u8 = undefined;
    const start = try encoder.step("", &prefix);
    const accepted = try encoder.step(h.plain, &.{});
    try std.testing.expectEqual(h.plain.len, accepted.progress.input_read);
    encoder.finish();
    const before = encoder.snapshot();
    const pending = try a.dupe(u8, encoder.pending.items);
    defer a.free(pending);
    const emitted = controls.emitted();
    tracked.fail_alloc_after = tracked.alloc_attempts;
    var output: [128]u8 = @splat(0xa5);
    try std.testing.expectError(error.OutOfMemory, encoder.step("", &output));
    try h.untouched(&output);
    try std.testing.expectEqualDeep(before, encoder.snapshot());
    try std.testing.expectEqualSlices(u8, pending, encoder.pending.items);
    try std.testing.expectEqualDeep(emitted, controls.emitted());
    tracked.clearFailures();
    const tail = try h.drive(a, &encoder, h.plain, 1, 1);
    defer a.free(tail);
    const bytes = try std.mem.concat(a, u8, &.{ prefix[0..start.progress.output_written], tail });
    defer a.free(bytes);
    const decoded = try zstd.decodeFrameAlloc(a, bytes);
    defer a.free(decoded);
    try std.testing.expectEqualSlices(u8, h.plain, decoded);
    const done = encoder.snapshot();
    options.max_total_working_memory = tracked.live - 1;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, encoder.nextFrame(options));
    try std.testing.expectEqualDeep(done, encoder.snapshot());
    options.max_total_working_memory = null;
    try encoder.nextFrame(options);
    const next = try h.drive(a, &encoder, h.plain, 31, 17);
    defer a.free(next);
    try std.testing.expectEqualSlices(u8, bytes, next);
    encoder.reset();
    const reset = encoder.snapshot();
    try std.testing.expectEqual(@as(usize, 0), reset.input_read);
    try std.testing.expectEqual(@as(usize, 0), reset.output_written);
    try std.testing.expectEqual(@as(usize, 0), reset.buffered_input);
    const repeated = try h.drive(a, &encoder, h.plain, 1, 1);
    defer a.free(repeated);
    try std.testing.expectEqualSlices(u8, bytes, repeated);
}
