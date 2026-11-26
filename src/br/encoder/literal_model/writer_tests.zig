//! Real writer/prepared oracles for sharing literal trees within one group.
const std = @import("std");
const context = @import("../literal_context_split.zig");
const literal_context = @import("../literal_context.zig");
const split_plan = @import("../block_split_plan.zig");
const literal_entropy = @import("../literal_entropy_plan.zig");
const BitCount = @import("../../../io/bit_count.zig").BitCount;
const a = std.testing.allocator;

pub fn run(comptime Api: type) !void {
    try writerAndPrepared(Api);
    try literalKeyMisses(Api);
    try groupIdentityAndReset(Api);
    try unsupportedWriters(Api);
}

fn Fixture(comptime Api: type) type {
    return struct {
        const Self = @This();
        input: []u8,
        commands: []Api.Command,

        fn init() !Self {
            const commands = try a.alloc(Api.Command, 33);
            errdefer a.free(commands);
            var position: usize = 0;
            const distances = [_]usize{ 1, 5, 9, 13, 17, 21, 25, 29 };
            for (commands[0..32], 0..) |*command, index| {
                const inserted = if (index == 0) 512 else 1 + index % 7;
                command.* = .{ .insert_start = position, .insert_len = inserted, .copy_len = 4, .distance = distances[index & 7], .has_copy = true };
                position += inserted + 4;
            }
            commands[32] = .{ .insert_start = position, .insert_len = 16 };
            position += 16;
            const input = try a.alloc(u8, position);
            errdefer a.free(input);
            const phrase = "literal model: alpha=0007 beta=0042 record=accepted; utf8=\xc3\xa9\xe4\xb8\xad\n";
            for (commands) |command| {
                for (input[command.insert_start..][0..command.insert_len], command.insert_start..) |*byte, index|
                    byte.* = phrase[(index + index / 97) % phrase.len];
                if (command.has_copy) {
                    const start = command.insert_start + command.insert_len;
                    for (0..command.copy_len) |offset| input[start + offset] = input[start + offset - command.distance];
                }
            }
            return .{ .input = input, .commands = commands };
        }

        fn deinit(self: Self) void {
            a.free(self.input);
            a.free(self.commands);
        }
    };
}

fn distancePlan() !split_plan.Plan {
    // None of this fixture's copies repeats the immediately previous distance;
    // all 32 copies carry an explicit distance even with recent codes enabled.
    return split_plan.Plan.initCopy(a, &.{ 16, 16 }, &.{ 0, 1 }, 2, 32, 0);
}

fn preparedOptions(comptime Api: type, options: Api.Options, split: *const split_plan.Plan) Api.Options {
    var result = options;
    result.shared_literal_models = null;
    result.use_recent_distances = true;
    result.optimize_same_last_distance = false;
    result.command_split = null;
    result.adaptive_command_split = null;
    result.distance_split = null;
    result.adaptive_distance_split = split;
    return result;
}

fn writerAndPrepared(comptime Api: type) !void {
    const data = try Fixture(Api).init();
    defer data.deinit();
    const distances = try distancePlan();
    defer distances.deinit(a);
    const commands = try split_plan.Plan.initCopy(a, &.{ 16, 17 }, &.{ 0, 1 }, 2, data.commands.len, 0);
    defer commands.deinit(a);
    var signed_map: [64]u8 = undefined;
    for (&signed_map, 0..) |*tree, index| tree.* = @intCast(index & 1);
    const settings = [_]Api.Options{
        .{},
        .{ .use_utf8_text_contexts = true, .utf8_context_cutoff = 40 },
        .{ .literal_context_candidate = context.Candidate.suffix(literal_context.mode_utf8, 56, 0) },
        .{ .literal_context_candidate = context.Candidate.suffix(literal_context.mode_lsb6, 40, 0), .initial_previous = .{ 0xe3, 0xbf } },
        .{ .literal_context_candidate = context.Candidate.suffix(literal_context.mode_msb6, 20, 0) },
        .{ .literal_context_candidate = .{ .mode = literal_context.mode_signed, .tree_count = 2, .context_map = signed_map, .savings_bits = 17 }, .initial_previous = .{ 'a', 'Z' } },
        .{ .disable_literal_context_modeling = true, .literal_context_candidate = context.Candidate.suffix(literal_context.mode_utf8, 56, 0), .use_utf8_text_contexts = true },
        .{ .literal_context_candidate = context.Candidate.suffix(literal_context.mode_lsb6, 40, 0) },
        .{ .literal_context_candidate = .{ .mode = literal_context.mode_signed, .tree_count = 2, .context_map = signed_map, .savings_bits = 17 } },
    };
    const Shape = enum { plain, command_fixed, distance_fixed, both_fixed, distance_adaptive, command_adaptive };
    const Variant = struct { recent: bool, same: bool, shape: Shape = .plain };
    const variants = [_]Variant{
        .{ .recent = false, .same = false },
        .{ .recent = true, .same = false },
        .{ .recent = true, .same = true },
        .{ .recent = false, .same = true },
        .{ .recent = true, .same = false, .shape = .command_fixed },
        .{ .recent = false, .same = false, .shape = .distance_fixed },
        .{ .recent = true, .same = false, .shape = .both_fixed },
        .{ .recent = true, .same = false, .shape = .distance_adaptive },
        .{ .recent = true, .same = false, .shape = .command_adaptive },
    };
    var wire_oracles: usize = 0;
    var fresh_decodes: usize = 0;
    var seeded_history: usize = 0;
    var diagnosed_history = false;
    for (settings) |setting| for ([_]bool{ false, true }) |optimize| {
        var options = setting;
        options.optimize_literal_tree_wire = optimize;
        const preparation = preparedOptions(Api, options, &distances);
        var oracle: Api.State = undefined;
        var oracle_stats: Api.Stats = .{};
        const exact = try Api.prepareAdaptive(a, data.input, data.commands, preparation, &oracle, &oracle_stats);
        var preparation_stats: Api.Stats = .{};
        const preparation_wire = try Api.encode(a, data.input, data.commands, preparation, &preparation_stats);
        defer a.free(preparation_wire);
        try std.testing.expectEqual(preparation_wire.len, exact);
        try std.testing.expectEqualDeep(preparation_stats, oracle_stats);
        var owner = Api.Owner.init(data.input, data.commands);
        defer owner.deinit(a);
        var first_wire: ?[]u8 = null;
        defer if (first_wire) |wire| a.free(wire);
        var changed_header = false;
        for (variants, 0..) |variant, index| {
            var current = options;
            current.use_recent_distances = variant.recent;
            current.optimize_same_last_distance = variant.same;
            switch (variant.shape) {
                .plain => {},
                .command_fixed => current.command_split = .{ .split = 16, .savings_bits = 0 },
                .distance_fixed => current.distance_split = .{ .split = 16, .savings_bits = 0 },
                .both_fixed => {
                    current.command_split = .{ .split = 16, .savings_bits = 0 };
                    current.distance_split = .{ .split = 16, .savings_bits = 0 };
                },
                .distance_adaptive => current.adaptive_distance_split = &distances,
                .command_adaptive => current.adaptive_command_split = &commands,
            }
            var expected_stats: Api.Stats = .{};
            const expected = try Api.encode(a, data.input, data.commands, current, &expected_stats);
            defer a.free(expected);
            current.shared_literal_models = &owner;
            var actual_stats: Api.Stats = .{};
            const actual = try Api.encode(a, data.input, data.commands, current, &actual_stats);
            defer a.free(actual);
            try std.testing.expectEqualSlices(u8, expected, actual);
            try std.testing.expectEqualDeep(expected_stats, actual_stats);
            try std.testing.expectEqual(@as(usize, 1), owner.len);
            try std.testing.expectEqual(@as(usize, 1), owner.counters.builds);
            try expectModel(Api, &owner.slots[0], &oracle, data.input, data.commands, options);
            wire_oracles += 1;
            if (options.initial_previous[0] == 0 and options.initial_previous[1] == 0) {
                const decoded = try Api.decode(a, actual);
                defer a.free(decoded);
                try std.testing.expectEqualSlices(u8, data.input, decoded);
                fresh_decodes += 1;
            } else {
                // Nonzero initial history is a private writer configuration
                // requiring preceding context; the stream prefix does not
                // serialize it for a fresh decoder. Retain every complete
                // wire/stats/model/pure-bits oracle above without claiming an
                // independent fresh-frame round trip for these configurations.
                seeded_history += 1;
                if (!diagnosed_history) {
                    try diagnoseSeededHistory(Api, data.input, expected, actual);
                    diagnosed_history = true;
                }
            }
            if (index == 0) first_wire = try a.dupe(u8, actual) else if (!std.mem.eql(u8, first_wire.?, actual)) changed_header = true;
        }
        try std.testing.expect(changed_header);
        try std.testing.expect(owner.counters.hits >= variants.len - 1);
        var shared_preparation = preparation;
        shared_preparation.shared_literal_models = &owner;
        var shared_state: Api.State = undefined;
        var shared_stats: Api.Stats = .{};
        const shared_exact = try Api.prepareAdaptive(a, data.input, data.commands, shared_preparation, &shared_state, &shared_stats);
        try std.testing.expectEqual(exact, shared_exact);
        try std.testing.expectEqualDeep(oracle_stats, shared_stats);
        try expectPrepared(Api, &oracle, &shared_state);

        // Reverse the producer/consumer direction. The temporary adaptive
        // common is already destroyed when the ordinary writer borrows trees.
        var reverse = Api.Owner.init(data.input, data.commands);
        defer reverse.deinit(a);
        shared_preparation.shared_literal_models = &reverse;
        _ = try Api.prepareAdaptive(a, data.input, data.commands, shared_preparation, &shared_state, &shared_stats);
        try std.testing.expectEqual(@as(usize, 1), reverse.counters.builds);
        try expectModel(Api, &reverse.slots[0], &oracle, data.input, data.commands, options);
        var cold = options;
        cold.use_recent_distances = true;
        cold.optimize_same_last_distance = false;
        cold.command_split = .{ .split = 16, .savings_bits = 0 };
        cold.distance_split = .{ .split = 16, .savings_bits = 0 };
        var expected_stats: Api.Stats = .{};
        const expected = try Api.encode(a, data.input, data.commands, cold, &expected_stats);
        defer a.free(expected);
        cold.shared_literal_models = &reverse;
        var actual_stats: Api.Stats = .{};
        const actual = try Api.encode(a, data.input, data.commands, cold, &actual_stats);
        defer a.free(actual);
        try std.testing.expectEqualSlices(u8, expected, actual);
        try std.testing.expectEqualDeep(expected_stats, actual_stats);
        try std.testing.expect(reverse.counters.hits > 0);
    };
    try std.testing.expectEqual(@as(usize, 162), wire_oracles);
    try std.testing.expectEqual(@as(usize, 126), fresh_decodes);
    try std.testing.expectEqual(@as(usize, 36), seeded_history);
    std.debug.print("literal_model_writer variant_wire_oracles={d} fresh_frame_decodes={d} seeded_history_oracles={d}\n", .{
        wire_oracles, fresh_decodes, seeded_history,
    });
}

fn diagnoseSeededHistory(comptime Api: type, input: []const u8, expected: []const u8, actual: []const u8) !void {
    // This one diagnostic uses the standard fresh-history decoder on both
    // identical seeded-history wires. It identifies the oracle mismatch;
    // these diagnostic decodes are excluded from fresh-frame coverage counts.
    const uncached = try Api.decode(a, expected);
    defer a.free(uncached);
    const cached = try Api.decode(a, actual);
    defer a.free(cached);
    try std.testing.expectEqualSlices(u8, uncached, cached);
    std.debug.print("literal_model_writer seeded_history_diagnostic uncached_first_difference={any} cached_first_difference={any} decoded_equal=true\n", .{
        firstDifference(input, uncached), firstDifference(input, cached),
    });
}

fn firstDifference(expected: []const u8, actual: []const u8) ?usize {
    const common = @min(expected.len, actual.len);
    for (expected[0..common], actual[0..common], 0..) |left, right, index|
        if (left != right) return index;
    return if (expected.len == actual.len) null else common;
}

fn expectPrepared(comptime Api: type, expected: *const Api.State, actual: *const Api.State) !void {
    try std.testing.expect(actual.ready);
    try std.testing.expectEqual(expected.tree_count, actual.tree_count);
    try std.testing.expectEqual(expected.header_bits, actual.header_bits);
    try std.testing.expectEqual(expected.payload_bits, actual.payload_bits);
    try std.testing.expectEqual(expected.wire_len, actual.wire_len);
    for (0..expected.tree_count) |tree| {
        try std.testing.expectEqual(expected.alphabets[tree].len, actual.alphabets[tree].len);
        try std.testing.expectEqualSlices(u16, expected.alphabets[tree].symbols[0..expected.alphabets[tree].len], actual.alphabets[tree].symbols[0..actual.alphabets[tree].len]);
        for (expected.alphabets[tree].symbols[0..expected.alphabets[tree].len]) |symbol|
            try std.testing.expectEqual(expected.lengths[tree][symbol], actual.lengths[tree][symbol]);
    }
}

fn expectModel(comptime Api: type, model: anytype, oracle: *const Api.State, input: []const u8, commands: []const Api.Command, options: Api.Options) !void {
    try std.testing.expect(model.key.matches(input, options));
    try std.testing.expectEqual(oracle.tree_count, model.alphabets.len);
    try std.testing.expectEqual(oracle.tree_count, model.lengths.len);
    if (oracle.normalized_context) |candidate| {
        try std.testing.expect(model.normalized_context != null);
        try std.testing.expect(context.Candidate.eql(candidate, model.normalized_context.?));
    } else try std.testing.expect(model.normalized_context == null);
    var symbols: usize = 0;
    for (0..oracle.tree_count) |tree| {
        const expected = &oracle.alphabets[tree];
        const actual = &model.alphabets[tree];
        try std.testing.expectEqual(expected.len, actual.len);
        try std.testing.expectEqualSlices(u16, expected.symbols[0..expected.len], actual.symbols[0..actual.len]);
        for (expected.symbols[0..expected.len]) |symbol|
            try std.testing.expectEqual(oracle.lengths[tree][symbol], model.lengths[tree][symbol]);
        symbols += expected.len;
    }
    try std.testing.expectEqual(symbols, model.symbolCount());
    var literal_count: usize = 0;
    var pure_bits: BitCount = 0;
    for (commands) |command| {
        for (input[command.insert_start..][0..command.insert_len], command.insert_start..) |byte, position| {
            const tree = if (oracle.normalized_context) |candidate| blk: {
                const previous = if (position == 0) options.initial_previous[1] else input[position - 1];
                const second = if (position == 0) options.initial_previous[0] else if (position == 1) options.initial_previous[1] else input[position - 2];
                break :blk candidate.treeFor(literal_context.value(candidate.mode, previous, second));
            } else 0;
            // Scalar per-literal code widths from the independent prepared
            // writer, without command/distance bits or header/alignment reuse.
            pure_bits += oracle.lengths[tree][byte];
            literal_count += 1;
        }
    }
    try std.testing.expectEqual(literal_count, model.literal_count);
    try std.testing.expectEqual(pure_bits, model.literal_payload_bits);
    try std.testing.expect(oracle.payload_bits > pure_bits);
}

fn literalKeyMisses(comptime Api: type) !void {
    const data = try Fixture(Api).init();
    defer data.deinit();
    const split = try distancePlan();
    defer split.deinit(a);
    const primary = context.Candidate.suffix(literal_context.mode_lsb6, 40, 0);
    var changed_map = primary;
    changed_map.context_map[0] = 1;
    var changed_mode = primary;
    changed_mode.mode = literal_context.mode_msb6;
    const options = [_]Api.Options{
        .{ .literal_context_candidate = primary },
        .{ .literal_context_candidate = primary, .initial_previous = .{ 0xe3, 0xbf } },
        .{ .literal_context_candidate = changed_map },
        .{ .literal_context_candidate = changed_mode },
        .{ .literal_context_candidate = primary, .optimize_literal_tree_wire = true },
    };
    var owner = Api.Owner.init(data.input, data.commands);
    defer owner.deinit(a);
    for (options, 0..) |option, index| {
        var expected_stats: Api.Stats = .{};
        const expected = try Api.encode(a, data.input, data.commands, option, &expected_stats);
        defer a.free(expected);
        var current = option;
        current.shared_literal_models = &owner;
        const hits = owner.counters.hits;
        var actual_stats: Api.Stats = .{};
        const actual = try Api.encode(a, data.input, data.commands, current, &actual_stats);
        defer a.free(actual);
        try std.testing.expectEqualSlices(u8, expected, actual);
        try std.testing.expectEqualDeep(expected_stats, actual_stats);
        try std.testing.expectEqual(index + 1, owner.counters.builds);
        try std.testing.expectEqual(hits, owner.counters.hits);
        var state: Api.State = undefined;
        var stats: Api.Stats = .{};
        _ = try Api.prepareAdaptive(a, data.input, data.commands, preparedOptions(Api, option, &split), &state, &stats);
        try expectModel(Api, &owner.slots[index], &state, data.input, data.commands, option);
    }
}

fn groupIdentityAndReset(comptime Api: type) !void {
    const data = try Fixture(Api).init();
    defer data.deinit();
    const other = try a.dupe(Api.Command, data.commands);
    defer a.free(other);
    other[1].insert_len += 1;
    other[1].copy_len -= 1;
    var owner = Api.Owner.init(data.input, data.commands);
    defer owner.deinit(a);
    const options: Api.Options = .{ .shared_literal_models = &owner };
    var stats: Api.Stats = .{};
    const prior = try Api.encode(a, data.input, data.commands, options, &stats);
    defer a.free(prior);
    const initial_hits = owner.counters.hits;
    var expected_stats: Api.Stats = .{};
    const expected = try Api.encode(a, data.input, other, .{}, &expected_stats);
    defer a.free(expected);
    stats = .{};
    const actual = try Api.encode(a, data.input, other, options, &stats);
    defer a.free(actual);
    try std.testing.expectEqualSlices(u8, expected, actual);
    try std.testing.expectEqualDeep(expected_stats, stats);
    try std.testing.expectEqual(initial_hits, owner.counters.hits);
    try std.testing.expectEqual(@as(usize, 1), owner.len);
    var fresh = Api.Owner.init(data.input, other);
    defer fresh.deinit(a);
    var fresh_options: Api.Options = .{ .shared_literal_models = &fresh };
    stats = .{};
    const new_group = try Api.encode(a, data.input, other, fresh_options, &stats);
    defer a.free(new_group);
    try std.testing.expectEqualSlices(u8, expected, new_group);
    try std.testing.expectEqualDeep(expected_stats, stats);
    try std.testing.expectEqual(@as(usize, 1), fresh.counters.builds);
    try std.testing.expectEqual(@as(usize, 0), fresh.counters.hits);

    const input_ptr = data.input.ptr;
    const command_ptr = data.commands.ptr;
    fresh.deinit(a);
    owner.reset(a, data.input, data.commands);
    data.input[0] = 0xff;
    data.commands[1] = other[1];
    try std.testing.expectEqual(input_ptr, data.input.ptr);
    try std.testing.expectEqual(command_ptr, data.commands.ptr);
    try std.testing.expectEqual(@as(usize, 0), owner.len);
    expected_stats = .{};
    const reset_expected = try Api.encode(a, data.input, data.commands, .{}, &expected_stats);
    defer a.free(reset_expected);
    fresh_options.shared_literal_models = &owner;
    stats = .{};
    const reset_actual = try Api.encode(a, data.input, data.commands, fresh_options, &stats);
    defer a.free(reset_actual);
    try std.testing.expectEqualSlices(u8, reset_expected, reset_actual);
    try std.testing.expectEqualDeep(expected_stats, stats);
    try std.testing.expect(!std.mem.eql(u8, prior, reset_actual));
    try std.testing.expectEqual(@as(usize, 1), owner.counters.builds);
    const decoded = try Api.decode(a, reset_actual);
    defer a.free(decoded);
    try std.testing.expectEqualSlices(u8, data.input, decoded);
}

fn unsupportedWriters(comptime Api: type) !void {
    var input: [512]u8 = undefined;
    for (&input, 0..) |*byte, index| byte.* = @intCast('a' + index % 19);
    const commands = [_]Api.Command{.{ .insert_start = 0, .insert_len = input.len }};
    var owner = Api.Owner.init(&input, &commands);
    defer owner.deinit(a);
    var stats: Api.Stats = .{};
    const baseline = try Api.encode(a, &input, &commands, .{ .shared_literal_models = &owner }, &stats);
    defer a.free(baseline);
    const before = owner.counters;
    const temporal = try split_plan.Plan.initCopy(a, &.{ 256, 256 }, &.{ 0, 1 }, 2, input.len, 0);
    defer temporal.deinit(a);
    var map: [128]u8 = undefined;
    @memset(map[0..64], 0);
    @memset(map[64..], 1);
    const joint = try literal_entropy.Plan.initCopy(a, temporal, &.{ literal_context.mode_lsb6, literal_context.mode_utf8 }, &map, 2, input.len);
    defer joint.deinit(a);
    const HqModel = @typeInfo(@typeInfo(@FieldType(Api.Options, "hq_model_output")).optional.child).pointer.child;
    var hq = HqModel.init((Api.Options{}).distance_parameters, literal_context.mode_lsb6);
    const cases = [_]Api.Options{
        .{ .literal_split = .{ .split = 256, .savings_bits = 0 }, .optimize_same_last_distance = false },
        .{ .adaptive_literal_split = &temporal, .optimize_same_last_distance = false },
        .{ .adaptive_literal_split = &temporal, .literal_entropy_plan = &joint, .optimize_same_last_distance = false },
        .{ .hq_model_output = &hq, .optimize_same_last_distance = false },
        .{ .metadata = "literal model fallback control" },
    };
    for (cases) |option| {
        var expected_stats: Api.Stats = .{};
        const expected = try Api.encode(a, &input, &commands, option, &expected_stats);
        defer a.free(expected);
        var current = option;
        current.shared_literal_models = &owner;
        stats = .{};
        const actual = try Api.encode(a, &input, &commands, current, &stats);
        defer a.free(actual);
        try std.testing.expectEqualSlices(u8, expected, actual);
        try std.testing.expectEqualDeep(expected_stats, stats);
        try std.testing.expectEqual(before.builds, owner.counters.builds);
        try std.testing.expectEqual(before.hits, owner.counters.hits);
        try std.testing.expectEqual(@as(usize, 1), owner.len);
        const decoded = try Api.decode(a, actual);
        defer a.free(decoded);
        try std.testing.expectEqualSlices(u8, &input, decoded);
    }
}
