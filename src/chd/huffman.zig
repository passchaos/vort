const std = @import("std");
const core_huffman = @import("../huffman.zig");
const format = @import("format.zig");

pub const Error = format.Error || std.mem.Allocator.Error;

/// CHD bitstreams are consumed most-significant bit first. Unlike libchdr's
/// padded 32-bit reservoir, this reader reports truncation at the exact read
/// which crosses the caller-owned input slice.
pub const BitReader = struct {
    bytes: []const u8,
    bit_offset: usize = 0,

    pub fn init(bytes: []const u8) BitReader {
        return .{ .bytes = bytes };
    }

    pub fn remainingBits(self: BitReader) usize {
        return self.bytes.len * 8 -| self.bit_offset;
    }

    pub fn read(self: *BitReader, bit_count: u8) Error!u32 {
        if (bit_count > 32) return error.InvalidChdMap;
        if (self.remainingBits() < bit_count) return error.TruncatedFrame;
        var value: u32 = 0;
        for (0..bit_count) |_| {
            const byte = self.bytes[self.bit_offset / 8];
            const shift: u3 = @intCast(7 - self.bit_offset % 8);
            value = (value << 1) | ((byte >> shift) & 1);
            self.bit_offset += 1;
        }
        return value;
    }

    pub fn byteOffset(self: BitReader) usize {
        return std.math.divCeil(usize, self.bit_offset, 8) catch unreachable;
    }
};

pub const BitWriter = struct {
    allocator: std.mem.Allocator,
    bytes: std.ArrayList(u8) = .empty,
    partial: u8 = 0,
    used_bits: u4 = 0,

    pub fn init(allocator: std.mem.Allocator) BitWriter {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *BitWriter) void {
        self.bytes.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn write(self: *BitWriter, value: u32, bit_count: u8) Error!void {
        if (bit_count > 32) return error.InvalidChdMap;
        var remaining = bit_count;
        while (remaining != 0) {
            remaining -= 1;
            const bit: u8 = @truncate(value >> @intCast(remaining));
            self.partial |= (bit & 1) << @intCast(7 - self.used_bits);
            self.used_bits += 1;
            if (self.used_bits == 8) {
                try self.bytes.append(self.allocator, self.partial);
                self.partial = 0;
                self.used_bits = 0;
            }
        }
    }

    pub fn finishAlloc(self: *BitWriter) Error![]u8 {
        if (self.used_bits != 0) {
            try self.bytes.append(self.allocator, self.partial);
            self.partial = 0;
            self.used_bits = 0;
        }
        return self.bytes.toOwnedSlice(self.allocator);
    }
};

pub fn Decoder(comptime symbol_count: usize, comptime max_bits: usize) type {
    if (symbol_count == 0 or max_bits == 0 or max_bits > 24)
        @compileError("unsupported CHD Huffman decoder dimensions");
    return struct {
        const Self = @This();
        const Symbol = std.math.IntFittingRange(0, symbol_count - 1);

        lengths: [symbol_count]u8 = @splat(0),
        starts: [max_bits + 1]u32 = @splat(0),
        counts: [max_bits + 1]usize = @splat(0),
        symbol_offsets: [max_bits + 1]usize = @splat(0),
        symbols: [symbol_count]Symbol = @splat(0),

        pub fn assign(self: *Self) Error!void {
            self.starts = @splat(0);
            self.counts = @splat(0);
            self.symbol_offsets = @splat(0);
            for (self.lengths) |length| {
                if (length > max_bits) return error.InvalidHuffmanCode;
                if (length != 0) self.counts[length] += 1;
            }
            var current_start: u32 = 0;
            var length = max_bits;
            while (length != 0) : (length -= 1) {
                const sum = std.math.add(
                    u32,
                    current_start,
                    @intCast(self.counts[length]),
                ) catch return error.InvalidHuffmanCode;
                const next_start = sum >> 1;
                if (length != 1 and next_start * 2 != sum)
                    return error.InvalidHuffmanCode;
                self.starts[length] = current_start;
                if (self.counts[length] != 0 and
                    current_start + self.counts[length] > (@as(u32, 1) << @intCast(length)))
                    return error.InvalidHuffmanCode;
                current_start = next_start;
            }

            var next_offset: usize = 0;
            for (1..max_bits + 1) |bits| {
                self.symbol_offsets[bits] = next_offset;
                next_offset += self.counts[bits];
            }
            var cursor = self.symbol_offsets;
            for (self.lengths, 0..) |bits, symbol| {
                if (bits == 0) continue;
                self.symbols[cursor[bits]] = @intCast(symbol);
                cursor[bits] += 1;
            }
        }

        pub fn decode(self: Self, reader: *BitReader) Error!usize {
            var code: u32 = 0;
            for (1..max_bits + 1) |bits| {
                code = (code << 1) | try reader.read(1);
                const start = self.starts[bits];
                if (code < start) continue;
                const index = code - start;
                if (index < self.counts[bits])
                    return self.symbols[self.symbol_offsets[bits] + index];
            }
            return error.InvalidHuffmanCode;
        }

        /// Imports the direct/RLE tree representation used by CHD's v5 map.
        pub fn importRle(self: *Self, reader: *BitReader) Error!void {
            const encoded_bits: u8 = if (max_bits >= 16)
                5
            else if (max_bits >= 8)
                4
            else
                3;
            var node: usize = 0;
            while (node < symbol_count) {
                var node_bits: u8 = @intCast(try reader.read(encoded_bits));
                if (node_bits != 1) {
                    self.lengths[node] = node_bits;
                    node += 1;
                    continue;
                }
                node_bits = @intCast(try reader.read(encoded_bits));
                if (node_bits == 1) {
                    self.lengths[node] = 1;
                    node += 1;
                    continue;
                }
                const repeat = 3 + try reader.read(encoded_bits);
                if (repeat > symbol_count - node)
                    return error.InvalidHuffmanCode;
                @memset(self.lengths[node..][0..repeat], node_bits);
                node += repeat;
            }
            try self.assign();
        }

        /// Imports the two-level Huffman representation used by `huff`
        /// compressed CHD hunks.
        pub fn importHuffman(self: *Self, reader: *BitReader) Error!void {
            var small: Decoder(24, 6) = .{};
            small.lengths[0] = @intCast(try reader.read(3));
            const start = try reader.read(3) + 1;
            var terminal: u32 = 0;
            for (1..24) |index| {
                if (index < start or terminal == 7) {
                    small.lengths[index] = 0;
                } else {
                    terminal = try reader.read(3);
                    small.lengths[index] = if (terminal == 7)
                        0
                    else
                        @intCast(terminal);
                }
            }
            try small.assign();

            const remaining_symbols = symbol_count -| 9;
            const full_count_bits: u8 = if (remaining_symbols == 0)
                0
            else
                @intCast(std.math.log2_int_ceil(usize, remaining_symbols + 1));
            var symbol: usize = 0;
            var last_length: u8 = 0;
            while (symbol < symbol_count) {
                const value = try small.decode(reader);
                if (value != 0) {
                    if (value - 1 > max_bits) return error.InvalidHuffmanCode;
                    last_length = @intCast(value - 1);
                    self.lengths[symbol] = last_length;
                    symbol += 1;
                } else {
                    var repeat = 2 + try reader.read(3);
                    if (repeat == 9)
                        repeat += try reader.read(full_count_bits);
                    if (repeat > symbol_count - symbol)
                        return error.InvalidHuffmanCode;
                    @memset(self.lengths[symbol..][0..repeat], last_length);
                    symbol += repeat;
                }
            }
            try self.assign();
        }
    };
}

pub const MapDecoder = Decoder(16, 8);
pub const ByteDecoder = Decoder(256, 16);

pub fn decodeHunk(input: []const u8, output: []u8) Error!void {
    var reader = BitReader.init(input);
    var decoder: ByteDecoder = .{};
    try decoder.importHuffman(&reader);
    for (output) |*byte|
        byte.* = @intCast(try decoder.decode(&reader));
}

/// Encode a CHD `huff` hunk. The wire representation first describes the
/// 256-symbol byte tree through a second, 24-symbol Huffman tree and then
/// writes the hunk bytes with CHD's reverse-canonical codes.
pub fn encodeHunkAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
) Error![]u8 {
    var frequencies = [_]u32{0} ** 256;
    for (input) |byte| frequencies[byte] += 1;
    const lengths = core_huffman.treeCodeLengths(256, &frequencies, 15);
    const codes = try canonicalCodes(256, 15, &lengths);

    const TreeToken = struct {
        symbol: u8,
        repeat_extra: u8 = 0,
    };
    var tokens: [256]TreeToken = undefined;
    var token_count: usize = 0;
    var small_frequencies = [_]u32{0} ** 24;
    var first: usize = 0;
    while (first < lengths.len) {
        const length = lengths[first];
        var end = first + 1;
        while (end < lengths.len and lengths[end] == length) : (end += 1) {}
        const run = end - first;
        const literal_symbol: u8 = @as(u8, length) + 1;
        tokens[token_count] = .{ .symbol = literal_symbol };
        token_count += 1;
        small_frequencies[literal_symbol] += 1;
        const additional = run - 1;
        if (additional == 1) {
            tokens[token_count] = .{ .symbol = literal_symbol };
            token_count += 1;
            small_frequencies[literal_symbol] += 1;
        } else if (additional >= 2) {
            tokens[token_count] = .{
                .symbol = 0,
                .repeat_extra = @intCast(additional - 2),
            };
            token_count += 1;
            small_frequencies[0] += 1;
        }
        first = end;
    }

    const small_lengths = core_huffman.treeCodeLengths(
        24,
        &small_frequencies,
        6,
    );
    const small_codes = try canonicalCodes(24, 6, &small_lengths);
    var first_non_zero: usize = 24;
    var last_non_zero: usize = 0;
    for (small_lengths[1..], 1..) |length, symbol| {
        if (length == 0) continue;
        first_non_zero = @min(first_non_zero, symbol);
        last_non_zero = symbol;
    }
    if (first_non_zero == 24) return error.InvalidHuffmanCode;
    first_non_zero = @min(first_non_zero, 8);

    var writer = BitWriter.init(allocator);
    defer writer.deinit();
    try writer.write(small_lengths[0], 3);
    try writer.write(@intCast(first_non_zero - 1), 3);
    for (small_lengths[first_non_zero .. last_non_zero + 1]) |length|
        try writer.write(length, 3);
    try writer.write(7, 3);

    for (tokens[0..token_count]) |token| {
        const bits = small_lengths[token.symbol];
        if (bits == 0) return error.InvalidHuffmanCode;
        try writer.write(small_codes[token.symbol], bits);
        if (token.symbol == 0) {
            if (token.repeat_extra < 7) {
                try writer.write(token.repeat_extra, 3);
            } else {
                try writer.write(7, 3);
                try writer.write(token.repeat_extra - 7, 8);
            }
        }
    }
    for (input) |byte| {
        const bits = lengths[byte];
        if (bits == 0) return error.InvalidHuffmanCode;
        try writer.write(codes[byte], bits);
    }
    return writer.finishAlloc();
}

fn canonicalCodes(
    comptime symbol_count: usize,
    comptime max_bits: usize,
    lengths: *const [symbol_count]u4,
) Error![symbol_count]u32 {
    var counts = [_]u32{0} ** (max_bits + 1);
    for (lengths) |length| {
        if (length > max_bits) return error.InvalidHuffmanCode;
        if (length != 0) counts[length] += 1;
    }
    var starts = [_]u32{0} ** (max_bits + 1);
    var current: u32 = 0;
    var length = max_bits;
    while (length != 0) : (length -= 1) {
        const sum = std.math.add(u32, current, counts[length]) catch
            return error.InvalidHuffmanCode;
        const next = sum >> 1;
        if (length != 1 and next * 2 != sum)
            return error.InvalidHuffmanCode;
        starts[length] = current;
        current = next;
    }
    var codes = [_]u32{0} ** symbol_count;
    for (lengths, 0..) |bits, symbol| {
        if (bits == 0) continue;
        codes[symbol] = starts[bits];
        starts[bits] += 1;
    }
    return codes;
}

test "CHD MSB bit reader and writer round trip" {
    var writer = BitWriter.init(std.testing.allocator);
    defer writer.deinit();
    try writer.write(0b101, 3);
    try writer.write(0b11110000, 8);
    try writer.write(1, 1);
    const bytes = try writer.finishAlloc();
    defer std.testing.allocator.free(bytes);
    try std.testing.expectEqualSlices(u8, &.{ 0xbe, 0x10 }, bytes);

    var reader = BitReader.init(bytes);
    try std.testing.expectEqual(@as(u32, 0b101), try reader.read(3));
    try std.testing.expectEqual(@as(u32, 0b11110000), try reader.read(8));
    try std.testing.expectEqual(@as(u32, 1), try reader.read(1));
}

test "CHD reverse canonical Huffman assignment" {
    var decoder: Decoder(4, 3) = .{};
    decoder.lengths = .{ 2, 1, 3, 3 };
    try decoder.assign();
    // Reverse-length assignment produces symbol 1 = 1, symbol 0 = 01,
    // and symbols 2/3 = 000/001.
    var reader = BitReader.init(&.{ 0b10100000, 0b10000000 });
    try std.testing.expectEqual(@as(usize, 1), try decoder.decode(&reader));
    try std.testing.expectEqual(@as(usize, 0), try decoder.decode(&reader));
    try std.testing.expectEqual(@as(usize, 2), try decoder.decode(&reader));
    try std.testing.expectEqual(@as(usize, 3), try decoder.decode(&reader));
}

test "CHD Huffman encoder round trips varied byte alphabets" {
    const allocator = std.testing.allocator;
    var broad: [4096]u8 = undefined;
    for (&broad, 0..) |*byte, index| byte.* = @truncate(index * 37 + index / 11);
    const cases = [_][]const u8{
        "A" ** 4096,
        ("CHD Huffman structured bytes\n" ** 256)[0..4096],
        &broad,
    };
    for (cases) |input| {
        const encoded = try encodeHunkAlloc(allocator, input);
        defer allocator.free(encoded);
        const decoded = try allocator.alloc(u8, input.len);
        defer allocator.free(decoded);
        try decodeHunk(encoded, decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
    }
}
