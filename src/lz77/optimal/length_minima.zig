//! Exact fixed-cost length choices over bounded sliding suffix ranges.
const std = @import("std");
const suffix_costs = @import("suffix_costs.zig");
const capacity = 128;
const mask = capacity - 1;

pub const Choice = struct { cost: usize, length: u16 };
const Range = struct { lo: usize, hi: usize, cost: usize };
const Spec = struct { values: [256]Range, count: usize };

fn ranges(comptime costs: [259]u8) Spec {
    @setEvalBranchQuota(10000);
    var result: Spec = undefined;
    result.count = 0;
    var lo: usize = 3;
    while (lo < costs.len) {
        var hi = lo;
        while (hi + 1 < costs.len and costs[hi + 1] == costs[lo]) hi += 1;
        std.debug.assert(hi - lo + 1 <= capacity);
        result.values[result.count] = .{ .lo = lo, .hi = hi, .cost = costs[lo] };
        result.count += 1;
        lo = hi + 1;
    }
    return result;
}

const Queue = struct {
    positions: [capacity]usize = undefined,
    head: usize = 0,
    len: usize = 0,
    lo: usize,
    hi: usize,
    cost: usize,

    fn advance(self: *Queue, costs: anytype, pos: usize) void {
        if (self.lo > self.hi) return;
        const available = costs.len - 1 - pos;
        const upper = pos + @min(self.hi, available);
        while (self.len > 0 and self.positions[self.head] > upper) {
            self.head = (self.head + 1) & mask;
            self.len -= 1;
        }
        if (self.lo > available) return;
        const next = pos + self.lo;
        // Equal-cost older positions remain first to preserve longest ties.
        while (self.len > 0 and suffix_costs.get(costs, self.positions[(self.head + self.len - 1) & mask]) > suffix_costs.get(costs, next)) self.len -= 1;
        std.debug.assert(self.len < capacity);
        self.positions[(self.head + self.len) & mask] = next;
        self.len += 1;
    }

    fn best(self: *const Queue, upper: usize) ?usize {
        if (self.len == 0) return null;
        if (self.positions[self.head] <= upper) return self.positions[self.head];
        // Positions decrease in queue order. A partial length range excludes
        // its older high positions; the first retained entry has minimum cost.
        var lo: usize = 0;
        var hi = self.len;
        while (lo < hi) {
            const mid = lo + (hi - lo) / 2;
            if (self.positions[(self.head + mid) & mask] > upper) lo = mid + 1 else hi = mid;
        }
        return if (lo == self.len) null else self.positions[(self.head + lo) & mask];
    }
};

pub fn Set(comptime length_costs: [259]u8) type {
    const spec = comptime ranges(length_costs);
    return struct {
        const Self = @This();
        queues: [spec.count]Queue = undefined,
        minimum: usize,
        maximum: usize,
        position: usize = std.math.maxInt(usize),

        pub fn init(minimum: usize, maximum: usize) Self {
            std.debug.assert(minimum >= 3 and minimum <= maximum and maximum <= 258);
            var result = Self{ .minimum = minimum, .maximum = maximum };
            for (0..spec.count) |i| {
                const range = spec.values[i];
                result.queues[i] = .{ .lo = @max(minimum, range.lo), .hi = @min(maximum, range.hi), .cost = range.cost };
            }
            return result;
        }

        pub fn advance(self: *Self, costs: anytype, pos: usize) void {
            std.debug.assert(pos < costs.len and (self.position == std.math.maxInt(usize) or pos + 1 == self.position));
            for (&self.queues) |*queue| queue.advance(costs, pos);
            self.position = pos;
        }

        pub fn best(self: *const Self, costs: anytype, pos: usize, maximum: usize) Choice {
            std.debug.assert(self.position == pos and maximum >= self.minimum and maximum <= self.maximum and maximum < costs.len - pos);
            var result = Choice{ .cost = std.math.maxInt(usize), .length = 0 };
            for (&self.queues) |*queue| {
                if (queue.lo > queue.hi or maximum < queue.lo) continue;
                const suffix = queue.best(pos + @min(maximum, queue.hi)) orelse continue;
                const cost = suffix_costs.get(costs, suffix) + queue.cost;
                const length: u16 = @intCast(suffix - pos);
                if (cost < result.cost or (cost == result.cost and length > result.length)) result = .{ .cost = cost, .length = length };
            }
            std.debug.assert(result.length != 0);
            return result;
        }
    };
}

pub fn compare(comptime length_costs: [259]u8) !void {
    var costs: [516]usize = undefined;
    var state: u32 = 0x937599bf;
    for (0..5) |kind| {
        for (&costs, 0..) |*cost, i| {
            state = state *% 1664525 +% 1013904223;
            cost.* = switch (kind) {
                0 => 0,
                1 => i,
                2 => costs.len - i,
                3 => i % 17,
                else => @as(usize, state >> 16) % 257,
            };
        }
        for ([_]usize{ 3, 4, 13, 129, 258 }) |minimum| {
            for ([_]usize{ 3, 32, 258 }) |limit| {
                if (minimum > limit) continue;
                var minima = Set(length_costs).init(minimum, limit);
                var pos = costs.len - 1;
                while (pos > 0) {
                    pos -= 1;
                    minima.advance(&costs, pos);
                    for ([_]usize{ minimum, minimum + 1, 7, 8, 10, 11, 18, 19, 34, 35, 66, 67, 114, 115, 130, 131, 257, 258 }) |maximum| {
                        if (maximum < minimum or maximum > limit or maximum >= costs.len - pos) continue;
                        var expected = Choice{ .cost = std.math.maxInt(usize), .length = 0 };
                        for (minimum..maximum + 1) |length| {
                            const cost = length_costs[length] + costs[pos + length];
                            if (cost < expected.cost or (cost == expected.cost and length > expected.length)) expected = .{ .cost = cost, .length = @intCast(length) };
                        }
                        try std.testing.expectEqual(expected, minima.best(&costs, pos, maximum));
                    }
                }
            }
        }
    }
    try std.testing.expect(@sizeOf(Set(length_costs)) <= 9 * 1024);
}
