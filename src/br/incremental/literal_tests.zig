const std = @import("std");
const br = @import("../../br.zig");

test "byte-progressive compressed literal decoder handles split Huffman input" {
    const len = 4096;
    const encoded = try br.IncrementalTestSupport.encodeCompressedLiteralCycle(std.testing.allocator, len);
    defer std.testing.allocator.free(encoded);
    var expected: [len]u8 = undefined;
    for (&expected, 0..) |*byte, i| byte.* = "abcd"[i & 3];
    var decoded: [len]u8 = undefined;
    var decoder = br.IncrementalLiteralStreamDecoder.initWithOptions(.{ .expected_output_len = len });
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (decoder.snapshot().phase != .done) {
        const input_end = @min(encoded.len, input_offset + 1);
        const output_end = @min(decoded.len, output_offset + 3);
        const step = try decoder.step(encoded[input_offset..input_end], decoded[output_offset..output_end]);
        input_offset += step.progress.input_read;
        output_offset += step.progress.output_written;
    }
    try decoder.finish();
    try std.testing.expectEqual(encoded.len, input_offset);
    try std.testing.expectEqualSlices(u8, &expected, &decoded);
    const snapshot = decoder.snapshot();
    try std.testing.expectEqual(encoded.len, snapshot.input_read);
    try std.testing.expectEqual(len, snapshot.output_written);
    try std.testing.expect(snapshot.retained_input_bytes <= 4096);
}

test "byte-progressive compressed literal decoder accepts Node-gated hello shape" {
    const encoded = try br.IncrementalTestSupport.encodeCompressedHello(std.testing.allocator);
    defer std.testing.allocator.free(encoded);
    var decoder = br.IncrementalLiteralStreamDecoder.initWithOptions(.{ .expected_output_len = 5 });
    var decoded: [5]u8 = undefined;
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (decoder.snapshot().phase != .done) {
        const input_end = @min(encoded.len, input_offset + 1);
        const output_end = @min(decoded.len, output_offset + 1);
        const step = try decoder.step(encoded[input_offset..input_end], decoded[output_offset..output_end]);
        input_offset += step.progress.input_read;
        output_offset += step.progress.output_written;
    }
    try decoder.finish();
    try std.testing.expectEqualSlices(u8, "hello", &decoded);
}

test "byte-progressive compressed literal decoder consumes final-empty trailer" {
    const encoded = try br.IncrementalTestSupport.encodeCompressedHelloWithFinal(std.testing.allocator, false);
    defer std.testing.allocator.free(encoded);
    var decoder = br.IncrementalLiteralStreamDecoder.initWithOptions(.{ .expected_output_len = 5 });
    var decoded: [5]u8 = undefined;
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (decoder.snapshot().phase != .done) {
        const input_end = @min(encoded.len, input_offset + 1);
        const output_end = @min(decoded.len, output_offset + 1);
        const step = try decoder.step(encoded[input_offset..input_end], decoded[output_offset..output_end]);
        input_offset += step.progress.input_read;
        output_offset += step.progress.output_written;
    }
    try decoder.finish();
    try std.testing.expectEqualSlices(u8, "hello", &decoded);

    var truncated = br.IncrementalLiteralStreamDecoder.init();
    var truncated_input: usize = 0;
    var truncated_output: usize = 0;
    while (truncated_output != decoded.len) {
        const step = try truncated.step(encoded[truncated_input .. encoded.len - 1], decoded[truncated_output..]);
        truncated_input += step.progress.input_read;
        truncated_output += step.progress.output_written;
        if (step.status == .need_input and truncated_input == encoded.len - 1) break;
    }
    try std.testing.expectError(error.TruncatedFrame, truncated.finish());
    try std.testing.expect(truncated_output < decoded.len or truncated_input < encoded.len);
}

test "byte-progressive compressed literal decoder streams following stored blocks" {
    const encoded = try br.IncrementalTestSupport.encodeCompressedHelloThenStored(std.testing.allocator, " world");
    defer std.testing.allocator.free(encoded);
    const expected = "hello world";
    var decoded: [expected.len]u8 = undefined;
    var decoder = br.IncrementalLiteralStreamDecoder.initWithOptions(.{
        .max_output_len = expected.len,
        .expected_output_len = expected.len,
    });
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (decoder.snapshot().phase != .done) {
        const input_end = @min(encoded.len, input_offset + 1);
        const output_end = @min(decoded.len, output_offset + 2);
        const step = try decoder.step(encoded[input_offset..input_end], decoded[output_offset..output_end]);
        input_offset += step.progress.input_read;
        output_offset += step.progress.output_written;
    }
    try decoder.finish();
    try std.testing.expectEqualSlices(u8, expected, &decoded);

    var limited = br.IncrementalLiteralStreamDecoder.initWithOptions(.{ .max_output_len = expected.len - 1 });
    var limited_output: [expected.len]u8 = undefined;
    try std.testing.expectError(error.OutputLimitExceeded, limited.step(encoded, &limited_output));

    const longer = try br.IncrementalTestSupport.encodeCompressedHelloThenStored(std.testing.allocator, "!" ** 257);
    defer std.testing.allocator.free(longer);
    var expected_mismatch = br.IncrementalLiteralStreamDecoder.initWithOptions(.{ .expected_output_len = 5 });
    var longer_output: [262]u8 = undefined;
    try std.testing.expectError(error.SizeMismatch, expected_mismatch.step(longer, &longer_output));
}

test "byte-progressive compressed literal decoder streams multiple stored blocks" {
    const encoded = try br.IncrementalTestSupport.encodeCompressedHelloThenStoredBlocks(std.testing.allocator, &.{ " ", "world", "!" });
    defer std.testing.allocator.free(encoded);
    const expected = "hello world!";
    var decoded: [expected.len]u8 = undefined;
    var decoder = br.IncrementalLiteralStreamDecoder.initWithOptions(.{ .expected_output_len = expected.len });
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (decoder.snapshot().phase != .done) {
        const input_end = @min(encoded.len, input_offset + 1);
        const output_end = @min(decoded.len, output_offset + 1);
        const step = try decoder.step(encoded[input_offset..input_end], decoded[output_offset..output_end]);
        input_offset += step.progress.input_read;
        output_offset += step.progress.output_written;
    }
    try decoder.finish();
    try std.testing.expectEqualSlices(u8, expected, &decoded);
}

test "byte-progressive compressed literal decoder captures following metadata" {
    const metadata = "stream metadata";
    const encoded = try br.IncrementalTestSupport.encodeCompressedHelloThenMetadataAndStoredBlocks(std.testing.allocator, metadata, &.{"!"});
    defer std.testing.allocator.free(encoded);
    var metadata_output: [6]u8 = undefined;
    var block_lengths: [1]usize = undefined;
    var decoder = br.IncrementalLiteralStreamDecoder.initWithOptions(.{
        .expected_output_len = 6,
        .metadata_output = &metadata_output,
        .metadata_block_lengths = &block_lengths,
    });
    var decoded: [6]u8 = undefined;
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (decoder.snapshot().phase != .done) {
        const input_end = @min(encoded.len, input_offset + 1);
        const step = try decoder.step(encoded[input_offset..input_end], decoded[output_offset..][0..@min(2, decoded.len - output_offset)]);
        input_offset += step.progress.input_read;
        output_offset += step.progress.output_written;
    }
    try decoder.finish();
    try std.testing.expectEqualSlices(u8, "hello!", &decoded);
    const snapshot = decoder.snapshot();
    try std.testing.expectEqualSlices(u8, metadata[0..metadata_output.len], &metadata_output);
    try std.testing.expectEqual(metadata.len, snapshot.metadata_total);
    try std.testing.expectEqual(@as(usize, 1), snapshot.metadata_block_count);
    try std.testing.expectEqual(metadata.len, block_lengths[0]);
}

test "byte-progressive compressed literal decoder crosses insert and length boundaries" {
    inline for (.{ 5, 66, 130, 578, 65_535, 65_536 }) |len| {
        const encoded = try br.IncrementalTestSupport.encodeCompressedLiteralCycle(std.testing.allocator, len);
        defer std.testing.allocator.free(encoded);
        const decoded = try std.testing.allocator.alloc(u8, len);
        defer std.testing.allocator.free(decoded);
        var decoder = br.IncrementalLiteralStreamDecoder.initWithOptions(.{
            .max_output_len = len,
            .expected_output_len = len,
        });
        var input_offset: usize = 0;
        var output_offset: usize = 0;
        while (decoder.snapshot().phase != .done) {
            const input_end = @min(encoded.len, input_offset + 7);
            const output_end = @min(decoded.len, output_offset + 257);
            const step = try decoder.step(encoded[input_offset..input_end], decoded[output_offset..output_end]);
            input_offset += step.progress.input_read;
            output_offset += step.progress.output_written;
        }
        try decoder.finish();
        try std.testing.expectEqual(encoded.len, input_offset);
        try std.testing.expectEqual(len, output_offset);
        for (decoded, 0..) |byte, i| try std.testing.expectEqual("abcd"[i & 3], byte);
    }
}

test "byte-progressive compressed literal decoder enforces bounds and framing" {
    const encoded = try br.IncrementalTestSupport.encodeCompressedLiteralCycle(std.testing.allocator, 257);
    defer std.testing.allocator.free(encoded);

    var limited = br.IncrementalLiteralStreamDecoder.initWithOptions(.{ .max_output_len = 256 });
    try std.testing.expectError(error.OutputLimitExceeded, limited.step(encoded, &.{}));
    var wrong_size = br.IncrementalLiteralStreamDecoder.initWithOptions(.{ .expected_output_len = 258 });
    try std.testing.expectError(error.SizeMismatch, wrong_size.step(encoded, &.{}));

    var truncated = br.IncrementalLiteralStreamDecoder.init();
    var output: [257]u8 = undefined;
    _ = try truncated.step(encoded[0 .. encoded.len - 1], &output);
    try std.testing.expectError(error.TruncatedFrame, truncated.finish());
    try std.testing.expectEqualStrings("truncated_input", truncated.diagnostics().recoverability_hint_name);

    var trailing_bytes: [512]u8 = undefined;
    @memcpy(trailing_bytes[0..encoded.len], encoded);
    trailing_bytes[encoded.len] = 0xff;
    var trailing = br.IncrementalLiteralStreamDecoder.init();
    try std.testing.expectError(error.TrailingData, trailing.step(trailing_bytes[0 .. encoded.len + 1], &output));
}

test "byte-progressive compressed literal decoder rejects copy commands" {
    const encoded = try br.encodeRleStreamAlloc(std.testing.allocator, "a" ** 64);
    defer std.testing.allocator.free(encoded);
    var decoder = br.IncrementalLiteralStreamDecoder.init();
    try std.testing.expectError(error.UnsupportedBrotliFeature, decoder.step(encoded, &.{}));
}
