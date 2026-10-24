const std = @import("std");
const hq = @import("../hq_parser.zig");
const controls = @import("../../encode/controls.zig");
const state = @import("state.zig");
const edges = @import("search_edges.zig");
const PriceBudget = @import("price_budget.zig").PriceBudget;
const replay = @import("lazy2_tests.zig").replay;
const a = std.testing.allocator;

test "Zstd HQ search complete prices every legal candidate length and exact offset alias" {
    const count: usize = 101;
    const nodes = try a.alloc(state.WholeNode, count * 8);
    defer a.free(nodes);
    @memset(nodes, .{});
    const repeats: hq.rep.Repeats = .{ 8, 8, 16 };
    const origin: state.WholeNode = .{ .cost = 0, .literal_len = 1, .repeats = repeats };
    nodes[0] = origin;
    var profile: controls.Profile = .{};
    var budget = PriceBudget.init(null, &profile);
    const parameters: hq.Parameters = .{ .strategy = .btopt, .hq_options = .{ .parse_mode = .whole_block, .match_lengths = .complete }, .profile = &profile };
    var context: edges.Context(true, true) = .{ .nodes = nodes, .width = 8, .base = 0, .goal = count - 1, .parameters = parameters, .price_budget = &budget };
    try context.candidate(0, 0, origin, 8, 100);
    budget.finish();
    const choices = try hq.rep.choices(1, 8, repeats);
    try std.testing.expectEqual(@as(u64, 98 * choices.len), budget.admitted);
    try std.testing.expectEqual(budget.admitted, profile.price_evaluations);
    try std.testing.expectEqual(budget.admitted, profile.max_plan_price_evaluations);
    try std.testing.expectEqual(@as(usize, 100), profile.max_match_length_considered);
    for (3..101) |length| {
        const first = nodes[length * 8];
        try std.testing.expect(first.cost != std.math.maxInt(u64));
        try std.testing.expectEqual(@as(u32, @intCast(length)), first.match_len);
        try std.testing.expectEqual(@as(usize, 8), first.distance);
    }
}

test "Zstd HQ search denied price admission precedes candidate work and keeps previous nodes" {
    var nodes: [11 * 8]state.WholeNode = @splat(.{});
    const origin: state.WholeNode = .{ .cost = 0, .literal_len = 1 };
    nodes[0] = origin;
    var profile: controls.Profile = .{};
    var budget = PriceBudget.init(1, &profile);
    const parameters: hq.Parameters = .{ .strategy = .btopt, .hq_options = .{ .parse_mode = .whole_block, .match_lengths = .complete }, .profile = &profile };
    var context: edges.Context(true, true) = .{ .nodes = &nodes, .width = 8, .base = 0, .goal = 10, .parameters = parameters, .price_budget = &budget };
    try std.testing.expectError(error.SearchLimitExceeded, context.candidate(0, 0, origin, 7, 10));
    budget.finish();
    try std.testing.expectEqual(@as(u64, 1), profile.price_evaluations);
    try std.testing.expectEqual(@as(u64, 1), profile.price_limit_refusals);
    try std.testing.expectEqual(@as(usize, 3), profile.max_match_length_considered);
    try std.testing.expect(nodes[3 * 8].cost != std.math.maxInt(u64));
    try std.testing.expectEqual(std.math.maxInt(u64), nodes[4 * 8].cost);
}

test "Zstd HQ search bounded complete compares cross horizon continuations at a common endpoint" {
    var nodes: [9 * 8]state.Node = @splat(.{});
    const origin: state.Node = .{ .cost = 0, .literal_len = 1 };
    nodes[6 * 8] = origin;
    var prefix: [21]u64 = undefined;
    for (&prefix, 0..) |*cost, index| cost.* = index * hq.prices.scale;
    var spill: edges.Spill = .{};
    var profile: controls.Profile = .{};
    var budget = PriceBudget.init(null, &profile);
    const parameters: hq.Parameters = .{ .strategy = .btopt, .hq_options = .{ .match_lengths = .complete }, .profile = &profile };
    var context: edges.Context(false, true) = .{ .nodes = &nodes, .width = 8, .base = 0, .goal = 8, .parameters = parameters, .price_budget = &budget, .literal_prefix = &prefix, .spill = &spill };
    try context.candidate(6, 0, origin, 7, 10);
    try std.testing.expectEqual(@as(usize, 16), spill.end_position);
    try std.testing.expectEqual(@as(u16, 6), spill.node.previous_position);
    try std.testing.expectEqual(@as(u32, 10), spill.node.match_len);
    try std.testing.expectEqual(@as(usize, 7), spill.node.distance);
    try std.testing.expectEqual(try hq.rep.resolve(1, spill.node.offset_value, origin.repeats), hq.rep.Choice{ .offset_value = spill.node.offset_value, .distance = spill.node.distance, .repeats = spill.node.repeats });
    try std.testing.expectEqual(spill.node.cost + 4 * hq.prices.scale, spill.continuation_cost);
    var limited = PriceBudget.init(0, &profile);
    context.price_budget = &limited;
    const before = spill;
    try std.testing.expectError(error.SearchLimitExceeded, context.candidate(6, 0, origin, 7, 10));
    try std.testing.expectEqual(before, spill);

    // Exercise that continuation through the real parser at its actual 4096
    // horizon. The unique final six-byte match starts at4094, where a clipped
    // bounded endpoint cannot hold even the minimum legal three-byte copy.
    var input: [4100]u8 = undefined;
    var random: u64 = 0x4094_6291;
    for (&input) |*byte| {
        random ^= random << 13;
        random ^= random >> 7;
        random ^= random << 17;
        byte.* = @intCast(random % 100);
    }
    const needle = [_]u8{ 200, 201, 202, 203, 204, 205 };
    @memcpy(input[0..6], &needle);
    @memcpy(input[4094..], &needle);
    var model: hq.EntropyModel = .{ .initialized = true };
    model.literal_prices = @splat(0);
    for (needle) |byte| model.literal_prices[byte] = 64 * hq.prices.scale;
    model.ll_prices = @splat(hq.prices.maximum_symbol_price);
    model.ml_prices = @splat(hq.prices.maximum_symbol_price);
    model.of_prices = @splat(hq.prices.maximum_symbol_price);
    model.ll_prices[30] = 0;
    model.ml_prices[3] = 0;
    model.of_prices[12] = 0;
    profile.reset();
    const source = hq.Source.init("", "", &input, 8192);
    const plan = try hq.planAlloc(a, source, .{ .strategy = .btopt, .hq_options = .{ .match_lengths = .complete, .search_depth = 1 }, .entropy = &model, .profile = &profile });
    defer plan.deinit(a);
    try std.testing.expectEqual(@as(usize, 1), plan.records.len);
    try std.testing.expectEqual(@as(usize, 4094), plan.records[0].literal_len);
    try std.testing.expectEqual(@as(usize, 6), plan.records[0].match_len);
    try std.testing.expectEqual(@as(usize, 4100), plan.records[0].match_end);
    try std.testing.expectEqual(@as(usize, 6), profile.max_match_length_considered);
    try std.testing.expectEqual(@as(usize, 4096), profile.max_parse_positions);
    try std.testing.expectEqual(@as(u64, 407 * hq.prices.scale), plan.estimated_cost);
    const decoded = try replay(a, source, plan, hq.rep.initial_repeats);
    defer a.free(decoded);
    try std.testing.expectEqualSlices(u8, &input, decoded);
}

test "Zstd HQ search whole complete tiny model matches independent exhaustive paths" {
    const source = hq.Source.init("abc", "", "abcabc", 1024);
    var model: hq.EntropyModel = .{};
    model.literal_prices = @splat(hq.prices.scale);
    model.ll_prices = @splat(0);
    model.ml_prices = @splat(0);
    model.of_prices = @splat(0);
    const cost = try exhaustive(source, &model, 0, 0, hq.rep.initial_repeats);
    var profile: controls.Profile = .{};
    const plan = try hq.planAlloc(a, source, .{ .strategy = .btultra, .hq_options = .{ .parse_mode = .whole_block, .match_lengths = .complete }, .entropy = &model, .profile = &profile });
    defer plan.deinit(a);
    try std.testing.expectEqual(cost, plan.estimated_cost);
    try std.testing.expectEqual(@as(u64, 1), profile.whole_block_passes);
    try std.testing.expectEqual(@as(u64, 1), profile.complete_length_passes);
    try std.testing.expectEqual(source.block.len, profile.max_parse_positions);
    const decoded = try replay(a, source, plan, hq.rep.initial_repeats);
    defer a.free(decoded);
    try std.testing.expectEqualSlices(u8, source.block, decoded);
}

fn exhaustive(source: hq.Source, model: *const hq.EntropyModel, position: usize, literals: usize, repeats: hq.rep.Repeats) !u64 {
    if (position == source.block.len) return 0;
    var best = @as(u64, model.literal_prices[source.block[position]]) + try exhaustive(source, model, position + 1, literals + 1, repeats);
    const current = source.prefixLen() + position;
    for (current - @min(current, source.window_len)..current) |candidate| {
        const match = source.match(position, candidate, 3);
        if (match.length == 0) continue;
        const choices = try hq.rep.choices(literals, match.distance, repeats);
        for (3..match.length + 1) |length| {
            for (choices.slice()) |choice|
                best = @min(best, @as(u64, try model.sequencePrice(literals, length, choice.offset_value)) + try exhaustive(source, model, position + length, 0, choice.repeats));
        }
    }
    return best;
}

test "Zstd HQ search exact plan price cap and one below distinguish cold two pass work" {
    const source = hq.Source.init("", "", "abcabcabcabcabcabc", 1024);
    for ([_]controls.Strategy{ .btopt, .btultra2 }) |strategy| {
        var profile: controls.Profile = .{};
        var parameters: hq.Parameters = .{ .strategy = strategy, .hq_options = .{ .parse_mode = .whole_block, .match_lengths = .complete }, .profile = &profile };
        const measured = try hq.planAlloc(a, source, parameters);
        defer measured.deinit(a);
        const cap = profile.max_plan_price_evaluations;
        try std.testing.expect(cap > 0);
        if (strategy == .btultra2) {
            try std.testing.expectEqual(@as(u64, 2), profile.hq_passes);
            try std.testing.expect(profile.price_evaluations > cap);
        }
        profile.reset();
        parameters.hq_options.max_price_evaluations = cap;
        const exact = try hq.planAlloc(a, source, parameters);
        defer exact.deinit(a);
        try std.testing.expectEqualDeep(measured.records, exact.records);
        try std.testing.expectEqualSlices(u32, measured.offset_values, exact.offset_values);
        try std.testing.expectEqual(measured.estimated_cost, exact.estimated_cost);
        for ([_]u64{ 0, cap - 1 }) |limit| {
            profile.reset();
            parameters.hq_options.max_price_evaluations = limit;
            try std.testing.expectError(error.SearchLimitExceeded, hq.planAlloc(a, source, parameters));
            try std.testing.expectEqual(@as(u64, 1), profile.price_limit_refusals);
            try std.testing.expectEqual(limit, profile.max_plan_price_evaluations);
        }
    }
    var profile: controls.Profile = .{};
    const unmatched = try hq.planAlloc(a, hq.Source.init("", "", "abcdefgh", 1024), .{ .strategy = .btopt, .hq_options = .{ .max_price_evaluations = 0 }, .profile = &profile });
    defer unmatched.deinit(a);
    try std.testing.expectEqual(@as(u64, 0), profile.max_plan_price_evaluations);
    try std.testing.expectEqual(@as(usize, 0), unmatched.records.len);
}

test "Zstd HQ search whole endpoint trace includes predecessor beyond sixty five thousand" {
    const input = try a.alloc(u8, 128 * 1024);
    defer a.free(input);
    var random: u64 = 0x6282_114b_c719_b09d;
    for (input) |*byte| {
        random ^= random << 13;
        random ^= random >> 7;
        random ^= random << 17;
        byte.* = @truncate(random >> 24);
    }
    const dictionary = "ABCDEFG";
    @memcpy(input[input.len - dictionary.len ..], dictionary);
    var profile: controls.Profile = .{};
    const initial: hq.rep.Repeats = .{ input.len, input.len, input.len + 8 };
    var model: hq.EntropyModel = .{};
    model.literal_prices = @splat(16 * hq.prices.scale);
    model.ll_prices = @splat(0);
    model.ml_prices = @splat(0);
    model.of_prices = @splat(0);
    const source = hq.Source.init(dictionary, "", input, input.len + dictionary.len);
    const plan = try hq.planAlloc(a, source, .{ .strategy = .btopt, .hq_options = .{ .parse_mode = .whole_block, .match_lengths = .complete, .min_match = 7, .search_depth = 1 }, .initial_repeated_offsets = initial, .entropy = &model, .profile = &profile });
    defer plan.deinit(a);
    try std.testing.expectEqual(input.len, profile.max_parse_positions);
    try std.testing.expect(plan.records.len != 0);
    try std.testing.expectEqual(input.len, plan.records[plan.records.len - 1].match_end);
    try std.testing.expect(plan.records[plan.records.len - 1].match_end - plan.records[plan.records.len - 1].match_len > 65535);
    const decoded = try replay(a, source, plan, initial);
    defer a.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}

test "Zstd HQ search expanded mode allocation failures release all DP owners" {
    const source = hq.Source.init("abc", "", "abcabcabc", 1024);
    for ([_]controls.HqParseMode{ .bounded, .whole_block }) |mode| {
        const Test = struct {
            fn run(allocator: std.mem.Allocator, input: hq.Source, selected: controls.HqParseMode) !void {
                const plan = try hq.planAlloc(allocator, input, .{ .strategy = .btultra2, .hq_options = .{ .parse_mode = selected, .match_lengths = .complete } });
                defer plan.deinit(allocator);
            }
        };
        try std.testing.checkAllAllocationFailures(a, Test.run, .{ source, mode });
    }
}
