const std = @import("std");
const builtin = @import("builtin");
const lz77 = @import("../../lz77.zig");

pub const text_section = switch (builtin.object_format) {
    .elf => ".vort_zstd_zz_optimal",
    .macho => "__TEXT,__vort_zstd_zo",
    .coff => ".text$vort_zstd_zz_optimal",
    else => ".text",
};

const min_match = 4;
const max_match = lz77.max_match_len;
pub const min_input_len = 64 * 1024 + 1;
pub const max_input_len = 128 * 1024;
const hash_size = 1 << 15;
const hash_init_words = hash_size / 64;
const empty = std.math.maxInt(u32);
pub const candidate_count = 7;
const length_bits = 9;
const length_mask: usize = (@as(usize, 1) << length_bits) - 1;

pub noinline fn planReuse(
    scratch: *lz77.OptimalScratch,
    allocator: std.mem.Allocator,
    input: []const u8,
    options: lz77.GreedyOptions,
) linksection(text_section) !lz77.PlanStats {
    if (input.len < min_input_len) return error.InvalidBlockPlan;
    return planReuseInternal(scratch, allocator, input, options, false, undefined, undefined);
}

pub noinline fn planReuseProfiled(
    scratch: *lz77.OptimalScratch,
    allocator: std.mem.Allocator,
    input: []const u8,
    options: lz77.GreedyOptions,
    io: std.Io,
    profile: *lz77.OptimalSearchProfile,
) linksection(text_section) !lz77.PlanStats {
    if (input.len < min_input_len) return error.InvalidBlockPlan;
    profile.* = .{ .input_bytes = input.len };
    const total_start = std.Io.Clock.awake.now(io);
    const stats = try planReuseInternal(scratch, allocator, input, options, true, io, profile);
    profile.total_ns = elapsedNs(total_start, io);
    return stats;
}

fn planReuseInternal(
    scratch: *lz77.OptimalScratch,
    allocator: std.mem.Allocator,
    input: []const u8,
    options: lz77.GreedyOptions,
    comptime collect_profile: bool,
    io: if (collect_profile) std.Io else void,
    profile: if (collect_profile) *lz77.OptimalSearchProfile else void,
) !lz77.PlanStats {
    if (input.len < min_input_len or input.len > max_input_len or
        options.min_match != min_match or options.max_match != max_match or
        options.window_len != lz77.default_window_len or options.max_chain != 128 or
        options.nice_len != max_match or options.max_candidates != candidate_count or
        options.min_savings_bits != 0)
        return error.InvalidBlockPlan;

    const n = input.len;
    try scratch.costs.resize(allocator, n + 1);
    try scratch.steps.resize(allocator, n);
    scratch.tokens.clearRetainingCapacity();

    const index_start = if (comptime collect_profile) std.Io.Clock.awake.now(io) else {};
    try buildIndex(scratch, allocator, input);
    if (comptime collect_profile) {
        profile.index_ns = elapsedNs(index_start, io);
        profile.index_bytes = (scratch.compact_head.items.len + scratch.compact_prev.items.len) * @sizeOf(u32) + hash_init_words * @sizeOf(u64);
    }

    const costs = scratch.costs.items;
    const steps = scratch.steps.items;
    costs[n] = 0;
    var rev_i: usize = n;
    const maximum_match = max_match;
    const candidate_limit = candidate_count;
    const search_start = if (comptime collect_profile) std.Io.Clock.awake.now(io) else {};

    while (rev_i > 0) {
        rev_i -= 1;
        if (comptime collect_profile) profile.positions += 1;
        costs[rev_i] = literalCost(input[rev_i]) + costs[rev_i + 1];
        steps[rev_i] = .{ .literal = input[rev_i] };
        if (rev_i + min_match > n) continue;

        const max_len = @min(maximum_match, n - rev_i);
        var choices_built_through: usize = min_match - 1;
        var chain_i = scratch.compact_prev.items[rev_i];
        var checked: usize = 0;
        var candidates_seen: usize = 0;
        while (chain_i != empty and checked < options.max_chain) : (checked += 1) {
            const candidate: usize = chain_i;
            std.debug.assert(candidate < rev_i);
            const distance = rev_i - candidate;
            if (distance == 0 or distance > options.window_len) break;
            if (comptime collect_profile) profile.chain_nodes += 1;
            const candidate_prefix = std.mem.readInt(u32, input[candidate..][0..4], .little);
            const current_prefix = std.mem.readInt(u32, input[rev_i..][0..4], .little);
            if (candidate_prefix != current_prefix) {
                if (comptime collect_profile) {
                    profile.prefix_rejections += 1;
                    profile.prefix_mismatch_histogram[@ctz(candidate_prefix ^ current_prefix) / 8] += 1;
                }
                chain_i = scratch.compact_prev.items[candidate];
                continue;
            }

            const distance_cost = lz77.fixedDistanceCost(distance);
            if (choices_built_through >= min_match and
                choices_built_through < max_len and
                input[candidate + choices_built_through] != input[rev_i + choices_built_through] and
                choiceCost(scratch.index.best_length_choices[choices_built_through]) + distance_cost >= costs[rev_i])
            {
                if (comptime collect_profile) {
                    profile.bound_rejections += 1;
                    profile.bound_length_histogram[boundLengthBucket(choices_built_through)] += 1;
                    profile.bound_distance_cost_histogram[distance_cost - 5] += 1;
                    const slack = choiceCost(scratch.index.best_length_choices[choices_built_through]) + distance_cost - costs[rev_i];
                    profile.bound_slack_histogram[@min(slack, profile.bound_slack_histogram.len - 1)] += 1;
                }
                candidates_seen += 1;
                if (candidates_seen >= candidate_limit) {
                    if (comptime collect_profile) profile.candidate_budget_stops += 1;
                    break;
                }
                chain_i = scratch.compact_prev.items[candidate];
                continue;
            }

            if (comptime collect_profile) profile.match_length_calls += 1;
            const length = matchLength(input, candidate, rev_i, max_len);
            if (length >= min_match) {
                if (comptime collect_profile) {
                    const added_choices = length -| choices_built_through;
                    profile.valid_match_candidates += 1;
                    profile.length_choices_built += added_choices;
                    profile.length_extension_histogram[lengthExtensionBucket(added_choices)] += 1;
                }
                extendLengthChoices(costs, rev_i, choices_built_through, length, &scratch.index.best_length_choices, &scratch.index.best_lengths);
                choices_built_through = @max(choices_built_through, length);
                const selected_choice = scratch.index.best_length_choices[length];
                const cost = choiceCost(selected_choice) + distance_cost;
                if (cost < costs[rev_i]) {
                    costs[rev_i] = cost;
                    steps[rev_i] = .{ .match = .{
                        .length = choiceLength(selected_choice, &scratch.index.best_lengths, length),
                        .distance = @intCast(distance),
                    } };
                }
                candidates_seen += 1;
                if (length == max_len) break;
                if (length >= options.nice_len and candidates_seen >= candidate_limit) {
                    if (comptime collect_profile) profile.candidate_budget_stops += 1;
                    break;
                }
                if (candidates_seen >= candidate_limit) {
                    if (comptime collect_profile) profile.candidate_budget_stops += 1;
                    break;
                }
            }
            chain_i = scratch.compact_prev.items[candidate];
        }
    }

    if (comptime collect_profile) profile.search_ns = elapsedNs(search_start, io);
    const reconstruct_start = if (comptime collect_profile) std.Io.Clock.awake.now(io) else {};
    var stats: lz77.PlanStats = .{};
    var position: usize = 0;
    while (position < n) {
        const token = steps[position];
        try scratch.tokens.append(allocator, token);
        switch (token) {
            .literal => {
                stats.literals += 1;
                position += 1;
            },
            .match => |match| {
                stats.matches += 1;
                stats.matched_bytes += match.length;
                position += match.length;
            },
        }
    }
    if (comptime collect_profile) profile.reconstruct_ns = elapsedNs(reconstruct_start, io);
    return stats;
}

fn buildIndex(scratch: *lz77.OptimalScratch, allocator: std.mem.Allocator, input: []const u8) !void {
    try scratch.compact_head.resize(allocator, hash_size);
    try scratch.compact_prev.resize(allocator, input.len);
    @memset(&scratch.index.head_initialized, 0);
    for (0..input.len) |position| {
        if (position + min_match > input.len) continue;
        const word = std.mem.readInt(u32, input[position..][0..4], .little);
        const hash = ((word *% 2_654_435_761) >> 17) & (hash_size - 1);
        const mask = @as(u64, 1) << @intCast(hash & 63);
        const initialized = &scratch.index.head_initialized[hash / 64];
        scratch.compact_prev.items[position] = if (initialized.* & mask == 0) empty else scratch.compact_head.items[hash];
        scratch.compact_head.items[hash] = @intCast(position);
        initialized.* |= mask;
    }
}

inline fn literalCost(byte: u8) usize {
    return if (byte <= 143) 8 else 9;
}

inline fn packedChoice(cost: usize, length: usize) usize {
    if (comptime @bitSizeOf(usize) >= 64) return (cost << length_bits) | (max_match - length);
    return cost;
}

inline fn choiceCost(value: usize) usize {
    return if (comptime @bitSizeOf(usize) >= 64) value >> length_bits else value;
}

inline fn choiceLength(value: usize, lengths: *const [max_match + 1]u16, index: usize) u16 {
    return if (comptime @bitSizeOf(usize) >= 64) @intCast(max_match - (value & length_mask)) else lengths[index];
}

fn extendLengthChoices(
    costs: []const usize,
    position: usize,
    built_through: usize,
    maximum: usize,
    choices: *[max_match + 1]usize,
    lengths: *[max_match + 1]u16,
) void {
    if (maximum <= built_through) return;
    var best_choice = if (built_through >= min_match) choices[built_through] else std.math.maxInt(usize);
    var best_length: u16 = if (comptime @bitSizeOf(usize) >= 64) 0 else if (built_through >= min_match) lengths[built_through] else 0;
    var length = @max(min_match, built_through + 1);
    while (length <= maximum) : (length += 1) {
        const cost = lz77.fixedLengthCost(length) + costs[position + length];
        if (comptime @bitSizeOf(usize) >= 64) {
            const candidate = packedChoice(cost, length);
            if (candidate < best_choice) best_choice = candidate;
        } else if (cost < best_choice or (cost == best_choice and length > best_length)) {
            best_choice = cost;
            best_length = @intCast(length);
        }
        choices[length] = best_choice;
        if (comptime @bitSizeOf(usize) < 64) lengths[length] = best_length;
    }
}

fn matchLength(input: []const u8, a: usize, b: usize, maximum: usize) usize {
    var length: usize = 0;
    while (length + 32 <= maximum) : (length += 32) {
        const left: @Vector(32, u8) = input[a + length ..][0..32].*;
        const right: @Vector(32, u8) = input[b + length ..][0..32].*;
        const differing: u32 = ~@as(u32, @bitCast(left == right));
        if (differing != 0) return length + @ctz(differing);
    }
    while (length + 8 <= maximum) : (length += 8) {
        const left = std.mem.readInt(u64, input[a + length ..][0..8], .little);
        const right = std.mem.readInt(u64, input[b + length ..][0..8], .little);
        if (left != right) return length + @ctz(left ^ right) / 8;
    }
    while (length < maximum and input[a + length] == input[b + length]) length += 1;
    return length;
}

fn boundLengthBucket(length: usize) usize {
    return if (length < 8) 0 else if (length < 16) 1 else if (length < 32) 2 else if (length < 64) 3 else if (length < 128) 4 else 5;
}

fn lengthExtensionBucket(added: usize) usize {
    return if (added == 0) 0 else if (added == 1) 1 else if (added < 4) 2 else if (added < 8) 3 else if (added < 16) 4 else if (added < 32) 5 else if (added < 64) 6 else if (added < 128) 7 else 8;
}

fn elapsedNs(start: std.Io.Timestamp, io: std.Io) u64 {
    const ns = start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds;
    return if (ns <= 0) 0 else @intCast(ns);
}

test "four-byte Zstd optimal routing starts above 64 KiB" {
    var short: [64 * 1024]u8 = @splat('a');
    var long: [64 * 1024 + 1]u8 = @splat('a');
    var scratch: lz77.OptimalScratch = .{};
    defer scratch.deinit(std.testing.allocator);
    const options: lz77.GreedyOptions = .{
        .window_len = lz77.default_window_len,
        .max_chain = 128,
        .nice_len = max_match,
        .max_candidates = candidate_count,
        .min_match = min_match,
        .max_match = max_match,
    };
    try std.testing.expectError(error.InvalidBlockPlan, planReuse(&scratch, std.testing.allocator, &short, options));
    const stats = try planReuse(&scratch, std.testing.allocator, &long, options);
    try std.testing.expectEqual(long.len, stats.literals + stats.matched_bytes);
    const replayed = try lz77.replayAlloc(std.testing.allocator, scratch.tokens.items);
    defer std.testing.allocator.free(replayed);
    try std.testing.expectEqualSlices(u8, &long, replayed);
}

test "four-byte Zstd optimal plans do not exceed three-byte reference cost" {
    const lengths = [_]usize{ min_input_len, 72 * 1024, 80 * 1024, 88 * 1024, 96 * 1024, 104 * 1024, 112 * 1024, max_input_len };
    var random_state: u32 = 0x243f_6a88;
    var improved: usize = 0;
    var reference_total: usize = 0;
    var actual_total: usize = 0;
    for (lengths) |length| {
        const input = try std.testing.allocator.alloc(u8, length);
        defer std.testing.allocator.free(input);
        for (0..16) |shape| {
            for (input, 0..) |*byte, position| {
                random_state = random_state *% 1_664_525 +% 1_013_904_223;
                byte.* = switch (shape & 3) {
                    0 => @truncate(random_state >> 24),
                    1 => @truncate(position * 17 + shape),
                    2 => @intCast('a' + (position / (3 + shape)) % 23),
                    else => if (position % 64 < 56) @truncate(position * 37 + shape) else @truncate(random_state >> 24),
                };
            }
            if (shape & 1 != 0) {
                const copied = input.len / 4;
                @memcpy(input[input.len - copied ..], input[input.len / 4 ..][0..copied]);
            }
            const options: lz77.GreedyOptions = .{
                .window_len = lz77.default_window_len,
                .max_chain = 128,
                .nice_len = max_match,
                .max_candidates = candidate_count,
                .min_match = min_match,
                .max_match = max_match,
            };
            var reference: lz77.OptimalScratch = .{};
            defer reference.deinit(std.testing.allocator);
            const reference_stats = try lz77.optimalPlanReuse(&reference, std.testing.allocator, input, options);
            var actual: lz77.OptimalScratch = .{};
            defer actual.deinit(std.testing.allocator);
            const actual_stats = try planReuse(&actual, std.testing.allocator, input, options);
            try std.testing.expectEqual(input.len, reference_stats.literals + reference_stats.matched_bytes);
            try std.testing.expectEqual(input.len, actual_stats.literals + actual_stats.matched_bytes);
            const reference_cost = lz77.fixedBitCost(reference.tokens.items);
            const actual_cost = lz77.fixedBitCost(actual.tokens.items);
            try std.testing.expect(actual_cost <= reference_cost);
            improved += @intFromBool(actual_cost < reference_cost);
            reference_total += reference_cost;
            actual_total += actual_cost;
            const replayed = try lz77.replayAlloc(std.testing.allocator, actual.tokens.items);
            defer std.testing.allocator.free(replayed);
            try std.testing.expectEqualSlices(u8, input, replayed);
        }
    }
    std.debug.print(
        "four-byte optimal plan audit: improved={d} total={d}/{d}\n",
        .{ improved, actual_total, reference_total },
    );
    try std.testing.expect(improved != 0);
    try std.testing.expect(actual_total <= reference_total);
}

test "four-byte Zstd optimal scratch recovers after allocation failure" {
    var input: [min_input_len]u8 = undefined;
    for (&input, 0..) |*byte, position| byte.* = @truncate(position * 37 + position / 251);
    const options: lz77.GreedyOptions = .{
        .window_len = lz77.default_window_len,
        .max_chain = 128,
        .nice_len = max_match,
        .max_candidates = candidate_count,
        .min_match = min_match,
        .max_match = max_match,
    };
    const Test = struct {
        fn run(allocator: std.mem.Allocator, bytes: []const u8, parser_options: lz77.GreedyOptions) !void {
            var local: lz77.OptimalScratch = .{};
            defer local.deinit(allocator);
            const stats = try planReuse(&local, allocator, bytes, parser_options);
            try std.testing.expectEqual(bytes.len, stats.literals + stats.matched_bytes);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Test.run, .{ &input, options });

    var scratch: lz77.OptimalScratch = .{};
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 3 });
    {
        const allocator = failing.allocator();
        try std.testing.expectError(error.OutOfMemory, planReuse(&scratch, allocator, &input, options));
        failing.fail_index = std.math.maxInt(usize);
        const stats = try planReuse(&scratch, allocator, &input, options);
        try std.testing.expectEqual(input.len, stats.literals + stats.matched_bytes);
        const replayed = try lz77.replayAlloc(allocator, scratch.tokens.items);
        defer allocator.free(replayed);
        try std.testing.expectEqualSlices(u8, &input, replayed);
    }
    scratch.deinit(failing.allocator());
    try std.testing.expectEqual(failing.allocated_bytes, failing.freed_bytes);
}

test "profiled four-byte Zstd optimal preserves production plan and accounting" {
    var input: [min_input_len]u8 = undefined;
    var random_state: u32 = 0x3c6e_f372;
    for (&input, 0..) |*byte, position| {
        random_state = random_state *% 1_664_525 +% 1_013_904_223;
        byte.* = if (position >= 769 and position % 17 < 13)
            input[position - 769]
        else
            @truncate(random_state >> 24);
    }
    const options: lz77.GreedyOptions = .{
        .window_len = lz77.default_window_len,
        .max_chain = 128,
        .nice_len = max_match,
        .max_candidates = candidate_count,
        .min_match = min_match,
        .max_match = max_match,
    };
    var expected: lz77.OptimalScratch = .{};
    defer expected.deinit(std.testing.allocator);
    const expected_stats = try planReuse(&expected, std.testing.allocator, &input, options);
    var actual: lz77.OptimalScratch = .{};
    defer actual.deinit(std.testing.allocator);
    var profile: lz77.OptimalSearchProfile = .{};
    const actual_stats = try planReuseProfiled(&actual, std.testing.allocator, &input, options, std.testing.io, &profile);
    try std.testing.expectEqual(expected_stats, actual_stats);
    try std.testing.expectEqualSlices(lz77.Token, expected.tokens.items, actual.tokens.items);
    try std.testing.expectEqual(input.len, profile.input_bytes);
    try std.testing.expectEqual(input.len, profile.positions);
    try std.testing.expectEqual(profile.chain_nodes, profile.prefix_rejections + profile.bound_rejections + profile.match_length_calls);
    var mismatch_total: usize = 0;
    for (profile.prefix_mismatch_histogram) |count| mismatch_total += count;
    try std.testing.expectEqual(profile.prefix_rejections, mismatch_total);
    var extension_total: usize = 0;
    for (profile.length_extension_histogram) |count| extension_total += count;
    try std.testing.expectEqual(profile.valid_match_candidates, extension_total);
}
