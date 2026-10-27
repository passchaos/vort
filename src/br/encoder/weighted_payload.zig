//! Exact payload bit costs from already prepared Brotli histograms.
const std = @import("std");
const bit_count = @import("../../io/bit_count.zig");
const BitCount = bit_count.BitCount;

pub const Error = bit_count.Error || error{InvalidBlockPlan};

pub fn add(left: BitCount, right: BitCount) bit_count.Error!BitCount {
    return std.math.add(BitCount, left, right) catch error.IntegerOverflow;
}

pub fn multiply(count: u64, width: u64) bit_count.Error!BitCount {
    return std.math.mul(BitCount, count, width) catch error.IntegerOverflow;
}

pub fn ceilBytes(bits: BitCount) bit_count.Error!usize {
    return bit_count.ceilBytes(bits);
}

/// `alphabet.symbols[0..alphabet.len]` is the prepared active support. Inactive
/// frequencies and lengths can remain undefined. Command and distance trees
/// set `simple_small`; their <=4-symbol wire codes are given by `simpleCode`.
/// Literal trees keep using their actual lengths, including small alphabets.
pub fn histogram(
    comptime N: usize,
    frequencies: *const [N]u32,
    alphabet: anytype,
    lengths: *const [N]u4,
    comptime simple_small: bool,
) Error!BitCount {
    if (alphabet.len == 0 or alphabet.len > N or alphabet.len > alphabet.symbols.len)
        return error.InvalidBlockPlan;
    var bits: BitCount = 0;
    for (alphabet.symbols[0..alphabet.len]) |symbol| {
        if (symbol >= N) return error.InvalidBlockPlan;
        const width = if (simple_small and alphabet.len <= 4)
            (alphabet.simpleCode(symbol) orelse return error.InvalidBlockPlan).bits
        else
            lengths[symbol];
        bits = try add(bits, try multiply(frequencies[symbol], width));
    }
    return bits;
}

test "Brotli weighted payload matches scalar codes for every alphabet shape" {
    try @import("weighted_payload_tests.zig").shapes(@This());
}

test "Brotli weighted payload observes only active support and maximum counts" {
    try @import("weighted_payload_tests.zig").activeSupport(@This());
}

test "Brotli weighted payload adds extras and checks arithmetic boundaries" {
    try @import("weighted_payload_tests.zig").boundaries(@This());
}
