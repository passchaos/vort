const std = @import("std");
const huffman = @import("../../huffman.zig");
const code_length_rle = @import("code_length_rle.zig");

const code_length_order = [_]u5{ 1, 2, 3, 4, 0, 5, 17, 6, 16, 7, 8, 9, 10, 11, 12, 13, 14, 15 };

/// Encode a Brotli complex prefix tree. Zero gaps use chained symbol-17 runs;
/// non-zero code lengths remain explicit for deterministic production output.
pub fn write(allocator: std.mem.Allocator, writer: anytype, alphabet_size: usize, lengths: []const u4) !void {
    if (lengths.len < alphabet_size) return error.InvalidBlockPlan;
    try writer.writeBits(allocator, 0, 2); // HSKIP=0, complex prefix.

    for (lengths[0..alphabet_size]) |length| {
        if (length > 15) return error.InvalidBlockPlan;
    }
    var stop_index = alphabet_size;
    while (stop_index != 0 and lengths[stop_index - 1] == 0) stop_index -= 1;
    const rle = try code_length_rle.encodeAlloc(allocator, lengths, stop_index);
    defer allocator.free(rle);

    // The RLE stream currently uses symbols 0...5 and 17. A fixed complete
    // code-length tree avoids recursively optimizing this tiny alphabet while
    // still making long zero gaps compact.
    var code_length_lengths: [18]u4 = @splat(0);
    code_length_lengths[0] = 3;
    code_length_lengths[1] = 3;
    code_length_lengths[2] = 3;
    code_length_lengths[3] = 3;
    code_length_lengths[4] = 3;
    code_length_lengths[5] = 3;
    code_length_lengths[17] = 2;

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
    }
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
