const std = @import("std");

pub const Writer = struct {
    bytes: std.ArrayList(u8) = .empty,
    word: u16 = 0,
    bit_count: u5 = 0,

    pub fn writeBits(
        self: *Writer,
        allocator: std.mem.Allocator,
        value: anytype,
        count: u5,
    ) !void {
        if (count > 17 or @as(u64, @intCast(value)) >> count != 0) return error.InvalidBlockPlan;
        var remaining: usize = count;
        while (remaining != 0) {
            remaining -= 1;
            self.word = (self.word << 1) |
                @as(u1, @truncate(@as(u64, @intCast(value)) >> @intCast(remaining)));
            self.bit_count += 1;
            if (self.bit_count == 16) try self.flushWord(allocator);
        }
    }

    /// LZX uncompressed blocks discard 1..16 bits, so an already aligned
    /// header would require a complete padding word rather than zero bits.
    pub fn alignForUncompressed(self: *Writer, allocator: std.mem.Allocator) !void {
        if (self.bit_count == 0) {
            try appendU16(allocator, &self.bytes, 0);
        } else {
            self.word <<= @intCast(16 - @as(usize, self.bit_count));
            try self.flushWord(allocator);
        }
    }

    pub fn flushWord(self: *Writer, allocator: std.mem.Allocator) !void {
        try appendU16(allocator, &self.bytes, self.word);
        self.word = 0;
        self.bit_count = 0;
    }

    pub fn finish(self: *Writer, allocator: std.mem.Allocator) !void {
        if (self.bit_count == 0) return;
        self.word <<= @intCast(16 - @as(usize, self.bit_count));
        try self.flushWord(allocator);
    }
};

pub fn appendU16(allocator: std.mem.Allocator, out: *std.ArrayList(u8), value: u16) !void {
    var bytes: [2]u8 = undefined;
    std.mem.writeInt(u16, &bytes, value, .little);
    try out.appendSlice(allocator, &bytes);
}

pub fn appendU32(allocator: std.mem.Allocator, out: *std.ArrayList(u8), value: u32) !void {
    var bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &bytes, value, .little);
    try out.appendSlice(allocator, &bytes);
}
