const std = @import("std");

pub fn contracts(comptime V: type) !void {
    const allocator = std.testing.allocator;
    const plain = "root Zstd decode memory quota and owned output";
    const wire = try V.zstdEncodeRawOrRleFrameAlloc(allocator, plain);
    defer allocator.free(wire);
    var profile: V.ZstdDecodeMemoryProfile = .{};
    const decoded = try V.zstdDecodeFrameAllocWithOptions(allocator, wire, .{ .memory_profile = &profile });
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings(plain, decoded);
    try std.testing.expect(profile.available);
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    const peak = profile.peak_requested_bytes;
    const exact = try V.zstdDecodeFrameAllocWithOptions(allocator, wire, .{ .max_total_working_memory = peak });
    defer allocator.free(exact);
    try std.testing.expectEqualStrings(plain, exact);
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, V.zstdDecodeFrameAllocWithOptions(allocator, wire, .{ .max_total_working_memory = peak - 1 }));
    try std.testing.expectEqual(plain.len, try V.zstdDecodedFrameSizeWithOptions(wire, .{ .max_total_working_memory = 0 }));

    profile.reset();
    var decoder = V.ZstdNativeFrameDecoder.initWithOptions(allocator, .{ .memory_profile = &profile });
    defer decoder.deinit();
    const scratch = try decoder.decodeScratch(wire);
    try std.testing.expectEqualStrings(plain, scratch);
    const snapshot: V.ZstdDecodeMemorySnapshot = decoder.memorySnapshot();
    try std.testing.expect(snapshot.available);
    try std.testing.expect(snapshot.live_requested_bytes >= decoder.scratch.capacity);
    try std.testing.expectEqual(profile.live_requested_bytes, snapshot.live_requested_bytes);
}
