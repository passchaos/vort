const std = @import("std");
const lz77 = @import("../../../../lz77.zig");

pub const Stats = struct {
    literal_frequencies: [286]u32 = @splat(0),
    distance_frequencies: [30]u32 = @splat(0),
    length_extra_bits: usize = 0,
    distance_extra_bits: usize = 0,
    literal_active_count: usize = 0,
    distance_active_count: usize = 0,
    // Preserve the exact symbols made non-zero so the reusable histogram can
    // be cleared in O(active symbols), not by zeroing all 316 counters.
    active_literals: [286]u16 = undefined,
    active_distances: [30]u16 = undefined,

    pub fn reset(self: *Stats) void {
        for (self.active_literals[0..self.literal_active_count]) |symbol|
            self.literal_frequencies[symbol] = 0;
        for (self.active_distances[0..self.distance_active_count]) |symbol|
            self.distance_frequencies[symbol] = 0;
        self.length_extra_bits = 0;
        self.distance_extra_bits = 0;
        self.literal_active_count = 0;
        self.distance_active_count = 0;
    }

    pub fn recordLiteral(self: *Stats, byte: u8) void {
        if (self.literal_frequencies[byte] == 0) {
            insertSorted(u16, &self.active_literals, self.literal_active_count, byte);
            self.literal_active_count += 1;
        }
        self.literal_frequencies[byte] += 1;
    }

    pub fn recordMatch(self: *Stats, match: lz77.Token.Match) void {
        const length = lengthSymbol(match.length);
        const distance = distanceSymbol(match.distance);
        if (self.literal_frequencies[length.symbol] == 0) {
            insertSorted(u16, &self.active_literals, self.literal_active_count, @intCast(length.symbol));
            self.literal_active_count += 1;
        }
        self.literal_frequencies[length.symbol] += 1;
        if (self.distance_frequencies[distance.symbol] == 0) {
            insertSorted(u16, &self.active_distances, self.distance_active_count, @intCast(distance.symbol));
            self.distance_active_count += 1;
        }
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

    pub fn literalSymbols(self: *const Stats) []const u16 {
        return self.active_literals[0..self.literal_active_count];
    }

    pub fn distanceSymbols(self: *const Stats) []const u16 {
        return self.active_distances[0..self.distance_active_count];
    }
};

fn insertSorted(comptime T: type, values: []T, len: usize, value: T) void {
    var index = len;
    while (index != 0 and value < values[index - 1]) : (index -= 1)
        values[index] = values[index - 1];
    values[index] = value;
}

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

test "incremental dynamic stats expose active symbols without stale entries" {
    var stats: Stats = .{};
    stats.recordLiteral('a');
    stats.recordLiteral('b');
    stats.recordLiteral('a');
    stats.recordMatch(.{ .length = 3, .distance = 5 });
    try std.testing.expectEqualSlices(u16, &.{ 'a', 'b', 257 }, stats.literalSymbols());
    try std.testing.expectEqualSlices(u16, &.{4}, stats.distanceSymbols());

    stats.reset();
    stats.recordLiteral('z');
    try std.testing.expectEqualSlices(u16, &.{'z'}, stats.literalSymbols());
    try std.testing.expectEqual(@as(usize, 0), stats.distanceSymbols().len);
}
