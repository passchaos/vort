const std = @import("std");
const zstd = @import("../../zstd.zig");
const core = @import("../../core.zig");

const policies = [_]core.CompressedInputPolicy{ .block_stream, .prevalidated_frame };

fn decode(decoder: *zstd.NativeIncrementalFrameDecoder, frame: []const u8, output: []u8, input_chunk: usize, output_chunk: usize) !void {
    var read: usize = 0;
    var written: usize = 0;
    while (true) {
        const result = try decoder.step(frame[read..@min(frame.len, read + input_chunk)], output[written..@min(output.len, written + output_chunk)]);
        read += result.progress.input_read;
        written += result.progress.output_written;
        try std.testing.expectEqual(result.progress, decoder.snapshot().last_step_progress);
        try std.testing.expect(decoder.workingMemoryBytes() <= decoder.options.max_working_memory);
        try std.testing.expect(decoder.peakWorkingMemoryBytes() >= decoder.workingMemoryBytes());
        if (result.status == .done and read == frame.len) break;
        try std.testing.expect(result.progress.input_read != 0 or result.progress.output_written != 0);
        if (result.status == .need_input) try std.testing.expect(read < frame.len);
        if (result.status == .need_output) try std.testing.expect(written < output.len);
    }
    try decoder.finish();
    try std.testing.expectEqual(frame.len, read);
    try std.testing.expectEqual(output.len, written);
}

fn expectSticky(decoder: *zstd.NativeIncrementalFrameDecoder, expected: anyerror, input: []const u8, output: []u8) !void {
    const before = decoder.snapshot();
    @memset(output, 0xa5);
    try std.testing.expectError(expected, decoder.step(input, output));
    const after = decoder.snapshot();
    try std.testing.expectEqual(before.input_received, after.input_received);
    try std.testing.expectEqual(before.output_written, after.output_written);
    try std.testing.expectEqual(before.error_input_offset, after.error_input_offset);
    try std.testing.expectEqual(before.error_output_offset, after.error_output_offset);
    try std.testing.expectEqual(core.Progress{}, after.last_step_progress);
    for (output) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
}

fn rawFrame(payload: []const u8, include_size: bool) ![]u8 {
    const result = try zstd.encodeNativeFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .selection = .raw_or_rle,
        .include_content_size = include_size,
        .content_checksum = true,
        .block_size_max = 8,
    });
    return result.frame;
}

test "Zstd incremental limits output exact below zero and no content size" {
    const payload = "bounded cumulative output";
    for (policies) |policy| {
        inline for (.{ true, false }) |include_size| {
            const frame = try rawFrame(payload, include_size);
            defer std.testing.allocator.free(frame);
            var output: [payload.len]u8 = undefined;
            var exact = zstd.NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
                .input_policy = policy,
                .max_output_len = payload.len,
                .expected_output_len = payload.len,
            });
            defer exact.deinit();
            try decode(&exact, frame, &output, 5, 3);
            try std.testing.expectEqualSlices(u8, payload, &output);

            var below = zstd.NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
                .input_policy = policy,
                .max_output_len = payload.len - 1,
            });
            defer below.deinit();
            try std.testing.expectError(error.OutputLimitExceeded, below.step(frame, &output));
            try std.testing.expect(below.snapshot().output_written < payload.len);
            try std.testing.expectEqual(@as(?usize, below.snapshot().input_received), below.snapshot().error_input_offset);
            try std.testing.expectEqual(@as(?usize, below.snapshot().output_written), below.snapshot().error_output_offset);
            try expectSticky(&below, error.OutputLimitExceeded, frame, &output);

            var zero = zstd.NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{ .input_policy = policy, .max_output_len = 0 });
            defer zero.deinit();
            try std.testing.expectError(error.OutputLimitExceeded, zero.step(frame, &output));
            try std.testing.expectEqual(@as(usize, 0), zero.snapshot().output_written);
            const empty = try rawFrame("", include_size);
            defer std.testing.allocator.free(empty);
            zero.reset();
            try decode(&zero, empty, &.{}, empty.len, 0);
        }
    }
}

test "Zstd incremental limits cumulative concatenation preserves per-frame cap" {
    const payload = "member payload";
    const frame = try rawFrame(payload, false);
    defer std.testing.allocator.free(frame);
    const stream = try std.mem.concat(std.testing.allocator, u8, &.{ frame, frame });
    defer std.testing.allocator.free(stream);
    for (policies) |policy| {
        var decoder = zstd.NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
            .input_policy = policy,
            .max_output_len = 2 * payload.len,
            .max_decoded_buffer_len = payload.len,
            .expected_output_len = 2 * payload.len,
        });
        defer decoder.deinit();
        var output: [2 * payload.len]u8 = undefined;
        try decode(&decoder, stream, &output, stream.len, 2);
        try std.testing.expectEqualSlices(u8, payload ++ payload, &output);
        try std.testing.expectEqual(@as(usize, 2), decoder.snapshot().data_frame_count);

        var capped = zstd.NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
            .input_policy = policy,
            .max_output_len = 2 * payload.len - 1,
            .max_decoded_buffer_len = payload.len,
        });
        defer capped.deinit();
        try std.testing.expectError(error.OutputLimitExceeded, capped.step(stream, &output));
        try std.testing.expect(capped.snapshot().output_written >= payload.len);
        try std.testing.expect(capped.snapshot().output_written < output.len);
        try expectSticky(&capped, error.OutputLimitExceeded, stream, &output);

        var automatic = zstd.NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
            .input_policy = policy,
            .max_output_len = payload.len,
        });
        defer automatic.deinit();
        try std.testing.expectEqual(core.StepResult.Status.done, (try automatic.step(frame, output[0..payload.len])).status);
        try std.testing.expectError(error.OutputLimitExceeded, automatic.step(frame, output[payload.len..]));
        try std.testing.expectEqual(payload.len, automatic.snapshot().output_written);
    }
}

test "Zstd incremental limits stopped members nextStream retains quota pledge and suffix" {
    const payload = "stopped member";
    const frame = try rawFrame(payload, true);
    defer std.testing.allocator.free(frame);
    const empty = try rawFrame("", true);
    defer std.testing.allocator.free(empty);
    const skip = try zstd.encodeSkippableFrameAlloc(std.testing.allocator, 3, "meta");
    defer std.testing.allocator.free(skip);
    const stream = try std.mem.concat(std.testing.allocator, u8, &.{ frame, skip, empty, frame });
    defer std.testing.allocator.free(stream);
    for (policies) |policy| {
        var capture: [4]u8 = undefined;
        var events: [1]zstd.NativeIncrementalFrameDecoder.SkippableEvent = undefined;
        var decoder = zstd.NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
            .input_policy = policy,
            .max_output_len = 2 * payload.len,
            .expected_output_len = 2 * payload.len,
            .stop_after_first_frame = true,
            .skippable_output = &capture,
            .skippable_events = &events,
        });
        defer decoder.deinit();
        try std.testing.expectError(error.InvalidStreamState, decoder.nextStream());
        var output: [2 * payload.len]u8 = undefined;
        const first = try decoder.step(stream, output[0..payload.len]);
        try std.testing.expectEqual(core.StepResult.Status.done, first.status);
        try std.testing.expectEqual(payload.len, first.progress.output_written);
        try std.testing.expectEqual(@as(?usize, 2 * payload.len), decoder.diagnostics().expected_output_len);
        try std.testing.expectError(error.SizeMismatch, decoder.finish());
        const retained = decoder.workingMemoryBytes();
        const peak = decoder.peakWorkingMemoryBytes();
        var read = first.progress.input_read;
        try decoder.nextStream();
        try std.testing.expectEqual(retained, decoder.workingMemoryBytes());
        try std.testing.expectEqual(peak, decoder.peakWorkingMemoryBytes());
        const middle = try decoder.step(stream[read..], output[payload.len..]);
        read += middle.progress.input_read;
        try std.testing.expectEqual(core.StepResult.Status.done, middle.status);
        try std.testing.expectEqual(@as(usize, 0), middle.progress.output_written);
        try decoder.nextStream();
        const last = try decoder.step(stream[read..], output[payload.len..]);
        read += last.progress.input_read;
        try std.testing.expectEqual(core.StepResult.Status.done, last.status);
        try std.testing.expectEqual(stream.len, read);
        try decoder.finish();
        try std.testing.expectEqualSlices(u8, payload ++ payload, &output);
        try std.testing.expectEqualSlices(u8, "meta", &capture);
        try std.testing.expectEqual(@as(usize, 3), decoder.snapshot().data_frame_count);
        try std.testing.expectEqual(@as(usize, 1), decoder.snapshot().skippable_event_count);
        try decoder.nextStream();
        try std.testing.expectError(error.OutputLimitExceeded, decoder.step(frame, output[0..payload.len]));
    }
}

test "Zstd incremental limits exact quota still accepts checksums metadata and empty members" {
    const payload = "quota complete";
    const frame = try rawFrame(payload, false);
    defer std.testing.allocator.free(frame);
    const empty = try rawFrame("", false);
    defer std.testing.allocator.free(empty);
    const skip = try zstd.encodeSkippableFrameAlloc(std.testing.allocator, 2, "tail metadata");
    defer std.testing.allocator.free(skip);
    const stream = try std.mem.concat(std.testing.allocator, u8, &.{ frame, skip, empty });
    defer std.testing.allocator.free(stream);
    for (policies) |policy| {
        var decoder = zstd.NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
            .input_policy = policy,
            .max_output_len = payload.len,
            .expected_output_len = payload.len,
        });
        defer decoder.deinit();
        var output: [payload.len]u8 = undefined;
        try decode(&decoder, stream, &output, stream.len, output.len);
        try std.testing.expectEqualSlices(u8, payload, &output);
        try std.testing.expectEqual(@as(usize, 2), decoder.snapshot().data_frame_count);
        try std.testing.expectEqual(@as(usize, 1), decoder.snapshot().skippable_event_count);
    }
}

test "Zstd incremental limits persistent allocation budget exact below reset and reconfigure" {
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    var invalid = zstd.NativeIncrementalFrameDecoder.initWithOptions(failing.allocator(), .{ .max_output_len = 1, .expected_output_len = 2 });
    defer invalid.deinit();
    const initial = invalid.snapshot();
    try std.testing.expectError(error.InvalidBlockPlan, invalid.finish());
    try std.testing.expectEqual(@as(usize, 0), failing.allocations);
    try std.testing.expectEqual(initial.phase, invalid.snapshot().phase);
    try std.testing.expectEqual(initial.input_received, invalid.snapshot().input_received);
    try std.testing.expectEqual(initial.output_written, invalid.snapshot().output_written);
    try std.testing.expectEqual(initial.working_bytes, invalid.workingMemoryBytes());
    try std.testing.expectEqual(initial.peak_working_bytes, invalid.peakWorkingMemoryBytes());
    try std.testing.expectEqual(core.Progress{}, invalid.snapshot().last_step_progress);
    const payload = "abcdefghijklmnopqrstuvwx";
    const frame = try rawFrame(payload, true);
    defer std.testing.allocator.free(frame);
    for (policies) |policy| {
        var output: [payload.len]u8 = undefined;
        var measured = zstd.NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{ .input_policy = policy });
        defer measured.deinit();
        try decode(&measured, frame, &output, frame.len, output.len);
        const peak = measured.peakWorkingMemoryBytes();
        const live = measured.workingMemoryBytes();
        try std.testing.expect(peak >= live and live != 0);
        try std.testing.expectEqual(measured.compressedBufferCapacity() + measured.decodedBufferCapacity() + measured.direct_history.capacity, live);
        measured.reset();
        try std.testing.expectEqual(live, measured.workingMemoryBytes());
        try std.testing.expectEqual(live, measured.peakWorkingMemoryBytes());
        try std.testing.expectEqual(@as(usize, 0), measured.snapshot().input_received);
        try std.testing.expectEqual(@as(usize, 0), measured.snapshot().output_written);
        try decode(&measured, frame, &output, frame.len, output.len);
        try std.testing.expectEqual(live, measured.peakWorkingMemoryBytes());
        const before = measured.snapshot();
        try std.testing.expectError(error.InvalidBlockPlan, measured.resetWithOptions(.{ .max_output_len = 1, .expected_output_len = 2 }));
        try std.testing.expectEqual(before, measured.snapshot());
        try measured.resetWithOptions(.{ .input_policy = policy, .max_working_memory = 0 });
        try std.testing.expectEqual(@as(usize, 0), measured.workingMemoryBytes());
        try std.testing.expectEqual(@as(usize, 0), measured.peakWorkingMemoryBytes());
        try std.testing.expectError(error.WorkingMemoryLimitExceeded, measured.step(frame, &output));
        try std.testing.expectEqual(core.Progress{}, measured.snapshot().last_step_progress);
        try expectSticky(&measured, error.WorkingMemoryLimitExceeded, frame, &output);

        var exact = zstd.NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{ .input_policy = policy, .max_working_memory = peak });
        defer exact.deinit();
        try decode(&exact, frame, &output, frame.len, output.len);
        try std.testing.expectEqual(peak, exact.peakWorkingMemoryBytes());
        var below = zstd.NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{ .input_policy = policy, .max_working_memory = peak - 1 });
        defer below.deinit();
        @memset(&output, 0xa5);
        try std.testing.expectError(error.WorkingMemoryLimitExceeded, below.step(frame, &output));
        try std.testing.expect(below.workingMemoryBytes() <= peak - 1);
        try std.testing.expect(below.peakWorkingMemoryBytes() <= peak - 1);
        try std.testing.expect(below.snapshot().last_step_progress.input_read != 0);
        const produced = below.snapshot().output_written;
        try std.testing.expect(produced != 0);
        try std.testing.expectEqual(produced, below.snapshot().last_step_progress.output_written);
        try std.testing.expectEqualSlices(u8, payload[0..produced], output[0..produced]);
        for (output[produced..]) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
        try expectSticky(&below, error.WorkingMemoryLimitExceeded, frame, &output);
    }
}

test "Zstd incremental limits compressed dictionaries share persistent working and output budgets" {
    const dictionary = zstd.NativeDictionary.init(0x4567, "abcdefghijklmnop");
    const dictionaries = [_]zstd.NativeDictionary{dictionary};
    const dictionary_set = zstd.NativeDictionarySet.init(&dictionaries);
    const payload = "pfx-abcdefghijklmnop-tail" ** 8;
    const encoded = try zstd.encodeNativeFrameWithDictionaryAlloc(std.testing.allocator, payload, .{
        .selection = .literal_only,
        .content_checksum = true,
        .include_content_size = false,
        .block_size_max = 64,
        .window_log = 10,
    }, dictionary);
    defer std.testing.allocator.free(encoded.frame);
    try std.testing.expect((try zstd.summarizeNativeFrameBlocks(encoded.frame)).compressed_block_count > 1);
    for (policies) |policy| {
        inline for (.{ false, true }) |use_set| {
            var decoder = if (use_set)
                zstd.NativeIncrementalFrameDecoder.initWithDictionarySetAndOptions(std.testing.allocator, dictionary_set, .{ .input_policy = policy, .max_output_len = payload.len })
            else
                zstd.NativeIncrementalFrameDecoder.initWithDictionaryAndOptions(std.testing.allocator, dictionary, .{ .input_policy = policy, .max_output_len = payload.len });
            defer decoder.deinit();
            try std.testing.expectEqual(@as(usize, 0), decoder.workingMemoryBytes());
            var output: [payload.len]u8 = undefined;
            try decode(&decoder, encoded.frame, &output, encoded.frame.len, 3);
            try std.testing.expectEqualSlices(u8, payload, &output);
            try std.testing.expect(decoder.streamedSequenceBlockCount() > 1);
            try std.testing.expectEqual(@as(usize, 0), decoder.decodedBufferCapacity());
            const peak = decoder.peakWorkingMemoryBytes();
            try decoder.resetWithOptions(.{ .input_policy = policy, .max_working_memory = peak, .max_output_len = payload.len });
            try decode(&decoder, encoded.frame, &output, encoded.frame.len, 3);
            try std.testing.expectEqual(peak, decoder.peakWorkingMemoryBytes());
            try decoder.resetWithOptions(.{ .input_policy = policy, .max_working_memory = peak - 1 });
            var read: usize = 0;
            var written: usize = 0;
            while (true) {
                const result = decoder.step(encoded.frame[read..], output[written..@min(output.len, written + 3)]) catch |err| {
                    try std.testing.expectEqual(error.WorkingMemoryLimitExceeded, err);
                    break;
                };
                read += result.progress.input_read;
                written += result.progress.output_written;
                try std.testing.expect(result.status != .done);
            }
            try std.testing.expect(decoder.peakWorkingMemoryBytes() <= peak - 1);
            try expectSticky(&decoder, error.WorkingMemoryLimitExceeded, encoded.frame, &output);
            try decoder.resetWithOptions(.{ .input_policy = policy, .max_output_len = payload.len - 1 });
            try std.testing.expectError(error.OutputLimitExceeded, decoder.step(encoded.frame, &output));
            try std.testing.expect(decoder.snapshot().output_written < payload.len);
        }
    }
}

test "Zstd incremental limits Huffman tail corruption records partial output before error" {
    // This alphabet selects a sequence-free compressed Huffman literal block.
    // Replacing the last stream with one repeated code length preserves the
    // declared byte sizes but makes its symbol count or terminal bits invalid.
    var payload: [129 * 64]u8 = undefined;
    for (payload[0..129], 0..) |*byte, index| byte.* = @intCast(index);
    var state: u32 = 0x1290_0f5e;
    for (payload[129..]) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @intCast((state >> 16) % 129);
    }
    const frame = try zstd.encodeLiteralOnlyFrameWithOptionsAlloc(std.testing.allocator, &payload, .{ .content_checksum = false });
    defer std.testing.allocator.free(frame);
    const block = try zstd.inspectNativeFrameFirstBlock(frame);
    const modes = try zstd.inspectNativeFrameBlockSequenceModes(frame, block);
    try std.testing.expectEqual(@as(usize, 0), modes.sequence_count);
    try std.testing.expectEqual(zstd.NativeLiteralsKind.compressed, modes.literals_kind);
    // Locate the already-parsed fourth stream without duplicating Huffman
    // tree/header parsing, then mutate the wire before fresh decode attempts.
    var locator = zstd.NativeIncrementalFrameDecoder.init(std.testing.allocator);
    defer locator.deinit();
    try std.testing.expectEqual(core.StepResult.Status.need_output, (try locator.step(frame, &.{})).status);
    const section = locator.block_stream_literal_section.?;
    const last_stream = section.huffman_streams.four[3];
    const relative = @intFromPtr(last_stream.ptr) - @intFromPtr(locator.frame_scratch.items.ptr) - locator.block_stream_input_offset;
    const start = block.payload_offset + relative;
    try std.testing.expect(last_stream.len > 1);
    @memset(frame[start..][0 .. last_stream.len - 1], 0);
    for (policies) |policy| {
        var decoder = zstd.NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{ .input_policy = policy });
        defer decoder.deinit();
        var output: [payload.len]u8 = @splat(0xa5);
        try std.testing.expectError(error.CorruptFrame, decoder.step(frame, &output));
        const progress = decoder.snapshot().last_step_progress;
        try std.testing.expectEqual(frame.len, progress.input_read);
        try std.testing.expectEqual(progress.output_written, decoder.snapshot().output_written);
        if (policy == .block_stream) try std.testing.expect(progress.output_written > 0);
        try std.testing.expect(progress.output_written <= output.len);
        for (output[0..progress.output_written]) |byte| try std.testing.expect(byte <= 128);
        for (output[progress.output_written..]) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
        try expectSticky(&decoder, error.CorruptFrame, frame, &output);
    }
}

test "Zstd incremental limits backing OutOfMemory differs from budget refusal and init allocates nothing" {
    const payload = "first raw bytes";
    const frame = try rawFrame(payload, true);
    defer std.testing.allocator.free(frame);
    for (policies) |policy| {
        for ([_]usize{ 0, 1 }) |fail_index| {
            var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = fail_index });
            var decoder = zstd.NativeIncrementalFrameDecoder.initWithOptions(failing.allocator(), .{ .input_policy = policy });
            defer decoder.deinit();
            try std.testing.expectEqual(@as(usize, 0), failing.allocations);
            var output: [payload.len]u8 = @splat(0xa5);
            try std.testing.expectError(error.OutOfMemory, decoder.step(frame, &output));
            try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().output_written);
            try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().last_step_progress.output_written);
            for (output) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
            try expectSticky(&decoder, error.OutOfMemory, frame, &output);
        }
    }
}

test "Zstd incremental limits compressed dictionary allocation failures preserve progress and reset retry" {
    const dictionary = zstd.NativeDictionary.init(0x7788, "abcdefghijklmnop");
    const payload = "pfx-abcdefghijklmnop-tail" ** 12;
    const encoded = try zstd.encodeNativeFrameWithDictionaryAlloc(std.testing.allocator, payload, .{
        .selection = .literal_only,
        .content_checksum = true,
        .include_content_size = false,
        .block_size_max = 64,
        .window_log = 10,
    }, dictionary);
    defer std.testing.allocator.free(encoded.frame);
    try std.testing.expect((try zstd.summarizeNativeFrameBlocks(encoded.frame)).compressed_block_count > 1);
    for (policies) |policy| {
        const options: zstd.NativeIncrementalFrameDecoder.Options = .{
            .input_policy = policy,
            .max_compressed_buffer_len = 1024,
            .max_output_len = payload.len,
            .expected_output_len = payload.len,
        };
        var baseline = std.testing.FailingAllocator.init(std.testing.allocator, .{ .resize_fail_index = 0 });
        {
            var decoder = zstd.NativeIncrementalFrameDecoder.initWithDictionaryAndOptions(baseline.allocator(), dictionary, options);
            defer decoder.deinit();
            var output: [payload.len]u8 = undefined;
            try decode(&decoder, encoded.frame, &output, 11, 7);
            try std.testing.expectEqualSlices(u8, payload, &output);
        }
        const allocation_count = baseline.allocations;
        try std.testing.expect(allocation_count > 2 and allocation_count < 64);
        try std.testing.expectEqual(baseline.allocated_bytes, baseline.freed_bytes);
        for (0..allocation_count) |fail_index| {
            var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = fail_index, .resize_fail_index = 0 });
            var decoder = zstd.NativeIncrementalFrameDecoder.initWithDictionaryAndOptions(failing.allocator(), dictionary, options);
            var decoder_live = true;
            defer if (decoder_live) decoder.deinit();
            try std.testing.expectEqual(@as(usize, 0), failing.allocations);
            var output: [payload.len]u8 = @splat(0xa5);
            var read: usize = 0;
            var written: usize = 0;
            while (true) {
                const before = decoder.snapshot();
                const result = decoder.step(
                    encoded.frame[read..@min(encoded.frame.len, read + 11)],
                    output[written..@min(output.len, written + 7)],
                ) catch |err| {
                    try std.testing.expectEqual(error.OutOfMemory, err);
                    const failed = decoder.snapshot();
                    try std.testing.expectEqual(core.Progress{
                        .input_read = failed.input_received - before.input_received,
                        .output_written = failed.output_written - before.output_written,
                    }, failed.last_step_progress);
                    const published = written + failed.last_step_progress.output_written;
                    try std.testing.expectEqual(published, failed.output_written);
                    try std.testing.expectEqual(@as(?usize, failed.input_received), failed.error_input_offset);
                    try std.testing.expectEqual(@as(?usize, published), failed.error_output_offset);
                    try std.testing.expectEqualSlices(u8, payload[0..published], output[0..published]);
                    for (output[published..]) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
                    var retry_output: [7]u8 = undefined;
                    const allocations_before_retry = failing.allocations;
                    try expectSticky(&decoder, error.OutOfMemory, encoded.frame, &retry_output);
                    try std.testing.expectEqual(allocations_before_retry, failing.allocations);
                    break;
                };
                read += result.progress.input_read;
                written += result.progress.output_written;
                try std.testing.expect(result.status != .done);
                try std.testing.expect(result.progress.input_read != 0 or result.progress.output_written != 0);
            }
            try std.testing.expect(failing.has_induced_failure);
            const retained = decoder.workingMemoryBytes();
            failing.fail_index = std.math.maxInt(usize);
            failing.resize_fail_index = std.math.maxInt(usize);
            decoder.reset();
            try std.testing.expectEqual(retained, decoder.workingMemoryBytes());
            try std.testing.expectEqual(retained, decoder.peakWorkingMemoryBytes());
            try decode(&decoder, encoded.frame, &output, 11, 7);
            try std.testing.expectEqualSlices(u8, payload, &output);
            decoder.deinit();
            decoder_live = false;
            try std.testing.expectEqual(failing.allocated_bytes, failing.freed_bytes);
            try std.testing.expectEqual(failing.allocations, failing.deallocations);
        }
    }
}

test "Zstd incremental limits late checksum reports final step progress and is sticky" {
    const payload = "accurate failure progress";
    const frame = try rawFrame(payload, false);
    defer std.testing.allocator.free(frame);
    var corrupt = try std.testing.allocator.dupe(u8, frame);
    defer std.testing.allocator.free(corrupt);
    corrupt[corrupt.len - 1] ^= 1;
    var decoder = zstd.NativeIncrementalFrameDecoder.init(std.testing.allocator);
    defer decoder.deinit();
    var output: [payload.len]u8 = undefined;
    const first = try decoder.step(corrupt[0 .. corrupt.len - 4], &output);
    try std.testing.expectEqual(core.StepResult.Status.need_input, first.status);
    try std.testing.expectEqual(payload.len, first.progress.output_written);
    try std.testing.expectError(error.TruncatedFrame, decoder.finish());
    try std.testing.expectError(error.ChecksumMismatch, decoder.step(corrupt[corrupt.len - 4 ..], &.{}));
    try std.testing.expectEqual(core.Progress{ .input_read = 4 }, decoder.snapshot().last_step_progress);
    try std.testing.expectEqual(@as(?usize, corrupt.len), decoder.snapshot().error_input_offset);
    try std.testing.expectEqual(@as(?usize, payload.len), decoder.snapshot().error_output_offset);
    try std.testing.expectEqual(decoder.snapshot().error_input_offset, decoder.diagnostics().error_input_offset);
    try std.testing.expectEqual(decoder.snapshot().error_output_offset, decoder.diagnostics().error_output_offset);
    try std.testing.expectEqual(@as(?core.Progress, decoder.snapshot().last_step_progress), decoder.diagnostics().last_step_progress);
    try std.testing.expectEqualSlices(u8, payload, &output);
    try expectSticky(&decoder, error.ChecksumMismatch, corrupt, &output);
}
