const std = @import("std");
const hq = @import("../hq_parser.zig");
const controls = @import("../../encode/controls.zig");
const source_mod = @import("../controlled_source.zig");
const replay = @import("lazy2_tests.zig").replay;
const dp = @import("dp.zig");
const dp_reuse = @import("dp_reuse.zig");
const frontier_cache = @import("match_frontier_cache.zig");
const resources = @import("resources.zig");
const tree = @import("../hq_tree.zig");

test {
    _ = @import("price_tests.zig");
    _ = @import("storage_controls_tests.zig");
    _ = @import("search_controls_tests.zig");
    _ = @import("lazy2_tests.zig");
    _ = @import("source_dominance.zig");
    _ = @import("prepared_price_tests.zig");
    _ = @import("choice_dominance_tests.zig");
    _ = @import("enumeration_count_tests.zig");
}

fn oracle(source: source_mod.Source, model: *const hq.EntropyModel, position: usize, literals: usize, repeats: hq.rep.Repeats) !u64 {
    if (position == source.block.len) return 0;
    var best = @as(u64, model.literal_prices[source.block[position]]) + try oracle(source, model, position + 1, literals + 1, repeats);
    const absolute = source.prefixLen() + position;
    for (absolute - @min(absolute, source.window_len)..absolute) |candidate| {
        const match = source.match(position, candidate, 3);
        if (match.length == 0) continue;
        const choices = try hq.rep.choices(literals, match.distance, repeats);
        for (3..match.length + 1) |length| {
            for (choices.slice()) |choice| {
                const cost = @as(u64, try model.sequencePrice(literals, length, choice.offset_value)) + try oracle(source, model, position + length, 0, choice.repeats);
                best = @min(best, cost);
            }
        }
    }
    return best;
}

fn expectSamePlan(expected: hq.Plan, actual: hq.Plan) !void {
    try std.testing.expectEqual(expected.statistics, actual.statistics);
    try std.testing.expectEqual(expected.estimated_cost, actual.estimated_cost);
    try std.testing.expectEqual(expected.final_repeated_offsets, actual.final_repeated_offsets);
    try std.testing.expectEqualSlices(source_mod.Record, expected.records, actual.records);
    try std.testing.expectEqualSlices(u32, expected.offset_values, actual.offset_values);
}

test "Zstd HQ cold reuse record and replay preserve independent DP plans" {
    const input = "cold btultra2 shared frontier and repeat length evidence 0123456789\n" ** 48;
    const source = source_mod.Source.init("", "", input, 4096);
    const parameters: hq.Parameters = .{ .strategy = .btultra };
    var expected_budget = resources.WorkingAllocator.init(
        std.testing.allocator,
        std.math.maxInt(usize),
    );
    const expected_allocator = expected_budget.allocator();
    const expected = try dp.plan(
        expected_allocator,
        &expected_budget,
        source,
        parameters,
        tree.Matcher,
    );
    defer expected.deinit(expected_allocator);

    var actual_budget = resources.WorkingAllocator.init(
        std.testing.allocator,
        std.math.maxInt(usize),
    );
    const actual_allocator = actual_budget.allocator();
    var scratch: dp_reuse.Scratch(tree.Matcher) = .{};
    defer scratch.deinit(actual_allocator);
    var frontier = try frontier_cache.Cache.init(actual_allocator, source.block.len);
    defer frontier.deinit(actual_allocator);
    const recorded = try dp_reuse.planReuse(
        tree.Matcher,
        &scratch,
        actual_allocator,
        &actual_budget,
        source,
        parameters,
        .{ .record = &frontier },
    );
    defer recorded.deinit(actual_allocator);
    try expectSamePlan(expected, recorded);
    try std.testing.expect(frontier.finish());
    const replayed = try dp_reuse.planReuse(
        tree.Matcher,
        &scratch,
        actual_allocator,
        &actual_budget,
        source,
        parameters,
        .{ .replay = &frontier },
    );
    defer replayed.deinit(actual_allocator);
    try expectSamePlan(expected, replayed);
}

test "Zstd HQ cold reuse dominance preserves plans and reduces priced edges" {
    const input = ("dominance shared repeats and literal lengths abcabcabcabc 0123456789\n" ** 96);
    const source = source_mod.Source.init("", "", input, 8192);
    var expected_profile: controls.Profile = .{};
    // A finite maximum requests the complete original admission ledger;
    // this remains the unpruned oracle for source/choice dominance.
    const expected_parameters: hq.Parameters = .{
        .hq_options = .{ .max_price_evaluations = std.math.maxInt(u64) },
        .strategy = .btultra,
        .profile = &expected_profile,
    };
    var expected_budget = resources.WorkingAllocator.init(
        std.testing.allocator,
        std.math.maxInt(usize),
    );
    const expected_allocator = expected_budget.allocator();
    const expected = try dp.plan(
        expected_allocator,
        &expected_budget,
        source,
        expected_parameters,
        tree.Matcher,
    );
    defer expected.deinit(expected_allocator);

    var actual_profile: controls.Profile = .{};
    const actual_parameters: hq.Parameters = .{
        .strategy = .btultra,
        .profile = &actual_profile,
    };
    var actual_budget = resources.WorkingAllocator.init(
        std.testing.allocator,
        std.math.maxInt(usize),
    );
    const actual_allocator = actual_budget.allocator();
    var scratch: dp_reuse.Scratch(tree.Matcher) = .{};
    defer scratch.deinit(actual_allocator);
    const actual = try dp_reuse.planReuse(
        tree.Matcher,
        &scratch,
        actual_allocator,
        &actual_budget,
        source,
        actual_parameters,
        .search,
    );
    defer actual.deinit(actual_allocator);

    try expectSamePlan(expected, actual);
    try std.testing.expect(actual_profile.price_evaluations <
        expected_profile.price_evaluations);
    try std.testing.expect(actual_profile.optimal_transitions <
        expected_profile.optimal_transitions);
    try std.testing.expectEqual(
        expected_profile.tree_nodes,
        actual_profile.tree_nodes,
    );

    // A finite public price budget disables dominance so admission order and
    // the exact success/failure boundary remain unchanged.
    var limited_profile: controls.Profile = .{};
    const limited_parameters: hq.Parameters = .{
        .strategy = .btultra,
        .hq_options = .{
            .max_price_evaluations = expected_profile.price_evaluations,
        },
        .profile = &limited_profile,
    };
    var limited_budget = resources.WorkingAllocator.init(
        std.testing.allocator,
        std.math.maxInt(usize),
    );
    const limited_allocator = limited_budget.allocator();
    var limited_scratch: dp_reuse.Scratch(tree.Matcher) = .{};
    defer limited_scratch.deinit(limited_allocator);
    const limited = try dp_reuse.planReuse(
        tree.Matcher,
        &limited_scratch,
        limited_allocator,
        &limited_budget,
        source,
        limited_parameters,
        .search,
    );
    defer limited.deinit(limited_allocator);
    try expectSamePlan(expected, limited);
    try std.testing.expectEqual(
        expected_profile.price_evaluations,
        limited_profile.price_evaluations,
    );

    var refused_budget = resources.WorkingAllocator.init(
        std.testing.allocator,
        std.math.maxInt(usize),
    );
    const refused_allocator = refused_budget.allocator();
    var refused_scratch: dp_reuse.Scratch(tree.Matcher) = .{};
    defer refused_scratch.deinit(refused_allocator);
    var refused_parameters = limited_parameters;
    refused_parameters.profile = null;
    refused_parameters.hq_options.max_price_evaluations =
        expected_profile.price_evaluations - 1;
    try std.testing.expectError(
        error.SearchLimitExceeded,
        dp_reuse.planReuse(
            tree.Matcher,
            &refused_scratch,
            refused_allocator,
            &refused_budget,
            source,
            refused_parameters,
            .search,
        ),
    );
}

test "Zstd HQ cold reuse dominance gate preserves sparse-prefix work" {
    var input: [1024]u8 = undefined;
    for (input[0..256], 0..) |*byte, index| byte.* = @intCast(index);
    for (input[256..], 0..) |*byte, index| byte.* = "xyz"[index % 3];
    const source = source_mod.Source.init("", "", &input, 2048);

    var expected_profile: controls.Profile = .{};
    const expected_parameters: hq.Parameters = .{
        .strategy = .btultra,
        .profile = &expected_profile,
    };
    var expected_budget = resources.WorkingAllocator.init(
        std.testing.allocator,
        std.math.maxInt(usize),
    );
    const expected_allocator = expected_budget.allocator();
    const expected = try dp.plan(
        expected_allocator,
        &expected_budget,
        source,
        expected_parameters,
        tree.Matcher,
    );
    defer expected.deinit(expected_allocator);

    var actual_profile: controls.Profile = .{};
    const actual_parameters: hq.Parameters = .{
        .strategy = .btultra,
        .profile = &actual_profile,
    };
    var actual_budget = resources.WorkingAllocator.init(
        std.testing.allocator,
        std.math.maxInt(usize),
    );
    const actual_allocator = actual_budget.allocator();
    var scratch: dp_reuse.Scratch(tree.Matcher) = .{};
    defer scratch.deinit(actual_allocator);
    const actual = try dp_reuse.planReuse(
        tree.Matcher,
        &scratch,
        actual_allocator,
        &actual_budget,
        source,
        actual_parameters,
        .search,
    );
    defer actual.deinit(actual_allocator);

    try expectSamePlan(expected, actual);
    try std.testing.expectEqual(
        expected_profile.price_evaluations,
        actual_profile.price_evaluations,
    );
    try std.testing.expectEqual(
        expected_profile.optimal_transitions,
        actual_profile.optimal_transitions,
    );
    try std.testing.expectEqual(
        expected_profile.tree_nodes,
        actual_profile.tree_nodes,
    );
}

test "Zstd HQ legacy beam tiny path matches exhaustive cost and exact final repeated offsets" {
    const source = source_mod.Source.init("abcde", "", "abcabcabc", 1024);
    const model: hq.EntropyModel = .{};
    const optimal = try oracle(source, &model, 0, 0, hq.rep.initial_repeats);
    for ([_]controls.Strategy{ .btopt, .btultra }) |strategy| {
        const plan = try hq.planAlloc(std.testing.allocator, source, .{ .strategy = strategy, .entropy = &model, .hq_options = .{ .parser_engine = .beam } });
        defer plan.deinit(std.testing.allocator);
        try std.testing.expectEqual(optimal, plan.estimated_cost);
        const decoded = try replay(std.testing.allocator, source, plan, hq.rep.initial_repeats);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, source.block, decoded);
    }
}

test "Zstd HQ legacy beam and lazy parser exact offset choice follows entropy instead of a cheaper repeat alias" {
    const source = source_mod.Source.init("abcaabc", "", "abc", 1024);
    var model: hq.EntropyModel = .{};
    model.of_prices[0] = hq.prices.maximum_symbol_price;
    model.of_prices[1] = hq.prices.maximum_symbol_price;
    model.of_prices[2] = 0;
    const repeats: hq.rep.Repeats = .{ 3, 3, 8 };
    for ([_]controls.Strategy{ .btlazy2, .btopt, .btultra }) |strategy| {
        const plan = try hq.planAlloc(std.testing.allocator, source, .{ .strategy = strategy, .entropy = &model, .initial_repeated_offsets = repeats, .hq_options = .{ .parser_engine = if (strategy == .btlazy2) .local_optimal else .beam } });
        defer plan.deinit(std.testing.allocator);
        try std.testing.expectEqual(@as(usize, 1), plan.records.len);
        try std.testing.expectEqual(@as(usize, 3), plan.records[0].distance);
        try std.testing.expectEqual(@as(u32, 6), plan.offset_values[0]);
        try std.testing.expectEqual(@as(?usize, 6), plan.records[0].offset_value);
        try std.testing.expectEqual(hq.rep.Repeats{ 3, 3, 3 }, plan.final_repeated_offsets);
    }
}

test "Zstd HQ legacy beam full block DP uses distinct beams and consumes a hundred twenty eight KiB" {
    const input = try std.testing.allocator.alloc(u8, 128 * 1024);
    defer std.testing.allocator.free(input);
    var random = std.Random.DefaultPrng.init(0x234567);
    random.random().bytes(input[0..1024]);
    for (input[1024..], 1024..) |*byte, i| byte.* = input[i % 1024];
    const source = source_mod.Source.init("", "", input, input.len);
    try std.testing.expectEqual(@as(usize, 8), dp.beamWidth(.btopt));
    try std.testing.expectEqual(@as(usize, 16), dp.beamWidth(.btultra));
    for ([_]controls.Strategy{ .btopt, .btultra }) |strategy| {
        var profile: controls.Profile = .{};
        const plan = try hq.planAlloc(std.testing.allocator, source, .{ .strategy = strategy, .profile = &profile, .hq_options = .{ .parser_engine = .beam } });
        defer plan.deinit(std.testing.allocator);
        try std.testing.expect(plan.statistics.literal_count < 2 * 1024);
        try std.testing.expectEqual(source.block.len, plan.records[plan.records.len - 1].match_end);
        try std.testing.expect(profile.tree_nodes > 0 and profile.price_evaluations > 0);
        try std.testing.expectEqual(@as(u64, 0), profile.rep_length_cache_hits);
        try std.testing.expectEqual(@as(u64, 0), profile.match_frontier_cache_entries);
        try std.testing.expectEqual(@as(u64, 0), profile.match_frontier_replay_positions);
        try std.testing.expectEqual(@as(u64, 0), profile.match_frontier_cache_fallbacks);
        const decoded = try replay(std.testing.allocator, source, plan, hq.rep.initial_repeats);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, source.block, decoded);
    }
}

test "Zstd HQ legacy beam ultra2 cold pass learns prices and retained or initialized models use one pass" {
    const initial: hq.EntropyModel = .{};
    const source = source_mod.Source.init("", "", "abcabcabcabcabcabcabcabc", 1024);
    var profile: controls.Profile = .{};
    const cold = try hq.planAlloc(std.testing.allocator, source, .{ .strategy = .btultra2, .entropy = &initial, .profile = &profile, .hq_options = .{ .parser_engine = .beam } });
    defer cold.deinit(std.testing.allocator);
    try std.testing.expect(cold.used_refinement);
    try std.testing.expectEqual(@as(u8, 2), cold.passes);
    try std.testing.expectEqual(@as(u64, 2), profile.hq_passes);
    try std.testing.expectEqual(@as(u64, 1), profile.refinement_passes);
    try std.testing.expect(cold.first_pass_cost != cold.refined_first_pass_cost);
    try std.testing.expect(cold.estimated_cost <= cold.refined_first_pass_cost);
    try std.testing.expect(profile.rep_length_cache_hits > 0);
    try std.testing.expect(profile.match_frontier_cache_entries > 0);
    try std.testing.expectEqual(@as(u64, source.block.len), profile.match_frontier_replay_positions);
    try std.testing.expectEqual(@as(u64, 0), profile.match_frontier_cache_fallbacks);
    try std.testing.expect(!initial.initialized);
    const decoded = try replay(std.testing.allocator, source, cold, hq.rep.initial_repeats);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, source.block, decoded);
    for ([_]source_mod.Source{
        source_mod.Source.init("abc", "", source.block, 1024),
        source_mod.Source.init("", "abc", source.block, 1024),
    }) |retained| {
        profile.reset();
        const plan = try hq.planAlloc(std.testing.allocator, retained, .{ .strategy = .btultra2, .profile = &profile, .hq_options = .{ .parser_engine = .beam } });
        defer plan.deinit(std.testing.allocator);
        try std.testing.expectEqual(@as(u8, 1), plan.passes);
        try std.testing.expectEqual(@as(u64, 1), profile.hq_passes);
        try std.testing.expectEqual(@as(u64, 0), profile.refinement_passes);
        try std.testing.expectEqual(@as(u64, 0), profile.rep_length_cache_hits);
        try std.testing.expectEqual(@as(u64, 0), profile.match_frontier_cache_entries);
        try std.testing.expectEqual(@as(u64, 0), profile.match_frontier_replay_positions);
        try std.testing.expectEqual(@as(u64, 0), profile.match_frontier_cache_fallbacks);
    }
    var previous = initial;
    previous.initialized = true;
    profile.reset();
    const plan = try hq.planAlloc(std.testing.allocator, source, .{ .strategy = .btultra2, .entropy = &previous, .profile = &profile, .hq_options = .{ .parser_engine = .beam } });
    defer plan.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(u8, 1), plan.passes);
    try std.testing.expectEqual(@as(u64, 0), profile.refinement_passes);
    try std.testing.expectEqual(@as(u64, 0), profile.rep_length_cache_hits);
    try std.testing.expectEqual(@as(u64, 0), profile.match_frontier_cache_entries);
    try std.testing.expectEqual(@as(u64, 0), profile.match_frontier_replay_positions);
    try std.testing.expectEqual(@as(u64, 0), profile.match_frontier_cache_fallbacks);
}

test "Zstd HQ DP exact budget one byte below and OOM preserve owned state" {
    const source = source_mod.Source.init("", "", "abcabcabcabc", 1024);
    for ([_]controls.Strategy{ .btlazy2, .btopt, .btultra2 }) |strategy| {
        var parameters: hq.Parameters = .{ .strategy = strategy };
        const required = try hq.requiredWorkingMemory(source, parameters);
        parameters.hq_options.max_working_memory = required;
        const plan = try hq.planAlloc(std.testing.allocator, source, parameters);
        defer plan.deinit(std.testing.allocator);
        try std.testing.expectEqual(required, plan.peak_working_memory);
        var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
        parameters.hq_options.max_working_memory -= 1;
        try std.testing.expectError(error.WorkingMemoryLimitExceeded, hq.planAlloc(failing.allocator(), source, parameters));
        try std.testing.expectEqual(@as(usize, 0), failing.alloc_index);
        const Test = struct {
            fn run(allocator: std.mem.Allocator, bytes: source_mod.Source, selected: controls.Strategy) !void {
                const result = try hq.planAlloc(allocator, bytes, .{ .strategy = selected });
                defer result.deinit(allocator);
            }
        };
        try std.testing.checkAllAllocationFailures(std.testing.allocator, Test.run, .{ source, strategy });
    }
}

test "Zstd HQ parser empty metadata costs no heap and configured seven byte minimum is respected" {
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    var profile: controls.Profile = .{};
    const empty = try hq.planAlloc(failing.allocator(), source_mod.Source.init("abc", "", "", 1024), .{ .strategy = .btultra2, .hq_options = .{ .max_working_memory = 0 }, .profile = &profile });
    defer empty.deinit(failing.allocator());
    try std.testing.expectEqual(@as(u8, 0), empty.passes);
    try std.testing.expectEqual(@as(u64, 0), profile.hq_passes);
    try std.testing.expectEqual(@as(usize, 0), profile.peak_working_memory);
    try std.testing.expectEqual(@as(usize, 0), failing.alloc_index);
    try std.testing.expect(profile.hq_used);
    const source = source_mod.Source.init("abcdef", "", "abcdef", 1024);
    const plan = try hq.planAlloc(failing.allocator(), source, .{ .strategy = .btopt, .hq_options = .{ .min_match = 7, .max_working_memory = 0 } });
    defer plan.deinit(failing.allocator());
    try std.testing.expectEqual(@as(usize, 0), plan.records.len);
    try std.testing.expectEqual(@as(u32, 6), plan.statistics.literal_count);
    try std.testing.expectEqual(@as(usize, 0), failing.alloc_index);
}

test "Zstd HQ legacy beam terminal extension compares ML boundaries and retains equal cost original" {
    var input: [4099]u8 = @splat('a');
    var model: hq.EntropyModel = .{};
    model.literal_prices = @splat(hq.prices.scale);
    model.ll_prices = @splat(0);
    model.of_prices = @splat(0);
    model.ml_prices = @splat(12 * hq.prices.scale);
    model.ml_prices[47] = 0;
    const repeats: hq.rep.Repeats = .{ 1, 1, 1 };
    for ([_]controls.Strategy{ .btopt, .btultra }) |strategy| {
        const source = source_mod.Source.init("", "a", &input, 8192);
        const plan = try hq.planAlloc(std.testing.allocator, source, .{ .strategy = strategy, .entropy = &model, .initial_repeated_offsets = repeats, .hq_options = .{ .parser_engine = .beam } });
        defer plan.deinit(std.testing.allocator);
        const retained_cost = try model.sequencePrice(0, 4096, 1);
        const literal_tail_cost = @as(u64, 3) * model.literal_prices['a'];
        try std.testing.expect(plan.estimated_cost <= retained_cost + literal_tail_cost);
        try std.testing.expectEqual(@as(usize, 1), plan.records.len);
        try std.testing.expectEqual(@as(usize, 4098), plan.records[0].match_len);
        try std.testing.expectEqual(@as(u64, 12 * hq.prices.scale), plan.estimated_cost);
        try std.testing.expectEqual(@as(?usize, 1), plan.records[0].offset_value);
        try std.testing.expectEqual(repeats, plan.final_repeated_offsets);
        const decoded = try replay(std.testing.allocator, source, plan, repeats);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, &input, decoded);

        var cheaper_next = model;
        cheaper_next.ml_prices[47] = 12 * hq.prices.scale;
        cheaper_next.ml_prices[48] = 0;
        const extended = try hq.planAlloc(std.testing.allocator, source, .{ .strategy = strategy, .entropy = &cheaper_next, .initial_repeated_offsets = repeats, .hq_options = .{ .parser_engine = .beam } });
        defer extended.deinit(std.testing.allocator);
        try std.testing.expectEqual(@as(usize, 4099), extended.records[0].match_len);
        try std.testing.expectEqual(@as(u64, 12 * hq.prices.scale), extended.estimated_cost);
    }

    @memset(input[4096..], 'b');
    model.literal_prices['b'] = 0;
    const distant: hq.rep.Repeats = @splat(input.len);
    for ([_]controls.Strategy{ .btopt, .btultra }) |strategy| {
        const source = source_mod.Source.init(&input, "", &input, 8192);
        const plan = try hq.planAlloc(std.testing.allocator, source, .{ .strategy = strategy, .entropy = &model, .initial_repeated_offsets = distant, .hq_options = .{ .parser_engine = .beam } });
        defer plan.deinit(std.testing.allocator);
        try std.testing.expectEqual(@as(usize, 4096), plan.records[0].match_len);
        try std.testing.expectEqual(@as(u64, 11 * hq.prices.scale), plan.estimated_cost);
        try std.testing.expectEqual(@as(?usize, 1), plan.records[0].offset_value);
    }
}
