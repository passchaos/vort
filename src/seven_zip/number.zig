const std = @import("std");
const core = @import("../core.zig");

pub const Error = core.Error || error{Invalid7zInteger};

pub const Reader = struct {
    bytes: []const u8,
    offset: usize = 0,

    pub fn init(bytes: []const u8) Reader {
        return .{ .bytes = bytes };
    }

    pub fn remaining(self: Reader) usize {
        return self.bytes.len -| self.offset;
    }

    pub fn readByte(self: *Reader) Error!u8 {
        if (self.offset >= self.bytes.len) return error.TruncatedFrame;
        const value = self.bytes[self.offset];
        self.offset += 1;
        return value;
    }

    pub fn readU32(self: *Reader) Error!u32 {
        if (self.remaining() < 4) return error.TruncatedFrame;
        const value = std.mem.readInt(u32, self.bytes[self.offset..][0..4], .little);
        self.offset += 4;
        return value;
    }

    pub fn readU64(self: *Reader) Error!u64 {
        if (self.remaining() < 8) return error.TruncatedFrame;
        const value = std.mem.readInt(u64, self.bytes[self.offset..][0..8], .little);
        self.offset += 8;
        return value;
    }

    pub fn readNumber(self: *Reader) Error!u64 {
        const first = try self.readByte();
        var value: u64 = 0;
        var mask: u8 = 0x80;
        for (0..8) |index| {
            if (first & mask == 0) {
                const high = first & (mask - 1);
                value |= @as(u64, high) << @intCast(index * 8);
                return value;
            }
            value |= @as(u64, try self.readByte()) << @intCast(index * 8);
            mask >>= 1;
        }
        return value;
    }

    pub fn readSize(self: *Reader) Error!usize {
        return std.math.cast(usize, try self.readNumber()) orelse error.IntegerOverflow;
    }

    pub fn take(self: *Reader, len: usize) Error![]const u8 {
        const end = std.math.add(usize, self.offset, len) catch return error.IntegerOverflow;
        if (end > self.bytes.len) return error.TruncatedFrame;
        defer self.offset = end;
        return self.bytes[self.offset..end];
    }

    pub fn subReader(self: *Reader, len: usize) Error!Reader {
        return Reader.init(try self.take(len));
    }
};

pub fn append(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value_arg: u64) !void {
    var value = value_arg;
    var first: u8 = 0;
    var mask: u8 = 0x80;
    var extra: usize = 0;
    while (extra < 8) : (extra += 1) {
        if (value < (@as(u64, 1) << @intCast(7 * (extra + 1)))) {
            first |= @truncate(value >> @intCast(8 * extra));
            break;
        }
        first |= mask;
        mask >>= 1;
    }
    try output.append(allocator, first);
    var remaining = extra;
    while (remaining != 0) : (remaining -= 1) {
        try output.append(allocator, @truncate(value));
        value >>= 8;
    }
}

test "7z variable integers round trip boundary values" {
    const values = [_]u64{
        0,
        0x7f,
        0x80,
        0x3fff,
        0x4000,
        0x1f_ffff,
        0x00ff_ffff_ffff_ffff,
        std.math.maxInt(u64),
    };
    for (values) |value| {
        var bytes: std.ArrayList(u8) = .empty;
        defer bytes.deinit(std.testing.allocator);
        try append(std.testing.allocator, &bytes, value);
        var reader = Reader.init(bytes.items);
        try std.testing.expectEqual(value, try reader.readNumber());
        try std.testing.expectEqual(@as(usize, 0), reader.remaining());
    }
}
