//! Public count-only contracts use tiny Brotli wire, never a wide plaintext.
const std = @import("std");
const Counter = @import("../../io/stream_count.zig").Counter;
const fixture = @import("wide_size_fixture.zig");
const types = @import("types.zig");
const stats = @import("stats.zig");

pub fn contracts(comptime Codec: type) !void {
    try typeContracts(Codec);
    try checkedCounters();
    try smallWireOracle(Codec);
    const wide = try fixture.create(std.testing.allocator, .{});
    defer std.testing.allocator.free(wide.wire);
    try std.testing.expect(wide.wire.len < 4096);
    try std.testing.expectEqual(@as(Counter, 4_294_968_326), wide.decoded_bytes);
    try publicVariants(Codec, wide);
    try boundaryLimits(Codec, wide);
    try sharedDictionary(Codec);
}

fn typeContracts(comptime Codec: type) !void {
    try std.testing.expect(Codec.Counter == Counter);
    try std.testing.expect(@TypeOf(@as(Codec.StreamSummary, undefined).decoded_bytes) == Counter);
    try std.testing.expect(@TypeOf(@as(Codec.StreamSummaryDiagnostics, undefined).offset) == Counter);
    try std.testing.expect(@TypeOf(@as(Codec.StreamSummaryDiagnostics, undefined).meta_block_index) == Counter);
    inline for (.{
        "decodedStreamSize",       "decodedStreamSizeLimited",       "decodedStreamSizeWithOptions",       "decodedStreamSizeLimitedWithOptions",
        "decodedStreamChunksSize", "decodedStreamChunksSizeLimited", "decodedStreamChunksSizeWithOptions", "decodedStreamChunksSizeLimitedWithOptions",
    }) |name| {
        const result = @typeInfo(@TypeOf(@field(Codec, name))).@"fn".return_type.?;
        try std.testing.expect(@typeInfo(result).error_union.payload == Counter);
    }
    inline for (.{
        "meta_block_count",                "empty_meta_block_count",          "metadata_meta_block_count",             "uncompressed_meta_block_count",         "compressed_meta_block_count",
        "metadata_bytes",                  "static_dictionary_copy_count",    "static_dictionary_bytes",               "shared_dictionary_copy_count",          "shared_dictionary_bytes",
        "command_count",                   "zero_insert_command_count",       "single_literal_insert_command_count",   "implicit_distance_command_count",       "implicit_distance_copy_count",
        "short_distance_copy_count",       "direct_distance_copy_count",      "regular_distance_copy_count",           "lz77_copy_count",                       "lz77_copy_bytes",
        "non_overlapping_lz77_copy_count", "non_overlapping_lz77_copy_bytes", "short_non_overlapping_lz77_copy_count", "short_non_overlapping_lz77_copy_bytes",
    }) |name| try std.testing.expect(@TypeOf(@field(@as(Codec.StreamSummary, undefined), name)) == Counter);
    try std.testing.expect(@TypeOf(@as(Codec.StreamSummary, undefined).copy_length_log2_histogram) == [9]Counter);
    try std.testing.expect(@TypeOf(@as(Codec.StreamSummary, undefined).literal_context_mode_bytes) == [4]Counter);
    // Every block-local byte total and productive count fits the 24-bit
    // declared output length; the stream's corresponding fields remain wide.
    inline for (.{
        "static_dictionary_bytes",         "shared_dictionary_bytes",               "single_literal_insert_command_count",
        "lz77_copy_count",                 "lz77_copy_bytes",                       "non_overlapping_lz77_copy_count",
        "non_overlapping_lz77_copy_bytes", "short_non_overlapping_lz77_copy_count", "short_non_overlapping_lz77_copy_bytes",
    }) |name| try std.testing.expect(@TypeOf(@field(@as(types.MetaBlockStats, undefined), name)) == usize);
    try std.testing.expect(@TypeOf(@as(types.MetaBlockStats, undefined).literal_context_mode_bytes) == [4]usize);
    // Empty transformed words still consume commands and distance symbols.
    inline for (.{
        "command_count",                "zero_insert_command_count",    "implicit_distance_command_count",
        "static_dictionary_copy_count", "shared_dictionary_copy_count", "implicit_distance_copy_count",
        "short_distance_copy_count",    "direct_distance_copy_count",   "regular_distance_copy_count",
    }) |name| try std.testing.expect(@TypeOf(@field(@as(types.MetaBlockStats, undefined), name)) == Counter);
    try std.testing.expect(@TypeOf(@as(types.MetaBlockStats, undefined).copy_length_log2_histogram) == [9]Counter);
    // These maxima describe local RFC tables and physical windows.
    try std.testing.expect(@TypeOf(@as(Codec.StreamSummary, undefined).max_lz77_distance) == usize);
    try std.testing.expect(@TypeOf(@as(Codec.StreamSummary, undefined).max_literal_context_trees) == usize);
}

fn checkedCounters() !void {
    const boundary: Counter = @as(Counter, 1) << 32;
    const maximum = std.math.maxInt(Counter);
    try std.testing.expectEqual(boundary + 7, try stats.addDecoded(boundary - 3, 10, boundary + 7));
    try std.testing.expectError(error.OutputLimitExceeded, stats.addDecoded(boundary - 3, 10, boundary + 6));
    try std.testing.expectEqual(maximum, try stats.addDecoded(maximum - 1, 1, maximum));
    try std.testing.expectError(error.IntegerOverflow, stats.addDecoded(maximum, 1, maximum));
    // Arithmetic overflow takes precedence over an output cap.
    try std.testing.expectError(error.IntegerOverflow, stats.addDecoded(maximum, 1, 0));

    inline for (.{
        "static_dictionary_copy_count",          "static_dictionary_bytes",               "shared_dictionary_copy_count",        "shared_dictionary_bytes",
        "command_count",                         "zero_insert_command_count",             "single_literal_insert_command_count", "implicit_distance_command_count",
        "implicit_distance_copy_count",          "short_distance_copy_count",             "direct_distance_copy_count",          "regular_distance_copy_count",
        "lz77_copy_count",                       "lz77_copy_bytes",                       "non_overlapping_lz77_copy_count",     "non_overlapping_lz77_copy_bytes",
        "short_non_overlapping_lz77_copy_count", "short_non_overlapping_lz77_copy_bytes",
    }) |name| {
        var summary: types.StreamSummary = .{ .window_bits = 16, .input_bytes = 0 };
        var delta: types.MetaBlockStats = .{};
        @field(summary, name) = maximum - 1;
        @field(delta, name) = 1;
        if (std.mem.eql(u8, name, "static_dictionary_bytes")) delta.static_dictionary_copy_count = 1;
        if (std.mem.eql(u8, name, "shared_dictionary_bytes")) delta.shared_dictionary_copy_count = 1;
        try stats.apply(&summary, delta);
        try std.testing.expectEqual(maximum, @field(summary, name));
        const before = summary;
        try std.testing.expectError(error.IntegerOverflow, stats.apply(&summary, delta));
        try std.testing.expectEqualDeep(before, summary);
    }
    inline for (.{ "copy_length_log2_histogram", "literal_context_mode_bytes" }) |name| {
        for (0..@typeInfo(@TypeOf(@field(@as(types.StreamSummary, undefined), name))).array.len) |index| {
            var summary: types.StreamSummary = .{ .window_bits = 16, .input_bytes = 0 };
            var delta: types.MetaBlockStats = .{};
            @field(summary, name)[index] = maximum - 1;
            @field(delta, name)[index] = 1;
            try stats.apply(&summary, delta);
            try std.testing.expectEqual(maximum, @field(summary, name)[index]);
            const before = summary;
            try std.testing.expectError(error.IntegerOverflow, stats.apply(&summary, delta));
            try std.testing.expectEqualDeep(before, summary);
        }
    }
}

fn smallWireOracle(comptime Codec: type) !void {
    for ([_][]const u8{ "a", "ab", "ba" }) |pattern| {
        for ([_]usize{ 7, 64, 257, 1025 }) |block_len| {
            const small = try fixture.create(std.testing.allocator, .{ .full_blocks = 2, .block_len = block_len, .tail_len = 11, .pattern = pattern });
            defer std.testing.allocator.free(small.wire);
            const expected = try std.testing.allocator.alloc(u8, @intCast(small.decoded_bytes));
            defer std.testing.allocator.free(expected);
            for ([_]usize{ block_len, block_len, 11 }, 0..) |len, block| {
                const offset = if (block < 2) block * block_len else 2 * block_len;
                for (expected[offset..][0..len], 0..) |*byte, index| byte.* = pattern[index % pattern.len];
            }
            @memcpy(expected[@intCast(small.core_bytes)..], "world!");
            const output = try std.testing.allocator.alloc(u8, expected.len);
            defer std.testing.allocator.free(output);
            try std.testing.expectEqual(expected.len, try Codec.decodeStreamIntoExactSize(small.wire, output, expected.len));
            try std.testing.expectEqualSlices(u8, expected, output);
            const summary = try Codec.summarizeStream(small.wire);
            try std.testing.expectEqual(small.decoded_bytes, summary.decoded_bytes);
            try std.testing.expectEqual(small.core_bytes - small.literal_bytes, summary.lz77_copy_bytes);
            try std.testing.expectEqual(pattern.len, summary.max_lz77_distance);

            // Non-power-of-two rings and odd copy lengths pin periodic phase,
            // wraparound, and the bounded-copy optimization's final suffix.
            for ([_]usize{ 2, 3, 7, 31 }) |capacity| {
                var history: [31]u8 = @splat(0xa5);
                const bounded = try Codec.summarizeStreamWithHistory(small.wire, history[0..capacity]);
                try std.testing.expectEqualDeep(summary, bounded);
                // Stored "!" finishes the ring. The newest capacity bytes may
                // wrap, but they must form precisely the decoded suffix.
                const tail = expected[expected.len - capacity ..];
                var matches = false;
                for (0..capacity) |start| {
                    var same = true;
                    for (tail, 0..) |byte, index| same = same and byte == history[(start + index) % capacity];
                    matches = matches or same;
                }
                try std.testing.expect(matches);
            }
        }
    }
}

fn expectWide(comptime Codec: type, summary: Codec.StreamSummary, wide: fixture.Fixture) !void {
    try std.testing.expectEqual(wide.decoded_bytes, summary.decoded_bytes);
    try std.testing.expectEqual(@as(Counter, wide.core_blocks + 4), summary.meta_block_count);
    try std.testing.expectEqual(@as(Counter, wide.core_blocks + 1), summary.compressed_meta_block_count);
    try std.testing.expectEqual(@as(Counter, 1), summary.empty_meta_block_count);
    try std.testing.expectEqual(@as(Counter, 1), summary.metadata_meta_block_count);
    try std.testing.expectEqual(@as(Counter, 1), summary.uncompressed_meta_block_count);
    try std.testing.expectEqual(@as(Counter, fixture.metadata.len), summary.metadata_bytes);
    try std.testing.expectEqual(@as(Counter, wide.core_blocks + 1), summary.command_count);
    try std.testing.expectEqual(@as(Counter, wide.core_blocks), summary.single_literal_insert_command_count);
    try std.testing.expectEqual(@as(Counter, 1), summary.zero_insert_command_count);
    try std.testing.expectEqual(@as(Counter, wide.core_blocks), summary.lz77_copy_count);
    try std.testing.expectEqual(wide.core_bytes - wide.literal_bytes, summary.lz77_copy_bytes);
    try std.testing.expect(summary.lz77_copy_bytes > std.math.maxInt(u32));
    try std.testing.expectEqual(@as(usize, 1), summary.max_lz77_distance);
    try std.testing.expectEqual(@as(Counter, wide.core_blocks), summary.direct_distance_copy_count);
    try std.testing.expectEqual(@as(Counter, 1), summary.regular_distance_copy_count);
    try std.testing.expectEqual(@as(Counter, wide.core_blocks), summary.copy_length_log2_histogram[8]);
    try std.testing.expectEqual(@as(Counter, 1), summary.copy_length_log2_histogram[2]);
    try std.testing.expectEqual(wide.literal_bytes, summary.literal_context_mode_bytes[0]);
    try std.testing.expect(summary.uses_static_dictionary and summary.uses_metadata and summary.uses_uncompressed_meta_blocks);
    try std.testing.expectEqual(@as(Counter, 1), summary.static_dictionary_copy_count);
    try std.testing.expectEqual(@as(Counter, 5), summary.static_dictionary_bytes);
    try std.testing.expect(!summary.stored_only);
}

fn publicVariants(comptime Codec: type, wide: fixture.Fixture) !void {
    const wire = wide.wire;
    const limit = wide.decoded_bytes;
    const options: Codec.DecodeOptions = .{ .allow_large_window = true };
    var diagnostics: Codec.StreamSummaryDiagnostics = undefined;
    var history: [7]u8 = undefined;
    const a = std.testing.failing_allocator;
    try std.testing.expectEqual(limit, try Codec.decodedStreamSize(wire));
    try std.testing.expectEqual(limit, try Codec.decodedStreamSizeLimited(wire, limit));
    try std.testing.expectEqual(limit, try Codec.decodedStreamSizeWithOptions(wire, options));
    try std.testing.expectEqual(limit, try Codec.decodedStreamSizeLimitedWithOptions(wire, limit, options));
    const contiguous = [_]Codec.StreamSummary{
        try Codec.summarizeStream(wire),
        try Codec.summarizeStreamLimited(wire, limit),
        try Codec.summarizeStreamWithOptions(wire, options),
        try Codec.summarizeStreamLimitedWithOptions(wire, limit, options),
        try Codec.summarizeStreamWithDiagnostics(wire, &diagnostics),
        try Codec.summarizeStreamWithOptionsAndDiagnostics(wire, options, &diagnostics),
        try Codec.summarizeStreamLimitedWithDiagnostics(wire, limit, &diagnostics),
        try Codec.summarizeStreamLimitedWithOptionsAndDiagnostics(wire, limit, options, &diagnostics),
        try Codec.summarizeStreamWithHistory(wire, &history),
        try Codec.summarizeStreamLimitedWithHistory(wire, &history, limit),
        try Codec.summarizeStreamWithHistoryAndOptions(wire, &history, options),
        try Codec.summarizeStreamLimitedWithHistoryAndOptions(wire, &history, limit, options),
        try Codec.summarizeStreamWithHistoryAndDiagnostics(wire, &history, &diagnostics),
        try Codec.summarizeStreamWithHistoryAndOptionsAndDiagnostics(wire, &history, options, &diagnostics),
        try Codec.summarizeStreamLimitedWithHistoryAndDiagnostics(wire, &history, limit, &diagnostics),
        try Codec.summarizeStreamLimitedWithHistoryAndOptionsAndDiagnostics(wire, &history, limit, options, &diagnostics),
        try Codec.summarizeStreamAlloc(a, wire),
        try Codec.summarizeStreamAllocLimited(a, wire, limit),
        try Codec.summarizeStreamAllocWithOptions(a, wire, options),
        try Codec.summarizeStreamAllocLimitedWithOptions(a, wire, limit, options),
        try Codec.summarizeStreamAllocWithDiagnostics(a, wire, &diagnostics),
        try Codec.summarizeStreamAllocLimitedWithDiagnostics(a, wire, limit, &diagnostics),
        try Codec.summarizeStreamAllocWithOptionsAndDiagnostics(a, wire, options, &diagnostics),
        try Codec.summarizeStreamAllocLimitedWithOptionsAndDiagnostics(a, wire, limit, options, &diagnostics),
    };
    for (contiguous) |summary| try expectWide(Codec, summary, wide);
    const chunks = [_][]const u8{ "", wire[0..1], "", wire[1..17], wire[17 .. wire.len - 1], "", wire[wire.len - 1 ..], "" };
    var scratch: [4096]u8 = undefined;
    try std.testing.expectEqual(limit, try Codec.decodedStreamChunksSize(&chunks, &scratch));
    try std.testing.expectEqual(limit, try Codec.decodedStreamChunksSizeLimited(&chunks, &scratch, limit));
    try std.testing.expectEqual(limit, try Codec.decodedStreamChunksSizeWithOptions(&chunks, &scratch, options));
    try std.testing.expectEqual(limit, try Codec.decodedStreamChunksSizeLimitedWithOptions(&chunks, &scratch, limit, options));
    const chunked = [_]Codec.StreamSummary{
        try Codec.summarizeStreamChunks(&chunks, &scratch),
        try Codec.summarizeStreamChunksWithOptions(&chunks, &scratch, options),
        try Codec.summarizeStreamChunksLimited(&chunks, &scratch, limit),
        try Codec.summarizeStreamChunksLimitedWithOptions(&chunks, &scratch, limit, options),
        try Codec.summarizeStreamChunksWithDiagnostics(&chunks, &scratch, &diagnostics),
        try Codec.summarizeStreamChunksWithOptionsAndDiagnostics(&chunks, &scratch, options, &diagnostics),
        try Codec.summarizeStreamChunksLimitedWithDiagnostics(&chunks, &scratch, limit, &diagnostics),
        try Codec.summarizeStreamChunksLimitedWithOptionsAndDiagnostics(&chunks, &scratch, limit, options, &diagnostics),
        try Codec.summarizeStreamChunksWithHistory(&chunks, &scratch, &history),
        try Codec.summarizeStreamChunksLimitedWithHistory(&chunks, &scratch, &history, limit),
        try Codec.summarizeStreamChunksWithHistoryAndOptions(&chunks, &scratch, &history, options),
        try Codec.summarizeStreamChunksLimitedWithHistoryAndOptions(&chunks, &scratch, &history, limit, options),
        try Codec.summarizeStreamChunksWithHistoryAndDiagnostics(&chunks, &scratch, &history, &diagnostics),
        try Codec.summarizeStreamChunksWithHistoryAndOptionsAndDiagnostics(&chunks, &scratch, &history, options, &diagnostics),
        try Codec.summarizeStreamChunksLimitedWithHistoryAndDiagnostics(&chunks, &scratch, &history, limit, &diagnostics),
        try Codec.summarizeStreamChunksLimitedWithHistoryAndOptionsAndDiagnostics(&chunks, &scratch, &history, limit, options, &diagnostics),
    };
    for (chunked) |summary| try expectWide(Codec, summary, wide);
    const probe = Codec.probeStreamLimitedWithOptions(wire, limit, options);
    try std.testing.expect(probe.ok);
    try expectWide(Codec, probe.summary.?, wide);
}

fn boundaryLimits(comptime Codec: type, wide: fixture.Fixture) !void {
    const boundary: Counter = @as(Counter, 1) << 32;
    var diagnostics: Codec.StreamSummaryDiagnostics = undefined;
    var history: [7]u8 = undefined;
    for ([_]Counter{ boundary - 1, boundary, wide.decoded_bytes - 1 }) |limit| {
        try std.testing.expectError(error.OutputLimitExceeded, Codec.decodedStreamSizeLimited(wide.wire, limit));
        try std.testing.expectError(error.OutputLimitExceeded, Codec.summarizeStreamLimitedWithHistoryAndOptionsAndDiagnostics(wide.wire, &history, limit, .{}, &diagnostics));
        try std.testing.expectEqual(Codec.StreamSummaryErrorPhase.meta_block_header, diagnostics.phase);
        const index: Counter = if (limit == boundary - 1) 255 else if (limit == boundary) 256 else 259;
        try std.testing.expectEqual(index, diagnostics.meta_block_index);
    }
    const exact = try fixture.create(std.testing.allocator, .{ .tail_len = 0, .suffix = false });
    defer std.testing.allocator.free(exact.wire);
    try std.testing.expectEqual(boundary, try Codec.decodedStreamSizeLimited(exact.wire, boundary));
    try std.testing.expectError(error.OutputLimitExceeded, Codec.decodedStreamSizeLimited(exact.wire, boundary - 1));
    const probe = Codec.probeStreamLimited(wide.wire, boundary);
    try std.testing.expect(!probe.ok);
    try std.testing.expectEqualStrings("OutputLimitExceeded", probe.error_name);
}

fn sharedDictionary(comptime Codec: type) !void {
    const wide = try fixture.create(std.testing.allocator, .{ .raw_dictionary = true });
    defer std.testing.allocator.free(wide.wire);
    const options: Codec.DecodeOptions = .{ .shared_dictionary = .{ .raw_prefixes = &.{ "wo", "", "rld" } } };
    var history: [7]u8 = undefined;
    const summary = try Codec.summarizeStreamLimitedWithHistoryAndOptions(wide.wire, &history, wide.decoded_bytes, options);
    try std.testing.expectEqual(wide.decoded_bytes, summary.decoded_bytes);
    try std.testing.expectEqual(wide.core_bytes - wide.literal_bytes, summary.lz77_copy_bytes);
    try std.testing.expect(summary.uses_shared_dictionary);
    try std.testing.expectEqual(@as(Counter, 1), summary.shared_dictionary_copy_count);
    try std.testing.expectEqual(@as(Counter, 5), summary.shared_dictionary_bytes);
    try std.testing.expectEqual(@as(Counter, 0), summary.static_dictionary_copy_count);
    try std.testing.expectEqual(wide.decoded_bytes, try Codec.decodedStreamSizeLimitedWithOptions(wide.wire, wide.decoded_bytes, options));
}
