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
        if (step.status == .need_input) try std.testing.expect(input_offset < encoded.len);
        if (step.status == .need_output) try std.testing.expect(output_offset < decoded.len);
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

test "byte-progressive compressed copy decoder crosses compressed meta-blocks" {
    const encoded = try br.IncrementalTestSupport.encodeCompressedCopiesAcrossMetaBlocks(std.testing.allocator);
    defer std.testing.allocator.free(encoded);
    const one_shot = try br.decodeStreamAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(one_shot);
    try std.testing.expectEqualSlices(u8, "aaaaa", one_shot);
    var history: [4]u8 = undefined;
    try drainSplit(encoded, "aaaaa", &history, 1, 1);

    // Removing the final byte leaves the second compressed header or payload
    // incomplete, depending on how many bits its compact trees occupy.
    var truncated = br.IncrementalCopyStreamDecoder.init(&history);
    var output: [5]u8 = undefined;
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (input_offset < encoded.len - 1) {
        const end = @min(encoded.len - 1, input_offset + 1);
        const step = try truncated.step(encoded[input_offset..end], output[output_offset..][0..@min(1, output.len - output_offset)]);
        input_offset += step.progress.input_read;
        output_offset += step.progress.output_written;
    }
    try std.testing.expectError(error.TruncatedFrame, truncated.finish());
}

test "byte-progressive compressed copy decoder preserves contexts across meta-blocks" {
    const encoded = try br.IncrementalTestSupport.encodeCompressedLiteralContextAcrossMetaBlocks(std.testing.allocator);
    defer std.testing.allocator.free(encoded);
    var history: [2]u8 = undefined;
    try drainSplit(encoded, "ab", &history, 1, 1);
}

test "byte-progressive copy decoder accepts stored and metadata first blocks" {
    const stored_first = try br.IncrementalTestSupport.encodeStoredThenCompressedContext(std.testing.allocator);
    defer std.testing.allocator.free(stored_first);
    var history: [8]u8 = undefined;
    try drainSplit(stored_first, "ab", &history, 1, 1);

    const metadata = "leading metadata";
    const metadata_first = try br.IncrementalTestSupport.encodeMetadataThenCompressedHello(std.testing.allocator, metadata);
    defer std.testing.allocator.free(metadata_first);
    var metadata_output: [metadata.len]u8 = undefined;
    var lengths: [1]usize = undefined;
    var decoder = br.IncrementalCopyStreamDecoder.initWithOptions(&history, .{
        .expected_output_len = 5,
        .metadata_output = &metadata_output,
        .metadata_block_lengths = &lengths,
    });
    var output: [5]u8 = undefined;
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (decoder.snapshot().phase != .done) {
        const input_end = @min(metadata_first.len, input_offset + 1);
        const output_end = @min(output.len, output_offset + 1);
        const step = try decoder.step(metadata_first[input_offset..input_end], output[output_offset..output_end]);
        input_offset += step.progress.input_read;
        output_offset += step.progress.output_written;
    }
    try decoder.finish();
    try std.testing.expectEqualSlices(u8, "hello", &output);
    try std.testing.expectEqualSlices(u8, metadata, &metadata_output);
    try std.testing.expectEqual(metadata.len, lengths[0]);
}

test "byte-progressive copy decoder uses caller-owned compressed header scratch" {
    const encoded = try br.IncrementalTestSupport.encodeLargeCompressedHeader(std.testing.allocator);
    defer std.testing.allocator.free(encoded);
    try std.testing.expect(encoded.len > br.default_incremental_compressed_header_bytes);

    var history: [1]u8 = undefined;
    var default_decoder = br.IncrementalCopyStreamDecoder.initWithOptions(&history, .{ .expected_output_len = 1 });
    var output: [1]u8 = undefined;
    try std.testing.expectError(error.UnsupportedBrotliFeature, default_decoder.step(encoded, &output));
    try std.testing.expectEqual(br.default_incremental_compressed_header_bytes, default_decoder.snapshot().retained_input_bytes);
    try std.testing.expectEqualSlices(u8, "compressed_header", default_decoder.diagnostics().last_error_phase_name);

    const header_scratch = try std.testing.allocator.alloc(u8, encoded.len);
    defer std.testing.allocator.free(header_scratch);
    var decoder = br.IncrementalCopyStreamDecoder.initWithOptions(&history, .{
        .expected_output_len = 1,
        .compressed_header_scratch = header_scratch,
    });
    var input_offset: usize = 0;
    while (decoder.snapshot().phase != .done) {
        const input_end = @min(encoded.len, input_offset + 257);
        const step = try decoder.step(encoded[input_offset..input_end], output[0..0]);
        input_offset += step.progress.input_read;
        if (step.status == .need_output) break;
        try std.testing.expectEqual(br.IncrementalCopyStreamDecoder.Phase.compressed_header, decoder.snapshot().phase);
        try std.testing.expect(decoder.snapshot().retained_input_bytes <= header_scratch.len);
    }
    const done = try decoder.step(encoded[input_offset..], &output);
    input_offset += done.progress.input_read;
    try std.testing.expectEqual(.done, done.status);
    try decoder.finish();
    try std.testing.expectEqual(encoded.len, input_offset);
    try std.testing.expectEqualSlices(u8, "x", &output);
}

test "byte-progressive compressed copy decoder streams following stored blocks" {
    const encoded = try br.IncrementalTestSupport.encodeCompressedAlternatingThenStored(std.testing.allocator, 'x', 'y', 257, " tail");
    defer std.testing.allocator.free(encoded);
    const expected = ("xy" ** 128) ++ "x tail";
    var history: [32]u8 = undefined;
    try drainSplit(encoded, expected, &history, 1, 2);

    var limited = br.IncrementalCopyStreamDecoder.initWithOptions(&history, .{ .max_output_len = expected.len - 1 });
    var output: [expected.len]u8 = undefined;
    try std.testing.expectError(error.OutputLimitExceeded, limited.step(encoded, &output));
}

test "byte-progressive compressed copy decoder skips following metadata" {
    const metadata = "copy metadata";
    const encoded = try br.IncrementalTestSupport.encodeCompressedAlternatingThenMetadataAndStored(std.testing.allocator, metadata, "!");
    defer std.testing.allocator.free(encoded);
    const expected = ("xy" ** 126) ++ "x!";
    var metadata_output: [4]u8 = undefined;
    var lengths: [1]usize = undefined;
    var history: [32]u8 = undefined;
    var decoder = br.IncrementalCopyStreamDecoder.initWithOptions(&history, .{
        .expected_output_len = expected.len,
        .metadata_output = &metadata_output,
        .metadata_block_lengths = &lengths,
    });
    var output: [expected.len]u8 = undefined;
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (decoder.snapshot().phase != .done) {
        const end = @min(encoded.len, input_offset + 1);
        const step = try decoder.step(encoded[input_offset..end], output[output_offset..][0..@min(2, output.len - output_offset)]);
        input_offset += step.progress.input_read;
        output_offset += step.progress.output_written;
    }
    try decoder.finish();
    try std.testing.expectEqualSlices(u8, expected, &output);
    const snapshot = decoder.snapshot();
    try std.testing.expectEqualSlices(u8, metadata[0..metadata_output.len], &metadata_output);
    try std.testing.expectEqual(metadata.len, snapshot.metadata_total);
    try std.testing.expectEqual(@as(usize, 1), snapshot.metadata_block_count);
    try std.testing.expectEqual(metadata.len, lengths[0]);
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

test "byte-progressive copy decoder bulk spans preserve overlap and ring wrap" {
    const prefix = "abcd";
    const repeated = prefix ** 17;
    const encoded = try br.encodeRepeatedPrefixStreamAlloc(std.testing.allocator, prefix, 17);
    defer std.testing.allocator.free(encoded);

    // A 17-byte output slice is just above the bulk threshold and one byte
    // longer than the overlap period used below. Repeated resumes eventually
    // cross both source and destination ends of the 32-byte history ring.
    var history: [32]u8 = undefined;
    try drainSplit(encoded, repeated, &history, 1, 17);

    const non_overlap = prefix ++ prefix;
    const non_overlap_encoded = try br.encodePlannedStreamAlloc(std.testing.allocator, non_overlap);
    defer std.testing.allocator.free(non_overlap_encoded);
    var wide_history: [64]u8 = undefined;
    try drainSplit(non_overlap_encoded, non_overlap, &wide_history, 1, 16);

    const long_repeated = prefix ** 16_384;
    const long_encoded = try br.encodeRepeatedPrefixStreamAlloc(std.testing.allocator, prefix, 16_384);
    defer std.testing.allocator.free(long_encoded);
    // Let one call drain a copy longer than the 32 KiB history. The bulk path
    // must advance its logical output position between ring-sized segments.
    var long_history: [32 * 1024]u8 = undefined;
    try drainSplit(long_encoded, long_repeated, &long_history, long_encoded.len, long_repeated.len);
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

test "byte-progressive copy decoder completes a partial-byte static dictionary header" {
    // Stable planner output for `information`: the compressed header ends in
    // the final retained byte, with command bits following it. A decoder that
    // exposes only complete header bytes consumes all nine input bytes and then
    // returns `need_input` forever without producing output.
    const encoded = [_]u8{ 66, 1, 0, 60, 4, 64, 0, 19, 149 };
    const expected = "information";
    var history: [32 * 1024]u8 = undefined;
    try drainSplit(&encoded, expected, &history, 1, 1);
}
