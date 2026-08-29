const std = @import("std");

/// Unbounded Huffman tree for at most 64 active symbols. `frequencies` must be
/// ordered from highest to lowest weight, with the caller's deterministic tie
/// order preserved. Planner alphabets in current text/source/log corpora are
/// <=33 symbols, so depth is comfortably below Brotli's 15-bit limit. Returns
/// false if an adversarial distribution exceeds that limit, allowing the
/// caller to retain package-merge fallback.
pub fn build(comptime capacity: usize, frequencies: []const u32, lengths: *[capacity]u4) bool {
    std.debug.assert(capacity <= 64 and frequencies.len <= capacity);
    if (frequencies.len > 1) {
        for (frequencies[1..], frequencies[0 .. frequencies.len - 1]) |frequency, previous|
            std.debug.assert(previous >= frequency);
    }
    if (frequencies.len == 0) return false;
    if (frequencies.len == 1) {
        lengths[0] = 1;
        return true;
    }
    // Leaves always precede generated parents, so node indexes are also the
    // stable tie-break serials used by the reference heap. Keeping weights and
    // parents in parallel compact arrays avoids dragging a padded 16-byte Node
    // through both queues. The largest legal node index is 126, so every
    // non-root parent fits in i8. All non-root nodes receive a parent during
    // construction, and the reverse traversal deliberately excludes the root.
    var weights: [2 * capacity - 1]u64 = undefined;
    var parents: [2 * capacity - 1]i8 = undefined;
    var leaves: [capacity]u8 = undefined;
    var node_len = frequencies.len;
    for (frequencies, 0..) |frequency, i| {
        weights[i] = frequency;
        leaves[i] = @intCast(i);
    }
    // PrefixAlphabet supplies descending weight with ascending-symbol ties.
    // Visit equal-weight groups from lightest to heaviest while preserving each
    // group's order, matching the heap's `(weight, serial)` tie behavior.
    var write_i: usize = 0;
    var group_end = frequencies.len;
    while (group_end != 0) {
        var group_start = group_end - 1;
        while (group_start != 0 and frequencies[group_start - 1] == frequencies[group_end - 1]) group_start -= 1;
        for (group_start..group_end) |index| {
            leaves[write_i] = @intCast(index);
            write_i += 1;
        }
        group_end = group_start;
    }
    var leaf_i: usize = 0;
    var parent_i = frequencies.len;
    var remaining = frequencies.len;
    while (remaining > 1) {
        const first = queuePop(weights[0..node_len], leaves[0..frequencies.len], &leaf_i, &parent_i, node_len);
        const second = queuePop(weights[0..node_len], leaves[0..frequencies.len], &leaf_i, &parent_i, node_len);
        const parent: u8 = @intCast(node_len);
        weights[node_len] = weights[first] + weights[second];
        parents[first] = @intCast(parent);
        parents[second] = @intCast(parent);
        node_len += 1;
        remaining -= 1;
    }
    // Parents are appended after both children. Walking nodes backwards makes
    // every parent depth available before its children, so all leaf depths are
    // recovered in O(nodes) instead of following each leaf-to-root chain.
    var depths: [2 * capacity - 1]u5 = undefined;
    depths[node_len - 1] = 0;
    var index = node_len - 1;
    while (index != 0) {
        index -= 1;
        const parent = parents[index];
        depths[index] = depths[@intCast(parent)] + 1;
    }
    for (frequencies, 0..) |_, symbol| {
        if (depths[symbol] > 15) return false;
        lengths[symbol] = @intCast(depths[symbol]);
    }
    return true;
}

fn less(comptime Node: type, nodes: []const Node, left_index: u8, right_index: u8) bool {
    const left = nodes[left_index];
    const right = nodes[right_index];
    return left.weight < right.weight or (left.weight == right.weight and left.serial < right.serial);
}

inline fn queuePop(weights: []const u64, leaves: []const u8, leaf_i: *usize, parent_i: *usize, parent_end: usize) u8 {
    if (leaf_i.* >= leaves.len) {
        const result: u8 = @intCast(parent_i.*);
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
    const result: u8 = @intCast(parent_i.*);
    parent_i.* += 1;
    return result;
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
        var depth: u4 = 0;
        var node: i16 = @intCast(symbol);
        while (nodes[@intCast(node)].parent >= 0) {
            depth += 1;
            if (depth > 15) return false;
            node = nodes[@intCast(node)].parent;
        }
        lengths[symbol] = depth;
    }
    return true;
}
