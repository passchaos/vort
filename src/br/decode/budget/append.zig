const std = @import("std");
const budget = @import("../budget.zig");
const output_size = @import("../output_size.zig");

/// Adopts output capacity before decoded staging is allocated and transfers
/// the final capacity back to its physical caller when the scope closes.
/// Caller and output must outlive this scope; close it before its lease owner.
pub const AppendScope = struct {
    lease: budget.Lease,
    caller: std.mem.Allocator,
    out: *std.ArrayList(u8),
    adopted: bool,
    active: bool = true,

    pub fn init(lease: budget.Lease, caller: std.mem.Allocator, out: *std.ArrayList(u8)) budget.Error!AppendScope {
        const scope = try initCharged(lease, caller, out);
        if (scope.adopted) try lease.seedExisting(out.capacity);
        return scope;
    }

    /// Entry.initExisting or a newly created Owner has already admitted the
    /// caller's capacity before its first control allocation. The ledger must
    /// contain this exact capacity unless caller already uses the same ledger.
    pub fn initCharged(lease: budget.Lease, caller: std.mem.Allocator, out: *std.ArrayList(u8)) budget.Error!AppendScope {
        if (lease.state != null) try lease.releaseToCaller(caller, 0);
        return .{ .lease = lease, .caller = caller, .out = out, .adopted = lease.state != null and !lease.isSameAllocator(caller) };
    }

    /// Count the full target capacity, including spare capacity and any
    /// fallback overlap. Failure preserves the output pointer/capacity/bytes.
    pub fn append(self: *AppendScope, decoded: []const u8) budget.Error!void {
        std.debug.assert(self.active);
        _ = try output_size.appendEnd(self.out.items.len, decoded.len);
        if (self.lease.state == null) return self.out.appendSlice(self.caller, decoded);
        self.out.appendSlice(self.lease.allocator(), decoded) catch |err| return @errorCast(budget.mapLeaseError(self.lease, err));
    }

    pub fn deinit(self: *AppendScope) void {
        if (!self.active) return;
        if (self.adopted) self.lease.releaseToCaller(self.caller, self.out.capacity) catch unreachable;
        self.active = false;
    }
};

/// Convenience for publication when staging is already live. Use AppendScope
/// directly to include caller capacity in earlier staging allocation peaks.
pub fn append(lease: budget.Lease, caller: std.mem.Allocator, out: *std.ArrayList(u8), decoded: []const u8) budget.Error!void {
    var scope = try AppendScope.init(lease, caller, out);
    defer scope.deinit();
    try scope.append(decoded);
}
