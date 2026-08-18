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
    var shift: u6 = 0;
    var index: usize = 0;
    while (index < block.len and index < 5) : (index += 1) {
        const byte = block[index];
        const payload = byte & 0x7f;
        if (index == 4 and payload > 0x0f) return error.CorruptFrame;
        result |= @as(usize, payload) << shift;
        if ((byte & 0x80) == 0) {
            return .{
                .decoded_len = result,
                .index = index + 1,
            };
        }
        shift += 7;
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
    var shift: u6 = 0;
    for (0..byte_count) |index| {
        len_minus_one |= @as(usize, block[input_index.* + index]) <<
            shift;
        shift += 8;
    }
    input_index.* += byte_count;
    return std.math.add(usize, len_minus_one, 1) catch
        error.IntegerOverflow;
}

/// Validate a raw block without materializing output. Size-query APIs require
/// a full token pass so malformed offsets and trailing bytes do not become
/// valid merely because the uncompressed length prefix was well-formed.
pub fn validateBody(block: []const u8, header: Header) Error!void {
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
                written += len;
            },
            else => unreachable,
        }
    }
    if (written != header.decoded_len) return error.TruncatedFrame;
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
