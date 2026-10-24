const std = @import("std");
pub const Counter = struct {
    backing: std.mem.Allocator,
    live: usize = 0,
    peak: usize = 0,
    total: usize = 0,
    allocations: usize = 0,
    fn add(self: *Counter, n: usize) void {
        self.live += n;
        self.peak = @max(self.peak, self.live);
        self.total += n;
        self.allocations += 1;
    }
    pub fn allocator(self: *Counter) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }
    fn from(ptr: *anyopaque) *Counter {
        return @ptrCast(@alignCast(ptr));
    }
    fn alloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, ret: usize) ?[*]u8 {
        const s = from(ctx);
        const p = s.backing.rawAlloc(len, alignment, ret) orelse return null;
        s.add(len);
        return p;
    }
    fn resize(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, n: usize, ret: usize) bool {
        const s = from(ctx);
        if (!s.backing.rawResize(memory, alignment, n, ret)) return false;
        s.live -= memory.len;
        s.add(n);
        return true;
    }
    fn remap(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, n: usize, ret: usize) ?[*]u8 {
        const s = from(ctx);
        const p = s.backing.rawRemap(memory, alignment, n, ret) orelse return null;
        s.live -= memory.len;
        s.add(n);
        return p;
    }
    fn free(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ret: usize) void {
        const s = from(ctx);
        s.live -= memory.len;
        s.backing.rawFree(memory, alignment, ret);
    }
};
