const std = @import("std");
const working = @import("../../io/working_allocator.zig");

/// One lock covers bookkeeping and the caller's backing allocator. Callers may
/// therefore supply an allocator without its own thread-safety guarantee.
pub const Budget = struct {
    state: working.WorkingAllocator,
    reserved_stacks: usize = 0,
    stack_peak: usize = 0,
    heap_peak: usize = 0,
    locked: std.atomic.Value(bool) = .init(false),

    pub fn init(allocator: std.mem.Allocator, maximum: usize) Budget {
        return .{ .state = working.WorkingAllocator.init(allocator, maximum) };
    }
    fn lock(self: *Budget) void {
        while (self.locked.swap(true, .acquire)) std.atomic.spinLoopHint();
    }
    fn unlock(self: *Budget) void {
        self.locked.store(false, .release);
    }
    fn observeHeap(self: *Budget) void {
        self.heap_peak = @max(self.heap_peak, self.state.live - self.reserved_stacks);
    }
};

/// A worker's error classification is copied while the shared lock is held.
/// Another worker's successful allocation cannot clear this slot's failure.
pub const Slot = struct {
    budget: *Budget,
    last_failure_was_limit: bool = false,

    pub fn allocator(self: *Slot) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }
    pub fn mapError(self: *const Slot, err: anytype) (@TypeOf(err) || error{WorkingMemoryLimitExceeded}) {
        return if (err == error.OutOfMemory and self.last_failure_was_limit) error.WorkingMemoryLimitExceeded else err;
    }
    /// Native std.Thread implementations can allocate stacks through the OS
    /// rather than SpawnConfig.allocator. Reserve their requested stack bytes
    /// explicitly, without allocating a second unused backing buffer.
    pub fn reserveStack(self: *Slot, bytes: usize) bool {
        const budget = self.budget;
        budget.lock();
        defer budget.unlock();
        if (budget.state.live > budget.state.limit or bytes > budget.state.limit - budget.state.live) return false;
        budget.state.live += bytes;
        budget.reserved_stacks += bytes;
        budget.stack_peak = @max(budget.stack_peak, budget.reserved_stacks);
        budget.state.peak = @max(budget.state.peak, budget.state.live);
        return true;
    }
    pub fn releaseStack(self: *Slot, bytes: usize) void {
        const budget = self.budget;
        budget.lock();
        defer budget.unlock();
        budget.state.live -= bytes;
        budget.reserved_stacks -= bytes;
    }
    fn alloc(raw: *anyopaque, len: usize, alignment: std.mem.Alignment, ra: usize) ?[*]u8 {
        const slot: *Slot = @ptrCast(@alignCast(raw));
        const self = slot.budget;
        self.lock();
        defer self.unlock();
        const result = self.state.allocator().rawAlloc(len, alignment, ra);
        self.observeHeap();
        slot.last_failure_was_limit = self.state.last_failure_was_limit;
        return result;
    }
    fn resize(raw: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, len: usize, ra: usize) bool {
        const slot: *Slot = @ptrCast(@alignCast(raw));
        const self = slot.budget;
        self.lock();
        defer self.unlock();
        const result = self.state.allocator().rawResize(bytes, alignment, len, ra);
        self.observeHeap();
        slot.last_failure_was_limit = self.state.last_failure_was_limit;
        return result;
    }
    fn remap(raw: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, len: usize, ra: usize) ?[*]u8 {
        const slot: *Slot = @ptrCast(@alignCast(raw));
        const self = slot.budget;
        self.lock();
        defer self.unlock();
        const result = self.state.allocator().rawRemap(bytes, alignment, len, ra);
        self.observeHeap();
        slot.last_failure_was_limit = self.state.last_failure_was_limit;
        return result;
    }
    fn free(raw: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, ra: usize) void {
        const slot: *Slot = @ptrCast(@alignCast(raw));
        const self = slot.budget;
        self.lock();
        defer self.unlock();
        self.state.allocator().rawFree(bytes, alignment, ra);
        self.observeHeap();
    }
};
