const std = @import("std");
const budget = @import("budget.zig");

/// A decoder call owns only its policy scope. The optional heap owner keeps
/// retained scratch and workspace charged between calls; a default call only
/// borrows the supplied allocator and any outer shared ledger.
pub const Operation = struct {
    caller: std.mem.Allocator,
    owner: ?*budget.Owner,
    fallback: budget.Lease = undefined,
    destination_precharged: bool = false,

    pub fn begin(
        slot: *?*budget.Owner,
        caller: std.mem.Allocator,
        options: anytype,
        retained_bytes: usize,
        caller_capacity: usize,
    ) budget.Error!Operation {
        if (slot.*) |owner| {
            _ = try owner.begin(options);
            return .{ .caller = caller, .owner = owner };
        }
        const inherited = budget.isTracked(caller);
        const existing = std.math.add(usize, retained_bytes, if (inherited) 0 else caller_capacity) catch
            return error.IntegerOverflow;
        const created = budget.Owner.create(caller, options, existing) catch |err| {
            if (!inherited) if (budget.config(options).profile) |profile|
                profile.record(retained_bytes, budget.config(options).limit);
            return err;
        };
        if (created) |owner| {
            slot.* = owner;
            return .{
                .caller = caller,
                .owner = owner,
                .destination_precharged = !inherited,
            };
        }
        return .{
            .caller = caller,
            .owner = null,
            .fallback = try budget.Lease.init(caller, null, null, 0),
        };
    }

    pub fn allocator(self: *const Operation) std.mem.Allocator {
        return self.lease().allocator();
    }

    pub fn lease(self: *const Operation) budget.Lease {
        return if (self.owner) |owner| owner.lease else self.fallback;
    }

    pub fn forward(_: *const Operation, options: anytype) @TypeOf(options) {
        return budget.forward(options);
    }

    pub fn appendScope(self: *const Operation, out: *std.ArrayList(u8)) budget.Error!budget.AppendScope {
        return if (self.destination_precharged)
            budget.AppendScope.initCharged(self.lease(), self.caller, out)
        else
            budget.AppendScope.init(self.lease(), self.caller, out);
    }

    pub fn releaseOwned(self: *const Operation, bytes: usize) budget.Error!void {
        try self.lease().releaseToCaller(self.caller, bytes);
    }

    pub fn mapError(self: *const Operation, err: anyerror) anyerror {
        return if (err == error.OutOfMemory and self.lease().snapshot().last_failure_was_limit)
            error.WorkingMemoryLimitExceeded
        else
            err;
    }

    pub fn end(self: *Operation) void {
        if (self.owner) |owner| owner.end() else self.fallback.deinit();
    }
};
