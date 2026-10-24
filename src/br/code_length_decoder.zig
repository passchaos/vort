const std = @import("std");
const bitstream = @import("../bitstream.zig");
const core = @import("../core.zig");
const huffman = @import("../huffman.zig");

pub const alphabet_size = 18;
pub const Error = core.Error;

/// Direct five-bit root for Brotli's 18-symbol code-length alphabet. Complex
/// prefix parsing already proves that every multi-symbol tree is complete, so
/// all 32 slots are initialized without a generic canonical-table intermediate.
pub const Decoder = struct {
    slots: [32]u8 = undefined,

    pub fn init(lengths: *const [alphabet_size]u4) Error!Decoder {
        var counts: [6]u8 = @splat(0);
        for (lengths) |bits| {
            if (bits > 5) return error.InvalidHuffmanCode;
            if (bits != 0) counts[bits] += 1;
        }

        var available: i16 = 1;
        var canonical: u8 = 0;
        var next_code: [6]u8 = @splat(0);
        for (1..6) |bits| {
            available = (available << 1) - counts[bits];
            if (available < 0) return error.InvalidHuffmanCode;
            canonical = (canonical + counts[bits - 1]) << 1;
            next_code[bits] = canonical;
        }
        if (available != 0) return error.InvalidHuffmanCode;

        var decoder: Decoder = undefined;
        var coverage: usize = 0;
        for (lengths, 0..) |bits, symbol| {
            if (bits == 0) continue;
            const code = @bitReverse(next_code[bits]) >> @intCast(8 - @as(usize, bits));
            next_code[bits] += 1;
            const fill = @as(usize, 1) << @intCast(5 - bits);
            const slot: u8 = @as(u8, @intCast(symbol)) << 3 | bits;
            for (0..fill) |index|
                decoder.slots[@as(usize, code) | (index << bits)] = slot;
            coverage += fill;
        }
        std.debug.assert(coverage == decoder.slots.len);
        return decoder;
    }

    pub inline fn decodeValue(self: *const Decoder, reader: *bitstream.BitReader) Error!u16 {
        const slot = self.slots[reader.peekBitsPadded(u5, 5)];
        const bits: u3 = @truncate(slot);
        if (!reader.hasBits(bits)) return error.TruncatedFrame;
        reader.advanceBitsStagedAssumeAvailable(bits);
        return slot >> 3;
    }
};

test "direct code-length decoder matches generic canonical lookup" {
    const GenericDecoder = huffman.FastDecoder(alphabet_size, 5);
    const Oracle = struct {
        fn expectMatch(lengths: *const [alphabet_size]u4) !void {
            const direct = try Decoder.init(lengths);
            const generic = GenericDecoder.init(try huffman.HuffmanTable(alphabet_size).init(lengths));
            for (0..32) |prefix| {
                const input = [1]u8{@intCast(prefix)};
                var direct_reader = bitstream.BitReader.initBitLength(&input, 5);
                var generic_reader = bitstream.BitReader.initBitLength(&input, 5);
                try std.testing.expectEqual(try generic.decodeValue(&generic_reader), try direct.decodeValue(&direct_reader));
                try std.testing.expectEqual(generic_reader.bitPosition(), direct_reader.bitPosition());
            }
        }
    };
    const cases = [_][alphabet_size]u4{
        [_]u4{ 1, 1 } ++ [_]u4{0} ** 16,
        [_]u4{ 1, 2, 3, 3 } ++ [_]u4{0} ** 14,
        [_]u4{2} ** 4 ++ [_]u4{0} ** 14,
        [_]u4{ 1, 2, 3, 4, 5, 5 } ++ [_]u4{0} ** 12,
        [_]u4{ 0, 2, 0, 3, 1, 0, 3 } ++ [_]u4{0} ** 11,
    };
    for (cases) |lengths| {
        const direct = try Decoder.init(&lengths);
        try Oracle.expectMatch(&lengths);

        const encoder = try huffman.HuffmanTable(alphabet_size).Encoder.init(&lengths);
        for (lengths, 0..) |bits, symbol| {
            if (bits == 0) continue;
            var writer: bitstream.BitWriter = .{};
            defer writer.deinit(std.testing.allocator);
            try encoder.writeSymbol(&writer, std.testing.allocator, symbol);
            const encoded = try writer.toOwnedSlice(std.testing.allocator);
            defer std.testing.allocator.free(encoded);
            var truncated = bitstream.BitReader.initBitLength(encoded, bits - 1);
            try std.testing.expectError(error.TruncatedFrame, direct.decodeValue(&truncated));
        }
    }

    // Exhaust every complete 1...5-bit histogram fitting the 18-symbol
    // alphabet. Coprime placements exercise sparse holes and tie ordering.
    for (0..3) |count1| {
        for (0..5) |count2| {
            for (0..9) |count3| {
                for (0..17) |count4| {
                    const covered = count1 * 16 + count2 * 8 + count3 * 4 + count4 * 2;
                    if (covered > 32) continue;
                    const count5 = 32 - covered;
                    const active = count1 + count2 + count3 + count4 + count5;
                    if (count5 > alphabet_size or active < 2 or active > alphabet_size) continue;
                    const counts = [6]usize{ 0, count1, count2, count3, count4, count5 };
                    for ([_]usize{ 0, 1, 5 }) |rotation| {
                        var lengths: [alphabet_size]u4 = @splat(0);
                        var ordinal: usize = 0;
                        for (1..6) |bits| {
                            for (0..counts[bits]) |_| {
                                const symbol = (ordinal * 7 + rotation) % alphabet_size;
                                lengths[symbol] = @intCast(bits);
                                ordinal += 1;
                            }
                        }
                        try Oracle.expectMatch(&lengths);
                    }
                }
            }
        }
    }

    try std.testing.expectError(
        error.InvalidHuffmanCode,
        Decoder.init(&([_]u4{ 1, 1, 1 } ++ [_]u4{0} ** 15)),
    );
    try std.testing.expectError(
        error.InvalidHuffmanCode,
        Decoder.init(&([_]u4{ 2, 2 } ++ [_]u4{0} ** 16)),
    );
}
