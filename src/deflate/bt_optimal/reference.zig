const std = @import("std");
const bt = @import("../bt_optimal.zig");
const lz77 = @import("../../lz77.zig");
const Match = lz77.Token.Match;
const none = std.math.maxInt(usize);
// Independent recursive treap split. Every comparison starts at byte zero;
// it has no production pending-link or lower/upper common-prefix state.
pub const Reference = struct {
    input: []const u8,
    options: lz77.GreedyOptions,
    roots: []usize,
    children: [][2]usize,
    offsets: []usize,
    raw: std.ArrayList(Match) = .empty,
    admitted: []bool = &.{},

    pub fn init(input: []const u8, options: lz77.GreedyOptions) !Reference {
        const a = std.testing.allocator;
        var result: Reference = .{
            .input = input,
            .options = options,
            .roots = try a.alloc(usize, bt.hash_size),
            .children = &.{},
            .offsets = &.{},
        };
        errdefer result.deinit();
        result.children = try a.alloc([2]usize, input.len);
        result.offsets = try a.alloc(usize, input.len + 1);
        result.admitted = try a.alloc(bool, input.len);
        @memset(result.admitted, true);
        @memset(result.roots, none);
        @memset(result.children, .{ none, none });
        for (0..input.len) |position| {
            result.offsets[position] = result.raw.items.len;
            if (input.len - position < 3) continue;
            const hash = bt.hashAt(input, position);
            var valid: usize = 0;
            const halves = try result.split(result.roots[hash], position, options.max_chain, &valid);
            result.children[position] = halves;
            result.roots[hash] = position;
        }
        result.offsets[input.len] = result.raw.items.len;
        // Independent raw-edge mask: only uncovered positions can trigger a
        // cover; every subsequent covered position is denied outgoing edges.
        var position: usize = 0;
        while (position < input.len) {
            var maximum: usize = 0;
            for (result.at(position)) |match| maximum = @max(maximum, match.length);
            if (maximum >= bt.coverage_threshold) {
                @memset(result.admitted[position + 1 .. position + maximum], false);
                position += maximum;
            } else position += 1;
        }
        return result;
    }
    pub fn deinit(self: *Reference) void {
        const a = std.testing.allocator;
        a.free(self.roots);
        a.free(self.children);
        a.free(self.offsets);
        a.free(self.admitted);
        self.raw.deinit(a);
    }
    fn split(self: *Reference, node: usize, position: usize, depth: usize, valid: *usize) std.mem.Allocator.Error![2]usize {
        const budget = @max(1, @min(lz77.max_optimal_candidates, self.options.max_candidates));
        if (node == none or depth == 0 or valid.* >= budget or position - node > self.options.window_len)
            return .{ none, none };
        const maximum = @min(@max(3, @min(258, self.options.max_match)), self.input.len - position);
        const minimum = @max(3, @min(@max(3, @min(258, self.options.max_match)), self.options.min_match));
        var length: usize = 0;
        while (length < maximum and self.input[node + length] == self.input[position + length]) : (length += 1) {}
        if (length >= minimum) {
            valid.* += 1;
            try self.raw.append(std.testing.allocator, .{ .length = @intCast(length), .distance = @intCast(position - node) });
        }
        if (length == maximum) return self.children[node];
        if (self.input[node + length] < self.input[position + length]) {
            const halves = try self.split(self.children[node][1], position, depth - 1, valid);
            self.children[node][1] = halves[0];
            return .{ node, halves[1] };
        }
        const halves = try self.split(self.children[node][0], position, depth - 1, valid);
        self.children[node][0] = halves[1];
        return .{ halves[0], node };
    }
    pub fn at(self: *const Reference, position: usize) []const Match {
        return self.raw.items[self.offsets[position]..self.offsets[position + 1]];
    }
};

pub fn compareEvidence(prepared: *const bt.Prepared, reference: *const Reference) !void {
    for (0..prepared.input.len) |position| {
        var expected: [30]?Match = @splat(null);
        for (if (reference.admitted[position]) reference.at(position) else &.{}) |match| {
            // Reference class lookup uses RFC upper limits, independent of
            // the production arithmetic distance-to-symbol calculation.
            var cls: usize = 0;
            while (match.distance > bt.class_ends[cls]) : (cls += 1) {}
            if (expected[cls]) |old| {
                if (match.length > old.length or (match.length == old.length and match.distance < old.distance))
                    expected[cls] = match;
            } else expected[cls] = match;
        }
        var cursor: usize = 0;
        const actual = prepared.evidenceAt(position);
        for (expected) |optional| if (optional) |match| {
            try std.testing.expect(cursor < actual.len);
            try std.testing.expectEqualDeep(match, bt.unpack(actual[cursor]));
            cursor += 1;
        };
        try std.testing.expectEqual(cursor, actual.len);
    }
}

// Exhaustively considers every legal length for every raw visited BT match.
// Unlike the production suffix prefix-minimum replay, it never class-collapses
// matches and never caches best choices over shorter lengths.
pub fn oracleCost(reference: *const Reference, comptime modeled: bool, model: if (modeled) lz77.OptimalCostModel else void) !usize {
    const costs = try std.testing.allocator.alloc(usize, reference.input.len + 1);
    defer std.testing.allocator.free(costs);
    costs[reference.input.len] = 0;
    const minimum = @max(3, @min(@max(3, @min(258, reference.options.max_match)), reference.options.min_match));
    var position = reference.input.len;
    while (position > 0) {
        position -= 1;
        const literal: usize = if (modeled) model.literal[reference.input[position]] else if (reference.input[position] < 144) 8 else 9;
        costs[position] = literal + costs[position + 1];
        for (if (reference.admitted[position]) reference.at(position) else &.{}) |match| {
            const distance: usize = if (modeled) model.distance[match.distance] else lz77.fixedDistanceCost(match.distance);
            for (minimum..match.length + 1) |length| {
                const edge: usize = if (modeled) model.length[length] else lz77.fixedLengthCost(length);
                costs[position] = @min(costs[position], costs[position + length] + edge + distance);
            }
        }
    }
    return costs[0];
}

pub fn validatePlan(input: []const u8, plan: lz77.GreedyPlan) !void {
    var position: usize = 0;
    var stats: lz77.PlanStats = .{};
    for (plan.tokens) |token| switch (token) {
        .literal => |literal| {
            try std.testing.expectEqual(input[position], literal);
            position += 1;
            stats.literals += 1;
        },
        .match => |match| {
            try std.testing.expect(match.distance > 0 and match.distance <= @min(position, 32768));
            try std.testing.expect(position + match.length <= input.len);
            for (0..match.length) |offset| try std.testing.expectEqual(input[position + offset - match.distance], input[position + offset]);
            position += match.length;
            stats.matches += 1;
            stats.matched_bytes += match.length;
        },
    };
    try std.testing.expectEqual(input.len, position);
    try std.testing.expectEqualDeep(stats, plan.stats);
}

pub fn fill(input: []u8, seed: u32) void {
    var state = seed;
    for (input, 0..) |*byte, i| {
        state = state *% 1664525 +% 1013904223;
        byte.* = if (i % 29 < 24) "abcabcdabcabcxyzabcabdaba"[i % 24] else @truncate(state >> 16);
    }
}
