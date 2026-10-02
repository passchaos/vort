const std = @import("std");
const builtin = @import("builtin");

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
    if (len != 0 and len <= 32 and distance >= short_copy_width) {
        const available = writable_end - destination;
        if (available >= 32) {
            // Keep these moves ordered: at distances 16--31, the first move
            // initializes the bytes that the second move may read.
            @memcpy(output[destination..][0..16], output[source..][0..16]);
            if (len > 16)
                @memcpy(output[destination + 16 ..][0..16], output[source + 16 ..][0..16]);
            return;
        }
        if (len <= 16 and available >= 16) {
            @memcpy(output[destination..][0..16], output[source..][0..16]);
            return;
        }
    }
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

/// Match-copy policy for the full literal-tree decoder. That executor's
/// measured workloads benefit from keeping the next copy tier in fixed,
/// ordered 16-byte moves; narrower decoders retain `append`'s smaller branch
/// footprint.
pub fn appendWide(output: []u8, written: *usize, distance: usize, len: usize, writable_end: usize) void {
    if (len == 0) return;
    appendWideNonZero(output, written, distance, len, writable_end);
}

/// Full-tier copy entry point for decoded Brotli commands, whose copy length
/// is guaranteed non-zero by the command alphabet.
pub fn appendWideNonZero(output: []u8, written: *usize, distance: usize, len: usize, writable_end: usize) void {
    if (comptime builtin.cpu.arch != .x86_64)
        return append(output, written, distance, len, writable_end);

    std.debug.assert(len != 0);
    const destination = written.*;
    const source = destination - distance;
    std.debug.assert(writable_end <= output.len);
    std.debug.assert(len <= writable_end - destination);
    written.* += len;
    if (distance >= short_copy_width) {
        const available = writable_end - destination;
        if (len <= 32 and available >= 32) {
            @memcpy(output[destination..][0..16], output[source..][0..16]);
            if (len > 16)
                @memcpy(output[destination + 16 ..][0..16], output[source + 16 ..][0..16]);
            return;
        }
        if (len <= 64 and available >= 64) {
            @memcpy(output[destination..][0..16], output[source..][0..16]);
            @memcpy(output[destination + 16 ..][0..16], output[source + 16 ..][0..16]);
            @memcpy(output[destination + 32 ..][0..16], output[source + 32 ..][0..16]);
            if (len > 48)
                @memcpy(output[destination + 48 ..][0..16], output[source + 48 ..][0..16]);
            return;
        }
        if (len <= 16 and available >= 16) {
            @memcpy(output[destination..][0..16], output[source..][0..16]);
            return;
        }
    }
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

test "Brotli match copy matches scalar replay across short widths and boundaries" {
    const start = 128;
    for (1..65) |distance| {
        for (0..65) |len| {
            for ([_]usize{ 0, 1, 15, 16, 31, 32 }) |slack| {
                var actual: [256]u8 = @splat(0xc7);
                for (actual[0..start], 0..) |*byte, index| byte.* = @truncate(index * 37 + 11);
                const before = actual;
                var expected = actual;
                for (0..len) |index| expected[start + index] = expected[start + index - distance];
                const end = start + len + slack;
                var written: usize = start;
                append(&actual, &written, distance, len, end);
                try std.testing.expectEqual(start + len, written);
                try std.testing.expectEqualSlices(u8, expected[0..written], actual[0..written]);
                try std.testing.expectEqualSlices(u8, before[end..], actual[end..]);
                if (len == 0) try std.testing.expectEqualSlices(u8, &before, &actual);
            }
        }
    }
}

test "Brotli wide match copy matches scalar replay across fixed tiers" {
    const start = 128;
    for (1..65) |distance| {
        for (0..65) |len| {
            for ([_]usize{ 0, 1, 15, 16, 31, 32, 47, 48, 63, 64 }) |slack| {
                var actual: [320]u8 = @splat(0xc7);
                for (actual[0..start], 0..) |*byte, index| byte.* = @truncate(index * 37 + 11);
                const before = actual;
                var expected = actual;
                for (0..len) |index| expected[start + index] = expected[start + index - distance];
                const end = start + len + slack;
                var written: usize = start;
                if (len == 0)
                    appendWide(&actual, &written, distance, len, end)
                else
                    appendWideNonZero(&actual, &written, distance, len, end);
                try std.testing.expectEqual(start + len, written);
                try std.testing.expectEqualSlices(u8, expected[0..written], actual[0..written]);
                try std.testing.expectEqualSlices(u8, before[end..], actual[end..]);
                if (len == 0) try std.testing.expectEqualSlices(u8, &before, &actual);
            }
        }
    }
}
