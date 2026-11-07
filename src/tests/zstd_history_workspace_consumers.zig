const std = @import("std");

pub fn contracts(comptime V: type) !void {
    const window = 1024;
    const payload = "public Zstd caller history overlap " ** 192;
    const encoded = try V.zstdEncodeNativeFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .selection = .fast_compressed,
        .block_size_max = 1024,
        .window_log = 10,
        .content_checksum = true,
        .include_content_size = false,
    });
    defer std.testing.allocator.free(encoded.frame);
    try std.testing.expectEqual(window, try V.zstdNativeIncrementalHistoryWorkspaceRequiredLen(window, 0));
    var compressed: [V.zstdNativeIncrementalCompressedBlockWorkspaceLen]u8 = undefined;
    var history: [window]u8 = undefined;
    var output: [payload.len]u8 = undefined;
    var decoder = V.ZstdNativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .max_window_size = window,
        .max_working_memory = 0,
        .expected_output_len = payload.len,
    });
    defer decoder.deinit();
    try decoder.bindCompressedBlockWorkspace(&compressed);
    try decoder.bindHistoryWorkspace(&history);
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (decoder.snapshot().phase != .done) {
        const input_end = @min(encoded.frame.len, input_offset + 3);
        const output_end = @min(payload.len, output_offset + 7);
        const result = try decoder.step(encoded.frame[input_offset..input_end], output[output_offset..output_end]);
        input_offset += result.progress.input_read;
        output_offset += result.progress.output_written;
    }
    try decoder.finish();
    try std.testing.expectEqualSlices(u8, payload, &output);
    try std.testing.expectEqual(@as(usize, 0), decoder.peakWorkingMemoryBytes());
}
