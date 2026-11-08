//! Checked ranges over the public random-access byte source.
const std = @import("std");
const byte_source = @import("../../io/source.zig");

pub const Error = byte_source.Error;

pub const Range = struct {
    source: byte_source.Source,
    offset: u64,
    len: u64,

    pub fn init(source: byte_source.Source, offset: u64, len: u64) Error!Range {
        const range_end = std.math.add(u64, offset, len) catch
            return error.IntegerOverflow;
        if (range_end > source.len) return error.TruncatedFrame;
        return .{ .source = source, .offset = offset, .len = len };
    }

    pub fn end(self: Range) Error!u64 {
        return std.math.add(u64, self.offset, self.len) catch
            return error.IntegerOverflow;
    }

    pub fn subrange(self: Range, relative_offset: u64, len: u64) Error!Range {
        const relative_end = std.math.add(u64, relative_offset, len) catch
            return error.IntegerOverflow;
        if (relative_end > self.len) return error.TruncatedFrame;
        const absolute = std.math.add(u64, self.offset, relative_offset) catch
            return error.IntegerOverflow;
        return .{ .source = self.source, .offset = absolute, .len = len };
    }

    pub fn readExact(self: Range, relative_offset: u64, output: []u8) Error!void {
        const output_len = std.math.cast(u64, output.len) orelse
            return error.IntegerOverflow;
        const relative_end = std.math.add(u64, relative_offset, output_len) catch
            return error.IntegerOverflow;
        if (relative_end > self.len) return error.TruncatedFrame;
        const absolute = std.math.add(u64, self.offset, relative_offset) catch
            return error.IntegerOverflow;
        try self.source.readExact(absolute, output);
    }

    pub fn byte(self: Range, relative_offset: u64) Error!u8 {
        var result: [1]u8 = undefined;
        try self.readExact(relative_offset, &result);
        return result[0];
    }
};

test "Zstd source range enforces absolute and relative bounds" {
    var slice = byte_source.SliceSource{ .bytes = "0123456789" };
    const range = try Range.init(slice.source(), 2, 6);
    try std.testing.expectEqual(@as(u64, 8), try range.end());
    var output: [3]u8 = undefined;
    try range.readExact(1, &output);
    try std.testing.expectEqualStrings("345", &output);
    try std.testing.expectEqual(@as(u8, '7'), try range.byte(5));
    try std.testing.expectError(error.TruncatedFrame, range.readExact(4, &output));
    try std.testing.expectError(error.TruncatedFrame, range.subrange(5, 2));
    try std.testing.expectError(error.TruncatedFrame, Range.init(slice.source(), 9, 2));
    try std.testing.expectError(error.IntegerOverflow, Range.init(slice.source(), std.math.maxInt(u64), 2));
}
