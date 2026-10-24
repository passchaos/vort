const std = @import("std");
const archive_mod = @import("archive.zig");
const format = @import("format.zig");

const Archive = archive_mod.Archive;

test "EROFS reads local chunk block maps and holes" {
    const allocator = std.testing.allocator;
    const bytes = try fixtureAlloc(allocator, @embedFile("testdata/chunk-local.erofs.b64"));
    defer allocator.free(bytes);
    const archive = try Archive.init(bytes);
    try std.testing.expectEqual(@as(u16, 0), archive.superblock.extra_devices);
    try std.testing.expect(
        archive.superblock.feature_incompat & format.feature_incompat_chunked_file != 0,
    );

    const expected = ("CHUNK-DATA-0123456789\n" ** 500)[0..9000];
    const inode_value = try archive.lookup(allocator, "large", expected.len, 4096);
    try std.testing.expectEqual(format.Layout.chunk_based, inode_value.layout);
    try std.testing.expectEqual(@as(u16, 1), inode_value.chunk_format);
    try std.testing.expectEqual(@as(u8, 13), inode_value.chunk_bits);
    try std.testing.expectEqual(@as(u8, 4), inode_value.chunk_index_size);
    const decoded = try archive.readFlatAllocLimited(allocator, inode_value, expected.len);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, expected, decoded);
    try std.testing.expectError(
        error.OutputLimitExceeded,
        archive.readFlatAllocLimited(allocator, inode_value, expected.len - 1),
    );

    std.mem.writeInt(
        u32,
        bytes[inode_value.chunk_index_start..][0..4],
        std.math.maxInt(u32),
        .little,
    );
    const sparse = try archive.readFlatAllocLimited(allocator, inode_value, expected.len);
    defer allocator.free(sparse);
    for (sparse[0..8192]) |byte| try std.testing.expectEqual(@as(u8, 0), byte);
    try std.testing.expectEqualSlices(u8, expected[8192..], sparse[8192..]);

    std.mem.writeInt(
        u32,
        bytes[inode_value.chunk_index_start..][0..4],
        @intCast(archive.superblock.block_count),
        .little,
    );
    try std.testing.expectError(
        error.InvalidErofs,
        archive.readFlatAllocLimited(allocator, inode_value, expected.len),
    );
}

test "EROFS reads borrowed external chunk devices" {
    const allocator = std.testing.allocator;
    const image = try fixtureAlloc(allocator, @embedFile("testdata/chunk-external.erofs.b64"));
    defer allocator.free(image);
    const blob = try fixtureAlloc(allocator, @embedFile("testdata/chunk-external.blob.b64"));
    defer allocator.free(blob);

    const metadata_only = try Archive.init(image);
    try std.testing.expectEqual(@as(u16, 1), metadata_only.superblock.extra_devices);
    const metadata_inode = try metadata_only.lookup(allocator, "large", 9000, 4096);
    try std.testing.expectError(
        error.ErofsMissingDevice,
        metadata_only.readFlatAllocLimited(allocator, metadata_inode, 9000),
    );

    const archive = try Archive.initWithDevices(image, &.{blob});
    const info = try archive.deviceInfo(0);
    try std.testing.expectEqual(@as(u64, 4), info.blocks);
    try std.testing.expectEqual(@as(u64, 1), info.unified_start);
    try std.testing.expectEqualSlices(u8, &@as([64]u8, @splat(0)), &info.tag);
    const expected = ("CHUNK-DATA-0123456789\n" ** 500)[0..9000];
    const inode_value = try archive.lookup(allocator, "large", expected.len, 4096);
    try std.testing.expectEqual(@as(u16, 0x21), inode_value.chunk_format);
    try std.testing.expectEqual(@as(u8, 8), inode_value.chunk_index_size);
    const decoded = try archive.readFlatAllocLimited(allocator, inode_value, expected.len);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, expected, decoded);
    const small = try archive.extractByPathAllocLimited(allocator, "small", 12, 4096);
    defer allocator.free(small);
    try std.testing.expectEqualStrings("chunk-small\n", small);

    try std.testing.expectError(
        error.InvalidErofs,
        Archive.initWithDevices(image, &.{ blob, blob }),
    );
    try std.testing.expectError(
        error.TruncatedFrame,
        Archive.initWithDevices(image, &.{blob[0..4095]}),
    );

    std.mem.writeInt(
        u32,
        image[inode_value.chunk_index_start + 4 ..][0..4],
        4,
        .little,
    );
    try std.testing.expectError(
        error.InvalidErofs,
        archive.readFlatAllocLimited(allocator, inode_value, expected.len),
    );
}

test "EROFS external chunk reader accepts explicit-only device slots" {
    const allocator = std.testing.allocator;
    const image = try fixtureAlloc(allocator, @embedFile("testdata/chunk-external.erofs.b64"));
    defer allocator.free(image);
    const slot_start: usize = @as(usize, format.readU16(image, format.super_offset + 88)) * 128;
    std.mem.writeInt(u32, image[slot_start + 68 ..][0..4], 0, .little);
    refreshFixtureChecksum(image);
    const blob = try fixtureAlloc(allocator, @embedFile("testdata/chunk-external.blob.b64"));
    defer allocator.free(blob);
    const archive = try Archive.initWithDevices(image, &.{blob});
    const expected = ("CHUNK-DATA-0123456789\n" ** 500)[0..9000];
    const decoded = try archive.extractByPathAllocLimited(allocator, "large", 9000, 4096);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, expected, decoded);
    try std.testing.expectEqual(@as(u64, 0), (try archive.deviceInfo(0)).unified_start);
}

test "EROFS external chunk reader releases every allocation failure" {
    const allocator = std.testing.allocator;
    const image = try fixtureAlloc(allocator, @embedFile("testdata/chunk-external.erofs.b64"));
    defer allocator.free(image);
    const blob = try fixtureAlloc(allocator, @embedFile("testdata/chunk-external.blob.b64"));
    defer allocator.free(blob);
    const Test = struct {
        fn run(
            failing_allocator: std.mem.Allocator,
            metadata: []const u8,
            device: []const u8,
        ) !void {
            const archive = try Archive.initWithDevices(metadata, &.{device});
            const decoded = try archive.extractByPathAllocLimited(
                failing_allocator,
                "large",
                9000,
                4096,
            );
            defer failing_allocator.free(decoded);
            try std.testing.expectEqual(@as(usize, 9000), decoded.len);
        }
    };
    try std.testing.checkAllAllocationFailures(allocator, Test.run, .{ image, blob });
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
    const block_size: usize = @as(usize, 1) << @intCast(bytes[base + 12]);
    const checksum = format.computeSuperblockChecksum(bytes[base..block_size]);
    std.mem.writeInt(u32, bytes[base + 4 ..][0..4], checksum, .little);
}
