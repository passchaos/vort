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

/// Conservative per-tree margin (in bits) between the floating-point Shannon
/// estimate and the true entropy. Each term is below 2^37 and f64 error is a
/// few ulps; over at most 256 live symbols the accumulated error is far below
/// 0.1 bit, so one full bit is a strict, platform-independent safety gap.
pub const entropy_margin_bits: f64 = 1.0;

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

/// Memo of `frequency * log2(frequency)`: one logarithm per distinct
/// frequency keeps each entropy query to a pass of f64 multiplies. Typical
/// blocks use a direct indexed table; blocks above `dense_capacity` fall back
/// to fixed-capacity open addressing so memory stays bounded at the 2^24
/// meta-block limit, where collisions simply recompute.
pub const WeightTable = struct {
    pub const dense_capacity: u32 = 1 << 17;
    const slot_count: usize = 4096;
    const mask: usize = slot_count - 1;
    const max_probe: usize = 8;

    dense: ?[]f64 = null,
    keys: [slot_count]u32 = [_]u32{0} ** slot_count,
    values: [slot_count]f64 = [_]f64{0} ** slot_count,

    pub fn init(allocator: std.mem.Allocator, max_frequency: u32) !WeightTable {
        if (max_frequency <= dense_capacity) {
            const weights = try allocator.alloc(f64, @as(usize, max_frequency) + 1);
            @memset(weights, std.math.nan(f64));
            weights[0] = 0;
            return .{ .dense = weights };
        }
        return .{};
    }

    pub fn deinit(self: *WeightTable, allocator: std.mem.Allocator) void {
        if (self.dense) |weights| allocator.free(weights);
    }

    fn slotFor(frequency: u32) usize {
        var hash: u64 = 0xcbf2_9ce4_8422_2325;
        hash = (hash ^ @as(u64, frequency)) *% 0x0000_0100_0000_01b3;
        return @intCast(hash & mask);
    }

    pub fn logWeight(self: *WeightTable, frequency: u32) f64 {
        if (self.dense) |weights| {
            const cached = weights[frequency];
            if (!std.math.isNan(cached)) return cached;
            const weight = @as(f64, @floatFromInt(frequency)) *
                std.math.log2(@as(f64, @floatFromInt(frequency)));
            weights[frequency] = weight;
            return weight;
        }
        var slot = slotFor(frequency);
        var probe: usize = 0;
        while (probe < max_probe) : (probe += 1) {
            if (self.keys[slot] == frequency) return self.values[slot];
            slot = (slot + 1) & mask;
        }
        const weight = @as(f64, @floatFromInt(frequency)) *
            std.math.log2(@as(f64, @floatFromInt(frequency)));
        // Frequencies are positive, so key zero is reserved as empty; publish
        // at the first empty slot encountered during the probe.
        slot = slotFor(frequency);
        probe = 0;
        while (probe < max_probe) : (probe += 1) {
            if (self.keys[slot] == 0) {
                self.keys[slot] = frequency;
                self.values[slot] = weight;
                break;
            }
            slot = (slot + 1) & mask;
        }
        return weight;
    }
};

/// Weighted Shannon entropy in bits, rounded strictly down after subtracting
/// the fixed margin. Huffman's weighted code cost is at least the entropy, so
/// this is a lower bound on the exact weighted payload without its header. The
/// weighted-frequency table makes the per-symbol cost one f64 multiply.
pub fn shannonPayloadLowerBound(histogram: *const [256]u32, total: u32, weights: *WeightTable) u64 {
    var entropy = @as(f64, @floatFromInt(total)) * std.math.log2(@as(f64, @floatFromInt(total)));
    for (histogram) |frequency| {
        if (frequency == 0) continue;
        entropy -= weights.logWeight(frequency);
    }
    if (entropy <= entropy_margin_bits) return 0;
    const bounded = @min(entropy - entropy_margin_bits, @as(f64, @floatFromInt(std.math.maxInt(u64))));
    return @intFromFloat(bounded);
}

/// Set-associative memo for Shannon lower bounds. The same histograms recur
/// across suffix cutoffs, cluster trials and RFC modes; the bound is a pure
/// function of the frequency vector.
pub const EntropyCache = struct {
    sets: [set_count][ways]EntropyEntry = [_][ways]EntropyEntry{[_]EntropyEntry{.{}} ** ways} ** set_count,
    tick: u32 = 0,

    pub fn get(self: *EntropyCache, histogram: *const [256]u32) ?u64 {
        const hash = histogramHash(histogram);
        const set = &self.sets[setForHash(hash)];
        for (set) |*entry| {
            if (entry.valid and entry.hash == hash and
                std.mem.eql(u32, &entry.histogram, histogram))
            {
                self.tick +%= 1;
                entry.tick = self.tick;
                return entry.bits;
            }
        }
        return null;
    }

    pub fn put(self: *EntropyCache, histogram: *const [256]u32, total: u32, bits: u64) void {
        const hash = histogramHash(histogram);
        const set = &self.sets[setForHash(hash)];
        var victim: *EntropyEntry = &set[0];
        for (set) |*entry| {
            if (!entry.valid) {
                victim = entry;
                break;
            }
            if (entry.hash == hash and std.mem.eql(u32, &entry.histogram, histogram)) {
                victim = entry;
                break;
            }
            if (victim.valid and entry.tick < victim.tick) victim = entry;
        }
        self.tick +%= 1;
        victim.* = .{
            .hash = hash,
            .histogram = histogram.*,
            .total = total,
            .bits = bits,
            .valid = true,
            .tick = self.tick,
        };
    }

    /// Score through the memo on demand.
    pub fn bound(self: *EntropyCache, histogram: *const [256]u32, total: u32, weights: *WeightTable) u64 {
        if (self.get(histogram)) |bits| return bits;
        const bits = shannonPayloadLowerBound(histogram, total, weights);
        self.put(histogram, total, bits);
        return bits;
    }
};

const EntropyEntry = struct {
    hash: u64 = 0,
    histogram: [256]u32 = [_]u32{0} ** 256,
    total: u32 = 0,
    bits: u64 = 0,
    valid: bool = false,
    tick: u32 = 0,
};

pub fn histogramHash(histogram: *const [256]u32) u64 {
    var hash: u64 = 0xcbf2_9ce4_8422_2325;
    for (histogram) |frequency| hash = (hash ^ @as(u64, frequency)) *% 0x0000_0100_0000_01b3;
    return hash;
}
