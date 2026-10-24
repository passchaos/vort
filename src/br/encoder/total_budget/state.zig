const std = @import("std");
const Profile = @import("profile.zig").EncodeMemoryProfile;

pub const Snapshot = struct {
    available: bool = false,
    live_requested_bytes: usize = 0,
    peak_requested_bytes: usize = 0,
    control_bytes: usize = 0,
    reserved_bytes: usize = 0,
    limit: ?usize = null,
    hit_limit: bool = false,
    last_failure_was_limit: bool = false,
};

/// Stable heap state; allocator pointers never refer to a movable Lease.
pub const State = struct {
    backing: std.mem.Allocator,
    limit: ?usize,
    profile: ?*Profile,
    live: usize,
    peak: usize,
    reserved: usize = 0,
    references: usize = 1,
    hit_limit: bool = false,
    last_failure_was_limit: bool = false,

    pub fn allocator(self: *State) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &vtable };
    }
    pub fn fromAllocator(a: std.mem.Allocator) ?*State {
        // A.ptr may be undefined for stateless allocators. Compare it only
        // after recognizing our vtable, which guarantees an initialized ptr.
        if (a.vtable != &vtable) return null;
        return @ptrCast(@alignCast(a.ptr));
    }
    pub fn snapshot(self: *const State) Snapshot {
        return .{ .available = true, .live_requested_bytes = self.live, .peak_requested_bytes = self.peak, .control_bytes = @sizeOf(State), .reserved_bytes = self.reserved, .limit = self.limit, .hit_limit = self.hit_limit, .last_failure_was_limit = self.last_failure_was_limit };
    }
    pub fn report(self: *State) void {
        if (self.profile) |profile| profile.record(self.live, self.limit);
    }
    pub fn allow(self: *State, increase: usize) bool {
        const cap = self.limit orelse std.math.maxInt(usize);
        if (self.live > cap or self.reserved > cap - self.live or increase > cap - self.live - self.reserved) {
            self.hit_limit = true;
            self.last_failure_was_limit = true;
            return false;
        }
        return true;
    }
    pub fn changed(self: *State, old: usize, new: usize) void {
        std.debug.assert(old <= self.live - @sizeOf(State));
        self.live = self.live - old + new;
        self.peak = @max(self.peak, self.live);
        self.report();
    }
    pub fn disposeIfUnused(self: *State) void {
        if (self.references != 0 or self.live != @sizeOf(State) or self.reserved != 0) return;
        const backing = self.backing;
        if (self.profile) |profile| profile.record(0, self.limit);
        backing.destroy(self);
    }

    const vtable: std.mem.Allocator.VTable = .{ .alloc = alloc, .resize = resize, .remap = remap, .free = free };
    fn alloc(raw: *anyopaque, len: usize, alignment: std.mem.Alignment, ret: usize) ?[*]u8 {
        const self: *State = @ptrCast(@alignCast(raw));
        if (self.references == 0 or !self.allow(len)) return null;
        self.last_failure_was_limit = false;
        const memory = self.backing.rawAlloc(len, alignment, ret) orelse return null;
        self.changed(0, len);
        return memory;
    }
    fn resize(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, len: usize, ret: usize) bool {
        const self: *State = @ptrCast(@alignCast(raw));
        if (len > memory.len and (self.references == 0 or !self.allow(len - memory.len))) return false;
        self.last_failure_was_limit = false;
        if (!self.backing.rawResize(memory, alignment, len, ret)) return false;
        self.changed(memory.len, len);
        return true;
    }
    fn remap(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, len: usize, ret: usize) ?[*]u8 {
        const self: *State = @ptrCast(@alignCast(raw));
        if (len > memory.len and (self.references == 0 or !self.allow(len - memory.len))) return null;
        self.last_failure_was_limit = false;
        const memory_new = self.backing.rawRemap(memory, alignment, len, ret) orelse return null;
        self.changed(memory.len, len);
        return memory_new;
    }
    fn free(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ret: usize) void {
        const self: *State = @ptrCast(@alignCast(raw));
        self.backing.rawFree(memory, alignment, ret);
        self.changed(memory.len, 0);
        self.disposeIfUnused();
    }
};
