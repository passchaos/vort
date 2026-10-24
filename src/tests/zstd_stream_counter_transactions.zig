const std = @import("std");
const zstd = @import("../zstd.zig");
const core = @import("../core.zig");
const h = @import("zstd_stream_counter_helpers.zig");
const a = std.testing.allocator;

test "Zstd stream counters checked cumulative encoder overflow preserves valid repeated frame state" {
    const options: zstd.NativeFrameOptions = .{ .selection = .raw_or_rle, .content_checksum = false };
    var encoder = try zstd.NativeIncrementalFrameEncoder.initExactSize(a, options, h.rle.len);
    defer encoder.deinit();
    const first = try h.drive(a, &encoder, &h.rle, 31, 17);
    defer a.free(first);
    const copies = std.math.maxInt(h.Count) / @as(h.Count, h.rle.len);
    const completed = try h.seedCompletedEncoder(&encoder, copies);
    try encoder.nextFrameExactSize(options, h.rle.len);
    const before = encoder.snapshot();
    var output: [64]u8 = @splat(0xa5);
    try std.testing.expectError(error.IntegerOverflow, encoder.step(&h.rle, &output));
    try h.untouched(&output);
    try std.testing.expectEqual(completed.input_bytes, encoder.snapshot().input_read);
    try std.testing.expectEqual(before.frame_input, encoder.snapshot().frame_input);
    try std.testing.expectEqual(before.output_written, encoder.snapshot().output_written);
    try std.testing.expectEqual(before.frame_count, encoder.snapshot().frame_count);
}

test "Zstd stream counters output overflow preserves copied prefix progress without wrapping" {
    const options: zstd.NativeFrameOptions = .{ .selection = .raw_or_rle, .content_checksum = false };
    var encoder = try zstd.NativeIncrementalFrameEncoder.initExactSize(a, options, 0);
    defer encoder.deinit();
    const first = try h.drive(a, &encoder, "", 1, 7);
    defer a.free(first);
    const copies = std.math.maxInt(h.Count) / @as(h.Count, @intCast(first.len));
    const completed = try h.seedCompletedEncoder(&encoder, copies);
    try encoder.nextFrameExactSize(options, 0);
    encoder.finish();
    const before = encoder.snapshot();
    var output: [64]u8 = @splat(0xa5);
    try std.testing.expectError(error.IntegerOverflow, encoder.step("", &output));
    const after = encoder.snapshot();
    const copied = after.output_written - before.output_written;
    try std.testing.expect(copied <= output.len);
    try std.testing.expect(after.output_written >= completed.output_bytes);
    try std.testing.expectEqualSlices(u8, first[0..@intCast(copied)], output[0..@intCast(copied)]);
    try h.untouched(output[@intCast(copied)..]);
    try std.testing.expectEqual(before.frame_count, after.frame_count);
}

test "Zstd stream counters both policies report wide output limit diagnostics and local error progress" {
    const frame = try zstd.encodeRawOrRleFrameWithOptionsAlloc(a, &h.rle, .{ .content_checksum = false });
    defer a.free(frame);
    for ([_]core.CompressedInputPolicy{ .block_stream, .prevalidated_frame }) |policy| {
        var decoder = zstd.NativeIncrementalFrameDecoder.initWithOptions(a, .{ .input_policy = policy, .stop_after_first_frame = true });
        defer decoder.deinit();
        const first = try h.decodeDrive(a, &decoder, frame, h.rle.len);
        defer a.free(first);
        const repetitions = (@as(h.Count, 1) << 32) / @as(h.Count, @intCast(frame.len)) + 2;
        const completed = try h.seedCompletedDecoder(&decoder, repetitions);
        decoder.options.max_output_len = completed.output_bytes + h.rle.len + 1;
        try decoder.nextStream();
        const second = try h.decodeDrive(a, &decoder, frame, h.rle.len);
        defer a.free(second);
        try decoder.nextStream();
        const before = decoder.snapshot();
        var destination: [1024]u8 = @splat(0xa5);
        try std.testing.expectError(error.OutputLimitExceeded, decoder.step(frame, &destination));
        try h.untouched(&destination);
        const after = decoder.snapshot();
        try std.testing.expectEqual(before.output_written, after.output_written);
        try std.testing.expectEqual(@as(h.Count, after.last_step_progress.input_read), after.input_received - before.input_received);
        try std.testing.expectEqual(@as(usize, 0), after.last_step_progress.output_written);
        try std.testing.expectEqual(@as(?h.Count, after.input_received), after.error_input_offset);
        try std.testing.expectEqual(@as(?h.Count, after.output_written), after.error_output_offset);
        const diagnostics = decoder.diagnostics();
        try std.testing.expectEqual(after.error_output_offset, diagnostics.error_output_offset);
        try std.testing.expectEqualStrings("raise_output_limit", diagnostics.recoverability_hint_name);
    }
}

test "Zstd stream counters empty completed decoder frames expose input overflow before accepting bytes" {
    const frame = try zstd.encodeRawOrRleFrameWithOptionsAlloc(a, "", .{ .content_checksum = false });
    defer a.free(frame);
    for ([_]core.CompressedInputPolicy{ .block_stream, .prevalidated_frame }) |policy| {
        var decoder = zstd.NativeIncrementalFrameDecoder.initWithOptions(a, .{ .input_policy = policy, .stop_after_first_frame = true });
        defer decoder.deinit();
        const empty = try h.decodeDrive(a, &decoder, frame, 0);
        defer a.free(empty);
        const copies = std.math.maxInt(h.Count) / @as(h.Count, @intCast(frame.len));
        const completed = try h.seedCompletedDecoder(&decoder, copies);
        try decoder.nextStream();
        var output: [8]u8 = @splat(0xa5);
        try std.testing.expectError(error.IntegerOverflow, decoder.step(frame, &output));
        try h.untouched(&output);
        const snapshot = decoder.snapshot();
        try std.testing.expectEqual(completed.input_bytes, snapshot.input_received);
        try std.testing.expectEqual(@as(h.Count, 0), snapshot.output_written);
        try std.testing.expectEqual(@as(usize, 0), snapshot.last_step_progress.input_read);
        try std.testing.expectEqual(@as(?h.Count, completed.input_bytes), snapshot.error_input_offset);
    }
}
