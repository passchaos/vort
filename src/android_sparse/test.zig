const std = @import("std");
const archive_mod = @import("archive.zig");
const format = @import("format.zig");
const writer = @import("writer.zig");

const allocator = std.testing.allocator;

test "Android sparse writer round trips RAW FILL DONT_CARE and CRC32" {
    const block_size = 4096;
    const input = try allocator.alloc(u8, 6 * block_size);
    defer allocator.free(input);
    @memset(input, 0);
    for (input[0..block_size], 0..) |*byte, index|
        byte.* = @truncate(index * 17 + index / 31);
    var fill_pattern: [4]u8 = undefined;
    std.mem.writeInt(u32, &fill_pattern, 0x1122_3344, .little);
    for (input[2 * block_size .. 4 * block_size], 0..) |*byte, index|
        byte.* = fill_pattern[index % 4];
    for (input[4 * block_size .. 5 * block_size], 0..) |*byte, index|
        byte.* = @truncate(index * 29 + 7);

    const encoded = try writer.encodeAlloc(allocator, input, .{
        .block_size = block_size,
        .emit_crc32_chunk = true,
        .write_image_checksum = true,
    });
    defer allocator.free(encoded);
    var archive = try archive_mod.Archive.initAlloc(allocator, encoded, .{});
    defer archive.deinit();
    try std.testing.expectEqual(@as(usize, 6), archive.header.total_chunks);
    try std.testing.expectEqual(@as(usize, 5), archive.chunks.len);
    try std.testing.expectEqual(format.ChunkType.raw, archive.chunks[0].kind);
    try std.testing.expectEqual(format.ChunkType.dont_care, archive.chunks[1].kind);
    try std.testing.expectEqual(format.ChunkType.fill, archive.chunks[2].kind);
    try std.testing.expectEqual(@as(usize, 2), archive.chunks[2].block_count);
    try std.testing.expectEqual(format.ChunkType.raw, archive.chunks[3].kind);
    try std.testing.expectEqual(format.ChunkType.dont_care, archive.chunks[4].kind);
    const decoded = try archive.decodeAllocLimited(allocator, input.len);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);

    const range_offset = block_size - 37;
    const range_length = 4 * block_size + 91;
    const range = try archive.readRangeAllocLimited(
        allocator,
        range_offset,
        range_length,
        range_length,
    );
    defer allocator.free(range);
    try std.testing.expectEqualSlices(
        u8,
        input[range_offset..][0..range_length],
        range,
    );
}

test "Android sparse writer supports raw mode and empty images" {
    const block_size = 4096;
    const input = [_]u8{0} ** (2 * block_size);
    const encoded = try writer.encodeAlloc(allocator, &input, .{
        .block_size = block_size,
        .sparse_zero_blocks = false,
        .use_fill_chunks = false,
    });
    defer allocator.free(encoded);
    var archive = try archive_mod.Archive.initAlloc(allocator, encoded, .{});
    defer archive.deinit();
    try std.testing.expectEqual(@as(usize, 1), archive.chunks.len);
    try std.testing.expectEqual(format.ChunkType.raw, archive.chunks[0].kind);

    const empty = try writer.encodeAlloc(allocator, "", .{});
    defer allocator.free(empty);
    var empty_archive = try archive_mod.Archive.initAlloc(allocator, empty, .{});
    defer empty_archive.deinit();
    try std.testing.expectEqual(@as(u64, 0), empty_archive.header.logical_size);
    try std.testing.expectEqual(@as(usize, 0), empty_archive.chunks.len);
}

test "Android sparse reader accepts extended headers and intermediate checksums" {
    const block_size = 16;
    const first = "abcdefghijklmnop";
    const second = "qrstuvwxyzABCDEF";
    var image = [_]u8{0} ** (32 + 16 + first.len + 16 + 4 + 16 + second.len);
    format.writeU32Le(&image, 0, format.magic);
    format.writeU16Le(&image, 4, format.major_version);
    format.writeU16Le(&image, 6, 7);
    format.writeU16Le(&image, 8, 32);
    format.writeU16Le(&image, 10, 16);
    format.writeU32Le(&image, 12, block_size);
    format.writeU32Le(&image, 16, 2);
    format.writeU32Le(&image, 20, 3);
    image[28] = 0xa1;
    image[29] = 0xb2;
    image[30] = 0xc3;
    image[31] = 0xd4;

    var offset: usize = 32;
    format.writeU16Le(&image, offset, @intFromEnum(format.ChunkType.raw));
    format.writeU32Le(&image, offset + 4, 1);
    format.writeU32Le(&image, offset + 8, 16 + first.len);
    image[offset + 12] = 0x11;
    image[offset + 13] = 0x22;
    image[offset + 14] = 0x33;
    image[offset + 15] = 0x44;
    @memcpy(image[offset + 16 ..][0..first.len], first);
    offset += 16 + first.len;

    format.writeU16Le(&image, offset, @intFromEnum(format.ChunkType.crc32));
    format.writeU32Le(&image, offset + 8, 20);
    image[offset + 12] = 0x55;
    image[offset + 13] = 0x66;
    image[offset + 14] = 0x77;
    image[offset + 15] = 0x88;
    format.writeU32Le(&image, offset + 16, @import("../checksum.zig").crc32(first));
    offset += 20;

    format.writeU16Le(&image, offset, @intFromEnum(format.ChunkType.raw));
    format.writeU32Le(&image, offset + 4, 1);
    format.writeU32Le(&image, offset + 8, 16 + second.len);
    image[offset + 12] = 0x99;
    image[offset + 13] = 0xaa;
    image[offset + 14] = 0xbb;
    image[offset + 15] = 0xcc;
    @memcpy(image[offset + 16 ..][0..second.len], second);

    var archive = try archive_mod.Archive.initAlloc(allocator, &image, .{});
    defer archive.deinit();
    try std.testing.expectEqual(@as(u16, 7), archive.header.minor);
    const decoded = try archive.decodeAllocLimited(allocator, 2 * block_size);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, first ++ second, decoded);
}

test "Android sparse parser enforces bounds and chunk invariants" {
    const input = [_]u8{0} ** 4096;
    const encoded = try writer.encodeAlloc(allocator, &input, .{
        .emit_crc32_chunk = true,
    });
    defer allocator.free(encoded);

    try std.testing.expectError(
        error.OutputLimitExceeded,
        archive_mod.Archive.initAlloc(allocator, encoded, .{
            .max_block_size = 1024,
        }),
    );
    try std.testing.expectError(
        error.OutputLimitExceeded,
        archive_mod.Archive.initAlloc(allocator, encoded, .{
            .max_checksum_bytes = 1024,
        }),
    );

    const corrupt = try allocator.dupe(u8, encoded);
    defer allocator.free(corrupt);
    const first_chunk = format.base_header_size;
    format.writeU16Le(corrupt, first_chunk + 2, 1);
    try std.testing.expectError(
        error.InvalidAndroidSparse,
        archive_mod.Archive.initAlloc(allocator, corrupt, .{}),
    );
    @memcpy(corrupt, encoded);
    format.writeU32Le(corrupt, first_chunk + 4, 0);
    try std.testing.expectError(
        error.InvalidAndroidSparse,
        archive_mod.Archive.initAlloc(allocator, corrupt, .{}),
    );
    @memcpy(corrupt, encoded);
    format.writeU32Le(corrupt, first_chunk + 8, format.base_chunk_header_size + 4);
    try std.testing.expectError(
        error.InvalidAndroidSparse,
        archive_mod.Archive.initAlloc(allocator, corrupt, .{}),
    );
    var archive = try archive_mod.Archive.initAlloc(allocator, encoded, .{});
    defer archive.deinit();
    try std.testing.expectError(
        error.RangeOutOfBounds,
        archive.readRangeAllocLimited(
            allocator,
            input.len - 1,
            2,
            2,
        ),
    );
}

test "Android sparse rejects malformed metadata and corrupt checksums" {
    const block_size = 4096;
    const input = "Android sparse checksum payload\n" ** 128;
    try std.testing.expectEqual(@as(usize, block_size), input.len);
    const encoded = try writer.encodeAlloc(allocator, input, .{
        .block_size = block_size,
        .emit_crc32_chunk = true,
        .write_image_checksum = true,
    });
    defer allocator.free(encoded);
    try std.testing.expectError(
        error.InvalidAndroidSparse,
        writer.encodeAlloc(allocator, input[0 .. input.len - 1], .{}),
    );

    const corrupt = try allocator.dupe(u8, encoded);
    defer allocator.free(corrupt);
    corrupt[0] ^= 1;
    try std.testing.expectError(
        error.InvalidMagic,
        archive_mod.Archive.initAlloc(allocator, corrupt, .{}),
    );
    @memcpy(corrupt, encoded);
    format.writeU16Le(corrupt, 4, 2);
    try std.testing.expectError(
        error.UnsupportedVersion,
        archive_mod.Archive.initAlloc(allocator, corrupt, .{}),
    );
    @memcpy(corrupt, encoded);
    const raw_payload = format.base_header_size + format.base_chunk_header_size;
    corrupt[raw_payload] ^= 1;
    try std.testing.expectError(
        error.ChecksumMismatch,
        archive_mod.Archive.initAlloc(allocator, corrupt, .{}),
    );
    var unchecked = try archive_mod.Archive.initAlloc(
        allocator,
        corrupt,
        .{ .verify_checksums = false },
    );
    unchecked.deinit();
    @memcpy(corrupt, encoded);
    format.writeU32Le(corrupt, 20, 99);
    try std.testing.expectError(
        error.OutputLimitExceeded,
        archive_mod.Archive.initAlloc(
            allocator,
            corrupt,
            .{ .max_chunks = 8 },
        ),
    );
    try std.testing.expectError(
        error.TruncatedFrame,
        archive_mod.Archive.initAlloc(
            allocator,
            encoded[0 .. encoded.len - 1],
            .{},
        ),
    );
}
