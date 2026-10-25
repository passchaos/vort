const std = @import("std");

pub const BuildProfile = struct {
    calls: usize = 0,
    failures: usize = 0,
    package_merge_calls: usize = 0,
    leaf_order_ns: u64 = 0,
    merge_ns: u64 = 0,
    depth_ns: u64 = 0,
    output_ns: u64 = 0,
};

/// Unbounded Huffman tree for at most 128 active symbols. `frequencies` must be
/// ordered from highest to lowest weight, with the caller's deterministic tie
/// order preserved. Observed ratio-mode literal trees reach the mid-80s while
/// remaining comfortably below Brotli's 15-bit limit. Returns false if an
/// adversarial distribution exceeds that limit, allowing the caller to retain
/// package-merge fallback.
pub fn build(comptime capacity: usize, frequencies: []const u32, lengths: *[capacity]u4) bool {
    return buildInternal(capacity, false, frequencies, lengths, {}, {});
}

pub fn buildProfiled(
    comptime capacity: usize,
    frequencies: []const u32,
    lengths: *[capacity]u4,
    io: std.Io,
    profile: *BuildProfile,
) bool {
    return buildInternal(capacity, true, frequencies, lengths, io, profile);
}

fn buildInternal(
    comptime capacity: usize,
    comptime profiled: bool,
    frequencies: []const u32,
    lengths: *[capacity]u4,
    io: if (profiled) std.Io else void,
    profile: if (profiled) *BuildProfile else void,
) bool {
    std.debug.assert(capacity <= 128 and frequencies.len <= capacity);
    if (profiled) profile.calls += 1;
    if (frequencies.len > 1) {
        for (frequencies[1..], frequencies[0 .. frequencies.len - 1]) |frequency, previous|
            std.debug.assert(previous >= frequency);
    }
    if (frequencies.len == 0) {
        if (profiled) profile.failures += 1;
        return false;
    }
    if (frequencies.len == 1) {
        lengths[0] = 1;
        return true;
    }
    // Leaves always precede generated parents, so node indexes are also the
    // stable tie-break serials used by the reference heap. Keeping weights and
    // parents in parallel compact arrays avoids dragging a padded 16-byte Node
    // through both queues. The largest legal node index is 254, so every
    // non-root parent fits in u8; the <=64 specialization retains signed bytes
    // for identical generated layout. All non-root nodes receive a parent during
    // construction, and the reverse traversal deliberately excludes the root.
    const leaf_order_start = if (profiled) std.Io.Clock.awake.now(io) else {};
    const Parent = if (capacity <= 64) i8 else u8;
    var weights: [2 * capacity - 1]u64 = undefined;
    var parents: [2 * capacity - 1]Parent = undefined;
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
    if (profiled) profile.leaf_order_ns +%= elapsedNs(leaf_order_start, io);
    const merge_start = if (profiled) std.Io.Clock.awake.now(io) else {};
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
    if (profiled) profile.merge_ns +%= elapsedNs(merge_start, io);
    // Parents are appended after both children. Walking nodes backwards makes
    // every parent depth available before its children, so all leaf depths are
    // recovered in O(nodes) instead of following each leaf-to-root chain.
    const depth_start = if (profiled) std.Io.Clock.awake.now(io) else {};
    var depths: [2 * capacity - 1]u5 = undefined;
    depths[node_len - 1] = 0;
    var index = node_len - 1;
    while (index != 0) {
        index -= 1;
        const parent = parents[index];
        depths[index] = depths[@intCast(parent)] + 1;
    }
    if (profiled) profile.depth_ns +%= elapsedNs(depth_start, io);
    const output_start = if (profiled) std.Io.Clock.awake.now(io) else {};
    for (frequencies, 0..) |_, symbol| {
        if (depths[symbol] > 15) {
            if (profiled) {
                profile.output_ns +%= elapsedNs(output_start, io);
                profile.failures += 1;
            }
            return false;
        }
        lengths[symbol] = @intCast(depths[symbol]);
    }
    if (profiled) profile.output_ns +%= elapsedNs(output_start, io);
    return true;
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

