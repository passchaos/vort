const std = @import("std");
const total = @import("../total_budget.zig");

pub const Config = struct {
    limit: ?usize = null,
    profile: ?*total.EncodeMemoryProfile = null,
};

pub fn config(options: anytype) Config {
    const Options = @TypeOf(options);
    return .{
        .limit = if (@hasField(Options, "max_total_working_memory")) options.max_total_working_memory else null,
        .profile = if (@hasField(Options, "memory_profile")) options.memory_profile else null,
    };
}

/// Inner codec calls inherit their allocator's policy. Clearing these fields
/// prevents them from becoming another operation/profile owner.
pub fn forward(options: anytype) @TypeOf(options) {
    var inner = options;
    if (@hasField(@TypeOf(options), "max_total_working_memory")) inner.max_total_working_memory = null;
    if (@hasField(@TypeOf(options), "memory_profile")) inner.memory_profile = null;
    return inner;
}

/// One-shot outer scope. Destroy encoder-owned state before closing the entry,
/// and transfer returned allocations while this stable ledger is still alive.
pub const Entry = struct {
    caller: std.mem.Allocator,
    lease: total.Lease,

    pub fn init(caller: std.mem.Allocator, options: anytype) total.Error!Entry {
        const settings = config(options);
        return .{ .caller = caller, .lease = try total.Lease.init(caller, settings.limit, settings.profile, 0) };
    }

    pub fn allocator(self: *const Entry) std.mem.Allocator {
        return self.lease.allocator();
    }

    pub fn forward(_: *const Entry, options: anytype) @TypeOf(options) {
        return @import("entry.zig").forward(options);
    }

    /// exact_bytes is the allocation capacity that transfers to caller,
    /// including any sentinel, rather than an ArrayList's logical length.
    pub fn releaseOwned(self: *const Entry, exact_bytes: usize) total.Error!void {
        try self.lease.releaseToCaller(self.caller, exact_bytes);
    }

    pub fn snapshot(self: *const Entry) total.Snapshot {
        return self.lease.snapshot();
    }

    pub fn mapError(self: *const Entry, err: anyerror) anyerror {
        return mapLeaseError(self.lease, err);
    }

    pub fn deinit(self: *Entry) void {
        self.lease.deinit();
    }
};

pub fn mapLeaseError(lease: total.Lease, err: anyerror) anyerror {
    if (err == error.OutOfMemory and lease.snapshot().last_failure_was_limit) return error.WorkingMemoryLimitExceeded;
    return err;
}
