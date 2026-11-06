const std = @import("std");
const core = @import("../../core.zig");
const adapter = @import("../../archive_stream/incremental_decoder_codecs.zig").Zstandard;
const h = @import("helpers.zig");
const a = h.a;

pub fn contracts(comptime Z: type) !void {
    try std.testing.expect(!(Z.NativeIncrementalFrameDecoder.Options{}).ignore_content_checksum);
    const raw = try h.wire.rawAlloc(a, h.plain, true);
    defer a.free(raw);
    const standard = try h.wire.standardAlloc(a, raw);
    defer a.free(standard);
    const repeated = [_]u8{'R'} ** 512;
    const rle = try h.memory.rleAlloc(&repeated, false);
    defer a.free(rle);
    const compressed = try h.memory.compressedAlloc();
    defer a.free(compressed);
    const compressed_plain = try h.memory.compressedPlainAlloc();
    defer a.free(compressed_plain);
    for ([_]struct { frame: []const u8, payload: []const u8 }{
        .{ .frame = standard, .payload = h.plain },
        .{ .frame = rle, .payload = &repeated },
        .{ .frame = compressed, .payload = compressed_plain },
    }) |sample| {
        for ([_]Z.FrameFormat{ .standard, .magicless }) |format| {
            const frame = if (format == .standard) sample.frame else sample.frame[4..];
            for ([_]core.CompressedInputPolicy{ .block_stream, .prevalidated_frame }) |policy| {
                try footer(Z, frame, sample.payload, .{ .format = format, .input_policy = policy, .ignore_content_checksum = true });
                try lifecycle(Z, frame, sample.payload, .{ .format = format, .input_policy = policy, .ignore_content_checksum = true });
            }
        }
    }
    try direct(Z);
    try constraints(Z, standard);
    try concatenation(Z, standard);
    try stopAndResume(Z, standard);
    try sourceAdapter(standard);
}

fn footer(comptime Z: type, frame: []const u8, payload: []const u8, options: Z.NativeIncrementalFrameDecoder.Options) !void {
    const bad = try h.corrupt(frame);
    defer a.free(bad);
    var decoder = Z.NativeIncrementalFrameDecoder.initWithOptions(a, options);
    defer decoder.deinit();
    const output = try a.alloc(u8, payload.len + 17);
    defer a.free(output);
    @memset(output, 0xa5);
    const end = bad.len - 4;
    var written: usize = 0;
    const prefix = try decoder.step(bad[0..end], output[0..payload.len]);
    written += prefix.progress.output_written;
    try std.testing.expectEqual(end, prefix.progress.input_read);
    try std.testing.expectEqual(core.StepResult.Status.need_input, prefix.status);
    try std.testing.expectEqual(@as(core.StreamCount, 0), decoder.snapshot().data_frame_count);
    try std.testing.expectError(error.TruncatedFrame, decoder.finish());
    for (0..4) |index| {
        const before = decoder.snapshot();
        const step = try decoder.step(bad[end + index ..][0..1], output[written..payload.len]);
        const after = decoder.snapshot();
        try std.testing.expectEqual(@as(usize, 1), step.progress.input_read);
        try std.testing.expectEqual(@as(core.StreamCount, 1), after.input_received - before.input_received);
        try std.testing.expectEqual(@as(core.StreamCount, step.progress.output_written), after.output_written - before.output_written);
        written += step.progress.output_written;
        if (index != 3) {
            try std.testing.expectEqual(core.StepResult.Status.need_input, step.status);
            try std.testing.expectEqual(@as(core.StreamCount, 0), after.data_frame_count);
            try std.testing.expectError(error.TruncatedFrame, decoder.finish());
        } else try std.testing.expectEqual(core.StepResult.Status.done, step.status);
    }
    try decoder.finish();
    try std.testing.expectEqual(payload.len, written);
    try std.testing.expectEqual(frame.len, decoder.snapshot().input_received);
    try std.testing.expectEqual(@as(core.StreamCount, 1), decoder.snapshot().data_frame_count);
    try std.testing.expectEqualSlices(u8, payload, output[0..written]);
    try h.wire.untouched(output[written..]);
}

fn lifecycle(comptime Z: type, frame: []const u8, payload: []const u8, options: Z.NativeIncrementalFrameDecoder.Options) !void {
    const bad = try h.corrupt(frame);
    defer a.free(bad);
    var decoder = Z.NativeIncrementalFrameDecoder.initWithOptions(a, options);
    defer decoder.deinit();
    const first = try h.wire.drive(a, &decoder, bad, payload.len, 1, 7);
    defer a.free(first.output);
    try decoder.finish();
    try std.testing.expectEqual(frame.len, first.consumed);
    try std.testing.expectEqualSlices(u8, payload, first.output);
    const done = try decoder.step(&.{}, &.{});
    try std.testing.expectEqual(core.StepResult.Status.done, done.status);
    try std.testing.expectEqual(@as(usize, 0), done.progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), done.progress.output_written);
    decoder.reset();
    try std.testing.expect(decoder.options.ignore_content_checksum);
    try std.testing.expectEqual(@as(core.StreamCount, 0), decoder.snapshot().input_received);
    try std.testing.expectEqual(@as(core.StreamCount, 0), decoder.snapshot().output_written);
    var strict = options;
    strict.ignore_content_checksum = false;
    try decoder.resetWithOptions(strict);
    try std.testing.expectError(error.ChecksumMismatch, h.wire.drive(a, &decoder, bad, payload.len, 1, 7));
    try std.testing.expectEqualStrings("ChecksumMismatch", decoder.diagnostics().last_error_name);
    try std.testing.expectError(error.ChecksumMismatch, decoder.finish());
    try decoder.resetWithOptions(options);
    const retry = try h.wire.drive(a, &decoder, bad, payload.len, 3, 11);
    defer a.free(retry.output);
    try decoder.finish();
    try std.testing.expectEqualSlices(u8, payload, retry.output);
}

fn direct(comptime Z: type) !void {
    const payload = "direct-checksum-sequence-history" ** 128;
    const encoded = try Z.encodeNativeFrameWithOptionsAlloc(a, payload, .{ .selection = .literal_only, .content_checksum = true });
    defer a.free(encoded.frame);
    try std.testing.expectEqual(Z.NativeBlockType.compressed, (try Z.inspectNativeFrameFirstBlock(encoded.frame)).block_type);
    const bad = try h.corrupt(encoded.frame);
    defer a.free(bad);
    for ([_]Z.FrameFormat{ .standard, .magicless }) |format| {
        const frame = if (format == .standard) bad else bad[4..];
        var decoder = Z.NativeIncrementalFrameDecoder.initWithOptions(a, .{ .format = format, .input_policy = .prevalidated_frame, .ignore_content_checksum = true, .expected_output_len = payload.len });
        defer decoder.deinit();
        const initial = try decoder.step(frame, &.{});
        try std.testing.expectEqual(frame.len, initial.progress.input_read);
        try std.testing.expectEqual(core.StepResult.Status.need_output, initial.status);
        try std.testing.expectEqualStrings("direct_output", decoder.diagnostics().phase_name);
        try std.testing.expectEqual(@as(usize, 0), decoder.decodedBufferCapacity());
        const result = try h.wire.drive(a, &decoder, &.{}, payload.len, 1, 13);
        defer a.free(result.output);
        try decoder.finish();
        try std.testing.expectEqualSlices(u8, payload, result.output);
        try std.testing.expectEqual(@as(usize, 0), decoder.decodedBufferCapacity());
    }
}

pub fn dictionaryContracts(comptime Z: type, frame: []const u8, payload: []const u8, base: Z.FrameDecodeOptions) !void {
    const bad = try h.corrupt(frame);
    defer a.free(bad);
    for ([_]core.CompressedInputPolicy{ .block_stream, .prevalidated_frame }) |policy| {
        const options: Z.NativeIncrementalFrameDecoder.Options = .{ .format = base.format, .input_policy = policy, .ignore_content_checksum = true };
        var decoder = if (base.dictionary) |dictionary|
            Z.NativeIncrementalFrameDecoder.initWithDictionaryAndOptions(a, dictionary, options)
        else
            Z.NativeIncrementalFrameDecoder.initWithDictionarySetAndOptions(a, base.dictionary_set.?, options);
        defer decoder.deinit();
        const result = try h.wire.drive(a, &decoder, bad, payload.len, 1, 7);
        defer a.free(result.output);
        try decoder.finish();
        try std.testing.expectEqualSlices(u8, payload, result.output);
        try std.testing.expectEqual(frame.len, result.consumed);
        var missing = Z.NativeIncrementalFrameDecoder.initWithOptions(a, options);
        defer missing.deinit();
        try std.testing.expectError(error.NeedDictionary, missing.step(bad, &.{}));
        try std.testing.expectEqual(@as(?u32, 42), missing.snapshot().required_dictionary_id);
    }
}

fn constraints(comptime Z: type, frame: []const u8) !void {
    const bad = try h.corrupt(frame);
    defer a.free(bad);
    for ([_]core.CompressedInputPolicy{ .block_stream, .prevalidated_frame }) |policy| {
        var limited = Z.NativeIncrementalFrameDecoder.initWithOptions(a, .{ .input_policy = policy, .ignore_content_checksum = true, .max_output_len = h.plain.len - 1 });
        defer limited.deinit();
        try std.testing.expectError(error.OutputLimitExceeded, h.wire.drive(a, &limited, bad, h.plain.len, 1, 7));
        var pledge = Z.NativeIncrementalFrameDecoder.initWithOptions(a, .{ .input_policy = policy, .ignore_content_checksum = true, .expected_output_len = h.plain.len + 1 });
        defer pledge.deinit();
        var output: [h.plain.len + 17]u8 = @splat(0xa5);
        const result = try pledge.step(bad, output[0..h.plain.len]);
        try std.testing.expectEqual(bad.len, result.progress.input_read);
        try std.testing.expectEqual(h.plain.len, result.progress.output_written);
        try std.testing.expectEqualSlices(u8, h.plain, output[0..h.plain.len]);
        try h.wire.untouched(output[h.plain.len..]);
        try std.testing.expectError(error.SizeMismatch, pledge.finish());
        var denied = Z.NativeIncrementalFrameDecoder.initWithOptions(a, .{ .input_policy = policy, .ignore_content_checksum = true, .max_working_memory = 0 });
        defer denied.deinit();
        try std.testing.expectError(error.WorkingMemoryLimitExceeded, denied.step(bad, &.{}));
        try std.testing.expectEqual(@as(usize, 0), denied.snapshot().working_bytes);
        var frame_limit = Z.NativeIncrementalFrameDecoder.initWithOptions(a, .{ .input_policy = policy, .ignore_content_checksum = true, .max_decoded_buffer_len = h.plain.len - 1 });
        defer frame_limit.deinit();
        try std.testing.expectError(error.OutputLimitExceeded, frame_limit.step(bad, &.{}));

        const wrong_size = try a.dupe(u8, bad);
        defer a.free(wrong_size);
        const header = try h.wire.header(wrong_size, false);
        wrong_size[header.payload_offset - header.content_width] ^= 1;
        var size = Z.NativeIncrementalFrameDecoder.initWithOptions(a, .{ .input_policy = policy, .ignore_content_checksum = true });
        defer size.deinit();
        try std.testing.expectError(error.SizeMismatch, size.step(wrong_size, output[0..h.plain.len]));
        const invalid = try a.dupe(u8, bad);
        defer a.free(invalid);
        invalid[header.payload_offset] |= 6;
        var syntax = Z.NativeIncrementalFrameDecoder.initWithOptions(a, .{ .input_policy = policy, .ignore_content_checksum = true });
        defer syntax.deinit();
        try std.testing.expectError(error.CorruptFrame, syntax.step(invalid, output[0..h.plain.len]));

        const suffix = try h.join(bad, &.{0x28});
        defer a.free(suffix);
        var trailing = Z.NativeIncrementalFrameDecoder.initWithOptions(a, .{ .input_policy = policy, .ignore_content_checksum = true });
        defer trailing.deinit();
        const accepted = try trailing.step(suffix, output[0..h.plain.len]);
        try std.testing.expectEqual(suffix.len, accepted.progress.input_read);
        try std.testing.expectEqual(h.plain.len, accepted.progress.output_written);
        try std.testing.expectError(error.TruncatedFrame, trailing.finish());
    }
}

fn concatenation(comptime Z: type, frame: []const u8) !void {
    const bad = try h.corrupt(frame);
    defer a.free(bad);
    const stream = try h.join(frame, bad);
    defer a.free(stream);
    for ([_]core.CompressedInputPolicy{ .block_stream, .prevalidated_frame }) |policy| {
        var decoder = Z.NativeIncrementalFrameDecoder.initWithOptions(a, .{ .input_policy = policy, .ignore_content_checksum = true });
        defer decoder.deinit();
        const result = try h.wire.drive(a, &decoder, stream, h.plain.len * 2, 1, 7);
        defer a.free(result.output);
        try decoder.finish();
        try std.testing.expectEqual(stream.len, result.consumed);
        try std.testing.expectEqualSlices(u8, h.plain ** 2, result.output);
        try std.testing.expectEqual(@as(core.StreamCount, 2), decoder.snapshot().data_frame_count);
        try decoder.resetWithOptions(.{ .input_policy = policy });
        try std.testing.expectError(error.ChecksumMismatch, h.wire.drive(a, &decoder, stream, h.plain.len * 2, 1, 7));
        try std.testing.expectEqual(@as(core.StreamCount, 1), decoder.snapshot().data_frame_count);
    }
}

fn stopAndResume(comptime Z: type, frame: []const u8) !void {
    const bad = try h.corrupt(frame);
    defer a.free(bad);
    const stream = try h.join(frame, bad);
    defer a.free(stream);
    for ([_]core.CompressedInputPolicy{ .block_stream, .prevalidated_frame }) |policy| {
        for ([_]bool{ false, true }) |ignore| {
            var options: Z.NativeIncrementalFrameDecoder.Options = .{ .input_policy = policy, .stop_after_first_frame = true, .max_compressed_buffer_len = stream.len };
            if (ignore) options.ignore_content_checksum = true;
            var decoder = Z.NativeIncrementalFrameDecoder.initWithOptions(a, options);
            defer decoder.deinit();
            const first = try h.wire.drive(a, &decoder, stream, h.plain.len, stream.len, 1);
            defer a.free(first.output);
            try std.testing.expectEqualSlices(u8, h.plain, first.output);
            try std.testing.expectEqual(frame.len + decoder.trailingInput().len, first.consumed);
            try std.testing.expectEqualSlices(u8, stream[frame.len..first.consumed], decoder.trailingInput());
            const before = decoder.snapshot();
            try std.testing.expectEqual(@as(core.StreamCount, 1), before.data_frame_count);
            try std.testing.expectEqual(first.consumed, before.input_received);
            try std.testing.expectEqual(h.plain.len, before.output_written);
            try decoder.finish();
            try decoder.nextStream();
            try std.testing.expectEqual(before.input_received, decoder.snapshot().input_received);
            try std.testing.expectEqual(before.output_written, decoder.snapshot().output_written);
            try std.testing.expectEqual(before.data_frame_count, decoder.snapshot().data_frame_count);
            const remainder = stream[first.consumed..];
            if (!ignore) {
                try std.testing.expectError(error.ChecksumMismatch, h.wire.drive(a, &decoder, remainder, h.plain.len, stream.len, 7));
                try std.testing.expectEqual(@as(core.StreamCount, 1), decoder.snapshot().data_frame_count);
                continue;
            }
            const second = try h.wire.drive(a, &decoder, remainder, h.plain.len, stream.len, 7);
            defer a.free(second.output);
            try std.testing.expectEqualSlices(u8, h.plain, second.output);
            try std.testing.expectEqual(remainder.len, second.consumed);
            try std.testing.expectEqual(stream.len, decoder.snapshot().input_received);
            try std.testing.expectEqual(h.plain.len * 2, decoder.snapshot().output_written);
            try std.testing.expectEqual(@as(core.StreamCount, 2), decoder.snapshot().data_frame_count);
            try std.testing.expectEqual(@as(usize, 0), decoder.trailingInput().len);
            try decoder.finish();
        }
    }
}

fn sourceAdapter(frame: []const u8) !void {
    const bad = try h.corrupt(frame);
    defer a.free(bad);
    try std.testing.expect(!adapter.default_options.ignore_content_checksum);
    var strict = try adapter.init(a, adapter.default_options);
    defer adapter.deinit(&strict);
    try std.testing.expectError(error.ChecksumMismatch, h.wire.drive(a, &strict, bad, h.plain.len, 1, 7));
    var state = try adapter.init(a, .{ .ignore_content_checksum = true });
    defer adapter.deinit(&state);
    var output: [h.plain.len + 17]u8 = @splat(0xa5);
    var written: usize = 0;
    for (0..bad.len) |index| {
        const step = try adapter.step(&state, bad[index..][0..1], output[written..h.plain.len]);
        try std.testing.expectEqual(@as(usize, 1), step.progress.input_read);
        written += step.progress.output_written;
    }
    try adapter.finish(&state);
    try std.testing.expectEqual(h.plain.len, written);
    try std.testing.expectEqualSlices(u8, h.plain, output[0..written]);
    try h.wire.untouched(output[written..]);
    try std.testing.expectEqual(@as(usize, 0), adapter.trailingInput(&state).len);
}
