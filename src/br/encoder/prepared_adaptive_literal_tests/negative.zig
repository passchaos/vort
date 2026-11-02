const std = @import("std");
const fixtures = @import("fixtures.zig");
const context = @import("../literal_context_split.zig");
const distance = @import("../distance.zig");

fn rejected(comptime Codec: type, input: []const u8, commands: []const Codec.Command, options: Codec.Options) !void {
    if (Codec.prepare(std.testing.allocator, input, commands, options)) |value| {
        var state = value;
        state.deinit(std.testing.allocator);
        return error.TestUnexpectedResult;
    } else |err| try std.testing.expect(err == error.InvalidBlockPlan);
}

fn literalLimit(comptime Codec: type) !void {
    const allocator = std.testing.allocator;
    const input = try allocator.alloc(u8, 65537);
    defer allocator.free(input);
    @memset(input[0..32768], 'A');
    @memset(input[32768..], 'B');
    var lengths = [_]u32{ 32768, 32768 };
    var types = [_]u8{ 0, 1 };
    const plan: Codec.Plan = .{ .lengths = &lengths, .types = &types, .type_count = 2, .estimated_bits = 0 };
    var commands = [_]Codec.Command{.{ .insert_start = 0, .insert_len = 65536 }};
    const options: Codec.Options = .{ .use_recent_distances = true, .adaptive_literal_split = &plan };
    try std.testing.expect(Codec.supported(input[0..65536], &commands, options));
    var state = try Codec.prepare(allocator, input[0..65536], &commands, options);
    defer state.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 65536), state.literal_count);
    var expected_stats: Codec.Stats = .{};
    const expected = try Codec.encode(allocator, input[0..65536], &commands, &expected_stats, options);
    defer allocator.free(expected);
    var actual_stats: Codec.Stats = .{};
    const actual = try Codec.emit(allocator, input[0..65536], &commands, &actual_stats, options, &state);
    defer allocator.free(actual);
    try std.testing.expectEqualSlices(u8, expected, actual);
    try std.testing.expectEqualDeep(expected_stats, actual_stats);
    lengths[1] = 32769;
    commands[0].insert_len = 65537;
    try std.testing.expect(!Codec.supported(input, &commands, options));
    var denied = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    if (Codec.prepare(denied.allocator(), input, &commands, options)) |value| {
        var rejected_state = value;
        rejected_state.deinit(denied.allocator());
        return error.TestUnexpectedResult;
    } else |err| try std.testing.expect(err == error.InvalidBlockPlan);
    try std.testing.expect(!denied.has_induced_failure and denied.allocations == 0);
    // Restore borrowed plan data before its live state is released.
    lengths[1] = 32768;
    commands[0].insert_len = 65536;
}

pub fn check(comptime Codec: type) !void {
    const allocator = std.testing.allocator;
    var data = try fixtures.tiny(allocator);
    defer data.deinit(allocator);
    const base: Codec.Options = .{ .use_recent_distances = true, .adaptive_literal_split = &data.plan };
    var prepared = try Codec.prepare(allocator, data.input, data.commands, base);
    defer prepared.deinit(allocator);
    var overflow = base;
    overflow.initial_output_pos = std.math.maxInt(@TypeOf(overflow.initial_output_pos));
    if (Codec.prepare(allocator, data.input, data.commands, overflow)) |value| {
        var state = value;
        state.deinit(allocator);
        return error.TestUnexpectedResult;
    } else |err| try std.testing.expect(err == error.IntegerOverflow);
    for (0..7) |kind| {
        var lengths = [_]u32{ 4, 4 };
        var types = [_]u8{ 0, 1 };
        var plan: Codec.Plan = .{ .lengths = &lengths, .types = &types, .type_count = 2, .estimated_bits = 0 };
        if (kind == 0) {
            plan.lengths = lengths[0..0];
            plan.types = types[0..0];
        }
        if (kind == 1) plan.types = types[0..1];
        if (kind == 2) lengths[0] = 0;
        if (kind == 3) types[1] = 2;
        if (kind == 4) plan.type_count = 3;
        if (kind == 5) types[1] = 0;
        if (kind == 6) lengths[1] = 3;
        var options = base;
        options.adaptive_literal_split = &plan;
        try rejected(Codec, data.input, data.commands, options);
    }
    for (0..2) |kind| {
        var bad = data.commands[0];
        if (kind == 0) bad.insert_start = data.input.len + 1 else bad.insert_len = data.input.len + 1;
        const commands = [_]Codec.Command{bad};
        try rejected(Codec, data.input, &commands, base);
    }
    for (0..11) |kind| {
        var options = base;
        if (kind == 0) options.large_window = true;
        if (kind == 1) options.use_recent_distances = false;
        if (kind == 2) options.window_bits = 9;
        if (kind == 3) options.window_bits = 25;
        if (kind == 4) options.metadata = "unsupported";
        if (kind == 5) options.write_stream_prefix = false;
        if (kind == 6) options.final_meta_block = false;
        if (kind == 7) options.use_utf8_text_contexts = true;
        if (kind == 8) options.literal_context_candidate = context.Candidate.suffix(2, 56, 0);
        if (kind == 9) options.adaptive_command_split = &data.plan;
        if (kind == 10) options.adaptive_distance_split = &data.plan;
        try std.testing.expect(!Codec.supported(data.input, data.commands, options));
        try rejected(Codec, data.input, data.commands, options);
    }
    var exact = data.commands[0];
    exact.hq_encoding = .{ .command_symbol = 0 };
    const exact_commands = [_]Codec.Command{exact};
    try std.testing.expect(!Codec.supported(data.input, &exact_commands, base));
    try rejected(Codec, data.input, &exact_commands, base);
    var stats: Codec.Stats = .{};
    inline for (.{ "window_bits", "initial_output_pos", "compound_dictionary_size", "literal_context_mode" }) |field| {
        var changed = base;
        @field(changed, field) += 1;
        try std.testing.expectError(error.InvalidBlockPlan, Codec.emit(allocator, data.input, data.commands, &stats, changed, &prepared));
    }
    for (0..4) |index| {
        var changed = base;
        changed.starting_last_distances[index] += 1;
        try std.testing.expectError(error.InvalidBlockPlan, Codec.emit(allocator, data.input, data.commands, &stats, changed, &prepared));
    }
    var changed = base;
    changed.distance_parameters = distance.Parameters.init(0, 0);
    try std.testing.expectError(error.InvalidBlockPlan, Codec.emit(allocator, data.input, data.commands, &stats, changed, &prepared));
    const commands = try allocator.dupe(Codec.Command, data.commands);
    defer allocator.free(commands);
    try std.testing.expectError(error.InvalidBlockPlan, Codec.emit(allocator, data.input, commands, &stats, base, &prepared));
    const input = try allocator.dupe(u8, data.input);
    defer allocator.free(input);
    try std.testing.expectError(error.InvalidBlockPlan, Codec.emit(allocator, input, data.commands, &stats, base, &prepared));
    try std.testing.expectError(error.InvalidBlockPlan, Codec.emit(allocator, data.input[0..7], data.commands, &stats, base, &prepared));
    var other = data.plan;
    changed = base;
    changed.adaptive_literal_split = &other;
    try std.testing.expectError(error.InvalidBlockPlan, Codec.emit(allocator, data.input, data.commands, &stats, changed, &prepared));
    const lengths = try allocator.dupe(u32, data.plan.lengths);
    defer allocator.free(lengths);
    const types = try allocator.dupe(u8, data.plan.types);
    defer allocator.free(types);
    const old_lengths = data.plan.lengths;
    data.plan.lengths = lengths;
    try std.testing.expectError(error.InvalidBlockPlan, Codec.emit(allocator, data.input, data.commands, &stats, base, &prepared));
    data.plan.lengths = old_lengths;
    const old_types = data.plan.types;
    data.plan.types = types;
    try std.testing.expectError(error.InvalidBlockPlan, Codec.emit(allocator, data.input, data.commands, &stats, base, &prepared));
    data.plan.types = old_types;
    data.plan.type_count = 3;
    try std.testing.expectError(error.InvalidBlockPlan, Codec.emit(allocator, data.input, data.commands, &stats, base, &prepared));
    data.plan.type_count = 2;
    data.plan.lengths = old_lengths[0..1];
    data.plan.types = old_types[0..1];
    try std.testing.expectError(error.InvalidBlockPlan, Codec.emit(allocator, data.input, data.commands, &stats, base, &prepared));
    data.plan.lengths = old_lengths;
    data.plan.types = old_types;
    // A fully initialized key with an unprepared common is rejected before
    // any undefined common histogram/tree storage can be read.
    var unready = prepared;
    unready.common = @import("../prepared_command_distance.zig").Prepared.init(base, data.commands);
    try std.testing.expectError(error.InvalidBlockPlan, Codec.emit(allocator, data.input, data.commands, &stats, base, &unready));
    try std.testing.expect(prepared.common.ready and prepared.key.matches(data.input, data.commands, base));
    try literalLimit(Codec);
}
