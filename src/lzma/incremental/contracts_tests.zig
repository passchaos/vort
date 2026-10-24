const std = @import("std");
const lzma = @import("../../lzma.zig");
const core = @import("../../core.zig");
const allocator = std.testing.allocator;
const python_hex = "5d00008000ffffffffffffffff00341949ee8de9148a6aa5d5e0718be227a7ffffdac50000";
pub const python_plain = "hello lzma\n" ** 16 ++ "hell";

pub fn pythonFrame() [python_hex.len / 2]u8 {
    var bytes: [python_hex.len / 2]u8 = undefined;
    _ = std.fmt.hexToBytes(&bytes, python_hex) catch unreachable;
    return bytes;
}

pub const Trace = struct { failure: ?anyerror = null, input_read: usize = 0, output_written: usize = 0, peak: usize = 0 };

pub fn drive(decoder: *lzma.IncrementalDecoder, encoded: []const u8, expected: []const u8, input_chunk: usize, output_chunk: usize) !Trace {
    var trace = Trace{};
    var output: [257]u8 = undefined;
    var finished = decoder.input_finished;
    var calls: usize = 0;
    while (true) : (calls += 1) {
        try std.testing.expect(calls < (encoded.len + expected.len + 1) * 16 + 256);
        if (trace.input_read == encoded.len and !finished) {
            decoder.finish();
            finished = true;
        }
        const offered = encoded[trace.input_read..][0..@min(input_chunk, encoded.len - trace.input_read)];
        @memset(&output, 0xa5);
        const target = output[0..if (calls % 5 == 0) 0 else output_chunk];
        const before = decoder.snapshot();
        const stepped = decoder.step(offered, target) catch |err| {
            const after = decoder.snapshot();
            try account(&trace, decoder, before, after.last_step_progress, offered.len, target, expected);
            try std.testing.expectEqual(@as(?usize, after.input_read), after.error_input_offset);
            try std.testing.expectEqual(@as(?usize, after.output_written), after.error_output_offset);
            trace.failure = err;
            return trace;
        };
        try account(&trace, decoder, before, stepped.progress, offered.len, target, expected);
        if (stepped.status == .done) return trace;
    }
}

pub fn account(trace: *Trace, decoder: *const lzma.IncrementalDecoder, before: lzma.IncrementalDecoder.Snapshot, progress: core.Progress, offered_len: usize, output: []const u8, expected: []const u8) !void {
    const after = decoder.snapshot();
    try std.testing.expect(progress.input_read <= offered_len and progress.output_written <= output.len);
    try std.testing.expectEqual(after.input_read - before.input_read, progress.input_read);
    try std.testing.expectEqual(after.output_written - before.output_written, progress.output_written);
    try std.testing.expectEqualDeep(progress, after.last_step_progress);
    try std.testing.expectEqualDeep(progress, decoder.diagnostics().last_step_progress.?);
    try std.testing.expectEqual(core.stream_count.fromOptionalLocal(after.error_input_offset), decoder.diagnostics().error_input_offset);
    try std.testing.expectEqual(core.stream_count.fromOptionalLocal(after.error_output_offset), decoder.diagnostics().error_output_offset);
    try std.testing.expect(progress.output_written <= expected.len - trace.output_written);
    try std.testing.expectEqualSlices(u8, expected[trace.output_written..][0..progress.output_written], output[0..progress.output_written]);
    for (output[progress.output_written..]) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
    trace.input_read += progress.input_read;
    trace.output_written += progress.output_written;
    trace.peak = @max(trace.peak, after.peak_working_bytes);
    try std.testing.expectEqual(@as(usize, 273), after.retained_output_capacity);
    try std.testing.expect(after.pending_output <= 273);
    try std.testing.expect(after.retained_compressed_capacity <= decoder.options.max_compressed_buffer_len);
    try std.testing.expect(after.working_bytes <= decoder.options.max_working_memory);
    try std.testing.expect(after.peak_working_bytes <= decoder.options.max_working_memory);
    try std.testing.expectEqual(after.working_bytes, decoder.workingMemoryBytes());
    try std.testing.expectEqual(after.peak_working_bytes, decoder.peakWorkingMemoryBytes());
}

pub fn expectComplete(trace: Trace, encoded_len: usize, raw_len: usize) !void {
    try std.testing.expectEqual(@as(?anyerror, null), trace.failure);
    try std.testing.expectEqual(encoded_len, trace.input_read);
    try std.testing.expectEqual(raw_len, trace.output_written);
}

pub fn expectSticky(decoder: *lzma.IncrementalDecoder, err: anyerror) !void {
    const before = decoder.snapshot();
    var output: [17]u8 = @splat(0xa5);
    try std.testing.expectError(err, decoder.step("unused bytes", &output));
    const after = decoder.snapshot();
    try std.testing.expectEqual(before.input_read, after.input_read);
    try std.testing.expectEqual(before.output_written, after.output_written);
    try std.testing.expectEqualDeep(core.Progress{}, after.last_step_progress);
    try std.testing.expectEqual(@as([17]u8, @splat(0xa5)), output);
}

test "LZMA stream contracts fixed staging and all publication counters match host fixture fragmentation" {
    const frame = pythonFrame();
    for ([_]usize{ 1, 17, frame.len }) |input_chunk| {
        var decoder = lzma.IncrementalDecoder.initWithOptions(allocator, .{ .max_working_memory = 64 * 1024 });
        defer decoder.deinit();
        try expectComplete(try drive(&decoder, &frame, python_plain, input_chunk, 7), frame.len, python_plain.len);
    }
}

test "LZMA stream contracts zero output never commits the next positive symbol or allocates history" {
    const frame = pythonFrame();
    var decoder = lzma.IncrementalDecoder.initWithOptions(allocator, .{ .stop_after_end_marker = true, .end_marker_input_guard = 1 });
    defer decoder.deinit();
    const accepted = try decoder.step(frame[0..18], &.{});
    try std.testing.expectEqual(@as(usize, 18), accepted.progress.input_read);
    const state = decoder.decoder.?;
    const probabilities = try allocator.dupe(u16, state.literal_probs.data);
    defer allocator.free(probabilities);
    const range = decoder.range_decoder.?;
    const capacity = decoder.snapshot().retained_dictionary_capacity;
    const blocked = try decoder.step(frame[18..], &.{});
    try std.testing.expectEqual(core.StepResult.Status.need_output, blocked.status);
    try std.testing.expectEqual(@as(usize, 0), blocked.progress.output_written);
    try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().validated_output);
    try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().pending_output);
    try std.testing.expectEqual(capacity, decoder.snapshot().retained_dictionary_capacity);
    try std.testing.expectEqualDeep(state, decoder.decoder.?);
    try std.testing.expectEqualSlices(u16, probabilities, decoder.decoder.?.literal_probs.data);
    try std.testing.expectEqualDeep(range, decoder.range_decoder.?);
}

test "LZMA stream contracts empty and full output quotas can parse zero output EOS" {
    const empty = try lzma.encodeAlloc(allocator, "", .{ .size_mode = .end_marker });
    defer allocator.free(empty);
    var decoder = lzma.IncrementalDecoder.initWithOptions(allocator, .{ .max_output_len = 0, .expected_output_len = 0 });
    defer decoder.deinit();
    var offset: usize = 0;
    var finished = false;
    while (true) {
        if (offset == empty.len and !finished) {
            decoder.finish();
            finished = true;
        }
        const step = try decoder.step(empty[offset..], &.{});
        offset += step.progress.input_read;
        try std.testing.expectEqual(@as(usize, 0), step.progress.output_written);
        if (step.status == .done) break;
    }
    try std.testing.expectEqual(empty.len, offset);
    try std.testing.expect(decoder.snapshot().saw_end_marker);
    decoder.resetWithOptions(.{ .max_output_len = python_plain.len, .expected_output_len = python_plain.len });
    const frame = pythonFrame();
    try expectComplete(try drive(&decoder, &frame, python_plain, 1, 1), frame.len, python_plain.len);
}

test "LZMA stream contracts small guards preserve short unknown tail and matched literal nonzero LP rows" {
    const short = pythonFrame();
    const suffix = "ZIP descriptor following EOS!";
    const plain = "abra-1234-abra-X234-abra-123Y-abra-1234\n" ** 32;
    const encoded = try lzma.encodeAlloc(allocator, plain, .{ .properties = .{ .lc = 3, .lp = 1, .pb = 2 }, .dictionary_size = 4096, .size_mode = .end_marker });
    defer allocator.free(encoded);
    for ([_]usize{ 1, 12, 16 }) |guard| {
        for ([_]struct { encoded: []const u8, expected: []const u8 }{
            .{ .encoded = &short, .expected = python_plain },
            .{ .encoded = encoded, .expected = plain },
        }) |sample| {
            var joined: std.ArrayList(u8) = .empty;
            defer joined.deinit(allocator);
            try joined.appendSlice(allocator, sample.encoded);
            try joined.appendSlice(allocator, suffix);
            var decoder = lzma.IncrementalDecoder.initWithOptions(allocator, .{ .stop_after_end_marker = true, .end_marker_input_guard = guard, .expected_output_len = sample.expected.len });
            defer decoder.deinit();
            const trace = try drive(&decoder, joined.items, sample.expected, joined.items.len, 13);
            try std.testing.expectEqual(@as(?anyerror, null), trace.failure);
            try std.testing.expectEqual(sample.expected.len, trace.output_written);
            var recovered: std.ArrayList(u8) = .empty;
            defer recovered.deinit(allocator);
            try recovered.appendSlice(allocator, decoder.trailingInput());
            try recovered.appendSlice(allocator, joined.items[trace.input_read..]);
            try std.testing.expectEqualSlices(u8, suffix, recovered.items);
        }
    }
}

test "LZMA stream contracts known size still consumes remaining coded caller bytes and seals only at EOF" {
    const plain = "known-size range tail" ** 32;
    const encoded = try lzma.encodeAlloc(allocator, plain, .{ .size_mode = .known });
    defer allocator.free(encoded);
    var joined: std.ArrayList(u8) = .empty;
    defer joined.deinit(allocator);
    try joined.appendSlice(allocator, encoded);
    try joined.appendSlice(allocator, "retained known-size semantics");
    var decoder = lzma.IncrementalDecoder.init(allocator);
    defer decoder.deinit();
    try expectComplete(try drive(&decoder, joined.items, plain, 5, 11), joined.items.len, plain.len);
    try std.testing.expect(!decoder.snapshot().saw_end_marker);
    try std.testing.expectEqual(joined.items.len, decoder.snapshot().input_read);
}

test "LZMA stream contracts truncation size quotas and tail errors report actual published prefix" {
    const frame = pythonFrame();
    for (0..frame.len) |cut| {
        var decoder = lzma.IncrementalDecoder.init(allocator);
        defer decoder.deinit();
        const trace = try drive(&decoder, frame[0..cut], python_plain, 3, 7);
        try std.testing.expectEqual(@as(?anyerror, error.TruncatedFrame), trace.failure);
        try expectSticky(&decoder, error.TruncatedFrame);
    }
    for ([_]lzma.IncrementalDecoder.Options{
        .{ .max_output_len = python_plain.len - 1 },
        .{ .expected_output_len = python_plain.len - 1 },
        .{ .expected_output_len = python_plain.len + 1 },
    }, [_]anyerror{ error.OutputLimitExceeded, error.SizeMismatch, error.SizeMismatch }) |options, err| {
        var decoder = lzma.IncrementalDecoder.initWithOptions(allocator, options);
        defer decoder.deinit();
        const trace = try drive(&decoder, &frame, python_plain, frame.len, 17);
        try std.testing.expectEqual(@as(?anyerror, err), trace.failure);
        try expectSticky(&decoder, err);
    }
    var joined: std.ArrayList(u8) = .empty;
    defer joined.deinit(allocator);
    try joined.appendSlice(allocator, &frame);
    try joined.append(allocator, 0);
    var decoder = lzma.IncrementalDecoder.init(allocator);
    defer decoder.deinit();
    const trace = try drive(&decoder, joined.items, python_plain, 5, 7);
    try std.testing.expectEqual(@as(?anyerror, error.TrailingData), trace.failure);
    try std.testing.expectEqual(python_plain.len, trace.output_written);
}

test "LZMA stream contracts incomplete small guard leaves original probabilities range and history unchanged" {
    var plain: [512]u8 = undefined;
    var random = std.Random.DefaultPrng.init(0x12_1630);
    random.random().bytes(&plain);
    const encoded = try lzma.encodeAlloc(allocator, &plain, .{ .properties = .{ .lc = 3, .lp = 1, .pb = 2 }, .dictionary_size = 4096 });
    defer allocator.free(encoded);
    var decoder = lzma.IncrementalDecoder.initWithOptions(allocator, .{ .stop_after_end_marker = true, .end_marker_input_guard = 1 });
    defer decoder.deinit();
    _ = try decoder.step(encoded[0..18], &.{});
    var offset: usize = 18;
    var published: usize = 0;
    var observed_incomplete = false;
    var output: [1]u8 = undefined;
    while (decoder.phase != .done) {
        if (offset == encoded.len) decoder.finish();
        const before = decoder.decoder.?;
        const before_range = decoder.range_decoder.?;
        const probabilities = try allocator.dupe(u16, before.literal_probs.data);
        defer allocator.free(probabilities);
        const dictionary_len = decoder.dictionary.?.len;
        const stepped = try decoder.step(encoded[offset..][0..@min(1, encoded.len - offset)], &output);
        offset += stepped.progress.input_read;
        if (stepped.progress.output_written != 0) {
            try std.testing.expectEqual(plain[published], output[0]);
            published += 1;
        }
        if (stepped.status == .need_input and stepped.progress.output_written == 0 and decoder.phase == .decode) {
            try std.testing.expectEqualDeep(before, decoder.decoder.?);
            try std.testing.expectEqualSlices(u16, probabilities, decoder.decoder.?.literal_probs.data);
            try std.testing.expectEqualDeep(before_range, decoder.range_decoder.?);
            try std.testing.expectEqual(dictionary_len, decoder.dictionary.?.len);
            observed_incomplete = true;
        }
    }
    try std.testing.expect(observed_incomplete);
    try std.testing.expectEqual(plain.len, published);
}
