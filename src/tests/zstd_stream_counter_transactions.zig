const std = @import("std");
const zstd = @import("../zstd.zig");
const core = @import("../core.zig");
const h = @import("zstd_stream_counter_helpers.zig");
const a = std.testing.allocator;

test "Zstd stream counters checked cumulative encoder overflow preserves valid repeated frame state" {
    const options: zstd.NativeFrameOptions = .{ .selection = .raw_or_rle, .content_checksum = false };
    var encoder = try zstd.NativeIncrementalFrameEncoder.initExactSize(a, options, h.rle.len);
    defer encoder.deinit();
    const first = try h.drive(a, &encoder, &h.rle, 31, 17);
    defer a.free(first);
    const copies = std.math.maxInt(h.Count) / @as(h.Count, h.rle.len);
    const completed = try h.seedCompletedEncoder(&encoder, copies);
    try encoder.nextFrameExactSize(options, h.rle.len);
    const before = encoder.snapshot();
    var output: [64]u8 = @splat(0xa5);
    try std.testing.expectError(error.IntegerOverflow, encoder.step(&h.rle, &output));
    try h.untouched(&output);
    try std.testing.expectEqual(completed.input_bytes, encoder.snapshot().input_read);
    try std.testing.expectEqual(before.frame_input, encoder.snapshot().frame_input);
    try std.testing.expectEqual(before.output_written, encoder.snapshot().output_written);
    try std.testing.expectEqual(before.frame_count, encoder.snapshot().frame_count);
}

test "Zstd stream counters pledge refusal preserves serial pending bytes and prefix" {
    try pledgedOfferRefusal(false);
}

test "Zstd stream counters pledge refusal preserves parallel pending bytes and prefix" {
    try pledgedOfferRefusal(true);
}

test "Zstd stream counters pledge short finish does not publish the staged header" {
    var encoder = try zstd.NativeIncrementalFrameEncoder.initExactSize(a, .{ .selection = .raw_or_rle }, 1);
    defer encoder.deinit();
    try std.testing.expectEqual(.need_output, (try encoder.step("", &.{})).status);
    try std.testing.expect(encoder.snapshot().pending_output != 0);
    encoder.finish();
    const before = encoder.snapshot();
    var output: [32]u8 = @splat(0xa5);
    try std.testing.expectError(error.SizeMismatch, encoder.step("", &output));
    try h.untouched(&output);
    try std.testing.expectEqualDeep(before, encoder.snapshot());
}

fn pledgedOfferRefusal(comptime parallel: bool) !void {
    const Encoder = if (parallel) zstd.NativeIncrementalParallelFrameEncoder else zstd.NativeIncrementalFrameEncoder;
    const Options = if (parallel) Encoder.Options else zstd.NativeFrameOptions;
    const frame: zstd.NativeFrameOptions = .{ .selection = .raw_or_rle, .block_size_max = 128, .window_log = 10, .content_checksum = true };
    const options: Options = if (parallel) .{
        .frame = frame,
        .parallel = .{ .io = std.testing.io, .worker_count = 1, .job_size = 256, .max_inflight_jobs = 2, .max_inflight_bytes = 512 },
    } else frame;
    const payload = "0123456789ABCDEF" ** 24;
    const surplus = payload ++ "x";
    var encoder = try Encoder.initExactSizeWithPrefix(a, options, payload.len, "preceding history");
    defer encoder.deinit();
    try std.testing.expectEqual(.pending, encoder.prefixSnapshot().phase);
    try expectPledgeRefusal(&encoder, surplus, .@"continue");
    try expectPledgeRefusal(&encoder, payload[0 .. payload.len - 1], .end);

    // Stage a header without publishing it. An invalid offer must not drain it
    // or consume the active prefix, even if several blocks fit the next call.
    const staged = try encoder.step("", &.{});
    try std.testing.expectEqual(.need_output, staged.status);
    try std.testing.expect(encoder.snapshot().pending_output != 0);
    try std.testing.expectEqual(.active, encoder.prefixSnapshot().phase);
    try expectPledgeRefusal(&encoder, surplus, .flush);
    try expectPledgeRefusal(&encoder, "", .end);

    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(a);
    const first = try encoder.step(payload[0..5], &.{});
    try std.testing.expectEqual(@as(usize, 0), first.progress.input_read);
    var header: [32]u8 = undefined;
    const accepted = try encoder.step(payload[0..5], &header);
    try std.testing.expectEqual(@as(usize, 5), accepted.progress.input_read);
    try wire.appendSlice(a, header[0..accepted.progress.output_written]);
    try expectPledgeRefusal(&encoder, surplus[5..], .end);
    try expectPledgeRefusal(&encoder, payload[5 .. payload.len - 1], .end);

    var offset: usize = 5;
    for (0..payload.len * 4) |_| {
        var output: [7]u8 = undefined;
        const step = try encoder.stepWithDirective(payload[offset..], &output, .end);
        offset += step.progress.input_read;
        try wire.appendSlice(a, output[0..step.progress.output_written]);
        if (step.status == .done) break;
    } else return error.TestUnexpectedResult;
    try std.testing.expectEqual(payload.len, offset);
    try std.testing.expectEqual(@as(core.StreamCount, 1), encoder.snapshot().frame_count);
    try std.testing.expectEqual(.none, encoder.prefixSnapshot().phase);
    const decoded = try zstd.decodeFrameAlloc(a, wire.items);
    defer a.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
}

fn expectPledgeRefusal(encoder: anytype, input: []const u8, directive: zstd.FrameEncodeDirective) !void {
    const before = encoder.snapshot();
    const prefix = encoder.prefixSnapshot();
    var output: [512]u8 = @splat(0xa5);
    try std.testing.expectError(error.SizeMismatch, encoder.stepWithDirective(input, &output, directive));
    try h.untouched(&output);
    var after = encoder.snapshot();
    if (@hasDecl(@TypeOf(encoder.*), "failedProgress")) {
        try std.testing.expectEqual(@as(?core.Progress, .{}), encoder.failedProgress());
        try std.testing.expectEqual(@as(?zstd.Error, error.SizeMismatch), after.parallel.last_error);
        after.parallel.last_error = before.parallel.last_error;
        after.parallel.last_step_progress = before.parallel.last_step_progress;
    }
    try std.testing.expectEqualDeep(before, after);
    try std.testing.expectEqualDeep(prefix, encoder.prefixSnapshot());
}

test "Zstd stream counters output overflow preserves copied prefix progress without wrapping" {
    const options: zstd.NativeFrameOptions = .{ .selection = .raw_or_rle, .content_checksum = false };
    var encoder = try zstd.NativeIncrementalFrameEncoder.initExactSize(a, options, 0);
    defer encoder.deinit();
    const first = try h.drive(a, &encoder, "", 1, 7);
    defer a.free(first);
    const copies = std.math.maxInt(h.Count) / @as(h.Count, @intCast(first.len));
    const completed = try h.seedCompletedEncoder(&encoder, copies);
    try encoder.nextFrameExactSize(options, 0);
    encoder.finish();
    const before = encoder.snapshot();
    var output: [64]u8 = @splat(0xa5);
    try std.testing.expectError(error.IntegerOverflow, encoder.step("", &output));
    const after = encoder.snapshot();
    const copied = after.output_written - before.output_written;
    try std.testing.expect(copied <= output.len);
    try std.testing.expect(after.output_written >= completed.output_bytes);
    try std.testing.expectEqualSlices(u8, first[0..@intCast(copied)], output[0..@intCast(copied)]);
    try h.untouched(output[@intCast(copied)..]);
    try std.testing.expectEqual(before.frame_count, after.frame_count);
}

test "Zstd stream counters both policies report wide output limit diagnostics and local error progress" {
    const frame = try zstd.encodeRawOrRleFrameWithOptionsAlloc(a, &h.rle, .{ .content_checksum = false });
    defer a.free(frame);
    for ([_]core.CompressedInputPolicy{ .block_stream, .prevalidated_frame }) |policy| {
        var decoder = zstd.NativeIncrementalFrameDecoder.initWithOptions(a, .{ .input_policy = policy, .stop_after_first_frame = true });
        defer decoder.deinit();
        const first = try h.decodeDrive(a, &decoder, frame, h.rle.len);
        defer a.free(first);
        const repetitions = (@as(h.Count, 1) << 32) / @as(h.Count, @intCast(frame.len)) + 2;
        const completed = try h.seedCompletedDecoder(&decoder, repetitions);
        decoder.options.max_output_len = completed.output_bytes + h.rle.len + 1;
        try decoder.nextStream();
        const second = try h.decodeDrive(a, &decoder, frame, h.rle.len);
        defer a.free(second);
        try decoder.nextStream();
        const before = decoder.snapshot();
        var destination: [1024]u8 = @splat(0xa5);
        try std.testing.expectError(error.OutputLimitExceeded, decoder.step(frame, &destination));
        try h.untouched(&destination);
        const after = decoder.snapshot();
        try std.testing.expectEqual(before.output_written, after.output_written);
        try std.testing.expectEqual(@as(h.Count, after.last_step_progress.input_read), after.input_received - before.input_received);
        try std.testing.expectEqual(@as(usize, 0), after.last_step_progress.output_written);
        try std.testing.expectEqual(@as(?h.Count, after.input_received), after.error_input_offset);
        try std.testing.expectEqual(@as(?h.Count, after.output_written), after.error_output_offset);
        const diagnostics = decoder.diagnostics();
        try std.testing.expectEqual(after.error_output_offset, diagnostics.error_output_offset);
        try std.testing.expectEqualStrings("raise_output_limit", diagnostics.recoverability_hint_name);
    }
}

test "Zstd stream counters empty completed decoder frames expose input overflow before accepting bytes" {
    const frame = try zstd.encodeRawOrRleFrameWithOptionsAlloc(a, "", .{ .content_checksum = false });
    defer a.free(frame);
    for ([_]core.CompressedInputPolicy{ .block_stream, .prevalidated_frame }) |policy| {
        var decoder = zstd.NativeIncrementalFrameDecoder.initWithOptions(a, .{ .input_policy = policy, .stop_after_first_frame = true });
        defer decoder.deinit();
        const empty = try h.decodeDrive(a, &decoder, frame, 0);
        defer a.free(empty);
        const copies = std.math.maxInt(h.Count) / @as(h.Count, @intCast(frame.len));
        const completed = try h.seedCompletedDecoder(&decoder, copies);
        try decoder.nextStream();
        var output: [8]u8 = @splat(0xa5);
        try std.testing.expectError(error.IntegerOverflow, decoder.step(frame, &output));
        try h.untouched(&output);
        const snapshot = decoder.snapshot();
        try std.testing.expectEqual(completed.input_bytes, snapshot.input_received);
        try std.testing.expectEqual(@as(h.Count, 0), snapshot.output_written);
        try std.testing.expectEqual(@as(usize, 0), snapshot.last_step_progress.input_read);
        try std.testing.expectEqual(@as(?h.Count, completed.input_bytes), snapshot.error_input_offset);
    }
}
