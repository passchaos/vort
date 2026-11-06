//! One-input owner for covered BT evidence and two reverse cost solves.
const std = @import("std");
const lz77 = @import("../../lz77.zig");
const matcher = @import("matcher.zig");
const evidence = @import("evidence.zig");
const Tree = matcher.Tree;
const min_input_len = matcher.min_input_len;
const max_input_len = matcher.max_input_len;
const coverage_threshold = matcher.coverage_threshold;
const empty = matcher.empty;
const class_ends = matcher.class_ends;
const pack = evidence.pack;
const unpack = evidence.unpack;

pub const Prepared = struct {
    input: []const u8,
    options: lz77.GreedyOptions,
    counts: []u8 = &.{},
    records: std.ArrayList(evidence.Record) = .empty,
    costs: []u32 = &.{},
    steps: []lz77.Token = &.{},

    pub fn init(allocator: std.mem.Allocator, input: []const u8, options: lz77.GreedyOptions) !Prepared {
        if (input.len < min_input_len or input.len > max_input_len or
            options.window_len == 0 or options.window_len > lz77.default_window_len)
            return error.InvalidBlockPlan;
        var result: Prepared = .{ .input = input, .options = options };
        errdefer result.deinit(allocator);
        result.counts = try allocator.alloc(u8, input.len);
        @memset(result.counts, 0);
        {
            var tree = try Tree.init(allocator, input.len);
            defer tree.deinit(allocator);
            const maximum = @max(3, @min(258, options.max_match));
            const minimum = @max(3, @min(maximum, options.min_match));
            var covered_end: usize = 0;
            for (0..input.len) |position| {
                if (input.len - position < 3) continue;
                var lengths: [30]u16 = @splat(0);
                var distances: [30]u16 = @splat(empty);
                tree.advance(input, position, @min(maximum, input.len - position), minimum, options.window_len, options.max_chain, @max(1, @min(lz77.max_optimal_candidates, options.max_candidates)), &lengths, &distances);
                // Evidence coverage never changes tree insertion/search budgets.
                // Every covered position still ran the full advance above; its
                // outgoing match edges are omitted and cannot extend coverage.
                if (position < covered_end) continue;
                const longest = std.mem.max(u16, &lengths);
                if (longest >= coverage_threshold) covered_end = position + longest;
                // Class order also orders exact distances from nearest to
                // farthest, providing deterministic cross-class DP ties.
                for (lengths, distances) |length, distance| {
                    if (length != 0) {
                        try result.records.append(allocator, pack(length, distance));
                        result.counts[position] += 1;
                    }
                }
            }
        }
        // Tree roots and full-input u16 child links are gone before any DP
        // workspace is allocated; only immutable sparse evidence remains.
        result.costs = try allocator.alloc(u32, input.len + 1);
        result.steps = try allocator.alloc(lz77.Token, input.len);
        return result;
    }

    pub fn deinit(self: *Prepared, allocator: std.mem.Allocator) void {
        allocator.free(self.counts);
        self.records.deinit(allocator);
        allocator.free(self.costs);
        allocator.free(self.steps);
        self.* = undefined;
    }

    pub fn evidenceAt(self: *const Prepared, position: usize) []const evidence.Record {
        // Diagnostic random access only. Production solves consume counts
        // and records backwards with a single cursor, without an offset table.
        var start: usize = 0;
        for (self.counts[0..position]) |count| start += count;
        return self.records.items[start .. start + self.counts[position]];
    }

    pub fn planFixedAlloc(self: *Prepared, allocator: std.mem.Allocator) !lz77.GreedyPlan {
        return self.solve(allocator, false, undefined, 0);
    }

    pub fn planModeledAlloc(self: *Prepared, allocator: std.mem.Allocator, model: lz77.OptimalCostModel) !lz77.GreedyPlan {
        try self.validateModel(model);
        return self.solve(allocator, true, model, 0);
    }

    /// Plan only the suffix starting at `start`. Earlier bytes stay available
    /// as match sources through the prepared evidence but are not DP positions.
    /// Used by history-prefixed chunk planning, where the prefix is context.
    pub fn planFixedAllocFrom(self: *Prepared, allocator: std.mem.Allocator, start: usize) !lz77.GreedyPlan {
        if (start > self.input.len) return error.InvalidBlockPlan;
        return self.solve(allocator, false, undefined, start);
    }

    pub fn planModeledAllocFrom(
        self: *Prepared,
        allocator: std.mem.Allocator,
        start: usize,
        model: lz77.OptimalCostModel,
    ) !lz77.GreedyPlan {
        if (start > self.input.len) return error.InvalidBlockPlan;
        try self.validateModel(model);
        return self.solve(allocator, true, model, start);
    }

    fn validateModel(self: *const Prepared, model: lz77.OptimalCostModel) !void {
        if (model.distance.len <= self.options.window_len) return error.InvalidBlockPlan;
        for (model.literal) |cost| if (cost == 0) return error.InvalidBlockPlan;
        for (model.length[3..]) |cost| if (cost == 0) return error.InvalidBlockPlan;
        var start: usize = 1;
        for (class_ends) |end| {
            const stop = @min(end, self.options.window_len);
            if (start > stop) break;
            const cost = model.distance[start];
            if (cost == 0) return error.InvalidBlockPlan;
            for (model.distance[start .. stop + 1]) |other| {
                if (cost != other) return error.InvalidBlockPlan;
            }
            start = stop + 1;
        }
        // Every positive-u16 model at N<=65536 has a finite all-literal
        // suffix bound<=4294901760. The largest temporary match-edge sum
        // is (N-minimum)*maxLiteral+maxLength+maxDistance<=4294836225.
        // Both fit u32; narrowing accepts the same models as native costs.
        const max_literal: u32 = std.mem.max(u16, model.literal);
        const literal_bound = std.math.mul(u32, @intCast(self.input.len), max_literal) catch return error.InvalidBlockPlan;
        if (literal_bound == std.math.maxInt(u32)) return error.InvalidBlockPlan;
        const minimum = @max(3, @min(@max(3, @min(258, self.options.max_match)), self.options.min_match));
        const suffix_bound = std.math.mul(u32, @intCast(self.input.len - minimum), max_literal) catch return error.InvalidBlockPlan;
        const edge_bound = @as(u32, std.mem.max(u16, model.length[minimum..])) +
            std.mem.max(u16, model.distance[1 .. self.options.window_len + 1]);
        _ = std.math.add(u32, suffix_bound, edge_bound) catch return error.InvalidBlockPlan;
    }

    fn solve(self: *Prepared, allocator: std.mem.Allocator, comptime modeled: bool, model: if (modeled) lz77.OptimalCostModel else void, start: usize) !lz77.GreedyPlan {
        const input = self.input;
        const minimum = @max(3, @min(@max(3, @min(258, self.options.max_match)), self.options.min_match));
        var best_costs: [259]u32 = undefined;
        var best_lengths: [259]u16 = undefined;
        self.costs[input.len] = 0;
        var position = input.len;
        var cursor = self.records.items.len;
        while (position > start) {
            position -= 1;
            const literal_cost: u32 = if (modeled) model.literal[input[position]] else if (input[position] < 144) 8 else 9;
            self.costs[position] = literal_cost + self.costs[position + 1];
            self.steps[position] = .{ .literal = input[position] };
            var built = minimum - 1;
            var prefix_cost: u32 = std.math.maxInt(u32);
            var prefix_length: u16 = 0;
            const end = cursor;
            cursor -= self.counts[position];
            for (self.records.items[cursor..end]) |word| {
                const match = unpack(word);
                while (built < match.length) {
                    built += 1;
                    const length_cost: u32 = if (modeled) model.length[built] else @intCast(lz77.fixedLengthCost(built));
                    const cost = length_cost + self.costs[position + built];
                    // Equal length-edge costs choose the longer match.
                    if (cost <= prefix_cost) {
                        prefix_cost = cost;
                        prefix_length = @intCast(built);
                    }
                    best_costs[built] = prefix_cost;
                    best_lengths[built] = prefix_length;
                }
                const distance_cost: u32 = if (modeled) model.distance[match.distance] else @intCast(lz77.fixedDistanceCost(match.distance));
                const cost = best_costs[match.length] + distance_cost;
                if (cost < self.costs[position]) {
                    self.costs[position] = cost;
                    self.steps[position] = .{ .match = .{ .length = best_lengths[match.length], .distance = match.distance } };
                }
            }
        }
        var tokens: std.ArrayList(lz77.Token) = .empty;
        errdefer tokens.deinit(allocator);
        var stats: lz77.PlanStats = .{};
        position = start;
        while (position < input.len) {
            const token = self.steps[position];
            try tokens.append(allocator, token);
            switch (token) {
                .literal => {
                    stats.literals += 1;
                    position += 1;
                },
                .match => |match| {
                    stats.matches += 1;
                    stats.matched_bytes += match.length;
                    position += match.length;
                },
            }
        }
        return .{ .tokens = try tokens.toOwnedSlice(allocator), .stats = stats };
    }
};
