const std = @import("std");
const bits = @import("../bitstream.zig");
const Count = @FieldType(bits.BitReader, "bit_len");
const Readers = .{ bits.BitReader, bits.BufferedBitReader, bits.ChunkedBitReader, bits.ChunkedSpanBitReader };
const input = [_]u8{ 0xd3, 0x6a, 0xf1, 0x29, 0x84, 0xbe, 0x07, 0x55, 0x13, 0x92, 0x46, 0xec, 0xab, 0x01, 0xfe, 0x37 };
const chunks = [_][]const u8{ &.{}, input[0..1], input[1..3], &.{}, input[3..8], input[8..9], &.{}, input[9..], &.{} };
fn init(comptime Reader: type) !Reader {
    if (Reader == bits.BitReader or Reader == bits.BufferedBitReader) return Reader.init(&input);
    return Reader.init(&chunks);
}
// Byte/bit enumeration is independent of every reader's word and reservoir path.
fn expected(data: []const u8, bit_len: usize, position: usize, width: u6) u64 {
    var result: u64 = 0;
    for (0..width) |offset| {
        const at = position + offset;
        if (at >= bit_len) break;
        result |= @as(u64, (data[at / 8] >> @as(u3, @intCast(at % 8))) & 1) << @as(u6, @intCast(offset));
    }
    return result;
}

test "wide bit readers agree on real input reads peeks staged advance and alignment" {
    inline for (Readers) |Reader| {
        var reader = try init(Reader);
        try std.testing.expectEqual(expected(&input, 128, 0, 18), try reader.peekBits(u64, 18));
        try std.testing.expectEqual(@as(Count, 0), reader.bitPosition());
        try std.testing.expectEqual(expected(&input, 128, 0, 3), try reader.readBits(u64, 3));
        try std.testing.expectEqual(expected(&input, 128, 3, 13), try reader.readBits(u64, 13));
        var copied: [4]u8 = undefined;
        try reader.readAlignedBytes(&copied);
        try std.testing.expectEqualSlices(u8, input[2..6], &copied);
        try std.testing.expectEqual(expected(&input, 128, 48, 9), try reader.readBits(u64, 9));
        try std.testing.expectEqual(expected(&input, 128, 57, 27), reader.peekBitsPadded(u64, 27));
        try std.testing.expect(reader.hasStagedBits(5));
        reader.advanceBitsStagedAssumeAvailable(5);
        try std.testing.expectEqual(@as(Count, 62), reader.bitPosition());
        reader.alignToByte();
        try std.testing.expectEqual(@as(Count, 64), reader.bitPosition());
        try std.testing.expectEqual(@as(u32, 0xec469213), try reader.readAlignedInt(u32, .little));
        reader.advanceBitsAssumeAvailable(7);
        try reader.skipBits(3);
        try std.testing.expectEqual(expected(&input, 128, 106, 21), try reader.peekBits(u64, 21));
        try std.testing.expectEqual(expected(&input, 128, 106, 21), try reader.readBits(u64, 21));
        try std.testing.expectEqual(@as(Count, 127), reader.bitPosition());
        reader.alignToByte();
        try std.testing.expectEqual(@as(Count, 128), reader.bitPosition());
    }
}

test "wide bit readers widths one through sixty three agree across chunk and word boundaries" {
    inline for (Readers) |Reader| {
        for ([_]u6{ 0, 1, 2, 7, 9, 31, 63 }) |position| {
            for (1..64) |width| {
                const count: u6 = @intCast(width);
                var reader = try init(Reader);
                try reader.skipBits(position);
                const value = expected(&input, 128, position, count);
                try std.testing.expectEqual(value, reader.peekBitsPadded(u64, count));
                try std.testing.expectEqual(value, try reader.peekBits(u64, count));
                try std.testing.expectEqual(@as(Count, position), reader.bitPosition());
                try std.testing.expectEqual(value, try reader.readBits(u64, count));
                try std.testing.expectEqual(@as(Count, position) + count, reader.bitPosition());
                const next = @as(usize, position) + count;
                if (next < 128) {
                    try std.testing.expectEqual(expected(&input, 128, next, 1), try reader.readBits(u64, 1));
                    try std.testing.expectEqual(@as(Count, @intCast(next + 1)), reader.bitPosition());
                }
                // A wide padded peek may use temporary staging. Both public
                // advancement paths must still consume exactly that field.
                for ([_]bool{ false, true }) |staged| {
                    var advanced = try init(Reader);
                    try advanced.skipBits(position);
                    try std.testing.expectEqual(value, advanced.peekBitsPadded(u64, count));
                    if (staged) advanced.advanceBitsStagedAssumeAvailable(count) else advanced.advanceBitsAssumeAvailable(count);
                    try std.testing.expectEqual(@as(Count, @intCast(next)), advanced.bitPosition());
                    if (next < 128) {
                        try std.testing.expectEqual(expected(&input, 128, next, 1), try advanced.readBits(u64, 1));
                        try std.testing.expectEqual(@as(Count, @intCast(next + 1)), advanced.bitPosition());
                    }
                }
            }
        }
    }
}

test "wide bit reader partial tails mask synthetic high bits in every padded width" {
    const padded = [_]u8{0xff} ** 16;
    for ([_]usize{ 1, 7, 13, 31, 37, 63, 71 }) |bit_len| {
        for ([_]usize{ 0, bit_len - @min(bit_len, 3), bit_len }) |position| {
            for (1..64) |width| {
                const count: u6 = @intCast(width);
                var reader = bits.BitReader.initBitLength(&padded, @intCast(bit_len));
                reader.byte_index = position / 8;
                reader.bit_index = @intCast(position % 8);
                const before = reader;
                try std.testing.expectEqual(expected(&padded, bit_len, position, count), reader.peekBitsPadded(u64, count));
                try std.testing.expectEqualDeep(before, reader);
                try std.testing.expectEqual(@as(u9, @intCast(expected(&padded, bit_len, position, 9))), reader.peekBits9Padded());
                if (width <= bit_len - position) {
                    try std.testing.expectEqual(expected(&padded, bit_len, position, count), try reader.readBits(u64, count));
                } else {
                    try std.testing.expectError(error.TruncatedFrame, reader.readBits(u64, count));
                    try std.testing.expectEqualDeep(before, reader);
                }
            }
        }
    }
}

test "wide bit readers failed reads leave output reservoir and cursors unchanged" {
    inline for (Readers) |Reader| {
        var reader = try init(Reader);
        _ = reader.peekBitsPadded(u64, 31);
        var output: [17]u8 = @splat(0xa5);
        const aligned_before = reader;
        try std.testing.expectError(error.TruncatedFrame, reader.readAlignedBytes(&output));
        try std.testing.expectEqualDeep(aligned_before, reader);
        try std.testing.expectEqualSlices(u8, &([_]u8{0xa5} ** 17), &output);
        _ = try reader.readBits(u8, 1);
        const unaligned_before = reader;
        try std.testing.expectError(error.CorruptFrame, reader.readAlignedBytes(output[0..1]));
        try std.testing.expectError(error.CorruptFrame, reader.readBits(u8, 9));
        try std.testing.expectEqualDeep(unaligned_before, reader);
        try reader.skipBits(63);
        try reader.skipBits(62);
        const tail_before = reader;
        try std.testing.expectError(error.TruncatedFrame, reader.readBits(u64, 3));
        try std.testing.expectError(error.TruncatedFrame, reader.peekBits(u64, 3));
        try std.testing.expectError(error.TruncatedFrame, reader.skipBits(3));
        try std.testing.expectEqualDeep(tail_before, reader);
        reader.alignToByte();
        const end = reader;
        try std.testing.expectError(error.TruncatedFrame, reader.readAlignedBytes(output[0..1]));
        try std.testing.expectEqualDeep(end, reader);
        try std.testing.expectEqualSlices(u8, &([_]u8{0xa5} ** 17), &output);
    }
    var partial = bits.BitReader.initBitLength(&.{0xff}, 3);
    _ = try partial.readBits(u3, 3);
    partial.alignToByte(); // Padding past the logical tail itself is permissive.
    try std.testing.expectEqual(@as(Count, 8), partial.bitPosition());
    const before = partial;
    var output: [1]u8 = .{0xa5};
    try std.testing.expectError(error.TruncatedFrame, partial.readAlignedBytes(&output));
    try std.testing.expectError(error.TruncatedFrame, partial.readBits(u8, 1));
    try std.testing.expectEqualDeep(before, partial);
    try std.testing.expectEqual(@as(u8, 0xa5), output[0]);
}

test "wide bit reader copies rewind prefetched reservoirs and chunk cursors" {
    inline for (Readers) |Reader| {
        var reader = try init(Reader);
        _ = try reader.readBits(u8, 3);
        _ = reader.peekBitsPadded(u64, 27);
        const checkpoint = reader;
        var reference = checkpoint;
        const value = try reference.readBits(u64, 29);
        _ = try reader.readBits(u64, 29);
        reader.alignToByte();
        var displaced: [7]u8 = undefined;
        try reader.readAlignedBytes(&displaced);
        _ = reader.peekBitsPadded(u64, 31);
        reader = checkpoint;
        try std.testing.expectEqualDeep(checkpoint, reader);
        try std.testing.expectEqual(value, try reader.readBits(u64, 29));
        try std.testing.expectEqualDeep(reference, reader);
    }
}

test "wide bit reader public counters widen while physical cursor types and native layouts remain" {
    try std.testing.expect(Count == if (@bitSizeOf(usize) < 64) u64 else usize);
    try std.testing.expect(bits.BitCount == Count);
    try std.testing.expect(@FieldType(bits.BufferedBitReader, "consumed_bits") == Count);
    inline for (Readers) |Reader| {
        const reader = try init(Reader);
        try std.testing.expect(@TypeOf(reader.bitPosition()) == Count);
        try std.testing.expect(@FieldType(Reader, "byte_index") == usize);
        try std.testing.expect(@TypeOf(reader.byteOffset()) == usize);
        if (@hasField(Reader, "bit_count")) try std.testing.expect(@FieldType(Reader, "bit_count") == usize);
        if (@hasField(Reader, "total_len")) try std.testing.expect(@FieldType(Reader, "total_len") == usize);
    }
    if (@bitSizeOf(usize) == 64) {
        inline for (.{ .{ bits.BitReader, LegacyScalar }, .{ bits.BufferedBitReader, LegacyBuffered }, .{ bits.ChunkedBitReader, LegacyChunked }, .{ bits.ChunkedSpanBitReader, LegacySpan } }) |pair| {
            try std.testing.expectEqual(@sizeOf(pair[1]), @sizeOf(pair[0]));
            try std.testing.expectEqual(@alignOf(pair[1]), @alignOf(pair[0]));
            try std.testing.expectEqual(std.meta.fields(pair[1]).len, std.meta.fields(pair[0]).len);
            inline for (std.meta.fields(pair[1])) |field| {
                try std.testing.expect(field.type == @FieldType(pair[0], field.name));
                try std.testing.expectEqual(@offsetOf(pair[1], field.name), @offsetOf(pair[0], field.name));
            }
        }
    }
}

test "wide bit reader helper addresses above two to the thirty two need no input allocation" {
    const bytes: usize = (1 << 29) + 7;
    const position = try bits.bit_count.position(bytes, 5);
    try std.testing.expectEqual((@as(Count, 1) << 32) + 61, position);
    try std.testing.expectEqual(position, bits.bit_count.positionAssumeBounded(bytes, 5));
    try std.testing.expectEqual(bytes, try bits.bit_count.floorBytes(position));
    try std.testing.expectEqual(bytes + 1, try bits.bit_count.ceilBytes(position));
    try std.testing.expectEqual(@as(usize, 63), bits.bit_count.bounded(position, 63));
    if (@bitSizeOf(usize) < 64) {
        try std.testing.expectError(error.IntegerOverflow, bits.bit_count.toLocal(position));
        const maximum = try bits.bit_count.position(std.math.maxInt(usize), 7);
        try std.testing.expectEqual(@as(Count, 34359738367), maximum);
        try std.testing.expectEqual(std.math.maxInt(usize), try bits.bit_count.floorBytes(maximum));
        try std.testing.expectError(error.IntegerOverflow, bits.bit_count.ceilBytes(maximum));
    }
}

// Independent public field schemas archived from 3e59413a, before bit widening.
const LegacyScalar = struct {
    input: []const u8,
    bit_len: usize,
    byte_index: usize = 0,
    bit_index: u3 = 0,
};
const LegacyBuffered = struct {
    input: []const u8,
    byte_index: usize = 0,
    bit_buffer: u64 = 0,
    bit_count: usize = 0,
    consumed_bits: usize = 0,
};
const LegacyChunked = struct {
    chunks: []const []const u8,
    byte_index: usize = 0,
    bit_index: u3 = 0,
    total_len: usize = 0,
    chunk_index: usize = 0,
    chunk_start: usize = 0,
    staged_byte_index: usize = 0,
    bit_buffer: u64 = 0,
    bit_count: usize = 0,
    staged_chunk_index: usize = 0,
    staged_chunk_start: usize = 0,
};
const LegacySpan = struct {
    chunks: []const []const u8,
    byte_index: usize = 0,
    bit_index: u3 = 0,
    total_len: usize = 0,
    source_absolute: usize = 0,
    source_chunk_index: usize = 0,
    source_chunk_start: usize = 0,
    source_local: usize = 0,
    bit_buffer: u64 = 0,
    bit_count: usize = 0,
};
