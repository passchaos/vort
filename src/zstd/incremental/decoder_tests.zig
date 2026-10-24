const std = @import("std");
const zstd = @import("../../zstd.zig");
const core = @import("../../core.zig");

fn drain(decoder: *zstd.NativeIncrementalFrameDecoder, input: []const u8, expected: []const u8, input_chunk: usize, output_chunk: usize) !void {
    const output = try std.testing.allocator.alloc(u8, expected.len);
    defer std.testing.allocator.free(output);
    var read: usize = 0;
    var written: usize = 0;
    while (true) {
        const result = try decoder.step(input[read..@min(input.len, read + input_chunk)], output[written..@min(output.len, written + output_chunk)]);
        read += result.progress.input_read;
        written += result.progress.output_written;
        try std.testing.expectEqual(@as(usize, 0), decoder.decodedBufferedBytes());
        try std.testing.expectEqual(@as(usize, 0), decoder.decodedBufferCapacity());
        try std.testing.expect(decoder.compressedBufferCapacity() <= std.compress.zstd.block_size_max);
        if (result.status == .done and read == input.len) break;
        try std.testing.expect(result.progress.input_read != 0 or result.progress.output_written != 0);
        if (result.status == .need_input) try std.testing.expect(read < input.len);
        if (result.status == .need_output) try std.testing.expect(written < output.len);
    }
    try decoder.finish();
    try std.testing.expectEqual(input.len, read);
    try std.testing.expectEqualSlices(u8, expected, output);
}

fn hexBytes(comptime path: []const u8) ![]u8 {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    for (@embedFile(path)) |byte| {
        if (!std.ascii.isWhitespace(byte)) try encoded.append(std.testing.allocator, byte);
    }
    const bytes = try std.testing.allocator.alloc(u8, encoded.items.len / 2);
    errdefer std.testing.allocator.free(bytes);
    _ = try std.fmt.hexToBytes(bytes, encoded.items);
    return bytes;
}

test "zstd default block stream accepts only header under raw output backpressure" {
    const payload = "default raw streaming" ** 8192;
    const encoded = try zstd.encodeNativeFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .selection = .raw_or_rle,
        .block_size_max = 1024,
        .window_log = 10,
        .content_checksum = true,
    });
    defer std.testing.allocator.free(encoded.frame);
    const header = try zstd.inspectNativeFrameHeader(encoded.frame);
    var decoder = zstd.NativeIncrementalFrameDecoder.init(std.testing.allocator);
    defer decoder.deinit();
    const blocked = try decoder.step(encoded.frame, &.{});
    try std.testing.expectEqual(core.StepResult.Status.need_output, blocked.status);
    try std.testing.expectEqual(header.payload_offset + 3, blocked.progress.input_read);
    try std.testing.expect(decoder.isBlockStreaming());
    try std.testing.expect(decoder.compressedBufferedBytes() <= 3);
    try std.testing.expectError(error.TruncatedFrame, decoder.finish());
    // No raw payload was accepted while no caller output was available.
    try drain(&decoder, encoded.frame[blocked.progress.input_read..], payload, 11, 1);
    try std.testing.expectEqual(@as(usize, 0), decoder.decodedBufferCapacity());
    try std.testing.expect(decoder.direct_history.capacity <= 2 * 1024);
}

test "zstd default block stream emits compressed blocks before frame completion" {
    const payload = "zstd bounded compressed sequence output " ** 512;
    const encoded = try zstd.encodeNativeFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .selection = .literal_only,
        .block_size_max = 1024,
        .window_log = 10,
        .content_checksum = true,
        .include_content_size = false,
    });
    defer std.testing.allocator.free(encoded.frame);
    const first_block = try zstd.inspectNativeFrameFirstBlock(encoded.frame);
    try std.testing.expectEqual(zstd.NativeBlockType.compressed, first_block.block_type);
    try std.testing.expect(!first_block.last);
    var decoder = zstd.NativeIncrementalFrameDecoder.init(std.testing.allocator);
    defer decoder.deinit();
    var first_output: [1024]u8 = undefined;
    const first = try decoder.step(encoded.frame[0..first_block.next_header_offset], &first_output);
    try std.testing.expectEqual(core.StepResult.Status.need_input, first.status);
    try std.testing.expectEqual(first_block.next_header_offset, first.progress.input_read);
    try std.testing.expectEqual(@as(usize, 1024), first.progress.output_written);
    try std.testing.expectEqualSlices(u8, payload[0..1024], &first_output);
    try std.testing.expect(decoder.isBlockStreaming());
    try std.testing.expectEqual(@as(?core.StreamCount, null), decoder.snapshot().decoded_len);
    try std.testing.expect(decoder.streamedSequenceBlockCount() > 0);
    const input_capacity = decoder.compressedBufferCapacity();
    try drain(&decoder, encoded.frame[first.progress.input_read..], payload[first.progress.output_written..], encoded.frame.len, 17);
    try std.testing.expect(decoder.compressedBufferCapacity() <= @max(input_capacity, 2 * first_block.payload_len));
    try std.testing.expect(decoder.direct_history.capacity <= 2 * 1024);
}

test "zstd default block stream retains one maximum block independently of frame length" {
    const block_len = std.compress.zstd.block_size_max;
    const payload = try std.testing.allocator.alloc(u8, block_len * 5 + 17);
    defer std.testing.allocator.free(payload);
    var random = std.Random.DefaultPrng.init(0x157a_790b);
    random.random().bytes(payload);
    const encoded = try zstd.encodeNativeFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .selection = .raw_or_rle,
        .window_log = 17,
        .content_checksum = true,
    });
    defer std.testing.allocator.free(encoded.frame);
    var decoder = zstd.NativeIncrementalFrameDecoder.init(std.testing.allocator);
    defer decoder.deinit();
    const output = try std.testing.allocator.alloc(u8, payload.len);
    defer std.testing.allocator.free(output);
    var read: usize = 0;
    var written: usize = 0;
    var full_block_capacity: usize = 0;
    while (true) {
        const result = try decoder.step(encoded.frame[read..], output[written..@min(output.len, written + block_len)]);
        read += result.progress.input_read;
        written += result.progress.output_written;
        try std.testing.expect(decoder.compressedBufferedBytes() <= block_len);
        try std.testing.expect(decoder.compressedBufferCapacity() <= block_len);
        try std.testing.expectEqual(@as(usize, 0), decoder.decodedBufferCapacity());
        try std.testing.expect(decoder.direct_history.items.len <= block_len);
        if (full_block_capacity == 0) full_block_capacity = decoder.compressedBufferCapacity();
        try std.testing.expectEqual(full_block_capacity, decoder.compressedBufferCapacity());
        if (result.status == .done) break;
        try std.testing.expect(read < encoded.frame.len);
        try std.testing.expect(written < output.len);
    }
    try decoder.finish();
    try std.testing.expectEqual(encoded.frame.len, read);
    try std.testing.expectEqualSlices(u8, payload, output);
}

test "zstd default block stream supports maximum compressed payload with tiny output" {
    const block_len = std.compress.zstd.block_size_max;
    const literal_len = block_len - 4;
    const payload = try std.testing.allocator.alloc(u8, literal_len * 3);
    defer std.testing.allocator.free(payload);
    var random = std.Random.DefaultPrng.init(0x2a4b_5c7d);
    random.random().bytes(payload);
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    // No-size frame with a standard 128 KiB window. Each compressed block has
    // a three-byte raw literal header, 131068 literals, and zero sequences.
    try frame.appendSlice(std.testing.allocator, &.{ 0x28, 0xb5, 0x2f, 0xfd, 0, 0x38 });
    for (0..3) |index| {
        var block_header: [3]u8 = undefined;
        std.mem.writeInt(u24, &block_header, @intCast((block_len << 3) | 4 | @as(usize, @intFromBool(index == 2))), .little);
        try frame.appendSlice(std.testing.allocator, &block_header);
        var literal_header: [3]u8 = undefined;
        std.mem.writeInt(u24, &literal_header, @intCast((literal_len << 4) | 12), .little);
        try frame.appendSlice(std.testing.allocator, &literal_header);
        try frame.appendSlice(std.testing.allocator, payload[index * literal_len ..][0..literal_len]);
        try frame.append(std.testing.allocator, 0);
    }
    var decoder = zstd.NativeIncrementalFrameDecoder.init(std.testing.allocator);
    defer decoder.deinit();
    const blocked = try decoder.step(frame.items, &.{});
    try std.testing.expectEqual(core.StepResult.Status.need_output, blocked.status);
    try std.testing.expectEqual(@as(usize, 9 + block_len), blocked.progress.input_read);
    try std.testing.expectEqual(block_len, decoder.compressedBufferCapacity());
    try drain(&decoder, frame.items[blocked.progress.input_read..], payload, frame.items.len, 1023);
    try std.testing.expectEqual(@as(usize, 3), decoder.streamedLiteralBlockCount());
    try std.testing.expectEqual(block_len, decoder.compressedBufferCapacity());
}

test "zstd default block stream supports standard dictionary entropy and dictionary sets" {
    const dictionary_bytes = try hexBytes("../testdata/libzstd-trained-repeat.dict.hex");
    defer std.testing.allocator.free(dictionary_bytes);
    const frame = try hexBytes("../testdata/libzstd-trained-repeat.frame.hex");
    defer std.testing.allocator.free(frame);
    const standard = try zstd.NativeDictionary.initFromStandardDictionary(dictionary_bytes);
    const expected = try zstd.decodeNativeFrameAllocWithDictionary(std.testing.allocator, frame, standard.dictionary);
    defer std.testing.allocator.free(expected);
    var decoder = zstd.NativeIncrementalFrameDecoder.initWithDictionary(std.testing.allocator, standard.dictionary);
    defer decoder.deinit();
    try drain(&decoder, frame, expected, 1, 1);
    try std.testing.expect(decoder.streamedSequenceBlockCount() > 0);

    const preset = zstd.NativeDictionary.init(0x5566, "abcdefghijklmnop");
    const preset_payload = "pfx-abcdefghijklmnop-tail" ** 17;
    const encoded = try zstd.encodeNativeFrameWithDictionaryAlloc(std.testing.allocator, preset_payload, .{
        .selection = .literal_only,
        .content_checksum = true,
        .include_content_size = false,
        .block_size_max = 128,
    }, preset);
    defer std.testing.allocator.free(encoded.frame);
    const skip = try zstd.encodeSkippableFrameAlloc(std.testing.allocator, 5, "metadata");
    defer std.testing.allocator.free(skip);
    const stream = try std.mem.concat(std.testing.allocator, u8, &.{ frame, skip, encoded.frame });
    defer std.testing.allocator.free(stream);
    const concatenated = try std.mem.concat(std.testing.allocator, u8, &.{ expected, preset_payload });
    defer std.testing.allocator.free(concatenated);
    const dictionaries = [_]zstd.NativeDictionary{ standard.dictionary, preset };
    var captured: [8]u8 = undefined;
    var events: [1]zstd.NativeIncrementalFrameDecoder.SkippableEvent = undefined;
    var set_decoder = zstd.NativeIncrementalFrameDecoder.initWithDictionarySetAndOptions(std.testing.allocator, zstd.NativeDictionarySet.init(&dictionaries), .{
        .expected_output_len = concatenated.len,
        .skippable_output = &captured,
        .skippable_events = &events,
    });
    defer set_decoder.deinit();
    try drain(&set_decoder, stream, concatenated, stream.len, 3);
    try std.testing.expectEqualSlices(u8, "metadata", &captured);
    try std.testing.expectEqual(@as(core.StreamCount, 2), set_decoder.snapshot().data_frame_count);
    try std.testing.expectEqual(@as(u4, 5), events[0].id);

    var single_capture: [8]u8 = undefined;
    var single_events: [1]zstd.NativeIncrementalFrameDecoder.SkippableEvent = undefined;
    var single = zstd.NativeIncrementalFrameDecoder.initWithDictionaryAndOptions(std.testing.allocator, preset, .{
        .skippable_output = &single_capture,
        .skippable_events = &single_events,
    });
    defer single.deinit();
    const skip_and_frame = try std.mem.concat(std.testing.allocator, u8, &.{ skip, encoded.frame });
    defer std.testing.allocator.free(skip_and_frame);
    try drain(&single, skip_and_frame, preset_payload, 1, 1);
    try std.testing.expectEqualSlices(u8, "metadata", &single_capture);
    try std.testing.expectEqual(@as(u4, 5), single_events[0].id);
}

test "zstd default block stream matches full entropy reference corpus under backpressure" {
    const fixtures = .{
        "../testdata/libzstd-large-json-128k.frame.hex",
        "../testdata/libzstd-all-fse-raw.frame.hex",
        "../testdata/libzstd-dense-sparse-literals.frame.hex",
        "../testdata/libzstd-numbered-json.frame.hex",
        "../testdata/decodecorpus-predefined-repeat.frame.hex",
    };
    inline for (fixtures) |path| {
        const frame = try hexBytes(path);
        defer std.testing.allocator.free(frame);
        const expected = try zstd.decodeNativeFrameAlloc(std.testing.allocator, frame);
        defer std.testing.allocator.free(expected);
        var decoder = zstd.NativeIncrementalFrameDecoder.init(std.testing.allocator);
        defer decoder.deinit();
        try drain(&decoder, frame, expected, 13, 31);
        try std.testing.expect(decoder.streamedSequenceBlockCount() > 0);
    }
}

test "zstd default block stream preserves id-less preset history" {
    const dictionary = zstd.NativeDictionary.initRawContent("wxyz");
    // One RLE-mode sequence references the four-byte raw dictionary without a
    // Dictionary_ID field or output literals.
    const frame = [_]u8{ 0x28, 0xb5, 0x2f, 0xfd, 0x20, 4, 0x3d, 0, 0, 0, 1, 0x54, 0, 2, 1, 7 };
    var decoder = zstd.NativeIncrementalFrameDecoder.initWithDictionary(std.testing.allocator, dictionary);
    defer decoder.deinit();
    try drain(&decoder, &frame, "wxyz", 1, 1);
    var missing = zstd.NativeIncrementalFrameDecoder.init(std.testing.allocator);
    defer missing.deinit();
    var output: [4]u8 = undefined;
    try std.testing.expectError(error.InvalidMatch, missing.step(&frame, &output));
}

test "zstd default block stream checks late corruption footer and opaque suffix accounting" {
    const payload = "bounded stream validation" ** 512;
    const encoded = try zstd.encodeNativeFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .selection = .raw_or_rle,
        .content_checksum = true,
        .block_size_max = 1024,
        .window_log = 10,
    });
    defer std.testing.allocator.free(encoded.frame);
    const first_block = try zstd.inspectNativeFrameFirstBlock(encoded.frame);
    var corrupt = try std.testing.allocator.dupe(u8, encoded.frame);
    defer std.testing.allocator.free(corrupt);
    corrupt[first_block.next_header_offset] |= 6; // Reserved block type.
    var decoder = zstd.NativeIncrementalFrameDecoder.init(std.testing.allocator);
    defer decoder.deinit();
    var first: [1024]u8 = undefined;
    const early = try decoder.step(corrupt[0..first_block.next_header_offset], &first);
    try std.testing.expectEqual(@as(usize, 1024), early.progress.output_written);
    try std.testing.expectEqualSlices(u8, payload[0..1024], &first);
    try std.testing.expectError(error.CorruptFrame, decoder.step(corrupt[early.progress.input_read..], &first));
    try std.testing.expectEqualSlices(u8, "CorruptFrame", decoder.diagnostics().last_error_name);

    @memcpy(corrupt, encoded.frame);
    corrupt[corrupt.len - 1] ^= 1;
    var checksum_decoder = zstd.NativeIncrementalFrameDecoder.init(std.testing.allocator);
    defer checksum_decoder.deinit();
    const output = try std.testing.allocator.alloc(u8, payload.len);
    defer std.testing.allocator.free(output);
    const before_footer = try checksum_decoder.step(corrupt[0 .. corrupt.len - 4], output);
    try std.testing.expectEqual(core.StepResult.Status.need_input, before_footer.status);
    try std.testing.expectEqual(payload.len, before_footer.progress.output_written);
    try std.testing.expectError(error.TruncatedFrame, checksum_decoder.finish());
    try std.testing.expectError(error.ChecksumMismatch, checksum_decoder.step(corrupt[corrupt.len - 4 ..], &.{}));
    try std.testing.expectEqualSlices(u8, payload, output);

    const suffix = "opaque ZIP footer";
    const wrapped = try std.mem.concat(std.testing.allocator, u8, &.{ encoded.frame, suffix });
    defer std.testing.allocator.free(wrapped);
    var stopped = zstd.NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{ .stop_after_first_frame = true });
    defer stopped.deinit();
    const stop = try stopped.step(wrapped, output);
    try std.testing.expectEqual(core.StepResult.Status.done, stop.status);
    try std.testing.expectEqual(encoded.frame.len, stop.progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), stopped.trailingInput().len);
    try std.testing.expectEqualSlices(u8, suffix, wrapped[stop.progress.input_read..]);
    try stopped.finish();
}

test "zstd default block stream enforces exact and per-frame output limits" {
    const payload = "default limits" ** 3;
    inline for (.{ true, false }) |include_content_size| {
        const encoded = try zstd.encodeNativeFrameWithOptionsAlloc(std.testing.allocator, payload, .{
            .selection = .raw_or_rle,
            .block_size_max = 8,
            .content_checksum = true,
            .include_content_size = include_content_size,
        });
        defer std.testing.allocator.free(encoded.frame);
        var output: [payload.len]u8 = undefined;
        var small = zstd.NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{ .expected_output_len = payload.len - 1 });
        defer small.deinit();
        try std.testing.expectError(error.SizeMismatch, small.step(encoded.frame, &output));
        try std.testing.expect(small.snapshot().output_written < payload.len);

        var large = zstd.NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{ .expected_output_len = payload.len + 1 });
        defer large.deinit();
        const short = try large.step(encoded.frame, &output);
        try std.testing.expectEqual(core.StepResult.Status.need_input, short.status);
        try std.testing.expectEqual(payload.len, short.progress.output_written);
        try std.testing.expectError(error.SizeMismatch, large.finish());

        var capped = zstd.NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{ .max_decoded_buffer_len = payload.len - 1 });
        defer capped.deinit();
        try std.testing.expectError(error.OutputLimitExceeded, capped.step(encoded.frame, &output));
        try std.testing.expect(capped.snapshot().output_written < payload.len);
        try std.testing.expectEqual(@as(usize, 0), capped.decodedBufferCapacity());

        const stream = try std.mem.concat(std.testing.allocator, u8, &.{ encoded.frame, encoded.frame });
        defer std.testing.allocator.free(stream);
        var concatenated = zstd.NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
            .expected_output_len = 2 * payload.len,
            .max_decoded_buffer_len = payload.len,
        });
        defer concatenated.deinit();
        // The decoded-buffer cap remains per frame; exact output accounting
        // spans the complete logical concatenated stream.
        try drain(&concatenated, stream, payload ++ payload, 3, 1);
        try std.testing.expectEqual(@as(core.StreamCount, 2), concatenated.snapshot().data_frame_count);
    }
}

test "zstd explicit prevalidated frame policy retains complete-frame validation" {
    const payload = "prevalidated frame behavior" ** 200;
    const encoded = try zstd.encodeNativeFrameWithOptionsAlloc(std.testing.allocator, payload, .{ .selection = .raw_or_rle, .content_checksum = true });
    defer std.testing.allocator.free(encoded.frame);
    var decoder = zstd.NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{ .input_policy = .prevalidated_frame });
    defer decoder.deinit();
    var output: [payload.len]u8 = undefined;
    const first = try decoder.step(encoded.frame[0 .. encoded.frame.len - 1], &output);
    try std.testing.expectEqual(core.StepResult.Status.need_input, first.status);
    try std.testing.expectEqual(@as(usize, 0), first.progress.output_written);
    try std.testing.expectEqual(encoded.frame.len - 1, decoder.compressedBufferedBytes());
    const done = try decoder.step(encoded.frame[encoded.frame.len - 1 ..], &output);
    try std.testing.expectEqual(core.StepResult.Status.done, done.status);
    try std.testing.expectEqualSlices(u8, payload, &output);
    var corrupt = try std.testing.allocator.dupe(u8, encoded.frame);
    defer std.testing.allocator.free(corrupt);
    corrupt[corrupt.len - 1] ^= 1;
    decoder.reset();
    @memset(&output, 0xa5);
    try std.testing.expectError(error.ChecksumMismatch, decoder.step(corrupt, &output));
    try std.testing.expectEqual(@as(core.StreamCount, 0), decoder.snapshot().output_written);
    for (output) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);

    // The explicit policy keeps the historical fallback when a caller's
    // compressed-input cap cannot retain a complete frame.
    var capped = zstd.NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .input_policy = .prevalidated_frame,
        .max_compressed_buffer_len = 32,
    });
    defer capped.deinit();
    try drain(&capped, encoded.frame, payload, 17, 7);

    const suffix = "preserved outer footer";
    const wrapped = try std.mem.concat(std.testing.allocator, u8, &.{ encoded.frame, suffix });
    defer std.testing.allocator.free(wrapped);
    var stopped = zstd.NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .input_policy = .prevalidated_frame,
        .stop_after_first_frame = true,
    });
    defer stopped.deinit();
    const result = try stopped.step(wrapped, &output);
    try std.testing.expectEqual(core.StepResult.Status.done, result.status);
    try std.testing.expectEqual(wrapped.len, result.progress.input_read);
    try std.testing.expectEqualSlices(u8, suffix, stopped.trailingInput());
    try stopped.finish();
}
