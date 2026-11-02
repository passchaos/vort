//! Strict entropy-candidate arbitration with an explicitly borrowed baseline.
const std = @import("std");
const profile = @import("quality_profile.zig");

pub fn Owner(comptime Stats: type) type {
    return struct {
        const Self = @This();
        pub const Selected = struct { wire: []u8, stats: Stats };
        baseline: []const u8,
        owned: ?[]u8 = null,
        stats: Stats,

        pub fn init(baseline: []const u8, stats: Stats) Self {
            return .{ .baseline = baseline, .stats = stats };
        }

        pub fn current(self: *const Self) []const u8 {
            return self.owned orelse self.baseline;
        }

        /// Consumes the candidate regardless of outcome; the borrowed baseline
        /// is never released. Equality keeps the earliest retained candidate.
        pub fn consider(self: *Self, comptime traced: bool, trace: profile.Recorder(traced), allocator: std.mem.Allocator, candidate: []u8, stats: Stats, comptime release: anytype) void {
            if (trace.prefer(candidate, self.current())) {
                if (self.owned) |wire| release(traced, trace, allocator, wire);
                self.owned = candidate;
                self.stats = stats;
            } else release(traced, trace, allocator, candidate);
        }

        pub fn deinit(self: *Self, comptime traced: bool, trace: profile.Recorder(traced), allocator: std.mem.Allocator, comptime release: anytype) void {
            if (self.owned) |wire| release(traced, trace, allocator, wire);
            self.owned = null;
        }

        pub fn take(self: *Self) ?Selected {
            const wire = self.owned orelse return null;
            self.owned = null;
            return .{ .wire = wire, .stats = self.stats };
        }
    };
}

test "entropy wire selection borrowed baseline and owned winner contracts" {
    try @import("entropy_wire_selection_tests.zig").check(@This());
}
