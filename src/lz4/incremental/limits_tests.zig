const std = @import("std");
const core = @import("../../core.zig");
const lz4 = @import("../../lz4.zig");

const Decoder = lz4.NativeIncrementalFrameDecoder;
const allocator = std.testing.allocator;
const policies = [_]core.CompressedInputPolicy{ .block_stream, .prevalidated_frame };

fn expectOwnedBytes(decoder: *const Decoder) !void {
    const retained = decoder.frame_scratch.capacity + decoder.decoded_scratch.capacity +
        decoder.direct_history.capacity + decoder.direct_block_decoded_lens.capacity * @sizeOf(usize);
    try std.testing.expectEqual(retained, decoder.workingMemoryBytes());
    try std.testing.expectEqual(retained, decoder.snapshot().working_bytes);
    try std.testing.expect(decoder.peakWorkingMemoryBytes() >= retained);
}

fn drain(decoder: *Decoder, input: []const u8, output: []u8, failure: ?lz4.Error) !core.Progress {
    const before = decoder.snapshot();
    var progress: core.Progress = .{};
    while (true) {
        const input_end = @min(input.len, progress.input_read + 19);
        const output_end = @min(output.len, progress.output_written + 127);
        const result = decoder.step(input[progress.input_read..input_end], output[progress.output_written..output_end]) catch |err| {
            if (failure) |expected| {
                try std.testing.expectEqual(expected, err);
                const last = decoder.snapshot().last_step_progress;
                try std.testing.expect(last.input_read <= input_end - progress.input_read);
                try std.testing.expect(last.output_written <= output_end - progress.output_written);
                try progress.add(last);
                try std.testing.expectEqual(before.input_received + progress.input_read, decoder.snapshot().input_received);
                try std.testing.expectEqual(before.output_written + progress.output_written, decoder.snapshot().output_written);
                try std.testing.expectEqual(@as(?usize, decoder.snapshot().input_received), decoder.snapshot().error_input_offset);
                try std.testing.expectEqual(@as(?usize, decoder.snapshot().output_written), decoder.snapshot().error_output_offset);
                try expectOwnedBytes(decoder);
                return progress;
            }
            return err;
        };
        try std.testing.expect(result.progress.input_read <= input_end - progress.input_read);
        try std.testing.expect(result.progress.output_written <= output_end - progress.output_written);
        try progress.add(result.progress);
        try std.testing.expectEqual(before.input_received + progress.input_read, decoder.snapshot().input_received);
        try std.testing.expectEqual(before.output_written + progress.output_written, decoder.snapshot().output_written);
        try std.testing.expectEqualDeep(result.progress, decoder.snapshot().last_step_progress);
        try expectOwnedBytes(decoder);
        if (result.status == .done and progress.input_read == input.len) break;
        try std.testing.expect(result.progress.input_read != 0 or result.progress.output_written != 0);
    }
    if (failure != null) return error.TestExpectedError;
    try std.testing.expectEqual(input.len, progress.input_read);
    try std.testing.expectEqual(output.len, progress.output_written);
    try decoder.finish();
    return progress;
}

fn fillRandom(bytes: []u8) void {
    var state: u32 = 0x9653_2471;
    for (bytes) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
}

test "LZ4 incremental limits initialization is allocation free and movable" {
    var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    const dict = lz4.NativeDictionary.init(23, "borrowed dictionary");
    const set = lz4.NativeDictionarySet.init(&.{dict});
    var decoders = [_]Decoder{
        Decoder.init(failing.allocator()),
        Decoder.initWithOptions(failing.allocator(), .{ .max_working_memory = 0 }),
        Decoder.initWithDictionary(failing.allocator(), dict),
        Decoder.initWithDictionaryAndOptions(failing.allocator(), dict, .{}),
        Decoder.initWithDictionarySet(failing.allocator(), set),
        Decoder.initWithDictionarySetAndOptions(failing.allocator(), set, .{}),
    };
    for (&decoders) |*decoder| {
        try std.testing.expectEqual(@as(usize, 0), decoder.workingMemoryBytes());
        try std.testing.expectEqual(@as(usize, 0), decoder.peakWorkingMemoryBytes());
        decoder.deinit();
    }
    try std.testing.expectEqual(@as(usize, 0), failing.alloc_index);
    var moved = Decoder.initWithOptions(allocator, .{ .max_working_memory = 32 });
    defer moved.deinit();
    const frame = try lz4.encodePureFrameWithOptionsAlloc(allocator, "", .{ .content_checksum = false });
    defer allocator.free(frame);
    var output: [0]u8 = .{};
    _ = try drain(&moved, frame, &output, null);
}

test "LZ4 incremental limits cumulative output is independent of frame caps" {
    const first_payload = "first member payload" ** 4;
    const second_payload = "second member payload" ** 5;
    const expected = first_payload ++ second_payload;
    for (policies) |policy| {
        for ([_]bool{ false, true }) |include_content_size| {
            for ([_]bool{ false, true }) |block_checksum| {
                const options: lz4.NativeFrameOptions = .{
                    .include_content_size = include_content_size,
                    .block_checksum = block_checksum,
                    .content_checksum = true,
                };
                const first = try lz4.encodePureFrameWithOptionsAlloc(allocator, first_payload, options);
                defer allocator.free(first);
                const second = try lz4.encodePureFrameWithOptionsAlloc(allocator, second_payload, options);
                defer allocator.free(second);
                const stream = try std.mem.concat(allocator, u8, &.{ first, second });
                defer allocator.free(stream);
                var decoder = Decoder.initWithOptions(allocator, .{
                    .input_policy = policy,
                    .max_output_len = expected.len,
                    .max_decoded_buffer_len = @max(first_payload.len, second_payload.len),
                });
                defer decoder.deinit();
                var output: [expected.len]u8 = undefined;
                _ = try drain(&decoder, stream, &output, null);
                try std.testing.expectEqualSlices(u8, expected, &output);
                var limited = Decoder.initWithOptions(allocator, .{
                    .input_policy = policy,
                    .max_output_len = expected.len - 1,
                    .max_decoded_buffer_len = @max(first_payload.len, second_payload.len),
                });
                defer limited.deinit();
                const result = try drain(&limited, stream, &output, error.OutputLimitExceeded);
                try std.testing.expect(result.output_written <= expected.len - 1);
                try std.testing.expect(limited.snapshot().output_written >= first_payload.len);
                const before = limited.snapshot();
                try std.testing.expectError(error.OutputLimitExceeded, limited.step(stream[result.input_read..], &output));
                try std.testing.expectEqual(before.input_received, limited.snapshot().input_received);
                try std.testing.expectEqual(before.output_written, limited.snapshot().output_written);
                try std.testing.expectEqualDeep(core.Progress{}, limited.snapshot().last_step_progress);
            }
        }
    }
}

test "LZ4 incremental limits zero output accepts empty frames and metadata" {
    for (policies) |policy| {
        const frame = try lz4.encodePureFrameWithOptionsAlloc(allocator, "", .{ .include_content_size = false });
        defer allocator.free(frame);
        const skip = try lz4.encodeSkippableFrameAlloc(allocator, 2, "only metadata");
        defer allocator.free(skip);
        const stream = try std.mem.concat(allocator, u8, &.{ skip, frame, skip });
        defer allocator.free(stream);
        var decoder = Decoder.initWithOptions(allocator, .{ .input_policy = policy, .max_output_len = 0, .expected_output_len = 0 });
        defer decoder.deinit();
        _ = try drain(&decoder, stream, &.{}, null);
        try std.testing.expectEqual(@as(usize, 2), decoder.snapshot().skippable_event_count);
        const nonempty = try lz4.encodePureFrameWithOptionsAlloc(allocator, "not empty", .{ .include_content_size = false });
        defer allocator.free(nonempty);
        var limited = Decoder.initWithOptions(allocator, .{ .input_policy = policy, .max_output_len = 0 });
        defer limited.deinit();
        var output: [9]u8 = undefined;
        _ = try drain(&limited, nonempty, &output, error.OutputLimitExceeded);
        try std.testing.expectEqual(@as(usize, 0), limited.snapshot().output_written);
    }
}

test "LZ4 incremental limits stopped members preserve pledge input budget and metadata" {
    const first_payload = "first stopped member" ** 8;
    const second_payload = "second stopped member" ** 9;
    const expected = first_payload ++ second_payload;
    const first = try lz4.encodePureFrameWithOptionsAlloc(allocator, first_payload, .{ .block_checksum = true });
    defer allocator.free(first);
    const second = try lz4.encodePureFrameWithOptionsAlloc(allocator, second_payload, .{ .block_checksum = true });
    defer allocator.free(second);
    const skip = try lz4.encodeSkippableFrameAlloc(allocator, 3, "metadata across members");
    defer allocator.free(skip);
    const stream = try std.mem.concat(allocator, u8, &.{ skip, first, skip, second });
    defer allocator.free(stream);
    for (policies) |policy| {
        var decoder = Decoder.initWithOptions(allocator, .{
            .input_policy = policy,
            .stop_after_first_frame = true,
            .max_output_len = expected.len,
            .max_decoded_buffer_len = second_payload.len,
            .expected_output_len = expected.len,
        });
        defer decoder.deinit();
        try std.testing.expectError(error.InvalidStreamState, decoder.nextStream());
        var output: [expected.len]u8 = undefined;
        const initial = try decoder.step(stream, &output);
        try std.testing.expectEqual(core.StepResult.Status.done, initial.status);
        try std.testing.expectEqual(first_payload.len, initial.progress.output_written);
        try std.testing.expectEqual(@as(usize, 1), decoder.snapshot().skippable_event_count);
        const before = decoder.snapshot();
        const accepted_trailing = decoder.trailingInput().len;
        if (policy == .prevalidated_frame) try std.testing.expect(accepted_trailing != 0);
        try std.testing.expectError(error.SizeMismatch, decoder.finish());
        try decoder.nextStream();
        try std.testing.expectEqual(before.input_received, decoder.snapshot().input_received);
        try std.testing.expectEqual(before.output_written, decoder.snapshot().output_written);
        try std.testing.expectEqual(before.working_bytes, decoder.workingMemoryBytes());
        try std.testing.expectEqual(before.peak_working_bytes, decoder.peakWorkingMemoryBytes());
        const done = try decoder.step(stream[initial.progress.input_read..], output[initial.progress.output_written..]);
        try std.testing.expectEqual(core.StepResult.Status.done, done.status);
        try std.testing.expectEqual(stream.len, decoder.snapshot().input_received);
        try std.testing.expectEqual(expected.len, decoder.snapshot().output_written);
        try std.testing.expectEqual(@as(usize, 2), decoder.snapshot().skippable_event_count);
        try std.testing.expectEqualSlices(u8, expected, &output);
        try decoder.finish();
        try expectOwnedBytes(&decoder);
    }
}

test "LZ4 incremental limits automatic next input keeps cumulative quota" {
    const payload = "one member then another";
    const frame = try lz4.encodePureFrameWithOptionsAlloc(allocator, payload, .{});
    defer allocator.free(frame);
    for (policies) |policy| {
        for ([_]bool{ false, true }) |stop| {
            var decoder = Decoder.initWithOptions(allocator, .{ .input_policy = policy, .stop_after_first_frame = stop, .max_output_len = payload.len });
            defer decoder.deinit();
            var output: [payload.len]u8 = undefined;
            try std.testing.expectEqual(core.StepResult.Status.done, (try decoder.step(frame, &output)).status);
            if (stop) {
                const stopped = try decoder.step(frame, &output);
                try std.testing.expectEqual(core.StepResult.Status.done, stopped.status);
                try std.testing.expectEqualDeep(core.Progress{}, stopped.progress);
                try decoder.nextStream();
            }
            try std.testing.expectError(error.OutputLimitExceeded, decoder.step(frame, &output));
            try std.testing.expectEqual(payload.len, decoder.snapshot().output_written);
            try std.testing.expect(decoder.snapshot().input_received > frame.len);
        }
    }
}

test "LZ4 incremental limits working memory includes retained and temporary preflight bytes" {
    var raw: [256]u8 = undefined;
    fillRandom(&raw);
    for (policies) |policy| {
        const frame = try lz4.encodePureFrameWithOptionsAlloc(allocator, &raw, .{ .block_checksum = true });
        defer allocator.free(frame);
        var baseline = Decoder.initWithOptions(allocator, .{ .input_policy = policy });
        defer baseline.deinit();
        const pending = try baseline.step(frame, &.{});
        try std.testing.expectEqual(core.StepResult.Status.need_output, pending.status);
        try expectOwnedBytes(&baseline);
        const peak = baseline.peakWorkingMemoryBytes();
        if (policy == .prevalidated_frame) try std.testing.expect(peak > baseline.workingMemoryBytes());
        var exact = Decoder.initWithOptions(allocator, .{ .input_policy = policy, .max_working_memory = peak });
        defer exact.deinit();
        const accepted = try exact.step(frame, &.{});
        try std.testing.expectEqual(core.StepResult.Status.need_output, accepted.status);
        try std.testing.expect(exact.peakWorkingMemoryBytes() <= peak);
        var output: [raw.len]u8 = undefined;
        const done = try exact.step(frame[accepted.progress.input_read..], &output);
        try std.testing.expectEqual(core.StepResult.Status.done, done.status);
        try std.testing.expectEqualSlices(u8, &raw, &output);
        var below = Decoder.initWithOptions(allocator, .{ .input_policy = policy, .max_working_memory = peak - 1 });
        defer below.deinit();
        try std.testing.expectError(error.WorkingMemoryLimitExceeded, below.step(frame, &output));
        try std.testing.expect(below.peakWorkingMemoryBytes() < peak);
        try std.testing.expectEqual(@as(?usize, below.snapshot().input_received), below.snapshot().error_input_offset);
        try std.testing.expectEqualSlices(u8, "WorkingMemoryLimitExceeded", below.snapshot().last_error_name);
        try expectOwnedBytes(&below);
    }
}

test "LZ4 incremental limits reset retains live capacity and reconfiguration releases it" {
    const payload = "retained history and budget" ** 512;
    const frame = try lz4.encodePureFrameWithOptionsAlloc(allocator, payload, .{});
    defer allocator.free(frame);
    for (policies) |policy| {
        var decoder = Decoder.initWithOptions(allocator, .{ .input_policy = policy, .max_output_len = payload.len });
        defer decoder.deinit();
        const output = try allocator.alloc(u8, payload.len);
        defer allocator.free(output);
        _ = try drain(&decoder, frame, output, null);
        const live = decoder.workingMemoryBytes();
        try std.testing.expect(live != 0);
        decoder.reset();
        try std.testing.expectEqual(live, decoder.workingMemoryBytes());
        try std.testing.expectEqual(live, decoder.peakWorkingMemoryBytes());
        try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().input_received);
        try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().output_written);
        _ = try drain(&decoder, frame, output, null);
        const before = decoder.snapshot();
        try std.testing.expectError(error.InvalidBlockPlan, decoder.resetWithOptions(.{ .max_output_len = 1, .expected_output_len = 2 }));
        try std.testing.expectEqualDeep(before, decoder.snapshot());
        try decoder.resetWithOptions(.{ .max_output_len = 0, .max_working_memory = 32 });
        try std.testing.expectEqual(@as(usize, 0), decoder.workingMemoryBytes());
        try std.testing.expectEqual(@as(usize, 0), decoder.peakWorkingMemoryBytes());
        const empty = try lz4.encodePureFrameWithOptionsAlloc(allocator, "", .{ .content_checksum = false });
        defer allocator.free(empty);
        _ = try drain(&decoder, empty, &.{}, null);
        try std.testing.expect(decoder.peakWorkingMemoryBytes() <= 32);
    }
}

test "LZ4 incremental limits backing OOM is distinct and repeated errors are sticky" {
    const frame = try lz4.encodePureFrameWithOptionsAlloc(allocator, "some payload", .{});
    defer allocator.free(frame);
    var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    var decoder = Decoder.init(failing.allocator());
    defer decoder.deinit();
    var output: [32]u8 = @splat(0xa5);
    try std.testing.expectError(error.OutOfMemory, decoder.step(frame, &output));
    const before = decoder.snapshot();
    try std.testing.expectEqual(@as(usize, 0), before.working_bytes);
    try std.testing.expectEqualDeep(core.Progress{}, before.last_step_progress);
    try std.testing.expectEqualSlices(u8, "allocation_failure", decoder.diagnostics().recoverability_hint_name);
    failing.fail_index = std.math.maxInt(usize);
    try std.testing.expectError(error.OutOfMemory, decoder.step(frame, &output));
    try std.testing.expectEqual(before.input_received, decoder.snapshot().input_received);
    try std.testing.expectEqual(before.output_written, decoder.snapshot().output_written);
    for (output) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
    decoder.reset();
    _ = try decoder.step(frame, output[0.."some payload".len]);
    try std.testing.expectEqualSlices(u8, "some payload", output[0.."some payload".len]);

    var denied = Decoder.initWithOptions(allocator, .{ .max_working_memory = 0 });
    defer denied.deinit();
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, denied.step(frame, &output));
    try std.testing.expectEqual(@as(usize, 0), denied.workingMemoryBytes());
}

test "LZ4 incremental limits direct output OOM records bytes already emitted" {
    var payload: [256]u8 = undefined;
    fillRandom(&payload);
    const frame = try lz4.encodePureFrameWithOptionsAlloc(allocator, &payload, .{ .block_mode = .linked, .content_checksum = false });
    defer allocator.free(frame);
    var failing = std.testing.FailingAllocator.init(allocator, .{});
    var decoder = Decoder.initWithOptions(failing.allocator(), .{ .input_policy = .prevalidated_frame });
    defer decoder.deinit();
    try std.testing.expectEqual(core.StepResult.Status.need_output, (try decoder.step(frame, &.{})).status);
    failing.fail_index = failing.alloc_index;
    var output: [payload.len]u8 = @splat(0xa5);
    try std.testing.expectError(error.OutOfMemory, decoder.step("", &output));
    try std.testing.expectEqualSlices(u8, &payload, &output);
    try std.testing.expectEqualDeep(core.Progress{ .output_written = payload.len }, decoder.snapshot().last_step_progress);
    try std.testing.expectEqual(@as(?usize, frame.len), decoder.snapshot().error_input_offset);
    try std.testing.expectEqual(@as(?usize, payload.len), decoder.snapshot().error_output_offset);
    const before = decoder.snapshot();
    @memset(&output, 0xa5);
    try std.testing.expectError(error.OutOfMemory, decoder.step("", &output));
    try std.testing.expectEqual(before.output_written, decoder.snapshot().output_written);
    for (output) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
    try expectOwnedBytes(&decoder);
}

fn tokenFrame(payload: []const u8) ![]u8 {
    const empty = try lz4.encodePureFrameWithOptionsAlloc(allocator, "", .{ .include_content_size = false, .content_checksum = false });
    defer allocator.free(empty);
    const header = try lz4.inspectNativeFrameHeader(empty);
    const frame = try allocator.alloc(u8, header.payload_offset + 4 + payload.len + 4);
    @memcpy(frame[0..header.payload_offset], empty[0..header.payload_offset]);
    std.mem.writeInt(u32, frame[header.payload_offset..][0..4], @intCast(payload.len), .little);
    @memcpy(frame[header.payload_offset + 4 ..][0..payload.len], payload);
    @memset(frame[frame.len - 4 ..], 0);
    return frame;
}

test "LZ4 incremental limits cursor errors capture partial input and output" {
    const malformed = try tokenFrame(&.{ 0x10, 'a', 0, 0 });
    defer allocator.free(malformed);
    const limited_frame = try tokenFrame(&.{ 0x10, 'a', 1, 0, 0 });
    defer allocator.free(limited_frame);
    for (policies) |policy| {
        var output: [8]u8 = @splat(0xa5);
        var decoder = Decoder.initWithOptions(allocator, .{ .input_policy = policy });
        defer decoder.deinit();
        try std.testing.expectError(error.InvalidMatch, decoder.step(malformed, &output));
        if (policy == .block_stream) {
            try std.testing.expectEqual(@as(usize, 15), decoder.snapshot().last_step_progress.input_read);
            try std.testing.expectEqual(@as(usize, 1), decoder.snapshot().last_step_progress.output_written);
            try std.testing.expectEqual(@as(u8, 'a'), output[0]);
        } else {
            try std.testing.expectEqual(malformed.len, decoder.snapshot().last_step_progress.input_read);
            try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().last_step_progress.output_written);
        }
        try std.testing.expectEqual(@as(?core.StreamCount, decoder.snapshot().input_received), decoder.diagnostics().error_input_offset);
        try std.testing.expectEqual(@as(?core.StreamCount, decoder.snapshot().output_written), decoder.diagnostics().error_output_offset);
        var limited = Decoder.initWithOptions(allocator, .{ .input_policy = policy, .max_output_len = 2 });
        defer limited.deinit();
        try std.testing.expectError(error.OutputLimitExceeded, limited.step(limited_frame, &output));
        try std.testing.expect(limited.snapshot().output_written <= 2);
        if (policy == .block_stream) try std.testing.expectEqual(@as(usize, 1), limited.snapshot().last_step_progress.output_written);
    }
}

test "LZ4 incremental limits pledge validation and per-frame caps remain separate" {
    const payload = "pledged frame output" ** 16;
    const frame = try lz4.encodePureFrameWithOptionsAlloc(allocator, payload, .{ .include_content_size = false });
    defer allocator.free(frame);
    for (policies) |policy| {
        var invalid = Decoder.initWithOptions(allocator, .{ .input_policy = policy, .max_output_len = 1, .expected_output_len = 2 });
        defer invalid.deinit();
        try std.testing.expectError(error.InvalidBlockPlan, invalid.step(frame, &.{}));
        try std.testing.expectEqual(@as(usize, 0), invalid.workingMemoryBytes());
        var capped = Decoder.initWithOptions(allocator, .{
            .input_policy = policy,
            .max_output_len = payload.len,
            .max_decoded_buffer_len = payload.len - 1,
            .expected_output_len = payload.len,
        });
        defer capped.deinit();
        var output: [payload.len]u8 = undefined;
        _ = try drain(&capped, frame, &output, error.OutputLimitExceeded);
        var pledged = Decoder.initWithOptions(allocator, .{ .input_policy = policy, .expected_output_len = payload.len - 1 });
        defer pledged.deinit();
        _ = try drain(&pledged, frame, &output, error.SizeMismatch);
    }
}

test "LZ4 incremental limits dictionaries share the working budget across members" {
    var dictionary_bytes: [4096]u8 = undefined;
    fillRandom(&dictionary_bytes);
    const dict = lz4.NativeDictionary.init(94, &dictionary_bytes);
    const set = lz4.NativeDictionarySet.init(&.{dict});
    const payload = dictionary_bytes[3072..];
    const frame = try lz4.encodeNativeFrameWithDictionaryAlloc(allocator, payload, .{
        .include_content_size = false,
        .content_checksum = true,
        .block_checksum = true,
    }, dict);
    defer allocator.free(frame);
    const stream = try std.mem.concat(allocator, u8, &.{ frame, frame });
    defer allocator.free(stream);
    for (policies) |policy| {
        var decoder = Decoder.initWithDictionarySetAndOptions(allocator, set, .{
            .input_policy = policy,
            .max_output_len = payload.len * 2,
            .max_decoded_buffer_len = payload.len,
            .expected_output_len = payload.len * 2,
        });
        defer decoder.deinit();
        var output: [2048]u8 = undefined;
        _ = try drain(&decoder, stream, &output, null);
        try std.testing.expectEqualSlices(u8, payload, output[0..1024]);
        try std.testing.expectEqualSlices(u8, payload, output[1024..]);
        const peak = decoder.peakWorkingMemoryBytes();
        var exact = Decoder.initWithDictionaryAndOptions(allocator, dict, .{ .input_policy = policy, .max_working_memory = peak });
        defer exact.deinit();
        var single_output: [1024]u8 = undefined;
        _ = try drain(&exact, frame, &single_output, null);
        try std.testing.expectEqualSlices(u8, payload, &single_output);
        var denied = Decoder.initWithDictionarySetAndOptions(allocator, set, .{ .input_policy = policy, .max_working_memory = 32 });
        defer denied.deinit();
        try std.testing.expectError(error.WorkingMemoryLimitExceeded, denied.step(frame, &single_output));
        try std.testing.expectEqual(@as(usize, 0), denied.snapshot().output_written);
        try expectOwnedBytes(&denied);
        try decoder.resetWithOptions(.{ .input_policy = policy, .max_output_len = payload.len });
        try std.testing.expect(decoder.dictionary_set != null);
        _ = try drain(&decoder, frame, &single_output, null);
    }
}

test "LZ4 incremental limits compressed history budget accepts exact peak and rejects below" {
    const payload = "history-memory-limit" ** 1024;
    const frame = try lz4.encodePureFrameWithOptionsAlloc(allocator, payload, .{ .content_checksum = true, .block_checksum = true });
    defer allocator.free(frame);
    for (policies) |policy| {
        var baseline = Decoder.initWithOptions(allocator, .{ .input_policy = policy });
        defer baseline.deinit();
        const output = try allocator.alloc(u8, payload.len);
        defer allocator.free(output);
        _ = try drain(&baseline, frame, output, null);
        try std.testing.expect(baseline.direct_history.capacity != 0);
        const peak = baseline.peakWorkingMemoryBytes();
        var exact = Decoder.initWithOptions(allocator, .{ .input_policy = policy, .max_working_memory = peak });
        defer exact.deinit();
        _ = try drain(&exact, frame, output, null);
        try std.testing.expectEqualSlices(u8, payload, output);
        var below = Decoder.initWithOptions(allocator, .{ .input_policy = policy, .max_working_memory = peak - 1 });
        defer below.deinit();
        _ = try drain(&below, frame, output, error.WorkingMemoryLimitExceeded);
        try std.testing.expect(below.peakWorkingMemoryBytes() < peak);
    }
}

fn allocationFailureRoundTrip(backing: std.mem.Allocator, frame: []const u8, payload: []const u8) !void {
    var decoder = Decoder.initWithOptions(backing, .{ .input_policy = .prevalidated_frame });
    defer decoder.deinit();
    var output: [1024]u8 = undefined;
    _ = decoder.step(frame, output[0..payload.len]) catch |err| {
        try std.testing.expectEqual(error.OutOfMemory, err);
        try expectOwnedBytes(&decoder);
        const before = decoder.snapshot();
        try std.testing.expectError(error.OutOfMemory, decoder.step("", &output));
        try std.testing.expectEqual(before.input_received, decoder.snapshot().input_received);
        try std.testing.expectEqual(before.output_written, decoder.snapshot().output_written);
        return err;
    };
    try std.testing.expectEqualSlices(u8, payload, output[0..payload.len]);
    try expectOwnedBytes(&decoder);
}

test "LZ4 incremental limits prevalidated allocations balance every backing OOM" {
    var payload: [1024]u8 = undefined;
    fillRandom(&payload);
    const frame = try lz4.encodePureFrameWithOptionsAlloc(allocator, &payload, .{ .block_mode = .linked });
    defer allocator.free(frame);
    try std.testing.checkAllAllocationFailures(allocator, allocationFailureRoundTrip, .{ frame, @as([]const u8, &payload) });
}

test "LZ4 incremental limits diagnostics distinguish logical pledge from frame size" {
    const payload = "logical pledge and frame snapshots";
    const frame = try lz4.encodePureFrameWithOptionsAlloc(allocator, payload, .{ .block_checksum = true });
    defer allocator.free(frame);
    for (policies) |policy| {
        var decoder = Decoder.initWithOptions(allocator, .{
            .input_policy = policy,
            .stop_after_first_frame = true,
            .expected_output_len = payload.len * 2,
        });
        defer decoder.deinit();
        const pending = try decoder.step(frame, &.{});
        try std.testing.expectEqual(core.StepResult.Status.need_output, pending.status);
        try std.testing.expectEqual(@as(?usize, payload.len), decoder.snapshot().decoded_len);
        try std.testing.expectEqual(@as(?core.StreamCount, payload.len * 2), decoder.diagnostics().expected_output_len);
        var output: [payload.len]u8 = undefined;
        const first = try decoder.step(frame[pending.progress.input_read..], &output);
        try std.testing.expectEqual(core.StepResult.Status.done, first.status);
        try decoder.nextStream();
        try std.testing.expectEqual(@as(?core.StreamCount, payload.len * 2), decoder.diagnostics().expected_output_len);
        try std.testing.expectEqual(core.StepResult.Status.done, (try decoder.step(frame, &output)).status);
        try decoder.finish();
    }
}

test "LZ4 incremental limits stopped frames require explicit resume with optional pledge" {
    const payload = "explicit stopped-member resume";
    const frame = try lz4.encodePureFrameWithOptionsAlloc(allocator, payload, .{});
    defer allocator.free(frame);
    for (policies) |policy| {
        for ([_]bool{ false, true }) |pledged| {
            var decoder = Decoder.initWithOptions(allocator, .{
                .input_policy = policy,
                .stop_after_first_frame = true,
                .max_output_len = payload.len * 2,
                .expected_output_len = if (pledged) payload.len * 2 else null,
            });
            defer decoder.deinit();
            var output: [payload.len]u8 = undefined;
            try std.testing.expectEqual(core.StepResult.Status.done, (try decoder.step(frame, &output)).status);
            const before = decoder.snapshot();
            @memset(&output, 0xa5);
            const paused = try decoder.step(frame, &output);
            try std.testing.expectEqual(core.StepResult.Status.done, paused.status);
            try std.testing.expectEqualDeep(core.Progress{}, paused.progress);
            try std.testing.expectEqual(before.input_received, decoder.snapshot().input_received);
            try std.testing.expectEqual(before.output_written, decoder.snapshot().output_written);
            try std.testing.expectEqual(before.working_bytes, decoder.workingMemoryBytes());
            try std.testing.expectEqual(before.peak_working_bytes, decoder.peakWorkingMemoryBytes());
            for (output) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
            try decoder.nextStream();
            const done = try decoder.step(frame, &output);
            try std.testing.expectEqual(core.StepResult.Status.done, done.status);
            try std.testing.expectEqual(frame.len, done.progress.input_read);
            try std.testing.expectEqual(payload.len, done.progress.output_written);
            try std.testing.expectEqual(@as(usize, payload.len * 2), decoder.snapshot().output_written);
            try std.testing.expectEqualSlices(u8, payload, &output);
            try decoder.finish();
        }
    }
}
