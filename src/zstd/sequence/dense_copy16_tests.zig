const std = @import("std");
const M = @import("match_copy.zig");
const distances = [_]usize{ 16, 17, 31, 32, 33, 63, 64, 65 };

fn seed(bytes: []u8) void {
    for (bytes, 0..) |*byte, i| byte.* = @truncate(i * 109 + 31);
}

fn scalar(bytes: []u8, cursor: *usize, distance: usize, len: usize) void {
    for (0..len) |i| bytes[cursor.* + i] = bytes[cursor.* + i - distance];
    cursor.* += len;
}

pub fn isolated() !void {
    for (3..17) |len| for (distances) |distance| for (0..16) |alignment| for ([_]usize{ 16, 32, 64 }) |headroom| {
        var expected: [512]u8 = undefined;
        seed(&expected);
        var actual = expected;
        const start = 128 + alignment;
        var expected_written = start;
        var actual_written = start;
        scalar(&expected, &expected_written, distance, len);
        M.appendForwardWildcopy16Once(actual[0 .. start + headroom], &actual_written, start - distance, len);
        try std.testing.expectEqual(expected_written, actual_written);
        try std.testing.expectEqualSlices(u8, expected[0..expected_written], actual[0..actual_written]);
        try std.testing.expectEqualSlices(u8, expected[start + 16 ..], actual[start + 16 ..]);
    };
}

pub fn chained() !void {
    for (0..16) |alignment| for (distances) |distance| {
        var expected: [1024]u8 = undefined;
        seed(&expected);
        var actual = expected;
        var expected_written = 128 + alignment;
        var actual_written = expected_written;
        for (0..56) |index| {
            const len = 3 + index % 14;
            const start = actual_written;
            scalar(&expected, &expected_written, distance, len);
            M.appendForwardWildcopy16Once(actual[0 .. start + 16], &actual_written, start - distance, len);
            try std.testing.expectEqual(expected_written, actual_written);
            try std.testing.expectEqualSlices(u8, expected[0..expected_written], actual[0..actual_written]);
            // Temporary bytes inside the 16-byte window are not yet output.
            try std.testing.expectEqualSlices(u8, expected[start + 16 ..], actual[start + 16 ..]);
        }
    };
}
