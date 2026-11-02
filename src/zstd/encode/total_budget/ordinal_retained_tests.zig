//! Independent requested-heap accounting for retained ordinal workspace.
const std = @import("std");
const lz77 = @import("../../../lz77.zig");
const oracle = @import("../allocation_test_oracle.zig");
const total = @import("../total_budget.zig");

fn stdDecode(frame: []const u8) ![]u8 {
    var input: std.Io.Reader = .fixed(frame);
    var output: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer output.deinit();
    var decoder: std.compress.zstd.Decompress = .init(&input, &.{}, .{ .window_len = 128 * 1024 });
    _ = try decoder.reader.streamRemaining(&output.writer);
    return output.toOwnedSlice();
}

pub fn check(comptime Root: type) !void {
    var admitted: [16 * 1024]u8 = undefined;
    for (0..admitted.len / 8) |record| {
        const position = record * 8;
        @memcpy(admitted[position..][0..3], "abc");
        admitted[position + 3] = @intCast(record % 251);
        @memcpy(admitted[position + 4 ..][0..4], "ZZZZ");
    }
    const parser_options: lz77.GreedyOptions = .{
        .window_len = 32768,
        .min_match = 4,
        .max_chain = 128,
        .max_candidates = 8,
    };
    var ledger = oracle.Ledger.init(std.testing.allocator);
    var profile: Root.EncodeMemoryProfile = .{};
    {
        var encoder = Root.NativeFrameEncoder.init(ledger.allocator());
        defer encoder.deinit();
        try std.testing.expectEqual(@as(usize, 0), ledger.live);
        try std.testing.expectEqual(@as(usize, 0), ledger.alloc_attempts);
        try std.testing.expectEqual(@as(usize, 0), try encoder.retainedRequestedBytes());
        try std.testing.expect(!encoder.memorySnapshot().available);

        _ = try lz77.optimalPlanReuse(&encoder.block_scratch.optimal, encoder.allocator, &admitted, parser_options);
        const ordinal = &encoder.block_scratch.optimal.ordinal;
        try std.testing.expectEqual(admitted.len, ordinal.ordinals.items.len);
        try std.testing.expectEqual(admitted.len, ordinal.four_prev.items.len);
        const ordinal_capacity = ordinal.ordinals.capacity;
        const four_capacity = ordinal.four_prev.capacity;
        try std.testing.expect(ordinal_capacity > 0 and four_capacity > 0);
        try std.testing.expectEqual(ledger.live, try encoder.retainedRequestedBytes());
        try std.testing.expect(!encoder.memorySnapshot().available);

        // The old route retains the previously allocated ordinal arrays.
        _ = try lz77.optimalPlanReuse(&encoder.block_scratch.optimal, encoder.allocator, "a" ** 256, parser_options);
        try std.testing.expectEqual(ordinal_capacity, ordinal.ordinals.capacity);
        try std.testing.expectEqual(four_capacity, ordinal.four_prev.capacity);
        const retained_before = try encoder.retainedRequestedBytes();
        try std.testing.expectEqual(ledger.live, retained_before);

        // Enable the public ledger after allocations already exist.
        const payload = "total budget retains ordinal parser arrays";
        const limit = try std.math.add(usize, retained_before, total.control_bytes + 128 * 1024);
        const options: Root.NativeFrameOptions = .{
            .selection = .literal_only,
            .window_log = 10,
            .max_total_working_memory = limit,
            .memory_profile = &profile,
        };
        const encoded = try encoder.encodeScratch(payload, options);
        try std.testing.expect(encoded.frame.len > 0);
        try std.testing.expect(encoded.frame.ptr == encoder.output_scratch.items.ptr);
        try std.testing.expectEqual(ordinal_capacity, ordinal.ordinals.capacity);
        try std.testing.expectEqual(four_capacity, ordinal.four_prev.capacity);

        const snapshot = encoder.memorySnapshot();
        const retained_after = try encoder.retainedRequestedBytes();
        try std.testing.expect(snapshot.available and profile.available);
        try std.testing.expectEqual(total.control_bytes, snapshot.control_bytes);
        try std.testing.expectEqual(try std.math.add(usize, retained_after, snapshot.control_bytes), snapshot.live_requested_bytes);
        try std.testing.expectEqual(ledger.live, snapshot.live_requested_bytes);
        try std.testing.expectEqual(snapshot.live_requested_bytes, profile.live_requested_bytes);
        try std.testing.expectEqual(snapshot.peak_requested_bytes, profile.peak_requested_bytes);
        try std.testing.expectEqual(@as(?usize, limit), snapshot.limit);
        try std.testing.expectEqual(@as(usize, 0), snapshot.reserved_bytes);
        try std.testing.expect(snapshot.peak_requested_bytes <= limit);
        try std.testing.expect(!snapshot.hit_limit);

        // Decoder allocations stay outside the encoder-only ledger.
        const decoded = try stdDecode(encoded.frame);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, payload, decoded);
        try std.testing.expectEqual(ledger.live, encoder.memorySnapshot().live_requested_bytes);
    }
    try std.testing.expectEqual(@as(usize, 0), ledger.live);
    try std.testing.expectEqual(ledger.allocated_bytes, ledger.freed_bytes);
}
