const std = @import("std");
const huffman = @import("../../huffman.zig");
const command_plan = @import("command_plan.zig");
const complex_prefix = @import("complex_prefix.zig");

pub const min_map_len: usize = 1;
pub const max_map_len: usize = 16 * 1024;
pub const min_tree_count: usize = 2;
pub const max_tree_count: usize = 256;

/// This bounded search matches the established context-map planner. Brotli's
/// wire field can describe larger prefixes, but prefix six already represents
/// zero runs through 127 entries per token; longer runs remain representable
/// by chaining tokens without expanding the search space.
pub const max_rle_prefix: usize = 6;
pub const max_alphabet_size: usize = max_tree_count + max_rle_prefix;

pub const Token = struct {
    symbol: u16,
    extra: u8 = 0,
    extra_bits: u3 = 0,
};

/// Allocator-owned encoding plan for a variable-length Brotli context map.
/// Only `tokens` is heap-owned; the bounded prefix-code model stays inline.
pub const Plan = struct {
    use_mtf: bool,
    rle_prefix: u3,
    tree_count: u16,
    map_len: usize,
    alphabet_size: usize,
    tokens: []Token,
    frequencies: [max_alphabet_size]u32,
    alphabet: command_plan.PrefixAlphabetFor(max_alphabet_size),
    lengths: [max_alphabet_size]u4,
    bit_cost: u64,

    pub fn deinit(self: Plan, allocator: std.mem.Allocator) void {
        allocator.free(self.tokens);
    }

    pub fn write(self: *const Plan, allocator: std.mem.Allocator, writer: anytype) !void {
        return writePlan(allocator, writer, self);
    }
};

const Candidate = struct {
    use_mtf: bool,
    rle_prefix: u3,
    alphabet_size: usize,
    token_count: usize,
    frequencies: [max_alphabet_size]u32,
    alphabet: command_plan.PrefixAlphabetFor(max_alphabet_size),
    lengths: [max_alphabet_size]u4,
    bit_cost: u64,
};

pub fn choose(
    allocator: std.mem.Allocator,
    context_map: []const u8,
    tree_count: usize,
) !Plan {
    try validateInput(context_map, tree_count);

    const mtf_symbols = try allocator.dupe(u8, context_map);
    defer allocator.free(mtf_symbols);
    applyMoveToFront(mtf_symbols, tree_count);

    const token_scratch = try allocator.alloc(Token, context_map.len);
    defer allocator.free(token_scratch);

    var best = try scoreCandidate(
        allocator,
        context_map,
        tree_count,
        false,
        0,
        token_scratch,
    );
    for ([_]bool{ false, true }) |use_mtf| {
        const symbols = if (use_mtf) mtf_symbols else context_map;
        for (0..max_rle_prefix + 1) |rle_prefix| {
            if (!use_mtf and rle_prefix == 0) continue;
            const candidate = try scoreCandidate(
                allocator,
                symbols,
                tree_count,
                use_mtf,
                @intCast(rle_prefix),
                token_scratch,
            );
            if (candidate.bit_cost < best.bit_cost) best = candidate;
        }
    }

    const best_symbols = if (best.use_mtf) mtf_symbols else context_map;
    const encoded = tokenize(best_symbols, best.rle_prefix, token_scratch);
    std.debug.assert(encoded.token_count == best.token_count);
    const owned_tokens = try allocator.dupe(Token, token_scratch[0..encoded.token_count]);

    return .{
        .use_mtf = best.use_mtf,
        .rle_prefix = best.rle_prefix,
        .tree_count = @intCast(tree_count),
        .map_len = context_map.len,
        .alphabet_size = best.alphabet_size,
        .tokens = owned_tokens,
        .frequencies = best.frequencies,
        .alphabet = best.alphabet,
        .lengths = best.lengths,
        .bit_cost = best.bit_cost,
    };
}

pub fn write(allocator: std.mem.Allocator, writer: anytype, plan: *const Plan) !void {
    return writePlan(allocator, writer, plan);
}

fn writePlan(allocator: std.mem.Allocator, writer: anytype, plan: *const Plan) !void {
    try validatePlanShape(plan);
    try writer.writeBits(allocator, @intFromBool(plan.rle_prefix != 0), 1);
    if (plan.rle_prefix != 0)
        try writer.writeBits(allocator, plan.rle_prefix - 1, 4);
    try writePrefix(
        allocator,
        writer,
        plan.alphabet_size,
        &plan.alphabet,
        &plan.lengths,
    );

    const encoder = if (plan.alphabet.len > 4)
        try huffman.HuffmanTable(max_alphabet_size).Encoder.init(&plan.lengths)
    else
        undefined;
    for (plan.tokens) |token| {
        if (plan.alphabet.len <= 4) {
            const code = plan.alphabet.simpleCode(token.symbol) orelse
                return error.InvalidBlockPlan;
            try writer.writeHuffmanBits(allocator, code.code, code.bits);
        } else try writer.writeHuffmanBits(
            allocator,
            encoder.codes[token.symbol],
            encoder.bits[token.symbol],
        );
        if (token.extra_bits != 0)
            try writer.writeBits(allocator, token.extra, token.extra_bits);
    }
    try writer.writeBits(allocator, @intFromBool(plan.use_mtf), 1);
}

fn validateInput(context_map: []const u8, tree_count: usize) !void {
    if (context_map.len < min_map_len or context_map.len > max_map_len or
        tree_count < min_tree_count or tree_count > max_tree_count)
    {
        return error.InvalidBlockPlan;
    }

    var used: [max_tree_count]bool = @splat(false);
    for (context_map) |tree| {
        if (@as(usize, tree) >= tree_count) return error.InvalidBlockPlan;
        used[tree] = true;
    }
    for (used[0..tree_count]) |is_used|
        if (!is_used) return error.InvalidBlockPlan;
}

fn validatePlanShape(plan: *const Plan) !void {
    if (plan.map_len < min_map_len or plan.map_len > max_map_len or
        plan.tree_count < min_tree_count or plan.tree_count > max_tree_count or
        plan.rle_prefix > max_rle_prefix or
        plan.alphabet_size != @as(usize, plan.tree_count) + plan.rle_prefix or
        plan.tokens.len == 0 or plan.tokens.len > plan.map_len or
        plan.alphabet.len == 0)
    {
        return error.InvalidBlockPlan;
    }

    var decoded_len: usize = 0;
    for (plan.tokens) |token| {
        if (token.symbol >= plan.alphabet_size) return error.InvalidBlockPlan;
        const token_len: usize = if (token.extra_bits == 0) blk: {
            if (token.extra != 0) return error.InvalidBlockPlan;
            break :blk 1;
        } else blk: {
            if (token.symbol == 0 or token.symbol > plan.rle_prefix or
                token.extra_bits != @as(u3, @intCast(token.symbol)) or
                token.extra >= (@as(u8, 1) << token.extra_bits))
            {
                return error.InvalidBlockPlan;
            }
            break :blk (@as(usize, 1) << token.extra_bits) + token.extra;
        };
        decoded_len = std.math.add(usize, decoded_len, token_len) catch
            return error.IntegerOverflow;
    }
    if (decoded_len != plan.map_len) return error.InvalidBlockPlan;
}

fn scoreCandidate(
    allocator: std.mem.Allocator,
    symbols: []const u8,
    tree_count: usize,
    use_mtf: bool,
    rle_prefix: u3,
    token_scratch: []Token,
) !Candidate {
    const encoded = tokenize(symbols, rle_prefix, token_scratch);
    var frequencies: [max_alphabet_size]u32 = @splat(0);
    for (token_scratch[0..encoded.token_count]) |token|
        frequencies[token.symbol] += 1;

    var alphabet: command_plan.PrefixAlphabetFor(max_alphabet_size) = undefined;
    try command_plan.alphabetFromFrequenciesInto(
        max_alphabet_size,
        &alphabet,
        &frequencies,
    );
    const lengths = try alphabet.codeLengths(&frequencies);
    const alphabet_size = tree_count + rle_prefix;
    var bit_cost: u64 = 2 + encoded.extra_bits; // RLE flag plus IMTF bit.
    if (rle_prefix != 0) bit_cost += 4;
    if (alphabet.len <= 4) {
        bit_cost += 4 + @as(u64, alphabet.len) * alphabetBits(alphabet_size) +
            @intFromBool(alphabet.len == 4);
        for (alphabet.symbols[0..alphabet.len]) |symbol| {
            const code = alphabet.simpleCode(symbol) orelse
                return error.InvalidBlockPlan;
            bit_cost += @as(u64, frequencies[symbol]) * code.bits;
        }
    } else {
        var highest: usize = 0;
        for (alphabet.symbols[0..alphabet.len]) |symbol|
            highest = @max(highest, symbol);
        bit_cost += try complex_prefix.bitCost(
            allocator,
            alphabet_size,
            &lengths,
            highest + 1,
        );
        for (frequencies, lengths) |frequency, length|
            bit_cost += @as(u64, frequency) * length;
    }

    return .{
        .use_mtf = use_mtf,
        .rle_prefix = rle_prefix,
        .alphabet_size = alphabet_size,
        .token_count = encoded.token_count,
        .frequencies = frequencies,
        .alphabet = alphabet,
        .lengths = lengths,
        .bit_cost = bit_cost,
    };
}

const Tokenized = struct {
    token_count: usize,
    extra_bits: u64,
};

fn tokenize(symbols: []const u8, rle_prefix: u3, output: []Token) Tokenized {
    std.debug.assert(rle_prefix <= max_rle_prefix);
    std.debug.assert(output.len >= symbols.len);
    var token_count: usize = 0;
    var extra_bits: u64 = 0;
    var index: usize = 0;
    while (index < symbols.len) {
        if (symbols[index] != 0 or rle_prefix == 0) {
            output[token_count] = .{
                .symbol = if (symbols[index] == 0)
                    0
                else
                    @as(u16, symbols[index]) + rle_prefix,
            };
            token_count += 1;
            index += 1;
            continue;
        }

        var run_len: usize = 1;
        while (index + run_len < symbols.len and symbols[index + run_len] == 0) : (run_len += 1) {}
        var remaining = run_len;
        while (remaining >= 2) {
            const floor = std.math.log2_int(usize, remaining);
            const prefix: u3 = @intCast(@min(@as(usize, rle_prefix), floor));
            const base = @as(usize, 1) << prefix;
            const encoded_len = @min(remaining, base * 2 - 1);
            output[token_count] = .{
                .symbol = prefix,
                .extra = @intCast(encoded_len - base),
                .extra_bits = prefix,
            };
            token_count += 1;
            extra_bits += prefix;
            remaining -= encoded_len;
        }
        if (remaining != 0) {
            output[token_count] = .{ .symbol = 0 };
            token_count += 1;
        }
        index += run_len;
    }
    return .{ .token_count = token_count, .extra_bits = extra_bits };
}

fn applyMoveToFront(values: []u8, tree_count: usize) void {
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

fn writePrefix(
    allocator: std.mem.Allocator,
    writer: anytype,
    alphabet_size: usize,
    alphabet: *const command_plan.PrefixAlphabetFor(max_alphabet_size),
    lengths: *const [max_alphabet_size]u4,
) !void {
    if (alphabet.len == 0) return error.InvalidBlockPlan;
    if (alphabet.len > 4) {
        var highest: usize = 0;
        for (alphabet.symbols[0..alphabet.len]) |symbol|
            highest = @max(highest, symbol);
        return complex_prefix.writeWithStopIndex(
            allocator,
            writer,
            alphabet_size,
            lengths,
            highest + 1,
        );
    }
    try writer.writeBits(allocator, 1, 2);
    try writer.writeBits(allocator, alphabet.len - 1, 2);
    for (alphabet.symbols[0..alphabet.len]) |symbol|
        try writer.writeBits(allocator, symbol, alphabetBits(alphabet_size));
    if (alphabet.len == 4) try writer.writeBits(allocator, 0, 1);
}

fn alphabetBits(alphabet_size: usize) u6 {
    if (alphabet_size <= 1) return 0;
    return @intCast(std.math.log2_int_ceil(usize, alphabet_size));
}

const CountingWriter = struct {
    bits: u64 = 0,

    pub fn writeBits(self: *@This(), _: std.mem.Allocator, _: anytype, count: anytype) !void {
        self.bits += count;
    }

    pub fn writeHuffmanBits(self: *@This(), _: std.mem.Allocator, _: u16, count: u4) !void {
        self.bits += count;
    }
};

test "dynamic context map bit cost matches emitted bits" {
    var context_map: [511]u8 = undefined;
    for (&context_map, 0..) |*tree, index|
        tree.* = if (index < 17)
            @intCast(index)
        else
            @intCast((index * 37 + index / 11) % 17);
    const plan = try choose(std.testing.allocator, &context_map, 17);
    defer plan.deinit(std.testing.allocator);

    var writer: CountingWriter = .{};
    try plan.write(std.testing.allocator, &writer);
    try std.testing.expectEqual(plan.bit_cost, writer.bits);
}

test "dynamic context map supports 256 trees and 16384 identity entries" {
    var context_map: [max_map_len]u8 = undefined;
    for (&context_map, 0..) |*tree, index|
        tree.* = @intCast(index / 64);

    const plan = try choose(std.testing.allocator, &context_map, max_tree_count);
    defer plan.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(u16, max_tree_count), plan.tree_count);
    try std.testing.expectEqual(@as(usize, max_map_len), plan.map_len);
    try std.testing.expect(plan.alphabet_size <= max_alphabet_size);

    var writer: CountingWriter = .{};
    try write(std.testing.allocator, &writer, &plan);
    try std.testing.expectEqual(plan.bit_cost, writer.bits);
}

test "dynamic context map selects MTF zero-run coding for clustered ranges" {
    var context_map: [512]u8 = undefined;
    for (&context_map, 0..) |*tree, index| tree.* = @intCast(index / 64);
    const plan = try choose(std.testing.allocator, &context_map, 8);
    defer plan.deinit(std.testing.allocator);

    try std.testing.expect(plan.use_mtf);
    try std.testing.expect(plan.rle_prefix != 0);
    var writer: CountingWriter = .{};
    try plan.write(std.testing.allocator, &writer);
    try std.testing.expectEqual(plan.bit_cost, writer.bits);
}

test "dynamic context map retains plain coding when MTF does not improve it" {
    var context_map: [128]u8 = undefined;
    for (&context_map, 0..) |*tree, index| tree.* = @intCast(index & 1);
    const plan = try choose(std.testing.allocator, &context_map, 2);
    defer plan.deinit(std.testing.allocator);

    try std.testing.expect(!plan.use_mtf);
    try std.testing.expectEqual(@as(u3, 0), plan.rle_prefix);
}

test "dynamic context map rejects invalid dimensions entries and unused trees" {
    try std.testing.expectError(
        error.InvalidBlockPlan,
        choose(std.testing.allocator, &.{}, 2),
    );

    const too_large = [_]u8{0} ** (max_map_len + 1);
    try std.testing.expectError(
        error.InvalidBlockPlan,
        choose(std.testing.allocator, &too_large, 2),
    );
    try std.testing.expectError(
        error.InvalidBlockPlan,
        choose(std.testing.allocator, &.{ 0, 1 }, 1),
    );
    try std.testing.expectError(
        error.InvalidBlockPlan,
        choose(std.testing.allocator, &.{ 0, 1 }, max_tree_count + 1),
    );
    try std.testing.expectError(
        error.InvalidBlockPlan,
        choose(std.testing.allocator, &.{ 0, 2, 1 }, 2),
    );
    try std.testing.expectError(
        error.InvalidBlockPlan,
        choose(std.testing.allocator, &.{ 0, 2 }, 3),
    );
    try std.testing.expectError(
        error.InvalidBlockPlan,
        choose(std.testing.allocator, &.{0}, 2),
    );
}

test "dynamic context map unwinds every allocation failure" {
    var context_map: [512]u8 = undefined;
    for (&context_map, 0..) |*tree, index| tree.* = @intCast(index / 64);

    var failure_count: usize = 0;
    var reached_success = false;
    for (0..16) |fail_index| {
        var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{
            .fail_index = fail_index,
        });
        const plan = choose(failing.allocator(), &context_map, 8) catch |err| {
            try std.testing.expect(err == error.OutOfMemory);
            try std.testing.expect(failing.has_induced_failure);
            try std.testing.expectEqual(failing.allocated_bytes, failing.freed_bytes);
            failure_count += 1;
            continue;
        };
        plan.deinit(failing.allocator());
        try std.testing.expect(!failing.has_induced_failure);
        try std.testing.expectEqual(failing.allocated_bytes, failing.freed_bytes);
        reached_success = true;
        break;
    }
    try std.testing.expect(reached_success);
    try std.testing.expectEqual(@as(usize, 3), failure_count);
}
