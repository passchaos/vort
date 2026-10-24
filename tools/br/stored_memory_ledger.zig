//! A probe-owned allocator ledger. It observes requested backing allocations,
//! independently of codec memory profiles and excludes only initial caller buffers.
const std = @import("std");

pub const Ledger = struct {
    backing: std.mem.Allocator,
    live: usize = 0,
    peak: usize = 0,
    owned_peak: usize = 0,
    allocation_calls: usize = 0,
    resize_calls: usize = 0,
    remap_calls: usize = 0,
    free_calls: usize = 0,
    forced_failures: usize = 0,
    fail_after: ?usize = null,
    slots: [128]Slot = @splat(.{}),
    const Slot = struct { ptr: ?[*]u8 = null, len: usize = 0, borrowed: usize = 0 };

    pub fn allocator(self: *Ledger) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }
    pub fn ownedLive(self: *const Ledger) usize {
        var excluded: usize = 0;
        for (self.slots) |slot| excluded += slot.borrowed;
        return self.live - excluded;
    }
    pub fn excludeCaller(self: *Ledger, bytes: []u8) void {
        if (bytes.len != 0) self.find(bytes).borrowed = bytes.len;
        self.begin();
    }
    pub fn begin(self: *Ledger) void {
        self.peak = self.live;
        self.owned_peak = self.ownedLive();
    }
    fn find(self: *Ledger, bytes: []u8) *Slot {
        for (&self.slots) |*slot| if (slot.ptr == bytes.ptr) {
            std.debug.assert(slot.len == bytes.len);
            return slot;
        };
        @panic("probe ledger allocation missing");
    }
    fn changed(self: *Ledger, old: usize, new: usize) void {
        self.live = self.live - old + new;
        self.peak = @max(self.peak, self.live);
        self.owned_peak = @max(self.owned_peak, self.ownedLive());
    }
    fn denied(self: *Ledger) bool {
        if (self.fail_after) |cap| if (self.allocation_calls + self.resize_calls + self.remap_calls > cap) {
            self.forced_failures += 1;
            return true;
        };
        return false;
    }
    fn alloc(raw: *anyopaque, len: usize, alignment: std.mem.Alignment, address: usize) ?[*]u8 {
        const self: *Ledger = @ptrCast(@alignCast(raw));
        self.allocation_calls += 1;
        if (self.denied()) return null;
        const ptr = self.backing.rawAlloc(len, alignment, address) orelse return null;
        for (&self.slots) |*slot| if (slot.ptr == null) {
            slot.* = .{ .ptr = ptr, .len = len };
            self.changed(0, len);
            return ptr;
        };
        @panic("probe ledger table exhausted");
    }
    fn resize(raw: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, new: usize, address: usize) bool {
        const self: *Ledger = @ptrCast(@alignCast(raw));
        self.resize_calls += 1;
        if (self.denied()) return false;
        const slot = self.find(bytes);
        if (!self.backing.rawResize(bytes, alignment, new, address)) return false;
        slot.len = new;
        slot.borrowed = @min(slot.borrowed, new);
        self.changed(bytes.len, new);
        return true;
    }
    fn remap(raw: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, new: usize, address: usize) ?[*]u8 {
        const self: *Ledger = @ptrCast(@alignCast(raw));
        self.remap_calls += 1;
        if (self.denied()) return null;
        const slot = self.find(bytes);
        const ptr = self.backing.rawRemap(bytes, alignment, new, address) orelse return null;
        slot.ptr = ptr;
        slot.len = new;
        // A moved allocation is a new request; retained caller capacity alone
        // stays excluded when the allocator can grow it in place.
        slot.borrowed = if (ptr == bytes.ptr) @min(slot.borrowed, new) else 0;
        self.changed(bytes.len, new);
        return ptr;
    }
    fn free(raw: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, address: usize) void {
        const self: *Ledger = @ptrCast(@alignCast(raw));
        self.free_calls += 1;
        const slot = self.find(bytes);
        self.backing.rawFree(bytes, alignment, address);
        slot.* = .{};
        self.changed(bytes.len, 0);
    }
};
