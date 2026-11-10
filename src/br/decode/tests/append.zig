const std = @import("std");
const h = @import("helpers.zig");
const Mode = enum { strict, limited, exact, prefix, prefix_limited, prefix_exact, chunks, chunks_limited, chunks_exact, prefix_chunks, prefix_chunks_limited, prefix_chunks_exact };

pub fn contracts(comptime B: type, sample: h.Sample(B)) !void {
    inline for (std.enums.values(Mode)) |mode| {
        inline for (.{ false, true }) |spare| {
            errdefer std.debug.print("Brotli append mode: {s}, spare={any}\n", .{ @tagName(mode), spare });
            const peak = try invoke(B, mode, spare, sample, null, true, false);
            try std.testing.expectEqual(peak, try invoke(B, mode, spare, sample, peak, true, false));
            _ = try invoke(B, mode, spare, sample, peak - 1, true, true);
            try std.testing.expectEqual(peak, try invoke(B, mode, spare, sample, peak, false, false));
            _ = try invoke(B, mode, spare, sample, peak - 1, false, true);
        }
    }
    inline for (.{ Mode.strict, Mode.exact, Mode.prefix, Mode.prefix_exact }) |mode| {
        inline for (.{ false, true }) |spare| {
            const peak = try alias(B, mode, spare, sample, null, true, false);
            _ = try alias(B, mode, spare, sample, null, false, false);
            try std.testing.expectEqual(peak, try alias(B, mode, spare, sample, peak, true, false));
            _ = try alias(B, mode, spare, sample, peak - 1, true, true);
            try std.testing.expectEqual(peak, try alias(B, mode, spare, sample, peak, false, false));
            _ = try alias(B, mode, spare, sample, peak - 1, false, true);
        }
    }
    if (!sample.options.allow_large_window and sample.options.shared_dictionary.raw_prefixes.len == 0 and sample.options.shared_dictionary.serialized == null) {
        // Call the legacy public symbols directly, including the guard before
        // their default fast paths. Compare the same physical snapshot scope
        // with the existing WithOptions(.{}) behavior on ordinary fixtures.
        inline for (.{ Mode.strict, Mode.limited, Mode.exact }) |mode| {
            inline for (.{ false, true }) |spare| {
                const default_peak = try alias(B, mode, spare, sample, null, false, false);
                const direct_peak = try aliasImpl(B, mode, spare, true, sample, null, false, false);
                try std.testing.expectEqual(default_peak, direct_peak);
            }
        }
    }
    // Existing storage must be admitted before the first control allocation.
    var tracker = h.CountingAllocator.init(h.a);
    const heap = tracker.allocator();
    var out = std.ArrayList(u8).fromOwnedSlice(try heap.dupe(u8, "caller-prefix"));
    defer out.deinit(heap);
    const pointer = out.items.ptr;
    const capacity = out.capacity;
    tracker.begin();
    var profile: B.DecodeMemoryProfile = .{};
    var options = sample.options;
    options.max_total_working_memory = capacity - 1;
    options.memory_profile = &profile;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, B.decodeStreamAppendWithOptions(heap, &out, sample.wire, options));
    try std.testing.expectEqual(pointer, out.items.ptr);
    try std.testing.expectEqual(capacity, out.capacity);
    try std.testing.expectEqualStrings("caller-prefix", out.items);
    try std.testing.expectEqual(@as(usize, 0), tracker.attempts);
    try std.testing.expectEqual(capacity, tracker.live);
    try h.profileMatches(profile, &tracker);
}

fn isPrefix(comptime mode: Mode) bool {
    return mode == .prefix or mode == .prefix_limited or mode == .prefix_exact or mode == .prefix_chunks or mode == .prefix_chunks_limited or mode == .prefix_chunks_exact;
}

noinline fn invoke(comptime B: type, comptime mode: Mode, comptime spare: bool, sample: h.Sample(B), limit: ?usize, comptime profiled: bool, denied: bool) !usize {
    var tracker = h.CountingAllocator.init(h.a);
    const heap = tracker.allocator();
    const initial = "caller-prefix";
    const capacity = initial.len + if (spare) sample.plain.len + 117 else 0;
    var out = std.ArrayList(u8).fromOwnedSlice(try heap.alloc(u8, capacity));
    @memset(out.allocatedSlice(), 0xa5);
    out.items.len = initial.len;
    @memcpy(out.items, initial);
    defer out.deinit(heap);
    const pointer = out.items.ptr;
    const before = try h.a.dupe(u8, out.allocatedSlice());
    defer h.a.free(before);
    const joined = try std.mem.concat(h.a, u8, &.{ sample.wire, "\xffnext" });
    defer h.a.free(joined);
    const stream = if (isPrefix(mode)) joined else sample.wire;
    const chunks = [_][]const u8{ "", stream[0..1], stream[1..], "" };
    const scratch = try h.a.alloc(u8, stream.len);
    defer h.a.free(scratch);
    var profile: B.DecodeMemoryProfile = .{};
    var options = sample.options;
    options.max_total_working_memory = limit;
    options.memory_profile = if (profiled) &profile else null;
    tracker.begin();
    const result = call(B, mode, heap, &out, stream, &chunks, scratch, sample.plain.len, options);
    if (denied) {
        try std.testing.expectError(error.WorkingMemoryLimitExceeded, result);
        try std.testing.expectEqual(pointer, out.items.ptr);
        try std.testing.expectEqual(capacity, out.capacity);
        try std.testing.expectEqualStrings(initial, out.items);
        try std.testing.expectEqualSlices(u8, before, out.allocatedSlice());
    } else {
        const decoded = try result;
        try std.testing.expectEqual(sample.wire.len, decoded.input_read);
        try std.testing.expectEqual(sample.plain.len, decoded.output_written);
        try std.testing.expectEqualStrings(initial, out.items[0..initial.len]);
        try std.testing.expectEqualSlices(u8, sample.plain, out.items[initial.len..]);
        if (spare) {
            try std.testing.expectEqual(pointer, out.items.ptr);
            try std.testing.expectEqual(capacity, out.capacity);
        } else {
            try std.testing.expect(pointer != out.items.ptr);
            try std.testing.expect(tracker.moving_growths != 0);
            // Forced moving growth keeps old and full new capacity live together.
            try std.testing.expect(tracker.peak >= capacity + out.capacity);
        }
    }
    try std.testing.expectEqual(out.capacity, tracker.live);
    try std.testing.expectEqual(@as(usize, 0), tracker.failures);
    if (profiled) {
        try h.profileMatches(profile, &tracker);
        try std.testing.expectEqual(limit, profile.limit);
    } else try std.testing.expect(!profile.available);
    if (limit) |cap| try std.testing.expect(tracker.peak <= cap);
    return tracker.peak;
}

/// Input in spare capacity must be pinned just like input in published items.
/// Forced growth additionally proves that the snapshot and old capacity remain
/// admitted while the full replacement allocation is requested.
fn alias(comptime B: type, comptime mode: Mode, comptime spare: bool, sample: h.Sample(B), limit: ?usize, comptime profiled: bool, denied: bool) !usize {
    return aliasImpl(B, mode, spare, false, sample, limit, profiled, denied);
}

noinline fn aliasImpl(comptime B: type, comptime mode: Mode, comptime spare: bool, comptime direct: bool, sample: h.Sample(B), limit: ?usize, comptime profiled: bool, denied: bool) !usize {
    errdefer std.debug.print("Brotli append alias: {s}, spare={any}, direct={any}, cap={any}\n", .{ @tagName(mode), spare, direct, limit });
    var tracker = h.CountingAllocator.init(h.a);
    const heap = tracker.allocator();
    const marker = "prefix";
    const initial_len = marker.len + if (spare) @as(usize, 0) else sample.wire.len;
    const capacity = if (spare) marker.len + sample.wire.len + sample.plain.len + 127 else initial_len;
    var out = std.ArrayList(u8).fromOwnedSlice(try heap.alloc(u8, capacity));
    @memset(out.allocatedSlice(), 0xa5);
    out.items.len = initial_len;
    @memcpy(out.items[0..marker.len], marker);
    @memcpy(out.allocatedSlice()[marker.len..][0..sample.wire.len], sample.wire);
    defer out.deinit(heap);
    const pointer = out.items.ptr;
    const before = try h.a.dupe(u8, out.allocatedSlice());
    defer h.a.free(before);
    var profile: B.DecodeMemoryProfile = .{};
    var options = sample.options;
    options.max_total_working_memory = limit;
    options.memory_profile = if (profiled) &profile else null;
    tracker.begin();
    const input = out.allocatedSlice()[marker.len..][0..sample.wire.len];
    const result = if (direct)
        callDirect(B, mode, heap, &out, input, sample.plain.len)
    else
        call(B, mode, heap, &out, input, &.{}, &.{}, sample.plain.len, options);
    if (denied) {
        try std.testing.expectError(error.WorkingMemoryLimitExceeded, result);
        try std.testing.expectEqual(pointer, out.items.ptr);
        try std.testing.expectEqual(capacity, out.capacity);
        try std.testing.expectEqual(initial_len, out.items.len);
        try std.testing.expectEqualSlices(u8, before, out.allocatedSlice());
    } else {
        const progress = try result;
        try std.testing.expectEqual(sample.wire.len, progress.input_read);
        try std.testing.expectEqual(sample.plain.len, progress.output_written);
        try std.testing.expectEqualSlices(u8, before[0..initial_len], out.items[0..initial_len]);
        try std.testing.expectEqualSlices(u8, sample.plain, out.items[initial_len..]);
        if (spare) {
            try std.testing.expectEqual(pointer, out.items.ptr);
            try std.testing.expectEqual(capacity, out.capacity);
        } else {
            try std.testing.expect(pointer != out.items.ptr);
            try std.testing.expect(tracker.moving_growths != 0);
        }
        if (!isPrefix(mode)) {
            const overlap = if (spare) capacity else capacity + out.capacity;
            try std.testing.expect(tracker.peak >= overlap + sample.wire.len);
        }
    }
    try std.testing.expectEqual(out.capacity, tracker.live);
    try std.testing.expectEqual(@as(usize, 0), tracker.failures);
    if (profiled) {
        try h.profileMatches(profile, &tracker);
        try std.testing.expectEqual(limit, profile.limit);
    } else try std.testing.expect(!profile.available);
    if (limit) |cap| try std.testing.expect(tracker.peak <= cap);
    return tracker.peak;
}

fn callDirect(comptime B: type, comptime mode: Mode, heap: std.mem.Allocator, out: *std.ArrayList(u8), stream: []const u8, len: usize) B.Error!B.DecodePrefixResult {
    const written = try switch (mode) {
        .strict => B.decodeStreamAppend(heap, out, stream),
        .limited => B.decodeStreamAppendLimited(heap, out, stream, len),
        .exact => B.decodeStreamAppendExactSize(heap, out, stream, len),
        else => unreachable,
    };
    return .{ .input_read = stream.len, .output_written = written };
}

fn call(comptime B: type, comptime mode: Mode, heap: std.mem.Allocator, out: *std.ArrayList(u8), stream: []const u8, chunks: []const []const u8, scratch: []u8, len: usize, options: B.DecodeOptions) B.Error!B.DecodePrefixResult {
    if (isPrefix(mode)) return switch (mode) {
        .prefix => B.decodeStreamPrefixAppendWithOptions(heap, out, stream, options),
        .prefix_limited => B.decodeStreamPrefixAppendLimitedWithOptions(heap, out, stream, len, options),
        .prefix_exact => B.decodeStreamPrefixAppendExactSizeWithOptions(heap, out, stream, len, options),
        .prefix_chunks => B.decodeStreamPrefixChunksAppendWithOptions(heap, out, chunks, scratch, options),
        .prefix_chunks_limited => B.decodeStreamPrefixChunksAppendLimitedWithOptions(heap, out, chunks, scratch, len, options),
        .prefix_chunks_exact => B.decodeStreamPrefixChunksAppendExactSizeWithOptions(heap, out, chunks, scratch, len, options),
        else => unreachable,
    };
    const written = try switch (mode) {
        .strict => B.decodeStreamAppendWithOptions(heap, out, stream, options),
        .limited => B.decodeStreamAppendLimitedWithOptions(heap, out, stream, len, options),
        .exact => B.decodeStreamAppendExactSizeWithOptions(heap, out, stream, len, options),
        .chunks => B.decodeStreamChunksAppendWithOptions(heap, out, chunks, scratch, options),
        .chunks_limited => B.decodeStreamChunksAppendLimitedWithOptions(heap, out, chunks, scratch, len, options),
        .chunks_exact => B.decodeStreamChunksAppendExactSizeWithOptions(heap, out, chunks, scratch, len, options),
        else => unreachable,
    };
    return .{ .input_read = stream.len, .output_written = written };
}
