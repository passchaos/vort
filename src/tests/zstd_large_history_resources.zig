const std = @import("std");
const zstd = @import("../zstd.zig");
const h = @import("zstd_large_history_helpers.zig");
const a = std.testing.allocator;

test "Zstd large history total peak exact and one below use independent requested byte accounting" {
    for ([_]zstd.Strategy{ .fast, .lazy, .btopt }) |strategy| {
        var tracked = h.TrackingAllocator.init(a);
        tracked.force_copy_reallocation = true;
        var memory: zstd.EncodeMemoryProfile = .{};
        var controls: zstd.EncoderControlProfile = .{};
        var options: zstd.NativeFrameOptions = .{ .include_content_size = false, .window_log = 27, .max_match_history_len = 128 * 1024 * 1024, .strategy = strategy, .control_profile = &controls, .memory_profile = &memory };
        const encoded = try zstd.encodeNativeFrameWithOptionsAlloc(tracked.allocator(), h.plain, options);
        const expected = try a.dupe(u8, encoded.frame);
        defer a.free(expected);
        const peak = tracked.peak;
        try std.testing.expect(memory.available);
        try std.testing.expectEqual(peak, memory.peak_requested_bytes);
        try std.testing.expectEqual(@as(usize, 0), memory.live_requested_bytes);
        try std.testing.expectEqual(encoded.frame.len, tracked.live);
        tracked.allocator().free(encoded.frame);
        memory.reset();
        tracked.beginMeasurement();
        options.max_total_working_memory = peak;
        const exact = try zstd.encodeNativeFrameWithOptionsAlloc(tracked.allocator(), h.plain, options);
        try std.testing.expectEqualSlices(u8, expected, exact.frame);
        try std.testing.expectEqual(peak, tracked.peak);
        tracked.allocator().free(exact.frame);
        memory.reset();
        options.max_total_working_memory = peak - 1;
        try std.testing.expectError(error.WorkingMemoryLimitExceeded, zstd.encodeNativeFrameWithOptionsAlloc(tracked.allocator(), h.plain, options));
        try std.testing.expectEqual(@as(usize, 0), tracked.live);
        try std.testing.expectEqual(@as(usize, 0), memory.live_requested_bytes);
        try std.testing.expectEqual(tracked.allocated_bytes, tracked.freed_bytes);
    }
}

test "Zstd large history zero total quota rejects empty and nonempty work before backing allocation" {
    for ([_][]const u8{ "", h.plain }) |input| {
        var tracked = h.TrackingAllocator.init(a);
        tracked.fail_alloc_after = 0;
        var profile: zstd.EncodeMemoryProfile = .{};
        try std.testing.expectError(error.WorkingMemoryLimitExceeded, zstd.encodeNativeFrameWithOptionsAlloc(tracked.allocator(), input, .{ .window_log = 27, .max_match_history_len = 128 * 1024 * 1024, .max_total_working_memory = 0, .memory_profile = &profile }));
        try std.testing.expectEqual(@as(usize, 0), tracked.alloc_attempts);
        try std.testing.expectEqual(@as(usize, 0), tracked.live);
        try std.testing.expect(profile.available);
        try std.testing.expectEqual(@as(?usize, 0), profile.limit);
    }
}

test "Zstd large history public level options propagate total quota through fast lazy and high quality encoding" {
    for ([_]c_int{ -3, 5, 18 }) |level| {
        var tracked = h.TrackingAllocator.init(a);
        tracked.force_copy_reallocation = true;
        var memory: zstd.EncodeMemoryProfile = .{};
        var options: zstd.FrameOptions = .{ .include_content_size = false, .window_log = 27, .max_match_history_len = 128 * 1024 * 1024, .memory_profile = &memory };
        const bytes = try zstd.encodeFrameWithLevelAndOptionsAlloc(tracked.allocator(), h.plain, level, options);
        const expected = try a.dupe(u8, bytes);
        defer a.free(expected);
        const peak = tracked.peak;
        try std.testing.expectEqual(peak, memory.peak_requested_bytes);
        try std.testing.expect(memory.available);
        try std.testing.expectEqual(@as(usize, 0), memory.live_requested_bytes);
        tracked.allocator().free(bytes);
        options.max_total_working_memory = peak;
        memory.reset();
        tracked.beginMeasurement();
        const exact = try zstd.encodeFrameWithLevelAndOptionsAlloc(tracked.allocator(), h.plain, level, options);
        try std.testing.expectEqualSlices(u8, expected, exact);
        try std.testing.expectEqual(peak, tracked.peak);
        tracked.allocator().free(exact);
        options.max_total_working_memory = peak - 1;
        try std.testing.expectError(error.WorkingMemoryLimitExceeded, zstd.encodeFrameWithLevelAndOptionsAlloc(tracked.allocator(), h.plain, level, options));
        try std.testing.expectEqual(@as(usize, 0), tracked.live);
        options.max_total_working_memory = null;
        memory.reset();
        tracked.beginMeasurement();
        const dictionary: zstd.NativeDictionary = .{ .id = 42, .content = h.prefix };
        const attached = try zstd.encodeFrameWithLevelAndOptionsAndDictionaryAlloc(tracked.allocator(), h.plain, level, options, dictionary);
        try std.testing.expectEqual(tracked.peak, memory.peak_requested_bytes);
        const decoded = try zstd.decodeFrameAllocWithDictionary(a, attached, dictionary);
        defer a.free(decoded);
        try std.testing.expectEqualSlices(u8, h.plain, decoded);
        tracked.allocator().free(attached);
        try std.testing.expectEqual(@as(usize, 0), tracked.live);
    }
}

const AllocationGraph = struct {
    pub fn run(backing: std.mem.Allocator) !void {
        var tracked = h.TrackingAllocator.init(backing);
        tracked.force_copy_reallocation = true;
        var memory: zstd.EncodeMemoryProfile = .{};
        var controls: zstd.EncoderControlProfile = .{};
        const encoded = zstd.encodeNativeFrameWithOptionsAlloc(tracked.allocator(), h.plain[0..64], .{ .window_log = 27, .max_match_history_len = 128 * 1024 * 1024, .strategy = .fast, .memory_profile = &memory, .control_profile = &controls }) catch |err| {
            try std.testing.expectEqual(@as(usize, 0), tracked.live);
            try std.testing.expectEqual(@as(usize, 0), memory.live_requested_bytes);
            try std.testing.expectEqualDeep(zstd.EncoderControlProfile.Emitted{}, controls.emitted());
            return err;
        };
        tracked.allocator().free(encoded.frame);
        try std.testing.expectEqual(@as(usize, 0), tracked.live);
        try std.testing.expectEqual(tracked.allocated_bytes, tracked.freed_bytes);
    }
};

test "Zstd large history tiny total tracked allocation failures release every nested encoder buffer" {
    try std.testing.checkAllAllocationFailures(a, AllocationGraph.run, .{});
}
