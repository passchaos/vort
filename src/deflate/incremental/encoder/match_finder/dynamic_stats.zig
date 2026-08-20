const std = @import("std");
const lz77 = @import("../../../../lz77.zig");

pub const Stats = struct {
    literal_frequencies: [286]u32 = @splat(0),
    distance_frequencies: [30]u32 = @splat(0),
    length_extra_bits: usize = 0,
    distance_extra_bits: usize = 0,
    literal_active_count: usize = 0,
    distance_active_count: usize = 0,

    pub fn reset(self: *Stats) void {
        self.* = .{};
    }

    pub fn recordLiteral(self: *Stats, byte: u8) void {
        if (self.literal_frequencies[byte] == 0) self.literal_active_count += 1;
        self.literal_frequencies[byte] += 1;
    }

    pub fn recordMatch(self: *Stats, match: lz77.Token.Match) void {
        const length = lengthSymbol(match.length);
        const distance = distanceSymbol(match.distance);
        if (self.literal_frequencies[length.symbol] == 0) self.literal_active_count += 1;
        self.literal_frequencies[length.symbol] += 1;
        if (self.distance_frequencies[distance.symbol] == 0) self.distance_active_count += 1;
        self.distance_frequencies[distance.symbol] += 1;
        self.length_extra_bits += length.extra_bits;
        self.distance_extra_bits += distance.extra_bits;
    }

    pub fn literalActiveCount(self: Stats) usize {
        return self.literal_active_count;
    }

    pub fn distanceActiveCount(self: Stats) usize {
        return self.distance_active_count;
    }
};

const SymbolBits = struct { symbol: usize, extra_bits: usize };

fn lengthSymbol(length: u16) SymbolBits {
    if (length <= 10) return .{ .symbol = length + 254, .extra_bits = 0 };
    if (length == 258) return .{ .symbol = 285, .extra_bits = 0 };
    const extra_bits: usize = std.math.log2_int(u16, length - 3) - 2;
    const span: u16 = @as(u16, 1) << @intCast(extra_bits);
    const group_base: u16 = (@as(u16, 1) << @intCast(extra_bits + 2)) + 3;
    const slot = (length - group_base) / span;
    return .{ .symbol = 261 + extra_bits * 4 + slot, .extra_bits = extra_bits };
}

fn distanceSymbol(distance: u16) SymbolBits {
    if (distance <= 4) return .{ .symbol = distance - 1, .extra_bits = 0 };
    const extra_bits: usize = std.math.log2_int(u16, distance - 1) - 1;
    const group_base: u16 = (@as(u16, 1) << @intCast(extra_bits + 1)) + 1;
    const slot = (distance - group_base) >> @intCast(extra_bits);
    return .{ .symbol = 2 + extra_bits * 2 + slot, .extra_bits = extra_bits };
}

test "incremental dynamic stats match DEFLATE symbol metadata" {
    var stats: Stats = .{};
    for (3..259) |length| {
        stats.reset();
        stats.recordMatch(.{ .length = @intCast(length), .distance = 1 });
        var literal_total: u32 = 0;
        for (stats.literal_frequencies) |frequency| literal_total += frequency;
        try std.testing.expectEqual(@as(u32, 1), literal_total);
    }
    for (1..32769) |distance| {
        stats.reset();
        stats.recordMatch(.{ .length = 3, .distance = @intCast(distance) });
        var distance_total: u32 = 0;
        for (stats.distance_frequencies) |frequency| distance_total += frequency;
        try std.testing.expectEqual(@as(u32, 1), distance_total);
    }
}
