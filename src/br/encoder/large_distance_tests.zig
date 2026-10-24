const std = @import("std");
const distance = @import("distance.zig");

// Forward RFC distance groups, independent of the production inverse and
// first-forbidden-group calculation. u128 also represents the 62-bit wire
// alphabet's mathematical distances before applying the signed-safe limit.
fn physical(symbol: usize, extra: u128, postfix: u2, direct: u7) u128 {
    if (symbol < 16 + @as(usize, direct)) return symbol - 15;
    const regular = symbol - 16 - direct;
    const group = regular >> postfix;
    const bits: u7 = @intCast(group / 2 + 1);
    const base = ((@as(u128, 2) + (group & 1)) << bits) - 4;
    const low = regular & ((@as(usize, 1) << postfix) - 1);
    return ((base + extra) << postfix) + low + direct + 1;
}

fn oracleLimit(postfix: u2, direct: u7) struct { alphabet: usize, maximum: usize } {
    var alphabet: usize = 16 + @as(usize, direct);
    var maximum: usize = direct;
    for (1..63) |bits| {
        for (0..2) |_| {
            const group_end = alphabet + (@as(usize, 1) << postfix) - 1;
            const upper = physical(group_end, (@as(u128, 1) << @intCast(bits)) - 1, postfix, direct);
            if (upper > 0x7FFFFFFC) return .{ .alphabet = alphabet, .maximum = maximum };
            maximum = @intCast(upper);
            alphabet = group_end + 1;
        }
    }
    unreachable;
}

test "Brotli large distance authority separates wire and active alphabets for all sixty four shapes" {
    var maximum_wire: usize = 0;
    var maximum_active: usize = 0;
    for (0..4) |postfix_value| for (0..16) |high_value| {
        const p = distance.Parameters.init(@intCast(postfix_value), @intCast(high_value));
        const expected = oracleLimit(p.npostfix, p.ndirect());
        try std.testing.expectEqual(16 + @as(usize, p.ndirect()) + (@as(usize, 124) << p.npostfix), p.wireAlphabetSize(.large_window));
        try std.testing.expectEqual(expected.alphabet, p.activeAlphabetSize(.large_window));
        try std.testing.expectEqual(expected.maximum, p.maximumDistanceForFormat(.large_window));
        try std.testing.expectEqual(p.alphabetSize(), p.wireAlphabetSize(.standard));
        try std.testing.expectEqual(p.alphabetSize(), p.activeAlphabetSize(.standard));
        try std.testing.expectEqual(p.maximumDistance(), p.maximumDistanceForFormat(.standard));
        maximum_wire = @max(maximum_wire, p.wireAlphabetSize(.large_window));
        maximum_active = @max(maximum_active, p.activeAlphabetSize(.large_window));
    };
    try std.testing.expectEqual(@as(usize, 1128), maximum_wire);
    try std.testing.expectEqual(@as(usize, 544), maximum_active);
    try std.testing.expectEqual(@as(usize, 2147483644), distance.Parameters.init(0, 0).maximumDistanceForFormat(.large_window));
    try std.testing.expectEqual(@as(usize, 1610612733), distance.Parameters.init(0, 1).maximumDistanceForFormat(.large_window));
    try std.testing.expectEqual(@as(usize, 1610612824), distance.Parameters.init(3, 15).maximumDistanceForFormat(.large_window));
}

test "Brotli large distance authority checks every active bucket boundary and forbidden extras" {
    for (0..4) |postfix_value| for (0..16) |high_value| {
        const p = distance.Parameters.init(@intCast(postfix_value), @intCast(high_value));
        const active = p.activeAlphabetSize(.large_window);
        const maximum = p.maximumDistanceForFormat(.large_window);
        try std.testing.expect(distance.encodeWithFormat(0, p, .large_window) == null);
        for (1..@as(usize, p.ndirect()) + 1) |value| {
            const direct: distance.Encoding = .{ .symbol = @intCast(15 + value) };
            try std.testing.expectEqualDeep(direct, distance.encodeWithFormat(value, p, .large_window).?);
            try std.testing.expectEqual(@as(?usize, value), distance.decodeWithFormat(direct, p, .large_window));
        }
        for (16 + @as(usize, p.ndirect())..active) |symbol| {
            const group = (symbol - 16 - p.ndirect()) >> p.npostfix;
            const bits: u5 = @intCast(group / 2 + 1);
            const max_extra = (@as(u32, 1) << bits) - 1;
            for ([_]u32{ 0, max_extra }) |extra| {
                const value: usize = @intCast(physical(symbol, extra, p.npostfix, p.ndirect()));
                const encoded: distance.Encoding = .{ .symbol = @intCast(symbol), .extra = extra, .extra_bits = bits };
                try std.testing.expectEqualDeep(encoded, distance.encodeWithFormat(value, p, .large_window).?);
                try std.testing.expectEqual(@as(?usize, value), distance.decodeWithFormat(encoded, p, .large_window));
                try std.testing.expect(value <= maximum);
            }
            try std.testing.expect(distance.decodeWithFormat(.{ .symbol = @intCast(symbol), .extra = max_extra + 1, .extra_bits = bits }, p, .large_window) == null);
        }
        const terminal = distance.encodeWithFormat(maximum, p, .large_window).?;
        try std.testing.expectEqual(@as(usize, terminal.symbol), active - 1);
        try std.testing.expect(distance.encodeWithFormat(maximum + 1, p, .large_window) == null);
        try std.testing.expect(distance.decodeWithFormat(.{ .symbol = @intCast(active), .extra_bits = terminal.extra_bits }, p, .large_window) == null);
        try std.testing.expect(distance.decodeWithFormat(.{ .symbol = @intCast(p.wireAlphabetSize(.large_window) - 1), .extra_bits = 31 }, p, .large_window) == null);
        try std.testing.expect(distance.encodeWithFormat(distance.safe_max_distance + 1, p, .large_window) == null);
        const old = distance.encodeWithParameters(p.maximumDistance(), p).?;
        try std.testing.expectEqualDeep(old, distance.encodeWithFormat(p.maximumDistance(), p, .standard).?);
        try std.testing.expectEqual(@as(?usize, p.maximumDistance()), distance.decodeWithFormat(old, p, .standard));
    };
}

test "Brotli large distance authority excludes incomplete groups below the global safe value" {
    const p = distance.Parameters.init(0, 1);
    const maximum = p.maximumDistanceForFormat(.large_window);
    try std.testing.expect(maximum < distance.safe_max_distance);
    try std.testing.expect(distance.encodeWithFormat(maximum + 1, p, .large_window) == null);
    const zero = distance.Parameters.init(0, 0);
    try std.testing.expect(distance.encodeWithFormat(distance.safe_max_distance, zero, .large_window) != null);
    try std.testing.expect(distance.encodeWithParameters(distance.safe_max_distance, zero) == null);
}
