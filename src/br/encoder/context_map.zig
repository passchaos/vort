const std = @import("std");
const huffman = @import("../../huffman.zig");
const command_plan = @import("command_plan.zig");
const complex_prefix = @import("complex_prefix.zig");

pub const max_tree_count: usize = 64;
pub const max_rle_prefix: usize = 6;
pub const max_alphabet_size: usize = max_tree_count + max_rle_prefix;
pub const map_len: usize = 64;

pub const Token = struct {
    symbol: u8,
    extra: u8 = 0,
    extra_bits: u3 = 0,
};

pub const Plan = struct {
    use_mtf: bool,
    rle_prefix: u3,
    alphabet_size: usize,
    tokens: [map_len]Token,
    token_count: usize,
    frequencies: [max_alphabet_size]u32,
    alphabet: command_plan.PrefixAlphabetFor(max_alphabet_size),
    lengths: [max_alphabet_size]u4,
    bit_cost: u64,
};

pub fn choose(allocator: std.mem.Allocator, context_map: *const [map_len]u8, tree_count: usize) !Plan {
    if (tree_count < 2 or tree_count > max_tree_count) return error.InvalidBlockPlan;
    for (context_map) |tree| if (tree >= tree_count) return error.InvalidBlockPlan;

    var best = try build(allocator, context_map, tree_count, false, 0);
    for ([_]bool{ false, true }) |use_mtf| {
        for (0..max_rle_prefix + 1) |rle_prefix| {
            if (!use_mtf and rle_prefix == 0) continue;
            const candidate = try build(allocator, context_map, tree_count, use_mtf, @intCast(rle_prefix));
            if (candidate.bit_cost < best.bit_cost) best = candidate;
        }
    }
    return best;
}

pub fn write(allocator: std.mem.Allocator, writer: anytype, plan: *const Plan) !void {
    try writer.writeBits(allocator, @intFromBool(plan.rle_prefix != 0), 1);
    if (plan.rle_prefix != 0) try writer.writeBits(allocator, plan.rle_prefix - 1, 4);
    try writePrefix(allocator, writer, plan.alphabet_size, &plan.alphabet, &plan.lengths);
    const encoder = if (plan.alphabet.len > 4)
        try huffman.HuffmanTable(max_alphabet_size).Encoder.init(&plan.lengths)
    else
        undefined;
    for (plan.tokens[0..plan.token_count]) |token| {
        if (plan.alphabet.len <= 4) {
            const code = plan.alphabet.simpleCode(token.symbol) orelse return error.InvalidBlockPlan;
            try writer.writeHuffmanBits(allocator, code.code, code.bits);
        } else try writer.writeHuffmanBits(allocator, encoder.codes[token.symbol], encoder.bits[token.symbol]);
        if (token.extra_bits != 0) try writer.writeBits(allocator, token.extra, token.extra_bits);
    }
    try writer.writeBits(allocator, @intFromBool(plan.use_mtf), 1);
}

fn writePrefix(allocator: std.mem.Allocator, writer: anytype, alphabet_size: usize, alphabet: anytype, lengths: []const u4) !void {
    if (alphabet.len == 0) return error.InvalidBlockPlan;
    if (alphabet.len > 4) {
        var highest: usize = 0;
        for (alphabet.symbols[0..alphabet.len]) |symbol| highest = @max(highest, symbol);
        return complex_prefix.writeWithStopIndex(allocator, writer, alphabet_size, lengths, highest + 1);
    }
    try writer.writeBits(allocator, 1, 2);
    try writer.writeBits(allocator, alphabet.len - 1, 2);
    for (alphabet.symbols[0..alphabet.len]) |symbol|
        try writer.writeBits(allocator, symbol, alphabetBits(alphabet_size));
    if (alphabet.len == 4) try writer.writeBits(allocator, 0, 1);
}

fn build(
    allocator: std.mem.Allocator,
    context_map: *const [map_len]u8,
    tree_count: usize,
    use_mtf: bool,
    rle_prefix: u3,
) !Plan {
    var symbols = context_map.*;
    if (use_mtf) applyMoveToFront(&symbols, tree_count);

    var tokens: [map_len]Token = undefined;
    var token_count: usize = 0;
    var extra_bits: u64 = 0;
    var index: usize = 0;
    while (index < symbols.len) {
        if (symbols[index] != 0 or rle_prefix == 0) {
            const symbol = if (symbols[index] == 0)
                0
            else
                @as(usize, symbols[index]) + rle_prefix;
            tokens[token_count] = .{ .symbol = @intCast(symbol) };
            token_count += 1;
            index += 1;
            continue;
        }

        var run_len: usize = 1;
        while (index + run_len < symbols.len and symbols[index + run_len] == 0) : (run_len += 1) {}
        var remaining = run_len;
        while (remaining >= 2) {
            const floor: usize = std.math.log2_int(usize, remaining);
            const prefix: usize = @min(@as(usize, rle_prefix), floor);
            const base = @as(usize, 1) << @intCast(prefix);
            const encoded_len = @min(remaining, base * 2 - 1);
            tokens[token_count] = .{
                .symbol = @intCast(prefix),
                .extra = @intCast(encoded_len - base),
                .extra_bits = @intCast(prefix),
            };
            token_count += 1;
            extra_bits += prefix;
            remaining -= encoded_len;
        }
        if (remaining != 0) {
            tokens[token_count] = .{ .symbol = 0 };
            token_count += 1;
        }
        index += run_len;
    }

    var frequencies: [max_alphabet_size]u32 = @splat(0);
    for (tokens[0..token_count]) |token| frequencies[token.symbol] += 1;
    var alphabet: command_plan.PrefixAlphabetFor(max_alphabet_size) = undefined;
    try command_plan.alphabetFromFrequenciesInto(max_alphabet_size, &alphabet, &frequencies);
    const lengths = try alphabet.codeLengths(&frequencies);
    const alphabet_size = tree_count + rle_prefix;
    var bit_cost: u64 = 2 + extra_bits; // RLE flag plus IMTF bit.
    if (rle_prefix != 0) bit_cost += 4;
    if (alphabet.len <= 4) {
        bit_cost += 4 + @as(u64, alphabet.len) * alphabetBits(alphabet_size) + @intFromBool(alphabet.len == 4);
        for (alphabet.symbols[0..alphabet.len]) |symbol| {
            const code = alphabet.simpleCode(symbol) orelse return error.InvalidBlockPlan;
            bit_cost += @as(u64, frequencies[symbol]) * code.bits;
        }
    } else {
        var highest: usize = 0;
        for (alphabet.symbols[0..alphabet.len]) |symbol| highest = @max(highest, symbol);
        bit_cost += try complex_prefix.bitCost(allocator, alphabet_size, &lengths, highest + 1);
        for (frequencies, lengths) |frequency, length|
            bit_cost += @as(u64, frequency) * length;
    }
    return .{
        .use_mtf = use_mtf,
        .rle_prefix = rle_prefix,
        .alphabet_size = alphabet_size,
        .tokens = tokens,
        .token_count = token_count,
        .frequencies = frequencies,
        .alphabet = alphabet,
        .lengths = lengths,
        .bit_cost = bit_cost,
    };
}

fn applyMoveToFront(values: *[map_len]u8, tree_count: usize) void {
    var mtf: [max_tree_count]u8 = undefined;
    for (mtf[0..tree_count], 0..) |*tree, index| tree.* = @intCast(index);
    for (values) |*value| {
        var index: usize = 0;
        while (index < tree_count and mtf[index] != value.*) : (index += 1) {}
        std.debug.assert(index < tree_count);
        const encoded_index = index;
        const tree = value.*;
        while (index > 0) : (index -= 1) mtf[index] = mtf[index - 1];
        mtf[0] = tree;
        value.* = @intCast(encoded_index);
    }
}

fn alphabetBits(alphabet_size: usize) u6 {
    if (alphabet_size <= 1) return 0;
    return @intCast(std.math.log2_int_ceil(usize, alphabet_size));
}

test "context map planner selects MTF zero-run coding for clustered ranges" {
    var context_map: [map_len]u8 = undefined;
    for (&context_map, 0..) |*tree, context| tree.* = @intCast(context / 16);
    const plain = try build(std.testing.allocator, &context_map, 4, false, 0);
    const selected = try choose(std.testing.allocator, &context_map, 4);
    try std.testing.expect(selected.use_mtf);
    try std.testing.expect(selected.rle_prefix != 0);
    try std.testing.expect(selected.bit_cost < plain.bit_cost);
}

test "context map planned bit cost matches emitted wire" {
    const CountingWriter = struct {
        bits: u64 = 0,
        pub fn writeBits(self: *@This(), _: std.mem.Allocator, _: u64, count: u6) !void {
            self.bits += count;
        }
        pub fn writeHuffmanBits(self: *@This(), _: std.mem.Allocator, _: u16, count: u4) !void {
            self.bits += count;
        }
    };
    var context_map: [map_len]u8 = undefined;
    for (&context_map, 0..) |*tree, context| tree.* = @intCast((context / 7) % 9);
    const plan = try choose(std.testing.allocator, &context_map, 9);
    var writer: CountingWriter = .{};
    try write(std.testing.allocator, &writer, &plan);
    try std.testing.expectEqual(plan.bit_cost, writer.bits);
}

test "context map move-to-front indices invert to the original map" {
    var original: [map_len]u8 = undefined;
    for (&original, 0..) |*tree, context| tree.* = @intCast((context / 5) % 9);
    var transformed = original;
    applyMoveToFront(&transformed, 9);
    var mtf: [max_tree_count]u8 = undefined;
    for (mtf[0..9], 0..) |*tree, index| tree.* = @intCast(index);
    for (&transformed) |*entry| {
        const index = entry.*;
        const tree = mtf[index];
        var cursor: usize = index;
        while (cursor > 0) : (cursor -= 1) mtf[cursor] = mtf[cursor - 1];
        mtf[0] = tree;
        entry.* = tree;
    }
    try std.testing.expectEqualSlices(u8, &original, &transformed);
}
