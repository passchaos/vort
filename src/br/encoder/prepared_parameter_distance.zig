//! Alternative distance-parameter preparation borrowing an immutable ordinary
//! command model and an already counted literal preparation from the same group.
const std = @import("std");
const core = @import("../../core.zig");
const bit_count = @import("../../io/bit_count.zig");
const command_plan = @import("command_plan.zig");
const shared_command = @import("prepared_command_distance.zig");
const prepared_literal = @import("prepared_literal.zig");
const compound_wire = @import("compound_wire.zig");
const distance = @import("distance.zig");
const huffman = @import("../../huffman.zig");
const weighted = @import("weighted_payload.zig");
const counting = @import("counting_writer.zig");

pub const distance_capacity = 520;
/// The prepared pair owns fixed-size distance storage and scans commands once,
/// so the bound only excludes pathological command streams; ordinary q8 inputs
/// up to 1 MiB (and beyond) fit comfortably.
pub const max_command_count = 1 << 20;

pub fn supported(options: anytype) bool {
    return !options.large_window and options.window_bits >= 10 and options.window_bits <= 24 and
        options.use_recent_distances and !options.optimize_same_last_distance and
        options.distance_parameters.alphabetSize() <= distance_capacity and
        options.write_stream_prefix and options.final_meta_block and options.metadata.len == 0 and
        options.hq_model_output == null and options.final_wire_state == null and
        options.command_split == null and options.adaptive_command_split == null and
        options.distance_split == null and options.adaptive_distance_split == null and
        options.literal_split == null and options.adaptive_literal_split == null and options.literal_entropy_plan == null;
}

pub fn borrowable(input: []const u8, commands: []const command_plan.Command, options: anytype, shared: *const shared_command.Prepared, literal: *const prepared_literal.State) bool {
    if (!supported(options) or commands.len == 0 or commands.len > max_command_count or
        !shared.ready or shared.has_exact_commands or
        !std.meta.eql(shared.key.distance_parameters, distance.Parameters.init(0, 0)) or
        !literal.matches(input, options) or literal.tree_count == 0 or literal.tree_count > prepared_literal.max_trees)
        return false;
    var baseline_options = options;
    baseline_options.distance_parameters = shared.key.distance_parameters;
    baseline_options.optimize_same_last_distance = shared.key.optimize_same_last_distance;
    return shared.matches(baseline_options, commands);
}

/// Fixed storage owns only the new distance model. Both borrowed owners must
/// stay ready, immutable and alive until counting and final emission finish.
pub const State = struct {
    shared: *const shared_command.Prepared = undefined,
    literal: *const prepared_literal.State = undefined,
    distance_frequencies: [distance_capacity]u32 = undefined,
    distance_alphabet: command_plan.PrefixAlphabetFor(distance_capacity) = undefined,
    distance_lengths: [distance_capacity]u4 = undefined,
    distance_encoder: huffman.HuffmanTable(distance_capacity).Encoder = undefined,
    key: shared_command.Key = undefined,
    header_bits: bit_count.BitCount = 0,
    payload_bits: bit_count.BitCount = 0,
    wire_len: usize = 0,
    ready: bool = false,

    pub fn commandPlan(self: *const State) *const shared_command.Prepared {
        return self.shared;
    }
    pub fn distancePlan(self: *const State) *const State {
        return self;
    }
    pub fn literalModels(self: *const State) *const prepared_literal.State {
        return self.literal;
    }
    pub fn reset(self: *State) void {
        self.ready = false;
    }
    pub fn matches(self: *const State, input: []const u8, commands: []const command_plan.Command, options: anytype) bool {
        return self.ready and self.key.matches(options, commands) and
            borrowable(input, commands, options, self.shared, self.literal);
    }
};

pub fn prepare(comptime S: type, allocator: std.mem.Allocator, input: []const u8, commands: []const command_plan.Command, options: S.Options, shared: *const shared_command.Prepared, literal: *const prepared_literal.State, stats: *S.Stats, state: *State) S.Error!void {
    state.ready = false;
    if (!borrowable(input, commands, options, shared, literal)) return error.InvalidBlockPlan;
    _ = try core.stream_count.addLocal(options.initial_output_pos, input.len);
    state.shared = shared;
    state.literal = literal;
    state.key = shared_command.Key.init(options, commands);
    @memset(&state.distance_frequencies, 0);
    var starting = options.starting_last_distances;
    var baseline_extra: bit_count.BitCount = 0;
    var alternative_extra: bit_count.BitCount = 0;
    for (commands, 0..) |command, index| {
        const physical = if (command.has_copy)
            try S.wireDistance(command, options.window_bits, options.compound_dictionary_size, options.initial_output_pos)
        else
            0;
        const recent = if (command.has_copy and compound_wire.canUseRecentDistance(command.source))
            S.recentDistance(physical, &starting)
        else
            null;
        const encoded = try S.commandEncoding(shared, index, commands.len, command, recent);
        if (command.has_copy and encoded.command.distance_code == -1) {
            const alternative = if (recent) |symbol| distance.Encoding{ .symbol = symbol } else distance.encodeWithFormat(physical, options.distance_parameters, .standard) orelse return error.InvalidBlockPlan;
            const baseline = if (recent) |symbol| distance.Encoding{ .symbol = symbol } else distance.encodeWithFormat(physical, shared.key.distance_parameters, .standard) orelse return error.InvalidBlockPlan;
            if (alternative.symbol >= distance_capacity or baseline.symbol >= shared_command.distance_capacity)
                return error.InvalidBlockPlan;
            const frequency = &state.distance_frequencies[alternative.symbol];
            frequency.* = std.math.add(u32, frequency.*, 1) catch return error.IntegerOverflow;
            baseline_extra = try weighted.add(baseline_extra, baseline.extra_bits);
            alternative_extra = try weighted.add(alternative_extra, alternative.extra_bits);
        }
        if (command.has_copy and compound_wire.updatesRecentDistance(command.source, recent == 0))
            S.pushDistance(&starting, physical);
    }
    const any_distance = for (state.distance_frequencies) |frequency| {
        if (frequency != 0) break true;
    } else false;
    if (!any_distance) state.distance_frequencies[0] = 1;
    try command_plan.alphabetFromFrequenciesInto(distance_capacity, &state.distance_alphabet, &state.distance_frequencies);
    state.distance_lengths = if (state.distance_alphabet.len <= 4) @splat(0) else try state.distance_alphabet.codeLengths(&state.distance_frequencies);
    state.distance_encoder = if (state.distance_alphabet.len <= 4) .{} else if (state.distance_alphabet.len <= 64)
        try huffman.HuffmanTable(distance_capacity).Encoder.initSparseTrusted(&state.distance_lengths, state.distance_alphabet.symbols[0..state.distance_alphabet.len])
    else
        try huffman.HuffmanTable(distance_capacity).Encoder.init(&state.distance_lengths);

    const baseline_payload = try weighted.histogram(shared_command.distance_capacity, &shared.distance_frequencies, &shared.distance_alphabet, &shared.distance_lengths, true);
    const alternative_payload = try weighted.histogram(distance_capacity, &state.distance_frequencies, &state.distance_alphabet, &state.distance_lengths, true);
    const without_tree = std.math.sub(bit_count.BitCount, literal.payload_bits, baseline_payload) catch return error.IntegerOverflow;
    const without_distance = std.math.sub(bit_count.BitCount, without_tree, baseline_extra) catch return error.IntegerOverflow;
    state.payload_bits = try weighted.add(try weighted.add(without_distance, alternative_payload), alternative_extra);
    var counter = counting.Writer.init(0);
    try S.header(allocator, &counter, input, options, state, literal);
    state.header_bits = try counter.checkedBitPosition();
    state.wire_len = try weighted.ceilBytes(try weighted.add(state.header_bits, state.payload_bits));
    var literal_symbols: usize = 0;
    for (literal.alphabets[0..literal.tree_count]) |alphabet|
        literal_symbols = std.math.add(usize, literal_symbols, alphabet.len) catch return error.IntegerOverflow;
    stats.literal_symbol_count = literal_symbols;
    stats.command_symbol_count = shared.command_alphabet.len;
    stats.distance_symbol_count = state.distance_alphabet.len;
    state.ready = true;
}

test "prepared distance parameters borrow command and literal owners" {
    try @import("prepared_parameter_distance_tests.zig").check(@This());
}
