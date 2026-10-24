const std = @import("std");
const encoder = @import("encoder.zig");
const prices = @import("parse/prices.zig");
const types = @import("parse/types.zig");
const matcher = @import("match_finder.zig");
const range_encoder = @import("range_encoder.zig");
const oracle = @import("parse_oracle_helpers.zig");
const allocator = std.testing.allocator;
const options = encoder.EncodeOptions{ .mode = .normal, .properties = .{ .lc = 0, .lp = 0, .pb = 0 }, .match_options = .{ .finder = .bt2, .nice_len = 273, .depth = 512 } };

fn productionState(state: oracle.State) types.State {
    var result = types.State{ .state = state.code };
    for (state.distances, &result.reps) |distance, *offset| offset.* = @intCast(distance - 1);
    return result;
}

fn expectPrice(model: *const encoder.Model, history: []const u8, input: []const u8, state: oracle.State, decision: oracle.Decision, expected: u32) !void {
    const lengths = prices.Lengths.init(model);
    const source = matcher.Source.init(history, input, model.dictionary_size);
    try std.testing.expectEqual(expected, try oracle.tokenCost(model, history, input, 0, history.len, state, decision));
    try std.testing.expectEqual(expected, prices.decision(model, &lengths, source, 0, history.len, productionState(state), .{ .length = @intCast(decision.length), .distance = @intCast(decision.distance) }));
}

test "LZMA advanced oracle fixed probability logarithms and uniform selectors" {
    for ([_]struct { probability: u16, zero: u32, one: u32 }{
        .{ .probability = 1024, .zero = 64, .one = 64 },
        .{ .probability = 512, .zero = 128, .one = 27 },
        .{ .probability = 1536, .zero = 27, .one = 128 },
        .{ .probability = 256, .zero = 192, .one = 12 },
        .{ .probability = 1792, .zero = 12, .one = 192 },
    }) |fixed| {
        try std.testing.expectEqual(fixed.zero, prices.bit(fixed.probability, false));
        try std.testing.expectEqual(fixed.one, prices.bit(fixed.probability, true));
    }
    const model = try encoder.initModel(options);
    try expectPrice(&model, "", "x", .{}, .{}, 9 * 64);
    const state = oracle.State{ .code = 5, .distances = .{ 1, 3, 5, 7 } };
    for ([_]u32{ 8 * 64, 8 * 64, 9 * 64, 9 * 64 }, state.distances) |expected, distance|
        try expectPrice(&model, "abcdefgh", "ab", state, .{ .length = 2, .distance = distance }, expected);
    try expectPrice(&model, "abcdefgh", "h", state, .{ .distance = 1 }, 4 * 64);
}

test "LZMA advanced oracle hand counted nonuniform literal and matched literal trees" {
    var model = try encoder.initModel(options);
    model.is_match[0] = 512;
    model.literal_probabilities[0][1] = 512;
    model.literal_probabilities[0][3] = 512;
    // A5 is 10100101: is_match=0, root=1, node3=0, six uniform bits.
    try expectPrice(&model, "", &.{0xa5}, .{}, .{}, 128 + 27 + 128 + 6 * 64);

    model = try encoder.initModel(options);
    model.is_match[7 * 16] = 1536;
    model.literal_probabilities[0][513] = 512;
    model.literal_probabilities[0][259] = 1536;
    model.literal_probabilities[0][538] = 512;
    model.literal_probabilities[0][52] = 512;
    // AF/A5 share 1010, differ at bit4, then use ordinary nodes 52/105/210.
    const state = oracle.State{ .code = 7 };
    try expectPrice(&model, &.{0xaf}, &.{0xa5}, state, .{}, 27 + 27 + 27 + 64 + 64 + 128 + 27 + 64 + 64);
}

test "LZMA advanced oracle literal contexts use stream positions and virtual history" {
    var contextual = options;
    contextual.properties = .{ .lc = 2, .lp = 1, .pb = 2 };
    var model = try encoder.initModel(contextual);
    const history = [_]u8{0xc0};
    const input = [_]u8{ 0xa5, 0x34 };
    model.is_match[3] = 512;
    model.is_match[0] = 256;
    model.literal_probabilities[7][1] = 512;
    model.literal_probabilities[2][1] = 512;
    const source = matcher.Source.init(&history, &input, model.dictionary_size);
    // Global position3: ps3, lp1, previous C0 gives context 4+3=7.
    // Global position4: ps0, lp0, previous A5 gives context 0+2=2.
    for ([_]u32{ 128 + 27 + 7 * 64, 192 + 128 + 7 * 64 }, 0..) |expected, position| {
        try std.testing.expectEqual(expected, try oracle.tokenCost(&model, &history, &input, position, 3, .{}, .{}));
        try std.testing.expectEqual(expected, prices.literal(&model, source, position, 3, .{}));
    }
}

test "LZMA advanced oracle hand counted four repeat ranks and short repeat" {
    var model = try encoder.initModel(options);
    model.is_match[5 * 16] = 512;
    model.is_rep[5] = 1536;
    model.is_rep_g0[5] = 512;
    model.is_rep_g1[5] = 1536;
    model.is_rep_g2[5] = 512;
    model.is_rep_0long[5 * 16] = 1536;
    const state = oracle.State{ .code = 5, .distances = .{ 1, 3, 5, 7 } };
    const expected = [_]u32{ 27 + 128 + 128 + 128 + 256, 27 + 128 + 27 + 27 + 256, 27 + 128 + 27 + 128 + 128 + 256, 27 + 128 + 27 + 128 + 27 + 256 };
    for (state.distances, expected) |distance, cost|
        try expectPrice(&model, "abcdefgh", "ab", state, .{ .length = 2, .distance = distance }, cost);
    try expectPrice(&model, "abcdefgh", "h", state, .{ .distance = 1 }, 27 + 128 + 128 + 27);
}

test "LZMA advanced oracle length tree borders and nonuniform position states" {
    var model = try encoder.initModel(options);
    model.length.choice = 1536;
    model.length.choice2 = 512;
    model.rep_length.choice = 512;
    model.rep_length.choice2 = 1536;
    model.length.low[3][1] = 512;
    model.rep_length.low[3][1] = 1536;
    const actual = prices.Lengths.init(&model);
    for ([_]struct { symbol: usize, normal: u32, repeated: u32 }{
        .{ .symbol = 0, .normal = 27 + 192, .repeated = 128 + 192 },
        .{ .symbol = 7, .normal = 27 + 192, .repeated = 128 + 192 },
        .{ .symbol = 8, .normal = 128 + 128 + 192, .repeated = 27 + 27 + 192 },
        .{ .symbol = 15, .normal = 128 + 128 + 192, .repeated = 27 + 27 + 192 },
        .{ .symbol = 16, .normal = 128 + 27 + 512, .repeated = 27 + 128 + 512 },
        .{ .symbol = 271, .normal = 128 + 27 + 512, .repeated = 27 + 128 + 512 },
    }) |fixed| {
        try std.testing.expectEqual(fixed.normal, actual.normal[0][fixed.symbol]);
        try std.testing.expectEqual(fixed.repeated, actual.repeated[0][fixed.symbol]);
    }
    try std.testing.expectEqual(@as(u32, 27 + 128 + 128), actual.normal[3][0]);
    try std.testing.expectEqual(@as(u32, 128 + 27 + 128), actual.repeated[3][0]);
}

test "LZMA advanced oracle new distance slots reverse suffix direct bits and alignment" {
    var model = try encoder.initModel(options);
    // Sizes of distance recipes are fixed wire counts, including slot bits.
    for ([_]struct { distance: usize, bits: u32 }{
        .{ .distance = 1, .bits = 6 },                 .{ .distance = 4, .bits = 6 },
        .{ .distance = 5, .bits = 7 },                 .{ .distance = 8, .bits = 7 },
        .{ .distance = 9, .bits = 8 },                 .{ .distance = 128, .bits = 11 },
        .{ .distance = 129, .bits = 12 },              .{ .distance = 257, .bits = 13 },
        .{ .distance = 64 * 1024 * 1024, .bits = 30 },
    }) |fixed| {
        for (0..4) |length_state|
            try std.testing.expectEqual(fixed.bits * 64, prices.distance(&model, length_state, fixed.distance - 1));
    }
    model.positions[84] = 1536;
    model.positions[114] = 512;
    // Offset127: slot13=001101, reverse suffix11111 at 84/86/90/98/114.
    try std.testing.expectEqual(@as(u32, 11 * 64 + 64 - 37), prices.distance(&model, 0, 127));
    model = try encoder.initModel(options);
    model.position_slots[0][4] = 1536;
    model.position_slots[0][39] = 512;
    model.alignment[1] = 512;
    model.alignment[3] = 512;
    // Offset129: slot14=001110, two direct bits, alignment0001 LSB first.
    try std.testing.expectEqual(@as(u32, 12 * 64 + 64 + 64 - 37 + 64), prices.distance(&model, 0, 129));
    try expectPrice(&model, "", "ab", .{}, .{ .length = 2, .distance = 130 }, 18 * 64 + 64 + 64 - 37 + 64);
    try expectPrice(&model, "", "abc", .{}, .{ .length = 3, .distance = 130 }, 18 * 64 - 37 + 64);
}

fn assertReplay(model: *const encoder.Model, history: []const u8, input: []const u8, stream_start: usize, plan: encoder.AdvancedPlan) !oracle.Walk {
    const walked = try oracle.walk(model, history, input[0..plan.consumed], stream_start, plan.tokens);
    try std.testing.expectEqual(walked.state.code, plan.final_state.state);
    for (walked.state.distances, plan.final_state.reps) |distance, offset|
        try std.testing.expectEqual(distance - 1, offset);
    var emitted_model = model.*;
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(allocator);
    var range = range_encoder.Encoder.init(allocator, &output);
    var stats = encoder.EncodeStats{ .input_bytes = plan.consumed, .output_bytes = 0, .literals = 0, .matches = 0, .matched_bytes = 0, .repeat_matches = 0, .new_distance_matches = 0 };
    const consumed = try emitted_model.encodeTokensWithDictionary(&range, input[0..plan.consumed], history, plan.tokens, stream_start, &stats);
    try range.finish();
    try std.testing.expectEqual(plan.consumed, consumed);
    try std.testing.expectEqual(walked.state.code, emitted_model.state);
    for (walked.state.distances, emitted_model.reps) |distance, offset|
        try std.testing.expectEqual(distance - 1, offset);
    try std.testing.expectEqual(walked.matches, stats.repeat_matches + stats.new_distance_matches);
    try std.testing.expect(output.items.len >= 5);
    return walked;
}

test "LZMA advanced oracle exhaustive tiny graphs choose independent minimum without beam truncation" {
    const fixtures = [_]struct { history: []const u8, input: []const u8, state: usize = 0, reps: [4]usize = @splat(0) }{
        .{ .history = "", .input = "" },                                              .{ .history = "", .input = "x" },
        .{ .history = "", .input = "ababa" },                                         .{ .history = "", .input = "abcab" },
        .{ .history = "xy", .input = "xyx" },                                         .{ .history = "abcd", .input = "d", .state = 7, .reps = .{ 0, 1, 2, 3 } },
        .{ .history = "abcd", .input = "cd", .state = 7, .reps = .{ 0, 1, 2, 3 } },   .{ .history = "abcdef", .input = "de", .state = 7, .reps = .{ 0, 1, 2, 3 } },
        .{ .history = "abcdef", .input = "cd", .state = 7, .reps = .{ 0, 1, 2, 3 } },
    };
    for ([_]bool{ false, true }) |skewed| for (fixtures) |fixture| {
        var model = try encoder.initModel(options);
        model.state = fixture.state;
        model.reps = fixture.reps;
        if (skewed) {
            @memset(&model.is_match, 512);
            @memset(&model.is_rep, 1536);
            model.length.choice = 1536;
            model.rep_length.choice = 512;
            model.literal_probabilities[0][1] = 512;
            model.literal_probabilities[0][3] = 1536;
        }
        var exhaustive: oracle.Exhaustive = .{};
        try exhaustive.run(&model, fixture.history, fixture.input, fixture.history.len);
        // Count all reachable state/rep combinations, even expensive paths.
        // With at most eight per position, the production beam cannot prune.
        try std.testing.expect(exhaustive.maximumStates() <= 8);
        try std.testing.expect(exhaustive.paths >= 1);
        const plan = try encoder.advancedPlanPrefix(allocator, &model, fixture.history, fixture.input, fixture.history.len, options, true);
        defer plan.deinit(allocator);
        try std.testing.expectEqual(fixture.input.len, plan.consumed);
        const walked = try assertReplay(&model, fixture.history, fixture.input, fixture.history.len, plan);
        try std.testing.expectEqual(exhaustive.minimum, walked.cost);
    };
}

test "LZMA advanced oracle bounded beam reconstructs legal repeat states" {
    var model = try encoder.initModel(options);
    model.state = 7;
    model.reps = .{ 0, 1, 2, 3 };
    const history = "aaaa";
    const input = "aaaa";
    var exhaustive: oracle.Exhaustive = .{};
    try exhaustive.run(&model, history, input, history.len);
    try std.testing.expect(exhaustive.maximumStates() > 8);
    const plan = try encoder.advancedPlanPrefix(allocator, &model, history, input, history.len, options, true);
    defer plan.deinit(allocator);
    _ = try assertReplay(&model, history, input, history.len, plan);
    // Deliberately no global-minimum claim once the state beam is bounded.
}

test "LZMA advanced oracle 4096 endpoint clips tokens and preserves replay state" {
    var input: [4099]u8 = undefined;
    var random = std.Random.DefaultPrng.init(0x1763a09b);
    random.random().bytes(&input);
    const model = try encoder.initModel(options);
    const plan = try encoder.advancedPlanPrefix(allocator, &model, "", &input, 0, options, true);
    defer plan.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 4096), plan.consumed);
    _ = try assertReplay(&model, "", &input, 0, plan);
}
