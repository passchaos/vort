const std = @import("std");

/// Exercise the package exports that callers use for both format controls.
pub fn contracts(comptime V: type) !void {
    const allocator = std.testing.allocator;
    const input = "format-owned compression controls: repeated repeated repeated";
    var encoder = try V.ZlibFrameEncoder.init(allocator, .{ .window_bits = 9, .mode = .fixed });
    defer encoder.deinit();
    const wire = try encoder.encodeAlloc(input);
    defer allocator.free(wire);
    try std.testing.expectEqual(@as(u8, 1), wire[0] >> 4);
    const decoded = try V.decodeZlibAlloc(allocator, wire);
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings(input, decoded);

    const frame = try V.zstd.encodeRawOrRleFrameWithOptionsAlloc(allocator, input, .{ .content_checksum = true });
    defer allocator.free(frame);
    frame[frame.len - 1] ^= 0x80;
    try std.testing.expectError(error.ChecksumMismatch, V.zstdDecodeFrameAllocWithOptions(allocator, frame, .{}));
    const options: V.ZstdFrameDecodeOptions = .{ .ignore_content_checksum = true };
    const ignored = try V.zstdDecodeFrameAllocWithOptions(allocator, frame, options);
    defer allocator.free(ignored);
    try std.testing.expectEqualStrings(input, ignored);
}
