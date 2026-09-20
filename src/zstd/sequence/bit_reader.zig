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
        const byte_count = last_byte + 1 - first_byte;
        const reservoir: u72 = switch (byte_count) {
            1 => self.bytes[first_byte],
            2 => std.mem.readInt(u16, self.bytes[first_byte..][0..2], .little),
            3...8 => blk: {
                var padded: [8]u8 = @splat(0);
                @memcpy(padded[0..byte_count], self.bytes[first_byte .. last_byte + 1]);
                break :blk std.mem.readInt(u64, &padded, .little);
            },
            9 => blk: {
                const low = std.mem.readInt(u64, self.bytes[first_byte..][0..8], .little);
                break :blk @as(u72, low) | (@as(u72, self.bytes[first_byte + 8]) << 64);
            },
            else => unreachable,
        };
        const shift: u7 = @intCast(start & 7);
        const mask: u72 = (@as(u72, 1) << @intCast(bit_count)) - 1;
        const little: usize = @intCast((reservoir >> shift) & mask);
        self.remaining_bits = start;
        // `little` already orders the selected range with the earliest reverse
        // stream bit in its most-significant selected position. Rebuilding the
        // same integer one bit at a time is redundant.
        return little;
    }

    /// Read a Zstd sequence field, whose width is bounded to 32 bits, from one
    /// 64-bit reservoir whenever enough bytes remain after the field start.
    /// The first few reverse reads can start too close to the physical end of
    /// the stream; those retain the generic exact-width gather to avoid any
    /// out-of-bounds over-read.
    pub inline fn readSequenceField(self: *Reader, bit_count: u8) Error!usize {
        if (bit_count == 0) return 0;
        if (bit_count > 32) return error.CorruptFrame;
        if (bit_count > self.remaining_bits) return error.TruncatedFrame;

        const start = self.remaining_bits - bit_count;
        const first_byte = start >> 3;
        if (self.bytes.len - first_byte < @sizeOf(u64)) {
            return self.read(bit_count);
        }
        const reservoir = std.mem.readInt(
            u64,
            self.bytes[first_byte..][0..@sizeOf(u64)],
            .little,
        );
        const mask = (@as(u64, 1) << @intCast(bit_count)) - 1;
        self.remaining_bits = start;
        return @intCast((reservoir >> @intCast(start & 7)) & mask);
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

    /// Return one full-width prefix for the four-stream Huffman bulk loop. The
    /// loop has already proven that `bit_count` bits remain, so this helper can
    /// select the 1/2/3-byte reservoir using only the start alignment: a field
    /// spans three bytes exactly when `alignment + width > 16`.
    pub fn peekBulkHuffman(self: Reader, bit_count: u4) usize {
        std.debug.assert(bit_count != 0 and bit_count <= self.remaining_bits);
        const start = self.remaining_bits - bit_count;
        const first_byte = start >> 3;
        const shift: u3 = @intCast(start & 7);
        const span_bits: u5 = @as(u5, shift) + bit_count;
        const reservoir: u32 = if (span_bits <= 8)
            self.bytes[first_byte]
        else if (span_bits <= 16)
            std.mem.readInt(u16, self.bytes[first_byte..][0..2], .little)
        else
            @as(u32, std.mem.readInt(u16, self.bytes[first_byte..][0..2], .little)) |
                (@as(u32, self.bytes[first_byte + 2]) << 16);
        return @intCast((reservoir >> shift) & ((@as(u32, 1) << bit_count) - 1));
    }

    /// Load up to two adjacent Huffman prefixes. The first prefix starts in the
    /// high bits, matching two consecutive reverse-stream reads.
    pub fn peekBulkHuffmanPair(self: Reader, bit_count: u4) u32 {
        std.debug.assert(bit_count != 0 and @as(usize, bit_count) * 2 <= self.remaining_bits);
        const total_bits: u5 = @as(u5, bit_count) * 2;
        const start = self.remaining_bits - total_bits;
        const first_byte = start >> 3;
        const last_byte = (self.remaining_bits - 1) >> 3;
        const byte_count = last_byte + 1 - first_byte;
        const shift: u3 = @intCast(start & 7);
        const reservoir: u32 = switch (byte_count) {
            1 => self.bytes[first_byte],
            2 => std.mem.readInt(u16, self.bytes[first_byte..][0..2], .little),
            3 => @as(u32, std.mem.readInt(u16, self.bytes[first_byte..][0..2], .little)) |
                (@as(u32, self.bytes[first_byte + 2]) << 16),
            4 => std.mem.readInt(u32, self.bytes[first_byte..][0..4], .little),
            else => unreachable,
        };
        return (reservoir >> shift) & ((@as(u32, 1) << total_bits) - 1);
    }

    /// Load five adjacent Huffman prefixes from one 64-bit reservoir. The
    /// earliest reverse-stream bit is returned at the high end of the selected
    /// range, so callers can decode variable-length symbols by advancing a
    /// logical bit offset without reloading input for every symbol.
    pub fn peekBulkHuffmanFive(self: Reader, bit_count: u4) u64 {
        std.debug.assert(bit_count != 0 and @as(usize, bit_count) * 5 <= self.remaining_bits);
        const total_bits: u6 = @as(u6, bit_count) * 5;
        const start = self.remaining_bits - total_bits;
        const first_byte = start >> 3;
        const shift: u3 = @intCast(start & 7);
        const available_bytes = self.bytes.len - first_byte;
        const reservoir = if (available_bytes >= @sizeOf(u64))
            std.mem.readInt(u64, self.bytes[first_byte..][0..@sizeOf(u64)], .little)
        else blk: {
            var padded: [8]u8 = @splat(0);
            @memcpy(padded[0..available_bytes], self.bytes[first_byte..]);
            break :blk std.mem.readInt(u64, &padded, .little);
        };
        return (reservoir >> shift) & ((@as(u64, 1) << total_bits) - 1);
    }

    /// Consume a code after a successful bulk Huffman lookup. The caller just
    /// proved that a full table width remains, and every valid code is no wider
    /// than that width, so this unchecked update removes a redundant bounds
    /// comparison from every decoded literal.
    pub inline fn skipBulkHuffman(self: *Reader, bit_count: u8) void {
        self.remaining_bits -= bit_count;
    }

    /// Consume a narrow field through the bounded prefix path. FSE sequence
    /// states stay below its three-byte bound and avoid the generic u72 gather.
    pub fn readSmall(self: *Reader, bit_count: u4) Error!usize {
        const value = try self.peekSmall(bit_count);
        try self.skip(bit_count);
        return value;
    }

    /// Read up to the currently available prefix for FSE streams whose state
    /// width is bounded to the small-reader range. The returned count lets the
    /// caller distinguish a clean final partial transition from truncation.
    pub inline fn readSmallAvailable(self: *Reader, bit_count: u4) Error!struct { value: usize, count: u4 } {
        const count: u4 = @intCast(@min(@as(usize, bit_count), self.remaining_bits));
        return .{
            .value = if (count == 0) 0 else try self.readSmall(count),
            .count = count,
        };
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

test "Zstd reverse reader bulk Huffman peek matches checked prefix" {
    var bytes: [8]u8 = .{ 0x35, 0xa6, 0x59, 0xc3, 0x17, 0xe8, 0x42, 0xd0 };
    for (0..16) |prefix_bits| {
        var reader = try Reader.init(&bytes);
        if (prefix_bits != 0) try reader.skip(@intCast(prefix_bits));
        var width: u4 = 1;
        while (width <= 11 and width <= reader.available()) : (width += 1) {
            try std.testing.expectEqual(
                try reader.peekSmall(width),
                reader.peekBulkHuffman(width),
            );
        }
    }
}

test "Zstd reverse reader paired Huffman peek matches checked prefix" {
    var bytes: [8]u8 = .{ 0x35, 0xa6, 0x59, 0xc3, 0x17, 0xe8, 0x42, 0xd0 };
    for (0..16) |prefix_bits| {
        var reader = try Reader.init(&bytes);
        if (prefix_bits != 0) try reader.skip(@intCast(prefix_bits));
        var width: u4 = 1;
        while (width <= 11 and @as(usize, width) * 2 <= reader.available()) : (width += 1)
            try std.testing.expectEqual(
                @as(u32, @intCast(try reader.peek(@as(u8, width) * 2))),
                reader.peekBulkHuffmanPair(width),
            );
    }
}

test "Zstd reverse reader five-symbol Huffman peek matches checked prefix" {
    var bytes: [12]u8 = .{ 0x35, 0xa6, 0x59, 0xc3, 0x17, 0xe8, 0x42, 0x91, 0x6b, 0xf4, 0x28, 0xd0 };
    for (0..32) |prefix_bits| {
        var reader = try Reader.init(&bytes);
        if (prefix_bits != 0) try reader.skip(@intCast(prefix_bits));
        var width: u4 = 1;
        while (width <= 11 and @as(usize, width) * 5 <= reader.available()) : (width += 1)
            try std.testing.expectEqual(
                @as(u64, @intCast(try reader.peek(@as(u8, width) * 5))),
                reader.peekBulkHuffmanFive(width),
            );
    }
}

test "Zstd reverse reader small read matches generic read" {
    const bytes = [_]u8{ 0x35, 0xa6, 0x59, 0xc3, 0xd0 };
    for (0..12) |prefix_bits| {
        var fast = try Reader.init(&bytes);
        if (prefix_bits != 0) try fast.skip(@intCast(prefix_bits));
        var generic = fast;
        var width: u4 = 1;
        while (width <= 11 and width <= fast.available()) : (width += 1) {
            try std.testing.expectEqual(try generic.read(width), try fast.readSmall(width));
        }
    }
}

test "Zstd reverse reader available small read matches bounded generic read" {
    const bytes = [_]u8{ 0x35, 0xa6, 0x59, 0xc3, 0xd0 };
    for (0..32) |consumed| {
        var fast = try Reader.init(&bytes);
        if (consumed != 0) try fast.skip(@intCast(consumed));
        var generic = fast;
        var width: u4 = 0;
        while (width <= 6) : (width += 1) {
            const expected_count: u4 = @intCast(@min(@as(usize, width), generic.available()));
            const expected_value = if (expected_count == 0) 0 else try generic.read(expected_count);
            const actual = try fast.readSmallAvailable(width);
            try std.testing.expectEqual(expected_count, actual.count);
            try std.testing.expectEqual(expected_value, actual.value);
            try std.testing.expectEqual(generic.available(), fast.available());
        }
    }
}

test "Zstd reverse sequence-field read matches generic read" {
    var bytes: [16]u8 = undefined;
    for (&bytes, 0..) |*byte, index| byte.* = @truncate(index * 73 + 19);
    bytes[bytes.len - 1] |= 0x80;

    // Independent reads cover every bit alignment, both the exact-width
    // fallback near the physical end and the 64-bit reservoir fast path.
    for (0..96) |consumed| {
        var positioned = try Reader.init(&bytes);
        if (consumed != 0) try positioned.skip(@intCast(consumed));
        const max_width = @min(@as(usize, 32), positioned.available());
        for (1..max_width + 1) |width| {
            var fast = positioned;
            var generic = positioned;
            try std.testing.expectEqual(
                try generic.read(@intCast(width)),
                try fast.readSequenceField(@intCast(width)),
            );
            try std.testing.expectEqual(generic.available(), fast.available());
        }
    }
    var reader = try Reader.init(&bytes);
    try std.testing.expectError(error.CorruptFrame, reader.readSequenceField(33));
}
