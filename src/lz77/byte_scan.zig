//! Exact backwards byte search for the scalar-window LZ77 candidate order.
const std = @import("std");

/// Return the last matching byte in [start, end). The newest byte is probed
/// first for common short-distance runs; full vectors skip impossible anchors
/// without changing which matching candidates consume the parser's budget.
pub fn previous(input: []const u8, start: usize, end: usize, needle: u8) ?usize {
    std.debug.assert(start <= end and end <= input.len);
    var cursor = end;
    if (cursor > start) {
        cursor -= 1;
        if (input[cursor] == needle) return cursor;
    }
    const lanes: @Vector(32, u8) = .{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32 };
    while (cursor - start >= 32) {
        const begin = cursor - 32;
        const bytes: @Vector(32, u8) = @bitCast(input[begin..][0..32].*);
        const selected = @reduce(.Max, @select(u8, bytes == @as(@Vector(32, u8), @splat(needle)), lanes, @as(@Vector(32, u8), @splat(0))));
        if (selected != 0) return begin + selected - 1;
        cursor = begin;
    }
    while (cursor > start) {
        cursor -= 1;
        if (input[cursor] == needle) return cursor;
    }
    return null;
}

fn scalar(input: []const u8, start: usize, end: usize, needle: u8) ?usize {
    var cursor = end;
    while (cursor > start) {
        cursor -= 1;
        if (input[cursor] == needle) return cursor;
    }
    return null;
}

test "LZ77 backwards byte scan preserves every needle and range across unaligned vector boundaries" {
    var data: [161]u8 = undefined;
    for (&data, 0..) |*byte, i| byte.* = @truncate(i * 37 + i / 7);
    for (0..32) |start| {
        for (start..data.len + 1) |end| for (0..256) |value| {
            const needle: u8 = @intCast(value);
            try std.testing.expectEqual(scalar(&data, start, end, needle), previous(&data, start, end, needle));
        };
    }
}

test "LZ77 backwards byte scan preserves exact candidate traversal for repeated and absent anchors" {
    var data: [32769]u8 = @splat(0);
    for ([_]usize{ 0, 1, 30, 31, 32, 33, 127, 1024, 32767, 32768 }) |at| data[at] = 255;
    var end: usize = data.len;
    while (end != 0) {
        const expected = scalar(&data, 0, end, 255);
        try std.testing.expectEqual(expected, previous(&data, 0, end, 255));
        end = expected orelse break;
    }
    try std.testing.expectEqual(@as(?usize, null), previous(&data, 1, data.len, 123));
    try std.testing.expectEqual(data.len - 3, previous(&data, 0, data.len - 1, 0));
}
