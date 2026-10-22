const std = @import("std");

pub const Error = error{ SinkWriteFailed, IntegerOverflow };

/// Caller-owned random-access output. Short writes are completed here;
/// final length is committed explicitly after metadata and data are written.
pub const Sink = struct {
    context: *anyopaque,
    write_at: *const fn (*anyopaque, u64, []const u8) error{SinkWriteFailed}!usize,
    set_len: *const fn (*anyopaque, u64) error{SinkWriteFailed}!void,
    max_write_size: usize = 64 * 1024,

    pub fn writeExact(self: Sink, offset: u64, input: []const u8) Error!void {
        if (self.max_write_size == 0) return error.SinkWriteFailed;
        _ = std.math.add(u64, offset, input.len) catch return error.IntegerOverflow;
        var position: usize = 0;
        while (position < input.len) {
            const size = @min(self.max_write_size, input.len - position);
            const absolute = std.math.add(u64, offset, position) catch return error.IntegerOverflow;
            const amount = try self.write_at(self.context, absolute, input[position..][0..size]);
            if (amount == 0 or amount > size) return error.SinkWriteFailed;
            position += amount;
        }
    }

    pub fn finish(self: Sink, length: u64) Error!void {
        try self.set_len(self.context, length);
    }
};

pub const BufferSink = struct {
    allocator: std.mem.Allocator,
    bytes: std.ArrayList(u8) = .empty,
    allocation_failed: bool = false,

    pub fn init(allocator: std.mem.Allocator) BufferSink {
        return .{ .allocator = allocator };
    }
    pub fn deinit(self: *BufferSink) void {
        self.bytes.deinit(self.allocator);
        self.* = undefined;
    }
    pub fn sink(self: *BufferSink) Sink {
        return .{ .context = self, .write_at = writeAt, .set_len = setLen };
    }
    pub fn take(self: *BufferSink) std.mem.Allocator.Error![]u8 {
        return self.bytes.toOwnedSlice(self.allocator);
    }

    fn resize(self: *BufferSink, length: usize) error{SinkWriteFailed}!void {
        const old = self.bytes.items.len;
        self.bytes.resize(self.allocator, length) catch {
            self.allocation_failed = true;
            return error.SinkWriteFailed;
        };
        if (length > old) @memset(self.bytes.items[old..], 0);
    }

    fn writeAt(raw: *anyopaque, offset: u64, input: []const u8) error{SinkWriteFailed}!usize {
        const self: *BufferSink = @ptrCast(@alignCast(raw));
        const start = std.math.cast(usize, offset) orelse return error.SinkWriteFailed;
        const end = std.math.add(usize, start, input.len) catch return error.SinkWriteFailed;
        if (end > self.bytes.items.len) try self.resize(end);
        @memcpy(self.bytes.items[start..end], input);
        return input.len;
    }

    fn setLen(raw: *anyopaque, length: u64) error{SinkWriteFailed}!void {
        const self: *BufferSink = @ptrCast(@alignCast(raw));
        try self.resize(std.math.cast(usize, length) orelse return error.SinkWriteFailed);
    }
};

test "byte sink completes short writes and preserves offsets" {
    const Context = struct {
        bytes: [32]u8 = @splat(0),
        length: u64 = 0,
        max_requested: usize = 0,
        fn writeAt(raw: *anyopaque, offset: u64, input: []const u8) error{SinkWriteFailed}!usize {
            const self: *@This() = @ptrCast(@alignCast(raw));
            self.max_requested = @max(self.max_requested, input.len);
            const size = @min(2, input.len);
            const start: usize = @intCast(offset);
            @memcpy(self.bytes[start..][0..size], input[0..size]);
            return size;
        }
        fn setLen(raw: *anyopaque, length: u64) error{SinkWriteFailed}!void {
            const self: *@This() = @ptrCast(@alignCast(raw));
            self.length = length;
        }
    };
    var context = Context{};
    const output = Sink{ .context = &context, .write_at = Context.writeAt, .set_len = Context.setLen, .max_write_size = 3 };
    try output.writeExact(5, "abcdefghij");
    try output.finish(15);
    try std.testing.expectEqualStrings("abcdefghij", context.bytes[5..15]);
    try std.testing.expectEqual(@as(usize, 3), context.max_requested);
    try std.testing.expectEqual(@as(u64, 15), context.length);
    try std.testing.expectError(error.IntegerOverflow, output.writeExact(std.math.maxInt(u64), "x"));
}

test "byte sink rejects failed zero and excessive write counts" {
    const Context = struct {
        mode: enum { fail, zero, excessive },
        fn writeAt(raw: *anyopaque, offset: u64, input: []const u8) error{SinkWriteFailed}!usize {
            _ = offset;
            const self: *@This() = @ptrCast(@alignCast(raw));
            return switch (self.mode) {
                .fail => error.SinkWriteFailed,
                .zero => 0,
                .excessive => input.len + 1,
            };
        }
        fn setLen(raw: *anyopaque, length: u64) error{SinkWriteFailed}!void {
            _ = raw;
            _ = length;
            return error.SinkWriteFailed;
        }
    };
    var context = Context{ .mode = .fail };
    var output = Sink{ .context = &context, .write_at = Context.writeAt, .set_len = Context.setLen };
    inline for (.{ .fail, .zero, .excessive }) |mode| {
        context.mode = mode;
        try std.testing.expectError(error.SinkWriteFailed, output.writeExact(0, "payload"));
    }
    try std.testing.expectError(error.SinkWriteFailed, output.finish(10));
    output.max_write_size = 0;
    try std.testing.expectError(error.SinkWriteFailed, output.writeExact(0, "x"));
}

test "buffer byte sink zero fills gaps and commits final length" {
    var buffer = BufferSink.init(std.testing.allocator);
    defer buffer.deinit();
    const output = buffer.sink();
    try output.writeExact(4, "abcd");
    try output.writeExact(0, "XY");
    try output.finish(7);
    const bytes = try buffer.take();
    defer std.testing.allocator.free(bytes);
    try std.testing.expectEqualSlices(u8, &.{ 'X', 'Y', 0, 0, 'a', 'b', 'c' }, bytes);
}
