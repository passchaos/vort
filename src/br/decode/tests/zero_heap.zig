const std = @import("std");
const h = @import("helpers.zig");
const Mode = enum { into, into_limited, into_exact, prefix, prefix_limited, prefix_exact, chunks, chunks_limited, chunks_exact, prefix_chunks, prefix_chunks_limited, prefix_chunks_exact, size, size_limited, prefix_size, prefix_size_limited, chunks_size, chunks_size_limited, prefix_chunks_size, prefix_chunks_size_limited, summary, summary_history, chunks_summary, chunks_summary_history, allocating_summary };

pub fn contracts(comptime B: type, sample: h.Sample(B)) !void {
    inline for (std.enums.values(Mode)) |mode| {
        inline for (.{ @as(?usize, null), @as(?usize, 0) }) |cap| {
            try invoke(B, mode, sample, cap, true);
        }
        try invoke(B, mode, sample, 0, false);
    }
}

fn isPrefix(comptime mode: Mode) bool {
    return switch (mode) {
        .prefix,
        .prefix_limited,
        .prefix_exact,
        .prefix_chunks,
        .prefix_chunks_limited,
        .prefix_chunks_exact,
        .prefix_size,
        .prefix_size_limited,
        .prefix_chunks_size,
        .prefix_chunks_size_limited,
        => true,
        else => false,
    };
}

noinline fn invoke(comptime B: type, comptime mode: Mode, sample: h.Sample(B), cap: ?usize, comptime profiled: bool) !void {
    errdefer std.debug.print("Brotli zero-heap mode: {s}, cap={any}\n", .{ @tagName(mode), cap });
    var profile: B.DecodeMemoryProfile = .{};
    var options = sample.options;
    options.max_total_working_memory = cap;
    options.memory_profile = if (profiled) &profile else null;
    const joined = try std.mem.concat(h.a, u8, &.{ sample.wire, "\xfftail" });
    defer h.a.free(joined);
    const stream = if (isPrefix(mode)) joined else sample.wire;
    const chunks = [_][]const u8{ "", stream[0..1], "", stream[1..], "" };
    const scratch = try h.a.alloc(u8, stream.len + 7);
    defer h.a.free(scratch);
    @memset(scratch, 0xa5);
    const output = try h.a.alloc(u8, sample.plain.len + 7);
    defer h.a.free(output);
    @memset(output, 0xa5);
    var history: [65520]u8 = undefined;
    if (comptime mode == .summary or mode == .summary_history or mode == .chunks_summary or mode == .chunks_summary_history or mode == .allocating_summary) {
        var tracker = h.CountingAllocator.init(h.a);
        tracker.fail_at = 0;
        const oracle = try B.summarizeStreamWithOptions(sample.wire, sample.options);
        const result = try switch (mode) {
            .summary => B.summarizeStreamLimitedWithOptions(stream, sample.plain.len, options),
            .summary_history => B.summarizeStreamLimitedWithHistoryAndOptions(stream, &history, sample.plain.len, options),
            .chunks_summary => B.summarizeStreamChunksLimitedWithOptions(&chunks, scratch[0..stream.len], sample.plain.len, options),
            .chunks_summary_history => B.summarizeStreamChunksLimitedWithHistoryAndOptions(&chunks, scratch[0..stream.len], &history, sample.plain.len, options),
            .allocating_summary => B.summarizeStreamAllocLimitedWithOptions(tracker.allocator(), stream, sample.plain.len, options),
            else => unreachable,
        };
        try std.testing.expectEqualDeep(oracle, result);
        try std.testing.expectEqual(@as(usize, 0), tracker.attempts);
    } else if (comptime mode == .size or mode == .size_limited or mode == .chunks_size or mode == .chunks_size_limited) {
        const result = try switch (mode) {
            .size => B.decodedStreamSizeWithOptions(stream, options),
            .size_limited => B.decodedStreamSizeLimitedWithOptions(stream, sample.plain.len, options),
            .chunks_size => B.decodedStreamChunksSizeWithOptions(&chunks, scratch[0..stream.len], options),
            .chunks_size_limited => B.decodedStreamChunksSizeLimitedWithOptions(&chunks, scratch[0..stream.len], sample.plain.len, options),
            else => unreachable,
        };
        try std.testing.expectEqual(@as(B.Counter, sample.plain.len), result);
    } else if (comptime mode == .prefix_size or mode == .prefix_size_limited or mode == .prefix_chunks_size or mode == .prefix_chunks_size_limited) {
        const result = try switch (mode) {
            .prefix_size => B.decodedStreamPrefixSizeWithOptions(stream, options),
            .prefix_size_limited => B.decodedStreamPrefixSizeLimitedWithOptions(stream, sample.plain.len, options),
            .prefix_chunks_size => B.decodedStreamPrefixChunksSizeWithOptions(&chunks, scratch[0..stream.len], options),
            .prefix_chunks_size_limited => B.decodedStreamPrefixChunksSizeLimitedWithOptions(&chunks, scratch[0..stream.len], sample.plain.len, options),
            else => unreachable,
        };
        try std.testing.expectEqual(sample.wire.len, result.input_read);
        try std.testing.expectEqual(@as(B.Counter, sample.plain.len), result.decoded_bytes);
    } else {
        const result = try into(B, mode, stream, &chunks, scratch[0..stream.len], output[0..sample.plain.len], sample.plain.len, options);
        try std.testing.expectEqual(sample.wire.len, result.input_read);
        try std.testing.expectEqual(sample.plain.len, result.output_written);
        try std.testing.expectEqualSlices(u8, sample.plain, output[0..sample.plain.len]);
    }
    for (output[sample.plain.len..]) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
    for (scratch[stream.len..]) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
    if (profiled) try h.zeroProfile(profile, cap) else try std.testing.expect(!profile.available);
}

fn into(comptime B: type, comptime mode: Mode, stream: []const u8, chunks: []const []const u8, scratch: []u8, output: []u8, len: usize, options: B.DecodeOptions) B.Error!B.DecodePrefixResult {
    if (isPrefix(mode)) return switch (mode) {
        .prefix => B.decodeStreamPrefixIntoWithOptions(stream, output, options),
        .prefix_limited => B.decodeStreamPrefixIntoLimitedWithOptions(stream, output, len, options),
        .prefix_exact => B.decodeStreamPrefixIntoExactSizeWithOptions(stream, output, len, options),
        .prefix_chunks => B.decodeStreamPrefixChunksIntoWithOptions(chunks, scratch, output, options),
        .prefix_chunks_limited => B.decodeStreamPrefixChunksIntoLimitedWithOptions(chunks, scratch, output, len, options),
        .prefix_chunks_exact => B.decodeStreamPrefixChunksIntoExactSizeWithOptions(chunks, scratch, output, len, options),
        else => unreachable,
    };
    const written = try switch (mode) {
        .into => B.decodeStreamIntoWithOptions(stream, output, options),
        .into_limited => B.decodeStreamIntoLimitedWithOptions(stream, output, len, options),
        .into_exact => B.decodeStreamIntoExactSizeWithOptions(stream, output, len, options),
        .chunks => B.decodeStreamChunksIntoWithOptions(chunks, scratch, output, options),
        .chunks_limited => B.decodeStreamChunksIntoLimitedWithOptions(chunks, scratch, output, len, options),
        .chunks_exact => B.decodeStreamChunksIntoExactSizeWithOptions(chunks, scratch, output, len, options),
        else => unreachable,
    };
    return .{ .input_read = stream.len, .output_written = written };
}

pub fn empty(comptime B: type) !void {
    const wire = try B.encodeStoredStreamWithOptionsAlloc(h.a, "", .{ .metadata = "metadata before empty stream" });
    defer h.a.free(wire);
    const joined = try std.mem.concat(h.a, u8, &.{ wire, "\xfftail" });
    defer h.a.free(joined);
    const chunks = [_][]const u8{ "", joined[0..1], joined[1..], "" };
    const scratch = try h.a.alloc(u8, joined.len);
    defer h.a.free(scratch);
    inline for (.{ @as(?usize, null), @as(?usize, 0) }) |cap| {
        var tracker = h.CountingAllocator.init(h.a);
        tracker.fail_at = 0;
        const heap = tracker.allocator();
        var profile: B.DecodeMemoryProfile = .{};
        const options: B.DecodeOptions = .{ .max_total_working_memory = cap, .memory_profile = &profile };
        const decoded = try B.decodeStreamAllocWithOptions(heap, wire, options);
        heap.free(decoded);
        try h.zeroProfile(profile, cap);
        profile.reset();
        const exact = try B.decodeStreamAllocExactSizeWithOptions(heap, wire, 0, options);
        heap.free(exact);
        try h.zeroProfile(profile, cap);
        profile.reset();
        const prefix = try B.decodeStreamPrefixChunksAllocLimitedWithOptions(heap, &chunks, scratch, 0, options);
        try std.testing.expectEqual(wire.len, prefix.input_read);
        try std.testing.expectEqual(@as(usize, 0), prefix.output_written);
        prefix.deinit(heap);
        try h.zeroProfile(profile, cap);
        profile.reset();
        const prefix_exact = try B.decodeStreamPrefixChunksAllocExactSizeWithOptions(heap, &chunks, scratch, 0, options);
        try std.testing.expectEqual(wire.len, prefix_exact.input_read);
        prefix_exact.deinit(heap);
        try h.zeroProfile(profile, cap);
        profile.reset();
        const summary = try B.summarizeStreamAllocWithOptions(heap, wire, options);
        try std.testing.expectEqual(@as(B.Counter, 0), summary.decoded_bytes);
        try h.zeroProfile(profile, cap);
        try std.testing.expectEqual(@as(usize, 0), tracker.attempts);
        try std.testing.expectEqual(@as(usize, 0), tracker.live);
    }
}
