//! A selected bounded-horizon record may continue under the same exact offBase.
const std = @import("std");
const source_mod = @import("../controlled_source.zig");
const state = @import("state.zig");
const prices = @import("prices.zig");
const PriceBudget = @import("price_budget.zig").PriceBudget;

pub fn choose(comptime complete: bool, source: source_mod.Source, record: state.Record, offset_value: u32, maximum: usize, parameters: state.Parameters, budget: *PriceBudget) !usize {
    if (maximum <= record.match_len) return record.match_len;
    const start = record.match_end - record.match_len;
    var literal_cost: u64 = 0;
    for (source.block[record.match_end .. start + maximum]) |byte|
        literal_cost = std.math.add(u64, literal_cost, parameters.entropy.literal_prices[byte]) catch return error.IntegerOverflow;
    const original = try sequencePrice(parameters, budget, record.literal_len, record.match_len, offset_value);
    var best_cost = std.math.add(u64, original, literal_cost) catch return error.IntegerOverflow;
    var best_length = record.match_len;
    var replaced_literal_cost: u64 = 0;
    if (complete) {
        for (record.match_len + 1..maximum + 1) |length| {
            replaced_literal_cost = std.math.add(u64, replaced_literal_cost, parameters.entropy.literal_prices[source.block[start + length - 1]]) catch return error.IntegerOverflow;
            const sequence_cost = try sequencePrice(parameters, budget, record.literal_len, length, offset_value);
            const cost = std.math.add(u64, sequence_cost, literal_cost - replaced_literal_cost) catch return error.IntegerOverflow;
            if (cost < best_cost) {
                best_cost = cost;
                best_length = length;
            }
        }
    } else {
        var priced_through = record.match_len;
        // Preserve the default ML-range endpoint sampling and its tie order.
        for (prices.ml_bases, prices.ml_bits) |base, bits| {
            if (base > maximum) break;
            const length = @min(maximum, @as(usize, base) + (@as(usize, 1) << @intCast(bits)) - 1);
            if (length <= priced_through) continue;
            for (source.block[start + priced_through .. start + length]) |byte|
                replaced_literal_cost = std.math.add(u64, replaced_literal_cost, parameters.entropy.literal_prices[byte]) catch return error.IntegerOverflow;
            priced_through = length;
            const sequence_cost = try sequencePrice(parameters, budget, record.literal_len, length, offset_value);
            const cost = std.math.add(u64, sequence_cost, literal_cost - replaced_literal_cost) catch return error.IntegerOverflow;
            if (cost < best_cost) {
                best_cost = cost;
                best_length = length;
            }
        }
    }
    return best_length;
}

fn sequencePrice(parameters: state.Parameters, budget: *PriceBudget, literals: usize, length: usize, offset: u32) !u32 {
    try budget.admit();
    if (parameters.profile) |profile| {
        profile.add("price_evaluations", 1);
        profile.recordMatchLengthConsidered(length);
    }
    return parameters.entropy.sequencePrice(literals, length, offset);
}
