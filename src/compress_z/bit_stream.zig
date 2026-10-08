const std = @import("std");
const core = @import("../core.zig");

pub const Reader = struct {
    bytes: []const u8,
    bit_offset: usize = 0,
    group_base: usize = 0,

    pub fn init(bytes: []const u8) Reader {
        return .{ .bytes = bytes };
    }

    pub fn canRead(self: Reader, width: u5) bool {
        const total_bits = std.math.mul(usize, self.bytes.len, 8) catch return false;
        const end = std.math.add(usize, self.bit_offset, width) catch return false;
        return end <= total_bits;
    }

    pub fn readCode(self: *Reader, width: u5) core.Error!u16 {
        if (width < 9 or width > 16) return error.CorruptFrame;
        if (!self.canRead(width)) return error.TruncatedFrame;

        const byte_offset = self.bit_offset / 8;
        const shift: u5 = @intCast(self.bit_offset & 7);
        var word: u32 = 0;
        for (0..3) |index| {
            const source = byte_offset + index;
            if (source < self.bytes.len)
                word |= @as(u32, self.bytes[source]) << @intCast(index * 8);
        }
        const mask = (@as(u32, 1) << width) - 1;
        self.bit_offset += width;
        return @intCast((word >> shift) & mask);
    }

    pub fn alignToCodeGroup(self: *Reader, width: u5) core.Error!void {
        const group_bits = @as(usize, width) * 8;
        const relative = self.bit_offset - self.group_base;
        const rounded = std.math.add(usize, relative, group_bits - 1) catch
            return error.IntegerOverflow;
        const aligned_relative = rounded / group_bits * group_bits;
        const aligned = std.math.add(usize, self.group_base, aligned_relative) catch
            return error.IntegerOverflow;
        const total_bits = std.math.mul(usize, self.bytes.len, 8) catch
            return error.IntegerOverflow;
        if (aligned > total_bits) return error.TruncatedFrame;
        self.bit_offset = aligned;
        self.group_base = aligned;
    }

    pub fn remainingBits(self: Reader) usize {
        const total_bits = std.math.mul(usize, self.bytes.len, 8) catch return 0;
        return total_bits -| self.bit_offset;
    }
};

pub const Writer = struct {
    allocator: std.mem.Allocator,
    bytes: *std.ArrayList(u8),
    byte_base: usize,
    bit_offset: usize = 0,
    group_base: usize = 0,

    pub fn init(allocator: std.mem.Allocator, bytes: *std.ArrayList(u8)) Writer {
        return .{
            .allocator = allocator,
            .bytes = bytes,
            .byte_base = bytes.items.len,
        };
    }

    pub fn writeCode(self: *Writer, code: u16, width: u5) !void {
        if (width < 9 or width > 16) return error.CorruptFrame;
        const limit = @as(u32, 1) << width;
        if (code >= limit) return error.CorruptFrame;
        const end = std.math.add(usize, self.bit_offset, width) catch
            return error.IntegerOverflow;
        try self.ensureBitLength(end);

        const byte_offset = self.byte_base + self.bit_offset / 8;
        const shift: u5 = @intCast(self.bit_offset & 7);
        const word = @as(u32, code) << shift;
        for (0..3) |index| {
            const destination = byte_offset + index;
            if (destination >= self.bytes.items.len) break;
            self.bytes.items[destination] |= @truncate(word >> @intCast(index * 8));
        }
        self.bit_offset = end;
    }

    pub fn alignToCodeGroup(self: *Writer, width: u5) !void {
        const group_bits = @as(usize, width) * 8;
        const relative = self.bit_offset - self.group_base;
        const rounded = std.math.add(usize, relative, group_bits - 1) catch
            return error.IntegerOverflow;
        const aligned_relative = rounded / group_bits * group_bits;
        const aligned = std.math.add(usize, self.group_base, aligned_relative) catch
            return error.IntegerOverflow;
        try self.ensureBitLength(aligned);
        self.bit_offset = aligned;
        self.group_base = aligned;
    }

    fn ensureBitLength(self: *Writer, bit_len: usize) !void {
        const rounded = std.math.add(usize, bit_len, 7) catch return error.IntegerOverflow;
        const payload_bytes = rounded / 8;
        const required = std.math.add(usize, self.byte_base, payload_bytes) catch
            return error.IntegerOverflow;
        if (required > self.bytes.items.len)
            try self.bytes.appendNTimes(self.allocator, 0, required - self.bytes.items.len);
    }
};

test "compress .Z bit stream uses LSB-first codes and group alignment" {
    var bytes: std.ArrayList(u8) = .empty;
    defer bytes.deinit(std.testing.allocator);
    var writer = Writer.init(std.testing.allocator, &bytes);
    try writer.writeCode(0x101, 9);
    try writer.writeCode(0x055, 9);
    try std.testing.expectEqualSlices(u8, &.{ 0x01, 0xab, 0x00 }, bytes.items);

    try writer.alignToCodeGroup(9);
    try std.testing.expectEqual(@as(usize, 9), bytes.items.len);
    try writer.writeCode(0x2aa, 10);
    for (0..7) |_| try writer.writeCode(0x155, 10);
    try writer.alignToCodeGroup(10);
    try std.testing.expectEqual(@as(usize, 19), bytes.items.len);

    var reader = Reader.init(bytes.items);
    try std.testing.expectEqual(@as(u16, 0x101), try reader.readCode(9));
    try std.testing.expectEqual(@as(u16, 0x055), try reader.readCode(9));
    try reader.alignToCodeGroup(9);
    try std.testing.expectEqual(@as(u16, 0x2aa), try reader.readCode(10));
    for (0..7) |_| try std.testing.expectEqual(@as(u16, 0x155), try reader.readCode(10));
    try reader.alignToCodeGroup(10);
    try std.testing.expectEqual(@as(usize, 0), reader.remainingBits());
}
