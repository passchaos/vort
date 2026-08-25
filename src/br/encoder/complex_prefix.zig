const std = @import("std");
const huffman = @import("../../huffman.zig");
const code_length_rle = @import("code_length_rle.zig");

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
    const rle_len = try code_length_rle.encodeInto(&rle_storage, lengths, stop_index);
    const rle = rle_storage[0..rle_len];

    var code_length_freqs: [18]u32 = @splat(0);
    for (rle) |token| code_length_freqs[token.symbol] += 1;
    const code_length_lengths = huffman.treeCodeLengths(18, &code_length_freqs, 5);

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
