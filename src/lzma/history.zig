const std = @import("std");

/// Sparse, caller-owned circular LZMA history with bounded copy distances.
pub const CircularBuffer = struct {
    bytes: std.ArrayList(u8) = .empty,
    dictionary_size: usize,
    output_limit: usize,
    cursor: usize = 0,
    len: usize = 0,
    allow_partial: bool = false,

    pub fn init(dictionary_size: usize, output_limit: usize) CircularBuffer {
        return .{
            .dictionary_size = dictionary_size,
            .output_limit = output_limit,
        };
    }

    pub fn deinit(self: *CircularBuffer, allocator: std.mem.Allocator) void {
        self.bytes.deinit(allocator);
    }

    pub fn lastOr(self: CircularBuffer, default: u8) u8 {
        if (self.len == 0) return default;
        const index = if (self.cursor != 0) self.cursor - 1 else self.dictionary_size - 1;
        return self.bytes.items[index];
    }

    pub fn lastN(self: CircularBuffer, distance: usize) !u8 {
        if (distance == 0 or distance > self.dictionary_size or distance > self.len)
            return error.CorruptInput;
        const index = if (self.cursor >= distance) self.cursor - distance else self.dictionary_size - (distance - self.cursor);
        return self.bytes.items[index];
    }

    pub fn appendLiteral(
        self: *CircularBuffer,
        allocator: std.mem.Allocator,
        byte: u8,
        writer: *std.Io.Writer,
    ) !void {
        if (self.len >= self.output_limit) return error.OutputLimitExceeded;
        if (self.cursor < self.bytes.items.len) {
            self.bytes.items[self.cursor] = byte;
        } else {
            try self.bytes.append(allocator, byte);
        }
        try writer.writeByte(byte);
        self.cursor += 1;
        if (self.cursor == self.dictionary_size) self.cursor = 0;
        self.len += 1;
    }

    pub fn appendLz(
        self: *CircularBuffer,
        allocator: std.mem.Allocator,
        length: usize,
        distance: usize,
        writer: *std.Io.Writer,
    ) !void {
        if (distance == 0 or distance > self.dictionary_size or distance > self.len)
            return error.CorruptInput;
        const remaining = self.output_limit -| self.len;
        if (!self.allow_partial and length > remaining) return error.OutputLimitExceeded;
        for (0..@min(length, remaining)) |_| {
            const byte = try self.lastN(distance);
            try self.appendLiteral(allocator, byte, writer);
        }
    }
};

test "LZMA history maximum declared windows need only sparse active storage" {
    for ([_]usize{ std.math.maxInt(usize), std.math.maxInt(u32), 4096 }) |size| {
        var history = CircularBuffer.init(size, 1);
        defer history.deinit(std.testing.allocator);
        var output: [1]u8 = undefined;
        var writer = std.Io.Writer.fixed(&output);
        try std.testing.expectEqual(@as(u8, 0x31), history.lastOr(0x31));
        try history.appendLiteral(std.testing.allocator, 0xa7, &writer);
        try std.testing.expectEqual(@as(usize, 1), history.bytes.items.len);
        try std.testing.expectEqual(@as(usize, 1), history.cursor);
        try std.testing.expectEqual(@as(u8, 0xa7), history.lastOr(0));
        try std.testing.expectEqual(@as(u8, 0xa7), try history.lastN(1));
        try std.testing.expectError(error.CorruptInput, history.lastN(0));
        try std.testing.expectError(error.CorruptInput, history.lastN(2));
    }
}

test "LZMA history indices match a linear reference through repeated wraps" {
    var source: [257]u8 = undefined;
    for (&source, 0..) |*byte, index| byte.* = @truncate(index *% 37 +% index / 3);
    for ([_]usize{ 3, 4, 7, 16 }) |size| {
        var history = CircularBuffer.init(size, source.len);
        defer history.deinit(std.testing.allocator);
        for (source, 0..) |byte, index| {
            var output: [1]u8 = undefined;
            var writer = std.Io.Writer.fixed(&output);
            try history.appendLiteral(std.testing.allocator, byte, &writer);
            try std.testing.expectEqual(byte, output[0]);
            try std.testing.expectEqual(byte, history.lastOr(0));
            for (1..@min(size, index + 1) + 1) |distance|
                try std.testing.expectEqual(source[index + 1 - distance], try history.lastN(distance));
        }
    }
}

test "LZMA history overlapping matches preserve distances across wraps" {
    var history = CircularBuffer.init(7, 23);
    defer history.deinit(std.testing.allocator);
    var output: [23]u8 = undefined;
    var writer = std.Io.Writer.fixed(&output);
    for ("abc") |byte| try history.appendLiteral(std.testing.allocator, byte, &writer);
    try history.appendLz(std.testing.allocator, 20, 3, &writer);
    for (output, 0..) |byte, index| try std.testing.expectEqual("abc"[index % 3], byte);
    try std.testing.expectEqual(@as(usize, 23), history.len);
    try std.testing.expectEqual(@as(usize, 2), history.cursor);
    for (1..8) |distance|
        try std.testing.expectEqual(output[output.len - distance], try history.lastN(distance));
}
