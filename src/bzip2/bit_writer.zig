const std = @import("std");

pub const BitWriter = struct {
    allocator: std.mem.Allocator,
    bytes: *std.ArrayList(u8),
    current: u8 = 0,
    used: u4 = 0,

    pub fn init(allocator: std.mem.Allocator, bytes: *std.ArrayList(u8)) BitWriter {
        return .{ .allocator = allocator, .bytes = bytes };
    }

    pub fn writeBit(self: *BitWriter, bit: u1) !void {
        self.current |= @as(u8, bit) << @intCast(7 - self.used);
        self.used += 1;
        if (self.used == 8) {
            try self.bytes.append(self.allocator, self.current);
            self.current = 0;
            self.used = 0;
        }
    }

    pub fn writeBits(self: *BitWriter, count: u6, value: u64) !void {
        std.debug.assert(count <= 56);
        var remaining = count;
        while (remaining != 0) {
            remaining -= 1;
            try self.writeBit(@truncate(value >> @intCast(remaining)));
        }
    }

    pub fn finish(self: *BitWriter) !void {
        if (self.used == 0) return;
        try self.bytes.append(self.allocator, self.current);
        self.current = 0;
        self.used = 0;
    }
};

test "Bzip2 bit writer emits MSB-first fields" {
    var bytes: std.ArrayList(u8) = .empty;
    defer bytes.deinit(std.testing.allocator);
    var writer = BitWriter.init(std.testing.allocator, &bytes);
    try writer.writeBits(3, 0b101);
    try writer.writeBits(5, 0b10010);
    try writer.writeBits(3, 0b011);
    try writer.finish();
    try std.testing.expectEqualSlices(u8, &.{ 0b1011_0010, 0b0110_0000 }, bytes.items);
}
