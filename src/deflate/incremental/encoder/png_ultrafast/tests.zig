const std = @import("std");
const Encoder = @import("root.zig").Encoder;
const deflate = @import("../../../../deflate.zig");
const reference = @import("reference_cases.zig");

test "incremental PNG ultrafast matches actual fdeflate payload with independently parsed final block framing" {
    inline for (reference.cases) |case| {
        const input = try std.testing.allocator.alloc(u8, case.source_hex.len / 2);
        defer std.testing.allocator.free(input);
        _ = try std.fmt.hexToBytes(input, case.source_hex);
        const expected = try std.testing.allocator.alloc(u8, case.expected_hex.len / 2);
        defer std.testing.allocator.free(expected);
        _ = try std.fmt.hexToBytes(expected, case.expected_hex);
        const actual = try encode(input, 7, 1, null);
        defer std.testing.allocator.free(actual);
        try std.testing.expectEqualSlices(u8, expected, actual);
    }
}

fn encode(input: []const u8, partition: usize, capacity: usize, flush_at: ?usize) ![]u8 {
    var encoder = Encoder.initExactSize(std.testing.failing_allocator, .{}, input.len);
    defer encoder.deinit();
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(std.testing.allocator);
    var scratch: [4096]u8 = undefined;
    var offset: usize = 0;
    var flushed = false;
    while (offset != input.len) {
        const end = @min(input.len, offset + partition);
        const next = try encoder.step(input[offset..end], scratch[0..capacity]);
        offset += next.progress.input_read;
        try out.appendSlice(std.testing.allocator, scratch[0..next.progress.output_written]);
        try std.testing.expect(next.progress.input_read != 0 or next.progress.output_written != 0);
        if (flush_at) |at| {
            if (!flushed and offset >= at) {
                encoder.flush();
                while (true) {
                    const drain = try encoder.step(&.{}, scratch[0..capacity]);
                    try out.appendSlice(std.testing.allocator, scratch[0..drain.progress.output_written]);
                    if (drain.status == .need_input) break;
                    try std.testing.expectEqual(@as(usize, 0), drain.progress.input_read);
                    try std.testing.expect(drain.progress.output_written != 0);
                }
                flushed = true;
            }
        }
    }
    encoder.finish();
    while (true) {
        const next = try encoder.step(&.{}, scratch[0..capacity]);
        try out.appendSlice(std.testing.allocator, scratch[0..next.progress.output_written]);
        if (next.status == .done) break;
        try std.testing.expect(next.progress.output_written != 0);
    }
    try std.testing.expectEqual(input.len, encoder.snapshot().input_read);
    try std.testing.expectEqual(out.items.len, encoder.snapshot().output_written);
    try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().pending_output);
    try std.testing.expectEqual(@as(u6, 0), encoder.snapshot().pending_bits);
    return out.toOwnedSlice(std.testing.allocator);
}

test "incremental PNG ultrafast is partition independent across zero and word boundaries without heap allocations" {
    var input: [8701]u8 = @splat(0);
    for (&input, 0..) |*value, at| {
        if (at % 337 < 4) value.* = @truncate(at);
    }
    const expected = try encode(&input, input.len, 4096, null);
    defer std.testing.allocator.free(expected);
    for ([_]usize{ 1, 7, 8, 257, 258, 259, 4096 }) |partition| {
        for ([_]usize{ 1, 2, 7, 128 }) |capacity| {
            const actual = try encode(&input, partition, capacity, null);
            defer std.testing.allocator.free(actual);
            try std.testing.expectEqualSlices(u8, expected, actual);
        }
    }
    const decoded = try deflate.decodeZlibAlloc(std.testing.allocator, expected);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &input, decoded);
}

test "incremental PNG ultrafast sync flush continues one stream across partial word and zero runs" {
    var input: [919]u8 = @splat(0);
    input[0] = 18;
    input[8] = 39;
    input[518] = 255;
    for ([_]usize{ 1, 7, 8, 257, 258, 259, 518 }) |at| {
        const actual = try encode(&input, 1, 1, at);
        defer std.testing.allocator.free(actual);
        const decoded = try deflate.decodeZlibAlloc(std.testing.allocator, actual);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, &input, decoded);
        try std.testing.expect(actual[1] & 0x20 == 0);
    }
}

test "incremental PNG ultrafast zero output empty finish and limits return exact progress and preflight errors" {
    var encoder = Encoder.initExactSize(std.testing.failing_allocator, .{ .max_input_len = 3 }, 2);
    defer encoder.deinit();
    var none: [0]u8 = .{};
    try std.testing.expectError(error.SizeMismatch, encoder.step("123", &none));
    try std.testing.expectEqual(@as(usize, 0), encoder.total_input);
    try std.testing.expectEqual(@as(usize, 0), encoder.pending_len);
    const first = try encoder.step("12", &none);
    try std.testing.expectEqual(@as(usize, 0), first.progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), first.progress.output_written);
    var scratch: [128]u8 = undefined;
    const next = try encoder.step("12", &scratch);
    try std.testing.expectEqual(@as(usize, 2), next.progress.input_read);
    encoder.finish();
    while ((try encoder.step(&.{}, &scratch)).status != .done) {}
    try std.testing.expectEqual(@import("../../../../core.zig").StepResult.Status.done, (try encoder.step(&.{}, &none)).status);
    try std.testing.expectError(error.TrailingData, encoder.step("x", &scratch));
    encoder.reset();
    encoder.finish();
    try std.testing.expectError(error.SizeMismatch, encoder.step(&.{}, &scratch));
    encoder.reset();
    encoder.options.max_input_len = 1;
    try std.testing.expectError(error.OutputLimitExceeded, encoder.step("12", &scratch));
    encoder.options.max_input_len = std.math.maxInt(usize);
    encoder.expected_input_len = null;
    encoder.total_input = std.math.maxInt(usize);
    try std.testing.expectError(error.IntegerOverflow, encoder.step("x", &scratch));
    encoder.reset();
    encoder.expected_input_len = 5;
    encoder.options.max_input_len = 4;
    try std.testing.expectError(error.OutputLimitExceeded, encoder.step(&.{}, &scratch));
    try std.testing.expectEqual(@as(usize, 0), encoder.pending_len);
    encoder.reset();
    encoder.expected_input_len = null;
    encoder.total_output = std.math.maxInt(usize);
    try std.testing.expectError(error.IntegerOverflow, encoder.step(&.{}, &scratch));
    const empty = try encode("", 1, 1, null);
    defer std.testing.allocator.free(empty);
    const decoded = try deflate.decodeZlibAlloc(std.testing.allocator, empty);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqual(@as(usize, 0), decoded.len);
}

test "incremental PNG ultrafast repeated empty sync flush drains without ending zlib" {
    var encoder = Encoder.initExactSize(std.testing.failing_allocator, .{}, 0);
    defer encoder.deinit();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(std.testing.allocator);
    var one: [1]u8 = undefined;
    for (0..3) |_| {
        encoder.flush();
        while (true) {
            const next = try encoder.step(&.{}, &one);
            try out.appendSlice(std.testing.allocator, one[0..next.progress.output_written]);
            if (next.status == .need_input) break;
            try std.testing.expectEqual(@as(usize, 1), next.progress.output_written);
        }
        try std.testing.expect(!encoder.snapshot().done and !encoder.snapshot().flushing);
    }
    encoder.finish();
    while (true) {
        const next = try encoder.step(&.{}, &one);
        try out.appendSlice(std.testing.allocator, one[0..next.progress.output_written]);
        if (next.status == .done) break;
        try std.testing.expectEqual(@as(usize, 1), next.progress.output_written);
    }
    const decoded = try deflate.decodeZlibAlloc(std.testing.allocator, out.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqual(@as(usize, 0), decoded.len);
}
