const std = @import("std");

pub const BuildProfile = struct {
    calls: usize = 0,
    failures: usize = 0,
    package_merge_calls: usize = 0,
    /// Initial leaf-order preparation. Ranked group advancement happens while
    /// merging and is therefore charged to `merge_ns`.
    leaf_order_ns: u64 = 0,
    merge_ns: u64 = 0,
    depth_ns: u64 = 0,
    output_ns: u64 = 0,
};

/// Unbounded Huffman tree for at most 256 active symbols. `frequencies` must be
/// ordered from highest to lowest weight, with the caller's deterministic tie
/// order preserved. Observed ratio-mode literal trees reach the mid-80s while
/// remaining comfortably below Brotli's 15-bit limit. Returns false if an
/// adversarial distribution exceeds that limit, allowing the caller to retain
/// package-merge fallback.
pub fn build(comptime capacity: usize, frequencies: []const u32, lengths: *[capacity]u4) bool {
    return buildInternal(capacity, false, false, {}, frequencies, lengths, {}, {});
}

pub fn buildProfiled(
    comptime capacity: usize,
    frequencies: []const u32,
    lengths: *[capacity]u4,
    io: std.Io,
    profile: *BuildProfile,
) bool {
    return buildInternal(capacity, true, false, {}, frequencies, lengths, io, profile);
}

/// Build directly from a caller-owned descending-frequency symbol rank. The
/// rank remains the creation serial used for deterministic equal-weight ties,
/// while completed depths are written to their original symbol positions.
pub fn buildRanked(
    comptime capacity: usize,
    comptime symbol_capacity: usize,
    symbols: []const u16,
    frequencies: *const [symbol_capacity]u32,
    lengths: *[symbol_capacity]u4,
) bool {
    return buildInternal(capacity, false, true, symbols, frequencies, lengths, {}, {});
}

pub fn buildRankedProfiled(
    comptime capacity: usize,
    comptime symbol_capacity: usize,
    symbols: []const u16,
    frequencies: *const [symbol_capacity]u32,
    lengths: *[symbol_capacity]u4,
    io: std.Io,
    profile: *BuildProfile,
) bool {
    return buildInternal(capacity, true, true, symbols, frequencies, lengths, io, profile);
}

fn buildInternal(
    comptime capacity: usize,
    comptime profiled: bool,
    comptime ranked: bool,
    symbols: if (ranked) []const u16 else void,
    frequencies: []const u32,
    lengths: []u4,
    io: if (profiled) std.Io else void,
    profile: if (profiled) *BuildProfile else void,
) bool {
    comptime std.debug.assert(capacity > 0 and capacity <= 256);
    const active_len = if (ranked) symbols.len else frequencies.len;
    std.debug.assert(active_len <= capacity);
    if (ranked) {
        std.debug.assert(frequencies.len == lengths.len);
        for (symbols, 0..) |symbol, rank| {
            std.debug.assert(symbol < frequencies.len);
            std.debug.assert(frequencies[symbol] != 0);
            if (rank != 0 and frequencies[symbols[rank - 1]] == frequencies[symbol])
                std.debug.assert(symbols[rank - 1] < symbol);
        }
    } else {
        std.debug.assert(lengths.len == capacity);
    }
    if (profiled) profile.calls += 1;
    if (active_len > 1) {
        for (1..active_len) |rank|
            std.debug.assert(frequencyAt(ranked, symbols, frequencies, rank - 1) >= frequencyAt(ranked, symbols, frequencies, rank));
    }
    if (active_len == 0) {
        if (profiled) profile.failures += 1;
        return false;
    }
    // The new dense path replaces package merge, which omits zero-weight
    // entries. An invalid active prefix containing zero must retain fallback.
    if (comptime capacity > 128) {
        if (frequencyAt(ranked, symbols, frequencies, active_len - 1) == 0) {
            if (profiled) profile.failures += 1;
            return false;
        }
    }
    if (active_len == 1) {
        writeLength(ranked, symbols, lengths, 0, 1);
        return true;
    }
    // Leaves always precede generated parents, so node indexes are also the
    // stable tie-break serials used by the reference heap. Keeping weights and
    // parents in parallel compact arrays avoids dragging a padded 16-byte Node
    // through both queues. Keep <=64 signed-byte and <=128 unsigned-byte
    // specializations; 256 symbols need u16 for indexes up to 510. All non-root
    // nodes receive a parent during
    // construction, and the reverse traversal deliberately excludes the root.
    const leaf_order_start = if (profiled) std.Io.Clock.awake.now(io) else {};
    const Index = if (capacity <= 128) u8 else u16;
    const Parent = if (capacity <= 64) i8 else if (capacity <= 128) u8 else u16;
    var weights: [2 * capacity - 1]u64 = undefined;
    var parents: [2 * capacity - 1]Parent = undefined;
    var leaves: if (ranked) void else [capacity]Index = if (ranked) {} else undefined;
    var node_len = active_len;
    for (0..active_len) |i| {
        weights[i] = frequencyAt(ranked, symbols, frequencies, i);
        if (!ranked) leaves[i] = @intCast(i);
    }
    // PrefixAlphabet supplies descending weight with ascending-symbol ties.
    // Visit equal-weight groups from lightest to heaviest while preserving each
    // group's order, matching the heap's `(weight, serial)` tie behavior.
    var write_i: usize = 0;
    var ranked_group_start: if (ranked) usize else void = if (ranked) active_len - 1 else {};
    var ranked_group_end: if (ranked) usize else void = if (ranked) active_len else {};
    var ranked_leaf_rank: if (ranked) usize else void = if (ranked) active_len - 1 else {};
    if (ranked) {
        while (ranked_group_start != 0 and weights[ranked_group_start - 1] == weights[ranked_group_end - 1])
            ranked_group_start -= 1;
        ranked_leaf_rank = ranked_group_start;
    } else {
        var group_end = active_len;
        while (group_end != 0) {
            var group_start = group_end - 1;
            while (group_start != 0 and weights[group_start - 1] == weights[group_end - 1]) group_start -= 1;
            for (group_start..group_end) |index| {
                leaves[write_i] = @intCast(index);
                write_i += 1;
            }
            group_end = group_start;
        }
    }
    if (profiled) profile.leaf_order_ns +%= elapsedNs(leaf_order_start, io);
    const merge_start = if (profiled) std.Io.Clock.awake.now(io) else {};
    var leaf_i: usize = 0;
    var parent_i = active_len;
    var remaining = active_len;
    while (remaining > 1) {
        const first = if (ranked)
            rankedQueuePop(Index, weights[0..node_len], active_len, &ranked_group_start, &ranked_group_end, &ranked_leaf_rank, &parent_i, node_len)
        else
            queuePop(Index, weights[0..node_len], leaves[0..active_len], &leaf_i, &parent_i, node_len);
        const second = if (ranked)
            rankedQueuePop(Index, weights[0..node_len], active_len, &ranked_group_start, &ranked_group_end, &ranked_leaf_rank, &parent_i, node_len)
        else
            queuePop(Index, weights[0..node_len], leaves[0..active_len], &leaf_i, &parent_i, node_len);
        const parent: Index = @intCast(node_len);
        weights[node_len] = weights[first] + weights[second];
        parents[first] = @intCast(parent);
        parents[second] = @intCast(parent);
        node_len += 1;
        remaining -= 1;
    }
    if (profiled) profile.merge_ns +%= elapsedNs(merge_start, io);
    // Parents are appended after both children. Walking nodes backwards makes
    // every parent depth available before its children, so all leaf depths are
    // recovered in O(nodes) instead of following each leaf-to-root chain.
    // Reject the first depth beyond 15 before writing it or reading any
    // remaining descendant depth. Every previously stored depth is <=15,
    // so the u5 addition is at most 16 even for a deeply skewed natural tree.
    const depth_start = if (profiled) std.Io.Clock.awake.now(io) else {};
    var depths: [2 * capacity - 1]u5 = undefined;
    depths[node_len - 1] = 0;
    var index = node_len - 1;
    while (index != 0) {
        index -= 1;
        const parent = parents[index];
        const depth = depths[@intCast(parent)] + 1;
        if (depth > 15) {
            if (profiled) {
                profile.depth_ns +%= elapsedNs(depth_start, io);
                profile.failures += 1;
            }
            return false;
        }
        depths[index] = depth;
    }
    if (profiled) profile.depth_ns +%= elapsedNs(depth_start, io);
    const output_start = if (profiled) std.Io.Clock.awake.now(io) else {};
    for (0..active_len) |rank|
        writeLength(ranked, symbols, lengths, rank, @intCast(depths[rank]));
    if (profiled) profile.output_ns +%= elapsedNs(output_start, io);
    return true;
}

inline fn frequencyAt(
    comptime ranked: bool,
    symbols: if (ranked) []const u16 else void,
    frequencies: []const u32,
    rank: usize,
) u32 {
    return frequencies[if (ranked) symbols[rank] else rank];
}

inline fn writeLength(
    comptime ranked: bool,
    symbols: if (ranked) []const u16 else void,
    lengths: []u4,
    rank: usize,
    bits: u4,
) void {
    lengths[if (ranked) symbols[rank] else rank] = bits;
}

fn elapsedNs(start: std.Io.Timestamp, io: std.Io) u64 {
    const ns = start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds;
    return if (ns <= 0) 0 else @intCast(ns);
}

fn less(comptime Node: type, nodes: []const Node, left_index: u8, right_index: u8) bool {
    const left = nodes[left_index];
    const right = nodes[right_index];
    return left.weight < right.weight or (left.weight == right.weight and left.serial < right.serial);
}

inline fn queuePop(comptime Index: type, weights: []const u64, leaves: []const Index, leaf_i: *usize, parent_i: *usize, parent_end: usize) Index {
    if (leaf_i.* >= leaves.len) {
        const result: Index = @intCast(parent_i.*);
        parent_i.* += 1;
        return result;
    }
    // A leaf index is always smaller than a parent index, so equal weights
    // select the leaf exactly as `(weight, serial)` ordering would.
    if (parent_i.* >= parent_end or weights[leaves[leaf_i.*]] <= weights[parent_i.*]) {
        const result = leaves[leaf_i.*];
        leaf_i.* += 1;
        return result;
    }
    const result: Index = @intCast(parent_i.*);
    parent_i.* += 1;
    return result;
}

inline fn rankedQueuePop(
    comptime Index: type,
    weights: []const u64,
    leaf_end: usize,
    group_start: *usize,
    group_end: *usize,
    leaf_rank: *usize,
    parent_i: *usize,
    parent_end: usize,
) Index {
    if (group_end.* == 0) {
        const result: Index = @intCast(parent_i.*);
        parent_i.* += 1;
        return result;
    }
    const leaf: Index = @intCast(leaf_rank.*);
    if (parent_i.* < parent_end and weights[parent_i.*] < weights[leaf]) {
        const result: Index = @intCast(parent_i.*);
        parent_i.* += 1;
        return result;
    }

    leaf_rank.* += 1;
    if (leaf_rank.* == group_end.*) {
        if (group_start.* == 0) {
            group_end.* = 0;
            leaf_rank.* = leaf_end;
        } else {
            group_end.* = group_start.*;
            group_start.* = group_end.* - 1;
            while (group_start.* != 0 and weights[group_start.* - 1] == weights[group_end.* - 1])
                group_start.* -= 1;
            leaf_rank.* = group_start.*;
        }
    }
    return leaf;
}

fn heapify(comptime Node: type, nodes: []const Node, heap: anytype, len: usize) void {
    var i = len / 2;
    while (i != 0) {
        i -= 1;
        siftDown(Node, nodes, heap, len, i);
    }
}

fn heapPop(comptime Node: type, nodes: []const Node, heap: anytype, len: *usize) u8 {
    const result = heap[0];
    len.* -= 1;
    if (len.* != 0) {
        heap[0] = heap[len.*];
        siftDown(Node, nodes, heap, len.*, 0);
    }
    return result;
}

fn heapPush(comptime Node: type, nodes: []const Node, heap: anytype, len: *usize, value: u8) void {
    var index = len.*;
    len.* += 1;
    while (index != 0) {
        const parent = (index - 1) / 2;
        if (!less(Node, nodes, value, heap[parent])) break;
        heap[index] = heap[parent];
        index = parent;
    }
    heap[index] = value;
}

fn siftDown(comptime Node: type, nodes: []const Node, heap: anytype, len: usize, start: usize) void {
    var root = start;
    while (root * 2 + 1 < len) {
        var child = root * 2 + 1;
        if (child + 1 < len and less(Node, nodes, heap[child + 1], heap[child])) child += 1;
        if (!less(Node, nodes, heap[child], heap[root])) break;
        std.mem.swap(u8, &heap[root], &heap[child]);
        root = child;
    }
}

test "dense Huffman exact tree lengths and bounded fallback contracts" {
    try @import("dense_huffman_tests.zig").contracts(@This());
}

test "small Huffman builds complete tree" {
    var lengths: [64]u4 = undefined;
    try std.testing.expect(build(64, &.{ 10, 7, 3, 2, 1 }, &lengths));
    var space: usize = 1 << 15;
    for (lengths[0..5]) |bits| space -= @as(usize, 1) << @intCast(15 - bits);
    try std.testing.expectEqual(@as(usize, 0), space);
}

test "small Huffman writes only the active length prefix" {
    var lengths: [64]u4 = @splat(0xf);
    try std.testing.expect(build(64, &.{ 10, 7, 3, 2, 1 }, &lengths));
    for (lengths[0..5]) |bits| try std.testing.expect(bits != 0 and bits <= 15);
    for (lengths[5..]) |bits| try std.testing.expectEqual(@as(u4, 0xf), bits);
}

test "small Huffman ordered frequencies match package merge weighted cost" {
    const huffman = @import("../../huffman.zig");
    var state: u32 = 0x1234_5678;
    for (0..64) |_| {
        var frequencies: [64]u32 = @splat(0);
        const active = 5 + state % 60;
        for (frequencies[0..active]) |*frequency| {
            state = state *% 1_664_525 +% 1_013_904_223;
            frequency.* = 1 + (state >> 20);
        }
        // The two-queue builder intentionally consumes PrefixAlphabet's
        // descending order rather than paying to sort on every hot-path call.
        std.mem.sort(u32, frequencies[0..active], {}, std.sort.desc(u32));
        var small: [64]u4 = undefined;
        if (!build(64, frequencies[0..active], &small)) continue;
        const reference = huffman.treeCodeLengths(64, &frequencies, 15);
        var small_cost: u64 = 0;
        var reference_cost: u64 = 0;
        for (frequencies[0..active], 0..) |frequency, i| {
            small_cost += @as(u64, frequency) * small[i];
            reference_cost += @as(u64, frequency) * reference[i];
        }
        try std.testing.expectEqual(reference_cost, small_cost);
    }
}

test "small Huffman two-queue builder matches heap reference lengths" {
    var state: u32 = 0x9e37_79b9;
    for (0..1024) |_| {
        var frequencies: [64]u32 = @splat(0);
        const active: usize = 2 + state % 63;
        for (frequencies[0..active]) |*frequency| {
            state = state *% 1_664_525 +% 1_013_904_223;
            frequency.* = 1 + (state >> 20);
        }
        std.mem.sort(u32, frequencies[0..active], {}, std.sort.desc(u32));
        var actual: [64]u4 = undefined;
        var expected: [64]u4 = undefined;
        const actual_ok = build(64, frequencies[0..active], &actual);
        const expected_ok = buildHeapReference(64, frequencies[0..active], &expected);
        try std.testing.expectEqual(expected_ok, actual_ok);
        if (actual_ok) try std.testing.expectEqualSlices(u4, expected[0..active], actual[0..active]);
    }
}

test "small Huffman 128-symbol builder matches heap reference lengths" {
    var state: u32 = 0x243f_6a88;
    for (0..256) |_| {
        var frequencies: [128]u32 = @splat(0);
        const active: usize = 65 + state % 64;
        for (frequencies[0..active]) |*frequency| {
            state = state *% 1_664_525 +% 1_013_904_223;
            frequency.* = 1 + (state >> 20);
        }
        std.mem.sort(u32, frequencies[0..active], {}, std.sort.desc(u32));
        var actual: [128]u4 = undefined;
        var expected: [128]u4 = undefined;
        const actual_ok = build(128, frequencies[0..active], &actual);
        const expected_ok = buildHeapReference(128, frequencies[0..active], &expected);
        try std.testing.expectEqual(expected_ok, actual_ok);
        if (actual_ok) try std.testing.expectEqualSlices(u4, expected[0..active], actual[0..active]);
    }
}

fn expectRankedTieCase(frequencies: []const u32) !void {
    const symbols = [_]u16{ 0, 2, 7, 11, 19, 23, 29, 31 };
    std.debug.assert(frequencies.len <= symbols.len);
    var dense_frequencies: [32]u32 = @splat(0);
    for (symbols[0..frequencies.len], frequencies) |symbol, frequency|
        dense_frequencies[symbol] = frequency;
    var compact: [64]u4 = @splat(0xf);
    var ranked: [32]u4 = @splat(0xf);
    try std.testing.expect(build(64, frequencies, &compact));
    try std.testing.expect(buildRanked(64, 32, symbols[0..frequencies.len], &dense_frequencies, &ranked));
    for (symbols[0..frequencies.len], compact[0..frequencies.len]) |symbol, bits|
        try std.testing.expectEqual(bits, ranked[symbol]);
    for (dense_frequencies, ranked) |frequency, bits|
        try std.testing.expectEqual(frequency != 0, bits != 0xf);
}

test "ranked Huffman preserves leaf and parent tie ordering" {
    // 1 + 1 produces a parent tied with both weight-two leaves.
    try expectRankedTieCase(&.{ 4, 2, 2, 1, 1 });
    // Equal leaves and equal parents must retain compact-rank/creation order.
    try expectRankedTieCase(&.{ 1, 1, 1, 1, 1, 1, 1, 1 });
    // Several generations contain simultaneous leaf/parent/parent ties.
    try expectRankedTieCase(&.{ 8, 4, 4, 2, 2, 1, 1 });
}

fn buildHeapReference(comptime capacity: usize, frequencies: []const u32, lengths: *[capacity]u4) bool {
    lengths.* = @splat(0);
    const Node = struct { weight: u64, parent: i16 = -1, serial: u8 };
    var nodes: [2 * capacity - 1]Node = undefined;
    var heap: [2 * capacity - 1]u8 = undefined;
    var node_len = frequencies.len;
    var heap_len = frequencies.len;
    for (frequencies, 0..) |frequency, i| {
        nodes[i] = .{ .weight = frequency, .serial = @intCast(i) };
        heap[i] = @intCast(i);
    }
    heapify(Node, nodes[0..node_len], &heap, heap_len);
    while (heap_len > 1) {
        const first = heapPop(Node, nodes[0..node_len], &heap, &heap_len);
        const second = heapPop(Node, nodes[0..node_len], &heap, &heap_len);
        const parent: u8 = @intCast(node_len);
        nodes[node_len] = .{ .weight = nodes[first].weight + nodes[second].weight, .serial = parent };
        nodes[first].parent = parent;
        nodes[second].parent = parent;
        node_len += 1;
        heapPush(Node, nodes[0..node_len], &heap, &heap_len, parent);
    }
    for (frequencies, 0..) |_, symbol| {
        var depth: u5 = 0;
        var node: i16 = @intCast(symbol);
        while (nodes[@intCast(node)].parent >= 0) {
            depth += 1;
            if (depth > 15) return false;
            node = nodes[@intCast(node)].parent;
        }
        lengths[symbol] = @intCast(depth);
    }
    return true;
}
