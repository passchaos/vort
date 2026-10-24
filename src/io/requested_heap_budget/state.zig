const std = @import("std");
const builtin = @import("builtin");
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

/// Movable owners point to this stable, counted allocation. One guard covers
/// each quota check, physical allocator call and ledger update, so sibling
/// workers cannot simultaneously admit allocations beyond the shared cap.
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
    mutex: std.atomic.Mutex = .unlocked,

    pub fn enter(self: *State) void {
        if (!builtin.single_threaded) while (!self.mutex.tryLock()) std.atomic.spinLoopHint();
    }
    pub fn leave(self: *State) void {
        if (!builtin.single_threaded) self.mutex.unlock();
    }
    pub fn allocator(self: *State) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &vtable };
    }
    pub fn fromAllocator(a: std.mem.Allocator) ?*State {
        if (a.vtable != &vtable) return null;
        return @ptrCast(@alignCast(a.ptr));
    }
    pub fn reportLocked(self: *State) void {
        if (self.profile) |p| p.record(self.live, self.limit);
    }
    pub fn allowedLocked(self: *State, extra: usize) bool {
        const cap = self.limit orelse std.math.maxInt(usize);
        if (self.live > cap or self.reserved > cap - self.live or extra > cap - self.live - self.reserved) {
            self.hit_limit = true;
            self.last_failure_was_limit = true;
            return false;
        }
        return true;
    }
    pub fn replaceLocked(self: *State, old: usize, new: usize) void {
        std.debug.assert(self.live >= @sizeOf(State) and old <= self.live - @sizeOf(State));
        self.live = self.live - old + new;
        self.peak = @max(self.peak, self.live);
        self.reportLocked();
    }
    pub fn unusedLocked(self: *State) bool {
        return self.references == 0 and self.live == @sizeOf(State) and self.reserved == 0;
    }
    pub fn destroyUnlocked(self: *State) void {
        const backing = self.backing;
        backing.destroy(self);
    }
    pub fn releaseReference(self: *State) void {
        self.enter();
        std.debug.assert(self.references > 0);
        self.references -= 1;
        const destroy = self.unusedLocked();
        if (destroy) {
            if (self.profile) |p| p.record(0, self.limit);
        } else if (self.references == 0) {
            self.reportLocked();
            self.profile = null;
        }
        self.leave();
        if (destroy) self.destroyUnlocked();
    }
    pub fn snapshot(self: *State) Snapshot {
        self.enter();
        defer self.leave();
        return .{ .available = true, .live_requested_bytes = self.live, .peak_requested_bytes = self.peak, .control_bytes = @sizeOf(State), .reserved_bytes = self.reserved, .limit = self.limit, .hit_limit = self.hit_limit, .last_failure_was_limit = self.last_failure_was_limit };
    }

    const vtable: std.mem.Allocator.VTable = .{ .alloc = alloc, .resize = resize, .remap = remap, .free = free };
    fn alloc(raw: *anyopaque, len: usize, alignment: std.mem.Alignment, ret: usize) ?[*]u8 {
        const self: *State = @ptrCast(@alignCast(raw));
        self.enter();
        defer self.leave();
        if (self.references == 0 or !self.allowedLocked(len)) return null;
        const memory = self.backing.rawAlloc(len, alignment, ret) orelse return null;
        self.replaceLocked(0, len);
        return memory;
    }
    fn resize(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, len: usize, ret: usize) bool {
        const self: *State = @ptrCast(@alignCast(raw));
        self.enter();
        defer self.leave();
        if (len > memory.len and (self.references == 0 or !self.allowedLocked(len - memory.len))) return false;
        if (!self.backing.rawResize(memory, alignment, len, ret)) return false;
        self.replaceLocked(memory.len, len);
        return true;
    }
    fn remap(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, len: usize, ret: usize) ?[*]u8 {
        const self: *State = @ptrCast(@alignCast(raw));
        self.enter();
        defer self.leave();
        if (len > memory.len and (self.references == 0 or !self.allowedLocked(len - memory.len))) return null;
        const updated = self.backing.rawRemap(memory, alignment, len, ret) orelse return null;
        self.replaceLocked(memory.len, len);
        return updated;
    }
    fn free(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ret: usize) void {
        const self: *State = @ptrCast(@alignCast(raw));
        self.enter();
        self.backing.rawFree(memory, alignment, ret);
        self.replaceLocked(memory.len, 0);
        const destroy = self.unusedLocked();
        if (destroy) if (self.profile) |p| p.record(0, self.limit);
        self.leave();
        if (destroy) self.destroyUnlocked();
    }
};
