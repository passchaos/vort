//! Natural Huffman oracle using repeated global minimum-node selection, not
//! sorted leaves or merge queues. Caller injection avoids reverse imports.
const std = @import("std");

const alphabet_size = 18;
const node_capacity = 2 * alphabet_size - 1;

const Node = struct {
    weight: u128,
    symbol: ?u8,
    parent: ?usize = null,
    used: bool = false,
};

const Natural = struct {
    lengths: [alphabet_size]u8 = @splat(0),
    max_depth: u8 = 0,
    total_weight: u128 = 0,
};

fn precedes(nodes: []const Node, left: usize, right: usize) bool {
    const a = nodes[left];
    const b = nodes[right];
    if (a.weight != b.weight) return a.weight < b.weight;
    if ((a.symbol != null) != (b.symbol != null)) return a.symbol != null;
    if (a.symbol) |symbol| return symbol < b.symbol.?;
    return left < right; // Earlier generated parent wins parent-parent ties.
}

fn removeMinimum(nodes: []Node) usize {
    var best: ?usize = null;
    for (nodes, 0..) |node, index| {
        if (node.used) continue;
        if (best == null or precedes(nodes, index, best.?)) best = index;
    }
    nodes[best.?].used = true;
    return best.?;
}

fn naturalTree(frequencies: *const [alphabet_size]u32) Natural {
    var result: Natural = .{};
    var nodes: [node_capacity]Node = undefined;
    var leaf_count: usize = 0;
    for (frequencies, 0..) |weight, symbol| {
        if (weight == 0) continue;
        nodes[leaf_count] = .{ .weight = weight, .symbol = @intCast(symbol) };
        result.total_weight += weight;
        leaf_count += 1;
    }
    if (leaf_count == 0) return result;
    if (leaf_count == 1) {
        result.lengths[nodes[0].symbol.?] = 1;
        result.max_depth = 1;
        return result;
    }
    var node_count = leaf_count;
    var active = leaf_count;
    while (active > 1) : (active -= 1) {
        const first = removeMinimum(nodes[0..node_count]);
        const second = removeMinimum(nodes[0..node_count]);
        nodes[node_count] = .{ .weight = nodes[first].weight + nodes[second].weight, .symbol = null };
        nodes[first].parent = node_count;
        nodes[second].parent = node_count;
        node_count += 1;
    }
    for (nodes[0..leaf_count], 0..) |leaf, index| {
        var depth: u8 = 0;
        var current = index;
        while (nodes[current].parent) |parent| {
            depth += 1;
            current = parent;
        }
        result.lengths[leaf.symbol.?] = depth;
        result.max_depth = @max(result.max_depth, depth);
    }
    return result;
}

const Coverage = struct { cases: usize = 0, empty: usize = 0, singleton: usize = 0, bounded: usize = 0, fallback: usize = 0 };

fn compare(comptime Codec: type, frequencies: *const [alphabet_size]u32, coverage: *Coverage) !void {
    const before = frequencies.*;
    const expected = naturalTree(frequencies);
    const actual = Codec.build(frequencies);
    var active: usize = 0;
    for (frequencies) |weight| active += @intFromBool(weight != 0);
    if (expected.max_depth > 5) {
        try std.testing.expect(actual == null);
        coverage.fallback += 1;
    } else {
        const lengths = actual orelse return error.TestUnexpectedResult;
        var expected_lengths: [alphabet_size]u4 = undefined;
        for (&expected_lengths, expected.lengths) |*length, oracle| length.* = @intCast(oracle);
        try std.testing.expectEqualSlices(u4, &expected_lengths, &lengths);
        var weighted_bits: u128 = 0;
        var expected_bits: u128 = 0;
        var kraft_units: usize = 0;
        for (frequencies, lengths, expected.lengths) |weight, length, oracle| {
            weighted_bits += @as(u128, weight) * length;
            expected_bits += @as(u128, weight) * oracle;
            if (weight == 0) {
                try std.testing.expectEqual(@as(u4, 0), length);
            } else {
                try std.testing.expect(length != 0 and length <= 5);
                kraft_units += @as(usize, 1) << @intCast(5 - length);
            }
        }
        try std.testing.expectEqual(expected_bits, weighted_bits);
        try std.testing.expectEqual(@as(usize, if (active == 0) 0 else if (active == 1) 16 else 32), kraft_units);
        if (active == 0) coverage.empty += 1 else if (active == 1) coverage.singleton += 1 else coverage.bounded += 1;
    }
    try std.testing.expectEqualSlices(u32, &before, frequencies);
    coverage.cases += 1;
}

fn activeSizes(comptime Codec: type, coverage: *Coverage) !void {
    for (0..alphabet_size + 1) |active| {
        for ([_]usize{ 0, 7, 17 }) |rotation| {
            for (0..6) |pattern| {
                var frequencies: [alphabet_size]u32 = @splat(0);
                for (0..active) |ordinal| {
                    const symbol = (ordinal + rotation) % alphabet_size;
                    frequencies[symbol] = switch (pattern) {
                        0 => 1,
                        1 => std.math.maxInt(u32),
                        2 => @intCast(ordinal + 1),
                        3 => @intCast(active - ordinal),
                        4 => @as(u32, 1) << @intCast(ordinal),
                        else => if (ordinal & 1 == 0) std.math.maxInt(u32) else 1,
                    };
                }
                try compare(Codec, &frequencies, coverage);
            }
        }
    }
}

fn generatedTies(comptime Codec: type, coverage: *Coverage) !void {
    // Exhaust every small histogram on five separated symbols. Sum-created
    // parent ties, leaf-parent ties and sparse symbol ties all occur naturally.
    for (0..1024) |encoded| {
        var frequencies: [alphabet_size]u32 = @splat(0);
        var values = encoded;
        for ([_]usize{ 0, 3, 7, 12, 17 }) |symbol| {
            frequencies[symbol] = @intCast(values % 4);
            values /= 4;
        }
        try compare(Codec, &frequencies, coverage);
    }
}

fn randomWeights(comptime Codec: type, coverage: *Coverage) !void {
    var random = std.Random.DefaultPrng.init(0x636c_6875_6666_0101);
    for (0..512) |round| {
        var frequencies: [alphabet_size]u32 = undefined;
        for (&frequencies, 0..) |*frequency, symbol| {
            const value = random.random().int(u32);
            frequency.* = switch (round % 4) {
                0 => value,
                1 => if (symbol % 3 == 0) 0 else value,
                2 => std.math.maxInt(u32) - value % 11,
                else => if (symbol & 1 == 0) 1 + value % 7 else value,
            };
        }
        try compare(Codec, &frequencies, coverage);
    }
}

fn depthAndComptime(comptime Codec: type, coverage: *Coverage) !void {
    var fibonacci: [alphabet_size]u32 = @splat(0);
    fibonacci[0] = 1;
    fibonacci[1] = 1;
    for (2..alphabet_size) |symbol| fibonacci[symbol] = fibonacci[symbol - 1] + fibonacci[symbol - 2];
    try std.testing.expect(naturalTree(&fibonacci).max_depth > 5);
    try compare(Codec, &fibonacci, coverage);
    const ties = [_]u32{ 0, 1, 1, 2, 2, 4, 4, 8, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0 };
    try compare(Codec, &ties, coverage);
    const compiled = comptime Codec.build(&ties);
    const expected = comptime naturalTree(&ties);
    if (expected.max_depth > 5) {
        try std.testing.expect(compiled == null);
    } else {
        const lengths = compiled orelse return error.TestUnexpectedResult;
        for (expected.lengths, lengths) |oracle, actual| try std.testing.expectEqual(oracle, @as(u8, actual));
    }
    const full = [_]u32{std.math.maxInt(u32)} ** alphabet_size;
    const sum = naturalTree(&full).total_weight;
    try std.testing.expectEqual(@as(u128, std.math.maxInt(u32)) * alphabet_size, sum);
    try std.testing.expect(sum > std.math.maxInt(u32));
    try compare(Codec, &full, coverage);
}

pub fn check(comptime Codec: type) !void {
    var coverage: Coverage = .{};
    try activeSizes(Codec, &coverage);
    try generatedTies(Codec, &coverage);
    try randomWeights(Codec, &coverage);
    try depthAndComptime(Codec, &coverage);
    try std.testing.expect(coverage.empty != 0 and coverage.singleton != 0 and coverage.bounded != 0 and coverage.fallback != 0);
    std.debug.print("code_length_huffman oracle_cases={d} empty={d} singleton={d} bounded={d} over_depth={d}\n", .{
        coverage.cases, coverage.empty, coverage.singleton, coverage.bounded, coverage.fallback,
    });
}
