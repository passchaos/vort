const std = @import("std");
const block_decode = @import("block_decode.zig");

pub const Error = error{
    CorruptFrame,
    IntegerOverflow,
    InvalidMagic,
    OutputLimitExceeded,
    TruncatedFrame,
    UnsupportedSnappyFeature,
};

pub const max_uncompressed_chunk_len: usize = 64 * 1024;
pub const stream_identifier_chunk_type: u8 = 0xff;
pub const compressed_data_chunk_type: u8 = 0x00;
pub const uncompressed_data_chunk_type: u8 = 0x01;
pub const min_skippable_chunk_type: u8 = 0x80;
pub const stream_identifier_payload = "sNaPpY";

pub const ChunkKind = enum {
    stream_identifier,
    compressed,
    uncompressed,
    skippable,
};

pub const Chunk = struct {
    kind: ChunkKind,
    payload: []const u8,
};

pub const Iterator = struct {
    bytes: []const u8,
    index: usize = 0,
    saw_identifier: bool = false,

    pub fn init(bytes: []const u8) Iterator {
        return .{ .bytes = bytes };
    }

    pub fn next(self: *Iterator) Error!?Chunk {
        if (self.index == self.bytes.len) return null;
        if (self.bytes.len - self.index < 4) return error.TruncatedFrame;
        const chunk_type = self.bytes[self.index];
        const chunk_len = readU24(
            self.bytes[self.index + 1 ..][0..3],
        );
        self.index += 4;
        if (self.bytes.len - self.index < chunk_len) {
            return error.TruncatedFrame;
        }
        const payload = self.bytes[self.index..][0..chunk_len];
        self.index += chunk_len;

        if (!self.saw_identifier and
            chunk_type != stream_identifier_chunk_type)
        {
            return error.InvalidMagic;
        }
        switch (chunk_type) {
            stream_identifier_chunk_type => {
                if (!std.mem.eql(
                    u8,
                    payload,
                    stream_identifier_payload,
                )) return error.InvalidMagic;
                self.saw_identifier = true;
                return .{
                    .kind = .stream_identifier,
                    .payload = payload,
                };
            },
            compressed_data_chunk_type => {
                try self.requireIdentifier();
                if (payload.len < 4) return error.TruncatedFrame;
                return .{ .kind = .compressed, .payload = payload };
            },
            uncompressed_data_chunk_type => {
                try self.requireIdentifier();
                if (payload.len < 4) return error.TruncatedFrame;
                if (payload.len - 4 > max_uncompressed_chunk_len) {
                    return error.CorruptFrame;
                }
                return .{ .kind = .uncompressed, .payload = payload };
            },
            else => {
                if (chunk_type >= min_skippable_chunk_type and
                    chunk_type != stream_identifier_chunk_type)
                {
                    return .{ .kind = .skippable, .payload = payload };
                }
                return error.UnsupportedSnappyFeature;
            },
        }
    }

    fn requireIdentifier(self: Iterator) Error!void {
        if (!self.saw_identifier) return error.InvalidMagic;
    }
};

/// Determine allocation size from framing and raw-block length prefixes only.
/// The caller performs the single full token/checksum validation pass after it
/// owns the final output buffer.
pub fn preflightDecodedLen(
    bytes: []const u8,
    max_output_len: usize,
) (Error || block_decode.Error)!usize {
    var iterator = Iterator.init(bytes);
    var total: usize = 0;
    while (try iterator.next()) |chunk| {
        const decoded_len = switch (chunk.kind) {
            .stream_identifier, .skippable => continue,
            .uncompressed => chunk.payload.len - 4,
            .compressed => blk: {
                const decoded_len =
                    (try block_decode.readHeader(chunk.payload[4..])).decoded_len;
                if (decoded_len > max_uncompressed_chunk_len) {
                    return error.CorruptFrame;
                }
                break :blk decoded_len;
            },
        };
        total = std.math.add(usize, total, decoded_len) catch
            return error.IntegerOverflow;
        if (total > max_output_len) return error.OutputLimitExceeded;
    }
    return total;
}

pub fn readU24(bytes: *const [3]u8) usize {
    return @as(usize, bytes[0]) |
        (@as(usize, bytes[1]) << 8) |
        (@as(usize, bytes[2]) << 16);
}

pub fn writeU24(bytes: *[3]u8, value: usize) void {
    bytes[0] = @intCast(value & 0xff);
    bytes[1] = @intCast((value >> 8) & 0xff);
    bytes[2] = @intCast((value >> 16) & 0xff);
}

test "Snappy frame iterator validates identifiers and chunk bounds" {
    const valid = [_]u8{
        0xff, 0x06, 0x00, 0x00, 's',  'N', 'a', 'P', 'p', 'Y',
        0x80, 0x01, 0x00, 0x00, 0xa5,
    };
    var iterator = Iterator.init(&valid);
    try std.testing.expectEqual(
        ChunkKind.stream_identifier,
        (try iterator.next()).?.kind,
    );
    try std.testing.expectEqual(
        ChunkKind.skippable,
        (try iterator.next()).?.kind,
    );
    try std.testing.expect((try iterator.next()) == null);

    var missing_identifier = Iterator.init(&.{
        0x80, 0x00, 0x00, 0x00,
    });
    try std.testing.expectError(
        error.InvalidMagic,
        missing_identifier.next(),
    );
    var truncated = Iterator.init(&.{ 0xff, 0x06 });
    try std.testing.expectError(error.TruncatedFrame, truncated.next());
}
