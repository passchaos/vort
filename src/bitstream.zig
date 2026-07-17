const std = @import("std");
const core = @import("core.zig");

pub const Error = core.Error;

pub const BitReader = struct {
    input: []const u8,
    byte_index: usize = 0,
    bit_index: u3 = 0,

    pub fn init(input: []const u8) BitReader {
        return .{ .input = input };
    }

    pub fn bitPosition(self: BitReader) usize {
        return self.byte_index * 8 + self.bit_index;
    }

    pub fn byteOffset(self: BitReader) usize {
        return self.byte_index + @intFromBool(self.bit_index != 0);
    }

    pub fn readBits(self: *BitReader, comptime T: type, count: u6) Error!T {
        if (count > @bitSizeOf(T)) return error.CorruptFrame;
        if (!self.hasBits(count)) return error.TruncatedFrame;
        const result = self.peekBitsPadded(T, count);
        self.advanceBitsAssumeAvailable(count);
        return result;
    }

    pub fn peekBits(self: BitReader, comptime T: type, count: u6) Error!T {
        var copy = self;
        return copy.readBits(T, count);
    }

    pub fn skipBits(self: *BitReader, count: u6) Error!void {
        if (self.byte_index > self.input.len) return error.TruncatedFrame;
        const remaining_bits = (self.input.len - self.byte_index) * 8 - @as(usize, self.bit_index);
        if (@as(usize, count) > remaining_bits) return error.TruncatedFrame;

        self.advanceBitsAssumeAvailable(count);
    }

    pub fn hasBits(self: BitReader, count: u6) bool {
        if (self.byte_index > self.input.len) return false;
        const remaining_bits = (self.input.len - self.byte_index) * 8 - @as(usize, self.bit_index);
        return @as(usize, count) <= remaining_bits;
    }

    pub fn advanceBitsAssumeAvailable(self: *BitReader, count: u6) void {
        const new_bit_index = @as(usize, self.bit_index) + count;
        self.byte_index += new_bit_index / 8;
        self.bit_index = @intCast(new_bit_index % 8);
    }

    pub fn peekBitsPadded(self: BitReader, comptime T: type, count: u6) T {
        std.debug.assert(count <= @bitSizeOf(T));
        if (count == 0 or self.byte_index >= self.input.len) return 0;

        // Deflate stores bits LSB-first, so a little-endian byte window shifted
        // by bit_index yields the requested bit sequence directly. Missing
        // bytes are intentionally treated as zero padding for fast lookup
        // probes; readBits/skipBits performs the strict availability check.
        const requested_bits = @as(usize, self.bit_index) + @as(usize, count);
        const available_bytes = self.input.len - self.byte_index;
        if (requested_bits <= 16 and available_bytes >= 2) {
            const window = std.mem.readInt(u16, self.input[self.byte_index..][0..2], .little) >> self.bit_index;
            const mask = (@as(u32, 1) << @intCast(count)) - 1;
            return @intCast(@as(u32, window) & mask);
        }
        if (requested_bits <= 32 and available_bytes >= 4) {
            const window = std.mem.readInt(u32, self.input[self.byte_index..][0..4], .little) >> self.bit_index;
            const mask = (@as(u64, 1) << @intCast(count)) - 1;
            return @intCast(@as(u64, window) & mask);
        }

        const requested_bytes = (requested_bits + 7) / 8;
        const bytes_to_read = @min(requested_bytes, available_bytes);
        var window: u128 = 0;
        var i: usize = 0;
        while (i < bytes_to_read) : (i += 1) {
            window |= @as(u128, self.input[self.byte_index + i]) << @intCast(i * 8);
        }
        const shifted = window >> self.bit_index;
        const mask = (@as(u128, 1) << @intCast(count)) - 1;
        return @intCast(shifted & mask);
    }

    pub fn alignToByte(self: *BitReader) void {
        if (self.bit_index != 0) {
            self.bit_index = 0;
            self.byte_index += 1;
        }
    }

    pub fn readAlignedBytes(self: *BitReader, output: []u8) Error!void {
        if (self.bit_index != 0) return error.CorruptFrame;
        if (self.byte_index > self.input.len or self.input.len - self.byte_index < output.len) return error.TruncatedFrame;
        @memcpy(output, self.input[self.byte_index..][0..output.len]);
        self.byte_index += output.len;
    }

    pub fn readAlignedInt(self: *BitReader, comptime T: type, endian: std.builtin.Endian) Error!T {
        var bytes: [@sizeOf(T)]u8 = undefined;
        try self.readAlignedBytes(&bytes);
        return std.mem.readInt(T, &bytes, endian);
    }
};

pub const BufferedBitReader = struct {
    input: []const u8,
    /// Next byte not yet staged in `bit_buffer`.
    byte_index: usize = 0,
    /// Low `bit_count` bits are the unread bitstream, in DEFLATE LSB-first
    /// order. Keeping this small reservoir avoids reloading the same two or
    /// four input bytes for every Huffman lookup in contiguous raw/zlib/gzip
    /// decode hot paths.
    bit_buffer: u64 = 0,
    bit_count: usize = 0,
    consumed_bits: usize = 0,

    pub fn init(input: []const u8) BufferedBitReader {
        return .{ .input = input };
    }

    pub fn bitPosition(self: BufferedBitReader) usize {
        return self.consumed_bits;
    }

    pub fn byteOffset(self: BufferedBitReader) usize {
        return (self.consumed_bits + 7) / 8;
    }

    pub fn readBits(self: *BufferedBitReader, comptime T: type, count: u6) Error!T {
        if (count > @bitSizeOf(T)) return error.CorruptFrame;
        if (!self.hasBits(count)) return error.TruncatedFrame;
        const result = self.peekBitsPadded(T, count);
        self.advanceBitsAssumeAvailable(count);
        return result;
    }

    pub fn peekBits(self: *BufferedBitReader, comptime T: type, count: u6) Error!T {
        if (count > @bitSizeOf(T)) return error.CorruptFrame;
        if (!self.hasBits(count)) return error.TruncatedFrame;
        return self.peekBitsPadded(T, count);
    }

    pub fn skipBits(self: *BufferedBitReader, count: u6) Error!void {
        if (!self.hasBits(count)) return error.TruncatedFrame;
        self.advanceBitsAssumeAvailable(count);
    }

    pub fn hasBits(self: BufferedBitReader, count: u6) bool {
        const remaining_staged = self.bit_count;
        const remaining_input_bits = if (self.byte_index <= self.input.len)
            (self.input.len - self.byte_index) * 8
        else
            0;
        return @as(usize, count) <= remaining_staged + remaining_input_bits;
    }

    pub fn advanceBitsAssumeAvailable(self: *BufferedBitReader, count: u6) void {
        self.fill(count);
        std.debug.assert(self.bit_count >= count);
        self.bit_buffer >>= @intCast(count);
        self.bit_count -= count;
        self.consumed_bits += count;
    }

    pub fn peekBitsPadded(self: *BufferedBitReader, comptime T: type, count: u6) T {
        std.debug.assert(count <= @bitSizeOf(T));
        if (count == 0) return 0;
        self.fill(count);
        const mask = (@as(u64, 1) << @intCast(count)) - 1;
        return @intCast(self.bit_buffer & mask);
    }

    pub fn alignToByte(self: *BufferedBitReader) void {
        const bit_index: u3 = @intCast(self.consumed_bits % 8);
        if (bit_index != 0) {
            const padding: usize = 8 - @as(usize, bit_index);
            const staged_drop = @min(padding, self.bit_count);
            self.bit_buffer >>= @intCast(staged_drop);
            self.bit_count -= staged_drop;
            // Match `BitReader.alignToByte`: alignment itself is permissive and
            // later aligned reads report truncation. This matters for malformed
            // stored-block tails, where no real padding byte may remain.
            self.consumed_bits += padding;
            if (staged_drop < padding) {
                self.bit_buffer = 0;
                self.bit_count = 0;
            }
        }
    }

    pub fn readAlignedBytes(self: *BufferedBitReader, output: []u8) Error!void {
        if (self.consumed_bits % 8 != 0) return error.CorruptFrame;
        const offset = self.byteOffset();
        if (offset > self.input.len or self.input.len - offset < output.len) return error.TruncatedFrame;
        @memcpy(output, self.input[offset..][0..output.len]);
        self.consumed_bits += output.len * 8;
        self.byte_index = offset + output.len;
        self.bit_buffer = 0;
        self.bit_count = 0;
    }

    pub fn readAlignedInt(self: *BufferedBitReader, comptime T: type, endian: std.builtin.Endian) Error!T {
        var bytes: [@sizeOf(T)]u8 = undefined;
        try self.readAlignedBytes(&bytes);
        return std.mem.readInt(T, &bytes, endian);
    }

    fn fill(self: *BufferedBitReader, requested_bits: usize) void {
        std.debug.assert(requested_bits <= 63);
        while (self.bit_count < requested_bits and self.byte_index < self.input.len and self.bit_count <= 56) {
            self.bit_buffer |= @as(u64, self.input[self.byte_index]) << @intCast(self.bit_count);
            self.bit_count += 8;
            self.byte_index += 1;
        }
    }
};

pub const ChunkedBitReader = struct {
    chunks: []const []const u8,
    byte_index: usize = 0,
    bit_index: u3 = 0,
    total_len: usize = 0,

    pub fn init(chunks: []const []const u8) Error!ChunkedBitReader {
        return initAt(chunks, 0);
    }

    pub fn initAt(chunks: []const []const u8, byte_offset: usize) Error!ChunkedBitReader {
        const total = try chunksTotalLen(chunks);
        if (byte_offset > total) return error.TruncatedFrame;
        return .{
            .chunks = chunks,
            .byte_index = byte_offset,
            .total_len = total,
        };
    }

    pub fn bitPosition(self: ChunkedBitReader) usize {
        return self.byte_index * 8 + self.bit_index;
    }

    pub fn byteOffset(self: ChunkedBitReader) usize {
        return self.byte_index + @intFromBool(self.bit_index != 0);
    }

    pub fn readBits(self: *ChunkedBitReader, comptime T: type, count: u6) Error!T {
        if (count > @bitSizeOf(T)) return error.CorruptFrame;
        if (!self.hasBits(count)) return error.TruncatedFrame;
        const result = self.peekBitsPadded(T, count);
        self.advanceBitsAssumeAvailable(count);
        return result;
    }

    pub fn peekBits(self: ChunkedBitReader, comptime T: type, count: u6) Error!T {
        var copy = self;
        return copy.readBits(T, count);
    }

    pub fn skipBits(self: *ChunkedBitReader, count: u6) Error!void {
        if (self.byte_index > self.total_len) return error.TruncatedFrame;
        const remaining_bits = (self.total_len - self.byte_index) * 8 - @as(usize, self.bit_index);
        if (@as(usize, count) > remaining_bits) return error.TruncatedFrame;

        self.advanceBitsAssumeAvailable(count);
    }

    pub fn hasBits(self: ChunkedBitReader, count: u6) bool {
        if (self.byte_index > self.total_len) return false;
        const remaining_bits = (self.total_len - self.byte_index) * 8 - @as(usize, self.bit_index);
        return @as(usize, count) <= remaining_bits;
    }

    pub fn advanceBitsAssumeAvailable(self: *ChunkedBitReader, count: u6) void {
        const new_bit_index = @as(usize, self.bit_index) + count;
        self.byte_index += new_bit_index / 8;
        self.bit_index = @intCast(new_bit_index % 8);
    }

    pub fn peekBitsPadded(self: ChunkedBitReader, comptime T: type, count: u6) T {
        std.debug.assert(count <= @bitSizeOf(T));
        if (count == 0 or self.byte_index >= self.total_len) return 0;

        const requested_bits = @as(usize, self.bit_index) + @as(usize, count);
        const requested_bytes = (requested_bits + 7) / 8;
        var window: u128 = 0;
        var i: usize = 0;
        while (i < requested_bytes) : (i += 1) {
            const byte = self.byteAt(self.byte_index + i) orelse break;
            window |= @as(u128, byte) << @intCast(i * 8);
        }
        const shifted = window >> self.bit_index;
        const mask = (@as(u128, 1) << @intCast(count)) - 1;
        return @intCast(shifted & mask);
    }

    pub fn alignToByte(self: *ChunkedBitReader) void {
        if (self.bit_index != 0) {
            self.bit_index = 0;
            self.byte_index += 1;
        }
    }

    pub fn readAlignedBytes(self: *ChunkedBitReader, output: []u8) Error!void {
        if (self.bit_index != 0) return error.CorruptFrame;
        if (self.byte_index > self.total_len or self.total_len - self.byte_index < output.len) return error.TruncatedFrame;
        for (output, 0..) |*byte, i| {
            byte.* = self.byteAt(self.byte_index + i) orelse return error.TruncatedFrame;
        }
        self.byte_index += output.len;
    }

    pub fn readAlignedInt(self: *ChunkedBitReader, comptime T: type, endian: std.builtin.Endian) Error!T {
        var bytes: [@sizeOf(T)]u8 = undefined;
        try self.readAlignedBytes(&bytes);
        return std.mem.readInt(T, &bytes, endian);
    }

    fn byteAt(self: ChunkedBitReader, absolute_offset: usize) ?u8 {
        var remaining = absolute_offset;
        for (self.chunks) |chunk| {
            if (remaining < chunk.len) return chunk[remaining];
            remaining -= chunk.len;
        }
        return null;
    }
};

fn chunksTotalLen(chunks: []const []const u8) Error!usize {
    var total: usize = 0;
    for (chunks) |chunk| {
        total = std.math.add(usize, total, chunk.len) catch return error.IntegerOverflow;
    }
    return total;
}

test "buffered bit reader matches scalar reader across mixed operations" {
    const input = [_]u8{ 0b1010_1101, 0b0111_0010, 0b1100_0001, 0b0001_1110, 0b0101_1010, 0b1110_0110 };
    var scalar = BitReader.init(&input);
    var buffered = BufferedBitReader.init(&input);

    inline for (.{ 3, 5, 9, 1 }) |count| {
        try std.testing.expectEqual(try scalar.readBits(u16, count), try buffered.readBits(u16, count));
        try std.testing.expectEqual(scalar.bitPosition(), buffered.bitPosition());
        try std.testing.expectEqual(scalar.byteOffset(), buffered.byteOffset());
    }

    const scalar_peek = try scalar.peekBits(u8, 5);
    const buffered_peek = try buffered.peekBits(u8, 5);
    try std.testing.expectEqual(scalar_peek, buffered_peek);
    try std.testing.expectEqual(scalar.bitPosition(), buffered.bitPosition());
    try std.testing.expectEqual(scalar.byteOffset(), buffered.byteOffset());

    scalar.alignToByte();
    buffered.alignToByte();
    try std.testing.expectEqual(scalar.bitPosition(), buffered.bitPosition());
    try std.testing.expectEqual(scalar.byteOffset(), buffered.byteOffset());

    var scalar_bytes: [2]u8 = undefined;
    var buffered_bytes: [2]u8 = undefined;
    try scalar.readAlignedBytes(&scalar_bytes);
    try buffered.readAlignedBytes(&buffered_bytes);
    try std.testing.expectEqualSlices(u8, &scalar_bytes, &buffered_bytes);
    try std.testing.expectEqual(scalar.bitPosition(), buffered.bitPosition());
    try std.testing.expectEqual(scalar.byteOffset(), buffered.byteOffset());

    try std.testing.expectEqual(try scalar.readBits(u8, 4), try buffered.readBits(u8, 4));
    try std.testing.expectEqual(scalar.bitPosition(), buffered.bitPosition());
    try std.testing.expectEqual(scalar.byteOffset(), buffered.byteOffset());
}

pub const BitWriter = struct {
    bytes: std.ArrayList(u8) = .empty,
    scratch: u8 = 0,
    bit_index: u3 = 0,

    pub fn deinit(self: *BitWriter, allocator: std.mem.Allocator) void {
        self.bytes.deinit(allocator);
        self.* = undefined;
    }

    pub fn writeBits(self: *BitWriter, allocator: std.mem.Allocator, bits: u64, count: u6) !void {
        if (count > 56) return error.CorruptFrame;
        var i: u6 = 0;
        while (i < count) : (i += 1) {
            const bit: u8 = @intCast((bits >> @intCast(i)) & 1);
            self.scratch |= bit << self.bit_index;
            self.bit_index +%= 1;
            if (self.bit_index == 0) {
                try self.bytes.append(allocator, self.scratch);
                self.scratch = 0;
            }
        }
    }

    pub fn alignToByte(self: *BitWriter, allocator: std.mem.Allocator) !void {
        if (self.bit_index != 0) {
            try self.bytes.append(allocator, self.scratch);
            self.scratch = 0;
            self.bit_index = 0;
        }
    }

    pub fn toOwnedSlice(self: *BitWriter, allocator: std.mem.Allocator) ![]u8 {
        try self.alignToByte(allocator);
        return self.bytes.toOwnedSlice(allocator);
    }
};

test "BitReader consumes LSB-first deflate bits" {
    var reader = BitReader.init(&.{ 0b1010_1101, 0b0000_0011 });
    try std.testing.expectEqual(@as(u3, 0b101), try reader.readBits(u3, 3));
    try std.testing.expectEqual(@as(u5, 0b10101), try reader.readBits(u5, 5));
    try std.testing.expectEqual(@as(u2, 0b11), try reader.readBits(u2, 2));
    try std.testing.expectEqual(@as(usize, 10), reader.bitPosition());
    reader.alignToByte();
    try std.testing.expectEqual(@as(usize, 2), reader.byteOffset());
}

test "BitReader skipBits advances without reading values" {
    var reader = BitReader.init(&.{ 0b1010_1101, 0b0000_0011 });
    try reader.skipBits(3);
    try std.testing.expectEqual(@as(usize, 3), reader.bitPosition());
    try std.testing.expectEqual(@as(u5, 0b10101), try reader.readBits(u5, 5));
    try reader.skipBits(2);
    try std.testing.expectEqual(@as(usize, 10), reader.bitPosition());
    try reader.skipBits(6);
    try std.testing.expectEqual(@as(usize, 16), reader.bitPosition());
    try std.testing.expectError(error.TruncatedFrame, reader.skipBits(1));
}

test "BitReader hasBits and unchecked advance match skipBits" {
    var reader = BitReader.init(&.{ 0b1010_1101, 0b0000_0011 });
    try std.testing.expect(reader.hasBits(10));
    reader.advanceBitsAssumeAvailable(10);
    try std.testing.expectEqual(@as(usize, 10), reader.bitPosition());
    try std.testing.expect(reader.hasBits(6));
    try std.testing.expect(!reader.hasBits(7));
}

test "BitReader peekBitsPadded uses zero padding past input" {
    var reader = BitReader.init(&.{0b0000_1011});
    try reader.skipBits(4);
    try std.testing.expectEqual(@as(u8, 0), reader.peekBitsPadded(u8, 8));
    try std.testing.expectError(error.TruncatedFrame, reader.readBits(u8, 5));
    try std.testing.expectEqual(@as(u4, 0), try reader.readBits(u4, 4));
}

test "ChunkedBitReader matches contiguous bit and aligned-byte reads" {
    const bytes = [_]u8{ 0b1010_1101, 0b0000_0011, 0x34, 0x12, 0xaa, 0xbb };
    const chunks = [_][]const u8{
        bytes[0..1],
        bytes[1..3],
        bytes[3..],
    };
    var chunked = try ChunkedBitReader.init(&chunks);
    try std.testing.expectEqual(@as(u3, 0b101), try chunked.readBits(u3, 3));
    try std.testing.expectEqual(@as(u5, 0b10101), try chunked.readBits(u5, 5));
    try std.testing.expectEqual(@as(u2, 0b11), try chunked.readBits(u2, 2));
    try std.testing.expectEqual(@as(usize, 10), chunked.bitPosition());
    chunked.alignToByte();
    try std.testing.expectEqual(@as(usize, 2), chunked.byteOffset());
    try std.testing.expectEqual(@as(u16, 0x1234), try chunked.readAlignedInt(u16, .little));
    var tail: [2]u8 = undefined;
    try chunked.readAlignedBytes(&tail);
    try std.testing.expectEqualSlices(u8, &.{ 0xaa, 0xbb }, &tail);
    try std.testing.expectError(error.TruncatedFrame, chunked.readBits(u1, 1));

    var offset_reader = try ChunkedBitReader.initAt(&chunks, 2);
    try std.testing.expectEqual(@as(u16, 0x1234), try offset_reader.readAlignedInt(u16, .little));
    try std.testing.expectError(error.TruncatedFrame, ChunkedBitReader.initAt(&chunks, bytes.len + 1));
}

test "ChunkedBitReader hasBits and unchecked advance match skipBits" {
    const bytes = [_]u8{ 0b1010_1101, 0b0000_0011 };
    const chunks = [_][]const u8{ bytes[0..1], bytes[1..] };
    var reader = try ChunkedBitReader.init(&chunks);
    try std.testing.expect(reader.hasBits(10));
    reader.advanceBitsAssumeAvailable(10);
    try std.testing.expectEqual(@as(usize, 10), reader.bitPosition());
    try std.testing.expect(reader.hasBits(6));
    try std.testing.expect(!reader.hasBits(7));
}

test "BitWriter emits LSB-first bytes readable by BitReader" {
    var writer = BitWriter{};
    defer writer.deinit(std.testing.allocator);
    try writer.writeBits(std.testing.allocator, 0b101, 3);
    try writer.writeBits(std.testing.allocator, 0b10101, 5);
    try writer.writeBits(std.testing.allocator, 0b11, 2);
    const bytes = try writer.toOwnedSlice(std.testing.allocator);
    defer std.testing.allocator.free(bytes);
    try std.testing.expectEqualSlices(u8, &.{ 0b1010_1101, 0b0000_0011 }, bytes);
}
