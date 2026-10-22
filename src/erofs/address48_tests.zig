const std = @import("std");
const archive_mod = @import("archive.zig");
const format = @import("format.zig");
const writer = @import("writer.zig");

const Archive = archive_mod.Archive;
const block_size: usize = 4096;

test "EROFS reads 48-bit compressed extents and high superblock fields" {
    const allocator = std.testing.allocator;
    const bytes = try fixtureAlloc(allocator, @embedFile("testdata/zstd-48bit.erofs.b64"));
    defer allocator.free(bytes);
    const archive = try Archive.init(bytes);
    try std.testing.expect(
        archive.superblock.feature_incompat & format.feature_incompat_48bit != 0,
    );
    const expected = ("48BIT-COMPRESSIBLE-0123456789\n" ** 500)[0..12000];
    const inode_value = try archive.lookup(allocator, "large", expected.len, block_size);
    try std.testing.expectEqual(@as(u8, 4), inode_value.compressed_extent_record_size);
    try std.testing.expectEqual(@as(usize, 3), inode_value.compressed_extent_count);
    const decoded = try archive.readFlatAllocLimited(allocator, inode_value, expected.len);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, expected, decoded);

    const original_physical = format.readU64(bytes, inode_value.compressed_extent_start);
    std.mem.writeInt(u64, bytes[inode_value.compressed_extent_start..][0..8], @as(u64, 1) << 32, .little);
    try std.testing.expectError(
        error.TruncatedFrame,
        archive.readFlatAllocLimited(allocator, inode_value, expected.len),
    );
    std.mem.writeInt(
        u64,
        bytes[inode_value.compressed_extent_start..][0..8],
        original_physical,
        .little,
    );

    const base = format.super_offset;
    std.mem.writeInt(u64, bytes[base + 112 ..][0..8], archive.superblock.root_nid, .little);
    std.mem.writeInt(u16, bytes[base + 14 ..][0..2], 0, .little);
    refreshFixtureChecksum(bytes);
    const root64 = try Archive.init(bytes);
    try std.testing.expectEqual(archive.superblock.root_nid, root64.superblock.root_nid);
    _ = try root64.rootInode();

    std.mem.writeInt(u16, bytes[base + 14 ..][0..2], 1, .little);
    refreshFixtureChecksum(bytes);
    try std.testing.expectError(error.TruncatedFrame, Archive.init(bytes));
}

test "EROFS 48-bit extent reader releases every allocation failure" {
    const allocator = std.testing.allocator;
    const bytes = try fixtureAlloc(allocator, @embedFile("testdata/zstd-48bit.erofs.b64"));
    defer allocator.free(bytes);
    const Test = struct {
        fn run(failing_allocator: std.mem.Allocator, image: []const u8) !void {
            const archive = try Archive.init(image);
            const decoded = try archive.extractByPathAllocLimited(
                failing_allocator,
                "large",
                12000,
                block_size,
            );
            defer failing_allocator.free(decoded);
            try std.testing.expectEqual(@as(usize, 12000), decoded.len);
        }
    };
    try std.testing.checkAllAllocationFailures(allocator, Test.run, .{bytes});
}

test "EROFS writer emits interoperable forced 48-bit images" {
    const allocator = std.testing.allocator;
    const payload = "forced 48-bit writer payload\n" ** 300;
    inline for (.{
        writer.Compression.stored,
        writer.Compression.lz4,
        writer.Compression.deflate,
        writer.Compression.zstandard,
    }) |compression| {
        const image = try writer.encodeAlloc(allocator, &.{.{
            .path = "file",
            .data = payload,
        }}, .{ .compression = compression, .force_48bit = true });
        defer allocator.free(image);
        const archive = try Archive.init(image);
        try std.testing.expect(
            archive.superblock.feature_incompat & format.feature_incompat_48bit != 0,
        );
        const decoded = try archive.extractByPathAllocLimited(
            allocator,
            "file",
            payload.len,
            block_size,
        );
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, payload, decoded);
    }

    const local = try writer.encodeAlloc(allocator, &.{.{
        .path = "file",
        .data = payload,
    }}, .{ .chunk_size = block_size, .force_48bit = true });
    defer allocator.free(local);
    const local_archive = try Archive.init(local);
    try std.testing.expect(
        local_archive.superblock.feature_incompat & format.feature_incompat_48bit != 0,
    );

    var external = try writer.encodeExternalChunksAlloc(allocator, &.{.{
        .path = "file",
        .data = payload,
    }}, .{ .chunk_size = block_size, .force_48bit = true });
    defer external.deinit(allocator);
    const external_archive = try Archive.initWithDevices(
        external.image,
        &.{external.device},
    );
    try std.testing.expect(
        external_archive.superblock.feature_incompat & format.feature_incompat_48bit != 0,
    );
    const info = try external_archive.deviceInfo(0);
    try std.testing.expectEqual(@as(u64, 0), info.blocks >> 32);
    try std.testing.expectEqual(@as(u64, 0), info.unified_start >> 32);
}

fn fixtureAlloc(allocator: std.mem.Allocator, encoded_base64: []const u8) ![]u8 {
    const decoder = std.base64.standard.decoderWithIgnore(" \r\n\t");
    const bytes = try allocator.alloc(u8, decoder.calcSizeUpperBound(encoded_base64.len));
    errdefer allocator.free(bytes);
    const written = try decoder.decode(bytes, encoded_base64);
    return allocator.realloc(bytes, written);
}

fn refreshFixtureChecksum(bytes: []u8) void {
    const base = format.super_offset;
    const block_size_value: usize = @as(usize, 1) << @intCast(bytes[base + 12]);
    const checksum = format.computeSuperblockChecksum(bytes[base..block_size_value]);
    std.mem.writeInt(u32, bytes[base + 4 ..][0..4], checksum, .little);
}
