//! Conservative suffix payload floors, computed together over parent support.
const std = @import("std");
const literal_entropy = @import("literal_entropy.zig");
const WeightTable = literal_entropy.WeightTable;

/// floor(log2(total / frequency)) using only bit scans: with a = floor(log2
/// total) and b = floor(log2 frequency), the result is a-b-1 plus a carry when
/// frequency * 2^(a-b) <= total.
inline fn floorLog2Ratio(total: u32, frequency: u32) u5 {
    std.debug.assert(frequency != 0 and frequency <= total);
    const diff: u5 = @intCast(std.math.log2_int(u32, total) - std.math.log2_int(u32, frequency));
    const shifted_le_total = (@as(u64, frequency) << @intCast(diff)) <= @as(u64, total);
    const carry: u5 = @intFromBool(shifted_le_total);
    return diff -% 1 +% carry;
}

/// Minimal declared-prefix overhead for a tree with `symbol_count` live codes.
/// It is exact for the <=4-symbol simple prefix and a 2-bit lower bound for the
/// complex prefix's HSKIP marker.
fn treeHeaderLowerBound(symbol_count: usize) u64 {
    if (symbol_count <= 4)
        return 4 + @as(u64, symbol_count) * 8 + @intFromBool(symbol_count == 4);
    return 2;
}

pub const SuffixPayloadBounds = struct {
    /// Per-symbol floor(log2) bound: bit scans only, no floating point.
    integer: u64,
    /// Tighter weighted-Shannon bound with the per-tree safety margin.
    entropy: u64,
};

/// Both lower bounds for the two cumulative-suffix trees at one cutoff, in a
/// single pass over the shared support. The f64 Shannon terms reuse the same
/// per-symbol loop as the integer floor terms, avoiding a second 256-entry
/// scan on every evaluated cutoff.
pub fn suffixPayloadBounds(
    active_symbols: []const u8,
    total: *const [256]u32,
    left: *const [256]u32,
    left_total: usize,
    right_total: usize,
    entropy_weights: *WeightTable,
) SuffixPayloadBounds {
    @setFloatMode(.strict);
    var left_bits: u64 = 0;
    var right_bits: u64 = 0;
    var left_symbols: usize = 0;
    var right_symbols: usize = 0;
    var left_weight: f64 = 0;
    var right_weight: f64 = 0;
    for (active_symbols) |symbol| {
        const left_frequency = left[symbol];
        if (left_frequency != 0) {
            left_symbols += 1;
            left_bits += @as(u64, left_frequency) *
                @as(u64, floorLog2Ratio(@intCast(left_total), left_frequency));
            left_weight += entropy_weights.logWeight(left_frequency);
        }
        const right_frequency = total[symbol] - left_frequency;
        if (right_frequency != 0) {
            right_symbols += 1;
            right_bits += @as(u64, right_frequency) *
                @as(u64, floorLog2Ratio(@intCast(right_total), right_frequency));
            right_weight += entropy_weights.logWeight(right_frequency);
        }
    }
    const left_header = treeHeaderLowerBound(left_symbols);
    const right_header = treeHeaderLowerBound(right_symbols);
    return .{
        .integer = left_bits + left_header + right_bits + right_header,
        .entropy = literal_entropy.shannonFromWeightSum(@intCast(left_total), left_weight) + left_header +
            literal_entropy.shannonFromWeightSum(@intCast(right_total), right_weight) + right_header,
    };
}
