const std = @import("std");

const short_copy_width = 16;

/// Replay an in-window Brotli copy into caller-owned output.
///
/// One source period is copied first, then the initialized prefix doubles. This
/// preserves overlapping LZ77 semantics while avoiding one branch and bounds
/// calculation per output byte. `writable_end` bounds bytes that the current
/// meta-block will initialize before returning successfully, allowing short,
/// non-overlapping copies to use the same fixed-width first move as libbrotli
/// without touching bytes outside the meta-block.
pub fn append(output: []u8, written: *usize, distance: usize, len: usize, writable_end: usize) void {
    const destination = written.*;
    const source = destination - distance;
    std.debug.assert(writable_end <= output.len);
    std.debug.assert(len <= writable_end - destination);
    written.* += len;
    if (len <= distance) {
        if (len != 0 and
            len <= short_copy_width and
            distance >= short_copy_width and
            writable_end - destination >= short_copy_width)
        {
            @memcpy(
                output[destination..][0..short_copy_width],
                output[source..][0..short_copy_width],
            );
            return;
        }
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
    append(&output, &written, 5, 37, output.len);
    for (output[0..written], 0..) |byte, index| {
        try std.testing.expectEqual("abcde"[index % 5], byte);
    }
}

test "Brotli match copy handles non-overlap" {
    var output: [16]u8 = undefined;
    @memcpy(output[0..8], "abcdefgh");
    var written: usize = 8;
    append(&output, &written, 8, 4, 12);
    try std.testing.expectEqualSlices(u8, "abcdefghabcd", output[0..written]);
}

test "Brotli match copy bounds speculative short copy to the meta-block" {
    var output: [48]u8 = @splat(0xcc);
    @memcpy(output[0..16], "abcdefghijklmnop");
    var written: usize = 16;
    append(&output, &written, 16, 3, 32);

    try std.testing.expectEqual(@as(usize, 19), written);
    try std.testing.expectEqualSlices(u8, "abc", output[16..written]);
    try std.testing.expectEqualSlices(u8, "defghijklmnop", output[written..32]);
    try std.testing.expectEqualSlices(u8, &(@as([16]u8, @splat(0xcc))), output[32..]);
}
