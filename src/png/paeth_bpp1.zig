//! Flat upper Paeth blocks reduce exactly to byte-stride Sub prefix sums.
const std = @import("std");

/// A cheap row admission keeps dense upper rows on their established loop.
/// Content only determines performance; both branches reconstruct exact Paeth.
pub inline fn hasFlatPrefix(previous: []const u8) bool {
    if (previous.len < 17) return false;
    const upper: @Vector(16, u8) = previous[1..][0..16].*;
    return @reduce(.Max, upper ^ @as(@Vector(16, u8), @splat(previous[0]))) == 0;
}

pub fn reconstruct(filtered: []const u8, previous: []const u8, output: []u8) void {
    if (filtered.len == 0) return;
    output[0] = filtered[0] +% previous[0];
    var left = output[0];
    var up_left = previous[0];
    var i: usize = 1;
    const lanes = 16;
    while (i + lanes <= filtered.len) {
        const upper: @Vector(lanes, u8) = previous[i..][0..lanes].*;
        if (@reduce(.Max, upper ^ @as(@Vector(lanes, u8), @splat(up_left))) == 0) {
            var prefix: @Vector(lanes, u8) = filtered[i..][0..lanes].*;
            inline for (.{ 1, 2, 4, 8 }) |offset| prefix +%= std.simd.shiftElementsRight(prefix, offset, 0);
            prefix +%= @splat(left);
            output[i..][0..lanes].* = prefix;
            left = prefix[lanes - 1];
            i += lanes;
        } else {
            const end = i + lanes;
            while (i < end) : (i += 1) {
                const up = previous[i];
                const value = filtered[i] +% predictor(left, up, up_left);
                output[i] = value;
                left = value;
                up_left = up;
            }
        }
    }
    while (i < filtered.len) : (i += 1) {
        const up = previous[i];
        const value = filtered[i] +% predictor(left, up, up_left);
        output[i] = value;
        left = value;
        up_left = up;
    }
}

inline fn predictor(left_byte: u8, up_byte: u8, up_left_byte: u8) u8 {
    const left: i16 = left_byte;
    const up: i16 = up_byte;
    const up_left: i16 = up_left_byte;
    const threshold = up_left * 3 - (left + up);
    const low = @min(left, up);
    const high = @max(left, up);
    const first = if (high <= threshold) low else up_left;
    return @intCast(if (threshold <= low) high else first);
}

fn reference(left: u8, up: u8, up_left: u8) u8 {
    const p = @as(i32, left) + up - up_left;
    const pa = @abs(p - left);
    const pb = @abs(p - up);
    const pc = @abs(p - up_left);
    if (pa <= pb and pa <= pc) return left;
    if (pb <= pc) return up;
    return up_left;
}

test "byte-stride Paeth predictor preserves full byte domain and ties" {
    for (0..256) |a| for (0..256) |b| for (0..256) |c| {
        try std.testing.expectEqual(reference(@intCast(a), @intCast(b), @intCast(c)), predictor(@intCast(a), @intCast(b), @intCast(c)));
    };
}

test "byte-stride Paeth carried state matches scalar and in-place odd rows" {
    var bytes: [4097]u8 = undefined;
    var prev: [4097]u8 = undefined;
    var expected: [4097]u8 = undefined;
    var output: [4097]u8 = undefined;
    for (&bytes, &prev, 0..) |*value, *up, i| {
        value.* = @truncate(i *% 7919 + i / 11);
        up.* = @truncate(i *% 73 + i / 7);
    }
    for ([_]usize{ 0, 1, 2, 3, 7, 17, 33, 255, 935, 4097 }) |size| {
        for (bytes[0..size], 0..) |value, i| expected[i] = value +% reference(if (i == 0) 0 else expected[i - 1], prev[i], if (i == 0) 0 else prev[i - 1]);
        reconstruct(bytes[0..size], prev[0..size], output[0..size]);
        try std.testing.expectEqualSlices(u8, expected[0..size], output[0..size]);
        @memcpy(output[0..size], bytes[0..size]);
        reconstruct(output[0..size], prev[0..size], output[0..size]);
        try std.testing.expectEqualSlices(u8, expected[0..size], output[0..size]);
    }
}

test "byte-stride Paeth flat upper blocks retain vector scalar and in-place boundaries" {
    var input: [257]u8 = undefined;
    var previous: [257]u8 = undefined;
    var expected: [257]u8 = undefined;
    var actual: [257]u8 = undefined;
    for (&input, 0..) |*value, i| value.* = @truncate(i *% 73 + i / 11);
    for ([_]u8{ 0, 1, 127, 255 }) |flat| for ([_]usize{ 1, 7, 16, 17, 33, 65, 257 }) |width| {
        @memset(&previous, flat);
        for (0..3) |pattern| {
            if (pattern == 1) previous[width / 2] = flat +% 1;
            if (pattern == 2) for (&previous, 0..) |*v, i| {
                v.* = if ((i / 16) % 3 == 0) flat else @truncate(i);
            };
            for (input[0..width], 0..) |value, i| expected[i] = value +% reference(if (i == 0) 0 else expected[i - 1], previous[i], if (i == 0) 0 else previous[i - 1]);
            reconstruct(input[0..width], previous[0..width], actual[0..width]);
            try std.testing.expectEqualSlices(u8, expected[0..width], actual[0..width]);
            @memcpy(actual[0..width], input[0..width]);
            reconstruct(actual[0..width], previous[0..width], actual[0..width]);
            try std.testing.expectEqualSlices(u8, expected[0..width], actual[0..width]);
        }
    };
}

test "byte-stride Paeth prefix admission stays within exact row bounds" {
    var previous: [33]u8 = @splat(127);
    for (0..17) |size| try std.testing.expect(!hasFlatPrefix(previous[0..size]));
    try std.testing.expect(hasFlatPrefix(previous[0..17]));
    for (1..17) |index| {
        previous[index] = 128;
        try std.testing.expect(!hasFlatPrefix(&previous));
        previous[index] = 127;
    }
    previous[17] = 128;
    try std.testing.expect(hasFlatPrefix(&previous));
}
