//! Exact rank-order tests for the bounded dense two-queue Huffman path.
const std = @import("std");
const huffman = @import("../../huffman.zig");

const NaturalTree = struct {
    depths: [256]u16 = @splat(0),
    maximum: u16 = 0,
};

/// Independent reference: repeatedly scan all live nodes for the least
/// (weight, creation serial), then walk each leaf's parent chain. No queues or
/// reverse depth propagation are shared with the optimized builder.
fn naturalTree(frequencies: []const u32) NaturalTree {
    const Node = struct { weight: u64, parent: ?u16 = null, live: bool = true };
    var nodes: [511]Node = undefined;
    for (frequencies, 0..) |frequency, index| nodes[index] = .{ .weight = frequency };
    var node_count = frequencies.len;
    var remaining = frequencies.len;
    while (remaining > 1) {
        var selected: [2]usize = undefined;
        for (&selected) |*choice| {
            var best: ?usize = null;
            for (nodes[0..node_count], 0..) |node, index| {
                if (!node.live) continue;
                if (best == null or node.weight < nodes[best.?].weight or (node.weight == nodes[best.?].weight and index < best.?)) best = index;
            }
            choice.* = best.?;
            nodes[choice.*].live = false;
        }
        nodes[node_count] = .{ .weight = nodes[selected[0]].weight + nodes[selected[1]].weight };
        nodes[selected[0]].parent = @intCast(node_count);
        nodes[selected[1]].parent = @intCast(node_count);
        node_count += 1;
        remaining -= 1;
    }
    var result: NaturalTree = .{};
    for (frequencies, 0..) |_, leaf| {
        var current = leaf;
        while (nodes[current].parent) |parent| {
            result.depths[leaf] += 1;
            current = parent;
        }
        result.maximum = @max(result.maximum, result.depths[leaf]);
    }
    return result;
}

fn check(comptime Codec: type, frequencies: []const u32) !bool {
    try std.testing.expect(frequencies.len >= 129 and frequencies.len <= 256);
    const natural = naturalTree(frequencies);
    const expected_success = natural.maximum <= 15;
    var unchanged: [256]u32 = @splat(0);
    @memcpy(unchanged[0..frequencies.len], frequencies);
    var ordinary: [256]u4 = @splat(0xf);
    var observed: [256]u4 = @splat(0xf);
    var profile: Codec.BuildProfile = .{};
    const success = Codec.build(256, frequencies, &ordinary);
    const profiled_success = Codec.buildProfiled(256, frequencies, &observed, std.testing.io, &profile);
    try std.testing.expectEqual(expected_success, success);
    try std.testing.expectEqual(success, profiled_success);
    try std.testing.expectEqualSlices(u32, unchanged[0..frequencies.len], frequencies);
    try std.testing.expectEqualSlices(u4, &ordinary, &observed);
    try std.testing.expectEqual(@as(usize, 1), profile.calls);
    try std.testing.expectEqual(@as(usize, @intFromBool(!success)), profile.failures);
    try std.testing.expectEqual(@as(usize, 0), profile.package_merge_calls);
    if (success) {
        // Input ranks, rather than original byte symbols, form the reference
        // alphabet. Inactive rank entries remain zero in the legacy planner.
        var reference_frequencies: [256]u32 = @splat(0);
        @memcpy(reference_frequencies[0..frequencies.len], frequencies);
        const reference = huffman.treeCodeLengths(256, &reference_frequencies, 15);
        try std.testing.expectEqualSlices(u4, reference[0..frequencies.len], ordinary[0..frequencies.len]);
        var kraft: usize = 0;
        for (ordinary[0..frequencies.len]) |bits| {
            try std.testing.expect(bits != 0 and bits <= 15);
            kraft += @as(usize, 1) << @intCast(15 - bits);
        }
        try std.testing.expectEqual(@as(usize, 1) << 15, kraft);
        for (ordinary[frequencies.len..]) |bits| try std.testing.expectEqual(@as(u4, 0xf), bits);
    } else {
        // Failed scratch output is not published by the caller. A bounded
        // legacy plan remains usable; rejection is not clamping.
        var bounded: [256]u32 = @splat(0);
        @memcpy(bounded[0..frequencies.len], frequencies);
        const fallback = huffman.treeCodeLengths(256, &bounded, 15);
        for (fallback[0..frequencies.len]) |bits| try std.testing.expect(bits != 0 and bits <= 15);
    }
    return success;
}

fn fibonacci(frequencies: []u32) void {
    @memset(frequencies, 1);
    var first: u32 = 1;
    var second: u32 = 1;
    const count = @min(frequencies.len, 46);
    for (frequencies[0..count], 0..) |*frequency, index| {
        if (index < 2) {
            frequency.* = 1;
        } else {
            const next = first + second;
            frequency.* = next;
            first = second;
            second = next;
        }
    }
    std.mem.sort(u32, frequencies, {}, std.sort.desc(u32));
}

fn narrowDepthBoundary(comptime Codec: type) !void {
    // Exactly 34 leaves: adding more weight-one leaves changes this depth
    // boundary and would stop exercising the original <=128 primitive.
    var frequencies: [34]u32 = undefined;
    fibonacci(&frequencies);
    const original = frequencies;
    try std.testing.expectEqual(@as(u32, 5702887), frequencies[0]);
    const natural = naturalTree(&frequencies);
    try std.testing.expectEqual(@as(u16, 33), natural.maximum);
    try std.testing.expect(natural.maximum > 31);
    inline for (.{ 64, 128 }) |capacity| {
        var ordinary: [capacity]u4 = @splat(0xf);
        var observed: [capacity]u4 = @splat(0xf);
        var profile: Codec.BuildProfile = .{};
        try std.testing.expect(!Codec.build(capacity, &frequencies, &ordinary));
        try std.testing.expect(!Codec.buildProfiled(capacity, &frequencies, &observed, std.testing.io, &profile));
        try std.testing.expectEqualSlices(u4, &ordinary, &observed);
        try std.testing.expectEqualSlices(u32, &original, &frequencies);
        try std.testing.expectEqual(@as(usize, 1), profile.calls);
        try std.testing.expectEqual(@as(usize, 1), profile.failures);
        try std.testing.expectEqual(@as(usize, 0), profile.package_merge_calls);
        // Failure leaves temporary output unpublished. The caller can still
        // build the original bounded plan instead of accepting clamped depths.
        var bounded: [capacity]u32 = @splat(0);
        @memcpy(bounded[0..frequencies.len], &frequencies);
        const fallback = huffman.treeCodeLengths(capacity, &bounded, 15);
        for (fallback[0..frequencies.len]) |bits| try std.testing.expect(bits != 0 and bits <= 15);
    }
}

pub fn contracts(comptime Codec: type) !void {
    try narrowDepthBoundary(Codec);
    var frequencies: [256]u32 = undefined;
    var random: u32 = 0x243f6a88;
    for ([_]usize{ 129, 130, 159, 192, 255, 256 }) |active| {
        @memset(&frequencies, 0);
        @memset(frequencies[0..active], 17);
        try std.testing.expect(try check(Codec, frequencies[0..active]));
        for ([_]u32{ 1, 7, 97, std.math.maxInt(u32) }) |range| {
            for (frequencies[0..active], 0..) |*frequency, index| frequency.* = if (range == std.math.maxInt(u32)) range - @as(u32, @intCast(index % 7)) else 1 + @as(u32, @intCast(index % @as(usize, range)));
            std.mem.sort(u32, frequencies[0..active], {}, std.sort.desc(u32));
            try std.testing.expect(try check(Codec, frequencies[0..active]));
        }
        for (0..12) |_| {
            for (frequencies[0..active]) |*frequency| {
                random = random *% 1664525 +% 1013904223;
                frequency.* = 1 + (random >> 16);
            }
            std.mem.sort(u32, frequencies[0..active], {}, std.sort.desc(u32));
            _ = try check(Codec, frequencies[0..active]);
        }
        fibonacci(frequencies[0..active]);
        const natural = naturalTree(frequencies[0..active]);
        try std.testing.expect(natural.maximum > 15);
        try std.testing.expect(!try check(Codec, frequencies[0..active]));
    }
    var empty: [256]u4 = @splat(0xf);
    try std.testing.expect(!Codec.build(256, &.{}, &empty));
    for (empty) |bits| try std.testing.expectEqual(@as(u4, 0xf), bits);
}

/// Optional command_plan hook passes its own namespace and SmallHuffman type,
/// avoiding a reverse import of command_plan from the small builder tests.
pub fn commandIntegration(comptime PlanCodec: type, comptime Small: type) !void {
    var frequencies: [256]u32 = @splat(0);
    for ([_]usize{ 129, 159, 255, 256 }) |active| {
        @memset(&frequencies, 0);
        for (0..active) |index| frequencies[(index * 149 + 41) % 256] = @intCast(1 + index % 19);
        const alphabet = try PlanCodec.alphabetFromFrequencies(256, &frequencies);
        const ordinary = try alphabet.codeLengths(&frequencies);
        var profile: Small.BuildProfile = .{};
        const observed = try alphabet.codeLengthsProfiled(&frequencies, std.testing.io, &profile);
        try std.testing.expectEqualSlices(u4, &ordinary, &observed);
        var compact: [256]u32 = @splat(0);
        for (alphabet.symbols[0..alphabet.len], 0..) |symbol, rank| compact[rank] = frequencies[symbol];
        const reference = huffman.treeCodeLengths(256, &compact, 15);
        for (alphabet.symbols[0..alphabet.len], 0..) |symbol, rank| try std.testing.expectEqual(reference[rank], ordinary[symbol]);
        for (frequencies, ordinary) |frequency, bits| try std.testing.expectEqual(frequency != 0, bits != 0);
        try std.testing.expectEqual(@as(usize, 1), profile.calls);
        try std.testing.expectEqual(@as(usize, 0), profile.package_merge_calls);
    }
    fibonacci(&frequencies);
    const alphabet = try PlanCodec.alphabetFromFrequencies(256, &frequencies);
    const ordinary = try alphabet.codeLengths(&frequencies);
    var profile: Small.BuildProfile = .{};
    const observed = try alphabet.codeLengthsProfiled(&frequencies, std.testing.io, &profile);
    try std.testing.expectEqualSlices(u4, &ordinary, &observed);
    try std.testing.expectEqual(@as(usize, 1), profile.failures);
    try std.testing.expectEqual(@as(usize, 1), profile.package_merge_calls);
    var compact: [256]u32 = @splat(0);
    for (alphabet.symbols[0..alphabet.len], 0..) |symbol, rank| compact[rank] = frequencies[symbol];
    const reference = huffman.treeCodeLengths(256, &compact, 15);
    for (alphabet.symbols[0..alphabet.len], 0..) |symbol, rank| try std.testing.expectEqual(reference[rank], ordinary[symbol]);
}
