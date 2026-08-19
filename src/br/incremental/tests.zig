const std = @import("std");
const core = @import("../../core.zig");
const br = @import("../../br.zig");

test "Brotli incremental decoder accepts split input and tiny output" {
    const payload = "split Brotli input payload " ** 32;
    const encoded = try br.IncrementalTestSupport.encodeStored(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);

    var decoder = br.IncrementalStreamDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = payload.len,
    });
    defer decoder.deinit();
    var offset: usize = 0;
    while (offset < encoded.len) {
        const end = @min(encoded.len, offset + 2);
        const result = try decoder.step(encoded[offset..end], &.{});
        offset += result.progress.input_read;
        try std.testing.expectEqual(core.StepResult.Status.need_input, result.status);
    }
    try decoder.finish();
    var output: [payload.len]u8 = undefined;
    var written: usize = 0;
    while (true) {
        const end = @min(output.len, written + 5);
        const result = try decoder.step("", output[written..end]);
        written += result.progress.output_written;
        if (result.status == .done) break;
        try std.testing.expectEqual(core.StepResult.Status.need_output, result.status);
    }
    try std.testing.expectEqualSlices(u8, payload, &output);
    try std.testing.expectEqual(br.IncrementalStreamDecoder.Phase.done, decoder.snapshot().phase);
    decoder.reset();
    try std.testing.expectEqual(br.IncrementalStreamDecoder.Phase.input, decoder.snapshot().phase);
}

test "Brotli incremental decoder enforces input output and exact limits" {
    const encoded = try br.IncrementalTestSupport.encodeStored(std.testing.allocator, "bounded");
    defer std.testing.allocator.free(encoded);

    var compressed_limited = br.IncrementalStreamDecoder.initWithOptions(std.testing.allocator, .{ .max_compressed_len = encoded.len - 1 });
    defer compressed_limited.deinit();
    try std.testing.expectError(error.OutputLimitExceeded, compressed_limited.step(encoded, &.{}));

    var output_limited = br.IncrementalStreamDecoder.initWithOptions(std.testing.allocator, .{ .max_output_len = 3 });
    defer output_limited.deinit();
    _ = try output_limited.step(encoded, &.{});
    try std.testing.expectError(error.OutputLimitExceeded, output_limited.finish());

    var exact = br.IncrementalStreamDecoder.initWithOptions(std.testing.allocator, .{ .expected_output_len = 8 });
    defer exact.deinit();
    _ = try exact.step(encoded, &.{});
    try std.testing.expectError(error.SizeMismatch, exact.finish());

    var truncated = br.IncrementalStreamDecoder.init(std.testing.allocator);
    defer truncated.deinit();
    _ = try truncated.step(encoded[0 .. encoded.len - 1], &.{});
    try std.testing.expectError(error.TruncatedFrame, truncated.finish());
    try std.testing.expectEqualStrings("truncated_input", truncated.diagnostics().recoverability_hint_name);
}

test "Brotli incremental decoder auto completes pledged compressed input" {
    const payload = "pledged compressed Brotli input" ** 8;
    const encoded = try br.IncrementalTestSupport.encodeStored(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);
    var decoder = br.IncrementalStreamDecoder.initExactCompressedSize(std.testing.allocator, .{
        .expected_output_len = payload.len,
    }, encoded.len);
    defer decoder.deinit();

    var output: [payload.len]u8 = undefined;
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (input_offset < encoded.len) {
        const end = @min(encoded.len, input_offset + 3);
        const output_end = @min(output.len, output_offset + 7);
        const result = try decoder.step(encoded[input_offset..end], output[output_offset..output_end]);
        input_offset += result.progress.input_read;
        output_offset += result.progress.output_written;
    }
    while (decoder.snapshot().phase != .done) {
        const end = @min(output.len, output_offset + 7);
        const result = try decoder.step("", output[output_offset..end]);
        output_offset += result.progress.output_written;
        try std.testing.expect(result.status == .need_output or result.status == .done);
    }
    try std.testing.expectEqualSlices(u8, payload, &output);
    try std.testing.expectEqual(@as(?usize, encoded.len), decoder.snapshot().expected_compressed_len);

    var short = br.IncrementalStreamDecoder.initExactCompressedSize(std.testing.allocator, .{}, encoded.len);
    defer short.deinit();
    _ = try short.step(encoded[0 .. encoded.len - 1], &.{});
    try std.testing.expectError(error.SizeMismatch, short.finish());

    var long = br.IncrementalStreamDecoder.initExactCompressedSize(std.testing.allocator, .{}, encoded.len - 1);
    defer long.deinit();
    try std.testing.expectError(error.SizeMismatch, long.step(encoded, &.{}));
}

test "Brotli incremental decoder auto completes compressed meta-block input" {
    const encoded = try br.IncrementalTestSupport.encodeCompressedHello(std.testing.allocator);
    defer std.testing.allocator.free(encoded);
    var decoder = br.IncrementalStreamDecoder.initExactCompressedSize(std.testing.allocator, .{
        .expected_output_len = 5,
    }, encoded.len);
    defer decoder.deinit();

    var output: [5]u8 = undefined;
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (input_offset < encoded.len) {
        const result = try decoder.step(
            encoded[input_offset .. input_offset + 1],
            output[output_offset..][0..@min(2, output.len - output_offset)],
        );
        input_offset += result.progress.input_read;
        output_offset += result.progress.output_written;
    }
    while (decoder.snapshot().phase != .done) {
        const result = try decoder.step("", output[output_offset..][0..@min(2, output.len - output_offset)]);
        output_offset += result.progress.output_written;
    }
    try std.testing.expectEqualSlices(u8, "hello", &output);
}
