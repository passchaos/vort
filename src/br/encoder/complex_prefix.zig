const std = @import("std");
const huffman = @import("../../huffman.zig");

const code_length_order = [_]u5{ 1, 2, 3, 4, 0, 5, 17, 6, 16, 7, 8, 9, 10, 11, 12, 13, 14, 15 };

/// Encode a Brotli complex prefix tree without repeat symbols. The resulting
/// code-length alphabet is tiny (only the lengths present in `lengths` plus
/// zero) and remains valid for the initial 5...8-symbol production slice.
pub fn write(allocator: std.mem.Allocator, writer: anytype, alphabet_size: usize, lengths: []const u4) !void {
    if (lengths.len < alphabet_size) return error.InvalidBlockPlan;
    try writer.writeBits(allocator, 0, 2); // HSKIP=0, complex prefix.

    for (lengths[0..alphabet_size]) |length| {
        if (length > 15) return error.InvalidBlockPlan;
    }
    // A fixed complete code-length tree is larger than an optimized one but
    // keeps this first general writer simple: 14 length-4 and four length-5
    // codes exactly fill the five-bit code space.
    var code_length_lengths: [18]u4 = @splat(0);
    code_length_lengths[0] = 2;
    code_length_lengths[1] = 2;
    code_length_lengths[2] = 2;
    code_length_lengths[3] = 3;
    code_length_lengths[4] = 4;
    code_length_lengths[5] = 4;

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
    // Stop once the main Huffman tree is complete; trailing zero lengths are
    // implicit in Brotli complex prefix encoding.
    var tree_space: i32 = 32768;
    for (lengths[0..alphabet_size]) |length| {
        try writer.writeBits(allocator, encoder.codes[length], encoder.bits[length]);
        if (length != 0) {
            tree_space -= @intCast(@as(u32, 32768) >> length);
            if (tree_space < 0) return error.InvalidHuffmanCode;
            if (tree_space == 0) break;
        }
    }
    if (tree_space != 0) return error.InvalidHuffmanCode;
}

fn writeCodeLengthCodeLength(allocator: std.mem.Allocator, writer: anytype, length: u4) !void {
    switch (length) {
        0 => try writer.writeBits(allocator, 0b00, 2),
        1 => try writer.writeBits(allocator, 0b1110, 4),
        2 => try writer.writeBits(allocator, 0b011, 3),
        3 => try writer.writeBits(allocator, 0b10, 2),
        4 => try writer.writeBits(allocator, 0b01, 2),
        5 => try writer.writeBits(allocator, 0b1111, 4),
        else => return error.InvalidBlockPlan,
    }
}
