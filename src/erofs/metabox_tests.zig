const std = @import("std");
const archive_mod = @import("archive.zig");
const format = @import("format.zig");

const Archive = archive_mod.Archive;

test "EROFS loads bounded metabox inode and directory metadata" {
    const allocator = std.testing.allocator;
    const image = try fixtureAlloc(allocator, @embedFile("testdata/metabox-id.erofs.b64"));
    defer allocator.free(image);
    const base = try Archive.init(image);
    try std.testing.expect(
        base.superblock.feature_incompat & format.feature_incompat_metabox != 0,
    );
    try std.testing.expectEqual(@as(u64, 128), base.superblock.metabox_nid);
    try std.testing.expectError(error.ErofsMissingMetabox, base.rootInode());
    try std.testing.expectError(
        error.OutputLimitExceeded,
        base.loadMetaboxAllocLimited(
            allocator,
            24_575,
            archive_mod.default_packed_extent_limit,
        ),
    );

    var loaded = try base.loadMetaboxAllocLimited(
        allocator,
        24_576,
        archive_mod.default_packed_extent_limit,
    );
    defer loaded.deinit();
    try std.testing.expectEqual(@as(usize, 24_576), loaded.bytes.len);
    const archive = loaded.archive;
    const root_inode = try archive.rootInode();
    try std.testing.expect(root_inode.in_metabox);
    var root = try archive.readDirectoryAlloc(allocator, root_inode, 4096);
    defer root.deinit();
    try std.testing.expect(root.find("dir") != null);
    try std.testing.expect(root.find("root.txt") != null);

    const directory_inode = try archive.lookup(allocator, "dir", 0, 4096);
    var directory = try archive.readDirectoryAlloc(allocator, directory_inode, 4096);
    defer directory.deinit();
    try std.testing.expectEqual(@as(usize, 80), directory.entries.len);
    try std.testing.expectEqualStrings("file-000", directory.entries[0].name);
    try std.testing.expectEqualStrings("file-079", directory.entries[79].name);
    const decoded = try archive.extractByPathAllocLimited(
        allocator,
        "dir/file-079",
        220,
        4096,
    );
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "metabox-79\n" ** 20, decoded);
}

test "EROFS metabox reconstructs inline shared and long-prefix xattrs" {
    const allocator = std.testing.allocator;
    const image = try fixtureAlloc(allocator, @embedFile("testdata/metabox-xattr.erofs.b64"));
    defer allocator.free(image);
    const base = try Archive.init(image);
    var loaded = try base.loadMetaboxAllocLimited(
        allocator,
        1024 * 1024,
        archive_mod.default_packed_extent_limit,
    );
    defer loaded.deinit();
    const inode_value = try loaded.archive.lookup(allocator, "a", 0, 4096);
    var attributes = try loaded.archive.readXattrsAllocLimited(
        allocator,
        inode_value,
        2,
        64,
    );
    defer attributes.deinit();
    try std.testing.expectEqualStrings("value", attributes.find("user.vort.repeat").?.value);
    try std.testing.expectEqualStrings("one", attributes.find("user.vort.unique").?.value);
}

test "EROFS metabox rejects malformed superblock and payload" {
    const allocator = std.testing.allocator;
    const image = try fixtureAlloc(allocator, @embedFile("testdata/metabox-id.erofs.b64"));
    defer allocator.free(image);
    const base_offset = format.super_offset;
    std.mem.writeInt(u64, image[base_offset + 128 ..][0..8], @as(u64, 1) << 63, .little);
    refreshFixtureChecksum(image);
    try std.testing.expectError(error.InvalidErofs, Archive.init(image));

    std.mem.writeInt(u64, image[base_offset + 128 ..][0..8], 128, .little);
    refreshFixtureChecksum(image);
    const base = try Archive.init(image);
    image[4096] ^= 0x5a;
    try std.testing.expectError(
        error.InvalidMatch,
        base.loadMetaboxAllocLimited(
            allocator,
            1024 * 1024,
            archive_mod.default_packed_extent_limit,
        ),
    );
}

test "EROFS metabox loader releases every allocation failure" {
    const allocator = std.testing.allocator;
    const image = try fixtureAlloc(allocator, @embedFile("testdata/metabox-id.erofs.b64"));
    defer allocator.free(image);
    const Test = struct {
        fn run(failing_allocator: std.mem.Allocator, bytes: []const u8) !void {
            const base = try Archive.init(bytes);
            var loaded = try base.loadMetaboxAllocLimited(
                failing_allocator,
                24_576,
                archive_mod.default_packed_extent_limit,
            );
            defer loaded.deinit();
            const decoded = try loaded.archive.extractByPathAllocLimited(
                failing_allocator,
                "root.txt",
                21,
                4096,
            );
            defer failing_allocator.free(decoded);
            try std.testing.expectEqualStrings("root metabox payload\n", decoded);
        }
    };
    try std.testing.checkAllAllocationFailures(allocator, Test.run, .{image});
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
