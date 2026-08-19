const std = @import("std");
const zstd = @import("../../zstd.zig");

test "Zstd incremental frame encoder round trips split raw RLE input" {
    const payload = ("incremental Zstd raw RLE payload " ** 5000) ++ ([_]u8{0} ** 256);
    var encoder = try zstd.NativeIncrementalFrameEncoder.init(std.testing.allocator, .{
        .include_content_size = false,
        .content_checksum = true,
        .selection = .raw_or_rle,
        .block_size_max = 4096,
    });
    defer encoder.deinit();
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    var input_offset: usize = 0;
    var scratch: [17]u8 = undefined;
    while (input_offset < payload.len) {
        const end = @min(payload.len, input_offset + 211);
        const result = try encoder.step(payload[input_offset..end], &scratch);
        input_offset += result.progress.input_read;
        try frame.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
    }
    encoder.finish();
    while (true) {
        const result = try encoder.step("", &scratch);
        try frame.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .done) break;
    }
    const decoded = try zstd.decodeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    encoder.reset();
}

test "Zstd incremental frame encoder requires raw no-size mode" {
    try std.testing.expectError(error.InvalidBlockPlan, zstd.NativeIncrementalFrameEncoder.init(std.testing.allocator, .{}));
}
