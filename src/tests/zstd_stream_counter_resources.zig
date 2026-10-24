const std = @import("std");
const zstd = @import("../zstd.zig");
const core = @import("../core.zig");
const h = @import("zstd_stream_counter_helpers.zig");
const a = std.testing.allocator;

test "Zstd stream counters widened history entry heap is exact and enforced by the shared quota" {
    const index_mod = @import("../zstd/incremental/encoder/history_index.zig");
    const budget_mod = @import("../zstd/encode/total_budget.zig");
    var measured: usize = 0;
    for ([_]?usize{ null, 0, 1 }) |variant| {
        var tracked = h.TrackingAllocator.init(a);
        tracked.force_copy_reallocation = true;
        var profile: zstd.EncodeMemoryProfile = .{};
        const limit: ?usize = if (variant) |below| measured - below else null;
        var lease = try budget_mod.Lease.init(tracked.allocator(), limit, &profile, 0);
        var index: index_mod.Index = .{};
        if (variant == 1) {
            try std.testing.expectError(error.OutOfMemory, index.prepare(lease.allocator(), true));
            try std.testing.expect(lease.snapshot().last_failure_was_limit);
            try std.testing.expect(tracked.peak <= measured - 1);
        } else {
            try index.prepare(lease.allocator(), true);
            const physical = (index.recent_entries.capacity + index.long_entries.capacity) * @sizeOf(h.Count);
            try std.testing.expectEqual(physical + budget_mod.control_bytes, tracked.live);
            try std.testing.expectEqual(tracked.live, profile.live_requested_bytes);
            try std.testing.expectEqual(tracked.peak, profile.peak_requested_bytes);
            if (variant == null) measured = tracked.peak else try std.testing.expectEqual(measured, tracked.peak);
        }
        index.deinit(lease.allocator());
        lease.deinit();
        try std.testing.expectEqual(@as(usize, 0), tracked.live);
        try std.testing.expectEqual(tracked.allocated_bytes, tracked.freed_bytes);
        try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    }
}

test "Zstd stream counters per frame byte budgets stay physical across repeated member accounting" {
    var tracked = h.TrackingAllocator.init(a);
    tracked.force_copy_reallocation = true;
    var profile: zstd.EncodeMemoryProfile = .{};
    var options: zstd.NativeFrameOptions = .{ .selection = .raw_or_rle, .content_checksum = true, .memory_profile = &profile };
    var encoder = try zstd.NativeIncrementalFrameEncoder.initExactSize(tracked.allocator(), options, h.rle.len);
    var destroyed = false;
    defer if (!destroyed) encoder.deinit();
    const first = try h.drive(a, &encoder, &h.rle, 31, 17);
    defer a.free(first);
    const peak = tracked.peak;
    try std.testing.expectEqual(peak, profile.peak_requested_bytes);
    const repeat: h.Count = (@as(h.Count, 1) << 32) / @as(h.Count, @intCast(first.len)) + 2;
    _ = try h.seedCompletedEncoder(&encoder, repeat);
    const before = encoder.snapshot();
    options.max_total_working_memory = tracked.live - 1;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, encoder.nextFrameExactSize(options, h.rle.len));
    try std.testing.expectEqualDeep(before, encoder.snapshot());
    options.max_total_working_memory = peak;
    try encoder.nextFrameExactSize(options, h.rle.len);
    const exact = try h.drive(a, &encoder, &h.rle, 1, 1);
    defer a.free(exact);
    try std.testing.expectEqualSlices(u8, first, exact);
    encoder.deinit();
    destroyed = true;
    try std.testing.expectEqual(@as(usize, 0), tracked.live);
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
}
