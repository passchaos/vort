const std = @import("std");
const br = @import("../../../br.zig");

test "byte-progressive stored decoder streams headers metadata and payload" {
    const payload = "byte-progressive Brotli stored payload " ** 8;
    const encoded = try br.encodeStoredStreamWithOptionsAlloc(std.testing.allocator, payload, .{
        .window_bits = 24,
        .metadata = "metadata",
    });
    defer std.testing.allocator.free(encoded);

    var decoder = br.IncrementalStoredStreamDecoder.init();
    var output: [payload.len]u8 = undefined;
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (input_offset < encoded.len) {
        const output_end = @min(output.len, output_offset + 3);
        const result = try decoder.step(encoded[input_offset .. input_offset + 1], output[output_offset..output_end]);
        input_offset += result.progress.input_read;
        output_offset += result.progress.output_written;
        try std.testing.expect(result.status != .done or input_offset == encoded.len);
    }
    while (decoder.snapshot().phase != .done) {
        const output_end = @min(output.len, output_offset + 3);
        const result = try decoder.step("", output[output_offset..output_end]);
        output_offset += result.progress.output_written;
        try std.testing.expect(result.status == .need_output or result.status == .done);
    }
    try decoder.finish();
    try std.testing.expectEqualSlices(u8, payload, &output);
    try std.testing.expectEqual(payload.len, decoder.snapshot().output_written);
}

test "byte-progressive stored decoder rejects compressed and truncated streams" {
    const compressed = [_]u8{ 0x1b, 0x02, 0x00, 0x00 };
    var unsupported = br.IncrementalStoredStreamDecoder.init();
    try std.testing.expectError(error.UnsupportedBrotliFeature, unsupported.step(&compressed, &.{}));

    const stored = try br.IncrementalTestSupport.encodeStored(std.testing.allocator, "truncated");
    defer std.testing.allocator.free(stored);
    var truncated = br.IncrementalStoredStreamDecoder.init();
    _ = try truncated.step(stored[0 .. stored.len - 1], &.{});
    try std.testing.expectError(error.TruncatedFrame, truncated.finish());

    var limited = br.IncrementalStoredStreamDecoder.initWithOptions(.{ .max_output_len = 3 });
    try std.testing.expectError(error.OutputLimitExceeded, limited.step(stored, &.{}));
    limited.reset();
    try std.testing.expectEqual(br.IncrementalStoredStreamDecoder.Phase.window, limited.snapshot().phase);
}

test "incremental stored encoder round trips split input and tiny output" {
    const payload = "incremental Brotli stored encode payload " ** 100;
    var encoder = br.IncrementalStoredStreamEncoder.initWithOptions(std.testing.allocator, .{
        .stream = .{ .window_bits = 21, .metadata = "meta" },
        .block_len = 97,
    });
    defer encoder.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var input_offset: usize = 0;
    var scratch: [9]u8 = undefined;
    while (input_offset < payload.len) {
        const end = @min(payload.len, input_offset + 31);
        const result = try encoder.step(payload[input_offset..end], &scratch);
        input_offset += result.progress.input_read;
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
    }
    try encoder.finish();
    while (true) {
        const result = try encoder.step("", &scratch);
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .done) break;
    }
    const decoded = try br.decodeStreamAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    encoder.reset();
    try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().input_read);
}

test "incremental stored encoder enforces limits and finish" {
    var encoder = br.IncrementalStoredStreamEncoder.initWithOptions(std.testing.allocator, .{ .max_input_len = 3 });
    defer encoder.deinit();
    try std.testing.expectError(error.OutputLimitExceeded, encoder.step("four", &.{}));
    encoder.reset();
    _ = try encoder.step("abc", &.{});
    try encoder.finish();
    try std.testing.expectError(error.TrailingData, encoder.step("x", &.{}));
}
