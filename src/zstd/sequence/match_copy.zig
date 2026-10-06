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
    const tail = output[repeat_start + 63 ..][0..8].*;
    output[destination_start..][0..32].* = first;
    output[destination_start + 32 ..][0..32].* = second;
    if (output.len - destination_start >= 72) {
        const source_tail = std.mem.readInt(u64, &tail, .little) >> 8;
        const preserved_suffix = @as(u64, output[destination_start + 71]) << 56;
        std.mem.writeInt(
            u64,
            output[destination_start + 64 ..][0..8],
            source_tail | preserved_suffix,
            .little,
        );
    } else {
        output[destination_start + 64 ..][0..4].* = tail[1..5].*;
        output[destination_start + 68 ..][0..2].* = tail[5..7].*;
        output[destination_start + 70] = tail[7];
    }
    written.* += 71;
}

/// Copy exactly 71 bytes with an in-range overlapping tail store. All source
/// loads happen before the first destination write, preserving the minimum
/// non-overlap distance while avoiding a destination-suffix read.
pub inline fn appendNonOverlapping71OverlapTail(
    output: []u8,
    written: *usize,
    repeat_start: usize,
) void {
    const destination_start = written.*;
    std.debug.assert(destination_start - repeat_start >= 71);
    const first: @Vector(32, u8) = output[repeat_start..][0..32].*;
    const second: @Vector(32, u8) = output[repeat_start + 32 ..][0..32].*;
    // Preserve the intentional overlapping eight-byte move. Without the
    // volatile access LLVM removes its redundant first byte and lowers the
    // seven remaining bytes into 4+2+1 scalar loads and stores.
    const tail_source: *align(1) const volatile u64 = @ptrCast(output[repeat_start + 63 ..].ptr);
    const tail = tail_source.*;
    output[destination_start..][0..32].* = first;
    const second_destination: *align(1) volatile @Vector(32, u8) = @ptrCast(output[destination_start + 32 ..].ptr);
    second_destination.* = second;
    const tail_destination: *align(1) volatile u64 = @ptrCast(output[destination_start + 63 ..].ptr);
    tail_destination.* = tail;
    written.* += 71;
}

/// Copy a 70-byte match at the head of a two-sequence pair. The caller proves
/// that at least two following output bytes will be replaced by the second
/// sequence, so the final eight-byte move may write through byte 72. Loading
/// the tail after the first 64 bytes also supports the minimum distance 70.
pub inline fn appendNonOverlapping70PairHead(
    output: []u8,
    written: *usize,
    repeat_start: usize,
) void {
    const destination_start = written.*;
    std.debug.assert(destination_start - repeat_start >= 70);
    std.debug.assert(output.len - destination_start >= 72);
    const first: @Vector(32, u8) = output[repeat_start..][0..32].*;
    const second: @Vector(32, u8) = output[repeat_start + 32 ..][0..32].*;
    output[destination_start..][0..32].* = first;
    output[destination_start + 32 ..][0..32].* = second;
    output[destination_start + 64 ..][0..8].* = output[repeat_start + 64 ..][0..8].*;
    written.* += 70;
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

pub inline fn appendNonOverlapping6Or7(
    output: []u8,
    written: *usize,
    repeat_start: usize,
    match_len: usize,
) void {
    const destination_start = written.*;
    std.debug.assert(match_len == 6 or match_len == 7);
    std.debug.assert(destination_start - repeat_start >= match_len);
    output[destination_start..][0..4].* = output[repeat_start..][0..4].*;
    output[destination_start + 4 ..][0..2].* = output[repeat_start + 4 ..][0..2].*;
    if (match_len == 7) output[destination_start + 6] = output[repeat_start + 6];
    written.* += match_len;
}

/// Copy the minimum three-byte Zstd match without entering the dynamic
/// memmove path. The caller proves that the source and destination do not
/// overlap, so three exact byte stores preserve both LZ semantics and the
/// caller's output suffix.
pub inline fn appendNonOverlapping3(
    output: []u8,
    written: *usize,
    repeat_start: usize,
) void {
    const destination_start = written.*;
    std.debug.assert(destination_start - repeat_start >= 3);
    output[destination_start] = output[repeat_start];
    output[destination_start + 1] = output[repeat_start + 1];
    output[destination_start + 2] = output[repeat_start + 2];
    written.* += 3;
}

/// Copy a non-overlapping 4--7-byte match. The exact form uses first/last
/// four-byte stores. `allow_wildcopy` may write through byte eight only when
/// the caller has clipped `output` to the declared frame end, so bytes beyond
/// the caller's logical frame slice remain untouched.
pub inline fn appendNonOverlapping4To7(
    output: []u8,
    written: *usize,
    repeat_start: usize,
    match_len: usize,
    comptime allow_wildcopy: bool,
) void {
    const destination_start = written.*;
    std.debug.assert(match_len >= 4 and match_len <= 7);
    std.debug.assert(destination_start - repeat_start >= match_len);
    if (allow_wildcopy and destination_start - repeat_start >= 8 and output.len - destination_start >= 8) {
        output[destination_start..][0..8].* = output[repeat_start..][0..8].*;
        written.* += match_len;
        return;
    }
    const first = output[repeat_start..][0..4].*;
    const last = output[repeat_start + match_len - 4 ..][0..4].*;
    output[destination_start..][0..4].* = first;
    output[destination_start + match_len - 4 ..][0..4].* = last;
    written.* += match_len;
}

/// Copy an 8--15-byte non-overlapping match. The optional 16-byte wildcopy has
/// the same clipped-frame-end contract as `appendNonOverlapping4To7`.
pub inline fn appendNonOverlapping8To15(
    output: []u8,
    written: *usize,
    repeat_start: usize,
    match_len: usize,
    comptime allow_wildcopy: bool,
) void {
    const destination_start = written.*;
    std.debug.assert(match_len >= 8 and match_len <= 15);
    std.debug.assert(destination_start - repeat_start >= match_len);
    if (allow_wildcopy and destination_start - repeat_start >= 16 and output.len - destination_start >= 16) {
        const chunk: @Vector(16, u8) = output[repeat_start..][0..16].*;
        output[destination_start..][0..16].* = chunk;
        written.* += match_len;
        return;
    }
    const first = output[repeat_start..][0..8].*;
    const last = output[repeat_start + match_len - 8 ..][0..8].*;
    output[destination_start..][0..8].* = first;
    output[destination_start + match_len - 8 ..][0..8].* = last;
    written.* += match_len;
}

/// Copy a match in 16-byte forward chunks. `distance >= 16` is sufficient:
/// each source vector is fully initialized before the corresponding store,
/// even when the logical match overlaps. The caller must provide writable
/// space through `roundUp(match_len, 16)`; bytes after the logical match are
/// intentional wildcopy padding and must remain inside the current frame.
pub inline fn appendForwardWildcopy16(
    output: []u8,
    written: *usize,
    repeat_start: usize,
    match_len: usize,
) void {
    const destination_start = written.*;
    const distance = destination_start - repeat_start;
    const rounded_len = (match_len + 15) & ~@as(usize, 15);
    std.debug.assert(match_len != 0);
    std.debug.assert(distance >= 16);
    std.debug.assert(output.len - destination_start >= rounded_len);

    var copied: usize = 0;
    while (copied < rounded_len) : (copied += 16) {
        const chunk: @Vector(16, u8) = output[repeat_start + copied ..][0..16].*;
        output[destination_start + copied ..][0..16].* = chunk;
    }
    written.* += match_len;
}

/// Copy a match of at most 16 bytes with exactly one 16-byte move. The caller
/// must prove both a non-overlapping 16-byte source and writable space through
/// the complete destination vector.
pub inline fn appendForwardWildcopy16Once(
    output: []u8,
    written: *usize,
    repeat_start: usize,
    match_len: usize,
) void {
    const destination_start = written.*;
    std.debug.assert(match_len > 0 and match_len <= 16);
    std.debug.assert(destination_start - repeat_start >= 16);
    std.debug.assert(output.len - destination_start >= 16);

    const chunk: @Vector(16, u8) = output[repeat_start..][0..16].*;
    output[destination_start..][0..16].* = chunk;
    written.* += match_len;
}

/// Copy a match in 32-byte forward chunks when the initialized history and
/// caller-owned frame suffix both cover the wider access. Callers retain the
/// 16-byte helper when either side has less than one complete 32-byte window.
pub inline fn appendForwardWildcopy32(
    output: []u8,
    written: *usize,
    repeat_start: usize,
    match_len: usize,
) void {
    const destination_start = written.*;
    const distance = destination_start - repeat_start;
    const rounded_len = (match_len + 31) & ~@as(usize, 31);
    std.debug.assert(match_len != 0);
    std.debug.assert(distance >= 32);
    std.debug.assert(output.len - destination_start >= rounded_len);

    var copied: usize = 0;
    while (copied < rounded_len) : (copied += 32) {
        const chunk: @Vector(32, u8) = output[repeat_start + copied ..][0..32].*;
        output[destination_start + copied ..][0..32].* = chunk;
    }
    written.* += match_len;
}

pub inline fn appendForwardWildcopy64(
    output: []u8,
    written: *usize,
    repeat_start: usize,
    match_len: usize,
) void {
    const destination_start = written.*;
    const distance = destination_start - repeat_start;
    const rounded_len = (match_len + 63) & ~@as(usize, 63);
    std.debug.assert(match_len != 0);
    std.debug.assert(distance >= 64);
    std.debug.assert(output.len - destination_start >= rounded_len);

    var copied: usize = 0;
    while (copied < rounded_len) : (copied += 64) {
        const first: @Vector(32, u8) = output[repeat_start + copied ..][0..32].*;
        const second: @Vector(32, u8) = output[repeat_start + copied + 32 ..][0..32].*;
        output[destination_start + copied ..][0..32].* = first;
        output[destination_start + copied + 32 ..][0..32].* = second;
    }
    written.* += match_len;
}

pub inline fn appendForwardWildcopy(
    output: []u8,
    written: *usize,
    repeat_start: usize,
    match_len: usize,
) bool {
    const destination_start = written.*;
    const distance = destination_start - repeat_start;
    const rounded_len_64 = (match_len + 63) & ~@as(usize, 63);
    if (distance >= 64 and output.len - destination_start >= rounded_len_64) {
        appendForwardWildcopy64(output, written, repeat_start, match_len);
        return true;
    }
    const rounded_len_32 = (match_len + 31) & ~@as(usize, 31);
    if (distance >= 32 and output.len - destination_start >= rounded_len_32) {
        appendForwardWildcopy32(output, written, repeat_start, match_len);
        return true;
    }
    appendForwardWildcopy16(output, written, repeat_start, match_len);
    return false;
}

pub inline fn appendNonOverlapping16To31(
    output: []u8,
    written: *usize,
    repeat_start: usize,
    match_len: usize,
) void {
    const destination_start = written.*;
    std.debug.assert(match_len >= 16 and match_len <= 31);
    std.debug.assert(destination_start - repeat_start >= match_len);
    const first: @Vector(16, u8) = output[repeat_start..][0..16].*;
    const last: @Vector(16, u8) = output[repeat_start + match_len - 16 ..][0..16].*;
    output[destination_start..][0..16].* = first;
    output[destination_start + match_len - 16 ..][0..16].* = last;
    written.* += match_len;
}

pub inline fn appendNonOverlapping32To63(
    output: []u8,
    written: *usize,
    repeat_start: usize,
    match_len: usize,
) void {
    const destination_start = written.*;
    std.debug.assert(match_len >= 32 and match_len <= 63);
    std.debug.assert(destination_start - repeat_start >= match_len);
    const first: @Vector(32, u8) = output[repeat_start..][0..32].*;
    const last: @Vector(32, u8) = output[repeat_start + match_len - 32 ..][0..32].*;
    output[destination_start..][0..32].* = first;
    output[destination_start + match_len - 32 ..][0..32].* = last;
    written.* += match_len;
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

    var tight_expected: [167]u8 = undefined;
    for (&tight_expected, 0..) |*byte, index| byte.* = @truncate(index * 37 + index / 11);
    var tight_actual = tight_expected;
    expected_written = 96;
    actual_written = expected_written;
    append(&tight_expected, &expected_written, 17, 71);
    appendNonOverlapping71(&tight_actual, &actual_written, 17);
    try std.testing.expectEqual(expected_written, actual_written);
    try std.testing.expectEqualSlices(u8, &tight_expected, &tight_actual);
}

test "Zstd fixed 71-byte overlapping-tail copy preserves output tail" {
    for (71..75) |distance| {
        var expected: [256]u8 = undefined;
        for (&expected, 0..) |*byte, index| byte.* = @truncate(index * 37 + index / 11);
        var actual = expected;
        var expected_written: usize = 96;
        var actual_written = expected_written;
        append(&expected, &expected_written, expected_written - distance, 71);
        appendNonOverlapping71OverlapTail(&actual, &actual_written, actual_written - distance);
        try std.testing.expectEqual(expected_written, actual_written);
        try std.testing.expectEqualSlices(u8, &expected, &actual);
    }
}

test "Zstd 70-byte pair-head copy preserves the following sequence" {
    for (80..96) |destination_start| {
        for (70..75) |distance| {
            for ([_]usize{ 3, 4, 16, 68, 69, 70, 71 }) |second_match_len| {
                var expected: [256]u8 = undefined;
                for (&expected, 0..) |*byte, index| byte.* = @truncate(index * 37 + index / 11);
                var actual = expected;
                var expected_written = destination_start;
                var actual_written = expected_written;

                expected[expected_written] = 0x5a;
                actual[actual_written] = 0x5a;
                expected_written += 1;
                actual_written += 1;
                append(&expected, &expected_written, expected_written - distance, 70);
                appendNonOverlapping70PairHead(&actual, &actual_written, actual_written - distance);

                expected[expected_written] = 0xa5;
                actual[actual_written] = 0xa5;
                expected_written += 1;
                actual_written += 1;
                append(&expected, &expected_written, expected_written - distance, second_match_len);
                append(&actual, &actual_written, actual_written - distance, second_match_len);

                try std.testing.expectEqual(expected_written, actual_written);
                try std.testing.expectEqualSlices(u8, &expected, &actual);
            }
        }
    }
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

test "Zstd fixed eight through fifteen byte matches preserve output tail" {
    for (8..16) |match_len| {
        var expected: [64]u8 = undefined;
        for (&expected, 0..) |*byte, index| byte.* = @truncate(index * 37 + 11);
        var actual = expected;
        var expected_written: usize = 23;
        var actual_written = expected_written;
        append(&expected, &expected_written, 7, match_len);
        appendNonOverlapping8To15(&actual, &actual_written, 7, match_len, false);
        try std.testing.expectEqual(expected_written, actual_written);
        try std.testing.expectEqualSlices(u8, &expected, &actual);
    }
}

test "Zstd fixed three-byte match preserves output tail" {
    var expected: [32]u8 = undefined;
    for (&expected, 0..) |*byte, index| byte.* = @truncate(index * 37 + 11);
    var actual = expected;
    var expected_written: usize = 17;
    var actual_written = expected_written;
    append(&expected, &expected_written, 5, 3);
    appendNonOverlapping3(&actual, &actual_written, 5);
    try std.testing.expectEqual(expected_written, actual_written);
    try std.testing.expectEqualSlices(u8, &expected, &actual);
}

test "Zstd fixed sixteen through thirty-one byte matches preserve output tail" {
    for (16..32) |match_len| {
        var expected: [96]u8 = undefined;
        for (&expected, 0..) |*byte, index| byte.* = @truncate(index * 37 + 11);
        var actual = expected;
        var expected_written: usize = 48;
        var actual_written = expected_written;
        append(&expected, &expected_written, 7, match_len);
        appendNonOverlapping16To31(&actual, &actual_written, 7, match_len);
        try std.testing.expectEqual(expected_written, actual_written);
        try std.testing.expectEqualSlices(u8, &expected, &actual);
    }
}

test "Zstd fixed thirty-two through sixty-three byte matches preserve output tail" {
    for (32..64) |match_len| {
        var expected: [160]u8 = undefined;
        for (&expected, 0..) |*byte, index| byte.* = @truncate(index * 37 + 11);
        var actual = expected;
        var expected_written: usize = 80;
        var actual_written = expected_written;
        append(&expected, &expected_written, 7, match_len);
        appendNonOverlapping32To63(&actual, &actual_written, 7, match_len);
        try std.testing.expectEqual(expected_written, actual_written);
        try std.testing.expectEqualSlices(u8, &expected, &actual);
    }
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

test "Zstd fixed six and seven byte match copies preserve output tail" {
    inline for (.{ @as(usize, 6), @as(usize, 7) }) |match_len| {
        var expected: [48]u8 = undefined;
        for (&expected, 0..) |*byte, index| byte.* = @truncate(index * 37 + 11);
        var actual = expected;
        var expected_written: usize = 24;
        var actual_written = expected_written;
        append(&expected, &expected_written, 8, match_len);
        appendNonOverlapping6Or7(&actual, &actual_written, 8, match_len);
        try std.testing.expectEqual(expected_written, actual_written);
        try std.testing.expectEqualSlices(u8, &expected, &actual);
    }
}

test "Zstd fixed four through seven byte match copies preserve output tail" {
    for (4..8) |match_len| {
        var expected: [64]u8 = undefined;
        for (&expected, 0..) |*byte, index| byte.* = @truncate(index * 37 + 11);
        var actual = expected;
        var expected_written: usize = 23;
        var actual_written = expected_written;
        append(&expected, &expected_written, 7, match_len);
        appendNonOverlapping4To7(&actual, &actual_written, 7, match_len, false);
        try std.testing.expectEqual(expected_written, actual_written);
        try std.testing.expectEqualSlices(u8, &expected, &actual);
    }
}

test "Zstd bounded short wildcopies preserve the caller suffix" {
    inline for (.{ @as(usize, 4), 5, 6, 7 }) |match_len| {
        var expected: [64]u8 = undefined;
        for (&expected, 0..) |*byte, index| byte.* = @truncate(index * 37 + 11);
        var actual = expected;
        const destination_start = 24;
        const logical_end = destination_start + 8;
        var expected_written: usize = destination_start;
        var actual_written: usize = destination_start;
        append(&expected, &expected_written, 8, match_len);
        appendNonOverlapping4To7(actual[0..logical_end], &actual_written, 8, match_len, true);
        try std.testing.expectEqual(expected_written, actual_written);
        try std.testing.expectEqualSlices(u8, expected[0..expected_written], actual[0..actual_written]);
        try std.testing.expectEqualSlices(u8, expected[logical_end..], actual[logical_end..]);
    }

    inline for (.{ @as(usize, 8), 9, 12, 15 }) |match_len| {
        var expected: [80]u8 = undefined;
        for (&expected, 0..) |*byte, index| byte.* = @truncate(index * 41 + 7);
        var actual = expected;
        const destination_start = 32;
        const logical_end = destination_start + 16;
        var expected_written: usize = destination_start;
        var actual_written: usize = destination_start;
        append(&expected, &expected_written, 8, match_len);
        appendNonOverlapping8To15(actual[0..logical_end], &actual_written, 8, match_len, true);
        try std.testing.expectEqual(expected_written, actual_written);
        try std.testing.expectEqualSlices(u8, expected[0..expected_written], actual[0..actual_written]);
        try std.testing.expectEqualSlices(u8, expected[logical_end..], actual[logical_end..]);
    }
}

test "Zstd bounded forward wildcopy handles overlapping long matches" {
    inline for (.{ @as(usize, 4), 15, 16, 17, 31, 32, 47, 64, 71 }) |match_len| {
        var expected: [160]u8 = undefined;
        for (&expected, 0..) |*byte, index| byte.* = @truncate(index * 29 + 13);
        var actual = expected;
        const destination_start = 64;
        const rounded_len = (match_len + 15) & ~@as(usize, 15);
        const logical_end = destination_start + rounded_len;
        var expected_written: usize = destination_start;
        var actual_written: usize = destination_start;
        append(&expected, &expected_written, destination_start - 16, match_len);
        appendForwardWildcopy16(actual[0..logical_end], &actual_written, destination_start - 16, match_len);
        try std.testing.expectEqual(expected_written, actual_written);
        try std.testing.expectEqualSlices(u8, expected[0..expected_written], actual[0..actual_written]);
        try std.testing.expectEqualSlices(u8, expected[logical_end..], actual[logical_end..]);
    }
}

test "Zstd single-move 16-byte wildcopy preserves logical output and suffix" {
    for (3..17) |match_len| {
        inline for (.{ @as(usize, 16), 23, 32 }) |distance| {
            var expected: [128]u8 = undefined;
            for (&expected, 0..) |*byte, index| byte.* = @truncate(index * 31 + 17);
            var actual = expected;
            const destination_start = 64;
            const writable_end = destination_start + 16;
            var expected_written: usize = destination_start;
            var actual_written: usize = destination_start;
            append(&expected, &expected_written, destination_start - distance, match_len);
            appendForwardWildcopy16Once(actual[0..writable_end], &actual_written, destination_start - distance, match_len);
            try std.testing.expectEqual(expected_written, actual_written);
            try std.testing.expectEqualSlices(u8, expected[0..expected_written], actual[0..actual_written]);
            try std.testing.expectEqualSlices(u8, expected[writable_end..], actual[writable_end..]);
        }
    }
}

test "Zstd bounded 32-byte forward wildcopy handles overlapping matches" {
    inline for (.{ @as(usize, 3), 15, 31, 32, 33, 63, 64, 95, 128 }) |match_len| {
        inline for (.{ @as(usize, 32), 47, 64 }) |distance| {
            var expected: [256]u8 = undefined;
            for (&expected, 0..) |*byte, index| byte.* = @truncate(index * 29 + 13);
            var actual = expected;
            const destination_start = 96;
            const rounded_len = (match_len + 31) & ~@as(usize, 31);
            const logical_end = destination_start + rounded_len;
            var expected_written: usize = destination_start;
            var actual_written: usize = destination_start;
            append(&expected, &expected_written, destination_start - distance, match_len);
            appendForwardWildcopy32(actual[0..logical_end], &actual_written, destination_start - distance, match_len);
            try std.testing.expectEqual(expected_written, actual_written);
            try std.testing.expectEqualSlices(u8, expected[0..expected_written], actual[0..actual_written]);
            try std.testing.expectEqualSlices(u8, expected[logical_end..], actual[logical_end..]);
        }
    }
}

test "Zstd bounded 64-byte forward wildcopy handles overlapping matches" {
    inline for (.{ @as(usize, 3), 31, 63, 64, 65, 95, 127, 128, 191 }) |match_len| {
        inline for (.{ @as(usize, 64), 95, 128 }) |distance| {
            var expected: [384]u8 = undefined;
            for (&expected, 0..) |*byte, index| byte.* = @truncate(index * 47 + 19);
            var actual = expected;
            const destination_start = 160;
            const rounded_len = (match_len + 63) & ~@as(usize, 63);
            const logical_end = destination_start + rounded_len;
            var expected_written: usize = destination_start;
            var actual_written: usize = destination_start;
            append(&expected, &expected_written, destination_start - distance, match_len);
            appendForwardWildcopy64(actual[0..logical_end], &actual_written, destination_start - distance, match_len);
            try std.testing.expectEqual(expected_written, actual_written);
            try std.testing.expectEqualSlices(u8, expected[0..expected_written], actual[0..actual_written]);
            try std.testing.expectEqualSlices(u8, expected[logical_end..], actual[logical_end..]);
        }
    }
}

test "Zstd adaptive forward wildcopy selects only a fully bounded wide copy" {
    var expected: [256]u8 = undefined;
    for (&expected, 0..) |*byte, index| byte.* = @truncate(index * 43 + 17);

    var wide = expected;
    var expected_written: usize = 96;
    var wide_written = expected_written;
    append(&expected, &expected_written, 64, 33);
    try std.testing.expect(appendForwardWildcopy(&wide, &wide_written, 64, 33));
    try std.testing.expectEqual(expected_written, wide_written);
    try std.testing.expectEqualSlices(u8, expected[0..expected_written], wide[0..wide_written]);

    var bounded = expected;
    expected_written = 96;
    var bounded_written = expected_written;
    append(&expected, &expected_written, 64, 33);
    try std.testing.expect(!appendForwardWildcopy(bounded[0 .. 96 + 48], &bounded_written, 64, 33));
    try std.testing.expectEqual(expected_written, bounded_written);
    try std.testing.expectEqualSlices(u8, expected[0..expected_written], bounded[0..bounded_written]);
    try std.testing.expectEqualSlices(u8, expected[96 + 48 ..], bounded[96 + 48 ..]);
}
