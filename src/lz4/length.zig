const std = @import("std");

pub const Error = error{ TruncatedFrame, IntegerOverflow };

/// Read an LZ4 literal or match length extension.
///
/// Long literal-only blocks encode almost the entire input length as a run of
/// 0xff bytes. Consume those runs a vector at a time, then return to the word
/// and byte loops for the first partial chunk and its terminating byte. Besides
/// being substantially cheaper for stored-like LZ4 blocks, this preserves the
/// exact cursor and overflow behavior of the scalar parser on malformed input.
pub fn readLongExtension(input: []const u8, offset: *usize) Error!usize {
    if (offset.* > input.len) return error.TruncatedFrame;
    var len: usize = 0;
    const word_bytes = @sizeOf(usize);
    const word_increment = 255 * word_bytes;
    const chunk_bytes = 32;
    const chunk_increment = 255 * chunk_bytes;
    const Chunk = @Vector(chunk_bytes, u8);
    const extension_bytes: Chunk = @splat(255);

    while (input.len - offset.* >= chunk_bytes) {
        const chunk: Chunk = input[offset.*..][0..chunk_bytes].*;
        if (!@reduce(.And, chunk == extension_bytes)) break;
        offset.* += chunk_bytes;
        len = std.math.add(usize, len, chunk_increment) catch
            return error.IntegerOverflow;
    }

    while (input.len - offset.* >= word_bytes) {
        const word = std.mem.readInt(
            usize,
            input[offset.*..][0..word_bytes],
            .little,
        );
        if (word != std.math.maxInt(usize)) break;
        offset.* += word_bytes;
        len = std.math.add(usize, len, word_increment) catch
            return error.IntegerOverflow;
    }

    while (true) {
        if (offset.* >= input.len) return error.TruncatedFrame;
        const byte = input[offset.*];
        offset.* += 1;
        len = std.math.add(usize, len, byte) catch
            return error.IntegerOverflow;
        if (byte != 255) return len;
    }
}

pub fn readScalarExtension(input: []const u8, offset: *usize) Error!usize {
    var len: usize = 0;
    while (true) {
        if (offset.* >= input.len) return error.TruncatedFrame;
        const byte = input[offset.*];
        offset.* += 1;
        len = std.math.add(usize, len, byte) catch
            return error.IntegerOverflow;
        if (byte != 255) return len;
    }
}

test "LZ4 length extension handles scalar and word-sized runs" {
    var offset: usize = 0;
    try std.testing.expectEqual(@as(usize, 17), try readLongExtension(&.{17}, &offset));
    try std.testing.expectEqual(@as(usize, 1), offset);

    const extension = ([_]u8{255} ** (@sizeOf(usize) * 8)) ++ [_]u8{31};
    offset = 0;
    try std.testing.expectEqual(
        @as(usize, 255 * @sizeOf(usize) * 8 + 31),
        try readLongExtension(&extension, &offset),
    );
    try std.testing.expectEqual(extension.len, offset);
}

test "LZ4 length extension rejects unterminated runs" {
    const extension = [_]u8{255} ** (@sizeOf(usize) + 1);
    var offset: usize = 0;
    try std.testing.expectError(
        error.TruncatedFrame,
        readLongExtension(&extension, &offset),
    );
    try std.testing.expectEqual(extension.len, offset);
}

test "LZ4 vector and scalar extension readers agree across boundaries" {
    var extension: [96]u8 = undefined;
    for (0..extension.len - 1) |run_len| {
        @memset(extension[0..run_len], 255);
        extension[run_len] = @intCast(run_len % 255);
        var vector_offset: usize = 0;
        var scalar_offset: usize = 0;
        const input = extension[0 .. run_len + 1];
        try std.testing.expectEqual(
            try readScalarExtension(input, &scalar_offset),
            try readLongExtension(input, &vector_offset),
        );
        try std.testing.expectEqual(scalar_offset, vector_offset);
    }
}
