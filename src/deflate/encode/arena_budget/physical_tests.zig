//! Independent physical request graphs verify reservation ownership and overlap.
const std = @import("std");
const budget = @import("../arena_budget.zig");
const shared = @import("../../../io/requested_heap_budget.zig");
const Counting = @import("../total_budget/counting_allocator.zig").CountingAllocator;
const a = std.testing.allocator;

const Moving = struct {
    base: std.mem.Allocator,
    fn allocator(self: *@This()) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &vtable };
    }
    const vtable: std.mem.Allocator.VTable = .{ .alloc = alloc, .resize = resize, .remap = remap, .free = free };
    fn alloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, ra: usize) ?[*]u8 {
        const self: *@This() = @ptrCast(@alignCast(ctx));
        return self.base.rawAlloc(len, alignment, ra);
    }
    fn resize(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize, _: usize) bool {
        return false;
    }
    fn remap(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize, _: usize) ?[*]u8 {
        return null;
    }
    fn free(ctx: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, ra: usize) void {
        const self: *@This() = @ptrCast(@alignCast(ctx));
        self.base.rawFree(bytes, alignment, ra);
    }
};

pub fn contracts() !void {
    var count: Counting = .{ .backing = a };
    var moving: Moving = .{ .base = count.allocator() };
    var profile: shared.EncodeMemoryProfile = .{};
    var lease = try shared.Lease.init(moving.allocator(), shared.control_bytes + 61, &profile, 0);
    var physical: budget.Physical = .{ .base = moving.allocator(), .lease = lease, .live = 0 };
    const allocator = physical.allocator();
    var first = try allocator.alloc(u8, 8);
    @memset(first, 0x4e);
    const second = try allocator.alloc(u8, 13);
    first = try allocator.realloc(first, 40);
    // Forced moving growth holds old 8 + other 13 + new 40 until copy/free.
    try std.testing.expectEqual(shared.control_bytes + 61, count.peak);
    try std.testing.expectEqual(count.peak, profile.peak_requested_bytes);
    try std.testing.expect(std.mem.allEqual(u8, first[0..8], 0x4e));
    allocator.free(first);
    allocator.free(second);
    physical.handoff();
    lease.deinit();
    try std.testing.expectEqual(@as(usize, 0), count.live);
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    try std.testing.checkAllAllocationFailures(a, failureGraph, .{});
    try stickyGraph();
    inline for (.{ false, true }) |supports_growth| {
        inline for (.{ false, true }) |remap| {
            try probeGraph(supports_growth, remap, null, false);
            try probeGraph(supports_growth, remap, shared.control_bytes + 24, false);
            try probeGraph(supports_growth, remap, shared.control_bytes + 23, true);
        }
    }
}

fn failureGraph(backing: std.mem.Allocator) !void {
    var moving: Moving = .{ .base = backing };
    var profile: shared.EncodeMemoryProfile = .{};
    var lease = try shared.Lease.init(moving.allocator(), null, &profile, 0);
    defer lease.deinit();
    var physical: budget.Physical = .{ .base = moving.allocator(), .lease = lease, .live = 0 };
    defer physical.handoff();
    const allocator = physical.allocator();
    var first = try allocator.alloc(u8, 8);
    defer allocator.free(first);
    const second = try allocator.alloc(u8, 13);
    defer allocator.free(second);
    first = try allocator.realloc(first, 40);
}

fn stickyGraph() !void {
    var count: Counting = .{ .backing = a };
    var lease = try shared.Lease.init(count.allocator(), shared.control_bytes + 8, null, 0);
    var physical: budget.Physical = .{ .base = count.allocator(), .lease = lease, .live = 0 };
    const allocator = physical.allocator();
    try std.testing.expectError(error.OutOfMemory, allocator.alloc(u8, 9));
    const calls = count.calls;
    // A smaller request fits the numerical quota but cannot revive this call.
    try std.testing.expectError(error.OutOfMemory, allocator.alloc(u8, 1));
    try std.testing.expectEqual(calls, count.calls);
    try std.testing.expectEqual(@as(?budget.Error, error.WorkingMemoryLimitExceeded), physical.failure);
    physical.handoff();
    lease.deinit();
    try std.testing.expectEqual(@as(usize, 0), count.live);
}

const ProbeBase = struct {
    base: std.mem.Allocator,
    supports_growth: bool,
    growth_calls: usize = 0,
    fn allocator(self: *@This()) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &vtable };
    }
    const vtable: std.mem.Allocator.VTable = .{ .alloc = alloc, .resize = resize, .remap = remap, .free = free };
    fn alloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, ra: usize) ?[*]u8 {
        const self: *@This() = @ptrCast(@alignCast(ctx));
        return self.base.rawAlloc(len, alignment, ra);
    }
    fn resize(ctx: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, len: usize, ra: usize) bool {
        const self: *@This() = @ptrCast(@alignCast(ctx));
        if (len > bytes.len) {
            self.growth_calls += 1;
            if (!self.supports_growth) return false;
        }
        return self.base.rawResize(bytes, alignment, len, ra);
    }
    fn remap(ctx: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, len: usize, ra: usize) ?[*]u8 {
        return if (resize(ctx, bytes, alignment, len, ra)) bytes.ptr else null;
    }
    fn free(ctx: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, ra: usize) void {
        const self: *@This() = @ptrCast(@alignCast(ctx));
        self.base.rawFree(bytes, alignment, ra);
    }
};

fn probeGraph(supports_growth: bool, remap: bool, limit: ?usize, deny_actual_alloc: bool) !void {
    var storage: [2048]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&storage);
    var count: Counting = .{ .backing = fba.allocator() };
    var base: ProbeBase = .{ .base = count.allocator(), .supports_growth = supports_growth };
    var profile: shared.EncodeMemoryProfile = .{};
    {
        var lease = try shared.Lease.init(base.allocator(), limit, &profile, 0);
        defer lease.deinit();
        var physical: budget.Physical = .{ .base = base.allocator(), .lease = lease, .live = 0 };
        defer physical.handoff();
        const allocator = physical.allocator();
        var bytes = try allocator.alloc(u8, 8);
        defer allocator.free(bytes);
        @memset(bytes, 0x5d);
        const grew = if (remap)
            allocator.rawRemap(bytes, .of(u8), 80, @returnAddress()) != null
        else
            allocator.rawResize(bytes, .of(u8), 80, @returnAddress());
        if (limit != null) {
            // A declined optional probe neither calls base nor sets refusal.
            try std.testing.expect(!grew);
            try std.testing.expectEqual(@as(usize, 0), base.growth_calls);
            try std.testing.expect(!lease.snapshot().hit_limit);
            try std.testing.expectEqual(@as(?budget.Error, null), physical.failure);
        } else {
            try std.testing.expectEqual(supports_growth, grew);
            try std.testing.expectEqual(@as(usize, 1), base.growth_calls);
        }
        if (grew) {
            bytes = bytes.ptr[0..80];
            try std.testing.expectEqual(shared.control_bytes + 80, count.peak);
        } else if (deny_actual_alloc) {
            const calls = count.calls;
            try std.testing.expectError(error.OutOfMemory, allocator.alloc(u8, 16));
            try std.testing.expectEqual(calls, count.calls);
            try std.testing.expect(lease.snapshot().hit_limit);
            try std.testing.expectEqual(@as(?budget.Error, error.WorkingMemoryLimitExceeded), physical.failure);
        } else {
            const next = try allocator.alloc(u8, 16);
            @memcpy(next[0..8], bytes);
            allocator.free(bytes);
            bytes = next;
            // Actual fallback overlaps old 8 and new 16, exactly D.
            try std.testing.expectEqual(shared.control_bytes + 24, count.peak);
        }
        try std.testing.expect(std.mem.allEqual(u8, bytes[0..8], 0x5d));
        try std.testing.expectEqual(count.peak, profile.peak_requested_bytes);
        if (limit) |cap| try std.testing.expect(count.peak <= cap);
    }
    try std.testing.expectEqual(@as(usize, 0), count.live);
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
}
