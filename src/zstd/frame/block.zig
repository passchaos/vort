const std = @import("std");
const core = @import("../../core.zig");

pub const Error = core.Error;

pub const Kind = enum {
    raw,
    rle,
    compressed,
};

pub const Header = struct {
    last: bool,
    kind: Kind,
    declared_len: usize,
    wire_len: usize,
};

pub fn parse(bytes: []const u8) Error!Header {
    if (bytes.len < 3) return error.TruncatedFrame;

    const encoded = std.mem.readInt(u24, bytes[0..3], .little);
    const kind: Kind = switch ((encoded >> 1) & 0x03) {
        0 => .raw,
        1 => .rle,
        2 => .compressed,
        else => return error.CorruptFrame,
    };
    const declared_len: usize = @intCast(encoded >> 3);
    return .{
        .last = (encoded & 1) != 0,
        .kind = kind,
        .declared_len = declared_len,
        .wire_len = if (kind == .rle) 1 else declared_len,
    };
}

pub fn validateSize(header: Header, frame_block_size_max: usize) Error!void {
    if (header.declared_len > frame_block_size_max) return error.CorruptFrame;
}

test "Zstd block wire header parses raw RLE and compressed kinds" {
    const raw = try parse(&.{ 0x29, 0x00, 0x00 });
    try std.testing.expect(raw.last);
    try std.testing.expectEqual(Kind.raw, raw.kind);
    try std.testing.expectEqual(@as(usize, 5), raw.declared_len);
    try std.testing.expectEqual(@as(usize, 5), raw.wire_len);

    const rle = try parse(&.{ 0x52, 0x00, 0x00 });
    try std.testing.expect(!rle.last);
    try std.testing.expectEqual(Kind.rle, rle.kind);
    try std.testing.expectEqual(@as(usize, 10), rle.declared_len);
    try std.testing.expectEqual(@as(usize, 1), rle.wire_len);

    const empty_rle = try parse(&.{ 0x03, 0x00, 0x00 });
    try std.testing.expect(empty_rle.last);
    try std.testing.expectEqual(Kind.rle, empty_rle.kind);
    try std.testing.expectEqual(@as(usize, 0), empty_rle.declared_len);
    try std.testing.expectEqual(@as(usize, 1), empty_rle.wire_len);

    const compressed = try parse(&.{ 0x2d, 0x00, 0x00 });
    try std.testing.expect(compressed.last);
    try std.testing.expectEqual(Kind.compressed, compressed.kind);
    try std.testing.expectEqual(@as(usize, 5), compressed.declared_len);
    try std.testing.expectEqual(@as(usize, 5), compressed.wire_len);
}

test "Zstd block wire header rejects short and reserved encodings" {
    try std.testing.expectError(error.TruncatedFrame, parse(&.{}));
    try std.testing.expectError(error.TruncatedFrame, parse(&.{0}));
    try std.testing.expectError(error.TruncatedFrame, parse(&.{ 0, 0 }));
    try std.testing.expectError(error.CorruptFrame, parse(&.{ 0x06, 0, 0 }));
}

test "Zstd block size validation enforces the frame limit for every kind" {
    const frame_limit: usize = 1024;
    const at_frame_limit: Header = .{ .last = false, .kind = .raw, .declared_len = frame_limit, .wire_len = frame_limit };
    try validateSize(at_frame_limit, frame_limit);

    var over_frame_limit = at_frame_limit;
    over_frame_limit.declared_len += 1;
    try std.testing.expectError(error.CorruptFrame, validateSize(over_frame_limit, frame_limit));
    over_frame_limit.kind = .rle;
    over_frame_limit.wire_len = 1;
    try std.testing.expectError(error.CorruptFrame, validateSize(over_frame_limit, frame_limit));

    const compressed: Header = .{ .last = true, .kind = .compressed, .declared_len = frame_limit, .wire_len = frame_limit };
    try validateSize(compressed, frame_limit);
    var oversized_compressed = compressed;
    oversized_compressed.declared_len += 1;
    oversized_compressed.wire_len += 1;
    try std.testing.expectError(error.CorruptFrame, validateSize(oversized_compressed, frame_limit));
}
