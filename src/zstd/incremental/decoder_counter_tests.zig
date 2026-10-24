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
