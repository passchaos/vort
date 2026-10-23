const std = @import("std");
const hadoop_lz4 = @import("../hadoop_lz4.zig");
const lz4 = @import("../lz4.zig");
const core = @import("../core.zig");

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

fn appendLength(out: *std.ArrayList(u8), value: usize) !void {
    var remaining = value;
    while (remaining >= 255) : (remaining -= 255) try out.append(std.testing.allocator, 255);
    try out.append(std.testing.allocator, @intCast(remaining));
}

fn historyBlock() ![]u8 {
    const allocator = std.testing.allocator;
    var raw: std.ArrayList(u8) = .empty;
    errdefer raw.deinit(allocator);
    try raw.append(allocator, 0xff);
    try appendLength(&raw, 65535 - 15);
    for (0..65535) |index| try raw.append(allocator, @intCast(index % 251));
    try raw.appendSlice(allocator, &.{ 0xff, 0xff }); // Match distance 65535.
    try appendLength(&raw, 4096 - 19);
    try raw.appendSlice(allocator, "\x50tail!");
    return raw.toOwnedSlice(allocator);
}

fn envelope(raw: []const u8, expected: usize) ![]u8 {
    const allocator = std.testing.allocator;
    const frame = try allocator.alloc(u8, 8 + raw.len);
    std.mem.writeInt(u32, frame[0..4], @intCast(expected), .big);
    std.mem.writeInt(u32, frame[4..8], @intCast(raw.len), .big);
    @memcpy(frame[8..], raw);
    return frame;
}

fn assertDecode(decoder: *hadoop_lz4.IncrementalDecoder, frame: []const u8, expected: []const u8, input_step: usize, output_step: usize) !void {
    var scratch: [4096]u8 = undefined;
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    var finished = decoder.input_finished;
    var calls: usize = 0;
    while (true) : (calls += 1) {
        try std.testing.expect(calls < (frame.len + expected.len + 1) * 4 + 64);
        if (input_offset == frame.len and !finished) {
            try decoder.finish();
            finished = true;
        }
        @memset(&scratch, 0xa5);
        const output = scratch[0..if (calls % 5 == 0) 0 else output_step];
        const input = frame[input_offset..][0..@min(input_step, frame.len - input_offset)];
        const before = decoder.snapshot();
        const step = try decoder.step(input, output);
        const after = decoder.snapshot();
        try std.testing.expectEqual(after.input_read - before.input_read, step.progress.input_read);
        try std.testing.expectEqual(after.output_written - before.output_written, step.progress.output_written);
        try std.testing.expectEqualDeep(step.progress, after.last_step_progress);
        try std.testing.expectEqualSlices(u8, expected[output_offset..][0..step.progress.output_written], output[0..step.progress.output_written]);
        for (output[step.progress.output_written..]) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
        try std.testing.expectEqual(@as(usize, 0), after.retained_decoded_capacity);
        try std.testing.expect(after.retained_history_capacity <= 64 * 1024);
        try std.testing.expectEqual(after.retained_compressed_capacity + after.retained_history_capacity, after.working_bytes);
        input_offset += step.progress.input_read;
        output_offset += step.progress.output_written;
        if (step.status == .done) break;
    }
    try std.testing.expectEqual(frame.len, input_offset);
    try std.testing.expectEqual(expected.len, output_offset);
}

fn expectSticky(decoder: *hadoop_lz4.IncrementalDecoder, err: anyerror) !void {
    const before = decoder.snapshot();
    var output: [7]u8 = @splat(0xa5);
    try std.testing.expectError(err, decoder.step("unaccepted", &output));
    try std.testing.expectEqual(before.input_read, decoder.snapshot().input_read);
    try std.testing.expectEqual(before.output_written, decoder.snapshot().output_written);
    try std.testing.expectEqualDeep(core.Progress{}, decoder.snapshot().last_step_progress);
    try std.testing.expectEqual(@as([7]u8, @splat(0xa5)), output);
}

test "Hadoop LZ4 incremental large raw history wraps with tiny output and active moves" {
    const allocator = std.testing.allocator;
    const raw = try historyBlock();
    defer allocator.free(raw);
    const expected = try lz4.decodeBlockAlloc(allocator, raw, null);
    defer allocator.free(expected);
    try std.testing.expectEqual(@as(usize, 65535 + 4096 + 5), expected.len);
    try std.testing.expectEqualSlices(u8, expected[0..4096], expected[65535..][0..4096]);
    const frame = try envelope(raw, expected.len);
    defer allocator.free(frame);
    var original = hadoop_lz4.IncrementalDecoder.init(allocator);
    const blocked = try original.step(frame, &.{});
    try std.testing.expectEqual(frame.len, blocked.progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), original.snapshot().retained_history_capacity);
    try std.testing.expectEqual(expected.len, original.snapshot().hadoop_block_decoded);
    try original.finish();
    var prefix: [3]u8 = undefined;
    _ = try original.step("", &prefix);
    try std.testing.expectEqualSlices(u8, expected[0..3], &prefix);
    var decoder = original;
    original = undefined;
    defer decoder.deinit();
    try assertDecode(&decoder, "", expected[3..], 1, 7);
    try std.testing.expectEqual(@as(usize, 64 * 1024), decoder.snapshot().retained_history_capacity);
    const retained = decoder.workingMemoryBytes();
    decoder.reset();
    try std.testing.expectEqual(retained, decoder.workingMemoryBytes());
    try std.testing.expectEqual(retained, decoder.peakWorkingMemoryBytes());
    try assertDecode(&decoder, frame, expected, 17, 13);
    decoder.resetWithOptions(.{ .expected_output_len = 2, .max_output_len = 1 });
    try std.testing.expectEqual(retained, decoder.workingMemoryBytes());
    try expectSticky(&decoder, error.InvalidBlockPlan);
    decoder.resetWithOptions(.{});
    try std.testing.expectEqual(@as(usize, 0), decoder.workingMemoryBytes());
    try assertDecode(&decoder, frame, expected, frame.len, 4096);
}

test "Hadoop LZ4 incremental body prevalidation and recoverable EOF preserve framing rules" {
    const allocator = std.testing.allocator;
    const bad = try envelope(&.{ 0x30, 'A', 'B', 'C', 0, 0 }, 7);
    defer allocator.free(bad);
    var decoder = hadoop_lz4.IncrementalDecoder.init(allocator);
    defer decoder.deinit();
    var guard: [17]u8 = @splat(0xa5);
    try std.testing.expectError(error.InvalidMatch, decoder.step(bad, &guard));
    try std.testing.expectEqual(bad.len, decoder.snapshot().last_step_progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().output_written);
    try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().retained_history_capacity);
    try std.testing.expectEqual(@as([17]u8, @splat(0xa5)), guard);
    try expectSticky(&decoder, error.InvalidMatch);
    const frame = try envelope("\x30ABC", 3);
    defer allocator.free(frame);
    decoder.reset();
    _ = try decoder.step(frame[0 .. frame.len - 1], &.{});
    try std.testing.expectError(error.TruncatedFrame, decoder.finish());
    try std.testing.expect(!decoder.input_finished);
    try assertDecode(&decoder, frame[frame.len - 1 ..], "ABC", 1, 1);
    var two: [24]u8 = undefined;
    @memcpy(two[0..12], frame);
    @memcpy(two[12..], frame);
    decoder.resetWithOptions(.{ .max_output_len = 5 });
    try std.testing.expectError(error.OutputLimitExceeded, decoder.step(&two, &guard));
    try std.testing.expectEqualDeep(core.Progress{ .input_read = frame.len + 4, .output_written = 3 }, decoder.snapshot().last_step_progress);
    try std.testing.expectEqualSlices(u8, "ABC", guard[0..3]);
    decoder.resetWithOptions(.{ .expected_output_len = 2 });
    try std.testing.expectError(error.SizeMismatch, decoder.step(frame, &.{}));
    try std.testing.expectEqual(@as(usize, 4), decoder.snapshot().last_step_progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), decoder.workingMemoryBytes());
}

test "Hadoop LZ4 incremental exact working budgets and backing denial precede new publication" {
    const allocator = std.testing.allocator;
    const raw = try historyBlock();
    defer allocator.free(raw);
    const expected = try lz4.decodeBlockAlloc(allocator, raw, null);
    defer allocator.free(expected);
    const frame = try envelope(raw, expected.len);
    defer allocator.free(frame);
    const output = try allocator.alloc(u8, expected.len);
    defer allocator.free(output);
    const peak = raw.len + 64 * 1024;
    inline for (.{ false, true }) |below| {
        var decoder = hadoop_lz4.IncrementalDecoder.initWithOptions(allocator, .{ .max_working_memory = peak - @intFromBool(below) });
        defer decoder.deinit();
        _ = try decoder.step(frame, &.{});
        try std.testing.expectEqual(raw.len, decoder.workingMemoryBytes());
        @memset(output, 0xa5);
        if (below) {
            try std.testing.expectError(error.WorkingMemoryLimitExceeded, decoder.step("", output));
            try std.testing.expectEqualDeep(core.Progress{}, decoder.snapshot().last_step_progress);
            for (output) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
            try expectSticky(&decoder, error.WorkingMemoryLimitExceeded);
        } else {
            _ = try decoder.step("", output);
            try decoder.finish();
            try std.testing.expectEqualSlices(u8, expected, output);
            try std.testing.expectEqual(peak, decoder.peakWorkingMemoryBytes());
        }
    }
    const first = "\x30ABC";
    const combined = try allocator.alloc(u8, 12 + 4 + raw.len);
    defer allocator.free(combined);
    std.mem.writeInt(u32, combined[0..4], @intCast(3 + expected.len), .big);
    std.mem.writeInt(u32, combined[4..8], first.len, .big);
    @memcpy(combined[8..12], first);
    std.mem.writeInt(u32, combined[12..16], @intCast(raw.len), .big);
    @memcpy(combined[16..], raw);
    var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 2, .resize_fail_index = 0 });
    {
        var decoder = hadoop_lz4.IncrementalDecoder.init(failing.allocator());
        defer decoder.deinit();
        var prefix: [17]u8 = @splat(0xa5);
        try std.testing.expectError(error.OutOfMemory, decoder.step(combined, &prefix));
        try std.testing.expectEqualDeep(core.Progress{ .input_read = 16, .output_written = 3 }, decoder.snapshot().last_step_progress);
        try std.testing.expectEqual(@as(?usize, 16), decoder.snapshot().error_input_offset);
        try std.testing.expectEqual(@as(?usize, 3), decoder.snapshot().error_output_offset);
        try std.testing.expectEqualSlices(u8, "ABC", prefix[0..3]);
        for (prefix[3..]) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
        try expectSticky(&decoder, error.OutOfMemory);
        failing.fail_index = std.math.maxInt(usize);
        failing.resize_fail_index = std.math.maxInt(usize);
        decoder.reset();
        try assertDecode(&decoder, frame, expected, frame.len, 4096);
    }
    try std.testing.expectEqual(failing.allocated_bytes, failing.freed_bytes);
}

test "Hadoop LZ4 incremental all compressed and history allocation failures remain movable and free" {
    const allocator = std.testing.allocator;
    const raw = try historyBlock();
    defer allocator.free(raw);
    const expected = try lz4.decodeBlockAlloc(allocator, raw, null);
    defer allocator.free(expected);
    const frame = try envelope(raw, expected.len);
    defer allocator.free(frame);
    const Graph = struct {
        fn run(active: std.mem.Allocator, input: []const u8, plain: []const u8) !void {
            var owner: ?hadoop_lz4.IncrementalDecoder = hadoop_lz4.IncrementalDecoder.init(active);
            defer if (owner) |*decoder| decoder.deinit();
            const decoder = &owner.?;
            assertDecode(decoder, input, plain, input.len, 4096) catch |err| {
                try expectSticky(decoder, err);
                return err;
            };
            decoder.reset();
            try assertDecode(decoder, input, plain, input.len, 4096);
            decoder.resetWithOptions(.{});
            var prefix: [3]u8 = undefined;
            _ = decoder.step(input, &prefix) catch |err| {
                try expectSticky(decoder, err);
                return err;
            };
            try std.testing.expectEqualSlices(u8, plain[0..3], &prefix);
            var moved = owner.?;
            owner = null;
            defer moved.deinit();
            try assertDecode(&moved, "", plain[3..], 1, 4096);
        }
    };
    try std.testing.checkAllAllocationFailures(allocator, Graph.run, .{ frame, expected });
}
