const std = @import("std");
const State = @import("state.zig").State;

/// Shared quota reservation for a separately owned physical allocator. No heap
/// is allocated for this token and failed physical allocation never raises peak.
pub const ExternalReservation = struct {
    state: ?*State,
    bytes: usize,
    allocated: bool = false,
    active: bool = true,

    pub fn init(state: ?*State, bytes: usize) error{ IntegerOverflow, WorkingMemoryLimitExceeded }!ExternalReservation {
        if (state) |s| {
            s.enter();
            defer s.leave();
            const occupied = std.math.add(usize, s.live, s.reserved) catch return error.IntegerOverflow;
            _ = std.math.add(usize, occupied, bytes) catch return error.IntegerOverflow;
            const refs = std.math.add(usize, s.references, 1) catch return error.IntegerOverflow;
            if (!s.allowedLocked(bytes)) return error.WorkingMemoryLimitExceeded;
            s.reserved += bytes;
            s.references = refs;
        }
        return .{ .state = state, .bytes = bytes };
    }
    pub fn markAllocated(self: *ExternalReservation) void {
        std.debug.assert(self.active and !self.allocated);
        if (self.state) |s| {
            s.enter();
            std.debug.assert(s.reserved >= self.bytes);
            s.reserved -= self.bytes;
            s.replaceLocked(0, self.bytes);
            s.leave();
        }
        self.allocated = true;
    }
    pub fn handoff(self: *ExternalReservation) void {
        std.debug.assert(self.allocated);
        self.deinit();
    }
    pub fn deinit(self: *ExternalReservation) void {
        if (!self.active) return;
        if (self.state) |s| {
            s.enter();
            if (self.allocated) s.replaceLocked(self.bytes, 0) else {
                std.debug.assert(s.reserved >= self.bytes);
                s.reserved -= self.bytes;
            }
            s.leave();
            s.releaseReference();
        }
        self.active = false;
    }
};
