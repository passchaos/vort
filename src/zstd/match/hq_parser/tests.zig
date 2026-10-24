const std = @import("std");
const hq = @import("../hq_parser.zig");
const controls = @import("../../encode/controls.zig");
const source_mod = @import("../controlled_source.zig");
const replay = @import("lazy2_tests.zig").replay;
const dp = @import("dp.zig");

test {
    _ = @import("price_tests.zig");
    _ = @import("lazy2_tests.zig");
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

test "Zstd HQ DP tiny path matches exhaustive cost and exact final repeated offsets" {
    const source = source_mod.Source.init("abcde", "", "abcabcabc", 1024);
    const model: hq.EntropyModel = .{};
    const optimal = try oracle(source, &model, 0, 0, hq.rep.initial_repeats);
    for ([_]controls.Strategy{ .btopt, .btultra }) |strategy| {
        const plan = try hq.planAlloc(std.testing.allocator, source, .{ .strategy = strategy, .entropy = &model });
        defer plan.deinit(std.testing.allocator);
        try std.testing.expectEqual(optimal, plan.estimated_cost);
        const decoded = try replay(std.testing.allocator, source, plan, hq.rep.initial_repeats);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, source.block, decoded);
    }
}

test "Zstd HQ parser exact offset choice follows entropy instead of a cheaper repeat alias" {
    const source = source_mod.Source.init("abcaabc", "", "abc", 1024);
    var model: hq.EntropyModel = .{};
    model.of_prices[0] = hq.prices.maximum_symbol_price;
    model.of_prices[1] = hq.prices.maximum_symbol_price;
    model.of_prices[2] = 0;
    const repeats: hq.rep.Repeats = .{ 3, 3, 8 };
    for ([_]controls.Strategy{ .btlazy2, .btopt, .btultra }) |strategy| {
        const plan = try hq.planAlloc(std.testing.allocator, source, .{ .strategy = strategy, .entropy = &model, .initial_repeated_offsets = repeats });
        defer plan.deinit(std.testing.allocator);
        try std.testing.expectEqual(@as(usize, 1), plan.records.len);
        try std.testing.expectEqual(@as(usize, 3), plan.records[0].distance);
        try std.testing.expectEqual(@as(u32, 6), plan.offset_values[0]);
        try std.testing.expectEqual(@as(?usize, 6), plan.records[0].offset_value);
        try std.testing.expectEqual(hq.rep.Repeats{ 3, 3, 3 }, plan.final_repeated_offsets);
    }
}

test "Zstd HQ full block DP uses distinct beams and consumes a hundred twenty eight KiB" {
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
        const plan = try hq.planAlloc(std.testing.allocator, source, .{ .strategy = strategy, .profile = &profile });
        defer plan.deinit(std.testing.allocator);
        try std.testing.expect(plan.statistics.literal_count < 2 * 1024);
        try std.testing.expectEqual(source.block.len, plan.records[plan.records.len - 1].match_end);
        try std.testing.expect(profile.tree_nodes > 0 and profile.price_evaluations > 0);
        const decoded = try replay(std.testing.allocator, source, plan, hq.rep.initial_repeats);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, source.block, decoded);
    }
}

test "Zstd HQ ultra2 cold pass learns prices and retained or initialized models use one pass" {
    const initial: hq.EntropyModel = .{};
    const source = source_mod.Source.init("", "", "abcabcabcabcabcabcabcabc", 1024);
    var profile: controls.Profile = .{};
    const cold = try hq.planAlloc(std.testing.allocator, source, .{ .strategy = .btultra2, .entropy = &initial, .profile = &profile });
    defer cold.deinit(std.testing.allocator);
    try std.testing.expect(cold.used_refinement);
    try std.testing.expectEqual(@as(u8, 2), cold.passes);
    try std.testing.expectEqual(@as(u64, 2), profile.hq_passes);
    try std.testing.expectEqual(@as(u64, 1), profile.refinement_passes);
    try std.testing.expect(cold.first_pass_cost != cold.refined_first_pass_cost);
    try std.testing.expect(cold.estimated_cost <= cold.refined_first_pass_cost);
    try std.testing.expect(!initial.initialized);
    const decoded = try replay(std.testing.allocator, source, cold, hq.rep.initial_repeats);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, source.block, decoded);
    for ([_]source_mod.Source{
        source_mod.Source.init("abc", "", source.block, 1024),
        source_mod.Source.init("", "abc", source.block, 1024),
    }) |retained| {
        profile.reset();
        const plan = try hq.planAlloc(std.testing.allocator, retained, .{ .strategy = .btultra2, .profile = &profile });
        defer plan.deinit(std.testing.allocator);
        try std.testing.expectEqual(@as(u8, 1), plan.passes);
        try std.testing.expectEqual(@as(u64, 1), profile.hq_passes);
        try std.testing.expectEqual(@as(u64, 0), profile.refinement_passes);
    }
    var previous = initial;
    previous.initialized = true;
    profile.reset();
    const plan = try hq.planAlloc(std.testing.allocator, source, .{ .strategy = .btultra2, .entropy = &previous, .profile = &profile });
    defer plan.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(u8, 1), plan.passes);
    try std.testing.expectEqual(@as(u64, 0), profile.refinement_passes);
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

test "Zstd HQ terminal extension compares ML boundaries and retains equal cost original" {
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
        const plan = try hq.planAlloc(std.testing.allocator, source, .{ .strategy = strategy, .entropy = &model, .initial_repeated_offsets = repeats });
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
        const extended = try hq.planAlloc(std.testing.allocator, source, .{ .strategy = strategy, .entropy = &cheaper_next, .initial_repeated_offsets = repeats });
        defer extended.deinit(std.testing.allocator);
        try std.testing.expectEqual(@as(usize, 4099), extended.records[0].match_len);
        try std.testing.expectEqual(@as(u64, 12 * hq.prices.scale), extended.estimated_cost);
    }

    @memset(input[4096..], 'b');
    model.literal_prices['b'] = 0;
    const distant: hq.rep.Repeats = @splat(input.len);
    for ([_]controls.Strategy{ .btopt, .btultra }) |strategy| {
        const source = source_mod.Source.init(&input, "", &input, 8192);
        const plan = try hq.planAlloc(std.testing.allocator, source, .{ .strategy = strategy, .entropy = &model, .initial_repeated_offsets = distant });
        defer plan.deinit(std.testing.allocator);
        try std.testing.expectEqual(@as(usize, 4096), plan.records[0].match_len);
        try std.testing.expectEqual(@as(u64, 11 * hq.prices.scale), plan.estimated_cost);
        try std.testing.expectEqual(@as(?usize, 1), plan.records[0].offset_value);
    }
}
