const std = @import("std");
const bitstream = @import("../bitstream.zig");
const core = @import("../core.zig");

/// Brotli payload reader modeled after upstream's hot-loop bit window. Header
/// parsing stays on the compact scalar reader; a complete compressed payload
/// can temporarily use this reservoir and synchronize its logical cursor back.
pub const Reader = struct {
    input: []const u8,
    bit_len: usize,
    next_byte: usize,
    bit_buffer: u64 = 0,
    bit_count: usize = 0,

    pub fn initFrom(source: bitstream.BitReader) Reader {
        const consumed_bits = source.bitPosition();
        var reader = Reader{
            .input = source.input,
            .bit_len = source.bit_len,
            .next_byte = source.byte_index,
        };
        if (source.bit_index != 0 and source.byte_index < source.input.len) {
            reader.bit_buffer = source.input[source.byte_index] >> source.bit_index;
            reader.bit_count = @min(8 - @as(usize, source.bit_index), source.bit_len -| consumed_bits);
            reader.next_byte += 1;
        }
        return reader;
    }

    pub fn syncTo(self: Reader, target: *bitstream.BitReader) void {
        const position = self.bitPosition();
        target.byte_index = position / 8;
        target.bit_index = @intCast(position % 8);
    }

    pub fn bitPosition(self: Reader) usize {
        // next_byte points just past the last staged source byte. Clipping its
        // bit position handles a final partial byte, so subtracting the live
        // reservoir count reconstructs the exact consumed position.
        const staged_end = @min(self.next_byte * 8, self.bit_len);
        std.debug.assert(self.bit_count <= staged_end);
        return staged_end - self.bit_count;
    }

    pub fn readBits(self: *Reader, comptime T: type, count: u6) core.Error!T {
        if (count > @bitSizeOf(T)) return error.CorruptFrame;
        self.fill(count);
        if (!self.hasStagedBits(count)) return error.TruncatedFrame;
        const value = self.peekStaged(T, count);
        self.advanceBitsStagedAssumeAvailable(count);
        return value;
    }

    pub fn peekBitsPadded(self: *Reader, comptime T: type, count: u6) T {
        std.debug.assert(count <= @bitSizeOf(T));
        if (count == 0) return 0;
        self.fill(count);
        return self.peekStaged(T, count);
    }

    pub fn peekBits10Padded(self: *Reader) u10 {
        self.fill(10);
        return @truncate(self.bit_buffer);
    }

    pub fn hasBits(self: Reader, count: u6) bool {
        const position = self.bitPosition();
        return @as(usize, count) <= self.bit_len - position;
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
        if (self.bit_count >= requested_bits or self.next_byte >= self.input.len) return;

        const remaining = self.input.len - self.next_byte;
        const valid_unstaged_bits = self.bit_len - @min(self.next_byte * 8, self.bit_len);
        if (requested_bits <= 8 and self.bit_count <= 8 and remaining >= 8 and valid_unstaged_bits >= 56) {
            const word = std.mem.readInt(u64, self.input[self.next_byte..][0..8], .little);
            self.bit_buffer |= word << @intCast(self.bit_count);
            self.bit_count += 56;
            self.next_byte += 7;
        } else if (requested_bits <= 16 and self.bit_count <= 16 and remaining >= 8 and valid_unstaged_bits >= 48) {
            const word = std.mem.readInt(u64, self.input[self.next_byte..][0..8], .little);
            self.bit_buffer |= word << @intCast(self.bit_count);
            self.bit_count += 48;
            self.next_byte += 6;
        } else if (self.bit_count <= 32 and remaining >= 4 and valid_unstaged_bits >= 32) {
            const word = std.mem.readInt(u32, self.input[self.next_byte..][0..4], .little);
            self.bit_buffer |= @as(u64, word) << @intCast(self.bit_count);
            self.bit_count += 32;
            self.next_byte += 4;
        }
        while (self.bit_count < requested_bits and self.next_byte < self.input.len and self.bit_count <= 56) {
            const valid_bits = self.bit_len - @min(self.next_byte * 8, self.bit_len);
            if (valid_bits == 0) break;
            self.bit_buffer |= @as(u64, self.input[self.next_byte]) << @intCast(self.bit_count);
            self.bit_count += @min(valid_bits, 8);
            self.next_byte += 1;
        }
    }
};

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
        var operation: usize = 0;
        while (scalar.hasBits(24)) : (operation += 1) {
            const count: u6 = @intCast(1 + (operation * 7 + start_bit) % 24);
            try std.testing.expectEqual(scalar.peekBitsPadded(u32, count), fast.peekBitsPadded(u32, count));
            try std.testing.expectEqual(try scalar.readBits(u32, count), try fast.readBits(u32, count));
            try std.testing.expectEqual(scalar.bitPosition(), fast.bitPosition());
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

test "Brotli fast bit reader specialized 10-bit peek matches generic reads" {
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
