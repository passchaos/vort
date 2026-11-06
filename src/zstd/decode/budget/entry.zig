const std = @import("std");
const budget = @import("../budget.zig");

pub const Config = struct {
    limit: ?usize = null,
    profile: ?*budget.DecodeMemoryProfile = null,
};

pub fn config(options: anytype) Config {
    const Options = @TypeOf(options);
    return .{
        .limit = if (@hasField(Options, "max_total_working_memory")) options.max_total_working_memory else null,
        .profile = if (@hasField(Options, "memory_profile")) options.memory_profile else null,
    };
}

/// Nested decoders inherit the allocator policy without owning a new profile.
pub fn forward(options: anytype) @TypeOf(options) {
    var inner = options;
    if (@hasField(@TypeOf(options), "max_total_working_memory")) inner.max_total_working_memory = null;
    if (@hasField(@TypeOf(options), "memory_profile")) inner.memory_profile = null;
    return inner;
}

/// One-shot scope. Free decoder-owned working allocations and transfer owned
/// output capacity before closing this entry.
pub const Entry = struct {
    caller: std.mem.Allocator,
    lease: budget.Lease,

    pub fn init(caller: std.mem.Allocator, options: anytype) budget.Error!Entry {
        return initExisting(caller, options, 0);
    }

    /// Charge caller output capacity before allocating control state or
    /// decoded staging. A caller already using this ledger needs no seed.
    /// Pair this with AppendScope.initCharged so the capacity transfers back
    /// before entry destruction, on both success and failure.
    pub fn initExisting(caller: std.mem.Allocator, options: anytype, existing_bytes: usize) budget.Error!Entry {
        const settings = config(options);
        const seed = if (budget.isTracked(caller)) 0 else existing_bytes;
        const lease = budget.Lease.init(caller, settings.limit, settings.profile, seed) catch |err| {
            // Existing append storage belongs to the caller again when no
            // entry could be established. Preserve any observed peak, while
            // leaving an inherited parent ledger's profile untouched.
            if (!budget.isTracked(caller)) if (settings.profile) |profile|
                profile.record(0, settings.limit);
            return err;
        };
        return .{ .caller = caller, .lease = lease };
    }

    pub fn allocator(self: *const Entry) std.mem.Allocator {
        return self.lease.allocator();
    }

    pub fn forward(_: *const Entry, options: anytype) @TypeOf(options) {
        return @import("entry.zig").forward(options);
    }

    pub fn snapshot(self: *const Entry) budget.Snapshot {
        return self.lease.snapshot();
    }

    /// The transferred size includes spare capacity and any sentinel.
    pub fn releaseOwned(self: *const Entry, exact_bytes: usize) budget.Error!void {
        try self.lease.releaseToCaller(self.caller, exact_bytes);
    }

    pub fn mapError(self: *const Entry, err: anyerror) anyerror {
        return mapLeaseError(self.lease, err);
    }

    pub fn deinit(self: *Entry) void {
        self.lease.deinit();
    }
};

pub fn mapLeaseError(lease: budget.Lease, err: anyerror) anyerror {
    if (err == error.OutOfMemory and lease.snapshot().last_failure_was_limit) return error.WorkingMemoryLimitExceeded;
    return err;
}
