const std = @import("std");
const br = @import("../../br.zig");

fn drainSplit(encoded: []const u8, expected: []const u8, history: []u8, input_chunk_len: usize, output_chunk_len: usize) !void {
    var decoder = br.IncrementalCopyStreamDecoder.initWithOptions(history, .{
        .max_output_len = expected.len,
        .expected_output_len = expected.len,
    });
    const decoded = try std.testing.allocator.alloc(u8, expected.len);
    defer std.testing.allocator.free(decoded);
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (decoder.snapshot().phase != .done) {
        const input_end = @min(encoded.len, input_offset + input_chunk_len);
        const output_end = @min(decoded.len, output_offset + output_chunk_len);
        const step = try decoder.step(encoded[input_offset..input_end], decoded[output_offset..output_end]);
        input_offset += step.progress.input_read;
        output_offset += step.progress.output_written;
    }
    try decoder.finish();
    try std.testing.expectEqual(encoded.len, input_offset);
    try std.testing.expectEqual(expected.len, output_offset);
    try std.testing.expectEqualSlices(u8, expected, decoded);
}

test "byte-progressive compressed copy decoder resumes overlapping copies" {
    inline for (.{ 5, 71, 1097, 65_536 }) |len| {
        const encoded = try br.encodeAlternatingStreamAlloc(std.testing.allocator, 'x', 'y', len);
        defer std.testing.allocator.free(encoded);
        const expected = try std.testing.allocator.alloc(u8, len);
        defer std.testing.allocator.free(expected);
        for (expected, 0..) |*byte, i| byte.* = "xy"[i & 1];
        var history: [2]u8 = undefined;
        try drainSplit(encoded, expected, &history, 1, 3);
    }
}

test "byte-progressive compressed copy decoder handles repeated commands and history wrap" {
    const cases = .{
        .{ "xy", 31 },
        .{ "xyz", 31 },
        .{ "abcd", 8193 },
    };
    inline for (cases) |case| {
        const prefix, const repeats = case;
        const encoded = try br.encodeRepeatedPrefixStreamAlloc(std.testing.allocator, prefix, repeats);
        defer std.testing.allocator.free(encoded);
        const expected = try std.testing.allocator.alloc(u8, prefix.len * repeats);
        defer std.testing.allocator.free(expected);
        for (expected, 0..) |*byte, i| byte.* = prefix[i % prefix.len];
        var history: [4]u8 = undefined;
        try drainSplit(encoded, expected, &history, 1, 5);
    }
}

test "byte-progressive compressed copy decoder enforces history and framing" {
    const encoded = try br.encodeAlternatingStreamAlloc(std.testing.allocator, 'a', 'b', 257);
    defer std.testing.allocator.free(encoded);
    var output: [257]u8 = undefined;

    var no_history = br.IncrementalCopyStreamDecoder.init(&.{});
    try std.testing.expectError(error.OutputTooSmall, no_history.step(encoded, &output));
    var short_history: [1]u8 = undefined;
    var invalid_match = br.IncrementalCopyStreamDecoder.init(&short_history);
    try std.testing.expectError(error.InvalidMatch, invalid_match.step(encoded, &output));
    var history: [2]u8 = undefined;
    var limited = br.IncrementalCopyStreamDecoder.initWithOptions(&history, .{ .max_output_len = 256 });
    try std.testing.expectError(error.OutputLimitExceeded, limited.step(encoded, &output));

    var truncated = br.IncrementalCopyStreamDecoder.init(&history);
    _ = try truncated.step(encoded[0 .. encoded.len - 1], &output);
    try std.testing.expectError(error.TruncatedFrame, truncated.finish());
    try std.testing.expectEqualStrings("truncated_input", truncated.diagnostics().recoverability_hint_name);

    var trailing_bytes: [128]u8 = undefined;
    @memcpy(trailing_bytes[0..encoded.len], encoded);
    trailing_bytes[encoded.len] = 0xff;
    var trailing = br.IncrementalCopyStreamDecoder.init(&history);
    try std.testing.expectError(error.TrailingData, trailing.step(trailing_bytes[0 .. encoded.len + 1], &output));
}
