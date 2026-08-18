const std = @import("std");

pub const Error = error{ InvalidMatch, SizeMismatch };

pub fn validate(
    written: usize,
    decoded_len: usize,
    offset_raw: anytype,
    len: usize,
) Error!void {
    const offset: usize = @intCast(offset_raw);
    if (offset == 0 or offset > written) return error.InvalidMatch;
    if (len > decoded_len - written) return error.SizeMismatch;
}

pub fn copy(
    output: []u8,
    written: usize,
    offset_raw: anytype,
    len: usize,
) Error!void {
    try validate(written, output.len, offset_raw, len);
    const offset: usize = @intCast(offset_raw);
    const destination = output[written..][0..len];
    if (offset == 1) {
        @memset(destination, output[written - 1]);
        return;
    }
    if (offset >= 8 and len >= 16) {
        // COPY_2 commonly describes 32--64 byte repetitions with enough
        // distance for an eight-byte load to precede its store. Advancing in
        // machine words preserves overlap semantics (each source word has
        // already been produced) and avoids two generic memcpy calls for the
        // frequent distance-32/length-60 shape.
        var copied: usize = 0;
        while (copied + 8 <= len) : (copied += 8) {
            destination[copied..][0..8].* =
                output[written - offset + copied ..][0..8].*;
        }
        while (copied < len) : (copied += 1) {
            destination[copied] = output[written - offset + copied];
        }
        return;
    }

    const seed_len = @min(offset, len);
    @memcpy(
        destination[0..seed_len],
        output[written - offset ..][0..seed_len],
    );

    // Snappy copies may overlap, but after one offset-sized seed the bytes
    // already written are a valid repetition source. Doubling from that seed
    // turns long small-distance matches into a logarithmic number of disjoint
    // memcpy operations instead of one dependent load/store per output byte.
    var copied = seed_len;
    while (copied < len) {
        const chunk_len = @min(copied, len - copied);
        @memcpy(
            destination[copied..][0..chunk_len],
            destination[0..chunk_len],
        );
        copied += chunk_len;
    }
}

test "Snappy match copy matches bytewise overlap semantics" {
    const written = 96;
    var offset: usize = 1;
    while (offset <= written) : (offset += 1) {
        var len: usize = 1;
        while (len <= 64) : (len += 1) {
            var actual: [written + 64]u8 = undefined;
            for (actual[0..written], 0..) |*byte, index| {
                byte.* = @truncate(index *% 73 +% (index >> 2));
            }
            var expected = actual;
            for (0..len) |index| {
                expected[written + index] =
                    expected[written - offset + index];
            }

            try copy(&actual, written, offset, len);
            try std.testing.expectEqualSlices(
                u8,
                expected[0 .. written + len],
                actual[0 .. written + len],
            );
        }
    }
}

test "Snappy match copy validates distance and output bounds" {
    var output: [16]u8 = @splat(0xa5);
    try std.testing.expectError(
        error.InvalidMatch,
        copy(&output, 4, @as(u16, 0), 4),
    );
    try std.testing.expectError(
        error.InvalidMatch,
        copy(&output, 4, @as(u32, 5), 4),
    );
    try std.testing.expectError(
        error.SizeMismatch,
        copy(&output, 13, @as(u16, 1), 4),
    );
}
