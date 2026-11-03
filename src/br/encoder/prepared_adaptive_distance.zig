//! Allocator-owned command/distance preparation shared by every literal-tree
//! candidate for one adaptive-distance split. The command stream, split, and
//! keyed wire options are immutable for the lifetime of a `Prepared` value.
const std = @import("std");
const builtin = @import("builtin");
const core = @import("../../core.zig");
const bit_count = @import("../../io/bit_count.zig");
const huffman = @import("../../huffman.zig");
const command_lut = @import("../command_lut.zig");
const command_encoding = @import("command_encoding.zig");
const command_plan = @import("command_plan.zig");
const compound_wire = @import("compound_wire.zig");
const encoder_distance = @import("distance.zig");
const block_split_plan = @import("block_split_plan.zig");
const adaptive_block_code = @import("adaptive_block_code.zig");
const identity_context_map = @import("identity_context_map.zig");
const counting_writer = @import("counting_writer.zig");
const weighted_payload = @import("weighted_payload.zig");
const literal_context = @import("literal_context.zig");
const literal_context_split = @import("literal_context_split.zig");
const prepared_literal = @import("prepared_literal.zig");
const prepared_command_distance = @import("prepared_command_distance.zig");

pub const command_capacity: usize = 704;
pub const distance_capacity: usize = 79;
pub const max_command_count: usize = 64 * 1024;
pub const max_distance_count: usize = 32 * 1024;

pub const TestCounters = struct {
    command_scans: usize = 0,
    command_model_builds: usize = 0,
    borrowed_command_models: usize = 0,
    distance_histogram_passes: usize = 0,
    distance_tree_build_passes: usize = 0,
    distance_trees_built: usize = 0,
    split_code_builds: usize = 0,
};
var test_counters: TestCounters = .{};

pub fn resetTestCounters() void {
    if (comptime builtin.is_test) test_counters = .{};
}

pub fn testCounters() TestCounters {
    if (comptime builtin.is_test) return test_counters;
    return .{};
}

/// Keep the retained symbol streams explicitly bounded. Production adaptive
/// distance discovery already caps explicit distances at `max_distance_count`;
/// the command cap protects caller-supplied plans with unusually many implicit
/// last-distance commands and lets them fall back to the ordinary writer.
pub fn bounded(commands_len: usize, split: *const block_split_plan.Plan) bool {
    if (commands_len == 0 or commands_len > max_command_count or
        split.lengths.len == 0 or split.lengths.len != split.types.len or
        split.type_count < 2 or split.type_count > 8)
        return false;
    var distance_count: usize = 0;
    for (split.lengths) |length| {
        distance_count = std.math.add(usize, distance_count, length) catch return false;
    }
    return distance_count <= commands_len and distance_count <= max_distance_count;
}

pub const Key = struct {
    commands_ptr: [*]const command_plan.Command,
    commands_len: usize,
    split_ptr: *const block_split_plan.Plan,
    split_lengths_ptr: [*]const u32,
    split_types_ptr: [*]const u8,
    split_block_count: usize,
    split_type_count: u16,
    window_bits: u5,
    distance_parameters: encoder_distance.Parameters,
    compound_dictionary_size: usize,
    initial_output_pos: core.StreamCount,
    starting_last_distances: [4]usize,
    use_recent_distances: bool,

    pub fn init(options: anytype, commands: []const command_plan.Command, split: *const block_split_plan.Plan) Key {
        return .{
            .commands_ptr = commands.ptr,
            .commands_len = commands.len,
            .split_ptr = split,
            .split_lengths_ptr = split.lengths.ptr,
            .split_types_ptr = split.types.ptr,
            .split_block_count = split.blockCount(),
            .split_type_count = split.type_count,
            .window_bits = options.window_bits,
            .distance_parameters = options.distance_parameters,
            .compound_dictionary_size = options.compound_dictionary_size,
            .initial_output_pos = options.initial_output_pos,
            .starting_last_distances = options.starting_last_distances,
            .use_recent_distances = options.use_recent_distances,
        };
    }

    pub fn matches(self: *const Key, options: anytype, commands: []const command_plan.Command) bool {
        const split = options.adaptive_distance_split orelse return false;
        return self.commands_ptr == commands.ptr and self.commands_len == commands.len and
            self.split_ptr == split and self.split_lengths_ptr == split.lengths.ptr and
            self.split_types_ptr == split.types.ptr and self.split_block_count == split.blockCount() and
            self.split_type_count == split.type_count and self.window_bits == options.window_bits and
            std.meta.eql(self.distance_parameters, options.distance_parameters) and
            self.compound_dictionary_size == options.compound_dictionary_size and
            self.initial_output_pos == options.initial_output_pos and
            std.mem.eql(usize, &self.starting_last_distances, &options.starting_last_distances) and
            self.use_recent_distances == options.use_recent_distances;
    }
};

/// Single-owner state. Do not copy a populated value: `split_code` and the
/// retained slices must be destroyed exactly once with the original allocator.
pub const Prepared = struct {
    key: Key,
    command_symbols: []u16,
    distance_encodings: []encoder_distance.Encoding,
    distance_count: usize,
    command_alphabet: command_plan.PrefixAlphabet,
    command_lengths: [command_capacity]u4,
    command_encoder: huffman.HuffmanTable(command_capacity).Encoder,
    borrowed_command: ?*const prepared_command_distance.Prepared = null,
    distance_alphabets: []command_plan.PrefixAlphabetFor(distance_capacity),
    distance_lengths: [][distance_capacity]u4,
    distance_encoders: []huffman.HuffmanTable(distance_capacity).Encoder,
    split_code: adaptive_block_code.Code,
    context_map: identity_context_map.Plan,
    payload_bits: bit_count.BitCount,
    command_symbol_count: usize,
    distance_symbol_count: usize,

    pub fn init(
        comptime S: type,
        allocator: std.mem.Allocator,
        commands: []const command_plan.Command,
        options: S.Options,
    ) S.Error!Prepared {
        return initInternal(S, allocator, commands, options, null);
    }

    /// Borrow only a published ordinary command model from this exact keyed
    /// command group. Distance histograms, trees, switches and symbol streams
    /// remain owned here. The owner must outlive this preparation and writing.
    pub fn initBorrowedCommand(
        comptime S: type,
        allocator: std.mem.Allocator,
        commands: []const command_plan.Command,
        options: S.Options,
        common: *const prepared_command_distance.Prepared,
    ) S.Error!Prepared {
        if (!borrowKeyMatches(common, options, commands)) return error.InvalidBlockPlan;
        return initInternal(S, allocator, commands, options, common);
    }

    fn initInternal(
        comptime S: type,
        allocator: std.mem.Allocator,
        commands: []const command_plan.Command,
        options: S.Options,
        borrowed: ?*const prepared_command_distance.Prepared,
    ) S.Error!Prepared {
        const split = options.adaptive_distance_split orelse return error.InvalidBlockPlan;
        if (!S.supported(options, commands) or !bounded(commands.len, split))
            return error.InvalidBlockPlan;
        var expected_distance_count: usize = 0;
        for (split.lengths) |length|
            expected_distance_count = std.math.add(usize, expected_distance_count, length) catch
                return error.IntegerOverflow;
        try split.validate(expected_distance_count);

        const command_symbols = try allocator.alloc(u16, commands.len);
        errdefer allocator.free(command_symbols);
        const distance_encodings = try allocator.alloc(encoder_distance.Encoding, expected_distance_count);
        errdefer allocator.free(distance_encodings);
        const type_count: usize = split.type_count;
        const distance_frequencies = try allocator.alloc([distance_capacity]u32, type_count);
        defer allocator.free(distance_frequencies);
        @memset(distance_frequencies, @splat(0));

        var command_frequencies: [command_capacity]u32 = undefined;
        var command_alphabet: command_plan.PrefixAlphabet = undefined;
        command_alphabet.len = 0;
        var payload_extra_bits: bit_count.BitCount = 0;
        var last_distances = options.starting_last_distances;
        var distance_count: usize = 0;
        var block_index: usize = 0;
        var block_end: usize = split.lengths[0];
        if (comptime builtin.is_test) {
            test_counters.command_scans += 1;
            test_counters.distance_histogram_passes += 1;
        }
        for (commands, command_symbols) |command, *command_symbol| {
            const wire_distance = if (command.has_copy)
                try S.wireDistance(
                    command,
                    options.window_bits,
                    options.compound_dictionary_size,
                    options.initial_output_pos,
                )
            else
                0;
            const recent_symbol = if (command.has_copy and compound_wire.canUseRecentDistance(command.source))
                S.recentDistance(wire_distance, &last_distances)
            else
                null;
            const encoding = command_encoding.forLengths(command.insert_len, command.copy_len, recent_symbol == 0) orelse
                command_encoding.forLengths(command.insert_len, command.copy_len, false) orelse
                return error.InvalidBlockPlan;
            command_symbol.* = encoding.symbol;
            if (borrowed == null)
                try command_alphabet.recordFrequency(&command_frequencies, encoding.symbol);
            payload_extra_bits = try weighted_payload.add(
                payload_extra_bits,
                @as(bit_count.BitCount, encoding.command.insert_extra_bits) + encoding.command.copy_extra_bits,
            );
            if (command.has_copy and encoding.command.distance_code == -1) {
                if (distance_count >= expected_distance_count) return error.InvalidBlockPlan;
                while (distance_count >= block_end) {
                    block_index += 1;
                    if (block_index >= split.blockCount()) return error.InvalidBlockPlan;
                    block_end = std.math.add(usize, block_end, split.lengths[block_index]) catch
                        return error.IntegerOverflow;
                }
                const distance = if (recent_symbol) |symbol|
                    encoder_distance.Encoding{ .symbol = symbol }
                else
                    encoder_distance.encodeWithFormat(
                        wire_distance,
                        options.distance_parameters,
                        .standard,
                    ) orelse return error.InvalidBlockPlan;
                if (distance.symbol >= distance_capacity) return error.InvalidBlockPlan;
                distance_encodings[distance_count] = distance;
                distance_frequencies[split.types[block_index]][distance.symbol] += 1;
                payload_extra_bits = try weighted_payload.add(payload_extra_bits, distance.extra_bits);
                distance_count += 1;
            }
            if (command.has_copy and compound_wire.updatesRecentDistance(command.source, recent_symbol == 0))
                S.pushDistance(&last_distances, wire_distance);
        }
        try split.validate(distance_count);
        if (distance_count != expected_distance_count or block_index + 1 != split.blockCount() or
            block_end != distance_count)
            return error.InvalidBlockPlan;

        var command_lengths: [command_capacity]u4 = undefined;
        var command_encoder: huffman.HuffmanTable(command_capacity).Encoder = undefined;
        if (borrowed == null) {
            if (comptime builtin.is_test) test_counters.command_model_builds += 1;
            try command_alphabet.sortByFrequencies(&command_frequencies);
            command_lengths = if (command_alphabet.len <= 4)
                @as([command_capacity]u4, @splat(0))
            else
                try command_alphabet.codeLengths(&command_frequencies);
            command_encoder = if (command_alphabet.len <= 4)
                .{}
            else if (command_alphabet.len <= 64)
                try huffman.HuffmanTable(command_capacity).Encoder.initSparseTrusted(
                    &command_lengths,
                    command_alphabet.symbols[0..command_alphabet.len],
                )
            else
                try huffman.HuffmanTable(command_capacity).Encoder.init(&command_lengths);
        } else if (comptime builtin.is_test) test_counters.borrowed_command_models += 1;

        const distance_alphabets = try allocator.alloc(command_plan.PrefixAlphabetFor(distance_capacity), type_count);
        errdefer allocator.free(distance_alphabets);
        const distance_lengths = try allocator.alloc([distance_capacity]u4, type_count);
        errdefer allocator.free(distance_lengths);
        const distance_encoders = try allocator.alloc(huffman.HuffmanTable(distance_capacity).Encoder, type_count);
        errdefer allocator.free(distance_encoders);
        var distance_symbol_count: usize = 0;
        if (comptime builtin.is_test) {
            test_counters.distance_tree_build_passes += 1;
            test_counters.distance_trees_built += type_count;
        }
        for (distance_frequencies, distance_alphabets, distance_lengths, distance_encoders) |*frequencies, *alphabet, *lengths, *encoder| {
            try command_plan.alphabetFromFrequenciesInto(distance_capacity, alphabet, frequencies);
            lengths.* = if (alphabet.len <= 4) @splat(0) else try alphabet.codeLengths(frequencies);
            encoder.* = if (alphabet.len <= 4)
                .{}
            else if (alphabet.len <= 64)
                try huffman.HuffmanTable(distance_capacity).Encoder.initSparseTrusted(
                    lengths,
                    alphabet.symbols[0..alphabet.len],
                )
            else
                try huffman.HuffmanTable(distance_capacity).Encoder.init(lengths);
            distance_symbol_count += alphabet.len;
        }

        if (comptime builtin.is_test) test_counters.split_code_builds += 1;
        const split_code = try adaptive_block_code.Code.init(allocator, split, distance_count);
        errdefer split_code.deinit(allocator);
        const context_map = try identity_context_map.Plan.init(allocator, type_count, 4);
        var payload_bits = try weighted_payload.histogram(
            command_capacity,
            if (borrowed) |owner| &owner.command_frequencies else &command_frequencies,
            if (borrowed) |owner| &owner.command_alphabet else &command_alphabet,
            if (borrowed) |owner| &owner.command_lengths else &command_lengths,
            true,
        );
        for (distance_frequencies, distance_alphabets, distance_lengths) |*frequencies, *alphabet, *lengths|
            payload_bits = try weighted_payload.add(
                payload_bits,
                try weighted_payload.histogram(distance_capacity, frequencies, alphabet, lengths, true),
            );
        var switches = counting_writer.Writer.init(0);
        for (1..split.blockCount()) |next_block|
            try split_code.writeSwitch(allocator, &switches, next_block);
        payload_bits = try weighted_payload.add(payload_bits, try switches.checkedBitPosition());
        payload_bits = try weighted_payload.add(payload_bits, payload_extra_bits);

        return .{
            .key = Key.init(options, commands, split),
            .command_symbols = command_symbols,
            .distance_encodings = distance_encodings,
            .distance_count = distance_count,
            .command_alphabet = command_alphabet,
            .command_lengths = command_lengths,
            .command_encoder = command_encoder,
            .borrowed_command = borrowed,
            .distance_alphabets = distance_alphabets,
            .distance_lengths = distance_lengths,
            .distance_encoders = distance_encoders,
            .split_code = split_code,
            .context_map = context_map,
            .payload_bits = payload_bits,
            .command_symbol_count = if (borrowed) |owner| owner.command_alphabet.len else command_alphabet.len,
            .distance_symbol_count = distance_symbol_count,
        };
    }

    pub fn deinit(self: *Prepared, allocator: std.mem.Allocator) void {
        self.split_code.deinit(allocator);
        allocator.free(self.distance_encoders);
        allocator.free(self.distance_lengths);
        allocator.free(self.distance_alphabets);
        allocator.free(self.distance_encodings);
        allocator.free(self.command_symbols);
        self.* = undefined;
    }

    pub fn matches(self: *const Prepared, options: anytype, commands: []const command_plan.Command) bool {
        if (self.borrowed_command) |owner|
            if (!borrowKeyMatches(owner, options, commands)) return false;
        return self.key.matches(options, commands) and self.command_symbols.len == commands.len and
            self.distance_count == self.distance_encodings.len and
            self.distance_alphabets.len == self.key.split_type_count and
            self.distance_lengths.len == self.key.split_type_count and
            self.distance_encoders.len == self.key.split_type_count;
    }

    pub fn commandAlphabet(self: *const Prepared) *const command_plan.PrefixAlphabet {
        return if (self.borrowed_command) |owner| &owner.command_alphabet else &self.command_alphabet;
    }

    pub fn commandLengths(self: *const Prepared) *const [command_capacity]u4 {
        return if (self.borrowed_command) |owner| &owner.command_lengths else &self.command_lengths;
    }

    pub fn commandEncoder(self: *const Prepared) *const huffman.HuffmanTable(command_capacity).Encoder {
        return if (self.borrowed_command) |owner| &owner.command_encoder else &self.command_encoder;
    }
};

fn borrowKeyMatches(common: *const prepared_command_distance.Prepared, options: anytype, commands: []const command_plan.Command) bool {
    // The owned entry's established test options omit this ordinary-key field.
    // Keep that generic instantiation valid without widening either API.
    if (comptime @hasField(@TypeOf(options), "optimize_same_last_distance")) {
        return common.ready and !common.has_exact_commands and
            options.use_recent_distances and
            std.meta.eql(options.distance_parameters, encoder_distance.Parameters.init(0, 15)) and
            common.key.matches(options, commands);
    } else return false;
}

/// Emit the selected literal preparation while borrowing every command,
/// distance, and split artifact from `common`. No command classification or
/// recent-distance simulation occurs on this path.
pub fn write(
    comptime S: type,
    allocator: std.mem.Allocator,
    writer: anytype,
    input: []const u8,
    commands: []const command_plan.Command,
    options: S.Options,
    common: *const Prepared,
    literals: *const prepared_literal.State,
) S.Error!void {
    if (!S.supported(options, commands) or !common.matches(options, commands) or
        !literals.matches(input, options)) return error.InvalidBlockPlan;
    const split = common.key.split_ptr;
    const command_alphabet = common.commandAlphabet();
    const command_encoder = common.commandEncoder();
    try S.header(allocator, writer, input, options, common, literals);

    var literal_encoders: [literal_context_split.max_trees]huffman.HuffmanTable(256).Encoder = undefined;
    for (literal_encoders[0..literals.tree_count], literals.alphabets[0..literals.tree_count], literals.lengths[0..literals.tree_count]) |*encoder, *alphabet, *lengths|
        encoder.* = try S.literalEncoder(lengths, alphabet);

    var distance_index: usize = 0;
    var block_index: usize = 0;
    var block_end: usize = split.lengths[0];
    for (commands, common.command_symbols) |command, symbol| {
        if (symbol >= command_lut.entries.len) return error.InvalidBlockPlan;
        const entry = command_lut.entries[symbol];
        if (command_alphabet.len > 1) {
            if (command_alphabet.len <= 4) {
                const code = command_alphabet.simpleCode(symbol) orelse return error.InvalidBlockPlan;
                try writer.writeHuffmanBits(allocator, code.code, code.bits);
            } else try writer.writeHuffmanBits(
                allocator,
                command_encoder.codes[symbol],
                command_encoder.bits[symbol],
            );
        }
        if (entry.insert_extra_bits != 0)
            try writer.writeBits(allocator, command.insert_len - entry.insert_base, entry.insert_extra_bits);
        if (entry.copy_extra_bits != 0)
            try writer.writeBits(allocator, command.copy_len - entry.copy_base, entry.copy_extra_bits);

        if (command.insert_start > input.len or command.insert_len > input.len - command.insert_start)
            return error.InvalidBlockPlan;
        for (input[command.insert_start..][0..command.insert_len], command.insert_start..) |literal, position| {
            const tree = if (literals.normalized_context) |candidate| blk: {
                const history = literalHistory(input, position, options.initial_previous);
                break :blk candidate.treeFor(literal_context.valueClustered(candidate.mode, history[0], history[1]));
            } else 0;
            const encoder = &literal_encoders[tree];
            if (encoder.bits[literal] != 0)
                try writer.writeHuffmanBits(allocator, encoder.codes[literal], encoder.bits[literal]);
        }

        if (command.has_copy and entry.distance_code == -1) {
            if (distance_index >= common.distance_count) return error.InvalidBlockPlan;
            if (distance_index > block_end) return error.InvalidBlockPlan;
            if (distance_index == block_end) {
                block_index += 1;
                if (block_index >= split.blockCount()) return error.InvalidBlockPlan;
                try common.split_code.writeSwitch(allocator, writer, block_index);
                block_end = std.math.add(usize, block_end, split.lengths[block_index]) catch
                    return error.IntegerOverflow;
            }
            const distance = common.distance_encodings[distance_index];
            const block_type: usize = split.types[block_index];
            const alphabet = &common.distance_alphabets[block_type];
            const encoder = &common.distance_encoders[block_type];
            if (distance.symbol >= distance_capacity) return error.InvalidBlockPlan;
            if (alphabet.len > 1) {
                if (alphabet.len <= 4) {
                    const code = alphabet.simpleCode(distance.symbol) orelse return error.InvalidBlockPlan;
                    try writer.writeHuffmanBits(allocator, code.code, code.bits);
                } else try writer.writeHuffmanBits(
                    allocator,
                    encoder.codes[distance.symbol],
                    encoder.bits[distance.symbol],
                );
            }
            if (distance.extra_bits != 0)
                try writer.writeBits(allocator, distance.extra, distance.extra_bits);
            distance_index += 1;
        }
    }
    if (distance_index != common.distance_count or block_index + 1 != split.blockCount() or
        block_end != distance_index) return error.InvalidBlockPlan;
    if (writer.bit_index != 0) writer.alignToByte();
}

fn literalHistory(input: []const u8, position: usize, initial_previous: [2]u8) [2]u8 {
    return if (position == 0)
        .{ initial_previous[1], initial_previous[0] }
    else if (position == 1)
        .{ input[0], initial_previous[1] }
    else
        .{ input[position - 1], input[position - 2] };
}

const TestOptions = struct {
    adaptive_distance_split: ?*const block_split_plan.Plan,
    window_bits: u5 = 16,
    distance_parameters: encoder_distance.Parameters = encoder_distance.Parameters.init(0, 15),
    compound_dictionary_size: usize = 0,
    initial_output_pos: core.StreamCount = 0,
    starting_last_distances: [4]usize = .{ 16, 15, 11, 4 },
    use_recent_distances: bool = true,
    initial_previous: [2]u8 = .{ 0, 0 },
    literal_context_mode: u2 = 0,
    utf8_context_cutoff: u6 = 56,
    optimize_literal_tree_wire: bool = false,
};

const TestStrategy = struct {
    pub const Error = anyerror;
    pub const Options = TestOptions;

    pub fn supported(options: Options, commands: []const command_plan.Command) bool {
        return options.adaptive_distance_split != null and options.use_recent_distances and commands.len != 0;
    }
    pub fn wireDistance(command: command_plan.Command, _: u5, _: usize, _: core.StreamCount) Error!usize {
        return command.distance;
    }
    pub fn recentDistance(_: usize, _: *[4]usize) ?u4 {
        return null;
    }
    pub fn pushDistance(_: *[4]usize, _: usize) void {}
};

fn testCommands() [4]command_plan.Command {
    return .{
        .{ .insert_start = 0, .insert_len = 1, .copy_len = 4, .distance = 5, .has_copy = true },
        .{ .insert_start = 5, .insert_len = 1, .copy_len = 4, .distance = 65, .has_copy = true },
        .{ .insert_start = 10, .insert_len = 1, .copy_len = 4, .distance = 1025, .has_copy = true },
        .{ .insert_start = 15, .insert_len = 1, .copy_len = 4, .distance = 33, .has_copy = true },
    };
}

test "prepared adaptive distance owns exact type storage and rejects key changes" {
    const lengths = [_]u32{ 2, 2 };
    const types = [_]u8{ 0, 1 };
    const split = try block_split_plan.Plan.initCopy(std.testing.allocator, &lengths, &types, 2, 4, 0);
    defer split.deinit(std.testing.allocator);
    var commands = testCommands();
    const options: TestOptions = .{ .adaptive_distance_split = &split };
    var prepared = try Prepared.init(TestStrategy, std.testing.allocator, &commands, options);
    defer prepared.deinit(std.testing.allocator);
    try std.testing.expect(prepared.matches(options, &commands));
    try std.testing.expectEqual(@as(usize, 2), prepared.distance_alphabets.len);
    try std.testing.expectEqual(@as(usize, 4), prepared.distance_count);
    try std.testing.expect(prepared.payload_bits != 0);

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
    changed.distance_parameters.npostfix = 1;
    try std.testing.expect(!prepared.matches(changed, &commands));
    changed = options;
    changed.distance_parameters.ndirect_high = 14;
    try std.testing.expect(!prepared.matches(changed, &commands));
    changed = options;
    changed.use_recent_distances = false;
    try std.testing.expect(!prepared.matches(changed, &commands));
    var other_commands = commands;
    try std.testing.expect(!prepared.matches(options, &other_commands));
    const other_split = try split.clone(std.testing.allocator, 4);
    defer other_split.deinit(std.testing.allocator);
    changed = options;
    changed.adaptive_distance_split = &other_split;
    try std.testing.expect(!prepared.matches(changed, &commands));

    changed = options;
    changed.initial_previous = .{ 7, 9 };
    changed.literal_context_mode = 3;
    changed.utf8_context_cutoff = 12;
    changed.optimize_literal_tree_wire = true;
    try std.testing.expect(prepared.matches(changed, &commands));
}

test "prepared adaptive distance cleans every partial allocation failure" {
    const lengths = [_]u32{ 1, 1, 1, 1 };
    const types = [_]u8{ 0, 1, 0, 1 };
    const split = try block_split_plan.Plan.initCopy(std.testing.allocator, &lengths, &types, 2, 4, 0);
    defer split.deinit(std.testing.allocator);
    var commands = testCommands();
    const Run = struct {
        fn run(allocator: std.mem.Allocator, command_stream: []const command_plan.Command, plan: *const block_split_plan.Plan) !void {
            var prepared = try Prepared.init(
                TestStrategy,
                allocator,
                command_stream,
                TestOptions{ .adaptive_distance_split = plan },
            );
            defer prepared.deinit(allocator);
            try std.testing.expect(prepared.matches(
                TestOptions{ .adaptive_distance_split = plan },
                command_stream,
            ));
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Run.run, .{ &commands, &split });
}

test "prepared adaptive distance borrows the keyed command model" {
    try @import("prepared_adaptive_distance_borrow_tests.zig").check(@This());
}
