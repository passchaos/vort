const std = @import("std");
const h = @import("helpers.zig");
const Mode = enum { alloc, exact, prefix, append };

pub fn contracts(comptime B: type, stored: h.Sample(B), compressed: h.Sample(B)) !void {
    for ([_]h.Sample(B){ stored, compressed }) |sample| {
        inline for (std.enums.values(Mode)) |mode| {
            const attempts = try oom(B, mode, sample, null);
            try std.testing.expect(attempts != 0);
            for (0..attempts) |failure| _ = try oom(B, mode, sample, failure);
        }
        try errorIdentity(B, sample);
    }
    try scalarPreflight(B, stored);
}

fn scalarPreflight(comptime B: type, sample: h.Sample(B)) !void {
    const f = @import("fixtures.zig");
    var tracker = h.CountingAllocator.init(h.a);
    tracker.fail_at = 0;
    const heap = tracker.allocator();
    var profile: B.DecodeMemoryProfile = .{};
    var options: B.DecodeOptions = .{ .max_total_working_memory = 0, .memory_profile = &profile };
    try std.testing.expectError(error.CorruptFrame, B.decodeStreamAllocWithOptions(heap, &f.large, options));
    const too_many = [_][]const u8{""} ** 16;
    options.shared_dictionary = .{ .raw_prefixes = &too_many };
    try std.testing.expectError(error.CorruptFrame, B.decodeStreamAllocWithOptions(heap, sample.wire, options));
    options.shared_dictionary = .{};
    const metadata = try B.encodeStoredStreamWithOptionsAlloc(h.a, "", .{ .metadata = "truncated metadata before any payload" });
    defer h.a.free(metadata);
    try std.testing.expectError(error.TruncatedFrame, B.decodeStreamAllocWithOptions(heap, metadata[0 .. metadata.len / 2], options));
    try std.testing.expectError(error.OutputLimitExceeded, B.decodeStreamAllocLimitedWithOptions(heap, sample.wire, sample.plain.len - 1, options));
    try std.testing.expectEqual(@as(usize, 0), tracker.attempts);
    try h.zeroProfile(profile, 0);

    // Allocating-summary errors keep the fixed parser's diagnostic location.
    var expected: B.StreamSummaryDiagnostics = .{};
    var actual: B.StreamSummaryDiagnostics = .{};
    const truncated = sample.wire[0 .. sample.wire.len - 1];
    const oracle = B.summarizeStreamWithOptionsAndDiagnostics(truncated, .{}, &expected);
    const observed = B.summarizeStreamAllocWithOptionsAndDiagnostics(heap, truncated, options, &actual);
    if (oracle) |_| return error.ExpectedTruncatedSummary else |err| try std.testing.expectError(err, observed);
    try std.testing.expectEqualDeep(expected, actual);
    try std.testing.expectEqual(@as(usize, 0), tracker.attempts);

    var out = std.ArrayList(u8).fromOwnedSlice(try h.a.dupe(u8, "unchanged caller"));
    defer out.deinit(h.a);
    const pointer = out.items.ptr;
    const capacity = out.capacity;
    try std.testing.expectError(error.TruncatedFrame, B.decodeStreamAppendWithOptions(heap, &out, truncated, options));
    try std.testing.expectError(error.OutputLimitExceeded, B.decodeStreamAppendLimitedWithOptions(heap, &out, sample.wire, sample.plain.len - 1, options));
    try std.testing.expectEqual(pointer, out.items.ptr);
    try std.testing.expectEqual(capacity, out.capacity);
    try std.testing.expectEqualStrings("unchanged caller", out.items);
    try std.testing.expectEqual(@as(usize, 0), tracker.attempts);
}

noinline fn oom(comptime B: type, comptime mode: Mode, sample: h.Sample(B), failure: ?usize) !usize {
    errdefer std.debug.print("Brotli actual OOM mode={s}, fail_at={any}\n", .{ @tagName(mode), failure });
    var tracker = h.CountingAllocator.init(h.a);
    const heap = tracker.allocator();
    var out = std.ArrayList(u8).fromOwnedSlice(try heap.dupe(u8, "preserve me"));
    defer out.deinit(heap);
    const pointer = out.items.ptr;
    const capacity = out.capacity;
    tracker.begin();
    tracker.fail_at = failure;
    var profile: B.DecodeMemoryProfile = .{};
    var options = sample.options;
    options.max_total_working_memory = std.math.maxInt(usize);
    options.memory_profile = &profile;
    const result: B.Error!void = blk: {
        if (mode == .append) {
            _ = B.decodeStreamAppendWithOptions(heap, &out, sample.wire, options) catch |err| break :blk err;
        } else if (mode == .prefix) {
            const decoded = B.decodeStreamPrefixAllocWithOptions(heap, sample.wire, options) catch |err| break :blk err;
            decoded.deinit(heap);
        } else {
            const decoded = (if (mode == .exact)
                B.decodeStreamAllocExactSizeWithOptions(heap, sample.wire, sample.plain.len, options)
            else
                B.decodeStreamAllocWithOptions(heap, sample.wire, options)) catch |err| break :blk err;
            heap.free(decoded);
        }
        break :blk {};
    };
    if (failure != null) {
        try std.testing.expectError(error.OutOfMemory, result);
        try std.testing.expect(tracker.failures != 0);
        try std.testing.expectEqual(pointer, out.items.ptr);
        try std.testing.expectEqual(capacity, out.capacity);
        try std.testing.expectEqualStrings("preserve me", out.items);
    } else try result;
    try std.testing.expectEqual(out.capacity, tracker.live);
    if (profile.available) try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    return tracker.attempts;
}

fn errorIdentity(comptime B: type, sample: h.Sample(B)) !void {
    const joined = try std.mem.concat(h.a, u8, &.{ sample.wire, "\xfftail" });
    defer h.a.free(joined);
    const chunks = [_][]const u8{ joined[0..1], "", joined[1..] };
    const scratch = try h.a.alloc(u8, joined.len);
    defer h.a.free(scratch);
    const output = try h.a.alloc(u8, sample.plain.len + 1);
    defer h.a.free(output);
    var profile: B.DecodeMemoryProfile = .{};
    var options = sample.options;
    options.max_total_working_memory = std.math.maxInt(usize);
    options.memory_profile = &profile;
    try std.testing.expectError(error.TrailingData, B.decodeStreamAllocWithOptions(h.a, joined, options));
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    try std.testing.expectError(error.TrailingData, B.decodeStreamChunksAllocWithOptions(h.a, &chunks, scratch, options));
    try std.testing.expectError(error.TrailingData, B.decodedStreamSizeWithOptions(joined, options));
    try std.testing.expectError(error.OutputLimitExceeded, B.decodeStreamPrefixAllocLimitedWithOptions(h.a, joined, sample.plain.len - 1, options));
    try std.testing.expectError(error.SizeMismatch, B.decodeStreamPrefixAllocExactSizeWithOptions(h.a, joined, sample.plain.len - 1, options));
    try std.testing.expectError(error.SizeMismatch, B.decodeStreamPrefixAllocExactSizeWithOptions(h.a, joined, sample.plain.len + 1, options));
    // Caller output and tail must remain intact after the limited preflight.
    @memset(output, 0xa5);
    try std.testing.expectError(error.OutputLimitExceeded, B.decodeStreamPrefixIntoLimitedWithOptions(joined, output, sample.plain.len - 1, options));
    for (output) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
    try std.testing.expectError(error.OutputTooSmall, B.decodeStreamPrefixIntoExactSizeWithOptions(joined, output[0 .. sample.plain.len - 1], sample.plain.len, options));
    // Empty or malformed header takes format precedence over quota control.
    options.max_total_working_memory = 0;
    try std.testing.expectError(error.TruncatedFrame, B.decodeStreamAllocWithOptions(h.a, "", options));
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, B.decodeStreamAllocWithOptions(h.a, sample.wire, options));
}
