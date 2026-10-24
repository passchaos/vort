const std = @import("std");

/// Bounds live requested allocation bytes. Allocator bookkeeping and any
/// underlying remap's internal transient memory are outside this accounting.
pub const WorkingAllocator = struct {
    backing: std.mem.Allocator,
    limit: usize,
    live: usize = 0,
    peak: usize = 0,
    hit_limit: bool = false,
    last_failure_was_limit: bool = false,
    pub fn init(backing: std.mem.Allocator, limit: usize) WorkingAllocator {
        return .{ .backing = backing, .limit = limit };
    }
    pub fn allocator(self: *WorkingAllocator) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }
    fn allow(self: *WorkingAllocator, increase: usize) bool {
        if (self.live > self.limit or increase > self.limit - self.live) {
            self.hit_limit = true;
            self.last_failure_was_limit = true;
            return false;
        }
        return true;
    }
    fn changed(self: *WorkingAllocator, old: usize, new: usize) void {
        self.live = self.live - old + new;
        self.peak = @max(self.peak, self.live);
    }
    fn alloc(raw: *anyopaque, len: usize, alignment: std.mem.Alignment, ret: usize) ?[*]u8 {
        const self: *WorkingAllocator = @ptrCast(@alignCast(raw));
        if (!self.allow(len)) return null;
        self.last_failure_was_limit = false;
        const memory = self.backing.rawAlloc(len, alignment, ret) orelse return null;
        self.changed(0, len);
        return memory;
    }
    fn resize(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, len: usize, ret: usize) bool {
        const self: *WorkingAllocator = @ptrCast(@alignCast(raw));
        if (len > memory.len and !self.allow(len - memory.len)) return false;
        self.last_failure_was_limit = false;
        if (!self.backing.rawResize(memory, alignment, len, ret)) return false;
        self.changed(memory.len, len);
        return true;
    }
    fn remap(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, len: usize, ret: usize) ?[*]u8 {
        const self: *WorkingAllocator = @ptrCast(@alignCast(raw));
        if (len > memory.len and !self.allow(len - memory.len)) return null;
        self.last_failure_was_limit = false;
        const updated = self.backing.rawRemap(memory, alignment, len, ret) orelse return null;
        self.changed(memory.len, len);
        return updated;
    }
    fn free(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ret: usize) void {
        const self: *WorkingAllocator = @ptrCast(@alignCast(raw));
        self.backing.rawFree(memory, alignment, ret);
        self.changed(memory.len, 0);
    }
};

test "working allocator tracks growth shrink and allocation limits" {
    var storage: [128]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&storage);
    var budget = WorkingAllocator.init(fixed.allocator(), 48);
    const allocator = budget.allocator();
    var bytes = try allocator.alloc(u8, 32);
    try std.testing.expectError(error.OutOfMemory, allocator.alloc(u8, 17));
    bytes = try allocator.realloc(bytes, 48);
    try std.testing.expect(!allocator.resize(bytes, 49));
    try std.testing.expect(allocator.resize(bytes, 8));
    bytes = bytes.ptr[0..8];
    allocator.free(bytes);
    try std.testing.expectEqual(@as(usize, 0), budget.live);
    try std.testing.expectEqual(@as(usize, 48), budget.peak);
    try std.testing.expect(budget.hit_limit);
}

test "working allocator remap accounts only successful changes" {
    var storage: [128]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&storage);
    var budget = WorkingAllocator.init(fixed.allocator(), 48);
    const allocator = budget.allocator();
    var bytes = try allocator.alloc(u8, 16);
    try std.testing.expect(allocator.remap(bytes, 49) == null);
    try std.testing.expectEqual(@as(usize, 16), budget.live);
    try std.testing.expect(budget.last_failure_was_limit);
    bytes = allocator.remap(bytes, 48) orelse return error.TestUnexpectedResult;
    try std.testing.expect(!budget.last_failure_was_limit);
    try std.testing.expectEqual(@as(usize, 48), budget.live);
    bytes = allocator.remap(bytes, 8) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(usize, 8), budget.live);
    allocator.free(bytes);
    try std.testing.expectEqual(@as(usize, 0), budget.live);
    try std.testing.expectEqual(@as(usize, 48), budget.peak);
}

test "working allocator distinguishes a later backing failure from budget denial" {
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    var budget = WorkingAllocator.init(failing.allocator(), 16);
    try std.testing.expectError(error.OutOfMemory, budget.allocator().alloc(u8, 17));
    try std.testing.expect(budget.last_failure_was_limit);
    try std.testing.expectError(error.OutOfMemory, budget.allocator().alloc(u8, 8));
    try std.testing.expect(!budget.last_failure_was_limit);
    try std.testing.expect(budget.hit_limit);
    try std.testing.expectEqual(@as(usize, 0), budget.live);
}
