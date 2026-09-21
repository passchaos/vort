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
