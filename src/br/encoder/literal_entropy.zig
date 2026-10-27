//! Weighted Shannon lower bounds and bounded frequency memoization.
//! Exact Huffman tree scores and replacement policy live separately.
const std = @import("std");

/// Conservative per-tree margin (in bits) between the floating-point Shannon
/// estimate and the true entropy. For a matching u32 total and at most 256
/// symbols, each term is below 2^37. With a few-ulp log2 implementation, strict
/// f64 arithmetic keeps accumulated error far below this one-bit margin.
pub const entropy_margin_bits: f64 = 1.0;

/// Memo of `frequency * log2(frequency)`: one logarithm per distinct
/// frequency keeps each entropy query to table lookups and f64 adds. Typical
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

/// Shannon payload floor from a pre-summed `sum frequency*log2(frequency)`,
/// rounded strictly down after the fixed margin. Huffman's weighted code cost
/// is at least the entropy, so this bounds the exact weighted payload without
/// its header.
/// `weight_sum` must be finite and equal to the sum over a histogram whose
/// counts add to `total`. The u32 total bounds the conversion below by 2^37.
pub fn shannonFromWeightSum(total: u32, weight_sum: f64) u64 {
    @setFloatMode(.strict);
    if (total <= 1) return 0;
    std.debug.assert(std.math.isFinite(weight_sum) and weight_sum >= 0);
    var entropy = @as(f64, @floatFromInt(total)) *
        std.math.log2(@as(f64, @floatFromInt(total))) - weight_sum;
    entropy -= entropy_margin_bits;
    if (!(entropy > 0)) return 0;
    return @intFromFloat(entropy);
}

/// Weighted Shannon entropy over a complete histogram; the weighted-frequency
/// table makes the per-symbol cost one table lookup plus f64 add.
pub fn shannonPayloadLowerBound(histogram: *const [256]u32, total: u32, weights: *WeightTable) u64 {
    @setFloatMode(.strict);
    var weight_sum: f64 = 0;
    for (histogram) |frequency| {
        if (frequency == 0) continue;
        weight_sum += weights.logWeight(frequency);
    }
    return shannonFromWeightSum(total, weight_sum);
}

test "literal context entropy backends agree through large count boundaries" {
    var dense = try WeightTable.init(std.testing.allocator, WeightTable.dense_capacity);
    defer dense.deinit(std.testing.allocator);
    var sparse = try WeightTable.init(std.testing.allocator, WeightTable.dense_capacity + 1);
    defer sparse.deinit(std.testing.allocator);
    for (0..8192) |i| {
        const frequency: u32 = @intCast(i * 16 + 1);
        const expected = @as(f64, @floatFromInt(frequency)) * std.math.log2(@as(f64, @floatFromInt(frequency)));
        try std.testing.expectEqual(expected, dense.logWeight(frequency));
        try std.testing.expectEqual(expected, sparse.logWeight(frequency));
        try std.testing.expectEqual(expected, sparse.logWeight(frequency));
    }
    for ([_]u32{ 0, 1, 1 << 17, (1 << 17) + 1, 1 << 24, std.math.maxInt(u32) }) |total| {
        var histogram: [256]u32 = @splat(0);
        histogram[251] = total;
        // A singleton consumes no payload bits, even near the u32 limit.
        try std.testing.expectEqual(@as(u64, 0), shannonPayloadLowerBound(&histogram, total, &sparse));
    }
    for ([_]u32{ 1, 1 << 16, 1 << 24 }) |frequency| {
        var histogram: [256]u32 = @splat(0);
        histogram[3] = frequency;
        histogram[241] = frequency;
        // Two equally weighted codes consume exactly one bit per literal.
        try std.testing.expectEqual(@as(u64, frequency) * 2 - 1, shannonPayloadLowerBound(&histogram, frequency * 2, &sparse));
    }
}
