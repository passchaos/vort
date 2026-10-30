//! Select the DP sources which need independent match materialization.
const std = @import("std");
const prices = @import("prices.zig");

const max_sources = @bitSizeOf(u16);

/// Return one bit for every row slot which must materialize match edges.
///
/// Positive-literal nodes with the same repeat history have identical offset
/// choices. Only their accumulated cost plus the LL field can distinguish all
/// of their future match edges, so the lowest-ranked source is sufficient.
/// Zero-literal nodes retain distinct repeat-selector semantics. Invalid ranks
/// conservatively disable dominance for their entire repeat-history group.
pub fn materializeMask(
    row: anytype,
    ll_prices: *const [prices.ll_symbol_count]u32,
) u16 {
    if (row.len == 0) return 0;
    var valid_len: usize = 0;
    while (valid_len < row.len and row[valid_len].cost != std.math.maxInt(u64))
        valid_len += 1;
    if (valid_len == 0) return 0;
    // HQ rows have at most sixteen sources. Preserve every representable bit
    // for an invalid wider caller without performing an out-of-range shift.
    if (valid_len > max_sources) return std.math.maxInt(u16);
    const nodes = row[0..valid_len];

    const empty_group = std.math.maxInt(u8);
    var table: [max_sources]u8 = @splat(empty_group);
    var representatives: [max_sources]u8 = undefined;
    var masks: [max_sources]u16 = @splat(0);
    var best_slots: [max_sources]u8 = undefined;
    var best_ranks: [max_sources]u64 = undefined;
    var ranks_valid: [max_sources]bool = @splat(true);
    var group_count: usize = 0;
    var result: u16 = 0;
    for (nodes, 0..) |node, slot| {
        const source_bit = bit(slot);
        if (node.literal_len == 0) {
            result |= source_bit;
            continue;
        }

        var bucket = repeatHash(node) & (max_sources - 1);
        var group_index: usize = undefined;
        while (true) : (bucket = (bucket + 1) & (max_sources - 1)) {
            const entry = table[bucket];
            if (entry == empty_group) {
                group_index = group_count;
                group_count += 1;
                table[bucket] = @intCast(group_index);
                representatives[group_index] = @intCast(slot);
                best_slots[group_index] = @intCast(slot);
                best_ranks[group_index] = 0;
                break;
            }
            group_index = entry;
            if (sameRepeats(node, nodes[representatives[group_index]])) break;
        }
        masks[group_index] |= source_bit;
        if (rank(node, ll_prices)) |node_rank| {
            if (masks[group_index] == source_bit or
                node_rank < best_ranks[group_index])
            {
                best_ranks[group_index] = node_rank;
                best_slots[group_index] = @intCast(slot);
            }
        } else ranks_valid[group_index] = false;
    }
    for (0..group_count) |group|
        result |= if (ranks_valid[group]) bit(best_slots[group]) else masks[group];
    return result;
}

inline fn bit(slot: usize) u16 {
    return @as(u16, 1) << @intCast(slot);
}

inline fn sameRepeats(left: anytype, right: @TypeOf(left)) bool {
    return left.repeats[0] == right.repeats[0] and
        left.repeats[1] == right.repeats[1] and
        left.repeats[2] == right.repeats[2];
}

inline fn repeatHash(node: anytype) usize {
    return node.repeats[0] ^
        std.math.rotl(usize, node.repeats[1], 11) ^
        std.math.rotl(usize, node.repeats[2], 23);
}

fn rank(node: anytype, ll_prices: *const [prices.ll_symbol_count]u32) ?u64 {
    // Preserve synthetic near-overflow behavior: a valid LL rank can still
    // overflow once any common ML/OF sequence cost is added.
    if (node.cost > std.math.maxInt(u64) - std.math.maxInt(u32)) return null;
    const symbol = prices.literalSymbol(node.literal_len) catch return null;
    const extra = std.math.mul(
        u64,
        @as(u64, symbol.extra_bits),
        @as(u64, prices.scale),
    ) catch return null;
    const with_symbol = std.math.add(
        u64,
        node.cost,
        @as(u64, ll_prices[symbol.code]),
    ) catch return null;
    return std.math.add(u64, with_symbol, extra) catch null;
}

test "Zstd HQ source dominance selects safe materialization masks" {
    try @import("source_dominance_tests.zig").contracts(@This());
}
