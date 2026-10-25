//! One requested-heap budget shared by a parallel XZ operation. The same lock
//! serializes quota accounting and the caller's potentially unsafe allocator.
//! OS thread stacks and allocator bookkeeping are outside this byte ledger.
const std = @import("std");
const working = @import("../../io/working_allocator.zig");

pub const Budget = struct {
    state: working.WorkingAllocator,
    mutex: std.atomic.Mutex = .unlocked,

    pub fn init(backing: std.mem.Allocator, maximum: usize) Budget {
        return .{ .state = working.WorkingAllocator.init(backing, maximum) };
    }

    pub fn liveRequestedBytes(self: *Budget) usize {
        self.lock();
        defer self.unlock();
        return self.state.live;
    }

    pub fn peakRequestedBytes(self: *Budget) usize {
        self.lock();
        defer self.unlock();
        return self.state.peak;
    }

    fn lock(self: *Budget) void {
        while (!self.mutex.tryLock()) std.atomic.spinLoopHint();
    }

    fn unlock(self: *Budget) void {
        self.mutex.unlock();
    }
};

/// Each worker and coordinator owns a distinct slot. Allocations belong to the
/// shared budget and may be released through another slot after synchronization.
/// A slot's failure classification survives sibling operations and frees.
/// Budget and slot addresses stay stable until every worker has joined and all
/// allocations are released. A slot is not used by concurrent worker calls.
pub const Slot = struct {
    budget: *Budget,
    last_failure_was_limit: bool = false,

    pub fn allocator(self: *Slot) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }

    pub fn mapError(self: *const Slot, err: anytype) (@TypeOf(err) || error{WorkingMemoryLimitExceeded}) {
        const failure: anyerror = err;
        return if (failure == error.OutOfMemory and self.last_failure_was_limit) error.WorkingMemoryLimitExceeded else err;
    }

    pub fn clearFailure(self: *Slot) void {
        self.budget.lock();
        defer self.budget.unlock();
        self.last_failure_was_limit = false;
    }

    fn alloc(raw: *anyopaque, len: usize, alignment: std.mem.Alignment, address: usize) ?[*]u8 {
        const slot: *Slot = @ptrCast(@alignCast(raw));
        const budget = slot.budget;
        budget.lock();
        defer budget.unlock();
        const result = budget.state.allocator().rawAlloc(len, alignment, address);
        slot.last_failure_was_limit = budget.state.last_failure_was_limit;
        return result;
    }

    fn resize(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, len: usize, address: usize) bool {
        const slot: *Slot = @ptrCast(@alignCast(raw));
        const budget = slot.budget;
        budget.lock();
        defer budget.unlock();
        const result = budget.state.allocator().rawResize(memory, alignment, len, address);
        slot.last_failure_was_limit = budget.state.last_failure_was_limit;
        return result;
    }

    fn remap(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, len: usize, address: usize) ?[*]u8 {
        const slot: *Slot = @ptrCast(@alignCast(raw));
        const budget = slot.budget;
        budget.lock();
        defer budget.unlock();
        const result = budget.state.allocator().rawRemap(memory, alignment, len, address);
        slot.last_failure_was_limit = budget.state.last_failure_was_limit;
        return result;
    }

    fn free(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, address: usize) void {
        const slot: *Slot = @ptrCast(@alignCast(raw));
        const budget = slot.budget;
        budget.lock();
        defer budget.unlock();
        budget.state.allocator().rawFree(memory, alignment, address);
    }
};

test {
    _ = @import("memory_tests.zig");
}
