//! Exact bounded Deflate64 dynamic-Huffman plan. A single unchanged greedy
//! pass gathers real symbols and fixed cost; tree completion modifies copies.
//! No token array, borrowed tree storage or allocator is retained in the plan.
const std = @import("std");
const huffman = @import("../huffman.zig");
const rle = @import("../deflate/dynamic/code_length_rle.zig");
const matching = @import("stream_match.zig");
const codes = @import("codes.zig");

pub const Error = error{InvalidBlockPlan};
pub const max_block_len: usize = 128 * 1024;
pub const Stats = struct {
    match_count: usize = 0,
    max_match_length: usize = 0,
    max_match_distance: usize = 0,
};
pub const DynamicPlan = struct {
    bits: usize,
    fixed_bits: usize,
    stats: Stats,
    header_bits: usize,
    payload_bits: usize,
    hlit: usize,
    hdist: usize,
    hclen: usize,
    literal_lengths: [286]u4,
    distance_lengths: [32]u4,
    code_length_lengths: [19]u4,
    literal_encoder: huffman.HuffmanTable(286).Encoder,
    distance_encoder: huffman.HuffmanTable(32).Encoder,
    code_length_encoder: huffman.HuffmanTable(19).Encoder,
    code_length_ops: rle.PlanFor(318),
};

/// Matcher storage must already cover history+block. Empty input does not
/// touch it. All unchecked histogram/cost sums below are bounded by 128KiB
/// input and the Deflate64 code widths; hostile spans are rejected first.
pub fn plan(matcher: *matching.Matcher, history: []const u8, block: []const u8, max_chain: usize, nice_length: usize) Error!DynamicPlan {
    if (history.len > matching.window_len or block.len > max_block_len) return error.InvalidBlockPlan;
    var literal_frequencies: [286]u32 = @splat(0);
    var distance_frequencies: [32]u32 = @splat(0);
    literal_frequencies[256] = 1; // Exactly one real EOB per block.
    var extra_bits: usize = 0;
    var fixed_bits: usize = 3 + 7;
    var stats: Stats = .{};
    if (block.len != 0) {
        matcher.begin(history, block);
        var position: usize = 0;
        while (position < block.len) {
            const current = history.len + position;
            const match = matcher.find(current, max_chain, nice_length);
            const take = if (match.length >= 3) match.length else 1;
            if (match.length >= 3) {
                const length = codes.lengthCode(match.length);
                const distance = codes.distanceCode(match.distance);
                literal_frequencies[length.symbol] += 1;
                distance_frequencies[distance.symbol] += 1;
                extra_bits += @as(usize, length.bits) + distance.bits;
                fixed_bits += @as(usize, huffman.fixed_literal_encoder.bits[length.symbol]) + length.bits + 5 + distance.bits;
                stats.match_count += 1;
                stats.max_match_length = @max(stats.max_match_length, match.length);
                stats.max_match_distance = @max(stats.max_match_distance, match.distance);
            } else {
                literal_frequencies[block[position]] += 1;
                fixed_bits += huffman.fixed_literal_encoder.bits[block[position]];
            }
            for (current..current + take) |inserted| matcher.insert(inserted);
            position += take;
        }
    }

    // Complete zero/one-symbol trees with the lowest absent symbols. Never
    // charge these synthetic frequencies as emitted payload or RLE operations.
    var literal_tree_frequencies = literal_frequencies;
    var distance_tree_frequencies = distance_frequencies;
    complete(286, &literal_tree_frequencies);
    complete(32, &distance_tree_frequencies);
    const literal_lengths = huffman.treeCodeLengths(286, &literal_tree_frequencies, 15);
    const distance_lengths = huffman.treeCodeLengths(32, &distance_tree_frequencies, 15);
    const hlit = trimmedCount(286, 257, &literal_lengths);
    const hdist = trimmedCount(32, 1, &distance_lengths);
    const code_length_ops = try rle.buildFor(318, literal_lengths[0..hlit], distance_lengths[0..hdist]);
    var code_length_tree_frequencies = code_length_ops.frequencies;
    complete(19, &code_length_tree_frequencies);
    const code_length_lengths = huffman.treeCodeLengths(19, &code_length_tree_frequencies, 7);
    var hclen: usize = 4;
    for (huffman.code_length_order, 0..) |symbol, index| {
        if (code_length_lengths[symbol] != 0) hclen = @max(hclen, index + 1);
    }
    const literal_encoder = huffman.HuffmanTable(286).Encoder.init(&literal_lengths) catch return error.InvalidBlockPlan;
    const distance_encoder = huffman.HuffmanTable(32).Encoder.init(&distance_lengths) catch return error.InvalidBlockPlan;
    const code_length_encoder = huffman.HuffmanTable(19).Encoder.init(&code_length_lengths) catch return error.InvalidBlockPlan;
    const header_bits = 3 + 5 + 5 + 4 + 3 * hclen +
        weighted(19, &code_length_ops.frequencies, &code_length_lengths) + code_length_ops.extra_bit_count;
    const payload_bits = weighted(286, &literal_frequencies, &literal_lengths) +
        weighted(32, &distance_frequencies, &distance_lengths) + extra_bits;
    return .{
        .bits = header_bits + payload_bits,
        .fixed_bits = fixed_bits,
        .stats = stats,
        .header_bits = header_bits,
        .payload_bits = payload_bits,
        .hlit = hlit,
        .hdist = hdist,
        .hclen = hclen,
        .literal_lengths = literal_lengths,
        .distance_lengths = distance_lengths,
        .code_length_lengths = code_length_lengths,
        .literal_encoder = literal_encoder,
        .distance_encoder = distance_encoder,
        .code_length_encoder = code_length_encoder,
        .code_length_ops = code_length_ops,
    };
}

fn complete(comptime count: usize, frequencies: *[count]u32) void {
    var active: usize = 0;
    for (frequencies) |frequency| active += @intFromBool(frequency != 0);
    if (active >= 2) return;
    for (frequencies) |*frequency| {
        if (frequency.* != 0) continue;
        frequency.* = 1;
        active += 1;
        if (active == 2) return;
    }
}
fn trimmedCount(comptime count: usize, minimum: usize, lengths: *const [count]u4) usize {
    var end = count;
    while (end > minimum and lengths[end - 1] == 0) end -= 1;
    return end;
}
fn weighted(comptime count: usize, frequencies: *const [count]u32, lengths: *const [count]u4) usize {
    var bits: usize = 0;
    for (frequencies, lengths) |frequency, length| bits += @as(usize, frequency) * length;
    return bits;
}
