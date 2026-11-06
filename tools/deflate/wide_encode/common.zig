const std = @import("std");
pub const chunk_len = 65536;
pub const Pattern = enum { repeat, zero, dirty };

pub fn fill(bytes: []u8, offset: u64, count: u64, pattern: Pattern) void {
    @memset(bytes, if (pattern == .repeat) 'R' else 0);
    if (pattern == .dirty and count != 0 and offset <= count - 1 and count - 1 - offset < bytes.len)
        bytes[@intCast(count - 1 - offset)] = 1;
}

/// Only requests made by the encoder allocator enter this ledger. Probe IO,
/// configuration and caller input/output buffers remain outside its scope.
pub const Ledger = struct {
    backing: std.mem.Allocator,
    live: usize = 0,
    peak: usize = 0,
    allocations: u64 = 0,
    pub fn allocator(self: *Ledger) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }
    fn change(self: *Ledger, old: usize, new: usize) void {
        self.live = self.live - old + new;
        self.peak = @max(self.peak, self.live);
    }
    fn alloc(raw: *anyopaque, len: usize, alignment: std.mem.Alignment, ret: usize) ?[*]u8 {
        const self: *Ledger = @ptrCast(@alignCast(raw));
        const bytes = self.backing.rawAlloc(len, alignment, ret) orelse return null;
        self.change(0, len);
        self.allocations += 1;
        return bytes;
    }
    fn resize(raw: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, len: usize, ret: usize) bool {
        const self: *Ledger = @ptrCast(@alignCast(raw));
        if (!self.backing.rawResize(bytes, alignment, len, ret)) return false;
        self.change(bytes.len, len);
        return true;
    }
    fn remap(raw: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, len: usize, ret: usize) ?[*]u8 {
        const self: *Ledger = @ptrCast(@alignCast(raw));
        const result = self.backing.rawRemap(bytes, alignment, len, ret) orelse return null;
        self.change(bytes.len, len);
        return result;
    }
    fn free(raw: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, ret: usize) void {
        const self: *Ledger = @ptrCast(@alignCast(raw));
        self.backing.rawFree(bytes, alignment, ret);
        self.change(bytes.len, 0);
    }
};
