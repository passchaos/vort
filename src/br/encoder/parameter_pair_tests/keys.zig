const std = @import("std");
const fixtures = @import("fixtures.zig");
const oracle = @import("oracle.zig");
const distance = @import("../distance.zig");
const context = @import("../literal_context_split.zig");

fn rejected(comptime C: type, data: fixtures.Fixture, session: *oracle.Session(C), state: *C.State, input: []const u8, commands: []const fixtures.Command, options: C.Options) !void {
    var heap = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    const initial = fixtures.stats(C.Stats, data);
    var stats = initial;
    try std.testing.expect(!state.matches(input, commands, options));
    try std.testing.expectError(error.InvalidBlockPlan, C.emitAlt(heap.allocator(), input, commands, &stats, options, &session.common.value, &session.literal.value, state));
    try std.testing.expectEqualDeep(initial, stats);
    try std.testing.expectEqual(@as(usize, 0), heap.alloc_index);
    var failed: oracle.Guarded(C.State) = .{ .value = state.* };
    try std.testing.expectError(error.InvalidBlockPlan, C.prepareAlt(heap.allocator(), input, commands, &stats, options, &session.common.value, &session.literal.value, &failed.value));
    try std.testing.expect(!failed.value.ready);
    try std.testing.expectEqualDeep(initial, stats);
    try std.testing.expectEqual(@as(usize, 0), heap.alloc_index);
    try failed.check();
    try session.unchanged(data);
}

pub fn check(comptime C: type) !void {
    const allocator = std.testing.allocator;
    const data = try fixtures.rich(allocator, 129, false);
    defer data.deinit(allocator);
    var session: oracle.Session(C) = undefined;
    try session.init(allocator, data, .{ .window_bits = 16 });
    defer session.deinit(allocator);
    const options = session.altOptions(distance.Parameters.init(3, 15));
    var state: oracle.Guarded(C.State) = .{ .value = .{} };
    try std.testing.expect(!state.value.matches(data.input, data.commands, options));
    var stats = fixtures.stats(C.Stats, data);
    _ = try C.prepareAlt(allocator, data.input, data.commands, &stats, options, &session.common.value, &session.literal.value, &state.value);
    const same_input = try allocator.dupe(u8, data.input);
    defer allocator.free(same_input);
    const same_commands = try allocator.dupe(fixtures.Command, data.commands);
    defer allocator.free(same_commands);
    try rejected(C, data, &session, &state.value, same_input, data.commands, options);
    try rejected(C, data, &session, &state.value, data.input[0 .. data.input.len - 1], data.commands, options);
    try rejected(C, data, &session, &state.value, data.input, same_commands, options);
    try rejected(C, data, &session, &state.value, data.input, data.commands[0 .. data.commands.len - 1], options);
    inline for (.{ "window_bits", "compound_dictionary_size", "initial_output_pos" }) |field| {
        var changed = options;
        @field(changed, field) += 1;
        try rejected(C, data, &session, &state.value, data.input, data.commands, changed);
    }
    for (0..4) |index| {
        var changed = options;
        changed.starting_last_distances[index] += 1;
        try rejected(C, data, &session, &state.value, data.input, data.commands, changed);
    }
    for (0..2) |index| {
        var changed = options;
        changed.initial_previous[index] += 1;
        try rejected(C, data, &session, &state.value, data.input, data.commands, changed);
    }
    inline for (.{ "large_window", "use_recent_distances", "use_utf8_text_contexts", "optimize_literal_tree_wire", "optimize_same_last_distance", "write_stream_prefix", "final_meta_block" }) |field| {
        var changed = options;
        @field(changed, field) = !@field(changed, field);
        try rejected(C, data, &session, &state.value, data.input, data.commands, changed);
    }
    var changed = options;
    changed.literal_context_candidate = context.Candidate.suffix(2, 56, 0);
    try rejected(C, data, &session, &state.value, data.input, data.commands, changed);
    changed = options;
    changed.utf8_context_cutoff -= 1;
    try rejected(C, data, &session, &state.value, data.input, data.commands, changed);
    changed = options;
    changed.literal_context_mode = (changed.literal_context_mode +% 1);
    try rejected(C, data, &session, &state.value, data.input, data.commands, changed);
    changed = options;
    changed.metadata = "nonempty metadata";
    try rejected(C, data, &session, &state.value, data.input, data.commands, changed);

    // A different candidate is legal to prepare, but stale emission must fail.
    changed = options;
    changed.distance_parameters = distance.Parameters.init(1, 1);
    var no_alloc = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    const initial = fixtures.stats(C.Stats, data);
    stats = initial;
    try std.testing.expect(!state.value.matches(data.input, data.commands, changed));
    try std.testing.expectError(error.InvalidBlockPlan, C.emitAlt(no_alloc.allocator(), data.input, data.commands, &stats, changed, &session.common.value, &session.literal.value, &state.value));
    try std.testing.expectEqualDeep(initial, stats);
    try std.testing.expectEqual(@as(usize, 0), no_alloc.alloc_index);
    var other_common = session.common.value;
    var other_literal = session.literal.value;
    try std.testing.expectError(error.InvalidBlockPlan, C.emitAlt(no_alloc.allocator(), data.input, data.commands, &stats, options, &other_common, &session.literal.value, &state.value));
    try std.testing.expectError(error.InvalidBlockPlan, C.emitAlt(no_alloc.allocator(), data.input, data.commands, &stats, options, &session.common.value, &other_literal, &state.value));
    try std.testing.expectEqualDeep(initial, stats);
    try std.testing.expectEqual(@as(usize, 0), no_alloc.alloc_index);
    session.common.value.reset();
    try rejected(C, data, &session, &state.value, data.input, data.commands, options);
    session.common.value.ready = true;
    session.literal.value.ready = false;
    try rejected(C, data, &session, &state.value, data.input, data.commands, options);
    session.literal.value.ready = true;
    const base_parameters = session.common.value.key.distance_parameters;
    session.common.value.key.distance_parameters = distance.Parameters.init(0, 15);
    try rejected(C, data, &session, &state.value, data.input, data.commands, options);
    session.common.value.key.distance_parameters = base_parameters;
    state.value.reset();
    try std.testing.expect(!state.value.matches(data.input, data.commands, options));
    try state.check();
    try session.unchanged(data);

    // Reach checked arithmetic with an otherwise valid captured model.
    const original_payload = session.literal.value.payload_bits;
    session.literal.value.payload_bits = std.math.maxInt(@TypeOf(original_payload));
    var overflow: oracle.Guarded(C.State) = .{ .value = .{} };
    stats = initial;
    try std.testing.expectError(error.IntegerOverflow, C.prepareAlt(allocator, data.input, data.commands, &stats, options, &session.common.value, &session.literal.value, &overflow.value));
    try std.testing.expect(!overflow.value.ready);
    try std.testing.expectEqualDeep(initial, stats);
    session.literal.value.payload_bits = original_payload;
    try overflow.check();
    try session.unchanged(data);

    changed = session.options;
    changed.initial_output_pos = std.math.maxInt(@TypeOf(changed.initial_output_pos));
    var physical_stats = initial;
    try std.testing.expectError(error.IntegerOverflow, oracle.physical(C, allocator, data, &physical_stats, changed));
    var common = C.Common.init(changed, data.commands);
    var literal: C.Literal = .{};
    stats = initial;
    try std.testing.expectError(error.IntegerOverflow, C.prepareBase(allocator, data.input, data.commands, &stats, changed, &common, &literal));
    try std.testing.expectEqualDeep(initial, stats);
    try std.testing.expect(!common.ready and !literal.ready);
}
