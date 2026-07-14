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
        const result = self.peekBitsPadded(T, count);
        try self.skipBits(count);
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
};

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

test "BitReader peekBitsPadded uses zero padding past input" {
    var reader = BitReader.init(&.{0b0000_1011});
    try reader.skipBits(4);
    try std.testing.expectEqual(@as(u8, 0), reader.peekBitsPadded(u8, 8));
    try std.testing.expectError(error.TruncatedFrame, reader.readBits(u8, 5));
    try std.testing.expectEqual(@as(u4, 0), try reader.readBits(u4, 4));
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
