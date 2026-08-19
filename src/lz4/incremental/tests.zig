const std = @import("std");
const lz4 = @import("../../lz4.zig");

test "LZ4 incremental frame encoder round trips split linked input" {
    const payload = "incremental linked LZ4 encode payload " ** 3000;
    var encoder = try lz4.NativeIncrementalFrameEncoder.init(std.testing.allocator, .{
        .include_content_size = false,
        .block_size_id = .max64kb,
        .block_mode = .linked,
        .block_checksum = true,
        .content_checksum = true,
    });
    defer encoder.deinit();
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    var input_offset: usize = 0;
    var scratch: [13]u8 = undefined;
    while (input_offset < payload.len) {
        const end = @min(payload.len, input_offset + 257);
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
    const decoded = try lz4.decodeNativeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    encoder.reset();
}

test "LZ4 incremental frame encoder requires unknown content size" {
    try std.testing.expectError(error.InvalidBlockPlan, lz4.NativeIncrementalFrameEncoder.init(std.testing.allocator, .{}));
}
