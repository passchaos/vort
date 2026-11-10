//! Independent observer of the physical allocator's requested live capacities.
const std = @import("std");
pub const CountingAllocator = struct {
    backing: std.mem.Allocator,
    live: usize = 0,
    peak: usize = 0,
    calls: usize = 0,
    reject_allocation_size: ?usize = null,
    rejected: usize = 0,
    pub fn allocator(self: *@This()) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &vtable };
    }
    fn change(self: *@This(), old: usize, new: usize) void {
        self.live = self.live - old + new;
        self.peak = @max(self.peak, self.live);
    }
    const vtable: std.mem.Allocator.VTable = .{ .alloc = alloc, .resize = resize, .remap = remap, .free = free };
    fn alloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, ra: usize) ?[*]u8 {
        const self: *@This() = @ptrCast(@alignCast(ctx));
        self.calls += 1;
        if (self.reject_allocation_size == len) {
            self.rejected += 1;
            return null;
        }
        const result = self.backing.rawAlloc(len, alignment, ra) orelse return null;
        self.change(0, len);
        return result;
    }
    fn resize(ctx: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, len: usize, ra: usize) bool {
        const self: *@This() = @ptrCast(@alignCast(ctx));
        if (!self.backing.rawResize(bytes, alignment, len, ra)) return false;
        self.change(bytes.len, len);
        return true;
    }
    fn remap(ctx: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, len: usize, ra: usize) ?[*]u8 {
        const self: *@This() = @ptrCast(@alignCast(ctx));
        const result = self.backing.rawRemap(bytes, alignment, len, ra) orelse return null;
        self.change(bytes.len, len);
        return result;
    }
    fn free(ctx: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, ra: usize) void {
        const self: *@This() = @ptrCast(@alignCast(ctx));
        self.backing.rawFree(bytes, alignment, ra);
        self.change(bytes.len, 0);
    }
};
