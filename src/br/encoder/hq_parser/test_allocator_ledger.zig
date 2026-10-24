const std = @import("std");

/// Independent requested-byte ledger for parser integration tests. Disabling
/// resize/remap forces allocate-copy-free paths and exposes coexistence peaks.
pub const Ledger = struct {
    backing: std.mem.Allocator,
    live: usize = 0,
    peak: usize = 0,
    forbid_remap: bool = false,

    pub fn allocator(self: *Ledger) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }
    fn replace(self: *Ledger, old: usize, new: usize) void {
        self.live = self.live - old + new;
        self.peak = @max(self.peak, self.live);
    }
    fn alloc(raw: *anyopaque, len: usize, alignment: std.mem.Alignment, ret: usize) ?[*]u8 {
        const self: *Ledger = @ptrCast(@alignCast(raw));
        const pointer = self.backing.rawAlloc(len, alignment, ret) orelse return null;
        self.replace(0, len);
        return pointer;
    }
    fn resize(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, len: usize, ret: usize) bool {
        const self: *Ledger = @ptrCast(@alignCast(raw));
        if (self.forbid_remap or !self.backing.rawResize(memory, alignment, len, ret)) return false;
        self.replace(memory.len, len);
        return true;
    }
    fn remap(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, len: usize, ret: usize) ?[*]u8 {
        const self: *Ledger = @ptrCast(@alignCast(raw));
        if (self.forbid_remap) return null;
        const pointer = self.backing.rawRemap(memory, alignment, len, ret) orelse return null;
        self.replace(memory.len, len);
        return pointer;
    }
    fn free(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ret: usize) void {
        const self: *Ledger = @ptrCast(@alignCast(raw));
        self.backing.rawFree(memory, alignment, ret);
        self.replace(memory.len, 0);
    }
};
