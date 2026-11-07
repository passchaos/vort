const std = @import("std");

pub fn contracts(comptime V: type) !void {
    const payload = "public Zstd compressed workspace sequence history " ** 64;
    const encoded = try V.zstdEncodeNativeFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .selection = .fast_compressed,
        .block_size_max = 1024,
        .window_log = 10,
        .content_checksum = true,
        .include_content_size = false,
    });
    defer std.testing.allocator.free(encoded.frame);
    try std.testing.expectEqual(
        std.compress.zstd.block_size_max,
        V.zstdNativeIncrementalCompressedBlockWorkspaceLen,
    );
    var workspace: [V.zstdNativeIncrementalCompressedBlockWorkspaceLen]u8 = undefined;
    var output: [payload.len]u8 = undefined;
    var decoder = V.ZstdNativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .max_working_memory = 0,
        .expected_output_len = payload.len,
    });
    defer decoder.deinit();
    try decoder.bindCompressedBlockWorkspace(&workspace);
    try decoder.bindStableOutput(&output);
    var input_offset: usize = 0;
    while (decoder.snapshot().phase != .done) {
        const end = @min(encoded.frame.len, input_offset + 3);
        const result = try decoder.stepStableLimited(encoded.frame[input_offset..end], 7);
        input_offset += result.progress.input_read;
        try std.testing.expect(result.progress.input_read != 0 or result.progress.output_written != 0);
    }
    try decoder.finish();
    try std.testing.expectEqual(encoded.frame.len, input_offset);
    try std.testing.expectEqualSlices(u8, payload, decoder.stableOutput());
    try std.testing.expectEqual(@as(usize, 0), decoder.peakWorkingMemoryBytes());
}
