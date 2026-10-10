const std = @import("std");
const core = @import("../core.zig");

pub const Error = core.Error || std.mem.Allocator.Error;

pub const Reader = struct {
    input: []const u8,
    byte_offset: usize = 0,
    reservoir: u64 = 0,
    bit_count: u7 = 0,

    pub fn read(self: *Reader, count: u6) Error!u32 {
        if (count == 0) return 0;
        while (self.bit_count < count) {
            if (self.byte_offset == self.input.len) return error.TruncatedFrame;
            self.reservoir = (self.reservoir << 8) | self.input[self.byte_offset];
            self.byte_offset += 1;
            self.bit_count += 8;
        }
        const shift: u7 = self.bit_count - count;
        const result: u32 = @truncate(self.reservoir >> @intCast(shift));
        self.bit_count -= count;
        self.reservoir &= lowMask(self.bit_count);
        return result & @as(u32, @intCast(lowMask(count)));
    }

    pub fn finish(self: *const Reader) Error!void {
        if (self.byte_offset != self.input.len) return error.TrailingData;
    }
};

pub const Writer = struct {
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    reservoir: u64 = 0,
    bit_count: u7 = 0,

    pub fn write(self: *Writer, value: u32, count: u6) Error!void {
        if (count == 0) return;
        std.debug.assert(@as(u64, value) <= lowMask(count));
        self.reservoir = (self.reservoir << @intCast(count)) | value;
        self.bit_count += count;
        while (self.bit_count >= 8) {
            const shift: u7 = self.bit_count - 8;
            try self.output.append(
                self.allocator,
                @truncate(self.reservoir >> @intCast(shift)),
            );
            self.bit_count -= 8;
            self.reservoir &= lowMask(self.bit_count);
        }
    }

    pub fn finish(self: *Writer) Error!void {
        if (self.bit_count != 0) {
            try self.output.append(
                self.allocator,
                @truncate(self.reservoir << @intCast(8 - self.bit_count)),
            );
        }
        self.reservoir = 0;
        self.bit_count = 0;
    }
};

fn lowMask(count: anytype) u64 {
    const bits: u7 = @intCast(count);
    if (bits == 0) return 0;
    return (@as(u64, 1) << @intCast(bits)) - 1;
}

test "LHA MSB bit stream crosses byte boundaries" {
    var bytes: std.ArrayList(u8) = .empty;
    defer bytes.deinit(std.testing.allocator);
    var writer = Writer{ .allocator = std.testing.allocator, .output = &bytes };
    try writer.write(5, 3);
    try writer.write(0x155, 9);
    try writer.write(3, 2);
    try writer.finish();
    var reader = Reader{ .input = bytes.items };
    try std.testing.expectEqual(@as(u32, 5), try reader.read(3));
    try std.testing.expectEqual(@as(u32, 0x155), try reader.read(9));
    try std.testing.expectEqual(@as(u32, 3), try reader.read(2));
    try reader.finish();
}
