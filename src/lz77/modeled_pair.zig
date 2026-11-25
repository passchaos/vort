//! Two independent modeled DPs sharing one nearest-first four-anchor scan.
//! Only the predecessor index and 16 bytes of DP storage per position persist;
//! no raw match frontier is materialized. Choices are local to one position.
//!
//! Api supplies the ordinary modeled parser's normalized options, prices,
//! four-anchor index and token append operation. Its dictionary provider must
//! return deterministic matches over immutable backing for this operation;
//! this path calls find once per eligible position rather than once per model.
//! Index predecessors are immutable, nearest-first, and use -1 as the sentinel.
//! This path matches the ordinary modeled branch with prefix bounds disabled.
const std = @import("std");

pub const max_input_len = 65536;
pub const max_window_len = 65535;
pub const max_match_len = 258;
const context_price_count = 4 * 256;
const choice_bits = 9;
const choice_mask = (1 << choice_bits) - 1;
const dictionary_marker: u32 = 1 << 31;
const dictionary_limit: u32 = 1 << 30;

/// Reject before allocating if a complete raw edge cost can exceed u32.
/// The always-available literal suffix bounds every stored DP cost. Adding the
/// largest active match/dictionary edge bounds temporary choices and sums too.
/// Api.validateModel also retains the ordinary parser's positivity, geometry
/// and input-dependent integer checks. False means use the ordinary parser.
pub fn supported(comptime Api: type, input: []const u8, options: Api.Options, models: [2]Api.Model) bool {
    const minimum = Api.minimum(options);
    const maximum = Api.maximum(options);
    if (input.len > max_input_len or options.window_len > max_window_len or
        minimum < 4 or maximum > max_match_len or minimum > maximum)
        return false;
    for (models) |model| {
        Api.validateModel(model, options.window_len, input.len) catch return false;
        if (model.distance.len <= options.window_len) return false;
        var max_literal: u64 = 0;
        for (model.literal) |price| max_literal = @max(max_literal, price);
        if (model.literal_context) |prices| {
            if (prices.len < context_price_count) return false;
            for (prices[0..context_price_count]) |price| max_literal = @max(max_literal, price);
        }
        var max_length: u64 = 0;
        for (model.length[minimum .. maximum + 1]) |price| max_length = @max(max_length, price);
        var max_distance: u64 = 0;
        for (model.distance[1 .. options.window_len + 1]) |price| max_distance = @max(max_distance, price);
        const dictionary_cost: u64 = if (options.dictionary != null) options.dictionary_cost else 0;
        const match_edge = std.math.add(u64, max_length, max_distance) catch return false;
        const largest_edge = @max(match_edge, dictionary_cost);
        const literal_bound = std.math.mul(u64, @intCast(input.len), max_literal) catch return false;
        const raw_bound = std.math.add(u64, literal_bound, largest_edge) catch return false;
        if (raw_bound > std.math.maxInt(u32)) return false;
    }
    return true;
}

/// Returned token slices have separate owners and remain valid after further
/// calls. Api.Plan contains tokens plus ordinary literals/matches/matched_bytes
/// stats; Api.Token.Match has the standard packed dictionary representation.
pub fn planAlloc(comptime Api: type, allocator: std.mem.Allocator, input: []const u8, options: Api.Options, models: [2]Api.Model) ![2]Api.Plan {
    if (!supported(Api, input, options, models)) return error.InvalidBlockPlan;
    if (input.len == 0) return .{
        .{ .tokens = &.{}, .stats = .{} },
        .{ .tokens = &.{}, .stats = .{} },
    };

    var index = try Api.buildIndex(allocator, input);
    var index_live = true;
    defer if (index_live) Api.deinitIndex(&index, allocator);
    Api.releaseHead(&index, allocator);
    const previous = Api.prev(&index);
    const empty = if (comptime @hasDecl(Api, "index_empty")) Api.index_empty else @as(isize, -1);
    std.debug.assert(previous.len == input.len);

    const count = input.len + 1;
    const storage = try allocator.alloc(u32, 4 * count);
    defer allocator.free(storage);
    const costs = [2][]u32{ storage[0..count], storage[count .. 2 * count] };
    const steps = [2][]u32{ storage[2 * count .. 3 * count], storage[3 * count ..] };
    const minimum = Api.minimum(options);
    const maximum = Api.maximum(options);
    const candidate_limit = Api.candidateLimit(options);
    std.debug.assert(candidate_limit != 0);
    for (costs) |values| values[input.len] = 0;
    var best_choices: [2][max_match_len + 1]u64 = undefined;

    var position = input.len;
    while (position != 0) {
        position -= 1;
        inline for (0..2) |side| {
            costs[side][position] = @intCast(@as(u64, costs[side][position + 1]) + Api.literalCost(models[side], position, input));
            steps[side][position] = 0;
        }
        // Ordinary modeled parsing skips dictionary work in this tail too.
        if (input.len - position < minimum) continue;
        const max_len = @min(maximum, input.len - position);
        var built_through = minimum - 1;
        var chain = previous[position];
        var checked: usize = 0;
        var candidates_seen: usize = 0;
        while (chain != empty and checked < options.max_chain) : (checked += 1) {
            const candidate: usize = @intCast(chain);
            std.debug.assert(candidate < position);
            const distance = position - candidate;
            if (distance == 0 or distance > options.window_len) break;
            // Hash collisions still consume chain budget, not candidate budget.
            if (std.mem.readInt(u32, input[candidate..][0..4], .little) !=
                std.mem.readInt(u32, input[position..][0..4], .little))
            {
                chain = previous[candidate];
                continue;
            }
            // A mismatch at the already-covered frontier bounds this match
            // by built_through. Reject only when the exact best covered cost
            // plus this distance's price cannot improve either independent
            // DP. Learned distance prices need not be monotone. Four equal
            // prefix bytes establish the valid candidate whose budget must
            // still be consumed when its matchLength call is avoided.
            if (minimum == 4 and built_through >= minimum and built_through < max_len and
                input[candidate + built_through] != input[position + built_through])
            {
                var both_dominated = true;
                inline for (0..2) |side| {
                    const bound = (best_choices[side][built_through] >> choice_bits) + models[side].distance[distance];
                    both_dominated = both_dominated and bound >= costs[side][position];
                }
                if (both_dominated) {
                    if (comptime @hasDecl(Api, "boundRejected")) Api.boundRejected();
                    candidates_seen += 1;
                    if (candidates_seen >= candidate_limit) break;
                    chain = previous[candidate];
                    continue;
                }
            }
            const length = Api.matchLength(input, candidate, position, max_len);
            if (length >= minimum) {
                inline for (0..2) |side| {
                    extendChoices(costs[side], models[side].length, position, minimum, built_through, length, &best_choices[side]);
                    const choice = best_choices[side][length];
                    const cost = (choice >> choice_bits) + models[side].distance[distance];
                    if (cost < costs[side][position]) {
                        costs[side][position] = @intCast(cost);
                        const selected_len: u32 = @intCast(max_match_len - (choice & choice_mask));
                        steps[side][position] = (@as(u32, @intCast(distance)) << 8) | (selected_len - 3);
                    }
                }
                built_through = @max(built_through, length);
                candidates_seen += 1;
                // Keep ordinary full/nice/candidate stopping order. In
                // particular, a nice match alone does not stop this parser.
                if (length == max_len) break;
                if (length >= options.nice_len and candidates_seen >= candidate_limit) break;
                if (candidates_seen >= candidate_limit) break;
            }
            // Repeated/equal/shorter lengths at another distance still have
            // independent distance prices and must be evaluated for both DPs.
            chain = previous[candidate];
        }

        if (options.dictionary) |provider| {
            if (options.dictionary_cost != 0) {
                if (provider.find(provider.context, position)) |match| {
                    const target = position + match.output_len;
                    if (match.output_len != 0 and match.copy_len != 0 and target <= input.len) {
                        var encoded: ?u32 = null;
                        inline for (0..2) |side| {
                            const cost = @as(u64, costs[side][target]) + options.dictionary_cost;
                            if (cost < costs[side][position]) {
                                if (encoded == null) {
                                    // Same contract as ordinary initDictionary;
                                    // check before its assertions/narrow packing.
                                    if (match.output_len < 4 or match.output_len > 63 or
                                        match.copy_len < 4 or match.copy_len > 24 or match.address >= (1 << 18))
                                        return error.InvalidBlockPlan;
                                    const token = Api.Token.Match.initDictionary(match.output_len, match.copy_len, match.address);
                                    if (token.dictionary >= dictionary_limit) return error.InvalidBlockPlan;
                                    encoded = dictionary_marker | token.dictionary;
                                }
                                costs[side][position] = @intCast(cost);
                                steps[side][position] = encoded.?;
                            }
                        }
                    }
                }
            }
        }
    }

    // Index ownership ends before the two final token arrays are materialized.
    Api.deinitIndex(&index, allocator);
    index_live = false;
    var plans: [2]Api.Plan = undefined;
    var completed: usize = 0;
    errdefer for (plans[0..completed]) |plan| allocator.free(plan.tokens);
    for (0..2) |side| {
        plans[side] = try reconstruct(Api, allocator, input, steps[side]);
        completed += 1;
    }
    return plans;
}

fn extendChoices(costs: []const u32, length_prices: *const [max_match_len + 1]u16, position: usize, minimum: usize, built_through: usize, maximum: usize, choices: *[max_match_len + 1]u64) void {
    if (maximum <= built_through) return;
    var best = if (built_through >= minimum) choices[built_through] else std.math.maxInt(u64);
    var length = @max(minimum, built_through + 1);
    while (length <= maximum) : (length += 1) {
        const cost = @as(u64, length_prices[length]) + costs[position + length];
        const choice = (cost << choice_bits) | (max_match_len - length);
        // Longer lengths win a cost tie; candidate-distance updates stay strict.
        best = @min(best, choice);
        choices[length] = best;
    }
}

fn reconstruct(comptime Api: type, allocator: std.mem.Allocator, input: []const u8, steps: []const u32) !Api.Plan {
    var tokens = try std.ArrayList(Api.Token).initCapacity(allocator, @min(input.len, 4096));
    errdefer tokens.deinit(allocator);
    var stats: @FieldType(Api.Plan, "stats") = .{};
    var position: usize = 0;
    while (position < input.len) {
        const step = steps[position];
        const token: Api.Token = if (step == 0)
            .{ .literal = input[position] }
        else if (step & dictionary_marker != 0) blk: {
            const dictionary = step & ~dictionary_marker;
            break :blk .{ .match = .{ .length = @intCast(dictionary & 0x3f), .distance = 0, .dictionary = dictionary } };
        } else .{ .match = .{ .length = @intCast((step & 0xff) + 3), .distance = @intCast(step >> 8) } };
        try Api.appendToken(&tokens, allocator, token);
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
    return .{ .tokens = try tokens.toOwnedSlice(allocator), .stats = stats };
}
