const core = @import("../core.zig");

pub const Error = core.Error || error{InvalidBzip2Stream};

pub const BitReader = struct {
    bytes: []const u8,
    bit_offset: usize = 0,

    pub fn init(bytes: []const u8) BitReader {
        return .{ .bytes = bytes };
    }

    pub fn readBit(self: *BitReader) Error!u1 {
        const byte_offset = self.bit_offset / 8;
        if (byte_offset >= self.bytes.len) return error.TruncatedFrame;
        const byte = self.bytes[byte_offset];
        const shift: u3 = @intCast(7 - (self.bit_offset & 7));
        self.bit_offset += 1;
        return @truncate(byte >> shift);
    }

    pub fn readBits(self: *BitReader, count: u6) Error!u32 {
        if (count > 32) return error.InvalidBzip2Stream;
        var value: u32 = 0;
        for (0..count) |_| value = (value << 1) | try self.readBit();
        return value;
    }

    pub fn readMarker(self: *BitReader) Error!u64 {
        return (@as(u64, try self.readBits(24)) << 24) | try self.readBits(24);
    }

    pub fn alignToByte(self: *BitReader) void {
        self.bit_offset = (self.bit_offset + 7) & ~@as(usize, 7);
    }

    pub fn consumedBytes(self: BitReader) usize {
        return self.bit_offset / 8 + @intFromBool(self.bit_offset & 7 != 0);
    }
};

test "Bzip2 bit reader reads MSB-first fields" {
    var reader = BitReader.init(&.{ 0b1011_0010, 0b0110_0000 });
    try @import("std").testing.expectEqual(@as(u32, 0b101), try reader.readBits(3));
    try @import("std").testing.expectEqual(@as(u32, 0b10010), try reader.readBits(5));
    try @import("std").testing.expectEqual(@as(u32, 0b011), try reader.readBits(3));
    reader.alignToByte();
    try @import("std").testing.expectEqual(@as(usize, 2), reader.consumedBytes());
}
