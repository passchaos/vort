//! Independent requested-byte observation with forced moving growth. Caller
//! append capacity is included; borrowed input/output/scratch never enter here.
const std = @import("std");

pub const Ledger = struct {
    backing: std.mem.Allocator,
    live: usize = 0,
    peak: usize = 0,
    allocations: usize = 0,
    moving_growths: usize = 0,

    pub fn allocator(self: *Ledger) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }

    pub fn begin(self: *Ledger) void {
        self.peak = self.live;
        self.allocations = 0;
        self.moving_growths = 0;
    }

    fn change(self: *Ledger, old: usize, new: usize) void {
        std.debug.assert(self.live >= old);
        self.live = self.live - old + new;
        self.peak = @max(self.peak, self.live);
    }

    fn alloc(raw: *anyopaque, len: usize, alignment: std.mem.Alignment, address: usize) ?[*]u8 {
        const self: *Ledger = @ptrCast(@alignCast(raw));
        self.allocations += 1;
        const ptr = self.backing.rawAlloc(len, alignment, address) orelse return null;
        self.change(0, len);
        return ptr;
    }

    fn resize(raw: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, len: usize, address: usize) bool {
        const self: *Ledger = @ptrCast(@alignCast(raw));
        if (len > bytes.len) {
            self.moving_growths += 1;
            return false;
        }
        if (!self.backing.rawResize(bytes, alignment, len, address)) return false;
        self.change(bytes.len, len);
        return true;
    }

    fn remap(raw: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, len: usize, address: usize) ?[*]u8 {
        const self: *Ledger = @ptrCast(@alignCast(raw));
        if (len > bytes.len) {
            self.moving_growths += 1;
            return null;
        }
        const ptr = self.backing.rawRemap(bytes, alignment, len, address) orelse return null;
        self.change(bytes.len, len);
        return ptr;
    }

    fn free(raw: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, address: usize) void {
        const self: *Ledger = @ptrCast(@alignCast(raw));
        self.backing.rawFree(bytes, alignment, address);
        self.change(bytes.len, 0);
    }
};
