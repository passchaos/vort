const std = @import("std");
const br = @import("../../br.zig");
const bitstream = @import("../../bitstream.zig");
const huffman = @import("../../huffman.zig");
const Reader = @import("bit_reader.zig").Reader;

const capacity = 256;

fn encodedWire(comptime alphabet: usize, lengths: []const u4, symbols: []const u16) ![]u8 {
    const Encoder = huffman.HuffmanTable(alphabet).Encoder;
    const encoder = try Encoder.init(lengths);
    var writer: bitstream.BitWriter = .{};
    defer writer.deinit(std.testing.allocator);
    for (symbols) |symbol| try encoder.writeSymbol(&writer, std.testing.allocator, symbol);
    return writer.toOwnedSlice(std.testing.allocator);
}

fn checkTree(comptime alphabet: usize, lengths: []const u4, symbols: []const u16) !void {
    var tree: br.PrefixCode(alphabet) = .{ .table = try huffman.HuffmanTable(alphabet).init(lengths) };
    const wire = try encodedWire(alphabet, lengths, symbols);
    defer std.testing.allocator.free(wire);

    var reference = bitstream.BitReader.init(wire);
    var input_read: usize = 0;
    var staged_bits: u128 = 0;
    var staged_count: u8 = 0;
    var stream_bits: usize = 0;
    var prepared_reader = Reader.init(wire, &input_read, &staged_bits, &staged_count, &stream_bits);
    for (symbols) |expected| {
        try std.testing.expectEqual(expected, try tree.decode(&reference));
        try std.testing.expectEqual(expected, try tree.decodePrepared(&prepared_reader));
    }
    try std.testing.expectEqual(wire.len, input_read);
    try std.testing.expect(tree.prepared);

    // Byte-granular truncation must agree on symbols and the first error.
    for (0..wire.len + 1) |len| {
        var cut_reference = bitstream.BitReader.initBitLength(wire[0..len], len * 8);
        var cut_read: usize = 0;
        var cut_staged: u128 = 0;
        var cut_count: u8 = 0;
        var cut_stream: usize = 0;
        var cut_reader = Reader.init(wire[0..len], &cut_read, &cut_staged, &cut_count, &cut_stream);
        for (symbols) |_| {
            const expected = tree.decode(&cut_reference);
            const actual = tree.decodePrepared(&cut_reader);
            if (expected) |value| {
                try std.testing.expectEqual(value, try actual);
            } else |err| {
                try std.testing.expectError(err, actual);
                break;
            }
        }
    }
}

test "Brotli prepared prefix lookup matches canonical decoding" {
    const two_lengths = [_]u4{ 1, 1, 0, 0 };
    try checkTree(capacity, &two_lengths, &.{ 0, 1, 0, 1, 1, 0 });

    const short_lengths = [_]u4{ 1, 2, 3, 4, 4, 0 };
    try checkTree(capacity, &short_lengths, &.{ 0, 1, 2, 3, 4, 0, 4, 2, 1, 3 });

    const long_lengths = [_]u4{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 9 };
    try checkTree(capacity, &long_lengths, &.{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0, 8, 9, 1 });

    const wide_lengths = [_]u4{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 10 };
    try checkTree(capacity, &wide_lengths, &.{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 0, 10, 9 });
}

test "Brotli prepared prefix lookup is cleared when a tree is replaced" {
    const first_lengths = [_]u4{ 1, 2, 3, 4, 4, 0 };
    const second_lengths = [_]u4{ 1, 2, 3, 4, 5, 5 };
    var tree: br.PrefixCode(capacity) = .{ .table = try huffman.HuffmanTable(capacity).init(&first_lengths) };
    const first_symbols = [_]u16{ 0, 1, 2, 3, 4, 4 };
    const first_wire = try encodedWire(capacity, &first_lengths, &first_symbols);
    defer std.testing.allocator.free(first_wire);
    var input_read: usize = 0;
    var staged_bits: u128 = 0;
    var staged_count: u8 = 0;
    var stream_bits: usize = 0;
    var reader = Reader.init(first_wire, &input_read, &staged_bits, &staged_count, &stream_bits);
    for (first_symbols) |expected| try std.testing.expectEqual(expected, try tree.decodePrepared(&reader));
    try std.testing.expect(tree.prepared);

    // Installing a different table without clearing the lazy lookup would
    // decode against the previous tree's slots.
    tree = .{ .table = try huffman.HuffmanTable(capacity).init(&second_lengths) };
    try std.testing.expect(!tree.prepared);
    const second_symbols = [_]u16{ 0, 1, 2, 3, 4, 5, 5, 4 };
    const second_wire = try encodedWire(capacity, &second_lengths, &second_symbols);
    defer std.testing.allocator.free(second_wire);
    input_read = 0;
    staged_bits = 0;
    staged_count = 0;
    stream_bits = 0;
    reader = Reader.init(second_wire, &input_read, &staged_bits, &staged_count, &stream_bits);
    for (second_symbols) |expected| try std.testing.expectEqual(expected, try tree.decodePrepared(&reader));
}
