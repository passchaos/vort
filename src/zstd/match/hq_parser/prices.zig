const std = @import("std");
const controls = @import("../../encode/controls.zig");
pub const scale: u32 = 256;
pub const ll_symbol_count = 36;
pub const ml_symbol_count = 53;
pub const of_symbol_count = 32;
pub const maximum_symbol_price: u32 = 64 * scale;
pub const Error = error{InvalidBlockPlan};

pub const ll_bases = [_]u32{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 18, 20, 22, 24, 28, 32, 40, 48, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384, 32768, 65536 };
pub const ll_bits = [_]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 3, 3, 4, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 };
pub const ml_bases = [_]u32{ 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 37, 39, 41, 43, 47, 51, 59, 67, 83, 99, 131, 259, 515, 1027, 2051, 4099, 8195, 16387, 32771, 65539 };
pub const ml_bits = [_]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 3, 3, 4, 4, 5, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 };
const ll_predefined = [_]u32{ 4, 3, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 3, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1 };
const ml_predefined = [_]u32{ 1, 4, 3, 2, 2, 2, 2, 2, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 };
const of_predefined = [_]u32{ 1, 1, 1, 1, 1, 1, 2, 2, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0 };

pub const Symbol = struct { code: u8, extra_bits: u8, extra_value: u32 };
pub fn literalSymbol(length: usize) Error!Symbol {
    const code: usize = if (length < 16) length else if (length < 24) 16 + (length - 16) / 2 else if (length < 32) 20 + (length - 24) / 4 else if (length < 48) 22 + (length - 32) / 8 else if (length < 64) 24 else @as(usize, 19) + std.math.log2_int(usize, length);
    return symbolAt(length, code, &ll_bases, &ll_bits);
}
pub fn matchSymbol(length: usize) Error!Symbol {
    if (length < 3) return error.InvalidBlockPlan;
    const code: usize = if (length <= 34) length - 3 else if (length < 43) 32 + (length - 35) / 2 else if (length < 51) 36 + (length - 43) / 4 else if (length < 67) 38 + (length - 51) / 8 else if (length < 99) 40 + (length - 67) / 16 else if (length < 131) 42 else @as(usize, 36) + std.math.log2_int(usize, length - 3);
    return symbolAt(length, code, &ml_bases, &ml_bits);
}
fn symbolAt(length: usize, code: usize, bases: []const u32, bits: []const u8) Error!Symbol {
    if (code >= bases.len or length < bases[code] or length - bases[code] >= (@as(usize, 1) << @intCast(bits[code]))) return error.InvalidBlockPlan;
    return .{ .code = @intCast(code), .extra_bits = bits[code], .extra_value = @intCast(length - bases[code]) };
}
pub fn offsetSymbol(offset_value: u32) Error!Symbol {
    if (offset_value == 0) return error.InvalidBlockPlan;
    const code: u8 = @intCast(std.math.log2_int(u32, offset_value));
    return .{ .code = code, .extra_bits = code, .extra_value = offset_value - (@as(u32, 1) << @intCast(code)) };
}

pub const Statistics = struct {
    literals: [256]u32 = @splat(0),
    literal_lengths: [ll_symbol_count]u32 = @splat(0),
    match_lengths: [ml_symbol_count]u32 = @splat(0),
    offsets: [of_symbol_count]u32 = @splat(0),
    literal_count: u32 = 0,
    sequence_count: u32 = 0,

    pub fn addLiterals(self: *Statistics, bytes: []const u8) void {
        for (bytes) |byte| self.literals[byte] +|= 1;
        self.literal_count +|= @intCast(bytes.len);
    }
    pub fn addSequence(self: *Statistics, literal_len: usize, match_len: usize, offset_value: u32) Error!void {
        self.literal_lengths[(try literalSymbol(literal_len)).code] +|= 1;
        self.match_lengths[(try matchSymbol(match_len)).code] +|= 1;
        self.offsets[(try offsetSymbol(offset_value)).code] +|= 1;
        self.sequence_count +|= 1;
    }
};

/// Caller-owned immutable Q8 entropy costs. The bridge supplies exact Huffman
/// bit lengths and FSE normalized frequencies from a dictionary or selected
/// previous block; raw literals and predefined sequence tables are the defaults.
pub const EntropyModel = struct {
    initialized: bool = false,
    penalize_long_offsets: bool = false,
    literal_prices: [256]u32 = @splat(8 * scale),
    ll_prices: [ll_symbol_count]u32 = predefinedPrices(ll_symbol_count, ll_predefined, 64),
    ml_prices: [ml_symbol_count]u32 = predefinedPrices(ml_symbol_count, ml_predefined, 64),
    of_prices: [of_symbol_count]u32 = predefinedPrices(of_symbol_count, of_predefined, 32),
    literal_frequencies: [256]u32 = @splat(1),
    ll_frequencies: [ll_symbol_count]u32 = ll_predefined,
    ml_frequencies: [ml_symbol_count]u32 = ml_predefined,
    of_frequencies: [of_symbol_count]u32 = of_predefined,
    origin: enum { predefined, dictionary, previous_block, refined } = .predefined,

    pub fn validate(self: *const EntropyModel) Error!void {
        inline for (.{ "literal_prices", "ll_prices", "ml_prices", "of_prices" }) |field|
            for (@field(self, field)) |price| if (price > maximum_symbol_price) return error.InvalidBlockPlan;
    }
    /// Native opt0 approximation: round each supplied Q8 symbol cost upward
    /// to whole bits. Huffman bit lengths already remain exact integers.
    /// Ultra modes retain Q8 precision. Keep the offset penalty separate from
    /// table prices so a valid 64-bit unknown-symbol cost remains valid input.
    pub fn forStrategy(self: *const EntropyModel, strategy: controls.Strategy) Error!EntropyModel {
        try self.validate();
        var result = self.*;
        result.penalize_long_offsets = strategy == .btopt;
        if (strategy == .btopt) {
            inline for (.{ "literal_prices", "ll_prices", "ml_prices", "of_prices" }) |field| {
                for (&@field(result, field)) |*price| {
                    price.* = ((price.* + scale - 1) / scale) * scale;
                }
            }
        }
        return result;
    }
    pub fn sequencePrice(self: *const EntropyModel, literal_len: usize, match_len: usize, offset_value: u32) Error!u32 {
        const ll = try literalSymbol(literal_len);
        const ml = try matchSymbol(match_len);
        const of = try offsetSymbol(offset_value);
        const offset_penalty = if (self.penalize_long_offsets and of.code >= 20) (@as(u32, of.code) - 19) * 2 * scale else 0;
        return self.ll_prices[ll.code] + self.ml_prices[ml.code] + self.of_prices[of.code] +
            (@as(u32, ll.extra_bits) + ml.extra_bits + of.extra_bits) * scale + offset_penalty;
    }
    /// First-pass selected sequences and actual literal bytes update all four
    /// distributions. A small smoothed prior keeps unseen second-pass choices
    /// finite; this changes prices, rather than merely increasing search depth.
    pub fn refined(self: *const EntropyModel, statistics: *const Statistics) EntropyModel {
        var result = self.*;
        refineTable(&result.literal_prices, &result.literal_frequencies, &statistics.literals);
        refineTable(&result.ll_prices, &result.ll_frequencies, &statistics.literal_lengths);
        refineTable(&result.ml_prices, &result.ml_frequencies, &statistics.match_lengths);
        refineTable(&result.of_prices, &result.of_frequencies, &statistics.offsets);
        result.origin = .refined;
        result.initialized = true;
        return result;
    }
};

fn refineTable(output: anytype, frequencies: anytype, samples: anytype) void {
    var total: u64 = 0;
    for (frequencies, samples) |*frequency, sample| {
        frequency.* = @max(1, frequency.* / 4) +| sample;
        total += frequency.*;
    }
    for (output, frequencies) |*price, frequency| price.* = probabilityPrice(frequency, total);
}
fn predefinedPrices(comptime n: usize, frequencies: [n]u32, total: u64) [n]u32 {
    @setEvalBranchQuota(30000);
    var result: [n]u32 = undefined;
    for (&result, frequencies) |*price, frequency| price.* = probabilityPrice(frequency, total);
    return result;
}
pub fn probabilityPrice(frequency: u32, total: u64) u32 {
    if (frequency == 0) return maximum_symbol_price;
    return @min(maximum_symbol_price, log2Q8(@max(total, frequency)) - log2Q8(frequency));
}
fn log2Q8(value: u64) u32 {
    std.debug.assert(value != 0);
    const exponent: u6 = @intCast(63 - @clz(value));
    var normalized: u64 = if (exponent <= 31) value << @intCast(31 - @as(u32, exponent)) else value >> @intCast(@as(u32, exponent) - 31);
    var result: u32 = @as(u32, exponent) * scale;
    for (0..8) |fractional_bit| {
        normalized = @intCast((@as(u128, normalized) * normalized) >> 31);
        if (normalized >= (@as(u64, 2) << 31)) {
            normalized >>= 1;
            result += @as(u32, 1) << @intCast(7 - fractional_bit);
        }
    }
    return result;
}
