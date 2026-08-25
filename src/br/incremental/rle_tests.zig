const std = @import("std");
const core = @import("../../core.zig");
const br = @import("../../br.zig");

test "byte-progressive compressed RLE decoder handles byte input and output backpressure" {
    const payload = "z" ** 4096;
    const encoded = try br.encodeRleStreamAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);
    var decoder = br.IncrementalRleStreamDecoder.initWithOptions(.{ .expected_output_len = payload.len });
    var decoded: [payload.len]u8 = undefined;
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (decoder.snapshot().phase != .done) {
        const input_end = @min(encoded.len, input_offset + 1);
        const output_end = @min(decoded.len, output_offset + 3);
        const step = try decoder.step(encoded[input_offset..input_end], decoded[output_offset..output_end]);
        input_offset += step.progress.input_read;
        output_offset += step.progress.output_written;
        if (step.status == .need_input) try std.testing.expect(input_offset < encoded.len);
        if (step.status == .need_output) try std.testing.expect(output_offset < decoded.len);
    }
    try decoder.finish();
    try std.testing.expectEqual(encoded.len, input_offset);
    try std.testing.expectEqual(payload.len, output_offset);
    try std.testing.expectEqualSlices(u8, payload, &decoded);
    try std.testing.expect(decoder.snapshot().retained_input_bytes <= 64);
}

test "byte-progressive compressed RLE decoder covers command extra-bit boundaries" {
    // These lengths cross several command-table ranges, including the 16-bit
    // meta-block length boundary and the widest copy-extra form used here.
    inline for (.{ 5, 71, 4096, 65_535, 65_536 }) |len| {
        const payload = try std.testing.allocator.alloc(u8, len);
        defer std.testing.allocator.free(payload);
        @memset(payload, @intCast(len & 0xff));
        const encoded = try br.encodeRleStreamAlloc(std.testing.allocator, payload);
        defer std.testing.allocator.free(encoded);
        const decoded = try std.testing.allocator.alloc(u8, len);
        defer std.testing.allocator.free(decoded);

        var decoder = br.IncrementalRleStreamDecoder.initWithOptions(.{
            .max_output_len = len,
            .expected_output_len = len,
        });
        var input_offset: usize = 0;
        var output_offset: usize = 0;
        while (decoder.snapshot().phase != .done) {
            const input_end = @min(encoded.len, input_offset + 2);
            const output_end = @min(decoded.len, output_offset + 257);
            const step = try decoder.step(encoded[input_offset..input_end], decoded[output_offset..output_end]);
            input_offset += step.progress.input_read;
            output_offset += step.progress.output_written;
        }
        try decoder.finish();
        try std.testing.expectEqual(encoded.len, input_offset);
        try std.testing.expectEqualSlices(u8, payload, decoded);
    }
}

test "byte-progressive compressed RLE decoder enforces limits truncation and trailing data" {
    const encoded = try br.encodeRleStreamAlloc(std.testing.allocator, "a" ** 257);
    defer std.testing.allocator.free(encoded);

    var limited = br.IncrementalRleStreamDecoder.initWithOptions(.{ .max_output_len = 256 });
    try std.testing.expectError(error.OutputLimitExceeded, limited.step(encoded, &.{}));

    var wrong_size = br.IncrementalRleStreamDecoder.initWithOptions(.{ .expected_output_len = 258 });
    try std.testing.expectError(error.SizeMismatch, wrong_size.step(encoded, &.{}));

    var truncated = br.IncrementalRleStreamDecoder.init();
    _ = try truncated.step(encoded[0 .. encoded.len - 1], &.{});
    try std.testing.expectError(error.TruncatedFrame, truncated.finish());
    try std.testing.expectEqualStrings("truncated_input", truncated.diagnostics().recoverability_hint_name);

    var trailing = br.IncrementalRleStreamDecoder.init();
    var output: [257]u8 = undefined;
    var with_trailing: [128]u8 = undefined;
    try std.testing.expect(encoded.len + 1 <= with_trailing.len);
    @memcpy(with_trailing[0..encoded.len], encoded);
    with_trailing[encoded.len] = 0xff;
    try std.testing.expectError(error.TrailingData, trailing.step(with_trailing[0 .. encoded.len + 1], &output));

    var corrupt_padding_bytes: [128]u8 = undefined;
    @memcpy(corrupt_padding_bytes[0..encoded.len], encoded);
    corrupt_padding_bytes[encoded.len - 1] |= 0x80;
    var corrupt_padding = br.IncrementalRleStreamDecoder.init();
    try std.testing.expectError(error.CorruptFrame, corrupt_padding.step(corrupt_padding_bytes[0..encoded.len], &output));
}

test "byte-progressive compressed RLE decoder rejects a broader compressed stream" {
    const encoded = try br.IncrementalTestSupport.encodeCompressedHello(std.testing.allocator);
    defer std.testing.allocator.free(encoded);
    var decoder = br.IncrementalRleStreamDecoder.init();
    try std.testing.expectError(error.UnsupportedBrotliFeature, decoder.step(encoded, &.{}));
    try std.testing.expectEqualStrings("unsupported_feature", decoder.diagnostics().recoverability_hint_name);
}
