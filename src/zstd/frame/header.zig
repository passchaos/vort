const std = @import("std");
const core = @import("../../core.zig");

pub const Error = core.Error;

pub const max_encoded_len: usize = 14;
const block_size_limit: u64 = 128 * 1024;

pub const WireHeader = struct {
    encoded_len: usize,
    content_size: ?u64,
    has_checksum: bool,
    single_segment: bool,
    window_size: u64,
    block_size_max: usize,
    dictionary_id: u32,
};

pub fn encodedLen(descriptor: u8) Error!usize {
    if ((descriptor & 0x08) != 0) return error.CorruptFrame;

    const single_segment = (descriptor & 0x20) != 0;
    const dictionary_id_len: usize = switch (descriptor & 0x03) {
        0 => 0,
        1 => 1,
        2 => 2,
        else => 4,
    };
    const content_size_flag = descriptor >> 6;
    const content_size_len: usize = if (single_segment or content_size_flag != 0)
        @as(usize, 1) << @intCast(content_size_flag)
    else
        0;

    return 1 + @as(usize, @intFromBool(!single_segment)) + dictionary_id_len + content_size_len;
}

pub fn parse(bytes: []const u8) Error!WireHeader {
    if (bytes.len < 1) return error.TruncatedFrame;

    const descriptor = bytes[0];
    const encoded_len = try encodedLen(descriptor);
    if (bytes.len < encoded_len) return error.TruncatedFrame;

    const single_segment = (descriptor & 0x20) != 0;
    var offset: usize = 1;
    const described_window_size: ?u64 = if (single_segment) null else blk: {
        const window_descriptor = bytes[offset];
        offset += 1;
        const exponent: u6 = @intCast(window_descriptor >> 3);
        const mantissa = window_descriptor & 0x07;
        const window_base = @as(u64, 1) << (10 + exponent);
        break :blk window_base + (window_base / 8) * mantissa;
    };

    const dictionary_id_len: usize = switch (descriptor & 0x03) {
        0 => 0,
        1 => 1,
        2 => 2,
        else => 4,
    };
    const dictionary_id: u32 = @intCast(readLittleEndian(bytes[offset..], dictionary_id_len));
    offset += dictionary_id_len;

    const content_size_flag = descriptor >> 6;
    const content_size_len: usize = if (single_segment or content_size_flag != 0)
        @as(usize, 1) << @intCast(content_size_flag)
    else
        0;
    const content_size: ?u64 = if (content_size_len == 0) null else value: {
        const encoded = readLittleEndian(bytes[offset..], content_size_len);
        offset += content_size_len;
        break :value encoded + @as(u64, if (content_size_len == 2) 256 else 0);
    };

    std.debug.assert(offset == encoded_len);
    const window_size = described_window_size orelse content_size.?;
    return .{
        .encoded_len = encoded_len,
        .content_size = content_size,
        .has_checksum = (descriptor & 0x04) != 0,
        .single_segment = single_segment,
        .window_size = window_size,
        .block_size_max = @intCast(@min(window_size, block_size_limit)),
        .dictionary_id = dictionary_id,
    };
}

fn readLittleEndian(bytes: []const u8, len: usize) u64 {
    var value: u64 = 0;
    for (bytes[0..len], 0..) |byte, index| {
        value |= @as(u64, byte) << @intCast(index * 8);
    }
    return value;
}

test "Zstd wire header encoded lengths cover every optional field" {
    try std.testing.expectEqual(@as(usize, 2), try encodedLen(0x00));
    try std.testing.expectEqual(@as(usize, 2), try encodedLen(0x20));
    try std.testing.expectEqual(@as(usize, 5), try encodedLen(0x41));
    try std.testing.expectEqual(@as(usize, 8), try encodedLen(0x82));
    try std.testing.expectEqual(max_encoded_len, try encodedLen(0xc3));
    try std.testing.expectEqual(@as(usize, 2), try encodedLen(0x10));
    try std.testing.expectError(error.CorruptFrame, encodedLen(0x08));
    try std.testing.expectError(error.CorruptFrame, encodedLen(0xff));
}

test "Zstd wire header parses window dictionary and content size fields" {
    const header = try parse(&.{
        0x47, // Two-byte FCS, checksum, four-byte dictionary ID.
        0x0b, // 2 KiB base plus 3/8.
        0x78,
        0x56,
        0x34,
        0x12,
        0x34,
        0x12,
    });
    try std.testing.expectEqual(@as(usize, 8), header.encoded_len);
    try std.testing.expectEqual(@as(?u64, 0x1234 + 256), header.content_size);
    try std.testing.expect(header.has_checksum);
    try std.testing.expect(!header.single_segment);
    try std.testing.expectEqual(@as(u64, 2816), header.window_size);
    try std.testing.expectEqual(@as(usize, 2816), header.block_size_max);
    try std.testing.expectEqual(@as(u32, 0x1234_5678), header.dictionary_id);
}

test "Zstd wire header exhaustively decodes window descriptors" {
    for (0..256) |value| {
        const descriptor: u8 = @intCast(value);
        const header = try parse(&.{ 0x00, descriptor });
        const exponent: u6 = @intCast(descriptor >> 3);
        const base = @as(u64, 1) << (10 + exponent);
        const expected = base + (base / 8) * (descriptor & 0x07);
        try std.testing.expectEqual(expected, header.window_size);
        try std.testing.expectEqual(
            @as(usize, @intCast(@min(expected, block_size_limit))),
            header.block_size_max,
        );
    }
}

test "Zstd wire header preserves noncanonical dictionary and content widths" {
    inline for (.{
        [_]u8{ 0x21, 0, 0 },
        [_]u8{ 0x22, 0, 0, 0 },
        [_]u8{ 0x23, 0, 0, 0, 0, 0 },
    }) |wire| {
        const header = try parse(&wire);
        try std.testing.expectEqual(@as(u32, 0), header.dictionary_id);
        try std.testing.expectEqual(@as(?u64, 0), header.content_size);
        try std.testing.expectEqual(wire.len, header.encoded_len);
    }

    try std.testing.expectEqual(@as(?u64, 0), (try parse(&.{ 0x20, 0x00 })).content_size);
    try std.testing.expectEqual(@as(?u64, 255), (try parse(&.{ 0x20, 0xff })).content_size);
    try std.testing.expectEqual(@as(?u64, 256), (try parse(&.{ 0x60, 0x00, 0x00 })).content_size);
    try std.testing.expectEqual(@as(?u64, 65_791), (try parse(&.{ 0x60, 0xff, 0xff })).content_size);
    try std.testing.expectEqual(@as(?u64, 13), (try parse(&.{ 0xa0, 13, 0, 0, 0 })).content_size);
    try std.testing.expectEqual(
        @as(?u64, 13),
        (try parse(&.{ 0xe0, 13, 0, 0, 0, 0, 0, 0, 0 })).content_size,
    );
}

test "Zstd single-segment wire header uses content size as its window" {
    const header = try parse(&.{ 0xb2, 0xcd, 0xab, 0x00, 0x02, 0x00, 0x00 });
    try std.testing.expectEqual(@as(usize, 7), header.encoded_len);
    try std.testing.expectEqual(@as(?u64, 512), header.content_size);
    try std.testing.expect(header.single_segment);
    try std.testing.expectEqual(@as(u64, 512), header.window_size);
    try std.testing.expectEqual(@as(usize, 512), header.block_size_max);
    try std.testing.expectEqual(@as(u32, 0xabcd), header.dictionary_id);

    const large = try parse(&.{ 0xe0, 0, 0, 4, 0, 0, 0, 0, 0 });
    try std.testing.expectEqual(@as(?u64, 262_144), large.content_size);
    try std.testing.expectEqual(@as(usize, 128 * 1024), large.block_size_max);
}

test "Zstd wire header accepts unused bit and rejects every truncated prefix" {
    const wire = [_]u8{ 0xd3, 0x7f, 0x78, 0x56, 0x34, 0x12, 1, 2, 3, 4, 5, 6, 7, 8 };
    const header = try parse(&wire);
    try std.testing.expectEqual(max_encoded_len, header.encoded_len);
    try std.testing.expectEqual(@as(u32, 0x1234_5678), header.dictionary_id);
    try std.testing.expectEqual(@as(?u64, 0x0807_0605_0403_0201), header.content_size);
    for (0..wire.len) |prefix_len| {
        try std.testing.expectError(error.TruncatedFrame, parse(wire[0..prefix_len]));
    }
    try std.testing.expectError(error.CorruptFrame, parse(&.{0x08}));
}
