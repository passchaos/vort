//! Observe physical requested bytes independently of the production ledger.
const std = @import("std");
pub const a = std.testing.allocator;

pub fn Sample(comptime B: type) type {
    return struct { name: []const u8, wire: []const u8, plain: []const u8, options: B.DecodeOptions = .{} };
}

pub const CountingAllocator = struct {
    backing: std.mem.Allocator,
    live: usize = 0,
    peak: usize = 0,
    attempts: usize = 0,
    failures: usize = 0,
    fail_at: ?usize = null,
    moving_growths: usize = 0,

    pub fn init(backing: std.mem.Allocator) CountingAllocator {
        return .{ .backing = backing };
    }
    pub fn allocator(self: *CountingAllocator) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }
    pub fn begin(self: *CountingAllocator) void {
        self.peak = self.live;
        self.attempts = 0;
        self.failures = 0;
        self.moving_growths = 0;
    }
    fn change(self: *CountingAllocator, old: usize, new: usize) void {
        std.debug.assert(self.live >= old);
        self.live = self.live - old + new;
        self.peak = @max(self.peak, self.live);
    }
    fn alloc(ptr: *anyopaque, len: usize, alignment: std.mem.Alignment, ret: usize) ?[*]u8 {
        const self: *CountingAllocator = @ptrCast(@alignCast(ptr));
        const index = self.attempts;
        self.attempts += 1;
        if (self.fail_at) |at| if (index >= at) {
            self.failures += 1;
            return null;
        };
        const result = self.backing.rawAlloc(len, alignment, ret) orelse return null;
        self.change(0, len);
        return result;
    }
    fn resize(ptr: *anyopaque, memory: []u8, alignment: std.mem.Alignment, len: usize, ret: usize) bool {
        const self: *CountingAllocator = @ptrCast(@alignCast(ptr));
        if (len > memory.len) {
            self.moving_growths += 1;
            return false;
        }
        if (!self.backing.rawResize(memory, alignment, len, ret)) return false;
        self.change(memory.len, len);
        return true;
    }
    fn remap(ptr: *anyopaque, memory: []u8, alignment: std.mem.Alignment, len: usize, ret: usize) ?[*]u8 {
        const self: *CountingAllocator = @ptrCast(@alignCast(ptr));
        if (len > memory.len) {
            self.moving_growths += 1;
            return null;
        }
        const result = self.backing.rawRemap(memory, alignment, len, ret) orelse return null;
        self.change(memory.len, len);
        return result;
    }
    fn free(ptr: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ret: usize) void {
        const self: *CountingAllocator = @ptrCast(@alignCast(ptr));
        self.backing.rawFree(memory, alignment, ret);
        self.change(memory.len, 0);
    }
};

pub fn profileMatches(profile: anytype, tracker: *const CountingAllocator) !void {
    try std.testing.expect(profile.available);
    try std.testing.expectEqual(tracker.peak, profile.peak_requested_bytes);
    // Completed one-shot operations have transferred caller output ownership.
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
}

pub fn zeroProfile(profile: anytype, limit: ?usize) !void {
    try std.testing.expect(profile.available);
    try std.testing.expectEqual(@as(usize, 0), profile.peak_requested_bytes);
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    try std.testing.expectEqual(limit, profile.limit);
}

pub fn observerContract() !void {
    var tracker = CountingAllocator.init(a);
    const heap = tracker.allocator();
    var list = std.ArrayList(u8).fromOwnedSlice(try heap.dupe(u8, "old"));
    const old = list.capacity;
    try list.appendSlice(heap, "new capacity must overlap the old allocation");
    try std.testing.expectEqual(old + list.capacity, tracker.peak);
    try std.testing.expect(tracker.moving_growths != 0);
    list.deinit(heap);
    try std.testing.expectEqual(@as(usize, 0), tracker.live);
}
