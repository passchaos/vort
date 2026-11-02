//! A ring's writable end can be inside the allocation. Speculative RLE stores
//! must leave the unreleased history beyond that logical end untouched.
const std = @import("std");
const huffman = @import("../../huffman.zig");
const bitstream = @import("../../bitstream.zig");

pub fn verify(comptime Decoder: type, comptime initialize: anytype, comptime decode: anytype) !void {
    var lengths: [286]u4 = @splat(0);
    lengths[285] = 1;
    lengths[0] = 2;
    lengths[256] = 2;
    const literals = try huffman.HuffmanTable(286).init(&lengths);
    const distances = try huffman.HuffmanTable(30).init(&.{ 1, 1 });
    var decoder: Decoder = undefined;
    try std.testing.expect(initialize(&decoder, &literals, &distances));
    // length258/distance1 = 00, followed by EOB = 11.
    const encoded = [_]u8{0b0000_1100} ++ ([_]u8{0} ** 15);
    var storage: [65536]u8 = undefined;
    for ([_]usize{ 0, 1, 7, 63, 1024 }) |position| {
        for (262..321) |room| {
            @memset(&storage, 0xa5);
            storage[if (position == 0) storage.len - 1 else position - 1] = 77;
            var reader = bitstream.BufferedBitReader.init(&encoded);
            const limit = position + room;
            const result = try decode(&reader, &storage, position, &decoder, limit, storage.len);
            try std.testing.expectEqual(position + 258, result.output_written);
            try std.testing.expectEqual(@as(usize, 2), reader.bitPosition());
            for (storage[position..][0..258]) |value| try std.testing.expectEqual(@as(u8, 77), value);
            const guard_end = if (position == 0) storage.len - 1 else storage.len;
            for (storage[limit..guard_end]) |value| try std.testing.expectEqual(@as(u8, 0xa5), value);
        }
    }
}
