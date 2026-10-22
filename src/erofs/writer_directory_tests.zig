const std = @import("std");
const archive = @import("archive.zig");
const format = @import("format.zig");
const writer = @import("writer.zig");

const block_size: usize = 4096;

test "EROFS writer stores directories as whole fragments for every codec" {
    const allocator = std.testing.allocator;
    var entries: std.ArrayList(writer.Entry) = .empty;
    defer entries.deinit(allocator);
    var paths: std.ArrayList([]u8) = .empty;
    defer {
        for (paths.items) |path| allocator.free(path);
        paths.deinit(allocator);
    }
    try entries.append(allocator, .{
        .path = "empty",
        .kind = .directory,
        .xattrs = &.{.{ .name = "user.directory", .value = "empty" }},
    });
    try entries.append(allocator, .{ .path = "small/tiny" });
    for (0..400) |index| {
        const path = try std.fmt.allocPrint(allocator, "wide/item-{d:0>3}", .{index});
        try paths.append(allocator, path);
        try entries.append(allocator, .{ .path = path });
    }

    inline for (.{ writer.Compression.lz4, .lzma, .deflate, .zstandard }) |compression| {
        const encoded = try writer.encodeAlloc(allocator, entries.items, .{
            .compression = compression,
            .compress_directories = true,
        });
        defer allocator.free(encoded);
        const parsed = try archive.Archive.init(encoded);
        try std.testing.expect(
            parsed.superblock.feature_incompat & format.feature_incompat_fragments != 0,
        );
        try std.testing.expect(parsed.superblock.packed_nid != 0);

        const root_inode = try parsed.rootInode();
        try std.testing.expectEqual(format.Layout.compressed_full, root_inode.layout);
        try std.testing.expectEqual(@as(?u64, 0), root_inode.fragment_offset);
        var root = try parsed.readDirectoryAlloc(allocator, root_inode, 16 * 1024);
        defer root.deinit();
        try std.testing.expectEqual(@as(usize, 3), root.entries.len);

        const wide_inode = try parsed.lookup(allocator, "wide", 0, 16 * 1024);
        try std.testing.expectEqual(format.Layout.compressed_full, wide_inode.layout);
        try std.testing.expect(wide_inode.fragment_offset != null);
        var wide = try parsed.readDirectoryAlloc(allocator, wide_inode, 16 * 1024);
        defer wide.deinit();
        try std.testing.expectEqual(@as(usize, 400), wide.entries.len);
        try std.testing.expectEqualStrings("item-000", wide.entries[0].name);
        try std.testing.expectEqualStrings("item-399", wide.entries[399].name);

        const empty_inode = try parsed.lookup(allocator, "empty", 0, 16 * 1024);
        try std.testing.expectEqual(format.Layout.flat_inline, empty_inode.layout);
        try std.testing.expectEqual(@as(?u64, null), empty_inode.fragment_offset);
        var attributes = try parsed.readXattrsAllocLimited(
            allocator,
            empty_inode,
            1,
            32,
        );
        defer attributes.deinit();
        try std.testing.expectEqualStrings(
            "empty",
            attributes.find("user.directory").?.value,
        );

        const packed_inode = try parsed.inode(parsed.superblock.packed_nid);
        const packed_bytes = try parsed.readFlatAllocWithLimits(
            allocator,
            packed_inode,
            .{
                .max_output_len = 32 * 1024,
                .max_packed_extent_len = block_size,
            },
        );
        defer allocator.free(packed_bytes);
        try std.testing.expect(packed_bytes.len > wide_inode.file_size);
    }
}

test "EROFS compressed directories coexist with file tail packing" {
    const allocator = std.testing.allocator;
    var entries: std.ArrayList(writer.Entry) = .empty;
    defer entries.deinit(allocator);
    var paths: std.ArrayList([]u8) = .empty;
    defer {
        for (paths.items) |path| allocator.free(path);
        paths.deinit(allocator);
    }
    for (0..40) |index| {
        const path = try std.fmt.allocPrint(allocator, "dir/item-{d:0>2}", .{index});
        try paths.append(allocator, path);
        try entries.append(allocator, .{ .path = path, .data = "file-fragment" });
    }
    inline for (.{ writer.TailPacking.fragments, .compressed_inline }) |tail_packing| {
        const encoded = try writer.encodeAlloc(allocator, entries.items, .{
            .compression = .lz4,
            .tail_packing = tail_packing,
            .compress_directories = true,
        });
        defer allocator.free(encoded);
        const parsed = try archive.Archive.init(encoded);
        const directory_inode = try parsed.lookup(allocator, "dir", 0, 16 * 1024);
        try std.testing.expect(directory_inode.fragment_offset != null);
        var directory = try parsed.readDirectoryAlloc(allocator, directory_inode, 16 * 1024);
        defer directory.deinit();
        try std.testing.expectEqual(@as(usize, 40), directory.entries.len);
        const decoded = try parsed.extractByPathAllocLimited(
            allocator,
            "dir/item-39",
            13,
            16 * 1024,
        );
        defer allocator.free(decoded);
        try std.testing.expectEqualStrings("file-fragment", decoded);
    }
}

test "EROFS metabox directory inodes resolve primary packed fragments" {
    const allocator = std.testing.allocator;
    var entries: std.ArrayList(writer.Entry) = .empty;
    defer entries.deinit(allocator);
    var paths: std.ArrayList([]u8) = .empty;
    defer {
        for (paths.items) |path| allocator.free(path);
        paths.deinit(allocator);
    }
    for (0..80) |index| {
        const path = try std.fmt.allocPrint(allocator, "dir/item-{d:0>2}", .{index});
        try paths.append(allocator, path);
        try entries.append(allocator, .{ .path = path });
    }
    const encoded = try writer.encodeAlloc(allocator, entries.items, .{
        .compression = .deflate,
        .metabox = true,
        .compress_directories = true,
    });
    defer allocator.free(encoded);
    const base = try archive.Archive.init(encoded);
    try std.testing.expect(base.superblock.packed_nid != 0);
    const metabox_inode = try base.inode(base.superblock.metabox_nid);
    var loaded = try base.loadMetaboxAllocLimited(
        allocator,
        metabox_inode.file_size,
        block_size,
    );
    defer loaded.deinit();
    const directory_inode = try loaded.archive.lookup(
        allocator,
        "dir",
        0,
        16 * 1024,
    );
    try std.testing.expect(directory_inode.in_metabox);
    try std.testing.expect(directory_inode.fragment_offset != null);
    var directory = try loaded.archive.readDirectoryAlloc(
        allocator,
        directory_inode,
        16 * 1024,
    );
    defer directory.deinit();
    try std.testing.expectEqual(@as(usize, 80), directory.entries.len);
}

test "EROFS compressed directory option rejects stored mode and preserves tiny wire" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(
        error.InvalidErofs,
        writer.encodeAlloc(allocator, &.{}, .{ .compress_directories = true }),
    );

    const ordinary = try writer.encodeAlloc(allocator, &.{}, .{ .compression = .lz4 });
    defer allocator.free(ordinary);
    const planned = try writer.encodeAlloc(allocator, &.{}, .{
        .compression = .lz4,
        .compress_directories = true,
    });
    defer allocator.free(planned);
    try std.testing.expectEqualSlices(u8, ordinary, planned);
}

test "EROFS compressed directory writer releases every allocation failure" {
    const allocator = std.testing.allocator;
    const Test = struct {
        fn run(failing_allocator: std.mem.Allocator) !void {
            const encoded = try writer.encodeAlloc(failing_allocator, &.{
                .{ .path = "dir/a" },
                .{ .path = "dir/b" },
                .{ .path = "dir/c" },
            }, .{
                .compression = .zstandard,
                .compress_directories = true,
            });
            defer failing_allocator.free(encoded);
            const parsed = try archive.Archive.init(encoded);
            const inode_value = try parsed.lookup(
                failing_allocator,
                "dir",
                0,
                block_size,
            );
            var directory = try parsed.readDirectoryAlloc(
                failing_allocator,
                inode_value,
                block_size,
            );
            defer directory.deinit();
            try std.testing.expectEqual(@as(usize, 3), directory.entries.len);
        }
    };
    try std.testing.checkAllAllocationFailures(allocator, Test.run, .{});
}
