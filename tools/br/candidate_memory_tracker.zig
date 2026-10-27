//! Independent requested-heap ledger. Probe storage is outside this allocator.
const std = @import("std");

pub const Operation = enum { allocate, resize, remap, free };
pub const Request = struct {
    operation: Operation,
    previous_bytes: usize,
    requested_bytes: usize,
    live_before: usize,
    succeeded: bool,
    live_after: usize,
    peak_after: usize,
};

pub const TrackingAllocator = struct {
    backing: std.mem.Allocator,
    force_moving_growth: bool = true,
    live: usize = 0,
    peak: usize = 0,
    allocated_bytes: usize = 0,
    freed_bytes: usize = 0,
    alloc_attempts: usize = 0,
    resize_attempts: usize = 0,
    remap_attempts: usize = 0,
    free_calls: usize = 0,
    successful_resizes: usize = 0,
    successful_remaps: usize = 0,
    peak_operation: Operation = .allocate,
    peak_before: usize = 0,
    peak_request: usize = 0,
    request_count: usize = 0,
    requests: [32768]Request = undefined,
    slots: [1024]Slot = @splat(.{}),

    const Slot = struct { pointer: ?[*]u8 = null, len: usize = 0 };

    pub fn init(backing: std.mem.Allocator) TrackingAllocator {
        return .{ .backing = backing };
    }

    pub fn allocator(self: *TrackingAllocator) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = allocate, .resize = resize, .remap = remap, .free = free } };
    }

    pub fn ledger(self: *const TrackingAllocator) []const Request {
        return self.requests[0..self.request_count];
    }

    fn slot(self: *TrackingAllocator, memory: []u8) *Slot {
        for (&self.slots) |*entry| if (entry.pointer == memory.ptr) {
            std.debug.assert(entry.len == memory.len);
            return entry;
        };
        @panic("untracked allocator pointer");
    }

    fn record(self: *TrackingAllocator, operation: Operation, previous: usize, requested: usize, before: usize, succeeded: bool) void {
        if (self.request_count == self.requests.len) @panic("request ledger exhausted");
        self.requests[self.request_count] = .{
            .operation = operation,
            .previous_bytes = previous,
            .requested_bytes = requested,
            .live_before = before,
            .succeeded = succeeded,
            .live_after = self.live,
            .peak_after = self.peak,
        };
        self.request_count += 1;
    }

    fn increase(self: *TrackingAllocator, amount: usize, operation: Operation, requested: usize) void {
        const previous = self.live;
        self.live += amount;
        self.allocated_bytes += amount;
        if (self.live > self.peak) {
            self.peak = self.live;
            self.peak_operation = operation;
            self.peak_before = previous;
            self.peak_request = requested;
        }
    }

    fn decrease(self: *TrackingAllocator, amount: usize) void {
        std.debug.assert(amount <= self.live);
        self.live -= amount;
        self.freed_bytes += amount;
    }

    fn allocate(raw: *anyopaque, len: usize, alignment: std.mem.Alignment, address: usize) ?[*]u8 {
        const self: *TrackingAllocator = @ptrCast(@alignCast(raw));
        self.alloc_attempts += 1;
        const before = self.live;
        const memory = self.backing.rawAlloc(len, alignment, address) orelse {
            self.record(.allocate, 0, len, before, false);
            return null;
        };
        for (&self.slots) |*entry| if (entry.pointer == null) {
            entry.* = .{ .pointer = memory, .len = len };
            self.increase(len, .allocate, len);
            self.record(.allocate, 0, len, before, true);
            return memory;
        };
        @panic("tracking allocation table exhausted");
    }

    fn resize(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, len: usize, address: usize) bool {
        const self: *TrackingAllocator = @ptrCast(@alignCast(raw));
        self.resize_attempts += 1;
        const before = self.live;
        const entry = self.slot(memory);
        if ((self.force_moving_growth and len > memory.len) or !self.backing.rawResize(memory, alignment, len, address)) {
            self.record(.resize, memory.len, len, before, false);
            return false;
        }
        self.successful_resizes += 1;
        if (len > memory.len) self.increase(len - memory.len, .resize, len) else self.decrease(memory.len - len);
        entry.len = len;
        self.record(.resize, memory.len, len, before, true);
        return true;
    }

    fn remap(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, len: usize, address: usize) ?[*]u8 {
        const self: *TrackingAllocator = @ptrCast(@alignCast(raw));
        self.remap_attempts += 1;
        const before = self.live;
        const entry = self.slot(memory);
        const result = if (self.force_moving_growth and len > memory.len) null else self.backing.rawRemap(memory, alignment, len, address);
        if (result) |pointer| {
            self.successful_remaps += 1;
            if (len > memory.len) self.increase(len - memory.len, .remap, len) else self.decrease(memory.len - len);
            entry.* = .{ .pointer = pointer, .len = len };
            self.record(.remap, memory.len, len, before, true);
            return pointer;
        }
        self.record(.remap, memory.len, len, before, false);
        return null;
    }

    fn free(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, address: usize) void {
        const self: *TrackingAllocator = @ptrCast(@alignCast(raw));
        const before = self.live;
        const entry = self.slot(memory);
        self.backing.rawFree(memory, alignment, address);
        entry.* = .{};
        self.free_calls += 1;
        self.decrease(memory.len);
        self.record(.free, memory.len, 0, before, true);
    }
};
