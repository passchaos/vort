const std = @import("std");
const huffman = @import("../../huffman.zig");
const command_plan = @import("command_plan.zig");
const literal_context = @import("literal_context.zig");

const min_block_literals: usize = 512;
const max_split_literals: usize = 32 * 1024;
const candidate_fractions = [_]struct { numerator: usize, denominator: usize }{
    .{ .numerator = 1, .denominator = 6 },
    .{ .numerator = 1, .denominator = 4 },
    .{ .numerator = 1, .denominator = 3 },
    .{ .numerator = 1, .denominator = 2 },
    .{ .numerator = 2, .denominator = 3 },
    .{ .numerator = 3, .denominator = 4 },
    .{ .numerator = 5, .denominator = 6 },
};
const candidate_count: usize = candidate_fractions.len;
const min_estimated_savings_bits: u64 = 2048;
const min_entropy_proposal_savings_bits: u64 = min_estimated_savings_bits * 3 / 4;
const min_clustered_over_two_savings_bits: u64 = 128;
const min_three_over_two_savings_bits: u64 = 1024;
const min_alternating_four_over_best_savings_bits: u64 = 256;
const min_reuse_first_four_over_best_savings_bits: u64 = 128;
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
    alternate_two_types: bool = false,
    reuse_first_for_fourth: bool = false,
    savings_bits: u64,

    pub fn regionCount(self: Result) usize {
        return if (self.third_split != null) 4 else if (self.second_split != null) 3 else 2;
    }

    pub fn typeCount(self: Result) usize {
        return if (self.alternate_two_types) 2 else if (self.reuse_first_for_fourth) 3 else self.regionCount();
    }

    pub fn blockIndex(self: Result, literal_index: usize) usize {
        if (literal_index < self.split) return 0;
        if (self.second_split) |second| {
            if (literal_index < second) return 1;
            if (self.third_split) |third| {
                if (self.alternate_two_types) return if (literal_index < third) 0 else 1;
                return if (literal_index < third) 2 else if (self.reuse_first_for_fourth) 0 else 3;
            }
            return if (self.alternate_two_types) 0 else 2;
        }
        return 1;
    }
};

pub const Proposals = struct {
    two: ?Result = null,
    three: ?Result = null,
    clustered: ?Result = null,
    alternating_four: ?Result = null,
    reuse_first_four: ?Result = null,
};

/// Choose one literal-stream boundary for a two-type Brotli entropy split.
/// This cheap proposal stage examines seven bounded sixth-, quarter-, third-,
/// and midpoint boundaries.
/// The caller still encodes the complete candidate and selects it only when
/// its exact wire size beats the existing stream.
pub fn choose(input: []const u8, commands: []const command_plan.Command, utf8_context_cutoff: ?u6) ?Result {
    return chooseProposals(input, commands, utf8_context_cutoff).two;
}

pub fn chooseProposals(input: []const u8, commands: []const command_plan.Command, utf8_context_cutoff: ?u6) Proposals {
    var total_literals: usize = 0;
    for (commands) |command| {
        if (command.insert_start > input.len or command.insert_len > input.len - command.insert_start) return .{};
        total_literals = std.math.add(usize, total_literals, command.insert_len) catch return .{};
    }
    if (total_literals < 2 * min_block_literals or total_literals > max_split_literals) return .{};

    var targets: [candidate_count]usize = undefined;
    var target_len: usize = 0;
    for (candidate_fractions) |fraction| {
        const target = total_literals * fraction.numerator / fraction.denominator;
        if (target < min_block_literals or total_literals - target < min_block_literals) continue;
        if (target_len != 0 and targets[target_len - 1] == target) continue;
        targets[target_len] = target;
        target_len += 1;
    }
    if (target_len == 0) return .{};

    var total_frequencies: [256]u32 = @splat(0);
    var context_frequencies: [2][256]u32 = @splat(@splat(0));
    var prefix_snapshots: [candidate_count][256]u32 = undefined;
    var literal_index: usize = 0;
    var target_index: usize = 0;
    for (commands) |command| {
        for (input[command.insert_start..][0..command.insert_len], command.insert_start..) |literal, position| {
            total_frequencies[literal] += 1;
            if (utf8_context_cutoff) |cutoff| {
                const previous = if (position == 0) 0 else input[position - 1];
                const second_previous = if (position < 2) 0 else input[position - 2];
                const context = literal_context.value(literal_context.mode_utf8, previous, second_previous);
                context_frequencies[literal_context.utf8SuffixTree(context, cutoff)][literal] += 1;
            }
            literal_index += 1;
            if (target_index >= target_len or literal_index != targets[target_index]) continue;
            prefix_snapshots[target_index] = total_frequencies;
            target_index += 1;
        }
    }
    if (literal_index != total_literals or target_index != target_len) return .{};

    const baseline_entropy = if (utf8_context_cutoff != null)
        entropyBitsQ8(&context_frequencies[0]) + entropyBitsQ8(&context_frequencies[1])
    else
        entropyBitsQ8(&total_frequencies);
    var best_split: ?usize = null;
    var best_entropy = baseline_entropy;
    var best_prefix_frequencies: [256]u32 = undefined;
    for (prefix_snapshots[0..target_len], targets[0..target_len]) |prefix_frequencies, target| {
        var suffix_frequencies: [256]u32 = undefined;
        for (&suffix_frequencies, &total_frequencies, &prefix_frequencies) |*suffix, total, prefix|
            suffix.* = total - prefix;
        const split_entropy = entropyBitsQ8(&prefix_frequencies) + entropyBitsQ8(&suffix_frequencies);
        if (split_entropy < best_entropy) {
            best_entropy = split_entropy;
            best_split = target;
            best_prefix_frequencies = prefix_frequencies;
        }
    }
    if (best_split == null or baseline_entropy - best_entropy < min_entropy_proposal_savings_bits * entropy_scale) return .{};

    var best_suffix_frequencies: [256]u32 = undefined;
    for (&best_suffix_frequencies, &total_frequencies, &best_prefix_frequencies) |*suffix, total, prefix|
        suffix.* = total - prefix;
    const baseline_bits = if (utf8_context_cutoff != null) blk: {
        const first_lengths = huffman.treeCodeLengths(256, &context_frequencies[0], 15);
        const second_lengths = huffman.treeCodeLengths(256, &context_frequencies[1], 15);
        break :blk weightedBits(&context_frequencies[0], &first_lengths) +
            weightedBits(&context_frequencies[1], &second_lengths);
    } else blk: {
        const baseline_lengths = huffman.treeCodeLengths(256, &total_frequencies, 15);
        break :blk weightedBits(&total_frequencies, &baseline_lengths);
    };
    const prefix_lengths = huffman.treeCodeLengths(256, &best_prefix_frequencies, 15);
    const suffix_lengths = huffman.treeCodeLengths(256, &best_suffix_frequencies, 15);
    const split_bits = weightedBits(&best_prefix_frequencies, &prefix_lengths) +
        weightedBits(&best_suffix_frequencies, &suffix_lengths);
    if (split_bits >= baseline_bits or baseline_bits - split_bits < min_estimated_savings_bits) return .{};
    var proposals = Proposals{ .two = .{
        .split = best_split.?,
        .savings_bits = baseline_bits - split_bits,
    } };

    var best_clustered_bits = baseline_bits;
    var best_clustered_first: usize = candidate_count;
    var best_clustered_second: usize = candidate_count;
    var best_three_bits = baseline_bits;
    var best_three_first: usize = candidate_count;
    var best_three_second: usize = candidate_count;
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
            for (&middle, &outer, &prefix_snapshots[first_index], &prefix_snapshots[second_index], &total_frequencies) |*middle_out, *outer_out, first, second, total| {
                middle_out.* = second - first;
                outer_out.* = @as(u32, first) + total - second;
            }
            for (&suffix, &prefix_snapshots[second_index], &total_frequencies) |*out, second, total|
                out.* = total - second;
            const first_lengths = huffman.treeCodeLengths(256, &prefix_snapshots[first_index], 15);
            const separate_middle_lengths = huffman.treeCodeLengths(256, &middle, 15);
            const region_suffix_lengths = huffman.treeCodeLengths(256, &suffix, 15);
            const three_bits = weightedBits(&prefix_snapshots[first_index], &first_lengths) +
                weightedBits(&middle, &separate_middle_lengths) +
                weightedBits(&suffix, &region_suffix_lengths);
            if (three_bits < best_three_bits) {
                best_three_bits = three_bits;
                best_three_first = first_index;
                best_three_second = second_index;
            }
            const outer_lengths = huffman.treeCodeLengths(256, &outer, 15);
            const middle_lengths = huffman.treeCodeLengths(256, &middle, 15);
            const clustered_bits = weightedBits(&outer, &outer_lengths) +
                weightedBits(&middle, &middle_lengths);
            if (clustered_bits < best_clustered_bits) {
                best_clustered_bits = clustered_bits;
                best_clustered_first = first_index;
                best_clustered_second = second_index;
            }
        }
    }
    if (best_three_first != candidate_count) {
        const savings = baseline_bits - best_three_bits;
        if (savings >= min_estimated_savings_bits and
            savings -| proposals.two.?.savings_bits >= min_three_over_two_savings_bits)
        {
            proposals.three = .{
                .split = targets[best_three_first],
                .second_split = targets[best_three_second],
                .savings_bits = savings,
            };
        }
    }
    if (best_clustered_first != candidate_count) {
        const savings = baseline_bits - best_clustered_bits;
        if (savings >= min_estimated_savings_bits and
            savings -| proposals.two.?.savings_bits >= min_clustered_over_two_savings_bits)
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
    var best_alternating_indexes: [3]usize = @splat(candidate_count);
    var best_reuse_first_bits = baseline_bits;
    var best_reuse_first_indexes: [3]usize = @splat(candidate_count);
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
                for (&type_a, &type_b, &prefix_snapshots[first_index], &prefix_snapshots[second_index], &prefix_snapshots[third_index], &total_frequencies) |*a, *b, first, second, third, total| {
                    a.* = @as(u32, first) + third - second;
                    b.* = @as(u32, second) - first + total - third;
                }
                const type_a_lengths = huffman.treeCodeLengths(256, &type_a, 15);
                const type_b_lengths = huffman.treeCodeLengths(256, &type_b, 15);
                const alternating_bits = weightedBits(&type_a, &type_a_lengths) +
                    weightedBits(&type_b, &type_b_lengths);
                if (alternating_bits < best_alternating_bits) {
                    best_alternating_bits = alternating_bits;
                    best_alternating_indexes = .{ first_index, second_index, third_index };
                }
                var outer: [256]u32 = undefined;
                var second_region: [256]u32 = undefined;
                var third_region: [256]u32 = undefined;
                for (&outer, &second_region, &third_region, &prefix_snapshots[first_index], &prefix_snapshots[second_index], &prefix_snapshots[third_index], &total_frequencies) |*outer_out, *second_out, *third_out, first, second, third, total| {
                    outer_out.* = @as(u32, first) + total - third;
                    second_out.* = @as(u32, second) - first;
                    third_out.* = @as(u32, third) - second;
                }
                const outer_lengths = huffman.treeCodeLengths(256, &outer, 15);
                const second_lengths = huffman.treeCodeLengths(256, &second_region, 15);
                const third_lengths = huffman.treeCodeLengths(256, &third_region, 15);
                const reuse_first_bits = weightedBits(&outer, &outer_lengths) +
                    weightedBits(&second_region, &second_lengths) +
                    weightedBits(&third_region, &third_lengths);
                if (reuse_first_bits < best_reuse_first_bits) {
                    best_reuse_first_bits = reuse_first_bits;
                    best_reuse_first_indexes = .{ first_index, second_index, third_index };
                }
            }
        }
    }
    if (best_alternating_indexes[0] != candidate_count) {
        const savings = baseline_bits - best_alternating_bits;
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
                .split = targets[best_alternating_indexes[0]],
                .second_split = targets[best_alternating_indexes[1]],
                .third_split = targets[best_alternating_indexes[2]],
                .alternate_two_types = true,
                .savings_bits = savings,
            };
        }
    }
    if (best_reuse_first_indexes[0] != candidate_count) {
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
        if (savings >= 2 * min_estimated_savings_bits and
            savings -| refined_baseline >= min_reuse_first_four_over_best_savings_bits)
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
    return proposals;
}

/// Fixed-point approximation of upstream Brotli's `BrotliBitsEntropy`. The
/// leading bit and an eight-bit mantissa index avoid floating-point logarithms
/// in the ratio proposal path while preserving enough ordering precision for
/// the exact Huffman-cost gate below.
fn entropyBitsQ8(frequencies: *const [256]u32) u64 {
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
    const normalized = if (floor >= 8)
        value >> @intCast(floor - 8)
    else
        value << @intCast(8 - floor);
    return @as(u64, floor) * entropy_scale + log2_fraction_q8[normalized - 256];
}

fn weightedBits(frequencies: *const [256]u32, lengths: *const [256]u4) u64 {
    var total: u64 = 0;
    for (frequencies, lengths) |frequency, bits| total += @as(u64, frequency) * bits;
    return total;
}

test "literal block split selects a strong distribution boundary" {
    var input: [4096]u8 = undefined;
    for (input[0..2048], 0..) |*byte, i| byte.* = @intCast(i & 15);
    for (input[2048..], 0..) |*byte, i| byte.* = @intCast(240 + (i & 15));
    const commands = [_]command_plan.Command{.{ .insert_start = 0, .insert_len = input.len }};
    const split = choose(&input, &commands, null) orelse return error.TestUnexpectedResult;
    try std.testing.expect(split.split >= 1536 and split.split <= 2560);
}

test "literal block split rejects stationary distributions" {
    var input: [4096]u8 = undefined;
    for (&input, 0..) |*byte, i| byte.* = @intCast(i & 31);
    const commands = [_]command_plan.Command{.{ .insert_start = 0, .insert_len = input.len }};
    try std.testing.expectEqual(@as(?Result, null), choose(&input, &commands, null));
}

test "literal block split keeps proposal work bounded" {
    const input = try std.testing.allocator.alloc(u8, max_split_literals + 1);
    defer std.testing.allocator.free(input);
    @memset(input, 'a');
    const commands = [_]command_plan.Command{.{ .insert_start = 0, .insert_len = input.len }};
    try std.testing.expectEqual(@as(?Result, null), choose(input, &commands, null));
}

test "literal block split avoids work already explained by UTF8 contexts" {
    var input: [4096]u8 = undefined;
    for (input[0..2048], 0..) |*byte, i| byte.* = @intCast('a' + (i & 15));
    for (input[2048..], 0..) |*byte, i| byte.* = @intCast(i & 15);
    const commands = [_]command_plan.Command{.{ .insert_start = 0, .insert_len = input.len }};
    try std.testing.expect(choose(&input, &commands, null) != null);
    try std.testing.expectEqual(@as(?Result, null), choose(&input, &commands, 56));
}

test "literal block split clusters matching outer regions" {
    var input: [6144]u8 = undefined;
    for (input[0..2048], 0..) |*byte, i| byte.* = @intCast(i & 15);
    for (input[2048..4096], 0..) |*byte, i| byte.* = @intCast(240 + (i & 15));
    for (input[4096..], 0..) |*byte, i| byte.* = @intCast(i & 15);
    const commands = [_]command_plan.Command{.{ .insert_start = 0, .insert_len = input.len }};
    const clustered = chooseProposals(&input, &commands, null).clustered orelse
        return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(usize, 3), clustered.regionCount());
    try std.testing.expectEqual(@as(usize, 2), clustered.typeCount());
    try std.testing.expectEqual(@as(usize, 0), clustered.blockIndex(0));
    try std.testing.expectEqual(@as(usize, 1), clustered.blockIndex(clustered.split));
    try std.testing.expectEqual(@as(usize, 0), clustered.blockIndex(clustered.second_split.?));
}

test "literal block split selects three distinct regions" {
    var input: [6144]u8 = undefined;
    for (input[0..2048], 0..) |*byte, i| byte.* = @intCast(i & 15);
    for (input[2048..4096], 0..) |*byte, i| byte.* = @intCast(112 + (i & 15));
    for (input[4096..], 0..) |*byte, i| byte.* = @intCast(240 + (i & 15));
    const commands = [_]command_plan.Command{.{ .insert_start = 0, .insert_len = input.len }};
    const three = chooseProposals(&input, &commands, null).three orelse
        return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(usize, 3), three.regionCount());
    try std.testing.expectEqual(@as(usize, 3), three.typeCount());
    try std.testing.expectEqual(@as(usize, 0), three.blockIndex(0));
    try std.testing.expectEqual(@as(usize, 1), three.blockIndex(three.split));
    try std.testing.expectEqual(@as(usize, 2), three.blockIndex(three.second_split.?));
}

test "literal block split clusters four alternating regions" {
    var input: [8192]u8 = undefined;
    for (&input, 0..) |*byte, i| {
        const region = i / 2048;
        byte.* = if (region & 1 == 0)
            @intCast(i & 15)
        else
            @intCast(240 + (i & 15));
    }
    const commands = [_]command_plan.Command{.{ .insert_start = 0, .insert_len = input.len }};
    const alternating = chooseProposals(&input, &commands, null).alternating_four orelse
        return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(usize, 4), alternating.regionCount());
    try std.testing.expectEqual(@as(usize, 2), alternating.typeCount());
    try std.testing.expectEqual(@as(usize, 0), alternating.blockIndex(0));
    try std.testing.expectEqual(@as(usize, 1), alternating.blockIndex(alternating.split));
    try std.testing.expectEqual(@as(usize, 0), alternating.blockIndex(alternating.second_split.?));
    try std.testing.expectEqual(@as(usize, 1), alternating.blockIndex(alternating.third_split.?));
}

test "literal block split reuses the first of three types in region four" {
    var input: [8192]u8 = undefined;
    for (&input, 0..) |*byte, i| {
        const region = i / 2048;
        byte.* = switch (region) {
            0, 3 => @intCast(i & 15),
            1 => @intCast(112 + (i & 15)),
            2 => @intCast(240 + (i & 15)),
            else => unreachable,
        };
    }
    const commands = [_]command_plan.Command{.{ .insert_start = 0, .insert_len = input.len }};
    const reused = chooseProposals(&input, &commands, null).reuse_first_four orelse
        return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(usize, 4), reused.regionCount());
    try std.testing.expectEqual(@as(usize, 3), reused.typeCount());
    try std.testing.expectEqual(@as(usize, 0), reused.blockIndex(0));
    try std.testing.expectEqual(@as(usize, 1), reused.blockIndex(reused.split));
    try std.testing.expectEqual(@as(usize, 2), reused.blockIndex(reused.second_split.?));
    try std.testing.expectEqual(@as(usize, 0), reused.blockIndex(reused.third_split.?));
}

test "literal block split fixed-point logarithm tracks powers and mantissas" {
    try std.testing.expectEqual(@as(u64, 0), fastLog2Q8(0));
    try std.testing.expectEqual(@as(u64, 0), fastLog2Q8(1));
    try std.testing.expectEqual(@as(u64, 8 * 256), fastLog2Q8(256));
    for (1..4097) |value| {
        const exact = @log2(@as(f64, @floatFromInt(value))) * 256.0;
        const approximate: f64 = @floatFromInt(fastLog2Q8(@intCast(value)));
        try std.testing.expect(@abs(exact - approximate) <= 2.0);
    }
}
