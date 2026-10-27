//! Bounded first-mismatch search with an inexpensive short-match entry.
const std = @import("std");

pub fn find(input: []const u8, a: usize, b: usize, maximum: usize) usize {
    var length: usize = 0;
    if (maximum >= 8) {
        const difference = std.mem.readInt(u64, input[a..][0..8], .little) ^
            std.mem.readInt(u64, input[b..][0..8], .little);
        if (difference != 0) return @ctz(difference) / 8;
        length = 8;
    }
    while (length + 32 <= maximum) : (length += 32) {
        const left: @Vector(32, u8) = input[a + length ..][0..32].*;
        const right: @Vector(32, u8) = input[b + length ..][0..32].*;
        const differing: u32 = ~@as(u32, @bitCast(left == right));
        if (differing != 0) return length + @ctz(differing);
    }
    while (length + 8 <= maximum) : (length += 8) {
        const difference = std.mem.readInt(u64, input[a + length ..][0..8], .little) ^
            std.mem.readInt(u64, input[b + length ..][0..8], .little);
        if (difference != 0) return length + @ctz(difference) / 8;
    }
    while (length < maximum and input[a + length] == input[b + length]) length += 1;
    return length;
}

fn scalar(input: []const u8, a: usize, b: usize, maximum: usize) usize {
    var length: usize = 0;
    while (length < maximum and input[a + length] == input[b + length]) length += 1;
    return length;
}

test "match length short entry and vector tails preserve every scalar boundary" {
    var input: [800]u8 = undefined;
    for (&input, 0..) |*byte, i| byte.* = @truncate(i * 37 + i / 11);
    for (0..8) |offset| {
        const a = offset;
        const b = 400 + offset;
        @memcpy(input[b..][0..321], input[a..][0..321]);
        for (0..322) |maximum| {
            try std.testing.expectEqual(scalar(&input, a, b, maximum), find(&input, a, b, maximum));
        }
        for (0..321) |mismatch| {
            input[b + mismatch] +%= 1;
            for ([_]usize{ 3, 7, 8, 9, 31, 32, 39, 40, 63, 64, 71, 72, 127, 128, 257, 258, 321 }) |maximum|
                try std.testing.expectEqual(scalar(&input, a, b, maximum), find(&input, a, b, maximum));
            input[b + mismatch] = input[a + mismatch];
        }
    }
    for (1..33) |distance| {
        @memset(&input, 7);
        try std.testing.expectEqual(@as(usize, 258), find(&input, 0, distance, 258));
        input[distance + 129] = 9;
        try std.testing.expectEqual(scalar(&input, 0, distance, 258), find(&input, 0, distance, 258));
    }
}
