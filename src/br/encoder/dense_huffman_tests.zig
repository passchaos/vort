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

fn rankedDirect(
    comptime PlanCodec: type,
    comptime Small: type,
    comptime scratch_capacity: usize,
    comptime symbol_capacity: usize,
    active: usize,
    seed: u32,
    skewed: bool,
) !void {
    try std.testing.expect(active >= 5 and active <= scratch_capacity);
    var frequencies: [symbol_capacity]u32 = @splat(0);
    var support: [scratch_capacity]u16 = undefined;
    support[0] = 0;
    support[1] = symbol_capacity - 1;
    var support_len: usize = 2;
    var candidate: usize = seed % symbol_capacity;
    while (support_len < active) {
        var duplicate = false;
        for (support[0..support_len]) |symbol| {
            if (symbol == candidate) {
                duplicate = true;
                break;
            }
        }
        if (!duplicate) {
            support[support_len] = @intCast(candidate);
            support_len += 1;
        }
        candidate = (candidate + 149) % symbol_capacity;
    }

    var compact_frequencies: [scratch_capacity]u32 = @splat(0);
    if (skewed) {
        fibonacci(compact_frequencies[0..active]);
    } else {
        for (compact_frequencies[0..active], 0..) |*frequency, index|
            frequency.* = 1 + @as(u32, @intCast((index * 17 + seed) % 23));
    }
    for (support[0..active], compact_frequencies[0..active]) |symbol, frequency|
        frequencies[symbol] = frequency;
    const original = frequencies;
    const alphabet = try PlanCodec.alphabetFromFrequencies(symbol_capacity, &frequencies);
    try std.testing.expectEqual(active, alphabet.len);
    for (alphabet.symbols[0..alphabet.len], 0..) |symbol, rank|
        compact_frequencies[rank] = frequencies[symbol];

    var compact_lengths: [scratch_capacity]u4 = @splat(0xf);
    const expected_ok = Small.build(
        scratch_capacity,
        compact_frequencies[0..alphabet.len],
        &compact_lengths,
    );
    var expected: [symbol_capacity]u4 = @splat(0xf);
    if (expected_ok) {
        for (alphabet.symbols[0..alphabet.len], compact_lengths[0..alphabet.len]) |symbol, bits|
            expected[symbol] = bits;
    }

    var ordinary: [symbol_capacity]u4 = @splat(0xf);
    const ordinary_ok = Small.buildRanked(
        scratch_capacity,
        symbol_capacity,
        alphabet.symbols[0..alphabet.len],
        &frequencies,
        &ordinary,
    );
    var profiled: [symbol_capacity]u4 = @splat(0xf);
    var profile: Small.BuildProfile = .{};
    const profiled_ok = Small.buildRankedProfiled(
        scratch_capacity,
        symbol_capacity,
        alphabet.symbols[0..alphabet.len],
        &frequencies,
        &profiled,
        std.testing.io,
        &profile,
    );
    try std.testing.expectEqual(expected_ok, ordinary_ok);
    try std.testing.expectEqual(expected_ok, profiled_ok);
    try std.testing.expectEqualSlices(u4, &expected, &ordinary);
    try std.testing.expectEqualSlices(u4, &ordinary, &profiled);
    try std.testing.expectEqualSlices(u32, &original, &frequencies);
    try std.testing.expectEqual(@as(usize, 1), profile.calls);
    try std.testing.expectEqual(@as(usize, @intFromBool(!expected_ok)), profile.failures);
    try std.testing.expectEqual(@as(usize, 0), profile.package_merge_calls);
}

fn rankedFallbackIntegration(
    comptime PlanCodec: type,
    comptime Small: type,
    comptime scratch_capacity: usize,
    comptime fallback_capacity: usize,
    active: usize,
) !void {
    try std.testing.expect(active >= 5 and active <= scratch_capacity);
    var ranked_frequencies: [scratch_capacity]u32 = undefined;
    fibonacci(ranked_frequencies[0..active]);
    var frequencies: [PlanCodec.max_prefix_symbols]u32 = @splat(0);
    for (ranked_frequencies[0..active], 0..) |frequency, rank|
        frequencies[(rank * 149 + 311) % PlanCodec.max_prefix_symbols] = frequency;
    const original = frequencies;
    const alphabet = try PlanCodec.alphabetFromFrequencies(PlanCodec.max_prefix_symbols, &frequencies);
    try std.testing.expectEqual(active, alphabet.len);

    var direct: [PlanCodec.max_prefix_symbols]u4 = @splat(0xf);
    try std.testing.expect(!Small.buildRanked(
        scratch_capacity,
        PlanCodec.max_prefix_symbols,
        alphabet.symbols[0..alphabet.len],
        &frequencies,
        &direct,
    ));
    for (direct) |bits| try std.testing.expectEqual(@as(u4, 0xf), bits);

    var compact_frequencies: [fallback_capacity]u32 = @splat(0);
    for (alphabet.symbols[0..alphabet.len], 0..) |symbol, rank|
        compact_frequencies[rank] = frequencies[symbol];
    const compact_lengths = huffman.treeCodeLengths(fallback_capacity, &compact_frequencies, 15);
    var expected: [PlanCodec.max_prefix_symbols]u4 = @splat(0);
    for (alphabet.symbols[0..alphabet.len], compact_lengths[0..alphabet.len]) |symbol, bits|
        expected[symbol] = bits;

    const ordinary = try alphabet.codeLengths(&frequencies);
    var profile: Small.BuildProfile = .{};
    const profiled = try alphabet.codeLengthsProfiled(&frequencies, std.testing.io, &profile);
    try std.testing.expectEqualSlices(u32, &original, &frequencies);
    try std.testing.expectEqualSlices(u4, &expected, &ordinary);
    try std.testing.expectEqualSlices(u4, &ordinary, &profiled);
    try std.testing.expectEqual(@as(usize, 1), profile.calls);
    try std.testing.expectEqual(@as(usize, 1), profile.failures);
    try std.testing.expectEqual(@as(usize, 1), profile.package_merge_calls);
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
    try rankedDirect(PlanCodec, Small, 64, 256, 5, 0x11, false);
    try rankedDirect(PlanCodec, Small, 64, 704, 64, 0x23, false);
    try rankedDirect(PlanCodec, Small, 128, 256, 65, 0x35, false);
    try rankedDirect(PlanCodec, Small, 128, 704, 96, 0x47, false);
    try rankedDirect(PlanCodec, Small, 256, 256, 129, 0x59, false);
    try rankedDirect(PlanCodec, Small, 256, 704, 256, 0x6b, false);
    try rankedDirect(PlanCodec, Small, 64, 256, 34, 0x7d, true);
    try rankedDirect(PlanCodec, Small, 128, 704, 96, 0x8f, true);
    try rankedDirect(PlanCodec, Small, 256, 704, 192, 0xa1, true);
    try rankedFallbackIntegration(PlanCodec, Small, 64, 64, 34);
    try rankedFallbackIntegration(PlanCodec, Small, 128, 256, 96);

    var frequencies: [256]u32 = @splat(0);
    for ([_]usize{ 5, 7, 32, 64, 65, 96, 128, 129, 159, 255, 256 }) |active| {
        @memset(&frequencies, 0);
        for (0..active) |index| frequencies[(index * 149 + 41) % 256] = @intCast(1 + index % 19);
        const original = frequencies;
        const alphabet = try PlanCodec.alphabetFromFrequencies(256, &frequencies);
        const ordinary = try alphabet.codeLengths(&frequencies);
        var profile: Small.BuildProfile = .{};
        const observed = try alphabet.codeLengthsProfiled(&frequencies, std.testing.io, &profile);
        try std.testing.expectEqualSlices(u32, &original, &frequencies);
        try std.testing.expectEqualSlices(u4, &ordinary, &observed);
        var compact: [256]u32 = @splat(0);
        for (alphabet.symbols[0..alphabet.len], 0..) |symbol, rank| compact[rank] = frequencies[symbol];
        const reference = huffman.treeCodeLengths(256, &compact, 15);
        for (alphabet.symbols[0..alphabet.len], 0..) |symbol, rank| try std.testing.expectEqual(reference[rank], ordinary[symbol]);
        for (frequencies, ordinary) |frequency, bits| try std.testing.expectEqual(frequency != 0, bits != 0);
        try std.testing.expectEqual(@as(usize, 1), profile.calls);
        try std.testing.expectEqual(@as(usize, 0), profile.package_merge_calls);
    }

    var command_frequencies: [PlanCodec.max_prefix_symbols]u32 = @splat(0);
    for (0..200) |index|
        command_frequencies[(index * 149 + 311) % PlanCodec.max_prefix_symbols] = @intCast(1 + index % 23);
    const command_original = command_frequencies;
    const command_alphabet = try PlanCodec.alphabetFromFrequencies(PlanCodec.max_prefix_symbols, &command_frequencies);
    const command_lengths = try command_alphabet.codeLengths(&command_frequencies);
    var command_profile: Small.BuildProfile = .{};
    const command_profiled = try command_alphabet.codeLengthsProfiled(&command_frequencies, std.testing.io, &command_profile);
    try std.testing.expectEqualSlices(u32, &command_original, &command_frequencies);
    try std.testing.expectEqualSlices(u4, &command_lengths, &command_profiled);
    var command_compact: [256]u32 = @splat(0);
    for (command_alphabet.symbols[0..command_alphabet.len], 0..) |symbol, rank|
        command_compact[rank] = command_frequencies[symbol];
    const command_reference = huffman.treeCodeLengths(256, &command_compact, 15);
    for (command_alphabet.symbols[0..command_alphabet.len], 0..) |symbol, rank|
        try std.testing.expectEqual(command_reference[rank], command_lengths[symbol]);
    for (command_frequencies, command_lengths) |frequency, bits|
        try std.testing.expectEqual(frequency != 0, bits != 0);
    try std.testing.expectEqual(@as(usize, 1), command_profile.calls);
    try std.testing.expectEqual(@as(usize, 0), command_profile.failures);
    try std.testing.expectEqual(@as(usize, 0), command_profile.package_merge_calls);

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
