const std = @import("std");
const core = @import("../../core.zig");
const Count = core.StreamCount;
const testing = std.testing;
const a = testing.allocator;

const magic = "\x28\xb5\x2f\xfd";
const payload = "abc";
const data_header = magic ++ "\x20\x03";
const raw_block = "\x19\x00\x00" ++ payload;
const data = data_header ++ raw_block;
const empty_data = magic ++ "\x20\x00\x01\x00\x00";
const empty_skip = "\x58\x2a\x4d\x18\x00\x00\x00\x00";
const skip = "\x53\x2a\x4d\x18\x01\x00\x00\x00m";
const next_skip_header = "\x59\x2a\x4d\x18\x02\x00\x00\x00";
const dict_header = magic ++ "\x21\x07\x03";
const invalid_header = magic ++ "\x28\x03"; // Reserved descriptor bit.
const mixed = data ++ empty_data ++ empty_skip;
const canary: u8 = 0xa5;

pub fn contracts(comptime zstd: type) !void {
    try testing.expectEqual(std.math.maxInt(Count), (zstd.FrameDecodeOptions{}).max_frames);
    try testing.expectEqual(std.math.maxInt(Count), (zstd.NativeIncrementalFrameDecoder.Options{}).max_frames);
    try contiguous(zstd);
    try fragmentedAndReusable(zstd);
    for ([_]core.CompressedInputPolicy{ .block_stream, .prevalidated_frame }) |policy| {
        try incrementalCommit(zstd, policy);
        try incrementalHeaders(zstd, policy);
        try incrementalResume(zstd, policy);
    }
}

fn contiguous(comptime Z: type) !void {
    const capped: Z.FrameDecodeOptions = .{ .max_frames = 2 };
    const exact: Z.FrameDecodeOptions = .{ .max_frames = 3 };
    var output: [payload.len + 1]u8 = @splat(canary);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(a);
    try out.appendSlice(a, "seed");

    try testing.expectError(error.OutputLimitExceeded, Z.decodedFrameSizeWithOptions(mixed, capped));
    try testing.expectError(error.OutputLimitExceeded, Z.decodeFrameAllocWithOptions(a, mixed, capped));
    try testing.expectError(error.OutputLimitExceeded, Z.decodeFrameIntoWithOptions(a, mixed, &output, capped));
    try testing.expectError(error.OutputLimitExceeded, Z.decodeFrameAppendWithOptions(a, &out, mixed, capped));
    try testing.expect(std.mem.allEqual(u8, &output, canary));
    try testing.expectEqualStrings("seed", out.items);

    try testing.expectEqual(@as(Count, payload.len), try Z.decodedFrameSizeWithOptions(mixed, exact));
    const owned = try Z.decodeFrameAllocWithOptions(a, mixed, exact);
    defer a.free(owned);
    try testing.expectEqualStrings(payload, owned);
    try testing.expectEqual(payload.len, try Z.decodeFrameIntoWithOptions(a, mixed, &output, exact));
    try testing.expectEqualStrings(payload, output[0..payload.len]);
    try testing.expectEqual(canary, output[payload.len]);
    try testing.expectEqual(payload.len, try Z.decodeFrameAppendWithOptions(a, &out, mixed, exact));
    try testing.expectEqualStrings("seed" ++ payload, out.items);

    for ([_][]const u8{ empty_data, empty_skip }) |frame| {
        try testing.expectError(error.OutputLimitExceeded, Z.decodedFrameSizeWithOptions(frame, .{ .max_frames = 0 }));
        try testing.expectEqual(@as(Count, 0), try Z.decodedFrameSizeWithOptions(frame, .{ .max_frames = 1 }));
    }
    const magicless = data[magic.len..] ++ empty_data[magic.len..];
    try testing.expectEqual(@as(Count, payload.len), try Z.decodedFrameSizeWithOptions(magicless, .{ .format = .magicless, .max_frames = 2 }));
    try testing.expectError(error.OutputLimitExceeded, Z.decodedFrameSizeWithOptions(magicless, .{ .format = .magicless, .max_frames = 1 }));
    try testing.expectError(error.CorruptFrame, Z.decodedFrameSizeWithOptions(empty_skip, .{ .format = .magicless, .max_frames = 0 }));
    try testing.expectError(error.InvalidMagic, Z.decodedFrameSizeWithOptions(mixed ++ "junk", exact));
    try testing.expectError(error.TruncatedFrame, Z.decodedFrameSizeWithOptions(mixed ++ next_skip_header, .{ .max_frames = 4 }));
    try testing.expectError(error.OutputLimitExceeded, Z.decodedFrameSizeWithOptions(mixed ++ next_skip_header, exact));
    try testing.expectError(error.TruncatedFrame, Z.decodedFrameSizeWithOptions(mixed ++ data_header, .{ .max_frames = 4 }));
    try testing.expectError(error.OutputLimitExceeded, Z.decodedFrameSizeWithOptions(mixed ++ data_header, exact));

    for ([_]Z.FrameFormat{ .standard, .magicless }) |format| {
        const start: usize = if (format == .standard) 0 else magic.len;
        const none: Z.FrameDecodeOptions = .{ .format = format, .max_frames = 0 };
        try testing.expectError(error.TruncatedFrame, Z.decodedFrameSizeWithOptions(dict_header[start .. dict_header.len - 1], none));
        try testing.expectError(error.CorruptFrame, Z.decodedFrameSizeWithOptions(invalid_header[start..], none));
        try testing.expectError(error.OutputLimitExceeded, Z.decodedFrameSizeWithOptions(dict_header[start..], none));
        try testing.expectError(error.NeedDictionary, Z.decodedFrameSizeWithOptions(dict_header[start..], .{ .format = format, .max_frames = 1 }));
    }
}

fn byteChunks(comptime bytes: []const u8) [2 * bytes.len][]const u8 {
    var chunks: [2 * bytes.len][]const u8 = @splat("");
    for (0..bytes.len) |i| chunks[2 * i + 1] = bytes[i..][0..1];
    return chunks;
}

fn fragmentedAndReusable(comptime Z: type) !void {
    // Start with three valid members, then split the refused skippable header
    // into individual bytes. Its missing body must not mask the count limit.
    const wire = mixed ++ next_skip_header;
    const chunks = byteChunks(wire);
    const allowed = chunks[0 .. 2 * mixed.len];
    const exact: Z.FrameDecodeOptions = .{ .max_frames = 3 };
    var scratch: [wire.len]u8 = @splat(canary);
    var output: [payload.len]u8 = @splat(canary);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(a);
    try out.appendSlice(a, "seed");
    var decoder = Z.NativeFrameDecoder.initWithOptions(a, exact);
    defer decoder.deinit();

    for ([_][]u8{ scratch[0..1], &scratch }) |buf| {
        try testing.expectError(error.TruncatedFrame, Z.decodedFrameChunksSizeWithOptions(chunks[0 .. chunks.len - 2], buf, exact));
        try testing.expectError(error.OutputLimitExceeded, Z.decodedFrameChunksSizeWithOptions(&chunks, buf, exact));
        try testing.expectError(error.OutputLimitExceeded, Z.decodeFrameChunksAllocWithOptions(a, &chunks, buf, exact));
        try testing.expectError(error.OutputLimitExceeded, Z.decodeFrameChunksIntoWithOptions(a, &chunks, buf, &output, exact));
        try testing.expectError(error.OutputLimitExceeded, Z.decodeFrameChunksAppendWithOptions(a, &out, &chunks, buf, exact));
        try testing.expectError(error.OutputLimitExceeded, decoder.decodedChunksSize(&chunks, buf));
        try testing.expectError(error.OutputLimitExceeded, decoder.decodeChunksIntoSlice(&chunks, buf, &output));
    }
    try testing.expectError(error.OutputLimitExceeded, decoder.decodedSize(wire));
    try testing.expectError(error.OutputLimitExceeded, decoder.decodeAlloc(wire));
    try testing.expectError(error.OutputLimitExceeded, decoder.decodeIntoSlice(wire, &output));
    try testing.expectError(error.OutputLimitExceeded, decoder.decodeAppend(&out, wire));
    try testing.expectError(error.OutputLimitExceeded, decoder.decodeScratch(wire));
    try testing.expect(std.mem.allEqual(u8, &scratch, canary));
    try testing.expect(std.mem.allEqual(u8, &output, canary));
    try testing.expectEqualStrings("seed", out.items);
    try testing.expectEqual(payload.len, try decoder.decodeChunksIntoSlice(allowed, &scratch, &output));
    try testing.expectEqualStrings(payload, &output);
    try testing.expectEqualStrings(payload, try decoder.decodeScratch(mixed));
}

fn incrementalCommit(comptime Z: type, policy: core.CompressedInputPolicy) !void {
    const Decoder = Z.NativeIncrementalFrameDecoder;
    const Observed = struct {
        starts: usize = 0,
        bytes: usize = 0,

        fn observe(context: ?*anyopaque, event: Decoder.SkippableObservation) void {
            const self: *@This() = @ptrCast(@alignCast(context.?));
            switch (event) {
                .start => self.starts += 1,
                .chunk => |chunk| self.bytes += chunk.bytes.len,
            }
        }
    };
    var observed: Observed = .{};
    var capture: [3]u8 = @splat(canary);
    const unused: Decoder.SkippableEvent = .{ .id = 0, .payload_len = 99 };
    var events: [3]Decoder.SkippableEvent = @splat(unused);
    var decoder = Decoder.initWithOptions(a, .{
        .input_policy = policy,
        .max_frames = 4,
        .skippable_output = &capture,
        .skippable_events = &events,
        .skippable_observer = .{ .context = &observed, .on_event = Observed.observe },
    });
    defer decoder.deinit();

    // Earlier output and metadata must be committed even within a failing step.
    var output: [payload.len + 1]u8 = @splat(canary);
    try testing.expectError(error.OutputLimitExceeded, decoder.step(skip ++ mixed ++ next_skip_header ++ "no", &output));
    const snapshot = decoder.snapshot();
    try testing.expectEqual(@as(Count, 2), snapshot.data_frame_count);
    try testing.expectEqual(@as(Count, 2), snapshot.skippable_event_count);
    try testing.expectEqual(@as(Count, payload.len), snapshot.output_written);
    try testing.expectEqual(payload.len, snapshot.last_step_progress.output_written);
    try testing.expectEqualStrings(payload, output[0..payload.len]);
    try testing.expectEqual(canary, output[payload.len]);
    try testing.expectEqualSlices(u8, &.{ 'm', canary, canary }, &capture);
    try testing.expectEqualDeep(Decoder.SkippableEvent{ .id = 3, .payload_len = 1 }, events[0]);
    try testing.expectEqualDeep(Decoder.SkippableEvent{ .id = 8, .payload_len = 0 }, events[1]);
    try testing.expectEqualDeep(unused, events[2]);
    try testing.expectEqual(@as(usize, 2), observed.starts);
    try testing.expectEqual(@as(usize, 1), observed.bytes);
}

fn incrementalHeaders(comptime Z: type, policy: core.CompressedInputPolicy) !void {
    const Decoder = Z.NativeIncrementalFrameDecoder;
    for ([_]Z.FrameFormat{ .standard, .magicless }) |format| {
        const start: usize = if (format == .standard) 0 else magic.len;
        const capped: Decoder.Options = .{ .input_policy = policy, .format = format, .max_frames = 0 };
        var decoder = Decoder.initWithOptions(a, capped);
        defer decoder.deinit();
        var output: [payload.len]u8 = @splat(canary);
        const header = dict_header[start..];
        const split = header.len - 1;

        try testing.expectEqual(core.StepResult.Status.need_input, (try decoder.step(header[0..split], &output)).status);
        try testing.expectError(error.TruncatedFrame, decoder.finish());
        decoder.reset();
        try testing.expectEqual(core.StepResult.Status.need_input, (try decoder.step(header[0..split], &output)).status);
        try testing.expectError(error.OutputLimitExceeded, decoder.step(header[split..], &output));
        try testing.expectEqual(@as(?u32, null), decoder.requiredDictionaryId());
        try testing.expect(std.mem.allEqual(u8, &output, canary));
        decoder.reset();
        try testing.expectError(error.CorruptFrame, decoder.step(invalid_header[start..], &output));

        var exact = capped;
        exact.max_frames = 1;
        try decoder.resetWithOptions(exact);
        try testing.expectError(error.NeedDictionary, decoder.step(header, &output));
        try testing.expectEqual(@as(?u32, 7), decoder.requiredDictionaryId());
        try decoder.provideDictionary(Z.NativeDictionary.init(7, "dictionary"));
        try testing.expectEqual(core.StepResult.Status.done, (try decoder.step(raw_block, &output)).status);
        try testing.expectEqualStrings(payload, &output);
        try decoder.finish();
    }

    var decoder = Decoder.initWithOptions(a, .{ .input_policy = policy, .max_frames = 0 });
    defer decoder.deinit();
    const wire = next_skip_header ++ "no";
    const split = next_skip_header.len - 1;
    try testing.expectEqual(core.StepResult.Status.need_input, (try decoder.step(wire[0..split], &.{})).status);
    try testing.expectError(error.OutputLimitExceeded, decoder.step(wire[split..], &.{}));
    const snapshot = decoder.snapshot();
    try testing.expectEqual(@as(Count, next_skip_header.len), snapshot.input_received);
    try testing.expectEqual(@as(usize, 1), snapshot.last_step_progress.input_read);
    try testing.expectEqual(@as(Count, 0), snapshot.skippable_event_count);
    try testing.expectEqual(@as(Count, 0), snapshot.skippable_total);
}

fn incrementalResume(comptime Z: type, policy: core.CompressedInputPolicy) !void {
    const Decoder = Z.NativeIncrementalFrameDecoder;
    var decoder = Decoder.initWithOptions(a, .{ .input_policy = policy, .max_frames = 3, .stop_after_first_frame = true });
    defer decoder.deinit();
    var output: [payload.len]u8 = undefined;

    try testing.expectEqual(core.StepResult.Status.done, (try decoder.step(empty_skip ++ data, &output)).status);
    try testing.expectEqualStrings(payload, &output);
    try decoder.nextStream();
    try testing.expectEqual(core.StepResult.Status.done, (try decoder.step(empty_data, &.{})).status);
    try decoder.nextStream();
    try testing.expectError(error.OutputLimitExceeded, decoder.step(data_header, &output));
    decoder.reset();
    try testing.expectEqual(core.StepResult.Status.done, (try decoder.step(empty_skip ++ data, &output)).status);
    try testing.expectEqual(@as(Count, 1), decoder.snapshot().data_frame_count);
    try testing.expectEqual(@as(Count, 1), decoder.snapshot().skippable_event_count);
}
