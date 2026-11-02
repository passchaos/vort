//! Exact ordinary adaptive-literal preparation for one immutable candidate.
const std = @import("std");
const bit_count = @import("../../io/bit_count.zig");
const command_plan = @import("command_plan.zig");
const command_encoding = @import("command_encoding.zig");
const distance = @import("distance.zig");
const compound_wire = @import("compound_wire.zig");
const common_plan = @import("prepared_command_distance.zig");
const split_plan = @import("block_split_plan.zig");
const block_code = @import("adaptive_block_code.zig");
const context_map = @import("identity_context_map.zig");
const counting = @import("counting_writer.zig");
const weighted = @import("weighted_payload.zig");
const huffman = @import("../../huffman.zig");
const stream_count = @import("../../io/stream_count.zig");

pub const max_types = 8;
pub const max_literals = 64 * 1024;
pub const Alphabet = command_plan.PrefixAlphabetFor(256);

pub const Key = struct {
    common: common_plan.Key,
    input_ptr: [*]const u8,
    input_len: usize,
    split_ptr: *const split_plan.Plan,
    lengths_ptr: [*]const u32,
    types_ptr: [*]const u8,
    blocks: usize,
    type_count: u16,
    literal_mode: u2,

    pub fn init(input: []const u8, commands: []const command_plan.Command, options: anytype) Key {
        const split = options.adaptive_literal_split.?;
        return .{ .common = common_plan.Key.init(options, commands), .input_ptr = input.ptr, .input_len = input.len, .split_ptr = split, .lengths_ptr = split.lengths.ptr, .types_ptr = split.types.ptr, .blocks = split.blockCount(), .type_count = split.type_count, .literal_mode = options.literal_context_mode };
    }

    pub fn matches(self: *const Key, input: []const u8, commands: []const command_plan.Command, options: anytype) bool {
        const split = options.adaptive_literal_split orelse return false;
        return self.common.matches(options, commands) and self.input_ptr == input.ptr and self.input_len == input.len and
            self.split_ptr == split and self.lengths_ptr == split.lengths.ptr and self.types_ptr == split.types.ptr and
            self.blocks == split.blockCount() and self.blocks == split.types.len and self.type_count == split.type_count and self.literal_mode == options.literal_context_mode;
    }
};

/// Single owner of `split_code`; input, commands and split remain borrowed.
pub const Prepared = struct {
    key: Key,
    common: common_plan.Prepared,
    alphabets: [max_types]Alphabet = undefined,
    lengths: [max_types][256]u4 = undefined,
    split_code: block_code.Code,
    context_map: context_map.Plan,
    literal_count: usize,
    header_bits: bit_count.BitCount,
    payload_bits: bit_count.BitCount,
    wire_len: usize,

    pub fn init(comptime S: type, allocator: std.mem.Allocator, input: []const u8, commands: []const command_plan.Command, options: S.Options) S.Error!Prepared {
        if (!S.supported(input, commands, options)) return error.InvalidBlockPlan;
        _ = try stream_count.addLocal(options.initial_output_pos, input.len);
        const split = options.adaptive_literal_split.?;
        var frequencies: [max_types][256]u32 = undefined;
        @memset(frequencies[0..split.type_count], @splat(0));
        var common = common_plan.Prepared.init(options, commands);
        var command_frequencies: [common_plan.command_capacity]u32 = undefined;
        var distance_frequencies: [common_plan.distance_capacity]u32 = @splat(0);
        var command_alphabet: command_plan.PrefixAlphabet = undefined;
        command_alphabet.len = 0;
        var command_symbols: [common_plan.symbol_capacity]u16 = undefined;
        const cache_symbols = commands.len <= command_symbols.len;
        var literal_count: usize = 0;
        for (commands) |command| {
            if (command.insert_start > input.len or command.insert_len > input.len - command.insert_start) return error.InvalidBlockPlan;
            literal_count = std.math.add(usize, literal_count, command.insert_len) catch return error.IntegerOverflow;
        }
        if (literal_count > max_literals) return error.InvalidBlockPlan;
        try split.validate(literal_count);
        var index: usize = 0;
        var block_index: usize = 0;
        var block_end: usize = split.lengths[0];
        var repeats = options.starting_last_distances;
        var extras: bit_count.BitCount = 0;
        for (commands, 0..) |command, command_index| {
            const physical = if (command.has_copy) try S.wireDistance(command, options.window_bits, options.compound_dictionary_size, options.initial_output_pos) else 0;
            const recent = if (command.has_copy and compound_wire.canUseRecentDistance(command.source)) S.recentDistance(physical, &repeats) else null;
            const encoded = command_encoding.forLengths(command.insert_len, command.copy_len, recent == 0) orelse
                command_encoding.forLengths(command.insert_len, command.copy_len, false) orelse return error.InvalidBlockPlan;
            try command_alphabet.recordFrequency(&command_frequencies, encoded.symbol);
            if (cache_symbols) command_symbols[command_index] = encoded.symbol;
            extras = try weighted.add(extras, @as(bit_count.BitCount, encoded.command.insert_extra_bits) + encoded.command.copy_extra_bits);
            for (input[command.insert_start..][0..command.insert_len]) |literal| {
                if (index == block_end) {
                    block_index += 1;
                    if (block_index >= split.blockCount()) return error.InvalidBlockPlan;
                    block_end = std.math.add(usize, block_end, split.lengths[block_index]) catch return error.IntegerOverflow;
                }
                frequencies[split.types[block_index]][literal] += 1;
                index += 1;
            }
            if (command.has_copy and encoded.command.distance_code == -1) {
                const encoding = if (recent) |symbol| distance.Encoding{ .symbol = symbol } else distance.encodeWithFormat(physical, options.distance_parameters, .standard) orelse return error.InvalidBlockPlan;
                if (encoding.symbol >= common_plan.distance_capacity) return error.InvalidBlockPlan;
                distance_frequencies[encoding.symbol] += 1;
                extras = try weighted.add(extras, encoding.extra_bits);
            }
            if (command.has_copy and compound_wire.updatesRecentDistance(command.source, recent == 0)) S.pushDistance(&repeats, physical);
        }
        if (index != literal_count or block_index + 1 != split.blockCount() or block_end != literal_count) return error.InvalidBlockPlan;
        if (for (distance_frequencies) |frequency| {
            if (frequency != 0) break false;
        } else true) distance_frequencies[0] = 1;
        try command_alphabet.sortByFrequencies(&command_frequencies);
        const command_lengths = if (command_alphabet.len <= 4) @as([common_plan.command_capacity]u4, @splat(0)) else try command_alphabet.codeLengths(&command_frequencies);
        var distance_alphabet: command_plan.PrefixAlphabetFor(common_plan.distance_capacity) = undefined;
        try command_plan.alphabetFromFrequenciesInto(common_plan.distance_capacity, &distance_alphabet, &distance_frequencies);
        const distance_lengths = if (distance_alphabet.len <= 4) @as([common_plan.distance_capacity]u4, @splat(0)) else try distance_alphabet.codeLengths(&distance_frequencies);
        try common.captureCounted(&command_frequencies, &command_alphabet, &command_lengths, &distance_frequencies, &distance_alphabet, &distance_lengths, extras, if (cache_symbols) &command_symbols else null);
        var alphabets: [max_types]Alphabet = undefined;
        var lengths: [max_types][256]u4 = undefined;
        for (frequencies[0..split.type_count], alphabets[0..split.type_count], lengths[0..split.type_count]) |*frequency, *alphabet, *tree_lengths| {
            try command_plan.alphabetFromFrequenciesInto(256, alphabet, frequency);
            tree_lengths.* = try alphabet.codeLengths(frequency);
        }
        var code = try block_code.Code.init(allocator, split, literal_count);
        errdefer code.deinit(allocator);
        const map = try context_map.Plan.init(allocator, split.type_count, 64);
        var result: Prepared = .{ .key = Key.init(input, commands, options), .common = common, .alphabets = alphabets, .lengths = lengths, .split_code = code, .context_map = map, .literal_count = literal_count, .header_bits = 0, .payload_bits = 0, .wire_len = 0 };
        var header = counting.Writer.init(0);
        try S.header(allocator, &header, input, options, &result);
        result.header_bits = try header.checkedBitPosition();
        var payload = try weighted.histogram(common_plan.command_capacity, &command_frequencies, &command_alphabet, &command_lengths, true);
        payload = try weighted.add(payload, try weighted.histogram(common_plan.distance_capacity, &distance_frequencies, &distance_alphabet, &distance_lengths, true));
        payload = try weighted.add(payload, extras);
        for (frequencies[0..split.type_count], alphabets[0..split.type_count], lengths[0..split.type_count]) |*frequency, *alphabet, *tree_lengths|
            payload = try weighted.add(payload, try weighted.histogram(256, frequency, alphabet, tree_lengths, false));
        var switches = counting.Writer.init(0);
        for (1..split.blockCount()) |block| try code.writeSwitch(allocator, &switches, block);
        result.payload_bits = try weighted.add(payload, try switches.checkedBitPosition());
        result.wire_len = try weighted.ceilBytes(try weighted.add(result.header_bits, result.payload_bits));
        return result;
    }

    pub fn deinit(self: *Prepared, allocator: std.mem.Allocator) void {
        self.split_code.deinit(allocator);
        self.* = undefined;
    }
};

pub fn write(comptime S: type, allocator: std.mem.Allocator, writer: anytype, input: []const u8, commands: []const command_plan.Command, options: S.Options, prepared: *const Prepared) S.Error!void {
    if (!S.supported(input, commands, options) or !prepared.key.matches(input, commands, options) or !prepared.common.ready) return error.InvalidBlockPlan;
    const split = options.adaptive_literal_split.?;
    try S.header(allocator, writer, input, options, prepared);
    var encoders: [max_types]huffman.HuffmanTable(256).Encoder = undefined;
    for (encoders[0..split.type_count], prepared.alphabets[0..split.type_count], prepared.lengths[0..split.type_count]) |*encoder, *alphabet, *lengths| encoder.* = try S.literalEncoder(lengths, alphabet);
    var repeats = options.starting_last_distances;
    var index: usize = 0;
    var block: usize = 0;
    var end: usize = split.lengths[0];
    for (commands, 0..) |command, command_index| {
        const physical = if (command.has_copy) try S.wireDistance(command, options.window_bits, options.compound_dictionary_size, options.initial_output_pos) else 0;
        const recent = if (command.has_copy and compound_wire.canUseRecentDistance(command.source)) S.recentDistance(physical, &repeats) else null;
        const encoded = try S.commandEncoding(&prepared.common, command_index, commands.len, command, recent);
        if (prepared.common.command_alphabet.len > 1) {
            if (prepared.common.command_alphabet.len <= 4) {
                const code = prepared.common.command_alphabet.simpleCode(encoded.symbol).?;
                try writer.writeHuffmanBits(allocator, code.code, code.bits);
            } else try writer.writeHuffmanBits(allocator, prepared.common.command_encoder.codes[encoded.symbol], prepared.common.command_encoder.bits[encoded.symbol]);
        }
        try S.writeExtras(allocator, writer, encoded, command.insert_len, command.copy_len);
        for (input[command.insert_start..][0..command.insert_len]) |literal| {
            if (index == end) {
                block += 1;
                if (block >= split.blockCount()) return error.InvalidBlockPlan;
                try prepared.split_code.writeSwitch(allocator, writer, block);
                end = std.math.add(usize, end, split.lengths[block]) catch return error.IntegerOverflow;
            }
            const encoder = &encoders[split.types[block]];
            if (encoder.bits[literal] != 0) try writer.writeHuffmanBits(allocator, encoder.codes[literal], encoder.bits[literal]);
            index += 1;
        }
        if (command.has_copy and encoded.command.distance_code == -1) {
            const encoding = if (recent) |symbol| distance.Encoding{ .symbol = symbol } else distance.encodeWithFormat(physical, options.distance_parameters, .standard) orelse return error.InvalidBlockPlan;
            if (prepared.common.distance_alphabet.len > 1) {
                if (prepared.common.distance_alphabet.len <= 4) {
                    const code = prepared.common.distance_alphabet.simpleCode(encoding.symbol).?;
                    try writer.writeHuffmanBits(allocator, code.code, code.bits);
                } else try writer.writeHuffmanBits(allocator, prepared.common.distance_encoder.codes[encoding.symbol], prepared.common.distance_encoder.bits[encoding.symbol]);
            }
            if (encoding.extra_bits != 0) try writer.writeBits(allocator, encoding.extra, encoding.extra_bits);
        }
        if (command.has_copy and compound_wire.updatesRecentDistance(command.source, recent == 0)) S.pushDistance(&repeats, physical);
    }
    if (index != prepared.literal_count or block + 1 != split.blockCount() or end != index) return error.InvalidBlockPlan;
    if (writer.bit_index != 0) writer.alignToByte();
}
