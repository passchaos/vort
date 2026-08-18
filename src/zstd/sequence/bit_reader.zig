const std = @import("std");

pub const Error = error{ CorruptFrame, TruncatedFrame };

/// Reverse bit reader used by Zstandard Huffman and sequence bitstreams.
///
/// Zstandard terminates a reverse stream with a highest-set marker bit. Reads
/// consume payload bits from that marker toward byte zero and return them in
/// stream order. The implementation gathers at most nine adjacent bytes into a
/// little-endian reservoir, replacing the previous one-branch-per-bit loop.
pub const Reader = struct {
    bytes: []const u8,
    remaining_bits: usize,

    pub fn init(bitstream: []const u8) Error!Reader {
        if (bitstream.len == 0) return error.TruncatedFrame;
        const last = bitstream[bitstream.len - 1];
        if (last == 0) return error.CorruptFrame;
        const marker_bit: usize = 7 - @clz(last);
        return .{
            .bytes = bitstream,
            .remaining_bits = (bitstream.len - 1) * 8 + marker_bit,
        };
    }

    pub fn read(self: *Reader, bit_count: u8) Error!usize {
        if (bit_count == 0) return 0;
        if (bit_count > @bitSizeOf(usize)) return error.CorruptFrame;
        if (bit_count > self.remaining_bits) return error.TruncatedFrame;

        const end = self.remaining_bits;
        const start = end - bit_count;
        const first_byte = start >> 3;
        const last_byte = (end - 1) >> 3;
        var reservoir: u72 = 0;
        for (self.bytes[first_byte .. last_byte + 1], 0..) |byte, index| {
            reservoir |= @as(u72, byte) << @intCast(index * 8);
        }
        const shift: u7 = @intCast(start & 7);
        const mask: u72 = (@as(u72, 1) << @intCast(bit_count)) - 1;
        const little: usize = @intCast((reservoir >> shift) & mask);
        self.remaining_bits = start;
        // `little` already orders the selected range with the earliest reverse
        // stream bit in its most-significant selected position. Rebuilding the
        // same integer one bit at a time is redundant.
        return little;
    }

    /// Return the next bits without advancing. The value uses the same stream
    /// order as `read`, so table decoders can index fixed-width prefixes and
    /// then consume the actual code length.
    pub fn peek(self: Reader, bit_count: u8) Error!usize {
        var copy = self;
        return copy.read(bit_count);
    }

    /// Fast non-advancing prefix extraction for Huffman lookup tables. Zstd's
    /// literal code width is at most 11 bits, so an unaligned prefix touches no
    /// more than three bytes and does not need the generic u72 gather loop.
    pub fn peekSmall(self: Reader, bit_count: u4) Error!usize {
        if (bit_count == 0) return 0;
        if (bit_count > self.remaining_bits) return error.TruncatedFrame;
        const end = self.remaining_bits;
        const start = end - bit_count;
        const first_byte = start >> 3;
        const last_byte = (end - 1) >> 3;
        const byte_count = last_byte + 1 - first_byte;
        const reservoir: u32 = switch (byte_count) {
            1 => self.bytes[first_byte],
            2 => std.mem.readInt(u16, self.bytes[first_byte..][0..2], .little),
            3 => @as(u32, std.mem.readInt(u16, self.bytes[first_byte..][0..2], .little)) |
                (@as(u32, self.bytes[first_byte + 2]) << 16),
            else => unreachable,
        };
        const mask = (@as(u32, 1) << bit_count) - 1;
        return @intCast((reservoir >> @intCast(start & 7)) & mask);
    }

    pub fn skip(self: *Reader, bit_count: u8) Error!void {
        if (bit_count > self.remaining_bits) return error.TruncatedFrame;
        self.remaining_bits -= bit_count;
    }

    pub fn available(self: Reader) usize {
        return self.remaining_bits;
    }

    pub fn expectEnd(self: Reader) Error!void {
        if (self.remaining_bits != 0) return error.CorruptFrame;
    }
};

fn readReference(reader: *Reader, bit_count: u8) Error!usize {
    if (bit_count == 0) return 0;
    if (bit_count > reader.remaining_bits) return error.TruncatedFrame;
    var value: usize = 0;
    var bit = reader.remaining_bits;
    while (bit > reader.remaining_bits - bit_count) {
        bit -= 1;
        const byte = reader.bytes[bit / 8];
        const bit_index: u3 = @intCast(bit & 7);
        value = (value << 1) | ((byte >> bit_index) & 1);
    }
    reader.remaining_bits -= bit_count;
    return value;
}

test "Zstd reverse reader matches per-bit oracle across alignments and widths" {
    var bytes: [12]u8 = undefined;
    for (&bytes, 0..) |*byte, index| byte.* = @truncate(index * 73 + 19);
    bytes[bytes.len - 1] |= 0x80;
    for (1..bytes.len + 1) |len| {
        var fast = try Reader.init(bytes[0..len]);
        var reference = fast;
        var width: u8 = 1;
        while (width <= 16 and width <= fast.remaining_bits) : (width += 1) {
            try std.testing.expectEqual(
                try readReference(&reference, width),
                try fast.read(width),
            );
        }
    }
}

test "Zstd reverse reader peek and skip match read" {
    const bytes = [_]u8{ 0x35, 0xa6, 0xd0 };
    var reader = try Reader.init(&bytes);
    const before = reader.available();
    const peeked = try reader.peek(7);
    try std.testing.expectEqual(before, reader.available());
    var oracle = reader;
    try std.testing.expectEqual(try oracle.read(7), peeked);
    try reader.skip(7);
    try std.testing.expectEqual(oracle.available(), reader.available());
    try std.testing.expectError(error.TruncatedFrame, reader.skip(@intCast(reader.available() + 1)));
}

test "Zstd reverse reader small peek matches read across alignments" {
    var bytes: [8]u8 = .{ 0x35, 0xa6, 0x59, 0xc3, 0x17, 0xe8, 0x42, 0xd0 };
    for (0..12) |prefix_bits| {
        var aligned = try Reader.init(&bytes);
        if (prefix_bits != 0) try aligned.skip(@intCast(prefix_bits));
        var width: u4 = 1;
        while (width <= 11 and width <= aligned.available()) : (width += 1) {
            var oracle = aligned;
            try std.testing.expectEqual(
                try oracle.read(width),
                try aligned.peekSmall(width),
            );
        }
    }
}
