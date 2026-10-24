const std = @import("std");
const builtin = @import("builtin");
const State = @import("total_budget/state.zig").State;
pub const Snapshot = @import("total_budget/state.zig").Snapshot;
pub const EncodeMemoryProfile = @import("total_budget/profile.zig").EncodeMemoryProfile;
pub const ExternalReservation = @import("total_budget/external.zig").ExternalReservation;
pub const Error = error{ OutOfMemory, InvalidBlockPlan, IntegerOverflow, WorkingMemoryLimitExceeded };
pub const control_bytes: usize = @sizeOf(State);

pub fn isTracked(a: std.mem.Allocator) bool {
    return State.fromAllocator(a) != null;
}

fn sameBacking(left: std.mem.Allocator, right: std.mem.Allocator) bool {
    if (left.vtable != right.vtable) return false;
    // These standard singletons deliberately leave ptr undefined. Their
    // vtable is their identity. A custom stateless allocator must use a defined
    // sentinel context if it participates in checked ownership transfers.
    if (!builtin.cpu.arch.isWasm()) {
        if (left.vtable == &std.heap.PageAllocator.vtable) return true;
    }
    if (!builtin.single_threaded) {
        if (left.vtable == &std.heap.SmpAllocator.vtable) return true;
    }
    if (builtin.single_threaded and (builtin.cpu.arch.isWasm() or builtin.os.tag == .linux)) {
        if (left.vtable == std.heap.brk_allocator.vtable) return true;
    }
    if (builtin.link_libc and left.vtable == std.heap.c_allocator.vtable) return true;
    return left.ptr == right.ptr;
}

/// One ownership reference to a stable total-requested-heap allocator. The
/// default null-limit/null-profile path is exactly the original allocator and
/// allocates no control. Finite limits or instrumentation create counted state.
/// A single coordinating owner configures the shared policy and starts error
/// intervals; retained descendants only borrow that authority. Sharing does not
/// synchronize allocator requests or lease lifetimes between threads.
/// After the last lease closes, outstanding buffers may still be freed or
/// shrunk, but their allocator cannot acquire a new lease or grow the ledger.
pub const Lease = struct {
    backing: std.mem.Allocator,
    state: ?*State = null,
    coordinator: bool = true,

    pub fn init(backing: std.mem.Allocator, limit: ?usize, profile: ?*EncodeMemoryProfile, seed_existing: usize) Error!Lease {
        if (State.fromAllocator(backing)) |state| {
            if (state.references == 0) return error.InvalidBlockPlan;
            // A nested encoder inherits the outer policy and bytes already
            // charged there. It must not re-seed or silently install a new cap.
            if (seed_existing != 0 or (limit != null and limit != state.limit)) return error.InvalidBlockPlan;
            const references = std.math.add(usize, state.references, 1) catch return error.IntegerOverflow;
            if (profile) |p| {
                if (state.profile != p) return error.InvalidBlockPlan;
            }
            state.references = references;
            return .{ .backing = state.backing, .state = state, .coordinator = false };
        }
        if (limit == null and profile == null) return .{ .backing = backing };
        if (profile) |p| p.record(seed_existing, limit);
        const initial = std.math.add(usize, seed_existing, control_bytes) catch return error.IntegerOverflow;
        if (initial > (limit orelse std.math.maxInt(usize))) return error.WorkingMemoryLimitExceeded;
        const state = try backing.create(State);
        state.* = .{ .backing = backing, .limit = limit, .profile = profile, .live = initial, .peak = initial };
        state.report();
        return .{ .backing = backing, .state = state };
    }
    pub fn allocator(self: Lease) std.mem.Allocator {
        return if (self.state) |state| state.allocator() else self.backing;
    }
    pub fn retain(self: Lease) Error!Lease {
        if (self.state) |state| {
            if (state.references == 0) return error.InvalidBlockPlan;
            state.references = std.math.add(usize, state.references, 1) catch return error.IntegerOverflow;
        }
        var child = self;
        child.coordinator = false;
        return child;
    }
    pub fn fromAllocator(a: std.mem.Allocator) Error!?Lease {
        const state = State.fromAllocator(a) orelse return null;
        const lease: Lease = .{ .backing = state.backing, .state = state, .coordinator = false };
        return try lease.retain();
    }
    pub fn snapshot(self: Lease) Snapshot {
        return if (self.state) |state| state.snapshot() else .{};
    }
    /// Only the coordinating owner starts a fresh error-classification interval.
    /// A quota refusal remains sticky through descendant calls and subsequent
    /// backing requests until the owner classifies it and begins the next call.
    pub fn beginOperation(self: Lease) void {
        if (!self.coordinator) return;
        if (self.state) |state| state.last_failure_was_limit = false;
    }
    pub fn isSameAllocator(self: Lease, a: std.mem.Allocator) bool {
        const state = self.state orelse return false;
        return State.fromAllocator(a) == state;
    }
    pub fn setLimit(self: Lease, limit: ?usize) Error!void {
        if (!self.coordinator) {
            if (limit != self.snapshot().limit) return error.InvalidBlockPlan;
            return;
        }
        const state = self.state orelse {
            if (limit != null) return error.InvalidBlockPlan;
            return;
        };
        const occupied = std.math.add(usize, state.live, state.reserved) catch return error.IntegerOverflow;
        if (occupied > (limit orelse std.math.maxInt(usize))) {
            state.hit_limit = true;
            state.last_failure_was_limit = true;
            return error.WorkingMemoryLimitExceeded;
        }
        state.limit = limit;
        state.report();
    }
    /// A call-scoped profile must be detached before its storage expires.
    pub fn setProfile(self: Lease, profile: ?*EncodeMemoryProfile) Error!void {
        if (!self.coordinator) {
            const current = if (self.state) |state| state.profile else null;
            if (profile != current) return error.InvalidBlockPlan;
            return;
        }
        if (self.state) |state| {
            state.profile = profile;
            state.report();
        } else if (profile != null) {
            // Enabling instrumentation needs a counted stable control, plus
            // adoption of any retained storage. The caller must initialize it.
            return error.InvalidBlockPlan;
        }
    }
    /// Adopt known existing allocations exactly once before rebinding their
    /// allocator/free paths. Already-total-tracked allocations need no adoption.
    pub fn seedExisting(self: Lease, bytes: usize) Error!void {
        if (self.state) |state| {
            const occupied = std.math.add(usize, state.live, state.reserved) catch return error.IntegerOverflow;
            _ = std.math.add(usize, occupied, bytes) catch return error.IntegerOverflow;
            if (!state.allow(bytes)) return error.WorkingMemoryLimitExceeded;
            state.changed(0, bytes);
        }
    }
    pub fn reserveExisting(self: Lease, bytes: usize) Error!void {
        try self.seedExisting(bytes);
    }
    pub fn tryReserveExternal(self: Lease, bytes: usize) Error!ExternalReservation {
        return ExternalReservation.init(self.state, bytes);
    }
    pub fn translateError(self: Lease, err: Error) Error {
        if (err == error.OutOfMemory and self.snapshot().last_failure_was_limit)
            return error.WorkingMemoryLimitExceeded;
        return err;
    }
    /// Release an externally freed or handed-off allocation's exact requested
    /// size without freeing its bytes. Never use logical length for spare capacity.
    pub fn releaseExisting(self: Lease, bytes: usize) void {
        if (self.state) |state| state.changed(bytes, 0);
    }
    /// A returned wire freed with the original backing allocator leaves this
    /// budget. Returning it to the same tracked allocator keeps its charge.
    pub fn releaseToCaller(self: Lease, caller: std.mem.Allocator, allocation_bytes: usize) Error!void {
        if (self.isSameAllocator(caller)) return;
        if (!sameBacking(self.backing, caller)) return error.InvalidBlockPlan;
        self.releaseExisting(allocation_bytes);
    }
    pub fn deinit(self: *Lease) void {
        if (self.state) |state| {
            std.debug.assert(state.references != 0);
            state.references -= 1;
            if (state.references == 0 and state.live != control_bytes) {
                // Outstanding allocator frees still have stable state. End the
                // borrowed profile lifetime when the last ownership lease ends.
                state.report();
                state.profile = null;
            }
            state.disposeIfUnused();
        }
        self.* = .{ .backing = self.backing };
    }
};

test {
    _ = @import("total_budget/tests.zig");
}
