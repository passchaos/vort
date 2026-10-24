const std = @import("std");
const huffman = @import("../../huffman.zig");
const command_plan = @import("command_plan.zig");
const block_split_plan = @import("block_split_plan.zig");
const block_switch_model = @import("block_switch_model.zig");

pub const LengthEncoding = struct {
    symbol: u5,
    extra: usize,
    extra_bits: u5,
};

/// Allocator-owned RFC 7932 block-type and block-length code shared by the
/// adaptive literal, command, and distance writers. The block payload trees
/// remain the responsibility of the format-specific caller.
pub const Code = struct {
    type_model: block_switch_model.Model,
    type_alphabet: command_plan.PrefixAlphabetFor(block_switch_model.max_alphabet_size),
    type_lengths: [block_switch_model.max_alphabet_size]u4,
    type_encoder: huffman.HuffmanTable(block_switch_model.max_alphabet_size).Encoder,
    length_alphabet: command_plan.PrefixAlphabetFor(26),
    length_lengths: [26]u4,
    length_encoder: huffman.HuffmanTable(26).Encoder,
    block_lengths: []LengthEncoding,

    pub fn init(
        allocator: std.mem.Allocator,
        plan: *const block_split_plan.Plan,
        symbol_count: usize,
    ) !Code {
        try plan.validate(symbol_count);
        if (plan.type_count < 2) return error.InvalidBlockPlan;
        const type_model = block_switch_model.buildAlloc(allocator, plan) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            error.IntegerOverflow => return error.IntegerOverflow,
            error.InvalidBlockPlan,
            error.CountOverflow,
            error.InvalidBlockSwitchState,
            error.InvalidBlockSwitchSymbol,
            error.OutputSizeMismatch,
            => return error.InvalidBlockPlan,
        };
        errdefer type_model.deinit(allocator);

        const block_lengths = try allocator.alloc(LengthEncoding, plan.blockCount());
        errdefer allocator.free(block_lengths);
        var length_frequencies: [26]u32 = @splat(0);
        for (plan.lengths, block_lengths) |block_len, *encoding| {
            encoding.* = lengthEncoding(block_len) orelse return error.InvalidBlockPlan;
            length_frequencies[encoding.symbol] += 1;
        }

        var type_alphabet: command_plan.PrefixAlphabetFor(block_switch_model.max_alphabet_size) = undefined;
        try command_plan.alphabetFromFrequenciesInto(
            block_switch_model.max_alphabet_size,
            &type_alphabet,
            &type_model.frequencies,
        );
        const type_lengths = if (type_alphabet.len <= 4)
            @as([block_switch_model.max_alphabet_size]u4, @splat(0))
        else
            try type_alphabet.codeLengths(&type_model.frequencies);
        const type_encoder = if (type_alphabet.len <= 4)
            huffman.HuffmanTable(block_switch_model.max_alphabet_size).Encoder{}
        else if (type_alphabet.len <= 64)
            try huffman.HuffmanTable(block_switch_model.max_alphabet_size).Encoder.initSparseTrusted(
                &type_lengths,
                type_alphabet.symbols[0..type_alphabet.len],
            )
        else
            try huffman.HuffmanTable(block_switch_model.max_alphabet_size).Encoder.init(&type_lengths);

        var length_alphabet: command_plan.PrefixAlphabetFor(26) = undefined;
        try command_plan.alphabetFromFrequenciesInto(26, &length_alphabet, &length_frequencies);
        const length_lengths = if (length_alphabet.len <= 4)
            @as([26]u4, @splat(0))
        else
            try length_alphabet.codeLengths(&length_frequencies);
        const length_encoder = if (length_alphabet.len <= 4)
            huffman.HuffmanTable(26).Encoder{}
        else
            try huffman.HuffmanTable(26).Encoder.initSparseTrusted(
                &length_lengths,
                length_alphabet.symbols[0..length_alphabet.len],
            );

        return .{
            .type_model = type_model,
            .type_alphabet = type_alphabet,
            .type_lengths = type_lengths,
            .type_encoder = type_encoder,
            .length_alphabet = length_alphabet,
            .length_lengths = length_lengths,
            .length_encoder = length_encoder,
            .block_lengths = block_lengths,
        };
    }

    pub fn deinit(self: Code, allocator: std.mem.Allocator) void {
        self.type_model.deinit(allocator);
        allocator.free(self.block_lengths);
    }

    pub fn writeInitialLength(self: *const Code, allocator: std.mem.Allocator, writer: anytype) !void {
        return self.writeLength(allocator, writer, 0);
    }

    pub fn writeSwitch(self: *const Code, allocator: std.mem.Allocator, writer: anytype, block_index: usize) !void {
        if (block_index == 0 or block_index >= self.block_lengths.len) return error.InvalidBlockPlan;
        const symbol = self.type_model.symbols[block_index - 1];
        if (self.type_alphabet.len > 1) {
            if (self.type_alphabet.len <= 4) {
                const code = self.type_alphabet.simpleCode(symbol) orelse return error.InvalidBlockPlan;
                try writer.writeHuffmanBits(allocator, code.code, code.bits);
            } else try writer.writeHuffmanBits(allocator, self.type_encoder.codes[symbol], self.type_encoder.bits[symbol]);
        }
        try self.writeLength(allocator, writer, block_index);
    }

    pub fn writeLength(self: *const Code, allocator: std.mem.Allocator, writer: anytype, block_index: usize) !void {
        if (block_index >= self.block_lengths.len) return error.InvalidBlockPlan;
        const encoding = self.block_lengths[block_index];
        if (self.length_alphabet.len > 1) {
            if (self.length_alphabet.len <= 4) {
                const code = self.length_alphabet.simpleCode(encoding.symbol) orelse return error.InvalidBlockPlan;
                try writer.writeHuffmanBits(allocator, code.code, code.bits);
            } else try writer.writeHuffmanBits(allocator, self.length_encoder.codes[encoding.symbol], self.length_encoder.bits[encoding.symbol]);
        }
        try writer.writeBits(allocator, encoding.extra, encoding.extra_bits);
    }
};

const LengthSpec = struct {
    base: usize,
    extra_bits: u5,
};

const length_specs = [_]LengthSpec{
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

fn lengthEncoding(len: usize) ?LengthEncoding {
    if (len == 0 or len > (@as(usize, 1) << 24)) return null;
    for (length_specs, 0..) |spec, symbol| {
        const capacity = @as(usize, 1) << @intCast(spec.extra_bits);
        if (len < spec.base or len - spec.base >= capacity) continue;
        return .{
            .symbol = @intCast(symbol),
            .extra = len - spec.base,
            .extra_bits = spec.extra_bits,
        };
    }
    return null;
}

test "adaptive block code emits every switch and length" {
    const lengths = [_]u32{ 5, 8, 13, 21, 34 };
    const types = [_]u8{ 0, 1, 0, 2, 0 };
    const symbol_count: usize = 81;
    const plan = try block_split_plan.Plan.initCopy(
        std.testing.allocator,
        &lengths,
        &types,
        3,
        symbol_count,
        0,
    );
    defer plan.deinit(std.testing.allocator);
    const code = try Code.init(std.testing.allocator, &plan, symbol_count);
    defer code.deinit(std.testing.allocator);

    const CountingWriter = struct {
        bits: usize = 0,

        pub fn writeBits(self: *@This(), _: std.mem.Allocator, _: anytype, count: anytype) !void {
            self.bits += count;
        }

        pub fn writeHuffmanBits(self: *@This(), _: std.mem.Allocator, _: u16, count: u4) !void {
            self.bits += count;
        }
    };
    var writer: CountingWriter = .{};
    try code.writeInitialLength(std.testing.allocator, &writer);
    for (1..plan.blockCount()) |block_index|
        try code.writeSwitch(std.testing.allocator, &writer, block_index);
    try std.testing.expect(writer.bits != 0);
    try std.testing.expectError(
        error.InvalidBlockPlan,
        code.writeSwitch(std.testing.allocator, &writer, plan.blockCount()),
    );
}

test "adaptive block code allocation failures clean up" {
    const lengths = [_]u32{ 7, 11, 13 };
    const types = [_]u8{ 0, 1, 0 };
    const symbol_count: usize = 31;
    const plan = try block_split_plan.Plan.initCopy(
        std.testing.allocator,
        &lengths,
        &types,
        2,
        symbol_count,
        0,
    );
    defer plan.deinit(std.testing.allocator);

    const Test = struct {
        fn run(allocator: std.mem.Allocator, active_plan: *const block_split_plan.Plan, count: usize) !void {
            const code = try Code.init(allocator, active_plan, count);
            code.deinit(allocator);
        }
    };
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        Test.run,
        .{ &plan, symbol_count },
    );
}
