const std = @import("std");
const total = @import("../../encode/total_budget.zig");

pub const Config = total.Config;

/// Original physical ownership and a persistent total ledger travel together.
/// Codec hooks cover retained storage not directly owned by the frame adapter.
pub const Binding = struct {
    base: std.mem.Allocator,
    lease: ?total.Lease = null,
    shared: bool = false,

    pub fn init(base: std.mem.Allocator) total.Error!Binding {
        return .{ .base = base, .lease = try total.Lease.fromAllocator(base), .shared = total.isTracked(base) };
    }
    pub fn initShared(base: std.mem.Allocator, lease: total.Lease) total.Error!Binding {
        try lease.releaseToCaller(base, 0);
        return .{ .base = base, .lease = try lease.retain(), .shared = true };
    }
    pub fn config(comptime Codec: type, options: Codec.Options) Config {
        if (@hasDecl(Codec, "extractMemoryConfig")) {
            const found = Codec.extractMemoryConfig(options);
            return .{ .limit = found.limit, .profile = found.profile };
        }
        return total.config(options);
    }
    pub fn activate(self: *Binding, comptime Codec: type, options: Codec.Options, state: *Codec.State, io_bytes: usize) (total.Error || Codec.Error)!std.mem.Allocator {
        const settings = config(Codec, options);
        if (self.lease) |lease| {
            if (self.shared) {
                var inherited = try total.Lease.init(lease.allocator(), settings.limit, settings.profile, 0);
                inherited.deinit();
            } else {
                lease.beginOperation();
                try lease.configure(settings.limit, settings.profile);
            }
            return lease.allocator();
        }
        if (settings.limit == null and settings.profile == null) return self.base;
        var retained = io_bytes;
        if (@hasDecl(Codec, "requiredTotalRetainedBytes"))
            retained = std.math.add(usize, retained, try Codec.requiredTotalRetainedBytes(state)) catch return error.IntegerOverflow;
        const lease = try total.Lease.init(self.base, settings.limit, settings.profile, retained);
        const a = lease.allocator();
        if (@hasDecl(Codec, "rebindStateAllocator")) Codec.rebindStateAllocator(state, a);
        self.lease = lease;
        return a;
    }
    pub fn current(self: *const Binding) std.mem.Allocator {
        return if (self.lease) |lease| lease.allocator() else self.base;
    }
    pub fn snapshot(self: *const Binding) total.Snapshot {
        return if (self.lease) |lease| lease.snapshot() else .{};
    }
    pub fn mapError(self: *const Binding, err: anyerror) anyerror {
        if (err == error.OutOfMemory) if (self.lease) |lease| {
            if (lease.snapshot().last_failure_was_limit) return error.WorkingMemoryLimitExceeded;
        };
        return err;
    }
    pub fn deinit(self: *Binding) void {
        if (self.lease) |*lease| lease.deinit();
        self.lease = null;
    }
};
