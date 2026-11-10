//! Sticky operation refusal must survive an optional candidate that continues.
const std = @import("std");
const budget = @import("../total_budget.zig");
const Counting = @import("counting_allocator.zig").CountingAllocator;
const a = std.testing.allocator;
const Options = struct {
    max_total_working_memory: ?usize = null,
    memory_profile: ?*budget.EncodeMemoryProfile = null,
    preserved: u8 = 19,
};
const Owner = struct {
    allocator: std.mem.Allocator,
    options: Options = .{},
    scratch: std.ArrayList(u8) = .empty,
    refused: bool = false,
    continued: bool = false,
    published: bool = false,

    fn optional(self: *@This()) !void {
        // Simulate an optional candidate whose caller catches allocator OOM.
        // The smaller winning wire below can still physically fit the cap.
        const candidate = self.allocator.alloc(u8, 256 * 1024) catch {
            self.refused = true;
            self.continued = true;
            return;
        };
        self.allocator.free(candidate);
        return error.InvalidBlockPlan;
    }
    fn owned(self: *@This()) ![]u8 {
        try self.optional();
        return self.allocator.dupe(u8, "new");
    }
    fn append(self: *@This(), output: *std.ArrayList(u8)) !usize {
        try self.optional();
        try output.appendSlice(self.allocator, "new");
        self.published = true;
        return 3;
    }
    fn retain(self: *@This()) ![]const u8 {
        try self.optional();
        const result = try budget.retainScratch(self, "new");
        self.published = true;
        return result;
    }
    fn into(self: *@This(), bytes: []const u8, output: []u8) !usize {
        try self.optional();
        try budget.beforePublish(self.allocator);
        @memcpy(output[0..bytes.len], bytes);
        self.published = true;
        return bytes.len;
    }
};

pub fn contracts(comptime C: type) !void {
    try callbacks();
    try inheritedFrame(C);
    inline for (.{ C.RawDeflateEncoder, C.ZlibEncoder, C.GzipEncoder }) |Encoder| try inheritedScratch(C, Encoder);
    var failing = std.testing.FailingAllocator.init(a, .{ .fail_index = 0 });
    try budget.beforePublish(failing.allocator());
    try std.testing.expectEqual(@as(usize, 0), failing.allocated_bytes);
}

fn callbacks() !void {
    inline for (.{ .alloc, .append, .scratch, .into }) |kind| {
        var count: Counting = .{ .backing = a };
        const caller = count.allocator();
        var owner: Owner = .{ .allocator = caller };
        try owner.scratch.ensureTotalCapacity(caller, 16);
        @memset(owner.scratch.allocatedSlice(), 0x93);
        owner.scratch.appendSliceAssumeCapacity("old");
        var output: std.ArrayList(u8) = .empty;
        if (kind == .append) try output.appendSlice(caller, "prefix");
        const retained = count.live;
        const before_calls = count.calls;
        var profile: budget.EncodeMemoryProfile = .{};
        const options: Options = .{ .max_total_working_memory = budget.control_bytes + retained + 8, .memory_profile = &profile };
        owner.options = options;
        var target: [32]u8 = @splat(0x97);
        switch (kind) {
            .alloc => try std.testing.expectError(error.WorkingMemoryLimitExceeded, budget.reusable(&owner, options, Owner.owned, .{&owner}, .alloc)),
            .append => try std.testing.expectError(error.WorkingMemoryLimitExceeded, budget.reusable(&owner, options, Owner.append, .{ &owner, &output }, .append)),
            .scratch => try std.testing.expectError(error.WorkingMemoryLimitExceeded, budget.reusable(&owner, options, Owner.retain, .{&owner}, .scratch)),
            .into => try std.testing.expectError(error.WorkingMemoryLimitExceeded, budget.reusable(&owner, options, Owner.into, .{ &owner, @as([]const u8, "new"), @as([]u8, &target) }, .into)),
            else => unreachable,
        }
        try std.testing.expect(owner.refused and owner.continued);
        try std.testing.expectEqualDeep(options, owner.options);
        try std.testing.expectEqual(caller.ptr, owner.allocator.ptr);
        try std.testing.expectEqual(caller.vtable, owner.allocator.vtable);
        try std.testing.expectEqual(retained, count.live);
        try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
        try std.testing.expectEqualSlices(u8, "old", owner.scratch.items);
        try std.testing.expect(std.mem.allEqual(u8, owner.scratch.allocatedSlice()[3..], 0x93));
        try std.testing.expect(std.mem.allEqual(u8, &target, 0x97));
        if (kind == .append) try std.testing.expectEqualSlices(u8, "prefix", output.items);
        if (kind == .scratch or kind == .into) {
            try std.testing.expect(!owner.published);
            // Publication inspection retains the existing ledger on the stack.
            try std.testing.expectEqual(before_calls + 1, count.calls);
        }
        owner.scratch.deinit(owner.allocator);
        output.deinit(caller);
        try std.testing.expectEqual(@as(usize, 0), count.live);
    }
}

fn refuse(lease: budget.Lease) !void {
    try std.testing.expectError(error.OutOfMemory, lease.allocator().alloc(u8, 256 * 1024));
    try std.testing.expect(lease.snapshot().hit_limit);
}

fn inheritedFrame(comptime C: type) !void {
    var count: Counting = .{ .backing = a };
    var profile: C.EncodeMemoryProfile = .{};
    var lease = try budget.Lease.init(count.allocator(), budget.control_bytes + 64 * 1024, &profile, 0);
    var owner = try C.ZlibFrameEncoder.init(lease.allocator(), .{ .compression = try C.optionsForZlibLevel(3) });
    const old = try owner.encodeScratch("old frame bytes");
    const saved = try a.dupe(u8, old);
    defer a.free(saved);
    const retained = count.live;
    try refuse(lease);
    var target: [256]u8 = @splat(0x97);
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, owner.encodeInto("new frame", &target));
    try std.testing.expect(std.mem.allEqual(u8, &target, 0x97));
    try std.testing.expectEqual(retained, count.live);
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, owner.encodeScratch("new frame"));
    try std.testing.expectEqualSlices(u8, saved, owner.scratch.items);
    try std.testing.expectEqual(retained, count.live);
    try owner.setOptions(.{ .mode = .stored });
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, owner.encodeInto("new frame", &target));
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, owner.encodeStoredChunksInto(&.{ "new", " frame" }, &target));
    try std.testing.expect(std.mem.allEqual(u8, &target, 0x97));
    owner.deinit();
    lease.deinit();
    try std.testing.expectEqual(@as(usize, 0), count.live);
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
}

fn inheritedScratch(comptime C: type, comptime Encoder: type) !void {
    var count: Counting = .{ .backing = a };
    var profile: C.EncodeMemoryProfile = .{};
    var lease = try budget.Lease.init(count.allocator(), budget.control_bytes + 64 * 1024, &profile, 0);
    var owner = Encoder.init(lease.allocator());
    const options = try C.optionsForZlibLevel(3);
    const old = try owner.encodeBestScratch("old bytes", options);
    const saved = try a.dupe(u8, old);
    defer a.free(saved);
    const retained = count.live;
    try refuse(lease);
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, owner.encodeBestScratch("new bytes", options));
    try std.testing.expectEqualSlices(u8, saved, owner.scratch.items);
    try std.testing.expectEqual(retained, count.live);
    owner.deinit();
    lease.deinit();
    try std.testing.expectEqual(@as(usize, 0), count.live);
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
}
