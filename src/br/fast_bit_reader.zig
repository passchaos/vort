const std = @import("std");
const bitstream = @import("../bitstream.zig");
const core = @import("../core.zig");
const bit_count = @import("../io/bit_count.zig");
const BitCount = bit_count.BitCount;

/// Brotli payload reader modeled after upstream's hot-loop bit window. Header
/// parsing stays on the compact scalar reader; a complete compressed payload
/// can temporarily use this reservoir and synchronize its logical cursor back.
pub const Reader = struct {
    input: []const u8,
    bit_len: BitCount,
    next_byte: usize,
    bit_buffer: u64 = 0,
    bit_count: usize = 0,

    pub fn initFrom(source: bitstream.BitReader) Reader {
        const consumed_bits = bit_count.positionAssumeBounded(source.byte_index, source.bit_index);
        var reader = Reader{
            .input = source.input,
            .bit_len = source.bit_len,
            .next_byte = source.byte_index,
        };
        if (source.bit_index != 0 and source.byte_index < source.input.len) {
            reader.bit_count = bit_count.bounded(source.bit_len -| consumed_bits, 8 - @as(usize, source.bit_index));
            reader.bit_buffer = lowByteBits(source.input[source.byte_index] >> source.bit_index, reader.bit_count);
            reader.next_byte += 1;
        }
        return reader;
    }

    pub fn syncTo(self: Reader, target: *bitstream.BitReader) void {
        const position = self.bitPosition();
        target.byte_index = bit_count.floorBytes(position) catch unreachable;
        target.bit_index = @intCast(position % 8);
    }

    pub fn bitPosition(self: Reader) BitCount {
        return consumedBitPosition(self.next_byte, self.bit_len, self.bit_count);
    }

    pub fn readBits(self: *Reader, comptime T: type, count: u6) core.Error!T {
        if (count > @bitSizeOf(T)) return error.CorruptFrame;
        self.fill(count);
        if (!self.hasStagedBits(count)) return error.TruncatedFrame;
        const value = self.peekStaged(T, count);
        self.advanceBitsStagedAssumeAvailable(count);
        return value;
    }

    /// Read a Brotli payload field of at most 24 bits. The prepared command and
    /// distance paths normally have enough bits staged by the preceding Huffman
    /// lookup, so keep that case inline and leave refill/truncation handling in
    /// the general out-of-line reader.
    pub inline fn readBits24StagedFirst(self: *Reader, count: u5) core.Error!u32 {
        std.debug.assert(count <= 24);
        if (@as(usize, count) <= self.bit_count) {
            const mask = (@as(u64, 1) << count) - 1;
            const value: u32 = @intCast(self.bit_buffer & mask);
            self.advanceBitsStagedAssumeAvailable(count);
            return value;
        }
        return self.readBits(u32, count);
    }

    pub fn peekBitsPadded(self: *Reader, comptime T: type, count: u6) T {
        std.debug.assert(count <= @bitSizeOf(T));
        if (count == 0) return 0;
        self.fill(count);
        return self.peekStaged(T, count);
    }

    pub fn peekBits9Padded(self: *Reader) u9 {
        // Auxiliary command/distance tables always probe exactly nine bits.
        // Keep that hot path free of the generic width check and mask.
        self.fill(9);
        return @truncate(self.bit_buffer);
    }

    pub fn peekBits10Padded(self: *Reader) u10 {
        self.fill(10);
        return @truncate(self.bit_buffer);
    }

    pub fn hasBits(self: Reader, count: u6) bool {
        const position = self.bitPosition();
        return @as(BitCount, count) <= self.bit_len - position;
    }

    pub fn hasStagedBits(self: Reader, count: u6) bool {
        return @as(usize, count) <= self.bit_count;
    }

    pub fn advanceBitsAssumeAvailable(self: *Reader, count: u6) void {
        self.fill(count);
        self.advanceBitsStagedAssumeAvailable(count);
    }

    pub fn advanceBitsStagedAssumeAvailable(self: *Reader, count: u6) void {
        std.debug.assert(self.hasStagedBits(count));
        self.bit_buffer >>= @intCast(count);
        self.bit_count -= count;
    }

    inline fn peekStaged(self: Reader, comptime T: type, count: u6) T {
        const mask = (@as(u64, 1) << @intCast(count)) - 1;
        return @intCast(self.bit_buffer & mask);
    }

    inline fn fill(self: *Reader, requested_bits: usize) void {
        std.debug.assert(requested_bits <= 32);
        if (self.bit_count >= requested_bits) return;

        // Logical bits are bounded by input.len, so a complete valid word
        // also proves its physical load is inside the caller buffer.
        const valid_unstaged_bits = self.bit_len -| bit_count.fromBytesAssumeBounded(self.next_byte);
        if (requested_bits <= 8 and self.bit_count <= 8 and valid_unstaged_bits >= 64) {
            const word = std.mem.readInt(u64, self.input[self.next_byte..][0..8], .little);
            self.bit_buffer |= word << @intCast(self.bit_count);
            self.bit_count += 56;
            self.next_byte += 7;
        } else if (requested_bits <= 16 and self.bit_count <= 16 and valid_unstaged_bits >= 64) {
            const word = std.mem.readInt(u64, self.input[self.next_byte..][0..8], .little);
            self.bit_buffer |= word << @intCast(self.bit_count);
            self.bit_count += 48;
            self.next_byte += 6;
        } else if (self.bit_count <= 32 and valid_unstaged_bits >= 32) {
            const word = std.mem.readInt(u32, self.input[self.next_byte..][0..4], .little);
            self.bit_buffer |= @as(u64, word) << @intCast(self.bit_count);
            self.bit_count += 32;
            self.next_byte += 4;
        }
        while (self.bit_count < requested_bits and self.next_byte < self.input.len and self.bit_count <= 56) {
            const valid_bits = bit_count.bounded(self.bit_len -| bit_count.fromBytesAssumeBounded(self.next_byte), 8);
            if (valid_bits == 0) break;
            self.bit_buffer |= @as(u64, lowByteBits(self.input[self.next_byte], valid_bits)) << @intCast(self.bit_count);
            self.bit_count += valid_bits;
            self.next_byte += 1;
        }
    }
};

inline fn lowByteBits(byte: u8, valid_bits: usize) u8 {
    // Mask padding when it enters the reservoir, so fixed-width Huffman peeks
    // need no logical-tail branch. The wider mask also handles all eight bits.
    std.debug.assert(valid_bits <= 8);
    const mask = (@as(u16, 1) << @intCast(valid_bits)) - 1;
    return byte & @as(u8, @intCast(mask));
}

fn consumedBitPosition(next_byte: usize, bit_len: BitCount, staged_bits: usize) BitCount {
    // next_byte points just past the last staged source byte. Clipping its
    // wide bit address handles a final partial byte before subtracting the
    // local reservoir count to reconstruct the exact consumed position.
    const staged_end = @min(bit_count.fromBytesAssumeBounded(next_byte), bit_len);
    std.debug.assert(staged_bits <= 64 and staged_bits <= staged_end);
    return staged_end - @as(BitCount, staged_bits);
}

test "Brotli fast bit reader absolute cursors cross narrow bit boundaries" {
    // Exercise cursor geometry independently of physical input: no fabricated
    // large slice or load is needed to reach addresses above the 32-bit limit.
    const vectors = [_]struct {
        next_byte: usize,
        bit_len: BitCount,
        staged_bits: usize,
        position: BitCount,
        byte_index: usize,
        bit_index: u3,
    }{
        .{ .next_byte = (1 << 29) - 1, .bit_len = 4294967296, .staged_bits = 5, .position = 4294967283, .byte_index = 536870910, .bit_index = 3 },
        .{ .next_byte = 1 << 29, .bit_len = 4294967296, .staged_bits = 0, .position = 4294967296, .byte_index = 536870912, .bit_index = 0 },
        .{ .next_byte = (1 << 29) + 1, .bit_len = 4294967301, .staged_bits = 2, .position = 4294967299, .byte_index = 536870912, .bit_index = 3 },
        .{ .next_byte = std.math.maxInt(u32), .bit_len = 34359738357, .staged_bits = 61, .position = 34359738296, .byte_index = 4294967287, .bit_index = 0 },
    };
    for (vectors) |vector| {
        const position = consumedBitPosition(vector.next_byte, vector.bit_len, vector.staged_bits);
        try std.testing.expectEqual(vector.position, position);
        try std.testing.expectEqual(vector.byte_index, try bit_count.floorBytes(position));
        try std.testing.expectEqual(vector.bit_index, @as(u3, @intCast(position % 8)));
    }
}

test "Brotli fast bit reader matches scalar mixed reads and cursors" {
    var input: [257]u8 = undefined;
    var state: u32 = 0x243f_6a88;
    for (&input) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }

    for (0..8) |start_bit| {
        var scalar = bitstream.BitReader.init(&input);
        scalar.bit_index = @intCast(start_bit);
        var fast = Reader.initFrom(scalar);
        var staged_first = Reader.initFrom(scalar);
        var operation: usize = 0;
        while (scalar.hasBits(24)) : (operation += 1) {
            const count: u5 = @intCast(1 + (operation * 7 + start_bit) % 24);
            try std.testing.expectEqual(scalar.peekBitsPadded(u32, count), fast.peekBitsPadded(u32, count));
            try std.testing.expectEqual(try scalar.readBits(u32, count), try fast.readBits(u32, count));
            var staged_reference = staged_first;
            try std.testing.expectEqual(try staged_reference.readBits(u32, count), try staged_first.readBits24StagedFirst(count));
            try std.testing.expectEqual(scalar.bitPosition(), fast.bitPosition());
            try std.testing.expectEqual(scalar.bitPosition(), staged_first.bitPosition());
        }
        fast.syncTo(&scalar);
        try std.testing.expectEqual(fast.bitPosition(), scalar.bitPosition());
    }
}

test "Brotli fast bit reader preserves truncated bit length" {
    const input = [_]u8{ 0xad, 0x72, 0xc1, 0x1e, 0x5a };
    var scalar = bitstream.BitReader.initBitLength(&input, input.len * 8 - 3);
    scalar.byte_index = 1;
    scalar.bit_index = 5;
    var fast = Reader.initFrom(scalar);

    while (scalar.hasBits(7)) {
        try std.testing.expectEqual(try scalar.readBits(u8, 7), try fast.readBits(u8, 7));
    }
    const remaining: u6 = @intCast(scalar.bit_len - scalar.bitPosition());
    try std.testing.expectEqual(try scalar.readBits(u8, remaining), try fast.readBits(u8, remaining));
    try std.testing.expectError(error.TruncatedFrame, scalar.readBits(u1, 1));
    try std.testing.expectError(error.TruncatedFrame, fast.readBits(u1, 1));
    fast.syncTo(&scalar);
    try std.testing.expectEqual(scalar.bit_len, scalar.bitPosition());
}

test "Brotli fast bit reader loads complete short tails" {
    const input = [_]u8{ 0xad, 0x72, 0xc1 };
    for (1..25) |count| {
        var scalar = bitstream.BitReader.init(&input);
        var fast = Reader.initFrom(scalar);
        const width: u6 = @intCast(count);
        try std.testing.expectEqual(try scalar.readBits(u32, width), try fast.readBits(u32, width));
        try std.testing.expectEqual(scalar.bitPosition(), fast.bitPosition());
    }
}

test "Brotli fast bit reader specialized fixed-width peeks match generic reads" {
    var input: [33]u8 = undefined;
    var state: u32 = 0x9e37_79b9;
    for (&input) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 17);
    }

    for (0..input.len + 1) |byte_len| {
        for (0..8) |start_bit| {
            if (byte_len == 0 and start_bit != 0) continue;
            const bit_len = byte_len * 8;
            if (start_bit > bit_len) continue;
            var source = bitstream.BitReader.initBitLength(input[0..byte_len], bit_len);
            source.byte_index = start_bit / 8;
            source.bit_index = @intCast(start_bit % 8);
            var generic = Reader.initFrom(source);
            var specialized = Reader.initFrom(source);
            var operation: usize = 0;
            while (true) : (operation += 1) {
                try std.testing.expectEqual(
                    generic.peekBitsPadded(u9, 9),
                    specialized.peekBits9Padded(),
                );
                try std.testing.expectEqual(
                    generic.peekBitsPadded(u10, 10),
                    specialized.peekBits10Padded(),
                );
                if (generic.bitPosition() == bit_len) break;
                const remaining = bit_len - generic.bitPosition();
                const consumed: u6 = @intCast(@min(remaining, 1 + operation % 10));
                generic.advanceBitsStagedAssumeAvailable(consumed);
                specialized.advanceBitsStagedAssumeAvailable(consumed);
                try std.testing.expectEqual(generic.bitPosition(), specialized.bitPosition());
            }
        }
    }
}

test "Brotli fast bit reader full-word refills honor every logical tail" {
    var input: [24]u8 = undefined;
    for (&input, 0..) |*byte, index| byte.* = @truncate(index * 73 + 0xa5);
    // Keep real, nonzero bytes beyond each logical endpoint. A bulk load may
    // only treat bits within bit_len as staged, even when physical bytes exist.
    for (0..input.len * 8 + 1) |bit_len| {
        for (0..8) |start| {
            if (start > bit_len) continue;
            for (0..33) |first_width| {
                var scalar = bitstream.BitReader.initBitLength(&input, bit_len);
                try scalar.skipBits(@intCast(start));
                var fast = Reader.initFrom(scalar);
                for ([_]usize{ first_width, (first_width + 17) % 33, (first_width + 21) % 33 }) |width| {
                    const count: u6 = @intCast(width);
                    const expected = scalar.readBits(u32, count);
                    const actual = fast.readBits(u32, count);
                    if (expected) |value| {
                        try std.testing.expectEqual(value, try actual);
                    } else |err| try std.testing.expectError(err, actual);
                    try std.testing.expectEqual(scalar.bitPosition(), fast.bitPosition());
                    var synced = bitstream.BitReader.initBitLength(&input, bit_len);
                    fast.syncTo(&synced);
                    try std.testing.expectEqual(scalar.byte_index, synced.byte_index);
                    try std.testing.expectEqual(scalar.bit_index, synced.bit_index);
                }
            }
        }
    }
}

test "Brotli fast bit reader padded peeks match independent logical bit oracle" {
    const Oracle = struct {
        fn peek(input: []const u8, logical_bits: usize, start: usize, width: usize) u32 {
            var value: u32 = 0;
            for (0..width) |offset| {
                const position = start + offset;
                if (position >= logical_bits) break;
                const bit = (input[position / 8] >> @as(u3, @intCast(position % 8))) & 1;
                value |= @as(u32, bit) << @as(u5, @intCast(offset));
            }
            return value;
        }
    };

    var input: [23]u8 = undefined;
    for (&input, 0..) |*byte, index| byte.* = @as(u8, @truncate(index * 73 + 0xa5)) | 0x80;
    // Physical high bits and bytes remain nonzero past every logical endpoint.
    // Every starting position exercises its own initial partial byte, while
    // wider probes also refill across the final partial byte and full words.
    for (0..input.len * 8 + 1) |logical_bits| {
        for (0..logical_bits + 1) |start| {
            var source = bitstream.BitReader.initBitLength(&input, logical_bits);
            source.byte_index = start / 8;
            source.bit_index = @intCast(start % 8);
            const initial = Reader.initFrom(source);

            var nine = initial;
            var ten = initial;
            try std.testing.expectEqual(@as(u9, @intCast(Oracle.peek(&input, logical_bits, start, 9))), nine.peekBits9Padded());
            try std.testing.expectEqual(@as(u10, @intCast(Oracle.peek(&input, logical_bits, start, 10))), ten.peekBits10Padded());
            try std.testing.expectEqual(@as(BitCount, start), nine.bitPosition());
            try std.testing.expectEqual(@as(BitCount, start), ten.bitPosition());

            for (0..33) |width| {
                const count: u6 = @intCast(width);
                const expected = Oracle.peek(&input, logical_bits, start, width);
                var generic = initial;
                try std.testing.expectEqual(expected, generic.peekBitsPadded(u32, count));
                try std.testing.expectEqual(@as(BitCount, start), generic.bitPosition());
                if (width <= logical_bits - start) {
                    try std.testing.expectEqual(expected, try generic.readBits(u32, count));
                    try std.testing.expectEqual(@as(BitCount, start + width), generic.bitPosition());
                } else {
                    try std.testing.expectError(error.TruncatedFrame, generic.readBits(u32, count));
                    try std.testing.expectEqual(@as(BitCount, start), generic.bitPosition());
                }
                var synced = source;
                generic.syncTo(&synced);
                try std.testing.expectEqual(generic.bitPosition(), synced.bitPosition());
            }
        }
    }
}
