//! Wrapped-source matches for the ring-aware semantic window. The destination
//! remains contiguous; only the rare crossing source needs split/replay copy.
const std = @import("std");
const Error = @import("../../core.zig").Error;

pub inline fn copyWrapped(output: []u8, pos: usize, length: usize, distance: usize) Error!void {
    if (distance <= pos or distance > 32768 or distance > output.len) return error.InvalidMatch;
    if (pos > output.len or length > output.len - pos) return error.OutputTooSmall;
    const source = output.len - (distance - pos);
    if (distance == 1) {
        @memset(output[pos..][0..length], output[source]);
    } else if (source + length <= output.len) {
        // The virtual source is in the preceding lap and physically well
        // beyond the destination. Short-word stores retain proven headroom.
        if (length <= 8 and source + 8 <= output.len and output.len - pos >= 8) {
            output[pos..][0..8].* = output[source..][0..8].*;
        } else {
            @memcpy(output[pos..][0..length], output[source..][0..length]);
        }
    } else if (distance >= length) {
        const first = output.len - source;
        @memcpy(output[pos..][0..first], output[source..]);
        @memcpy(output[pos + first ..][0 .. length - first], output[0 .. length - first]);
    } else {
        var i: usize = 0;
        while (i < length) : (i += 1) {
            const from = (source + i) % output.len;
            output[pos + i] = output[from];
        }
    }
}

test "ring window wrapped source preserves overlap split and speculative guards" {
    var original: [65536]u8 = undefined;
    for (&original, 0..) |*byte, i| byte.* = @truncate(i *% 73 +% i / 17);
    for ([_]usize{ 0, 1, 7, 63, 255 }) |pos| {
        for ([_]usize{ 1, 2, 4, 8, 64, 256, 32768 }) |distance| {
            if (distance <= pos) continue;
            for ([_]usize{ 3, 7, 8, 17, 258 }) |length| {
                var expected = original;
                var active = original;
                const start = original.len - (distance - pos);
                for (0..length) |i| expected[pos + i] = expected[(start + i) % original.len];
                try copyWrapped(&active, pos, length, distance);
                try std.testing.expectEqualSlices(u8, expected[pos..][0..length], active[pos..][0..length]);
                for (active[pos + @max(length, 8) ..], original[pos + @max(length, 8) ..]) |a, b|
                    try std.testing.expectEqual(a, b);
            }
        }
    }
}
