const std = @import("std");
const h = @import("helpers.zig");
const Mode = enum { alloc, limited, exact, prefix, prefix_limited, prefix_exact, chunks, chunks_limited, chunks_exact, prefix_chunks, prefix_chunks_limited, prefix_chunks_exact };

pub fn contracts(comptime B: type, sample: h.Sample(B)) !void {
    inline for (std.enums.values(Mode)) |mode| {
        errdefer std.debug.print("Brotli owned memory mode: {s}\n", .{@tagName(mode)});
        const peak = try invoke(B, mode, sample, null, true, false);
        try std.testing.expect(peak != 0);
        try std.testing.expectEqual(peak, try invoke(B, mode, sample, peak, true, false));
        try std.testing.expectEqual(peak, try invoke(B, mode, sample, peak, false, false));
        _ = try invoke(B, mode, sample, peak - 1, true, true);
        _ = try invoke(B, mode, sample, peak - 1, false, true);
    }
}

fn isPrefix(comptime mode: Mode) bool {
    return mode == .prefix or mode == .prefix_limited or mode == .prefix_exact or
        mode == .prefix_chunks or mode == .prefix_chunks_limited or mode == .prefix_chunks_exact;
}

noinline fn invoke(comptime B: type, comptime mode: Mode, sample: h.Sample(B), limit: ?usize, comptime profiled: bool, denied: bool) !usize {
    var tracker = h.CountingAllocator.init(h.a);
    const heap = tracker.allocator();
    var profile: B.DecodeMemoryProfile = .{};
    var options = sample.options;
    options.max_total_working_memory = limit;
    options.memory_profile = if (profiled) &profile else null;
    const joined = try std.mem.concat(h.a, u8, &.{ sample.wire, "\xffnext member" });
    defer h.a.free(joined);
    const stream = if (isPrefix(mode)) joined else sample.wire;
    const chunks = [_][]const u8{ "", stream[0..1], "", stream[1 .. stream.len - 1], stream[stream.len - 1 ..], "" };
    const scratch = try h.a.alloc(u8, stream.len + 7);
    defer h.a.free(scratch);
    @memset(scratch, 0xa5);
    tracker.begin();
    const result = call(B, mode, heap, stream, &chunks, scratch[0..stream.len], sample.plain.len, options);
    if (denied) {
        // Free unexpected success before reporting a contract failure.
        if (result) |decoded| {
            heap.free(decoded.bytes);
            return error.ExpectedWorkingMemoryLimitExceeded;
        } else |err| try std.testing.expectEqual(error.WorkingMemoryLimitExceeded, err);
    } else {
        const decoded = try result;
        try std.testing.expectEqualSlices(u8, sample.plain, decoded.bytes);
        try std.testing.expectEqual(sample.wire.len, decoded.input_read);
        try std.testing.expectEqual(sample.plain.len, decoded.output_written);
        if (profiled) try h.profileMatches(profile, &tracker);
        heap.free(decoded.bytes);
    }
    try std.testing.expectEqual(@as(usize, 0), tracker.live);
    try std.testing.expectEqual(@as(usize, 0), tracker.failures);
    if (profiled) {
        try h.profileMatches(profile, &tracker);
        try std.testing.expectEqual(limit, profile.limit);
    } else try std.testing.expect(!profile.available);
    if (limit) |cap| try std.testing.expect(tracker.peak <= cap);
    try std.testing.expectEqual(@as(u8, 0xa5), scratch[stream.len]);
    return tracker.peak;
}

pub fn call(comptime B: type, comptime mode: Mode, heap: std.mem.Allocator, stream: []const u8, chunks: []const []const u8, scratch: []u8, len: usize, options: B.DecodeOptions) B.Error!B.DecodedPrefix {
    if (isPrefix(mode)) return switch (mode) {
        .prefix => B.decodeStreamPrefixAllocWithOptions(heap, stream, options),
        .prefix_limited => B.decodeStreamPrefixAllocLimitedWithOptions(heap, stream, len, options),
        .prefix_exact => B.decodeStreamPrefixAllocExactSizeWithOptions(heap, stream, len, options),
        .prefix_chunks => B.decodeStreamPrefixChunksAllocWithOptions(heap, chunks, scratch, options),
        .prefix_chunks_limited => B.decodeStreamPrefixChunksAllocLimitedWithOptions(heap, chunks, scratch, len, options),
        .prefix_chunks_exact => B.decodeStreamPrefixChunksAllocExactSizeWithOptions(heap, chunks, scratch, len, options),
        else => unreachable,
    };
    const bytes = try switch (mode) {
        .alloc => B.decodeStreamAllocWithOptions(heap, stream, options),
        .limited => B.decodeStreamAllocLimitedWithOptions(heap, stream, len, options),
        .exact => B.decodeStreamAllocExactSizeWithOptions(heap, stream, len, options),
        .chunks => B.decodeStreamChunksAllocWithOptions(heap, chunks, scratch, options),
        .chunks_limited => B.decodeStreamChunksAllocLimitedWithOptions(heap, chunks, scratch, len, options),
        .chunks_exact => B.decodeStreamChunksAllocExactSizeWithOptions(heap, chunks, scratch, len, options),
        else => unreachable,
    };
    return .{ .bytes = bytes, .input_read = stream.len, .output_written = bytes.len };
}
