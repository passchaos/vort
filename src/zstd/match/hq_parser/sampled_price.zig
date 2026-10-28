//! Prices for already-enumerated valid ML range endpoints.
//! The caller has admitted the edge and supplies the current fixed-table code;
//! this removes classification without changing price or validation order.
const std = @import("std");
const prices = @import("prices.zig");
pub inline fn sequencePrice(model: *const prices.EntropyModel, literal_len: usize, match_len: usize, offset_value: u32, match_code: u8) prices.Error!u32 {
    const ll = try prices.literalSymbol(literal_len);
    std.debug.assert(match_code < prices.ml_bases.len);
    const base = prices.ml_bases[match_code];
    const bits = prices.ml_bits[match_code];
    std.debug.assert(match_len >= base and match_len - base < (@as(usize, 1) << @intCast(bits)));
    const of = try prices.offsetSymbol(offset_value);
    const penalty = if (model.penalize_long_offsets and of.code >= 20) (@as(u32, of.code) - 19) * 2 * prices.scale else 0;
    return model.ll_prices[ll.code] + model.ml_prices[match_code] + model.of_prices[of.code] +
        (@as(u32, ll.extra_bits) + bits + of.extra_bits) * prices.scale + penalty;
}
