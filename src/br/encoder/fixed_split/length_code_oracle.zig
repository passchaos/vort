//! Frozen src/br.zig block-length oracle from revision 0dd219d929d1883affab68a98c73a910487a07ce.
//! Source logic is copied verbatim; declarations and methods are made public
//! for tests, and imports plus the original 1 << 24 encoder limit are local.
//! Do not replace these checks or the resolver with production helpers.
const std = @import("std");
const core = @import("../../../core.zig");
const br_length = @import("../../length.zig");
const command_plan = @import("../command_plan.zig");
const distance_block_split = @import("../distance_block_split.zig");
const literal_block_split = @import("../literal_block_split.zig");
const command_block_split = @import("../command_block_split.zig");
const BitWriter = @import("../bit_writer.zig").Writer;
const Error = core.Error || std.mem.Allocator.Error || error{WorkingMemoryLimitExceeded};
const max_uncompressed_meta_block_len: usize = 1 << 24;

pub const Distance = DistanceBlockLengthCode;
pub const Literal = LiteralBlockLengthCode;
pub const Command = CommandBlockLengthCode;

pub const BlockLengthEncoding = struct {
    symbol: u5,
    extra: usize,
    extra_bits: u5,
};

pub const DistanceBlockLengthCode = struct {
    alphabet: command_plan.PrefixAlphabetFor(26),
    lengths: [26]u4,
    block_lengths: [distance_block_split.max_regions]BlockLengthEncoding,
    block_count: usize,

    pub fn init(split: distance_block_split.Result, symbol_count: usize) Error!DistanceBlockLengthCode {
        const block_count = split.regionCount();
        if (split.typeCount() < 2 or split.typeCount() > block_count) return error.InvalidBlockPlan;
        if (split.second_split == null and (split.third_split != null or split.fourth_split != null or split.fifth_split != null)) return error.InvalidBlockPlan;
        if (split.third_split == null and (split.fourth_split != null or split.fifth_split != null)) return error.InvalidBlockPlan;
        if (split.fourth_split == null and split.fifth_split != null) return error.InvalidBlockPlan;
        var block_lengths: [distance_block_split.max_regions]BlockLengthEncoding = undefined;
        var previous: usize = 0;
        for (0..block_count) |region| {
            const end = if (region + 1 == block_count) symbol_count else split.boundary(region);
            if (end <= previous or end > symbol_count) return error.InvalidBlockPlan;
            block_lengths[region] = blockLengthEncoding(end - previous) orelse return error.InvalidBlockPlan;
            previous = end;
        }
        var frequencies: [26]u32 = @splat(0);
        for (block_lengths[0..block_count]) |encoding| frequencies[encoding.symbol] += 1;
        var alphabet: command_plan.PrefixAlphabetFor(26) = undefined;
        try command_plan.alphabetFromFrequenciesInto(26, &alphabet, &frequencies);
        return .{
            .alphabet = alphabet,
            .lengths = try alphabet.codeLengths(&frequencies),
            .block_lengths = block_lengths,
            .block_count = block_count,
        };
    }

    pub fn writeLength(self: *const DistanceBlockLengthCode, allocator: std.mem.Allocator, writer: *BitWriter, index: usize) Error!void {
        if (index >= self.block_count) return error.InvalidBlockPlan;
        const encoding = self.block_lengths[index];
        if (self.alphabet.len > 1) {
            const code = self.alphabet.simpleCode(encoding.symbol) orelse return error.InvalidBlockPlan;
            try writer.writeHuffmanBits(allocator, code.code, code.bits);
        }
        try writer.writeBits(allocator, encoding.extra, encoding.extra_bits);
    }
};

pub const LiteralBlockLengthCode = struct {
    alphabet: command_plan.PrefixAlphabetFor(26),
    lengths: [26]u4,
    block_lengths: [literal_block_split.max_regions]BlockLengthEncoding,
    block_count: usize,
    type_count: usize,

    pub fn init(split: literal_block_split.Result, literal_count: usize) Error!LiteralBlockLengthCode {
        const block_count = split.regionCount();
        if (split.typeCount() < 2 or split.typeCount() > block_count) return error.InvalidBlockPlan;
        if (split.cycle_type_count != null and (split.alternate_two_types or split.reuse_first_for_fourth)) return error.InvalidBlockPlan;
        if (split.cycle_type_count == null and split.alternate_two_types and split.reuse_first_for_fourth) return error.InvalidBlockPlan;
        if (split.alternate_two_types and block_count > 4) return error.InvalidBlockPlan;
        if (split.reuse_first_for_fourth and block_count != 4) return error.InvalidBlockPlan;
        if (split.second_split == null and (split.third_split != null or split.fourth_split != null or split.fifth_split != null)) return error.InvalidBlockPlan;
        if (split.third_split == null and (split.fourth_split != null or split.fifth_split != null)) return error.InvalidBlockPlan;
        if (split.fourth_split == null and split.fifth_split != null) return error.InvalidBlockPlan;
        var block_lengths: [literal_block_split.max_regions]BlockLengthEncoding = undefined;
        var previous: usize = 0;
        for (0..block_count) |region| {
            const end = if (region + 1 == block_count) literal_count else split.boundary(region);
            if (end <= previous or end > literal_count) return error.InvalidBlockPlan;
            block_lengths[region] = blockLengthEncoding(end - previous) orelse return error.InvalidBlockPlan;
            previous = end;
        }
        var frequencies: [26]u32 = @splat(0);
        for (block_lengths[0..block_count]) |encoding| frequencies[encoding.symbol] += 1;
        var alphabet: command_plan.PrefixAlphabetFor(26) = undefined;
        try command_plan.alphabetFromFrequenciesInto(26, &alphabet, &frequencies);
        return .{
            .alphabet = alphabet,
            .lengths = try alphabet.codeLengths(&frequencies),
            .block_lengths = block_lengths,
            .block_count = block_count,
            .type_count = split.typeCount(),
        };
    }

    pub fn writeLength(self: *const LiteralBlockLengthCode, allocator: std.mem.Allocator, writer: *BitWriter, index: usize) Error!void {
        if (index >= self.block_count) return error.InvalidBlockPlan;
        const encoding = self.block_lengths[index];
        if (self.alphabet.len > 1) {
            const code = self.alphabet.simpleCode(encoding.symbol) orelse return error.InvalidBlockPlan;
            try writer.writeHuffmanBits(allocator, code.code, code.bits);
        }
        try writer.writeBits(allocator, encoding.extra, encoding.extra_bits);
    }
};

pub const CommandBlockLengthCode = struct {
    alphabet: command_plan.PrefixAlphabetFor(26),
    lengths: [26]u4,
    block_lengths: [command_block_split.max_regions]BlockLengthEncoding,
    block_count: usize,

    pub fn init(split: command_block_split.Result, command_count: usize) Error!CommandBlockLengthCode {
        const block_count = split.regionCount();
        if (split.typeCount() < 2 or split.typeCount() > block_count) return error.InvalidBlockPlan;
        if (split.second_split == null and (split.third_split != null or split.fourth_split != null or split.fifth_split != null)) return error.InvalidBlockPlan;
        if (split.third_split == null and (split.fourth_split != null or split.fifth_split != null)) return error.InvalidBlockPlan;
        if (split.fourth_split == null and split.fifth_split != null) return error.InvalidBlockPlan;
        var block_lengths: [command_block_split.max_regions]BlockLengthEncoding = undefined;
        var previous: usize = 0;
        for (0..block_count) |region| {
            const end = if (region + 1 == block_count) command_count else split.boundary(region);
            if (end <= previous or end > command_count) return error.InvalidBlockPlan;
            block_lengths[region] = blockLengthEncoding(end - previous) orelse return error.InvalidBlockPlan;
            previous = end;
        }
        var frequencies: [26]u32 = @splat(0);
        for (block_lengths[0..block_count]) |encoding| frequencies[encoding.symbol] += 1;
        var alphabet: command_plan.PrefixAlphabetFor(26) = undefined;
        try command_plan.alphabetFromFrequenciesInto(26, &alphabet, &frequencies);
        return .{
            .alphabet = alphabet,
            .lengths = try alphabet.codeLengths(&frequencies),
            .block_lengths = block_lengths,
            .block_count = block_count,
        };
    }

    pub fn writeLength(self: *const CommandBlockLengthCode, allocator: std.mem.Allocator, writer: *BitWriter, index: usize) Error!void {
        if (index >= self.block_count) return error.InvalidBlockPlan;
        const encoding = self.block_lengths[index];
        if (self.alphabet.len > 1) {
            const code = self.alphabet.simpleCode(encoding.symbol) orelse return error.InvalidBlockPlan;
            try writer.writeHuffmanBits(allocator, code.code, code.bits);
        }
        try writer.writeBits(allocator, encoding.extra, encoding.extra_bits);
    }
};

const LengthSpec = br_length.Spec;

pub const block_length_specs = [_]LengthSpec{
    .{ .base = 1, .extra_bits = 2 },
    .{ .base = 5, .extra_bits = 2 },
    .{ .base = 9, .extra_bits = 2 },
    .{ .base = 13, .extra_bits = 2 },
    .{ .base = 17, .extra_bits = 3 },
    .{ .base = 25, .extra_bits = 3 },
    .{ .base = 33, .extra_bits = 3 },
    .{ .base = 41, .extra_bits = 3 },
    .{ .base = 49, .extra_bits = 4 },
    .{ .base = 65, .extra_bits = 4 },
    .{ .base = 81, .extra_bits = 4 },
    .{ .base = 97, .extra_bits = 4 },
    .{ .base = 113, .extra_bits = 5 },
    .{ .base = 145, .extra_bits = 5 },
    .{ .base = 177, .extra_bits = 5 },
    .{ .base = 209, .extra_bits = 5 },
    .{ .base = 241, .extra_bits = 6 },
    .{ .base = 305, .extra_bits = 6 },
    .{ .base = 369, .extra_bits = 7 },
    .{ .base = 497, .extra_bits = 8 },
    .{ .base = 753, .extra_bits = 9 },
    .{ .base = 1265, .extra_bits = 10 },
    .{ .base = 2289, .extra_bits = 11 },
    .{ .base = 4337, .extra_bits = 12 },
    .{ .base = 8433, .extra_bits = 13 },
    .{ .base = 16625, .extra_bits = 24 },
};

pub fn blockLengthEncoding(len: usize) ?BlockLengthEncoding {
    if (len == 0 or len > max_uncompressed_meta_block_len) return null;
    for (block_length_specs, 0..) |spec, symbol| {
        const capacity = @as(usize, 1) << @intCast(spec.extra_bits);
        if (len < spec.base or len - spec.base >= capacity) continue;
        return .{ .symbol = @intCast(symbol), .extra = len - spec.base, .extra_bits = spec.extra_bits };
    }
    return null;
}
