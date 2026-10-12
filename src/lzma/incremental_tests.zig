const std = @import("std");
const core = @import("../core.zig");
const lzma = @import("../lzma.zig");

const python_frame_hex = "5d00008000ffffffffffffffff00341949ee8de9148a6aa5d5e0718be227a7ffffdac50000";
const python_payload = "hello lzma\n" ** 16 ++ "hell";

test "LZMA incremental decoder accepts byte input and tiny output" {
    const unknown = pythonFrame();
    var decoder = lzma.IncrementalDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = python_payload.len,
        .max_output_len = python_payload.len,
        .max_dictionary_size = 8 * 1024 * 1024,
    });
    defer decoder.deinit();
    const decoded = try decodeSplit(&decoder, &unknown, 1, 7, null);
    defer std.testing.allocator.free(decoded.bytes);
    try std.testing.expectEqualSlices(u8, python_payload, decoded.bytes);
    try std.testing.expect(decoder.snapshot().saw_end_marker);
    try std.testing.expectEqual(lzma.IncrementalDecoder.Phase.done, decoder.snapshot().phase);
    try std.testing.expect(decoder.snapshot().retained_compressed_capacity <= 64);

    decoder.reset();
    try std.testing.expectEqual(lzma.IncrementalDecoder.Phase.header, decoder.snapshot().phase);
    try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().output_written);
}

test "LZMA incremental decoder produces output before finish" {
    const input = try std.testing.allocator.alloc(u8, 4096);
    defer std.testing.allocator.free(input);
    var state: u32 = 0x6c7a_6d61;
    for (input) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    const encoded = try lzma.encodeAlloc(std.testing.allocator, input, .{
        .dictionary_size = 32 * 1024,
        .size_mode = .end_marker,
    });
    defer std.testing.allocator.free(encoded);
    try std.testing.expect(encoded.len > 64 + 13);

    var decoder = lzma.IncrementalDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = input.len,
        .max_output_len = input.len,
        .max_dictionary_size = 32 * 1024,
    });
    defer decoder.deinit();
    const decoded = try decodeSplit(&decoder, encoded, 17, 11, input.len / 2);
    defer std.testing.allocator.free(decoded.bytes);
    try std.testing.expect(decoded.output_before_finish);
    try std.testing.expectEqualSlices(u8, input, decoded.bytes);
}

test "LZMA incremental decoder supports known-size streams and trailing range bytes" {
    const input = "known-size incremental LZMA" ** 64;
    const encoded = try lzma.encodeAlloc(std.testing.allocator, input, .{
        .size_mode = .known,
    });
    defer std.testing.allocator.free(encoded);
    var with_trailing: std.ArrayList(u8) = .empty;
    defer with_trailing.deinit(std.testing.allocator);
    try with_trailing.appendSlice(std.testing.allocator, encoded);
    try with_trailing.appendSlice(std.testing.allocator, "accepted-known-size-tail");

    var decoder = lzma.IncrementalDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = input.len,
    });
    defer decoder.deinit();
    const decoded = try decodeSplit(&decoder, with_trailing.items, 5, 9, null);
    defer std.testing.allocator.free(decoded.bytes);
    try std.testing.expectEqualSlices(u8, input, decoded.bytes);
    try std.testing.expect(!decoder.snapshot().saw_end_marker);

    var wrong_size = lzma.IncrementalDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = input.len + 1,
    });
    defer wrong_size.deinit();
    var scratch: [16]u8 = undefined;
    try std.testing.expectError(error.SizeMismatch, wrong_size.step(encoded, &scratch));
}

test "LZMA incremental decoder rejects trailing bytes after end marker" {
    const frame = pythonFrame();
    var trailing: [frame.len + 1]u8 = undefined;
    @memcpy(trailing[0..frame.len], &frame);
    trailing[frame.len] = 0;
    var decoder = lzma.IncrementalDecoder.init(std.testing.allocator);
    defer decoder.deinit();
    var output: [python_payload.len]u8 = undefined;
    _ = try decoder.step(&trailing, &output);
    decoder.finish();
    try std.testing.expectError(error.TrailingData, drainFinished(&decoder, &output));
}

test "LZMA incremental decoder honors zero-output backpressure" {
    const frame = pythonFrame();
    var decoder = lzma.IncrementalDecoder.init(std.testing.allocator);
    defer decoder.deinit();
    _ = try decoder.step(&frame, &.{});
    decoder.finish();
    const blocked = try decoder.step("", &.{});
    try std.testing.expectEqual(core.StepResult.Status.need_output, blocked.status);
    try std.testing.expect(blocked.progress.output_written == 0);
    try std.testing.expect(decoder.snapshot().pending_output != 0);
    var output: [python_payload.len]u8 = undefined;
    try drainFinished(&decoder, &output);
    try std.testing.expectEqualSlices(u8, python_payload, &output);
}

test "LZMA incremental decoder enforces input output dictionary and exact limits" {
    const frame = pythonFrame();
    var output: [python_payload.len]u8 = undefined;

    var dictionary_limited = lzma.IncrementalDecoder.initWithOptions(std.testing.allocator, .{
        .max_dictionary_size = 1024 * 1024,
    });
    defer dictionary_limited.deinit();
    try std.testing.expectError(error.OutputLimitExceeded, dictionary_limited.step(&frame, &output));

    var compressed_limited = lzma.IncrementalDecoder.initWithOptions(std.testing.allocator, .{
        .max_compressed_buffer_len = 8,
    });
    defer compressed_limited.deinit();
    try std.testing.expectError(error.OutputLimitExceeded, compressed_limited.step(&frame, &output));

    var output_limited = lzma.IncrementalDecoder.initWithOptions(std.testing.allocator, .{
        .max_output_len = python_payload.len - 1,
    });
    defer output_limited.deinit();
    _ = try output_limited.step(&frame, &output);
    output_limited.finish();
    try std.testing.expectError(error.OutputLimitExceeded, drainFinished(&output_limited, &output));

    var exact_short = lzma.IncrementalDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = python_payload.len - 1,
    });
    defer exact_short.deinit();
    _ = try exact_short.step(&frame, &output);
    exact_short.finish();
    try std.testing.expectError(error.SizeMismatch, drainFinished(&exact_short, &output));

    var exact_long = lzma.IncrementalDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = python_payload.len + 1,
    });
    defer exact_long.deinit();
    _ = try exact_long.step(&frame, &output);
    exact_long.finish();
    try std.testing.expectError(error.SizeMismatch, drainFinished(&exact_long, &output));
}

test "LZMA incremental decoder reports every truncated unknown-size prefix" {
    const frame = pythonFrame();
    var output: [31]u8 = undefined;
    for (0..frame.len) |cut| {
        var decoder = lzma.IncrementalDecoder.init(std.testing.allocator);
        defer decoder.deinit();
        var offset: usize = 0;
        while (offset < cut) {
            const result = try decoder.step(frame[offset..cut], &output);
            offset += result.progress.input_read;
        }
        decoder.finish();
        try std.testing.expectError(error.TruncatedFrame, drainFinishedDiscard(&decoder, &output));
        try std.testing.expectEqualStrings("truncated_input", decoder.diagnostics().recoverability_hint_name);
    }
}

test "LZMA incremental decoder releases every allocation failure" {
    const frame = pythonFrame();
    const Test = struct {
        fn run(allocator: std.mem.Allocator, encoded: []const u8) !void {
            var decoder = lzma.IncrementalDecoder.initWithOptions(allocator, .{
                .expected_output_len = python_payload.len,
            });
            defer decoder.deinit();
            const output = try allocator.alloc(u8, python_payload.len);
            defer allocator.free(output);
            _ = try decoder.step(encoded, output);
            decoder.finish();
            try drainFinished(&decoder, output);
            try std.testing.expectEqualSlices(u8, python_payload, output);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Test.run, .{frame[0..]});
}

const SplitResult = struct {
    bytes: []u8,
    output_before_finish: bool,
};

fn decodeSplit(
    decoder: *lzma.IncrementalDecoder,
    encoded: []const u8,
    input_chunk_len: usize,
    output_chunk_len: usize,
    before_finish_threshold: ?usize,
) !SplitResult {
    var decoded: std.ArrayList(u8) = .empty;
    errdefer decoded.deinit(std.testing.allocator);
    const scratch = try std.testing.allocator.alloc(u8, output_chunk_len);
    defer std.testing.allocator.free(scratch);
    var input_offset: usize = 0;
    var output_before_finish = false;
    while (input_offset < encoded.len) {
        const input_end = @min(encoded.len, input_offset + input_chunk_len);
        const result = try decoder.step(encoded[input_offset..input_end], scratch);
        input_offset += result.progress.input_read;
        try decoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.progress.output_written != 0 and
            input_offset < (before_finish_threshold orelse encoded.len))
            output_before_finish = true;
    }
    decoder.finish();
    while (true) {
        const result = try decoder.step("", scratch);
        try decoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .done) break;
        try std.testing.expectEqual(core.StepResult.Status.need_output, result.status);
    }
    return .{
        .bytes = try decoded.toOwnedSlice(std.testing.allocator),
        .output_before_finish = output_before_finish,
    };
}

fn drainFinished(decoder: *lzma.IncrementalDecoder, output: []u8) !void {
    var output_offset: usize = 0;
    while (true) {
        const result = try decoder.step("", output[output_offset..]);
        output_offset += result.progress.output_written;
        switch (result.status) {
            .done => return,
            .need_input => return error.TestUnexpectedResult,
            .need_output => if (output_offset == output.len) return error.TestUnexpectedResult,
        }
    }
}

fn drainFinishedDiscard(decoder: *lzma.IncrementalDecoder, output: []u8) !void {
    while (true) {
        const result = try decoder.step("", output);
        if (result.status == .done) return;
    }
}

fn pythonFrame() [python_frame_hex.len / 2]u8 {
    var bytes: [python_frame_hex.len / 2]u8 = undefined;
    _ = std.fmt.hexToBytes(&bytes, python_frame_hex) catch unreachable;
    return bytes;
}
