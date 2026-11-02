const std = @import("std");
pub const Old = @import("../prices_known_ml_reference.zig");
const state = @import("../state.zig");
const rep = @import("../rep.zig");
const Budget = @import("../price_budget.zig").PriceBudget;
const Profile = @import("../../../encode/controls.zig").Profile;

pub const Parameters = struct { entropy: *const Old.EntropyModel, profile: ?*Profile = null };

/// Frozen original virtual trailing-LL expression; real sequencePrice still
/// receives the original LL, so 131072 is rejected for a priced sequence.
pub fn literalLengthPrice(model: *const Old.EntropyModel, length: usize) !u32 {
    if (length > 128 * 1024) return error.InvalidBlockPlan;
    const symbol = try Old.literalSymbol(@min(length, 131071));
    return model.ll_prices[symbol.code] + @as(u32, symbol.extra_bits) * Old.scale;
}

/// Frozen pre-memo pricedNode ordering. No call into frontier_price helpers.
pub fn pricedNode(parameters: Parameters, budget: *Budget, node: state.Node, position: usize, length: usize, choice: rep.Choice) !state.Node {
    try budget.admit();
    if (parameters.profile) |profile| {
        profile.add("price_evaluations", 1);
        profile.add("optimal_transitions", 1);
        profile.recordMatchLengthConsidered(length);
    }
    const sequence = try parameters.entropy.sequencePrice(node.literal_len, length, choice.offset_value);
    const old_ll = try literalLengthPrice(parameters.entropy, node.literal_len);
    const closed_cost = std.math.sub(u64, node.cost, old_ll) catch return error.IntegerOverflow;
    const sequence_cost = std.math.add(u64, closed_cost, sequence) catch return error.IntegerOverflow;
    return .{ .cost = std.math.add(u64, sequence_cost, try literalLengthPrice(parameters.entropy, 0)) catch return error.IntegerOverflow, .repeats = choice.repeats, .match_len = @intCast(length), .distance = choice.distance, .offset_value = choice.offset_value, .previous_position = @intCast(position) };
}
