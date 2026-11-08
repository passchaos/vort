//! Pure wire decoding for the Zstandard Literals_Section_Header.
const std = @import("std");
const core = @import("../../core.zig");

pub const Error = core.Error;
pub const max_encoded_len: usize = 5;

pub const Kind = enum { raw, rle, compressed, treeless };

pub const Info = struct {
    kind: Kind,
    size_format: u2,
    encoded_len: usize,
    regenerated_size: usize,
    compressed_size: usize = 0,
};

pub fn encodedLen(first: u8) usize {
    const kind: Kind = @enumFromInt(first & 0x03);
    const size_format: u2 = @intCast((first >> 2) & 0x03);
    return switch (kind) {
        .raw, .rle => switch (size_format) {
            0, 2 => 1,
            1 => 2,
            3 => 3,
        },
        .compressed, .treeless => switch (size_format) {
            0, 1 => 3,
            2 => 4,
            3 => 5,
        },
    };
}

pub fn parse(bytes: []const u8) Error!Info {
    if (bytes.len == 0) return error.TruncatedFrame;
    const byte0 = bytes[0];
    const required = encodedLen(byte0);
    if (bytes.len < required) return error.TruncatedFrame;
    const kind: Kind = @enumFromInt(byte0 & 0x03);
    const size_format: u2 = @intCast((byte0 >> 2) & 0x03);
    if (kind == .compressed or kind == .treeless)
        return parseHuffman(bytes[0..required], byte0, size_format, kind);

    const regenerated_size: usize = switch (size_format) {
        0, 2 => byte0 >> 3,
        1 => @as(usize, byte0 >> 4) + (@as(usize, bytes[1]) << 4),
        3 => @as(usize, byte0 >> 4) +
            (@as(usize, bytes[1]) << 4) +
            (@as(usize, bytes[2]) << 12),
    };
    return .{
        .kind = kind,
        .size_format = size_format,
        .encoded_len = required,
        .regenerated_size = regenerated_size,
    };
}

fn parseHuffman(bytes: []const u8, byte0: u8, size_format: u2, kind: Kind) Error!Info {
    return switch (size_format) {
        0, 1 => blk: {
            const value = @as(usize, byte0 >> 4) |
                (@as(usize, bytes[1]) << 4) |
                (@as(usize, bytes[2]) << 12);
            const compressed_size = (value >> 10) & 0x3ff;
            if (compressed_size == 0) return error.CorruptFrame;
            if (size_format == 1 and compressed_size < 10) return error.CorruptFrame;
            break :blk .{
                .kind = kind,
                .size_format = size_format,
                .encoded_len = bytes.len,
                .regenerated_size = value & 0x3ff,
                .compressed_size = compressed_size,
            };
        },
        2 => blk: {
            const value = @as(usize, byte0 >> 4) |
                (@as(usize, bytes[1]) << 4) |
                (@as(usize, bytes[2]) << 12) |
                (@as(usize, bytes[3]) << 20);
            const compressed_size = (value >> 14) & 0x3fff;
            if (compressed_size < 10) return error.CorruptFrame;
            break :blk .{
                .kind = kind,
                .size_format = size_format,
                .encoded_len = bytes.len,
                .regenerated_size = value & 0x3fff,
                .compressed_size = compressed_size,
            };
        },
        3 => blk: {
            const value = @as(u64, byte0 >> 4) |
                (@as(u64, bytes[1]) << 4) |
                (@as(u64, bytes[2]) << 12) |
                (@as(u64, bytes[3]) << 20) |
                (@as(u64, bytes[4]) << 28);
            const compressed_size: usize = @intCast((value >> 18) & 0x3ffff);
            if (compressed_size < 10) return error.CorruptFrame;
            break :blk .{
                .kind = kind,
                .size_format = size_format,
                .encoded_len = bytes.len,
                .regenerated_size = @intCast(value & 0x3ffff),
                .compressed_size = compressed_size,
            };
        },
    };
}

test "Zstd literals header reports exact encoded lengths" {
    try std.testing.expectEqual(@as(usize, 1), encodedLen(0));
    try std.testing.expectEqual(@as(usize, 2), encodedLen(4));
    try std.testing.expectEqual(@as(usize, 1), encodedLen(8));
    try std.testing.expectEqual(@as(usize, 3), encodedLen(12));
    try std.testing.expectEqual(@as(usize, 3), encodedLen(2));
    try std.testing.expectEqual(@as(usize, 3), encodedLen(6));
    try std.testing.expectEqual(@as(usize, 4), encodedLen(10));
    try std.testing.expectEqual(@as(usize, 5), encodedLen(14));
}
