const std = @import("std");
const budget = @import("../budget.zig");

/// Optional stable control owner for reusable decoders. The decoder stores
/// only its pointer and rebinds retained payload growth/free to allocator().
pub const Owner = struct {
    lease: budget.Lease,
    inherited: bool,

    /// Existing retained payload is adopted only for a new independent
    /// ledger. The complete initial quota is checked before either control
    /// allocation; creation failure leaves that payload and its allocator
    /// ownership unchanged. Profile peaks count successful physical requests.
    pub fn create(base: std.mem.Allocator, options: anytype, retained_bytes: usize) budget.Error!?*Owner {
        const settings = budget.config(options);
        const inherited = budget.isTracked(base);
        if (settings.limit == null and settings.profile == null) return null;
        if (!inherited) {
            if (settings.profile) |p| p.record(retained_bytes, settings.limit);
            const controls = std.math.add(usize, budget.control_bytes, @sizeOf(Owner)) catch return error.IntegerOverflow;
            const occupied = std.math.add(usize, controls, retained_bytes) catch return error.IntegerOverflow;
            if (occupied > (settings.limit orelse std.math.maxInt(usize))) return error.WorkingMemoryLimitExceeded;
        }
        const adopted = if (inherited) 0 else retained_bytes;
        var lease = try budget.Lease.init(base, settings.limit, settings.profile, adopted);
        errdefer {
            if (!inherited) lease.releaseExisting(adopted);
            lease.deinit();
        }
        const owner = lease.allocator().create(Owner) catch |err| return @errorCast(budget.mapLeaseError(lease, err));
        owner.* = .{ .lease = lease, .inherited = inherited };
        return owner;
    }

    pub fn begin(self: *Owner, options: anytype) budget.Error!std.mem.Allocator {
        const settings = budget.config(options);
        if (!self.inherited) self.lease.beginOperation();
        self.lease.configure(settings.limit, settings.profile) catch |err| {
            if (!self.inherited) {
                if (settings.profile) |p| p.record(self.snapshot().live_requested_bytes, settings.limit);
                self.end();
            }
            return err;
        };
        return self.allocator();
    }

    pub fn allocator(self: *const Owner) std.mem.Allocator {
        return self.lease.allocator();
    }

    pub fn forward(_: *const Owner, options: anytype) @TypeOf(options) {
        return budget.forward(options);
    }

    pub fn snapshot(self: *const Owner) budget.Snapshot {
        return self.lease.snapshot();
    }

    pub fn mapError(self: *const Owner, err: anyerror) anyerror {
        return budget.mapLeaseError(self.lease, err);
    }

    pub fn releaseOwned(self: *const Owner, base_caller: std.mem.Allocator, exact_bytes: usize) budget.Error!void {
        try self.lease.releaseToCaller(base_caller, exact_bytes);
    }

    /// Call profiles may leave scope after end; inherited profiles belong to
    /// the parent operation and must remain attached.
    pub fn end(self: *Owner) void {
        if (!self.inherited) self.lease.setProfile(null) catch unreachable;
    }

    /// Free retained payload through allocator() before destroying the owner.
    pub fn destroy(self: *Owner) void {
        self.end();
        var lease = self.lease;
        lease.allocator().destroy(self);
        lease.deinit();
    }
};
