//! A second physical allocator participates in one stable shared ledger.
const std = @import("std");
const shared = @import("../../../io/requested_heap_budget.zig");
const Error = @import("../arena_budget.zig").Error;

/// Transfer an allocated reservation's charge to the caller's aggregate scope.
/// markAllocated() acquired one reference for the reservation. Consume exactly
/// that reference without handing off its live bytes; the scope's owning Lease
/// remains alive until Physical.handoff releases the aggregate's retained heap.
/// No allocation ticket, copied owning Lease or new reference survives this call.
pub fn adoptAllocated(scope: shared.Lease, reservation: *shared.ExternalReservation) void {
    std.debug.assert(reservation.active and reservation.allocated);
    std.debug.assert(reservation.state == scope.state);
    reservation.active = false;
    var reservation_reference = scope;
    reservation_reference.deinit();
}

pub const Physical = struct {
    base: std.mem.Allocator,
    /// Borrowed from Operation; this field never owns an additional reference.
    lease: shared.Lease,
    /// Existing seed plus successful physical replacements, excluding remap
    /// transients internal to a backing allocator and arena logical suballocs.
    live: usize,
    failure: ?Error = null,

    pub fn allocator(self: *Physical) std.mem.Allocator {
        if (self.lease.state == null) return self.base;
        return .{ .ptr = self, .vtable = &vtable };
    }
    pub fn handoff(self: *Physical) void {
        if (self.lease.state != null and !self.lease.isSameAllocator(self.base)) self.lease.releaseExisting(self.live);
        self.live = 0;
    }
    fn backingLimitHit(self: *Physical) bool {
        var backing_lease = (shared.Lease.fromAllocator(self.base) catch |err| {
            self.failure = @errorCast(err);
            return false;
        }) orelse return false;
        defer backing_lease.deinit();
        return backing_lease.snapshot().hit_limit;
    }
    fn mayRequest(self: *Physical) bool {
        if (self.failure != null) return false;
        if (self.lease.snapshot().hit_limit or self.backingLimitHit()) {
            self.failure = error.WorkingMemoryLimitExceeded;
            return false;
        }
        return self.failure == null;
    }
    fn fitsProbe(lease: shared.Lease, bytes: usize) bool {
        const snapshot = lease.snapshot();
        const limit = snapshot.limit orelse std.math.maxInt(usize);
        if (snapshot.live_requested_bytes > limit or snapshot.reserved_bytes > limit - snapshot.live_requested_bytes) return false;
        return bytes <= limit - snapshot.live_requested_bytes - snapshot.reserved_bytes;
    }
    /// resize/remap may be declined as unsupported without asking the physical
    /// allocator to grow. Std Arena's speculative node growth can exceed the
    /// subsequent new-node fallback size because of its end_index overshoot.
    /// Let the actual allocation decide quota; a probe denial is not a refused
    /// codec candidate and must not make a feasible exact-peak operation sticky.
    fn mayProbe(self: *Physical, bytes: usize) bool {
        if (!self.mayRequest() or !fitsProbe(self.lease, bytes)) return false;
        if (self.lease.isSameAllocator(self.base)) return true;
        var backing_lease = (shared.Lease.fromAllocator(self.base) catch |err| {
            self.failure = @errorCast(err);
            return false;
        }) orelse return true;
        defer backing_lease.deinit();
        return fitsProbe(backing_lease, bytes);
    }
    fn reserve(self: *Physical, bytes: usize) ?shared.ExternalReservation {
        if (!self.mayRequest()) return null;
        _ = std.math.add(usize, self.live, bytes) catch {
            self.failure = error.IntegerOverflow;
            return null;
        };
        return self.lease.tryReserveExternal(bytes) catch |err| {
            self.failure = @errorCast(err);
            return null;
        };
    }
    fn allocated(self: *Physical, ticket: *shared.ExternalReservation) void {
        ticket.markAllocated();
        self.live += ticket.bytes;
        adoptAllocated(self.lease, ticket);
    }
    fn backingFailed(self: *Physical) void {
        if (self.backingLimitHit()) self.failure = error.WorkingMemoryLimitExceeded else if (self.failure == null) self.failure = error.OutOfMemory;
    }

    const vtable: std.mem.Allocator.VTable = .{ .alloc = alloc, .resize = resize, .remap = remap, .free = free };
    fn alloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, ra: usize) ?[*]u8 {
        const self: *Physical = @ptrCast(@alignCast(ctx));
        if (self.lease.isSameAllocator(self.base)) {
            if (!self.mayRequest()) return null;
            return self.base.rawAlloc(len, alignment, ra) orelse {
                self.backingFailed();
                return null;
            };
        }
        var ticket = self.reserve(len) orelse return null;
        const bytes = self.base.rawAlloc(len, alignment, ra) orelse {
            ticket.deinit();
            self.backingFailed();
            return null;
        };
        self.allocated(&ticket);
        return bytes;
    }
    fn resize(ctx: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, new_len: usize, ra: usize) bool {
        const self: *Physical = @ptrCast(@alignCast(ctx));
        if (self.lease.isSameAllocator(self.base)) {
            if (new_len > bytes.len and !self.mayProbe(new_len - bytes.len)) return false;
            const success = self.base.rawResize(bytes, alignment, new_len, ra);
            if (!success and self.backingLimitHit()) self.failure = error.WorkingMemoryLimitExceeded;
            return success;
        }
        if (new_len <= bytes.len) {
            if (!self.base.rawResize(bytes, alignment, new_len, ra)) return false;
            self.lease.releaseExisting(bytes.len - new_len);
            self.live -= bytes.len - new_len;
            return true;
        }
        if (!self.mayProbe(new_len - bytes.len)) return false;
        var ticket = self.reserve(new_len - bytes.len) orelse return false;
        if (!self.base.rawResize(bytes, alignment, new_len, ra)) {
            ticket.deinit();
            // false also means unsupported in-place growth. Only a known
            // backing quota refusal is sticky before the normal alloc fallback.
            if (self.backingLimitHit()) self.failure = error.WorkingMemoryLimitExceeded;
            return false;
        }
        self.allocated(&ticket);
        return true;
    }
    fn remap(ctx: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, new_len: usize, ra: usize) ?[*]u8 {
        const self: *Physical = @ptrCast(@alignCast(ctx));
        if (self.lease.isSameAllocator(self.base)) {
            if (new_len > bytes.len and !self.mayProbe(new_len - bytes.len)) return null;
            const updated = self.base.rawRemap(bytes, alignment, new_len, ra);
            if (updated == null and self.backingLimitHit()) self.failure = error.WorkingMemoryLimitExceeded;
            return updated;
        }
        if (new_len <= bytes.len) {
            const updated = self.base.rawRemap(bytes, alignment, new_len, ra) orelse return null;
            self.lease.releaseExisting(bytes.len - new_len);
            self.live -= bytes.len - new_len;
            return updated;
        }
        if (!self.mayProbe(new_len - bytes.len)) return null;
        var ticket = self.reserve(new_len - bytes.len) orelse return null;
        const updated = self.base.rawRemap(bytes, alignment, new_len, ra) orelse {
            ticket.deinit();
            if (self.backingLimitHit()) self.failure = error.WorkingMemoryLimitExceeded;
            return null;
        };
        self.allocated(&ticket);
        return updated;
    }
    fn free(ctx: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, ra: usize) void {
        const self: *Physical = @ptrCast(@alignCast(ctx));
        self.base.rawFree(bytes, alignment, ra);
        if (self.lease.isSameAllocator(self.base)) return;
        self.lease.releaseExisting(bytes.len);
        self.live -= bytes.len;
    }
};
