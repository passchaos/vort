const std = @import("std");
const huffman = @import("../../huffman.zig");

const alphabet_size: usize = 79;
const min_block_symbols: usize = 512;
const max_split_symbols: usize = 32 * 1024;
const candidate_count: usize = 5;
const min_estimated_savings_bits: u64 = 2200;
const min_entropy_proposal_savings_bits: u64 = 2250;
const min_three_over_two_savings_bits: u64 = 1024;
const min_four_over_best_savings_bits: u64 = 1024;
const entropy_fraction_bits: u6 = 8;
const entropy_scale: u64 = 1 << entropy_fraction_bits;

const log2_fraction_q8 = blk: {
    var table: [256]u16 = undefined;
    for (&table, 0..) |*entry, i| {
        const value = 1.0 + @as(f64, @floatFromInt(i)) / 256.0;
        entry.* = @intFromFloat(@round(@log2(value) * 256.0));
    }
    break :blk table;
};

pub const Result = struct {
    split: usize,
    second_split: ?usize = null,
    third_split: ?usize = null,
    savings_bits: u64,

    pub fn regionCount(self: Result) usize {
        return if (self.third_split != null) 4 else if (self.second_split != null) 3 else 2;
    }

    pub fn blockIndex(self: Result, symbol_index: usize) usize {
        if (symbol_index < self.split) return 0;
        if (self.second_split) |second| {
            if (symbol_index < second) return 1;
            if (self.third_split) |third| return if (symbol_index < third) 2 else 3;
            return 2;
        }
        return 1;
    }
};

pub const Proposals = struct {
    two: ?Result = null,
    three: ?Result = null,
    four: ?Result = null,
};

pub fn eligible(symbol_count: usize) bool {
    return symbol_count >= 2 * min_block_symbols and symbol_count <= max_split_symbols;
}

pub fn choose(symbols: []const u16) ?Result {
    return chooseProposals(symbols).two;
}

pub fn chooseProposals(symbols: []const u16) Proposals {
    if (!eligible(symbols.len)) return .{};
    var total: [alphabet_size]u32 = @splat(0);
    var prefixes: [candidate_count][alphabet_size]u32 = undefined;
    var targets: [candidate_count]usize = undefined;
    for (1..candidate_count + 1) |i| targets[i - 1] = symbols.len * i / (candidate_count + 1);
    var target_index: usize = 0;
    for (symbols, 1..) |symbol, count| {
        if (symbol >= alphabet_size) return .{};
        total[symbol] += 1;
        if (target_index < targets.len and count == targets[target_index]) {
            prefixes[target_index] = total;
            target_index += 1;
        }
    }
    if (target_index != targets.len) return .{};

    const baseline_entropy = entropyBitsQ8(&total);
    var best_split: usize = 0;
    var best_entropy = baseline_entropy;
    var best_prefix: [alphabet_size]u32 = undefined;
    for (prefixes, targets) |prefix, split| {
        var suffix: [alphabet_size]u32 = undefined;
        for (&suffix, &total, &prefix) |*out, all, before| out.* = all - before;
        const split_entropy = entropyBitsQ8(&prefix) + entropyBitsQ8(&suffix);
        if (split_entropy < best_entropy) {
            best_entropy = split_entropy;
            best_split = split;
            best_prefix = prefix;
        }
    }
    if (best_split == 0 or baseline_entropy - best_entropy < min_entropy_proposal_savings_bits * entropy_scale) return .{};

    var best_suffix: [alphabet_size]u32 = undefined;
    for (&best_suffix, &total, &best_prefix) |*out, all, before| out.* = all - before;
    const baseline_lengths = huffman.treeCodeLengths(alphabet_size, &total, 15);
    const prefix_lengths = huffman.treeCodeLengths(alphabet_size, &best_prefix, 15);
    const two_suffix_lengths = huffman.treeCodeLengths(alphabet_size, &best_suffix, 15);
    const baseline_bits = weightedBits(&total, &baseline_lengths);
    const split_bits = weightedBits(&best_prefix, &prefix_lengths) + weightedBits(&best_suffix, &two_suffix_lengths);
    if (split_bits >= baseline_bits or baseline_bits - split_bits < min_estimated_savings_bits) return .{};
    var proposals = Proposals{ .two = .{ .split = best_split, .savings_bits = baseline_bits - split_bits } };

    var best_three_entropy = baseline_entropy;
    var best_three_indexes: [2]usize = @splat(candidate_count);
    for (0..candidate_count) |first_index| {
        for (first_index + 1..candidate_count) |second_index| {
            const first_split = targets[first_index];
            const second_split = targets[second_index];
            if (first_split < min_block_symbols or
                second_split - first_split < min_block_symbols or
                symbols.len - second_split < min_block_symbols)
                continue;
            var middle: [alphabet_size]u32 = undefined;
            var suffix: [alphabet_size]u32 = undefined;
            for (&middle, &suffix, &prefixes[first_index], &prefixes[second_index], &total) |*middle_out, *suffix_out, first, second, all| {
                middle_out.* = second - first;
                suffix_out.* = all - second;
            }
            const entropy = entropyBitsQ8(&prefixes[first_index]) +
                entropyBitsQ8(&middle) + entropyBitsQ8(&suffix);
            if (entropy < best_three_entropy) {
                best_three_entropy = entropy;
                best_three_indexes = .{ first_index, second_index };
            }
        }
    }
    if (best_three_indexes[0] != candidate_count and
        baseline_entropy - best_three_entropy >= 2 * min_entropy_proposal_savings_bits * entropy_scale)
    {
        const first_index = best_three_indexes[0];
        const second_index = best_three_indexes[1];
        var middle: [alphabet_size]u32 = undefined;
        var suffix: [alphabet_size]u32 = undefined;
        for (&middle, &suffix, &prefixes[first_index], &prefixes[second_index], &total) |*middle_out, *suffix_out, first, second, all| {
            middle_out.* = second - first;
            suffix_out.* = all - second;
        }
        const first_lengths = huffman.treeCodeLengths(alphabet_size, &prefixes[first_index], 15);
        const middle_lengths = huffman.treeCodeLengths(alphabet_size, &middle, 15);
        const suffix_lengths = huffman.treeCodeLengths(alphabet_size, &suffix, 15);
        const three_bits = weightedBits(&prefixes[first_index], &first_lengths) +
            weightedBits(&middle, &middle_lengths) +
            weightedBits(&suffix, &suffix_lengths);
        const savings = baseline_bits -| three_bits;
        if (savings >= 2 * min_estimated_savings_bits and
            savings -| proposals.two.?.savings_bits >= min_three_over_two_savings_bits)
        {
            proposals.three = .{
                .split = targets[first_index],
                .second_split = targets[second_index],
                .savings_bits = savings,
            };
        }
    }

    var best_four_entropy = baseline_entropy;
    var best_four_indexes: [3]usize = @splat(candidate_count);
    for (0..candidate_count) |first_index| {
        for (first_index + 1..candidate_count) |second_index| {
            for (second_index + 1..candidate_count) |third_index| {
                const first_split = targets[first_index];
                const second_split = targets[second_index];
                const third_split = targets[third_index];
                if (first_split < min_block_symbols or
                    second_split - first_split < min_block_symbols or
                    third_split - second_split < min_block_symbols or
                    symbols.len - third_split < min_block_symbols)
                    continue;
                var second: [alphabet_size]u32 = undefined;
                var third: [alphabet_size]u32 = undefined;
                var fourth: [alphabet_size]u32 = undefined;
                for (&second, &third, &fourth, &prefixes[first_index], &prefixes[second_index], &prefixes[third_index], &total) |*second_out, *third_out, *fourth_out, first, through_second, through_third, all| {
                    second_out.* = through_second - first;
                    third_out.* = through_third - through_second;
                    fourth_out.* = all - through_third;
                }
                const entropy = entropyBitsQ8(&prefixes[first_index]) +
                    entropyBitsQ8(&second) + entropyBitsQ8(&third) +
                    entropyBitsQ8(&fourth);
                if (entropy < best_four_entropy) {
                    best_four_entropy = entropy;
                    best_four_indexes = .{ first_index, second_index, third_index };
                }
            }
        }
    }
    if (best_four_indexes[0] != candidate_count and
        baseline_entropy - best_four_entropy >= 2 * min_entropy_proposal_savings_bits * entropy_scale)
    {
        const first_index = best_four_indexes[0];
        const second_index = best_four_indexes[1];
        const third_index = best_four_indexes[2];
        var second: [alphabet_size]u32 = undefined;
        var third: [alphabet_size]u32 = undefined;
        var fourth: [alphabet_size]u32 = undefined;
        for (&second, &third, &fourth, &prefixes[first_index], &prefixes[second_index], &prefixes[third_index], &total) |*second_out, *third_out, *fourth_out, first, through_second, through_third, all| {
            second_out.* = through_second - first;
            third_out.* = through_third - through_second;
            fourth_out.* = all - through_third;
        }
        const first_lengths = huffman.treeCodeLengths(alphabet_size, &prefixes[first_index], 15);
        const second_lengths = huffman.treeCodeLengths(alphabet_size, &second, 15);
        const third_lengths = huffman.treeCodeLengths(alphabet_size, &third, 15);
        const fourth_lengths = huffman.treeCodeLengths(alphabet_size, &fourth, 15);
        const four_bits = weightedBits(&prefixes[first_index], &first_lengths) +
            weightedBits(&second, &second_lengths) +
            weightedBits(&third, &third_lengths) +
            weightedBits(&fourth, &fourth_lengths);
        const savings = baseline_bits -| four_bits;
        const refined_baseline = @max(
            proposals.two.?.savings_bits,
            if (proposals.three) |three| three.savings_bits else 0,
        );
        if (savings >= 2 * min_estimated_savings_bits and
            savings -| refined_baseline >= min_four_over_best_savings_bits)
        {
            proposals.four = .{
                .split = targets[first_index],
                .second_split = targets[second_index],
                .third_split = targets[third_index],
                .savings_bits = savings,
            };
        }
    }
    return proposals;
}

fn entropyBitsQ8(frequencies: *const [alphabet_size]u32) u64 {
    var sum: u64 = 0;
    var weighted_logs: u64 = 0;
    for (frequencies) |frequency| {
        sum += frequency;
        weighted_logs += @as(u64, frequency) * fastLog2Q8(frequency);
    }
    if (sum == 0) return 0;
    const entropy = sum * fastLog2Q8(@intCast(sum)) -| weighted_logs;
    return @max(entropy, sum * entropy_scale);
}

fn fastLog2Q8(value: u32) u64 {
    if (value == 0) return 0;
    const floor: u5 = @intCast(31 - @clz(value));
    const normalized = if (floor >= 8) value >> @intCast(floor - 8) else value << @intCast(8 - floor);
    return @as(u64, floor) * entropy_scale + log2_fraction_q8[normalized - 256];
}

fn weightedBits(frequencies: *const [alphabet_size]u32, lengths: *const [alphabet_size]u4) u64 {
    var total: u64 = 0;
    for (frequencies, lengths) |frequency, bits| total += @as(u64, frequency) * bits;
    return total;
}

test "distance block split finds distinct symbol regions" {
    var symbols: [4096]u16 = undefined;
    for (symbols[0..2048], 0..) |*symbol, i| symbol.* = @intCast(i & 3);
    for (symbols[2048..], 0..) |*symbol, i| symbol.* = @intCast(75 + (i & 3));
    const result = choose(&symbols) orelse return error.TestUnexpectedResult;
    try std.testing.expect(result.split >= 1365 and result.split <= 2730);
}

test "distance block split finds three distinct symbol regions" {
    var symbols: [6144]u16 = undefined;
    for (symbols[0..2048], 0..) |*symbol, i| symbol.* = @intCast(i & 3);
    for (symbols[2048..4096], 0..) |*symbol, i| symbol.* = @intCast(36 + (i & 3));
    for (symbols[4096..], 0..) |*symbol, i| symbol.* = @intCast(75 + (i & 3));
    const result = chooseProposals(&symbols).three orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(usize, 3), result.regionCount());
    try std.testing.expectEqual(@as(usize, 0), result.blockIndex(0));
    try std.testing.expectEqual(@as(usize, 1), result.blockIndex(result.split));
    try std.testing.expectEqual(@as(usize, 2), result.blockIndex(result.second_split.?));
}

test "distance block split finds four distinct symbol regions" {
    var symbols: [8192]u16 = undefined;
    const first_split = symbols.len / 6;
    const second_split = symbols.len * 2 / 6;
    const third_split = symbols.len * 3 / 6;
    for (&symbols, 0..) |*symbol, i| {
        const region: usize = if (i < first_split) 0 else if (i < second_split) 1 else if (i < third_split) 2 else 3;
        symbol.* = @intCast(region * 25 + (i & 3));
    }
    const result = chooseProposals(&symbols).four orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(usize, 4), result.regionCount());
    try std.testing.expectEqual(@as(usize, 0), result.blockIndex(0));
    try std.testing.expectEqual(@as(usize, 1), result.blockIndex(result.split));
    try std.testing.expectEqual(@as(usize, 2), result.blockIndex(result.second_split.?));
    try std.testing.expectEqual(@as(usize, 3), result.blockIndex(result.third_split.?));
}

test "distance block split rejects stationary and small streams" {
    var symbols: [2048]u16 = undefined;
    for (&symbols, 0..) |*symbol, i| symbol.* = @intCast(i & 15);
    try std.testing.expectEqual(@as(?Result, null), choose(&symbols));
    try std.testing.expectEqual(@as(?Result, null), choose(symbols[0..512]));
    try std.testing.expect(!eligible(2 * min_block_symbols - 1));
    try std.testing.expect(eligible(2 * min_block_symbols));
    try std.testing.expect(eligible(max_split_symbols));
    try std.testing.expect(!eligible(max_split_symbols + 1));
}

test "distance block split fixed-point logarithm stays within two q8 units" {
    for (1..4097) |value| {
        const exact = @log2(@as(f64, @floatFromInt(value))) * 256.0;
        const approximate: f64 = @floatFromInt(fastLog2Q8(@intCast(value)));
        try std.testing.expect(@abs(exact - approximate) <= 2.0);
    }
}
