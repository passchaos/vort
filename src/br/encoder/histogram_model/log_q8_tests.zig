const std = @import("std");
const log = @import("log_q8.zig");
pub fn reference(value: u64) u16 {
    if (value <= 1) return 0;
    var exponent: u6 = 0;
    var integer = value;
    while (integer > 1) : (exponent += 1) integer >>= 1;
    var normalized: u128 = @as(u128, value) << @intCast(63 - exponent);
    var fraction: u16 = 0;
    for (0..9) |bit| {
        normalized = (normalized * normalized) / (@as(u128, 1) << 63);
        if (normalized >= (@as(u128, 1) << 64)) {
            normalized /= 2;
            fraction |= @as(u16, 1) << @intCast(8 - bit);
        }
    }
    return @as(u16, exponent) * 256 + fraction / 2 + fraction % 2;
}

test "histogram exact log preserves exhaustive table boundary and independent Q9 rounding" {
    for (0..65537) |value| try std.testing.expectEqual(reference(@intCast(value)), log.log2Q8(@intCast(value)));
    for (1..64) |bit| {
        const power = @as(u64, 1) << @intCast(bit);
        for ([_]u64{ power - 1, power, power + 1 }) |value|
            try std.testing.expectEqual(reference(value), log.log2Q8(value));
    }
    for ([_]u64{ std.math.maxInt(u32), @as(u64, std.math.maxInt(u32)) + 1, std.math.maxInt(u64) - 1, std.math.maxInt(u64) }) |value|
        try std.testing.expectEqual(reference(value), log.log2Q8(value));
    var random: u64 = 0x98271634abe10839;
    for (0..4096) |_| {
        random = random *% 6364136223846793005 +% 1442695040888963407;
        try std.testing.expectEqual(reference(random), log.log2Q8(random));
    }
}
