const std = @import("std");

pub const Crc32 = struct {
    value: u32 = 0xffff_ffff,

    pub fn updateByte(self: *Crc32, byte: u8) void {
        const index: u8 = @truncate((self.value >> 24) ^ byte);
        self.value = (self.value << 8) ^ table[index];
    }

    pub fn updateRepeat(self: *Crc32, byte: u8, count: usize) void {
        for (0..count) |_| self.updateByte(byte);
    }

    pub fn digest(self: Crc32) u32 {
        return ~self.value;
    }

    pub fn hash(input: []const u8) u32 {
        var state = Crc32{};
        for (input) |byte| state.updateByte(byte);
        return state.digest();
    }
};

const table = makeTable();

fn makeTable() [256]u32 {
    @setEvalBranchQuota(4096);
    var result: [256]u32 = undefined;
    for (&result, 0..) |*entry, index| {
        var value: u32 = @as(u32, @intCast(index)) << 24;
        for (0..8) |_| value = if (value & 0x8000_0000 != 0)
            (value << 1) ^ 0x04c1_1db7
        else
            value << 1;
        entry.* = value;
    }
    return result;
}

test "Bzip2 CRC matches the standard check vector" {
    try std.testing.expectEqual(@as(u32, 0xfc89_1918), Crc32.hash("123456789"));
}
