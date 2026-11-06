const std = @import("std");
pub const tile_len = 1024 * 1024;
pub const word = "information";
pub const metadata = "wide-sizes-meta";
pub const prefix = "caller-prefix";

pub fn require(ok: bool) !void {
    if (!ok) return error.WideSizeOracleMismatch;
}
pub const Ledger = struct {
    backing: std.mem.Allocator,
    live: usize = 0,
    peak: usize = 0,
    pub fn allocator(self: *Ledger) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }
    fn change(self: *Ledger, old: usize, new: usize) void {
        self.live = self.live - old + new;
        self.peak = @max(self.peak, self.live);
    }
    fn alloc(raw: *anyopaque, len: usize, alignment: std.mem.Alignment, ret: usize) ?[*]u8 {
        const self: *Ledger = @ptrCast(@alignCast(raw));
        const ptr = self.backing.rawAlloc(len, alignment, ret) orelse return null;
        self.change(0, len);
        return ptr;
    }
    fn resize(raw: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, len: usize, ret: usize) bool {
        const self: *Ledger = @ptrCast(@alignCast(raw));
        if (!self.backing.rawResize(bytes, alignment, len, ret)) return false;
        self.change(bytes.len, len);
        return true;
    }
    fn remap(raw: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, len: usize, ret: usize) ?[*]u8 {
        const self: *Ledger = @ptrCast(@alignCast(raw));
        const ptr = self.backing.rawRemap(bytes, alignment, len, ret) orelse return null;
        self.change(bytes.len, len);
        return ptr;
    }
    fn free(raw: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, ret: usize) void {
        const self: *Ledger = @ptrCast(@alignCast(raw));
        self.backing.rawFree(bytes, alignment, ret);
        self.change(bytes.len, 0);
    }
};
