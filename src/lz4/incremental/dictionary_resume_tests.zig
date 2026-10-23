const std = @import("std");
const core = @import("../../core.zig");
const lz4 = @import("../../lz4.zig");
const allocator = std.testing.allocator;
const Decoder = lz4.NativeIncrementalFrameDecoder;
const policies = [_]core.CompressedInputPolicy{ .block_stream, .prevalidated_frame };
const dictionary = lz4.NativeDictionary.init(0x4455_6677, "application dictionary prefix:0123456789abcdef" ** 128);
const payload = "application dictionary prefix:0123456789abcdef" ** 64;

fn encode(checksum: bool, independent: bool) ![]u8 {
    return lz4.encodeNativeFrameWithDictionaryAlloc(allocator, payload, .{
        .content_checksum = checksum,
        .block_checksum = checksum,
        .include_content_size = false,
        .block_mode = if (independent) .independent else .linked,
        .block_size_id = .max64kb,
    }, dictionary);
}

fn drainResumed(decoder: *Decoder, frame: []const u8, start: usize, output: []u8) !void {
    var read = start;
    var written: usize = 0;
    while (true) {
        const input_end = @min(frame.len, read + 13);
        const output_end = @min(output.len, written + 17);
        const result = try decoder.step(frame[read..input_end], output[written..output_end]);
        read += result.progress.input_read;
        written += result.progress.output_written;
        if (result.status == .done) break;
        try std.testing.expect(result.progress.input_read != 0 or result.progress.output_written != 0);
    }
    try std.testing.expectEqual(frame.len, read);
    try std.testing.expectEqual(output.len, written);
    try decoder.finish();
}

fn request(decoder: *Decoder, frame: []const u8, chunk: usize) !usize {
    var read: usize = 0;
    while (true) {
        const end = read + @min(frame.len - read, chunk);
        const step = decoder.step(frame[read..end], &.{}) catch |err| {
            try std.testing.expectEqual(error.NeedDictionary, err);
            read += decoder.snapshot().last_step_progress.input_read;
            try std.testing.expectEqual(@as(?u32, dictionary.id), decoder.requiredDictionaryId());
            try std.testing.expectEqualSlices(u8, "retry_with_dictionary", decoder.diagnostics().recoverability_hint_name);
            return read;
        };
        read += step.progress.input_read;
        try std.testing.expect(read < frame.len);
    }
}

test "LZ4 dictionary resume retains byte split and full accepted input across policies" {
    for (policies) |policy| {
        for ([_]usize{ 1, 11, std.math.maxInt(usize) }) |chunk| {
            for ([_]bool{ false, true }) |checksum| {
                for ([_]bool{ false, true }) |independent| {
                    const frame = try encode(checksum, independent);
                    defer allocator.free(frame);
                    var decoder = Decoder.initWithOptions(allocator, .{
                        .input_policy = policy,
                        .max_output_len = payload.len,
                        .expected_output_len = payload.len,
                    });
                    defer decoder.deinit();
                    const read = try request(&decoder, frame, chunk);
                    const before = decoder.snapshot();
                    try std.testing.expectError(error.NeedDictionary, decoder.step(frame[read..], &.{}));
                    try std.testing.expectEqualDeep(core.Progress{}, decoder.snapshot().last_step_progress);
                    try std.testing.expectEqual(before.input_received, decoder.snapshot().input_received);
                    try std.testing.expectError(error.NeedDictionary, decoder.finish());
                    try std.testing.expectEqual(@as(?u32, dictionary.id), decoder.requiredDictionaryId());
                    try std.testing.expectError(error.DictionaryMismatch, decoder.provideDictionary(lz4.NativeDictionary.init(dictionary.id + 1, dictionary.content)));
                    try std.testing.expectEqual(@as(?u32, dictionary.id), decoder.requiredDictionaryId());
                    try std.testing.expectEqual(before.working_bytes, decoder.workingMemoryBytes());
                    try decoder.provideDictionary(dictionary);
                    try std.testing.expectEqual(@as(?u32, null), decoder.requiredDictionaryId());
                    try std.testing.expectEqual(before.working_bytes, decoder.workingMemoryBytes());
                    var output: [payload.len]u8 = undefined;
                    try drainResumed(&decoder, frame, read, &output);
                    try std.testing.expectEqualSlices(u8, payload, &output);
                    try std.testing.expectEqual(frame.len, decoder.snapshot().input_received);
                    try std.testing.expectError(error.InvalidStreamState, decoder.provideDictionary(dictionary));
                }
            }
        }
    }
}

test "LZ4 dictionary resume overrides a missing set only for the current member" {
    const frame = try encode(true, false);
    defer allocator.free(frame);
    const missing = lz4.NativeDictionarySet.init(&.{lz4.NativeDictionary.init(9, "other dictionary")});
    for (policies) |policy| {
        var decoder = Decoder.initWithDictionarySetAndOptions(allocator, missing, .{ .input_policy = policy });
        defer decoder.deinit();
        var read = try request(&decoder, frame, 19);
        try std.testing.expectError(error.NeedDictionary, decoder.provideDictionarySet(missing));
        try std.testing.expectEqual(@as(?u32, dictionary.id), decoder.requiredDictionaryId());
        try decoder.provideDictionarySet(lz4.NativeDictionarySet.init(&.{dictionary}));
        var output: [payload.len]u8 = undefined;
        try drainResumed(&decoder, frame, read, &output);
        try std.testing.expectEqualSlices(u8, payload, &output);
        const old_input = decoder.snapshot().input_received;
        read = try request(&decoder, frame, 19);
        try std.testing.expect(decoder.snapshot().input_received > old_input);
        try std.testing.expectEqual(@as(?u32, dictionary.id), decoder.requiredDictionaryId());
        try decoder.provideDictionary(dictionary);
        try drainResumed(&decoder, frame, read, &output);
        try std.testing.expectEqual(@as(usize, payload.len * 2), decoder.snapshot().output_written);
    }
}

test "LZ4 dictionary resume trusts the application ID and defers byte integrity to frame checks" {
    const frame = try encode(true, true);
    defer allocator.free(frame);
    var decoder = Decoder.init(allocator);
    defer decoder.deinit();
    const read = try request(&decoder, frame, frame.len);
    var wrong_bytes: [dictionary.content.len]u8 = @splat('!');
    try decoder.provideDictionary(lz4.NativeDictionary.init(dictionary.id, &wrong_bytes));
    try std.testing.expectEqual(@as(?u32, null), decoder.requiredDictionaryId());
    var output: [payload.len]u8 = undefined;
    try std.testing.expectError(error.ChecksumMismatch, decoder.step(frame[read..], &output));
    try std.testing.expectEqual(payload.len, decoder.snapshot().output_written);
    try std.testing.expectError(error.InvalidStreamState, decoder.provideDictionary(dictionary));
    try std.testing.expectError(error.ChecksumMismatch, decoder.step("", &output));
}

test "LZ4 dictionary resume waits at a validated header before frame input ends" {
    const frame = try encode(true, false);
    defer allocator.free(frame);
    const header = try lz4.inspectNativeFrameHeader(frame);
    for (policies) |policy| {
        var decoder = Decoder.initWithOptions(allocator, .{ .input_policy = policy });
        defer decoder.deinit();
        try std.testing.expectError(error.InvalidStreamState, decoder.provideDictionary(dictionary));
        try std.testing.expectError(error.NeedDictionary, decoder.step(frame[0..header.payload_offset], &.{}));
        try std.testing.expectEqual(header.payload_offset, decoder.snapshot().last_step_progress.input_read);
        try std.testing.expectError(error.NeedDictionary, decoder.finish());
        try std.testing.expectEqual(@as(?u32, dictionary.id), decoder.requiredDictionaryId());
        try decoder.provideDictionary(dictionary);
        var output: [payload.len]u8 = undefined;
        try drainResumed(&decoder, frame, header.payload_offset, &output);
        try std.testing.expectEqualSlices(u8, payload, &output);
    }
}

test "LZ4 dictionary resume preserves earlier concatenated output in the failing step" {
    const first_payload = "plain earlier member";
    const first = try lz4.encodePureFrameWithOptionsAlloc(allocator, first_payload, .{});
    defer allocator.free(first);
    const second = try encode(true, false);
    defer allocator.free(second);
    const stream = try std.mem.concat(allocator, u8, &.{ first, second });
    defer allocator.free(stream);
    for (policies) |policy| {
        var decoder = Decoder.initWithOptions(allocator, .{ .input_policy = policy, .expected_output_len = first_payload.len + payload.len });
        defer decoder.deinit();
        var output: [first_payload.len + payload.len]u8 = undefined;
        try std.testing.expectError(error.NeedDictionary, decoder.step(stream, &output));
        const before = decoder.snapshot();
        try std.testing.expectEqual(first_payload.len, before.last_step_progress.output_written);
        try std.testing.expectEqualSlices(u8, first_payload, output[0..first_payload.len]);
        try std.testing.expectEqual(before.input_received, before.last_step_progress.input_read);
        try std.testing.expectEqual(@as(?usize, before.input_received), before.error_input_offset);
        try std.testing.expectEqual(@as(?usize, first_payload.len), before.error_output_offset);
        try std.testing.expectError(error.NeedDictionary, decoder.finish());
        try decoder.provideDictionary(dictionary);
        try std.testing.expectEqualDeep(before.last_step_progress, decoder.snapshot().last_step_progress);
        try drainResumed(&decoder, stream, before.input_received, output[first_payload.len..]);
        try std.testing.expectEqualSlices(u8, payload, output[first_payload.len..]);
        try std.testing.expectEqual(stream.len, decoder.snapshot().input_received);
        try std.testing.expectEqual(output.len, decoder.snapshot().output_written);
    }
}

test "LZ4 dictionary resume keeps stopped logical pledges and clears frame override" {
    const frame = try encode(true, true);
    defer allocator.free(frame);
    for (policies) |policy| {
        var decoder = Decoder.initWithOptions(allocator, .{
            .input_policy = policy,
            .expected_output_len = payload.len * 2,
            .max_output_len = payload.len * 2,
            .stop_after_first_frame = true,
        });
        defer decoder.deinit();
        var output: [payload.len]u8 = undefined;
        const read = try request(&decoder, frame, frame.len);
        try std.testing.expectError(error.NeedDictionary, decoder.finish());
        try decoder.provideDictionary(dictionary);
        const first = try decoder.step(frame[read..], &output);
        try std.testing.expectEqual(core.StepResult.Status.done, first.status);
        try std.testing.expectEqual(@as(?u32, null), decoder.requiredDictionaryId());
        try std.testing.expectError(error.SizeMismatch, decoder.finish());
        try std.testing.expectEqualDeep(core.Progress{}, (try decoder.step(frame, &output)).progress);
        const old_input = decoder.snapshot().input_received;
        const old_live = decoder.workingMemoryBytes();
        try decoder.nextStream();
        try std.testing.expectEqual(@as(?u32, null), decoder.requiredDictionaryId());
        try std.testing.expectEqual(old_input, decoder.snapshot().input_received);
        try std.testing.expectEqual(old_live, decoder.workingMemoryBytes());
        try std.testing.expectError(error.NeedDictionary, decoder.step(frame, &output));
        const accepted = decoder.snapshot().last_step_progress.input_read;
        try decoder.provideDictionary(dictionary);
        try std.testing.expectEqual(core.StepResult.Status.done, (try decoder.step(frame[accepted..], &output)).status);
        try decoder.finish();
        try std.testing.expectEqual(@as(usize, payload.len * 2), decoder.snapshot().output_written);
        try std.testing.expectEqualSlices(u8, payload, &output);
    }
}

test "LZ4 dictionary resume preserves short pledges and other failures stay sticky" {
    const frame = try encode(true, true);
    defer allocator.free(frame);
    for (policies) |policy| {
        var decoder = Decoder.initWithOptions(allocator, .{ .input_policy = policy, .expected_output_len = payload.len - 1 });
        defer decoder.deinit();
        const accepted = try request(&decoder, frame, frame.len);
        try decoder.provideDictionary(dictionary);
        var output: [payload.len]u8 = undefined;
        try std.testing.expectError(error.SizeMismatch, decoder.step(frame[accepted..], &output));
        try std.testing.expectEqual(@as(?u32, null), decoder.requiredDictionaryId());
        const before = decoder.snapshot();
        try std.testing.expectError(error.SizeMismatch, decoder.step(frame[accepted..], &output));
        try std.testing.expectEqual(before.input_received, decoder.snapshot().input_received);
        try std.testing.expectEqual(before.output_written, decoder.snapshot().output_written);
        try std.testing.expectError(error.InvalidStreamState, decoder.provideDictionary(dictionary));
        decoder.reset();
        try std.testing.expectEqual(@as(?u32, null), decoder.requiredDictionaryId());
        try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().input_received);
        try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().output_written);
        try decoder.resetWithOptions(.{ .input_policy = policy, .expected_output_len = payload.len });
        const read = try request(&decoder, frame, frame.len);
        try decoder.provideDictionary(dictionary);
        try drainResumed(&decoder, frame, read, &output);
    }
}

test "LZ4 dictionary resume does not allocate on provide and distinguishes budget denial from OOM" {
    const frame = try encode(true, true);
    defer allocator.free(frame);
    for (policies) |policy| {
        var baseline = Decoder.initWithOptions(allocator, .{ .input_policy = policy, .max_output_len = payload.len });
        defer baseline.deinit();
        const read = try request(&baseline, frame, frame.len);
        try baseline.provideDictionary(dictionary);
        var output: [payload.len]u8 = undefined;
        try drainResumed(&baseline, frame, read, &output);
        const peak = baseline.peakWorkingMemoryBytes();
        var exact = Decoder.initWithOptions(allocator, .{ .input_policy = policy, .max_output_len = payload.len, .max_working_memory = peak });
        defer exact.deinit();
        const exact_read = try request(&exact, frame, frame.len);
        const waiting_live = exact.workingMemoryBytes();
        try exact.provideDictionary(dictionary);
        try std.testing.expectEqual(waiting_live, exact.workingMemoryBytes());
        try drainResumed(&exact, frame, exact_read, &output);
        var denied = Decoder.initWithOptions(allocator, .{ .input_policy = policy, .max_output_len = payload.len, .max_working_memory = peak - 1 });
        defer denied.deinit();
        const denied_read = try request(&denied, frame, frame.len);
        try denied.provideDictionary(dictionary);
        var offset = denied_read;
        var written: usize = 0;
        var failed = false;
        while (!failed) {
            const step = denied.step(frame[offset..], output[written..@min(output.len, written + 17)]) catch |err| {
                try std.testing.expectEqual(error.WorkingMemoryLimitExceeded, err);
                failed = true;
                break;
            };
            offset += step.progress.input_read;
            written += step.progress.output_written;
            try std.testing.expect(step.status != .done);
        }
        try std.testing.expect(denied.peakWorkingMemoryBytes() < peak);
        try std.testing.expectError(error.WorkingMemoryLimitExceeded, denied.step("", &output));
        try denied.resetWithOptions(.{ .input_policy = policy, .max_output_len = payload.len, .max_working_memory = peak });
        const retried = try request(&denied, frame, frame.len);
        try denied.provideDictionary(dictionary);
        try drainResumed(&denied, frame, retried, &output);
    }
    var backing = std.testing.FailingAllocator.init(allocator, .{});
    var decoder = Decoder.init(backing.allocator());
    defer decoder.deinit();
    const read = try request(&decoder, frame, frame.len);
    const allocation_count = backing.alloc_index;
    backing.fail_index = allocation_count;
    try decoder.provideDictionary(dictionary);
    try std.testing.expectEqual(allocation_count, backing.alloc_index);
    var output: [payload.len]u8 = undefined;
    try std.testing.expectError(error.OutOfMemory, decoder.step(frame[read..], &output));
    try std.testing.expectError(error.OutOfMemory, decoder.step(frame[read..], &output));
    backing.fail_index = std.math.maxInt(usize);
    decoder.reset();
    const new_read = try request(&decoder, frame, frame.len);
    try decoder.provideDictionary(dictionary);
    try drainResumed(&decoder, frame, new_read, &output);
}

test "LZ4 dictionary resume supports multiple independent and linked blocks across the history window" {
    const large = try allocator.alloc(u8, 2 * 64 * 1024 + 1024);
    defer allocator.free(large);
    for (large, 0..) |*byte, i| byte.* = dictionary.content[i % dictionary.content.len];
    for (policies) |policy| {
        for ([_]bool{ false, true }) |independent| {
            const frame = try lz4.encodeNativeFrameWithDictionaryAlloc(allocator, large, .{
                .block_mode = if (independent) .independent else .linked,
                .block_size_id = .max64kb,
                .block_checksum = true,
                .content_checksum = true,
            }, dictionary);
            defer allocator.free(frame);
            var decoder = Decoder.initWithOptions(allocator, .{ .input_policy = policy });
            defer decoder.deinit();
            const read = try request(&decoder, frame, frame.len);
            try decoder.provideDictionary(dictionary);
            const output = try allocator.alloc(u8, large.len);
            defer allocator.free(output);
            try drainResumed(&decoder, frame, read, output);
            try std.testing.expectEqualSlices(u8, large, output);
            try std.testing.expectEqual(@as(?u32, null), decoder.requiredDictionaryId());
            try std.testing.expect(decoder.direct_history.capacity <= 64 * 1024);
        }
    }
}

test "LZ4 dictionary resume resets pending requests and completes empty dictionary frames" {
    const empty = try lz4.encodeNativeFrameWithDictionaryAlloc(allocator, "", .{}, dictionary);
    defer allocator.free(empty);
    for (policies) |policy| {
        var decoder = Decoder.initWithOptions(allocator, .{ .input_policy = policy, .max_output_len = 0 });
        defer decoder.deinit();
        _ = try request(&decoder, empty, empty.len);
        try std.testing.expectError(error.InvalidStreamState, decoder.nextStream());
        decoder.reset();
        try std.testing.expectEqual(@as(?u32, null), decoder.requiredDictionaryId());
        try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().input_received);
        try std.testing.expectError(error.InvalidStreamState, decoder.provideDictionary(dictionary));
        const accepted = try request(&decoder, empty, empty.len);
        try decoder.provideDictionary(dictionary);
        try drainResumed(&decoder, empty, accepted, &.{});
        try std.testing.expectEqual(@as(?u32, null), decoder.requiredDictionaryId());
        try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().output_written);
        try std.testing.expectEqual(@as(?lz4.NativeDictionary, null), decoder.frame_dictionary_override);
    }
}

test "LZ4 dictionary resume rejects corrupt headers without trusting their dictionary request" {
    const frame = try encode(true, true);
    defer allocator.free(frame);
    const corrupt = try allocator.dupe(u8, frame);
    defer allocator.free(corrupt);
    const header = try lz4.inspectNativeFrameHeader(corrupt);
    corrupt[header.payload_offset - 1] ^= 1;
    for (policies) |policy| {
        var decoder = Decoder.initWithOptions(allocator, .{ .input_policy = policy });
        defer decoder.deinit();
        var output: [payload.len]u8 = undefined;
        try std.testing.expectError(error.ChecksumMismatch, decoder.step(corrupt, &output));
        try std.testing.expectEqual(@as(?u32, null), decoder.requiredDictionaryId());
        try std.testing.expectError(error.InvalidStreamState, decoder.provideDictionary(dictionary));
        const before = decoder.snapshot();
        try std.testing.expectError(error.ChecksumMismatch, decoder.step(corrupt, &output));
        try std.testing.expectEqual(before.input_received, decoder.snapshot().input_received);
        try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().output_written);
    }
}

fn appendWord(out: *std.ArrayList(u8), value: u32) !void {
    var bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &bytes, value, .little);
    try out.appendSlice(allocator, &bytes);
}

test "LZ4 dictionary resume retains dictionary history after a short linked raw block" {
    const first = "qwertyuiopasdfgh";
    const second = dictionary.content[0..1024];
    const history = try std.mem.concat(allocator, u8, &.{ dictionary.content, first });
    defer allocator.free(history);
    const compressed = try lz4.encodeBlockWithPrefixAlloc(allocator, second, history);
    defer allocator.free(compressed);
    try std.testing.expectEqual(@as(u8, 0), compressed[0] >> 4);
    try std.testing.expect(std.mem.readInt(u16, compressed[1..3], .little) > first.len);
    const template = try lz4.encodeNativeFrameWithDictionaryAlloc(allocator, "", .{
        .include_content_size = false,
        .block_mode = .linked,
        .block_checksum = true,
        .content_checksum = true,
    }, dictionary);
    defer allocator.free(template);
    const header = try lz4.inspectNativeFrameHeader(template);
    const expected = try std.mem.concat(allocator, u8, &.{ first, second });
    defer allocator.free(expected);
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(allocator);
    try frame.appendSlice(allocator, template[0..header.payload_offset]);
    try appendWord(&frame, 0x8000_0000 | @as(u32, first.len));
    try frame.appendSlice(allocator, first);
    try appendWord(&frame, std.hash.XxHash32.hash(0, first));
    try appendWord(&frame, @intCast(compressed.len));
    try frame.appendSlice(allocator, compressed);
    try appendWord(&frame, std.hash.XxHash32.hash(0, compressed));
    try appendWord(&frame, 0);
    try appendWord(&frame, std.hash.XxHash32.hash(0, expected));
    for (policies) |policy| {
        var decoder = Decoder.initWithOptions(allocator, .{ .input_policy = policy });
        defer decoder.deinit();
        const accepted = try request(&decoder, frame.items, frame.items.len);
        try decoder.provideDictionary(dictionary);
        const output = try allocator.alloc(u8, expected.len);
        defer allocator.free(output);
        try drainResumed(&decoder, frame.items, accepted, output);
        try std.testing.expectEqualSlices(u8, expected, output);
    }
}

test "LZ4 dictionary resume provided catalog leaves the configured next member catalog intact" {
    const other_dictionary = lz4.NativeDictionary.init(9, "other dictionary" ** 64);
    const other_payload = other_dictionary.content[0..128];
    const first = try encode(true, false);
    defer allocator.free(first);
    const second = try lz4.encodeNativeFrameWithDictionaryAlloc(allocator, other_payload, .{
        .include_content_size = false,
        .block_checksum = true,
        .content_checksum = true,
    }, other_dictionary);
    defer allocator.free(second);
    const stream = try std.mem.concat(allocator, u8, &.{ first, second, first });
    defer allocator.free(stream);
    for (policies) |policy| {
        var decoder = Decoder.initWithDictionarySetAndOptions(allocator, lz4.NativeDictionarySet.init(&.{other_dictionary}), .{
            .input_policy = policy,
            .expected_output_len = payload.len * 2 + other_payload.len,
        });
        defer decoder.deinit();
        const read = try request(&decoder, stream, stream.len);
        {
            // This temporary catalog's B entry must never replace configured B.
            const supplied = [_]lz4.NativeDictionary{ dictionary, lz4.NativeDictionary.init(other_dictionary.id, "wrong B bytes") };
            try decoder.provideDictionarySet(lz4.NativeDictionarySet.init(&supplied));
        }
        var output: [payload.len * 2 + other_payload.len]u8 = undefined;
        try std.testing.expectError(error.NeedDictionary, decoder.step(stream[read..], &output));
        try std.testing.expectEqual(@as(usize, payload.len + other_payload.len), decoder.snapshot().last_step_progress.output_written);
        try std.testing.expectEqualSlices(u8, payload, output[0..payload.len]);
        try std.testing.expectEqualSlices(u8, other_payload, output[payload.len..][0..other_payload.len]);
        try std.testing.expectEqual(@as(?u32, dictionary.id), decoder.requiredDictionaryId());
        const accepted = decoder.snapshot().input_received;
        try decoder.provideDictionary(dictionary);
        try drainResumed(&decoder, stream, accepted, output[payload.len + other_payload.len ..]);
        try std.testing.expectEqualSlices(u8, payload, output[payload.len + other_payload.len ..]);
    }
}
