//! Exact prepared-literal integration against the independent full writer.
const std = @import("std");
const lz77 = @import("../../lz77.zig");
const bit_count = @import("../../io/bit_count.zig");
const command_plan = @import("command_plan.zig");
const context = @import("literal_context_split.zig");
const common_prepared = @import("prepared_command_distance.zig");
const prepared_literal = @import("prepared_literal.zig");

pub fn run(
    comptime Options: type,
    comptime Stats: type,
    comptime encode: anytype,
    comptime prepare: anytype,
    comptime emit: anytype,
) !void {
    const allocator = std.testing.allocator;
    var mixed: [8192]u8 = undefined;
    fillMixed(&mixed);
    const tokens = try lz77.hashGreedyPlanAlloc(allocator, &mixed, .{ .min_match = 4, .max_chain = 64, .max_candidates = 4 });
    defer tokens.deinit(allocator);
    const plan = try command_plan.buildAlloc(allocator, &mixed, tokens.tokens);
    defer plan.deinit(allocator);
    try std.testing.expect(plan.commands.len > common_prepared.symbol_capacity);
    try compare(Options, Stats, encode, prepare, emit, &mixed, plan.commands, null);

    for (1..5) |symbol_count| {
        const fixture = try smallFixture(allocator, symbol_count);
        defer fixture.deinit(allocator);
        try compare(Options, Stats, encode, prepare, emit, fixture.input, fixture.plan.commands, symbol_count);
    }
}

fn fillMixed(input: []u8) void {
    var random: u32 = 0x243f_6a88;
    var position: usize = 0;
    var record: usize = 0;
    const repeated = " repeated common value: the quick brown fox jumps over the lazy dog";
    while (position < input.len) : (record += 1) {
        for (0..4 + record % 19) |_| {
            if (position == input.len) break;
            random = random *% 1664525 +% 1013904223;
            input[position] = @truncate(random >> 24);
            position += 1;
        }
        for (0..4 + (record * 7) % 60) |index| {
            if (position == input.len) break;
            input[position] = repeated[index];
            position += 1;
        }
    }
}

const Fixture = struct {
    input: []u8,
    plan: command_plan.Plan,

    fn deinit(self: Fixture, allocator: std.mem.Allocator) void {
        allocator.free(self.input);
        self.plan.deinit(allocator);
    }
};

/// The initial most recent distance is 4. Constant insert lengths and distinct
/// copy lengths give exactly 1..4 command symbols with one distance symbol.
/// Copy bytes are materialized from the actual history to keep every plan legal.
fn smallFixture(allocator: std.mem.Allocator, symbols: usize) !Fixture {
    const input_len = 16 * symbols + symbols * (symbols + 3) / 2;
    const input = try allocator.alloc(u8, input_len);
    errdefer allocator.free(input);
    const commands = try allocator.alloc(command_plan.Command, symbols);
    errdefer allocator.free(commands);
    var position: usize = 0;
    for (commands, 0..) |*command, index| {
        command.* = .{ .insert_start = position, .insert_len = 16, .copy_len = index + 2, .distance = 4, .has_copy = true };
        for (input[position..][0..16], 0..) |*literal, literal_index|
            literal.* = @intCast(0x20 + literal_index % symbols);
        position += 16;
        for (0..command.copy_len) |_| {
            input[position] = input[position - command.distance];
            position += 1;
        }
    }
    std.debug.assert(position == input.len);
    return .{ .input = input, .plan = .{ .commands = commands, .match_count = symbols } };
}

fn initialStats(comptime Stats: type, input: []const u8, commands: []const command_plan.Command) Stats {
    var stats: Stats = .{ .input_bytes = input.len, .command_count = commands.len };
    for (commands) |command| {
        stats.literal_bytes += command.insert_len;
        stats.matched_bytes += command.outputLen();
    }
    stats.token_count = stats.literal_bytes + commands.len;
    return stats;
}

fn compare(
    comptime Options: type,
    comptime Stats: type,
    comptime encode: anytype,
    comptime prepare: anytype,
    comptime emit: anytype,
    input: []const u8,
    commands: []const command_plan.Command,
    small_symbols: ?usize,
) !void {
    const allocator = std.testing.allocator;
    var options: Options = .{ .use_recent_distances = true, .literal_context_candidate = context.Candidate.suffix(2, 56, 0) };
    var common = common_prepared.Prepared.init(options, commands);
    options.prepared_common = &common;
    var warm_stats = initialStats(Stats, input, commands);
    const warm = try encode(allocator, input, commands, &warm_stats, options);
    defer allocator.free(warm);
    try std.testing.expect(common.matches(options, commands));
    if (small_symbols) |symbols| {
        try std.testing.expectEqual(symbols, common.command_alphabet.len);
        try std.testing.expectEqual(@as(usize, 1), common.distance_alphabet.len);
    } else {
        try std.testing.expect(input.len >= 8192);
        try std.testing.expect(commands.len > 128);
        try std.testing.expect(common.command_alphabet.len > 4);
    }

    for (0..8) |variant| {
        errdefer std.debug.print("prepared literal input={d} commands={d} variant={d}\n", .{ input.len, commands.len, variant });
        options.literal_context_candidate = if (variant < 4)
            context.Candidate.suffix(@intCast(variant), @intCast(16 + variant * 12), 0)
        else
            null;
        options.use_utf8_text_contexts = variant == 5 or variant == 7;
        options.optimize_literal_tree_wire = variant == 6 or variant == 7;
        options.literal_context_mode = @intCast(variant % 4);
        var independent_options = options;
        independent_options.prepared_common = null;
        independent_options.prepared_literal = null;
        var expected_stats = initialStats(Stats, input, commands);
        const expected = try encode(allocator, input, commands, &expected_stats, independent_options);
        defer allocator.free(expected);

        var state: prepared_literal.State = .{};
        var measured_stats = initialStats(Stats, input, commands);
        try prepare(allocator, input, commands, &measured_stats, options, &state);
        try std.testing.expect(state.matches(input, options));
        try std.testing.expectEqual(expected.len, state.wire_len);
        try std.testing.expectEqual(expected.len, try bit_count.ceilBytes(state.header_bits + state.payload_bits));
        try std.testing.expectEqualDeep(expected_stats, measured_stats);
        if (variant == 4 and small_symbols != null) {
            try std.testing.expectEqual(@as(usize, 1), state.tree_count);
            try std.testing.expectEqual(small_symbols.?, state.alphabets[0].len);
        }

        // Emission receives the semantic statistics produced during counting,
        // as it does when the selected candidate is emitted by the caller.
        var emitted_stats = measured_stats;
        const actual = try emit(allocator, input, commands, &emitted_stats, options, &state);
        defer allocator.free(actual);
        try std.testing.expectEqualSlices(u8, expected, actual);
        try std.testing.expectEqualDeep(expected_stats, emitted_stats);
        try std.testing.expect(state.matches(input, options));
        try countFailures(Stats, prepare, input, commands, options, &state, expected_stats);
        if (variant == 7) try wrongKeys(Options, Stats, prepare, emit, input, commands, options, &state);
    }
}

fn countFailures(
    comptime Stats: type,
    comptime prepare: anytype,
    input: []const u8,
    commands: []const command_plan.Command,
    options: anytype,
    expected_state: *const prepared_literal.State,
    expected_stats: Stats,
) !void {
    var probe_heap = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    var probe_state: prepared_literal.State = .{};
    var probe_stats = initialStats(Stats, input, commands);
    try prepare(probe_heap.allocator(), input, commands, &probe_stats, options, &probe_state);
    try std.testing.expectEqual(expected_state.wire_len, probe_state.wire_len);
    try std.testing.expectEqualDeep(expected_stats, probe_stats);
    try std.testing.expectEqual(probe_heap.allocated_bytes, probe_heap.freed_bytes);

    // The current fixed-storage path can make no requests. Test fail_index=0
    // in that case, and inject every actual allocation if the path grows one.
    for (0..probe_heap.alloc_index + 1) |fail_index| {
        var heap = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = fail_index });
        var state: prepared_literal.State = .{};
        state.copyFrom(expected_state);
        var stats = initialStats(Stats, input, commands);
        if (prepare(heap.allocator(), input, commands, &stats, options, &state)) |_| {
            try std.testing.expect(!heap.has_induced_failure);
            try std.testing.expect(state.matches(input, options));
            try std.testing.expectEqual(expected_state.wire_len, state.wire_len);
            try std.testing.expectEqualDeep(expected_stats, stats);
        } else |err| {
            try std.testing.expect(err == error.OutOfMemory);
            try std.testing.expect(heap.has_induced_failure);
            try std.testing.expect(!state.ready);
        }
        try std.testing.expectEqual(heap.allocated_bytes, heap.freed_bytes);
    }
}

fn wrongKeys(
    comptime Options: type,
    comptime Stats: type,
    comptime prepare: anytype,
    comptime emit: anytype,
    input: []const u8,
    commands: []const command_plan.Command,
    options: Options,
    state: *const prepared_literal.State,
) !void {
    const allocator = std.testing.allocator;
    var stats: Stats = .{};
    var rejected: prepared_literal.State = .{};
    inline for (.{ "window_bits", "compound_dictionary_size", "initial_output_pos" }) |field| {
        var changed = options;
        @field(changed, field) += 1;
        rejected.copyFrom(state);
        try std.testing.expectError(error.InvalidBlockPlan, prepare(allocator, input, commands, &stats, changed, &rejected));
        try std.testing.expect(!rejected.ready);
        try std.testing.expectError(error.InvalidBlockPlan, emit(allocator, input, commands, &stats, changed, state));
    }
    var changed = options;
    changed.distance_parameters = @import("distance.zig").Parameters.init(0, 0);
    rejected.copyFrom(state);
    try std.testing.expectError(error.InvalidBlockPlan, prepare(allocator, input, commands, &stats, changed, &rejected));
    try std.testing.expect(!rejected.ready);
    try std.testing.expectError(error.InvalidBlockPlan, emit(allocator, input, commands, &stats, changed, state));
    for (0..4) |index| {
        changed = options;
        changed.starting_last_distances[index] += 1;
        rejected.copyFrom(state);
        try std.testing.expectError(error.InvalidBlockPlan, prepare(allocator, input, commands, &stats, changed, &rejected));
        try std.testing.expect(!rejected.ready);
        try std.testing.expectError(error.InvalidBlockPlan, emit(allocator, input, commands, &stats, changed, state));
    }
    inline for (.{ "use_recent_distances", "optimize_same_last_distance" }) |field| {
        changed = options;
        @field(changed, field) = !@field(changed, field);
        rejected.copyFrom(state);
        try std.testing.expectError(error.InvalidBlockPlan, prepare(allocator, input, commands, &stats, changed, &rejected));
        try std.testing.expect(!rejected.ready);
        try std.testing.expectError(error.InvalidBlockPlan, emit(allocator, input, commands, &stats, changed, state));
    }
    changed = options;
    changed.prepared_common = null;
    try std.testing.expectError(error.InvalidBlockPlan, prepare(allocator, input, commands, &stats, changed, &rejected));
    try std.testing.expectError(error.InvalidBlockPlan, emit(allocator, input, commands, &stats, changed, state));
    const other_commands = try allocator.dupe(command_plan.Command, commands);
    defer allocator.free(other_commands);
    try std.testing.expectError(error.InvalidBlockPlan, prepare(allocator, input, other_commands, &stats, options, &rejected));
    try std.testing.expectError(error.InvalidBlockPlan, emit(allocator, input, other_commands, &stats, options, state));

    inline for (.{ "literal_context_mode", "utf8_context_cutoff" }) |field| {
        changed = options;
        @field(changed, field) -%= 1;
        try std.testing.expectError(error.InvalidBlockPlan, emit(allocator, input, commands, &stats, changed, state));
    }
    inline for (.{ "use_utf8_text_contexts", "optimize_literal_tree_wire" }) |field| {
        changed = options;
        @field(changed, field) = !@field(changed, field);
        try std.testing.expectError(error.InvalidBlockPlan, emit(allocator, input, commands, &stats, changed, state));
    }
    changed = options;
    changed.literal_context_candidate = context.Candidate.suffix(2, 56, 0);
    try std.testing.expectError(error.InvalidBlockPlan, emit(allocator, input, commands, &stats, changed, state));
    changed = options;
    changed.initial_previous[0] = 1;
    try std.testing.expectError(error.InvalidBlockPlan, emit(allocator, input, commands, &stats, changed, state));
    const other_input = try allocator.dupe(u8, input);
    defer allocator.free(other_input);
    try std.testing.expectError(error.InvalidBlockPlan, emit(allocator, other_input, commands, &stats, options, state));
    try std.testing.expectError(error.InvalidBlockPlan, emit(allocator, input[0 .. input.len - 1], commands, &stats, options, state));
    rejected.ready = false;
    try std.testing.expectError(error.InvalidBlockPlan, emit(allocator, input, commands, &stats, options, &rejected));
    inline for (.{ "write_stream_prefix", "final_meta_block" }) |field| {
        changed = options;
        @field(changed, field) = false;
        rejected.copyFrom(state);
        try std.testing.expectError(error.InvalidBlockPlan, prepare(allocator, input, commands, &stats, changed, &rejected));
        try std.testing.expect(!rejected.ready);
        try std.testing.expectError(error.InvalidBlockPlan, emit(allocator, input, commands, &stats, changed, state));
    }
    changed = options;
    changed.metadata = "metadata";
    rejected.copyFrom(state);
    try std.testing.expectError(error.InvalidBlockPlan, prepare(allocator, input, commands, &stats, changed, &rejected));
    try std.testing.expect(!rejected.ready);
    try std.testing.expectError(error.InvalidBlockPlan, emit(allocator, input, commands, &stats, changed, state));

    // Unlike counting, emission owns a real output allocation. Its first
    // allocation failure must propagate and leave the borrowed state reusable.
    var heap = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.OutOfMemory, emit(heap.allocator(), input, commands, &stats, options, state));
    try std.testing.expect(heap.has_induced_failure);
    try std.testing.expectEqual(heap.allocated_bytes, heap.freed_bytes);
    try std.testing.expect(state.matches(input, options));
}
