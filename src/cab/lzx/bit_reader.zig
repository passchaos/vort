const std = @import("std");

/// LZX consumes little-endian 16-bit words from the byte stream, then reads
/// bits most-significant first within each word.
pub const Reader = struct {
    input: []const u8,
    byte_offset: usize = 0,
    word: u16 = 0,
    bits_remaining: u5 = 0,

    pub fn readBits(self: *Reader, count: u5) !u32 {
        if (count == 0 or count > 17) return error.InvalidLzxStream;
        var needed: usize = count;
        var value: u32 = 0;
        while (needed != 0) {
            if (self.bits_remaining == 0) try self.loadWord();
            const take = @min(needed, @as(usize, self.bits_remaining));
            const shift: u4 = @intCast(@as(usize, self.bits_remaining) - take);
            const mask = (@as(u32, 1) << @intCast(take)) - 1;
            value = (value << @intCast(take)) | ((@as(u32, self.word) >> shift) & mask);
            self.bits_remaining -= @intCast(take);
            needed -= take;
        }
        return value;
    }

    pub fn alignToWord(self: *Reader) void {
        self.bits_remaining = 0;
    }

    /// Uncompressed LZX blocks consume 1..16 padding bits, never zero. At an
    /// exact word boundary this therefore discards one complete word.
    pub fn alignForUncompressed(self: *Reader) !void {
        if (self.bits_remaining == 0) try self.loadWord();
        self.bits_remaining = 0;
    }

    pub fn skipAlignedByte(self: *Reader) !void {
        if (self.bits_remaining != 0) return error.InvalidLzxStream;
        if (self.byte_offset >= self.input.len) return error.TruncatedFrame;
        self.byte_offset += 1;
    }

    pub fn readAlignedBytes(self: *Reader, output: []u8) !void {
        if (self.bits_remaining != 0) return error.InvalidLzxStream;
        if (self.byte_offset > self.input.len or output.len > self.input.len - self.byte_offset)
            return error.TruncatedFrame;
        @memcpy(output, self.input[self.byte_offset..][0..output.len]);
        self.byte_offset += output.len;
    }

    pub fn readAlignedInt(self: *Reader, comptime T: type) !T {
        var bytes: [@sizeOf(T)]u8 = undefined;
        try self.readAlignedBytes(&bytes);
        return std.mem.readInt(T, &bytes, .little);
    }

    fn loadWord(self: *Reader) !void {
        if (self.byte_offset > self.input.len or self.input.len - self.byte_offset < 2)
            return error.TruncatedFrame;
        self.word = std.mem.readInt(u16, self.input[self.byte_offset..][0..2], .little);
        self.byte_offset += 2;
        self.bits_remaining = 16;
    }
};

test "LZX word bit reader consumes little-endian words MSB first" {
    var reader = Reader{ .input = &.{ 0x34, 0x12, 0xcd, 0xab } };
    try std.testing.expectEqual(@as(u32, 0x1), try reader.readBits(4));
    try std.testing.expectEqual(@as(u32, 0x234), try reader.readBits(12));
    try std.testing.expectEqual(@as(u32, 0xabcd), try reader.readBits(16));
}
