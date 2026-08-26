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

test "byte-progressive compressed copy decoder consumes final-empty trailer" {
    const len = 4096;
    const encoded = try br.IncrementalTestSupport.encodeCompressedAlternatingWithFinalEmpty(std.testing.allocator, 'x', 'y', len);
    defer std.testing.allocator.free(encoded);
    const expected = try std.testing.allocator.alloc(u8, len);
    defer std.testing.allocator.free(expected);
    for (expected, 0..) |*byte, i| byte.* = "xy"[i & 1];
    var history: [2]u8 = undefined;
    try drainSplit(encoded, expected, &history, 1, 3);

    var truncated = br.IncrementalCopyStreamDecoder.init(&history);
    const decoded = try std.testing.allocator.alloc(u8, len);
    defer std.testing.allocator.free(decoded);
    var truncated_input: usize = 0;
    var truncated_output: usize = 0;
    while (truncated_output != decoded.len) {
        const step = try truncated.step(encoded[truncated_input .. encoded.len - 1], decoded[truncated_output..]);
        truncated_input += step.progress.input_read;
        truncated_output += step.progress.output_written;
        if (step.status == .need_input and truncated_input == encoded.len - 1) break;
    }
    try std.testing.expectError(error.TruncatedFrame, truncated.finish());
    try std.testing.expect(truncated_output < decoded.len or truncated_input < encoded.len);
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

test "byte-progressive compressed copy decoder supports recent and regular distances" {
    inline for (.{
        .{ br.IncrementalTestSupport.CompressedCopyFixture.implicit_last, "aaaaa" },
        .{ br.IncrementalTestSupport.CompressedCopyFixture.short, "aaaaa" },
        .{ br.IncrementalTestSupport.CompressedCopyFixture.regular, "ababa" },
    }) |case| {
        const kind, const expected = case;
        const encoded = try br.IncrementalTestSupport.encodeCompressedCopyFixture(std.testing.allocator, kind);
        defer std.testing.allocator.free(encoded);
        var history: [16]u8 = undefined;
        try drainSplit(encoded, expected, &history, 1, 1);
    }
}

test "byte-progressive compressed copy decoder accepts planner output" {
    inline for (.{
        "abcabcXabcabcXabcabcX",
        ("abcd" ** 10) ++ "aa" ++ ("abcd" ** 10),
        "abcdefabcdefXabcdefabcdefXabcdefabcdefX",
        "abcdefghijklmnop" ** 8,
        ("abcd" ** 128) ++ "UNMATCHED-LITERAL-TAIL!",
    }) |payload| {
        const encoded = try br.encodePlannedStreamAlloc(std.testing.allocator, payload);
        defer std.testing.allocator.free(encoded);
        var history: [32 * 1024]u8 = undefined;
        try drainSplit(encoded, payload, &history, 1, 3);
    }
}

test "byte-progressive compressed copy decoder accepts ratio context output" {
    const payload = ("compression contexts favor repeated lowercase words and spaces; " ** 128);
    const encoded = try br.encodePlannedStreamRatioAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);
    var history: [32 * 1024]u8 = undefined;
    try drainSplit(encoded, payload, &history, 1, 7);
}

test "byte-progressive compressed copy decoder selects literal and distance contexts" {
    inline for (.{
        .{ br.IncrementalTestSupport.CompressedCopyFixture.literal_context, "aba" },
        .{ br.IncrementalTestSupport.CompressedCopyFixture.distance_context, "ababa" },
    }) |case| {
        const kind, const expected = case;
        const encoded = try br.IncrementalTestSupport.encodeCompressedCopyFixture(std.testing.allocator, kind);
        defer std.testing.allocator.free(encoded);
        var history: [16]u8 = undefined;
        try drainSplit(encoded, expected, &history, 1, 1);
    }
}

test "byte-progressive compressed copy decoder switches entropy block types" {
    inline for (.{
        .{ br.IncrementalTestSupport.CompressedCopyFixture.command_switch, "aaab" },
        .{ br.IncrementalTestSupport.CompressedCopyFixture.command_switch_three, "aaabbbc" },
        .{ br.IncrementalTestSupport.CompressedCopyFixture.literal_switch, "ab" },
        .{ br.IncrementalTestSupport.CompressedCopyFixture.literal_switch_complex_length, "ab" },
        .{ br.IncrementalTestSupport.CompressedCopyFixture.literal_switch_three, "abc" },
        .{ br.IncrementalTestSupport.CompressedCopyFixture.distance_switch, "abcabab" },
        .{ br.IncrementalTestSupport.CompressedCopyFixture.distance_switch_three, "abcababbb" },
    }) |case| {
        const kind, const expected = case;
        const encoded = try br.IncrementalTestSupport.encodeCompressedCopyFixture(std.testing.allocator, kind);
        defer std.testing.allocator.free(encoded);
        var history: [16]u8 = undefined;
        try drainSplit(encoded, expected, &history, 1, 1);
    }
}

test "byte-progressive compressed copy decoder enforces history and framing" {
    const encoded = try br.encodeAlternatingStreamAlloc(std.testing.allocator, 'a', 'b', 257);
    defer std.testing.allocator.free(encoded);
    var output: [257]u8 = undefined;

    var no_history = br.IncrementalCopyStreamDecoder.init(&.{});
    try std.testing.expectError(error.OutputTooSmall, no_history.step(encoded, &output));
    const wider_distance = try br.encodeRepeatedPrefixStreamAlloc(std.testing.allocator, "abcd", 8);
    defer std.testing.allocator.free(wider_distance);
    var short_history: [1]u8 = undefined;
    var invalid_match = br.IncrementalCopyStreamDecoder.init(&short_history);
    try std.testing.expectError(error.InvalidMatch, invalid_match.step(wider_distance, &output));
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

test "byte-progressive compressed copy decoder emits transformed dictionary words" {
    inline for (.{
        "information",
        "Information about compression performance and dictionary support.",
        " information follows the information",
        "abcdefghabcdefgh information follows abcdefghabcdefgh",
    }) |payload| {
        const encoded = try br.encodePlannedStreamStaticDictionaryAlloc(std.testing.allocator, payload);
        defer std.testing.allocator.free(encoded);
        var history: [32 * 1024]u8 = undefined;
        try drainSplit(encoded, payload, &history, 1, 1);
    }
}
