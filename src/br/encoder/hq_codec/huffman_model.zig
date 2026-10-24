//! Prices from the chosen on-wire Huffman representation, including simple trees.
const std = @import("std");
const command_plan = @import("../command_plan.zig");
pub const scale: u32 = 256;
pub const absent_price: u32 = 64 * scale;

pub fn table(comptime capacity: usize, prices: *[capacity]u32, frequencies: *[capacity]u32, alphabet: *const command_plan.PrefixAlphabetFor(capacity), lengths: *const [capacity]u4, samples: *const [capacity]u32) error{InvalidBlockPlan}!void {
    if (alphabet.len == 0 or alphabet.len > capacity) return error.InvalidBlockPlan;
    prices.* = @splat(absent_price);
    frequencies.* = @splat(0);
    for (alphabet.symbols[0..alphabet.len]) |symbol| {
        if (symbol >= capacity) return error.InvalidBlockPlan;
        const bits: u32 = if (alphabet.len == 1) 0 else if (alphabet.len <= 4)
            (alphabet.simpleCode(symbol) orelse return error.InvalidBlockPlan).bits
        else
            lengths[symbol];
        if (bits == 0 and alphabet.len != 1) return error.InvalidBlockPlan;
        prices[symbol] = bits * scale;
        frequencies[symbol] = samples[symbol];
    }
}

pub fn tables(comptime capacity: usize, prices: *[capacity]u32, frequencies: *[capacity]u32, alphabets: []const command_plan.PrefixAlphabetFor(capacity), lengths: []const [capacity]u4, samples: []const [capacity]u32) error{InvalidBlockPlan}!void {
    if (alphabets.len == 0 or alphabets.len != lengths.len or alphabets.len != samples.len) return error.InvalidBlockPlan;
    var weighted: [capacity]u64 = @splat(0);
    frequencies.* = @splat(0);
    for (alphabets, lengths, samples) |*alphabet, *tree_lengths, *counts| {
        var actual: [capacity]u32 = undefined;
        var copied: [capacity]u32 = undefined;
        try table(capacity, &actual, &copied, alphabet, tree_lengths, counts);
        for (&weighted, frequencies, actual, copied) |*cost, *count, price, sample| {
            cost.* += @as(u64, price) * sample;
            count.* +|= sample;
        }
    }
    for (prices, frequencies, weighted) |*price, count, cost|
        price.* = if (count == 0) absent_price else @intCast(cost / count);
}

test "Brotli HQ literal prices use actual simple tree bit widths" {
    var alphabet: command_plan.PrefixAlphabetFor(256) = undefined;
    const samples: [256]u32 = init: {
        var counts: [256]u32 = @splat(0);
        counts['a'] = 100;
        counts['b'] = 10;
        counts['c'] = 1;
        break :init counts;
    };
    try command_plan.alphabetFromFrequenciesInto(256, &alphabet, &samples);
    var prices: [256]u32 = undefined;
    var frequencies: [256]u32 = undefined;
    // The main emitter intentionally uses all-zero lengths for simple trees.
    const lengths: [256]u4 = @splat(0);
    try table(256, &prices, &frequencies, &alphabet, &lengths, &samples);
    for ("abc") |symbol| try std.testing.expectEqual(@as(u32, alphabet.simpleCode(symbol).?.bits) * scale, prices[symbol]);
    try std.testing.expectEqual(absent_price, prices['z']);
    try std.testing.expectEqual(samples, frequencies);
}

test "Brotli HQ model ignores inactive sparse frequency slots" {
    var alphabet: command_plan.PrefixAlphabetFor(256) = .{};
    alphabet.symbols[0] = 'a';
    alphabet.len = 1;
    var samples: [256]u32 = @splat(std.math.maxInt(u32));
    samples['a'] = 7;
    const lengths: [256]u4 = @splat(0);
    var prices: [256]u32 = undefined;
    var frequencies: [256]u32 = undefined;
    try table(256, &prices, &frequencies, &alphabet, &lengths, &samples);
    try std.testing.expectEqual(@as(u32, 7), frequencies['a']);
    try std.testing.expectEqual(@as(u32, 0), frequencies['z']);
    try std.testing.expectEqual(@as(u32, 0), prices['a']);
    try std.testing.expectEqual(absent_price, prices['z']);
}
