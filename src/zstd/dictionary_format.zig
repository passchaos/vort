const std = @import("std");

pub const magic: u32 = 0xec30_a437;

pub const View = struct {
    id: u32,
    content: []const u8,
};

/// Parse the format-independent prefix of a standard Zstandard dictionary.
/// The entropy payload is deliberately left opaque here; the parent codec owns
/// Huffman/FSE parsing and advances `entropy_len` before constructing `View`.
pub fn viewAfterEntropy(bytes: []const u8, entropy_len: usize) !View {
    if (bytes.len < 8) return error.TruncatedFrame;
    if (std.mem.readInt(u32, bytes[0..4], .little) != magic) return error.InvalidMagic;
    const id = std.mem.readInt(u32, bytes[4..8], .little);
    if (id == 0) return error.InvalidDictionaryMetadata;
    const content_offset = std.math.add(usize, 8, entropy_len) catch return error.IntegerOverflow;
    const repcode_end = std.math.add(usize, content_offset, 12) catch return error.IntegerOverflow;
    if (repcode_end > bytes.len) return error.TruncatedFrame;
    const content = bytes[repcode_end..];
    for (0..3) |i| {
        const repcode = std.mem.readInt(u32, bytes[content_offset + i * 4 ..][0..4], .little);
        if (repcode == 0 or repcode > content.len) return error.InvalidDictionaryMetadata;
    }
    return .{ .id = id, .content = content };
}

test "standard dictionary prefix validates repcodes and content" {
    var bytes: [24]u8 = @splat(0);
    std.mem.writeInt(u32, bytes[0..4], magic, .little);
    std.mem.writeInt(u32, bytes[4..8], 0x1234, .little);
    std.mem.writeInt(u32, bytes[8..12], 1, .little);
    std.mem.writeInt(u32, bytes[12..16], 2, .little);
    std.mem.writeInt(u32, bytes[16..20], 3, .little);
    @memcpy(bytes[20..24], "dict");
    const view = try viewAfterEntropy(&bytes, 0);
    try std.testing.expectEqual(@as(u32, 0x1234), view.id);
    try std.testing.expectEqualSlices(u8, "dict", view.content);
    bytes[8] = 0;
    try std.testing.expectError(error.InvalidDictionaryMetadata, viewAfterEntropy(&bytes, 0));
}
