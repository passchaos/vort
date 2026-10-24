const std = @import("std");
const types = @import("../hq_types.zig");
const distance = @import("../distance.zig");
const command_lut = @import("../../command_lut.zig");
const length = @import("../../length.zig");
const literal_context = @import("../literal_context.zig");
pub const scale: u32 = 256;
pub const command_alphabet_size = 704;
pub const maximum_distance_alphabet_size = 520;
pub const maximum_symbol_price: u32 = 64 * scale;
pub const Error = error{ InvalidBlockPlan, IntegerOverflow };

const Pair = struct { symbols: [2]u16 = undefined, len: u2 = 0 };
pub const command_pairs = blk: {
    @setEvalBranchQuota(200000);
    var lookup: [24][24]Pair = @splat(@splat(.{}));
    for (command_lut.entries, 0..) |entry, symbol| {
        const insert = length.codeForValue(entry.insert_base, true) orelse unreachable;
        const copy = length.codeForValue(entry.copy_base, false) orelse unreachable;
        std.debug.assert(entry.distance_code == 0 or entry.distance_code == -1);
        std.debug.assert(lookup[insert][copy].len < 2);
        lookup[insert][copy].symbols[lookup[insert][copy].len] = @intCast(symbol);
        lookup[insert][copy].len += 1;
    }
    break :blk lookup;
};

pub const EncodingCost = struct { encoding: types.ExactEncoding, copy_len: usize, cost: u64 };
pub const EncodingCosts = struct {
    items: [2]EncodingCost = undefined,
    len: usize = 0,
    pub fn slice(self: *const EncodingCosts) []const EncodingCost {
        return self.items[0..self.len];
    }
};

pub const Statistics = struct {
    literal_counts: [64][256]u32 = @splat(@splat(0)),
    command_counts: [command_alphabet_size]u32 = @splat(0),
    distance_counts: [maximum_distance_alphabet_size]u32 = @splat(0),
    distance_parameters: distance.Parameters = distance.Parameters.init(0, 0),
    literal_count: usize = 0,
    command_count: usize = 0,
    copy_count: usize = 0,
    copy_bytes: usize = 0,

    pub fn addLiteral(self: *Statistics, context: u6, byte: u8) Error!void {
        self.literal_counts[context][byte] = std.math.add(u32, self.literal_counts[context][byte], 1) catch return error.IntegerOverflow;
        self.literal_count = std.math.add(usize, self.literal_count, 1) catch return error.IntegerOverflow;
    }
    pub fn addCommand(self: *Statistics, encoding: types.ExactEncoding, has_copy: bool, output_len: usize) Error!void {
        if (encoding.command_symbol >= command_alphabet_size or !std.meta.eql(self.distance_parameters, encoding.distance_parameters)) return error.InvalidBlockPlan;
        self.command_counts[encoding.command_symbol] = std.math.add(u32, self.command_counts[encoding.command_symbol], 1) catch return error.IntegerOverflow;
        self.command_count = std.math.add(usize, self.command_count, 1) catch return error.IntegerOverflow;
        if (!has_copy) return;
        self.copy_count = std.math.add(usize, self.copy_count, 1) catch return error.IntegerOverflow;
        self.copy_bytes = std.math.add(usize, self.copy_bytes, output_len) catch return error.IntegerOverflow;
        if (command_lut.entries[encoding.command_symbol].distance_code == -1) {
            const encoded = encoding.distance_encoding orelse return error.InvalidBlockPlan;
            if (encoded.symbol >= self.distance_parameters.alphabetSize()) return error.InvalidBlockPlan;
            self.distance_counts[encoded.symbol] = std.math.add(u32, self.distance_counts[encoded.symbol], 1) catch return error.IntegerOverflow;
        }
    }
};

/// Fixed coding state is caller-owned. Tables hold Q8 costs for actual literal
/// contexts, complete command symbols and the active distance alphabet.
/// An optional position table can carry a bridge's clustered literal estimate;
/// its borrowed dynamic bytes are included in workingBytes, unlike fixed tables.
pub const Model = struct {
    literal_prices: [64][256]u32 = @splat(@splat(8 * scale)),
    command_prices: [command_alphabet_size]u32 = @splat(probabilityPrice(1, command_alphabet_size)),
    distance_prices: [maximum_distance_alphabet_size]u32 = @splat(probabilityPrice(1, 64)),
    literal_frequencies: [64][256]u32 = @splat(@splat(1)),
    command_frequencies: [command_alphabet_size]u32 = @splat(1),
    distance_frequencies: [maximum_distance_alphabet_size]u32 = @splat(1),
    distance_parameters: distance.Parameters = distance.Parameters.init(0, 0),
    literal_mode: u2 = literal_context.mode_lsb6,
    literal_position_prices: ?[]const u32 = null,

    pub fn init(parameters: distance.Parameters, mode: u2) Model {
        var result: Model = .{ .distance_parameters = parameters, .literal_mode = mode };
        result.distance_prices = @splat(maximum_symbol_price);
        result.distance_frequencies = @splat(0);
        const alphabet = parameters.alphabetSize();
        @memset(result.distance_prices[0..alphabet], probabilityPrice(1, alphabet));
        @memset(result.distance_frequencies[0..alphabet], 1);
        return result;
    }
    pub fn validate(self: *const Model, parameters: distance.Parameters, input_len: usize) Error!void {
        if (!std.meta.eql(self.distance_parameters, parameters)) return error.InvalidBlockPlan;
        for (self.literal_prices) |literal_table| for (literal_table) |price| if (price > maximum_symbol_price) return error.InvalidBlockPlan;
        for (self.command_prices) |price| if (price > maximum_symbol_price) return error.InvalidBlockPlan;
        for (self.distance_prices[0..parameters.alphabetSize()]) |price| if (price > maximum_symbol_price) return error.InvalidBlockPlan;
        if (self.literal_position_prices) |prices| {
            if (prices.len != input_len) return error.InvalidBlockPlan;
            for (prices) |price| if (price > maximum_symbol_price) return error.InvalidBlockPlan;
        }
    }
    pub fn workingBytes(self: *const Model) Error!usize {
        return std.math.mul(usize, if (self.literal_position_prices) |prices| prices.len else 0, @sizeOf(u32)) catch error.IntegerOverflow;
    }
    pub fn context(self: *const Model, source: types.Source, position: usize, previous: [2]u8) u6 {
        const decoded = previousAt(source, position, previous);
        return @intCast(literal_context.value(self.literal_mode, decoded[0], decoded[1]));
    }
    pub fn literalPrice(self: *const Model, source: types.Source, position: usize, previous: [2]u8) u32 {
        if (self.literal_position_prices) |prices| return prices[position];
        return self.literal_prices[self.context(source, position, previous)][source.input[position]];
    }

    /// Price every legal complete command for the length pair. Code zero can
    /// use either an implicit command or an explicit distance-tree symbol zero.
    /// A null semantic code is a terminal insert-only command: no distance bits
    /// are read after its inserts exhaust the meta-block.
    pub fn commandCosts(self: *const Model, insert_len: usize, copy_len: usize, semantic_code: ?usize) Error!EncodingCosts {
        const insert_code = length.codeForValue(insert_len, true) orelse return error.InvalidBlockPlan;
        const copy_code = length.codeForValue(copy_len, false) orelse return error.InvalidBlockPlan;
        var result: EncodingCosts = .{};
        const pair = command_pairs[insert_code][copy_code];
        for (pair.symbols[0..pair.len]) |symbol| {
            const entry = command_lut.entries[symbol];
            if (semantic_code != null and entry.distance_code == 0 and semantic_code.? != 0) continue;
            var encoding: types.ExactEncoding = .{ .command_symbol = symbol, .distance_code = semantic_code orelse 0, .distance_parameters = self.distance_parameters };
            var cost: u64 = self.command_prices[symbol] + (@as(u32, entry.insert_extra_bits) + entry.copy_extra_bits) * scale;
            if (semantic_code) |code| {
                if (entry.distance_code == -1) {
                    const encoded = if (code < 16) distance.Encoding{ .symbol = @intCast(code) } else distance.encodeWithParameters(code - 15, self.distance_parameters) orelse continue;
                    if (encoded.symbol >= self.distance_parameters.alphabetSize()) continue;
                    encoding.distance_encoding = encoded;
                    cost += self.distance_prices[encoded.symbol] + @as(u32, encoded.extra_bits) * scale;
                }
            }
            result.items[result.len] = .{ .encoding = encoding, .copy_len = copy_len, .cost = cost };
            result.len += 1;
        }
        return result;
    }
    pub fn terminal(self: *const Model, insert_len: usize) Error!EncodingCost {
        var best: ?EncodingCost = null;
        for (0..24) |code| {
            const candidates = try self.commandCosts(insert_len, length.copySpec(@intCast(code)).base, null);
            for (candidates.slice()) |candidate|
                if (best == null or candidate.cost < best.?.cost or (candidate.cost == best.?.cost and candidate.encoding.command_symbol < best.?.encoding.command_symbol)) {
                    best = candidate;
                };
        }
        return best orelse error.InvalidBlockPlan;
    }
    pub fn refined(self: *const Model, statistics: *const Statistics) Error!Model {
        if (!std.meta.eql(self.distance_parameters, statistics.distance_parameters)) return error.InvalidBlockPlan;
        var result = self.*;
        for (&result.literal_prices, &result.literal_frequencies, &statistics.literal_counts) |*prices, *frequencies, *samples|
            refine(prices, frequencies, samples);
        refine(&result.command_prices, &result.command_frequencies, &statistics.command_counts);
        const alphabet = self.distance_parameters.alphabetSize();
        refine(result.distance_prices[0..alphabet], result.distance_frequencies[0..alphabet], statistics.distance_counts[0..alphabet]);
        result.literal_position_prices = null;
        return result;
    }
    pub fn withLiteralPrior(self: *const Model, source: types.Source, previous: [2]u8) Error!Model {
        var statistics: Statistics = .{ .distance_parameters = self.distance_parameters };
        for (source.input, 0..) |byte, position| try statistics.addLiteral(self.context(source, position, previous), byte);
        return self.refined(&statistics);
    }
};

pub fn previousAt(source: types.Source, position: usize, initial: [2]u8) [2]u8 {
    const newest = if (position != 0) source.input[position - 1] else if (source.history.len != 0) source.history[source.history.len - 1] else initial[0];
    const second = if (position >= 2) source.input[position - 2] else if (position == 1) if (source.history.len != 0) source.history[source.history.len - 1] else initial[0] else if (source.history.len >= 2) source.history[source.history.len - 2] else initial[1];
    return .{ newest, second };
}
fn refine(prices: anytype, frequencies: anytype, samples: anytype) void {
    var total: u64 = 0;
    for (frequencies, samples) |*frequency, sample| {
        frequency.* = @max(1, frequency.* / 4) +| sample;
        total += frequency.*;
    }
    for (prices, frequencies) |*price, frequency| price.* = probabilityPrice(frequency, total);
}
pub fn probabilityPrice(frequency: u32, total: u64) u32 {
    if (frequency == 0) return maximum_symbol_price;
    return @min(maximum_symbol_price, log2Q8(@max(total, frequency)) - log2Q8(frequency));
}
fn log2Q8(value: u64) u32 {
    @setEvalBranchQuota(30000);
    std.debug.assert(value != 0);
    const exponent: u6 = @intCast(63 - @clz(value));
    var word: u64 = if (exponent <= 31) value << @intCast(31 - @as(u32, exponent)) else value >> @intCast(@as(u32, exponent) - 31);
    var result: u32 = @as(u32, exponent) * scale;
    for (0..8) |bit| {
        word = @intCast((@as(u128, word) * word) >> 31);
        if (word >= (@as(u64, 2) << 31)) {
            word >>= 1;
            result += @as(u32, 1) << @intCast(7 - bit);
        }
    }
    return result;
}
