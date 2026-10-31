const std = @import("std");
const count = @import("enumeration_count.zig");
const prices = @import("prices.zig");
const Strategy = @import("../../encode/controls.zig").Strategy;

fn original(strategy: Strategy, minimum: usize, maximum: usize) u64 {
    var result: u64 = 1;
    const exhaustive: usize = if (strategy == .btopt) 16 else 64;
    var length = minimum;
    while (length < @min(maximum, exhaustive + 1)) : (length += 1) result += 1;
    for (prices.ml_bases, prices.ml_bits) |base, bits| {
        const lower: usize = base;
        if (lower >= maximum) break;
        const upper = lower + (@as(usize, 1) << @intCast(bits)) - 1;
        if (lower > exhaustive and lower < maximum) result += 1;
        if (strategy != .btopt and upper > exhaustive and upper < maximum) result += 1;
    }
    return result;
}

fn compare(minimum: usize, maximum: usize) !void {
    if (maximum < minimum or maximum > 131074) return;
    for ([_]Strategy{ .btopt, .btultra, .btultra2 }) |strategy| {
        try std.testing.expectEqual(original(strategy, minimum, maximum), count.perChoice(false, strategy, minimum, maximum));
        try std.testing.expectEqual(@as(u64, @intCast(maximum - minimum + 1)), count.perChoice(true, strategy, minimum, maximum));
    }
}

test "Zstd HQ choice enumeration count preserves every legal length and endpoint order" {
    for (3..131075) |maximum| try compare(3, maximum);
    for ([_]usize{ 3, 7, 16, 64, 131, 255 }) |minimum| {
        for (3..68) |maximum| try compare(minimum, maximum);
        for (prices.ml_bases, prices.ml_bits) |base, bits| {
            const lower: usize = base;
            const upper = lower + (@as(usize, 1) << @intCast(bits)) - 1;
            for ([_]usize{ lower -| 1, lower, lower + 1, upper -| 1, upper, upper + 1 }) |maximum| try compare(minimum, maximum);
        }
    }
}
