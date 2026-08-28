const std = @import("std");
const huffman = @import("../../huffman.zig");
const code_length_rle = @import("code_length_rle.zig");
const small_huffman = @import("small_huffman.zig");

const code_length_order = [_]u5{ 1, 2, 3, 4, 0, 5, 17, 6, 16, 7, 8, 9, 10, 11, 12, 13, 14, 15 };

/// Encode a Brotli complex prefix tree. Zero gaps use chained symbol-17 runs;
/// non-zero code lengths remain explicit for deterministic production output.
pub fn write(allocator: std.mem.Allocator, writer: anytype, alphabet_size: usize, lengths: []const u4) !void {
    if (lengths.len < alphabet_size) return error.InvalidBlockPlan;
    const stop_index = try code_length_rle.validatedStopIndex(lengths[0..alphabet_size]);
    return writeWithStopIndex(allocator, writer, alphabet_size, lengths, stop_index);
}

/// Encode a tree whose highest non-zero symbol is already known by the
/// caller. PrefixAlphabet maintains exactly that sparse symbol set, so its
/// wire path can avoid rescanning the complete dense code-length array.
pub fn writeWithStopIndex(allocator: std.mem.Allocator, writer: anytype, alphabet_size: usize, lengths: []const u4, stop_index: usize) !void {
    if (lengths.len < alphabet_size or stop_index == 0 or stop_index > alphabet_size or lengths[stop_index - 1] == 0) return error.InvalidBlockPlan;
    try writer.writeBits(allocator, 0, 2); // HSKIP=0, complex prefix.

    return if (alphabet_size <= 256)
        writeWithStorage(256, allocator, writer, lengths, stop_index)
    else if (alphabet_size <= 520)
        writeWithStorage(520, allocator, writer, lengths, stop_index)
    else
        writeWithStorage(704, allocator, writer, lengths, stop_index);
}

fn writeWithStorage(comptime storage_len: usize, allocator: std.mem.Allocator, writer: anytype, lengths: []const u4, stop_index: usize) !void {
    var rle_storage: [storage_len]code_length_rle.Token = undefined;
    var code_length_freqs: [18]u32 = undefined;
    const rle_len = try code_length_rle.encodeIntoWithFrequencies(&rle_storage, lengths, stop_index, &code_length_freqs);
    const rle = rle_storage[0..rle_len];

    const code_length_lengths = codeLengthCodeLengths(&code_length_freqs);

    var space: i32 = 32;
    for (code_length_order) |symbol| {
        const length = code_length_lengths[symbol];
        try writeCodeLengthCodeLength(allocator, writer, length);
        if (length != 0) {
            space -= @intCast(@as(u32, 32) >> length);
            if (space < 0) return error.InvalidHuffmanCode;
            if (space == 0) break;
        }
    }
    if (space != 0) return error.InvalidHuffmanCode;

    const encoder = try huffman.HuffmanTable(18).Encoder.init(&code_length_lengths);
    for (rle) |token| {
        try writer.writeBits(allocator, encoder.codes[token.symbol], encoder.bits[token.symbol]);
        if (token.symbol == 17) try writer.writeBits(allocator, token.extra, 3);
        if (token.symbol == 16) try writer.writeBits(allocator, token.extra, 2);
    }
}

/// The code-length alphabet has at most 18 live symbols. Its common trees fit
/// Brotli's five-bit limit without length limiting, so reuse the linear small
/// Huffman builder and reserve package merge for the rare over-depth shape.
fn codeLengthCodeLengths(frequencies: *const [18]u32) [18]u4 {
    var symbols: [18]u16 = undefined;
    var compact_frequencies: [18]u32 = undefined;
    var active: usize = 0;
    for (frequencies, 0..) |frequency, symbol| {
        if (frequency == 0) continue;
        var index = active;
        while (index != 0 and frequency > compact_frequencies[index - 1]) : (index -= 1) {
            compact_frequencies[index] = compact_frequencies[index - 1];
            symbols[index] = symbols[index - 1];
        }
        compact_frequencies[index] = frequency;
        symbols[index] = @intCast(symbol);
        active += 1;
    }
    if (active == 0) return @splat(0);

    var compact_lengths: [18]u4 = undefined;
    if (small_huffman.build(18, compact_frequencies[0..active], &compact_lengths)) {
        for (compact_lengths[0..active]) |length| if (length > 5)
            return huffman.treeCodeLengths(18, frequencies, 5);
        var lengths: [18]u4 = @splat(0);
        for (symbols[0..active], compact_lengths[0..active]) |symbol, length| lengths[symbol] = length;
        return lengths;
    }
    return huffman.treeCodeLengths(18, frequencies, 5);
}

fn writeCodeLengthCodeLength(allocator: std.mem.Allocator, writer: anytype, length: u4) !void {
    switch (length) {
        0 => try writer.writeBits(allocator, 0b00, 2),
        1 => try writer.writeBits(allocator, 0b0111, 4),
        2 => try writer.writeBits(allocator, 0b011, 3),
        3 => try writer.writeBits(allocator, 0b10, 2),
        4 => try writer.writeBits(allocator, 0b01, 2),
        5 => try writer.writeBits(allocator, 0b1111, 4),
        else => return error.InvalidBlockPlan,
    }
}

test "precomputed complex prefix stop index is validated" {
    const TestWriter = struct {
        fn writeBits(_: *@This(), _: std.mem.Allocator, _: u64, _: u6) !void {}
    };
    var writer = TestWriter{};
    var lengths: [8]u4 = @splat(0);
    lengths[0] = 1;
    try std.testing.expectError(error.InvalidBlockPlan, writeWithStopIndex(std.testing.allocator, &writer, lengths.len, &lengths, 0));
    try std.testing.expectError(error.InvalidBlockPlan, writeWithStopIndex(std.testing.allocator, &writer, lengths.len, &lengths, lengths.len + 1));
    try std.testing.expectError(error.InvalidBlockPlan, writeWithStopIndex(std.testing.allocator, &writer, lengths.len, &lengths, 2));
}

test "small code-length alphabet matches package-merge weighted cost" {
    var state: u32 = 0x4f1b_2c3d;
    for (0..1024) |_| {
        var frequencies: [18]u32 = @splat(0);
        for (&frequencies) |*frequency| {
            state = state *% 1_664_525 +% 1_013_904_223;
            frequency.* = if (state & 3 == 0) 0 else 1 + (state >> 24);
        }
        const actual = codeLengthCodeLengths(&frequencies);
        const reference = huffman.treeCodeLengths(18, &frequencies, 5);
        var actual_cost: u64 = 0;
        var reference_cost: u64 = 0;
        var actual_declaration_bits: usize = 0;
        var reference_declaration_bits: usize = 0;
        var actual_space: usize = 32;
        var reference_space: usize = 32;
        for (frequencies, actual, reference) |frequency, actual_length, reference_length| {
            try std.testing.expect(actual_length <= 5);
            actual_cost += @as(u64, frequency) * actual_length;
            reference_cost += @as(u64, frequency) * reference_length;
        }
        for (code_length_order) |symbol| {
            const actual_length = actual[symbol];
            actual_declaration_bits += codeLengthCodeLengthBits(actual_length);
            if (actual_length != 0) {
                actual_space -= @as(usize, 32) >> actual_length;
                if (actual_space == 0) break;
            }
        }
        for (code_length_order) |symbol| {
            const length = reference[symbol];
            reference_declaration_bits += codeLengthCodeLengthBits(length);
            if (length != 0) {
                reference_space -= @as(usize, 32) >> length;
                if (reference_space == 0) break;
            }
        }
        try std.testing.expectEqual(reference_cost, actual_cost);
        try std.testing.expectEqual(@as(usize, 0), actual_space);
        try std.testing.expectEqual(@as(usize, 0), reference_space);
        try std.testing.expect(actual_declaration_bits <= reference_declaration_bits);
    }
}

fn codeLengthCodeLengthBits(length: u4) usize {
    return switch (length) {
        0, 3, 4 => 2,
        2 => 3,
        1, 5 => 4,
        else => unreachable,
    };
}
