//! Fixed-storage preparation invariants. Real writer comparisons are separate;
//! these fixtures verify borrowed identities, recomputed frequencies and errors.
const std = @import("std");
const core = @import("../../core.zig");
const plan = @import("command_plan.zig");
const command_encoding = @import("command_encoding.zig");
const lut = @import("../command_lut.zig");
const common_mod = @import("prepared_command_distance.zig");
const literal_mod = @import("prepared_literal.zig");
const distance = @import("distance.zig");
const weighted = @import("weighted_payload.zig");

const TestOptions = struct {
    large_window: bool = false,
    window_bits: u5 = 16,
    distance_parameters: distance.Parameters = distance.Parameters.init(0, 0),
    use_recent_distances: bool = true,
    optimize_same_last_distance: bool = false,
    compound_dictionary_size: usize = 0,
    initial_output_pos: core.StreamCount = 0,
    starting_last_distances: [4]usize = .{ 16, 15, 11, 4 },
    initial_previous: [2]u8 = .{ 0, 0 },
    literal_context_candidate: ?@import("literal_context_split.zig").Candidate = null,
    use_utf8_text_contexts: bool = false,
    literal_context_mode: u2 = 0,
    utf8_context_cutoff: u6 = 56,
    optimize_literal_tree_wire: bool = false,
    write_stream_prefix: bool = true,
    final_meta_block: bool = true,
    metadata: []const u8 = "",
    hq_model_output: ?u8 = null,
    final_wire_state: ?u8 = null,
    command_split: ?u8 = null,
    adaptive_command_split: ?u8 = null,
    distance_split: ?u8 = null,
    adaptive_distance_split: ?u8 = null,
    literal_split: ?u8 = null,
    adaptive_literal_split: ?u8 = null,
    literal_entropy_plan: ?u8 = null,
};
const Strategy = struct {
    pub const Options = TestOptions;
    pub const Error = anyerror;
    pub const Stats = struct {
        seed: usize = 101,
        encoded_bytes: usize = 997,
        literal_symbol_count: usize = 991,
        command_symbol_count: usize = 983,
        distance_symbol_count: usize = 977,
    };
    var fault: enum { none, synthetic, oom, overflow } = .none;
    var headers: usize = 0;
    pub fn wireDistance(command: plan.Command, _: u5, _: usize, _: core.StreamCount) !usize {
        if (command.distance == 0) return error.InvalidBlockPlan;
        return command.distance;
    }
    pub fn recentDistance(value: usize, last: *[4]usize) ?u4 {
        for (last, 0..) |old, index| if (old == value) return @intCast(index);
        return null;
    }
    pub fn pushDistance(last: *[4]usize, value: usize) void {
        last.* = .{ value, last[0], last[1], last[2] };
    }
    pub fn commandEncoding(common: *const common_mod.Prepared, index: usize, count: usize, command: plan.Command, recent: ?u4) !command_encoding.Encoding {
        if (count <= common_mod.symbol_capacity) {
            const symbol = common.command_symbols[index];
            if (symbol >= lut.entries.len) return error.InvalidBlockPlan;
            return .{ .symbol = symbol, .command = lut.entries[symbol] };
        }
        return command_encoding.forLengths(command.insert_len, command.copy_len, recent == 0) orelse
            command_encoding.forLengths(command.insert_len, command.copy_len, false) orelse error.InvalidBlockPlan;
    }
    pub fn header(allocator: std.mem.Allocator, writer: anytype, _: []const u8, options: Options, state: anytype, literal: *const literal_mod.State) !void {
        headers += 1;
        try std.testing.expect(state.literal == literal);
        try std.testing.expect(state.commandPlan().ready);
        try std.testing.expect(state.distancePlan() == state);
        if (fault == .synthetic) return error.SyntheticFailure;
        if (fault == .oom) {
            const temporary = try allocator.alloc(u8, 1);
            defer allocator.free(temporary);
        }
        if (fault == .overflow) {
            try writer.addBits(std.math.maxInt(@TypeOf(writer.bits)));
            try writer.addBits(1);
        }
        try writer.writeBits(allocator, options.distance_parameters.alphabetSize(), 10);
        for (state.distance_alphabet.symbols[0..state.distance_alphabet.len]) |symbol| {
            try writer.writeBits(allocator, symbol, 10);
            try writer.writeBits(allocator, state.distance_lengths[symbol], 4);
        }
    }
};

fn setup(common: *common_mod.Prepared, literal: *literal_mod.State, input: []const u8, commands: []const plan.Command, options: TestOptions) !void {
    common.* = common_mod.Prepared.init(options, commands);
    var command_frequencies: [704]u32 = @splat(0);
    var distance_frequencies: [79]u32 = @splat(0);
    var symbols: [128]u16 = @splat(0);
    var extras: usize = 0;
    var last = options.starting_last_distances;
    for (commands, 0..) |command, index| {
        const recent = if (command.has_copy) Strategy.recentDistance(command.distance, &last) else null;
        const encoded = command_encoding.forLengths(command.insert_len, command.copy_len, recent == 0) orelse
            command_encoding.forLengths(command.insert_len, command.copy_len, false) orelse return error.InvalidBlockPlan;
        command_frequencies[encoded.symbol] += 1;
        if (index < symbols.len) symbols[index] = encoded.symbol;
        extras += encoded.command.insert_extra_bits + encoded.command.copy_extra_bits;
        if (command.has_copy and encoded.command.distance_code == -1) {
            const value = if (recent) |symbol| distance.Encoding{ .symbol = symbol } else distance.encodeWithFormat(command.distance, options.distance_parameters, .standard).?;
            distance_frequencies[value.symbol] += 1;
            extras += value.extra_bits;
        }
        if (command.has_copy and recent != 0) Strategy.pushDistance(&last, command.distance);
    }
    if (std.mem.allEqual(u32, &distance_frequencies, 0)) distance_frequencies[0] = 1;
    var ca: plan.PrefixAlphabet = undefined;
    var da: plan.PrefixAlphabetFor(79) = undefined;
    try plan.alphabetFromFrequenciesInto(704, &ca, &command_frequencies);
    try plan.alphabetFromFrequenciesInto(79, &da, &distance_frequencies);
    const cl = if (ca.len <= 4) @as([704]u4, @splat(0)) else try ca.codeLengths(&command_frequencies);
    const dl = if (da.len <= 4) @as([79]u4, @splat(0)) else try da.codeLengths(&distance_frequencies);
    try common.captureCounted(&command_frequencies, &ca, &cl, &distance_frequencies, &da, &dl, extras, if (commands.len <= 128) &symbols else null);
    var alphabet: literal_mod.Alphabet = .{};
    alphabet.len = 1;
    alphabet.symbols[0] = 'A';
    const lengths: [256]u4 = @splat(0);
    const payload = try weighted.add(try weighted.add(
        try weighted.histogram(704, &command_frequencies, &ca, &cl, true),
        try weighted.histogram(79, &distance_frequencies, &da, &dl, true),
    ), extras);
    try literal.capture(input, options, null, &.{alphabet}, &.{lengths}, 0, payload);
}

fn commandSet(commands: []plan.Command) void {
    var position: usize = 0;
    for (commands, 0..) |*command, index| {
        const extra = 1 + index / 16;
        const selector = (index / 8) % 2;
        const value = 89 + ((2 + selector) << @as(u6, @intCast(extra + 3))) + index % 8;
        command.* = .{ .insert_start = position, .insert_len = 1 + index % 8, .copy_len = 7, .distance = value, .has_copy = true };
        position += command.insert_len + command.copy_len;
    }
}

fn invariants(comptime Module: type) !void {
    var commands: [192]plan.Command = undefined;
    commandSet(&commands);
    const input = [_]u8{'A'} ** 8192;
    var options: TestOptions = .{ .optimize_same_last_distance = true };
    var shared: common_mod.Prepared = undefined;
    var literal: literal_mod.State = undefined;
    try setup(&shared, &literal, &input, &commands, options);
    const shared_frequencies = shared.command_frequencies;
    const literal_key = literal.key;
    var state: Module.State = .{};
    var stats: Strategy.Stats = .{};
    var full_models: usize = 0;
    for (0..4) |postfix| {
        for (0..16) |direct| {
            options.distance_parameters = distance.Parameters.init(@intCast(postfix), @intCast(direct));
            options.optimize_same_last_distance = false;
            var forbidden = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
            try Module.prepare(Strategy, forbidden.allocator(), &input, &commands, options, &shared, &literal, &stats, &state);
            try std.testing.expect(state.ready and state.matches(&input, &commands, options));
            try std.testing.expect(state.commandPlan() == &shared and state.literalModels() == &literal);
            try std.testing.expectEqual(@as(usize, 101), stats.seed);
            try std.testing.expectEqual(@as(usize, 997), stats.encoded_bytes);
            try std.testing.expectEqual(@as(usize, 0), forbidden.alloc_index);
            try std.testing.expectEqualSlices(u32, &shared_frequencies, &shared.command_frequencies);
            try std.testing.expectEqualDeep(literal_key, literal.key);
            var total: usize = 0;
            for (state.distance_frequencies) |frequency| total += frequency;
            try std.testing.expectEqual(commands.len, total);
            for (state.distance_alphabet.symbols[0..state.distance_alphabet.len]) |symbol|
                try std.testing.expect(symbol < options.distance_parameters.alphabetSize());
            if (state.distance_alphabet.len > 64) full_models += 1;
        }
    }
    try std.testing.expect(full_models != 0);
    var other_commands = commands;
    try std.testing.expect(!state.matches(&input, &other_commands, options));
    shared.ready = false;
    try std.testing.expect(!state.matches(&input, &commands, options));
    shared.ready = true;
    try std.testing.expect(state.matches(&input, &commands, options));
    state.reset();
    try std.testing.expect(!state.ready and !state.matches(&input, &commands, options));
    // A new literal-only group must clear all distance frequencies from the
    // prior 192-symbol model, with the exact old dummy-symbol rule.
    const only = [_]plan.Command{.{ .insert_start = 0, .insert_len = 1 }};
    const baseline: TestOptions = .{};
    try setup(&shared, &literal, &input, &only, baseline);
    options = baseline;
    options.distance_parameters = distance.Parameters.init(3, 15);
    try Module.prepare(Strategy, std.testing.allocator, &input, &only, options, &shared, &literal, &stats, &state);
    try std.testing.expectEqual(@as(usize, 1), state.distance_alphabet.len);
    try std.testing.expectEqual(@as(u32, 1), state.distance_frequencies[0]);
    for (state.distance_frequencies[1..]) |frequency| try std.testing.expectEqual(@as(u32, 0), frequency);
    for (state.distance_lengths) |length| try std.testing.expectEqual(@as(u4, 0), length);
    try std.testing.expectEqual(literal.payload_bits, state.payload_bits);
}

fn failures(comptime Module: type) !void {
    var commands: [8]plan.Command = undefined;
    commandSet(&commands);
    const input = [_]u8{'A'} ** 512;
    var shared: common_mod.Prepared = undefined;
    var literal: literal_mod.State = undefined;
    var options: TestOptions = .{};
    try setup(&shared, &literal, &input, &commands, options);
    options.distance_parameters = distance.Parameters.init(1, 0);
    var state: Module.State = .{};
    var stats: Strategy.Stats = .{};
    const initial = stats;
    for ([_]@TypeOf(Strategy.fault){ .synthetic, .oom, .overflow }) |fault| {
        Strategy.fault = fault;
        defer Strategy.fault = .none;
        var heap = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
        const wanted = if (fault == .synthetic) error.SyntheticFailure else if (fault == .oom) error.OutOfMemory else error.IntegerOverflow;
        try std.testing.expectError(wanted, Module.prepare(Strategy, heap.allocator(), &input, &commands, options, &shared, &literal, &stats, &state));
        try std.testing.expect(!state.ready);
        try std.testing.expectEqualDeep(initial, stats);
        try std.testing.expect(shared.ready and literal.ready);
    }
    const saved_payload = literal.payload_bits;
    literal.payload_bits = 0;
    Strategy.headers = 0;
    try std.testing.expectError(error.IntegerOverflow, Module.prepare(Strategy, std.testing.allocator, &input, &commands, options, &shared, &literal, &stats, &state));
    try std.testing.expectEqual(@as(usize, 0), Strategy.headers);
    literal.payload_bits = saved_payload;
    shared.ready = false;
    try std.testing.expectError(error.InvalidBlockPlan, Module.prepare(Strategy, std.testing.allocator, &input, &commands, options, &shared, &literal, &stats, &state));
    shared.ready = true;
    shared.has_exact_commands = true;
    try std.testing.expectError(error.InvalidBlockPlan, Module.prepare(Strategy, std.testing.allocator, &input, &commands, options, &shared, &literal, &stats, &state));
    shared.has_exact_commands = false;
    options.optimize_same_last_distance = true;
    try std.testing.expectError(error.InvalidBlockPlan, Module.prepare(Strategy, std.testing.allocator, &input, &commands, options, &shared, &literal, &stats, &state));
    try std.testing.expect(!state.ready);
    try std.testing.expectEqualDeep(initial, stats);
}

pub fn check(comptime Module: type) !void {
    try invariants(Module);
    try failures(Module);
}
