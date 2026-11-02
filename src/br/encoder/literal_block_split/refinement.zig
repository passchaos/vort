const interval_cost = @import("interval_cost.zig");
const huffman = @import("../../../huffman.zig");

/// Refine only a two-region proposal that passed its exact savings gate.
/// Keeping the large histogram search here avoids reserving its workspace in
/// the common early-screening path. Rules are supplied by the selector.
pub noinline fn refine(
    comptime Rules: type,
    comptime memoize: bool,
    targets: []const usize,
    prefix_snapshots: *const [Rules.candidate_count][256]u32,
    total_frequencies: *const [256]u32,
    total_literals: usize,
    baseline_entropy: u64,
    baseline_bits: u64,
    best_split: usize,
    best_split_index: usize,
    prefix_bits: u64,
    suffix_bits: u64,
) Rules.Proposals {
    const target_len = targets.len;
    const min_block_literals = Rules.min_block_literals;
    const split_bits = prefix_bits + suffix_bits;
    // Prepare memo storage only after the exact two-region gate accepts the
    // search, then reuse the two costs that gate already computed.
    var costs: interval_cost.Cache(Rules.candidate_count + 2) = .{};
    if (memoize) {
        costs.seed(0, best_split_index + 1, prefix_bits);
        costs.seed(best_split_index + 1, target_len + 1, suffix_bits);
    }
    var proposals = Rules.Proposals{ .two = .{
        .split = best_split,
        .savings_bits = baseline_bits - split_bits,
    } };

    var best_clustered_bits = baseline_bits;
    var best_clustered_first: usize = Rules.candidate_count;
    var best_clustered_second: usize = Rules.candidate_count;
    var best_three_bits = baseline_bits;
    var best_three_first: usize = Rules.candidate_count;
    var best_three_second: usize = Rules.candidate_count;
    for (0..target_len) |first_index| {
        for (first_index + 1..target_len) |second_index| {
            const first_split = targets[first_index];
            const second_split = targets[second_index];
            if (first_split < min_block_literals or
                second_split - first_split < min_block_literals or
                total_literals - second_split < min_block_literals)
                continue;
            var middle: [256]u32 = undefined;
            var outer: [256]u32 = undefined;
            var suffix: [256]u32 = undefined;
            for (&middle, &outer, &prefix_snapshots[first_index], &prefix_snapshots[second_index], total_frequencies) |*middle_out, *outer_out, first, second, total| {
                middle_out.* = second - first;
                outer_out.* = @as(u32, first) + total - second;
            }
            for (&suffix, &prefix_snapshots[second_index], total_frequencies) |*out, second, total|
                out.* = total - second;
            const three_bits = contiguousCost(Rules, memoize, &costs, 0, first_index + 1, &prefix_snapshots[first_index]) +
                contiguousCost(Rules, memoize, &costs, first_index + 1, second_index + 1, &middle) +
                contiguousCost(Rules, memoize, &costs, second_index + 1, target_len + 1, &suffix);
            if (three_bits < best_three_bits) {
                best_three_bits = three_bits;
                best_three_first = first_index;
                best_three_second = second_index;
            }
            const outer_lengths = huffman.treeCodeLengths(256, &outer, 15);
            const clustered_bits = Rules.weightedBits(&outer, &outer_lengths) +
                contiguousCost(Rules, memoize, &costs, first_index + 1, second_index + 1, &middle);
            if (clustered_bits < best_clustered_bits) {
                best_clustered_bits = clustered_bits;
                best_clustered_first = first_index;
                best_clustered_second = second_index;
            }
        }
    }
    if (best_three_first != Rules.candidate_count) {
        const savings = baseline_bits - best_three_bits;
        if (savings >= Rules.min_estimated_savings_bits and
            savings -| proposals.two.?.savings_bits >= Rules.min_three_over_two_savings_bits)
        {
            proposals.three = .{
                .split = targets[best_three_first],
                .second_split = targets[best_three_second],
                .savings_bits = savings,
            };
        }
    }
    if (best_clustered_first != Rules.candidate_count) {
        const savings = baseline_bits - best_clustered_bits;
        if (savings >= Rules.min_estimated_savings_bits and
            savings -| proposals.two.?.savings_bits >= Rules.min_clustered_over_two_savings_bits)
        {
            proposals.clustered = .{
                .split = targets[best_clustered_first],
                .second_split = targets[best_clustered_second],
                .alternate_two_types = true,
                .savings_bits = savings,
            };
        }
    }
    var best_alternating_bits = baseline_bits;
    var best_alternating_indexes: [3]usize = @splat(Rules.candidate_count);
    var best_reuse_first_bits = baseline_bits;
    var best_reuse_first_indexes: [3]usize = @splat(Rules.candidate_count);
    var best_four_bits = baseline_bits;
    var best_four_indexes: [3]usize = @splat(Rules.candidate_count);
    for (0..target_len) |first_index| {
        for (first_index + 1..target_len) |second_index| {
            for (second_index + 1..target_len) |third_index| {
                const first_split = targets[first_index];
                const second_split = targets[second_index];
                const third_split = targets[third_index];
                if (first_split < min_block_literals or
                    second_split - first_split < min_block_literals or
                    third_split - second_split < min_block_literals or
                    total_literals - third_split < min_block_literals)
                    continue;
                var type_a: [256]u32 = undefined;
                var type_b: [256]u32 = undefined;
                for (&type_a, &type_b, &prefix_snapshots[first_index], &prefix_snapshots[second_index], &prefix_snapshots[third_index], total_frequencies) |*a, *b, first, second, third, total| {
                    a.* = @as(u32, first) + third - second;
                    b.* = @as(u32, second) - first + total - third;
                }
                const type_a_lengths = huffman.treeCodeLengths(256, &type_a, 15);
                const type_b_lengths = huffman.treeCodeLengths(256, &type_b, 15);
                const alternating_bits = Rules.weightedBits(&type_a, &type_a_lengths) +
                    Rules.weightedBits(&type_b, &type_b_lengths);
                if (alternating_bits < best_alternating_bits) {
                    best_alternating_bits = alternating_bits;
                    best_alternating_indexes = .{ first_index, second_index, third_index };
                }
                var outer: [256]u32 = undefined;
                var second_region: [256]u32 = undefined;
                var third_region: [256]u32 = undefined;
                var fourth_region: [256]u32 = undefined;
                for (&outer, &second_region, &third_region, &fourth_region, &prefix_snapshots[first_index], &prefix_snapshots[second_index], &prefix_snapshots[third_index], total_frequencies) |*outer_out, *second_out, *third_out, *fourth_out, first, second, third, total| {
                    outer_out.* = @as(u32, first) + total - third;
                    second_out.* = @as(u32, second) - first;
                    third_out.* = @as(u32, third) - second;
                    fourth_out.* = total - third;
                }
                const outer_lengths = huffman.treeCodeLengths(256, &outer, 15);
                const second_bits = contiguousCost(Rules, memoize, &costs, first_index + 1, second_index + 1, &second_region);
                const third_bits = contiguousCost(Rules, memoize, &costs, second_index + 1, third_index + 1, &third_region);
                const reuse_first_bits = Rules.weightedBits(&outer, &outer_lengths) + second_bits + third_bits;
                if (reuse_first_bits < best_reuse_first_bits) {
                    best_reuse_first_bits = reuse_first_bits;
                    best_reuse_first_indexes = .{ first_index, second_index, third_index };
                }
                const four_bits = contiguousCost(Rules, memoize, &costs, 0, first_index + 1, &prefix_snapshots[first_index]) +
                    second_bits + third_bits +
                    contiguousCost(Rules, memoize, &costs, third_index + 1, target_len + 1, &fourth_region);
                if (four_bits < best_four_bits) {
                    best_four_bits = four_bits;
                    best_four_indexes = .{ first_index, second_index, third_index };
                }
            }
        }
    }
    if (best_alternating_indexes[0] != Rules.candidate_count) {
        const savings = baseline_bits - best_alternating_bits;
        const refined_baseline = @max(
            proposals.two.?.savings_bits,
            @max(
                if (proposals.clustered) |clustered| clustered.savings_bits else 0,
                if (proposals.three) |three| three.savings_bits else 0,
            ),
        );
        if (savings >= Rules.min_estimated_savings_bits and
            savings -| refined_baseline >= Rules.min_alternating_four_over_best_savings_bits)
        {
            proposals.alternating_four = .{
                .split = targets[best_alternating_indexes[0]],
                .second_split = targets[best_alternating_indexes[1]],
                .third_split = targets[best_alternating_indexes[2]],
                .alternate_two_types = true,
                .savings_bits = savings,
            };
        }
    }
    if (best_reuse_first_indexes[0] != Rules.candidate_count) {
        const savings = baseline_bits - best_reuse_first_bits;
        const refined_baseline = @max(
            proposals.two.?.savings_bits,
            @max(
                if (proposals.clustered) |clustered| clustered.savings_bits else 0,
                @max(
                    if (proposals.three) |three| three.savings_bits else 0,
                    if (proposals.alternating_four) |alternating| alternating.savings_bits else 0,
                ),
            ),
        );
        if (savings >= 2 * Rules.min_estimated_savings_bits and
            savings -| refined_baseline >= Rules.min_reuse_first_four_over_best_savings_bits)
        {
            proposals.reuse_first_four = .{
                .split = targets[best_reuse_first_indexes[0]],
                .second_split = targets[best_reuse_first_indexes[1]],
                .third_split = targets[best_reuse_first_indexes[2]],
                .reuse_first_for_fourth = true,
                .savings_bits = savings,
            };
        }
    }
    if (best_four_indexes[0] != Rules.candidate_count) {
        const savings = baseline_bits - best_four_bits;
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
        if (savings >= 2 * Rules.min_estimated_savings_bits and
            savings -| refined_baseline >= Rules.min_four_over_best_savings_bits)
        {
            proposals.four = .{
                .split = targets[best_four_indexes[0]],
                .second_split = targets[best_four_indexes[1]],
                .third_split = targets[best_four_indexes[2]],
                .savings_bits = savings,
            };
        }
    }
    var fixed_best_savings = proposals.two.?.savings_bits;
    inline for (.{ proposals.three, proposals.clustered, proposals.alternating_four, proposals.reuse_first_four, proposals.four }) |proposal| {
        if (proposal) |active| fixed_best_savings = @max(fixed_best_savings, active.savings_bits);
    }
    var best_dynamic_entropy = baseline_entropy;
    var best_dynamic_mask: u8 = 0;
    var best_dynamic_type_count: usize = 0;
    const mask_limit = @as(usize, 1) << @intCast(target_len);
    for (1..mask_limit) |mask_value| {
        const mask: u8 = @intCast(mask_value);
        const boundary_count: usize = @popCount(mask);
        if (boundary_count < 4 or boundary_count >= Rules.max_regions) continue;
        const region_count = boundary_count + 1;
        var selected_indexes: [Rules.candidate_count]usize = @splat(0);
        var selected_count: usize = 0;
        for (0..target_len) |candidate_index| {
            if (mask & (@as(u8, 1) << @intCast(candidate_index)) == 0) continue;
            selected_indexes[selected_count] = candidate_index;
            selected_count += 1;
        }
        var regions: [Rules.max_regions][256]u32 = @splat(@splat(0));
        var previous: [256]u32 = @splat(0);
        var valid = true;
        var previous_boundary: usize = 0;
        for (0..boundary_count) |region| {
            const boundary = targets[selected_indexes[region]];
            if (boundary - previous_boundary < min_block_literals) valid = false;
            previous_boundary = boundary;
            const prefix = prefix_snapshots[selected_indexes[region]];
            for (&regions[region], &prefix, &previous) |*out, through, before|
                out.* = through - before;
            previous = prefix;
        }
        if (total_literals - previous_boundary < min_block_literals) valid = false;
        if (!valid) continue;
        for (&regions[region_count - 1], total_frequencies, &previous) |*out, all, before|
            out.* = all - before;
        for (2..region_count + 1) |type_count| {
            var pooled: [Rules.max_regions][256]u32 = @splat(@splat(0));
            for (regions[0..region_count], 0..) |region_frequencies, region| {
                for (&pooled[region % type_count], &region_frequencies) |*out, frequency|
                    out.* += frequency;
            }
            var candidate_entropy: u64 = 0;
            for (pooled[0..type_count]) |*frequencies|
                candidate_entropy += Rules.entropyBitsQ8(frequencies);
            if (candidate_entropy < best_dynamic_entropy) {
                best_dynamic_entropy = candidate_entropy;
                best_dynamic_mask = mask;
                best_dynamic_type_count = type_count;
            }
        }
    }
    if (best_dynamic_mask != 0 and
        baseline_entropy - best_dynamic_entropy >= 2 * Rules.min_entropy_proposal_savings_bits * Rules.entropy_scale)
    {
        const boundary_count: usize = @popCount(best_dynamic_mask);
        const region_count = boundary_count + 1;
        var boundaries: [Rules.max_regions - 1]usize = @splat(0);
        var selected_indexes: [Rules.candidate_count]usize = @splat(0);
        var selected_count: usize = 0;
        for (0..target_len) |candidate_index| {
            if (best_dynamic_mask & (@as(u8, 1) << @intCast(candidate_index)) == 0) continue;
            boundaries[selected_count] = targets[candidate_index];
            selected_indexes[selected_count] = candidate_index;
            selected_count += 1;
        }
        var pooled: [Rules.max_regions][256]u32 = @splat(@splat(0));
        var previous: [256]u32 = @splat(0);
        for (0..region_count) |region| {
            var frequencies: [256]u32 = undefined;
            if (region + 1 < region_count) {
                const prefix = prefix_snapshots[selected_indexes[region]];
                for (&frequencies, &prefix, &previous) |*out, through, before|
                    out.* = through - before;
                previous = prefix;
            } else for (&frequencies, total_frequencies, &previous) |*out, all, before|
                out.* = all - before;
            for (&pooled[region % best_dynamic_type_count], &frequencies) |*out, frequency|
                out.* += frequency;
        }
        var dynamic_bits: u64 = 0;
        for (pooled[0..best_dynamic_type_count]) |*frequencies| {
            const lengths = huffman.treeCodeLengths(256, frequencies, 15);
            dynamic_bits += Rules.weightedBits(frequencies, &lengths);
        }
        const savings = baseline_bits -| dynamic_bits;
        if (savings >= 2 * Rules.min_estimated_savings_bits and
            savings -| fixed_best_savings >= Rules.min_dynamic_over_best_savings_bits)
        {
            var result = Rules.Result{
                .split = boundaries[0],
                .cycle_type_count = best_dynamic_type_count,
                .savings_bits = savings,
            };
            if (boundary_count >= 2) result.second_split = boundaries[1];
            if (boundary_count >= 3) result.third_split = boundaries[2];
            if (boundary_count >= 4) result.fourth_split = boundaries[3];
            if (boundary_count >= 5) result.fifth_split = boundaries[4];
            proposals.dynamic = result;
        }
    }
    return proposals;
}

inline fn contiguousCost(comptime Rules: type, comptime memoize: bool, cache: *interval_cost.Cache(Rules.candidate_count + 2), start: usize, end: usize, frequencies: *const [256]u32) u64 {
    return if (memoize) cache.cost(start, end, frequencies) else interval_cost.weightedCost(frequencies);
}
