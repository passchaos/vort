const std = @import("std");
const zstd = @import("../zstd.zig");
const core = @import("../core.zig");
const h = @import("zstd_stream_counter_helpers.zig");
const a = std.testing.allocator;

test {
    _ = h;
}

test "Zstd stream counters ordinary frames retain all independently archived small wires" {
    for (h.frozen_wires) |sample| {
        const expected = try h.frozenAlloc(a, sample.name);
        defer a.free(expected);
        const actual = switch (sample.name) {
            .rle_single => try zstd.encodeRawOrRleFrameWithOptionsAlloc(a, &h.rle, .{ .content_checksum = false }),
            .empty_single => try zstd.encodeRawOrRleFrameWithOptionsAlloc(a, "", .{ .content_checksum = false }),
            .structured_single => (try zstd.encodeNativeFrameWithOptionsAlloc(a, h.plain, .{ .strategy = .fast, .content_checksum = false })).frame,
            .rle_incremental_exact => block: {
                var encoder = try zstd.NativeIncrementalFrameEncoder.initExactSize(a, .{ .selection = .raw_or_rle, .content_checksum = false, .block_size_max = 128 }, h.rle.len);
                defer encoder.deinit();
                break :block try h.drive(a, &encoder, &h.rle, 31, 17);
            },
            .rle_incremental_unknown => block: {
                var encoder = try zstd.NativeIncrementalFrameEncoder.init(a, .{ .selection = .raw_or_rle, .include_content_size = false, .content_checksum = false, .block_size_max = 128 });
                defer encoder.deinit();
                break :block try h.drive(a, &encoder, &h.rle, 31, 17);
            },
            .dictionary_incremental_exact => block: {
                const dictionary: zstd.NativeDictionary = .{ .id = 42, .content = h.prefix };
                var encoder = try zstd.NativeIncrementalFrameEncoder.initExactSizeWithPresetDictionary(a, .{ .strategy = .fast, .dictionary_id = 42, .content_checksum = false, .block_size_max = 128 }, h.plain.len, dictionary);
                defer encoder.deinit();
                break :block try h.drive(a, &encoder, h.plain, 31, 17);
            },
        };
        defer a.free(actual);
        try std.testing.expectEqualSlices(u8, expected, actual);
    }
    const checksum = try h.checksumWireAlloc(a);
    defer a.free(checksum);
    var encoder = try zstd.NativeIncrementalFrameEncoder.initExactSize(a, .{ .selection = .raw_or_rle, .content_checksum = true }, h.rle.len);
    defer encoder.deinit();
    const actual = try h.drive(a, &encoder, &h.rle, 31, 17);
    defer a.free(actual);
    try std.testing.expectEqualSlices(u8, checksum, actual);
    for ([_]core.CompressedInputPolicy{ .block_stream, .prevalidated_frame }) |policy| {
        var decoder = zstd.NativeIncrementalFrameDecoder.initWithOptions(a, .{ .input_policy = policy });
        defer decoder.deinit();
        const decoded = try h.decodeDrive(a, &decoder, actual, h.rle.len);
        defer a.free(decoded);
        try std.testing.expectEqualSlices(u8, &h.rle, decoded);
    }
}

test "Zstd stream counters wide public types preserve local progress and allocation accounting" {
    try std.testing.expect(core.StreamCount == h.Count);
    const Encoder = zstd.NativeIncrementalFrameEncoder;
    const Decoder = zstd.NativeIncrementalFrameDecoder;
    inline for (.{ "input_read", "output_written", "frame_input", "frame_output", "frame_count", "frame_index" }) |field|
        try std.testing.expect(@FieldType(Encoder.Snapshot, field) == h.Count);
    inline for (.{ "input_received", "output_written", "data_frame_count", "skippable_total" }) |field|
        try std.testing.expect(@FieldType(Decoder.Snapshot, field) == h.Count);
    try std.testing.expect(@FieldType(Decoder.Options, "max_output_len") == h.Count);
    try std.testing.expect(@FieldType(Decoder.Options, "expected_output_len") == ?h.Count);
    try std.testing.expect(@FieldType(core.StreamingDiagnostics, "error_input_offset") == ?h.Count);
    try std.testing.expect(@FieldType(core.Progress, "input_read") == usize);
    try std.testing.expect(@FieldType(core.Progress, "output_written") == usize);
    try std.testing.expect(@FieldType(Decoder.Options, "max_working_memory") == usize);
}

test "Zstd stream counters completed checksum frames continue past four GiB with consistent cumulative counts" {
    const options: zstd.NativeFrameOptions = .{ .selection = .raw_or_rle, .content_checksum = true };
    var encoder = try zstd.NativeIncrementalFrameEncoder.initExactSize(a, options, h.rle.len);
    defer encoder.deinit();
    const first = try h.drive(a, &encoder, &h.rle, 17, 7);
    defer a.free(first);
    const repetitions: h.Count = (@as(h.Count, 1) << 32) / @as(h.Count, @intCast(first.len)) + 2;
    const completed = try h.seedCompletedEncoder(&encoder, repetitions);
    try std.testing.expect(completed.input_bytes > (@as(h.Count, 1) << 32));
    try std.testing.expect(completed.output_bytes > (@as(h.Count, 1) << 32));
    try encoder.nextFrameExactSize(options, h.rle.len);
    const next = try h.drive(a, &encoder, &h.rle, 1, 1);
    defer a.free(next);
    try std.testing.expectEqualSlices(u8, first, next);
    const snapshot = encoder.snapshot();
    try std.testing.expectEqual(completed.input_bytes + h.rle.len, snapshot.input_read);
    try std.testing.expectEqual(completed.output_bytes + first.len, snapshot.output_written);
    try std.testing.expectEqual(completed.frames + 1, snapshot.frame_count);
    try std.testing.expectEqual(@as(h.Count, h.rle.len), snapshot.frame_input);
    try std.testing.expectEqual(@as(h.Count, first.len), snapshot.frame_output);
    encoder.reset();
    try std.testing.expectEqual(@as(h.Count, 0), encoder.snapshot().input_read);
    const reset = try h.drive(a, &encoder, &h.rle, 31, 17);
    defer a.free(reset);
    try std.testing.expectEqualSlices(u8, first, reset);
}

test "Zstd stream counters both decoder policies retain wide continuation and dictionary state" {
    const dictionary: zstd.NativeDictionary = .{ .id = 42, .content = h.prefix };
    const frame = try zstd.encodeNativeFrameWithDictionaryAlloc(a, h.plain, .{ .content_checksum = true, .strategy = .fast }, dictionary);
    defer a.free(frame.frame);
    for ([_]core.CompressedInputPolicy{ .block_stream, .prevalidated_frame }) |policy| {
        var decoder = zstd.NativeIncrementalFrameDecoder.initWithDictionaryAndOptions(a, dictionary, .{ .input_policy = policy, .stop_after_first_frame = true });
        defer decoder.deinit();
        const first = try h.decodeDrive(a, &decoder, frame.frame, h.plain.len);
        defer a.free(first);
        try std.testing.expectEqualSlices(u8, h.plain, first);
        const repeat: h.Count = (@as(h.Count, 1) << 32) / @as(h.Count, @intCast(frame.frame.len)) + 2;
        const completed = try h.seedCompletedDecoder(&decoder, repeat);
        try std.testing.expect(completed.input_bytes > (@as(h.Count, 1) << 32));
        try std.testing.expect(completed.output_bytes > (@as(h.Count, 1) << 32));
        try decoder.nextStream();
        const next = try h.decodeDrive(a, &decoder, frame.frame, h.plain.len);
        defer a.free(next);
        try std.testing.expectEqualSlices(u8, h.plain, next);
        const snapshot = decoder.snapshot();
        try std.testing.expectEqual(completed.input_bytes + frame.frame.len, snapshot.input_received);
        try std.testing.expectEqual(completed.output_bytes + h.plain.len, snapshot.output_written);
        try std.testing.expectEqual(completed.frames + 1, snapshot.data_frame_count);
        try std.testing.expectEqual(snapshot.input_received, decoder.diagnostics().frame_input_read);
        try std.testing.expectEqual(snapshot.output_written, decoder.diagnostics().output_written);
        decoder.reset();
        try std.testing.expectEqual(@as(h.Count, 0), decoder.snapshot().input_received);
        try std.testing.expectEqual(@as(h.Count, 0), decoder.snapshot().output_written);
    }
}

test "Zstd stream counters rolling absolute index stores real candidates on both sides of four GiB" {
    const index_mod = @import("../zstd/incremental/encoder/history_index.zig");
    var index: index_mod.Index = .{};
    defer index.deinit(a);
    try index.prepare(a, false);
    const base: h.Count = (@as(h.Count, 1) << 32) - 4;
    index.insertBlock("abcdefgh-abcdefgh-abcdefgh", base);
    const candidates = index.recentCandidates("abcdefgh");
    try std.testing.expectEqual(base + 18, candidates[0]);
    try std.testing.expectEqual(base + 9, candidates[1]);
    try std.testing.expectEqual(base, candidates[2]);
    try std.testing.expect(@typeInfo(@TypeOf(index.recent_entries.items)).pointer.child == h.Count);
}

test "Zstd stream counters large pledge metadata crosses four GiB without allocating corresponding content" {
    const pledge: h.Count = (@as(h.Count, 1) << 32) + 7;
    var encoder = try zstd.NativeIncrementalFrameEncoder.initExactSize(a, .{ .selection = .raw_or_rle, .content_checksum = true, .window_log = 10 }, pledge);
    defer encoder.deinit();
    try std.testing.expectEqual(@as(?h.Count, pledge), encoder.expected_input_len);
    var header: [64]u8 = undefined;
    const step = try encoder.step("", &header);
    try std.testing.expect(step.progress.output_written > 0);
    try std.testing.expectEqual(@as(u64, pledge), try h.pledgedContentSize(header[0..step.progress.output_written]));
    encoder.finish();
    var untouched: [8]u8 = @splat(0xa5);
    try std.testing.expectError(error.SizeMismatch, encoder.step("", &untouched));
    try h.untouched(&untouched);
    for ([_]core.CompressedInputPolicy{ .block_stream, .prevalidated_frame }) |policy| {
        var decoder = zstd.NativeIncrementalFrameDecoder.initWithOptions(a, .{ .input_policy = policy, .expected_output_len = pledge, .max_output_len = pledge, .max_working_memory = 4096 });
        defer decoder.deinit();
        _ = try decoder.step(header[0..step.progress.output_written], &.{});
        try std.testing.expectEqual(@as(?h.Count, pledge), decoder.diagnostics().expected_output_len);
        try std.testing.expectEqual(@as(h.Count, 0), decoder.snapshot().output_written);
        try std.testing.expect(decoder.workingMemoryBytes() <= 4096);
        try std.testing.expectError(error.TruncatedFrame, decoder.finish());
    }
}

test "Zstd stream counters validated repeated RLE prefix keeps within frame history and pledge consistent past four GiB" {
    const block = try a.alloc(u8, 128 * 1024);
    defer a.free(block);
    @memset(block, 'R');
    const pledge: h.Count = (@as(h.Count, 1) << 32) + 7;
    const options: zstd.NativeFrameOptions = .{ .selection = .raw_or_rle, .content_checksum = false, .window_log = 20, .block_size_max = block.len };
    var encoder = try zstd.NativeIncrementalFrameEncoder.initExactSize(a, options, pledge);
    defer encoder.deinit();
    var header: [64]u8 = undefined;
    const first = try encoder.step("", &header);
    try std.testing.expectEqual(@as(usize, 14), first.progress.output_written);
    try std.testing.expectEqual(@as(u64, pledge), try h.pledgedContentSize(header[0..first.progress.output_written]));
    const accepted = try encoder.step(block, &.{});
    try std.testing.expectEqual(block.len, accepted.progress.input_read);
    encoder.flush();
    var nonfinal: std.ArrayList(u8) = .empty;
    defer nonfinal.deinit(a);
    var scratch: [8]u8 = undefined;
    for (0..16) |_| {
        const result = try encoder.step("", &scratch);
        try nonfinal.appendSlice(a, scratch[0..result.progress.output_written]);
        if (result.status == .need_input) break;
    }
    const completed = try h.validatedRepeatedRleEncoderPrefix(&encoder, nonfinal.items, first.progress.output_written, 32768);
    try std.testing.expectEqual(@as(h.Count, 1) << 32, completed);
    const before = encoder.snapshot();
    const tail_input = "RRRRRRR";
    const tail_step = try encoder.step(tail_input, &.{});
    try std.testing.expectEqual(tail_input.len, tail_step.progress.input_read);
    try std.testing.expectEqual(@as(h.Count, tail_input.len), encoder.snapshot().frame_input - before.frame_input);
    encoder.finish();
    var wire_tail: std.ArrayList(u8) = .empty;
    defer wire_tail.deinit(a);
    for (0..16) |_| {
        const result = try encoder.step("", &scratch);
        try wire_tail.appendSlice(a, scratch[0..result.progress.output_written]);
        if (result.status == .done) break;
    }
    try std.testing.expectEqualSlices(u8, &.{ 0x3b, 0, 0, 'R' }, wire_tail.items);
    const after = encoder.snapshot();
    try std.testing.expect(after.done);
    try std.testing.expectEqual(pledge, after.frame_input);
    try std.testing.expectEqual(pledge, after.input_read);
    try std.testing.expectEqual(@as(h.Count, 14 + 32768 * 4 + 4), after.output_written);
    try std.testing.expectEqual(@as(h.Count, 1), after.frame_count);
    try std.testing.expectEqual(completed, encoder.history.absolute_end);
    std.debug.print("validated RLE prefix model={d} actual-final-input=7 wire-tail=4 bytes\n", .{completed});
}
