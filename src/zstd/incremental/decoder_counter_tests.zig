const std = @import("std");
const core = @import("../../core.zig");
const zstd = @import("../../zstd.zig");
const Count = core.StreamCount;
const logical_len: Count = (@as(Count, 1) << 32) + 1;

/// A complete ~128 KiB wire frame regenerates 4 GiB + 1 byte, without an
/// output allocation or a fabricated checkpoint inside the decoder.
fn wideRleFrame(pledge: ?Count) ![]u8 {
    const header_len: usize = if (pledge != null) 14 else 6;
    const frame = try std.testing.allocator.alloc(u8, header_len + 32769 * 4);
    @memcpy(frame[0..4], &[_]u8{ 0x28, 0xb5, 0x2f, 0xfd });
    frame[4] = if (pledge != null) 0xc0 else 0;
    frame[5] = 0x38; // 128 KiB window, independent of wide content size.
    if (pledge) |len| std.mem.writeInt(u64, frame[6..14], @intCast(len), .little);
    for (0..32768) |i| @memcpy(frame[header_len + i * 4 ..][0..4], &[_]u8{ 2, 0, 0x10, 'R' });
    @memcpy(frame[frame.len - 4 ..], &[_]u8{ 0x0b, 0, 0, 'R' });
    return frame;
}

test "Zstd incremental decoder counters prevalidate wide real RLE frames with one byte output" {
    const frame = try wideRleFrame(logical_len);
    defer std.testing.allocator.free(frame);
    for ([_]core.CompressedInputPolicy{ .block_stream, .prevalidated_frame }) |policy| {
        var decoder = zstd.NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
            .input_policy = policy,
            .expected_output_len = logical_len,
            .max_output_len = logical_len,
            .max_decoded_buffer_len = logical_len,
            .max_compressed_buffer_len = frame.len,
            .max_working_memory = frame.len + 128 * 1024,
        });
        defer decoder.deinit();
        var output = [_]u8{ 0xa5, 0xa5 };
        const step = try decoder.step(frame, output[0..1]);
        try std.testing.expectEqual(.need_output, step.status);
        try std.testing.expectEqual(@as(usize, 1), step.progress.output_written);
        try std.testing.expectEqualSlices(u8, &.{ 'R', 0xa5 }, &output);
        try std.testing.expectEqual(@as(?Count, logical_len), decoder.snapshot().decoded_len);
        try std.testing.expectEqual(@as(?Count, logical_len - 1), decoder.snapshot().decoded_remaining);
        try std.testing.expectEqual(@as(Count, 1), decoder.snapshot().output_written);
        try std.testing.expectEqual(@as(usize, 0), decoder.decodedBufferCapacity());
        try std.testing.expect(decoder.workingMemoryBytes() <= frame.len + 128 * 1024);
        if (policy == .prevalidated_frame) try std.testing.expectEqual(frame.len, step.progress.input_read);
    }
}

test "Zstd incremental decoder counters wide preflight preserves absent sizes limits and mismatches" {
    const frame = try wideRleFrame(null);
    defer std.testing.allocator.free(frame);
    var decoder = zstd.NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .input_policy = .prevalidated_frame,
        .max_compressed_buffer_len = frame.len,
    });
    defer decoder.deinit();
    const prepared = try decoder.step(frame, &.{});
    try std.testing.expectEqual(.need_output, prepared.status);
    try std.testing.expectEqual(@as(?Count, logical_len), decoder.snapshot().decoded_len);
    try std.testing.expectEqual(@as(Count, 0), decoder.snapshot().output_written);
    try std.testing.expectEqual(@as(usize, 0), decoder.decodedBufferCapacity());

    var capped = zstd.NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .input_policy = .prevalidated_frame,
        .max_output_len = logical_len - 1,
        .max_compressed_buffer_len = frame.len,
    });
    defer capped.deinit();
    var output = [_]u8{0xa5} ** 8;
    try std.testing.expectError(error.OutputLimitExceeded, capped.step(frame, &output));
    try std.testing.expectEqualSlices(u8, &([_]u8{0xa5} ** 8), &output);
    try std.testing.expectEqual(@as(usize, 0), capped.snapshot().last_step_progress.output_written);

    const mismatch = try wideRleFrame(logical_len + 1);
    defer std.testing.allocator.free(mismatch);
    var wrong_size = zstd.NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .input_policy = .prevalidated_frame,
        .max_compressed_buffer_len = mismatch.len,
    });
    defer wrong_size.deinit();
    try std.testing.expectError(error.SizeMismatch, wrong_size.step(mismatch, &output));
    try std.testing.expectEqualSlices(u8, &([_]u8{0xa5} ** 8), &output);
    try std.testing.expectEqual(@as(usize, 0), wrong_size.snapshot().last_step_progress.output_written);
    try std.testing.expectEqual(@as(usize, 0), wrong_size.decodedBufferCapacity());
}

const first_skip = [_]u8{ 0x50, 0x2a, 0x4d, 0x18, 3, 0, 0, 0, 'a', 'b', 'c' };
const second_skip = [_]u8{ 0x51, 0x2a, 0x4d, 0x18, 2, 0, 0, 0, 'd', 'e' };

test "Zstd incremental decoder counters zero output pledge permits split metadata after done" {
    for ([_]core.CompressedInputPolicy{ .block_stream, .prevalidated_frame }) |policy| {
        var capture: [5]u8 = undefined;
        var events: [2]zstd.NativeIncrementalFrameDecoder.SkippableEvent = undefined;
        var decoder = zstd.NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
            .input_policy = policy,
            .expected_output_len = 0,
            .max_output_len = 0,
            .max_compressed_buffer_len = 8,
            .skippable_output = &capture,
            .skippable_events = &events,
        });
        defer decoder.deinit();
        const first = try decoder.step(&first_skip, &.{});
        try std.testing.expectEqual(.done, first.status);
        try std.testing.expectEqual(core.Progress{ .input_read = first_skip.len }, first.progress);
        const prefix = try decoder.step(second_skip[0..4], &.{});
        try std.testing.expectEqual(.need_input, prefix.status);
        try std.testing.expectEqual(core.Progress{ .input_read = 4 }, prefix.progress);
        const tail = try decoder.step(second_skip[4..], &.{});
        try std.testing.expectEqual(.done, tail.status);
        try std.testing.expectEqual(core.Progress{ .input_read = second_skip.len - 4 }, tail.progress);
        try decoder.finish();
        try std.testing.expectEqualSlices(u8, "abcde", &capture);
        try std.testing.expectEqual(@as(Count, 5), decoder.snapshot().skippable_total);
        try std.testing.expectEqual(@as(Count, 2), decoder.snapshot().skippable_event_count);
        try std.testing.expectEqual(@as(Count, first_skip.len + second_skip.len), decoder.snapshot().input_received);
        try std.testing.expectEqual(@as(Count, 0), decoder.snapshot().output_written);
        try std.testing.expectEqual(@as(Count, 0), decoder.snapshot().data_frame_count);
        try std.testing.expectEqual(@as(usize, 3), events[0].payload_len);
        try std.testing.expectEqual(@as(usize, 2), events[1].payload_len);
    }
}

test "Zstd incremental decoder counters fulfilled pledge rejects later data before output with sticky progress" {
    const frame = try zstd.encodeRawOrRleFrameWithOptionsAlloc(std.testing.allocator, "x", .{ .content_checksum = false });
    defer std.testing.allocator.free(frame);
    const empty = try zstd.encodeRawOrRleFrameWithOptionsAlloc(std.testing.allocator, "", .{ .content_checksum = false });
    defer std.testing.allocator.free(empty);
    for ([_]core.CompressedInputPolicy{ .block_stream, .prevalidated_frame }) |policy| {
        var decoder = zstd.NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
            .input_policy = policy,
            .expected_output_len = 0,
        });
        defer decoder.deinit();
        try std.testing.expectEqual(.done, (try decoder.step(&first_skip, &.{})).status);
        try std.testing.expectEqual(.done, (try decoder.step(empty, &.{})).status);
        try std.testing.expectEqual(@as(Count, 1), decoder.snapshot().data_frame_count);
        const before = decoder.snapshot();
        var output: [8]u8 = @splat(0xa5);
        try std.testing.expectError(error.SizeMismatch, decoder.step(frame, &output));
        const failed = decoder.snapshot();
        try std.testing.expectEqualSlices(u8, &([_]u8{0xa5} ** 8), &output);
        try std.testing.expectEqual(@as(Count, 0), failed.output_written);
        try std.testing.expectEqual(@as(usize, 0), failed.last_step_progress.output_written);
        try std.testing.expectEqual(failed.input_received - before.input_received, @as(Count, failed.last_step_progress.input_read));
        try std.testing.expectEqual(@as(?Count, failed.input_received), failed.error_input_offset);
        try std.testing.expectEqual(@as(?Count, 0), failed.error_output_offset);
        try std.testing.expect(failed.last_step_progress.input_read != 0);
        try std.testing.expectError(error.SizeMismatch, decoder.step(&second_skip, &output));
        try std.testing.expectEqual(failed.input_received, decoder.snapshot().input_received);
        try std.testing.expectEqualSlices(u8, &([_]u8{0xa5} ** 8), &output);
    }
}

test "Zstd incremental decoder counters stopped empty member keeps explicit done behavior" {
    const frame = try zstd.encodeRawOrRleFrameWithOptionsAlloc(std.testing.allocator, "", .{ .content_checksum = false });
    defer std.testing.allocator.free(frame);
    for ([_]core.CompressedInputPolicy{ .block_stream, .prevalidated_frame }) |policy| {
        var decoder = zstd.NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
            .input_policy = policy,
            .expected_output_len = 0,
            .stop_after_first_frame = true,
        });
        defer decoder.deinit();
        try std.testing.expectEqual(.done, (try decoder.step(frame, &.{})).status);
        const before = decoder.snapshot();
        const stopped = try decoder.step(&first_skip, &.{});
        try std.testing.expectEqual(.done, stopped.status);
        try std.testing.expectEqual(core.Progress{}, stopped.progress);
        try std.testing.expectEqual(before.input_received, decoder.snapshot().input_received);
        try std.testing.expectEqual(@as(Count, 1), decoder.snapshot().data_frame_count);
    }
}
