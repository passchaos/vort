const std = @import("std");
const framing = @import("../snappy_framing.zig");

fn encodeWithoutFlush(
    allocator: std.mem.Allocator,
    encoder: anytype,
    input: []const u8,
    input_step: usize,
    output_step: usize,
) ![]u8 {
    std.debug.assert(input_step != 0 and output_step != 0 and output_step <= 64);
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    var temporary: [64]u8 = undefined;
    var input_offset: usize = 0;
    while (input_offset < input.len) {
        const input_end = @min(input.len, input_offset + input_step);
        const step = try encoder.step(input[input_offset..input_end], temporary[0..output_step]);
        if (step.progress.input_read == 0 and step.progress.output_written == 0)
            return error.InvalidBlockPlan;
        input_offset += step.progress.input_read;
        try output.appendSlice(allocator, temporary[0..step.progress.output_written]);
    }
    encoder.finish();
    while (!encoder.snapshot().done) {
        const step = try encoder.step("", temporary[0..output_step]);
        if (step.progress.output_written == 0 and step.status != .done)
            return error.InvalidBlockPlan;
        try output.appendSlice(allocator, temporary[0..step.progress.output_written]);
    }
    return output.toOwnedSlice(allocator);
}

fn acceptInput(
    allocator: std.mem.Allocator,
    encoder: anytype,
    output: *std.ArrayList(u8),
    input: []const u8,
    input_step: usize,
    output_step: usize,
) !void {
    var temporary: [64]u8 = undefined;
    var input_offset: usize = 0;
    while (input_offset < input.len) {
        const input_end = @min(input.len, input_offset + input_step);
        const step = try encoder.step(input[input_offset..input_end], temporary[0..output_step]);
        if (step.progress.input_read == 0 and step.progress.output_written == 0)
            return error.InvalidBlockPlan;
        input_offset += step.progress.input_read;
        try output.appendSlice(allocator, temporary[0..step.progress.output_written]);
    }
}

fn acknowledgeFlush(
    allocator: std.mem.Allocator,
    encoder: anytype,
    output: *std.ArrayList(u8),
    output_step: usize,
) !void {
    var temporary: [64]u8 = undefined;
    encoder.flush();
    while (true) {
        const step = try encoder.step("", temporary[0..output_step]);
        try output.appendSlice(allocator, temporary[0..step.progress.output_written]);
        if (step.status == .need_input) return;
        if (step.progress.output_written == 0) return error.InvalidBlockPlan;
    }
}

fn finishEncoding(
    allocator: std.mem.Allocator,
    encoder: anytype,
    output: *std.ArrayList(u8),
    output_step: usize,
) !void {
    var temporary: [64]u8 = undefined;
    encoder.finish();
    while (!encoder.snapshot().done) {
        const step = try encoder.step("", temporary[0..output_step]);
        try output.appendSlice(allocator, temporary[0..step.progress.output_written]);
        if (step.progress.output_written == 0 and step.status != .done)
            return error.InvalidBlockPlan;
    }
}

test "Snappy framing incremental encoders match one-shot wire" {
    const allocator = std.testing.allocator;
    const xerial_payload = "Xerial incremental encode alpha beta gamma\n" ** 1024;
    const xerial_options = framing.XerialOptions{ .block_size = 4096 };
    const xerial_expected = try framing.encodeXerialAlloc(allocator, xerial_payload, xerial_options);
    defer allocator.free(xerial_expected);
    var xerial_encoder = try framing.XerialIncrementalEncoder.initExactSize(allocator, .{
        .block_size = xerial_options.block_size,
        .max_input_len = xerial_payload.len,
        .max_pending_output_len = 1024 * 1024,
    }, xerial_payload.len);
    defer xerial_encoder.deinit();
    const xerial_actual = try encodeWithoutFlush(allocator, &xerial_encoder, xerial_payload, 3, 7);
    defer allocator.free(xerial_actual);
    try std.testing.expectEqualSlices(u8, xerial_expected, xerial_actual);
    const xerial_archive = try framing.parseXerial(xerial_actual);
    try std.testing.expectEqual(xerial_archive.chunk_count, xerial_encoder.snapshot().chunk_count);
    try std.testing.expectEqual(xerial_payload.len, xerial_encoder.snapshot().input_read);

    const hadoop_payload = "Hadoop incremental encode alpha beta gamma\n" ** 2048;
    const hadoop_options = framing.HadoopOptions{ .block_size = 16 * 1024, .chunk_size = 2048 };
    const hadoop_expected = try framing.encodeHadoopAlloc(allocator, hadoop_payload, hadoop_options);
    defer allocator.free(hadoop_expected);
    var hadoop_encoder = try framing.HadoopIncrementalEncoder.initExactSize(allocator, .{
        .block_size = hadoop_options.block_size,
        .chunk_size = hadoop_options.chunk_size,
        .max_input_len = hadoop_payload.len,
        .max_pending_output_len = 1024 * 1024,
    }, hadoop_payload.len);
    defer hadoop_encoder.deinit();
    const hadoop_actual = try encodeWithoutFlush(allocator, &hadoop_encoder, hadoop_payload, 5, 11);
    defer allocator.free(hadoop_actual);
    try std.testing.expectEqualSlices(u8, hadoop_expected, hadoop_actual);
    const hadoop_archive = try framing.parseHadoop(hadoop_actual);
    try std.testing.expectEqual(hadoop_archive.block_count, hadoop_encoder.snapshot().block_count);
    try std.testing.expectEqual(hadoop_archive.chunk_count, hadoop_encoder.snapshot().chunk_count);
}

test "Snappy framing incremental encoders preserve empty wire" {
    const allocator = std.testing.allocator;
    const xerial_expected = try framing.encodeXerialAlloc(allocator, "", .{});
    defer allocator.free(xerial_expected);
    var xerial_encoder = try framing.XerialIncrementalEncoder.initExactSize(allocator, .{}, 0);
    defer xerial_encoder.deinit();
    const xerial_actual = try encodeWithoutFlush(allocator, &xerial_encoder, "", 1, 1);
    defer allocator.free(xerial_actual);
    try std.testing.expectEqualSlices(u8, xerial_expected, xerial_actual);

    const hadoop_expected = try framing.encodeHadoopAlloc(allocator, "", .{});
    defer allocator.free(hadoop_expected);
    var hadoop_encoder = try framing.HadoopIncrementalEncoder.initExactSize(allocator, .{}, 0);
    defer hadoop_encoder.deinit();
    const hadoop_actual = try encodeWithoutFlush(allocator, &hadoop_encoder, "", 1, 1);
    defer allocator.free(hadoop_actual);
    try std.testing.expectEqualSlices(u8, hadoop_expected, hadoop_actual);
}

test "Snappy framing incremental encoder flush closes current boundaries" {
    const allocator = std.testing.allocator;
    const payload = "explicit flush changes ecosystem framing boundaries" ** 64;
    inline for (.{
        .{ framing.XerialIncrementalEncoder, framing.XerialIncrementalDecoder, framing.encodeXerialAlloc, framing.XerialOptions{} },
        .{ framing.HadoopIncrementalEncoder, framing.HadoopIncrementalDecoder, framing.encodeHadoopAlloc, framing.HadoopOptions{} },
    }) |case| {
        const one_shot = try case[2](allocator, payload, case[3]);
        defer allocator.free(one_shot);
        var encoder = try case[0].initExactSize(allocator, .{}, payload.len);
        defer encoder.deinit();
        var encoded: std.ArrayList(u8) = .empty;
        defer encoded.deinit(allocator);
        const middle = payload.len / 3;
        try acceptInput(allocator, &encoder, &encoded, payload[0..middle], 13, 17);
        try acknowledgeFlush(allocator, &encoder, &encoded, 17);
        try acknowledgeFlush(allocator, &encoder, &encoded, 17);
        try acceptInput(allocator, &encoder, &encoded, payload[middle..], 13, 17);
        try finishEncoding(allocator, &encoder, &encoded, 17);
        try std.testing.expect(!std.mem.eql(u8, one_shot, encoded.items));

        var decoder = case[1].initWithOptions(allocator, .{ .expected_output_len = payload.len });
        defer decoder.deinit();
        var decoded: [payload.len]u8 = undefined;
        const step = try decoder.step(encoded.items, &decoded);
        try std.testing.expectEqual(encoded.items.len, step.progress.input_read);
        var decoded_offset = step.progress.output_written;
        try decoder.finish();
        while (decoder.snapshot().phase != .done) {
            const drain = try decoder.step("", decoded[decoded_offset..]);
            decoded_offset += drain.progress.output_written;
            try std.testing.expect(drain.progress.output_written != 0 or drain.status == .done);
        }
        try std.testing.expectEqual(payload.len, decoded_offset);
        try std.testing.expectEqualSlices(u8, payload, &decoded);
    }
}

test "Snappy framing incremental encoders enforce backpressure and limits" {
    const allocator = std.testing.allocator;
    const payload = "encoder backpressure payload" ** 32;
    var xerial_encoder = try framing.XerialIncrementalEncoder.initExactSize(allocator, .{
        .block_size = payload.len,
        .max_input_len = payload.len,
    }, payload.len);
    defer xerial_encoder.deinit();
    const blocked = try xerial_encoder.step(payload, &.{});
    try std.testing.expectEqual(@as(usize, 0), blocked.progress.input_read);
    try std.testing.expect(blocked.status == .need_output);
    var header: [framing.xerial_header.len]u8 = undefined;
    const header_step = try xerial_encoder.step(payload, &header);
    try std.testing.expectEqualSlices(u8, &framing.xerial_header, &header);
    try std.testing.expectEqual(@as(usize, 0), header_step.progress.input_read);
    const payload_step = try xerial_encoder.step(payload, &.{});
    try std.testing.expectEqual(payload.len, payload_step.progress.input_read);
    try std.testing.expect(payload_step.status == .need_output);

    try std.testing.expectError(error.InvalidBlockPlan, framing.XerialIncrementalEncoder.initWithOptions(allocator, .{ .block_size = 0 }));
    try std.testing.expectError(error.InvalidBlockPlan, framing.HadoopIncrementalEncoder.initWithOptions(allocator, .{ .chunk_size = 0 }));
    try std.testing.expectError(error.OutputLimitExceeded, framing.XerialIncrementalEncoder.initExactSize(allocator, .{ .max_input_len = payload.len - 1 }, payload.len));

    var header_limited = try framing.XerialIncrementalEncoder.initWithOptions(allocator, .{ .max_pending_output_len = 1 });
    defer header_limited.deinit();
    try std.testing.expectError(error.OutputLimitExceeded, header_limited.step("", &.{}));

    var input_limited = try framing.XerialIncrementalEncoder.initWithOptions(allocator, .{
        .block_size = payload.len,
        .max_input_len = payload.len - 1,
    });
    defer input_limited.deinit();
    var large_output: [4096]u8 = undefined;
    try std.testing.expectError(error.OutputLimitExceeded, input_limited.step(payload, &large_output));

    var pending_limited = try framing.HadoopIncrementalEncoder.initWithOptions(allocator, .{
        .block_size = payload.len,
        .chunk_size = payload.len,
        .max_pending_output_len = 1,
    });
    defer pending_limited.deinit();
    try std.testing.expectError(error.OutputLimitExceeded, pending_limited.step(payload, &.{}));

    var pledged = try framing.HadoopIncrementalEncoder.initExactSize(allocator, .{}, payload.len - 1);
    defer pledged.deinit();
    try std.testing.expectError(error.SizeMismatch, pledged.step(payload, &.{}));

    var short = try framing.XerialIncrementalEncoder.initExactSize(allocator, .{ .block_size = payload.len }, payload.len + 1);
    defer short.deinit();
    _ = try short.step(payload, &large_output);
    short.finish();
    try std.testing.expectError(error.SizeMismatch, short.step("", &large_output));
}

test "Snappy framing incremental encoders reset retained scratch" {
    const allocator = std.testing.allocator;
    const payload = "retained encoder scratch" ** 64;
    var encoder = try framing.HadoopIncrementalEncoder.initExactSize(allocator, .{
        .block_size = 512,
        .chunk_size = 128,
    }, payload.len);
    defer encoder.deinit();
    const first = try encodeWithoutFlush(allocator, &encoder, payload, 19, 23);
    defer allocator.free(first);
    const retained = encoder.snapshot();
    try encoder.resetExactSize(.{ .block_size = 512, .chunk_size = 128 }, payload.len);
    const reset = encoder.snapshot();
    try std.testing.expectEqual(retained.retained_plain_capacity, reset.retained_plain_capacity);
    try std.testing.expectEqual(retained.retained_encoded_capacity, reset.retained_encoded_capacity);
    try std.testing.expectEqual(retained.retained_pending_capacity, reset.retained_pending_capacity);
    const second = try encodeWithoutFlush(allocator, &encoder, payload, 7, 13);
    defer allocator.free(second);
    try std.testing.expectEqualSlices(u8, first, second);
}

test "Snappy framing incremental encoders clean up allocation failures" {
    const allocator = std.testing.allocator;
    const xerial_payload = "xerial encoder allocation payload" ** 32;
    const xerial_options = framing.XerialOptions{ .block_size = 256 };
    const xerial_expected = try framing.encodeXerialAlloc(allocator, xerial_payload, xerial_options);
    defer allocator.free(xerial_expected);
    const XerialTest = struct {
        fn run(active: std.mem.Allocator, input: []const u8, expected: []const u8) !void {
            var encoder = try framing.XerialIncrementalEncoder.initExactSize(active, .{ .block_size = 256 }, input.len);
            defer encoder.deinit();
            const actual = try encodeWithoutFlush(active, &encoder, input, 17, 31);
            defer active.free(actual);
            try std.testing.expectEqualSlices(u8, expected, actual);
        }
    };
    try std.testing.checkAllAllocationFailures(allocator, XerialTest.run, .{ xerial_payload, xerial_expected });

    const hadoop_payload = "hadoop encoder allocation payload" ** 32;
    const hadoop_options = framing.HadoopOptions{ .block_size = 512, .chunk_size = 128 };
    const hadoop_expected = try framing.encodeHadoopAlloc(allocator, hadoop_payload, hadoop_options);
    defer allocator.free(hadoop_expected);
    const HadoopTest = struct {
        fn run(active: std.mem.Allocator, input: []const u8, expected: []const u8) !void {
            var encoder = try framing.HadoopIncrementalEncoder.initExactSize(active, .{ .block_size = 512, .chunk_size = 128 }, input.len);
            defer encoder.deinit();
            const actual = try encodeWithoutFlush(active, &encoder, input, 17, 31);
            defer active.free(actual);
            try std.testing.expectEqualSlices(u8, expected, actual);
        }
    };
    try std.testing.checkAllAllocationFailures(allocator, HadoopTest.run, .{ hadoop_payload, hadoop_expected });
}
