const std = @import("std");

pub const Tracker = struct {
    backing: std.mem.Allocator,
    live: usize = 0,
    peak: usize = 0,
    increased_bytes: usize = 0,
    released_bytes: usize = 0,
    alloc_attempts: usize = 0,
    successful_allocations: usize = 0,
    resize_attempts: usize = 0,
    remap_attempts: usize = 0,
    successful_resizes: usize = 0,
    successful_remaps: usize = 0,
    free_calls: usize = 0,
    event_count: usize = 0,
    fail_alloc_at: ?usize = null,
    phase: []const u8 = "xml",
    slots: [1024]Slot = @splat(.{}),
    const Slot = struct { pointer: ?[*]u8 = null, len: usize = 0 };
    pub fn allocator(self: *Tracker) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = allocate, .resize = resize, .remap = remap, .free = free } };
    }
    fn slot(self: *Tracker, memory: []u8) *Slot {
        for (&self.slots) |*entry| if (entry.pointer == memory.ptr) {
            std.debug.assert(entry.len == memory.len);
            return entry;
        };
        @panic("untracked allocation pointer");
    }
    fn event(self: *Tracker, operation: []const u8, old: usize, request: usize, success: bool) void {
        std.debug.print("EVENT {{\"phase\":\"{s}\",\"index\":{d},\"op\":\"{s}\",\"old_bytes\":{d},\"requested_bytes\":{d},\"success\":{},\"live\":{d}}}\n", .{ self.phase, self.event_count, operation, old, request, success, self.live });
        self.event_count += 1;
    }
    fn changed(self: *Tracker, old: usize, new: usize) void {
        std.debug.assert(old <= self.live);
        self.live = self.live - old + new;
        self.peak = @max(self.peak, self.live);
        if (new >= old) self.increased_bytes += new - old else self.released_bytes += old - new;
    }
    fn allocate(raw: *anyopaque, len: usize, alignment: std.mem.Alignment, address: usize) ?[*]u8 {
        const self: *Tracker = @ptrCast(@alignCast(raw));
        const attempt = self.alloc_attempts;
        self.alloc_attempts += 1;
        if (self.fail_alloc_at == attempt) {
            self.event("alloc", 0, len, false);
            return null;
        }
        const pointer = self.backing.rawAlloc(len, alignment, address) orelse {
            self.event("alloc", 0, len, false);
            return null;
        };
        for (&self.slots) |*entry| if (entry.pointer == null) {
            entry.* = .{ .pointer = pointer, .len = len };
            self.successful_allocations += 1;
            self.changed(0, len);
            self.event("alloc", 0, len, true);
            return pointer;
        };
        @panic("tracking table exhausted");
    }
    fn resize(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, len: usize, address: usize) bool {
        const self: *Tracker = @ptrCast(@alignCast(raw));
        self.resize_attempts += 1;
        const entry = self.slot(memory);
        if (!self.backing.rawResize(memory, alignment, len, address)) {
            self.event("resize", memory.len, len, false);
            return false;
        }
        entry.len = len;
        self.successful_resizes += 1;
        self.changed(memory.len, len);
        self.event("resize", memory.len, len, true);
        return true;
    }
    fn remap(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, len: usize, address: usize) ?[*]u8 {
        const self: *Tracker = @ptrCast(@alignCast(raw));
        self.remap_attempts += 1;
        const entry = self.slot(memory);
        const pointer = self.backing.rawRemap(memory, alignment, len, address) orelse {
            self.event("remap", memory.len, len, false);
            return null;
        };
        entry.* = .{ .pointer = pointer, .len = len };
        self.successful_remaps += 1;
        self.changed(memory.len, len);
        self.event("remap", memory.len, len, true);
        return pointer;
    }
    fn free(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, address: usize) void {
        const self: *Tracker = @ptrCast(@alignCast(raw));
        const entry = self.slot(memory);
        self.backing.rawFree(memory, alignment, address);
        entry.* = .{};
        self.free_calls += 1;
        self.changed(memory.len, 0);
        self.event("free", memory.len, 0, true);
    }
};
