//! Transactional ownership of the shared total-memory authority for retained
//! stored-encoder buffers. Allocators point to Lease's stable heap state, never
//! to a movable Owner or operation Scope.
const std = @import("std");
const total = @import("total_budget.zig");
pub const Error = @import("../../core.zig").Error || total.Error;

pub const Owner = struct {
    lease: ?total.Lease = null,
    inherited: bool = false,

    pub fn current(self: *const Owner, backing: std.mem.Allocator) std.mem.Allocator {
        return if (self.lease) |lease| lease.allocator() else backing;
    }

    /// Inherited controls are already counted by their outer owner.
    pub fn ownedControlBytes(self: *const Owner) usize {
        if (self.inherited) return 0;
        return if (self.lease) |lease| lease.snapshot().control_bytes else 0;
    }

    /// Free every retained payload through current() before releasing its lease.
    pub fn deinit(self: *Owner) void {
        if (self.lease) |*lease| lease.deinit();
        self.* = .{};
    }
};

/// One operation borrows its Owner only until commit. Every temporary payload
/// must be freed before deinit; unsuccessful adoption also requires the old
/// retained buffers to remain unchanged and owned by the backing allocator.
pub const Scope = struct {
    lease: total.Lease,
    owner: *Owner,
    activating: bool,
    inherited: bool,
    seed_existing: usize = 0,
    previous_limit: ?usize = null,
    // Existing locally owned operations retain a child lease for lifetime,
    // while only their original root may configure the shared authority.
    policy_lease: ?total.Lease = null,
    committed: bool = false,
    owns_reference: bool = true,
    active: bool = true,

    pub fn allocator(self: Scope) std.mem.Allocator {
        return self.lease.allocator();
    }

    pub fn mapError(self: Scope, err: anyerror) Error {
        if (err == error.OutOfMemory) return self.lease.translateError(error.OutOfMemory);
        inline for (@typeInfo(Error).error_set.?) |known|
            if (err == @field(Error, known.name)) return @field(Error, known.name);
        return error.InvalidBlockPlan;
    }

    /// Call only after all fallible payload work and ownership swaps succeed.
    /// A new authority moves into the Owner without another allocation or retain.
    pub fn commit(self: *Scope) void {
        std.debug.assert(self.active and !self.committed);
        if (self.activating and self.lease.snapshot().available) {
            std.debug.assert(self.owner.lease == null);
            self.owner.* = .{ .lease = self.lease, .inherited = self.inherited };
            self.owns_reference = false;
        }
        self.committed = true;
    }

    pub fn deinit(self: *Scope) void {
        if (!self.active) return;
        self.active = false;
        if (self.activating and !self.committed) {
            // Only the accounting is rolled back: the old backing allocation
            // has not moved. The final lease release reports zero live bytes.
            if (!self.inherited) self.lease.releaseExisting(self.seed_existing);
        } else if (!self.inherited) {
            const policy = self.policy_lease orelse self.lease;
            if (!self.activating and !self.committed)
                policy.setLimit(self.previous_limit) catch unreachable;
            policy.setProfile(null) catch unreachable;
        }
        if (self.owns_reference) self.lease.deinit();
    }
};

/// Source and option validation precede this call. retained_bytes is the exact
/// requested capacity of old allocations on an ordinary backing allocator;
/// inherited allocations have already been charged and are never seeded again.
pub fn begin(owner: *Owner, backing: std.mem.Allocator, options: anytype, retained_bytes: usize) Error!Scope {
    if (owner.lease) |existing| {
        try existing.releaseToCaller(backing, 0);
        var lease = if (owner.inherited)
            try total.Lease.init(existing.allocator(), options.max_total_working_memory, options.memory_profile, 0)
        else
            try existing.retain();
        errdefer lease.deinit();
        const previous_limit = lease.snapshot().limit;
        if (!owner.inherited) {
            existing.beginOperation();
            try existing.setLimit(options.max_total_working_memory);
            existing.setProfile(options.memory_profile) catch |err| {
                existing.setLimit(previous_limit) catch unreachable;
                return err;
            };
        }
        return .{
            .lease = lease,
            .owner = owner,
            .activating = false,
            .inherited = owner.inherited,
            .previous_limit = previous_limit,
            .policy_lease = if (owner.inherited) null else existing,
        };
    }

    const inherited = total.isTracked(backing);
    const seed_existing = if (inherited) 0 else retained_bytes;
    const lease = try total.Lease.init(backing, options.max_total_working_memory, options.memory_profile, seed_existing);
    lease.beginOperation();
    return .{
        .lease = lease,
        .owner = owner,
        .activating = true,
        .inherited = inherited,
        .seed_existing = if (lease.snapshot().available) seed_existing else 0,
    };
}

test {
    _ = @import("stored_memory_owner_tests.zig");
}
