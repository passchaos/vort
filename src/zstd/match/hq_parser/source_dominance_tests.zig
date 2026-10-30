const std = @import("std");
const prices = @import("prices.zig");
const state = @import("state.zig");

const repeats_a = [3]usize{ 1, 4, 8 };
const repeats_b = [3]usize{ 3, 7, 11 };

pub fn contracts(comptime Codec: type) !void {
    inline for (.{ state.Node, state.WholeNode }) |Node| {
        inline for (.{ 1, 8, 16 }) |width| {
            try ranksAndGroups(Codec, Node, width);
            try invalidRanks(Codec, Node, width);
            try exhaustiveSmallOracle(Codec, Node, width);
        }
        try sentinels(Codec, Node);
    }
}

fn makeNode(comptime Node: type, cost: u64, literal_len: u32, repeats: [3]usize) Node {
    return .{ .cost = cost, .literal_len = literal_len, .repeats = repeats };
}

fn ranksAndGroups(comptime Codec: type, comptime Node: type, comptime width: usize) !void {
    var ll_prices: [prices.ll_symbol_count]u32 = @splat(0);
    var row: [width]Node = @splat(.{});
    row[0] = makeNode(Node, 100, 16, repeats_a); // rank 356
    try std.testing.expectEqual(@as(u16, 0b1), Codec.materializeMask(&row, &ll_prices));
    if (width == 1) return;

    // Below, equal, and above comparisons include the LL extra-bit price.
    row[1] = makeNode(Node, 357, 1, repeats_a);
    try std.testing.expectEqual(@as(u16, 0b1), Codec.materializeMask(&row, &ll_prices));
    row[1].cost = 356;
    try std.testing.expectEqual(@as(u16, 0b1), Codec.materializeMask(&row, &ll_prices));
    row[1].cost = 355;
    try std.testing.expectEqual(@as(u16, 0b10), Codec.materializeMask(&row, &ll_prices));

    // Distinct repeat histories never dominate each other.
    row[1].repeats = repeats_b;
    try std.testing.expectEqual(@as(u16, 0b11), Codec.materializeMask(&row, &ll_prices));

    // A zero-literal source is always independent, even when repeats match.
    row[1] = makeNode(Node, 0, 0, repeats_a);
    try std.testing.expectEqual(@as(u16, 0b11), Codec.materializeMask(&row, &ll_prices));
    if (width < 8) return;
    row[2] = makeNode(Node, 0, 0, repeats_a);
    row[3] = makeNode(Node, 99, 1, repeats_a);
    try std.testing.expectEqual(@as(u16, 0b1110), Codec.materializeMask(&row, &ll_prices));

    // The price table participates in rank, independently of extra bits.
    ll_prices[1] = 400;
    try std.testing.expectEqual(@as(u16, 0b111), Codec.materializeMask(&row, &ll_prices));
}

fn invalidRanks(comptime Codec: type, comptime Node: type, comptime width: usize) !void {
    if (width == 1) return;
    var ll_prices: [prices.ll_symbol_count]u32 = @splat(0);
    var row: [width]Node = @splat(.{});
    row[0] = makeNode(Node, 7, 1, repeats_a);
    row[1] = makeNode(Node, 0, std.math.maxInt(u32), repeats_a);
    try std.testing.expectEqual(@as(u16, 0b11), Codec.materializeMask(&row, &ll_prices));

    row[1] = makeNode(Node, std.math.maxInt(u64) - 1, 1, repeats_a);
    ll_prices[1] = 2;
    try std.testing.expectEqual(@as(u16, 0b11), Codec.materializeMask(&row, &ll_prices));

    // The rank itself fits, but a later common u32 sequence price may not.
    ll_prices[1] = 0;
    row[1] = makeNode(Node, std.math.maxInt(u64) - std.math.maxInt(u32) + 1, 1, repeats_a);
    try std.testing.expectEqual(@as(u16, 0b11), Codec.materializeMask(&row, &ll_prices));

    // An invalid member only disables dominance in its own repeat group.
    if (width >= 8) {
        row[2] = makeNode(Node, 0, 1, repeats_b);
        row[3] = makeNode(Node, 1, 1, repeats_b);
        try std.testing.expectEqual(@as(u16, 0b111), Codec.materializeMask(&row, &ll_prices));
    }
}

fn sentinels(comptime Codec: type, comptime Node: type) !void {
    var ll_prices: [prices.ll_symbol_count]u32 = @splat(0);
    const empty: [0]Node = .{};
    try std.testing.expectEqual(@as(u16, 0), Codec.materializeMask(&empty, &ll_prices));

    var row: [4]Node = @splat(.{});
    row[0] = makeNode(Node, 4, 1, repeats_a);
    // The first empty slot terminates the valid prefix. Later garbage neither
    // sets a bit nor makes the live prefix's rank invalid.
    row[1].literal_len = 1;
    row[1].repeats = repeats_a;
    row[2] = makeNode(Node, 0, std.math.maxInt(u32), repeats_a);
    row[3] = makeNode(Node, 0, 1, .{ 0, 0, 0 });
    try std.testing.expectEqual(@as(u16, 0b1), Codec.materializeMask(&row, &ll_prices));
}

fn exhaustiveSmallOracle(comptime Codec: type, comptime Node: type, comptime width: usize) !void {
    var ll_prices: [prices.ll_symbol_count]u32 = @splat(0);
    ll_prices[1] = 2;
    const variants = [_]Node{
        .{},
        makeNode(Node, 0, 0, repeats_a),
        makeNode(Node, 0, 1, repeats_a),
        makeNode(Node, 3, 1, repeats_a),
        makeNode(Node, 0, 16, repeats_a),
        makeNode(Node, 1, std.math.maxInt(u32), repeats_a),
        makeNode(Node, std.math.maxInt(u64) - 1, 1, repeats_a),
        makeNode(Node, 0, 1, repeats_b),
    };
    const live = @min(width, 3);
    var case_count: usize = 1;
    for (0..live) |_| case_count *= variants.len;
    for (0..case_count) |case_index| {
        var row: [width]Node = @splat(.{});
        var code = case_index;
        for (0..live) |slot| {
            row[slot] = variants[code % variants.len];
            code /= variants.len;
        }
        try std.testing.expectEqual(
            referenceMask(&row, &ll_prices),
            Codec.materializeMask(&row, &ll_prices),
        );
    }
}

/// Deliberately selects each slot independently rather than constructing
/// groups, and uses u128 arithmetic as the checked-rank oracle.
fn referenceMask(row: anytype, ll_prices: *const [prices.ll_symbol_count]u32) u16 {
    var result: u16 = 0;
    for (row, 0..) |node, slot| {
        if (node.cost == std.math.maxInt(u64)) break;
        const source_bit = @as(u16, 1) << @intCast(slot);
        if (node.literal_len == 0) {
            result |= source_bit;
            continue;
        }
        const own_rank = referenceRank(node, ll_prices);
        var group_valid = own_rank != null;
        var selected = own_rank != null;
        for (row, 0..) |other, other_slot| {
            if (other.cost == std.math.maxInt(u64)) break;
            if (other.literal_len == 0 or !std.mem.eql(usize, &node.repeats, &other.repeats)) continue;
            const other_rank = referenceRank(other, ll_prices);
            if (other_rank == null) {
                group_valid = false;
                continue;
            }
            if (own_rank) |rank| {
                selected = selected and (rank < other_rank.? or
                    (rank == other_rank.? and slot <= other_slot));
            }
        }
        if (!group_valid or selected) result |= source_bit;
    }
    return result;
}

fn referenceRank(node: anytype, ll_prices: *const [prices.ll_symbol_count]u32) ?u64 {
    const symbol = prices.literalSymbol(node.literal_len) catch return null;
    const rank = @as(u128, node.cost) + ll_prices[symbol.code] +
        @as(u128, symbol.extra_bits) * prices.scale;
    if (rank > std.math.maxInt(u64)) return null;
    return @intCast(rank);
}
