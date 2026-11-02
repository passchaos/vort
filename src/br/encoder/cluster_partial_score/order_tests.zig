//! Independent selection-order and exact partial-score oracle. Totals are
//! scheduling hints only; mapped costs and reached errors remain authoritative.
const std = @import("std");

const max_trees = 64;
const byte_poison: u8 = 0xd3;
const value_poison: u64 = 0xf1f2_f3f4_f5f6_f7f8;

const Coverage = struct {
    orders: usize = 0,
    evaluations: usize = 0,
    completed: usize = 0,
    pruned: usize = 0,
    reached_errors: usize = 0,
    skipped_errors: usize = 0,
};

/// Pick the largest unused total from scratch each round. Ascending ID scans
/// retain the first ID on equality; no insertion or production sort is used.
fn selectionOracle(totals: []const u32) [max_trees]u8 {
    var used: [max_trees]bool = @splat(false);
    var result: [max_trees]u8 = undefined;
    for (0..totals.len) |position| {
        var best: ?usize = null;
        for (totals, 0..) |total, id| {
            if (used[id]) continue;
            if (best == null or total > totals[best.?]) best = id;
        }
        result[position] = @intCast(best.?);
        used[best.?] = true;
    }
    return result;
}

fn compareOrder(comptime Codec: type, totals: []const u32, coverage: *Coverage) ![max_trees]u8 {
    var before: [max_trees]u32 = undefined;
    @memcpy(before[0..totals.len], totals);
    const expected = selectionOracle(totals);
    const actual = Codec.descendingTotalOrder(totals);
    try std.testing.expectEqualSlices(u8, expected[0..totals.len], actual[0..totals.len]);
    try std.testing.expectEqualSlices(u32, before[0..totals.len], totals);

    // The production result's inactive suffix is undefined by contract. Copy
    // only its active prefix into controlled poisoned storage for later use.
    var controlled: [max_trees]u8 = @splat(byte_poison);
    @memcpy(controlled[0..totals.len], actual[0..totals.len]);
    var seen: [max_trees]bool = @splat(false);
    for (controlled[0..totals.len], 0..) |id, position| {
        try std.testing.expect(id < totals.len and !seen[id]);
        seen[id] = true;
        if (position != 0) {
            const previous = controlled[position - 1];
            try std.testing.expect(totals[previous] >= totals[id]);
            if (totals[previous] == totals[id]) try std.testing.expect(previous < id);
        }
    }
    for (controlled[totals.len..]) |byte| try std.testing.expectEqual(byte_poison, byte);
    coverage.orders += 1;
    return controlled;
}

fn sortingCases(comptime Codec: type, coverage: *Coverage) !void {
    var random = std.Random.DefaultPrng.init(0x7138_6f72_6465_7201);
    var totals: [max_trees]u32 = undefined;
    for (0..max_trees + 1) |count| {
        for (0..7) |pattern| {
            @memset(&totals, 0xcafe_babe);
            for (totals[0..count], 0..) |*total, id| {
                total.* = switch (pattern) {
                    0 => 0,
                    1 => std.math.maxInt(u32),
                    2 => @intCast(id),
                    3 => @intCast(count - id),
                    4 => @intCast(id % 5),
                    5 => if (id & 1 == 0) std.math.maxInt(u32) else 1,
                    else => random.random().int(u32),
                };
            }
            const before = totals;
            _ = try compareOrder(Codec, totals[0..count], coverage);
            try std.testing.expectEqualSlices(u32, &before, &totals);
        }
    }
}

const MappedScorer = struct {
    costs: []const u64,
    order: []const u8,
    fail_id: ?u8 = null,
    calls: usize = 0,
    requests: [max_trees + 2]u8 = @splat(byte_poison),
    values: [max_trees + 2]u64 = @splat(value_poison),

    pub fn score(self: *MappedScorer, position: usize) error{ ScoreFailure, InvalidRequest }!u64 {
        if (position != self.calls or position >= self.order.len) return error.InvalidRequest;
        const id = self.order[position];
        if (id >= self.costs.len) return error.InvalidRequest;
        self.requests[self.calls + 1] = id;
        self.calls += 1;
        if (self.fail_id == id) return error.ScoreFailure;
        self.values[id + 1] = self.costs[id];
        return self.costs[id];
    }
};

const Outcome = struct {
    kind: enum { completed, pruned, failed },
    calls: usize,
    sum: u64,
};

/// Build every exact prefix first, then locate a rejecting prefix and a
/// reached failure independently. A final over-threshold sum is complete.
fn evaluationOracle(comptime prune: bool, initial: u64, threshold: u64, costs: []const u64, order: []const u8, fail_id: ?u8) Outcome {
    var prefixes: [max_trees + 1]u128 = undefined;
    prefixes[0] = initial;
    for (order, 0..) |id, position| prefixes[position + 1] = prefixes[position] + costs[id];
    std.debug.assert(prefixes[order.len] <= std.math.maxInt(u64));
    var limit = order.len;
    if (prune) {
        for (prefixes[0..order.len], 0..) |prefix, position| {
            if (prefix > threshold) {
                limit = position;
                break;
            }
        }
    }
    if (fail_id) |failed| {
        for (order[0..limit], 0..) |id, position| {
            if (id == failed) return .{ .kind = .failed, .calls = position + 1, .sum = @intCast(prefixes[position]) };
        }
    }
    return .{
        .kind = if (limit == order.len) .completed else .pruned,
        .calls = limit,
        .sum = @intCast(prefixes[limit]),
    };
}

fn compareEvaluation(comptime Codec: type, comptime prune: bool, initial: u64, threshold: u64, costs: []const u64, order: []const u8, fail_id: ?u8, coverage: *Coverage) !void {
    var costs_before: [max_trees]u64 = undefined;
    var order_before: [max_trees]u8 = undefined;
    @memcpy(costs_before[0..costs.len], costs);
    @memcpy(order_before[0..order.len], order);
    const expected = evaluationOracle(prune, initial, threshold, costs, order, fail_id);
    var scorer: MappedScorer = .{ .costs = costs, .order = order, .fail_id = fail_id };
    const result = Codec.evaluate(prune, initial, threshold, costs.len, &scorer);
    var published = value_poison;
    var publication_count: usize = 0;
    if (result) |complete| {
        if (complete) |sum| {
            published = sum;
            publication_count += 1;
        }
    } else |_| {}
    switch (expected.kind) {
        .completed => {
            try std.testing.expectEqual(@as(?u64, expected.sum), try result);
            try std.testing.expectEqual(expected.sum, published);
            try std.testing.expectEqual(@as(usize, 1), publication_count);
            try std.testing.expectEqual(costs.len, scorer.calls);
            coverage.completed += 1;
        },
        .pruned => {
            try std.testing.expectEqual(@as(?u64, null), try result);
            try std.testing.expectEqual(value_poison, published);
            try std.testing.expectEqual(@as(usize, 0), publication_count);
            try std.testing.expect(expected.sum > threshold);
            try std.testing.expect(scorer.calls < costs.len);
            coverage.pruned += 1;
            if (fail_id != null) coverage.skipped_errors += 1;
        },
        .failed => {
            try std.testing.expectError(error.ScoreFailure, result);
            try std.testing.expectEqual(value_poison, published);
            try std.testing.expectEqual(@as(usize, 0), publication_count);
            coverage.reached_errors += 1;
        },
    }
    try std.testing.expectEqual(expected.calls, scorer.calls);
    var expected_requests: [max_trees + 2]u8 = @splat(byte_poison);
    var expected_values: [max_trees + 2]u64 = @splat(value_poison);
    for (order[0..expected.calls], 0..) |id, position| {
        expected_requests[position + 1] = id;
        if (expected.kind == .failed and position + 1 == expected.calls) continue;
        expected_values[id + 1] = costs[id];
    }
    // Unrequested active entries and every inactive entry retain poison. The
    // first/last elements are guards for ID-mapped values and request slots.
    try std.testing.expectEqualSlices(u8, &expected_requests, &scorer.requests);
    try std.testing.expectEqualSlices(u64, &expected_values, &scorer.values);
    try std.testing.expectEqualSlices(u64, costs_before[0..costs.len], costs);
    try std.testing.expectEqualSlices(u8, order_before[0..order.len], order);
    coverage.evaluations += 1;
}

fn scoreMatrix(comptime Codec: type, coverage: *Coverage) !void {
    var random = std.Random.DefaultPrng.init(0x6373_636f_7265_0102);
    var costs: [max_trees]u64 = undefined;
    var totals: [max_trees]u32 = undefined;
    for (0..max_trees + 1) |count| {
        for (0..3) |pattern| {
            @memset(&costs, value_poison);
            @memset(&totals, 0xcafe_babe);
            var sum: u64 = 7;
            for (costs[0..count], totals[0..count], 0..) |*cost, *total, id| {
                cost.* = switch (pattern) {
                    0 => id % 4,
                    1 => ((count - id) % 11) * 37,
                    else => if (id == 0) 1 else 80 + id,
                };
                total.* = if (pattern == 2 and id == 0) std.math.maxInt(u32) else random.random().int(u32);
                sum += cost.*;
            }
            const totals_before = totals;
            const costs_before = costs;
            const scheduled = try compareOrder(Codec, totals[0..count], coverage);
            for (0..4) |permutation| {
                var order: [max_trees]u8 = @splat(byte_poison);
                for (order[0..count], 0..) |*id, position| {
                    id.* = switch (permutation) {
                        0 => @intCast(position),
                        1 => @intCast(count - 1 - position),
                        2 => scheduled[position],
                        else => @intCast((position + count / 2) % count),
                    };
                }
                const order_before = order;
                var middle: u64 = 7;
                for (order[0 .. count / 2]) |id| middle += costs[id];
                const thresholds = [_]u64{ 0, 6, 7, middle -| 1, middle, middle + 1, sum -| 1, sum, sum + 1 };
                for (thresholds) |threshold| {
                    try compareEvaluation(Codec, true, 7, threshold, costs[0..count], order[0..count], null, coverage);
                    try compareEvaluation(Codec, false, 7, threshold, costs[0..count], order[0..count], null, coverage);
                }
                if (count != 0) {
                    for ([_]u8{ order[0], order[count / 2], order[count - 1] }) |failed_id| {
                        for ([_]u64{ 0, middle, sum }) |threshold| {
                            try compareEvaluation(Codec, true, 7, threshold, costs[0..count], order[0..count], failed_id, coverage);
                            try compareEvaluation(Codec, false, 7, threshold, costs[0..count], order[0..count], failed_id, coverage);
                        }
                    }
                }
                try std.testing.expectEqualSlices(u8, &order_before, &order);
            }
            try std.testing.expectEqualSlices(u32, &totals_before, &totals);
            try std.testing.expectEqualSlices(u64, &costs_before, &costs);
        }
    }
}

fn explicitBoundaries(comptime Codec: type, coverage: *Coverage) !void {
    // Largest histogram: one symbol, negligible actual payload cost. Sorting
    // cannot turn its frequency total into a lower bound or reject this tie.
    const totals = [_]u32{ std.math.maxInt(u32), 10, 5 };
    const costs = [_]u64{ 1, 20, 3 };
    const order = try compareOrder(Codec, &totals, coverage);
    try compareEvaluation(Codec, true, 4, 28, &costs, order[0..costs.len], null, coverage);
    // Equality immediately before the final score retains the complete sum
    // of 28, even though it exceeds this request's threshold of 25.
    try compareEvaluation(Codec, true, 4, 25, &costs, order[0..costs.len], null, coverage);
    try compareEvaluation(Codec, true, 4, 24, &costs, order[0..costs.len], 2, coverage);
    try compareEvaluation(Codec, true, 4, 25, &costs, order[0..costs.len], 2, coverage);
    const zero_costs = [_]u64{ 12, 0, 8 };
    const identity = [_]u8{ 0, 1, 2 };
    // C reaches 17, a zero-cost tree keeps equality, then the final tree
    // crosses the threshold. All three trees and the full sum 25 survive.
    try compareEvaluation(Codec, true, 5, 17, &zero_costs, &identity, null, coverage);
    const wide_costs = [_]u64{ std.math.maxInt(u64) - 10, 1, 2 };
    for ([_]u64{ 0, std.math.maxInt(u64) - 5, std.math.maxInt(u64) }) |threshold| {
        try compareEvaluation(Codec, true, 3, threshold, &wide_costs, order[0..wide_costs.len], null, coverage);
        try compareEvaluation(Codec, false, 3, threshold, &wide_costs, order[0..wide_costs.len], null, coverage);
    }
}

fn crossModeSlots(comptime Codec: type, coverage: *Coverage) !void {
    const costs = [_]u64{ 1, 20, 3 };
    const orders = [_][3]u8{ .{ 0, 1, 2 }, .{ 2, 0, 1 }, .{ 1, 2, 0 } };
    for (orders, 0..) |order, index| {
        try compareEvaluation(Codec, true, 4, 25, &costs, &order, null, coverage);
        var scorer: MappedScorer = .{ .costs = &costs, .order = &order };
        const result = try Codec.evaluate(true, 4, 25, costs.len, &scorer);
        var mode_best: u64 = 40;
        var published = value_poison;
        if (result) |complete| {
            try std.testing.expectEqual(@as(u64, 28), complete);
            try std.testing.expectEqual(costs.len, scorer.calls);
            published = complete;
            mode_best = @min(mode_best, complete);
        }
        // The local candidate can beat 40 and still lose to another mode's
        // 25. Earlier rejection of that candidate preserves the outer winner.
        try std.testing.expectEqual(@as(u64, 25), @min(@as(u64, 25), mode_best));
        if (index < 2) {
            try std.testing.expectEqual(@as(u64, 28), mode_best);
            try std.testing.expectEqual(@as(u64, 28), published);
        } else {
            try std.testing.expectEqual(@as(?u64, null), result);
            try std.testing.expectEqual(value_poison, published);
        }
    }
}

fn smallPermutations(comptime Codec: type, coverage: *Coverage) !void {
    const costs = [_]u64{ 0, 3, 50, 1 };
    for (0..4) |a| {
        for (0..4) |b| {
            if (b == a) continue;
            for (0..4) |c| {
                if (c == a or c == b) continue;
                const d = 6 - a - b - c;
                const order = [_]u8{ @intCast(a), @intCast(b), @intCast(c), @intCast(d) };
                for ([_]u64{ 2, 13, 56 }) |threshold| {
                    try compareEvaluation(Codec, true, 2, threshold, &costs, &order, null, coverage);
                    try compareEvaluation(Codec, false, 2, threshold, &costs, &order, null, coverage);
                }
                for (0..4) |failed_id| {
                    try compareEvaluation(Codec, true, 2, 13, &costs, &order, @intCast(failed_id), coverage);
                    try compareEvaluation(Codec, false, 2, 13, &costs, &order, @intCast(failed_id), coverage);
                }
            }
        }
    }
}

fn comptimeCases(comptime Codec: type) !void {
    const totals = [_]u32{ 0, std.math.maxInt(u32), 7, std.math.maxInt(u32), 7, 0, 8, std.math.maxInt(u32) };
    const sorted = comptime Codec.descendingTotalOrder(&totals);
    try std.testing.expectEqualSlices(u8, &.{ 1, 3, 7, 6, 2, 4, 0, 5 }, sorted[0..totals.len]);
    const complete = comptime blk: {
        const costs = [_]u64{ 1, 23, 0, 11 };
        const ordered_totals = [_]u32{ std.math.maxInt(u32), 1, 9, 1 };
        const order = Codec.descendingTotalOrder(&ordered_totals);
        var scorer: MappedScorer = .{ .costs = &costs, .order = order[0..costs.len] };
        const result = Codec.evaluate(true, 7, 31, costs.len, &scorer) catch @compileError("comptime scoring failed");
        if (result == null or result.? != 42 or scorer.calls != costs.len) @compileError("comptime complete sum was pruned");
        break :blk result.?;
    };
    try std.testing.expectEqual(@as(u64, 42), complete);
}

pub fn check(comptime Codec: type) !void {
    var coverage: Coverage = .{};
    try sortingCases(Codec, &coverage);
    try scoreMatrix(Codec, &coverage);
    try explicitBoundaries(Codec, &coverage);
    try crossModeSlots(Codec, &coverage);
    try smallPermutations(Codec, &coverage);
    try comptimeCases(Codec);
    try std.testing.expect(coverage.completed != 0 and coverage.pruned != 0);
    try std.testing.expect(coverage.reached_errors != 0 and coverage.skipped_errors != 0);
    std.debug.print("q8_order sort_cases={d} evaluations={d} complete={d} pruned={d} reached_errors={d} skipped_errors={d}\n", .{
        coverage.orders, coverage.evaluations, coverage.completed, coverage.pruned, coverage.reached_errors, coverage.skipped_errors,
    });
}
