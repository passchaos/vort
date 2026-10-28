//! Score a complete cluster map or reject it before its remaining trees.
//! The caller publishes only complete results; exact tree scores are
//! nonnegative and remain owned by the caller's scorer/cache.
//! The complete sum must fit u64; codec callers bound it by their literal
//! count, maximum code width, and fixed maximum of sixty-four tree headers.
const std = @import("std");

pub fn evaluate(comptime prune: bool, initial_bits: u64, threshold: u64, tree_count: usize, scorer: anytype) !?u64 {
    var bits = initial_bits;
    for (0..tree_count) |tree| {
        // A strict inequality retains equality at both the savings gate and
        // incumbent boundary. No check after the final tree discards an exact
        // value that can be published for a later, looser threshold.
        if (prune and bits > threshold) return null;
        bits += try scorer.score(tree);
    }
    return bits;
}

const Fixture = struct {
    costs: []const u64,
    calls: usize = 0,
    fail_at: ?usize = null,

    pub fn score(self: *@This(), tree: usize) error{SyntheticFailure}!u64 {
        std.debug.assert(tree == self.calls);
        self.calls += 1;
        if (self.fail_at == tree) return error.SyntheticFailure;
        return self.costs[tree];
    }
};

test "cluster partial score preserves equality and complete cache values" {
    const costs = [_]u64{ 12, 19, 0, 23 };
    var first: Fixture = .{ .costs = &costs };
    try std.testing.expectEqual(@as(?u64, null), try evaluate(true, 10, 21, costs.len, &first));
    try std.testing.expectEqual(@as(usize, 1), first.calls);
    var tied: Fixture = .{ .costs = &costs };
    try std.testing.expectEqual(@as(?u64, null), try evaluate(true, 10, 22, costs.len, &tied));
    try std.testing.expectEqual(@as(usize, 2), tied.calls);
    // Once the final tree is scored, the result is complete even when over
    // threshold; its caller may safely cache it for future requests.
    var completed: Fixture = .{ .costs = &costs };
    try std.testing.expectEqual(@as(?u64, 64), try evaluate(true, 10, 41, costs.len, &completed));
    try std.testing.expectEqual(costs.len, completed.calls);
    var reference: Fixture = .{ .costs = &costs };
    try std.testing.expectEqual(@as(?u64, 64), try evaluate(false, 10, 0, costs.len, &reference));
    try std.testing.expectEqual(costs.len, reference.calls);
}

test "cluster partial score skips only provably irrelevant scorer failures" {
    const costs = [_]u64{ 12, 19, 23 };
    var skipped: Fixture = .{ .costs = &costs, .fail_at = 1 };
    try std.testing.expectEqual(@as(?u64, null), try evaluate(true, 10, 21, costs.len, &skipped));
    try std.testing.expectEqual(@as(usize, 1), skipped.calls);
    var reached: Fixture = .{ .costs = &costs, .fail_at = 1 };
    try std.testing.expectError(error.SyntheticFailure, evaluate(true, 10, 22, costs.len, &reached));
    var exhaustive: Fixture = .{ .costs = &costs, .fail_at = 1 };
    try std.testing.expectError(error.SyntheticFailure, evaluate(false, 10, 0, costs.len, &exhaustive));
}

test "cluster partial score agrees with complete sums and first exceeding prefixes" {
    var state: u32 = 0x243f6a88;
    var costs: [64]u64 = undefined;
    for (1..65) |count| {
        var complete: u64 = 17;
        for (costs[0..count]) |*cost| {
            state = state *% 1664525 +% 1013904223;
            cost.* = state >> 24;
            complete += cost.*;
        }
        for (0..count) |prefix_count| {
            var prefix: u64 = 17;
            for (costs[0..prefix_count]) |cost| prefix += cost;
            for ([_]u64{ prefix -| 1, prefix, prefix + 1, complete }) |threshold| {
                var scorer: Fixture = .{ .costs = costs[0..count] };
                const result = try evaluate(true, 17, threshold, count, &scorer);
                if (result) |value| {
                    try std.testing.expectEqual(complete, value);
                    try std.testing.expectEqual(count, scorer.calls);
                } else {
                    try std.testing.expect(scorer.calls < count);
                    var known: u64 = 17;
                    for (costs[0..scorer.calls]) |cost| known += cost;
                    try std.testing.expect(known > threshold);
                    if (scorer.calls != 0) {
                        try std.testing.expect(known - costs[scorer.calls - 1] <= threshold);
                    }
                }
            }
        }
    }
}
