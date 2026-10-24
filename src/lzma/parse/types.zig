const std = @import("std");

pub const window_len: usize = 4096;
pub const guard_len: usize = 273;
pub const beam_width: usize = 8;

/// distance zero represents one literal. A one-byte nonzero distance is only
/// legal for current rep0, and uses LZMA's dedicated short-repeat symbol.
pub const Decision = struct { length: u16 = 1, distance: u32 = 0 };
pub const Token = union(enum) {
    literal: u8,
    match: struct { length: u16, distance: u32 },
};
pub const State = struct {
    state: u8 = 0,
    reps: [4]u32 = @splat(0),

    pub fn fromModel(model: anytype) State {
        var reps: [4]u32 = undefined;
        for (model.reps, &reps) |rep, *target| target.* = @intCast(rep);
        return .{ .state = @intCast(model.state), .reps = reps };
    }
    pub fn repIndex(self: State, distance: u32) ?usize {
        if (distance == 0) return null;
        for (self.reps, 0..) |rep, index| if (rep == distance - 1) return index;
        return null;
    }
    pub fn after(self: State, decision: Decision) State {
        var next = self;
        if (decision.distance == 0) {
            next.state = if (self.state < 4) 0 else if (self.state < 10) self.state - 3 else self.state - 6;
        } else if (decision.length == 1) {
            std.debug.assert(decision.distance == self.reps[0] + 1);
            next.state = if (self.state < 7) 9 else 11;
        } else if (self.repIndex(decision.distance)) |index| {
            const selected = next.reps[index];
            var i = index;
            while (i != 0) : (i -= 1) next.reps[i] = next.reps[i - 1];
            next.reps[0] = selected;
            next.state = if (self.state < 7) 8 else 11;
        } else {
            next.reps = .{ decision.distance - 1, self.reps[0], self.reps[1], self.reps[2] };
            next.state = if (self.state < 7) 7 else 10;
        }
        return next;
    }
};

pub const Plan = struct {
    tokens: []Token,
    consumed: usize,
    final_state: State,

    pub fn deinit(self: Plan, allocator: std.mem.Allocator) void {
        allocator.free(self.tokens);
    }
};
