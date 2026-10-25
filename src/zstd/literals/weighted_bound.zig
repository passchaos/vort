//! Fixed certificates for lower bounds on length-limited Huffman bit cost.
//! This module checks frequency/scalar geometry. It does not prove that a
//! caller-provided scalar is an optimum or a valid lower bound on that optimum.
const std = @import("std");
const frequency_reduction = @import("frequency_reduction.zig");

pub const max_total_frequency: u32 = 128 * 1024;
pub const Error = error{
    InvalidSupport,
    InvalidFrequencyTotal,
    InvalidCertificateCost,
    IntegerOverflow,
};

pub const Analysis = struct {
    same_support: bool,
    current_total: u32,
    current_active_symbols: usize,
    negative_delta: u32,
    bit_lower_bound: ?u64,
};

/// A caller-owned frequency snapshot and trusted scalar for one fixed code
/// alphabet and bit limit. There is no allocation, retained input pointer, or
/// shared mutable state. Use an optional Certificate to represent no witness.
///
/// The caller must establish `trusted_lower_bits <= Opt(f)` for the same
/// length-limited prefix-code domain before init/publish. The checked envelope
/// `sum(f) <= trusted_lower_bits <= max_bits * sum(f)` is necessary numerical
/// geometry only: an in-range scalar can still exceed the true optimum.
pub fn Certificate(comptime n: usize, comptime max_bits: u8) type {
    comptime {
        if (n < 2) @compileError("weighted certificate needs an alphabet of at least two symbols");
        if (max_bits == 0) @compileError("weighted certificate needs at least one code bit");
    }
    return struct {
        frequencies: [n]u32,
        total_frequency: u32,
        active_symbols: usize,
        trusted_lower_bits: u64,

        const Self = @This();
        const Inspection = frequency_reduction.Inspection;

        pub fn init(frequencies: *const [n]u32, trusted_lower_bits: u64) Error!Self {
            const info = try inspect(false, frequencies, {});
            if (info.active < 2) return error.InvalidSupport;
            if (comptime max_bits < @bitSizeOf(usize)) {
                const support_limit = @as(usize, 1) << @intCast(max_bits);
                if (info.active > support_limit) return error.InvalidSupport;
            }
            const maximum_bits = std.math.mul(u64, max_bits, info.total) catch return error.IntegerOverflow;
            if (trusted_lower_bits < info.total or trusted_lower_bits > maximum_bits)
                return error.InvalidCertificateCost;
            return .{
                .frequencies = frequencies.*,
                .total_frequency = info.total,
                .active_symbols = info.active,
                .trusted_lower_bits = trusted_lower_bits,
            };
        }

        /// Validate and copy before replacing the witness. Any error leaves
        /// the previous complete frequency/scalar binding unchanged.
        pub fn publish(self: *Self, frequencies: *const [n]u32, trusted_lower_bits: u64) Error!void {
            const replacement = try init(frequencies, trusted_lower_bits);
            self.* = replacement;
        }

        /// Current frequencies may describe empty/RLE literals. Their total
        /// must remain bounded, but changed support yields no Huffman bound.
        /// Inspection still returns the total, active count, and negative mass.
        pub fn analyze(self: *const Self, frequencies: *const [n]u32) Error!Analysis {
            const info = try inspect(true, frequencies, &self.frequencies);
            return self.finishAnalysis(info);
        }

        /// Bounded diagnostics/reference entry. It retains the original
        /// generic checked inspection and the same final scalar arithmetic.
        pub fn analyzeReference(self: *const Self, frequencies: *const [n]u32) Error!Analysis {
            const info = try inspectScalar(true, frequencies, &self.frequencies);
            return self.finishAnalysis(info);
        }

        fn finishAnalysis(self: *const Self, info: Inspection) Error!Analysis {
            var result: Analysis = .{
                .same_support = info.same_support,
                .current_total = info.total,
                .current_active_symbols = info.active,
                .negative_delta = info.negative_delta,
                .bit_lower_bound = null,
            };
            if (!info.same_support) return result;

            // Any current feasible l is also feasible for the prior support:
            // f.l >= Cf. Positive deltas contribute at least delta*1; negative
            // deltas contribute at least delta*max_bits. Thus the bound is
            // Cf + (Rg-Rf) - (max_bits-1)*Dminus, also clamped to Rg.
            const prior = std.math.cast(i64, self.trusted_lower_bits) orelse return error.IntegerOverflow;
            const delta_total = @as(i64, info.total) - @as(i64, self.total_frequency);
            const penalty = std.math.mul(i64, @as(i64, max_bits) - 1, info.negative_delta) catch return error.IntegerOverflow;
            const changed = std.math.add(i64, prior, delta_total) catch return error.IntegerOverflow;
            const adjusted = std.math.sub(i64, changed, penalty) catch return error.IntegerOverflow;
            const lower = @max(@as(i64, info.total), adjusted);
            result.bit_lower_bound = std.math.cast(u64, lower) orelse return error.IntegerOverflow;
            return result;
        }

        pub fn bitLowerBound(self: *const Self, frequencies: *const [n]u32) Error!?u64 {
            return (try self.analyze(frequencies)).bit_lower_bound;
        }

        fn inspect(comptime compare: bool, frequencies: *const [n]u32, previous: anytype) Error!Inspection {
            if (comptime compare and n == 256)
                return frequency_reduction.inspect256(frequencies, previous, max_total_frequency);
            return inspectScalar(compare, frequencies, previous);
        }

        fn inspectScalar(comptime compare: bool, frequencies: *const [n]u32, previous: anytype) Error!Inspection {
            var total: u64 = 0;
            var active: usize = 0;
            var same_support = true;
            var negative: u64 = 0;
            for (frequencies, 0..) |frequency, symbol| {
                total = std.math.add(u64, total, frequency) catch return error.IntegerOverflow;
                if (total > max_total_frequency) return error.InvalidFrequencyTotal;
                active += @intFromBool(frequency != 0);
                if (compare) {
                    const prior = previous[symbol];
                    same_support = same_support and ((prior != 0) == (frequency != 0));
                    if (prior > frequency)
                        negative = std.math.add(u64, negative, prior - frequency) catch return error.IntegerOverflow;
                }
            }
            return .{
                .total = @intCast(total),
                .active = active,
                .same_support = same_support,
                .negative_delta = std.math.cast(u32, negative) orelse return error.IntegerOverflow,
            };
        }
    };
}

test "zstd weighted reduction complete scalar oracle contracts" {
    try @import("weighted_reduction_tests.zig").contracts(@This());
}
