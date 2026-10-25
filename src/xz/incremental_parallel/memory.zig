//! Stable requested-heap ownership for an incremental parallel XZ encoder.
//! One lock guards both quota accounting and the possibly unsafe backing
//! allocator. Caller buffers, OS stacks and allocator bookkeeping are excluded.
const std = @import("std");
const builtin = @import("builtin");
const working = @import("../../io/working_allocator.zig");

pub const Error = error{ OutOfMemory, WorkingMemoryLimitExceeded, IntegerOverflow };
pub const control_bytes: usize = @sizeOf(Control);
pub const Snapshot = struct {
    live_requested_bytes: usize,
    peak_requested_bytes: usize,
    control_bytes: usize,
    limit: usize,
};

/// An encoder value may move; this control and every allocator Slot stay at
/// their final addresses until all workers join and tracked storage is freed.
pub const Control = struct {
    budget: Budget,
    coordinator: Slot,

    /// retained_bytes are existing exact capacities on backing. Only the
    /// ledger is seeded; the caller commits allocator rebinding after success.
    pub fn create(backing: std.mem.Allocator, limit: usize, retained_bytes: usize) Error!*Control {
        const initial = std.math.add(usize, control_bytes, retained_bytes) catch return error.IntegerOverflow;
        if (initial > limit) return error.WorkingMemoryLimitExceeded;
        const control = try backing.create(Control);
        control.* = .{ .budget = Budget.init(backing, limit, initial), .coordinator = undefined };
        control.coordinator = .{ .budget = &control.budget };
        return control;
    }

    pub fn allocator(self: *Control) std.mem.Allocator {
        return self.coordinator.allocator();
    }

    /// Store the returned Slot in stable worker storage before taking its
    /// allocator. Never keep an allocator pointing into a movable temporary.
    pub fn workerSlot(self: *Control) Slot {
        return .{ .budget = &self.budget };
    }

    pub fn snapshot(self: *Control) Snapshot {
        return self.budget.snapshot();
    }

    pub fn checkNewLimit(self: *Control, limit: usize) Error!void {
        self.budget.lock();
        defer self.budget.unlock();
        if (self.budget.state.live > limit) return error.WorkingMemoryLimitExceeded;
    }

    /// A rejected change leaves the previous policy and every allocation intact.
    pub fn changeLimit(self: *Control, limit: usize) Error!void {
        self.budget.lock();
        defer self.budget.unlock();
        if (self.budget.state.live > limit) return error.WorkingMemoryLimitExceeded;
        self.budget.state.limit = limit;
    }

    /// Call after stopping/joining workers for a new retained-memory epoch.
    pub fn resetPeak(self: *Control) void {
        self.budget.lock();
        defer self.budget.unlock();
        self.budget.state.peak = self.budget.state.live;
    }

    /// All workers must have joined. Free tracked storage or release its exact
    /// adopted/disowned credit first. The control is freed directly by backing.
    pub fn destroy(self: *Control) void {
        self.budget.lock();
        std.debug.assert(self.budget.state.live == control_bytes);
        const backing = self.budget.state.backing;
        self.budget.unlock();
        backing.destroy(self);
    }
};

pub const Budget = struct {
    state: working.WorkingAllocator,
    mutex: std.atomic.Mutex = .unlocked,

    fn init(backing: std.mem.Allocator, limit: usize, initial: usize) Budget {
        var state = working.WorkingAllocator.init(backing, limit);
        state.live = initial;
        state.peak = initial;
        return .{ .state = state };
    }

    /// Coordinator-only ownership transition for existing backing allocations.
    /// Do not seed allocations that have already passed through a Slot.
    pub fn seedExisting(self: *Budget, bytes: usize) Error!void {
        self.lock();
        defer self.unlock();
        const next = std.math.add(usize, self.state.live, bytes) catch return error.IntegerOverflow;
        if (next > self.state.limit) return error.WorkingMemoryLimitExceeded;
        self.state.live = next;
        self.state.peak = @max(self.state.peak, next);
    }

    /// Disown retained storage or roll back an uncommitted adoption. This does
    /// not free physical memory; the caller restores its backing allocator.
    pub fn releaseExisting(self: *Budget, bytes: usize) void {
        self.lock();
        defer self.unlock();
        std.debug.assert(self.state.live >= control_bytes and bytes <= self.state.live - control_bytes);
        self.state.live -= bytes;
    }

    pub fn snapshot(self: *Budget) Snapshot {
        self.lock();
        defer self.unlock();
        return .{ .live_requested_bytes = self.state.live, .peak_requested_bytes = self.state.peak, .control_bytes = control_bytes, .limit = self.state.limit };
    }

    pub fn liveRequestedBytes(self: *Budget) usize {
        return self.snapshot().live_requested_bytes;
    }

    pub fn peakRequestedBytes(self: *Budget) usize {
        return self.snapshot().peak_requested_bytes;
    }

    fn lock(self: *Budget) void {
        if (!builtin.single_threaded) while (!self.mutex.tryLock()) std.atomic.spinLoopHint();
    }

    fn unlock(self: *Budget) void {
        if (!builtin.single_threaded) self.mutex.unlock();
    }
};

/// Per-worker errors never borrow the shared allocator's last failure. A Slot
/// may be used by one thread at a time; cross-slot frees require synchronization.
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
        slot.budget.lock();
        defer slot.budget.unlock();
        const result = slot.budget.state.allocator().rawAlloc(len, alignment, address);
        slot.last_failure_was_limit = slot.budget.state.last_failure_was_limit;
        return result;
    }

    fn resize(raw: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, len: usize, address: usize) bool {
        const slot: *Slot = @ptrCast(@alignCast(raw));
        slot.budget.lock();
        defer slot.budget.unlock();
        const result = slot.budget.state.allocator().rawResize(bytes, alignment, len, address);
        slot.last_failure_was_limit = slot.budget.state.last_failure_was_limit;
        return result;
    }

    fn remap(raw: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, len: usize, address: usize) ?[*]u8 {
        const slot: *Slot = @ptrCast(@alignCast(raw));
        slot.budget.lock();
        defer slot.budget.unlock();
        const result = slot.budget.state.allocator().rawRemap(bytes, alignment, len, address);
        slot.last_failure_was_limit = slot.budget.state.last_failure_was_limit;
        return result;
    }

    fn free(raw: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, address: usize) void {
        const slot: *Slot = @ptrCast(@alignCast(raw));
        slot.budget.lock();
        defer slot.budget.unlock();
        slot.budget.state.allocator().rawFree(bytes, alignment, address);
    }
};

test {
    _ = @import("memory_tests.zig");
}
