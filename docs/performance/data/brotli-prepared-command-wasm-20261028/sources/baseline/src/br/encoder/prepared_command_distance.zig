//! Call-group storage for one ordinary command/distance preparation. Commands
//! are borrowed and immutable until the group ends. Pointer/length identity is
//! not a content cache: initialize a new Prepared for each command group.
const std = @import("std");
const core = @import("../../core.zig");
const command_plan = @import("command_plan.zig");
const distance = @import("distance.zig");
const huffman = @import("../../huffman.zig");

pub const command_capacity: usize = 704;
pub const distance_capacity: usize = 79;
pub const symbol_capacity: usize = 128;
comptime {
    std.debug.assert(command_capacity == command_plan.max_prefix_symbols);
    std.debug.assert(distance_capacity == 79);
    std.debug.assert(symbol_capacity == 128);
    std.debug.assert(distance.Parameters.init(0, 15).alphabetSize() == distance_capacity);
}

pub const Key = struct {
    commands_ptr: [*]const command_plan.Command,
    commands_len: usize,
    window_bits: u5,
    distance_parameters: distance.Parameters,
    compound_dictionary_size: usize,
    initial_output_pos: core.StreamCount,
    starting_last_distances: [4]usize,
    use_recent_distances: bool,
    optimize_same_last_distance: bool,

    pub fn init(options: anytype, commands: []const command_plan.Command) Key {
        return .{
            .commands_ptr = commands.ptr,
            .commands_len = commands.len,
            .window_bits = options.window_bits,
            .distance_parameters = options.distance_parameters,
            .compound_dictionary_size = options.compound_dictionary_size,
            .initial_output_pos = options.initial_output_pos,
            .starting_last_distances = options.starting_last_distances,
            .use_recent_distances = options.use_recent_distances,
            .optimize_same_last_distance = options.optimize_same_last_distance,
        };
    }

    pub fn matches(self: *const Key, options: anytype, commands: []const command_plan.Command) bool {
        return self.commands_ptr == commands.ptr and self.commands_len == commands.len and
            self.window_bits == options.window_bits and
            std.meta.eql(self.distance_parameters, options.distance_parameters) and
            self.compound_dictionary_size == options.compound_dictionary_size and
            self.initial_output_pos == options.initial_output_pos and
            std.mem.eql(usize, &self.starting_last_distances, &options.starting_last_distances) and
            self.use_recent_distances == options.use_recent_distances and
            self.optimize_same_last_distance == options.optimize_same_last_distance;
    }
};

/// Only the ordinary 79-capacity writer may borrow this preparation. Smaller
/// standard parameter shapes still fit that writer. Same-last's requested flag
/// remains in the key, but recent-distance use disables its effective recoding.
pub fn supported(options: anytype, has_exact_commands: bool) bool {
    return !options.large_window and options.window_bits >= 10 and options.window_bits <= 24 and
        options.distance_parameters.alphabetSize() <= distance_capacity and options.use_recent_distances and
        !has_exact_commands and options.hq_model_output == null and options.final_wire_state == null and
        options.command_split == null and options.adaptive_command_split == null and
        options.distance_split == null and options.adaptive_distance_split == null and
        options.literal_split == null and options.adaptive_literal_split == null and options.literal_entropy_plan == null;
}

pub const Prepared = struct {
    command_frequencies: [command_capacity]u32 = undefined,
    distance_frequencies: [distance_capacity]u32 = undefined,
    command_alphabet: command_plan.PrefixAlphabet = undefined,
    distance_alphabet: command_plan.PrefixAlphabetFor(distance_capacity) = undefined,
    command_lengths: [command_capacity]u4 = undefined,
    distance_lengths: [distance_capacity]u4 = undefined,
    command_encoder: huffman.HuffmanTable(command_capacity).Encoder = undefined,
    distance_encoder: huffman.HuffmanTable(distance_capacity).Encoder = undefined,
    command_symbols: [symbol_capacity]u16 = undefined,
    key: Key = undefined,
    ready: bool = false,
    // This property is stable under the same immutable-command group contract
    // as the key; do not rescan commands on each literal-context candidate.
    has_exact_commands: bool = false,

    /// Initialize metadata only. The actual writer initializes frequency/tree
    /// storage on a miss and publishes ready=true only after preparation succeeds.
    pub fn init(options: anytype, commands: []const command_plan.Command) Prepared {
        const has_exact_commands = for (commands) |command| {
            if (command.hq_encoding != null) break true;
        } else false;
        return .{ .key = Key.init(options, commands), .has_exact_commands = has_exact_commands };
    }

    pub fn matches(self: *const Prepared, options: anytype, commands: []const command_plan.Command) bool {
        return self.ready and self.key.matches(options, commands) and supported(options, self.has_exact_commands);
    }

    /// Invalidate publication without clearing the fixed scratch. Use init,
    /// rather than merely changing the borrowed key, for a different group.
    pub fn reset(self: *Prepared) void {
        self.ready = false;
    }
};

// Nullness alone matters for unsupported payload options. Keep these fixture
// markers small instead of duplicating br.zig's private full wire option type.
const TestOptions = struct {
    large_window: bool = false,
    window_bits: u5 = 16,
    distance_parameters: distance.Parameters = distance.Parameters.init(0, 15),
    compound_dictionary_size: usize = 0,
    initial_output_pos: core.StreamCount = (@as(core.StreamCount, 1) << 32) + 17,
    starting_last_distances: [4]usize = .{ 16, 15, 11, 4 },
    use_recent_distances: bool = true,
    optimize_same_last_distance: bool = true,
    hq_model_output: ?u8 = null,
    final_wire_state: ?u8 = null,
    command_split: ?u8 = null,
    adaptive_command_split: ?u8 = null,
    distance_split: ?u8 = null,
    adaptive_distance_split: ?u8 = null,
    literal_split: ?u8 = null,
    adaptive_literal_split: ?u8 = null,
    literal_entropy_plan: ?u8 = null,
    literal_context_candidate: ?@import("literal_context_split.zig").Candidate = null,
    use_utf8_text_contexts: bool = false,
    literal_context_mode: u2 = 0,
    optimize_literal_tree_wire: bool = false,
};

fn testCommands() [2]command_plan.Command {
    return .{
        .{ .insert_start = 0, .insert_len = 3, .copy_len = 8, .distance = 16, .has_copy = true },
        .{ .insert_start = 11, .insert_len = 5 }, // A legal terminal insert.
    };
}

test "prepared command distance key rejects every changed wire or command identity field" {
    var commands = testCommands();
    var other_commands = commands;
    other_commands[0].distance = 15;
    const options: TestOptions = .{};
    var prepared = Prepared.init(options, &commands);
    prepared.ready = true;
    try std.testing.expect(prepared.matches(options, &commands));
    try std.testing.expect(!prepared.matches(options, &other_commands));
    try std.testing.expect(!prepared.matches(options, commands[0..1]));
    inline for (.{ "window_bits", "compound_dictionary_size", "initial_output_pos" }) |field| {
        var changed = options;
        @field(changed, field) += 1;
        try std.testing.expect(!prepared.matches(changed, &commands));
    }
    for (0..4) |index| {
        var changed = options;
        changed.starting_last_distances[index] += 1;
        try std.testing.expect(!prepared.matches(changed, &commands));
    }
    var changed = options;
    changed.distance_parameters.ndirect_high = 14;
    try std.testing.expect(supported(changed, false));
    try std.testing.expect(!prepared.matches(changed, &commands));
    changed = options;
    changed.distance_parameters.npostfix = 1;
    try std.testing.expect(!prepared.key.matches(changed, &commands));
    changed = options;
    changed.use_recent_distances = false;
    try std.testing.expect(!prepared.key.matches(changed, &commands));
    changed = options;
    changed.optimize_same_last_distance = false;
    try std.testing.expect(supported(changed, false));
    try std.testing.expect(!prepared.matches(changed, &commands));
}

test "prepared command distance accepts changing literal context and tree policy" {
    var commands = testCommands();
    var options: TestOptions = .{};
    var prepared = Prepared.init(options, &commands);
    prepared.ready = true;
    const Candidate = @import("literal_context_split.zig").Candidate;
    options.literal_context_candidate = Candidate.suffix(2, 56, 0);
    options.use_utf8_text_contexts = true;
    options.literal_context_mode = 2;
    options.optimize_literal_tree_wire = true;
    try std.testing.expect(prepared.matches(options, &commands));
    options.literal_context_candidate = Candidate.suffix(3, 8, 0);
    try std.testing.expect(prepared.matches(options, &commands));
}

test "prepared command distance support preserves recent defaults and rejects special writers" {
    var commands = testCommands();
    const options: TestOptions = .{};
    var prepared = Prepared.init(options, &commands);
    prepared.ready = true;
    try std.testing.expect(supported(options, false)); // same-last defaults true.
    var changed = options;
    changed.distance_parameters = distance.Parameters.init(0, 0);
    try std.testing.expect(supported(changed, false));
    changed = options;
    changed.large_window = true;
    try std.testing.expect(!prepared.matches(changed, &commands));
    for ([_]u5{ 9, 25 }) |window| {
        changed = options;
        changed.window_bits = window;
        try std.testing.expect(!supported(changed, false));
    }
    inline for (.{ "hq_model_output", "final_wire_state", "command_split", "adaptive_command_split", "distance_split", "adaptive_distance_split", "literal_split", "adaptive_literal_split", "literal_entropy_plan" }) |field| {
        changed = options;
        @field(changed, field) = 1;
        try std.testing.expect(!prepared.matches(changed, &commands));
    }
    try std.testing.expect(!supported(options, true));
    commands[0].hq_encoding = .{ .command_symbol = 0 };
    prepared = Prepared.init(options, &commands);
    prepared.ready = true;
    try std.testing.expect(prepared.has_exact_commands);
    try std.testing.expect(!prepared.matches(options, &commands));
}

test "prepared command distance init and reset publish no scratch or allocation" {
    var commands = testCommands();
    const options: TestOptions = .{};
    var prepared = Prepared.init(options, &commands);
    try std.testing.expect(!prepared.ready);
    try std.testing.expect(!prepared.matches(options, &commands));
    prepared.command_frequencies[17] = 42;
    prepared.distance_frequencies[3] = 99;
    prepared.command_symbols[0] = 7;
    const key = prepared.key;
    prepared.ready = true;
    prepared.reset();
    try std.testing.expect(!prepared.matches(options, &commands));
    try std.testing.expectEqual(@as(u32, 42), prepared.command_frequencies[17]);
    try std.testing.expectEqual(@as(u32, 99), prepared.distance_frequencies[3]);
    try std.testing.expectEqual(@as(u16, 7), prepared.command_symbols[0]);
    try std.testing.expectEqualDeep(key, prepared.key);
    try std.testing.expect(@sizeOf(Prepared) < 12 * 1024);
}
