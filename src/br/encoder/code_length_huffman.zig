const std = @import("std");

const alphabet_size = 18;
const node_capacity = 2 * alphabet_size - 1;
const Symbol = u5;
const NodeIndex = u6;

comptime {
    if (alphabet_size - 1 > std.math.maxInt(Symbol))
        @compileError("code-length symbol type is too narrow");
    if (node_capacity - 1 > std.math.maxInt(NodeIndex))
        @compileError("code-length Huffman node type is too narrow");
}

/// Build the unbounded Huffman tree for Brotli's 18-symbol code-length
/// alphabet. The caller can use package merge when this returns null because
/// the unbounded tree exceeds Brotli's five-bit limit.
///
/// Leaves are ordered by `(weight, symbol)`. The two-queue merge prefers a
/// leaf over a generated parent at equal weight; generated parents retain
/// generation order. Those rules make the result deterministic without a
/// heap or a compact-to-original-symbol scatter pass.
pub fn build(frequencies: *const [18]u32) ?[18]u4 {
    var lengths: [alphabet_size]u4 = @splat(0);
    var weights: [node_capacity]u64 = undefined;
    var leaf_symbols: [alphabet_size]Symbol = undefined;
    var active: usize = 0;

    // Insertion sort is bounded to eighteen entries. Scanning symbols in
    // ascending order already makes equal-weight insertion stable; retaining
    // the full comparator here documents and enforces the required order.
    for (frequencies, 0..) |frequency, symbol_usize| {
        if (frequency == 0) continue;
        const symbol: Symbol = @intCast(symbol_usize);
        var index = active;
        while (index != 0 and leafLess(
            frequency,
            symbol,
            weights[index - 1],
            leaf_symbols[index - 1],
        )) : (index -= 1) {
            weights[index] = weights[index - 1];
            leaf_symbols[index] = leaf_symbols[index - 1];
        }
        weights[index] = frequency;
        leaf_symbols[index] = symbol;
        active += 1;
    }

    if (active == 0) return lengths;
    if (active == 1) {
        lengths[leaf_symbols[0]] = 1;
        return lengths;
    }

    // Eighteen u32 weights sum to fewer than 37 bits. u64 therefore covers
    // every generated weight, while NodeIndex covers all 35 possible nodes.
    var parents: [node_capacity]NodeIndex = undefined;
    var leaf_cursor: usize = 0;
    var parent_cursor: usize = active;
    var node_count: usize = active;
    var queue_items: usize = active;
    while (queue_items > 1) : (queue_items -= 1) {
        const first = queuePop(&weights, active, &leaf_cursor, &parent_cursor, node_count);
        const second = queuePop(&weights, active, &leaf_cursor, &parent_cursor, node_count);
        const parent: NodeIndex = @intCast(node_count);
        weights[node_count] = weights[first] + weights[second];
        parents[first] = parent;
        parents[second] = parent;
        node_count += 1;
    }

    // Parents are appended after their children. Reverse traversal therefore
    // obtains every child depth in one bounded pass and writes each leaf back
    // to its original symbol directly.
    var depths: [node_capacity]u5 = undefined;
    depths[node_count - 1] = 0;
    var node = node_count - 1;
    while (node != 0) {
        node -= 1;
        depths[node] = depths[parents[node]] + 1;
    }
    for (leaf_symbols[0..active], 0..) |symbol, leaf| {
        const depth = depths[leaf];
        if (depth > 5) return null;
        lengths[symbol] = @intCast(depth);
    }
    return lengths;
}

inline fn leafLess(left_weight: u32, left_symbol: Symbol, right_weight: u64, right_symbol: Symbol) bool {
    return left_weight < right_weight or
        (left_weight == right_weight and left_symbol < right_symbol);
}

inline fn queuePop(
    weights: *const [node_capacity]u64,
    leaf_count: usize,
    leaf_cursor: *usize,
    parent_cursor: *usize,
    parent_end: usize,
) NodeIndex {
    // Leaf <= parent is intentional: leaves win cross-queue weight ties.
    if (leaf_cursor.* < leaf_count and
        (parent_cursor.* == parent_end or weights[leaf_cursor.*] <= weights[parent_cursor.*]))
    {
        const result: NodeIndex = @intCast(leaf_cursor.*);
        leaf_cursor.* += 1;
        return result;
    }
    const result: NodeIndex = @intCast(parent_cursor.*);
    parent_cursor.* += 1;
    return result;
}

test "direct code-length Huffman handles empty and singleton alphabets" {
    const empty_frequencies: [alphabet_size]u32 = @splat(0);
    const empty = build(&empty_frequencies).?;
    try std.testing.expectEqualSlices(u4, &([_]u4{0} ** alphabet_size), &empty);

    var single_frequencies: [alphabet_size]u32 = @splat(0);
    single_frequencies[11] = std.math.maxInt(u32);
    var expected: [alphabet_size]u4 = @splat(0);
    expected[11] = 1;
    const single = build(&single_frequencies).?;
    try std.testing.expectEqualSlices(u4, &expected, &single);
}

test "direct code-length Huffman uses deterministic tie order" {
    var symbol_ties: [alphabet_size]u32 = @splat(0);
    symbol_ties[2] = 1;
    symbol_ties[7] = 1;
    symbol_ties[14] = 1;
    const symbol_lengths = build(&symbol_ties).?;
    try std.testing.expectEqual(@as(u4, 2), symbol_lengths[2]);
    try std.testing.expectEqual(@as(u4, 2), symbol_lengths[7]);
    try std.testing.expectEqual(@as(u4, 1), symbol_lengths[14]);

    // The generated weight-two parent ties the remaining leaf. Leaf priority
    // makes symbol 14 the root's direct child.
    var queue_tie: [alphabet_size]u32 = @splat(0);
    queue_tie[2] = 1;
    queue_tie[7] = 1;
    queue_tie[14] = 2;
    const queue_lengths = build(&queue_tie).?;
    try std.testing.expectEqual(@as(u4, 2), queue_lengths[2]);
    try std.testing.expectEqual(@as(u4, 2), queue_lengths[7]);
    try std.testing.expectEqual(@as(u4, 1), queue_lengths[14]);
}

test "direct code-length Huffman returns complete bounded trees" {
    const frequencies: [alphabet_size]u32 = @splat(1);
    const lengths = build(&frequencies).?;
    var kraft_units: u32 = 0;
    for (lengths) |length| {
        try std.testing.expect(length != 0 and length <= 5);
        kraft_units += @as(u32, 1) << @intCast(5 - length);
    }
    try std.testing.expectEqual(@as(u32, 1 << 5), kraft_units);
}

test "direct code-length Huffman rejects an over-depth tree" {
    var frequencies: [alphabet_size]u32 = @splat(0);
    frequencies[0] = 1;
    frequencies[1] = 1;
    frequencies[2] = 2;
    frequencies[3] = 4;
    frequencies[4] = 8;
    frequencies[5] = 16;
    frequencies[6] = 32;
    try std.testing.expect(build(&frequencies) == null);
}
