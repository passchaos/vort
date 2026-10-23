const std = @import("std");

/// Appended integers retain their low-bit order. FSE decoders consume these
/// fields in reverse from the last valid bit, without a terminal marker bit.
pub const Writer = struct {
    bytes: std.ArrayList(u8) = .empty,
    accumulator: u64 = 0,
    bit_count: u8 = 0,
    finished: bool = false,

    pub fn deinit(self: *Writer, allocator: std.mem.Allocator) void {
        self.bytes.deinit(allocator);
        self.* = .{};
    }

    pub fn push(self: *Writer, allocator: std.mem.Allocator, value: u32, width: u8) !void {
        if (self.finished or width > 31 or value >= @as(u64, 1) << @intCast(width))
            return error.InvalidLzfseStream;
        const total = self.bit_count + width;
        const byte_count = total / 8;
        try self.bytes.ensureUnusedCapacity(allocator, byte_count);
        self.accumulator |= @as(u64, value) << @intCast(self.bit_count);
        self.bit_count = total;
        for (0..byte_count) |_| {
            self.bytes.appendAssumeCapacity(@truncate(self.accumulator));
            self.accumulator >>= 8;
            self.bit_count -= 8;
        }
    }

    /// Returns minus the number of unused high bits in the last byte.
    pub fn finish(self: *Writer, allocator: std.mem.Allocator) !i8 {
        if (self.finished) return error.InvalidLzfseStream;
        const final_bits: i8 = if (self.bit_count == 0) 0 else @as(i8, @intCast(self.bit_count)) - 8;
        if (self.bit_count != 0) try self.bytes.append(allocator, @intCast(self.accumulator));
        self.accumulator = 0;
        self.bit_count = 0;
        self.finished = true;
        return final_bits;
    }
};

test "LZFSE encoder bit writer reverses fields with every final padding" {
    const Reader = @import("../fse.zig").BitReader;
    for (0..8) |tail| {
        var writer = Writer{};
        defer writer.deinit(std.testing.allocator);
        try writer.push(std.testing.allocator, 0, 0);
        try writer.push(std.testing.allocator, 0x5a_bcd1, 23);
        try writer.push(std.testing.allocator, 0x18d, 9);
        try writer.push(std.testing.allocator, @intCast((@as(u32, 1) << @intCast(tail)) - 1), @intCast(tail));
        const final_bits = try writer.finish(std.testing.allocator);
        try std.testing.expectEqual(if (tail == 0) @as(i8, 0) else @as(i8, @intCast(tail)) - 8, final_bits);
        var reader = try Reader.init(writer.bytes.items, final_bits);
        try std.testing.expectEqual((@as(u32, 1) << @intCast(tail)) - 1, try reader.pull(@intCast(tail)));
        try std.testing.expectEqual(@as(u32, 0x18d), try reader.pull(9));
        try std.testing.expectEqual(@as(u32, 0x5a_bcd1), try reader.pull(23));
        try std.testing.expectEqual(@as(usize, 0), reader.bit_position);
    }
    var writer = Writer{};
    defer writer.deinit(std.testing.allocator);
    try std.testing.expectError(error.InvalidLzfseStream, writer.push(std.testing.allocator, 1, 0));
    try std.testing.expectError(error.InvalidLzfseStream, writer.push(std.testing.allocator, 4, 2));
    try std.testing.expectError(error.InvalidLzfseStream, writer.push(std.testing.allocator, 0, 32));
    try std.testing.expectEqual(@as(i8, 0), try writer.finish(std.testing.allocator));
    try std.testing.expectError(error.InvalidLzfseStream, writer.push(std.testing.allocator, 0, 0));
}
