const std = @import("std");
const testing = std.testing;

const max_block_size = 128 * 1024;
const canary: u8 = 0xa5;
const frame_1k = "\x28\xb5\x2f\xfd\x00\x00"; // Non-single-segment, unknown content size.
const frame_2k = "\x28\xb5\x2f\xfd\x00\x08";
const first_plain = "abc";
const first_block = "\x18\x00\x00" ++ first_plain; // Non-final raw block, three bytes.
const multi_prefix = frame_1k ++ first_block;
// An eight-byte compressed payload with one literal and one match sequence.
const sequence_block = "\x45\x00\x00\x09a\x01\x50\x01\x00\x00\x2a";
const sequence_plain = "a" ** 132;

pub fn contracts(comptime Z: type) !void {
    const Decoder = Z.NativeIncrementalFrameDecoder;
    try testing.expectEqual(max_block_size, (Decoder.Options{}).max_block_size);
    for ([_]@FieldType(Decoder.Options, "input_policy"){ .block_stream, .prevalidated_frame }) |policy| {
        const options: Decoder.Options = .{ .input_policy = policy };
        try declaredLengths(Decoder, options);
        try expandedLengths(Decoder, options);
        try upstreamBlock(Decoder, options);
        try formatLimits(Decoder, options);
        try optionsAndSkippables(Decoder, options);
    }
    try borrowedWorkspaces(Decoder);
}

fn expectDecoded(decoder: anytype, input: []const u8, expected: []const u8) !void {
    var output: [first_plain.len + sequence_plain.len]u8 = undefined;
    var read: usize = 0;
    var written: usize = 0;
    while (true) {
        const result = try decoder.step(input[read..@min(read + 2, input.len)], output[written..@min(written + 3, expected.len)]);
        read += result.progress.input_read;
        written += result.progress.output_written;
        if (result.status == .done and read == input.len) break;
        try testing.expect(result.progress.input_read != 0 or result.progress.output_written != 0);
    }
    try decoder.finish();
    try testing.expectEqual(input.len, read);
    try testing.expectEqualSlices(u8, expected, output[0..written]);
}

fn expectPublication(decoder: anytype, output: []const u8, expected: []const u8) !void {
    const failed = decoder.snapshot();
    try testing.expectEqual(expected.len, failed.output_written);
    try testing.expectEqual(failed.input_received, failed.error_input_offset orelse return error.TestUnexpectedResult);
    try testing.expectEqual(failed.output_written, failed.error_output_offset orelse return error.TestUnexpectedResult);
    try testing.expect(!failed.frame_admission_paused);
    try testing.expectEqualSlices(u8, expected, output[0..expected.len]);
    try testing.expect(std.mem.allEqual(u8, output[expected.len..], canary));
}

fn declaredLengths(comptime Decoder: type, base: Decoder.Options) !void {
    const cases = [_]struct { wire: []const u8, plain: []const u8 }{
        .{ .wire = multi_prefix ++ "\x29\x00\x00defgh", .plain = first_plain ++ "defgh" }, // Raw length 5.
        .{ .wire = multi_prefix ++ "\x2b\x00\x00z", .plain = first_plain ++ "zzzzz" }, // RLE length 5, wire payload 1.
        .{ .wire = multi_prefix ++ "\x2d\x00\x00\x18def\x00", .plain = first_plain ++ "def" }, // Compressed wire length 5; three raw literals and no sequences.
    };
    const streaming = base.input_policy == .block_stream;
    const published = if (streaming) first_plain else "";
    var options = base;
    for (cases) |case| {
        options.max_block_size = 5;
        var decoder = Decoder.initWithOptions(testing.allocator, options);
        defer decoder.deinit();
        try expectDecoded(&decoder, case.wire, case.plain);

        options.max_block_size = 4;
        // Check failing-call progress both with an earlier block emitted by
        // that call and with only the last header byte arriving in that call.
        for ([_]usize{ 0, multi_prefix.len + 2 }) |split| {
            try decoder.resetWithOptions(options);
            var output: [9]u8 = @splat(canary);
            const before = if (split != 0) published.len else 0;
            if (split != 0) {
                const partial = try decoder.step(case.wire[0..split], &output);
                try testing.expectEqual(.need_input, partial.status);
                try testing.expectEqual(split, partial.progress.input_read);
                try testing.expectEqual(before, partial.progress.output_written);
            }
            try testing.expectError(error.OutputLimitExceeded, decoder.step(case.wire[split..], output[before..]));
            try expectPublication(&decoder, &output, published);
            const failed = decoder.snapshot();
            try testing.expectEqual(published.len - before, failed.last_step_progress.output_written);
            if (streaming) {
                const header_end = multi_prefix.len + 3;
                try testing.expectEqual(header_end, failed.input_received);
                try testing.expectEqual(header_end - split, failed.last_step_progress.input_read);
            }
        }
    }
}

fn expandedLengths(comptime Decoder: type, base: Decoder.Options) !void {
    const literals_block = "\x25\x00\x00\x45\x08a\x00"; // 132 RLE literals, no sequences.
    const plain = first_plain ++ sequence_plain;
    for ([_][]const u8{ multi_prefix ++ sequence_block, multi_prefix ++ literals_block }) |wire| {
        var options = base;
        options.max_block_size = sequence_plain.len;
        var decoder = Decoder.initWithOptions(testing.allocator, options);
        defer decoder.deinit();
        try expectDecoded(&decoder, wire, plain);

        options.max_block_size -= 1;
        try decoder.resetWithOptions(options);
        var output: [plain.len]u8 = @splat(canary);
        try testing.expectError(error.OutputLimitExceeded, decoder.step(wire, &output));
        const streaming = options.input_policy == .block_stream;
        try expectPublication(&decoder, &output, if (streaming) first_plain else "");
        if (streaming) try testing.expectEqual(wire.len, decoder.snapshot().last_step_progress.input_read);
        try testing.expectError(error.OutputLimitExceeded, decoder.finish());
    }
}

fn upstreamBlock(comptime Decoder: type, base: Decoder.Options) !void {
    // libzstd 1.6.0 compress2 at default level with ZSTD_c_maxBlockSize=2048.
    // Upstream streaming decode rejects at 1024 and accepts at 2048.
    const wire = "\x28\xb5\x2f\xfd\x60\x00\x07\xb5\x00\x00\x78" ++
        "vort-reference-" ++ "\x01\x00\xee\xcb\x3f\xeb";
    const plain = ("vort-reference-" ** 137)[0..2048];
    var options = base;
    options.max_block_size = 1024;
    var decoder = Decoder.initWithOptions(testing.allocator, options);
    defer decoder.deinit();
    var output: [plain.len]u8 = @splat(canary);
    try testing.expectError(error.OutputLimitExceeded, decoder.step(wire, &output));
    try expectPublication(&decoder, &output, "");

    options.max_block_size = 2048;
    try decoder.resetWithOptions(options);
    const step = try decoder.step(wire, &output);
    try testing.expectEqual(.done, step.status);
    try testing.expectEqual(wire.len, step.progress.input_read);
    try testing.expectEqual(plain.len, step.progress.output_written);
    try decoder.finish();
    try testing.expectEqualSlices(u8, plain, &output);
}

fn formatLimits(comptime Decoder: type, base: Decoder.Options) !void {
    var options = base;
    options.max_block_size = 4;
    var decoder = Decoder.initWithOptions(testing.allocator, options);
    defer decoder.deinit();
    for ([_][]const u8{
        frame_1k ++ "\x0b\x20\x00z", // RLE block declares 1025 bytes; frame window is 1024.
        frame_1k ++ "\x25\x00\x00\x15\x40z\x00", // Four-byte compressed block with 1025 RLE literals, no sequences.
    }) |wire| {
        var output: [1025]u8 = @splat(canary);
        try testing.expectError(error.CorruptFrame, decoder.step(wire, &output));
        try expectPublication(&decoder, &output, "");
        decoder.reset();
    }
}

fn optionsAndSkippables(comptime Decoder: type, base: Decoder.Options) !void {
    const metadata = "abcdefghijklmnopqrstuvwx";
    const skip = "\x53\x2a\x4d\x18\x18\x00\x00\x00" ++ metadata;
    const wire = skip ++ frame_1k ++ "\x08\x00\x00a\x09\x00\x00b"; // Two one-byte data blocks.
    var capture: [metadata.len]u8 = @splat(canary);
    var options = base;
    options.max_block_size = 1;
    options.skippable_output = &capture;
    var decoder = Decoder.initWithOptions(testing.allocator, options);
    defer decoder.deinit();
    try expectDecoded(&decoder, wire, "ab");
    try testing.expectEqualSlices(u8, metadata, &capture);
    try testing.expectEqual(@as(usize, 1), decoder.snapshot().skippable_event_count);
    const before = decoder.snapshot();
    for ([_]usize{ 0, max_block_size + 1 }) |cap| {
        var invalid = base;
        invalid.max_block_size = cap;
        try testing.expectError(error.InvalidBlockPlan, decoder.resetWithOptions(invalid));
        try testing.expectEqualDeep(before, decoder.snapshot());

        var unconfigured = Decoder.initWithOptions(testing.allocator, invalid);
        defer unconfigured.deinit();
        var output: [2]u8 = @splat(canary);
        try testing.expectError(error.InvalidBlockPlan, unconfigured.step(wire, &output));
        try expectPublication(&unconfigured, &output, "");
        try testing.expectEqual(@as(usize, 0), unconfigured.snapshot().last_step_progress.input_read);
    }
}

fn borrowedWorkspaces(comptime Decoder: type) !void {
    const cap = sequence_plain.len;
    const Count = @FieldType(Decoder.Options, "max_window_size");
    const unlimited = std.math.maxInt(Count);
    try testing.expectEqual(@as(usize, 18), Decoder.requiredCompressedBlockWorkspaceLenForLimits(unlimited, 1));
    try testing.expectEqual(@as(usize, 18), Decoder.requiredCompressedBlockWorkspaceLenForLimits(0, cap));
    try testing.expectEqual(@as(usize, 64), Decoder.requiredCompressedBlockWorkspaceLenForLimits(64, cap));
    try testing.expectEqual(cap, Decoder.requiredCompressedBlockWorkspaceLenForLimits(1024, cap));
    try testing.expectEqual(max_block_size, Decoder.requiredCompressedBlockWorkspaceLenForLimits(unlimited, max_block_size));

    var compressed: [cap]u8 = undefined;
    var replacement: [cap]u8 = undefined;
    var history: [1024]u8 = undefined;
    var larger_history: [2048]u8 = undefined;
    var failing = testing.FailingAllocator.init(testing.allocator, .{ .fail_index = 0 });
    const options: Decoder.Options = .{
        .max_block_size = cap,
        .max_window_size = history.len,
        .max_working_memory = 0,
        .retry_frame_admission_limits = true,
    };
    var decoder = Decoder.initWithOptions(failing.allocator(), options);
    defer decoder.deinit();
    try testing.expectError(error.OutputTooSmall, decoder.bindCompressedBlockWorkspace(compressed[0 .. cap - 1]));
    try decoder.bindCompressedBlockWorkspace(&compressed);
    try testing.expectEqual(cap, decoder.compressedBlockWorkspaceCapacity());
    try testing.expectError(error.OutputTooSmall, decoder.bindHistoryWorkspace(history[0..cap]));
    try decoder.bindHistoryWorkspace(&history);

    var output: [cap]u8 = @splat(canary);
    try testing.expectError(error.OutputLimitExceeded, decoder.step(frame_2k ++ sequence_block, &output));
    const paused = decoder.snapshot();
    try testing.expect(paused.frame_admission_paused);
    try testing.expectEqual(frame_2k.len, paused.last_step_progress.input_read);
    try testing.expect(std.mem.allEqual(u8, &output, canary));
    // Increasing the window still requires sufficient history, but not a
    // larger compressed workspace when the block cap is already smaller.
    const limits: Decoder.FrameAdmissionLimits = .{ .max_window_size = larger_history.len };
    try testing.expectError(error.OutputTooSmall, decoder.retryFrameAdmission(limits));
    try testing.expectEqualDeep(paused, decoder.snapshot());
    try decoder.retryFrameAdmissionWithWorkspaces(limits, &replacement, &larger_history);
    try testing.expectEqual(cap, decoder.compressedBlockWorkspaceCapacity());
    try testing.expectEqual(larger_history.len, decoder.historyWorkspaceCapacity());
    try expectDecoded(&decoder, sequence_block, sequence_plain);

    const done = decoder.snapshot();
    var next = options;
    next.max_block_size = cap + 1;
    try testing.expectError(error.OutputTooSmall, decoder.resetWithOptions(next));
    try testing.expectEqualDeep(done, decoder.snapshot());
    try decoder.resetWithOptions(options);
    try expectDecoded(&decoder, frame_1k ++ sequence_block, sequence_plain);
    try testing.expectEqual(larger_history.len, decoder.historyWorkspaceCapacity());
    try testing.expectEqual(@as(usize, 0), decoder.peakWorkingMemoryBytes());
    try testing.expect(!failing.has_induced_failure);
}
