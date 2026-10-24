const std = @import("std");
const State = @import("requested_heap_budget/state.zig").State;
const identity = @import("requested_heap_budget/identity.zig");
pub const EncodeMemoryProfile = @import("requested_heap_budget/profile.zig").EncodeMemoryProfile;
pub const Snapshot = @import("requested_heap_budget/state.zig").Snapshot;
pub const ExternalReservation = @import("requested_heap_budget/external.zig").ExternalReservation;
pub const Error = error{ OutOfMemory, InvalidBlockPlan, IntegerOverflow, WorkingMemoryLimitExceeded };
pub const control_bytes: usize = @sizeOf(State);

pub fn isTracked(a: std.mem.Allocator) bool {
    return State.fromAllocator(a) != null;
}

/// A stable shared ledger is allocated only for a cap or instrumentation. The
/// default path is exactly the provided allocator. Backing contexts and active
/// profile storage must outlive their leases; nested operations inherit policy.
pub const Lease = struct {
    backing: std.mem.Allocator,
    state: ?*State = null,
    /// Only the owning operation coordinates error-classification intervals
    /// and profile/policy binding; borrowed sibling leases cannot reset it.
    coordinator: bool = true,

    pub fn init(backing: std.mem.Allocator, limit: ?usize, profile: ?*EncodeMemoryProfile, seed_existing: usize) Error!Lease {
        if (State.fromAllocator(backing)) |s| {
            s.enter();
            defer s.leave();
            if (seed_existing != 0 or (limit != null and limit != s.limit) or (profile != null and profile != s.profile)) return error.InvalidBlockPlan;
            s.references = std.math.add(usize, s.references, 1) catch return error.IntegerOverflow;
            return .{ .backing = s.backing, .state = s, .coordinator = false };
        }
        if (limit == null and profile == null) return .{ .backing = backing };
        if (profile) |p| p.record(seed_existing, limit);
        const initial = std.math.add(usize, seed_existing, control_bytes) catch return error.IntegerOverflow;
        if (initial > (limit orelse std.math.maxInt(usize))) return error.WorkingMemoryLimitExceeded;
        const state = try backing.create(State);
        state.* = .{ .backing = backing, .limit = limit, .profile = profile, .live = initial, .peak = initial };
        state.reportLocked();
        return .{ .backing = backing, .state = state };
    }
    pub fn allocator(self: Lease) std.mem.Allocator {
        return if (self.state) |s| s.allocator() else self.backing;
    }
    pub fn retain(self: Lease) Error!Lease {
        if (self.state) |s| {
            s.enter();
            defer s.leave();
            std.debug.assert(s.references != 0);
            s.references = std.math.add(usize, s.references, 1) catch return error.IntegerOverflow;
        }
        var shared = self;
        shared.coordinator = false;
        return shared;
    }
    pub fn fromAllocator(a: std.mem.Allocator) Error!?Lease {
        const s = State.fromAllocator(a) orelse return null;
        return try (Lease{ .backing = s.backing, .state = s }).retain();
    }
    pub fn snapshot(self: Lease) Snapshot {
        return if (self.state) |s| s.snapshot() else .{};
    }
    pub fn isSameAllocator(self: Lease, a: std.mem.Allocator) bool {
        return self.state != null and State.fromAllocator(a) == self.state;
    }
    pub fn beginOperation(self: Lease) void {
        if (!self.coordinator) return;
        if (self.state) |s| {
            s.enter();
            s.hit_limit = false;
            s.last_failure_was_limit = false;
            s.leave();
        }
    }
    pub fn configure(self: Lease, limit: ?usize, profile: ?*EncodeMemoryProfile) Error!void {
        const s = self.state orelse {
            if (limit != null or profile != null) return error.InvalidBlockPlan;
            return;
        };
        s.enter();
        defer s.leave();
        if (!self.coordinator) {
            if ((limit != null and limit != s.limit) or (profile != null and profile != s.profile)) return error.InvalidBlockPlan;
            return;
        }
        const occupied = std.math.add(usize, s.live, s.reserved) catch return error.IntegerOverflow;
        if (occupied > (limit orelse std.math.maxInt(usize))) {
            s.hit_limit = true;
            s.last_failure_was_limit = true;
            return error.WorkingMemoryLimitExceeded;
        }
        s.limit = limit;
        s.profile = profile;
        s.reportLocked();
    }
    pub fn setLimit(self: Lease, limit: ?usize) Error!void {
        const s = self.state orelse {
            if (limit != null) return error.InvalidBlockPlan;
            return;
        };
        s.enter();
        defer s.leave();
        if (!self.coordinator) {
            if (limit != s.limit) return error.InvalidBlockPlan;
            return;
        }
        const occupied = std.math.add(usize, s.live, s.reserved) catch return error.IntegerOverflow;
        if (occupied > (limit orelse std.math.maxInt(usize))) {
            s.hit_limit = true;
            s.last_failure_was_limit = true;
            return error.WorkingMemoryLimitExceeded;
        }
        s.limit = limit;
        s.reportLocked();
    }
    pub fn setProfile(self: Lease, profile: ?*EncodeMemoryProfile) Error!void {
        if (self.state) |s| {
            s.enter();
            defer s.leave();
            if (!self.coordinator) {
                if (profile != s.profile) return error.InvalidBlockPlan;
                return;
            }
            s.profile = profile;
            s.reportLocked();
        } else if (profile != null) return error.InvalidBlockPlan;
    }
    pub fn seedExisting(self: Lease, bytes: usize) Error!void {
        if (self.state) |s| {
            s.enter();
            defer s.leave();
            const occupied = std.math.add(usize, s.live, s.reserved) catch return error.IntegerOverflow;
            _ = std.math.add(usize, occupied, bytes) catch return error.IntegerOverflow;
            if (!s.allowedLocked(bytes)) return error.WorkingMemoryLimitExceeded;
            s.replaceLocked(0, bytes);
        }
    }
    pub fn reserveExisting(self: Lease, bytes: usize) Error!void {
        try self.seedExisting(bytes);
    }
    pub fn releaseExisting(self: Lease, bytes: usize) void {
        if (self.state) |s| {
            s.enter();
            s.replaceLocked(bytes, 0);
            s.leave();
        }
    }
    pub fn releaseToCaller(self: Lease, caller: std.mem.Allocator, bytes: usize) Error!void {
        if (self.isSameAllocator(caller)) return;
        if (!identity.equal(self.backing, caller)) return error.InvalidBlockPlan;
        self.releaseExisting(bytes);
    }
    pub fn tryReserveExternal(self: Lease, bytes: usize) Error!ExternalReservation {
        return ExternalReservation.init(self.state, bytes);
    }
    pub fn translateError(self: Lease, err: Error) Error {
        if (err == error.OutOfMemory and self.snapshot().last_failure_was_limit) return error.WorkingMemoryLimitExceeded;
        return err;
    }
    pub fn deinit(self: *Lease) void {
        if (self.state) |s| s.releaseReference();
        self.state = null;
    }
};

test {
    _ = @import("requested_heap_budget/tests.zig");
}
