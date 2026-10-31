//! Exact size of the original per-choice ML enumeration, including duplicates.
const std = @import("std");
const prices = @import("prices.zig");
const Strategy = @import("../../encode/controls.zig").Strategy;

pub fn perChoice(comptime complete: bool, strategy: Strategy, minimum: usize, maximum: usize) u64 {
    std.debug.assert(minimum >= 3 and minimum <= maximum and maximum <= 131074);
    if (complete) return @intCast(maximum - minimum + 1);
    const exhaustive: usize = if (strategy == .btopt) 16 else 64;
    const end = @min(maximum, exhaustive + 1);
    var count: u64 = 1;
    if (end > minimum) count += @intCast(end - minimum);
    if (maximum <= exhaustive + 1) return count;
    // ML bases are strictly increasing. The final bucket of maximum-1 counts
    // exactly those lower endpoints which precede maximum.
    const lower_end: u64 = @as(u64, (prices.matchSymbol(maximum - 1) catch unreachable).code) + 1;
    const lower_start: u64 = if (strategy == .btopt) 14 else 40;
    if (lower_end > lower_start) count += lower_end - lower_start;
    // An upper endpoint is the next ML base minus one. Ultra's first upper
    // endpoint above 64 is 66, the end of symbol 39. Keep repeated endpoints
    // exactly as the original loop does; min_match does not gate this tail.
    if (strategy != .btopt) {
        const upper_end: u64 = (prices.matchSymbol(maximum) catch unreachable).code;
        if (upper_end > 39) count += upper_end - 39;
    }
    return count;
}
