const std = @import("std");
const huffman = @import("../../huffman.zig");

const alphabet_size: usize = 704;
const min_block_commands: usize = 1024;
const max_split_commands: usize = 32 * 1024;
const candidate_count: usize = 5;
const min_estimated_savings_bits: u64 = 2048;
const min_entropy_proposal_savings_bits: u64 = min_estimated_savings_bits * 3 / 4;
// A three-tree command header adds one complete command tree plus a second
// block-length token. Require a conservative margin over the two-tree payload
// estimate before paying for a second complete wire candidate.
const min_three_over_two_savings_bits: u64 = 1024;
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
    savings_bits: u64,

    pub fn blockCount(self: Result) usize {
        return if (self.second_split == null) 2 else 3;
    }

    pub fn blockIndex(self: Result, command_index: usize) usize {
        if (command_index < self.split) return 0;
        if (self.second_split) |second| return if (command_index < second) 1 else 2;
        return 1;
    }
};

pub const Proposals = struct {
    two: ?Result = null,
    three: ?Result = null,

    /// Three-way proposals have already cleared a conservative incremental
    /// margin over `two`; prefer them without materializing both full wires.
    pub fn preferred(self: Proposals) ?Result {
        return self.three orelse self.two;
    }
};
pub const Accumulator = struct {
    symbol_count: usize,
    seen_count: usize = 0,
    target_index: usize = 0,
    total: [alphabet_size]u32 = @splat(0),
    prefixes: [candidate_count][alphabet_size]u32 = undefined,
    targets: [candidate_count]usize,

    pub fn init(symbol_count: usize) ?Accumulator {
        if (!eligible(symbol_count)) return null;
        var targets: [candidate_count]usize = undefined;
        for (1..candidate_count + 1) |i| targets[i - 1] = symbol_count * i / (candidate_count + 1);
        return .{ .symbol_count = symbol_count, .targets = targets };
    }

    pub fn add(self: *Accumulator, symbol: u16) bool {
        if (self.seen_count >= self.symbol_count or symbol >= alphabet_size) return false;
        self.total[symbol] += 1;
        self.seen_count += 1;
        if (self.target_index < self.targets.len and self.seen_count == self.targets[self.target_index]) {
            self.prefixes[self.target_index] = self.total;
            self.target_index += 1;
        }
        return true;
    }

    pub fn finish(self: *const Accumulator) ?Result {
        return self.finishProposals().two;
    }

    pub fn finishProposals(self: *const Accumulator) Proposals {
        if (self.seen_count != self.symbol_count or self.target_index != self.targets.len) return .{};
        return chooseFromHistograms(&self.total, &self.prefixes, &self.targets);
    }
};

pub fn eligible(command_count: usize) bool {
    return command_count >= 2 * min_block_commands and command_count <= max_split_commands;
}

pub fn choose(symbols: []const u16) ?Result {
    var accumulator = Accumulator.init(symbols.len) orelse return null;
    for (symbols) |symbol| if (!accumulator.add(symbol)) return null;
    return accumulator.finish();
}

fn chooseFromHistograms(total: *const [alphabet_size]u32, prefixes: *const [candidate_count][alphabet_size]u32, targets: *const [candidate_count]usize) Proposals {
    const baseline_entropy = entropyBitsQ8(total);
    var best_two_index: usize = candidate_count;
    var best_two_entropy = baseline_entropy;
    var best_two_prefix: [alphabet_size]u32 = undefined;
    for (prefixes, 0..) |prefix, candidate_index| {
        var suffix: [alphabet_size]u32 = undefined;
        for (&suffix, total, &prefix) |*out, all, before| out.* = all - before;
        const split_entropy = entropyBitsQ8(&prefix) + entropyBitsQ8(&suffix);
        if (split_entropy < best_two_entropy) {
            best_two_entropy = split_entropy;
            best_two_index = candidate_index;
            best_two_prefix = prefix;
        }
    }

    var proposals: Proposals = .{};
    if (best_two_index == candidate_count or baseline_entropy - best_two_entropy < min_entropy_proposal_savings_bits * entropy_scale) return proposals;

    const baseline_lengths = huffman.treeCodeLengths(alphabet_size, total, 15);
    const baseline_bits = weightedBits(total, &baseline_lengths);
    var best_two_suffix: [alphabet_size]u32 = undefined;
    for (&best_two_suffix, total, &best_two_prefix) |*out, all, before| out.* = all - before;
    const prefix_lengths = huffman.treeCodeLengths(alphabet_size, &best_two_prefix, 15);
    const two_suffix_lengths = huffman.treeCodeLengths(alphabet_size, &best_two_suffix, 15);
    const two_bits = weightedBits(&best_two_prefix, &prefix_lengths) + weightedBits(&best_two_suffix, &two_suffix_lengths);
    if (two_bits >= baseline_bits or baseline_bits - two_bits < min_estimated_savings_bits) return proposals;
    proposals.two = .{ .split = targets[best_two_index], .savings_bits = baseline_bits - two_bits };

    // Refine the already-profitable two-way split with one additional boundary.
    // This bounds three-way scoring to four candidates and avoids imposing its
    // cost on stationary streams that cannot even justify two command trees.
    var best_three_entropy = baseline_entropy;
    var best_first_index: usize = candidate_count;
    var best_second_index: usize = candidate_count;
    const symbol_count = totalCount(total);
    for (0..candidate_count) |candidate_index| {
        if (candidate_index == best_two_index) continue;
        const first_index = @min(candidate_index, best_two_index);
        const second_index = @max(candidate_index, best_two_index);
        const first_split = targets[first_index];
        const second_split = targets[second_index];
        if (first_split < min_block_commands or second_split - first_split < min_block_commands or symbol_count - second_split < min_block_commands) continue;
        var middle: [alphabet_size]u32 = undefined;
        var suffix: [alphabet_size]u32 = undefined;
        for (&middle, &suffix, &prefixes[first_index], &prefixes[second_index], total) |*middle_out, *suffix_out, first, second, all| {
            middle_out.* = second - first;
            suffix_out.* = all - second;
        }
        const split_entropy = entropyBitsQ8(&prefixes[first_index]) + entropyBitsQ8(&middle) + entropyBitsQ8(&suffix);
        if (split_entropy < best_three_entropy) {
            best_three_entropy = split_entropy;
            best_first_index = first_index;
            best_second_index = second_index;
        }
    }
    if (best_first_index != candidate_count and baseline_entropy - best_three_entropy >= 2 * min_entropy_proposal_savings_bits * entropy_scale) {
        var middle: [alphabet_size]u32 = undefined;
        var suffix: [alphabet_size]u32 = undefined;
        for (&middle, &suffix, &prefixes[best_first_index], &prefixes[best_second_index], total) |*middle_out, *suffix_out, first, second, all| {
            middle_out.* = second - first;
            suffix_out.* = all - second;
        }
        const first_lengths = huffman.treeCodeLengths(alphabet_size, &prefixes[best_first_index], 15);
        const middle_lengths = huffman.treeCodeLengths(alphabet_size, &middle, 15);
        const suffix_lengths = huffman.treeCodeLengths(alphabet_size, &suffix, 15);
        const split_bits = weightedBits(&prefixes[best_first_index], &first_lengths) + weightedBits(&middle, &middle_lengths) + weightedBits(&suffix, &suffix_lengths);
        const savings = baseline_bits -| split_bits;
        if (savings >= 2 * min_estimated_savings_bits and savings -| proposals.two.?.savings_bits >= min_three_over_two_savings_bits)
            proposals.three = .{ .split = targets[best_first_index], .second_split = targets[best_second_index], .savings_bits = savings };
    }
    return proposals;
}

fn totalCount(total: *const [alphabet_size]u32) usize {
    var length: usize = 0;
    for (total) |frequency| length += frequency;
    return length;
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

test "command block split finds distinct symbol regions" {
    var symbols: [4096]u16 = undefined;
    for (symbols[0..2048], 0..) |*symbol, i| symbol.* = @intCast(i & 7);
    for (symbols[2048..], 0..) |*symbol, i| symbol.* = @intCast(696 + (i & 7));
    const result = choose(&symbols) orelse return error.TestUnexpectedResult;
    try std.testing.expect(result.split >= 1365 and result.split <= 2730);
    var accumulator = Accumulator.init(symbols.len).?;
    for (symbols) |symbol| try std.testing.expect(accumulator.add(symbol));
    try std.testing.expectEqual(result, accumulator.finish().?);
    try std.testing.expectEqual(@as(usize, 2), result.blockCount());
    try std.testing.expectEqual(@as(?usize, null), result.second_split);
}

test "command block split finds three distinct symbol regions" {
    var symbols: [6144]u16 = undefined;
    for (symbols[0..2048], 0..) |*symbol, i| symbol.* = @intCast(i & 7);
    for (symbols[2048..4096], 0..) |*symbol, i| symbol.* = @intCast(320 + (i & 7));
    for (symbols[4096..], 0..) |*symbol, i| symbol.* = @intCast(696 + (i & 7));
    const result = choose(&symbols) orelse return error.TestUnexpectedResult;
    const proposals = blk: {
        var accumulator = Accumulator.init(symbols.len).?;
        for (symbols) |symbol| try std.testing.expect(accumulator.add(symbol));
        break :blk accumulator.finishProposals();
    };
    try std.testing.expect(proposals.two != null);
    try std.testing.expect(proposals.three != null);
    try std.testing.expectEqual(proposals.three.?, proposals.preferred().?);
    const three = proposals.three.?;
    try std.testing.expectEqual(proposals.two.?, result);
    try std.testing.expectEqual(@as(usize, 3), three.blockCount());
    try std.testing.expect(three.split >= 1024 and three.split <= 3072);
    try std.testing.expect(three.second_split.? >= 3072 and three.second_split.? <= 5120);
    try std.testing.expectEqual(@as(usize, 0), three.blockIndex(0));
    try std.testing.expectEqual(@as(usize, 1), three.blockIndex(three.split));
    try std.testing.expectEqual(@as(usize, 2), three.blockIndex(three.second_split.?));
}

test "command block split rejects stationary and small streams" {
    var symbols: [4096]u16 = undefined;
    for (&symbols, 0..) |*symbol, i| symbol.* = @intCast(i & 31);
    try std.testing.expectEqual(@as(?Result, null), choose(&symbols));
    try std.testing.expectEqual(@as(?Result, null), choose(symbols[0..1024]));
    try std.testing.expect(!eligible(2 * min_block_commands - 1));
    try std.testing.expect(eligible(2 * min_block_commands));
    try std.testing.expect(eligible(max_split_commands));
    try std.testing.expect(!eligible(max_split_commands + 1));
    var incomplete = Accumulator.init(symbols.len).?;
    for (symbols[0 .. symbols.len - 1]) |symbol| try std.testing.expect(incomplete.add(symbol));
    try std.testing.expectEqual(@as(?Result, null), incomplete.finish());

    var invalid_symbol = Accumulator.init(symbols.len).?;
    try std.testing.expect(!invalid_symbol.add(alphabet_size));
    try std.testing.expectEqual(@as(usize, 0), invalid_symbol.seen_count);

    var complete = Accumulator.init(symbols.len).?;
    for (symbols) |symbol| try std.testing.expect(complete.add(symbol));
    try std.testing.expect(!complete.add(0));
}

test "command block split fixed-point logarithm stays within two q8 units" {
    for (1..4097) |value| {
        const exact = @log2(@as(f64, @floatFromInt(value))) * 256.0;
        const approximate: f64 = @floatFromInt(fastLog2Q8(@intCast(value)));
        try std.testing.expect(@abs(exact - approximate) <= 2.0);
    }
}
