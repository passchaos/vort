const std = @import("std");

pub const cost_fraction_bits: u4 = 8;
pub const cost_scale: u16 = 1 << cost_fraction_bits;
pub const unseen_symbol_penalty_q8: u16 = 2 * cost_scale;

pub fn Histogram(comptime alphabet_size: usize) type {
    if (alphabet_size == 0) @compileError("a histogram must have at least one symbol");

    return struct {
        const Self = @This();

        pub const Error = error{
            SymbolOutOfRange,
            CountOverflow,
            TotalOverflow,
        };

        pub const CostModel = struct {
            /// Negative log2 probabilities in Q8. An unseen symbol costs two
            /// bits more than the logarithm of the population, matching the
            /// penalty used by Brotli's adaptive block splitter.
            symbol_costs_q8: [alphabet_size]u16,
            population: u64,
            /// Sum of count[symbol] * symbol_costs_q8[symbol].
            entropy_cost_q8: u64,
            /// Entropy proxy used for splitter comparisons. A non-empty
            /// population is charged at least one bit per symbol.
            population_cost_q8: u64,
        };

        counts: [alphabet_size]u32 = @splat(0),
        total: u64 = 0,

        pub fn init() Self {
            return .{};
        }

        pub fn clear(self: *Self) void {
            self.counts = @splat(0);
            self.total = 0;
        }

        pub fn add(self: *Self, symbol: usize) Error!void {
            return self.addCount(symbol, 1);
        }

        pub fn addCount(self: *Self, symbol: usize, count: u32) Error!void {
            if (symbol >= alphabet_size) return error.SymbolOutOfRange;
            if (count == 0) return;

            const new_count = std.math.add(u32, self.counts[symbol], count) catch
                return error.CountOverflow;
            const new_total = std.math.add(u64, self.total, count) catch
                return error.TotalOverflow;
            self.counts[symbol] = new_count;
            self.total = new_total;
        }

        /// Merge another histogram transactionally: if any counter or the
        /// total would overflow, `self` is left unchanged.
        pub fn addHistogram(self: *Self, other: *const Self) Error!void {
            const new_total = std.math.add(u64, self.total, other.total) catch
                return error.TotalOverflow;
            for (self.counts, other.counts) |left, right| {
                _ = std.math.add(u32, left, right) catch
                    return error.CountOverflow;
            }
            for (&self.counts, other.counts) |*left, right| left.* += right;
            self.total = new_total;
        }

        /// Build a histogram from any slice or array of integer symbols.
        pub fn fromSymbols(symbols: anytype) Error!Self {
            var result: Self = .{};
            for (symbols) |symbol| {
                const index = std.math.cast(usize, symbol) orelse
                    return error.SymbolOutOfRange;
                try result.add(index);
            }
            return result;
        }

        pub fn symbolCostsQ8(self: *const Self) [alphabet_size]u16 {
            return self.costModel().symbol_costs_q8;
        }

        pub fn entropyCostQ8(self: *const Self) u64 {
            return self.costModel().entropy_cost_q8;
        }

        pub fn populationCostQ8(self: *const Self) u64 {
            return self.costModel().population_cost_q8;
        }

        pub fn costModel(self: *const Self) CostModel {
            const total_log_q8 = log2Q8(self.total);
            const missing_cost_q8: u16 = @intCast(
                @as(u32, total_log_q8) + unseen_symbol_penalty_q8,
            );
            var result: CostModel = .{
                .symbol_costs_q8 = undefined,
                .population = self.total,
                .entropy_cost_q8 = 0,
                .population_cost_q8 = 0,
            };
            for (&result.symbol_costs_q8, self.counts) |*cost, count| {
                cost.* = if (count == 0)
                    missing_cost_q8
                else
                    total_log_q8 - log2Q8(count);
                if (count != 0) {
                    result.entropy_cost_q8 = saturatingAdd(
                        result.entropy_cost_q8,
                        @as(u64, count) * cost.*,
                    );
                }
            }

            const one_bit_per_symbol = saturatingMul(self.total, cost_scale);
            result.population_cost_q8 = @max(
                result.entropy_cost_q8,
                one_bit_per_symbol,
            );
            return result;
        }
    };
}

/// Rounded base-2 logarithm in Q8. This extracts nine fractional bits with
/// fixed-point squaring, then rounds to eight; no target-dependent floating
/// point evaluation is involved.
fn log2Q8(value: u64) u16 {
    if (value <= 1) return 0;

    const exponent: u6 = @intCast(std.math.log2_int(u64, value));
    var normalized: u128 = @as(u128, value) << @intCast(63 - exponent);
    var fraction_q9: u16 = 0;
    for (0..9) |_| {
        normalized = (normalized * normalized) >> 63;
        fraction_q9 <<= 1;
        if (normalized >= (@as(u128, 1) << 64)) {
            normalized >>= 1;
            fraction_q9 |= 1;
        }
    }
    const value_q9 = @as(u32, exponent) * 512 + fraction_q9;
    return @intCast((value_q9 + 1) >> 1);
}

fn saturatingAdd(a: u64, b: u64) u64 {
    return std.math.add(u64, a, b) catch std.math.maxInt(u64);
}

fn saturatingMul(a: u64, b: u64) u64 {
    return std.math.mul(u64, a, b) catch std.math.maxInt(u64);
}

test "histogram integer costs match scalar power-of-two reference" {
    const H = Histogram(4);
    var histogram: H = .{};
    try histogram.addCount(0, 4);
    try histogram.addCount(1, 2);
    try histogram.add(2);
    try histogram.add(3);

    const model = histogram.costModel();
    try std.testing.expectEqual(@as(u64, 8), model.population);
    try std.testing.expectEqual([_]u16{ 256, 512, 768, 768 }, model.symbol_costs_q8);
    try std.testing.expectEqual(@as(u64, 3584), model.entropy_cost_q8);
    try std.testing.expectEqual(@as(u64, 3584), model.population_cost_q8);
}

test "histogram builds clears and merges transactionally" {
    const H = Histogram(5);
    var left = try H.fromSymbols(&[_]u16{ 0, 1, 1, 4 });
    const right = try H.fromSymbols(&[_]u8{ 1, 2, 2 });
    try left.addHistogram(&right);
    try std.testing.expectEqual([_]u32{ 1, 3, 2, 0, 1 }, left.counts);
    try std.testing.expectEqual(@as(u64, 7), left.total);

    var overflowing: H = .{};
    overflowing.counts[1] = std.math.maxInt(u32);
    overflowing.total = std.math.maxInt(u32);
    const before = overflowing;
    try std.testing.expectError(error.CountOverflow, overflowing.addHistogram(&right));
    try std.testing.expectEqualDeep(before, overflowing);

    left.clear();
    try std.testing.expectEqual(@as(u64, 0), left.total);
    try std.testing.expectEqual([_]u32{0} ** 5, left.counts);
}

test "identical scaled distributions have identical active symbol costs" {
    const H = Histogram(4);
    var small: H = .{};
    try small.addCount(0, 2);
    try small.add(1);
    try small.add(2);

    var large: H = .{};
    try large.addCount(0, 8);
    try large.addCount(1, 4);
    try large.addCount(2, 4);

    const small_model = small.costModel();
    const large_model = large.costModel();
    try std.testing.expectEqualSlices(
        u16,
        small_model.symbol_costs_q8[0..3],
        large_model.symbol_costs_q8[0..3],
    );
    try std.testing.expectEqual(
        small_model.entropy_cost_q8 * 4,
        large_model.entropy_cost_q8,
    );
    try std.testing.expect(
        small_model.symbol_costs_q8[3] < large_model.symbol_costs_q8[3],
    );
}

test "skewed distribution favors the frequent symbol" {
    const H = Histogram(3);
    var histogram: H = .{};
    try histogram.addCount(0, 15);
    try histogram.add(1);

    const model = histogram.costModel();
    try std.testing.expect(model.symbol_costs_q8[0] < model.symbol_costs_q8[1]);
    try std.testing.expectEqual(@as(u16, 1024), model.symbol_costs_q8[1]);
    try std.testing.expectEqual(@as(u16, 1536), model.symbol_costs_q8[2]);
    try std.testing.expect(model.entropy_cost_q8 < model.population_cost_q8);
    try std.testing.expectEqual(@as(u64, 16 * cost_scale), model.population_cost_q8);
}

test "empty single-symbol and overflow boundaries are explicit" {
    const H = Histogram(2);
    const empty: H = .{};
    const empty_model = empty.costModel();
    try std.testing.expectEqual([_]u16{ 512, 512 }, empty_model.symbol_costs_q8);
    try std.testing.expectEqual(@as(u64, 0), empty_model.entropy_cost_q8);
    try std.testing.expectEqual(@as(u64, 0), empty_model.population_cost_q8);

    var single: H = .{};
    try single.addCount(1, 32);
    const single_model = single.costModel();
    try std.testing.expectEqual([_]u16{ 1792, 0 }, single_model.symbol_costs_q8);
    try std.testing.expectEqual(@as(u64, 0), single_model.entropy_cost_q8);
    try std.testing.expectEqual(@as(u64, 32 * cost_scale), single_model.population_cost_q8);

    try std.testing.expectError(error.SymbolOutOfRange, single.add(2));
    try std.testing.expectError(error.SymbolOutOfRange, H.fromSymbols(&[_]i16{-1}));

    var count_limit: H = .{};
    count_limit.counts[0] = std.math.maxInt(u32);
    count_limit.total = std.math.maxInt(u32);
    try std.testing.expectError(error.CountOverflow, count_limit.add(0));
    try std.testing.expectEqual(std.math.maxInt(u32), count_limit.counts[0]);
    try std.testing.expectEqual(@as(u64, std.math.maxInt(u32)), count_limit.total);

    var total_limit: H = .{};
    total_limit.total = std.math.maxInt(u64);
    try std.testing.expectError(error.TotalOverflow, total_limit.add(0));
    try std.testing.expectEqual(@as(u32, 0), total_limit.counts[0]);
    try std.testing.expectEqual(std.math.maxInt(u64), total_limit.total);
}

test "command alphabet histograms remain compact" {
    const command_model_bytes = @sizeOf(Histogram(704));
    try std.testing.expect(command_model_bytes <= 3 * 1024);
    try std.testing.expect(command_model_bytes * 50 <= 150 * 1024);
}
