const std = @import("std");

/// Unbounded Huffman tree for at most 64 active symbols. Planner alphabets in
/// current text/source/log corpora are <=33 symbols, so depth is comfortably
/// below Brotli's 15-bit limit. Returns false if an adversarial distribution
/// exceeds that limit, allowing the caller to retain package-merge fallback.
pub fn build(comptime capacity: usize, frequencies: []const usize, lengths: *[capacity]u4) bool {
    std.debug.assert(capacity <= 64 and frequencies.len <= capacity);
    lengths.* = @splat(0);
    if (frequencies.len == 0) return false;
    if (frequencies.len == 1) {
        lengths[0] = 1;
        return true;
    }
    const Node = struct { weight: u64, parent: i16 = -1, serial: u8 };
    var nodes: [2 * capacity - 1]Node = undefined;
    var active: [2 * capacity - 1]u8 = undefined;
    var node_len = frequencies.len;
    var active_len = frequencies.len;
    for (frequencies, 0..) |frequency, i| {
        nodes[i] = .{ .weight = frequency, .serial = @intCast(i) };
        active[i] = @intCast(i);
    }
    while (active_len > 1) {
        const first_pos = minNode(nodes[0..node_len], active[0..active_len]);
        const first = active[first_pos];
        removeActive(&active, &active_len, first_pos);
        const second_pos = minNode(nodes[0..node_len], active[0..active_len]);
        const second = active[second_pos];
        removeActive(&active, &active_len, second_pos);
        const parent: u8 = @intCast(node_len);
        nodes[node_len] = .{ .weight = nodes[first].weight + nodes[second].weight, .serial = parent };
        nodes[first].parent = parent;
        nodes[second].parent = parent;
        node_len += 1;
        active[active_len] = parent;
        active_len += 1;
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

fn minNode(nodes: anytype, active: []const u8) usize {
    var best: usize = 0;
    for (active[1..], 1..) |index, pos| {
        const left = nodes[index];
        const right = nodes[active[best]];
        if (left.weight < right.weight or (left.weight == right.weight and left.serial < right.serial)) best = pos;
    }
    return best;
}

fn removeActive(active: anytype, len: *usize, pos: usize) void {
    len.* -= 1;
    active[pos] = active[len.*];
}

test "small Huffman builds complete tree" {
    var lengths: [64]u4 = undefined;
    try std.testing.expect(build(64, &.{ 10, 7, 3, 2, 1 }, &lengths));
    var space: usize = 1 << 15;
    for (lengths[0..5]) |bits| space -= @as(usize, 1) << @intCast(15 - bits);
    try std.testing.expectEqual(@as(usize, 0), space);
}

test "small Huffman matches package merge weighted cost" {
    const huffman = @import("../../huffman.zig");
    var state: u32 = 0x1234_5678;
    for (0..64) |_| {
        var frequencies: [64]usize = @splat(0);
        const active = 5 + state % 60;
        for (frequencies[0..active]) |*frequency| {
            state = state *% 1_664_525 +% 1_013_904_223;
            frequency.* = 1 + (state >> 20);
        }
        var small: [64]u4 = undefined;
        if (!build(64, frequencies[0..active], &small)) continue;
        var reference_frequencies: [64]u32 = @splat(0);
        for (frequencies, 0..) |frequency, i| reference_frequencies[i] = @intCast(frequency);
        const reference = huffman.treeCodeLengths(64, &reference_frequencies, 15);
        var small_cost: u64 = 0;
        var reference_cost: u64 = 0;
        for (frequencies[0..active], 0..) |frequency, i| {
            small_cost += @as(u64, frequency) * small[i];
            reference_cost += @as(u64, frequency) * reference[i];
        }
        try std.testing.expectEqual(reference_cost, small_cost);
    }
}
