const std = @import("std");
const huffman = @import("../../huffman.zig");
const command_plan = @import("command_plan.zig");
const complex_prefix = @import("complex_prefix.zig");

pub const max_tree_count: usize = 256;

/// A Brotli context map where each block type maps all of its contexts to the
/// tree with the same numeric ID. Distance splitting uses four contexts per
/// block type, so this compact plan avoids materializing a 1024-entry map while
/// still covering the complete RFC block/tree count range.
pub const Plan = struct {
    tree_count: usize,
    contexts_per_type: usize,
    alphabet: command_plan.PrefixAlphabetFor(max_tree_count),
    lengths: [max_tree_count]u4,
    encoder: huffman.HuffmanTable(max_tree_count).Encoder,
    bit_cost: u64,

    pub fn init(allocator: std.mem.Allocator, tree_count: usize, contexts_per_type: usize) !Plan {
        if (tree_count < 2 or tree_count > max_tree_count or contexts_per_type == 0)
            return error.InvalidBlockPlan;
        var frequencies: [max_tree_count]u32 = @splat(0);
        const frequency: u32 = std.math.cast(u32, contexts_per_type) orelse return error.IntegerOverflow;
        @memset(frequencies[0..tree_count], frequency);
        var alphabet: command_plan.PrefixAlphabetFor(max_tree_count) = undefined;
        try command_plan.alphabetFromFrequenciesInto(max_tree_count, &alphabet, &frequencies);
        const lengths = if (alphabet.len <= 4)
            @as([max_tree_count]u4, @splat(0))
        else
            try alphabet.codeLengths(&frequencies);
        const encoder = if (alphabet.len <= 4)
            huffman.HuffmanTable(max_tree_count).Encoder{}
        else if (alphabet.len <= 64)
            try huffman.HuffmanTable(max_tree_count).Encoder.initSparseTrusted(
                &lengths,
                alphabet.symbols[0..alphabet.len],
            )
        else
            try huffman.HuffmanTable(max_tree_count).Encoder.init(&lengths);

        var bit_cost: u64 = 2; // RLEMAX=0 plus IMTF=false.
        if (alphabet.len <= 4) {
            bit_cost += 4 + @as(u64, alphabet.len) * alphabetBits(tree_count) + @intFromBool(alphabet.len == 4);
            for (0..tree_count) |tree| {
                const code = alphabet.simpleCode(@intCast(tree)) orelse return error.InvalidBlockPlan;
                bit_cost += @as(u64, contexts_per_type) * code.bits;
            }
        } else {
            bit_cost += try complex_prefix.bitCost(allocator, tree_count, &lengths, tree_count);
            for (lengths[0..tree_count]) |length|
                bit_cost += @as(u64, contexts_per_type) * length;
        }
        return .{
            .tree_count = tree_count,
            .contexts_per_type = contexts_per_type,
            .alphabet = alphabet,
            .lengths = lengths,
            .encoder = encoder,
            .bit_cost = bit_cost,
        };
    }

    pub fn write(self: *const Plan, allocator: std.mem.Allocator, writer: anytype) !void {
        try writer.writeBits(allocator, 0, 1); // RLEMAX = 0.
        try writePrefix(allocator, writer, self.tree_count, &self.alphabet, &self.lengths);
        for (0..self.tree_count) |tree| {
            for (0..self.contexts_per_type) |_| {
                if (self.alphabet.len <= 4) {
                    const code = self.alphabet.simpleCode(@intCast(tree)) orelse return error.InvalidBlockPlan;
                    try writer.writeHuffmanBits(allocator, code.code, code.bits);
                } else try writer.writeHuffmanBits(
                    allocator,
                    self.encoder.codes[tree],
                    self.encoder.bits[tree],
                );
            }
        }
        try writer.writeBits(allocator, 0, 1); // IMTF = false.
    }
};

fn writePrefix(
    allocator: std.mem.Allocator,
    writer: anytype,
    alphabet_size: usize,
    alphabet: *const command_plan.PrefixAlphabetFor(max_tree_count),
    lengths: *const [max_tree_count]u4,
) !void {
    if (alphabet.len == 0) return error.InvalidBlockPlan;
    if (alphabet.len > 4)
        return complex_prefix.writeWithStopIndex(allocator, writer, alphabet_size, lengths, alphabet_size);
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

test "identity context map bit cost matches emitted wire" {
    const CountingWriter = struct {
        bits: u64 = 0,

        pub fn writeBits(self: *@This(), _: std.mem.Allocator, _: anytype, count: anytype) !void {
            self.bits += count;
        }

        pub fn writeHuffmanBits(self: *@This(), _: std.mem.Allocator, _: u16, count: u4) !void {
            self.bits += count;
        }
    };

    inline for (.{ 2, 3, 4, 5, 8, 17, 50, 256 }) |tree_count| {
        const plan = try Plan.init(std.testing.allocator, tree_count, 4);
        var writer: CountingWriter = .{};
        try plan.write(std.testing.allocator, &writer);
        try std.testing.expectEqual(plan.bit_cost, writer.bits);
    }
}

test "identity context map validates dimensions" {
    try std.testing.expectError(error.InvalidBlockPlan, Plan.init(std.testing.allocator, 1, 4));
    try std.testing.expectError(error.InvalidBlockPlan, Plan.init(std.testing.allocator, 257, 4));
    try std.testing.expectError(error.InvalidBlockPlan, Plan.init(std.testing.allocator, 2, 0));
}
