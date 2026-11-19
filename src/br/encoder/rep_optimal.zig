const std = @import("std");
const lz77 = @import("../../lz77.zig");
const entropy_feedback = @import("entropy_feedback.zig");
const command_encoding = @import("command_encoding.zig");

/// Forward beam parser that carries Brotli's four-entry distance cache in
/// every state. The reference q11 parser keeps a distance cache per DP node,
/// which is why roughly half of its copies reuse the last distance and pay no
/// distance symbol. A state-free optimal parser cannot see that saving.
///
/// The beam keeps the cheapest states per position, deduplicated by
/// `(distance cache, insert bucket)`. Each transition stores the exact insert
/// length so the command symbol is priced with the real literal run.
pub const Options = struct {
    window_len: usize,
    max_chain: u16,
    nice_len: u16,
    frontier_candidates: usize = 4,
    beam_width: usize = 8,
    min_match: usize = 4,
    max_match: usize = lz77.max_match_len,
};

pub const PlanStats = struct {
    matches: usize = 0,
    matched_bytes: usize = 0,
    implicit_matches: usize = 0,
};

pub const Plan = struct {
    tokens: []lz77.Token,
    stats: PlanStats,

    pub fn deinit(self: Plan, allocator: std.mem.Allocator) void {
        allocator.free(self.tokens);
    }
};

const max_beam_width: usize = 16;
const bucket_count = 9;
const bucket_starts = [bucket_count]usize{ 0, 1, 2, 3, 4, 8, 16, 32, 64 };
const unavailable_cost: u32 = std.math.maxInt(u32);

const Kind = enum(u2) { literal, lz77 };

const State = struct {
    cost: u32 = unavailable_cost,
    prev_position: u32 = 0,
    prev_slot: u8 = 0,
    insert_len: u32 = 0,
    length: u16 = 0,
    distance: u16 = 0,
    kind: Kind = .literal,
    implicit: bool = false,
    cache: [4]u16 = .{ 0, 0, 0, 0 },
};

fn bucketFor(insert_len: usize) usize {
    var bucket: usize = 0;
    while (bucket + 1 < bucket_count and insert_len >= bucket_starts[bucket + 1]) : (bucket += 1) {}
    return bucket;
}

fn pushDistance(cache: *[4]u16, distance: u16) void {
    cache[0] = cache[1];
    cache[1] = cache[2];
    cache[2] = cache[3];
    cache[3] = distance;
}

/// Returns the Brotli short-distance symbol for `distance`, matching the
/// decoder's cache order (0 is the most recent entry).
fn cacheSymbol(distance: u16, cache: *const [4]u16) ?u4 {
    if (distance == cache[3]) return 0;
    if (distance == cache[2]) return 1;
    if (distance == cache[1]) return 2;
    if (distance == cache[0]) return 3;
    return null;
}

fn literalPrice(model: *const entropy_feedback.Model, input: []const u8, position: usize) u32 {
    const byte = input[position];
    const previous: u8 = if (position == 0) 0 else input[position - 1];
    return model.literal_context[
        @as(usize, lz77.literalContextClass(previous)) * 256 + byte
    ];
}

fn commandPrice(
    model: *const entropy_feedback.Model,
    insert_len: usize,
    copy_len: usize,
    distance: u16,
    symbol: ?u4,
) u32 {
    // The seed model rarely contains implicit command-symbol variants, so the
    // unseen-symbol penalty would overprice exactly the repcode edges this
    // parser exists to find. Price the command with the explicit variant,
    // which shares the same insert/copy shape, and charge only the distance
    // code on top: zero for the last distance and a bounded short-code cost
    // for the other three cache entries.
    const encoding = command_encoding.forLengths(insert_len, copy_len, false) orelse
        return unavailable_cost;
    const extra: u32 = @as(u32, encoding.command.insert_extra_bits) +
        encoding.command.copy_extra_bits;
    const base = @as(u32, model.command[encoding.symbol]) +
        extra * entropy_feedback.cost_scale;
    const distance_cost: u32 = if (symbol) |short|
        (if (short == 0) 0 else @min(
            @as(u32, model.distance_symbol[short]),
            4 * entropy_feedback.cost_scale,
        ))
    else
        (if (distance < model.distance.len) model.distance[distance] else return unavailable_cost);
    return std.math.add(u32, base, distance_cost) catch unavailable_cost;
}

fn addCost(cost: u32, extra: u32) u32 {
    return std.math.add(u32, cost, extra) catch unavailable_cost;
}

fn insertState(
    states: []State,
    counts: []u8,
    position: usize,
    beam_width: usize,
    candidate: State,
) void {
    const base = position * beam_width;
    const count = counts[position];
    const bucket = bucketFor(candidate.insert_len);
    var worst_slot: usize = 0;
    var worst_cost: u32 = 0;
    var slot: usize = 0;
    while (slot < count) : (slot += 1) {
        const existing = states[base + slot];
        if (bucketFor(existing.insert_len) == bucket and
            std.mem.eql(u16, &existing.cache, &candidate.cache))
        {
            if (candidate.cost < existing.cost) states[base + slot] = candidate;
            return;
        }
        if (existing.cost > worst_cost) {
            worst_cost = existing.cost;
            worst_slot = slot;
        }
    }
    if (count < beam_width) {
        states[base + count] = candidate;
        counts[position] = @intCast(count + 1);
        return;
    }
    if (candidate.cost < worst_cost) states[base + worst_slot] = candidate;
}

pub fn planAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: Options,
    model: *const entropy_feedback.Model,
    starting_distances: [4]usize,
) !Plan {
    if (options.window_len == 0 or options.window_len > lz77.max_window_len)
        return error.InvalidBlockPlan;
    if (options.beam_width == 0 or options.beam_width > max_beam_width)
        return error.InvalidBlockPlan;
    if (model.distance.len <= options.window_len) return error.InvalidBlockPlan;
    if (options.min_match < lz77.min_match_len) return error.InvalidBlockPlan;
    if (input.len == 0) return .{ .tokens = try allocator.alloc(lz77.Token, 0), .stats = .{} };

    var initial_cache: [4]u16 = undefined;
    for (starting_distances, 0..) |distance, index| {
        if (distance > options.window_len) return error.InvalidBlockPlan;
        initial_cache[index] = @intCast(distance);
    }

    const state_count = std.math.mul(usize, input.len + 1, options.beam_width) catch
        return error.IntegerOverflow;
    const states = try allocator.alloc(State, state_count);
    defer allocator.free(states);
    @memset(states, State{});
    const counts = try allocator.alloc(u8, input.len + 1);
    defer allocator.free(counts);
    @memset(counts, 0);

    const frontier = try lz77.collectHashFrontierAlloc(allocator, input, .{
        .window_len = options.window_len,
        .max_chain = options.max_chain,
        .nice_len = options.nice_len,
        .min_match = options.min_match,
        .max_match = options.max_match,
    }, options.frontier_candidates);
    defer frontier.deinit(allocator);

    states[0] = .{ .cost = 0, .cache = initial_cache };
    counts[0] = 1;

    for (0..input.len) |position| {
        const count = counts[position];
        if (count == 0) continue;
        const base = position * options.beam_width;
        const matches = frontier.at(position);
        for (0..count) |slot| {
            const state = states[base + slot];
            if (state.cost == unavailable_cost) continue;

            {
                var next = state;
                next.cost = addCost(state.cost, literalPrice(model, input, position));
                if (next.cost != unavailable_cost) {
                    next.prev_position = @intCast(position);
                    next.prev_slot = @intCast(slot);
                    next.insert_len += 1;
                    next.length = 0;
                    next.distance = 0;
                    next.kind = .literal;
                    next.implicit = false;
                    insertState(states, counts, position + 1, options.beam_width, next);
                }
            }

            const max_len = @min(options.max_match, input.len - position);
            for (matches) |match| {
                if (@as(usize, match.length) > max_len) continue;
                const symbol = cacheSymbol(match.distance, &state.cache);
                const price = commandPrice(model, state.insert_len, match.length, match.distance, symbol);
                if (price == unavailable_cost) continue;
                var next = state;
                next.cost = addCost(state.cost, price);
                if (next.cost == unavailable_cost) continue;
                if (symbol) |short| {
                    if (short != 0) pushDistance(&next.cache, match.distance);
                }
                next.prev_position = @intCast(position);
                next.prev_slot = @intCast(slot);
                next.insert_len = 0;
                next.length = match.length;
                next.distance = match.distance;
                next.kind = .lz77;
                next.implicit = symbol != null and symbol.? == 0;
                insertState(states, counts, position + @as(usize, match.length), options.beam_width, next);
            }

            // Cached distances are the source of implicit and short distance
            // codes. They are cheap to test and often missed by the hash chain.
            for (0..4) |cache_index| {
                const distance = state.cache[cache_index];
                const distance_len: usize = distance;
                if (distance == 0 or distance_len > position or distance_len > options.window_len) continue;
                const candidate_position = position - distance_len;
                if (position + options.min_match > input.len) continue;
                if (!std.mem.eql(
                    u8,
                    input[candidate_position..][0..options.min_match],
                    input[position..][0..options.min_match],
                )) continue;
                const length = lz77.matchLength(
                    input,
                    candidate_position,
                    position,
                    max_len,
                );
                if (length < options.min_match) continue;
                const symbol: u4 = @intCast(3 - cache_index);
                const price = commandPrice(model, state.insert_len, length, distance, symbol);
                if (price == unavailable_cost) continue;
                var next = state;
                next.cost = addCost(state.cost, price);
                if (next.cost == unavailable_cost) continue;
                if (symbol != 0) pushDistance(&next.cache, distance);
                next.prev_position = @intCast(position);
                next.prev_slot = @intCast(slot);
                next.insert_len = 0;
                next.length = @intCast(length);
                next.distance = distance;
                next.kind = .lz77;
                next.implicit = symbol == 0;
                insertState(states, counts, position + length, options.beam_width, next);
            }
        }
    }

    const final_count = counts[input.len];
    if (final_count == 0) return error.InvalidBlockPlan;
    var best_slot: usize = 0;
    var best_cost: u32 = unavailable_cost;
    for (0..final_count) |slot| {
        const state = states[input.len * options.beam_width + slot];
        if (state.cost < best_cost) {
            best_cost = state.cost;
            best_slot = slot;
        }
    }
    if (best_cost == unavailable_cost) return error.InvalidBlockPlan;

    var reversed: std.ArrayList(lz77.Token) = .empty;
    errdefer reversed.deinit(allocator);
    var stats = PlanStats{};
    var position = input.len;
    var slot = best_slot;
    while (position > 0) {
        const state = states[position * options.beam_width + slot];
        switch (state.kind) {
            .literal => {
                try reversed.append(allocator, .{ .literal = input[position - 1] });
                position -= 1;
            },
            .lz77 => {
                try reversed.append(allocator, .{ .match = .{
                    .length = state.length,
                    .distance = state.distance,
                } });
                stats.matches += 1;
                stats.matched_bytes += state.length;
                if (state.implicit) stats.implicit_matches += 1;
                position = state.prev_position;
            },
        }
        slot = state.prev_slot;
    }
    std.mem.reverse(lz77.Token, reversed.items);
    return .{ .tokens = try reversed.toOwnedSlice(allocator), .stats = stats };
}

test "repcode beam plan round-trips repetitive input" {
    const input = "abcabcabcabcabcabcabcabcabcabcXabcabcabcabc";
    var seed = try lz77.hashGreedyPlanAutoAlloc(std.testing.allocator, input, .{ .min_match = 4 });
    defer seed.deinit(std.testing.allocator);
    const commands = try @import("command_plan.zig").buildAlloc(std.testing.allocator, input, seed.tokens);
    defer commands.deinit(std.testing.allocator);
    var model = try entropy_feedback.build(std.testing.allocator, input, commands.commands, input.len);
    defer model.deinit(std.testing.allocator);

    const plan = try planAlloc(std.testing.allocator, input, .{
        .window_len = input.len,
        .max_chain = 16,
        .nice_len = lz77.max_match_len,
    }, &model, .{ 16, 15, 11, 4 });
    defer plan.deinit(std.testing.allocator);
    const replayed = try lz77.replayAlloc(std.testing.allocator, plan.tokens);
    defer std.testing.allocator.free(replayed);
    try std.testing.expectEqualSlices(u8, input, replayed);
    try std.testing.expect(plan.stats.matches >= 1);
}

test "repcode beam plan prefers the cached distance for repeated copies" {
    const input = "abcdXabcdYabcdZabcdWabcdVabcdUabcdT";
    var seed = try lz77.hashGreedyPlanAutoAlloc(std.testing.allocator, input, .{ .min_match = 4 });
    defer seed.deinit(std.testing.allocator);
    const commands = try @import("command_plan.zig").buildAlloc(std.testing.allocator, input, seed.tokens);
    defer commands.deinit(std.testing.allocator);
    var model = try entropy_feedback.build(std.testing.allocator, input, commands.commands, input.len);
    defer model.deinit(std.testing.allocator);

    const plan = try planAlloc(std.testing.allocator, input, .{
        .window_len = input.len,
        .max_chain = 16,
        .nice_len = lz77.max_match_len,
        .beam_width = 8,
    }, &model, .{ 16, 15, 11, 4 });
    defer plan.deinit(std.testing.allocator);
    const replayed = try lz77.replayAlloc(std.testing.allocator, plan.tokens);
    defer std.testing.allocator.free(replayed);
    try std.testing.expectEqualSlices(u8, input, replayed);
    var previous_distance: u16 = 0;
    var repeated = false;
    for (plan.tokens) |token| switch (token) {
        .literal => {},
        .match => |match| {
            if (match.distance == previous_distance) repeated = true;
            previous_distance = match.distance;
        },
    };
    try std.testing.expect(repeated);
}
