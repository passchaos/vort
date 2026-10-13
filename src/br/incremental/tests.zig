const std = @import("std");
const br = @import("../../br.zig");

test "Brotli incremental decoder accepts split input and tiny output" {
    const payload = "split Brotli input payload " ** 32;
    const encoded = try br.IncrementalTestSupport.encodeStored(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);

    var decoder = br.IncrementalStreamDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = payload.len,
    });
    defer decoder.deinit();
    var output: [payload.len]u8 = undefined;
    var offset: usize = 0;
    var written: usize = 0;
    var saw_output_before_finish = false;
    while (decoder.snapshot().phase != .done) {
        const input_end = @min(encoded.len, offset + 2);
        const output_end = @min(output.len, written + 5);
        const result = try decoder.step(encoded[offset..input_end], output[written..output_end]);
        offset += result.progress.input_read;
        written += result.progress.output_written;
        saw_output_before_finish = saw_output_before_finish or
            (written != 0 and offset < encoded.len);
    }
    try decoder.finish();
    try std.testing.expect(saw_output_before_finish);
    try std.testing.expectEqual(encoded.len, offset);
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
    try std.testing.expectError(error.OutputLimitExceeded, output_limited.step(encoded, &.{}));

    var exact = br.IncrementalStreamDecoder.initWithOptions(std.testing.allocator, .{ .expected_output_len = 8 });
    defer exact.deinit();
    var exact_output: [8]u8 = undefined;
    try std.testing.expectError(error.SizeMismatch, exact.step(encoded, &exact_output));

    var truncated = br.IncrementalStreamDecoder.init(std.testing.allocator);
    defer truncated.deinit();
    var truncated_output: [7]u8 = undefined;
    var truncated_input_offset: usize = 0;
    var truncated_output_offset: usize = 0;
    while (truncated_input_offset < encoded.len - 1) {
        const step = try truncated.step(
            encoded[truncated_input_offset .. encoded.len - 1],
            truncated_output[truncated_output_offset..],
        );
        truncated_input_offset += step.progress.input_read;
        truncated_output_offset += step.progress.output_written;
    }
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

test "Brotli incremental decoder reuses allocations across framed payloads" {
    const first_payload = "first framed Brotli payload" ** 8;
    const first = try br.IncrementalTestSupport.encodeStored(std.testing.allocator, first_payload);
    defer std.testing.allocator.free(first);
    const second = try br.IncrementalTestSupport.encodeCompressedHello(std.testing.allocator);
    defer std.testing.allocator.free(second);

    var decoder = br.IncrementalStreamDecoder.initExactCompressedSize(std.testing.allocator, .{
        .expected_output_len = first_payload.len,
    }, first.len);
    defer decoder.deinit();
    var first_output: [first_payload.len]u8 = undefined;
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (decoder.snapshot().phase != .done) {
        const step = try decoder.step(first[input_offset..], first_output[output_offset..]);
        input_offset += step.progress.input_read;
        output_offset += step.progress.output_written;
    }
    try std.testing.expectEqualSlices(u8, first_payload, &first_output);
    try std.testing.expectEqual(@as(usize, 1), decoder.snapshot().frame_count);
    try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().frame_index);

    try decoder.nextFrameExactCompressedSize(.{ .expected_output_len = 5 }, second.len);
    var second_output: [5]u8 = undefined;
    input_offset = 0;
    output_offset = 0;
    while (decoder.snapshot().phase != .done) {
        const step = try decoder.step(second[input_offset..], second_output[output_offset..]);
        input_offset += step.progress.input_read;
        output_offset += step.progress.output_written;
    }
    try std.testing.expectEqualSlices(u8, "hello", &second_output);
    const snapshot = decoder.snapshot();
    try std.testing.expectEqual(@as(usize, 2), snapshot.frame_count);
    try std.testing.expectEqual(@as(usize, 1), snapshot.frame_index);
    try std.testing.expectEqual(first.len + second.len, snapshot.total_compressed);
    try std.testing.expectEqual(first_payload.len + second_output.len, snapshot.total_output);
}

test "Brotli incremental decoder rejects early next frame" {
    var decoder = br.IncrementalStreamDecoder.init(std.testing.allocator);
    defer decoder.deinit();
    try std.testing.expectError(error.InvalidBlockPlan, decoder.nextFrame(.{}));
}

test "Brotli incremental decoder streams compressed output before finish" {
    const prefix = "abcd";
    const repeat_count = 8193;
    const encoded = try br.encodeRepeatedPrefixStreamAlloc(std.testing.allocator, prefix, repeat_count);
    defer std.testing.allocator.free(encoded);
    const expected_len = prefix.len * repeat_count;
    const output = try std.testing.allocator.alloc(u8, expected_len);
    defer std.testing.allocator.free(output);
    var decoder = br.IncrementalStreamDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = expected_len,
        .max_history_len = 32,
    });
    defer decoder.deinit();
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    var saw_early_output = false;
    while (decoder.snapshot().phase != .done) {
        const input_end = @min(encoded.len, input_offset + 1);
        const output_end = @min(output.len, output_offset + 7);
        const step = try decoder.step(encoded[input_offset..input_end], output[output_offset..output_end]);
        input_offset += step.progress.input_read;
        output_offset += step.progress.output_written;
        saw_early_output = saw_early_output or (output_offset != 0 and input_offset < encoded.len);
        try std.testing.expect(decoder.snapshot().retained_input_bytes <= br.default_incremental_compressed_header_bytes);
    }
    try decoder.finish();
    try std.testing.expect(saw_early_output);
    try std.testing.expectEqual(encoded.len, input_offset);
    try std.testing.expectEqual(expected_len, output_offset);
    for (output, 0..) |byte, index| try std.testing.expectEqual(prefix[index % prefix.len], byte);
}

test "Brotli incremental decoder releases every owned history allocation failure" {
    const payload = "owned progressive history" ** 32;
    const encoded = try br.IncrementalTestSupport.encodeStored(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);
    const Test = struct {
        fn run(allocator: std.mem.Allocator, stream: []const u8, expected: []const u8) !void {
            var decoder = br.IncrementalStreamDecoder.initWithOptions(allocator, .{
                .expected_output_len = expected.len,
                .max_history_len = expected.len,
            });
            defer decoder.deinit();
            const output = try allocator.alloc(u8, expected.len);
            defer allocator.free(output);
            var input_offset: usize = 0;
            var output_offset: usize = 0;
            while (decoder.snapshot().phase != .done) {
                const step = try decoder.step(stream[input_offset..], output[output_offset..]);
                input_offset += step.progress.input_read;
                output_offset += step.progress.output_written;
            }
            try std.testing.expectEqualSlices(u8, expected, output);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Test.run, .{ encoded, payload });
}

test "Brotli incremental decoder forwards metadata and external header scratch" {
    const metadata = "owned facade metadata";
    const encoded = try br.IncrementalTestSupport.encodeMetadataThenCompressedHello(std.testing.allocator, metadata);
    defer std.testing.allocator.free(encoded);
    var metadata_output: [metadata.len]u8 = undefined;
    var metadata_lengths: [1]usize = undefined;
    var decoder = br.IncrementalStreamDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = 5,
        .metadata_output = &metadata_output,
        .metadata_block_lengths = &metadata_lengths,
    });
    defer decoder.deinit();
    var output: [5]u8 = undefined;
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (decoder.snapshot().phase != .done) {
        const input_end = @min(encoded.len, input_offset + 1);
        const output_end = @min(output.len, output_offset + 1);
        const step = try decoder.step(encoded[input_offset..input_end], output[output_offset..output_end]);
        input_offset += step.progress.input_read;
        output_offset += step.progress.output_written;
    }
    try std.testing.expectEqualSlices(u8, "hello", &output);
    try std.testing.expectEqualSlices(u8, metadata, &metadata_output);
    try std.testing.expectEqual(metadata.len, metadata_lengths[0]);

    const large_header = try br.IncrementalTestSupport.encodeLargeCompressedHeader(std.testing.allocator);
    defer std.testing.allocator.free(large_header);
    const header_scratch = try std.testing.allocator.alloc(u8, large_header.len);
    defer std.testing.allocator.free(header_scratch);
    try decoder.nextFrameExactCompressedSize(.{
        .expected_output_len = 1,
        .compressed_header_scratch = header_scratch,
    }, large_header.len);
    var large_output: [1]u8 = undefined;
    input_offset = 0;
    output_offset = 0;
    while (decoder.snapshot().phase != .done) {
        const input_end = @min(large_header.len, input_offset + 257);
        const step = try decoder.step(large_header[input_offset..input_end], large_output[output_offset..]);
        input_offset += step.progress.input_read;
        output_offset += step.progress.output_written;
    }
    try std.testing.expectEqualSlices(u8, "x", &large_output);
}
