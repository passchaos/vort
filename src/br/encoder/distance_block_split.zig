const std = @import("std");
const huffman = @import("../../huffman.zig");
const adaptive_block_split = @import("adaptive_block_split.zig");
const block_split_plan = @import("block_split_plan.zig");
const histogram_model = @import("histogram_model.zig");
const distance = @import("distance.zig");

const alphabet_size: usize = 79;
const min_block_symbols: usize = 512;
const max_split_symbols: usize = 32 * 1024;
const candidate_count: usize = 5;
pub const max_regions: usize = candidate_count + 1;
const min_estimated_savings_bits: u64 = 2200;
const min_entropy_proposal_savings_bits: u64 = 2250;
const min_three_over_two_savings_bits: u64 = 1024;
const min_clustered_over_two_savings_bits: u64 = 128;
const min_alternating_four_over_best_savings_bits: u64 = 256;
const min_reuse_first_four_over_best_savings_bits: u64 = 128;
const min_four_over_best_savings_bits: u64 = 1024;
const min_dynamic_over_best_savings_bits: u64 = 1024;
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
    fourth_split: ?usize = null,
    fifth_split: ?usize = null,
    alternate_two_types: bool = false,
    reuse_first_for_fourth: bool = false,
    cycle_type_count: ?usize = null,
    savings_bits: u64,

    pub fn regionCount(self: Result) usize {
        return if (self.fifth_split != null)
            6
        else if (self.fourth_split != null)
            5
        else if (self.third_split != null)
            4
        else if (self.second_split != null)
            3
        else
            2;
    }

    pub fn typeCount(self: Result) usize {
        return self.cycle_type_count orelse if (self.alternate_two_types) 2 else if (self.reuse_first_for_fourth) 3 else self.regionCount();
    }

    pub fn blockIndex(self: Result, symbol_index: usize) usize {
        var region: usize = 0;
        while (region + 1 < self.regionCount() and symbol_index >= self.boundary(region))
            region += 1;
        return region % self.typeCount();
    }

    pub fn boundary(self: Result, index: usize) usize {
        return switch (index) {
            0 => self.split,
            1 => self.second_split orelse unreachable,
            2 => self.third_split orelse unreachable,
            3 => self.fourth_split orelse unreachable,
            4 => self.fifth_split orelse unreachable,
            else => unreachable,
        };
    }
};

pub const Proposals = struct {
    two: ?Result = null,
    three: ?Result = null,
    clustered: ?Result = null,
    alternating_four: ?Result = null,
    reuse_first_four: ?Result = null,
    four: ?Result = null,
    dynamic: ?Result = null,
};

const AdaptiveSplitter = adaptive_block_split.Splitter(u16, alphabet_size);
pub const AdaptiveOptions = AdaptiveSplitter.Options;

/// Discover arbitrary distance boundaries and non-cyclic type reuse. The
/// legacy fixed-grid proposals remain separate complete-wire candidates until
/// this general plan proves smaller after all Brotli header costs.
pub fn chooseAdaptiveAlloc(
    allocator: std.mem.Allocator,
    symbols: []const u16,
    options: AdaptiveOptions,
) !?block_split_plan.Plan {
    return AdaptiveSplitter.splitAlloc(allocator, symbols, options);
}

/// NPOSTFIX=0 / NDIRECT=15 discovery uses 79 symbols in standard streams,
/// while Large Window permits 88 signed-safe symbols. The legacy proposal
/// scorer remains an optional bounded search; the adaptive path can represent
/// the whole active shape and the complete writer owns the wire alphabet.
pub fn chooseAdaptiveAllocWithFormat(
    allocator: std.mem.Allocator,
    symbols: []const u16,
    options: AdaptiveOptions,
    format: distance.Format,
) !?block_split_plan.Plan {
    if (format == .standard) return chooseAdaptiveAlloc(allocator, symbols, options);
    const capacity = comptime distance.Parameters.init(0, 15).activeAlphabetSize(.large_window);
    const LargeSplitter = adaptive_block_split.Splitter(u16, capacity);
    return LargeSplitter.splitAlloc(allocator, symbols, .{
        .type_count = options.type_count,
        .iterations = options.iterations,
        .switch_cost_q8 = options.switch_cost_q8,
        .min_symbols = options.min_symbols,
        .max_symbols = options.max_symbols,
        .scratch_budget_bytes = options.scratch_budget_bytes,
    });
}

test "Br general large window adaptive distance discovery accepts the whole active alphabet" {
    var symbols: [2048]u16 = undefined;
    for (symbols[0..1024], 0..) |*symbol, index| symbol.* = @intCast(index % 2);
    const active_size = comptime distance.Parameters.init(0, 15).activeAlphabetSize(.large_window);
    for (symbols[1024..], 0..) |*symbol, index| symbol.* = @intCast(active_size - 2 + index % 2);
    const options: AdaptiveOptions = .{ .type_count = 2, .iterations = 1 };
    try std.testing.expectError(error.InvalidSymbol, chooseAdaptiveAllocWithFormat(std.testing.allocator, &symbols, options, .standard));
    const plan = (try chooseAdaptiveAllocWithFormat(std.testing.allocator, &symbols, options, .large_window)) orelse return error.TestExpectedEqual;
    defer plan.deinit(std.testing.allocator);
    try plan.validate(symbols.len);
    try std.testing.expectEqual(@as(usize, 2), plan.blockCount());
    symbols[symbols.len - 1] = active_size;
    try std.testing.expectError(error.InvalidSymbol, chooseAdaptiveAllocWithFormat(std.testing.allocator, &symbols, options, .large_window));
}

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
    var best_clustered_entropy = baseline_entropy;
    var best_clustered_indexes: [2]usize = @splat(candidate_count);
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
            var outer: [alphabet_size]u32 = undefined;
            for (&outer, &prefixes[first_index], &suffix) |*out, first, last|
                out.* = first + last;
            const clustered_entropy = entropyBitsQ8(&outer) + entropyBitsQ8(&middle);
            if (clustered_entropy < best_clustered_entropy) {
                best_clustered_entropy = clustered_entropy;
                best_clustered_indexes = .{ first_index, second_index };
            }
        }
    }
    if (best_clustered_indexes[0] != candidate_count and
        baseline_entropy - best_clustered_entropy >= min_entropy_proposal_savings_bits * entropy_scale)
    {
        const first_index = best_clustered_indexes[0];
        const second_index = best_clustered_indexes[1];
        var middle: [alphabet_size]u32 = undefined;
        var suffix: [alphabet_size]u32 = undefined;
        var outer: [alphabet_size]u32 = undefined;
        for (&middle, &suffix, &prefixes[first_index], &prefixes[second_index], &total) |*middle_out, *suffix_out, first, second, all| {
            middle_out.* = second - first;
            suffix_out.* = all - second;
        }
        for (&outer, &prefixes[first_index], &suffix) |*out, first, last|
            out.* = first + last;
        const outer_lengths = huffman.treeCodeLengths(alphabet_size, &outer, 15);
        const middle_lengths = huffman.treeCodeLengths(alphabet_size, &middle, 15);
        const clustered_bits = weightedBits(&outer, &outer_lengths) +
            weightedBits(&middle, &middle_lengths);
        const savings = baseline_bits -| clustered_bits;
        if (savings >= min_estimated_savings_bits and
            savings -| proposals.two.?.savings_bits >= min_clustered_over_two_savings_bits)
        {
            proposals.clustered = .{
                .split = targets[first_index],
                .second_split = targets[second_index],
                .alternate_two_types = true,
                .savings_bits = savings,
            };
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
        const refined_baseline = @max(
            proposals.two.?.savings_bits,
            if (proposals.clustered) |clustered| clustered.savings_bits else 0,
        );
        if (savings >= 2 * min_estimated_savings_bits and
            savings -| refined_baseline >= min_three_over_two_savings_bits)
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
    var best_alternating_entropy = baseline_entropy;
    var best_alternating_indexes: [3]usize = @splat(candidate_count);
    var best_reuse_first_entropy = baseline_entropy;
    var best_reuse_first_indexes: [3]usize = @splat(candidate_count);
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
                var type_a: [alphabet_size]u32 = undefined;
                var type_b: [alphabet_size]u32 = undefined;
                for (&type_a, &type_b, &prefixes[first_index], &second, &third, &fourth) |*a, *b, first, second_region, third_region, fourth_region| {
                    a.* = first + third_region;
                    b.* = second_region + fourth_region;
                }
                const alternating_entropy = entropyBitsQ8(&type_a) + entropyBitsQ8(&type_b);
                if (alternating_entropy < best_alternating_entropy) {
                    best_alternating_entropy = alternating_entropy;
                    best_alternating_indexes = .{ first_index, second_index, third_index };
                }
                var outer: [alphabet_size]u32 = undefined;
                for (&outer, &prefixes[first_index], &fourth) |*out, first, last|
                    out.* = first + last;
                const reuse_first_entropy = entropyBitsQ8(&outer) +
                    entropyBitsQ8(&second) + entropyBitsQ8(&third);
                if (reuse_first_entropy < best_reuse_first_entropy) {
                    best_reuse_first_entropy = reuse_first_entropy;
                    best_reuse_first_indexes = .{ first_index, second_index, third_index };
                }
            }
        }
    }
    if (best_alternating_indexes[0] != candidate_count and
        baseline_entropy - best_alternating_entropy >= min_entropy_proposal_savings_bits * entropy_scale)
    {
        const first_index = best_alternating_indexes[0];
        const second_index = best_alternating_indexes[1];
        const third_index = best_alternating_indexes[2];
        var second: [alphabet_size]u32 = undefined;
        var third: [alphabet_size]u32 = undefined;
        var fourth: [alphabet_size]u32 = undefined;
        var type_a: [alphabet_size]u32 = undefined;
        var type_b: [alphabet_size]u32 = undefined;
        for (&second, &third, &fourth, &prefixes[first_index], &prefixes[second_index], &prefixes[third_index], &total) |*second_out, *third_out, *fourth_out, first, through_second, through_third, all| {
            second_out.* = through_second - first;
            third_out.* = through_third - through_second;
            fourth_out.* = all - through_third;
        }
        for (&type_a, &type_b, &prefixes[first_index], &second, &third, &fourth) |*a, *b, first, second_region, third_region, fourth_region| {
            a.* = first + third_region;
            b.* = second_region + fourth_region;
        }
        const type_a_lengths = huffman.treeCodeLengths(alphabet_size, &type_a, 15);
        const type_b_lengths = huffman.treeCodeLengths(alphabet_size, &type_b, 15);
        const alternating_bits = weightedBits(&type_a, &type_a_lengths) +
            weightedBits(&type_b, &type_b_lengths);
        const savings = baseline_bits -| alternating_bits;
        const refined_baseline = @max(
            proposals.two.?.savings_bits,
            @max(
                if (proposals.clustered) |clustered| clustered.savings_bits else 0,
                if (proposals.three) |three| three.savings_bits else 0,
            ),
        );
        if (savings >= min_estimated_savings_bits and
            savings -| refined_baseline >= min_alternating_four_over_best_savings_bits)
        {
            proposals.alternating_four = .{
                .split = targets[first_index],
                .second_split = targets[second_index],
                .third_split = targets[third_index],
                .alternate_two_types = true,
                .savings_bits = savings,
            };
        }
    }
    if (best_reuse_first_indexes[0] != candidate_count and
        baseline_entropy - best_reuse_first_entropy >= 2 * min_entropy_proposal_savings_bits * entropy_scale)
    {
        const first_index = best_reuse_first_indexes[0];
        const second_index = best_reuse_first_indexes[1];
        const third_index = best_reuse_first_indexes[2];
        var second: [alphabet_size]u32 = undefined;
        var third: [alphabet_size]u32 = undefined;
        var fourth: [alphabet_size]u32 = undefined;
        var outer: [alphabet_size]u32 = undefined;
        for (&second, &third, &fourth, &prefixes[first_index], &prefixes[second_index], &prefixes[third_index], &total) |*second_out, *third_out, *fourth_out, first, through_second, through_third, all| {
            second_out.* = through_second - first;
            third_out.* = through_third - through_second;
            fourth_out.* = all - through_third;
        }
        for (&outer, &prefixes[first_index], &fourth) |*out, first, last|
            out.* = first + last;
        const outer_lengths = huffman.treeCodeLengths(alphabet_size, &outer, 15);
        const second_lengths = huffman.treeCodeLengths(alphabet_size, &second, 15);
        const third_lengths = huffman.treeCodeLengths(alphabet_size, &third, 15);
        const reuse_bits = weightedBits(&outer, &outer_lengths) +
            weightedBits(&second, &second_lengths) +
            weightedBits(&third, &third_lengths);
        const savings = baseline_bits -| reuse_bits;
        const refined_baseline = @max(
            if (proposals.three) |three| three.savings_bits else proposals.two.?.savings_bits,
            @max(
                if (proposals.clustered) |clustered| clustered.savings_bits else 0,
                if (proposals.alternating_four) |alternating| alternating.savings_bits else 0,
            ),
        );
        if (savings >= 2 * min_estimated_savings_bits and
            savings -| refined_baseline >= min_reuse_first_four_over_best_savings_bits)
        {
            proposals.reuse_first_four = .{
                .split = targets[first_index],
                .second_split = targets[second_index],
                .third_split = targets[third_index],
                .reuse_first_for_fourth = true,
                .savings_bits = savings,
            };
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
            @max(
                if (proposals.clustered) |clustered| clustered.savings_bits else 0,
                @max(
                    if (proposals.three) |three| three.savings_bits else 0,
                    @max(
                        if (proposals.alternating_four) |alternating| alternating.savings_bits else 0,
                        if (proposals.reuse_first_four) |reused| reused.savings_bits else 0,
                    ),
                ),
            ),
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
    var fixed_best_savings = proposals.two.?.savings_bits;
    inline for (.{ proposals.three, proposals.clustered, proposals.alternating_four, proposals.reuse_first_four, proposals.four }) |proposal| {
        if (proposal) |active| fixed_best_savings = @max(fixed_best_savings, active.savings_bits);
    }
    var best_dynamic_savings: u64 = 0;
    var best_dynamic: ?Result = null;
    for (1..@as(usize, 1) << candidate_count) |mask_value| {
        const mask: u5 = @intCast(mask_value);
        const boundary_count: usize = @popCount(mask);
        if (boundary_count < 4) continue;
        const region_count = boundary_count + 1;
        var boundaries: [candidate_count]usize = @splat(0);
        var selected_indexes: [candidate_count]usize = @splat(0);
        var selected_count: usize = 0;
        for (0..candidate_count) |candidate_index| {
            if (mask & (@as(u5, 1) << @intCast(candidate_index)) == 0) continue;
            boundaries[selected_count] = targets[candidate_index];
            selected_indexes[selected_count] = candidate_index;
            selected_count += 1;
        }
        var regions: [max_regions][alphabet_size]u32 = @splat(@splat(0));
        var previous: [alphabet_size]u32 = @splat(0);
        for (0..boundary_count) |region| {
            const prefix = prefixes[selected_indexes[region]];
            for (&regions[region], &prefix, &previous) |*out, through, before|
                out.* = through - before;
            previous = prefix;
        }
        for (&regions[region_count - 1], &total, &previous) |*out, all, before|
            out.* = all - before;

        for (2..region_count + 1) |type_count| {
            var pooled: [max_regions][alphabet_size]u32 = @splat(@splat(0));
            for (regions[0..region_count], 0..) |region_frequencies, region| {
                for (&pooled[region % type_count], &region_frequencies) |*out, frequency|
                    out.* += frequency;
            }
            var candidate_entropy: u64 = 0;
            for (pooled[0..type_count]) |*frequencies|
                candidate_entropy += entropyBitsQ8(frequencies);
            if (baseline_entropy -| candidate_entropy < 2 * min_entropy_proposal_savings_bits * entropy_scale) continue;
            var candidate_bits: u64 = 0;
            for (pooled[0..type_count]) |*frequencies| {
                const lengths = huffman.treeCodeLengths(alphabet_size, frequencies, 15);
                candidate_bits += weightedBits(frequencies, &lengths);
            }
            const savings = baseline_bits -| candidate_bits;
            if (savings < 2 * min_estimated_savings_bits or
                savings -| fixed_best_savings < min_dynamic_over_best_savings_bits or
                savings <= best_dynamic_savings)
                continue;
            var result = Result{
                .split = boundaries[0],
                .cycle_type_count = type_count,
                .savings_bits = savings,
            };
            if (boundary_count >= 2) result.second_split = boundaries[1];
            if (boundary_count >= 3) result.third_split = boundaries[2];
            if (boundary_count >= 4) result.fourth_split = boundaries[3];
            if (boundary_count >= 5) result.fifth_split = boundaries[4];
            best_dynamic_savings = savings;
            best_dynamic = result;
        }
    }
    proposals.dynamic = best_dynamic;
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

test "distance block split clusters matching outer regions" {
    var symbols: [12_288]u16 = undefined;
    for (symbols[0..4096], 0..) |*symbol, i| symbol.* = @intCast(i & 3);
    for (symbols[4096..8192], 0..) |*symbol, i| symbol.* = @intCast(75 + (i & 3));
    for (symbols[8192..], 0..) |*symbol, i| symbol.* = @intCast(i & 3);
    const result = chooseProposals(&symbols).clustered orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(usize, 3), result.regionCount());
    try std.testing.expectEqual(@as(usize, 2), result.typeCount());
    try std.testing.expectEqual(@as(usize, 0), result.blockIndex(0));
    try std.testing.expectEqual(@as(usize, 1), result.blockIndex(result.split));
    try std.testing.expectEqual(@as(usize, 0), result.blockIndex(result.second_split.?));
}

test "distance block split clusters four alternating regions" {
    var symbols: [8192]u16 = undefined;
    const first_split = symbols.len / 6;
    const second_split = symbols.len * 2 / 6;
    const third_split = symbols.len * 3 / 6;
    for (&symbols, 0..) |*symbol, i| {
        const region: usize = if (i < first_split) 0 else if (i < second_split) 1 else if (i < third_split) 2 else 3;
        symbol.* = if (region & 1 == 0) @intCast(i & 3) else @intCast(75 + (i & 3));
    }
    const result = chooseProposals(&symbols).alternating_four orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(usize, 4), result.regionCount());
    try std.testing.expectEqual(@as(usize, 2), result.typeCount());
    try std.testing.expectEqual(@as(usize, 0), result.blockIndex(0));
    try std.testing.expectEqual(@as(usize, 1), result.blockIndex(result.split));
    try std.testing.expectEqual(@as(usize, 0), result.blockIndex(result.second_split.?));
    try std.testing.expectEqual(@as(usize, 1), result.blockIndex(result.third_split.?));
}

test "distance block split reuses the first of three types in region four" {
    var symbols: [8192]u16 = undefined;
    const first_split = symbols.len / 6;
    const second_split = symbols.len * 2 / 6;
    const third_split = symbols.len * 3 / 6;
    for (&symbols, 0..) |*symbol, i| {
        const region: usize = if (i < first_split) 0 else if (i < second_split) 1 else if (i < third_split) 2 else 3;
        symbol.* = switch (region) {
            0, 3 => @intCast(i & 3),
            1 => @intCast(36 + (i & 3)),
            else => @intCast(75 + (i & 3)),
        };
    }
    const result = chooseProposals(&symbols).reuse_first_four orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(usize, 4), result.regionCount());
    try std.testing.expectEqual(@as(usize, 3), result.typeCount());
    try std.testing.expectEqual(@as(usize, 0), result.blockIndex(0));
    try std.testing.expectEqual(@as(usize, 1), result.blockIndex(result.split));
    try std.testing.expectEqual(@as(usize, 2), result.blockIndex(result.second_split.?));
    try std.testing.expectEqual(@as(usize, 0), result.blockIndex(result.third_split.?));
}

test "distance block split selects five independent regions" {
    var symbols: [12_288]u16 = undefined;
    const boundaries = [4]usize{ 2048, 4096, 6144, 8192 };
    for (&symbols, 0..) |*symbol, i| {
        const region: usize = if (i < boundaries[0]) 0 else if (i < boundaries[1]) 1 else if (i < boundaries[2]) 2 else if (i < boundaries[3]) 3 else 4;
        symbol.* = @intCast(region * 16 + (i & 3));
    }
    const result = chooseProposals(&symbols).dynamic orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(usize, 5), result.regionCount());
    try std.testing.expectEqual(@as(usize, 5), result.typeCount());
    for (0..5) |region|
        try std.testing.expectEqual(region, result.blockIndex(if (region == 0) 0 else result.boundary(region - 1)));
}

test "distance block split cycles three trees across six regions" {
    var symbols: [12_288]u16 = undefined;
    for (&symbols, 0..) |*symbol, i| {
        const region = i / 2048;
        symbol.* = @intCast((region % 3) * 32 + (i & 3));
    }
    const result = chooseProposals(&symbols).dynamic orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(usize, 6), result.regionCount());
    try std.testing.expectEqual(@as(usize, 3), result.typeCount());
    for (0..6) |region|
        try std.testing.expectEqual(region % 3, result.blockIndex(region * 2048));
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

test "adaptive distance block split finds an arbitrary off-grid boundary" {
    var symbols: [120]u16 = undefined;
    const expected_split: usize = 47;
    for (symbols[0..expected_split], 0..) |*symbol, index|
        symbol.* = @intCast(index % 4);
    for (symbols[expected_split..], 0..) |*symbol, index|
        symbol.* = @intCast(75 + index % 4);

    const plan = (try chooseAdaptiveAlloc(std.testing.allocator, &symbols, .{
        .type_count = 2,
        .switch_cost_q8 = 2 * histogram_model.cost_scale,
    })) orelse return error.TestUnexpectedResult;
    defer plan.deinit(std.testing.allocator);

    try std.testing.expectEqualSlices(u32, &.{ expected_split, symbols.len - expected_split }, plan.lengths);
    try std.testing.expectEqualSlices(u8, &.{ 0, 1 }, plan.types);
    try std.testing.expectEqual(@as(u16, 2), plan.type_count);
    try plan.validate(symbols.len);
}

test "adaptive distance block split preserves non-cyclic type reuse" {
    var symbols: [160]u16 = undefined;
    @memset(symbols[0..32], 0);
    @memset(symbols[32..64], 39);
    @memset(symbols[64..96], 0);
    @memset(symbols[96..128], 78);
    @memset(symbols[128..160], 0);

    const plan = (try chooseAdaptiveAlloc(std.testing.allocator, &symbols, .{
        .type_count = 5,
        .switch_cost_q8 = histogram_model.cost_scale,
    })) orelse return error.TestUnexpectedResult;
    defer plan.deinit(std.testing.allocator);

    try std.testing.expectEqualSlices(u32, &.{ 32, 32, 32, 32, 32 }, plan.lengths);
    try std.testing.expectEqualSlices(u8, &.{ 0, 1, 0, 2, 0 }, plan.types);
    try std.testing.expectEqual(@as(u16, 3), plan.type_count);
    try plan.validate(symbols.len);
}

test "adaptive distance block split rejects stationary input symbols and options" {
    const stationary = [_]u16{7} ** 96;
    try std.testing.expect((try chooseAdaptiveAlloc(std.testing.allocator, &stationary, .{})) == null);

    try std.testing.expectError(
        error.InvalidSymbol,
        chooseAdaptiveAlloc(std.testing.allocator, &.{ 0, alphabet_size }, .{}),
    );
    try std.testing.expectError(
        error.InvalidOptions,
        chooseAdaptiveAlloc(std.testing.allocator, &stationary, .{ .type_count = 0 }),
    );
    try std.testing.expectError(
        error.InvalidOptions,
        chooseAdaptiveAlloc(std.testing.allocator, &stationary, .{ .iterations = 0 }),
    );
    try std.testing.expectError(
        error.InvalidOptions,
        chooseAdaptiveAlloc(std.testing.allocator, &stationary, .{
            .min_symbols = 97,
            .max_symbols = 96,
        }),
    );
}

test "adaptive distance block split propagates and unwinds allocator failures" {
    var symbols: [120]u16 = undefined;
    for (symbols[0..47], 0..) |*symbol, index| symbol.* = @intCast(index % 4);
    for (symbols[47..], 0..) |*symbol, index| symbol.* = @intCast(75 + index % 4);

    // Seven scratch allocations and two final-plan allocations must each
    // propagate OutOfMemory and release every preceding allocation.
    for (0..9) |fail_index| {
        var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{
            .fail_index = fail_index,
        });
        try std.testing.expectError(
            error.OutOfMemory,
            chooseAdaptiveAlloc(failing.allocator(), &symbols, .{
                .type_count = 2,
                .switch_cost_q8 = 2 * histogram_model.cost_scale,
            }),
        );
        try std.testing.expect(failing.has_induced_failure);
        try std.testing.expectEqual(failing.allocated_bytes, failing.freed_bytes);
    }
}
