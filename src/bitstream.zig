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
        var result: T = 0;
        var shift: u6 = 0;
        while (shift < count) : (shift += 1) {
            if (self.byte_index >= self.input.len) return error.TruncatedFrame;
            const bit: T = @intCast((self.input[self.byte_index] >> self.bit_index) & 1);
            result |= bit << @intCast(shift);
            self.advanceOneBit();
        }
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
        var copy = self;
        var result: T = 0;
        var shift: u6 = 0;
        while (shift < count) : (shift += 1) {
            if (copy.byte_index >= copy.input.len) break;
            const bit: T = @intCast((copy.input[copy.byte_index] >> copy.bit_index) & 1);
            result |= bit << @intCast(shift);
            copy.advanceOneBit();
        }
        return result;
    }

    pub fn alignToByte(self: *BitReader) void {
        if (self.bit_index != 0) {
            self.bit_index = 0;
            self.byte_index += 1;
        }
    }

    fn advanceOneBit(self: *BitReader) void {
        self.bit_index +%= 1;
        if (self.bit_index == 0) self.byte_index += 1;
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
