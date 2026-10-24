const std = @import("std");
const total = @import("../total_budget.zig");
const entry = @import("entry.zig");
const identity = @import("../../../io/requested_heap_budget/identity.zig");

/// Persistent ledger for reusable encoders. The physical owner remains base;
/// tracking is activated only when requested and retained capacity is adopted
/// once, before the owner rebinds its growth/free allocator to the result.
pub const Reusable = struct {
    base: std.mem.Allocator,
    lease: ?total.Lease = null,
    inherited: bool = false,

    pub fn init(base: std.mem.Allocator) total.Error!Reusable {
        return .{ .base = base, .lease = try total.Lease.fromAllocator(base), .inherited = total.isTracked(base) };
    }

    pub fn initShared(base: std.mem.Allocator, lease: total.Lease) total.Error!Reusable {
        try lease.releaseToCaller(base, 0);
        return .{ .base = base, .lease = try lease.retain(), .inherited = true };
    }

    /// retainedGetter(owner) returns exact requested capacity and may fail with
    /// IntegerOverflow. It runs only when this call first enables tracking.
    pub fn begin(self: *Reusable, options: anytype, owner: anytype, comptime retainedGetter: anytype) total.Error!std.mem.Allocator {
        const settings = entry.config(options);
        if (self.lease) |lease| {
            if (self.inherited) {
                var nested = try total.Lease.init(lease.allocator(), settings.limit, settings.profile, 0);
                nested.deinit();
            } else {
                lease.beginOperation();
                try lease.configure(settings.limit, settings.profile);
            }
            return lease.allocator();
        }
        if (settings.limit == null and settings.profile == null) return self.base;
        const retained = try retainedGetter(owner);
        self.lease = try total.Lease.init(self.base, settings.limit, settings.profile, retained);
        return self.allocator();
    }

    pub fn allocator(self: *const Reusable) std.mem.Allocator {
        return if (self.lease) |lease| lease.allocator() else self.base;
    }

    pub fn forward(_: *const Reusable, options: anytype) @TypeOf(options) {
        return entry.forward(options);
    }

    pub fn snapshot(self: *const Reusable) total.Snapshot {
        return if (self.lease) |lease| lease.snapshot() else .{};
    }

    pub fn mapError(self: *const Reusable, err: anyerror) anyerror {
        return if (self.lease) |lease| entry.mapLeaseError(lease, err) else err;
    }

    /// Borrowed result/scratch remains charged. Call this only for an owned
    /// allocation transferred to its compatible physical allocator.
    pub fn releaseOwned(self: *const Reusable, caller: std.mem.Allocator, exact_bytes: usize) total.Error!void {
        if (self.lease) |lease| try lease.releaseToCaller(caller, exact_bytes) else {
            if (!identity.equal(self.base, caller)) return error.InvalidBlockPlan;
        }
    }

    /// Separate return allocators reserve the same quota before requesting
    /// physical memory. A failed physical request does not raise actual peak.
    pub fn duplicateOwned(self: *const Reusable, caller: std.mem.Allocator, bytes: []const u8) total.Error![]u8 {
        if (self.lease) |lease| {
            if (lease.isSameAllocator(caller)) return caller.dupe(u8, bytes) catch |err| return @errorCast(self.mapError(err));
            if (identity.equal(lease.backing, caller)) {
                const copy = lease.allocator().dupe(u8, bytes) catch |err| return @errorCast(self.mapError(err));
                errdefer lease.allocator().free(copy);
                try lease.releaseToCaller(caller, copy.len);
                return copy;
            }
            var reservation = try lease.tryReserveExternal(bytes.len);
            defer reservation.deinit();
            const copy = try caller.dupe(u8, bytes);
            reservation.markAllocated();
            reservation.handoff();
            return copy;
        }
        return caller.dupe(u8, bytes);
    }

    /// Per-call profile storage may go out of scope after this returns. The
    /// reusable heap stays counted and the shared outer profile stays attached.
    pub fn end(self: *Reusable) void {
        if (!self.inherited) if (self.lease) |lease| lease.setProfile(null) catch unreachable;
    }

    /// All retained payload must be freed through allocator() before deinit.
    pub fn deinit(self: *Reusable) void {
        self.end();
        if (self.lease) |*lease| lease.deinit();
        self.lease = null;
    }
};
