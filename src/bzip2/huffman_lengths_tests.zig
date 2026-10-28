const std = @import("std");
const codec = @import("huffman_lengths.zig");

fn cost(frequencies: []const u32, lengths: []const u5) u64 {
    var result: u64 = 0;
    for (frequencies, lengths) |frequency, length|
        result += @as(u64, @max(frequency, 1)) * length;
    return result;
}

/// Construct canonical integers independently, then compare all prefixes.
fn canonical(lengths: []const u5) !void {
    var counts: [21]u32 = @splat(0);
    var kraft: u64 = 0;
    for (lengths) |length| {
        try std.testing.expect(length >= 1 and length <= codec.max_bits);
        counts[length] += 1;
        kraft += @as(u64, 1) << @intCast(codec.max_bits - length);
    }
    try std.testing.expectEqual(@as(u64, 1) << codec.max_bits, kraft);
    var next: [21]u32 = @splat(0);
    var value: u32 = 0;
    for (1..21) |bits| {
        value = (value + counts[bits - 1]) * 2;
        next[bits] = value;
        try std.testing.expect(value + counts[bits] <= @as(u32, 1) << @intCast(bits));
    }
    var codes: [codec.max_symbols]u32 = undefined;
    for (lengths, 0..) |length, symbol| {
        codes[symbol] = next[length];
        next[length] += 1;
    }
    for (lengths, 0..) |left, i| {
        for (lengths[i + 1 ..], i + 1..) |right, j| {
            const width = @min(left, right);
            try std.testing.expect(codes[i] >> @intCast(left - width) != codes[j] >> @intCast(right - width));
        }
    }
}

fn verify(frequencies: []const u32) !u64 {
    var first: [codec.max_symbols]u5 = undefined;
    var second: [codec.max_symbols]u5 = undefined;
    const lengths = first[0..frequencies.len];
    try codec.build(frequencies, lengths);
    try codec.build(frequencies, second[0..frequencies.len]);
    try std.testing.expectEqualSlices(u5, lengths, second[0..frequencies.len]);
    try canonical(lengths);
    return cost(frequencies, lengths);
}

/// Exhaustive length vectors, with highest weights assigned shorter lengths.
/// This enumerates prefix-code shapes rather than reproducing a tree builder.
fn bruteCost(frequencies: []const u32) u64 {
    var weights: [8]u32 = undefined;
    for (frequencies, weights[0..frequencies.len]) |frequency, *weight| weight.* = @max(frequency, 1);
    std.mem.sort(u32, weights[0..frequencies.len], {}, std.sort.desc(u32));
    const limit: u5 = @intCast(frequencies.len - 1);
    var best: u64 = std.math.maxInt(u64);
    enumerate(weights[0..frequencies.len], limit, 0, 1, @as(u32, 1) << limit, 0, &best);
    return best;
}

fn enumerate(weights: []const u32, limit: u5, index: usize, minimum: u5, remaining: u32, spent: u64, best: *u64) void {
    if (index == weights.len) {
        if (remaining == 0) best.* = @min(best.*, spent);
        return;
    }
    if (spent >= best.*) return;
    var bits = minimum;
    while (bits <= limit) : (bits += 1) {
        const space = @as(u32, 1) << @intCast(limit - bits);
        if (space > remaining) continue;
        const after = remaining - space;
        const symbols_left = weights.len - index - 1;
        if (after < symbols_left or after > symbols_left * @as(usize, space)) continue;
        enumerate(weights, limit, index + 1, bits, after, spent + @as(u64, weights[index]) * bits, best);
    }
}

/// Independent constrained optimum by enumerating the leaf count at each
/// depth. State records assigned symbols and available tree slots, not packages.
fn depthCountCost(frequencies: []const u32, limit: usize) u64 {
    const capacity = 48;
    std.debug.assert(frequencies.len <= capacity);
    var weights: [capacity]u32 = undefined;
    for (frequencies, weights[0..frequencies.len]) |frequency, *weight| weight.* = @max(frequency, 1);
    std.mem.sort(u32, weights[0..frequencies.len], {}, std.sort.desc(u32));
    var prefix: [capacity + 1]u64 = undefined;
    prefix[0] = 0;
    for (weights[0..frequencies.len], 0..) |weight, index| prefix[index + 1] = prefix[index] + weight;
    const State = [capacity + 1][capacity + 1]u64;
    var current: State = @splat(@splat(std.math.maxInt(u64)));
    var next: State = undefined;
    current[0][2] = 0;
    const n = frequencies.len;
    for (1..limit + 1) |depth| {
        next = @splat(@splat(std.math.maxInt(u64)));
        for (0..n + 1) |assigned| {
            for (0..n - assigned + 1) |slots| {
                const before = current[assigned][slots];
                if (before == std.math.maxInt(u64)) continue;
                for (0..@min(slots, n - assigned) + 1) |leaves| {
                    const after_assigned = assigned + leaves;
                    const after_slots = 2 * (slots - leaves);
                    if (after_slots > n - after_assigned) continue;
                    if (depth == limit and (after_slots != 0 or after_assigned != n)) continue;
                    const after = before + (prefix[after_assigned] - prefix[assigned]) * depth;
                    next[after_assigned][after_slots] = @min(next[after_assigned][after_slots], after);
                }
            }
        }
        std.mem.swap(State, &current, &next);
    }
    return current[n][0];
}

/// A slow forest scan detects unrestricted depth independently of the
/// production sorted two-queue construction. It also covers the full alphabet.
fn naturalDepth(frequencies: []const u32) usize {
    const capacity = 2 * codec.max_symbols - 1;
    var weights: [capacity]u64 = @splat(std.math.maxInt(u64));
    var parents: [capacity]u16 = undefined;
    var depths: [capacity]usize = undefined;
    const n = frequencies.len;
    for (frequencies, 0..) |frequency, symbol| weights[symbol] = @max(frequency, 1);
    for (n..2 * n - 1) |parent| {
        var first: usize = 0;
        for (0..parent) |index| if (weights[index] < weights[first]) {
            first = index;
        };
        const first_weight = weights[first];
        weights[first] = std.math.maxInt(u64);
        var second: usize = 0;
        for (0..parent) |index| if (weights[index] < weights[second]) {
            second = index;
        };
        weights[parent] = first_weight + weights[second];
        weights[second] = std.math.maxInt(u64);
        parents[first] = @intCast(parent);
        parents[second] = @intCast(parent);
    }
    depths[2 * n - 2] = 0;
    var index = 2 * n - 2;
    while (index != 0) {
        index -= 1;
        depths[index] = depths[parents[index]] + 1;
    }
    return std.mem.max(usize, depths[0..n]);
}

test "Bzip2 Huffman lengths validate shape without changing output" {
    var lengths: [259]u5 = @splat(17);
    const frequencies: [259]u32 = @splat(0);
    for ([_]usize{ 0, 1, 2, 259 }) |n| {
        try std.testing.expectError(error.InvalidBzip2HuffmanLengths, codec.build(frequencies[0..n], lengths[0..n]));
        for (lengths) |length| try std.testing.expectEqual(@as(u5, 17), length);
    }
    try std.testing.expectError(error.InvalidBzip2HuffmanLengths, codec.build(frequencies[0..3], lengths[0..4]));
    try std.testing.expectError(error.InvalidBzip2HuffmanLengths, codec.build(frequencies[0..4], lengths[0..3]));
    for (lengths) |length| try std.testing.expectEqual(@as(u5, 17), length);
}

test "Bzip2 Huffman positive smoothing and stable equal-weight ties" {
    var lengths: [3]u5 = undefined;
    for ([_][3]u32{ .{ 0, 0, 0 }, .{ 1, 1, 1 }, .{ 9, 9, 9 } }) |frequencies| {
        try codec.build(&frequencies, &lengths);
        try std.testing.expectEqualSlices(u5, &.{ 2, 2, 1 }, &lengths);
        try canonical(&lengths);
    }
    try codec.build(&.{ 900_001, 0, 0 }, &lengths);
    try std.testing.expectEqualSlices(u5, &.{ 1, 2, 2 }, &lengths);
    try std.testing.expectEqual(@as(u64, 900_005), cost(&.{ 900_001, 0, 0 }, &lengths));
}

test "Bzip2 Huffman full alphabet handles equal zero uniform and skewed weights" {
    var frequencies: [codec.max_symbols]u32 = @splat(0);
    try std.testing.expectEqual(@as(u64, 2068), try verify(&frequencies));
    frequencies = @splat(1);
    try std.testing.expectEqual(@as(u64, 2068), try verify(&frequencies));
    frequencies = @splat(37);
    try std.testing.expectEqual(@as(u64, 2068 * 37), try verify(&frequencies));
    frequencies = @splat(0);
    frequencies[257] = 900_001;
    _ = try verify(&frequencies);
    frequencies = @splat(std.math.maxInt(u32));
    try std.testing.expectEqual(@as(u64, 2068) * std.math.maxInt(u32), try verify(&frequencies));
}

test "Bzip2 Huffman lengths match independent small-alphabet brute optimal costs" {
    var state: u32 = 0x35de_27a9;
    for (3..9) |n| {
        var frequencies: [8]u32 = undefined;
        for (0..32) |round| {
            for (frequencies[0..n], 0..) |*frequency, symbol| {
                state = state *% 1_664_525 +% 1_013_904_223;
                frequency.* = if (round % 3 == 0) state % 4 else if (symbol == round % n) 10_000 else state % 41;
            }
            try std.testing.expectEqual(bruteCost(frequencies[0..n]), try verify(frequencies[0..n]));
            try std.testing.expectEqual(bruteCost(frequencies[0..n]), depthCountCost(frequencies[0..n], n - 1));
        }
    }
}

test "Bzip2 Huffman Fibonacci invokes the bounded optimal package fallback" {
    var frequencies: [27]u32 = undefined;
    frequencies[0] = 1;
    frequencies[1] = 1;
    for (2..frequencies.len) |index| frequencies[index] = frequencies[index - 1] + frequencies[index - 2];
    var total: u64 = 0;
    for (frequencies) |frequency| total += frequency;
    try std.testing.expectEqual(@as(u64, 514_228), total);
    // Fibonacci's unrestricted tree has depth 26. Its constrained optimum
    // strictly exceeds that unrestricted optimum, so this proves limiting.
    const unrestricted = depthCountCost(&frequencies, frequencies.len - 1);
    const bounded = depthCountCost(&frequencies, codec.max_bits);
    try std.testing.expect(bounded > unrestricted);
    try std.testing.expectEqual(bounded, try verify(&frequencies));
    var lengths: [27]u5 = undefined;
    try codec.build(&frequencies, &lengths);
    try std.testing.expectEqual(codec.max_bits, std.mem.max(u5, &lengths));
}

test "Bzip2 Huffman maximum alphabet and large Fibonacci weights exercise bounded recovery" {
    // Heavy remaining symbols keep the Fibonacci subtree deep instead of
    // balancing it with additional smoothed one-weight leaves.
    var frequencies: [codec.max_symbols]u32 = @splat(std.math.maxInt(u32));
    frequencies[0] = 1;
    frequencies[1] = 1;
    for (2..27) |index| frequencies[index] = frequencies[index - 1] + frequencies[index - 2];
    try std.testing.expect(naturalDepth(&frequencies) > codec.max_bits);
    _ = try verify(&frequencies);
    var lengths: [codec.max_symbols]u5 = undefined;
    try codec.build(&frequencies, &lengths);
    try std.testing.expectEqual(codec.max_bits, std.mem.max(u5, &lengths));
    // The public builder supports all u32 inputs, beyond the ordinary block
    // frequency bound. Forty Fibonacci weights also verify u64 package costs.
    for (2..40) |index| frequencies[index] = frequencies[index - 1] + frequencies[index - 2];
    try std.testing.expect(naturalDepth(frequencies[0..40]) > codec.max_bits);
    try std.testing.expectEqual(depthCountCost(frequencies[0..40], codec.max_bits), try verify(frequencies[0..40]));
}

test "Bzip2 Huffman fixed-seed dense random weights remain canonical and deterministic" {
    var state: u32 = 0x6a09_e667;
    var frequencies: [codec.max_symbols]u32 = undefined;
    for (0..128) |round| {
        const n = 3 + round * 47 % 256;
        for (frequencies[0..n], 0..) |*frequency, symbol| {
            state = state *% 1_664_525 +% 1_013_904_223;
            frequency.* = switch (round % 4) {
                0 => state % 7,
                1 => state % 4096,
                2 => if (symbol == round % n) 900_001 else 0,
                else => state,
            };
        }
        _ = try verify(frequencies[0..n]);
    }
}
