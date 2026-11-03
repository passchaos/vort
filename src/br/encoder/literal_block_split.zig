const std = @import("std");
const huffman = @import("../../huffman.zig");
const adaptive_block_split = @import("adaptive_block_split.zig");
const block_split_plan = @import("block_split_plan.zig");
const command_plan = @import("command_plan.zig");
const histogram_model = @import("histogram_model.zig");
const literal_context = @import("literal_context.zig");
const refinement = @import("literal_block_split/refinement.zig");
const Splitter = @This();

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
pub const max_regions: usize = 6;
const min_estimated_savings_bits: u64 = 2048;
const min_entropy_proposal_savings_bits: u64 = min_estimated_savings_bits * 3 / 4;
const min_clustered_over_two_savings_bits: u64 = 128;
const min_three_over_two_savings_bits: u64 = 1024;
const min_alternating_four_over_best_savings_bits: u64 = 256;
const min_reuse_first_four_over_best_savings_bits: u64 = 128;
const min_four_over_best_savings_bits: u64 = 1024;
const min_dynamic_over_best_savings_bits: u64 = 1024;
const entropy_fraction_bits: u6 = 8;
const entropy_scale: u64 = 1 << entropy_fraction_bits;

const RefinementRules = struct {
    pub const min_block_literals = Splitter.min_block_literals;
    pub const candidate_count = Splitter.candidate_count;
    pub const max_regions = Splitter.max_regions;
    pub const min_estimated_savings_bits = Splitter.min_estimated_savings_bits;
    pub const min_clustered_over_two_savings_bits = Splitter.min_clustered_over_two_savings_bits;
    pub const min_three_over_two_savings_bits = Splitter.min_three_over_two_savings_bits;
    pub const min_alternating_four_over_best_savings_bits = Splitter.min_alternating_four_over_best_savings_bits;
    pub const min_reuse_first_four_over_best_savings_bits = Splitter.min_reuse_first_four_over_best_savings_bits;
    pub const min_four_over_best_savings_bits = Splitter.min_four_over_best_savings_bits;
    pub const min_dynamic_over_best_savings_bits = Splitter.min_dynamic_over_best_savings_bits;
    pub const min_entropy_proposal_savings_bits = Splitter.min_entropy_proposal_savings_bits;
    pub const entropy_scale = Splitter.entropy_scale;
    pub const Proposals = Splitter.Proposals;
    pub const Result = Splitter.Result;
    pub const weightedBits = Splitter.weightedBits;
    pub const entropyBitsQ8 = Splitter.entropyBitsQ8;
};

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

    pub fn blockIndex(self: Result, literal_index: usize) usize {
        var region: usize = 0;
        while (region + 1 < self.regionCount() and literal_index >= self.boundary(region))
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

const AdaptiveSplitter = adaptive_block_split.Splitter(u8, 256);
pub const AdaptiveOptions = AdaptiveSplitter.Options;

/// Discover arbitrary literal boundaries and non-cyclic type reuse. The
/// legacy fixed-grid proposals remain separate complete-wire candidates until
/// this general plan proves smaller after all Brotli header costs.
pub fn chooseAdaptiveAlloc(
    allocator: std.mem.Allocator,
    literals: []const u8,
    options: AdaptiveOptions,
) !?block_split_plan.Plan {
    return AdaptiveSplitter.splitAlloc(allocator, literals, options);
}

/// Choose one literal-stream boundary for a two-type Brotli entropy split.
/// This cheap proposal stage examines seven bounded sixth-, quarter-, third-,
/// and midpoint boundaries.
/// The caller still encodes the complete candidate and selects it only when
/// its exact wire size beats the existing stream.
pub fn choose(input: []const u8, commands: []const command_plan.Command, utf8_context_cutoff: ?u6) ?Result {
    return chooseProposals(input, commands, utf8_context_cutoff).two;
}

pub fn chooseProposals(input: []const u8, commands: []const command_plan.Command, utf8_context_cutoff: ?u6) Proposals {
    return chooseProposalsMode(true, input, commands, utf8_context_cutoff);
}

/// Exact proposal oracle without interval reuse. Both paths retain the same
/// candidate order, strict ties and final savings gates.
pub fn chooseProposalsReference(input: []const u8, commands: []const command_plan.Command, utf8_context_cutoff: ?u6) Proposals {
    return chooseProposalsMode(false, input, commands, utf8_context_cutoff);
}

fn chooseProposalsMode(comptime memoize: bool, input: []const u8, commands: []const command_plan.Command, utf8_context_cutoff: ?u6) Proposals {
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
                const context = literal_context.valueClustered(literal_context.mode_utf8, previous, second_previous);
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
    const prefix_bits = weightedBits(&best_prefix_frequencies, &prefix_lengths);
    const suffix_bits = weightedBits(&best_suffix_frequencies, &suffix_lengths);
    const split_bits = prefix_bits + suffix_bits;
    if (split_bits >= baseline_bits or baseline_bits - split_bits < min_estimated_savings_bits) return .{};
    const best_split_index = std.mem.indexOfScalar(usize, targets[0..target_len], best_split.?).?;
    return refinement.refine(
        RefinementRules,
        memoize,
        targets[0..target_len],
        &prefix_snapshots,
        &total_frequencies,
        total_literals,
        baseline_entropy,
        baseline_bits,
        best_split.?,
        best_split_index,
        prefix_bits,
        suffix_bits,
    );
}

test "literal interval cost memo preserves all proposals and savings" {
    try @import("literal_block_split_tests/interval_cost.zig").check(@This());
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

test "literal block split selects four distinct regions" {
    var input: [8192]u8 = undefined;
    for (&input, 0..) |*byte, i| {
        const region = i / 2048;
        byte.* = @intCast(region * 80 + (i & 15));
    }
    const commands = [_]command_plan.Command{.{ .insert_start = 0, .insert_len = input.len }};
    const four = chooseProposals(&input, &commands, null).four orelse
        return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(usize, 4), four.regionCount());
    try std.testing.expectEqual(@as(usize, 4), four.typeCount());
    try std.testing.expectEqual(@as(usize, 0), four.blockIndex(0));
    try std.testing.expectEqual(@as(usize, 1), four.blockIndex(four.split));
    try std.testing.expectEqual(@as(usize, 2), four.blockIndex(four.second_split.?));
    try std.testing.expectEqual(@as(usize, 3), four.blockIndex(four.third_split.?));
}

test "literal block split selects five independent regions" {
    var input: [12_288]u8 = undefined;
    const boundaries = [4]usize{ 2048, 4096, 6144, 8192 };
    for (&input, 0..) |*byte, i| {
        const region: usize = if (i < boundaries[0]) 0 else if (i < boundaries[1]) 1 else if (i < boundaries[2]) 2 else if (i < boundaries[3]) 3 else 4;
        byte.* = @intCast(region * 48 + (i & 15));
    }
    const commands = [_]command_plan.Command{.{ .insert_start = 0, .insert_len = input.len }};
    const result = chooseProposals(&input, &commands, null).dynamic orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(usize, 5), result.regionCount());
    try std.testing.expectEqual(@as(usize, 5), result.typeCount());
    for (0..5) |region|
        try std.testing.expectEqual(region, result.blockIndex(if (region == 0) 0 else result.boundary(region - 1)));
}

test "literal block split cycles three trees across six regions" {
    var input: [12_288]u8 = undefined;
    for (&input, 0..) |*byte, i| {
        const region = i / 2048;
        byte.* = @intCast((region % 3) * 96 + (i & 15));
    }
    const commands = [_]command_plan.Command{.{ .insert_start = 0, .insert_len = input.len }};
    const result = chooseProposals(&input, &commands, null).dynamic orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(usize, 6), result.regionCount());
    try std.testing.expectEqual(@as(usize, 3), result.typeCount());
    for (0..6) |region|
        try std.testing.expectEqual(region % 3, result.blockIndex(region * 2048));
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

test "adaptive literal block split finds an arbitrary off-grid boundary" {
    var literals: [120]u8 = undefined;
    const expected_split: usize = 47;
    for (literals[0..expected_split], 0..) |*literal, index|
        literal.* = @intCast(index % 4);
    for (literals[expected_split..], 0..) |*literal, index|
        literal.* = @intCast(252 + index % 4);

    const plan = (try chooseAdaptiveAlloc(std.testing.allocator, &literals, .{
        .type_count = 2,
        .switch_cost_q8 = 2 * histogram_model.cost_scale,
    })) orelse return error.TestUnexpectedResult;
    defer plan.deinit(std.testing.allocator);

    try std.testing.expectEqualSlices(u32, &.{ expected_split, literals.len - expected_split }, plan.lengths);
    try std.testing.expectEqualSlices(u8, &.{ 0, 1 }, plan.types);
    try std.testing.expectEqual(@as(u16, 2), plan.type_count);
    try plan.validate(literals.len);
}

test "adaptive literal block split preserves non-cyclic type reuse" {
    var literals: [160]u8 = undefined;
    @memset(literals[0..32], 0);
    @memset(literals[32..64], 127);
    @memset(literals[64..96], 0);
    @memset(literals[96..128], 255);
    @memset(literals[128..160], 0);

    const plan = (try chooseAdaptiveAlloc(std.testing.allocator, &literals, .{
        .type_count = 5,
        .switch_cost_q8 = histogram_model.cost_scale,
    })) orelse return error.TestUnexpectedResult;
    defer plan.deinit(std.testing.allocator);

    try std.testing.expectEqualSlices(u32, &.{ 32, 32, 32, 32, 32 }, plan.lengths);
    try std.testing.expectEqualSlices(u8, &.{ 0, 1, 0, 2, 0 }, plan.types);
    try std.testing.expectEqual(@as(u16, 3), plan.type_count);
    try plan.validate(literals.len);
}

test "adaptive literal block split rejects stationary input and invalid options" {
    const stationary = [_]u8{7} ** 96;
    try std.testing.expect((try chooseAdaptiveAlloc(std.testing.allocator, &stationary, .{})) == null);

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

test "adaptive literal block split propagates and unwinds all allocator failures" {
    var literals: [120]u8 = undefined;
    for (literals[0..47], 0..) |*literal, index| literal.* = @intCast(index % 4);
    for (literals[47..], 0..) |*literal, index| literal.* = @intCast(252 + index % 4);

    // Seven scratch allocations and two final-plan allocations must each
    // propagate OutOfMemory and release every preceding allocation.
    for (0..9) |fail_index| {
        var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{
            .fail_index = fail_index,
        });
        try std.testing.expectError(
            error.OutOfMemory,
            chooseAdaptiveAlloc(failing.allocator(), &literals, .{
                .type_count = 2,
                .switch_cost_q8 = 2 * histogram_model.cost_scale,
            }),
        );
        try std.testing.expect(failing.has_induced_failure);
        try std.testing.expectEqual(failing.allocated_bytes, failing.freed_bytes);
    }
}
