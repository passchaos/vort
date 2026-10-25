//! Exact fixed-alphabet inspection with numerical widening before reduction.
//! The two input arrays need only their normal u32 alignment and must contain
//! all 256 initialized values. No state or input pointer is retained.
const std = @import("std");

pub const Error = error{ InvalidFrequencyTotal, IntegerOverflow };
pub const Inspection = struct {
    total: u32,
    active: usize,
    same_support: bool,
    negative_delta: u32,
};

const lane_count = 8;
const Frequencies = @Vector(lane_count, u32);
const Wide = @Vector(lane_count, u64);

/// Each wide lane adds 32 u32 values, and the final total is at most
/// 256*(2^32-1) < 2^40. Negative mass has the same unconditional upper bound.
/// This remains exact even for malformed arrays outside the caller's cap.
pub fn inspect256(current: *const [256]u32, previous: *const [256]u32, max_total: u32) Error!Inspection {
    var totals: Wide = @splat(0);
    var negatives: Wide = @splat(0);
    var mismatch_mask: u8 = 0;
    var active: usize = 0;
    var offset: usize = 0;
    while (offset < 256) : (offset += lane_count) {
        const now: Frequencies = current[offset..][0..lane_count].*;
        const prior: Frequencies = previous[offset..][0..lane_count].*;
        const widened: Wide = now;
        totals += widened;

        // min(prior, now) cannot exceed prior. Unlike select(prior>now,
        // prior-now, 0), this never evaluates an underflowing subtraction.
        const delta: Frequencies = prior - @min(prior, now);
        const widened_delta: Wide = delta;
        negatives += widened_delta;

        const now_support = now != @as(Frequencies, @splat(0));
        const prior_support = prior != @as(Frequencies, @splat(0));
        mismatch_mask |= @as(u8, @bitCast(now_support != prior_support));
        active += @popCount(@as(u8, @bitCast(now_support)));
    }

    const total = @reduce(.Add, totals);
    // Nonnegative inputs exceed the cap in a scalar prefix iff the complete
    // sum exceeds it. Preserve that error ahead of negative-mass conversion.
    if (total > max_total) return error.InvalidFrequencyTotal;
    const negative = @reduce(.Add, negatives);
    return .{
        .total = @intCast(total),
        .active = active,
        .same_support = mismatch_mask == 0,
        .negative_delta = std.math.cast(u32, negative) orelse return error.IntegerOverflow,
    };
}
