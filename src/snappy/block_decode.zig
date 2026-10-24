const std = @import("std");
const match_copy = @import("match_copy.zig");

pub const Error = error{
    CorruptFrame,
    IntegerOverflow,
    InvalidMatch,
    SizeMismatch,
    TrailingData,
    TruncatedFrame,
};

pub const Header = struct {
    decoded_len: usize,
    index: usize,
};

pub fn readHeader(block: []const u8) Error!Header {
    var result: usize = 0;
    var index: usize = 0;
    while (index < block.len and index < 5) : (index += 1) {
        const byte = block[index];
        const payload = byte & 0x7f;
        if (index == 4 and payload > 0x0f) return error.CorruptFrame;
        const shift: std.math.Log2Int(usize) = @intCast(index * 7);
        result |= @as(usize, payload) << shift;
        if ((byte & 0x80) == 0) {
            return .{
                .decoded_len = result,
                .index = index + 1,
            };
        }
    }
    return if (index < 5) error.TruncatedFrame else error.CorruptFrame;
}

pub fn readLiteralLen(
    tag: u8,
    block: []const u8,
    input_index: *usize,
) Error!usize {
    const tag_len = tag >> 2;
    if (tag_len < 60) return @as(usize, tag_len) + 1;
    const byte_count: usize = @as(usize, tag_len) - 59;
    if (block.len - input_index.* < byte_count) {
        return error.TruncatedFrame;
    }
    var len_minus_one: usize = 0;
    for (0..byte_count) |index| {
        const shift: std.math.Log2Int(usize) = @intCast(index * 8);
        len_minus_one |= @as(usize, block[input_index.* + index]) <<
            shift;
    }
    input_index.* += byte_count;
    return std.math.add(usize, len_minus_one, 1) catch
        error.IntegerOverflow;
}

/// Validate a raw block without materializing output. Size-query APIs require
/// a full token pass so malformed offsets and trailing bytes do not become
/// valid merely because the uncompressed length prefix was well-formed.
pub const BodyPlan = struct { max_offset: usize };

pub fn validateBody(block: []const u8, header: Header) Error!void {
    _ = try analyzeBody(block, header);
}

/// Validate every token and record the largest backward dependency. COPY_4
/// retains its full u32 distance; only the already-decoded prefix bounds it.
pub fn analyzeBody(block: []const u8, header: Header) Error!BodyPlan {
    var max_offset: usize = 0;
    var input_index = header.index;
    var written: usize = 0;
    while (input_index < block.len) {
        if (written == header.decoded_len) return error.TrailingData;
        const tag = block[input_index];
        input_index += 1;
        switch (tag & 0x03) {
            0 => {
                const literal_len =
                    try readLiteralLen(tag, block, &input_index);
                if (literal_len > header.decoded_len - written) {
                    return error.SizeMismatch;
                }
                if (block.len - input_index < literal_len) {
                    return error.TruncatedFrame;
                }
                input_index += literal_len;
                written += literal_len;
            },
            1 => {
                const len: usize = 4 + ((tag >> 2) & 0x07);
                if (block.len - input_index < 1) {
                    return error.TruncatedFrame;
                }
                const offset: usize =
                    (@as(usize, tag & 0xe0) << 3) | block[input_index];
                input_index += 1;
                try match_copy.validate(
                    written,
                    header.decoded_len,
                    offset,
                    len,
                );
                max_offset = @max(max_offset, @as(usize, offset));
                written += len;
            },
            2 => {
                const len: usize = 1 + (tag >> 2);
                if (block.len - input_index < 2) {
                    return error.TruncatedFrame;
                }
                const offset = std.mem.readInt(
                    u16,
                    block[input_index..][0..2],
                    .little,
                );
                input_index += 2;
                try match_copy.validate(
                    written,
                    header.decoded_len,
                    offset,
                    len,
                );
                max_offset = @max(max_offset, @as(usize, offset));
                written += len;
            },
            3 => {
                const len: usize = 1 + (tag >> 2);
                if (block.len - input_index < 4) {
                    return error.TruncatedFrame;
                }
                const offset = std.mem.readInt(
                    u32,
                    block[input_index..][0..4],
                    .little,
                );
                input_index += 4;
                try match_copy.validate(
                    written,
                    header.decoded_len,
                    offset,
                    len,
                );
                max_offset = @max(max_offset, @as(usize, offset));
                written += len;
            },
            else => unreachable,
        }
    }
    if (written != header.decoded_len) return error.TruncatedFrame;
    return .{ .max_offset = max_offset };
}

/// Decode tokens after the caller has consumed the length prefix and provided
/// an exact output slice. Keeping this out-of-line gives raw-block and framed
/// callers one shared hot loop without duplicating it into every allocation,
/// append, and exact-size API wrapper.
pub noinline fn decodeBody(
    block: []const u8,
    header: Header,
    output: []u8,
) Error!usize {
    std.debug.assert(output.len == header.decoded_len);
    var input_index = header.index;
    var written: usize = 0;
    while (input_index < block.len) {
        if (written == header.decoded_len) return error.TrailingData;
        const tag = block[input_index];
        input_index += 1;
        switch (tag & 0x03) {
            0 => {
                const literal_len =
                    try readLiteralLen(tag, block, &input_index);
                if (literal_len > header.decoded_len - written) {
                    return error.SizeMismatch;
                }
                if (block.len - input_index < literal_len) {
                    return error.TruncatedFrame;
                }
                @memcpy(
                    output[written..][0..literal_len],
                    block[input_index..][0..literal_len],
                );
                input_index += literal_len;
                written += literal_len;
            },
            1 => {
                const len: usize = 4 + ((tag >> 2) & 0x07);
                if (block.len - input_index < 1) {
                    return error.TruncatedFrame;
                }
                const offset: usize =
                    (@as(usize, tag & 0xe0) << 3) | block[input_index];
                input_index += 1;
                try match_copy.copy(output, written, offset, len);
                written += len;
            },
            2 => {
                const len: usize = 1 + (tag >> 2);
                if (block.len - input_index < 2) {
                    return error.TruncatedFrame;
                }
                const offset = std.mem.readInt(
                    u16,
                    block[input_index..][0..2],
                    .little,
                );
                input_index += 2;
                try match_copy.copy(output, written, offset, len);
                written += len;
            },
            3 => {
                const len: usize = 1 + (tag >> 2);
                if (block.len - input_index < 4) {
                    return error.TruncatedFrame;
                }
                const offset = std.mem.readInt(
                    u32,
                    block[input_index..][0..4],
                    .little,
                );
                input_index += 4;
                try match_copy.copy(output, written, offset, len);
                written += len;
            },
            else => unreachable,
        }
    }
    if (written != header.decoded_len) return error.TruncatedFrame;
    return written;
}

test "Snappy block validation covers malformed token boundaries" {
    try std.testing.expectError(
        error.TruncatedFrame,
        validateBody(&.{5}, .{ .decoded_len = 5, .index = 1 }),
    );
    try std.testing.expectError(
        error.InvalidMatch,
        validateBody(
            &.{ 4, 0x0e, 0, 0 },
            .{ .decoded_len = 4, .index = 1 },
        ),
    );
    try std.testing.expectError(
        error.TrailingData,
        validateBody(
            &.{ 0, 0 },
            .{ .decoded_len = 0, .index = 1 },
        ),
    );
}

test "Snappy length fields retain all four bytes on narrow targets" {
    const header = try readHeader(&.{ 0xff, 0xff, 0xff, 0xff, 0x0f });
    try std.testing.expectEqual(@as(usize, std.math.maxInt(u32)), header.decoded_len);
    try std.testing.expectEqual(@as(usize, 5), header.index);
    try std.testing.expectError(error.CorruptFrame, readHeader(&.{ 0xff, 0xff, 0xff, 0xff, 0x10 }));
    try std.testing.expectError(error.CorruptFrame, readHeader(&.{ 0x80, 0x80, 0x80, 0x80, 0x80 }));
    try std.testing.expectError(error.TruncatedFrame, readHeader(&.{ 0x80, 0x80, 0x80, 0x80 }));

    var index: usize = 0;
    try std.testing.expectEqual(@as(usize, 60), try readLiteralLen(0xfc, &.{ 59, 0, 0, 0 }, &index));
    try std.testing.expectEqual(@as(usize, 4), index);
    index = 0;
    if (@bitSizeOf(usize) == 32) {
        try std.testing.expectError(error.IntegerOverflow, readLiteralLen(0xfc, &.{ 0xff, 0xff, 0xff, 0xff }, &index));
    } else {
        try std.testing.expectEqual(@as(usize, 4294967296), try readLiteralLen(0xfc, &.{ 0xff, 0xff, 0xff, 0xff }, &index));
    }
}
