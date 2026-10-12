const std = @import("std");
const checksum = @import("../checksum.zig");
const core = @import("../core.zig");
const header = @import("header.zig");
const lzop = @import("../lzop.zig");

test "LZOP incremental decoder accepts split concatenated streams and tiny output" {
    const first = ("incremental LZOP compressed payload\n" ** 96) ++ ([_]u8{0xa5} ** 97);
    const second = "stored second LZOP stream" ** 37;
    const first_frame = try lzop.encodeAlloc(std.testing.allocator, first, .{
        .block_size = 127,
        .checksum = .crc32,
        .compressed_checksum = true,
        .header_checksum = .crc32,
        .filename = "first.bin",
    });
    defer std.testing.allocator.free(first_frame);
    const second_frame = try lzop.encodeStoredAlloc(std.testing.allocator, second, .{
        .block_size = 61,
        .checksum = .adler32,
        .filename = "second.bin",
    });
    defer std.testing.allocator.free(second_frame);

    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    try encoded.appendSlice(std.testing.allocator, first_frame);
    try encoded.appendSlice(std.testing.allocator, second_frame);

    var decoder = lzop.IncrementalDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = first.len + second.len,
        .max_output_len = first.len + second.len,
        .max_block_size = 127,
    });
    defer decoder.deinit();
    const decoded = try decodeSplit(&decoder, encoded.items, 3, 7);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, first ++ second, decoded);

    const snap = decoder.snapshot();
    try std.testing.expectEqual(lzop.IncrementalDecoder.Phase.done, snap.phase);
    try std.testing.expectEqual(@as(usize, 2), snap.stream_count);
    try std.testing.expectEqual(
        (first.len + 126) / 127 + (second.len + 60) / 61,
        snap.block_count,
    );
    try std.testing.expect(snap.compressed_block_count != 0);
    try std.testing.expect(snap.stored_block_count != 0);
    try std.testing.expectEqual(first.len + second.len, snap.output_written);
    try std.testing.expect(snap.retained_compressed_capacity <= 127);
    try std.testing.expect(snap.retained_decoded_capacity <= 127);

    decoder.reset();
    try std.testing.expectEqual(lzop.IncrementalDecoder.Phase.header, decoder.snapshot().phase);
    try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().stream_count);
}

test "LZOP incremental decoder honors zero-sized output backpressure" {
    const plain = "zero output LZOP backpressure" ** 32;
    const frame = try lzop.encodeAlloc(std.testing.allocator, plain, .{ .block_size = plain.len });
    defer std.testing.allocator.free(frame);
    var decoder = lzop.IncrementalDecoder.init(std.testing.allocator);
    defer decoder.deinit();

    const blocked = try decoder.step(frame, &.{});
    try std.testing.expectEqual(core.StepResult.Status.need_output, blocked.status);
    try std.testing.expectEqual(@as(usize, 0), blocked.progress.output_written);
    try std.testing.expect(blocked.progress.input_read < frame.len);
    try std.testing.expectEqual(plain.len, decoder.snapshot().pending_output);

    var output: [plain.len]u8 = undefined;
    const drained = try decoder.step(frame[blocked.progress.input_read..], &output);
    try std.testing.expectEqual(core.StepResult.Status.need_input, drained.status);
    try std.testing.expectEqual(frame.len - blocked.progress.input_read, drained.progress.input_read);
    try decoder.finish();
    try std.testing.expectEqualSlices(u8, plain, &output);
}

test "LZOP incremental decoder validates complete blocks before output" {
    const plain = "checksum-before-output LZOP block" ** 128;
    const frame = try lzop.encodeAlloc(std.testing.allocator, plain, .{
        .block_size = plain.len,
        .checksum = .crc32,
        .compressed_checksum = true,
    });
    defer std.testing.allocator.free(frame);
    const stream_header = try header.parse(frame);
    var payload_offset = stream_header.encoded_size;
    const uncompressed_len = readU32(frame, &payload_offset);
    const compressed_len = readU32(frame, &payload_offset);
    try std.testing.expect(compressed_len < uncompressed_len);
    if (stream_header.flags & header.Flag.adler32_data != 0) payload_offset += 4;
    if (stream_header.flags & header.Flag.crc32_data != 0) payload_offset += 4;
    if (stream_header.flags & header.Flag.adler32_compressed != 0) payload_offset += 4;
    if (stream_header.flags & header.Flag.crc32_compressed != 0) payload_offset += 4;

    const corrupt = try std.testing.allocator.dupe(u8, frame);
    defer std.testing.allocator.free(corrupt);
    corrupt[payload_offset] ^= 0x40;
    var output: [plain.len]u8 = @splat(0xcc);
    var decoder = lzop.IncrementalDecoder.init(std.testing.allocator);
    defer decoder.deinit();
    try std.testing.expectError(error.ChecksumMismatch, decoder.step(corrupt, &output));
    try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().output_written);
    try std.testing.expectEqualSlices(u8, &([_]u8{0xcc} ** plain.len), &output);
    try std.testing.expectEqualStrings("ChecksumMismatch", decoder.diagnostics().last_error_name);
    try std.testing.expectEqualStrings("payload_corrupt", decoder.diagnostics().recoverability_hint_name);
}

test "LZOP incremental decoder enforces header block and output bounds" {
    const plain = "bounded incremental LZOP" ** 16;
    const frame = try lzop.encodeAlloc(std.testing.allocator, plain, .{ .block_size = 83 });
    defer std.testing.allocator.free(frame);

    var header_limited = lzop.IncrementalDecoder.initWithOptions(std.testing.allocator, .{
        .max_header_len = header.magic.len - 1,
    });
    defer header_limited.deinit();
    try std.testing.expectError(error.OutputLimitExceeded, header_limited.step(frame, &.{}));

    var block_limited = lzop.IncrementalDecoder.initWithOptions(std.testing.allocator, .{
        .max_block_size = 82,
    });
    defer block_limited.deinit();
    try std.testing.expectError(error.OutputLimitExceeded, block_limited.step(frame, &.{}));

    var output_limited = lzop.IncrementalDecoder.initWithOptions(std.testing.allocator, .{
        .max_output_len = plain.len - 1,
    });
    defer output_limited.deinit();
    var output: [plain.len]u8 = undefined;
    try std.testing.expectError(error.OutputLimitExceeded, output_limited.step(frame, &output));

    var exact_short = lzop.IncrementalDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = plain.len - 1,
    });
    defer exact_short.deinit();
    try std.testing.expectError(error.SizeMismatch, exact_short.step(frame, &output));

    var exact_long = lzop.IncrementalDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = plain.len + 1,
    });
    defer exact_long.deinit();
    const result = try exact_long.step(frame, &output);
    try std.testing.expectEqual(core.StepResult.Status.need_input, result.status);
    try std.testing.expectError(error.SizeMismatch, exact_long.finish());
}

test "LZOP incremental decoder reports truncation in header payload and terminator" {
    const plain = "truncated incremental LZOP" ** 64;
    const frame = try lzop.encodeAlloc(std.testing.allocator, plain, .{ .block_size = plain.len });
    defer std.testing.allocator.free(frame);
    const stream_header = try header.parse(frame);

    const cuts = [_]usize{
        header.magic.len - 1,
        stream_header.encoded_size + 2,
        frame.len - 5,
        frame.len - 1,
    };
    for (cuts) |cut| {
        var decoder = lzop.IncrementalDecoder.init(std.testing.allocator);
        defer decoder.deinit();
        var output: [plain.len]u8 = undefined;
        var offset: usize = 0;
        while (offset < cut) {
            const result = try decoder.step(frame[offset..cut], &output);
            offset += result.progress.input_read;
            if (result.status == .need_output) continue;
        }
        try std.testing.expectError(error.TruncatedFrame, decoder.finish());
        try std.testing.expectEqualStrings("truncated_input", decoder.diagnostics().recoverability_hint_name);
    }
}

test "LZOP incremental header probe accepts bounded extra fields" {
    var stream = try lzop.encodeStoredAlloc(std.testing.allocator, "", .{});
    defer std.testing.allocator.free(stream);
    const parsed = try header.parse(stream);
    const original_header_len = parsed.encoded_size;
    const flags_offset = header.magic.len + 2 + 2 + 2 + 1 + 1;
    const flags = std.mem.readInt(u32, stream[flags_offset..][0..4], .big) | header.Flag.extra_field;
    std.mem.writeInt(u32, stream[flags_offset..][0..4], flags, .big);
    const checksum_offset = original_header_len - 4;
    std.mem.writeInt(u32, stream[checksum_offset..][0..4], checksum.adler32(stream[header.magic.len..checksum_offset]), .big);

    var extended: std.ArrayList(u8) = .empty;
    defer extended.deinit(std.testing.allocator);
    try extended.appendSlice(std.testing.allocator, stream[0..original_header_len]);
    const extra_start = extended.items.len;
    try header.appendU32(std.testing.allocator, &extended, 5);
    try extended.appendSlice(std.testing.allocator, "extra");
    try header.appendU32(std.testing.allocator, &extended, checksum.adler32(extended.items[extra_start..]));
    try extended.appendSlice(std.testing.allocator, stream[original_header_len..]);

    var decoder = lzop.IncrementalDecoder.initWithOptions(std.testing.allocator, .{
        .max_header_len = extended.items.len - 4,
        .expected_output_len = 0,
    });
    defer decoder.deinit();
    const decoded = try decodeSplit(&decoder, extended.items, 1, 1);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqual(@as(usize, 0), decoded.len);

    var limited = lzop.IncrementalDecoder.initWithOptions(std.testing.allocator, .{
        .max_header_len = original_header_len,
    });
    defer limited.deinit();
    try std.testing.expectError(error.OutputLimitExceeded, limited.step(extended.items, &.{}));
}

test "LZOP incremental decoder releases every allocation failure" {
    const plain = ("allocation-safe incremental LZOP" ** 64) ++ "tail";
    const frame = try lzop.encodeAlloc(std.testing.allocator, plain, .{
        .block_size = 73,
        .compressed_checksum = true,
    });
    defer std.testing.allocator.free(frame);

    const Test = struct {
        fn run(allocator: std.mem.Allocator, encoded: []const u8, expected: []const u8) !void {
            var decoder = lzop.IncrementalDecoder.initWithOptions(allocator, .{
                .expected_output_len = expected.len,
                .max_block_size = 73,
            });
            defer decoder.deinit();
            const output = try allocator.alloc(u8, expected.len);
            defer allocator.free(output);
            var input_offset: usize = 0;
            var output_offset: usize = 0;
            while (input_offset < encoded.len) {
                const result = try decoder.step(encoded[input_offset..], output[output_offset..]);
                input_offset += result.progress.input_read;
                output_offset += result.progress.output_written;
            }
            try decoder.finish();
            try std.testing.expectEqualSlices(u8, expected, output[0..output_offset]);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Test.run, .{ frame, plain });
}

fn decodeSplit(
    decoder: *lzop.IncrementalDecoder,
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
    try decoder.finish();
    const done = try decoder.step("", scratch);
    try decoded.appendSlice(std.testing.allocator, scratch[0..done.progress.output_written]);
    try std.testing.expectEqual(core.StepResult.Status.done, done.status);
    return decoded.toOwnedSlice(std.testing.allocator);
}

fn readU32(bytes: []const u8, offset: *usize) u32 {
    const value = std.mem.readInt(u32, bytes[offset.*..][0..4], .big);
    offset.* += 4;
    return value;
}
