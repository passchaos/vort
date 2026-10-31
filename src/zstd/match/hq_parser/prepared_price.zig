//! Reuse LL/OF terms only after an admitted sequence price succeeds.
const std = @import("std");
const prices = @import("prices.zig");
const known = @import("sampled_price.zig");

pub const ForChoice = struct {
    // The caller holds the node, choice and entropy model fixed for the
    // complete enumeration. Reset this owner before changing any of them.
    literal_len: usize,
    offset_value: u32,
    base: ?u32 = null,

    pub inline fn price(self: *ForChoice, comptime known_match: bool, model: *const prices.EntropyModel, length: usize, match_code: u8) prices.Error!u32 {
        // Legal symbol prices and extras bound the full sum at 71,424.
        // The first successful price contains this exact nonnegative ML term.
        if (self.base) |base| return base + try matchPrice(known_match, model, length, match_code);
        // Preserve first-edge LL -> ML -> OF validation and arithmetic. The
        // caller admits and profiles every edge before entering this helper.
        const original = if (known_match)
            try known.sequencePrice(model, self.literal_len, length, self.offset_value, match_code)
        else
            try model.sequencePrice(self.literal_len, length, self.offset_value);
        self.base = original - try matchPrice(known_match, model, length, match_code);
        return original;
    }
};

inline fn matchPrice(comptime known_match: bool, model: *const prices.EntropyModel, length: usize, match_code: u8) prices.Error!u32 {
    const symbol = if (known_match) blk: {
        std.debug.assert(match_code < prices.ml_bases.len);
        const base = prices.ml_bases[match_code];
        const bits = prices.ml_bits[match_code];
        std.debug.assert(length >= base and length - base < (@as(usize, 1) << @intCast(bits)));
        break :blk prices.Symbol{ .code = match_code, .extra_bits = bits, .extra_value = @intCast(length - base) };
    } else try prices.matchSymbol(length);
    return model.ml_prices[symbol.code] + @as(u32, symbol.extra_bits) * prices.scale;
}

test {
    _ = @import("prepared_price_tests.zig");
}
