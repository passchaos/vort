//! Set-associative memo for exact literal tree bit costs. All 256 frequency
//! values must be initialized, and callers retain one fixed parent support
//! throughout the cache lifetime: a tree score is a pure function of its
//! frequency vector, so the same cache may be shared across RFC modes. No
//! input, allocator or tree plan is retained.
const std = @import("std");

pub const capacity: usize = 128;
pub const ways: usize = 4;
pub const set_count: usize = capacity / ways;
comptime {
    std.debug.assert(std.math.isPowerOfTwo(capacity));
    std.debug.assert(std.math.isPowerOfTwo(set_count));
    std.debug.assert(set_count * ways == capacity);
}

pub const Hit = struct {
    bit_cost: u64,
    owner_mode: u8,
};

const Entry = struct {
    hash: u64 = 0,
    histogram: [256]u32 = [_]u32{0} ** 256,
    bit_cost: u64 = 0,
    owner_mode: u8 = 0,
    valid: bool = false,
    tick: u32 = 0,
};

pub const Cache = struct {
    sets: [set_count][ways]Entry = [_][ways]Entry{[_]Entry{.{}} ** ways} ** set_count,
    hits: usize = 0,
    misses: usize = 0,
    cold_misses: usize = 0,
    conflict_misses: usize = 0,
    tick: u32 = 0,

    /// Returns the owner recorded by the publishing score so callers can
    /// classify cross-mode memo reuse. A hit requires the complete vector.
    pub fn get(self: *Cache, comptime classify_misses: bool, histogram: *const [256]u32) ?Hit {
        const hash = histogramHash(histogram);
        const set = &self.sets[setForHash(hash)];
        var has_invalid_way = false;
        for (set) |*entry| {
            if (!entry.valid) {
                has_invalid_way = true;
                continue;
            }
            if (entry.hash == hash and std.mem.eql(u32, &entry.histogram, histogram)) {
                self.hits += 1;
                self.tick +%= 1;
                entry.tick = self.tick;
                return .{ .bit_cost = entry.bit_cost, .owner_mode = entry.owner_mode };
            }
        }
        if (classify_misses) {
            if (has_invalid_way) self.cold_misses += 1 else self.conflict_misses += 1;
        }
        self.misses += 1;
        return null;
    }

    /// Publish only a completed successful score. The caller invokes the
    /// unchanged scorer on a miss; errors never reach this publication point.
    pub fn put(self: *Cache, histogram: *const [256]u32, bit_cost: u64, owner_mode: u8) void {
        const hash = histogramHash(histogram);
        const set = &self.sets[setForHash(hash)];
        var victim: *Entry = &set[0];
        for (set) |*entry| {
            if (!entry.valid) {
                victim = entry;
                break;
            }
            if (entry.hash == hash and std.mem.eql(u32, &entry.histogram, histogram)) {
                victim = entry;
                break;
            }
            // Recency only orders occupied ways; invalid slots are preferred.
            if (victim.valid and entry.tick < victim.tick) victim = entry;
        }
        self.tick +%= 1;
        victim.* = .{
            .hash = hash,
            .histogram = histogram.*,
            .bit_cost = bit_cost,
            .owner_mode = owner_mode,
            .valid = true,
            .tick = self.tick,
        };
    }
};

fn setForHash(hash: u64) usize {
    return @intCast(hash & (set_count - 1));
}

pub fn histogramHash(histogram: *const [256]u32) u64 {
    var hash: u64 = 0xcbf2_9ce4_8422_2325;
    for (histogram) |frequency| hash = (hash ^ @as(u64, frequency)) *% 0x0000_0100_0000_01b3;
    return hash;
}
