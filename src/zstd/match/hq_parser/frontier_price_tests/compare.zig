const std = @import("std");
const state = @import("../state.zig");
const rep = @import("../rep.zig");
const prices = @import("../prices.zig");
const Budget = @import("../price_budget.zig").PriceBudget;
const Profile = @import("../../../encode/controls.zig").Profile;
const models = @import("../known_ml_tests/models.zig");
const oracle = @import("oracle.zig");

pub const Metrics = struct { first_calls: usize = 0, replay_calls: usize = 0, errors: usize = 0 };
pub const Case = struct {
    model: prices.EntropyModel,
    node: state.Node,
    choice: rep.Choice,
    lengths: []const usize,
    position: usize = 4095,
    limit: ?u64 = null,
    admitted: u64 = 0,
    instrument: bool = true,
    profile_seed: Profile = .{ .price_evaluations = 7, .optimal_transitions = 13, .price_limit_refusals = 2, .raw_blocks = 9 },
};

fn profileEqual(actual: Profile, expected: Profile) !void {
    var comparable = actual;
    inline for (.{ "frontier_choice_preparations", "frontier_choice_replays", "frontier_unprepared_edges" }) |field|
        @field(comparable, field) = @field(expected, field);
    try std.testing.expectEqualDeep(expected, comparable);
}

pub fn run(comptime Helper: type, case: Case, metrics: *Metrics) !void {
    try case.model.validate();
    const old = models.freeze(case.model);
    const saved_model = case.model;
    const saved_node = case.node;
    const saved_choice = case.choice;
    var actual_profile = case.profile_seed;
    var expected_profile = case.profile_seed;
    var actual_budget = Budget.init(case.limit, if (case.instrument) &actual_profile else null);
    var expected_budget = Budget.init(case.limit, if (case.instrument) &expected_profile else null);
    actual_budget.admitted = case.admitted;
    expected_budget.admitted = case.admitted;
    const parameters: state.Parameters = .{ .strategy = .btultra, .entropy = &case.model, .profile = if (case.instrument) &actual_profile else null };
    const old_parameters: oracle.Parameters = .{ .entropy = &old, .profile = if (case.instrument) &expected_profile else null };
    var published: ?Helper.Prepared = null;
    var prepares: usize = 0;
    var replays: usize = 0;
    for (case.lengths) |length| {
        const before = actual_budget.admitted;
        const expected = oracle.pricedNode(old_parameters, &expected_budget, case.node, case.position, length, case.choice);
        var actual: ?state.Node = null;
        var actual_error: ?anyerror = null;
        if (published) |memo| {
            metrics.replay_calls += 1;
            actual = Helper.replay(parameters, &actual_budget, case.node, case.position, length, case.choice, memo) catch |err| blk: {
                actual_error = err;
                break :blk null;
            };
            if (actual_budget.admitted != before) replays += 1;
        } else {
            metrics.first_calls += 1;
            if (Helper.first(parameters, &actual_budget, case.node, case.position, length, case.choice)) |result| {
                actual = result.node;
                // No preparation becomes visible unless the original full
                // price and complete next-node construction have succeeded.
                published = result.prepared;
                prepares += 1;
                const sequence = try old.sequencePrice(case.node.literal_len, length, case.choice.offset_value);
                const match = try oracle.Old.matchSymbol(length);
                const ml = old.ml_prices[match.code] + @as(u32, match.extra_bits) * oracle.Old.scale;
                try std.testing.expectEqual(case.node.cost - try oracle.literalLengthPrice(&old, case.node.literal_len), result.prepared.closed_cost);
                try std.testing.expectEqual(sequence - ml, result.prepared.sequence_base);
                try std.testing.expectEqual(try oracle.literalLengthPrice(&old, 0), result.prepared.literal_zero);
            } else |err| actual_error = err;
        }
        if (expected) |node| {
            try std.testing.expectEqual(@as(?anyerror, null), actual_error);
            try std.testing.expectEqualDeep(node, actual.?);
        } else |err| {
            metrics.errors += 1;
            try std.testing.expectEqual(@as(?anyerror, err), actual_error);
            try std.testing.expect(actual == null);
        }
        try std.testing.expectEqual(expected_budget.limit, actual_budget.limit);
        try std.testing.expectEqual(expected_budget.admitted, actual_budget.admitted);
        if (case.limit) |limit| try std.testing.expectEqual(limit -| expected_budget.admitted, limit -| actual_budget.admitted);
        try profileEqual(actual_profile, expected_profile);
        if (case.instrument) {
            try std.testing.expectEqual(case.profile_seed.frontier_choice_preparations +| prepares, actual_profile.frontier_choice_preparations);
            try std.testing.expectEqual(case.profile_seed.frontier_choice_replays +| replays, actual_profile.frontier_choice_replays);
            try std.testing.expectEqual(case.profile_seed.frontier_unprepared_edges, actual_profile.frontier_unprepared_edges);
        }
    }
    actual_budget.finish();
    expected_budget.finish();
    try profileEqual(actual_profile, expected_profile);
    try std.testing.expectEqualDeep(saved_model, case.model);
    try std.testing.expectEqualDeep(saved_node, case.node);
    try std.testing.expectEqualDeep(saved_choice, case.choice);
}
