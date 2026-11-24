const std = @import("std");
const core = @import("../../core.zig");
const zstd = @import("../../zstd.zig");

const Decoder = zstd.NativeIncrementalFrameDecoder;
const Count = core.StreamCount;
const testing = std.testing;
const policies = [_]core.CompressedInputPolicy{ .block_stream, .prevalidated_frame };
const canary: u8 = 0xa5;

const magic = "\x28\xb5\x2f\xfd";
const first_payload = "first";
const first_frame = magic ++ "\x20\x05\x29\x00\x00" ++ first_payload;
const metadata_payload = "meta";
const metadata_frame = "\x53\x2a\x4d\x18\x04\x00\x00\x00" ++ metadata_payload;
const last_payload = "second";
const last_header = magic ++ "\x20\x06";
const last_block = "\x31\x00\x00" ++ last_payload;
const last_frame = last_header ++ last_block;

fn expectPaused(decoder: *const Decoder, received: Count, written: Count, delta: core.Progress) !void {
    const snap = decoder.snapshot();
    try testing.expect(snap.frame_admission_paused);
    try testing.expectEqual(Decoder.Phase.frame, snap.phase);
    try testing.expectEqual(received, snap.input_received);
    try testing.expectEqual(written, snap.output_written);
    try testing.expectEqual(@as(?Count, received), snap.error_input_offset);
    try testing.expectEqual(@as(?Count, written), snap.error_output_offset);
    try testing.expectEqual(delta, snap.last_step_progress);
}

fn expectBlocked(decoder: *Decoder, suffix: []const u8, paused: bool) !void {
    const before = decoder.snapshot();
    var guarded: [16]u8 = @splat(canary);
    try testing.expectError(error.OutputLimitExceeded, decoder.finish());
    for ([_][]const u8{ suffix, &.{} }) |input| {
        try testing.expectError(error.OutputLimitExceeded, decoder.step(input, &guarded));
        const after = decoder.snapshot();
        try testing.expectEqual(paused, after.frame_admission_paused);
        try testing.expectEqual(before.input_received, after.input_received);
        try testing.expectEqual(before.output_written, after.output_written);
        try testing.expectEqual(before.error_input_offset, after.error_input_offset);
        try testing.expectEqual(before.error_output_offset, after.error_output_offset);
        try testing.expectEqual(core.Progress{}, after.last_step_progress);
        try testing.expect(std.mem.allEqual(u8, &guarded, canary));
    }
}

fn decodeSuffix(decoder: *Decoder, input: []const u8, output: []u8) !void {
    var read: usize = 0;
    var written: usize = 0;
    while (true) {
        const result = try decoder.step(input[read..@min(read + 3, input.len)], output[written..@min(written + 2, output.len)]);
        read += result.progress.input_read;
        written += result.progress.output_written;
        if (result.status == .done and read == input.len) break;
        try testing.expect(result.progress.input_read != 0 or result.progress.output_written != 0);
    }
    try decoder.finish();
    try testing.expectEqual(input.len, read);
    try testing.expectEqual(output.len, written);
}

test "Zstd frame admission retry split window header preserves prefix and workspace transaction" {
    const window = 2048;
    // Non-single-segment frame, 2 KiB window and one-byte dictionary ID 7.
    const header = magic ++ "\x01\x08\x07";
    const frame = header ++ last_block;
    const prefix_bytes = "borrowed prefix";
    const prefix = zstd.NativeDictionary.init(7, prefix_bytes);
    for (policies) |policy| {
        var history: [window + prefix_bytes.len]u8 = @splat(canary);
        var decoder = Decoder.initWithOptions(testing.allocator, .{
            .input_policy = policy,
            .max_window_size = 1024,
            .retry_frame_admission_limits = true,
        });
        defer decoder.deinit();
        try testing.expectError(error.InvalidStreamState, decoder.retryFrameAdmission(.{}));
        try decoder.setPrefixWithDictionary(prefix);
        try decoder.bindHistoryWorkspace(&history);
        var output: [last_payload.len + 1]u8 = @splat(canary);

        const split = header.len - 1;
        const partial = try decoder.step(frame[0..split], &output);
        try testing.expectEqual(core.StepResult.Status.need_input, partial.status);
        try testing.expectEqual(core.Progress{ .input_read = split }, partial.progress);
        try testing.expect(!decoder.snapshot().frame_admission_paused);
        try testing.expectError(error.OutputLimitExceeded, decoder.step(frame[split..], &output));
        try expectPaused(&decoder, header.len, 0, .{ .input_read = 1 });
        try testing.expectEqual(@as(?u32, null), decoder.requiredDictionaryId());
        try testing.expect(std.mem.allEqual(u8, &output, canary));

        const paused = decoder.snapshot();
        const borrowed = decoder.prefixSnapshot();
        try testing.expect(borrowed.phase != .none);
        try testing.expectError(error.OutputTooSmall, decoder.retryFrameAdmission(.{
            .max_window_size = window + 1,
            .max_frames = 1,
        }));
        try testing.expectEqualDeep(paused, decoder.snapshot());
        try testing.expectEqualDeep(borrowed, decoder.prefixSnapshot());
        try testing.expectEqual(@as(Count, 1024), decoder.options.max_window_size);
        try testing.expectEqual((Decoder.Options{}).max_frames, decoder.options.max_frames);
        try testing.expect(std.mem.allEqual(u8, &history, canary));
        try expectBlocked(&decoder, frame[header.len..], true);

        try decoder.retryFrameAdmission(.{ .max_window_size = window });
        const resumed = decoder.snapshot();
        try testing.expect(!resumed.frame_admission_paused);
        try testing.expectEqual(paused.input_received, resumed.input_received);
        try testing.expectEqual(paused.output_written, resumed.output_written);
        try decodeSuffix(&decoder, frame[header.len..], output[0..last_payload.len]);
        try testing.expectEqualSlices(u8, last_payload, output[0..last_payload.len]);
        try testing.expectEqual(canary, output[last_payload.len]);
        try testing.expectEqual(@as(Count, frame.len), decoder.snapshot().input_received);
        try testing.expectEqual(@as(Count, 1), decoder.snapshot().data_frame_count);
        try testing.expectEqual(zstd.PrefixPhase.none, decoder.prefixSnapshot().phase);
    }
}

test "Zstd frame admission retry can migrate retained input to a larger compressed workspace" {
    const window = 2048;
    const header = magic ++ "\x01\x08\x07";
    const frame = header ++ last_block;
    const prefix_bytes = "borrowed prefix";
    const prefix = zstd.NativeDictionary.init(7, prefix_bytes);
    const Storage = enum { owned, separate, in_place, shifted };
    for (std.enums.values(Storage)) |storage| {
        var small: [1024]u8 = @splat(canary);
        var larger: [window + 3]u8 = @splat(canary);
        var history: [window + prefix_bytes.len]u8 = @splat(canary);
        var decoder = Decoder.initWithOptions(testing.allocator, .{
            .max_window_size = small.len,
            .max_working_memory = if (storage == .owned) std.math.maxInt(usize) else 0,
            .retry_frame_admission_limits = true,
        });
        defer decoder.deinit();
        try testing.expectError(error.InvalidStreamState, decoder.retryFrameAdmissionWithCompressedBlockWorkspace(.{ .max_window_size = window }, &larger));
        try decoder.setPrefixWithDictionary(prefix);
        try decoder.bindHistoryWorkspace(&history);
        switch (storage) {
            .owned => {},
            .separate => try decoder.bindCompressedBlockWorkspace(&small),
            .in_place, .shifted => try decoder.bindCompressedBlockWorkspace(larger[0..small.len]),
        }
        var output: [last_payload.len]u8 = @splat(canary);
        try testing.expectError(error.OutputLimitExceeded, decoder.step(frame, &output));
        try expectPaused(&decoder, header.len, 0, .{ .input_read = header.len });
        const paused = decoder.snapshot();
        const borrowed = decoder.prefixSnapshot();
        const saved_small = small;
        const saved_larger = larger;
        const offset: usize = if (storage == .shifted) 1 else 0;
        if (storage != .owned)
            try testing.expectError(error.OutputTooSmall, decoder.retryFrameAdmission(.{ .max_window_size = window }));
        try testing.expectError(error.OutputTooSmall, decoder.retryFrameAdmissionWithCompressedBlockWorkspace(.{ .max_window_size = window }, larger[0 .. window - 1]));
        try testing.expectError(error.InvalidBlockPlan, decoder.retryFrameAdmissionWithCompressedBlockWorkspace(.{ .max_window_size = window }, history[0..window]));
        try testing.expectError(error.InvalidBlockPlan, decoder.retryFrameAdmissionWithCompressedBlockWorkspace(.{ .max_window_size = window }, std.mem.asBytes(&decoder)[0..window]));
        // The compressed buffer fits this change, but the history ring does not.
        try testing.expectError(error.OutputTooSmall, decoder.retryFrameAdmissionWithCompressedBlockWorkspace(.{ .max_window_size = window + 1 }, larger[offset..]));
        try testing.expectEqualDeep(paused, decoder.snapshot());
        try testing.expectEqualDeep(borrowed, decoder.prefixSnapshot());
        try testing.expectEqual(@as(Count, small.len), decoder.options.max_window_size);
        try testing.expectEqualSlices(u8, &saved_small, &small);
        try testing.expectEqualSlices(u8, &saved_larger, &larger);
        try testing.expect(std.mem.allEqual(u8, &history, canary));

        try decoder.retryFrameAdmissionWithCompressedBlockWorkspace(.{ .max_window_size = window }, larger[offset..]);
        try testing.expect(!decoder.snapshot().frame_admission_paused);
        try testing.expectEqualDeep(borrowed, decoder.prefixSnapshot());
        try testing.expectEqual(paused.last_step_progress, decoder.snapshot().last_step_progress);
        try testing.expectEqual(paused.input_received, decoder.snapshot().input_received);
        try testing.expectEqual(@as(Count, window), decoder.options.max_window_size);
        try testing.expectEqual(window, decoder.compressedBlockWorkspaceCapacity());
        try testing.expectEqual(@as(usize, 0), decoder.workingMemoryBytes());
        try testing.expectEqualSlices(u8, &saved_small, &small);
        try testing.expectEqualSlices(u8, saved_larger[0..offset], larger[0..offset]);
        try testing.expectEqualSlices(u8, header, larger[offset..][0..header.len]);
        try testing.expectEqualSlices(u8, saved_larger[offset + header.len ..], larger[offset + header.len ..]);
        try decodeSuffix(&decoder, frame[header.len..], &output);
        try testing.expectEqualSlices(u8, last_payload, &output);
        try testing.expectEqual(@as(Count, frame.len), decoder.snapshot().input_received);
        try testing.expectEqual(@as(usize, 0), decoder.workingMemoryBytes());
    }
}

test "Zstd frame admission retry replaces both workspaces without replaying accepted input" {
    const window = 2048;
    const header = magic ++ "\x01\x08\x07";
    const frame = header ++ last_block;
    const prefix_bytes = "borrowed prefix";
    const prefix = zstd.NativeDictionary.init(7, prefix_bytes);
    const history_len = window + prefix_bytes.len;
    for ([_]bool{ false, true }) |swap| {
        var left: [history_len + 1]u8 = @splat(canary);
        var right: [history_len + 1]u8 = @splat(canary);
        var decoder = Decoder.initWithOptions(testing.allocator, .{
            .max_window_size = 1024,
            .max_working_memory = 0,
            .stop_after_first_frame = true,
            .retry_frame_admission_limits = true,
        });
        defer decoder.deinit();
        try decoder.bindCompressedBlockWorkspace(left[0..1024]);
        try decoder.bindHistoryWorkspace(right[0 .. 1024 + prefix_bytes.len]);
        var prior_output: [first_payload.len]u8 = undefined;
        try decodeSuffix(&decoder, first_frame, &prior_output);
        try testing.expectEqualSlices(u8, first_payload, &prior_output);
        try decoder.setPrefixWithDictionary(prefix);
        try decoder.nextStream();

        var output: [last_payload.len]u8 = @splat(canary);
        try testing.expectError(error.OutputLimitExceeded, decoder.step(frame, &output));
        try expectPaused(&decoder, first_frame.len + header.len, first_payload.len, .{ .input_read = header.len });
        const paused = decoder.snapshot();
        const borrowed = decoder.prefixSnapshot();
        const saved_left = left;
        const saved_right = right;
        const compressed = if (swap) right[1..] else left[1..];
        const history = if (swap) left[1..] else right[1..];
        const limits: Decoder.FrameAdmissionLimits = .{ .max_window_size = window };
        if (!swap)
            try testing.expectError(error.OutputTooSmall, decoder.retryFrameAdmissionWithCompressedBlockWorkspace(limits, compressed));
        try testing.expectError(error.OutputTooSmall, decoder.retryFrameAdmissionWithWorkspaces(limits, compressed, history[0 .. history_len - 1]));
        try testing.expectError(error.InvalidBlockPlan, decoder.retryFrameAdmissionWithWorkspaces(limits, compressed, compressed));
        try testing.expectError(error.InvalidBlockPlan, decoder.retryFrameAdmissionWithWorkspaces(limits, compressed, std.mem.asBytes(&decoder)[0..history_len]));
        try testing.expectEqualDeep(paused, decoder.snapshot());
        try testing.expectEqualDeep(borrowed, decoder.prefixSnapshot());
        try testing.expectEqual(@as(Count, 1024), decoder.options.max_window_size);
        try testing.expectEqualSlices(u8, &saved_left, &left);
        try testing.expectEqualSlices(u8, &saved_right, &right);

        try decoder.retryFrameAdmissionWithWorkspaces(limits, compressed, history);
        const resumed = decoder.snapshot();
        try testing.expect(!resumed.frame_admission_paused);
        try testing.expectEqualDeep(borrowed, decoder.prefixSnapshot());
        try testing.expectEqual(paused.input_received, resumed.input_received);
        try testing.expectEqual(paused.output_written, resumed.output_written);
        try testing.expectEqual(paused.last_step_progress, resumed.last_step_progress);
        try testing.expectEqual(window, decoder.compressedBlockWorkspaceCapacity());
        try testing.expectEqual(history_len, decoder.historyWorkspaceCapacity());
        const expected_compressed = if (swap) &saved_right else &saved_left;
        const expected_history = if (swap) &saved_left else &saved_right;
        try testing.expectEqual(expected_compressed[0], if (swap) right[0] else left[0]);
        try testing.expectEqualSlices(u8, header, compressed[0..header.len]);
        try testing.expectEqualSlices(u8, expected_compressed[1 + header.len ..], compressed[header.len..]);
        try testing.expectEqualSlices(u8, expected_history[1..], history);
        try testing.expect(std.mem.allEqual(u8, &output, canary));
        try decodeSuffix(&decoder, frame[header.len..], &output);
        try testing.expectEqualSlices(u8, last_payload, &output);
        try testing.expectEqualSlices(u8, first_payload, &prior_output);
        try testing.expectEqual(@as(Count, first_frame.len + frame.len), decoder.snapshot().input_received);
        try testing.expectEqual(@as(Count, 2), decoder.snapshot().data_frame_count);
        try testing.expectEqual(@as(usize, 0), decoder.peakWorkingMemoryBytes());
    }
}

test "Zstd frame admission retry cannot replace stable output with history workspace implicitly" {
    const header = magic ++ "\x00\x08";
    var decoder = Decoder.initWithOptions(testing.allocator, .{
        .max_window_size = 1024,
        .retry_frame_admission_limits = true,
    });
    defer decoder.deinit();
    var output: [last_payload.len]u8 = @splat(canary);
    var compressed: [2048]u8 = @splat(canary);
    var history: [2048]u8 = @splat(canary);
    try decoder.bindStableOutput(&output);
    try testing.expectError(error.OutputLimitExceeded, decoder.stepStable(header ++ last_block));
    const paused = decoder.snapshot();
    try testing.expectError(error.InvalidBlockPlan, decoder.retryFrameAdmissionWithWorkspaces(.{ .max_window_size = 2048 }, &compressed, &history));
    try testing.expectEqualDeep(paused, decoder.snapshot());
    try testing.expectEqual(@as(Count, 1024), decoder.options.max_window_size);
    try testing.expectEqual(@as(usize, 0), decoder.stableOutput().len);
    try testing.expect(std.mem.allEqual(u8, &output, canary));
    try testing.expect(std.mem.allEqual(u8, &compressed, canary));
    try testing.expect(std.mem.allEqual(u8, &history, canary));
}

test "Zstd frame admission retry cannot bind a block workspace to prevalidated input" {
    const header = magic ++ "\x00\x08"; // Non-single-segment, 2 KiB window.
    const frame = header ++ last_block;
    var decoder = Decoder.initWithOptions(testing.allocator, .{
        .input_policy = .prevalidated_frame,
        .max_window_size = 1024,
        .retry_frame_admission_limits = true,
    });
    defer decoder.deinit();
    var workspace: [2048]u8 = @splat(canary);
    var output: [last_payload.len]u8 = @splat(canary);
    try testing.expectError(error.OutputLimitExceeded, decoder.step(frame, &output));
    const paused = decoder.snapshot();
    try testing.expectError(error.InvalidBlockPlan, decoder.retryFrameAdmissionWithCompressedBlockWorkspace(.{ .max_window_size = 2048 }, &workspace));
    try testing.expectEqualDeep(paused, decoder.snapshot());
    try testing.expectEqual(@as(Count, 1024), decoder.options.max_window_size);
    try testing.expect(std.mem.allEqual(u8, &workspace, canary));
    try decoder.retryFrameAdmission(.{ .max_window_size = 2048 });
    try decodeSuffix(&decoder, frame[header.len..], &output);
    try testing.expectEqualSlices(u8, last_payload, &output);
}

test "Zstd frame admission retry known sizes and combined frame quota preserve the accepted prefix" {
    const prefix = first_frame ++ metadata_frame;
    const wire = prefix ++ last_frame;
    const plaintext = first_payload ++ last_payload;
    const Cap = enum { cumulative, per_frame, frame_count };
    for (policies) |policy| {
        // Prevalidated input can retain the following frame as lookahead
        // from the first frame. It must not ask for those bytes again.
        const accepted = if (policy == .prevalidated_frame) wire.len else prefix.len + last_header.len;
        for ([_]Cap{ .cumulative, .per_frame, .frame_count }) |cap| {
            var capture: [metadata_payload.len]u8 = @splat(canary);
            var options: Decoder.Options = .{
                .input_policy = policy,
                .retry_frame_admission_limits = true,
                .skippable_output = &capture,
            };
            switch (cap) {
                .cumulative => options.max_output_len = plaintext.len - 1,
                .per_frame => options.max_decoded_buffer_len = last_payload.len - 1,
                .frame_count => options.max_frames = 2,
            }
            var decoder = Decoder.initWithOptions(testing.allocator, options);
            defer decoder.deinit();
            var output: [plaintext.len + 1]u8 = @splat(canary);
            var read: usize = 0;
            var written: usize = 0;
            while (true) {
                const result = decoder.step(wire[read..], output[written..]) catch |err| {
                    try testing.expectEqual(error.OutputLimitExceeded, err);
                    break;
                };
                read += result.progress.input_read;
                written += result.progress.output_written;
                try testing.expect(result.progress.input_read != 0 or result.progress.output_written != 0);
            }
            try testing.expect(read <= accepted);
            try testing.expect(written <= first_payload.len);
            try expectPaused(&decoder, accepted, first_payload.len, .{
                .input_read = accepted - read,
                .output_written = first_payload.len - written,
            });
            const pause = decoder.snapshot();
            read += pause.last_step_progress.input_read;
            written += pause.last_step_progress.output_written;
            try testing.expectEqual(@as(Count, 1), pause.data_frame_count);
            try testing.expectEqual(@as(Count, 1), pause.skippable_event_count);
            try testing.expectEqualSlices(u8, first_payload, output[0..written]);
            try testing.expectEqualSlices(u8, metadata_payload, &capture);
            try testing.expect(std.mem.allEqual(u8, output[written..], canary));
            try expectBlocked(&decoder, wire[read..], true);

            switch (cap) {
                .cumulative => try decoder.retryFrameAdmission(.{ .max_output_len = plaintext.len }),
                .per_frame => try decoder.retryFrameAdmission(.{ .max_decoded_buffer_len = last_payload.len }),
                .frame_count => try decoder.retryFrameAdmission(.{ .max_frames = 3 }),
            }
            try decodeSuffix(&decoder, wire[read..], output[written..plaintext.len]);
            const done = decoder.snapshot();
            try testing.expect(!done.frame_admission_paused);
            try testing.expectEqual(@as(Count, wire.len), done.input_received);
            try testing.expectEqual(@as(Count, plaintext.len), done.output_written);
            try testing.expectEqual(@as(Count, 2), done.data_frame_count);
            try testing.expectEqual(@as(Count, 1), done.skippable_event_count);
            try testing.expectEqualSlices(u8, plaintext, output[0..plaintext.len]);
            try testing.expectEqual(canary, output[plaintext.len]);
        }
    }
}

test "Zstd frame admission retry preserves a supplied dictionary across size refusal" {
    const header = magic ++ "\x21\x07\x06";
    const frame = header ++ last_block;
    for (policies) |policy| {
        var decoder = Decoder.initWithOptions(testing.allocator, .{
            .input_policy = policy,
            .max_window_size = last_payload.len - 1,
            .max_output_len = last_payload.len - 1,
            .retry_frame_admission_limits = true,
        });
        defer decoder.deinit();
        var output: [last_payload.len]u8 = @splat(canary);
        try testing.expectError(error.OutputLimitExceeded, decoder.step(frame, &output));
        try expectPaused(&decoder, header.len, 0, .{ .input_read = header.len });
        try decoder.retryFrameAdmission(.{ .max_window_size = last_payload.len });
        try testing.expectError(error.NeedDictionary, decoder.step(last_block, &output));
        try testing.expectEqual(@as(?u32, 7), decoder.requiredDictionaryId());
        try testing.expectEqual(core.Progress{}, decoder.snapshot().last_step_progress);
        try decoder.provideDictionary(zstd.NativeDictionary.init(7, "provided history"));
        try testing.expectError(error.OutputLimitExceeded, decoder.step(last_block, &output));
        try expectPaused(&decoder, header.len, 0, .{});
        try testing.expect(std.mem.allEqual(u8, &output, canary));
        try decoder.retryFrameAdmission(.{ .max_output_len = last_payload.len });
        try decodeSuffix(&decoder, last_block, &output);
        try testing.expectEqualSlices(u8, last_payload, &output);
        try testing.expectEqual(@as(Count, frame.len), decoder.snapshot().input_received);
    }
}

test "Zstd frame admission retry does not unstick default payload or skippable rejections" {
    const unknown_size_header = magic ++ "\x00\x00";
    const unknown_size_frame = unknown_size_header ++ last_block;
    for (policies) |policy| {
        const cases = [_]struct { frame: []const u8, options: Decoder.Options }{
            .{ .frame = last_frame, .options = .{ .input_policy = policy, .max_output_len = last_payload.len - 1 } },
            .{ .frame = unknown_size_frame, .options = .{ .input_policy = policy, .max_output_len = last_payload.len - 1, .retry_frame_admission_limits = true } },
            .{ .frame = metadata_frame, .options = .{ .input_policy = policy, .max_frames = 0, .retry_frame_admission_limits = true } },
        };
        for (cases, 0..) |case, index| {
            var decoder = Decoder.initWithOptions(testing.allocator, case.options);
            defer decoder.deinit();
            var output: [last_payload.len]u8 = @splat(canary);
            try testing.expectError(error.OutputLimitExceeded, decoder.step(case.frame, &output));
            const failed = decoder.snapshot();
            try testing.expect(!failed.frame_admission_paused);
            switch (index) {
                0 => try testing.expectEqual(@as(Count, last_header.len), failed.input_received),
                1 => try testing.expect(failed.input_received > unknown_size_header.len),
                else => {
                    try testing.expectEqual(@as(Count, 8), failed.input_received);
                    try testing.expectEqual(@as(Count, 0), failed.skippable_event_count);
                },
            }
            try testing.expectError(error.InvalidStreamState, decoder.retryFrameAdmission(.{ .max_output_len = last_payload.len, .max_frames = 1 }));
            try expectBlocked(&decoder, case.frame, false);
        }
    }
}
