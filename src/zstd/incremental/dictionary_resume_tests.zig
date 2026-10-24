const std = @import("std");
const zstd = @import("../../zstd.zig");
const core = @import("../../core.zig");
const allocator = std.testing.allocator;
const policies = [_]core.CompressedInputPolicy{ .block_stream, .prevalidated_frame };

fn encode(payload: []const u8, dictionary: zstd.NativeDictionary) ![]u8 {
    const result = try zstd.encodeNativeFrameWithDictionaryAlloc(allocator, payload, .{ .selection = .literal_only, .content_checksum = true, .block_size_max = 128, .window_log = 10 }, dictionary);
    return result.frame;
}
fn finish(decoder: *zstd.NativeIncrementalFrameDecoder, frame: []const u8, expected: []const u8, input_chunk: usize, output_chunk: usize) !void {
    const output = try allocator.alloc(u8, expected.len);
    defer allocator.free(output);
    var read: usize = 0;
    var written: usize = 0;
    while (true) {
        const result = try decoder.step(frame[read..@min(frame.len, read + input_chunk)], output[written..@min(output.len, written + output_chunk)]);
        read += result.progress.input_read;
        written += result.progress.output_written;
        if (result.status == .done) break;
        try std.testing.expect(result.progress.input_read != 0 or result.progress.output_written != 0);
    }
    try std.testing.expectEqual(frame.len, read);
    try std.testing.expectEqualSlices(u8, expected, output);
    try decoder.finish();
}
fn awaiting(decoder: *zstd.NativeIncrementalFrameDecoder, id: u32) !void {
    try std.testing.expectEqual(@as(?u32, id), decoder.requiredDictionaryId());
    try std.testing.expectEqual(@as(?u32, id), decoder.snapshot().required_dictionary_id);
    try std.testing.expectEqualStrings("retry_with_dictionary", decoder.diagnostics().recoverability_hint_name);
    const before = decoder.snapshot();
    var output: [17]u8 = @splat(0xa5);
    try std.testing.expectError(error.NeedDictionary, decoder.step("unconsumed", &output));
    try std.testing.expectEqual(before.input_received, decoder.snapshot().input_received);
    try std.testing.expectEqual(before.output_written, decoder.snapshot().output_written);
    try std.testing.expectEqualDeep(core.Progress{}, decoder.last_step_progress);
    try std.testing.expectEqual(before.working_bytes, decoder.workingMemoryBytes());
    try std.testing.expectError(error.NeedDictionary, decoder.finish());
    try std.testing.expectEqual(@as(?u32, id), decoder.requiredDictionaryId());
    for (output) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
}
fn fixture(comptime name: []const u8) ![]u8 {
    const hex = std.mem.trim(u8, @embedFile(name), " \r\n\t");
    const bytes = try allocator.alloc(u8, hex.len / 2);
    errdefer allocator.free(bytes);
    _ = try std.fmt.hexToBytes(bytes, hex);
    return bytes;
}

test "Zstd dictionary resume byte headers and whole input keep accepted progress" {
    const dictionary = zstd.NativeDictionary.init(0x5566_7788, "abcdefghijklmnop");
    const payload = "pfx-abcdefghijklmnop-tail" ** 8;
    const frame = try encode(payload, dictionary);
    defer allocator.free(frame);
    const header = try zstd.inspectNativeFrameHeader(frame);
    for (policies) |policy| {
        inline for (.{ true, false }) |split_header| {
            var decoder = zstd.NativeIncrementalFrameDecoder.initWithOptions(allocator, .{ .input_policy = policy, .expected_output_len = payload.len });
            defer decoder.deinit();
            try std.testing.expectEqual(@as(?u32, null), decoder.requiredDictionaryId());
            try std.testing.expectError(error.InvalidStreamState, decoder.provideDictionary(dictionary));
            var read: usize = 0;
            while (true) {
                const end = if (split_header) read + 1 else frame.len;
                const result = decoder.step(frame[read..end], &.{}) catch |err| {
                    try std.testing.expectEqual(error.NeedDictionary, err);
                    read += decoder.last_step_progress.input_read;
                    break;
                };
                read += result.progress.input_read;
                try std.testing.expectEqual(core.StepResult.Status.need_input, result.status);
                try std.testing.expectEqual(@as(?u32, null), decoder.requiredDictionaryId());
            }
            try std.testing.expectEqual(header.payload_offset, read);
            try std.testing.expectEqual(@as(?usize, read), decoder.error_input_offset);
            try std.testing.expectEqual(@as(?usize, 0), decoder.error_output_offset);
            try awaiting(&decoder, dictionary.id);
            try std.testing.expectError(error.DictionaryMismatch, decoder.provideDictionary(zstd.NativeDictionary.init(dictionary.id + 1, dictionary.content)));
            try std.testing.expectEqual(@as(?u32, dictionary.id), decoder.requiredDictionaryId());
            const live = decoder.workingMemoryBytes();
            try decoder.provideDictionary(dictionary);
            try std.testing.expectEqual(live, decoder.workingMemoryBytes());
            try std.testing.expectEqual(@as(?u32, null), decoder.requiredDictionaryId());
            try finish(&decoder, frame[read..], payload, 3, 1);
            try std.testing.expectEqual(frame.len, decoder.input_received);
            try std.testing.expectEqual(payload.len, decoder.output_written);
            try std.testing.expectEqual(@as(?zstd.NativeDictionary, null), decoder.frame_dictionary);
        }
    }
}

test "Zstd dictionary resume overrides a missing set only for the current frame" {
    const dictionary = zstd.NativeDictionary.init(0x6677, "abcdefghijklmnop");
    const wrong = zstd.NativeDictionary.init(0x6678, dictionary.content);
    const catalog = zstd.NativeDictionarySet.init(&.{wrong});
    const payload = "pfx-abcdefghijklmnop-tail";
    const frame = try encode(payload, dictionary);
    defer allocator.free(frame);
    for (policies) |policy| {
        var decoder = zstd.NativeIncrementalFrameDecoder.initWithDictionarySetAndOptions(allocator, catalog, .{ .input_policy = policy });
        defer decoder.deinit();
        try std.testing.expectError(error.NeedDictionary, decoder.step(frame, &.{}));
        var read = decoder.last_step_progress.input_read;
        const before_set_miss = decoder.snapshot();
        try std.testing.expectError(error.NeedDictionary, decoder.provideDictionarySet(catalog));
        try std.testing.expectEqual(before_set_miss.input_received, decoder.input_received);
        try std.testing.expectEqual(before_set_miss.output_written, decoder.output_written);
        try std.testing.expectEqual(before_set_miss.working_bytes, decoder.workingMemoryBytes());
        try std.testing.expectEqual(before_set_miss.peak_working_bytes, decoder.peakWorkingMemoryBytes());
        try std.testing.expectEqual(@as(?u32, dictionary.id), decoder.requiredDictionaryId());
        try std.testing.expectEqualDeep(core.Progress{}, decoder.last_step_progress);
        {
            // The catalog is temporary; only its matching entry's bytes are
            // borrowed through this frame. Configuration remains unchanged.
            const temporary = [_]zstd.NativeDictionary{dictionary};
            try decoder.provideDictionarySet(zstd.NativeDictionarySet.init(&temporary));
        }
        try finish(&decoder, frame[read..], payload, frame.len, 1);
        try std.testing.expectError(error.NeedDictionary, decoder.step(frame, &.{}));
        read = decoder.last_step_progress.input_read;
        try std.testing.expectEqual(@as(?u32, dictionary.id), decoder.requiredDictionaryId());
        try decoder.provideDictionary(dictionary);
        try finish(&decoder, frame[read..], payload, frame.len, 3);
        try std.testing.expectEqual(2 * frame.len, decoder.input_received);
        try std.testing.expectEqual(2 * payload.len, decoder.output_written);
        decoder.reset();
        try std.testing.expectEqual(@as(?u32, null), decoder.requiredDictionaryId());
        try std.testing.expectError(error.NeedDictionary, decoder.step(frame, &.{}));
    }
}

test "Zstd dictionary resume full entropy validates provided metadata without losing request" {
    const bytes = try fixture("../testdata/libzstd-trained-repeat.dict.hex");
    defer allocator.free(bytes);
    const frame = try fixture("../testdata/libzstd-trained-repeat.frame.hex");
    defer allocator.free(frame);
    const standard = try zstd.NativeDictionary.initFromStandardDictionary(bytes);
    const wrong_header = try allocator.dupe(u8, bytes);
    defer allocator.free(wrong_header);
    std.mem.writeInt(u32, wrong_header[4..8], standard.dictionary.id +% 1, .little);
    var wrong_embedded_id = (try zstd.NativeDictionary.initFromStandardDictionary(wrong_header)).dictionary;
    wrong_embedded_id.id = standard.dictionary.id;
    const expected = try zstd.decodeNativeFrameAllocWithDictionary(allocator, frame, standard.dictionary);
    defer allocator.free(expected);
    for (policies) |policy| {
        var decoder = zstd.NativeIncrementalFrameDecoder.initWithOptions(allocator, .{ .input_policy = policy, .expected_output_len = expected.len });
        defer decoder.deinit();
        try std.testing.expectError(error.NeedDictionary, decoder.step(frame, &.{}));
        const accepted = decoder.last_step_progress.input_read;
        var inconsistent = standard.dictionary;
        inconsistent.content = inconsistent.content[1..];
        try std.testing.expectError(error.InvalidDictionaryMetadata, decoder.provideDictionary(inconsistent));
        try std.testing.expectError(error.InvalidDictionaryMetadata, decoder.provideDictionary(wrong_embedded_id));
        try awaiting(&decoder, standard.dictionary.id);
        try decoder.provideDictionary(standard.dictionary);
        try finish(&decoder, frame[accepted..], expected, 1, 1);
        try std.testing.expect(decoder.streamedSequenceBlockCount() > 0);
    }
}

test "Zstd dictionary resume supports unknown content size and bounded window history" {
    const dictionary = zstd.NativeDictionary.init(0x55ad, "abcdefghijklmnop");
    const payload = "pfx-abcdefghijklmnop-tail" ** 24;
    const result = try zstd.encodeNativeFrameWithDictionaryAlloc(allocator, payload, .{
        .selection = .literal_only,
        .include_content_size = false,
        .window_log = 10,
        .block_size_max = 128,
        .content_checksum = true,
    }, dictionary);
    defer allocator.free(result.frame);
    const header = try zstd.inspectNativeFrameHeader(result.frame);
    try std.testing.expect(header.content_size == null);
    try std.testing.expectEqual(@as(u64, 1024), header.window_size);
    for (policies) |policy| {
        var decoder = zstd.NativeIncrementalFrameDecoder.initWithOptions(allocator, .{
            .input_policy = policy,
            .expected_output_len = payload.len,
            .max_output_len = payload.len,
            .max_compressed_buffer_len = 128,
        });
        defer decoder.deinit();
        try std.testing.expectError(error.NeedDictionary, decoder.step(result.frame, &.{}));
        const accepted = decoder.last_step_progress.input_read;
        try std.testing.expectEqual(header.payload_offset, accepted);
        try decoder.provideDictionary(dictionary);
        try finish(&decoder, result.frame[accepted..], payload, 1, 1);
        try std.testing.expectEqual(result.frame.len, decoder.input_received);
        try std.testing.expectEqual(payload.len, decoder.output_written);
        try std.testing.expect(decoder.direct_history.capacity <= 1024 + dictionary.content.len);
        try std.testing.expectEqual(@as(usize, 0), decoder.decodedBufferCapacity());
    }
}

test "Zstd dictionary resume prior members retain cumulative pledge and stopped continuation" {
    const dictionary = zstd.NativeDictionary.init(0x5599, "abcdefghijklmnop");
    const first_payload = "plain preceding frame";
    const second_payload = "pfx-abcdefghijklmnop-tail";
    const first = try zstd.encodeRawOrRleFrameAlloc(allocator, first_payload);
    defer allocator.free(first);
    const second = try encode(second_payload, dictionary);
    defer allocator.free(second);
    const stream = try std.mem.concat(allocator, u8, &.{ first, second });
    defer allocator.free(stream);
    for (policies) |policy| {
        var decoder = zstd.NativeIncrementalFrameDecoder.initWithOptions(allocator, .{ .input_policy = policy, .expected_output_len = first_payload.len + second_payload.len });
        defer decoder.deinit();
        var output: [first_payload.len + second_payload.len]u8 = undefined;
        try std.testing.expectError(error.NeedDictionary, decoder.step(stream, &output));
        const progressed = decoder.last_step_progress;
        try std.testing.expectEqual(first_payload.len, progressed.output_written);
        try std.testing.expectEqualSlices(u8, first_payload, output[0..first_payload.len]);
        try std.testing.expectEqual(@as(usize, 1), decoder.data_frame_count);
        const live = decoder.workingMemoryBytes();
        const peak = decoder.peakWorkingMemoryBytes();
        try decoder.provideDictionary(dictionary);
        try std.testing.expectEqual(live, decoder.workingMemoryBytes());
        try std.testing.expectEqual(peak, decoder.peakWorkingMemoryBytes());
        try finish(&decoder, stream[progressed.input_read..], second_payload, stream.len, 3);
        try std.testing.expectEqual(stream.len, decoder.input_received);
        try std.testing.expectEqual(output.len, decoder.output_written);

        decoder.resetWithOptions(.{ .input_policy = policy, .stop_after_first_frame = true }) catch unreachable;
        try std.testing.expectError(error.NeedDictionary, decoder.step(second, &.{}));
        const read = decoder.last_step_progress.input_read;
        try decoder.provideDictionary(dictionary);
        try finish(&decoder, second[read..], second_payload, second.len, 1);
        try decoder.nextStream();
        try std.testing.expectEqual(@as(?u32, null), decoder.requiredDictionaryId());
        try std.testing.expectError(error.NeedDictionary, decoder.step(second, &.{}));
    }
}

test "Zstd dictionary resume preserves fatal errors and ID zero never requests a dictionary" {
    const dictionary = zstd.NativeDictionary.init(0x5588, "abcdefghijklmnop");
    const payload = "pfx-abcdefghijklmnop-tail";
    const frame = try encode(payload, dictionary);
    defer allocator.free(frame);
    for (policies) |policy| {
        var failing = std.testing.FailingAllocator.init(allocator, .{});
        var decoder = zstd.NativeIncrementalFrameDecoder.initWithOptions(failing.allocator(), .{ .input_policy = policy });
        var decoder_live = true;
        defer if (decoder_live) decoder.deinit();
        try std.testing.expectError(error.NeedDictionary, decoder.step(frame, &.{}));
        const read = decoder.last_step_progress.input_read;
        try decoder.provideDictionary(dictionary);
        failing.fail_index = failing.alloc_index;
        var output: [payload.len]u8 = undefined;
        try std.testing.expectError(error.OutOfMemory, decoder.step(frame[read..], &output));
        try std.testing.expectEqual(@as(?u32, null), decoder.requiredDictionaryId());
        try std.testing.expectError(error.InvalidStreamState, decoder.provideDictionary(dictionary));
        try std.testing.expectError(error.OutOfMemory, decoder.step(frame, &output));
        try std.testing.expectEqualDeep(core.Progress{}, decoder.last_step_progress);
        failing.fail_index = std.math.maxInt(usize);
        decoder.reset();
        try std.testing.expectEqual(@as(?u32, null), decoder.requiredDictionaryId());
        try std.testing.expectEqual(decoder.workingMemoryBytes(), decoder.peakWorkingMemoryBytes());
        decoder.deinit();
        decoder_live = false;
        try std.testing.expectEqual(failing.allocated_bytes, failing.freed_bytes);
    }
    const idless = [_]u8{ 0x28, 0xb5, 0x2f, 0xfd, 0x20, 4, 0x3d, 0, 0, 0, 1, 0x54, 0, 2, 1, 7 };
    var decoder = zstd.NativeIncrementalFrameDecoder.init(allocator);
    defer decoder.deinit();
    var output: [4]u8 = undefined;
    try std.testing.expectError(error.InvalidMatch, decoder.step(&idless, &output));
    try std.testing.expectEqual(@as(?u32, null), decoder.requiredDictionaryId());
    try std.testing.expectError(error.InvalidStreamState, decoder.provideDictionary(zstd.NativeDictionary.initRawContent("wxyz")));
    decoder.reset();
    decoder.input_received = std.math.maxInt(usize);
    try std.testing.expectError(error.IntegerOverflow, decoder.step("x", &output));
    try std.testing.expectEqualDeep(core.Progress{}, decoder.last_step_progress);
}

test "Zstd dictionary resume borrowed bytes expire at frame completion and reset clears requests" {
    const dictionary = zstd.NativeDictionary.init(0x55ab, "abcdefghijklmnop");
    const payload = "pfx-abcdefghijklmnop-tail";
    const frame = try encode(payload, dictionary);
    defer allocator.free(frame);
    const next_payload = "ordinary following frame";
    const next = try zstd.encodeRawOrRleFrameAlloc(allocator, next_payload);
    defer allocator.free(next);
    for (policies) |policy| {
        var decoder = zstd.NativeIncrementalFrameDecoder.initWithOptions(allocator, .{ .input_policy = policy });
        defer decoder.deinit();
        try std.testing.expectError(error.NeedDictionary, decoder.step(frame, &.{}));
        const accepted = decoder.last_step_progress.input_read;
        {
            const borrowed = try allocator.dupe(u8, dictionary.content);
            defer allocator.free(borrowed);
            try decoder.provideDictionary(zstd.NativeDictionary.init(dictionary.id, borrowed));
            try finish(&decoder, frame[accepted..], payload, frame.len, 1);
            try std.testing.expect(decoder.frame_dictionary == null);
            try std.testing.expectEqual(@as(usize, 0), decoder.direct_dictionary_history.len);
        }
        try finish(&decoder, next, next_payload, next.len, 3);
        try std.testing.expectEqual(frame.len + next.len, decoder.input_received);
        try std.testing.expectError(error.NeedDictionary, decoder.step(frame, &.{}));
        const retained = decoder.workingMemoryBytes();
        decoder.reset();
        try std.testing.expect(decoder.requiredDictionaryId() == null);
        try std.testing.expectEqual(retained, decoder.workingMemoryBytes());
        try std.testing.expectEqual(retained, decoder.peakWorkingMemoryBytes());
        try std.testing.expectError(error.InvalidStreamState, decoder.provideDictionary(dictionary));
        try std.testing.expectError(error.NeedDictionary, decoder.step(frame, &.{}));
        try decoder.resetWithOptions(.{ .input_policy = policy });
        try std.testing.expect(decoder.requiredDictionaryId() == null);
        try std.testing.expectEqual(@as(usize, 0), decoder.workingMemoryBytes());
    }
}

test "Zstd dictionary resume work and checksum failures stay fatal after a successful provide" {
    const dictionary = zstd.NativeDictionary.init(0x55ac, "abcdefghijklmnop");
    const payload = "pfx-abcdefghijklmnop-tail";
    const frame = try encode(payload, dictionary);
    defer allocator.free(frame);
    for (policies) |policy| {
        var decoder = zstd.NativeIncrementalFrameDecoder.initWithOptions(allocator, .{ .input_policy = policy, .max_working_memory = 16 });
        defer decoder.deinit();
        try std.testing.expectError(error.NeedDictionary, decoder.step(frame, &.{}));
        const accepted = decoder.last_step_progress.input_read;
        const live = decoder.workingMemoryBytes();
        try decoder.provideDictionary(dictionary);
        try std.testing.expectEqual(live, decoder.workingMemoryBytes());
        var output: [payload.len]u8 = @splat(0xa5);
        try std.testing.expectError(error.WorkingMemoryLimitExceeded, decoder.step(frame[accepted..], &output));
        try std.testing.expect(decoder.requiredDictionaryId() == null);
        try std.testing.expect(decoder.peakWorkingMemoryBytes() <= 16);
        try std.testing.expectEqual(@as(usize, 0), decoder.last_step_progress.output_written);
        try std.testing.expectError(error.InvalidStreamState, decoder.provideDictionary(dictionary));
        for (output) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);

        var corrupt = try allocator.dupe(u8, frame);
        defer allocator.free(corrupt);
        corrupt[corrupt.len - 1] ^= 1;
        try decoder.resetWithOptions(.{ .input_policy = policy });
        try std.testing.expectError(error.NeedDictionary, decoder.step(corrupt, &.{}));
        const read = decoder.last_step_progress.input_read;
        try decoder.provideDictionary(dictionary);
        try std.testing.expectError(error.ChecksumMismatch, decoder.step(corrupt[read..], &output));
        try std.testing.expectEqual(payload.len, decoder.last_step_progress.output_written);
        try std.testing.expectEqualSlices(u8, payload, &output);
        try std.testing.expect(decoder.requiredDictionaryId() == null);
        try std.testing.expectError(error.InvalidStreamState, decoder.provideDictionary(dictionary));
        try std.testing.expectError(error.ChecksumMismatch, decoder.step(corrupt, &output));
        try std.testing.expectEqualDeep(core.Progress{}, decoder.last_step_progress);
    }
}

test "Zstd dictionary resume fatal termination releases provided borrow but preserves configured dictionaries" {
    const requested = zstd.NativeDictionary.init(0x55ae, "abcdefghijklmnop");
    const configured = zstd.NativeDictionary.init(0x55af, "QRSTUVWXYZabcdef");
    const payload = "pfx-abcdefghijklmnop-tail";
    const next_payload = "pfx-QRSTUVWXYZabcdef-tail";
    const frame = try encode(payload, requested);
    defer allocator.free(frame);
    const next = try encode(next_payload, configured);
    defer allocator.free(next);
    const corrupt = try allocator.dupe(u8, frame);
    defer allocator.free(corrupt);
    corrupt[corrupt.len - 1] ^= 1;
    const configured_entries = [_]zstd.NativeDictionary{configured};
    for (policies) |policy| {
        inline for (.{ false, true }) |use_set| {
            var decoder = if (use_set)
                zstd.NativeIncrementalFrameDecoder.initWithDictionarySetAndOptions(allocator, zstd.NativeDictionarySet.init(&configured_entries), .{ .input_policy = policy })
            else
                zstd.NativeIncrementalFrameDecoder.initWithDictionaryAndOptions(allocator, configured, .{ .input_policy = policy });
            defer decoder.deinit();
            try std.testing.expectError(error.NeedDictionary, decoder.step(corrupt, &.{}));
            const read = decoder.last_step_progress.input_read;
            {
                const borrowed = try allocator.dupe(u8, requested.content);
                defer allocator.free(borrowed);
                try decoder.provideDictionary(zstd.NativeDictionary.init(requested.id, borrowed));
                var output: [payload.len]u8 = undefined;
                try std.testing.expectError(error.ChecksumMismatch, decoder.step(corrupt[read..], &output));
                try std.testing.expectEqualSlices(u8, payload, &output);
                try std.testing.expect(decoder.frame_dictionary == null);
                try std.testing.expect(decoder.requiredDictionaryId() == null);
                try std.testing.expectEqual(@as(usize, 0), decoder.direct_dictionary_history.len);
                try std.testing.expectEqual(payload.len, decoder.last_step_progress.output_written);
            }
            // The caller has freed provided bytes. Terminal operations only
            // consult owned state and keep the published progress unchanged.
            const terminal = decoder.snapshot();
            var guard: [7]u8 = @splat(0xa5);
            try std.testing.expectError(error.ChecksumMismatch, decoder.step("unconsumed", &guard));
            try std.testing.expectError(error.ChecksumMismatch, decoder.finish());
            try std.testing.expectEqual(terminal.input_received, decoder.input_received);
            try std.testing.expectEqual(terminal.output_written, decoder.output_written);
            try std.testing.expectEqual(terminal.working_bytes, decoder.workingMemoryBytes());
            try std.testing.expectEqual(terminal.peak_working_bytes, decoder.peakWorkingMemoryBytes());
            try std.testing.expectEqual(terminal.error_input_offset, decoder.error_input_offset);
            try std.testing.expectEqual(terminal.error_output_offset, decoder.error_output_offset);
            try std.testing.expectEqualDeep(core.Progress{}, decoder.last_step_progress);
            for (guard) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
            decoder.reset();
            try finish(&decoder, next, next_payload, 3, 1);
            try std.testing.expect(decoder.requiredDictionaryId() == null);
            try std.testing.expectEqual(next.len, decoder.input_received);
            try std.testing.expectEqual(next_payload.len, decoder.output_written);
        }
    }
}
