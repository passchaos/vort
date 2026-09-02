const std = @import("std");

/// Replay an in-window Brotli copy into caller-owned output.
///
/// One source period is copied first, then the initialized prefix doubles. This
/// preserves overlapping LZ77 semantics while avoiding one branch and bounds
/// calculation per output byte.
pub fn append(output: []u8, written: *usize, distance: usize, len: usize) void {
    const destination = written.*;
    const source = destination - distance;
    written.* += len;
    if (len <= distance) {
        @memcpy(output[destination..][0..len], output[source..][0..len]);
        return;
    }
    @memcpy(output[destination..][0..distance], output[source..][0..distance]);
    var copied = distance;
    while (copied < len) {
        const n = @min(copied, len - copied);
        @memcpy(output[destination + copied ..][0..n], output[destination..][0..n]);
        copied += n;
    }
}

test "Brotli match copy preserves overlapping period" {
    var output: [64]u8 = undefined;
    @memcpy(output[0..5], "abcde");
    var written: usize = 5;
    append(&output, &written, 5, 37);
    for (output[0..written], 0..) |byte, index| {
        try std.testing.expectEqual("abcde"[index % 5], byte);
    }
}

test "Brotli match copy handles non-overlap" {
    var output: [16]u8 = undefined;
    @memcpy(output[0..8], "abcdefgh");
    var written: usize = 8;
    append(&output, &written, 8, 4);
    try std.testing.expectEqualSlices(u8, "abcdefghabcd", output[0..written]);
}
