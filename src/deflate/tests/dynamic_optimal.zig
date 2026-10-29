const std = @import("std");
const lz77 = @import("../../lz77.zig");
const dynamic_optimal = @import("../dynamic_optimal.zig");

const source_fixture =
    \\const std = @import("std");
    \\pub fn update(state: *State, input: []const u8) !usize {
    \\    var consumed: usize = 0;
    \\    for (input) |byte| {
    \\        state.checksum = state.checksum *% 33 + byte;
    \\        consumed += 1;
    \\    }
    \\    return consumed;
    \\}
    \\
** 24;

pub fn contracts(comptime C: type) !void {
    try costModel(C);
    try policy(C);
    try completeWire(C);
    try excludedPathsStayStable(C);
    try allocationFailures(C);
}

fn costModel(comptime C: type) !void {
    var literal_lengths: [286]u4 = @splat(0);
    var distance_lengths: [30]u4 = @splat(0);
    literal_lengths[0] = 3;
    literal_lengths[144] = 11;
    literal_lengths[255] = 15;
    for (257..286) |symbol| literal_lengths[symbol] = @intCast(1 + symbol % 15);
    for (1..30) |symbol| distance_lengths[symbol] = @intCast(1 + symbol % 15);

    var model = try dynamic_optimal.Model.init(
        C.Strategy,
        std.testing.allocator,
        &literal_lengths,
        &distance_lengths,
        lz77.default_window_len,
    );
    defer model.deinit(std.testing.allocator);

    for (model.literal, 0..) |cost, symbol| {
        const expected = if (literal_lengths[symbol] == 0)
            C.Strategy.fixedLiteralBits(symbol)
        else
            literal_lengths[symbol];
        try std.testing.expectEqual(@as(u16, expected), cost);
        try std.testing.expect(cost != 0);
    }
    for (lz77.min_match_len..lz77.max_match_len + 1) |match_len| {
        const code = C.Strategy.lengthCode(match_len);
        const prefix = if (literal_lengths[code.symbol] == 0)
            C.Strategy.fixedLiteralBits(code.symbol)
        else
            literal_lengths[code.symbol];
        try std.testing.expectEqual(@as(u16, prefix) + code.extra_bits, model.length[match_len]);
        try std.testing.expect(model.length[match_len] != 0);
    }
    try std.testing.expectEqual(@as(u16, 1), model.distance[0]);
    for (1..model.distance.len) |distance| {
        const code = C.Strategy.distanceCode(distance);
        const prefix = if (distance_lengths[code.symbol] == 0)
            C.Strategy.fixedDistanceBits(code.symbol)
        else
            distance_lengths[code.symbol];
        try std.testing.expectEqual(@as(u16, prefix) + code.extra_bits, model.distance[distance]);
        try std.testing.expect(model.distance[distance] != 0);
    }

    const tokens = [_]lz77.Token{
        .{ .literal = 0 },
        .{ .match = .{ .length = 258, .distance = 32_768 } },
    };
    try std.testing.expectEqual(
        @as(usize, model.literal[0]) + model.length[258] + model.distance[32_768],
        try dynamic_optimal.tokenCost(&model, &tokens),
    );
    try std.testing.expectError(
        error.InvalidBlockPlan,
        dynamic_optimal.tokenCost(&model, &.{.{ .match = .{ .length = 3, .distance = 0 } }}),
    );

    var literal_only_lengths: [286]u4 = @splat(0);
    literal_only_lengths['x'] = 1;
    literal_only_lengths[256] = 1;
    const no_distance_lengths: [30]u4 = @splat(0);
    var literal_only = try dynamic_optimal.Model.init(
        C.Strategy,
        std.testing.allocator,
        &literal_only_lengths,
        &no_distance_lengths,
        lz77.default_window_len,
    );
    defer literal_only.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(u16, 1), literal_only.literal['x']);
    try std.testing.expectEqual(
        @as(u16, C.Strategy.fixedLiteralBits('y')),
        literal_only.literal['y'],
    );
    for (1..literal_only.distance.len) |distance| {
        const code = C.Strategy.distanceCode(distance);
        try std.testing.expectEqual(
            @as(u16, C.Strategy.fixedDistanceBits(code.symbol)) + code.extra_bits,
            literal_only.distance[distance],
        );
    }
}

fn policy(comptime C: type) !void {
    const level7 = C.options(7);
    const level8 = C.options(8);
    const level9 = C.options(9);
    try std.testing.expect(!level7.dynamic_cost_refinement);
    try std.testing.expect(level8.dynamic_cost_refinement);
    try std.testing.expect(level9.dynamic_cost_refinement);
    try std.testing.expect(!C.eligible(4095, level9));
    try std.testing.expect(C.eligible(4096, level8));
    try std.testing.expect(C.eligible(4096, level9));
    try std.testing.expect(C.eligible(65_535, level9));
    try std.testing.expect(!C.eligible(65_536, level9));

    var disabled = level9;
    disabled.dynamic_cost_refinement = false;
    try std.testing.expect(!C.eligible(4096, disabled));
    var filtered = level9;
    filtered.strategy = .filtered;
    try std.testing.expect(!C.eligible(4096, filtered));
    var lazy = level9;
    lazy.parser = .lazy;
    try std.testing.expect(!C.eligible(4096, lazy));
    var no_dynamic = level9;
    no_dynamic.block_selection = .stored_fixed;
    try std.testing.expect(!C.eligible(4096, no_dynamic));
}

fn completeWire(comptime C: type) !void {
    var baseline_options = C.options(9);
    baseline_options.dynamic_cost_refinement = false;
    const refined_options = C.options(9);

    const raw_baseline = try C.encodeRaw(std.testing.allocator, source_fixture, baseline_options);
    defer std.testing.allocator.free(raw_baseline);
    const raw_refined = try C.encodeRaw(std.testing.allocator, source_fixture, refined_options);
    defer std.testing.allocator.free(raw_refined);
    try std.testing.expect(raw_refined.len < raw_baseline.len);
    try std.testing.expectEqual(.dynamic, (try C.rawBlockType(raw_refined)).block_type);
    const raw_decoded = try C.decodeRaw(std.testing.allocator, raw_refined);
    defer std.testing.allocator.free(raw_decoded);
    try std.testing.expectEqualSlices(u8, source_fixture, raw_decoded);

    const zlib_baseline = try C.encodeZlib(std.testing.allocator, source_fixture, baseline_options);
    defer std.testing.allocator.free(zlib_baseline);
    const zlib_refined = try C.encodeZlib(std.testing.allocator, source_fixture, refined_options);
    defer std.testing.allocator.free(zlib_refined);
    try std.testing.expect(zlib_refined.len < zlib_baseline.len);
    const zlib_decoded = try C.decodeZlib(std.testing.allocator, zlib_refined);
    defer std.testing.allocator.free(zlib_decoded);
    try std.testing.expectEqualSlices(u8, source_fixture, zlib_decoded);

    const gzip_baseline = try C.encodeGzip(std.testing.allocator, source_fixture, baseline_options);
    defer std.testing.allocator.free(gzip_baseline);
    const gzip_refined = try C.encodeGzip(std.testing.allocator, source_fixture, refined_options);
    defer std.testing.allocator.free(gzip_refined);
    try std.testing.expect(gzip_refined.len < gzip_baseline.len);
    const gzip_decoded = try C.decodeGzip(std.testing.allocator, gzip_refined);
    defer std.testing.allocator.free(gzip_decoded);
    try std.testing.expectEqualSlices(u8, source_fixture, gzip_decoded);

    const repeated = try C.encodeRaw(std.testing.allocator, source_fixture, refined_options);
    defer std.testing.allocator.free(repeated);
    try std.testing.expectEqualSlices(u8, raw_refined, repeated);

    const tie_input = "a" ** 4096;
    const tie_baseline = try C.encodeRaw(std.testing.allocator, tie_input, baseline_options);
    defer std.testing.allocator.free(tie_baseline);
    const tie_refined = try C.encodeRaw(std.testing.allocator, tie_input, refined_options);
    defer std.testing.allocator.free(tie_refined);
    try std.testing.expectEqualSlices(u8, tie_baseline, tie_refined);

    var level8_baseline_options = C.options(8);
    level8_baseline_options.dynamic_cost_refinement = false;
    const level8_baseline = try C.encodeRaw(std.testing.allocator, source_fixture, level8_baseline_options);
    defer std.testing.allocator.free(level8_baseline);
    const level8_refined = try C.encodeRaw(std.testing.allocator, source_fixture, C.options(8));
    defer std.testing.allocator.free(level8_refined);
    try std.testing.expect(level8_refined.len < level8_baseline.len);

    var random: [4096]u8 = undefined;
    var state: u32 = 0x243f_6a88;
    for (&random) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }

    const stored_baseline = try C.encodeRaw(std.testing.allocator, &random, baseline_options);
    defer std.testing.allocator.free(stored_baseline);
    const stored_refined = try C.encodeRaw(std.testing.allocator, &random, refined_options);
    defer std.testing.allocator.free(stored_refined);
    try std.testing.expectEqualSlices(u8, stored_baseline, stored_refined);
    try std.testing.expectEqual(.stored, (try C.rawBlockType(stored_refined)).block_type);
}

fn excludedPathsStayStable(comptime C: type) !void {
    var baseline_options = C.options(9);
    baseline_options.dynamic_cost_refinement = false;
    const refined_options = C.options(9);
    const dictionary = "const std update checksum consumed input state";

    const baseline_plan = try C.plan(std.testing.allocator, source_fixture, baseline_options);
    defer baseline_plan.deinit(std.testing.allocator);
    const refined_plan = try C.plan(std.testing.allocator, source_fixture, refined_options);
    defer refined_plan.deinit(std.testing.allocator);
    try std.testing.expectEqualDeep(baseline_plan.stats, refined_plan.stats);
    try std.testing.expectEqualSlices(lz77.Token, baseline_plan.tokens, refined_plan.tokens);

    const dict_baseline = try C.encodeRawDictionary(
        std.testing.allocator,
        source_fixture,
        dictionary,
        baseline_options,
    );
    defer std.testing.allocator.free(dict_baseline);
    const dict_refined = try C.encodeRawDictionary(
        std.testing.allocator,
        source_fixture,
        dictionary,
        refined_options,
    );
    defer std.testing.allocator.free(dict_refined);
    try std.testing.expectEqualSlices(u8, dict_baseline, dict_refined);

    const split_baseline = try C.encodeRawSplit(
        std.testing.allocator,
        source_fixture,
        2048,
        baseline_options,
    );
    defer std.testing.allocator.free(split_baseline);
    const split_refined = try C.encodeRawSplit(
        std.testing.allocator,
        source_fixture,
        2048,
        refined_options,
    );
    defer std.testing.allocator.free(split_refined);
    try std.testing.expectEqualSlices(u8, split_baseline, split_refined);

    var filtered_baseline = baseline_options;
    filtered_baseline.strategy = .filtered;
    var filtered_refined = refined_options;
    filtered_refined.strategy = .filtered;
    const strategy_baseline = try C.encodeRaw(std.testing.allocator, source_fixture, filtered_baseline);
    defer std.testing.allocator.free(strategy_baseline);
    const strategy_refined = try C.encodeRaw(std.testing.allocator, source_fixture, filtered_refined);
    defer std.testing.allocator.free(strategy_refined);
    try std.testing.expectEqualSlices(u8, strategy_baseline, strategy_refined);
}

fn allocationFailures(comptime C: type) !void {
    const Run = struct {
        fn run(allocator: std.mem.Allocator) !void {
            const encoded = try C.encodeRaw(allocator, source_fixture, C.options(9));
            allocator.free(encoded);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Run.run, .{});
}
