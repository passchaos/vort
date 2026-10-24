//! The Generic encoder owns a movable lease to the one stable total-memory
//! authority. Codec hooks enumerate and rebind its retained heap allocations.
const std = @import("std");
const total = @import("../../encoder/total_budget.zig");
pub const Error = total.Error;
pub const Config = struct {
    limit: ?usize = null,
    profile: ?*total.EncodeMemoryProfile = null,
};

pub const Binding = struct {
    lease: ?total.Lease = null,
    shared: bool = false,

    pub fn initShared(base: std.mem.Allocator, lease: total.Lease) Error!Binding {
        try lease.releaseToCaller(base, 0);
        return .{ .lease = try lease.retain(), .shared = true };
    }

    pub fn activate(self: *Binding, comptime Codec: type, base: std.mem.Allocator, state: *Codec.State, options: Codec.StreamOptions, plain_capacity: usize, pending_capacity: usize) (Codec.Error || Error)!std.mem.Allocator {
        const config: Config = if (@hasDecl(Codec, "extractMemoryConfig")) blk: {
            const extracted = Codec.extractMemoryConfig(options);
            break :blk .{ .limit = extracted.limit, .profile = extracted.profile };
        } else .{};
        if (self.lease) |lease| {
            try lease.releaseToCaller(base, 0);
            if (self.shared) {
                if (config.limit != null or config.profile != null) {
                    var checked = try total.Lease.init(lease.allocator(), config.limit, config.profile, 0);
                    checked.deinit();
                }
            } else {
                // Rejection precedes any reset or allocator rebinding. A lease
                // remains alive while retained buffers still use its context.
                const previous_limit = lease.snapshot().limit;
                try lease.setLimit(config.limit);
                lease.setProfile(config.profile) catch |err| {
                    lease.setLimit(previous_limit) catch unreachable;
                    return err;
                };
            }
            lease.beginOperation();
            return lease.allocator();
        }
        const tracked = total.isTracked(base);
        if (config.limit == null and config.profile == null and !tracked) return base;
        var retained: usize = 0;
        if (!tracked) {
            retained = std.math.add(usize, plain_capacity, pending_capacity) catch return error.IntegerOverflow;
            if (@hasDecl(Codec, "requiredTotalRetainedBytes")) {
                retained = std.math.add(usize, retained, try Codec.requiredTotalRetainedBytes(state)) catch return error.IntegerOverflow;
            }
        }
        const lease = try total.Lease.init(base, config.limit, config.profile, retained);
        const allocator = lease.allocator();
        if (@hasDecl(Codec, "rebindStateAllocator")) Codec.rebindStateAllocator(state, allocator);
        self.* = .{ .lease = lease, .shared = tracked };
        return allocator;
    }

    /// Cleanup uses the original ownership allocator, regardless of mutations
    /// to the encoder's public base field. It never creates or changes a lease.
    pub fn current(self: *const Binding, base: std.mem.Allocator) std.mem.Allocator {
        return if (self.lease) |lease| lease.allocator() else base;
    }

    pub fn mapError(self: *const Binding, err: anyerror) anyerror {
        if (err == error.OutOfMemory) {
            if (self.lease) |lease| if (lease.snapshot().last_failure_was_limit) return error.WorkingMemoryLimitExceeded;
        }
        return err;
    }

    /// All Codec payload and Generic IO must be freed before this final release.
    pub fn deinit(self: *Binding) void {
        if (self.lease) |*lease| lease.deinit();
        self.* = .{};
    }
};
