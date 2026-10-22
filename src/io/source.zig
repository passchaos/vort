const std = @import("std");

pub const Error = error{ SourceReadFailed, TruncatedFrame, IntegerOverflow };

/// Borrowed, stable random-access input. Keep the context, length, and bytes
/// valid for every consumer call. Short callback reads are completed here.
pub const Source = struct {
    context: *anyopaque,
    len: u64,
    read_at: *const fn (context: *anyopaque, offset: u64, output: []u8) error{SourceReadFailed}!usize,
    /// Bounds each individual callback destination, including large outputs.
    max_read_size: usize = 64 * 1024,

    pub fn readExact(self: Source, offset: u64, output: []u8) Error!void {
        if (self.max_read_size == 0) return error.SourceReadFailed;
        const length = std.math.cast(u64, output.len) orelse return error.IntegerOverflow;
        const end = std.math.add(u64, offset, length) catch return error.IntegerOverflow;
        if (end > self.len) return error.TruncatedFrame;
        var position: usize = 0;
        while (position < output.len) {
            const size = @min(self.max_read_size, output.len - position);
            const absolute = std.math.add(u64, offset, position) catch return error.IntegerOverflow;
            const amount = try self.read_at(self.context, absolute, output[position..][0..size]);
            if (amount == 0) return error.TruncatedFrame;
            if (amount > size) return error.SourceReadFailed;
            position += amount;
        }
    }
};

pub const SliceSource = struct {
    bytes: []const u8,

    pub fn source(self: *SliceSource) Source {
        return .{ .context = self, .len = self.bytes.len, .read_at = readAt };
    }

    fn readAt(context: *anyopaque, offset: u64, output: []u8) error{SourceReadFailed}!usize {
        const self: *SliceSource = @ptrCast(@alignCast(context));
        const start = std.math.cast(usize, offset) orelse return error.SourceReadFailed;
        if (start >= self.bytes.len) return 0;
        const size = @min(output.len, self.bytes.len - start);
        @memcpy(output[0..size], self.bytes[start..][0..size]);
        return size;
    }
};

test "byte source completes short reads and bounds callback requests" {
    const Context = struct {
        bytes: []const u8,
        max_requested: usize = 0,
        fn readAt(raw: *anyopaque, offset: u64, output: []u8) error{SourceReadFailed}!usize {
            const self: *@This() = @ptrCast(@alignCast(raw));
            self.max_requested = @max(self.max_requested, output.len);
            const start = std.math.cast(usize, offset) orelse return error.SourceReadFailed;
            if (start >= self.bytes.len) return 0;
            const size = @min(2, @min(output.len, self.bytes.len - start));
            @memcpy(output[0..size], self.bytes[start..][0..size]);
            return size;
        }
    };
    var context = Context{ .bytes = "0123456789abcdef" };
    const input = Source{ .context = &context, .len = context.bytes.len, .read_at = Context.readAt, .max_read_size = 3 };
    var output: [10]u8 = undefined;
    try input.readExact(3, &output);
    try std.testing.expectEqualStrings("3456789abc", &output);
    try std.testing.expectEqual(@as(usize, 3), context.max_requested);
    try std.testing.expectError(error.TruncatedFrame, input.readExact(7, &output));
    try std.testing.expectError(error.IntegerOverflow, input.readExact(std.math.maxInt(u64), output[0..1]));
}

test "byte source distinguishes callback failures truncation and invalid counts" {
    const Context = struct {
        mode: enum { fail, eof, excessive },
        fn readAt(raw: *anyopaque, offset: u64, output: []u8) error{SourceReadFailed}!usize {
            _ = offset;
            const self: *@This() = @ptrCast(@alignCast(raw));
            return switch (self.mode) {
                .fail => error.SourceReadFailed,
                .eof => 0,
                .excessive => output.len + 1,
            };
        }
    };
    var context = Context{ .mode = .fail };
    var input = Source{ .context = &context, .len = 1, .read_at = Context.readAt };
    var output: [1]u8 = undefined;
    try std.testing.expectError(error.SourceReadFailed, input.readExact(0, &output));
    context.mode = .eof;
    try std.testing.expectError(error.TruncatedFrame, input.readExact(0, &output));
    context.mode = .excessive;
    try std.testing.expectError(error.SourceReadFailed, input.readExact(0, &output));
    input.max_read_size = 0;
    try std.testing.expectError(error.SourceReadFailed, input.readExact(0, &output));
}
