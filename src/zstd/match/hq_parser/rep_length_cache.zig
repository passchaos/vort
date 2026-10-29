//! Per-position repeat-distance match lengths shared across beam states.
const std = @import("std");

pub const capacity: usize = 64;
const mask = capacity - 1;

const Entry = struct {
    generation: u32 = 0,
    distance: u32 = 0,
    length: u32 = 0,
};

pub const Lookup = struct {
    slot: u6,
    length: ?u32,
};

pub const Cache = struct {
    entries: [capacity]Entry = @splat(.{}),
    generation: u32 = 0,

    pub fn beginPosition(self: *Cache) void {
        self.generation +%= 1;
        if (self.generation == 0) {
            @memset(&self.entries, .{});
            self.generation = 1;
        }
    }

    pub fn lookup(self: *const Cache, distance: u32) Lookup {
        std.debug.assert(self.generation != 0 and distance != 0);
        var slot = @as(usize, distance *% 0x9e37_79b1) & mask;
        for (0..capacity) |_| {
            const entry = self.entries[slot];
            if (entry.generation != self.generation)
                return .{ .slot = @intCast(slot), .length = null };
            if (entry.distance == distance)
                return .{ .slot = @intCast(slot), .length = entry.length };
            slot = (slot + 1) & mask;
        }
        unreachable;
    }

    pub fn store(self: *Cache, probe: Lookup, distance: u32, length: usize) void {
        std.debug.assert(probe.length == null and length <= std.math.maxInt(u32));
        self.entries[probe.slot] = .{
            .generation = self.generation,
            .distance = distance,
            .length = @intCast(length),
        };
    }
};

test "Zstd HQ repeat length cache preserves collision and generation contracts" {
    try @import("rep_length_cache_tests.zig").contracts(@This());
}
