const std = @import("std");
const bitstream = @import("../../../bitstream.zig");
const huffman = @import("../../../huffman.zig");

// Independently specified RFC 1951 length fields, including every extra-bit
// width and the longest code. Expected output is built directly from runs.
const runs = [_]struct { symbol: u16, length: usize, extra_bits: u6, extra: u5 }{
    .{ .symbol = 257, .length = 3, .extra_bits = 0, .extra = 0 },
    .{ .symbol = 264, .length = 10, .extra_bits = 0, .extra = 0 },
    .{ .symbol = 265, .length = 12, .extra_bits = 1, .extra = 1 },
    .{ .symbol = 269, .length = 21, .extra_bits = 2, .extra = 2 },
    .{ .symbol = 273, .length = 40, .extra_bits = 3, .extra = 5 },
    .{ .symbol = 277, .length = 80, .extra_bits = 4, .extra = 13 },
    .{ .symbol = 281, .length = 160, .extra_bits = 5, .extra = 29 },
    .{ .symbol = 282, .length = 190, .extra_bits = 5, .extra = 27 },
    .{ .symbol = 283, .length = 224, .extra_bits = 5, .extra = 29 },
    .{ .symbol = 284, .length = 257, .extra_bits = 5, .extra = 30 },
    .{ .symbol = 285, .length = 258, .extra_bits = 0, .extra = 0 },
};
const rounds = 8;
const body_len = rounds * blk: {
    var length: usize = 4;
    for (runs) |run| length += run.length;
    break :blk length;
};

pub fn check(comptime Api: type) !void {
    const allocator = std.testing.allocator;
    var lengths: [286]u4 = @splat(0);
    const symbols = [_]usize{ 0, 'A', 'B', 'C', 256, 257, 264, 265, 269, 273, 277, 281, 282, 283, 284, 285 };
    for (symbols, 0..) |symbol, i| lengths[symbol] = @intCast(@min(i + 1, 15));
    const literals = try huffman.HuffmanTable(286).init(&lengths);
    const encoder = try huffman.HuffmanTable(286).Encoder.init(&lengths);
    const distances = try huffman.HuffmanTable(30).init(&.{1});
    var reference: Api.Reference = undefined;
    var active: Api.Active = undefined;
    try std.testing.expect(Api.initReference(&reference, &literals, &distances));
    try std.testing.expect(Api.initActive(&active, &literals, &distances));
    const expected = try allocator.alloc(u8, body_len);
    defer allocator.free(expected);
    var position: usize = 0;
    for (0..rounds) |_| {
        @memcpy(expected[position..][0..4], &[_]u8{ 0, 'A', 'B', 'C' });
        position += 4;
        for (runs) |run| {
            @memset(expected[position..][0..run.length], 'C');
            position += run.length;
        }
    }
    try std.testing.expectEqual(body_len, position);
    const reference_output = try allocator.alloc(u8, body_len + 64);
    defer allocator.free(reference_output);
    const active_output = try allocator.alloc(u8, body_len + 64);
    defer allocator.free(active_output);

    for (0..8) |alignment| {
        var writer = bitstream.BitWriter{};
        defer writer.deinit(allocator);
        try writer.writeBits(allocator, 0, @intCast(alignment));
        var invalid_bit: usize = 0;
        for (0..rounds) |round| {
            for ([_]u8{ 0, 'A', 'B', 'C' }) |literal| try encoder.writeSymbol(&writer, allocator, literal);
            for (runs) |run| {
                try encoder.writeSymbol(&writer, allocator, run.symbol);
                try writer.writeBits(allocator, run.extra, run.extra_bits);
                if (round == 3 and run.symbol == 281) invalid_bit = writer.bytes.items.len * 8 + writer.bit_index;
                try writer.writeBits(allocator, 0, 1);
            }
        }
        try encoder.writeSymbol(&writer, allocator, 256);
        const logical_bits = writer.bytes.items.len * 8 + writer.bit_index;
        const encoded = try writer.toOwnedSlice(allocator);
        defer allocator.free(encoded);
        const padded = try allocator.alloc(u8, encoded.len + 8);
        defer allocator.free(padded);
        @memcpy(padded[0..encoded.len], encoded);
        @memset(padded[encoded.len..], 0);
        for (0..9) |padding| {
            const input = padded[0 .. encoded.len + padding];
            var reference_reader = bitstream.BufferedBitReader.init(input);
            var active_reader = bitstream.BufferedBitReader.init(input);
            try reference_reader.skipBits(@intCast(alignment));
            try active_reader.skipBits(@intCast(alignment));
            const reference_written = try Api.decodeReference(&reference_reader, reference_output, &reference);
            const active_written = try Api.decodeActive(&active_reader, active_output, &active);
            try std.testing.expectEqual(body_len, active_written);
            try std.testing.expectEqual(reference_written, active_written);
            try std.testing.expectEqualSlices(u8, expected, reference_output[0..reference_written]);
            try std.testing.expectEqualSlices(u8, expected, active_output[0..active_written]);
            try std.testing.expectEqual(logical_bits, active_reader.bitPosition());
            try std.testing.expectEqual(reference_reader.bitPosition(), active_reader.bitPosition());
            try std.testing.expectEqual(active_reader.consumed_bits, active_reader.byte_index * 8 - active_reader.bit_count);
            try std.testing.expectEqual(reference_reader.byteOffset(), active_reader.byteOffset());
        }
        var short_reference = bitstream.BufferedBitReader.init(encoded);
        var short_active = bitstream.BufferedBitReader.init(encoded);
        try short_reference.skipBits(@intCast(alignment));
        try short_active.skipBits(@intCast(alignment));
        try std.testing.expectError(error.OutputTooSmall, Api.decodeReference(&short_reference, reference_output[0 .. body_len - 1], &reference));
        try std.testing.expectError(error.OutputTooSmall, Api.decodeActive(&short_active, active_output[0 .. body_len - 1], &active));
        var truncated_reference = bitstream.BufferedBitReader.init(encoded[0 .. encoded.len / 2]);
        var truncated_active = bitstream.BufferedBitReader.init(encoded[0 .. encoded.len / 2]);
        try truncated_reference.skipBits(@intCast(alignment));
        try truncated_active.skipBits(@intCast(alignment));
        try std.testing.expectError(error.TruncatedFrame, Api.decodeReference(&truncated_reference, reference_output, &reference));
        try std.testing.expectError(error.TruncatedFrame, Api.decodeActive(&truncated_active, active_output, &active));
        const invalid = try allocator.dupe(u8, padded);
        defer allocator.free(invalid);
        invalid[invalid_bit / 8] ^= @as(u8, 1) << @intCast(invalid_bit % 8);
        var invalid_reference = bitstream.BufferedBitReader.init(invalid);
        var invalid_active = bitstream.BufferedBitReader.init(invalid);
        try invalid_reference.skipBits(@intCast(alignment));
        try invalid_active.skipBits(@intCast(alignment));
        try std.testing.expectError(error.InvalidHuffmanCode, Api.decodeReference(&invalid_reference, reference_output, &reference));
        try std.testing.expectError(error.InvalidHuffmanCode, Api.decodeActive(&invalid_active, active_output, &active));
    }
}
