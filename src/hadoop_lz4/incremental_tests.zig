const std = @import("std");
const hadoop_lz4 = @import("../hadoop_lz4.zig");

fn encodeIncremental(
    allocator: std.mem.Allocator,
    encoder: *hadoop_lz4.IncrementalEncoder,
    input: []const u8,
    input_step: usize,
    output_step: usize,
) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    const temporary = try allocator.alloc(u8, output_step);
    defer allocator.free(temporary);
    var input_offset: usize = 0;
    while (input_offset < input.len) {
        const input_end = @min(input.len, input_offset + input_step);
        const step = try encoder.step(input[input_offset..input_end], temporary);
        if (step.progress.input_read == 0 and step.progress.output_written == 0)
            return error.InvalidBlockPlan;
        input_offset += step.progress.input_read;
        try output.appendSlice(allocator, temporary[0..step.progress.output_written]);
    }
    encoder.finish();
    while (!encoder.snapshot().done) {
        const step = try encoder.step("", temporary);
        if (step.progress.output_written == 0 and step.status != .done)
            return error.InvalidBlockPlan;
        try output.appendSlice(allocator, temporary[0..step.progress.output_written]);
    }
    return output.toOwnedSlice(allocator);
}

fn decodeIncremental(
    allocator: std.mem.Allocator,
    encoded: []const u8,
    expected: []const u8,
    input_step: usize,
    output_step: usize,
) !hadoop_lz4.IncrementalDecoder.Snapshot {
    var decoder = hadoop_lz4.IncrementalDecoder.initWithOptions(allocator, .{
        .max_compressed_chunk_len = 1024 * 1024,
        .max_decoded_chunk_len = 1024 * 1024,
        .max_output_len = expected.len,
        .expected_output_len = expected.len,
    });
    defer decoder.deinit();
    const output = try allocator.alloc(u8, expected.len);
    defer allocator.free(output);
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (input_offset < encoded.len) {
        const input_end = @min(encoded.len, input_offset + input_step);
        const output_end = @min(output.len, output_offset + output_step);
        const step = try decoder.step(encoded[input_offset..input_end], output[output_offset..output_end]);
        if (step.progress.input_read == 0 and step.progress.output_written == 0)
            return error.InvalidBlockPlan;
        input_offset += step.progress.input_read;
        output_offset += step.progress.output_written;
    }
    try decoder.finish();
    while (decoder.snapshot().phase != .done) {
        const output_end = @min(output.len, output_offset + output_step);
        const step = try decoder.step("", output[output_offset..output_end]);
        if (step.progress.output_written == 0 and step.status != .done)
            return error.InvalidBlockPlan;
        output_offset += step.progress.output_written;
    }
    try std.testing.expectEqual(expected.len, output_offset);
    try std.testing.expectEqualSlices(u8, expected, output);
    return decoder.snapshot();
}

fn appendInput(
    allocator: std.mem.Allocator,
    encoder: *hadoop_lz4.IncrementalEncoder,
    output: *std.ArrayList(u8),
    input: []const u8,
) !void {
    var temporary: [17]u8 = undefined;
    var input_offset: usize = 0;
    while (input_offset < input.len) {
        const input_end = @min(input.len, input_offset + 13);
        const step = try encoder.step(input[input_offset..input_end], &temporary);
        if (step.progress.input_read == 0 and step.progress.output_written == 0)
            return error.InvalidBlockPlan;
        input_offset += step.progress.input_read;
        try output.appendSlice(allocator, temporary[0..step.progress.output_written]);
    }
}

fn acknowledgeFlush(
    allocator: std.mem.Allocator,
    encoder: *hadoop_lz4.IncrementalEncoder,
    output: *std.ArrayList(u8),
) !void {
    var temporary: [17]u8 = undefined;
    encoder.flush();
    while (true) {
        const step = try encoder.step("", &temporary);
        try output.appendSlice(allocator, temporary[0..step.progress.output_written]);
        if (step.status == .need_input) return;
        if (step.progress.output_written == 0) return error.InvalidBlockPlan;
    }
}

fn finishEncoding(
    allocator: std.mem.Allocator,
    encoder: *hadoop_lz4.IncrementalEncoder,
    output: *std.ArrayList(u8),
) !void {
    var temporary: [17]u8 = undefined;
    encoder.finish();
    while (!encoder.snapshot().done) {
        const step = try encoder.step("", &temporary);
        try output.appendSlice(allocator, temporary[0..step.progress.output_written]);
        if (step.progress.output_written == 0 and step.status != .done)
            return error.InvalidBlockPlan;
    }
}

test "Hadoop LZ4 incremental encode is exact and decode is fragmented" {
    const allocator = std.testing.allocator;
    const payload = "Hadoop LZ4 incremental alpha beta gamma\n" ** 2048;
    const options = hadoop_lz4.Options{ .block_size = 16 * 1024, .chunk_size = 2048 };
    const expected = try hadoop_lz4.encodeAlloc(allocator, payload, options);
    defer allocator.free(expected);
    var encoder = try hadoop_lz4.IncrementalEncoder.initExactSize(allocator, .{
        .block_size = options.block_size,
        .chunk_size = options.chunk_size,
        .max_input_len = payload.len,
        .max_pending_output_len = 1024 * 1024,
    }, payload.len);
    defer encoder.deinit();
    const actual = try encodeIncremental(allocator, &encoder, payload, 5, 11);
    defer allocator.free(actual);
    try std.testing.expectEqualSlices(u8, expected, actual);
    const archive = try hadoop_lz4.parse(actual);
    try std.testing.expectEqual(archive.block_count, encoder.snapshot().block_count);
    try std.testing.expectEqual(archive.chunk_count, encoder.snapshot().chunk_count);

    const snapshot = try decodeIncremental(allocator, actual, payload, 3, 7);
    try std.testing.expectEqual(archive.block_count, snapshot.block_count);
    try std.testing.expectEqual(archive.chunk_count, snapshot.chunk_count);
}

test "Hadoop LZ4 incremental empty flush reset and backpressure" {
    const allocator = std.testing.allocator;
    var empty_encoder = try hadoop_lz4.IncrementalEncoder.initExactSize(allocator, .{}, 0);
    defer empty_encoder.deinit();
    const empty = try encodeIncremental(allocator, &empty_encoder, "", 1, 1);
    defer allocator.free(empty);
    try std.testing.expectEqual(@as(usize, 0), empty.len);
    var empty_decoder = hadoop_lz4.IncrementalDecoder.initWithOptions(allocator, .{ .expected_output_len = 0 });
    defer empty_decoder.deinit();
    try empty_decoder.finish();

    const payload = "explicit Hadoop LZ4 flush boundary" ** 64;
    const one_shot = try hadoop_lz4.encodeAlloc(allocator, payload, .{});
    defer allocator.free(one_shot);
    var encoder = try hadoop_lz4.IncrementalEncoder.initExactSize(allocator, .{}, payload.len);
    defer encoder.deinit();
    var flushed: std.ArrayList(u8) = .empty;
    defer flushed.deinit(allocator);
    const middle = payload.len / 3;
    try appendInput(allocator, &encoder, &flushed, payload[0..middle]);
    try acknowledgeFlush(allocator, &encoder, &flushed);
    try acknowledgeFlush(allocator, &encoder, &flushed);
    try appendInput(allocator, &encoder, &flushed, payload[middle..]);
    try finishEncoding(allocator, &encoder, &flushed);
    try std.testing.expect(!std.mem.eql(u8, one_shot, flushed.items));
    const decoded = try hadoop_lz4.decodeAlloc(allocator, flushed.items);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);

    const retained = encoder.snapshot();
    try encoder.resetExactSize(.{}, payload.len);
    try std.testing.expectEqual(retained.retained_plain_capacity, encoder.snapshot().retained_plain_capacity);
    try std.testing.expectEqual(retained.retained_encoded_capacity, encoder.snapshot().retained_encoded_capacity);
    try std.testing.expectEqual(retained.retained_pending_capacity, encoder.snapshot().retained_pending_capacity);

    const framed = try hadoop_lz4.encodeAlloc(allocator, payload, .{ .block_size = payload.len, .chunk_size = payload.len });
    defer allocator.free(framed);
    var decoder = hadoop_lz4.IncrementalDecoder.initWithOptions(allocator, .{ .expected_output_len = payload.len });
    defer decoder.deinit();
    const blocked = try decoder.step(framed, &.{});
    try std.testing.expect(blocked.status == .need_output);
    try std.testing.expect(blocked.progress.input_read > 0);
    var output: [payload.len]u8 = undefined;
    var input_offset = blocked.progress.input_read;
    var output_offset: usize = 0;
    while (input_offset < framed.len) {
        const step = try decoder.step(framed[input_offset..], output[output_offset..]);
        input_offset += step.progress.input_read;
        output_offset += step.progress.output_written;
    }
    try decoder.finish();
    while (decoder.snapshot().phase != .done) {
        const step = try decoder.step("", output[output_offset..]);
        output_offset += step.progress.output_written;
    }
    try std.testing.expectEqualSlices(u8, payload, output[0..output_offset]);
}

test "Hadoop LZ4 incremental limits malformed and allocation failures" {
    const allocator = std.testing.allocator;
    const payload = "Hadoop LZ4 limits payload" ** 32;
    const encoded = try hadoop_lz4.encodeAlloc(allocator, payload, .{ .block_size = 512, .chunk_size = 128 });
    defer allocator.free(encoded);

    var output_limited = hadoop_lz4.IncrementalDecoder.initWithOptions(allocator, .{ .max_output_len = 1 });
    defer output_limited.deinit();
    try std.testing.expectError(error.OutputLimitExceeded, output_limited.step(encoded, &.{}));
    var compressed_limited = hadoop_lz4.IncrementalDecoder.initWithOptions(allocator, .{ .max_compressed_chunk_len = 1 });
    defer compressed_limited.deinit();
    try std.testing.expectError(error.OutputLimitExceeded, compressed_limited.step(encoded, &.{}));

    const corrupt = try allocator.dupe(u8, encoded);
    defer allocator.free(corrupt);
    std.mem.writeInt(u32, corrupt[0..4], 1, .big);
    var malformed = hadoop_lz4.IncrementalDecoder.init(allocator);
    defer malformed.deinit();
    var output: [payload.len]u8 = undefined;
    try std.testing.expectError(error.InvalidHadoopLz4Stream, malformed.step(corrupt, &output));

    var pending_limited = try hadoop_lz4.IncrementalEncoder.initWithOptions(allocator, .{
        .block_size = 512,
        .chunk_size = 128,
        .max_pending_output_len = 1,
    });
    defer pending_limited.deinit();
    try std.testing.expectError(error.OutputLimitExceeded, pending_limited.step(payload, &.{}));
    var input_limited = try hadoop_lz4.IncrementalEncoder.initWithOptions(allocator, .{ .max_input_len = payload.len - 1 });
    defer input_limited.deinit();
    try std.testing.expectError(error.OutputLimitExceeded, input_limited.step(payload, &output));

    const EncoderTest = struct {
        fn run(active: std.mem.Allocator, input: []const u8, expected: []const u8) !void {
            var encoder = try hadoop_lz4.IncrementalEncoder.initExactSize(active, .{ .block_size = 512, .chunk_size = 128 }, input.len);
            defer encoder.deinit();
            const actual = try encodeIncremental(active, &encoder, input, 17, 31);
            defer active.free(actual);
            try std.testing.expectEqualSlices(u8, expected, actual);
        }
    };
    try std.testing.checkAllAllocationFailures(allocator, EncoderTest.run, .{ payload, encoded });

    const DecoderTest = struct {
        fn run(active: std.mem.Allocator, frame: []const u8, expected: []const u8) !void {
            _ = try decodeIncremental(active, frame, expected, 17, 31);
        }
    };
    try std.testing.checkAllAllocationFailures(allocator, DecoderTest.run, .{ encoded, payload });
}
