const std = @import("std");
const core = @import("../../core.zig");
const snappy = @import("../../snappy.zig");

test "incremental frame decoder accepts split input and tiny output" {
    const payload = ("incremental snappy payload " ** 64) ++ ([_]u8{0xa5} ** 257);
    const frame = try snappy.encodeFrameAlloc(std.testing.allocator, payload[0..]);
    defer std.testing.allocator.free(frame);

    var framed: std.ArrayList(u8) = .empty;
    defer framed.deinit(std.testing.allocator);
    try framed.appendSlice(std.testing.allocator, frame[0..10]);
    try framed.appendSlice(std.testing.allocator, &.{ 0x80, 0, 0, 0 });
    try framed.appendSlice(std.testing.allocator, frame[10..]);

    var decoder = snappy.IncrementalFrameDecoder.init(std.testing.allocator);
    defer decoder.deinit();
    var decoded: [payload.len]u8 = undefined;
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (input_offset < framed.items.len) {
        const input_end = @min(framed.items.len, input_offset + 3);
        const output_end = @min(decoded.len, output_offset + 7);
        const result = try decoder.step(framed.items[input_offset..input_end], decoded[output_offset..output_end]);
        input_offset += result.progress.input_read;
        output_offset += result.progress.output_written;
        try std.testing.expect(result.progress.input_read != 0 or result.progress.output_written != 0 or result.status == .need_input);
    }
    try decoder.finish();
    while (true) {
        const output_end = @min(decoded.len, output_offset + 7);
        const result = try decoder.step("", decoded[output_offset..output_end]);
        output_offset += result.progress.output_written;
        if (result.status == .done) break;
        try std.testing.expectEqual(core.StepResult.Status.need_output, result.status);
    }
    try std.testing.expectEqual(payload.len, output_offset);
    try std.testing.expectEqualSlices(u8, payload[0..], &decoded);
    try std.testing.expect(decoder.snapshot().saw_identifier);
    try std.testing.expectEqual(snappy.IncrementalFrameDecoder.Phase.done, decoder.snapshot().phase);

    decoder.reset();
    try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().output_written);
    try std.testing.expectEqual(snappy.IncrementalFrameDecoder.Phase.header, decoder.snapshot().phase);
}

test "incremental frame decoder enforces limits and finish semantics" {
    const frame = try snappy.encodeFrameAlloc(std.testing.allocator, "bounded snappy frame");
    defer std.testing.allocator.free(frame);

    var output_limited = snappy.IncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{ .max_output_len = 3 });
    defer output_limited.deinit();
    try std.testing.expectError(error.OutputLimitExceeded, output_limited.step(frame, &.{}));
    try std.testing.expectEqualStrings("OutputLimitExceeded", output_limited.snapshot().last_error_name);

    var chunk_limited = snappy.IncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{ .max_chunk_payload_len = 5 });
    defer chunk_limited.deinit();
    try std.testing.expectError(error.OutputLimitExceeded, chunk_limited.step(frame, &.{}));

    var truncated = snappy.IncrementalFrameDecoder.init(std.testing.allocator);
    defer truncated.deinit();
    const partial = try truncated.step(frame[0 .. frame.len - 1], &.{});
    try std.testing.expectEqual(core.StepResult.Status.need_input, partial.status);
    try std.testing.expectError(error.TruncatedFrame, truncated.finish());
    try std.testing.expectEqualStrings("truncated_input", truncated.diagnostics().recoverability_hint_name);
}

test "incremental frame decoder enforces exact output size" {
    const frame = try snappy.encodeFrameAlloc(std.testing.allocator, "exact");
    defer std.testing.allocator.free(frame);
    var short = snappy.IncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{ .expected_output_len = 6 });
    defer short.deinit();
    var output: [8]u8 = undefined;
    _ = try short.step(frame, &output);
    try std.testing.expectError(error.SizeMismatch, short.finish());

    var long = snappy.IncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{ .expected_output_len = 4 });
    defer long.deinit();
    try std.testing.expectError(error.SizeMismatch, long.step(frame, &output));
}

test "incremental frame decoder drains uncompressed chunks" {
    // Framed Snappy chunk: identifier followed by an uncompressed "raw"
    // payload with the well-known masked CRC-32C value produced by Vort.
    const frame = try snappy.encodeFrameAlloc(std.testing.allocator, "raw");
    defer std.testing.allocator.free(frame);
    // The encoder selects the uncompressed representation when a raw block
    // would not be smaller, so this also pins the direct data-chunk branch.
    try std.testing.expectEqual(@as(u8, 0x01), frame[10]);
    var decoder = snappy.IncrementalFrameDecoder.init(std.testing.allocator);
    defer decoder.deinit();
    var output: [3]u8 = undefined;
    const first = try decoder.step(frame, output[0..1]);
    try std.testing.expectEqual(core.StepResult.Status.need_output, first.status);
    try decoder.finish();
    const second = try decoder.step("", output[1..]);
    try std.testing.expectEqual(core.StepResult.Status.done, second.status);
    try std.testing.expectEqualSlices(u8, "raw", &output);
}

test "incremental frame encoder accepts split input and tiny output" {
    const payload = ("incremental encode payload " ** 3000) ++ "tail";
    var encoder = snappy.IncrementalFrameEncoder.init(std.testing.allocator);
    defer encoder.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var input_offset: usize = 0;
    var output_buf: [11]u8 = undefined;
    while (input_offset < payload.len) {
        const end = @min(payload.len, input_offset + 137);
        const result = try encoder.step(payload[input_offset..end], &output_buf);
        input_offset += result.progress.input_read;
        try encoded.appendSlice(std.testing.allocator, output_buf[0..result.progress.output_written]);
    }
    try encoder.finish();
    while (true) {
        const result = try encoder.step("", &output_buf);
        try encoded.appendSlice(std.testing.allocator, output_buf[0..result.progress.output_written]);
        if (result.status == .done) break;
    }
    const decoded = try snappy.decodeFrameAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    try std.testing.expectEqual(payload.len, encoder.snapshot().input_read);
    encoder.reset();
    try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().input_read);
}

test "incremental frame encoder enforces input limit and finish" {
    var encoder = snappy.IncrementalFrameEncoder.initWithOptions(std.testing.allocator, .{ .max_input_len = 3 });
    defer encoder.deinit();
    var scratch: [64]u8 = undefined;
    try std.testing.expectError(error.OutputLimitExceeded, encoder.step("four", &scratch));
    encoder.reset();
    _ = try encoder.step("abc", &scratch);
    try encoder.finish();
    try std.testing.expectError(error.TrailingData, encoder.step("x", &scratch));
}

test "incremental frame encoder enforces pledged input size" {
    var encoder = snappy.IncrementalFrameEncoder.initExactSize(std.testing.allocator, .{}, 4);
    defer encoder.deinit();
    var scratch: [64]u8 = undefined;
    _ = try encoder.step("abc", &scratch);
    try encoder.finish();
    try std.testing.expectError(error.SizeMismatch, encoder.step("", &scratch));
    encoder.reset();
    try std.testing.expectError(error.SizeMismatch, encoder.step("abcde", &scratch));
}

test "incremental frame encoder flushes and resumes" {
    const first = "first flushed Snappy chunk";
    const second = "second Snappy chunk after flush";
    var encoder = snappy.IncrementalFrameEncoder.init(std.testing.allocator);
    defer encoder.deinit();
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    var scratch: [5]u8 = undefined;

    var first_offset: usize = 0;
    var result: core.StepResult = undefined;
    while (first_offset < first.len) {
        result = try encoder.step(first[first_offset..], &scratch);
        first_offset += result.progress.input_read;
        try frame.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
    }
    encoder.flush();
    while (true) {
        result = try encoder.step("", &scratch);
        try frame.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .need_input) break;
        try std.testing.expectEqual(.need_output, result.status);
    }
    try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().buffered_input);

    var offset: usize = 0;
    while (offset < second.len) {
        result = try encoder.step(second[offset..], &scratch);
        offset += result.progress.input_read;
        try frame.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
    }
    encoder.flush();
    while (true) {
        result = try encoder.step("", &scratch);
        try frame.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .need_input) break;
    }
    const flushed_len = frame.items.len;
    encoder.flush();
    result = try encoder.step("", &scratch);
    try std.testing.expectEqual(.need_input, result.status);
    try std.testing.expectEqual(flushed_len, frame.items.len);

    try encoder.finish();
    while (true) {
        result = try encoder.step("", &scratch);
        try frame.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .done) break;
    }
    const decoded = try snappy.decodeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, first ++ second, decoded);
    encoder.reset();
}

test "incremental Snappy encoder and decoder continue streams" {
    const first = "first framed Snappy stream" ** 32;
    const second = "second framed Snappy stream" ** 24;
    var encoder = snappy.IncrementalFrameEncoder.initExactSize(std.testing.allocator, .{}, first.len);
    defer encoder.deinit();
    const first_frame = try encodeIncrementalFrameTest(&encoder, first);
    defer std.testing.allocator.free(first_frame);
    try encoder.nextStreamExactSize(.{}, second.len);
    const second_frame = try encodeIncrementalFrameTest(&encoder, second);
    defer std.testing.allocator.free(second_frame);
    try std.testing.expectEqual(@as(usize, 2), encoder.snapshot().stream_count);
    try std.testing.expectEqual(first.len + second.len, encoder.snapshot().input_read);

    var decoder = snappy.IncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{ .expected_output_len = first.len });
    defer decoder.deinit();
    var first_output: [first.len]u8 = undefined;
    _ = try decoder.step(first_frame, &first_output);
    try decoder.finish();
    try decoder.nextStream(.{ .expected_output_len = second.len });
    var second_output: [second.len]u8 = undefined;
    _ = try decoder.step(second_frame, &second_output);
    try decoder.finish();
    try std.testing.expectEqualSlices(u8, first, &first_output);
    try std.testing.expectEqualSlices(u8, second, &second_output);
    try std.testing.expectEqual(@as(usize, 2), decoder.snapshot().stream_count);
    try std.testing.expectEqual(first.len + second.len, decoder.snapshot().total_output);
}

fn encodeIncrementalFrameTest(encoder: *snappy.IncrementalFrameEncoder, payload: []const u8) ![]u8 {
    var frame: std.ArrayList(u8) = .empty;
    errdefer frame.deinit(std.testing.allocator);
    var scratch: [17]u8 = undefined;
    var offset: usize = 0;
    while (offset < payload.len) {
        const result = try encoder.step(payload[offset..], &scratch);
        offset += result.progress.input_read;
        try frame.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
    }
    try encoder.finish();
    while (true) {
        const result = try encoder.step("", &scratch);
        try frame.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .done) break;
    }
    return frame.toOwnedSlice(std.testing.allocator);
}
