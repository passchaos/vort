const std = @import("std");
const br = @import("../br.zig");
const h = @import("br_large_window_helpers.zig");
const a = std.testing.allocator;

test "Brotli large window invalid legacy and width combinations reject before any allocation or output" {
    for ([_]br.PlannedEncodeOptions{
        .{ .large_window = true },
        .{ .quality = 9, .large_window = true },
        .{ .quality = 10, .large_window = true },
        .{ .quality = 10, .hq = .{}, .large_window = true, .window_bits = 9 },
        .{ .quality = 11, .hq = .{}, .large_window = true, .window_bits = 31 },
        .{ .quality = 11, .hq = .{}, .window_bits = 25 },
    }) |options| {
        var tracked = h.TrackingAllocator.init(a);
        tracked.fail_alloc_after = 0;
        try std.testing.expectError(error.InvalidBlockPlan, br.encodePlannedStreamWithOptionsAlloc(tracked.allocator(), h.plain, options));
        try std.testing.expectEqual(@as(usize, 0), tracked.alloc_attempts);
        var output: [1024]u8 = @splat(0xa5);
        try std.testing.expectError(error.InvalidBlockPlan, br.encodePlannedStreamWithOptionsInto(h.plain, &output, options));
        try h.untouched(&output);
    }
}

test "Brotli large window total memory exact requested peak and one below remain independent of HQ cap" {
    var tracked = h.TrackingAllocator.init(a);
    tracked.force_moving_growth = true;
    var total: br.EncodeMemoryProfile = .{};
    var workspace: br.HqProfile = .{};
    var options: br.PlannedEncodeOptions = .{
        .quality = 11,
        .window_bits = 30,
        .large_window = true,
        .memory_profile = &total,
        .hq = .{ .profile = &workspace },
    };
    const bytes = try br.encodePlannedStreamWithOptionsAlloc(tracked.allocator(), h.plain, options);
    const expected = try a.dupe(u8, bytes);
    defer a.free(expected);
    const peak = tracked.peak;
    const workspace_peak = workspace.peak_working_memory;
    try std.testing.expectEqual(peak, total.peak_requested_bytes);
    try std.testing.expect(peak > workspace_peak and workspace_peak > 0);
    tracked.allocator().free(bytes);
    try std.testing.expectEqual(@as(usize, 0), tracked.live);
    total.reset();
    workspace.reset();
    tracked.beginMeasurement();
    options.max_total_working_memory = peak;
    options.hq.?.max_working_memory = workspace_peak;
    const exact = try br.encodePlannedStreamWithOptionsAlloc(tracked.allocator(), h.plain, options);
    try std.testing.expectEqualSlices(u8, expected, exact);
    try std.testing.expectEqual(tracked.peak, total.peak_requested_bytes);
    tracked.allocator().free(exact);
    options.max_total_working_memory = peak - 1;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, br.encodePlannedStreamWithOptionsAlloc(tracked.allocator(), h.plain, options));
    try std.testing.expectEqual(@as(usize, 0), tracked.live);
    options.max_total_working_memory = null;
    options.hq.?.max_working_memory = workspace_peak - 1;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, br.encodePlannedStreamWithOptionsAlloc(tracked.allocator(), h.plain, options));
    try std.testing.expectEqual(@as(usize, 0), tracked.live);
}
