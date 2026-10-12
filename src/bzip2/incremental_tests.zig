const std = @import("std");
const bzip2 = @import("../bzip2.zig");
const block_decoder = @import("decoder.zig");
const core = @import("../core.zig");

const python_payload = "hello hello hello\n" ** 20;
const python_frame_hex = "425a6831314159265359e2c777e0000054d100001040000244a00030c002950c9a55855e13c4c2ad157c5dc914e142438b1ddf80";

test "Bzip2 incremental decoder accepts byte input tiny output and concatenation" {
    const frame = pythonFrame();
    var concatenated: [frame.len * 2]u8 = undefined;
    @memcpy(concatenated[0..frame.len], &frame);
    @memcpy(concatenated[frame.len..], &frame);

    var decoder = bzip2.IncrementalDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = python_payload.len * 2,
        .max_output_len = python_payload.len * 2,
        .max_compressed_block_len = 256,
        .max_decoded_block_len = python_payload.len,
    });
    defer decoder.deinit();
    const decoded = try decodeSplit(&decoder, &concatenated, 1, 7);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, python_payload ++ python_payload, decoded);

    const snap = decoder.snapshot();
    try std.testing.expectEqual(bzip2.IncrementalDecoder.Phase.done, snap.phase);
    try std.testing.expectEqual(@as(usize, 2), snap.stream_count);
    try std.testing.expectEqual(@as(usize, 2), snap.block_count);
    try std.testing.expectEqual(python_payload.len * 2, snap.output_written);
    try std.testing.expect(snap.buffered_bit_offset < 8);

    decoder.reset();
    try std.testing.expectEqual(bzip2.IncrementalDecoder.Phase.header, decoder.snapshot().phase);
    try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().stream_count);
}

test "Bzip2 incremental decoder crosses non-byte-aligned multi-block boundaries" {
    const input = try std.testing.allocator.alloc(u8, 100_321);
    defer std.testing.allocator.free(input);
    for (input, 0..) |*byte, index| byte.* = @truncate(index *% 73 +% index / 251);
    const encoded = try bzip2.encodeAlloc(std.testing.allocator, input, .{ .block_size_100k = 1 });
    defer std.testing.allocator.free(encoded);

    var decoder = bzip2.IncrementalDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = input.len,
        .max_output_len = input.len,
        .max_compressed_block_len = 4 * 1024 * 1024,
        .max_decoded_block_len = 100_000 * 259 / 5 + 4,
    });
    defer decoder.deinit();
    const decoded = try decodeSplit(&decoder, encoded, 11, 17);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
    try std.testing.expect(decoder.snapshot().block_count >= 2);
    try std.testing.expectEqual(@as(usize, 1), decoder.snapshot().stream_count);
}

test "Bzip2 incremental decoder honors zero-output backpressure" {
    const frame = pythonFrame();
    var decoder = bzip2.IncrementalDecoder.init(std.testing.allocator);
    defer decoder.deinit();
    const accepted = try decoder.step(&frame, &.{});
    try std.testing.expectEqual(frame.len, accepted.progress.input_read);
    try std.testing.expectEqual(core.StepResult.Status.need_input, accepted.status);
    decoder.finish();

    const blocked = try decoder.step("", &.{});
    try std.testing.expectEqual(core.StepResult.Status.need_output, blocked.status);
    try std.testing.expectEqual(@as(usize, 0), blocked.progress.output_written);
    try std.testing.expectEqual(python_payload.len, decoder.snapshot().pending_output);

    var output: [python_payload.len]u8 = undefined;
    const done = try decoder.step("", &output);
    try std.testing.expectEqual(core.StepResult.Status.done, done.status);
    try std.testing.expectEqualSlices(u8, python_payload, &output);
}

test "Bzip2 incremental decoder verifies block CRC before output" {
    var corrupt = pythonFrame();
    corrupt[10] ^= 1;
    var output: [python_payload.len]u8 = @splat(0xcc);
    var decoder = bzip2.IncrementalDecoder.init(std.testing.allocator);
    defer decoder.deinit();
    const accepted = try decoder.step(&corrupt, &output);
    try std.testing.expectEqual(core.StepResult.Status.need_input, accepted.status);
    decoder.finish();
    try std.testing.expectError(error.ChecksumMismatch, decoder.step("", &output));
    try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().output_written);
    try std.testing.expectEqualSlices(u8, &([_]u8{0xcc} ** python_payload.len), &output);
    try std.testing.expectEqualStrings("ChecksumMismatch", decoder.diagnostics().last_error_name);
}

test "Bzip2 incremental decoder verifies the member combined CRC" {
    var corrupt = pythonFrame();
    var transformed: std.ArrayList(u8) = .empty;
    defer transformed.deinit(std.testing.allocator);
    var decoded: std.ArrayList(u8) = .empty;
    defer decoded.deinit(std.testing.allocator);
    const part = try block_decoder.decodeIncrementalPart(
        std.testing.allocator,
        corrupt[4..],
        0,
        100_000,
        python_payload.len,
        &transformed,
        &decoded,
    );
    const block = switch (part) {
        .block => |value| value,
        .end => return error.TestUnexpectedResult,
    };
    const combined_crc_bit = block.next_bit_offset + 48;
    const crc_byte = 4 + combined_crc_bit / 8;
    const crc_shift: u3 = @intCast(7 - (combined_crc_bit & 7));
    corrupt[crc_byte] ^= @as(u8, 1) << crc_shift;
    try std.testing.expectError(error.ChecksumMismatch, bzip2.decodeAlloc(std.testing.allocator, &corrupt));

    var output: [python_payload.len]u8 = undefined;
    var decoder = bzip2.IncrementalDecoder.init(std.testing.allocator);
    defer decoder.deinit();
    _ = try decoder.step(&corrupt, &output);
    decoder.finish();
    try std.testing.expectError(error.ChecksumMismatch, drainFinished(&decoder, &output));
    try std.testing.expectEqual(python_payload.len, decoder.snapshot().output_written);
    try std.testing.expectEqualSlices(u8, python_payload, &output);
}

test "Bzip2 incremental decoder enforces compressed decoded and total limits" {
    const frame = pythonFrame();
    var scratch: [python_payload.len]u8 = undefined;

    var compressed_limited = bzip2.IncrementalDecoder.initWithOptions(std.testing.allocator, .{
        .max_compressed_block_len = 8,
    });
    defer compressed_limited.deinit();
    try std.testing.expectError(error.OutputLimitExceeded, compressed_limited.step(&frame, &scratch));

    var block_limited = bzip2.IncrementalDecoder.initWithOptions(std.testing.allocator, .{
        .max_decoded_block_len = python_payload.len - 1,
    });
    defer block_limited.deinit();
    _ = try block_limited.step(&frame, &scratch);
    block_limited.finish();
    try std.testing.expectError(error.OutputLimitExceeded, block_limited.step("", &scratch));

    var output_limited = bzip2.IncrementalDecoder.initWithOptions(std.testing.allocator, .{
        .max_output_len = python_payload.len - 1,
    });
    defer output_limited.deinit();
    _ = try output_limited.step(&frame, &scratch);
    output_limited.finish();
    try std.testing.expectError(error.OutputLimitExceeded, output_limited.step("", &scratch));

    var exact_short = bzip2.IncrementalDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = python_payload.len - 1,
    });
    defer exact_short.deinit();
    _ = try exact_short.step(&frame, &scratch);
    exact_short.finish();
    try std.testing.expectError(error.SizeMismatch, exact_short.step("", &scratch));

    var exact_long = bzip2.IncrementalDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = python_payload.len + 1,
    });
    defer exact_long.deinit();
    _ = try exact_long.step(&frame, &scratch);
    exact_long.finish();
    try std.testing.expectError(error.SizeMismatch, drainFinished(&exact_long, &scratch));
}

test "Bzip2 incremental decoder reports every truncated fixture prefix" {
    const frame = pythonFrame();
    var scratch: [31]u8 = undefined;
    for (0..frame.len) |cut| {
        var decoder = bzip2.IncrementalDecoder.init(std.testing.allocator);
        defer decoder.deinit();
        var offset: usize = 0;
        while (offset < cut) {
            const result = try decoder.step(frame[offset..cut], &scratch);
            offset += result.progress.input_read;
        }
        decoder.finish();
        try std.testing.expectError(error.TruncatedFrame, drainFinished(&decoder, &scratch));
        try std.testing.expectEqualStrings("truncated_input", decoder.diagnostics().recoverability_hint_name);
    }
}

test "Bzip2 incremental decoder releases every allocation failure" {
    const frame = pythonFrame();
    const Test = struct {
        fn run(allocator: std.mem.Allocator, encoded: []const u8) !void {
            var decoder = bzip2.IncrementalDecoder.initWithOptions(allocator, .{
                .expected_output_len = python_payload.len,
            });
            defer decoder.deinit();
            const output = try allocator.alloc(u8, python_payload.len);
            defer allocator.free(output);
            const accepted = try decoder.step(encoded, output);
            try std.testing.expectEqual(encoded.len, accepted.progress.input_read);
            decoder.finish();
            const done = try decoder.step("", output);
            try std.testing.expectEqual(core.StepResult.Status.done, done.status);
            try std.testing.expectEqualSlices(u8, python_payload, output);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Test.run, .{frame[0..]});
}

fn decodeSplit(
    decoder: *bzip2.IncrementalDecoder,
    encoded: []const u8,
    input_chunk_len: usize,
    output_chunk_len: usize,
) ![]u8 {
    var decoded: std.ArrayList(u8) = .empty;
    errdefer decoded.deinit(std.testing.allocator);
    const scratch = try std.testing.allocator.alloc(u8, output_chunk_len);
    defer std.testing.allocator.free(scratch);
    var input_offset: usize = 0;
    while (input_offset < encoded.len) {
        const input_end = @min(encoded.len, input_offset + input_chunk_len);
        const result = try decoder.step(encoded[input_offset..input_end], scratch);
        input_offset += result.progress.input_read;
        try decoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        try std.testing.expect(
            result.progress.input_read != 0 or
                result.progress.output_written != 0 or
                result.status == .need_input,
        );
    }
    decoder.finish();
    while (true) {
        const result = try decoder.step("", scratch);
        try decoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .done) break;
        try std.testing.expectEqual(core.StepResult.Status.need_output, result.status);
    }
    return decoded.toOwnedSlice(std.testing.allocator);
}

fn drainFinished(decoder: *bzip2.IncrementalDecoder, output: []u8) !void {
    while (true) {
        const result = try decoder.step("", output);
        if (result.status == .done) return;
    }
}

fn pythonFrame() [python_frame_hex.len / 2]u8 {
    var bytes: [python_frame_hex.len / 2]u8 = undefined;
    _ = std.fmt.hexToBytes(&bytes, python_frame_hex) catch unreachable;
    return bytes;
}
