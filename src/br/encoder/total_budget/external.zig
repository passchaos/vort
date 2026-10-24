const std = @import("std");
const State = @import("state.zig").State;

/// A no-allocation reservation in the same total ledger for an allocation
/// physically owned by another allocator. The token retains stable state.
/// Reserve before allocation, mark only after allocation succeeds, then release
/// after physical free or transfer to the caller. Reservations are not peak heap.
pub const ExternalReservation = struct {
    state: ?*State = null,
    bytes: usize,
    allocated: bool = false,
    active: bool = true,

    pub fn init(state: ?*State, bytes: usize) error{ IntegerOverflow, WorkingMemoryLimitExceeded }!ExternalReservation {
        if (state) |s| {
            const occupied = std.math.add(usize, s.live, s.reserved) catch return error.IntegerOverflow;
            _ = std.math.add(usize, occupied, bytes) catch return error.IntegerOverflow;
            const refs = std.math.add(usize, s.references, 1) catch return error.IntegerOverflow;
            if (!s.allow(bytes)) return error.WorkingMemoryLimitExceeded;
            s.reserved += bytes;
            s.references = refs;
        }
        return .{ .state = state, .bytes = bytes };
    }
    pub fn markAllocated(self: *ExternalReservation) void {
        std.debug.assert(self.active and !self.allocated);
        if (self.state) |state| {
            std.debug.assert(state.reserved >= self.bytes);
            state.reserved -= self.bytes;
            state.changed(0, self.bytes);
        }
        self.allocated = true;
    }
    pub fn handoff(self: *ExternalReservation) void {
        std.debug.assert(self.allocated);
        self.deinit();
    }
    pub fn deinit(self: *ExternalReservation) void {
        if (!self.active) return;
        if (self.state) |state| {
            if (self.allocated) {
                state.changed(self.bytes, 0);
            } else {
                std.debug.assert(state.reserved >= self.bytes);
                state.reserved -= self.bytes;
            }
            std.debug.assert(state.references != 0);
            state.references -= 1;
            state.disposeIfUnused();
        }
        self.active = false;
    }
};
