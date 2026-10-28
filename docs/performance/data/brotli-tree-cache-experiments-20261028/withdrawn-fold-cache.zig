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
        return self.getHashed(classify_misses, histogram, histogramHash(histogram));
    }

    /// Lookup and publication may share the hash when scoring leaves the
    /// histogram unchanged. Hash equality still requires full-vector equality.
    pub fn getHashed(self: *Cache, comptime classify_misses: bool, histogram: *const [256]u32, hash: u64) ?Hit {
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
        self.putHashed(histogram, histogramHash(histogram), bit_cost, owner_mode);
    }

    /// Use the hash obtained before a pure score computation, avoiding another
    /// 256-frequency scan. Callers must retain the same histogram until publish.
    pub fn putHashed(self: *Cache, histogram: *const [256]u32, hash: u64, bit_cost: u64, owner_mode: u8) void {
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
    // FNV's low bits only see low frequency bits. Fixed-total histograms with
    // frequencies divisible by 32 otherwise concentrate in one cache set.
    // Fold the complete fingerprint before indexing; matching still checks the
    // original 64-bit fingerprint and every frequency value.
    const folded = hash ^ (hash >> 16) ^ (hash >> 32) ^ (hash >> 48);
    return @intCast(folded & (set_count - 1));
}

pub fn histogramHash(histogram: *const [256]u32) u64 {
    var hash: u64 = 0xcbf2_9ce4_8422_2325;
    for (histogram) |frequency| hash = (hash ^ @as(u64, frequency)) *% 0x0000_0100_0000_01b3;
    return hash;
}

test "literal context reused hash preserves cache publication and replacement" {
    const legacy = try std.testing.allocator.create(Cache);
    defer std.testing.allocator.destroy(legacy);
    const reused = try std.testing.allocator.create(Cache);
    defer std.testing.allocator.destroy(reused);
    legacy.* = .{};
    reused.* = .{};
    var pool: [16][256]u32 = @splat(@splat(0));
    for (&pool, 0..) |*histogram, index| {
        histogram[17] = @intCast(index + 1);
        // Force set conflicts while keeping the complete vectors distinct.
        while (setForHash(histogramHash(histogram)) != 7) histogram[0] += 1;
    }
    var state: u32 = 0x243f_6a88;
    for (0..1024) |request| {
        state = state *% 1664525 +% 1013904223;
        const index = if (request % 3 == 0) 0 else state >> 28;
        const histogram = &pool[index];
        const hash = histogramHash(histogram);
        const expected = legacy.get(true, histogram);
        const actual = reused.getHashed(true, histogram, hash);
        try std.testing.expectEqualDeep(expected, actual);
        if (expected == null) {
            const cost = 100 + @as(u64, index);
            const mode: u8 = @intCast(request % 4);
            legacy.put(histogram, cost, mode);
            reused.putHashed(histogram, hash, cost, mode);
        }
    }
    try std.testing.expectEqualDeep(legacy.*, reused.*);
    try std.testing.expect(reused.hits > 0 and reused.conflict_misses > 0);
}

test "literal context supplied hash collisions still require full vectors" {
    const cache = try std.testing.allocator.create(Cache);
    defer std.testing.allocator.destroy(cache);
    cache.* = .{};
    var first: [256]u32 = @splat(0);
    first[2] = 128;
    var second = first;
    second[255] = 1;
    const collision_hash: u64 = 0x17;
    cache.putHashed(&first, collision_hash, 200, 0);
    try std.testing.expectEqual(@as(?Hit, null), cache.getHashed(true, &second, collision_hash));
    cache.putHashed(&second, collision_hash, 300, 1);
    try std.testing.expectEqual(@as(u64, 200), cache.getHashed(false, &first, collision_hash).?.bit_cost);
    try std.testing.expectEqual(@as(u64, 300), cache.getHashed(false, &second, collision_hash).?.bit_cost);
}

test "literal context set selection uses every 16 bit fingerprint word" {
    try std.testing.expectEqual(@as(usize, 0), setForHash(0));
    inline for (.{ 0, 16, 32, 48 }) |shift| {
        const hash = @as(u64, 21) << shift;
        try std.testing.expectEqual(@as(usize, 21), setForHash(hash));
    }
    try std.testing.expectEqual(@as(usize, 0), setForHash(0x0015_0015_0015_0015));
    try std.testing.expectEqual(@as(usize, 2), setForHash(0x0000_0000_0001_0003));
}

test "literal context fixed total wide frequencies use the full cache" {
    const cache = try std.testing.allocator.create(Cache);
    defer std.testing.allocator.destroy(cache);
    cache.* = .{};
    var histograms: [64][256]u32 = @splat(@splat(0));
    var populated: [set_count]bool = @splat(false);
    var legacy_set: ?usize = null;
    for (&histograms, 0..) |*histogram, index| {
        histogram[17] = @intCast((index + 1) * 32);
        histogram[193] = 4096 - histogram[17];
        const hash = histogramHash(histogram);
        const low: usize = @intCast(hash & (set_count - 1));
        if (legacy_set) |expected| try std.testing.expectEqual(expected, low) else legacy_set = low;
        populated[setForHash(hash)] = true;
    }
    var distinct: usize = 0;
    for (populated) |used| distinct += @intFromBool(used);
    try std.testing.expect(distinct > set_count / 2);
    // The independent four-slot baseline cycles all keys through their one
    // low-bit set. A sequential sweep cannot hit once the first four are gone.
    var old_slots: [ways]?usize = @splat(null);
    var old_ticks: [ways]usize = @splat(0);
    var old_tick: usize = 0;
    var old_hits: usize = 0;
    for (0..5) |round| {
        for (&histograms, 0..) |*histogram, index| {
            var found: ?usize = null;
            for (old_slots, 0..) |slot, way| if (slot == index) {
                found = way;
                break;
            };
            old_tick += 1;
            if (found) |way| {
                old_hits += 1;
                old_ticks[way] = old_tick;
            } else {
                var victim: usize = 0;
                for (old_slots, 0..) |slot, way| {
                    if (slot == null) {
                        victim = way;
                        break;
                    }
                    if (old_ticks[way] < old_ticks[victim]) victim = way;
                }
                old_slots[victim] = index;
                old_ticks[victim] = old_tick;
            }
            const expected_cost = @as(u64, histogram[17]) * 3 + @as(u64, histogram[193]) * 11;
            if (cache.get(true, histogram)) |hit| {
                try std.testing.expectEqual(expected_cost, hit.bit_cost);
            } else cache.put(histogram, expected_cost, @intCast(round % 4));
        }
    }
    try std.testing.expectEqual(@as(usize, 0), old_hits);
    try std.testing.expect(cache.hits >= 200);
    try std.testing.expectEqual(cache.misses, cache.cold_misses + cache.conflict_misses);
}
