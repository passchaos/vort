//! Stable random-access byte source for large 7z archives.
//!
//! The callback and its context remain borrowed for the lifetime of a parsed
//! source archive. Callers must keep the reported length and bytes stable.

const std = @import("std");

pub const Error = error{
    SourceReadFailed,
    TruncatedFrame,
    IntegerOverflow,
};

pub const Source = struct {
    context: *anyopaque,
    len: u64,
    read_at: *const fn (
        context: *anyopaque,
        offset: u64,
        output: []u8,
    ) error{SourceReadFailed}!usize,

    pub fn readExact(self: Source, offset: u64, output: []u8) Error!void {
        const output_len = std.math.cast(u64, output.len) orelse
            return error.IntegerOverflow;
        const end = std.math.add(u64, offset, output_len) catch
            return error.IntegerOverflow;
        if (end > self.len) return error.TruncatedFrame;

        var written: usize = 0;
        while (written < output.len) {
            const absolute = std.math.add(
                u64,
                offset,
                std.math.cast(u64, written) orelse return error.IntegerOverflow,
            ) catch return error.IntegerOverflow;
            const amount = try self.read_at(self.context, absolute, output[written..]);
            if (amount == 0 or amount > output.len - written)
                return error.TruncatedFrame;
            written += amount;
        }
    }
};

test "7z random-access source completes short reads and enforces length" {
    const Context = struct {
        bytes: []const u8,
        max_chunk: usize,

        fn readAt(context: *anyopaque, offset: u64, output: []u8) error{SourceReadFailed}!usize {
            const self: *@This() = @ptrCast(@alignCast(context));
            const start = std.math.cast(usize, offset) orelse return error.SourceReadFailed;
            if (start >= self.bytes.len) return 0;
            const count = @min(output.len, @min(self.max_chunk, self.bytes.len - start));
            @memcpy(output[0..count], self.bytes[start..][0..count]);
            return count;
        }
    };
    var context = Context{ .bytes = "source bytes", .max_chunk = 2 };
    const source = Source{
        .context = &context,
        .len = context.bytes.len,
        .read_at = Context.readAt,
    };
    var output: [6]u8 = undefined;
    try source.readExact(3, &output);
    try std.testing.expectEqualSlices(u8, "rce by", &output);
    try std.testing.expectError(error.TruncatedFrame, source.readExact(8, &output));

    const Failing = struct {
        fn readAt(
            raw_context: *anyopaque,
            offset: u64,
            destination: []u8,
        ) error{SourceReadFailed}!usize {
            _ = raw_context;
            _ = offset;
            _ = destination;
            return error.SourceReadFailed;
        }
    };
    const failing = Source{ .context = &context, .len = 1, .read_at = Failing.readAt };
    var byte: [1]u8 = undefined;
    try std.testing.expectError(error.SourceReadFailed, failing.readExact(0, &byte));
}
