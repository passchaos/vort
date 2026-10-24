const std = @import("std");
const br = @import("../br.zig");
const h = @import("br_general_large_window_helpers.zig");
const a = std.testing.allocator;

test "Brotli general large window invalid widths and settings reject before caller mutation" {
    for ([_]br.PlannedEncodeOptions{
        .{ .quality = 0, .window_bits = 9, .large_window = true },
        .{ .quality = 1, .window_bits = 31, .large_window = true },
        .{ .quality = 4, .window_bits = 25, .large_window = false },
        .{ .quality = 12, .window_bits = 30, .large_window = true },
        .{ .level = .balanced, .mode = .text, .window_bits = 30, .large_window = true },
    }) |options| {
        var ledger = h.TrackingAllocator.init(a);
        ledger.fail_alloc_after = 0;
        try std.testing.expectError(error.InvalidBlockPlan, br.encodePlannedStreamWithOptionsAlloc(ledger.allocator(), h.plain, options));
        try std.testing.expectEqual(@as(usize, 0), ledger.alloc_attempts);
        var destination: [512]u8 = @splat(0xa5);
        try std.testing.expectError(error.InvalidBlockPlan, br.encodePlannedStreamWithOptionsInto(h.plain, &destination, options));
        try h.untouched(&destination);
    }
    for ([_]br.StoredStreamOptions{
        .{ .large_window = true, .window_bits = 9 },
        .{ .large_window = true, .window_bits = 31 },
        .{ .window_bits = 25 },
    }) |options| {
        var ledger = h.TrackingAllocator.init(a);
        ledger.fail_alloc_after = 0;
        try std.testing.expectError(error.InvalidBlockPlan, br.encodeStoredStreamWithOptionsAlloc(ledger.allocator(), h.plain, options));
        try std.testing.expectEqual(@as(usize, 0), ledger.alloc_attempts);
    }
}

test "Brotli general large window total requested peak is exact and one below refuses all low and legacy paths" {
    for ([_]br.PlannedEncodeOptions{
        .{ .quality = 0 }, .{ .quality = 1 }, .{ .quality = 4 }, .{ .quality = 11 }, .{ .level = .ratio },
    }) |base| {
        var ledger = h.TrackingAllocator.init(a);
        ledger.force_moving_growth = true;
        var memory: br.EncodeMemoryProfile = .{};
        var options = base;
        options.large_window = true;
        options.window_bits = 30;
        options.memory_profile = &memory;
        const bytes = try br.encodePlannedStreamWithOptionsAlloc(ledger.allocator(), h.plain, options);
        const expected = try a.dupe(u8, bytes);
        defer a.free(expected);
        try std.testing.expect(memory.available);
        try std.testing.expectEqual(ledger.peak, memory.peak_requested_bytes);
        try std.testing.expectEqual(@as(usize, 0), memory.live_requested_bytes);
        const peak = memory.peak_requested_bytes;
        ledger.allocator().free(bytes);
        try std.testing.expectEqual(@as(usize, 0), ledger.live);
        ledger.beginMeasurement();
        memory.reset();
        options.max_total_working_memory = peak;
        const exact = try br.encodePlannedStreamWithOptionsAlloc(ledger.allocator(), h.plain, options);
        try std.testing.expectEqualSlices(u8, expected, exact);
        try std.testing.expectEqual(peak, memory.peak_requested_bytes);
        ledger.allocator().free(exact);
        for ([_]usize{ 0, peak - 1 }) |limit| {
            memory.reset();
            options.max_total_working_memory = limit;
            try std.testing.expectError(error.WorkingMemoryLimitExceeded, br.encodePlannedStreamWithOptionsAlloc(ledger.allocator(), h.plain, options));
            try std.testing.expectEqual(@as(usize, 0), ledger.live);
            try std.testing.expectEqual(@as(usize, 0), memory.live_requested_bytes);
            try std.testing.expect(memory.peak_requested_bytes <= limit);
        }
    }
}

test "Brotli general large window one shot releases every allocation failure" {
    for ([_]u4{ 0, 1, 11 }) |quality|
        try std.testing.checkAllAllocationFailures(a, allocationCase, .{quality});
}

fn allocationCase(allocator: std.mem.Allocator, quality: u4) !void {
    const bytes = try br.encodePlannedStreamWithOptionsAlloc(allocator, h.plain, .{ .quality = quality, .window_bits = 30, .large_window = true });
    allocator.free(bytes);
}

test "Brotli general large window encoded bounds detect host integer overflow" {
    // The 32-bit address-space limit reaches overflow after a small number of
    // format blocks. Avoid walking an artificial 64-bit maximum-sized stream.
    if (@bitSizeOf(usize) != 32) return error.SkipZigTest;
    try std.testing.expectError(error.IntegerOverflow, br.encodedStoredStreamBoundWithOptions(std.math.maxInt(usize), .{ .window_bits = 30, .large_window = true }));
    try std.testing.expectError(error.IntegerOverflow, br.encodedPlannedStreamBoundWithOptions(std.math.maxInt(usize), .{ .quality = 0, .window_bits = 30, .large_window = true }));
    try std.testing.expectError(error.IntegerOverflow, br.encodedPlannedStreamBoundWithOptions(std.math.maxInt(usize), .{ .level = .ratio, .window_bits = 30, .large_window = true }));
}
