const std = @import("std");
const kernel = @import("shortcopy.zig");

pub fn check() !void {
    var source: [512]u8 = undefined;
    for (&source, 0..) |*byte, i| byte.* = @truncate(i * 131 + i / 7);
    for (3..259) |length| {
        for (0..8) |source_offset| {
            for (0..8) |output_offset| {
                var actual: [512]u8 = @splat(0xa5);
                var expected = actual;
                const start = 32 + output_offset;
                for (0..length) |i| expected[start + i] = source[source_offset + i];
                kernel.copy(actual[start..][0..length], source[source_offset..][0..length], length);
                try std.testing.expectEqualSlices(u8, &expected, &actual);
            }
        }
    }
    // Exercise adjacent, disjoint source/destination regions in one allocation.
    for (3..259) |length| {
        var actual: [1024]u8 = @splat(0xa5);
        @memcpy(actual[16..][0..length], source[0..length]);
        var expected = actual;
        for (0..length) |i| expected[16 + length + i] = source[i];
        kernel.copy(actual[16 + length ..][0..length], actual[16..][0..length], length);
        try std.testing.expectEqualSlices(u8, &expected, &actual);
    }
}
