//! Observe requested decoder heap bytes through the allocator interface.
//! Growing buffers must relocate while their previous storage is still live.
const std = @import("std");

pub const Tracker = struct {
    backing: std.mem.Allocator,
    live: usize = 0,
    peak: usize = 0,
    allocation_calls: usize = 0,
    allocation_bytes: usize = 0,
    free_calls: usize = 0,
    growing_resize_refusals: usize = 0,
    growing_remap_refusals: usize = 0,
    forced_growth: bool = true,
    hard_limit: ?usize = null,
    denied_requests: usize = 0,

    pub fn init(backing: std.mem.Allocator) Tracker {
        return .{ .backing = backing };
    }

    pub fn allocator(self: *Tracker) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }

    pub fn begin(self: *Tracker) void {
        self.peak = self.live;
        self.allocation_calls = 0;
        self.allocation_bytes = 0;
        self.free_calls = 0;
        self.growing_resize_refusals = 0;
        self.growing_remap_refusals = 0;
        self.denied_requests = 0;
    }

    fn accepted(self: *Tracker, old: usize, new: usize) bool {
        std.debug.assert(self.live >= old);
        if (self.hard_limit) |limit| {
            if (new > limit -| (self.live - old)) {
                self.denied_requests += 1;
                return false;
            }
        }
        return true;
    }

    fn change(self: *Tracker, old: usize, new: usize) void {
        std.debug.assert(self.live >= old);
        self.live = self.live - old + new;
        self.peak = @max(self.peak, self.live);
    }

    fn alloc(ptr: *anyopaque, len: usize, alignment: std.mem.Alignment, ret: usize) ?[*]u8 {
        const self: *Tracker = @ptrCast(@alignCast(ptr));
        self.allocation_calls += 1;
        self.allocation_bytes += len;
        if (!self.accepted(0, len)) return null;
        const result = self.backing.rawAlloc(len, alignment, ret) orelse return null;
        self.change(0, len);
        return result;
    }

    fn resize(ptr: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, len: usize, ret: usize) bool {
        const self: *Tracker = @ptrCast(@alignCast(ptr));
        if (self.forced_growth and len > bytes.len) {
            self.growing_resize_refusals += 1;
            return false;
        }
        if (!self.accepted(bytes.len, len) or !self.backing.rawResize(bytes, alignment, len, ret)) return false;
        self.change(bytes.len, len);
        return true;
    }

    fn remap(ptr: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, len: usize, ret: usize) ?[*]u8 {
        const self: *Tracker = @ptrCast(@alignCast(ptr));
        if (self.forced_growth and len > bytes.len) {
            self.growing_remap_refusals += 1;
            return null;
        }
        if (!self.accepted(bytes.len, len)) return null;
        const result = self.backing.rawRemap(bytes, alignment, len, ret) orelse return null;
        self.change(bytes.len, len);
        return result;
    }

    fn free(ptr: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, ret: usize) void {
        const self: *Tracker = @ptrCast(@alignCast(ptr));
        self.backing.rawFree(bytes, alignment, ret);
        self.free_calls += 1;
        self.change(bytes.len, 0);
    }
};
