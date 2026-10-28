//! Conservative whole-period sampling, exact KMP period and stable tie rank.
const std = @import("std");

pub const minimum_len: usize = 16;

/// Reject clear nonperiodic blocks before the O(n) prefix pass. Every true
/// whole period divides n and passes each cyclic equality below. A sampled
/// false positive is harmless: KMP and divisibility still decide the path.
/// Shorter blocks use generic sorting to avoid extra periodic allocations.
pub fn possible(input: []const u8) bool {
    if (input.len < minimum_len) return false;
    var divisor: usize = 1;
    while (divisor <= input.len / divisor) : (divisor += 1) {
        if (input.len % divisor != 0) continue;
        if (divisor < input.len and matches(input, divisor)) return true;
        const other = input.len / divisor;
        if (other != divisor and other < input.len and matches(input, other)) return true;
    }
    return false;
}

fn matches(input: []const u8, period: usize) bool {
    const offsets = [_]usize{ 0, 1, input.len / 3, input.len / 2, input.len - 1 };
    for (offsets) |index| {
        const previous = if (index >= period) index - period else index + input.len - period;
        if (input[index] != input[previous]) return false;
    }
    return true;
}

pub fn least(input: []const u8, prefix: []u32) usize {
    std.debug.assert(input.len != 0 and input.len == prefix.len);
    prefix[0] = 0;
    for (1..input.len) |index| {
        var length: usize = prefix[index - 1];
        while (length != 0 and input[index] != input[length]) length = prefix[length - 1];
        if (input[index] == input[length]) length += 1;
        prefix[index] = @intCast(length);
    }
    const period = input.len - prefix[input.len - 1];
    return if (input.len % period == 0) period else input.len;
}

pub fn originalPointer(length: usize, period: usize, base_pointer: u32) u32 {
    std.debug.assert(length <= 900_000 and period != 0 and period < length and length % period == 0 and base_pointer < period);
    const repeated = length / period;
    var power: usize = 1;
    while (power < length) power *= 2;
    // Stable doubling ties sort by (index + power - 1) mod length. In the
    // original rotation's class (index=k*period), its rank is floor(S/p) mod r.
    return @intCast(@as(usize, base_pointer) * repeated + ((power - 1) / period) % repeated);
}
