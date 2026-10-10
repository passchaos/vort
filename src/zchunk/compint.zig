const std = @import("std");
const core = @import("../core.zig");

pub const Error = core.Error || error{InvalidZchunkInteger};

pub const Reader = struct {
    bytes: []const u8,
    position: usize = 0,
    end: usize,

    pub fn init(bytes: []const u8) Reader {
        return .{ .bytes = bytes, .end = bytes.len };
    }

    pub fn initRange(bytes: []const u8, start: usize, end: usize) Error!Reader {
        if (start > end or end > bytes.len) return error.TruncatedFrame;
        return .{ .bytes = bytes, .position = start, .end = end };
    }

    pub fn read(self: *Reader) Error!usize {
        const max_bytes = (@bitSizeOf(usize) + 6) / 7;
        var value: usize = 0;
        var multiplier: usize = 1;
        var count: usize = 0;
        while (true) {
            if (self.position >= self.end) return error.TruncatedFrame;
            const byte = self.bytes[self.position];
            self.position += 1;
            const digit: usize = byte & 0x7f;
            const contribution = std.math.mul(usize, digit, multiplier) catch
                return error.IntegerOverflow;
            value = std.math.add(usize, value, contribution) catch
                return error.IntegerOverflow;
            count += 1;
            if (byte & 0x80 != 0) {
                if (count > 1 and digit == 0) return error.InvalidZchunkInteger;
                return value;
            }
            if (count >= max_bytes) return error.IntegerOverflow;
            multiplier = std.math.mul(usize, multiplier, 128) catch
                return error.IntegerOverflow;
        }
    }
};

pub fn append(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    value: usize,
) std.mem.Allocator.Error!void {
    var remaining = value;
    while (true) {
        var byte: u8 = @truncate(remaining & 0x7f);
        remaining >>= 7;
        if (remaining == 0) byte |= 0x80;
        try output.append(allocator, byte);
        if (remaining == 0) return;
    }
}

test "zchunk compressed integers round trip canonical boundaries" {
    const allocator = std.testing.allocator;
    inline for (.{ 0, 1, 127, 128, 16_511, 16_512, std.math.maxInt(u32) }) |value| {
        var bytes: std.ArrayList(u8) = .empty;
        defer bytes.deinit(allocator);
        try append(allocator, &bytes, value);
        var reader = Reader.init(bytes.items);
        try std.testing.expectEqual(@as(usize, value), try reader.read());
        try std.testing.expectEqual(bytes.items.len, reader.position);
    }
    var truncated = Reader.init(&.{0});
    try std.testing.expectError(error.TruncatedFrame, truncated.read());
    var overlong = Reader.init(&.{ 0, 0x80 });
    try std.testing.expectError(error.InvalidZchunkInteger, overlong.read());
}
