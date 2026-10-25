//! Independent medium-alphabet checks. Old DAG traversal supplies creation
//! serial tie order; full-width packed planning verifies optimal cost.
//! This helper never imports the parent Huffman module.
const std = @import("std");
const Frequency = struct { symbol: u8, count: u32 };

// Independently counted bytes from silesia-xml-65536.bin;
// SHA-256 e32aff2bebf00105a17dd57f5490c1986d17543cee837b42eb56b3e0e6f8e7f1.
const xml_frequencies = [_]Frequency{
    .{ .symbol = 0, .count = 430 },
    .{ .symbol = 13, .count = 1939 },
    .{ .symbol = 32, .count = 9137 },
    .{ .symbol = 33, .count = 113 },
    .{ .symbol = 34, .count = 1070 },
    .{ .symbol = 39, .count = 2 },
    .{ .symbol = 43, .count = 8 },
    .{ .symbol = 44, .count = 44 },
    .{ .symbol = 45, .count = 461 },
    .{ .symbol = 46, .count = 568 },
    .{ .symbol = 47, .count = 1527 },
    .{ .symbol = 48, .count = 535 },
    .{ .symbol = 49, .count = 578 },
    .{ .symbol = 50, .count = 400 },
    .{ .symbol = 51, .count = 423 },
    .{ .symbol = 52, .count = 262 },
    .{ .symbol = 53, .count = 288 },
    .{ .symbol = 54, .count = 235 },
    .{ .symbol = 55, .count = 256 },
    .{ .symbol = 56, .count = 204 },
    .{ .symbol = 57, .count = 218 },
    .{ .symbol = 60, .count = 2303 },
    .{ .symbol = 61, .count = 536 },
    .{ .symbol = 62, .count = 2303 },
    .{ .symbol = 63, .count = 2 },
    .{ .symbol = 65, .count = 2813 },
    .{ .symbol = 66, .count = 383 },
    .{ .symbol = 67, .count = 1619 },
    .{ .symbol = 68, .count = 543 },
    .{ .symbol = 69, .count = 2201 },
    .{ .symbol = 70, .count = 535 },
    .{ .symbol = 71, .count = 616 },
    .{ .symbol = 72, .count = 565 },
    .{ .symbol = 73, .count = 4035 },
    .{ .symbol = 74, .count = 50 },
    .{ .symbol = 75, .count = 345 },
    .{ .symbol = 76, .count = 1060 },
    .{ .symbol = 77, .count = 1352 },
    .{ .symbol = 78, .count = 2755 },
    .{ .symbol = 79, .count = 2969 },
    .{ .symbol = 80, .count = 646 },
    .{ .symbol = 82, .count = 956 },
    .{ .symbol = 83, .count = 1389 },
    .{ .symbol = 84, .count = 3980 },
    .{ .symbol = 85, .count = 1319 },
    .{ .symbol = 86, .count = 548 },
    .{ .symbol = 87, .count = 193 },
    .{ .symbol = 88, .count = 122 },
    .{ .symbol = 89, .count = 576 },
    .{ .symbol = 90, .count = 220 },
    .{ .symbol = 91, .count = 56 },
    .{ .symbol = 93, .count = 56 },
    .{ .symbol = 95, .count = 1872 },
    .{ .symbol = 97, .count = 189 },
    .{ .symbol = 98, .count = 114 },
    .{ .symbol = 99, .count = 323 },
    .{ .symbol = 100, .count = 160 },
    .{ .symbol = 101, .count = 1362 },
    .{ .symbol = 102, .count = 31 },
    .{ .symbol = 103, .count = 322 },
    .{ .symbol = 104, .count = 9 },
    .{ .symbol = 105, .count = 597 },
    .{ .symbol = 106, .count = 102 },
    .{ .symbol = 107, .count = 103 },
    .{ .symbol = 108, .count = 649 },
    .{ .symbol = 109, .count = 581 },
    .{ .symbol = 110, .count = 486 },
    .{ .symbol = 111, .count = 539 },
    .{ .symbol = 112, .count = 24 },
    .{ .symbol = 114, .count = 541 },
    .{ .symbol = 115, .count = 611 },
    .{ .symbol = 116, .count = 626 },
    .{ .symbol = 117, .count = 312 },
    .{ .symbol = 118, .count = 225 },
    .{ .symbol = 119, .count = 1 },
    .{ .symbol = 120, .count = 2 },
    .{ .symbol = 121, .count = 11 },
};

// Independently counted bytes from brotli-source-65536.bin;
// SHA-256 756844ce2536d939ccf7f698f894a3763530df3c471345f0de90ab8f25e47684.
const source_frequencies = [_]Frequency{
    .{ .symbol = 10, .count = 1419 },
    .{ .symbol = 32, .count = 13073 },
    .{ .symbol = 33, .count = 56 },
    .{ .symbol = 34, .count = 174 },
    .{ .symbol = 38, .count = 43 },
    .{ .symbol = 39, .count = 6 },
    .{ .symbol = 40, .count = 403 },
    .{ .symbol = 41, .count = 402 },
    .{ .symbol = 42, .count = 62 },
    .{ .symbol = 43, .count = 16 },
    .{ .symbol = 44, .count = 592 },
    .{ .symbol = 45, .count = 56 },
    .{ .symbol = 46, .count = 908 },
    .{ .symbol = 47, .count = 398 },
    .{ .symbol = 48, .count = 124 },
    .{ .symbol = 49, .count = 109 },
    .{ .symbol = 50, .count = 50 },
    .{ .symbol = 51, .count = 18 },
    .{ .symbol = 52, .count = 39 },
    .{ .symbol = 53, .count = 14 },
    .{ .symbol = 54, .count = 75 },
    .{ .symbol = 55, .count = 15 },
    .{ .symbol = 56, .count = 70 },
    .{ .symbol = 57, .count = 9 },
    .{ .symbol = 58, .count = 297 },
    .{ .symbol = 59, .count = 426 },
    .{ .symbol = 60, .count = 24 },
    .{ .symbol = 61, .count = 606 },
    .{ .symbol = 62, .count = 56 },
    .{ .symbol = 63, .count = 26 },
    .{ .symbol = 64, .count = 96 },
    .{ .symbol = 65, .count = 42 },
    .{ .symbol = 66, .count = 70 },
    .{ .symbol = 67, .count = 118 },
    .{ .symbol = 68, .count = 131 },
    .{ .symbol = 69, .count = 71 },
    .{ .symbol = 70, .count = 39 },
    .{ .symbol = 71, .count = 6 },
    .{ .symbol = 72, .count = 40 },
    .{ .symbol = 73, .count = 66 },
    .{ .symbol = 75, .count = 2 },
    .{ .symbol = 76, .count = 40 },
    .{ .symbol = 77, .count = 31 },
    .{ .symbol = 78, .count = 11 },
    .{ .symbol = 79, .count = 84 },
    .{ .symbol = 80, .count = 82 },
    .{ .symbol = 81, .count = 5 },
    .{ .symbol = 82, .count = 24 },
    .{ .symbol = 83, .count = 280 },
    .{ .symbol = 84, .count = 103 },
    .{ .symbol = 85, .count = 9 },
    .{ .symbol = 86, .count = 4 },
    .{ .symbol = 87, .count = 45 },
    .{ .symbol = 88, .count = 1 },
    .{ .symbol = 90, .count = 2 },
    .{ .symbol = 91, .count = 111 },
    .{ .symbol = 93, .count = 111 },
    .{ .symbol = 95, .count = 1935 },
    .{ .symbol = 96, .count = 10 },
    .{ .symbol = 97, .count = 2995 },
    .{ .symbol = 98, .count = 618 },
    .{ .symbol = 99, .count = 2078 },
    .{ .symbol = 100, .count = 2187 },
    .{ .symbol = 101, .count = 4578 },
    .{ .symbol = 102, .count = 759 },
    .{ .symbol = 103, .count = 422 },
    .{ .symbol = 104, .count = 572 },
    .{ .symbol = 105, .count = 3488 },
    .{ .symbol = 106, .count = 4 },
    .{ .symbol = 107, .count = 209 },
    .{ .symbol = 108, .count = 1858 },
    .{ .symbol = 109, .count = 992 },
    .{ .symbol = 110, .count = 3035 },
    .{ .symbol = 111, .count = 3444 },
    .{ .symbol = 112, .count = 1241 },
    .{ .symbol = 113, .count = 69 },
    .{ .symbol = 114, .count = 3866 },
    .{ .symbol = 115, .count = 2563 },
    .{ .symbol = 116, .count = 3651 },
    .{ .symbol = 117, .count = 1193 },
    .{ .symbol = 118, .count = 401 },
    .{ .symbol = 119, .count = 329 },
    .{ .symbol = 120, .count = 418 },
    .{ .symbol = 121, .count = 556 },
    .{ .symbol = 122, .count = 433 },
    .{ .symbol = 123, .count = 155 },
    .{ .symbol = 124, .count = 134 },
    .{ .symbol = 125, .count = 153 },
};

fn fromPairs(pairs: []const Frequency) [256]u32 {
    var frequencies: [256]u32 = @splat(0);
    for (pairs) |pair| frequencies[pair.symbol] = pair.count;
    return frequencies;
}

fn compare(comptime Codec: type, frequencies: *const [256]u32, expected_active: usize, max_bits: u4) ![256]u4 {
    var active: [256]u16 = undefined;
    var active_len: usize = 0;
    for (frequencies, 0..) |frequency, symbol| {
        if (frequency == 0) continue;
        active[active_len] = @intCast(symbol);
        active_len += 1;
    }
    try std.testing.expectEqual(expected_active, active_len);
    const full_width = Codec.treeCodeLengthsFullWidth(256, frequencies, max_bits);
    const reference = if (active_len <= 64)
        full_width
    else
        Codec.treeCodeLengthsBackrefTraversal(256, frequencies, max_bits);
    const actual = Codec.treeCodeLengthsKnownActive(256, frequencies, max_bits, active[0..active_len]);
    try std.testing.expectEqualSlices(u4, &reference, &actual);
    const scanned = Codec.treeCodeLengths(256, frequencies, max_bits);
    try std.testing.expectEqualSlices(u4, &scanned, &actual);
    var kraft: usize = 0;
    var cost: u64 = 0;
    for (frequencies, actual, reference) |frequency, bits, reference_bits| {
        try std.testing.expectEqual(frequency != 0, bits != 0);
        if (bits == 0) continue;
        try std.testing.expect(bits <= max_bits);
        kraft += @as(usize, 1) << @intCast(max_bits - bits);
        cost += @as(u64, frequency) * bits;
        try std.testing.expectEqual(reference_bits, bits);
    }
    try std.testing.expectEqual(@as(usize, 1) << max_bits, kraft);
    var reference_cost: u64 = 0;
    for (frequencies, reference) |frequency, bits| reference_cost += @as(u64, frequency) * bits;
    try std.testing.expectEqual(reference_cost, cost);
    // Reusing the trusted list must preserve deterministic tie assignment.
    const repeated = Codec.treeCodeLengthsKnownActive(256, frequencies, max_bits, active[0..active_len]);
    try std.testing.expectEqualSlices(u4, &actual, &repeated);
    var full_width_cost: u64 = 0;
    var full_width_kraft: usize = 0;
    for (frequencies, full_width) |frequency, bits| {
        full_width_cost += @as(u64, frequency) * bits;
        if (bits != 0) full_width_kraft += @as(usize, 1) << @intCast(max_bits - bits);
    }
    try std.testing.expectEqual(full_width_cost, cost);
    try std.testing.expectEqual(@as(usize, 1) << max_bits, full_width_kraft);
    return actual;
}

const Pattern = enum { equal, ties, skew, near_max, random };
fn makeFrequencies(active_count: usize, pattern: Pattern, seed: u32) [256]u32 {
    var frequencies: [256]u32 = @splat(0);
    var state = seed;
    for (0..active_count) |index| {
        // Symbol 255 is always active; the others form holes throughout the
        // alphabet. Multiplication by 149 permutes the remaining 255 symbols.
        const symbol = if (index == 0) 255 else ((index - 1) * 149 + 37) % 255;
        state = state *% 1664525 +% 1013904223;
        frequencies[symbol] = switch (pattern) {
            .equal => 17,
            .ties => @intCast(1 + index % 5),
            .skew => if (index < active_count - 20) 1 else @as(u32, 1) << @intCast(index - (active_count - 20)),
            .near_max => std.math.maxInt(u32) - @as(u32, @intCast(index % 7)),
            .random => 1 + (state >> 16),
        };
    }
    return frequencies;
}

pub fn mediumAlphabet(comptime Codec: type) !void {
    // Packed full-width recovery and back-reference creation-order recovery
    // may assign different lengths at tied weights. Keep this concrete case
    // to distinguish exact old-wire checks from independent optimal costs.
    var tied: [256]u32 = @splat(0);
    for (0..65) |index| tied[(index * 149 + 41) % 256] = @intCast(1 + (index * 7) % 9);
    const packed_lengths = Codec.treeCodeLengthsFullWidth(256, &tied, 11);
    const old_serial = Codec.treeCodeLengthsBackrefTraversal(256, &tied, 11);
    try std.testing.expect(!std.mem.eql(u4, &packed_lengths, &old_serial));
    _ = try compare(Codec, &tied, 65, 11);
    // Real 64 KiB corpus histograms, independently captured before the new
    // planner. Their active symbols are exactly XML 77 and source code 88.
    const xml = fromPairs(&xml_frequencies);
    const source = fromPairs(&source_frequencies);
    _ = try compare(Codec, &xml, 77, 11);
    _ = try compare(Codec, &source, 88, 11);

    for ([_]usize{ 65, 66, 77, 88, 96, 127 }) |active_count| {
        for (std.enums.values(Pattern)) |pattern| {
            const frequencies = makeFrequencies(active_count, pattern, 0x6a09e667);
            _ = try compare(Codec, &frequencies, active_count, 11);
        }
        for ([_]u32{ 1, 17, 0x243f6a88 }) |seed| {
            const frequencies = makeFrequencies(active_count, .random, seed);
            _ = try compare(Codec, &frequencies, active_count, 11);
        }
    }

    // The natural skewed trees exceed 11 bits. Preserve exact old serial
    // lengths and independently check full-width optimal weighted cost.
    const skew = makeFrequencies(96, .skew, 1);
    const natural = Codec.treeCodeLengthsFullWidth(256, &skew, 15);
    var natural_max: u4 = 0;
    for (natural) |bits| natural_max = @max(natural_max, bits);
    try std.testing.expect(natural_max > 11);
    const limited = try compare(Codec, &skew, 96, 11);
    var limited_max: u4 = 0;
    for (limited) |bits| limited_max = @max(limited_max, bits);
    try std.testing.expectEqual(@as(u4, 11), limited_max);

    // max_bits policies outside the new 11-bit specialization and the lower
    // active-count boundary continue through their established planners.
    for ([_]usize{ 64, 65, 127 }) |active_count| {
        const frequencies = makeFrequencies(active_count, .ties, 19);
        for ([_]u4{ 7, 8, 11, 15 }) |max_bits|
            _ = try compare(Codec, &frequencies, active_count, max_bits);
    }
    const all_max = makeFrequencies(127, .near_max, 0);
    var total: u64 = 0;
    for (all_max) |frequency| total += frequency;
    try std.testing.expect(total > std.math.maxInt(u32));
    _ = try compare(Codec, &all_max, 127, 11);
}
