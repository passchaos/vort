const std = @import("std");

pub const Reader = struct {
    input: []const u8,
    byte_offset: usize = 0,
    bit_offset: u4 = 0,

    pub fn readBits(self: *Reader, count: u5) !u32 {
        if (count > 24) return error.InvalidQuantumStream;
        var value: u32 = 0;
        var remaining: u5 = count;
        while (remaining != 0) : (remaining -= 1) {
            if (self.byte_offset >= self.input.len) return error.TruncatedFrame;
            value = (value << 1) |
                ((self.input[self.byte_offset] >> @intCast(7 - self.bit_offset)) & 1);
            self.bit_offset += 1;
            if (self.bit_offset == 8) {
                self.bit_offset = 0;
                self.byte_offset += 1;
            }
        }
        return value;
    }

    pub fn alignToByte(self: *Reader) void {
        if (self.bit_offset == 0) return;
        self.bit_offset = 0;
        self.byte_offset += 1;
    }

    pub fn readAlignedByte(self: *Reader) !u8 {
        if (self.bit_offset != 0) return error.InvalidQuantumStream;
        if (self.byte_offset >= self.input.len) return error.TruncatedFrame;
        const value = self.input[self.byte_offset];
        self.byte_offset += 1;
        return value;
    }
};

pub const Writer = struct {
    bytes: std.ArrayList(u8) = .empty,
    byte: u8 = 0,
    bits_used: u4 = 0,

    pub fn writeBits(self: *Writer, allocator: std.mem.Allocator, value: u32, count: u5) !void {
        if (count > 24 or value >> count != 0) return error.InvalidBlockPlan;
        var remaining: usize = count;
        while (remaining != 0) {
            remaining -= 1;
            try self.writeBit(allocator, @truncate(value >> @intCast(remaining)));
        }
    }

    pub fn writeBit(self: *Writer, allocator: std.mem.Allocator, bit: u1) !void {
        self.byte |= @as(u8, bit) << @intCast(7 - self.bits_used);
        self.bits_used += 1;
        if (self.bits_used == 8) {
            try self.bytes.append(allocator, self.byte);
            self.byte = 0;
            self.bits_used = 0;
        }
    }

    pub fn alignToByte(self: *Writer, allocator: std.mem.Allocator) !void {
        if (self.bits_used == 0) return;
        try self.bytes.append(allocator, self.byte);
        self.byte = 0;
        self.bits_used = 0;
    }
};
