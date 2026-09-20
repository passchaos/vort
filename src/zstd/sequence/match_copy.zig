const std = @import("std");

/// Replay a match whose source is entirely in the current output frame.
/// Non-overlapping matches use one memcpy; overlapping matches seed one period
/// and then double the initialized prefix, preserving LZ semantics without a
/// byte-at-a-time loop.
pub fn append(
    output: []u8,
    written: *usize,
    repeat_start: usize,
    match_len: usize,
) void {
    const distance = written.* - repeat_start;
    const destination_start = written.*;
    written.* += match_len;
    if (match_len <= distance) {
        @memcpy(
            output[destination_start..][0..match_len],
            output[repeat_start..][0..match_len],
        );
        return;
    }

    @memcpy(
        output[destination_start..][0..distance],
        output[repeat_start..][0..distance],
    );
    var copied = distance;
    while (copied < match_len) {
        const copy_len = @min(copied, match_len - copied);
        @memcpy(
            output[destination_start + copied ..][0..copy_len],
            output[destination_start..][0..copy_len],
        );
        copied += copy_len;
    }
}

pub inline fn appendNonOverlapping71(
    output: []u8,
    written: *usize,
    repeat_start: usize,
) void {
    const destination_start = written.*;
    std.debug.assert(destination_start - repeat_start >= 71);
    const first: @Vector(32, u8) = output[repeat_start..][0..32].*;
    const second: @Vector(32, u8) = output[repeat_start + 32 ..][0..32].*;
    output[destination_start..][0..32].* = first;
    output[destination_start + 32 ..][0..32].* = second;
    @memcpy(output[destination_start + 64 ..][0..7], output[repeat_start + 64 ..][0..7]);
    written.* += 71;
}

/// Copy the other dense Zstd match-length cluster beside the 71-byte fast
/// path. Fixed-size array moves keep these 68--70 byte non-overlapping matches
/// out of the dynamic-length memmove path while preserving exact output bounds.
pub inline fn appendNonOverlapping68To70(
    output: []u8,
    written: *usize,
    repeat_start: usize,
    match_len: usize,
) void {
    const destination_start = written.*;
    std.debug.assert(match_len >= 68 and match_len <= 70);
    std.debug.assert(destination_start - repeat_start >= match_len);
    const first: @Vector(32, u8) = output[repeat_start..][0..32].*;
    const second: @Vector(32, u8) = output[repeat_start + 32 ..][0..32].*;
    output[destination_start..][0..32].* = first;
    output[destination_start + 32 ..][0..32].* = second;
    switch (match_len) {
        68 => output[destination_start + 64 ..][0..4].* = output[repeat_start + 64 ..][0..4].*,
        69 => {
            output[destination_start + 64 ..][0..4].* = output[repeat_start + 64 ..][0..4].*;
            output[destination_start + 68] = output[repeat_start + 68];
        },
        70 => {
            output[destination_start + 64 ..][0..4].* = output[repeat_start + 64 ..][0..4].*;
            output[destination_start + 68 ..][0..2].* = output[repeat_start + 68 ..][0..2].*;
        },
        else => unreachable,
    }
    written.* += match_len;
}

/// Expand the common eight-byte, distance-seven match with two exact four-byte
/// copies. The second load observes the first byte just written, matching LZ
/// overlap semantics without entering the generic seed-and-double loop.
pub inline fn appendOverlapping8Offset7(
    output: []u8,
    written: *usize,
) void {
    const destination_start = written.*;
    std.debug.assert(destination_start >= 7);
    const repeat_start = destination_start - 7;
    const first = output[repeat_start..][0..4].*;
    output[destination_start..][0..4].* = first;
    const second = output[repeat_start + 4 ..][0..4].*;
    output[destination_start + 4 ..][0..4].* = second;
    written.* += 8;
}

pub inline fn appendNonOverlapping23(
    output: []u8,
    written: *usize,
    repeat_start: usize,
) void {
    const destination_start = written.*;
    std.debug.assert(destination_start - repeat_start >= 23);
    const first: @Vector(16, u8) = output[repeat_start..][0..16].*;
    output[destination_start..][0..16].* = first;
    @memcpy(output[destination_start + 16 ..][0..7], output[repeat_start + 16 ..][0..7]);
    written.* += 23;
}

pub inline fn appendNonOverlapping48(
    output: []u8,
    written: *usize,
    repeat_start: usize,
) void {
    const destination_start = written.*;
    std.debug.assert(destination_start - repeat_start >= 48);
    const first: @Vector(32, u8) = output[repeat_start..][0..32].*;
    const second: @Vector(16, u8) = output[repeat_start + 32 ..][0..16].*;
    output[destination_start..][0..32].* = first;
    output[destination_start + 32 ..][0..16].* = second;
    written.* += 48;
}

pub inline fn appendNonOverlapping56(
    output: []u8,
    written: *usize,
    repeat_start: usize,
) void {
    const destination_start = written.*;
    std.debug.assert(destination_start - repeat_start >= 56);
    const first: @Vector(32, u8) = output[repeat_start..][0..32].*;
    const second: @Vector(16, u8) = output[repeat_start + 32 ..][0..16].*;
    const tail = output[repeat_start + 48 ..][0..8].*;
    output[destination_start..][0..32].* = first;
    output[destination_start + 32 ..][0..16].* = second;
    output[destination_start + 48 ..][0..8].* = tail;
    written.* += 56;
}

test "Zstd match copy preserves overlapping periods" {
    var output: [80]u8 = undefined;
    @memcpy(output[0..5], "abcde");
    var written: usize = 5;
    append(&output, &written, 0, 37);
    try std.testing.expectEqual(@as(usize, 42), written);
    for (output[0..written], 0..) |byte, index| {
        try std.testing.expectEqual("abcde"[index % 5], byte);
    }
}

test "Zstd match copy handles non-overlapping source" {
    var output: [16]u8 = undefined;
    @memcpy(output[0..8], "abcdefgh");
    var written: usize = 8;
    append(&output, &written, 0, 4);
    try std.testing.expectEqualSlices(u8, "abcdefghabcd", output[0..written]);
}

test "Zstd fixed 71-byte match copy preserves output tail" {
    var expected: [256]u8 = undefined;
    for (&expected, 0..) |*byte, index| byte.* = @truncate(index * 37 + index / 11);
    var actual = expected;
    var expected_written: usize = 96;
    var actual_written = expected_written;
    append(&expected, &expected_written, 17, 71);
    appendNonOverlapping71(&actual, &actual_written, 17);
    try std.testing.expectEqual(expected_written, actual_written);
    try std.testing.expectEqualSlices(u8, &expected, &actual);
}

test "Zstd fixed 68 through 70 byte match copies preserve output tail" {
    for (68..71) |match_len| {
        var expected: [256]u8 = undefined;
        for (&expected, 0..) |*byte, index| byte.* = @truncate(index * 37 + index / 11);
        var actual = expected;
        var expected_written: usize = 96;
        var actual_written = expected_written;
        append(&expected, &expected_written, 17, match_len);
        appendNonOverlapping68To70(&actual, &actual_written, 17, match_len);
        try std.testing.expectEqual(expected_written, actual_written);
        try std.testing.expectEqualSlices(u8, &expected, &actual);
    }
}

test "Zstd fixed distance-seven match preserves overlap and output tail" {
    var expected: [64]u8 = undefined;
    for (&expected, 0..) |*byte, index| byte.* = @truncate(index * 37 + 11);
    var actual = expected;
    var expected_written: usize = 23;
    var actual_written = expected_written;
    append(&expected, &expected_written, expected_written - 7, 8);
    appendOverlapping8Offset7(&actual, &actual_written);
    try std.testing.expectEqual(expected_written, actual_written);
    try std.testing.expectEqualSlices(u8, &expected, &actual);
}

test "Zstd fixed 23-byte match preserves output tail" {
    var expected: [96]u8 = undefined;
    for (&expected, 0..) |*byte, index| byte.* = @truncate(index * 37 + 11);
    var actual = expected;
    var expected_written: usize = 48;
    var actual_written = expected_written;
    append(&expected, &expected_written, 17, 23);
    appendNonOverlapping23(&actual, &actual_written, 17);
    try std.testing.expectEqual(expected_written, actual_written);
    try std.testing.expectEqualSlices(u8, &expected, &actual);
}

test "Zstd fixed 48-byte match preserves output tail" {
    var expected: [160]u8 = undefined;
    for (&expected, 0..) |*byte, index| byte.* = @truncate(index * 37 + 11);
    var actual = expected;
    var expected_written: usize = 80;
    var actual_written = expected_written;
    append(&expected, &expected_written, 17, 48);
    appendNonOverlapping48(&actual, &actual_written, 17);
    try std.testing.expectEqual(expected_written, actual_written);
    try std.testing.expectEqualSlices(u8, &expected, &actual);
}

test "Zstd fixed 56-byte match copy preserves output tail" {
    var expected: [160]u8 = undefined;
    for (&expected, 0..) |*byte, index| byte.* = @truncate(index * 37 + 11);
    var actual = expected;
    var expected_written: usize = 80;
    var actual_written = expected_written;
    append(&expected, &expected_written, 17, 56);
    appendNonOverlapping56(&actual, &actual_written, 17);
    try std.testing.expectEqual(expected_written, actual_written);
    try std.testing.expectEqualSlices(u8, &expected, &actual);
}
