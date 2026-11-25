//! Fixed-grid block-length trees for the literal, command and distance streams.
const std = @import("std");
const huffman = @import("../../../huffman.zig");
const block_length = @import("../../format/block_length.zig");
const command_plan = @import("../command_plan.zig");
const distance_block_split = @import("../distance_block_split.zig");
const literal_block_split = @import("../literal_block_split.zig");
const command_block_split = @import("../command_block_split.zig");

pub const LengthEncoding = block_length.Encoding;
const Alphabet = command_plan.PrefixAlphabetFor(26);
const Encoder = huffman.HuffmanTable(26).Encoder;

pub const Distance = struct {
    alphabet: Alphabet,
    lengths: [26]u4,
    encoder: Encoder,
    block_lengths: [distance_block_split.max_regions]LengthEncoding,
    block_count: usize,

    pub fn init(split: distance_block_split.Result, symbol_count: usize) !Distance {
        const data = try build(distance_block_split.max_regions, split, symbol_count);
        return .{
            .alphabet = data.alphabet,
            .lengths = data.lengths,
            .encoder = data.encoder,
            .block_lengths = data.block_lengths,
            .block_count = data.block_count,
        };
    }

    pub fn writeLength(self: *const Distance, allocator: std.mem.Allocator, writer: anytype, index: usize) !void {
        return write(self, allocator, writer, index);
    }
};

pub const Literal = struct {
    alphabet: Alphabet,
    lengths: [26]u4,
    encoder: Encoder,
    block_lengths: [literal_block_split.max_regions]LengthEncoding,
    block_count: usize,
    type_count: usize,

    pub fn init(split: literal_block_split.Result, literal_count: usize) !Literal {
        const block_count = split.regionCount();
        if (split.typeCount() < 2 or split.typeCount() > block_count) return error.InvalidBlockPlan;
        if (split.cycle_type_count != null and (split.alternate_two_types or split.reuse_first_for_fourth)) return error.InvalidBlockPlan;
        if (split.cycle_type_count == null and split.alternate_two_types and split.reuse_first_for_fourth) return error.InvalidBlockPlan;
        if (split.alternate_two_types and block_count > 4) return error.InvalidBlockPlan;
        if (split.reuse_first_for_fourth and block_count != 4) return error.InvalidBlockPlan;
        const data = try build(literal_block_split.max_regions, split, literal_count);
        return .{
            .alphabet = data.alphabet,
            .lengths = data.lengths,
            .encoder = data.encoder,
            .block_lengths = data.block_lengths,
            .block_count = data.block_count,
            .type_count = split.typeCount(),
        };
    }

    pub fn writeLength(self: *const Literal, allocator: std.mem.Allocator, writer: anytype, index: usize) !void {
        return write(self, allocator, writer, index);
    }
};

pub const Command = struct {
    alphabet: Alphabet,
    lengths: [26]u4,
    encoder: Encoder,
    block_lengths: [command_block_split.max_regions]LengthEncoding,
    block_count: usize,

    pub fn init(split: command_block_split.Result, command_count: usize) !Command {
        const data = try build(command_block_split.max_regions, split, command_count);
        return .{
            .alphabet = data.alphabet,
            .lengths = data.lengths,
            .encoder = data.encoder,
            .block_lengths = data.block_lengths,
            .block_count = data.block_count,
        };
    }

    pub fn writeLength(self: *const Command, allocator: std.mem.Allocator, writer: anytype, index: usize) !void {
        return write(self, allocator, writer, index);
    }
};

fn Data(comptime max_regions: usize) type {
    return struct {
        alphabet: Alphabet,
        lengths: [26]u4,
        encoder: Encoder,
        block_lengths: [max_regions]LengthEncoding,
        block_count: usize,
    };
}

/// These checks intentionally match the original Distance and Command rules.
/// Literal's additional reuse-policy checks stay in its own initializer.
fn build(comptime max_regions: usize, split: anytype, symbol_count: usize) !Data(max_regions) {
    const block_count = split.regionCount();
    if (split.typeCount() < 2 or split.typeCount() > block_count) return error.InvalidBlockPlan;
    if (split.second_split == null and (split.third_split != null or split.fourth_split != null or split.fifth_split != null)) return error.InvalidBlockPlan;
    if (split.third_split == null and (split.fourth_split != null or split.fifth_split != null)) return error.InvalidBlockPlan;
    if (split.fourth_split == null and split.fifth_split != null) return error.InvalidBlockPlan;
    var block_lengths: [max_regions]LengthEncoding = undefined;
    var previous: usize = 0;
    for (0..block_count) |region| {
        const end = if (region + 1 == block_count) symbol_count else split.boundary(region);
        if (end <= previous or end > symbol_count) return error.InvalidBlockPlan;
        block_lengths[region] = block_length.encode(end - previous) orelse return error.InvalidBlockPlan;
        previous = end;
    }
    var frequencies: [26]u32 = @splat(0);
    for (block_lengths[0..block_count]) |encoding| frequencies[encoding.symbol] += 1;
    var alphabet: Alphabet = undefined;
    try command_plan.alphabetFromFrequenciesInto(26, &alphabet, &frequencies);
    const lengths = try alphabet.codeLengths(&frequencies);
    const encoder = if (alphabet.len <= 4) Encoder{} else try Encoder.init(&lengths);
    return .{
        .alphabet = alphabet,
        .lengths = lengths,
        .encoder = encoder,
        .block_lengths = block_lengths,
        .block_count = block_count,
    };
}

fn write(self: anytype, allocator: std.mem.Allocator, writer: anytype, index: usize) !void {
    if (index >= self.block_count) return error.InvalidBlockPlan;
    const encoding = self.block_lengths[index];
    if (self.alphabet.len > 1) {
        if (self.alphabet.len <= 4) {
            const code = self.alphabet.simpleCode(encoding.symbol) orelse return error.InvalidBlockPlan;
            try writer.writeHuffmanBits(allocator, code.code, code.bits);
        } else try writer.writeHuffmanBits(allocator, self.encoder.codes[encoding.symbol], self.encoder.bits[encoding.symbol]);
    }
    try writer.writeBits(allocator, encoding.extra, encoding.extra_bits);
}

test {
    _ = @import("length_code_tests.zig");
}
