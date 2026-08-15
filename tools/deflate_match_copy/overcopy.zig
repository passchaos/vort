const std = @import("std");

/// Benchmark-only fdeflate-style 16-byte speculative match copy.
///
/// This module owns only the speculative non-overlapping primitive; policy and
/// exact-copy fallbacks stay in the benchmark driver. The final store may write
/// up to 15 bytes beyond the logical match, so callers must provide that
/// headroom and treat only the logical match bytes as observable.
pub inline fn copyNonOverlapping16(
    output: []u8,
    out_offset: usize,
    length: usize,
    distance: usize,
) void {
    std.debug.assert(length != 0);
    std.debug.assert(distance >= length);
    std.debug.assert(distance <= out_offset);
    std.debug.assert(out_offset <= output.len);
    std.debug.assert(length + 15 <= output.len - out_offset);

    // Snapshot each complete vector before storing it. This matters when the
    // 16 speculative source lanes overlap the destination even though the
    // logical match itself is non-overlapping.
    const start = out_offset - distance;
    const first = output[start..][0..16].*;
    output[out_offset..][0..16].* = first;

    const step: usize = @min(distance, 16);
    if (length <= step) return;
    var source: [*]u8 = output.ptr + start + step;
    var dest: [*]u8 = output.ptr + out_offset + step;
    var remaining = length - step;
    while (true) {
        const chunk = source[0..16].*;
        dest[0..16].* = chunk;
        if (remaining <= step) return;
        source += step;
        dest += step;
        remaining -= step;
    }
}

fn copyReference(
    output: []u8,
    out_offset: usize,
    length: usize,
    distance: usize,
) void {
    const first = @min(distance, length);
    @memcpy(
        output[out_offset..][0..first],
        output[out_offset - distance ..][0..first],
    );
    var copied = first;
    while (copied < length) {
        const count = @min(copied, length - copied);
        @memcpy(
            output[out_offset + copied ..][0..count],
            output[out_offset..][0..count],
        );
        copied += count;
    }
}

test "overcopy16 preserves short non-overlapping logical output" {
    var length: usize = 3;
    while (length <= 16) : (length += 1) {
        var distance = length;
        while (distance <= length + 17) : (distance += 1) {
            const out_offset = distance + 19;
            const logical_end = out_offset + length;
            const total_len = logical_end + 15;
            var input: [567]u8 = undefined;
            for (input[0..total_len], 0..) |*byte, i| {
                byte.* = @truncate(
                    i *% 73 +% length *% 29 +% distance *% 11,
                );
            }

            var expected = input;
            var actual = input;
            copyReference(
                expected[0..total_len],
                out_offset,
                length,
                distance,
            );
            copyNonOverlapping16(
                actual[0..total_len],
                out_offset,
                length,
                distance,
            );
            try std.testing.expectEqualSlices(
                u8,
                expected[0..logical_end],
                actual[0..logical_end],
            );
        }
    }
}
