const std = @import("std");
const bytes = @import("../../io/source.zig");

pub const Error = bytes.Error;

/// Borrowed metadata/data address space. Reads never materialize the image.
pub const Input = union(enum) {
    slice: []const u8,
    source: bytes.Source,

    pub fn len(self: Input) u64 {
        return switch (self) {
            .slice => |data| data.len,
            .source => |source| source.len,
        };
    }

    pub fn end(self: Input, start: usize, size: usize) Error!usize {
        const result = std.math.add(usize, start, size) catch return error.IntegerOverflow;
        if (result > self.len()) return error.TruncatedFrame;
        return result;
    }

    pub fn read(self: Input, offset: usize, output: []u8) Error!void {
        _ = try self.end(offset, output.len);
        try self.readAt(offset, output);
    }

    pub fn endAt(self: Input, start: u64, size: usize) Error!u64 {
        const result = std.math.add(u64, start, size) catch return error.IntegerOverflow;
        if (result > self.len()) return error.TruncatedFrame;
        return result;
    }

    pub fn readAt(self: Input, offset: u64, output: []u8) Error!void {
        const limit = try self.endAt(offset, output.len);
        switch (self) {
            .slice => |data| @memcpy(output, data[@intCast(offset)..@intCast(limit)]),
            .source => |source| try source.readExact(offset, output),
        }
    }

    pub fn integer(self: Input, comptime T: type, offset: usize) Error!T {
        var buffer: [@sizeOf(T)]u8 = undefined;
        try self.read(offset, &buffer);
        return std.mem.readInt(T, &buffer, .little);
    }
};

test "EROFS metadata input completes short source reads and enforces ranges" {
    const Context = struct {
        data: []const u8,
        fn read(raw: *anyopaque, offset: u64, output: []u8) error{SourceReadFailed}!usize {
            const self: *@This() = @ptrCast(@alignCast(raw));
            const start: usize = @intCast(offset);
            const size = @min(2, @min(output.len, self.data.len - start));
            @memcpy(output[0..size], self.data[start..][0..size]);
            return size;
        }
    };
    var context = Context{ .data = &.{ 1, 2, 3, 4, 5, 6, 7, 8 } };
    const source = Input{ .source = .{ .context = &context, .len = context.data.len, .read_at = Context.read, .max_read_size = 3 } };
    const slice = Input{ .slice = context.data };
    try std.testing.expectEqual(try slice.integer(u64, 0), try source.integer(u64, 0));
    try std.testing.expectError(error.TruncatedFrame, source.integer(u32, 6));
    try std.testing.expectError(error.IntegerOverflow, source.end(std.math.maxInt(usize), 1));
}
