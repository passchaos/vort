const std = @import("std");

/// Copy a 2--15-byte literal run without entering the dynamic memmove path.
/// The overlapping first/last stores touch exactly the logical destination.
pub inline fn append2To15(
    output: []u8,
    written: *usize,
    literals: []const u8,
    literal_offset: *usize,
    literal_len: usize,
) void {
    const destination_start = written.*;
    const source_start = literal_offset.*;
    std.debug.assert(literal_len >= 2 and literal_len <= 15);

    if (literal_len < 4) {
        const first = literals[source_start..][0..2].*;
        const last = literals[source_start + literal_len - 2 ..][0..2].*;
        output[destination_start..][0..2].* = first;
        output[destination_start + literal_len - 2 ..][0..2].* = last;
    } else if (literal_len < 8) {
        const first = literals[source_start..][0..4].*;
        const last = literals[source_start + literal_len - 4 ..][0..4].*;
        output[destination_start..][0..4].* = first;
        output[destination_start + literal_len - 4 ..][0..4].* = last;
    } else {
        const first = literals[source_start..][0..8].*;
        const last = literals[source_start + literal_len - 8 ..][0..8].*;
        output[destination_start..][0..8].* = first;
        output[destination_start + literal_len - 8 ..][0..8].* = last;
    }
    written.* += literal_len;
    literal_offset.* += literal_len;
}

/// Copy a 0--15-byte literal run with one 16-byte move. The caller provides
/// initialized source padding and writable output through byte sixteen. Bytes
/// beyond the logical literal run are intentionally temporary: the following
/// match or later sequence overwrites them before the frame is returned.
pub inline fn appendUpTo15Wildcopy16(
    output: []u8,
    written: *usize,
    literals: []const u8,
    literal_offset: *usize,
    literal_len: usize,
) void {
    const destination_start = written.*;
    const source_start = literal_offset.*;
    std.debug.assert(literal_len <= 15);
    std.debug.assert(output.len - destination_start >= 16);
    std.debug.assert(literals.len - source_start >= 16);

    const chunk: @Vector(16, u8) = literals[source_start..][0..16].*;
    output[destination_start..][0..16].* = chunk;
    written.* += literal_len;
    literal_offset.* += literal_len;
}

/// Copy a literal run of any bounded length. Whole 16-byte chunks move
/// directly; the final 16-byte window handles 1--15 trailing bytes. The caller
/// guarantees 16 bytes of source padding after the run and that the following
/// match copy overwrites any destination bytes written past the logical run.
pub inline fn appendBulkWildcopy16(
    output: []u8,
    written: *usize,
    literals: []const u8,
    literal_offset: *usize,
    literal_len: usize,
) void {
    const destination_start = written.*;
    const source_start = literal_offset.*;
    std.debug.assert(literal_len != 0);
    std.debug.assert(literals.len - source_start >= literal_len + 16);

    const whole_chunks = literal_len / 16;
    var index: usize = 0;
    while (index < whole_chunks) : (index += 1) {
        const chunk: @Vector(16, u8) =
            literals[source_start + index * 16 ..][0..16].*;
        output[destination_start + index * 16 ..][0..16].* = chunk;
    }
    const tail = literal_len - whole_chunks * 16;
    if (tail != 0) {
        const chunk: @Vector(16, u8) =
            literals[source_start + literal_len - 16 ..][0..16].*;
        output[destination_start + literal_len - 16 ..][0..16].* = chunk;
    }
    written.* += literal_len;
    literal_offset.* += literal_len;
}

test "Zstd exact short literal copy preserves output suffix" {
    const literals = "abcdefghijklmnopqrstuvwxyz";
    for (2..16) |literal_len| {
        var expected: [64]u8 = @splat(0xa5);
        var actual = expected;
        @memcpy(expected[7..][0..literal_len], literals[3..][0..literal_len]);
        var written: usize = 7;
        var literal_offset: usize = 3;
        append2To15(&actual, &written, literals, &literal_offset, literal_len);
        try std.testing.expectEqual(@as(usize, 7) + literal_len, written);
        try std.testing.expectEqual(@as(usize, 3) + literal_len, literal_offset);
        try std.testing.expectEqualSlices(u8, &expected, &actual);
    }
}

test "Zstd bounded literal wildcopy preserves logical bytes and caller suffix" {
    var literals: [48]u8 = undefined;
    for (&literals, 0..) |*byte, index| byte.* = @truncate(index * 31 + 5);
    for (0..16) |literal_len| {
        var expected: [64]u8 = @splat(0xa5);
        var actual = expected;
        @memcpy(expected[7..][0..literal_len], literals[3..][0..literal_len]);
        var written: usize = 7;
        var literal_offset: usize = 3;
        appendUpTo15Wildcopy16(actual[0..23], &written, &literals, &literal_offset, literal_len);
        try std.testing.expectEqual(@as(usize, 7) + literal_len, written);
        try std.testing.expectEqual(@as(usize, 3) + literal_len, literal_offset);
        try std.testing.expectEqualSlices(u8, expected[0..written], actual[0..written]);
        try std.testing.expectEqualSlices(u8, expected[23..], actual[23..]);
    }
}

test "Zstd bulk wildcopy matches exact copy across lengths and alignments" {
    var source: [256]u8 = undefined;
    for (&source, 0..) |*byte, index| byte.* = @truncate(index * 17 + 9);
    for (16..128) |literal_len| {
        var expected: [256]u8 = @splat(0xa5);
        var actual = expected;
        @memcpy(expected[5..][0..literal_len], source[3..][0..literal_len]);
        var written: usize = 5;
        var source_offset: usize = 3;
        appendBulkWildcopy16(&actual, &written, &source, &source_offset, literal_len);
        try std.testing.expectEqual(@as(usize, 5) + literal_len, written);
        try std.testing.expectEqual(@as(usize, 3) + literal_len, source_offset);
        try std.testing.expectEqualSlices(u8, expected[0 .. 5 + literal_len], actual[0 .. 5 + literal_len]);
    }
}
