const std = @import("std");
const builtin = @import("builtin");
const lz77 = @import("../../lz77.zig");
const test_counter = if (builtin.is_test) @import("../../testing/atomic_counter.zig") else struct {};

const text_section = switch (builtin.object_format) {
    .elf => ".vort_zstd_single_beam",
    .macho => "__TEXT,__vort_zstd_sb",
    .coff => ".text$vort_zstd_single_beam",
    else => ".text",
};

const max_input_len = std.math.maxInt(u16);
const min_match = 4;
const head_size = 4096;
const empty = std.math.maxInt(u16);
const max_chain = 16;

var test_first_shifted_indexed_match_hits: usize = 0;

pub const Profile = struct {
    pub const length_bucket_count = 6;

    positions: usize = 0,
    literal_empty_inserts: usize = 0,
    literal_replacements: usize = 0,
    literal_rejections: usize = 0,
    indexed_empty_inserts: usize = 0,
    indexed_replacements: usize = 0,
    indexed_rejections: usize = 0,
    indexed_min_cost_rejections: usize = 0,
    indexed_short_min_cost_rejections: usize = 0,
    rep0_empty_inserts: usize = 0,
    rep0_replacements: usize = 0,
    rep0_rejections: usize = 0,
    rep0_min_cost_rejections: usize = 0,
    indexed_searches: usize = 0,
    indexed_chain_nodes: usize = 0,
    indexed_prefix_rejections: usize = 0,
    indexed_matches: usize = 0,
    shifted_indexed_matches: usize = 0,
    indexed_window_stops: usize = 0,
    indexed_chain_limit_stops: usize = 0,
    indexed_length_histogram: [length_bucket_count]usize = @splat(0),
    rep0_probes: usize = 0,
    rep0_prefix_rejections: usize = 0,
    rep0_prefix_mismatch_histogram: [4]usize = @splat(0),
    rep0_matches: usize = 0,
    rep0_length_histogram: [length_bucket_count]usize = @splat(0),

    pub fn add(self: *Profile, other: Profile) void {
        inline for (.{
            "positions",
            "literal_empty_inserts",
            "literal_replacements",
            "literal_rejections",
            "indexed_empty_inserts",
            "indexed_replacements",
            "indexed_rejections",
            "indexed_min_cost_rejections",
            "indexed_short_min_cost_rejections",
            "rep0_empty_inserts",
            "rep0_replacements",
            "rep0_rejections",
            "rep0_min_cost_rejections",
            "indexed_searches",
            "indexed_chain_nodes",
            "indexed_prefix_rejections",
            "indexed_matches",
            "shifted_indexed_matches",
            "indexed_window_stops",
            "indexed_chain_limit_stops",
            "rep0_probes",
            "rep0_prefix_rejections",
            "rep0_matches",
        }) |field| @field(self, field) += @field(other, field);
        for (&self.indexed_length_histogram, other.indexed_length_histogram) |*total, count| total.* += count;
        for (&self.rep0_prefix_mismatch_histogram, other.rep0_prefix_mismatch_histogram) |*total, count| total.* += count;
        for (&self.rep0_length_histogram, other.rep0_length_histogram) |*total, count| total.* += count;
    }
};

const State = struct {
    cost: u32 = std.math.maxInt(u32),
    rep0: u16 = 1,
    previous_position: u16 = 0,
    token: lz77.Token = .{ .literal = 0 },
};

comptime {
    std.debug.assert(@sizeOf(State) == 16);
}

pub const Scratch = struct {
    head: [head_size]u16 = @splat(empty),
    prev: std.ArrayList(u16) = .empty,
    states: std.ArrayList(State) = .empty,
    occupied: std.ArrayList(u8) = .empty,
    reversed: std.ArrayList(lz77.Token) = .empty,

    pub fn deinit(self: *Scratch, allocator: std.mem.Allocator) void {
        self.reversed.deinit(allocator);
        self.occupied.deinit(allocator);
        self.states.deinit(allocator);
        self.prev.deinit(allocator);
        self.* = .{};
    }
};

pub noinline fn planReuse(scratch: *Scratch, allocator: std.mem.Allocator, input: []const u8) linksection(text_section) !lz77.PlanStats {
    return planReuseWithChainLimit(scratch, allocator, input, max_chain, true, false, undefined);
}

pub noinline fn planReuseProfiled(scratch: *Scratch, allocator: std.mem.Allocator, input: []const u8, profile: *Profile) !lz77.PlanStats {
    profile.* = .{};
    return planReuseWithChainLimit(scratch, allocator, input, max_chain, true, true, profile);
}

pub fn planDeepReferenceReuse(scratch: *Scratch, allocator: std.mem.Allocator, input: []const u8) !lz77.PlanStats {
    return planReuseWithChainLimit(scratch, allocator, input, 128, true, false, undefined);
}

fn planReuseWithChainLimit(
    scratch: *Scratch,
    allocator: std.mem.Allocator,
    input: []const u8,
    comptime chain_limit: usize,
    comptime reuse_shifted_match: bool,
    comptime collect_profile: bool,
    profile: if (collect_profile) *Profile else void,
) !lz77.PlanStats {
    if (input.len == 0 or input.len > max_input_len) return error.InvalidBlockPlan;
    try scratch.prev.resize(allocator, input.len);
    @memset(&scratch.head, empty);
    try scratch.states.resize(allocator, input.len + 1);
    try scratch.occupied.resize(allocator, input.len + 1);
    const states = scratch.states.items;
    const occupied = scratch.occupied.items;
    @memset(occupied, 0);
    states[0] = .{ .cost = 0 };
    occupied[0] = 1;
    var previous_indexed_match: ?lz77.Token.Match = null;

    for (0..input.len) |position| {
        if (comptime collect_profile) profile.positions += 1;
        std.debug.assert(occupied[position] != 0);
        const state = states[position];
        insertStateProfiled(states, occupied, position + 1, .{
            .cost = state.cost + literalCost(input[position]),
            .rep0 = state.rep0,
            .previous_position = @intCast(position),
            .token = .{ .literal = input[position] },
        }, .literal, collect_profile, profile);

        if (position + min_match > input.len) {
            scratch.prev.items[position] = empty;
            previous_indexed_match = null;
            continue;
        }
        const anchor = std.mem.readInt(u32, input[position..][0..4], .little);
        const hash = hashWord(anchor);
        const first_candidate = scratch.head[hash];
        scratch.prev.items[position] = first_candidate;
        scratch.head[hash] = @intCast(position);
        const indexed_match = firstIndexedMatch(scratch, input, position, first_candidate, anchor, previous_indexed_match, chain_limit, reuse_shifted_match, collect_profile, profile);
        previous_indexed_match = indexed_match;
        if (indexed_match) |match|
            extendMatchProfiled(states, occupied, position, state, match, .indexed, collect_profile, profile);
        const indexed_rep0 = if (indexed_match) |match| match.distance == state.rep0 else false;
        if (state.rep0 <= position and !indexed_rep0) {
            if (comptime collect_profile) profile.rep0_probes += 1;
            const length = matchAtDistance(input, position, state.rep0, anchor);
            if (length != 0) {
                if (comptime collect_profile) {
                    profile.rep0_matches += 1;
                    profile.rep0_length_histogram[matchLengthBucket(length)] += 1;
                }
                extendMatchProfiled(states, occupied, position, state, .{
                    .length = @intCast(length),
                    .distance = state.rep0,
                }, .rep0, collect_profile, profile);
            } else if (comptime collect_profile) {
                profile.rep0_prefix_rejections += 1;
                const candidate = position - state.rep0;
                const candidate_prefix = std.mem.readInt(u32, input[candidate..][0..4], .little);
                profile.rep0_prefix_mismatch_histogram[@ctz(candidate_prefix ^ anchor) / 8] += 1;
            }
        }
    }

    scratch.reversed.clearRetainingCapacity();
    try scratch.reversed.ensureTotalCapacity(allocator, @min(input.len, 4096));
    var position = input.len;
    while (position != 0) {
        const state = states[position];
        try scratch.reversed.append(allocator, state.token);
        position = state.previous_position;
    }
    std.mem.reverse(lz77.Token, scratch.reversed.items);

    var stats: lz77.PlanStats = .{};
    for (scratch.reversed.items) |token| switch (token) {
        .literal => stats.literals += 1,
        .match => |match| {
            stats.matches += 1;
            stats.matched_bytes += match.length;
        },
    };
    return stats;
}

fn firstIndexedMatch(
    scratch: *const Scratch,
    input: []const u8,
    position: usize,
    first_candidate: u16,
    anchor: u32,
    previous_match: ?lz77.Token.Match,
    comptime chain_limit: usize,
    comptime reuse_shifted_match: bool,
    comptime collect_profile: bool,
    profile: if (collect_profile) *Profile else void,
) ?lz77.Token.Match {
    var candidate_i = first_candidate;
    var checked: usize = 0;
    const maximum = @min(lz77.max_match_len, input.len - position);
    const window_len = @min(input.len, lz77.default_window_len);
    if (comptime collect_profile) profile.indexed_searches += @intFromBool(first_candidate != empty);
    // Adjacent matches overwhelmingly remain at the newest hash-chain entry on
    // structured input. Handle that exact recurrence before entering the
    // generic chain loop so its optional/candidate checks stay off the common
    // path. Capped matches still require normal extension.
    if (comptime reuse_shifted_match) {
        if (previous_match) |previous| {
            if (previous.distance <= position and
                first_candidate == position - previous.distance)
            {
                if (shiftedIndexedMatchLength(maximum, previous.length)) |length| {
                    if (comptime collect_profile) {
                        profile.indexed_chain_nodes += 1;
                        profile.shifted_indexed_matches += 1;
                        profile.indexed_matches += 1;
                        profile.indexed_length_histogram[matchLengthBucket(length)] += 1;
                    }
                    if (comptime builtin.is_test) test_counter.add(&test_first_shifted_indexed_match_hits, 1);
                    return .{
                        .length = @intCast(length),
                        .distance = previous.distance,
                    };
                }
            }
        }
    }
    while (candidate_i != empty and checked < chain_limit) : (checked += 1) {
        if (comptime collect_profile) profile.indexed_chain_nodes += 1;
        const candidate: usize = candidate_i;
        const distance = position - candidate;
        if (distance == 0 or distance > window_len) {
            if (comptime collect_profile) profile.indexed_window_stops += 1;
            break;
        }
        const shifted_length: ?usize = if (reuse_shifted_match)
            if (previous_match) |previous|
                if (previous.distance == distance) shiftedIndexedMatchLength(maximum, previous.length) else null
            else
                null
        else
            null;
        if (comptime collect_profile) profile.shifted_indexed_matches += @intFromBool(shifted_length != null);
        if (shifted_length orelse if (std.mem.readInt(u32, input[candidate..][0..4], .little) == anchor)
            matchLengthAfterPrefix(input, candidate, position, maximum, min_match)
        else
            null) |length|
        {
            if (comptime collect_profile) {
                profile.indexed_matches += 1;
                profile.indexed_length_histogram[matchLengthBucket(length)] += 1;
            }
            return .{
                .length = @intCast(length),
                .distance = @intCast(distance),
            };
        }
        if (comptime collect_profile) profile.indexed_prefix_rejections += 1;
        candidate_i = scratch.prev.items[candidate];
    }
    if (comptime collect_profile)
        profile.indexed_chain_limit_stops += @intFromBool(candidate_i != empty and checked >= chain_limit);
    return null;
}

inline fn shiftedIndexedMatchLength(maximum: usize, previous_length: usize) ?usize {
    // A length-L match at the immediately preceding position proves that the
    // same distance matches L-1 bytes here. Below the format maximum, its
    // terminating mismatch also proves the shifted length exactly. Keep capped
    // 258-byte matches on the established vector extension path: those dominate
    // text blocks and checking their newly exposed tail byte is slower there.
    if (previous_length <= min_match or previous_length == lz77.max_match_len) return null;
    const guaranteed = @min(maximum, previous_length - 1);
    return guaranteed;
}

fn matchLengthBucket(length: usize) usize {
    std.debug.assert(length >= min_match and length <= lz77.max_match_len);
    return if (length < 12) 0 else if (length < 36) 1 else if (length < 68) 2 else if (length < 132) 3 else if (length < 258) 4 else 5;
}

fn extendMatch(states: []State, occupied: []u8, position: usize, state: State, match: lz77.Token.Match) void {
    const target = position + match.length;
    // Every repeat match costs at least 7 + 1 bits and every direct match at
    // least 7 + 5 + 4 bits. Apply that lower bound to the profiled short-match
    // hot path, while leaving text's dominant long matches branch-free. Avoid
    // the distance lookup and State construction when the bound cannot improve
    // the reached target. Equal costs retain the earlier path.
    if (match.length < 68) {
        const minimum_transition_cost: u32 = if (match.distance == state.rep0) 8 else 16;
        if (occupied[target] != 0 and state.cost + minimum_transition_cost >= states[target].cost) return;
    }
    const distance_cost: u32 = if (match.distance == state.rep0) 1 else @intCast(distanceCost(match.distance) + 4);
    insertState(states, occupied, target, .{
        .cost = state.cost + lengthCost(match.length) + distance_cost,
        .rep0 = match.distance,
        .previous_position = @intCast(position),
        .token = .{ .match = match },
    });
}

fn extendMatchReference(states: []State, occupied: []u8, position: usize, state: State, match: lz77.Token.Match) void {
    const distance_cost: u32 = if (match.distance == state.rep0) 1 else @intCast(distanceCost(match.distance) + 4);
    insertState(states, occupied, position + match.length, .{
        .cost = state.cost + lengthCost(match.length) + distance_cost,
        .rep0 = match.distance,
        .previous_position = @intCast(position),
        .token = .{ .match = match },
    });
}

const TransitionKind = enum { literal, indexed, rep0 };

fn extendMatchProfiled(
    states: []State,
    occupied: []u8,
    position: usize,
    state: State,
    match: lz77.Token.Match,
    comptime kind: TransitionKind,
    comptime collect_profile: bool,
    profile: if (collect_profile) *Profile else void,
) void {
    if (!collect_profile) return extendMatch(states, occupied, position, state, match);
    const distance_cost: u32 = if (match.distance == state.rep0) 1 else @intCast(distanceCost(match.distance) + 4);
    const target = position + match.length;
    const minimum_transition_cost: u32 = if (match.distance == state.rep0) 8 else 16;
    if (occupied[target] != 0 and state.cost + minimum_transition_cost >= states[target].cost) {
        switch (kind) {
            .literal => unreachable,
            .indexed => {
                profile.indexed_min_cost_rejections += 1;
                profile.indexed_short_min_cost_rejections += @intFromBool(match.length < 68);
            },
            .rep0 => profile.rep0_min_cost_rejections += 1,
        }
    }
    insertStateProfiled(states, occupied, position + match.length, .{
        .cost = state.cost + lengthCost(match.length) + distance_cost,
        .rep0 = match.distance,
        .previous_position = @intCast(position),
        .token = .{ .match = match },
    }, kind, true, profile);
}

fn insertState(states: []State, occupied: []u8, position: usize, candidate: State) void {
    if (occupied[position] == 0 or candidate.cost < states[position].cost) {
        states[position] = candidate;
        occupied[position] = 1;
    }
}

fn insertStateProfiled(
    states: []State,
    occupied: []u8,
    position: usize,
    candidate: State,
    comptime kind: TransitionKind,
    comptime collect_profile: bool,
    profile: if (collect_profile) *Profile else void,
) void {
    if (!collect_profile) return insertState(states, occupied, position, candidate);
    const is_empty = occupied[position] == 0;
    const replaces = !is_empty and candidate.cost < states[position].cost;
    switch (kind) {
        .literal => if (is_empty) {
            profile.literal_empty_inserts += 1;
        } else if (replaces) {
            profile.literal_replacements += 1;
        } else {
            profile.literal_rejections += 1;
        },
        .indexed => if (is_empty) {
            profile.indexed_empty_inserts += 1;
        } else if (replaces) {
            profile.indexed_replacements += 1;
        } else {
            profile.indexed_rejections += 1;
        },
        .rep0 => if (is_empty) {
            profile.rep0_empty_inserts += 1;
        } else if (replaces) {
            profile.rep0_replacements += 1;
        } else {
            profile.rep0_rejections += 1;
        },
    }
    if (is_empty or replaces) {
        states[position] = candidate;
        occupied[position] = 1;
    }
}

fn matchAtDistance(input: []const u8, position: usize, distance: usize, anchor: u32) usize {
    if (distance == 0 or distance > position) return 0;
    const candidate = position - distance;
    if (std.mem.readInt(u32, input[candidate..][0..4], .little) != anchor) return 0;
    return matchLengthAfterPrefix(input, candidate, position, @min(lz77.max_match_len, input.len - position), min_match);
}

fn matchLengthAfterPrefix(input: []const u8, a: usize, b: usize, maximum: usize, prefix_len: usize) usize {
    var len = prefix_len;
    while (len + 32 <= maximum) : (len += 32) {
        const left: @Vector(32, u8) = input[a + len ..][0..32].*;
        const right: @Vector(32, u8) = input[b + len ..][0..32].*;
        const differing: u32 = ~@as(u32, @bitCast(left == right));
        if (differing != 0) return len + @ctz(differing);
    }
    while (len + 8 <= maximum) : (len += 8) {
        const left = std.mem.readInt(u64, input[a + len ..][0..8], .little);
        const right = std.mem.readInt(u64, input[b + len ..][0..8], .little);
        if (left != right) return len + @ctz(left ^ right) / 8;
    }
    while (len < maximum and input[a + len] == input[b + len]) len += 1;
    return len;
}

fn hash4(input: []const u8, position: usize) usize {
    const word = std.mem.readInt(u32, input[position..][0..4], .little);
    return hashWord(word);
}

inline fn hashWord(word: u32) usize {
    return ((word *% 2654435761) >> 17) & (head_size - 1);
}

fn literalCost(byte: u8) u32 {
    return if (byte <= 143) 8 else 9;
}

fn lengthCost(length: usize) u32 {
    return if (length <= 10) 7 else if (length <= 18) 8 else if (length <= 34) 9 else if (length <= 66) 10 else if (length <= 130) 11 else if (length <= 257) 12 else 8;
}

fn distanceCost(distance: usize) usize {
    return lz77.fixedDistanceCost(distance);
}

test "single-state shared distance cost matches scalar formula" {
    for (1..lz77.default_window_len + 1) |distance| {
        const expected: usize = if (distance <= 4) 5 else 4 + std.math.log2_int(usize, distance - 1);
        try std.testing.expectEqual(expected, distanceCost(distance));
    }
}

test "profiled single-state short transition lower bound preserves reference insertion" {
    const lengths = [_]u16{ 4, 10, 11, 18, 19, 34, 35, 66, 67, 68, 130, 258 };
    const distances = [_]u16{ 1, 2, 4, 5, 31, 32, 255, 32_768 };
    const state_costs = [_]u32{ 0, 17, max_input_len * 9 };
    const target_costs = [_]u32{ 0, 7, 8, 15, 16, 31, 127, 1024, std.math.maxInt(u16), max_input_len * 9 + 32 };
    for (lengths) |length| for (distances) |distance| for (state_costs) |state_cost| for (target_costs) |target_cost| for ([_]bool{ false, true }) |target_occupied| {
        const position: usize = 1;
        const target = position + length;
        const state: State = .{ .cost = state_cost, .rep0 = if (distance & 1 == 0) distance else 3 };
        const match: lz77.Token.Match = .{ .length = length, .distance = distance };
        var expected_states: [260]State = @splat(.{});
        var actual_states = expected_states;
        var expected_occupied: [260]u8 = @splat(0);
        var actual_occupied = expected_occupied;
        expected_states[target] = .{ .cost = target_cost };
        actual_states[target] = .{ .cost = target_cost };
        expected_occupied[target] = @intFromBool(target_occupied);
        actual_occupied[target] = @intFromBool(target_occupied);
        extendMatchReference(&expected_states, &expected_occupied, position, state, match);
        extendMatch(&actual_states, &actual_occupied, position, state, match);
        try std.testing.expectEqualSlices(u8, &expected_occupied, &actual_occupied);
        try std.testing.expectEqualSlices(State, &expected_states, &actual_states);
    };
}

test "single-state repeat beam replays bounded input" {
    const input = ("abcdefgh-abcdefgh-" ** 128) ++ ("0123456789abcdef" ** 64);
    var scratch: Scratch = .{};
    defer scratch.deinit(std.testing.allocator);
    const stats = try planReuse(&scratch, std.testing.allocator, input);
    const replayed = try lz77.replayAlloc(std.testing.allocator, scratch.reversed.items);
    defer std.testing.allocator.free(replayed);
    try std.testing.expectEqualSlices(u8, input, replayed);
    try std.testing.expectEqual(input.len, stats.literals + stats.matched_bytes);
}

test "profiled single-state repeat beam preserves tokens and accounting" {
    const input = ("abcdefgh-abcdefgh-" ** 128) ++ ("0123456789abcdef" ** 64);
    var expected: Scratch = .{};
    defer expected.deinit(std.testing.allocator);
    const expected_stats = try planReuse(&expected, std.testing.allocator, input);
    var actual: Scratch = .{};
    defer actual.deinit(std.testing.allocator);
    var profile: Profile = .{};
    const actual_stats = try planReuseProfiled(&actual, std.testing.allocator, input, &profile);
    try std.testing.expectEqual(expected_stats, actual_stats);
    try std.testing.expect(tokenSlicesEqual(expected.reversed.items, actual.reversed.items));
    try std.testing.expectEqual(input.len, profile.positions);
    try std.testing.expectEqual(
        profile.positions,
        profile.literal_empty_inserts + profile.literal_replacements + profile.literal_rejections,
    );
    try std.testing.expectEqual(
        profile.indexed_matches,
        profile.indexed_empty_inserts + profile.indexed_replacements + profile.indexed_rejections,
    );
    try std.testing.expectEqual(
        profile.rep0_matches,
        profile.rep0_empty_inserts + profile.rep0_replacements + profile.rep0_rejections,
    );
    try std.testing.expectEqual(
        profile.indexed_chain_nodes,
        profile.indexed_prefix_rejections + profile.indexed_matches + profile.indexed_window_stops,
    );
    var indexed_length_total: usize = 0;
    for (profile.indexed_length_histogram) |count| indexed_length_total += count;
    try std.testing.expectEqual(profile.indexed_matches, indexed_length_total);
    var rep0_length_total: usize = 0;
    for (profile.rep0_length_histogram) |count| rep0_length_total += count;
    try std.testing.expectEqual(profile.rep0_matches, rep0_length_total);
    try std.testing.expectEqual(profile.rep0_probes, profile.rep0_prefix_rejections + profile.rep0_matches);
    var rep0_mismatch_total: usize = 0;
    for (profile.rep0_prefix_mismatch_histogram) |count| rep0_mismatch_total += count;
    try std.testing.expectEqual(profile.rep0_prefix_rejections, rep0_mismatch_total);
}

test "single-state fused index matches prebuilt predecessor chains" {
    var input: [8192]u8 = undefined;
    var random_state: u32 = 0x243f_6a88;
    for (&input, 0..) |*byte, index| {
        random_state = random_state *% 1_664_525 +% 1_013_904_223;
        byte.* = if (index % 64 < 52)
            @intCast('a' + index % 23)
        else
            @truncate(random_state >> 24);
    }

    var expected_head: [head_size]u16 = @splat(empty);
    const expected_prev = try std.testing.allocator.alloc(u16, input.len);
    defer std.testing.allocator.free(expected_prev);
    for (&input, 0..) |_, position| {
        if (position + min_match > input.len) {
            expected_prev[position] = empty;
            continue;
        }
        const hash = hash4(&input, position);
        expected_prev[position] = expected_head[hash];
        expected_head[hash] = @intCast(position);
    }

    var scratch: Scratch = .{};
    defer scratch.deinit(std.testing.allocator);
    _ = try planReuse(&scratch, std.testing.allocator, &input);
    try std.testing.expectEqualSlices(u16, &expected_head, &scratch.head);
    try std.testing.expectEqualSlices(u16, expected_prev, scratch.prev.items);
}

test "single-state shifted indexed matches preserve full-extension plans" {
    if (builtin.single_threaded) test_first_shifted_indexed_match_hits = 0 else @atomicStore(usize, &test_first_shifted_indexed_match_hits, 0, .monotonic);
    var shifted: Scratch = .{};
    defer shifted.deinit(std.testing.allocator);
    var reference: Scratch = .{};
    defer reference.deinit(std.testing.allocator);

    var shifted_hits: usize = 0;
    for (0..64) |seed| {
        const input_len = 4 * 1024 + (seed % 8) * 4 * 1024;
        const input = try std.testing.allocator.alloc(u8, input_len);
        defer std.testing.allocator.free(input);
        var random_state: u32 = @truncate(0x3c6e_f372 +% seed *% 0x0100_0193);
        for (input, 0..) |*byte, position| {
            random_state = random_state *% 1_664_525 +% 1_013_904_223;
            byte.* = switch (seed & 3) {
                0 => @truncate(random_state >> 24),
                1 => @intCast('a' + (position / 5 + seed) % 19),
                2 => if (position % 64 < 52) @intCast(' ' + (position + seed) % 64) else @truncate(random_state >> 24),
                else => @truncate((position * 29 + (position / 13) * 11 + seed) & 0xff),
            };
        }
        if (seed % 3 != 0) {
            const copy_len = input.len / 4;
            @memcpy(input[input.len - copy_len ..], input[input.len / 4 ..][0..copy_len]);
        }

        var profile: Profile = .{};
        const shifted_stats = try planReuseWithChainLimit(&shifted, std.testing.allocator, input, max_chain, true, true, &profile);
        const reference_stats = try planReuseWithChainLimit(&reference, std.testing.allocator, input, max_chain, false, false, undefined);
        try std.testing.expectEqual(reference_stats, shifted_stats);
        try std.testing.expect(tokenSlicesEqual(reference.reversed.items, shifted.reversed.items));
        shifted_hits += profile.shifted_indexed_matches;
    }
    try std.testing.expect(shifted_hits != 0);
    try std.testing.expect(test_first_shifted_indexed_match_hits != 0);
}

test "single-state prefixed match extension preserves every boundary" {
    var input: [768]u8 = undefined;
    var random_state: u32 = 0x9e37_79b9;
    for (&input) |*byte| {
        random_state = random_state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(random_state >> 24);
    }
    const candidate: usize = 17;
    const position: usize = 320;
    for (min_match..259) |expected| {
        @memcpy(input[position..][0..expected], input[candidate..][0..expected]);
        if (position + expected < input.len)
            input[position + expected] = input[candidate + expected] ^ 1;
        const maximum = @min(expected + 1, input.len - position);
        try std.testing.expectEqual(expected, matchLengthAfterPrefix(&input, candidate, position, maximum, min_match));
    }
}

test "single-state bounded chain preserves generated plan cost" {
    var fast: Scratch = .{};
    defer fast.deinit(std.testing.allocator);
    var deep: Scratch = .{};
    defer deep.deinit(std.testing.allocator);
    var changed: usize = 0;
    var higher_cost: usize = 0;
    var total_fast_cost: usize = 0;
    var total_deep_cost: usize = 0;
    var worst_extra: usize = 0;

    for (0..128) |seed| {
        const length = 4 * 1024 + (seed % 8) * 4 * 1024;
        const input = try std.testing.allocator.alloc(u8, length);
        defer std.testing.allocator.free(input);
        var random_state: u32 = @truncate(0x6a09_e667 +% seed *% 0x0100_0193);
        for (input, 0..) |*byte, index| {
            random_state = random_state *% 1_664_525 +% 1_013_904_223;
            byte.* = switch (seed & 3) {
                0 => @truncate(random_state >> 24),
                1 => @intCast('a' + (index + seed) % 23),
                2 => if (index % 64 < 52) @intCast('a' + (index / 7 + seed) % 19) else @truncate(random_state >> 24),
                else => @truncate((index * 37 + (index / 11) * 17 + seed) & 0xff),
            };
        }
        if (seed % 3 == 0) {
            const copy_len = input.len / 4;
            @memcpy(input[input.len - copy_len ..], input[input.len / 4 ..][0..copy_len]);
        }

        const fast_stats = try planReuseWithChainLimit(&fast, std.testing.allocator, input, max_chain, true, false, undefined);
        const deep_stats = try planReuseWithChainLimit(&deep, std.testing.allocator, input, 128, true, false, undefined);
        try std.testing.expectEqual(input.len, fast_stats.literals + fast_stats.matched_bytes);
        try std.testing.expectEqual(input.len, deep_stats.literals + deep_stats.matched_bytes);
        const fast_cost = planCost(fast.reversed.items);
        const deep_cost = planCost(deep.reversed.items);
        changed += @intFromBool(!tokenSlicesEqual(fast.reversed.items, deep.reversed.items));
        higher_cost += @intFromBool(fast_cost > deep_cost);
        total_fast_cost += fast_cost;
        total_deep_cost += deep_cost;
        worst_extra = @max(worst_extra, fast_cost -| deep_cost);
    }
    try std.testing.expectEqual(@as(usize, 1), changed);
    try std.testing.expectEqual(@as(usize, 1), higher_cost);
    try std.testing.expectEqual(@as(usize, 4_593_896), total_fast_cost);
    try std.testing.expectEqual(@as(usize, 4_593_884), total_deep_cost);
    try std.testing.expectEqual(@as(usize, 12), worst_extra);
}

fn planCost(tokens: []const lz77.Token) usize {
    var total: usize = 0;
    var rep0: usize = 1;
    for (tokens) |token| switch (token) {
        .literal => |byte| total += literalCost(byte),
        .match => |match| {
            total += lengthCost(match.length);
            total += if (match.distance == rep0) 1 else distanceCost(match.distance) + 4;
            rep0 = match.distance;
        },
    };
    return total;
}

fn tokenSlicesEqual(a: []const lz77.Token, b: []const lz77.Token) bool {
    if (a.len != b.len) return false;
    for (a, b) |left, right| switch (left) {
        .literal => |byte| switch (right) {
            .literal => |other| if (byte != other) return false,
            .match => return false,
        },
        .match => |match| switch (right) {
            .literal => return false,
            .match => |other| if (match.length != other.length or match.distance != other.distance) return false,
        },
    };
    return true;
}

test "single-state repeat beam releases every allocation failure" {
    const input = ("abcdefgh-abcdefgh-" ** 128) ++ ("0123456789abcdef" ** 64);
    const Test = struct {
        fn run(allocator: std.mem.Allocator, bytes: []const u8) !void {
            var scratch: Scratch = .{};
            defer scratch.deinit(allocator);
            const stats = try planReuse(&scratch, allocator, bytes);
            try std.testing.expectEqual(bytes.len, stats.literals + stats.matched_bytes);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Test.run, .{input});
}
