//! Pure eight-byte Zstandard skippable-frame header parser.
const std = @import("std");
const core = @import("../../core.zig");
const format = @import("format.zig");

pub const Error = core.Error;
pub const encoded_len: usize = 8;

pub const Header = struct {
    magic: u32,
    id: u4,
    payload_len: u32,
};

pub fn parse(bytes: []const u8) Error!Header {
    if (bytes.len < encoded_len) return error.TruncatedFrame;
    const magic = std.mem.readInt(u32, bytes[0..4], .little);
    if (magic < format.skippable_magic_min or magic > format.skippable_magic_max)
        return error.InvalidMagic;
    return .{
        .magic = magic,
        .id = @intCast(magic - format.skippable_magic_min),
        .payload_len = std.mem.readInt(u32, bytes[4..8], .little),
    };
}

test "Zstd skippable wire header covers ids lengths and errors" {
    var bytes: [encoded_len]u8 = undefined;
    for (0..16) |id| {
        std.mem.writeInt(u32, bytes[0..4], format.skippable_magic_min + @as(u32, @intCast(id)), .little);
        std.mem.writeInt(u32, bytes[4..8], 0xfedc_ba98, .little);
        const header = try parse(&bytes);
        try std.testing.expectEqual(@as(u4, @intCast(id)), header.id);
        try std.testing.expectEqual(@as(u32, 0xfedc_ba98), header.payload_len);
    }
    for (0..encoded_len) |len|
        try std.testing.expectError(error.TruncatedFrame, parse(bytes[0..len]));
    std.mem.writeInt(u32, bytes[0..4], format.data_magic, .little);
    try std.testing.expectError(error.InvalidMagic, parse(&bytes));
}
