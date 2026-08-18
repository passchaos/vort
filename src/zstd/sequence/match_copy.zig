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
