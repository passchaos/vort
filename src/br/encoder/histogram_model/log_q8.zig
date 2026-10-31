//! Exact rounded Q8 logarithms for frequently repeated histogram counts.
const std = @import("std");
const cache_limit: usize = 1024;
const cache: [cache_limit + 1]u16 = blk: {
    @setEvalBranchQuota(5000000);
    var result: [cache_limit + 1]u16 = undefined;
    for (&result, 0..) |*value, index| value.* = squaring(index);
    break :blk result;
};

pub fn log2Q8(value: u64) u16 {
    if (value <= cache_limit) return cache[@intCast(value)];
    return squaring(value);
}

fn squaring(value: u64) u16 {
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

test {
    _ = @import("log_q8_tests.zig");
    _ = @import("model_tests.zig");
}
