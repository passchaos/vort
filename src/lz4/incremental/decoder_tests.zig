const std = @import("std");
const core = @import("../../core.zig");
const lz4 = @import("../../lz4.zig");

const allocator = std.testing.allocator;
const block_len: usize = 64 * 1024;
const Decoder = lz4.NativeIncrementalFrameDecoder;

const DrainEvidence = struct {
    emitted_before_end: bool = false,
    max_compressed_capacity: usize = 0,
    max_history_capacity: usize = 0,
};

fn drain(
    decoder: *Decoder,
    frame: []const u8,
    expected: []const u8,
    input_chunk_len: usize,
    output_chunk_len: usize,
) !DrainEvidence {
    const output = try allocator.alloc(u8, expected.len);
    defer allocator.free(output);
    var read: usize = 0;
    var written: usize = 0;
    var evidence: DrainEvidence = .{};
    while (true) {
        const input_end = @min(frame.len, read + input_chunk_len);
        const output_end = @min(output.len, written + output_chunk_len);
        const result = try decoder.step(frame[read..input_end], output[written..output_end]);
        try std.testing.expect(result.progress.input_read <= input_end - read);
        try std.testing.expect(result.progress.output_written <= output_end - written);
        read += result.progress.input_read;
        written += result.progress.output_written;
        const snap = decoder.snapshot();
        try std.testing.expectEqual(read, snap.input_received);
        try std.testing.expectEqual(written, snap.output_written);
        evidence.emitted_before_end = evidence.emitted_before_end or (written != 0 and read < frame.len);
        evidence.max_compressed_capacity = @max(evidence.max_compressed_capacity, decoder.compressedBufferCapacity());
        evidence.max_history_capacity = @max(evidence.max_history_capacity, decoder.direct_history.capacity);
        try std.testing.expectEqual(@as(usize, 0), decoder.decodedBufferedBytes());
        try std.testing.expectEqual(@as(usize, 0), decoder.decodedBufferCapacity());
        if (result.status == .done) break;
        try std.testing.expect(result.progress.input_read != 0 or result.progress.output_written != 0);
    }
    try decoder.finish();
    try std.testing.expectEqual(frame.len, read);
    try std.testing.expectEqual(expected.len, written);
    try std.testing.expectEqualSlices(u8, expected, output);
    return evidence;
}

fn fillRandom(bytes: []u8, seed: u32) void {
    var state = seed;
    for (bytes) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
}

test "LZ4 default incremental streams large frames with bounded block and history memory" {
    const payload = try allocator.alloc(u8, block_len * 8 + 8192);
    defer allocator.free(payload);
    const pattern = "default-block-stream-0123456789abcdef";
    for (payload, 0..) |*byte, i| byte.* = pattern[i % pattern.len];
    for ([_]bool{ false, true }) |block_checksum| {
        for ([_]bool{ false, true }) |include_content_size| {
            for ([_]lz4.BlockMode{ .independent, .linked }) |block_mode| {
                const frame = try lz4.encodePureFrameWithOptionsAlloc(allocator, payload, .{
                    .block_size_id = .max64kb,
                    .block_mode = block_mode,
                    .include_content_size = include_content_size,
                    .block_checksum = block_checksum,
                    .content_checksum = true,
                });
                defer allocator.free(frame);
                var decoder = Decoder.init(allocator);
                defer decoder.deinit();
                try std.testing.expectEqual(core.CompressedInputPolicy.block_stream, decoder.options.input_policy);
                const evidence = try drain(&decoder, frame, payload, 257, 113);
                try std.testing.expect(evidence.emitted_before_end);
                try std.testing.expect(evidence.max_compressed_capacity <= if (block_checksum) block_len else 32);
                try std.testing.expect(evidence.max_history_capacity <= block_len);
                try std.testing.expectEqual(@as(usize, 9), decoder.streamedCompressedBlockCount());
                try std.testing.expectEqual(@as(usize, 0), decoder.compressedBufferedBytes());
            }
        }
    }
}

test "LZ4 default incremental raw blocks use caller input and respect output backpressure" {
    const payload = try allocator.alloc(u8, block_len * 6 + 123);
    defer allocator.free(payload);
    fillRandom(payload, 0x9153_7246);
    for ([_]lz4.BlockMode{ .independent, .linked }) |mode| {
        const frame = try lz4.encodePureFrameWithOptionsAlloc(allocator, payload, .{
            .block_size_id = .max64kb,
            .block_mode = mode,
            .block_checksum = false,
            .content_checksum = true,
        });
        defer allocator.free(frame);
        const first_block = (try lz4.inspectNativeFrameFirstBlock(frame)).?;
        try std.testing.expect(!first_block.is_compressed);
        var decoder = Decoder.init(allocator);
        defer decoder.deinit();
        const initial = try decoder.step(frame, &.{});
        try std.testing.expectEqual(core.StepResult.Status.need_output, initial.status);
        try std.testing.expectEqual(first_block.payload_offset, initial.progress.input_read);
        try std.testing.expectEqual(@as(usize, 0), decoder.compressedBufferedBytes());
        const stalled = try decoder.step(frame[initial.progress.input_read..], &.{});
        try std.testing.expectEqual(core.StepResult.Status.need_output, stalled.status);
        try std.testing.expectEqual(@as(usize, 0), stalled.progress.input_read);
        try std.testing.expectEqual(@as(usize, 0), stalled.progress.output_written);
        try std.testing.expectEqual(initial.progress.input_read, decoder.snapshot().input_received);
        decoder.reset();
        const evidence = try drain(&decoder, frame, payload, 509, 127);
        try std.testing.expect(evidence.emitted_before_end);
        try std.testing.expect(evidence.max_compressed_capacity <= 32);
        try std.testing.expect(evidence.max_history_capacity <= block_len);
        if (mode == .independent) try std.testing.expectEqual(@as(usize, 0), evidence.max_history_capacity);
        try std.testing.expectEqual(@as(usize, 0), decoder.streamedCompressedBlockCount());
    }
}

test "LZ4 default incremental raw block validates split checksum before any output" {
    var payload: [4096]u8 = undefined;
    fillRandom(&payload, 0x8432_1937);
    const frame = try lz4.encodePureFrameWithOptionsAlloc(allocator, &payload, .{
        .block_size_id = .max64kb,
        .block_checksum = true,
        .content_checksum = true,
    });
    defer allocator.free(frame);
    const block = (try lz4.inspectNativeFrameFirstBlock(frame)).?;
    try std.testing.expect(!block.is_compressed);
    const checksum_offset = block.block_checksum_offset.?;
    var decoder = Decoder.init(allocator);
    defer decoder.deinit();
    var output: [payload.len]u8 = @splat(0xa5);
    const prefix = try decoder.step(frame[0 .. checksum_offset + 3], &output);
    try std.testing.expectEqual(core.StepResult.Status.need_input, prefix.status);
    try std.testing.expectEqual(checksum_offset + 3, prefix.progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), prefix.progress.output_written);
    for (output) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
    const first_output = try decoder.step(frame[prefix.progress.input_read..], output[0..7]);
    try std.testing.expectEqual(core.StepResult.Status.need_output, first_output.status);
    try std.testing.expectEqual(@as(usize, 1), first_output.progress.input_read);
    try std.testing.expectEqual(@as(usize, 7), first_output.progress.output_written);
    try std.testing.expectError(error.OutputTooSmall, decoder.finish());
    const rest = try decoder.step(frame[checksum_offset + 4 ..], output[7..]);
    try std.testing.expectEqual(core.StepResult.Status.done, rest.status);
    try std.testing.expectEqualSlices(u8, &payload, &output);
    try std.testing.expectEqual(frame.len, decoder.snapshot().input_received);
    try std.testing.expectEqual(payload.len, decoder.snapshot().output_written);
    try std.testing.expect(decoder.compressedBufferCapacity() <= 8192);
    try std.testing.expectEqual(@as(usize, 0), decoder.decodedBufferCapacity());

    const corrupt = try allocator.dupe(u8, frame);
    defer allocator.free(corrupt);
    for ([_]usize{ block.payload_offset + 17, checksum_offset }) |corrupt_offset| {
        @memcpy(corrupt, frame);
        corrupt[corrupt_offset] ^= 1;
        @memset(&output, 0xa5);
        var bad = Decoder.init(allocator);
        defer bad.deinit();
        try std.testing.expectError(error.ChecksumMismatch, bad.step(corrupt, &output));
        try std.testing.expectEqual(@as(usize, 0), bad.snapshot().output_written);
        for (output) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
    }

    var limited = Decoder.initWithOptions(allocator, .{ .max_compressed_buffer_len = block.payload_len - 1 });
    defer limited.deinit();
    try std.testing.expectError(error.OutputLimitExceeded, limited.step(frame, &output));
    try std.testing.expectEqual(@as(usize, 0), limited.snapshot().output_written);
}

test "LZ4 explicit prevalidated input policy retains the complete frame path" {
    const payload = "explicit-prevalidation-0123456789abcdef" ** 8192;
    const frame = try lz4.encodePureFrameWithOptionsAlloc(allocator, payload, .{
        .include_content_size = false,
        .block_size_id = .max64kb,
        .content_checksum = true,
        .block_checksum = true,
    });
    defer allocator.free(frame);
    var decoder = Decoder.initWithOptions(allocator, .{ .input_policy = .prevalidated_frame });
    defer decoder.deinit();
    const output = try allocator.alloc(u8, payload.len);
    defer allocator.free(output);
    const prefix = try decoder.step(frame[0 .. frame.len / 2], output[0..17]);
    try std.testing.expectEqual(core.StepResult.Status.need_input, prefix.status);
    try std.testing.expectEqual(@as(usize, 0), prefix.progress.output_written);
    try std.testing.expectEqual(frame.len / 2, decoder.compressedBufferedBytes());
    const complete = try decoder.step(frame[prefix.progress.input_read..], &.{});
    try std.testing.expectEqual(core.StepResult.Status.need_output, complete.status);
    try std.testing.expectEqual(frame.len, decoder.compressedBufferedBytes());
    try std.testing.expect(!decoder.isBlockStreaming());
    const done = try decoder.step("", output);
    try std.testing.expectEqual(core.StepResult.Status.done, done.status);
    try std.testing.expectEqual(payload.len, done.progress.output_written);
    try std.testing.expectEqualSlices(u8, payload, output);
    try decoder.finish();
}

test "LZ4 default incremental dictionary set streams linked members and skippable metadata" {
    var first_dictionary_bytes: [4096]u8 = undefined;
    var second_dictionary_bytes: [4096]u8 = undefined;
    fillRandom(&first_dictionary_bytes, 0x4587_3961);
    fillRandom(&second_dictionary_bytes, 0x2914_8657);
    const dictionaries = [_]lz4.NativeDictionary{
        lz4.NativeDictionary.init(11, &first_dictionary_bytes),
        lz4.NativeDictionary.init(22, &second_dictionary_bytes),
    };
    const dictionary_set = lz4.NativeDictionarySet.init(&dictionaries);
    const payload_len = block_len * 2 + 109;
    const payloads = try allocator.alloc(u8, payload_len * 2);
    defer allocator.free(payloads);
    for (payloads[0..payload_len], 0..) |*byte, i| byte.* = first_dictionary_bytes[3072 + i % 1024];
    for (payloads[payload_len..], 0..) |*byte, i| byte.* = second_dictionary_bytes[3072 + i % 1024];
    for ([_]bool{ false, true }) |block_checksum| {
        const options: lz4.NativeFrameOptions = .{
            .include_content_size = false,
            .block_size_id = .max64kb,
            .block_mode = .linked,
            .block_checksum = block_checksum,
            .content_checksum = true,
        };
        const first = try lz4.encodeNativeFrameWithDictionaryAlloc(allocator, payloads[0..payload_len], options, dictionaries[0]);
        defer allocator.free(first);
        const second = try lz4.encodeNativeFrameWithDictionaryAlloc(allocator, payloads[payload_len..], options, dictionaries[1]);
        defer allocator.free(second);
        const metadata = "metadata between dictionary members" ** 2048;
        const skip = try lz4.encodeSkippableFrameAlloc(allocator, 7, metadata);
        defer allocator.free(skip);
        const stream = try std.mem.concat(allocator, u8, &.{ first, skip, second });
        defer allocator.free(stream);
        var capture: [13]u8 = undefined;
        var events: [1]Decoder.SkippableEvent = undefined;
        var decoder = Decoder.initWithDictionarySetAndOptions(allocator, dictionary_set, .{
            .skippable_output = &capture,
            .skippable_events = &events,
        });
        defer decoder.deinit();
        const evidence = try drain(&decoder, stream, payloads, 73, 37);
        try std.testing.expect(evidence.emitted_before_end);
        try std.testing.expect(evidence.max_history_capacity <= block_len);
        try std.testing.expect(evidence.max_compressed_capacity <= if (block_checksum) block_len else 32);
        try std.testing.expectEqualSlices(u8, metadata[0..capture.len], &capture);
        try std.testing.expectEqual(@as(usize, 1), decoder.snapshot().skippable_event_count);
        try std.testing.expectEqual(@as(u4, 7), events[0].id);
        try std.testing.expectEqual(metadata.len, events[0].payload_len);
        try std.testing.expectEqual(@as(usize, 6), decoder.streamedCompressedBlockCount());

        var missing = Decoder.init(allocator);
        defer missing.deinit();
        try std.testing.expectError(error.NeedDictionary, missing.step(first, &.{}));
    }
}

test "LZ4 default incremental linked history survives raw to compressed transitions" {
    const payload = try allocator.alloc(u8, block_len * 4);
    defer allocator.free(payload);
    fillRandom(payload[0..block_len], 0x5487_2196);
    for (1..4) |i| {
        @memcpy(payload[i * block_len ..][0 .. block_len - 1], payload[(i - 1) * block_len + 1 ..][0 .. block_len - 1]);
        payload[(i + 1) * block_len - 1] = payload[(i - 1) * block_len] ^ 0xa5;
    }
    for ([_]bool{ false, true }) |block_checksum| {
        const frame = try lz4.encodePureFrameWithOptionsAlloc(allocator, payload, .{
            .block_mode = .linked,
            .block_size_id = .max64kb,
            .include_content_size = false,
            .block_checksum = block_checksum,
            .content_checksum = true,
        });
        defer allocator.free(frame);
        const first = (try lz4.inspectNativeFrameFirstBlock(frame)).?;
        const second = (try lz4.inspectNativeFrameBlockAt(frame, first.next_header_offset)).?;
        try std.testing.expect(!first.is_compressed);
        try std.testing.expect(second.is_compressed);
        var decoder = Decoder.init(allocator);
        defer decoder.deinit();
        const evidence = try drain(&decoder, frame, payload, 251, 97);
        try std.testing.expect(evidence.emitted_before_end);
        try std.testing.expect(evidence.max_history_capacity <= block_len);
        try std.testing.expect(evidence.max_compressed_capacity <= if (block_checksum) block_len else 32);
        try std.testing.expectEqual(@as(usize, 3), decoder.streamedCompressedBlockCount());
    }
}

test "LZ4 default incremental validates late content checksum and truncation" {
    const payload = "late-frame-checksum-and-truncation" ** 3000;
    const frame = try lz4.encodePureFrameWithOptionsAlloc(allocator, payload, .{
        .block_size_id = .max64kb,
        .content_checksum = true,
        .block_checksum = true,
    });
    defer allocator.free(frame);
    const output = try allocator.alloc(u8, payload.len);
    defer allocator.free(output);
    var decoder = Decoder.init(allocator);
    defer decoder.deinit();
    const prefix = try decoder.step(frame[0 .. frame.len - 1], output);
    try std.testing.expectEqual(core.StepResult.Status.need_input, prefix.status);
    try std.testing.expectEqual(frame.len - 1, prefix.progress.input_read);
    try std.testing.expectEqual(payload.len, prefix.progress.output_written);
    try std.testing.expectEqualSlices(u8, payload, output);
    try std.testing.expectError(error.TruncatedFrame, decoder.finish());
    var corrupt_last: [1]u8 = .{frame[frame.len - 1] ^ 1};
    try std.testing.expectError(error.ChecksumMismatch, decoder.step(&corrupt_last, &.{}));
    try std.testing.expectEqual(payload.len, decoder.snapshot().output_written);
    try std.testing.expectEqual(frame.len, decoder.snapshot().input_received);
    try std.testing.expectEqualSlices(u8, "ChecksumMismatch", decoder.snapshot().last_error_name);
}

test "LZ4 default incremental output limits apply across raw and compressed blocks" {
    const payload = "frame-output-limits" ** 6000;
    const frame = try lz4.encodePureFrameWithOptionsAlloc(allocator, payload, .{
        .include_content_size = false,
        .block_size_id = .max64kb,
        .block_checksum = false,
        .content_checksum = true,
    });
    defer allocator.free(frame);
    const first_block = (try lz4.inspectNativeFrameFirstBlock(frame)).?;
    var limited = Decoder.initWithOptions(allocator, .{ .max_decoded_buffer_len = block_len });
    defer limited.deinit();
    var first_output: [block_len]u8 = undefined;
    const first = try limited.step(frame[0..first_block.next_header_offset], &first_output);
    try std.testing.expectEqual(core.StepResult.Status.need_input, first.status);
    try std.testing.expectEqual(block_len, first.progress.output_written);
    var extra: [1]u8 = undefined;
    try std.testing.expectError(error.OutputLimitExceeded, limited.step(frame[first.progress.input_read..], &extra));
    try std.testing.expectEqual(block_len, limited.snapshot().output_written);

    var exact = Decoder.initWithOptions(allocator, .{ .expected_output_len = block_len });
    defer exact.deinit();
    const exact_first = try exact.step(frame[0..first_block.next_header_offset], &first_output);
    try std.testing.expectEqual(core.StepResult.Status.need_input, exact_first.status);
    try std.testing.expectError(error.SizeMismatch, exact.step(frame[exact_first.progress.input_read..], &extra));

    var raw: [4096]u8 = undefined;
    fillRandom(&raw, 0x5124_7859);
    const raw_frame = try lz4.encodePureFrameWithOptionsAlloc(allocator, &raw, .{
        .include_content_size = false,
        .block_checksum = false,
        .content_checksum = false,
    });
    defer allocator.free(raw_frame);
    var raw_limited = Decoder.initWithOptions(allocator, .{ .max_decoded_buffer_len = raw.len - 1 });
    defer raw_limited.deinit();
    var raw_output: [raw.len]u8 = undefined;
    try std.testing.expectError(error.OutputLimitExceeded, raw_limited.step(raw_frame, &raw_output));
    try std.testing.expectEqual(@as(usize, 0), raw_limited.snapshot().output_written);

    var bad_magic = Decoder.init(allocator);
    defer bad_magic.deinit();
    try std.testing.expectError(error.CorruptFrame, bad_magic.step("bad magic", &.{}));
}

test "LZ4 default incremental stops at the first member without accepting its successor" {
    const first_payload = "first streaming member" ** 4000;
    const second_payload = "second streaming member" ** 4000;
    const first = try lz4.encodePureFrameWithOptionsAlloc(allocator, first_payload, .{ .block_size_id = .max64kb });
    defer allocator.free(first);
    const second = try lz4.encodePureFrameWithOptionsAlloc(allocator, second_payload, .{ .block_size_id = .max64kb });
    defer allocator.free(second);
    const stream = try std.mem.concat(allocator, u8, &.{ first, second });
    defer allocator.free(stream);
    var decoder = Decoder.initWithOptions(allocator, .{ .stop_after_first_frame = true });
    defer decoder.deinit();
    const output = try allocator.alloc(u8, first_payload.len);
    defer allocator.free(output);
    const result = try decoder.step(stream, output);
    try std.testing.expectEqual(core.StepResult.Status.done, result.status);
    try std.testing.expectEqual(first.len, result.progress.input_read);
    try std.testing.expectEqual(first_payload.len, result.progress.output_written);
    try std.testing.expectEqualSlices(u8, first_payload, output);
    try std.testing.expectEqual(@as(usize, 0), decoder.trailingInput().len);
    try std.testing.expect(decoder.compressedBufferCapacity() <= 32);
}

test "LZ4 default incremental unchecked cursor rejects malformed matches after partial output" {
    const payload = "malformed-default-token-offset-0123456789" ** 128;
    const frame = try lz4.encodePureFrameWithOptionsAlloc(allocator, payload, .{
        .include_content_size = false,
        .block_checksum = false,
        .content_checksum = false,
    });
    defer allocator.free(frame);
    const block = (try lz4.inspectNativeFrameFirstBlock(frame)).?;
    try std.testing.expect(block.is_compressed);
    const corrupt = try allocator.dupe(u8, frame);
    defer allocator.free(corrupt);
    var offset = block.payload_offset + 1;
    var literal_len: usize = corrupt[block.payload_offset] >> 4;
    if (literal_len == 15) {
        while (true) {
            const byte = corrupt[offset];
            offset += 1;
            literal_len += byte;
            if (byte != 255) break;
        }
    }
    offset += literal_len;
    corrupt[offset] = 0;
    corrupt[offset + 1] = 0;
    var decoder = Decoder.init(allocator);
    defer decoder.deinit();
    var output: [payload.len]u8 = undefined;
    var input_read: usize = 0;
    var output_written: usize = 0;
    var saw_error = false;
    while (input_read < corrupt.len) {
        const result = decoder.step(corrupt[input_read..][0..1], output[output_written..][0..1]) catch |err| {
            try std.testing.expectEqual(error.InvalidMatch, err);
            saw_error = true;
            break;
        };
        input_read += result.progress.input_read;
        output_written += result.progress.output_written;
        try std.testing.expectEqual(input_read, decoder.snapshot().input_received);
        try std.testing.expectEqual(output_written, decoder.snapshot().output_written);
        try std.testing.expect(result.progress.input_read != 0 or result.progress.output_written != 0);
    }
    try std.testing.expect(saw_error);
    try std.testing.expect(output_written != 0);
    try std.testing.expectEqual(literal_len, output_written);
    try std.testing.expectEqualSlices(u8, payload[0..literal_len], output[0..literal_len]);
    try std.testing.expectEqual(output_written, decoder.snapshot().output_written);
    try std.testing.expect(decoder.compressedBufferCapacity() <= 32);
    try std.testing.expectEqual(@as(usize, 0), decoder.decodedBufferCapacity());
    try std.testing.expectEqualSlices(u8, "InvalidMatch", decoder.snapshot().last_error_name);
}

test "LZ4 default incremental compressed block waits for checksum with unbounded options" {
    const payload = "default-checksummed-compressed-payload" ** 4096;
    const frame = try lz4.encodePureFrameWithOptionsAlloc(allocator, payload, .{
        .block_size_id = .max64kb,
        .block_checksum = true,
        .content_checksum = true,
    });
    defer allocator.free(frame);
    const block = (try lz4.inspectNativeFrameFirstBlock(frame)).?;
    try std.testing.expect(block.is_compressed);
    const checksum_offset = block.block_checksum_offset.?;
    const output = try allocator.alloc(u8, payload.len);
    defer allocator.free(output);
    @memset(output, 0xa5);
    var decoder = Decoder.init(allocator);
    defer decoder.deinit();
    const prefix = try decoder.step(frame[0 .. checksum_offset + 3], output);
    try std.testing.expectEqual(core.StepResult.Status.need_input, prefix.status);
    try std.testing.expectEqual(@as(usize, 0), prefix.progress.output_written);
    for (output) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
    const checked = try decoder.step(frame[checksum_offset + 3 ..], output[0..17]);
    try std.testing.expectEqual(core.StepResult.Status.need_output, checked.status);
    try std.testing.expectEqual(@as(usize, 1), checked.progress.input_read);
    try std.testing.expectEqual(@as(usize, 17), checked.progress.output_written);
    try std.testing.expectEqualSlices(u8, payload[0..17], output[0..17]);

    const corrupt = try allocator.dupe(u8, frame);
    defer allocator.free(corrupt);
    corrupt[checksum_offset] ^= 1;
    @memset(output, 0xa5);
    var bad = Decoder.init(allocator);
    defer bad.deinit();
    try std.testing.expectError(error.ChecksumMismatch, bad.step(corrupt, output));
    try std.testing.expectEqual(@as(usize, 0), bad.snapshot().output_written);
    for (output) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
}
