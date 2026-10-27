const std = @import("std");
const bit_count = @import("../../io/bit_count.zig");
const BitCount = bit_count.BitCount;
const command_plan = @import("command_plan.zig");

/// Counts individual symbol occurrences and code bits with a wider oracle.
/// This intentionally avoids the histogram's multiply-and-add calculation.
fn scalar(comptime N: usize, frequencies: *const [N]u32, symbols: []const u16, widths: []const u4) u128 {
    var result: u128 = 0;
    for (symbols, widths) |symbol, width| {
        for (0..frequencies[symbol]) |_| {
            for (0..width) |_| result += 1;
        }
    }
    return result;
}

pub fn shapes(comptime module: type) !void {
    const N = 16;
    const order = [_]u16{ 15, 2, 9, 0, 7, 3, 11, 5 };
    for (1..order.len + 1) |count| {
        var alphabet: command_plan.PrefixAlphabetFor(N) = .{};
        alphabet.len = count;
        @memcpy(alphabet.symbols[0..count], order[0..count]);
        var frequencies: [N]u32 = undefined;
        var lengths: [N]u4 = undefined;
        var actual_widths: [order.len]u4 = undefined;
        var simple_widths: [order.len]u4 = undefined;
        for (order[0..count], 0..) |symbol, index| {
            frequencies[symbol] = @intCast(19 - index * 2);
            // Small literal widths deliberately differ from simple prefixes.
            lengths[symbol] = @intCast(1 + index % 5);
            actual_widths[index] = lengths[symbol];
            simple_widths[index] = if (count <= 4)
                switch (count) {
                    1 => 0,
                    2 => 1,
                    3 => if (index == 0) 1 else 2,
                    4 => 2,
                    else => unreachable,
                }
            else
                lengths[symbol];
        }
        const literal_expected = scalar(N, &frequencies, order[0..count], actual_widths[0..count]);
        const simple_expected = scalar(N, &frequencies, order[0..count], simple_widths[0..count]);
        try std.testing.expectEqual(@as(BitCount, @intCast(literal_expected)), try module.histogram(N, &frequencies, &alphabet, &lengths, false));
        try std.testing.expectEqual(@as(BitCount, @intCast(simple_expected)), try module.histogram(N, &frequencies, &alphabet, &lengths, true));
        if (count <= 4) {
            const ignored_lengths: [N]u4 = undefined;
            try std.testing.expectEqual(@as(BitCount, @intCast(simple_expected)), try module.histogram(N, &frequencies, &alphabet, &ignored_lengths, true));
            for (order[0..count]) |symbol| frequencies[symbol] = std.math.maxInt(u32);
            const total_width: u64 = switch (count) {
                1 => 0,
                2 => 2,
                3 => 5,
                4 => 8,
                else => unreachable,
            };
            try std.testing.expectEqual(@as(BitCount, std.math.maxInt(u32)) * total_width, try module.histogram(N, &frequencies, &alphabet, &ignored_lengths, true));
        }
    }

    // A literal alphabet needs no simpleCode method when that route is disabled.
    const LiteralSupport = struct { symbols: [4]u8, len: usize };
    const alphabet = LiteralSupport{ .symbols = .{ 3, 0, 2, 1 }, .len = 4 };
    const frequencies: [4]u32 = .{ 5, 3, 7, 11 };
    const lengths: [4]u4 = .{ 2, 3, 3, 1 };
    const widths: [4]u4 = .{ 1, 2, 3, 3 };
    const symbols: [4]u16 = .{ 3, 0, 2, 1 };
    try std.testing.expectEqual(@as(BitCount, @intCast(scalar(4, &frequencies, &symbols, &widths))), try module.histogram(4, &frequencies, &alphabet, &lengths, false));
}

pub fn activeSupport(comptime module: type) !void {
    const N = 704;
    var alphabet: command_plan.PrefixAlphabetFor(N) = .{};
    alphabet.len = 5;
    alphabet.symbols[0..5].* = .{ 703, 0, 511, 13, 256 };
    var frequencies: [N]u32 = undefined;
    var lengths: [N]u4 = undefined;
    var expected: u128 = 0;
    for (alphabet.symbols[0..alphabet.len], 0..) |symbol, index| {
        frequencies[symbol] = std.math.maxInt(u32) - @as(u32, @intCast(index));
        lengths[symbol] = @intCast(15 - index);
        expected += @as(u128, frequencies[symbol]) * lengths[symbol];
    }
    try std.testing.expectEqual(@as(BitCount, @intCast(expected)), try module.histogram(N, &frequencies, &alphabet, &lengths, true));
    try std.testing.expectEqual(@as(BitCount, @intCast(expected)), try module.histogram(N, &frequencies, &alphabet, &lengths, false));
    // All-active maximum counts prove that the result stays wider than u32.
    alphabet.len = N;
    expected = 0;
    for (0..N) |symbol| {
        alphabet.symbols[symbol] = @intCast(symbol);
        frequencies[symbol] = std.math.maxInt(u32);
        lengths[symbol] = 15;
        expected += @as(u128, std.math.maxInt(u32)) * 15;
    }
    try std.testing.expectEqual(@as(BitCount, @intCast(expected)), try module.histogram(N, &frequencies, &alphabet, &lengths, true));

    alphabet.len = 0;
    try std.testing.expectError(error.InvalidBlockPlan, module.histogram(N, &frequencies, &alphabet, &lengths, true));
    alphabet.len = N + 1;
    try std.testing.expectError(error.InvalidBlockPlan, module.histogram(N, &frequencies, &alphabet, &lengths, true));
    alphabet.len = 1;
    alphabet.symbols[0] = N;
    try std.testing.expectError(error.InvalidBlockPlan, module.histogram(N, &frequencies, &alphabet, &lengths, true));
}

pub fn boundaries(comptime module: type) !void {
    const maximum: BitCount = std.math.maxInt(BitCount);
    try std.testing.expectEqual(@as(BitCount, 0), try module.multiply(std.math.maxInt(u64), 0));
    try std.testing.expectEqual(maximum, try module.multiply(std.math.maxInt(u64), 1));
    try std.testing.expectEqual(maximum - 1, try module.multiply(std.math.maxInt(u64) / 2, 2));
    try std.testing.expectError(error.IntegerOverflow, module.multiply(std.math.maxInt(u64), 2));
    try std.testing.expectEqual(maximum, try module.add(maximum - 3, 3));
    try std.testing.expectError(error.IntegerOverflow, module.add(maximum, 1));

    var expected: u128 = 27;
    var bits: BitCount = 27;
    const extras = [_]struct { count: u64, width: u64 }{
        .{ .count = 19, .width = 24 },
        .{ .count = 3, .width = 39 },
        .{ .count = std.math.maxInt(u32), .width = 15 },
    };
    for (extras) |extra| {
        expected += @as(u128, extra.count) * extra.width;
        bits = try module.add(bits, try module.multiply(extra.count, extra.width));
    }
    try std.testing.expectEqual(@as(BitCount, @intCast(expected)), bits);
    const expected_bytes = (expected + 7) / 8;
    if (expected_bytes > std.math.maxInt(usize)) {
        try std.testing.expectError(error.IntegerOverflow, module.ceilBytes(bits));
    } else {
        try std.testing.expectEqual(@as(usize, @intCast(expected_bytes)), try module.ceilBytes(bits));
    }
    try std.testing.expectEqual(@as(usize, 0), try module.ceilBytes(0));
    try std.testing.expectEqual(@as(usize, 1), try module.ceilBytes(1));
    if (@bitSizeOf(usize) < 64) {
        try std.testing.expectError(error.IntegerOverflow, module.ceilBytes(maximum));
    } else {
        try std.testing.expectEqual(bit_count.max_addressable_bytes + 1, try module.ceilBytes(maximum));
    }
}
