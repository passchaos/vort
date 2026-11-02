const std = @import("std");
const fixtures = @import("../prepared_adaptive_literal_tests/fixtures.zig");
const distance = @import("../distance.zig");

fn refuse(comptime Codec: type, input: []const u8, commands: []const Codec.Command, options: Codec.Options, common: *const Codec.Common, expected: anyerror) !void {
    if (Codec.prepareBorrowed(std.testing.allocator, input, commands, options, common)) |value| {
        var state = value;
        state.deinit(std.testing.allocator);
        return error.TestUnexpectedResult;
    } else |err| try std.testing.expect(err == expected);
}

pub fn check(comptime Codec: type) !void {
    const allocator = std.testing.allocator;
    const data = try fixtures.tiny(allocator);
    defer data.deinit(allocator);
    const base: Codec.Options = .{ .use_recent_distances = true, .adaptive_literal_split = &data.plan };
    var shared = try Codec.buildCommon(allocator, data.input, data.commands, base);
    var state = try Codec.prepareBorrowed(allocator, data.input, data.commands, base, &shared);
    defer state.deinit(allocator);
    var unready = Codec.Common.init(base, data.commands);
    try refuse(Codec, data.input, data.commands, base, &unready, error.InvalidBlockPlan);
    var exact = shared;
    exact.has_exact_commands = true;
    try refuse(Codec, data.input, data.commands, base, &exact, error.InvalidBlockPlan);
    inline for (.{ "window_bits", "initial_output_pos", "compound_dictionary_size" }) |field| {
        var changed = base;
        @field(changed, field) += 1;
        try refuse(Codec, data.input, data.commands, changed, &shared, error.InvalidBlockPlan);
    }
    for (0..4) |index| {
        var changed = base;
        changed.starting_last_distances[index] += 1;
        try refuse(Codec, data.input, data.commands, changed, &shared, error.InvalidBlockPlan);
    }
    inline for (.{ "use_recent_distances", "optimize_same_last_distance", "large_window" }) |field| {
        var changed = base;
        @field(changed, field) = !@field(changed, field);
        try refuse(Codec, data.input, data.commands, changed, &shared, error.InvalidBlockPlan);
    }
    var changed = base;
    changed.metadata = "unsupported";
    try refuse(Codec, data.input, data.commands, changed, &shared, error.InvalidBlockPlan);
    const other_commands = try allocator.dupe(Codec.Command, data.commands);
    defer allocator.free(other_commands);
    try refuse(Codec, data.input, other_commands, base, &shared, error.InvalidBlockPlan);
    try refuse(Codec, data.input[0..7], data.commands, base, &shared, error.InvalidBlockPlan);
    for (0..3) |kind| {
        var lengths = [_]u32{ 4, 4 };
        var types = [_]u8{ 0, 1 };
        var plan = data.plan;
        plan.lengths = &lengths;
        plan.types = &types;
        if (kind == 0) lengths[1] = 3;
        if (kind == 1) lengths[0] = 0;
        if (kind == 2) plan.type_count = 3;
        changed = base;
        changed.adaptive_literal_split = &plan;
        try refuse(Codec, data.input, data.commands, changed, &shared, error.InvalidBlockPlan);
    }
    // Smaller ordinary parameter shapes remain supported by the owned path;
    // this first borrowed increment intentionally limits scope to standard 0/15.
    var small = base;
    small.distance_parameters = distance.Parameters.init(0, 0);
    const small_common = try Codec.buildCommon(allocator, data.input, data.commands, small);
    var owned_small = try Codec.prepare(allocator, data.input, data.commands, small);
    defer owned_small.deinit(allocator);
    try refuse(Codec, data.input, data.commands, small, &small_common, error.InvalidBlockPlan);
    var stats: Codec.Stats = .{};
    shared.ready = false;
    try std.testing.expectError(error.InvalidBlockPlan, Codec.emit(allocator, data.input, data.commands, &stats, base, &state));
    shared.ready = true;
    const key = shared.key;
    shared.key.commands_ptr = other_commands.ptr;
    try std.testing.expectError(error.InvalidBlockPlan, Codec.emit(allocator, data.input, data.commands, &stats, base, &state));
    shared.key = key;
    shared.has_exact_commands = true;
    try std.testing.expectError(error.InvalidBlockPlan, Codec.emit(allocator, data.input, data.commands, &stats, base, &state));
    shared.has_exact_commands = false;
    try std.testing.expect(shared.ready and state.commonPlan() == &shared);
    // A real ready common built with this wide geometry can be reused for
    // the same commands, but a larger surrounding input must still overflow.
    var wide = base;
    wide.initial_output_pos = std.math.maxInt(@TypeOf(wide.initial_output_pos)) - 16;
    const wide_common = try Codec.buildCommon(allocator, data.input, data.commands, wide);
    const larger: [32]u8 = @splat('A');
    try refuse(Codec, &larger, data.commands, wide, &wide_common, error.IntegerOverflow);
}
