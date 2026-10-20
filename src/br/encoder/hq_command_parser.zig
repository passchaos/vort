const std = @import("std");
const lz77 = @import("../../lz77.zig");
const command_encoding = @import("command_encoding.zig");
const distance = @import("distance.zig");
const distance_history = @import("../decoder/distance_history.zig");
const entropy_feedback = @import("entropy_feedback.zig");
const length = @import("../length.zig");

const beam_width = 2;
const initial_last_distances = [_]usize{ 16, 15, 11, 4 };
const q8: u64 = 256;

const RecentCandidates = struct {
    distances: [16]u16 = undefined,
    symbols: [16]u4 = undefined,
    len: u5 = 0,

    fn init(last_distances: *const [4]usize) RecentCandidates {
        var result: RecentCandidates = .{};
        for (0..16) |symbol| {
            var match_distance: usize = undefined;
            distance_history.resolveShortInto(
                @intCast(symbol),
                last_distances,
                &match_distance,
            ) catch continue;
            if (match_distance == 0 or match_distance > std.math.maxInt(u16))
                continue;
            var duplicate = false;
            for (result.distances[0..result.len]) |existing| {
                duplicate = duplicate or existing == match_distance;
            }
            if (duplicate) continue;
            result.distances[result.len] = @intCast(match_distance);
            result.symbols[result.len] = @intCast(symbol);
            result.len += 1;
        }
        return result;
    }

    fn symbolFor(self: *const RecentCandidates, match_distance: usize) ?u4 {
        if (match_distance > std.math.maxInt(u16)) return null;
        const narrowed: u16 = @intCast(match_distance);
        for (self.distances[0..self.len], self.symbols[0..self.len]) |candidate, symbol| {
            if (candidate == narrowed) return symbol;
        }
        return null;
    }
};

const State = struct {
    cost: u64,
    last_distances: [4]usize,
    pending_insert: usize,
    previous_position: u32,
    previous_slot: u8,
    token: lz77.Token,
};

pub const Stats = struct {
    positions: usize = 0,
    states_visited: usize = 0,
    match_candidates: usize = 0,
    match_transitions: usize = 0,
    general_match_transitions: usize = 0,
    recent_match_transitions: usize = 0,
    cost_bound_rejections: usize = 0,
    beam_replacements: usize = 0,
    index_ns: u64 = 0,
    setup_ns: u64 = 0,
    search_ns: u64 = 0,
    reconstruct_ns: u64 = 0,
    total_ns: u64 = 0,
};

pub const Plan = struct {
    lz: lz77.GreedyPlan,
    stats: Stats,

    pub fn deinit(self: Plan, allocator: std.mem.Allocator) void {
        self.lz.deinit(allocator);
    }
};

/// Bounded forward parser whose state includes the pending insert run and
/// Brotli's four recent distances. It is intentionally a candidate generator:
/// callers must retain it only after complete wire-size arbitration.
pub fn planAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: lz77.GreedyOptions,
    model: *const entropy_feedback.Model,
) !Plan {
    return planAllocWithStartingDistances(
        allocator,
        input,
        options,
        model,
        initial_last_distances,
    );
}

pub fn planAllocWithStartingDistances(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: lz77.GreedyOptions,
    model: *const entropy_feedback.Model,
    starting_last_distances: [4]usize,
) !Plan {
    return planAllocInternal(
        false,
        allocator,
        input,
        options,
        model,
        starting_last_distances,
        undefined,
    );
}

pub fn planAllocProfiledWithStartingDistances(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: lz77.GreedyOptions,
    model: *const entropy_feedback.Model,
    starting_last_distances: [4]usize,
    io: std.Io,
) !Plan {
    return planAllocInternal(
        true,
        allocator,
        input,
        options,
        model,
        starting_last_distances,
        io,
    );
}

fn planAllocInternal(
    comptime profiled: bool,
    allocator: std.mem.Allocator,
    input: []const u8,
    options: lz77.GreedyOptions,
    model: *const entropy_feedback.Model,
    starting_last_distances: [4]usize,
    io: if (profiled) std.Io else void,
) !Plan {
    const total_start = if (comptime profiled) std.Io.Clock.awake.now(io) else {};
    if (input.len == 0 or input.len > std.math.maxInt(u32) or
        options.window_len == 0 or options.window_len > lz77.default_window_len or
        options.min_match < 3 or options.min_match > options.max_match or
        options.max_match > lz77.max_match_len or options.max_chain == 0 or
        options.max_candidates == 0 or options.max_candidates > lz77.max_optimal_candidates)
    {
        return error.InvalidBlockPlan;
    }
    if (model.distance.len <= options.window_len) return error.InvalidBlockPlan;
    for (starting_last_distances) |value|
        if (value == 0) return error.InvalidBlockPlan;

    const index_start = if (comptime profiled) std.Io.Clock.awake.now(io) else {};
    var index: lz77.HashIndex = .{};
    defer index.deinit(allocator);
    try index.build(allocator, input);
    const index_ns = if (comptime profiled) elapsedNs(index_start, io) else {};

    const setup_start = if (comptime profiled) std.Io.Clock.awake.now(io) else {};

    const position_count = std.math.add(usize, input.len, 1) catch
        return error.IntegerOverflow;
    const state_count = std.math.mul(usize, position_count, beam_width) catch
        return error.IntegerOverflow;
    const states = try allocator.alloc(State, state_count);
    defer allocator.free(states);
    const lengths = try allocator.alloc(u8, input.len + 1);
    defer allocator.free(lengths);
    @memset(lengths, 0);
    states[0] = .{
        .cost = 0,
        .last_distances = starting_last_distances,
        .pending_insert = 0,
        .previous_position = 0,
        .previous_slot = 0,
        .token = .{ .literal = 0 },
    };
    lengths[0] = 1;

    var stats: Stats = .{};
    if (comptime profiled) {
        stats.index_ns = index_ns;
        stats.setup_ns = elapsedNs(setup_start, io);
    }
    const search_start = if (comptime profiled) std.Io.Clock.awake.now(io) else {};
    var candidate_distances: [lz77.max_optimal_candidates]u16 = undefined;
    var cached_match_lengths: [lz77.max_optimal_candidates]u16 = undefined;
    const minimum_regular_distance_cost = std.mem.min(
        u16,
        model.distance_symbol[16..],
    );
    for (0..input.len) |position| {
        stats.positions += 1;
        const candidate_count = try index.candidateDistancesAt(
            input,
            position,
            options,
            &candidate_distances,
        );
        @memset(
            cached_match_lengths[0..candidate_count],
            std.math.maxInt(u16),
        );
        stats.match_candidates += candidate_count;
        const current = states[position * beam_width ..][0..lengths[position]];
        for (current, 0..) |*state, slot| {
            stats.states_visited += 1;
            insertState(states, lengths, position + 1, .{
                .cost = addCost(state.cost, model.literal[input[position]]),
                .last_distances = state.last_distances,
                .pending_insert = state.pending_insert + 1,
                .previous_position = @intCast(position),
                .previous_slot = @intCast(slot),
                .token = .{ .literal = input[position] },
            }, &stats);
            const insert_code = length.codeForValue(
                state.pending_insert,
                true,
            ) orelse continue;
            const insert_extra_bits = length.insertSpec(insert_code).extra_bits;
            const recent_candidates = RecentCandidates.init(&state.last_distances);

            for (candidate_distances[0..candidate_count], 0..) |match_distance, candidate_index| {
                const recent_symbol = recent_candidates.symbolFor(match_distance);
                if (candidate_index >= options.max_candidates and recent_symbol == null) {
                    const regular = distance.encodeWithParameters(
                        match_distance,
                        distance.Parameters.init(0, 0),
                    ) orelse continue;
                    if (model.distance_symbol[regular.symbol] >
                        @as(u32, minimum_regular_distance_cost) + 256)
                    {
                        continue;
                    }
                }
                const cached_length = &cached_match_lengths[candidate_index];
                if (cached_length.* == std.math.maxInt(u16)) {
                    cached_length.* = @intCast(matchLengthAtDistance(
                        input,
                        position,
                        match_distance,
                        @max(options.min_match, 3),
                        @min(options.max_match, lz77.max_match_len),
                    ) orelse 0);
                }
                const copy_len: usize = cached_length.*;
                if (copy_len == 0) continue;
                const transition = transitionCost(
                    model,
                    state,
                    insert_code,
                    insert_extra_bits,
                    @intCast(copy_len),
                    match_distance,
                    recent_symbol,
                    null,
                ) orelse continue;
                stats.match_transitions += 1;
                if (comptime profiled) stats.general_match_transitions += 1;
                if (!canBeatBeamCost(
                    states,
                    lengths,
                    position + copy_len,
                    transition.cost,
                )) {
                    if (comptime profiled) stats.cost_bound_rejections += 1;
                    continue;
                }
                insertState(states, lengths, position + copy_len, .{
                    .cost = transition.cost,
                    .last_distances = transitionLastDistances(
                        state,
                        match_distance,
                        transition.recent_symbol,
                    ),
                    .pending_insert = 0,
                    .previous_position = @intCast(position),
                    .previous_slot = @intCast(slot),
                    .token = .{ .match = .{
                        .length = @intCast(copy_len),
                        .distance = match_distance,
                    } },
                }, &stats);
            }

            for (
                recent_candidates.distances[0..recent_candidates.len],
                recent_candidates.symbols[0..recent_candidates.len],
            ) |match_distance, recent_symbol| {
                if (match_distance > position) continue;
                const copy_len = matchLengthAtDistance(
                    input,
                    position,
                    match_distance,
                    @max(options.min_match, 3),
                    @min(options.max_match, lz77.max_match_len),
                ) orelse continue;
                const transition = transitionCost(
                    model,
                    state,
                    insert_code,
                    insert_extra_bits,
                    @intCast(copy_len),
                    match_distance,
                    recent_symbol,
                    null,
                ) orelse continue;
                stats.match_transitions += 1;
                if (comptime profiled) stats.recent_match_transitions += 1;
                if (!canBeatBeamCost(
                    states,
                    lengths,
                    position + copy_len,
                    transition.cost,
                )) {
                    if (comptime profiled) stats.cost_bound_rejections += 1;
                    continue;
                }
                insertState(states, lengths, position + copy_len, .{
                    .cost = transition.cost,
                    .last_distances = transitionLastDistances(
                        state,
                        match_distance,
                        transition.recent_symbol,
                    ),
                    .pending_insert = 0,
                    .previous_position = @intCast(position),
                    .previous_slot = @intCast(slot),
                    .token = .{ .match = .{
                        .length = @intCast(copy_len),
                        .distance = match_distance,
                    } },
                }, &stats);
            }
        }
    }

    if (comptime profiled) stats.search_ns = elapsedNs(search_start, io);
    const reconstruct_start = if (comptime profiled) std.Io.Clock.awake.now(io) else {};
    const final_states = states[input.len * beam_width ..][0..lengths[input.len]];
    var best_slot: ?usize = null;
    var best_cost: u64 = std.math.maxInt(u64);
    for (final_states, 0..) |state, slot| {
        const cost = terminalCost(model, state) orelse continue;
        if (cost < best_cost) {
            best_cost = cost;
            best_slot = slot;
        }
    }

    var reversed: std.ArrayList(lz77.Token) = .empty;
    defer reversed.deinit(allocator);
    try reversed.ensureTotalCapacity(allocator, @min(input.len, 4096));
    var position = input.len;
    var slot = best_slot orelse return error.InvalidBlockPlan;
    while (position != 0) {
        const state = states[position * beam_width + slot];
        try reversed.append(allocator, state.token);
        position = state.previous_position;
        slot = state.previous_slot;
    }
    std.mem.reverse(lz77.Token, reversed.items);

    var plan_stats: lz77.PlanStats = .{};
    for (reversed.items) |token| switch (token) {
        .literal => plan_stats.literals += 1,
        .match => |match| {
            plan_stats.matches += 1;
            plan_stats.matched_bytes += match.length;
        },
    };
    if (comptime profiled) {
        stats.reconstruct_ns = elapsedNs(reconstruct_start, io);
        stats.total_ns = elapsedNs(total_start, io);
    }
    return .{
        .lz = .{
            .tokens = try reversed.toOwnedSlice(allocator),
            .stats = plan_stats,
        },
        .stats = stats,
    };
}

fn elapsedNs(start: std.Io.Timestamp, io: std.Io) u64 {
    const ns = start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds;
    return if (ns <= 0) 0 else @intCast(ns);
}

const Transition = struct {
    cost: u64,
    recent_symbol: ?u4,
};

fn transitionCost(
    model: *const entropy_feedback.Model,
    state: *const State,
    insert_code: u5,
    insert_extra_bits: u5,
    copy_len: u16,
    match_distance: u16,
    recent_symbol: ?u4,
    prepared_regular: ?distance.Encoding,
) ?Transition {
    const copy_code = length.codeForValue(copy_len, false) orelse return null;
    const copy_spec = length.copySpec(copy_code);
    const extras = (@as(u64, insert_extra_bits) + copy_spec.extra_bits) * q8;
    const explicit_command = command_encoding.forCodes(insert_code, copy_code, false) orelse
        return null;
    const regular_distance = if (recent_symbol == null)
        prepared_regular orelse distance.encodeWithParameters(
            match_distance,
            distance.Parameters.init(0, 0),
        ) orelse return null
    else
        undefined;
    const distance_symbol: usize = recent_symbol orelse regular_distance.symbol;
    var best_edge = @as(u64, model.command[explicit_command.symbol]) + extras +
        model.distance_symbol[distance_symbol] +
        @as(u64, if (recent_symbol == null) regular_distance.extra_bits else 0) * q8;
    if (recent_symbol == 0) {
        if (command_encoding.forCodes(insert_code, copy_code, true)) |implicit| {
            best_edge = @min(
                best_edge,
                @as(u64, model.command[implicit.symbol]) + extras,
            );
        }
    }

    return .{
        .cost = addCost(state.cost, best_edge),
        .recent_symbol = recent_symbol,
    };
}

fn canBeatBeamCost(
    states: []const State,
    lengths: []const u8,
    position: usize,
    cost: u64,
) bool {
    const len = lengths[position];
    if (len < beam_width) return true;
    const slots = states[position * beam_width ..][0..beam_width];
    var worst = slots[0].cost;
    for (slots[1..]) |state| {
        worst = @max(worst, state.cost);
    }
    return cost < worst;
}

fn transitionLastDistances(
    state: *const State,
    match_distance: u16,
    recent_symbol: ?u4,
) [4]usize {
    var last_distances = state.last_distances;
    if (recent_symbol != 0) distance_history.push(&last_distances, match_distance);
    return last_distances;
}

fn terminalCost(model: *const entropy_feedback.Model, state: State) ?u64 {
    if (state.pending_insert == 0) return state.cost;
    const encoding = command_encoding.forLengths(state.pending_insert, 2, false) orelse
        return null;
    const insert_code = length.codeForValue(state.pending_insert, true) orelse return null;
    const extras = @as(u64, length.insertSpec(insert_code).extra_bits) * q8;
    return addCost(state.cost, @as(u64, model.command[encoding.symbol]) + extras);
}

fn insertState(
    states: []State,
    lengths: []u8,
    position: usize,
    candidate: State,
    stats: *Stats,
) void {
    const slots = states[position * beam_width ..][0..beam_width];
    const len = lengths[position];
    for (slots[0..len]) |*state| {
        if (state.pending_insert == candidate.pending_insert and
            std.mem.eql(usize, &state.last_distances, &candidate.last_distances))
        {
            if (candidate.cost < state.cost) state.* = candidate;
            return;
        }
    }
    if (len < beam_width) {
        slots[len] = candidate;
        lengths[position] += 1;
        return;
    }
    var worst: usize = 0;
    for (slots[1..], 1..) |state, slot| {
        if (state.cost > slots[worst].cost) worst = slot;
    }
    if (candidate.cost < slots[worst].cost) {
        slots[worst] = candidate;
        stats.beam_replacements += 1;
    }
}

fn addCost(left: u64, right: anytype) u64 {
    return std.math.add(u64, left, @intCast(right)) catch std.math.maxInt(u64);
}

fn matchLengthAtDistance(
    input: []const u8,
    position: usize,
    match_distance: usize,
    minimum: usize,
    maximum: usize,
) ?usize {
    if (match_distance == 0 or match_distance > position or
        position >= input.len or minimum == 0)
    {
        return null;
    }
    const limit = @min(maximum, input.len - position);
    if (limit < minimum) return null;
    const candidate = position - match_distance;
    if (minimum >= 4 and std.mem.readInt(u32, input[candidate..][0..4], .little) !=
        std.mem.readInt(u32, input[position..][0..4], .little))
    {
        return null;
    }
    var len: usize = if (minimum >= 4) 4 else 0;
    while (len < limit and input[candidate + len] == input[position + len]) len += 1;
    return if (len >= minimum) len else null;
}

test "HQ command parser round trips and visits stateful matches" {
    const input = "abcabcabcabcXabcabcYabcabcZabcabc" ** 8;
    const seed = try lz77.optimalPlanAlloc(std.testing.allocator, input, .{
        .window_len = input.len,
        .max_chain = 64,
        .nice_len = 258,
        .max_candidates = 32,
        .min_match = 4,
        .max_match = 258,
    });
    defer seed.deinit(std.testing.allocator);
    const command_plan = @import("command_plan.zig");
    const commands = try command_plan.buildAlloc(std.testing.allocator, input, seed.tokens);
    defer commands.deinit(std.testing.allocator);
    var model = try entropy_feedback.build(
        std.testing.allocator,
        input,
        commands.commands,
        input.len,
    );
    defer model.deinit(std.testing.allocator);

    const plan = try planAlloc(std.testing.allocator, input, .{
        .window_len = input.len,
        .max_chain = 64,
        .nice_len = 258,
        .max_candidates = 32,
        .min_match = 4,
        .max_match = 258,
    }, &model);
    defer plan.deinit(std.testing.allocator);
    try std.testing.expect(plan.lz.stats.matches != 0);
    try std.testing.expect(plan.stats.states_visited >= input.len);
    try std.testing.expect(plan.stats.match_transitions != 0);
    const replayed = try lz77.replayAlloc(std.testing.allocator, plan.lz.tokens);
    defer std.testing.allocator.free(replayed);
    try std.testing.expectEqualSlices(u8, input, replayed);
}

test "beam cost bound rejects only candidates that cannot enter" {
    var states: [beam_width]State = undefined;
    states[0].cost = 100;
    states[1].cost = 200;
    var lengths = [_]u8{beam_width};
    try std.testing.expect(canBeatBeamCost(&states, &lengths, 0, 199));
    try std.testing.expect(!canBeatBeamCost(&states, &lengths, 0, 200));
    try std.testing.expect(!canBeatBeamCost(&states, &lengths, 0, 300));
    lengths[0] = 1;
    try std.testing.expect(canBeatBeamCost(&states, &lengths, 0, 300));
}

test "recent candidate table preserves first-symbol RFC mapping" {
    const histories = [_][4]usize{
        .{ 16, 15, 11, 4 },
        .{ 4, 4, 4, 4 },
        .{ 128, 64, 32, 16 },
    };
    for (histories) |history| {
        const candidates = RecentCandidates.init(&history);
        for (0..16) |symbol| {
            var match_distance: usize = undefined;
            distance_history.resolveShortInto(
                @intCast(symbol),
                &history,
                &match_distance,
            ) catch continue;
            if (match_distance == 0 or match_distance > std.math.maxInt(u16))
                continue;
            try std.testing.expectEqual(
                distance_history.symbolForDistance(match_distance, &history),
                candidates.symbolFor(match_distance),
            );
        }
    }
}
