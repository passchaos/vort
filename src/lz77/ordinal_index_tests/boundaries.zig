const std = @import("std");
const Harness = @import("fixture.zig").Harness;

pub fn check(comptime Codec: type) !void {
    const H = Harness(Codec);
    const allocator = H.allocator;
    const poison = H.poison;
    const poison16 = H.poison16;
    const empty16 = H.empty16;
    const checked16 = H.checked16;
    const linearBoundaryFixture = H.linearBoundaryFixture;
    const compareCandidates = H.compareCandidates;
    const cursor_module = Codec;
    // 65536-byte boundary reaches highest ordinal and four-byte start
    {
        var fixture = try linearBoundaryFixture();
        defer fixture.deinit();
        try std.testing.expectEqual(@as(usize, 65536), fixture.scratch.ordinals.items.len);
        try std.testing.expectEqual(@as(u16, 65534), fixture.scratch.ordinals.items[65533]);
        try std.testing.expectEqual(@as(u16, 65532), try checked16(65532));
        try std.testing.expectEqual(empty16, fixture.scratch.four_prev.items[0]);
        var first = cursor_module.Cursor.init(fixture.three_prev, fixture.scratch.four_prev.items, fixture.scratch.ordinals.items, fixture.input, 0, 128, 65536);
        try std.testing.expectEqual(cursor_module.empty, first.current);
        try std.testing.expectEqual(@as(?u32, null), first.next(fixture.input));
        var last = cursor_module.Cursor.init(fixture.three_prev, fixture.scratch.four_prev.items, fixture.scratch.ordinals.items, fixture.input, 65532, 1, 1);
        try std.testing.expectEqual(@as(u32, 65531), last.current);
        try std.testing.expectEqual(@as(?u32, 65531), last.next(fixture.input));
        try std.testing.expectEqual(@as(?u32, null), last.next(fixture.input));
        for ([_]usize{ 0, 1, 128 }) |quota| {
            for ([_]usize{ 0, 1, 127, 128, 129, 65531, 65532, 65533 }) |window| {
                const stats = try compareCandidates(&fixture, 65532, quota, window);
                try std.testing.expectEqual(@min(quota, @min(window, @as(usize, 65532))), stats.returned);
            }
        }
        try fixture.expectImmutable();
    }

    // 65537-byte prepare rejects before allocation or cleanup
    {
        const three_prev = try allocator.alloc(u32, 65537);
        defer allocator.free(three_prev);
        @memset(three_prev, poison);
        const saved = try allocator.dupe(u32, three_prev);
        defer allocator.free(saved);

        var denied = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0, .resize_fail_index = 0 });
        var fresh: cursor_module.Scratch = .{};
        try std.testing.expectError(error.InvalidBlockPlan, fresh.prepare(denied.allocator(), three_prev));
        try std.testing.expect(!denied.has_induced_failure);
        try std.testing.expectEqual(@as(usize, 0), denied.allocations);
        try std.testing.expectEqual(@as(usize, 0), denied.deallocations);
        try std.testing.expectEqual(@as(usize, 0), denied.allocated_bytes);
        try std.testing.expectEqual(@as(usize, 0), denied.freed_bytes);
        try std.testing.expectEqual(@as(usize, 0), fresh.ordinals.items.len);
        try std.testing.expectEqual(@as(usize, 0), fresh.ordinals.capacity);
        try std.testing.expectEqual(@as(usize, 0), fresh.four_prev.items.len);
        try std.testing.expectEqual(@as(usize, 0), fresh.four_prev.capacity);

        // Rejection must also preserve an existing reusable Scratch allocation.
        var tracked = std.testing.FailingAllocator.init(allocator, .{});
        var reused: cursor_module.Scratch = .{};
        defer reused.deinit(tracked.allocator());
        try reused.prepare(tracked.allocator(), &.{ cursor_module.empty, 0, poison, poison });
        @memset(reused.ordinals.items[2..], poison16);
        @memset(reused.four_prev.items, poison16);
        const saved_ordinals = try allocator.dupe(u16, reused.ordinals.items);
        defer allocator.free(saved_ordinals);
        const saved_four_prev = try allocator.dupe(u16, reused.four_prev.items);
        defer allocator.free(saved_four_prev);
        const ordinal_pointer = reused.ordinals.items.ptr;
        const four_pointer = reused.four_prev.items.ptr;
        const ordinal_capacity = reused.ordinals.capacity;
        const four_capacity = reused.four_prev.capacity;
        const allocations = tracked.allocations;
        const allocated_bytes = tracked.allocated_bytes;
        tracked.fail_index = tracked.alloc_index;
        tracked.resize_fail_index = tracked.resize_index;
        try std.testing.expectError(error.InvalidBlockPlan, reused.prepare(tracked.allocator(), three_prev));
        try std.testing.expect(!tracked.has_induced_failure);
        try std.testing.expectEqual(allocations, tracked.allocations);
        try std.testing.expectEqual(allocated_bytes, tracked.allocated_bytes);
        try std.testing.expectEqual(@as(usize, 0), tracked.deallocations);
        try std.testing.expectEqual(@as(usize, 0), tracked.freed_bytes);
        try std.testing.expect(reused.ordinals.items.ptr == ordinal_pointer);
        try std.testing.expect(reused.four_prev.items.ptr == four_pointer);
        try std.testing.expectEqual(ordinal_capacity, reused.ordinals.capacity);
        try std.testing.expectEqual(four_capacity, reused.four_prev.capacity);
        try std.testing.expectEqualSlices(u16, saved_ordinals, reused.ordinals.items);
        try std.testing.expectEqualSlices(u16, saved_four_prev, reused.four_prev.items);
        try std.testing.expectEqualSlices(u32, saved, three_prev);
    }
}
