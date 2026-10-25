//! One direct-mapped memo for exact literal tree bit costs. All 256 frequency
//! values must be initialized, and callers retain one fixed parent support
//! throughout the cache lifetime. No input, allocator or tree plan is retained.
const std = @import("std");

pub const capacity: usize = 128;
const word_count: usize = (capacity + 63) / 64;
comptime {
    std.debug.assert(std.math.isPowerOfTwo(capacity));
}
const Entry = struct {
    hash: u64,
    histogram: [256]u32,
    bit_cost: u64,
};
const Origin = struct { scope: u2, mode: ?u2 };

pub const Cache = struct {
    entries: [capacity]Entry = undefined,
    occupied: [word_count]u64 = @splat(0),
    hits: usize = 0,
    misses: usize = 0,
    cold_misses: usize = 0,
    conflict_misses: usize = 0,
    // Written/read only by profiled score requests, after successful put.
    origins: [capacity]Origin = undefined,

    pub fn get(self: *Cache, comptime classify_misses: bool, histogram: *const [256]u32) ?u64 {
        const hash = histogramHash(histogram);
        const slot = slotForHash(hash);
        const word = slot >> 6;
        const bit: u6 = @truncate(slot);
        const mask = @as(u64, 1) << bit;
        if (self.occupied[word] & mask != 0) {
            const entry = &self.entries[slot];
            if (entry.hash == hash and std.mem.eql(u32, &entry.histogram, histogram)) {
                self.hits += 1;
                return entry.bit_cost;
            }
            if (classify_misses) self.conflict_misses += 1;
        } else if (classify_misses) self.cold_misses += 1;
        self.misses += 1;
        return null;
    }

    /// Publish only a completed successful score. The caller invokes the
    /// unchanged scorer on a miss; errors never reach this publication point.
    pub fn put(self: *Cache, histogram: *const [256]u32, bit_cost: u64) void {
        const hash = histogramHash(histogram);
        const slot = slotForHash(hash);
        const word = slot >> 6;
        const bit: u6 = @truncate(slot);
        self.entries[slot] = .{ .hash = hash, .histogram = histogram.*, .bit_cost = bit_cost };
        self.occupied[word] |= @as(u64, 1) << bit;
    }

    pub fn setOrigin(self: *Cache, histogram: *const [256]u32, scope: u2, mode: ?u2) void {
        self.origins[slotForHash(histogramHash(histogram))] = .{ .scope = scope, .mode = mode };
    }

    /// Only valid after get returned a hit from a profiled publication.
    pub fn origin(self: *const Cache, histogram: *const [256]u32) Origin {
        return self.origins[slotForHash(histogramHash(histogram))];
    }
};

fn slotForHash(hash: u64) usize {
    return @intCast(hash & (capacity - 1));
}

pub fn histogramHash(histogram: *const [256]u32) u64 {
    var hash: u64 = 0xcbf2_9ce4_8422_2325;
    for (histogram) |frequency| hash = (hash ^ @as(u64, frequency)) *% 0x0000_0100_0000_01b3;
    return hash;
}
