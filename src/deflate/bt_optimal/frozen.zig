//! Isolated DEFLATE-only prototype: a forward three-byte hash binary tree
//! materializes one longest visited match per RFC 1951 distance cost class.
//! Equal-length evidence keeps the nearest distance. This is a different
//! matcher from the generic hash-chain optimal parser, not a wire-exact cache.
const std = @import("std");
const lz77 = @import("../../lz77.zig");

pub const min_input_len = 4096;
pub const max_input_len = 65536;
pub const coverage_threshold: usize = 258;
pub const empty: u16 = 65535;
pub const hash_size = 1 << 15;
pub const class_ends = [_]u16{
    1,    2,    3,    4,    6,    8,    12,    16,    24,    32,
    48,   64,   96,   128,  192,  256,  384,   512,   768,   1024,
    1536, 2048, 3072, 4096, 6144, 8192, 12288, 16384, 24576, 32768,
};

// 8 bits encode length minus three (3...258), 15 encode distance minus one
// (1...32768). Upper bits are zero; every record occupies exactly four bytes.
pub fn pack(length: u16, distance: u16) u32 {
    std.debug.assert(length >= 3 and length <= 258);
    std.debug.assert(distance >= 1 and distance <= 32768);
    return (@as(u32, length - 3) << 15) | (distance - 1);
}
pub fn unpack(word: u32) lz77.Token.Match {
    return .{ .length = @intCast((word >> 15) + 3), .distance = @intCast((word & 32767) + 1) };
}
pub fn distanceClass(distance: usize) usize {
    std.debug.assert(distance > 0 and distance <= 32768);
    if (distance <= 4) return distance - 1;
    const log: usize = std.math.log2_int(usize, distance - 1);
    return log * 2 + @as(usize, ((distance - 1) >> @intCast(log - 1)) & 1);
}
pub fn hashAt(input: []const u8, position: usize) usize {
    const word = @as(u32, input[position]) | (@as(u32, input[position + 1]) << 8) |
        (@as(u32, input[position + 2]) << 16);
    return (word *% 0x1e35_a7bd) >> 17;
}

// Portable extension from an already proven common prefix. Little-endian
// reads put the first mismatching byte at the least significant set bit.
// Both 8-byte reads are bounded by the current suffix maximum; the older
// candidate has at least as many available input bytes as the current suffix.
pub fn extendPortable(input: []const u8, candidate: usize, position: usize, start: usize, maximum: usize) usize {
    var length = start;
    while (maximum - length >= 8) : (length += 8) {
        const difference = std.mem.readInt(u64, input[candidate + length ..][0..8], .little) ^
            std.mem.readInt(u64, input[position + length ..][0..8], .little);
        if (difference != 0) return length + @ctz(difference) / 8;
    }
    while (length < maximum and input[candidate + length] == input[position + length]) : (length += 1) {}
    return length;
}

pub const Tree = struct {
    roots: []u16,
    children: [][2]u16,

    pub fn init(allocator: std.mem.Allocator, len: usize) !Tree {
        const roots = try allocator.alloc(u16, hash_size);
        errdefer allocator.free(roots);
        const children = try allocator.alloc([2]u16, len);
        @memset(roots, empty);
        // Every inserted node's two children are assigned before later use.
        return .{ .roots = roots, .children = children };
    }
    pub fn deinit(self: Tree, allocator: std.mem.Allocator) void {
        allocator.free(self.roots);
        allocator.free(self.children);
    }

    pub fn advance(
        self: *Tree,
        input: []const u8,
        position: usize,
        maximum: usize,
        minimum: usize,
        window: usize,
        depth_limit: usize,
        candidate_limit: usize,
        lengths: *[30]u16,
        distances: *[30]u16,
    ) void {
        const hash = hashAt(input, position);
        var node = self.roots[hash];
        self.roots[hash] = @intCast(position);
        var pending_lt = &self.children[position][0];
        var pending_gt = &self.children[position][1];
        var lt_prefix: usize = 0;
        var gt_prefix: usize = 0;
        var depth: usize = 0;
        var candidates: usize = 0;
        while (node != empty and depth < depth_limit and candidates < candidate_limit) : (depth += 1) {
            const candidate: usize = node;
            std.debug.assert(candidate < position);
            const distance = position - candidate;
            // The tree is a treap with newer positions above older positions.
            // An expired root therefore has no in-window descendants.
            if (distance > window) break;
            // Earlier comparisons establish both shared prefixes. Hash
            // equality alone never establishes even one matching byte.
            var length = @min(lt_prefix, gt_prefix);
            length = extendPortable(input, candidate, position, length, maximum);
            if (length >= minimum) {
                candidates += 1;
                const cls = distanceClass(distance);
                if (length > lengths[cls] or (length == lengths[cls] and distance < distances[cls])) {
                    lengths[cls] = @intCast(length);
                    distances[cls] = @intCast(distance);
                }
            }
            if (length == maximum) {
                pending_lt.* = self.children[candidate][0];
                pending_gt.* = self.children[candidate][1];
                return;
            }
            if (input[candidate + length] < input[position + length]) {
                pending_lt.* = node;
                pending_lt = &self.children[candidate][1];
                node = pending_lt.*;
                lt_prefix = length;
            } else {
                pending_gt.* = node;
                pending_gt = &self.children[candidate][0];
                node = pending_gt.*;
                gt_prefix = length;
            }
        }
        // A depth-limited split discards deeper evidence and subtrees. Search
        // budgets count raw BT nodes, including hash collisions.
        pending_lt.* = empty;
        pending_gt.* = empty;
    }
};

pub const Prepared = struct {
    input: []const u8,
    options: lz77.GreedyOptions,
    counts: []u8 = &.{},
    records: std.ArrayList(u32) = .empty,
    costs: []usize = &.{},
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
        result.costs = try allocator.alloc(usize, input.len + 1);
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

    pub fn evidenceAt(self: *const Prepared, position: usize) []const u32 {
        // Diagnostic random access only. Production solves consume counts
        // and records backwards with a single cursor, without an offset table.
        var start: usize = 0;
        for (self.counts[0..position]) |count| start += count;
        return self.records.items[start .. start + self.counts[position]];
    }

    pub fn planFixedAlloc(self: *Prepared, allocator: std.mem.Allocator) !lz77.GreedyPlan {
        return self.solve(allocator, false, undefined);
    }

    pub fn planModeledAlloc(self: *Prepared, allocator: std.mem.Allocator, model: lz77.OptimalCostModel) !lz77.GreedyPlan {
        try self.validateModel(model);
        return self.solve(allocator, true, model);
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
        // All-literal suffixes provide a finite upper bound for each DP node.
        // A match edge can only land at <=N-minimum, even at natural N=65536.
        const max_literal = std.mem.max(u16, model.literal);
        _ = std.math.mul(usize, self.input.len, max_literal) catch return error.InvalidBlockPlan;
        const minimum = @max(3, @min(@max(3, @min(258, self.options.max_match)), self.options.min_match));
        const suffix_bound = std.math.mul(usize, self.input.len - minimum, max_literal) catch return error.InvalidBlockPlan;
        const edge_bound = @as(usize, std.mem.max(u16, model.length[minimum..])) +
            std.mem.max(u16, model.distance[1 .. self.options.window_len + 1]);
        _ = std.math.add(usize, suffix_bound, edge_bound) catch return error.InvalidBlockPlan;
    }

    fn solve(self: *Prepared, allocator: std.mem.Allocator, comptime modeled: bool, model: if (modeled) lz77.OptimalCostModel else void) !lz77.GreedyPlan {
        const input = self.input;
        const minimum = @max(3, @min(@max(3, @min(258, self.options.max_match)), self.options.min_match));
        var best_costs: [259]usize = undefined;
        var best_lengths: [259]u16 = undefined;
        self.costs[input.len] = 0;
        var position = input.len;
        var cursor = self.records.items.len;
        while (position > 0) {
            position -= 1;
            const literal_cost: usize = if (modeled) model.literal[input[position]] else if (input[position] < 144) 8 else 9;
            self.costs[position] = literal_cost + self.costs[position + 1];
            self.steps[position] = .{ .literal = input[position] };
            var built = minimum - 1;
            var prefix_cost: usize = std.math.maxInt(usize);
            var prefix_length: u16 = 0;
            const end = cursor;
            cursor -= self.counts[position];
            for (self.records.items[cursor..end]) |word| {
                const match = unpack(word);
                while (built < match.length) {
                    built += 1;
                    const length_cost: usize = if (modeled) model.length[built] else lz77.fixedLengthCost(built);
                    const cost = length_cost + self.costs[position + built];
                    // Equal length-edge costs choose the longer match.
                    if (cost <= prefix_cost) {
                        prefix_cost = cost;
                        prefix_length = @intCast(built);
                    }
                    best_costs[built] = prefix_cost;
                    best_lengths[built] = prefix_length;
                }
                const distance_cost: usize = if (modeled) model.distance[match.distance] else lz77.fixedDistanceCost(match.distance);
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
        position = 0;
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
