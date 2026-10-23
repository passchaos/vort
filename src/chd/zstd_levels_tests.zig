const std = @import("std");
const writer = @import("writer.zig");
const archive_mod = @import("archive.zig");
const format = @import("format.zig");
const zstd = @import("../zstd.zig");

test "CHD signed Zstd levels preserve default positive wire" {
    const input = "CHD signed Zstd level payload abcdefghijklmnopqrstuvwxyz\n" ** 128;
    const encoded = try writer.encodeAlloc(std.testing.allocator, input, .{ .compression = .zstd });
    defer std.testing.allocator.free(encoded);
    const explicit = try writer.encodeAlloc(std.testing.allocator, input, .{
        .compression = .zstd,
        .compression_level = 6,
    });
    defer std.testing.allocator.free(explicit);
    try std.testing.expectEqualSlices(u8, encoded, explicit);
    try std.testing.expectEqual(@as(usize, 312), encoded.len);
    var actual: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(encoded, &actual, .{});
    var expected: [32]u8 = undefined;
    _ = try std.fmt.hexToBytes(&expected, "83a22f50cd79ece1478d23c96ef5fade3d6917d4a4285356de73cb9f54e4dabf");
    try std.testing.expectEqual(expected, actual);
}

test "CHD signed Zstd levels round trip and pass fast options to hunks" {
    const input = "CHD fast hunk signed level payload!\n" ** 256;
    for ([_]c_int{ -1, -7, -1000, -131072 }) |level| {
        const image = try writer.encodeAlloc(std.testing.allocator, input, .{
            .compression = .zstd,
            .compression_level = level,
        });
        defer std.testing.allocator.free(image);
        var archive = try archive_mod.Archive.initAlloc(std.testing.allocator, image, .{});
        defer archive.deinit();
        try std.testing.expectEqual(format.Codec.zstd, try archive.header.codec(0));
        const decoded = try archive.decodeAllocLimited(std.testing.allocator, input.len);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualStrings(input, decoded);

        // Compare the first independently framed hunk with the public Zstd
        // level API. A fast level may correctly fall back to an uncompressed
        // CHD hunk when its frame exceeds the hunk size.
        const frame = try zstd.encodeFrameWithLevelAndOptionsAlloc(
            std.testing.allocator,
            input[0..4096],
            level,
            .{ .include_content_size = true, .content_checksum = false },
        );
        defer std.testing.allocator.free(frame);
        const entry = archive.map[0];
        const offset: usize = @intCast(entry.offset);
        if (frame.len <= 4096) {
            try std.testing.expectEqual(format.MapType.codec_0, entry.kind);
            try std.testing.expectEqualSlices(u8, frame, image[offset..][0..entry.length]);
        } else {
            try std.testing.expectEqual(format.MapType.uncompressed, entry.kind);
            try std.testing.expectEqualSlices(u8, input[0..4096], image[offset..][0..4096]);
        }
    }
}

test "CHD signed Zstd levels reject invalid codec hints before allocation" {
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    const allocator = failing.allocator();
    for ([_]writer.Compression{ .none, .zlib, .lzma, .huffman, .auto }) |compression| {
        try std.testing.expectError(error.InvalidChd, writer.encodeAlloc(allocator, "payload", .{
            .compression = compression,
            .compression_level = -1,
        }));
    }
    for ([_]c_int{ std.math.minInt(c_int), -131073, 23, std.math.maxInt(c_int) }) |level| {
        try std.testing.expectError(error.InvalidChd, writer.encodeAlloc(allocator, "payload", .{
            .compression = .zstd,
            .compression_level = level,
        }));
    }
    for ([_]writer.Compression{ .zlib, .auto }) |compression| {
        try std.testing.expectError(error.InvalidChd, writer.encodeAlloc(allocator, "payload", .{
            .compression = compression,
            .compression_level = 10,
        }));
    }
    for ([_]writer.Compression{ .none, .lzma, .huffman }) |compression| {
        try std.testing.expectError(error.InvalidChd, writer.encodeAlloc(allocator, "payload", .{
            .compression = compression,
            .compression_level = 256,
        }));
    }
    try std.testing.expect(!failing.has_induced_failure);

    // The old unsigned hint domain remains accepted for fixed-policy codecs.
    for ([_]writer.Compression{ .none, .lzma, .huffman }) |compression| {
        try std.testing.expectError(error.OutOfMemory, writer.encodeAlloc(allocator, "payload", .{
            .compression = compression,
            .compression_level = 255,
        }));
    }
    for ([_]c_int{ 0, 22 }) |level| {
        try std.testing.expectError(error.OutOfMemory, writer.encodeAlloc(allocator, "payload", .{
            .compression = .zstd,
            .compression_level = level,
        }));
    }
}
