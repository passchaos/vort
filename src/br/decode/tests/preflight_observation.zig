//! Every early return publishes a fresh zero-heap observation. Chunk joining
//! happens before allocator admission and must preserve an inherited ledger.
const std = @import("std");
const h = @import("helpers.zig");
const budget = @import("../budget.zig");
const Mode = enum {
    owned,
    owned_limited,
    owned_exact,
    prefix,
    prefix_limited,
    prefix_exact,
    append,
    append_limited,
    append_exact,
    prefix_append,
    prefix_append_limited,
    prefix_append_exact,
    into,
    into_limited,
    into_exact,
    prefix_into,
    size,
    size_limited,
    prefix_size,
    summary,
    summary_limited,
    summary_diagnostics,
    allocating_summary,
    probe,
    eager,
    eager_exact,
    eager_reset,
};

pub fn contracts(comptime B: type, sample: h.Sample(B)) !void {
    inline for (std.enums.values(Mode)) |mode| {
        inline for (.{ @as(?usize, null), @as(?usize, 0) }) |cap| {
            try fresh(B, mode, false, sample, cap);
        }
    }
    inline for (.{ Mode.owned, Mode.owned_limited, Mode.owned_exact, Mode.prefix, Mode.prefix_exact, Mode.append, Mode.append_limited, Mode.append_exact, Mode.prefix_append, Mode.prefix_append_exact, Mode.into, Mode.into_limited, Mode.into_exact, Mode.prefix_into, Mode.size, Mode.size_limited, Mode.prefix_size, Mode.summary, Mode.summary_limited, Mode.summary_diagnostics, Mode.probe, Mode.eager, Mode.eager_exact, Mode.eager_reset }) |mode| {
        inline for (.{ @as(?usize, null), @as(?usize, 0) }) |cap| {
            try fresh(B, mode, true, sample, cap);
        }
    }
    try inheritedChunks(B, sample);
}

noinline fn fresh(comptime B: type, comptime mode: Mode, comptime chunks_error: bool, sample: h.Sample(B), cap: ?usize) !void {
    errdefer std.debug.print("Brotli preflight observation {s}, chunks={any}, cap={any}\n", .{ @tagName(mode), chunks_error, cap });
    var tracker = h.CountingAllocator.init(h.a);
    tracker.fail_at = 0;
    var profile: B.DecodeMemoryProfile = .{};
    const invalid = [_][]const u8{""} ** 16;
    const options: B.DecodeOptions = .{
        .max_total_working_memory = cap,
        .memory_profile = &profile,
        .shared_dictionary = if (chunks_error) .{} else .{ .raw_prefixes = &invalid },
    };
    const chunks = [_][]const u8{ sample.wire[0..1], "", sample.wire[1..] };
    const scratch = try h.a.alloc(u8, sample.wire.len - 1);
    defer h.a.free(scratch);
    @memset(scratch, 0xa5);
    const output = try h.a.alloc(u8, sample.plain.len + 7);
    defer h.a.free(output);
    @memset(output, 0xa5);
    var out = std.ArrayList(u8).fromOwnedSlice(try h.a.dupe(u8, "caller-prefix"));
    defer out.deinit(h.a);
    const pointer = out.items.ptr;
    const capacity = out.capacity;
    const expected = if (chunks_error) error.OutputTooSmall else error.CorruptFrame;
    try std.testing.expectError(expected, call(B, mode, chunks_error, tracker.allocator(), &out, sample, &chunks, scratch, output, options, expected));
    try h.zeroProfile(profile, cap);
    try std.testing.expectEqual(@as(usize, 0), tracker.attempts);
    try std.testing.expectEqual(@as(usize, 0), tracker.live);
    try std.testing.expectEqual(@as(usize, 0), tracker.failures);
    try std.testing.expectEqual(pointer, out.items.ptr);
    try std.testing.expectEqual(capacity, out.capacity);
    try std.testing.expectEqualStrings("caller-prefix", out.items);
    for (output) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
    for (scratch) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
}

fn inheritedChunks(comptime B: type, sample: h.Sample(B)) !void {
    var tracker = h.CountingAllocator.init(h.a);
    defer std.debug.assert(tracker.live == 0);
    var profile: B.DecodeMemoryProfile = .{};
    var lease = try budget.Lease.init(tracker.allocator(), null, &profile, 0);
    defer lease.deinit();
    const parent = lease.allocator();
    var out = std.ArrayList(u8).fromOwnedSlice(try parent.dupe(u8, "caller-prefix"));
    defer out.deinit(parent);
    const pointer = out.items.ptr;
    const capacity = out.capacity;
    try lease.setLimit(tracker.live);
    lease.beginOperation();
    try std.testing.expectError(error.OutOfMemory, parent.alloc(u8, 1));
    const before = profile;
    const snapshot = lease.snapshot();
    try std.testing.expect(snapshot.last_failure_was_limit);
    const chunks = [_][]const u8{ sample.wire[0..1], sample.wire[1..] };
    const scratch = try h.a.alloc(u8, sample.wire.len - 1);
    defer h.a.free(scratch);
    const output = try h.a.alloc(u8, sample.plain.len);
    defer h.a.free(output);
    tracker.begin();
    tracker.fail_at = 0;
    const outer: B.DecodeOptions = .{ .max_total_working_memory = snapshot.limit, .memory_profile = &profile };
    inline for (.{ Mode.owned, Mode.owned_limited, Mode.owned_exact, Mode.prefix, Mode.prefix_limited, Mode.prefix_exact, Mode.append, Mode.append_limited, Mode.append_exact, Mode.prefix_append, Mode.prefix_append_limited, Mode.prefix_append_exact }) |mode| {
        inline for (.{ false, true }) |forwarded| {
            const options = if (forwarded) budget.forward(outer) else outer;
            try std.testing.expectError(error.OutputTooSmall, call(B, mode, true, parent, &out, sample, &chunks, scratch, output, options, error.OutputTooSmall));
            try std.testing.expectEqual(before, profile);
            try std.testing.expectEqual(snapshot, lease.snapshot());
            try std.testing.expectEqual(pointer, out.items.ptr);
            try std.testing.expectEqual(capacity, out.capacity);
            try std.testing.expectEqualStrings("caller-prefix", out.items);
            try std.testing.expectEqual(@as(usize, 0), tracker.attempts);
        }
    }
}

fn call(comptime B: type, comptime mode: Mode, comptime chunks_error: bool, heap: std.mem.Allocator, out: *std.ArrayList(u8), sample: h.Sample(B), chunks: []const []const u8, scratch: []u8, output: []u8, options: B.DecodeOptions, expected: B.Error) !void {
    switch (mode) {
        .owned, .owned_limited, .owned_exact => {
            const bytes = try switch (mode) {
                .owned => if (chunks_error) B.decodeStreamChunksAllocWithOptions(heap, chunks, scratch, options) else B.decodeStreamAllocWithOptions(heap, sample.wire, options),
                .owned_limited => if (chunks_error) B.decodeStreamChunksAllocLimitedWithOptions(heap, chunks, scratch, sample.plain.len, options) else B.decodeStreamAllocLimitedWithOptions(heap, sample.wire, sample.plain.len, options),
                .owned_exact => if (chunks_error) B.decodeStreamChunksAllocExactSizeWithOptions(heap, chunks, scratch, sample.plain.len, options) else B.decodeStreamAllocExactSizeWithOptions(heap, sample.wire, sample.plain.len, options),
                else => unreachable,
            };
            heap.free(bytes);
        },
        .prefix, .prefix_limited, .prefix_exact => {
            const decoded = try switch (mode) {
                .prefix => if (chunks_error) B.decodeStreamPrefixChunksAllocWithOptions(heap, chunks, scratch, options) else B.decodeStreamPrefixAllocWithOptions(heap, sample.wire, options),
                .prefix_limited => if (chunks_error) B.decodeStreamPrefixChunksAllocLimitedWithOptions(heap, chunks, scratch, sample.plain.len, options) else B.decodeStreamPrefixAllocLimitedWithOptions(heap, sample.wire, sample.plain.len, options),
                .prefix_exact => if (chunks_error) B.decodeStreamPrefixChunksAllocExactSizeWithOptions(heap, chunks, scratch, sample.plain.len, options) else B.decodeStreamPrefixAllocExactSizeWithOptions(heap, sample.wire, sample.plain.len, options),
                else => unreachable,
            };
            decoded.deinit(heap);
        },
        .append => _ = try if (chunks_error) B.decodeStreamChunksAppendWithOptions(heap, out, chunks, scratch, options) else B.decodeStreamAppendWithOptions(heap, out, sample.wire, options),
        .append_limited => _ = try if (chunks_error) B.decodeStreamChunksAppendLimitedWithOptions(heap, out, chunks, scratch, sample.plain.len, options) else B.decodeStreamAppendLimitedWithOptions(heap, out, sample.wire, sample.plain.len, options),
        .append_exact => _ = try if (chunks_error) B.decodeStreamChunksAppendExactSizeWithOptions(heap, out, chunks, scratch, sample.plain.len, options) else B.decodeStreamAppendExactSizeWithOptions(heap, out, sample.wire, sample.plain.len, options),
        .prefix_append => _ = try if (chunks_error) B.decodeStreamPrefixChunksAppendWithOptions(heap, out, chunks, scratch, options) else B.decodeStreamPrefixAppendWithOptions(heap, out, sample.wire, options),
        .prefix_append_limited => _ = try if (chunks_error) B.decodeStreamPrefixChunksAppendLimitedWithOptions(heap, out, chunks, scratch, sample.plain.len, options) else B.decodeStreamPrefixAppendLimitedWithOptions(heap, out, sample.wire, sample.plain.len, options),
        .prefix_append_exact => _ = try if (chunks_error) B.decodeStreamPrefixChunksAppendExactSizeWithOptions(heap, out, chunks, scratch, sample.plain.len, options) else B.decodeStreamPrefixAppendExactSizeWithOptions(heap, out, sample.wire, sample.plain.len, options),
        .into => _ = try if (chunks_error) B.decodeStreamChunksIntoWithOptions(chunks, scratch, output, options) else B.decodeStreamIntoWithOptions(sample.wire, output, options),
        .into_limited => _ = try if (chunks_error) B.decodeStreamChunksIntoLimitedWithOptions(chunks, scratch, output, sample.plain.len, options) else B.decodeStreamIntoLimitedWithOptions(sample.wire, output, sample.plain.len, options),
        .into_exact => _ = try if (chunks_error) B.decodeStreamChunksIntoExactSizeWithOptions(chunks, scratch, output, sample.plain.len, options) else B.decodeStreamIntoExactSizeWithOptions(sample.wire, output, sample.plain.len, options),
        .prefix_into => _ = try if (chunks_error) B.decodeStreamPrefixChunksIntoWithOptions(chunks, scratch, output, options) else B.decodeStreamPrefixIntoWithOptions(sample.wire, output, options),
        .size => _ = try if (chunks_error) B.decodedStreamChunksSizeWithOptions(chunks, scratch, options) else B.decodedStreamSizeWithOptions(sample.wire, options),
        .size_limited => _ = try if (chunks_error) B.decodedStreamChunksSizeLimitedWithOptions(chunks, scratch, sample.plain.len, options) else B.decodedStreamSizeLimitedWithOptions(sample.wire, sample.plain.len, options),
        .prefix_size => _ = try if (chunks_error) B.decodedStreamPrefixChunksSizeWithOptions(chunks, scratch, options) else B.decodedStreamPrefixSizeWithOptions(sample.wire, options),
        .summary => _ = try if (chunks_error) B.summarizeStreamChunksWithOptions(chunks, scratch, options) else B.summarizeStreamWithOptions(sample.wire, options),
        .summary_limited => _ = try if (chunks_error) B.summarizeStreamChunksLimitedWithOptions(chunks, scratch, sample.plain.len, options) else B.summarizeStreamLimitedWithOptions(sample.wire, sample.plain.len, options),
        .summary_diagnostics => {
            var diagnostics: B.StreamSummaryDiagnostics = .{};
            _ = try if (chunks_error) B.summarizeStreamChunksWithOptionsAndDiagnostics(chunks, scratch, options, &diagnostics) else B.summarizeStreamWithOptionsAndDiagnostics(sample.wire, options, &diagnostics);
        },
        .allocating_summary => _ = try B.summarizeStreamAllocWithOptions(heap, sample.wire, options),
        .probe => {
            const result = if (chunks_error) B.probeStreamChunksWithOptions(chunks, scratch, options) else B.probeStreamWithOptions(sample.wire, options);
            try std.testing.expect(!result.ok);
            try std.testing.expectEqualStrings(@errorName(expected), result.error_name);
            return expected;
        },
        .eager => _ = try if (chunks_error) B.StreamDecoder.initFromChunksWithOptions(chunks, scratch, output, options) else B.StreamDecoder.initWithOptions(sample.wire, output, options),
        .eager_exact => _ = try if (chunks_error) B.StreamDecoder.initFromChunksExactSizeWithOptions(chunks, scratch, output, sample.plain.len, options) else B.StreamDecoder.initExactSizeWithOptions(sample.wire, output, sample.plain.len, options),
        .eager_reset => {
            var decoder: B.StreamDecoder = .{};
            if (chunks_error) try decoder.resetFromChunksWithOptions(chunks, scratch, output, options) else try decoder.resetWithOptions(sample.wire, output, options);
        },
    }
}
