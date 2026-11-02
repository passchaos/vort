//! A successful first edge closes one immutable literal run and prepares its
//! LL/OF terms. Later edges retain admission, ML validation and checked cost.
const std = @import("std");
const state = @import("state.zig");
const rep = @import("rep.zig");
const prices = @import("prices.zig");
const PriceBudget = @import("price_budget.zig").PriceBudget;

pub const Prepared = struct {
    closed_cost: u64,
    sequence_base: u32,
    literal_zero: u32,
};
pub const First = struct { node: state.Node, prepared: Prepared };

/// Models, node and choice remain immutable for the complete interval.
/// Publication follows the original full price and node construction.
pub noinline fn first(parameters: state.Parameters, budget: *PriceBudget, node: state.Node, position: usize, length: usize, choice: rep.Choice) !First {
    try admit(parameters, budget, length);
    const sequence = try parameters.entropy.sequencePrice(node.literal_len, length, choice.offset_value);
    const old_ll = try literalLengthPrice(parameters.entropy, node.literal_len);
    const closed = std.math.sub(u64, node.cost, old_ll) catch return error.IntegerOverflow;
    const with_sequence = std.math.add(u64, closed, sequence) catch return error.IntegerOverflow;
    const zero = try literalLengthPrice(parameters.entropy, 0);
    const cost = std.math.add(u64, with_sequence, zero) catch return error.IntegerOverflow;
    const next = makeNode(node, position, length, choice, cost);
    const ml = try matchPrice(parameters.entropy, length);
    const prepared: Prepared = .{ .closed_cost = closed, .sequence_base = sequence - ml, .literal_zero = zero };
    if (parameters.profile) |profile| profile.add("frontier_choice_preparations", 1);
    return .{ .node = next, .prepared = prepared };
}

pub noinline fn replay(parameters: state.Parameters, budget: *PriceBudget, node: state.Node, position: usize, length: usize, choice: rep.Choice, prepared: Prepared) !state.Node {
    try admit(parameters, budget, length);
    if (parameters.profile) |profile| profile.add("frontier_choice_replays", 1);
    // A validated entropy model bounds the full u32 sequence price. Preserve
    // each edge's ML symbol checks and both original cumulative u64 additions.
    const sequence = std.math.add(u32, prepared.sequence_base, try matchPrice(parameters.entropy, length)) catch return error.IntegerOverflow;
    const with_sequence = std.math.add(u64, prepared.closed_cost, sequence) catch return error.IntegerOverflow;
    const cost = std.math.add(u64, with_sequence, prepared.literal_zero) catch return error.IntegerOverflow;
    return makeNode(node, position, length, choice, cost);
}

inline fn admit(parameters: state.Parameters, budget: *PriceBudget, length: usize) !void {
    try budget.admit();
    if (parameters.profile) |profile| {
        profile.add("price_evaluations", 1);
        profile.add("optimal_transitions", 1);
        profile.recordMatchLengthConsidered(length);
    }
}

inline fn makeNode(_: state.Node, position: usize, length: usize, choice: rep.Choice, cost: u64) state.Node {
    return .{ .cost = cost, .repeats = choice.repeats, .match_len = @intCast(length), .distance = choice.distance, .offset_value = choice.offset_value, .previous_position = @intCast(position) };
}

inline fn matchPrice(model: *const prices.EntropyModel, length: usize) !u32 {
    const symbol = try prices.matchSymbol(length);
    return model.ml_prices[symbol.code] + @as(u32, symbol.extra_bits) * prices.scale;
}

fn literalLengthPrice(model: *const prices.EntropyModel, length: usize) !u32 {
    if (length > 128 * 1024) return error.InvalidBlockPlan;
    const symbol = try prices.literalSymbol(@min(length, 131071));
    return model.ll_prices[symbol.code] + @as(u32, symbol.extra_bits) * prices.scale;
}

test "Zstd HQ frontier choice price preserves independent errors and costs" {
    try @import("frontier_price_tests.zig").check(@This());
}
