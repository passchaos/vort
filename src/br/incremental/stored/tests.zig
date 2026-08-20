const std = @import("std");
const core = @import("../../../core.zig");
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

test "byte-progressive stored decoder captures bounded metadata" {
    const metadata = "captured Brotli metadata";
    const encoded = try br.encodeStoredStreamWithOptionsAlloc(std.testing.allocator, "payload", .{ .metadata = metadata });
    defer std.testing.allocator.free(encoded);
    var metadata_output: [8]u8 = undefined;
    var block_lengths: [1]usize = undefined;
    var decoder = br.IncrementalStoredStreamDecoder.initWithOptions(.{
        .metadata_output = &metadata_output,
        .metadata_block_lengths = &block_lengths,
    });
    var payload_output: [7]u8 = undefined;
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (input_offset < encoded.len) {
        const result = try decoder.step(encoded[input_offset .. input_offset + 1], payload_output[output_offset..]);
        input_offset += result.progress.input_read;
        output_offset += result.progress.output_written;
    }
    try decoder.finish();
    const snapshot = decoder.snapshot();
    try std.testing.expectEqualSlices(u8, metadata[0..metadata_output.len], &metadata_output);
    try std.testing.expectEqual(metadata_output.len, snapshot.metadata_written);
    try std.testing.expectEqual(metadata.len, snapshot.metadata_total);
    try std.testing.expect(snapshot.metadata_truncated);
    try std.testing.expectEqual(@as(usize, 1), snapshot.metadata_block_count);
    try std.testing.expectEqual(@as(usize, 1), snapshot.metadata_blocks_captured);
    try std.testing.expectEqual(metadata.len, block_lengths[0]);
    try std.testing.expect(!snapshot.metadata_blocks_truncated);
    try std.testing.expectEqualSlices(u8, "payload", &payload_output);
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

test "byte-progressive stored decoder continues framed streams" {
    const first_payload = "first stored decoder stream" ** 8;
    const second_payload = "second stored decoder stream" ** 6;
    const first = try br.encodeStoredStreamWithOptionsAlloc(std.testing.allocator, first_payload, .{ .window_bits = 18, .metadata = "first" });
    defer std.testing.allocator.free(first);
    const second = try br.encodeStoredStreamWithOptionsAlloc(std.testing.allocator, second_payload, .{ .window_bits = 22, .metadata = "second" });
    defer std.testing.allocator.free(second);
    var decoder = br.IncrementalStoredStreamDecoder.init();
    var first_output: [first_payload.len]u8 = undefined;
    _ = try decoder.step(first, &first_output);
    try decoder.finish();
    try std.testing.expectEqual(@as(usize, 1), decoder.snapshot().stream_count);
    try decoder.nextStream(.{});
    var second_output: [second_payload.len]u8 = undefined;
    _ = try decoder.step(second, &second_output);
    try decoder.finish();
    try std.testing.expectEqualSlices(u8, first_payload, &first_output);
    try std.testing.expectEqualSlices(u8, second_payload, &second_output);
    try std.testing.expectEqual(@as(usize, 2), decoder.snapshot().stream_count);
    try std.testing.expectEqual(first.len + second.len, decoder.snapshot().stream_input);
    try std.testing.expectEqual(first_payload.len + second_payload.len, decoder.snapshot().stream_output);
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

test "incremental stored encoder flushes and resumes" {
    const first = "first flushed Brotli stored segment";
    const second = "second Brotli stored segment";
    var encoder = br.IncrementalStoredStreamEncoder.initWithOptions(std.testing.allocator, .{
        .stream = .{ .window_bits = 21, .metadata = "flush-meta" },
        .block_len = 128,
    });
    defer encoder.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var scratch: [5]u8 = undefined;

    var first_offset: usize = 0;
    var result: core.StepResult = undefined;
    while (first_offset < first.len) {
        result = try encoder.step(first[first_offset..], &scratch);
        first_offset += result.progress.input_read;
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
    }
    encoder.flush();
    while (true) {
        result = try encoder.step("", &scratch);
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .need_input) break;
        try std.testing.expectEqual(.need_output, result.status);
    }
    try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().buffered_input);

    var second_offset: usize = 0;
    while (second_offset < second.len) {
        result = try encoder.step(second[second_offset..], &scratch);
        second_offset += result.progress.input_read;
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
    }
    encoder.flush();
    while (true) {
        result = try encoder.step("", &scratch);
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .need_input) break;
    }
    const flushed_len = encoded.items.len;
    encoder.flush();
    result = try encoder.step("", &scratch);
    try std.testing.expectEqual(.need_input, result.status);
    try std.testing.expectEqual(flushed_len, encoded.items.len);

    try encoder.finish();
    while (true) {
        result = try encoder.step("", &scratch);
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .done) break;
    }
    const decoded = try br.decodeStreamAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, first ++ second, decoded);

    encoder.reset();
    try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().input_read);
}

test "incremental stored encoder continues independent streams" {
    const first = "first stored Brotli stream" ** 16;
    const second = "second stored Brotli stream" ** 12;
    var encoder = br.IncrementalStoredStreamEncoder.initWithOptions(std.testing.allocator, .{
        .stream = .{ .window_bits = 18, .metadata = "first-meta" },
        .block_len = 64,
    });
    defer encoder.deinit();
    const first_encoded = try encodeStoredIncrementalTest(&encoder, first);
    defer std.testing.allocator.free(first_encoded);
    try std.testing.expectEqual(@as(usize, 1), encoder.snapshot().stream_count);
    try encoder.nextStream(.{
        .stream = .{ .window_bits = 22, .metadata = "second-meta" },
        .block_len = 31,
    });
    const second_encoded = try encodeStoredIncrementalTest(&encoder, second);
    defer std.testing.allocator.free(second_encoded);
    try std.testing.expectEqual(@as(usize, 2), encoder.snapshot().stream_count);
    try std.testing.expectEqual(@as(usize, 1), encoder.snapshot().stream_index);
    try std.testing.expectEqual(first.len + second.len, encoder.snapshot().input_read);
    const first_decoded = try br.decodeStreamAlloc(std.testing.allocator, first_encoded);
    defer std.testing.allocator.free(first_decoded);
    const second_decoded = try br.decodeStreamAlloc(std.testing.allocator, second_encoded);
    defer std.testing.allocator.free(second_decoded);
    try std.testing.expectEqualSlices(u8, first, first_decoded);
    try std.testing.expectEqualSlices(u8, second, second_decoded);
}

fn encodeStoredIncrementalTest(encoder: *br.IncrementalStoredStreamEncoder, payload: []const u8) ![]u8 {
    var encoded: std.ArrayList(u8) = .empty;
    errdefer encoded.deinit(std.testing.allocator);
    var scratch: [11]u8 = undefined;
    var offset: usize = 0;
    while (offset < payload.len) {
        const result = try encoder.step(payload[offset..], &scratch);
        offset += result.progress.input_read;
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
    }
    try encoder.finish();
    while (true) {
        const result = try encoder.step("", &scratch);
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .done) break;
    }
    return encoded.toOwnedSlice(std.testing.allocator);
}
