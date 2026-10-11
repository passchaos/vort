const std = @import("std");
const dmg = @import("../dmg.zig");

const allocator = std.testing.allocator;

test "DMG writer and reader round trip all supported chunk codecs" {
    const input = try makeInput(allocator, 3 * 1024);
    defer allocator.free(input);
    inline for (std.enums.values(dmg.Compression)) |compression| {
        const encoded = try dmg.encodeAlloc(allocator, input, .{
            .compression = compression,
            .block_size = 1024,
            .name = "Apple_HFS & Vort",
            .copy_if_larger = false,
        });
        defer allocator.free(encoded);
        var archive = try dmg.parseAlloc(allocator, encoded, .{});
        defer archive.deinit();
        try std.testing.expectEqual(@as(usize, 1), archive.partitions.len);
        const partition = archive.partitions[0];
        try std.testing.expectEqualStrings("Apple_HFS & Vort", partition.name);
        try std.testing.expectEqual(@as(u64, input.len), partition.decoded_size);
        try std.testing.expect(partition.blocks.len >= 3);
        const decoded = try archive.decodePartitionAllocLimited(
            allocator,
            0,
            input.len,
        );
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);

        const range_offset = 1024 - 37;
        const range_len = 1024 + 91;
        const range = try archive.decodePartitionRangeAllocLimited(
            allocator,
            0,
            range_offset,
            range_len,
            range_len,
        );
        defer allocator.free(range);
        try std.testing.expectEqualSlices(
            u8,
            input[range_offset..][0..range_len],
            range,
        );
    }
}

test "DMG writer selects zero and copy fallback chunks" {
    var input: [2048]u8 = undefined;
    @memset(input[0..1024], 0);
    var state: u32 = 0x1234_5678;
    for (input[1024..]) |*byte| {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        byte.* = @truncate(state);
    }
    const encoded = try dmg.encodeAlloc(allocator, &input, .{
        .compression = .zlib,
        .block_size = 1024,
    });
    defer allocator.free(encoded);
    var archive = try dmg.parseAlloc(allocator, encoded, .{});
    defer archive.deinit();
    try std.testing.expectEqual(dmg.ChunkKind.zero, archive.partitions[0].blocks[0].kind);
    try std.testing.expectEqual(dmg.ChunkKind.copy, archive.partitions[0].blocks[1].kind);
}

test "DMG reader accepts a front koly trailer" {
    var input: [1024]u8 = undefined;
    for (&input, 0..) |*byte, index|
        byte.* = "front-koly-DMG\n"[index % 15];
    const normal = try dmg.encodeAlloc(allocator, &input, .{
        .compression = .zlib,
        .block_size = 512,
    });
    defer allocator.free(normal);
    const body_len = normal.len - dmg.trailerSize;
    const front = try allocator.alloc(u8, normal.len);
    defer allocator.free(front);
    @memcpy(front[0..dmg.trailerSize], normal[body_len..]);
    @memcpy(front[dmg.trailerSize..], normal[0..body_len]);
    for ([_]usize{ 0x18, 0xd8 }) |field_offset| {
        const old = std.mem.readInt(u64, front[field_offset..][0..8], .big);
        std.mem.writeInt(
            u64,
            front[field_offset..][0..8],
            old + dmg.trailerSize,
            .big,
        );
    }
    var archive = try dmg.parseAlloc(allocator, front, .{});
    defer archive.deinit();
    try std.testing.expect(archive.trailer.at_front);
    const decoded = try archive.decodePartitionAllocLimited(allocator, 0, input.len);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &input, decoded);
}

test "DMG parser rejects damaged trailer metadata and checksums" {
    const input = "DMG corruption test sector" ++ ("\x00" ** (512 - 26));
    const encoded = try dmg.encodeAlloc(allocator, input, .{ .block_size = 512 });
    defer allocator.free(encoded);

    var bad_magic = try allocator.dupe(u8, encoded);
    defer allocator.free(bad_magic);
    bad_magic[bad_magic.len - dmg.trailerSize] ^= 1;
    try std.testing.expectError(error.InvalidMagic, dmg.parseAlloc(allocator, bad_magic, .{}));

    var bad_data_crc = try allocator.dupe(u8, encoded);
    defer allocator.free(bad_data_crc);
    bad_data_crc[0] ^= 1;
    try std.testing.expectError(
        error.ChecksumMismatch,
        dmg.parseAlloc(allocator, bad_data_crc, .{}),
    );

    var bad_xml = try allocator.dupe(u8, encoded);
    defer allocator.free(bad_xml);
    const trailer = try dmg.parseTrailer(bad_xml);
    const xml_offset: usize = @intCast(trailer.xml.offset);
    bad_xml[xml_offset] = '!';
    try std.testing.expectError(
        error.InvalidDmgPlist,
        dmg.parseAlloc(allocator, bad_xml, .{ .verify_data_fork_checksum = false }),
    );

    try std.testing.expectError(
        error.EncryptedDmg,
        dmg.parseTrailer("encrcdsa"),
    );

    var segmented = try allocator.dupe(u8, encoded);
    defer allocator.free(segmented);
    const trailer_offset = segmented.len - dmg.trailerSize;
    std.mem.writeInt(u32, segmented[trailer_offset + 0x3c ..][0..4], 2, .big);
    try std.testing.expectError(
        error.UnsupportedDmgFeature,
        dmg.parseTrailer(segmented),
    );

    var no_xml = try allocator.dupe(u8, encoded);
    defer allocator.free(no_xml);
    @memset(no_xml[trailer_offset + 0xd8 ..][0..16], 0);
    try std.testing.expectError(
        error.UnsupportedDmgMetadata,
        dmg.parseAlloc(allocator, no_xml, .{}),
    );
}

test "DMG APIs enforce output and range bounds" {
    const input = "DMG bounded decode" ++ ("\x00" ** (512 - 18));
    const encoded = try dmg.encodeAlloc(allocator, input, .{ .block_size = 512 });
    defer allocator.free(encoded);
    var archive = try dmg.parseAlloc(allocator, encoded, .{});
    defer archive.deinit();
    try std.testing.expectError(
        error.OutputLimitExceeded,
        archive.decodePartitionAllocLimited(allocator, 0, input.len - 1),
    );
    try std.testing.expectError(
        error.RangeOutOfBounds,
        archive.decodePartitionRangeAllocLimited(
            allocator,
            0,
            input.len - 8,
            16,
            16,
        ),
    );
    try std.testing.expectError(
        error.RangeOutOfBounds,
        archive.decodePartitionAllocLimited(allocator, 1, input.len),
    );
    try std.testing.expectError(
        error.InvalidDmg,
        dmg.encodeAlloc(allocator, "not sector aligned", .{}),
    );
    try std.testing.expectError(
        error.InvalidDmg,
        dmg.encodeAlloc(allocator, input, .{ .block_size = 0 }),
    );
}

test "DMG XZ decoding enforces the caller dictionary limit" {
    var input: [512]u8 = undefined;
    for (&input, 0..) |*byte, index|
        byte.* = "DMG-XZ-dictionary-limit\n"[index % 24];
    const encoded = try dmg.encodeAlloc(allocator, &input, .{
        .compression = .xz,
        .block_size = 512,
        .copy_if_larger = false,
    });
    defer allocator.free(encoded);
    var archive = try dmg.parseAlloc(allocator, encoded, .{
        .max_xz_dictionary_bytes = 1024,
    });
    defer archive.deinit();
    try std.testing.expectError(
        error.OutputLimitExceeded,
        archive.decodePartitionAllocLimited(allocator, 0, input.len),
    );
}

test "DMG decodes pinned hdiutil zlib and sparse partition" {
    const encoded_text = @embedFile("testdata/hdiutil-hfs-xattrs.dmg.b64");
    const base64 = std.base64.standard.decoderWithIgnore(" \r\n\t");
    const bytes = try allocator.alloc(
        u8,
        base64.calcSizeUpperBound(encoded_text.len),
    );
    defer allocator.free(bytes);
    const bytes_len = try base64.decode(bytes, encoded_text);
    var archive = try dmg.parseAlloc(allocator, bytes[0..bytes_len], .{});
    defer archive.deinit();
    try std.testing.expectEqual(@as(usize, 8), archive.partitions.len);
    try std.testing.expectEqualStrings(
        "disk image (Apple_HFS : 4)",
        archive.partitions[4].name,
    );
    try std.testing.expectEqual(@as(u64, 5_201_920), archive.partitions[4].decoded_size);
    const decoded = try archive.decodePartitionAllocLimited(
        allocator,
        4,
        5_201_920,
    );
    defer allocator.free(decoded);
    var digest: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(decoded, &digest, .{});
    var expected: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
    _ = try std.fmt.hexToBytes(
        &expected,
        "69a6e7366f3f71e4847a08542b2088ab56ecb61ba0534b22f84d43abf6266a77",
    );
    try std.testing.expectEqualSlices(u8, &expected, &digest);
}

fn makeInput(alloc: std.mem.Allocator, size: usize) ![]u8 {
    const output = try alloc.alloc(u8, size);
    for (output[0..1024], 0..) |*byte, index|
        byte.* = "DMG-compressed-block-pattern\n"[index % 29];
    @memset(output[1024..2048], 0);
    var state: u32 = 0xa5a5_1234;
    for (output[2048..]) |*byte| {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        byte.* = @truncate(state);
    }
    return output;
}
