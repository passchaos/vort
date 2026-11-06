const std = @import("std");
pub const wire = @import("../zstd_magicless_helpers.zig");
pub const memory = @import("../zstd_decode_memory/helpers.zig");
pub const a = std.testing.allocator;
pub const plain = "dictionary identity stays real when its frame ID is absent\n" ** 8;
pub const id: u32 = 0x5566_7788;

/// Independent wire arithmetic proves that only the dictionary field changes.
pub fn pair(kept: []const u8, omitted: []const u8, format: anytype, identity: u32) !void {
    const magicless = format == .magicless;
    const before = try wire.header(kept, magicless);
    const after = try wire.header(omitted, magicless);
    try std.testing.expectEqual(identity, before.dictionary_id);
    try std.testing.expectEqual(@as(u32, 0), after.dictionary_id);
    try std.testing.expectEqual(before.content_size, after.content_size);
    try std.testing.expectEqual(before.window, after.window);
    try std.testing.expectEqual(before.checksum, after.checksum);
    const prefix: usize = if (magicless) 0 else 4;
    const start = prefix + 1 + @as(usize, if (before.descriptor & 0x20 == 0) 1 else 0);
    const width: usize = if (identity == 0) 0 else if (identity <= 255) 1 else if (identity <= 65535) 2 else 4;
    try std.testing.expectEqual(omitted.len + width, kept.len);
    try std.testing.expectEqual(after.payload_offset + width, before.payload_offset);
    try std.testing.expectEqual(before.descriptor & ~@as(u8, 3), after.descriptor);
    try std.testing.expectEqualSlices(u8, kept[0..prefix], omitted[0..prefix]);
    try std.testing.expectEqualSlices(u8, kept[prefix + 1 .. start], omitted[prefix + 1 .. start]);
    try std.testing.expectEqualSlices(u8, kept[start + width ..], omitted[start..]);
}

pub fn check(comptime Z: type, bytes: []const u8, input: []const u8, format: Z.FrameFormat, dictionary: Z.NativeDictionary) !void {
    try wire.check(Z, a, bytes, input, .{ .format = format, .dictionary = dictionary, .expected_output_len = input.len });
}

pub fn omitReferenceId(bytes: []const u8) ![]u8 {
    const header = try wire.header(bytes, false);
    const start: usize = 5 + @as(usize, if (header.descriptor & 0x20 == 0) 1 else 0);
    const width: usize = switch (header.descriptor & 3) {
        0 => 0,
        1 => 1,
        2 => 2,
        3 => 4,
        else => unreachable,
    };
    const result = try a.alloc(u8, bytes.len - width);
    @memcpy(result[0..start], bytes[0..start]);
    result[4] &= ~@as(u8, 3);
    @memcpy(result[start..], bytes[start + width ..]);
    return result;
}
