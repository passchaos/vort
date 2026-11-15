//! Empty data members remain valid after an exact logical-stream output pledge.
const std = @import("std");
const zstd = @import("../../zstd.zig");
const core = @import("../../core.zig");
const a = std.testing.allocator;
const policies = [_]core.CompressedInputPolicy{ .block_stream, .prevalidated_frame };
const formats = [_]zstd.FrameFormat{ .standard, .magicless };
const kinds = [_]zstd.NativeBlockType{ .raw, .rle, .compressed };
const flags = [_]bool{ false, true };
const data_cases = [_]struct { selection: zstd.NativeFrameSelection, payload: []const u8 }{
    .{ .selection = .raw_or_rle, .payload = "surplus" },
    .{ .selection = .literal_only, .payload = "surplus" },
    .{ .selection = .raw_or_rle, .payload = "zzzz" },
};

fn emptyFrame(format: zstd.FrameFormat, known: bool, checksum: bool, kind: zstd.NativeBlockType) ![]u8 {
    const descriptor: u8 = (if (known) @as(u8, 0x20) else 0) | (if (checksum) @as(u8, 4) else 0);
    const short_header = [_]u8{ descriptor, 0 };
    // A compressed block needs a nonzero Block_Maximum_Size even when its
    // decoded content is empty. Preserve a 1 KiB window with four-byte FCS=0.
    const compressed_header = [_]u8{ 0x80 | (descriptor & 4), 0, 0, 0, 0, 0 };
    const header: []const u8 = if (known and kind == .compressed) &compressed_header else &short_header;
    const block: []const u8 = switch (kind) {
        .raw => &.{ 1, 0, 0 },
        .rle => &.{ 3, 0, 0, 'z' },
        // Last compressed block, three-byte payload: two-byte raw-literals
        // header with regenerated size zero, followed by zero sequences.
        // All three block forms were independently accepted by libzstd 1.4.8.
        .compressed => &.{ 0x1d, 0, 0, 4, 0, 0 },
    };
    // Low 32 bits of XXH64("", seed=0), in little-endian wire order.
    return std.mem.concat(a, u8, &.{
        if (format == .standard) &.{ 0x28, 0xb5, 0x2f, 0xfd } else &.{},
        header,
        block,
        if (checksum) &.{ 0x99, 0xe9, 0xd8, 0x51 } else &.{},
    });
}

fn dataFrame(format: zstd.FrameFormat, known: bool, selection: zstd.NativeFrameSelection, payload: []const u8) ![]u8 {
    const encoded = try zstd.encodeNativeFrameWithOptionsAlloc(a, payload, .{
        .format = format,
        .include_content_size = known,
        .content_checksum = true,
        .selection = selection,
    });
    return encoded.frame;
}

const Totals = struct { read: usize = 0, written: usize = 0 };

fn account(decoder: *zstd.NativeIncrementalFrameDecoder, totals: *Totals, progress: core.Progress, input_len: usize, output_len: usize) !void {
    try std.testing.expect(progress.input_read <= input_len);
    try std.testing.expect(progress.output_written <= output_len);
    totals.read += progress.input_read;
    totals.written += progress.output_written;
    const snap = decoder.snapshot();
    try std.testing.expectEqual(@as(core.StreamCount, totals.read), snap.input_received);
    try std.testing.expectEqual(@as(core.StreamCount, totals.written), snap.output_written);
    try std.testing.expectEqual(progress, snap.last_step_progress);
}

fn step(decoder: *zstd.NativeIncrementalFrameDecoder, totals: *Totals, input: []const u8, output: []u8) !core.StepResult {
    const result = decoder.step(input, output) catch |err| {
        try account(decoder, totals, decoder.snapshot().last_step_progress, input.len, output.len);
        return err;
    };
    try account(decoder, totals, result.progress, input.len, output.len);
    return result;
}

fn pollWithOutput(decoder: *zstd.NativeIncrementalFrameDecoder, totals: *Totals, output: []u8) !void {
    const before = decoder.snapshot().data_frame_count;
    const result = try step(decoder, totals, "", output);
    try std.testing.expect(result.status == .need_input or result.status == .done);
    try std.testing.expectEqual(core.Progress{}, result.progress);
    try std.testing.expectEqual(before, decoder.snapshot().data_frame_count);
}

fn poll(decoder: *zstd.NativeIncrementalFrameDecoder, totals: *Totals) !void {
    try pollWithOutput(decoder, totals, &.{});
}

fn feed(decoder: *zstd.NativeIncrementalFrameDecoder, totals: *Totals, stream: []const u8, end: usize, output: []u8) !void {
    while (totals.read < end) {
        const result = try step(decoder, totals, stream[totals.read..end], output[totals.written..]);
        try std.testing.expect(result.progress.input_read != 0 or result.progress.output_written != 0);
        try std.testing.expect(result.status != .need_output);
    }
    // Before a nonempty prefix is complete, preserve available output space;
    // once its pledge is fulfilled every subsequent poll uses an empty slice.
    try pollWithOutput(decoder, totals, output[totals.written..]);
}

fn partitioned(stream: []const u8, expected: []const u8, members: usize, policy: core.CompressedInputPolicy, format: zstd.FrameFormat, split: ?usize) !void {
    var decoder = zstd.NativeIncrementalFrameDecoder.initWithOptions(a, .{
        .format = format,
        .input_policy = policy,
        .expected_output_len = expected.len,
    });
    defer decoder.deinit();
    const storage = try a.alloc(u8, expected.len + 8);
    defer a.free(storage);
    @memset(storage, 0xa5);
    var totals: Totals = .{};
    // This also exercises a zero pledge before any frame bytes have arrived.
    try poll(&decoder, &totals);
    if (split) |cut| {
        try feed(&decoder, &totals, stream, cut, storage[0..expected.len]);
        try feed(&decoder, &totals, stream, stream.len, storage[0..expected.len]);
    } else {
        for (1..stream.len + 1) |end|
            try feed(&decoder, &totals, stream, end, storage[0..expected.len]);
    }
    try decoder.finish();
    try std.testing.expectEqual(stream.len, totals.read);
    try std.testing.expectEqual(expected.len, totals.written);
    try std.testing.expectEqual(@as(core.StreamCount, members), decoder.snapshot().data_frame_count);
    try std.testing.expectEqualSlices(u8, expected, storage[0..expected.len]);
    for (storage[expected.len..]) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
    try poll(&decoder, &totals);
}

test "Zstd empty member fixtures and all input splits" {
    for (formats) |format| for (flags) |known| for (flags) |checksum| for (kinds) |kind| {
        const empty = try emptyFrame(format, known, checksum, kind);
        defer a.free(empty);
        const decoded = try zstd.decodeFrameAllocWithOptions(a, empty, .{ .format = format, .expected_output_len = 0 });
        defer a.free(decoded);
        try std.testing.expectEqual(@as(usize, 0), decoded.len);
        const header = try zstd.inspectNativeFrameHeaderWithFormat(empty, format);
        try std.testing.expectEqual(if (known) @as(?u64, 0) else null, header.content_size);
        try std.testing.expectEqual(checksum, header.has_checksum);
        try std.testing.expectEqual(kind, (try zstd.inspectNativeFrameFirstBlockWithFormat(empty, format)).block_type);
        const prefix = try dataFrame(format, known, .raw_or_rle, "pledge");
        defer a.free(prefix);
        for (policies) |policy| for (flags) |has_prefix| {
            const stream = try std.mem.concat(a, u8, &.{ if (has_prefix) prefix else &.{}, empty });
            defer a.free(stream);
            const expected: []const u8 = if (has_prefix) "pledge" else "";
            const members: usize = if (has_prefix) 2 else 1;
            // Endpoints include an empty first or second input chunk.
            for (0..stream.len + 1) |cut|
                try partitioned(stream, expected, members, policy, format, cut);
            try partitioned(stream, expected, members, policy, format, null);
        };
    };
}

test "Zstd empty member surplus rejects output after complete header or block preflight" {
    for (formats) |format| for (policies) |policy| for (flags) |known| {
        for (data_cases) |case| {
            const frame = try dataFrame(format, known, case.selection, case.payload);
            defer a.free(frame);
            if (std.mem.eql(u8, case.payload, "zzzz"))
                try std.testing.expectEqual(zstd.NativeBlockType.rle, (try zstd.inspectNativeFrameFirstBlockWithFormat(frame, format)).block_type);
            const header = try zstd.inspectNativeFrameHeaderWithFormat(frame, format);
            for (flags) |has_prefix| for (flags) |whole_frame| {
                const prefix = try dataFrame(format, true, .raw_or_rle, "pledge");
                defer a.free(prefix);
                var decoder = zstd.NativeIncrementalFrameDecoder.initWithOptions(a, .{
                    .format = format,
                    .input_policy = policy,
                    .expected_output_len = if (has_prefix) 6 else 0,
                });
                defer decoder.deinit();
                var totals: Totals = .{};
                var output: [6]u8 = @splat(0xa5);
                if (has_prefix) {
                    try feed(&decoder, &totals, prefix, prefix.len, &output);
                    try std.testing.expectEqualSlices(u8, "pledge", &output);
                }
                try poll(&decoder, &totals);
                if (whole_frame) {
                    try std.testing.expectError(error.SizeMismatch, step(&decoder, &totals, frame, &.{}));
                } else {
                    // A partial header cannot yet prove that the member emits.
                    const partial = try step(&decoder, &totals, frame[0 .. header.payload_offset - 1], &.{});
                    try std.testing.expectEqual(core.StepResult.Status.need_input, partial.status);
                    if (known) {
                        try std.testing.expectError(error.SizeMismatch, step(&decoder, &totals, frame[header.payload_offset - 1 .. header.payload_offset], &.{}));
                    } else {
                        const admitted = try step(&decoder, &totals, frame[header.payload_offset - 1 .. header.payload_offset], &.{});
                        try std.testing.expectEqual(core.StepResult.Status.need_input, admitted.status);
                        try std.testing.expectError(error.SizeMismatch, step(&decoder, &totals, frame[header.payload_offset..], &.{}));
                    }
                }
                try std.testing.expectEqual(@as(usize, if (has_prefix) 6 else 0), totals.written);
                try std.testing.expectEqual(@as(core.StreamCount, if (has_prefix) 1 else 0), decoder.snapshot().data_frame_count);
                if (!has_prefix) for (output) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
                try std.testing.expectError(error.SizeMismatch, decoder.finish());
            };
        }
    };
}

test "Zstd empty member zero output quota distinguishes pledge from limit" {
    for (formats) |format| for (policies) |policy| for (flags) |known| {
        const empty = try emptyFrame(format, known, true, .compressed);
        defer a.free(empty);
        for (data_cases) |case| {
            const frame = try dataFrame(format, known, case.selection, case.payload);
            defer a.free(frame);
            for (flags) |has_empty| {
                var decoder = zstd.NativeIncrementalFrameDecoder.initWithOptions(a, .{
                    .format = format,
                    .input_policy = policy,
                    .max_output_len = 0,
                });
                defer decoder.deinit();
                var totals: Totals = .{};
                try poll(&decoder, &totals);
                if (has_empty) {
                    try feed(&decoder, &totals, empty, empty.len, &.{});
                    try decoder.finish();
                }
                try std.testing.expectError(error.OutputLimitExceeded, step(&decoder, &totals, frame, &.{}));
                try std.testing.expectEqual(@as(usize, 0), totals.written);
                try std.testing.expectEqual(@as(core.StreamCount, if (has_empty) 1 else 0), decoder.snapshot().data_frame_count);
                try std.testing.expectError(error.OutputLimitExceeded, decoder.finish());
            }
        }
    };
}

test "Zstd empty member checksum corruption and truncation retain frame validation" {
    for (formats) |format| for (flags) |known| for (kinds) |kind| {
        const frame = try emptyFrame(format, known, true, kind);
        defer a.free(frame);
        const corrupt = try a.dupe(u8, frame);
        defer a.free(corrupt);
        corrupt[corrupt.len - 1] ^= 1;
        for (policies) |policy| {
            for (flags) |bytewise| {
                var decoder = zstd.NativeIncrementalFrameDecoder.initWithOptions(a, .{ .format = format, .input_policy = policy, .expected_output_len = 0 });
                defer decoder.deinit();
                var totals: Totals = .{};
                var saw_error = false;
                while (totals.read < corrupt.len) {
                    const end = if (bytewise) totals.read + 1 else corrupt.len;
                    _ = step(&decoder, &totals, corrupt[totals.read..end], &.{}) catch |err| {
                        try std.testing.expectEqual(error.ChecksumMismatch, err);
                        saw_error = true;
                        break;
                    };
                }
                try std.testing.expect(saw_error);
                try std.testing.expectEqual(@as(usize, 0), totals.written);
                try std.testing.expectEqual(@as(core.StreamCount, 0), decoder.snapshot().data_frame_count);
                try std.testing.expectError(error.ChecksumMismatch, decoder.finish());
            }
            // Every nonempty strict prefix must remain incomplete, including
            // prefixes that already establish zero decoded bytes.
            for (1..frame.len) |cut| {
                var decoder = zstd.NativeIncrementalFrameDecoder.initWithOptions(a, .{ .format = format, .input_policy = policy, .expected_output_len = 0 });
                defer decoder.deinit();
                var totals: Totals = .{};
                try feed(&decoder, &totals, frame, cut, &.{});
                try std.testing.expectError(error.TruncatedFrame, decoder.finish());
                try std.testing.expectEqual(@as(core.StreamCount, 0), decoder.snapshot().data_frame_count);
                // EOF validation is resumable when the missing footer arrives.
                try feed(&decoder, &totals, frame, frame.len, &.{});
                try decoder.finish();
                try std.testing.expectEqual(@as(core.StreamCount, 1), decoder.snapshot().data_frame_count);
            }
        }
    };
}

test "Zstd empty member stopped frames retain suffix and cumulative pledge" {
    for (formats) |format| for (policies) |policy| {
        const first = try emptyFrame(format, false, true, .compressed);
        defer a.free(first);
        const second = try emptyFrame(format, true, true, .raw);
        defer a.free(second);
        const surplus = try dataFrame(format, false, .raw_or_rle, "surplus");
        defer a.free(surplus);
        const stream = try std.mem.concat(a, u8, &.{ first, second, surplus });
        defer a.free(stream);
        var decoder = zstd.NativeIncrementalFrameDecoder.initWithOptions(a, .{
            .format = format,
            .input_policy = policy,
            .expected_output_len = 0,
            .stop_after_first_frame = true,
        });
        defer decoder.deinit();
        var totals: Totals = .{};
        try poll(&decoder, &totals);
        const stopped = try step(&decoder, &totals, stream, &.{});
        try std.testing.expectEqual(core.StepResult.Status.done, stopped.status);
        try std.testing.expect(totals.read >= first.len);
        try std.testing.expectEqualSlices(u8, stream[first.len..totals.read], decoder.trailingInput());
        try std.testing.expectEqual(@as(core.StreamCount, 1), decoder.snapshot().data_frame_count);
        try decoder.finish();
        const held = try step(&decoder, &totals, stream[totals.read..], &.{});
        try std.testing.expectEqual(core.StepResult.Status.done, held.status);
        try std.testing.expectEqual(core.Progress{}, held.progress);
        try decoder.nextStream();
        const next = try step(&decoder, &totals, stream[totals.read..], &.{});
        try std.testing.expectEqual(core.StepResult.Status.done, next.status);
        try std.testing.expect(totals.read >= first.len + second.len);
        try std.testing.expectEqualSlices(u8, stream[first.len + second.len .. totals.read], decoder.trailingInput());
        try std.testing.expectEqual(@as(core.StreamCount, 2), decoder.snapshot().data_frame_count);
        try decoder.finish();
        try poll(&decoder, &totals);
        try decoder.nextStream();
        try std.testing.expectError(error.SizeMismatch, step(&decoder, &totals, stream[totals.read..], &.{}));
        try std.testing.expectEqual(@as(usize, 0), totals.written);
        try std.testing.expectEqual(@as(core.StreamCount, 2), decoder.snapshot().data_frame_count);
    };
}
