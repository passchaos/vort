const std = @import("std");
const bit_reader = @import("../sequence/bit_reader.zig");

/// Persistent 64-bit reverse reservoir for the large four-stream Huffman loop.
///
/// The next stream bit is kept at the most-significant end of `bits`. A low
/// sentinel records the total shift since the last load, allowing one reload
/// after five symbols without recomputing byte indexes for every prefix. The
/// caller must keep each input stream separate; this type never reads before
/// that stream's first byte or beyond its last byte.
pub const Reservoir = struct {
    bytes: [*]const u8,
    byte_offset: usize,
    bits: u64,

    pub fn init(source_reader: bit_reader.Reader) ?Reservoir {
        const end_byte = (source_reader.remaining_bits + 7) >> 3;
        if (end_byte < @sizeOf(u64) or end_byte > source_reader.bytes.len) return null;
        const byte_offset = end_byte - @sizeOf(u64);
        const high_padding: u3 = @intCast(end_byte * 8 - source_reader.remaining_bits);
        const loaded = std.mem.readInt(
            u64,
            source_reader.bytes[byte_offset..][0..@sizeOf(u64)],
            .little,
        ) | 1;
        return .{
            .bytes = source_reader.bytes.ptr,
            .byte_offset = byte_offset,
            .bits = loaded << high_padding,
        };
    }

    /// A five-symbol batch consumes at most 55 bits. Seven preceding bytes are
    /// therefore enough to make its following reload unconditionally safe.
    pub inline fn canDecodeFive(self: Reservoir, width: u4) bool {
        std.debug.assert(width != 0);
        return self.byte_offset >= 7;
    }

    /// Eight symbols consume at most 56 bits when the complete tree is at most
    /// seven bits wide, leaving the low sentinel available for refill.
    pub inline fn canDecodeEight(self: Reservoir, width: u4) bool {
        std.debug.assert(width != 0 and width <= 7);
        return self.byte_offset >= 7;
    }

    /// Four wide X2 entries consume at most 56 bits when the lookup spans at
    /// most fourteen bits, matching the same seven-byte refill bound.
    pub inline fn canDecodeFourWide(self: Reservoir, width: u4) bool {
        std.debug.assert(width != 0 and width <= 14);
        return self.byte_offset >= 7;
    }

    pub inline fn peek(self: Reservoir, width: u4) usize {
        std.debug.assert(width != 0 and width <= self.remainingBits());
        return @intCast(self.bits >> @intCast(64 - @as(u7, width)));
    }

    pub inline fn consume(self: *Reservoir, bit_count: u8) void {
        std.debug.assert(bit_count != 0 and bit_count <= self.remainingBits());
        self.bits <<= @intCast(bit_count);
    }

    /// Refill after a bounded batch. `canDecodeFive()` guarantees this cannot
    /// cross the beginning of the stream for five codes of width at most 11.
    pub inline fn reload(self: *Reservoir) void {
        std.debug.assert(self.bits != 0);
        const shifted: u7 = @intCast(@ctz(self.bits));
        const byte_count: usize = shifted >> 3;
        std.debug.assert(byte_count <= self.byte_offset);
        self.byte_offset -= byte_count;
        const loaded = std.mem.readInt(
            u64,
            self.bytes[self.byte_offset..][0..@sizeOf(u64)],
            .little,
        ) | 1;
        self.bits = loaded << @intCast(shifted & 7);
    }

    pub inline fn remainingBits(self: Reservoir) usize {
        std.debug.assert(self.bits != 0);
        return (self.byte_offset + @sizeOf(u64)) * 8 - @ctz(self.bits);
    }
};

test "persistent Huffman reservoir prefixes match reverse reader" {
    var bytes: [24]u8 = undefined;
    for (&bytes, 0..) |*byte, index| byte.* = @truncate(index * 73 + 19);

    for (8..bytes.len + 1) |len| {
        for (0..8) |marker_bit| {
            bytes[len - 1] = @as(u8, 1) << @intCast(marker_bit);
            const initial = try bit_reader.Reader.init(bytes[0..len]);
            const max_alignment = @min(@as(usize, 31), initial.available());
            var alignment: usize = 0;
            while (alignment <= max_alignment) : (alignment += 1) {
                var positioned = initial;
                if (alignment != 0) try positioned.skip(@intCast(alignment));
                const reservoir = Reservoir.init(positioned) orelse continue;
                const max_width = @min(@as(usize, 11), positioned.available());
                var width: usize = 1;
                while (width <= max_width) : (width += 1) {
                    try std.testing.expectEqual(
                        try positioned.peekSmall(@intCast(width)),
                        reservoir.peek(@intCast(width)),
                    );
                }
            }
        }
    }
}

test "persistent Huffman reservoir batches match reverse reader and preserve tails" {
    var bytes: [40]u8 = undefined;
    for (&bytes, 0..) |*byte, index| byte.* = @truncate(index * 109 + 37);

    for (8..bytes.len + 1) |len| {
        for (0..8) |marker_bit| {
            const payload_mask: u8 = if (marker_bit == 0) 0 else (@as(u8, 1) << @intCast(marker_bit)) - 1;
            bytes[len - 1] = (@as(u8, 1) << @intCast(marker_bit)) |
                (@as(u8, @intCast(marker_bit * 13)) & payload_mask);
            var reference = try bit_reader.Reader.init(bytes[0..len]);
            var reservoir = Reservoir.init(reference) orelse continue;
            var pattern_index: usize = marker_bit;
            while (reservoir.canDecodeFive(11)) {
                for (0..5) |_| {
                    const width: u4 = @intCast(1 + (pattern_index % 11));
                    try std.testing.expectEqual(
                        try reference.read(width),
                        reservoir.peek(width),
                    );
                    reservoir.consume(width);
                    pattern_index += 7;
                }
                reservoir.reload();
                try std.testing.expectEqual(reference.available(), reservoir.remainingBits());
            }

            var tail = reference;
            tail.remaining_bits = reservoir.remainingBits();
            try std.testing.expectEqual(reference.available(), tail.available());
            while (reference.available() != 0) {
                const width: u8 = @intCast(@min(@as(usize, 11), reference.available()));
                try std.testing.expectEqual(try reference.read(width), try tail.read(width));
            }
            try reference.expectEnd();
            try tail.expectEnd();
        }
    }
}

test "persistent Huffman reservoir decodes eight narrow prefixes per refill" {
    var bytes: [40]u8 = undefined;
    for (&bytes, 0..) |*byte, index| byte.* = @truncate(index * 61 + 23);
    bytes[bytes.len - 1] = 0x80;
    var reference = try bit_reader.Reader.init(&bytes);
    var reservoir = Reservoir.init(reference) orelse unreachable;
    while (reservoir.canDecodeEight(7)) {
        inline for (0..8) |_| {
            try std.testing.expectEqual(try reference.read(7), reservoir.peek(7));
            reservoir.consume(7);
        }
        reservoir.reload();
        try std.testing.expectEqual(reference.available(), reservoir.remainingBits());
    }
}

test "persistent Huffman reservoir decodes four wide prefixes per refill" {
    var bytes: [40]u8 = undefined;
    for (&bytes, 0..) |*byte, index| byte.* = @truncate(index * 47 + 29);
    bytes[bytes.len - 1] = 0x80;
    var reference = try bit_reader.Reader.init(&bytes);
    var reservoir = Reservoir.init(reference) orelse unreachable;
    while (reservoir.canDecodeFourWide(14)) {
        inline for (0..4) |_| {
            try std.testing.expectEqual(try reference.read(14), reservoir.peek(14));
            reservoir.consume(14);
        }
        reservoir.reload();
        try std.testing.expectEqual(reference.available(), reservoir.remainingBits());
    }
}
