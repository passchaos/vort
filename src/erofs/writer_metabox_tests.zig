const std = @import("std");
const archive = @import("archive.zig");
const format = @import("format.zig");
const writer = @import("writer.zig");

const block_size: usize = 4096;

test "EROFS writer emits interoperable MZi metadata for every codec" {
    const allocator = std.testing.allocator;
    const prefixes = [_][]const u8{"user.vort."};
    const root_xattrs = [_]writer.Xattr{
        .{ .name = "user.vort.root", .value = "root-value" },
    };
    const file_xattrs = [_]writer.Xattr{
        .{ .name = "user.vort.author", .value = "vort" },
        .{ .name = "security.selinux", .value = "u:object_r:system_file:s0" },
    };
    const payload = "MZi compressed metadata payload 0123456789\n" ** 300;
    const entries = [_]writer.Entry{
        .{
            .path = "etc/config",
            .data = payload,
            .xattrs = &file_xattrs,
        },
        .{ .path = "etc/tiny", .data = "inline in metabox" },
        .{ .path = "link", .kind = .symlink, .target = "etc/config" },
        .{ .path = "empty", .kind = .directory },
    };

    inline for (.{
        writer.Compression.stored,
        .lz4,
        .lzma,
        .deflate,
        .zstandard,
    }) |compression| {
        const encoded = try writer.encodeAlloc(allocator, &entries, .{
            .compression = compression,
            .root_xattrs = &root_xattrs,
            .xattr_prefixes = &prefixes,
            .metabox = true,
        });
        defer allocator.free(encoded);

        const base = try archive.Archive.init(encoded);
        try std.testing.expectEqual(@as(usize, 144), base.superblock.super_size);
        try std.testing.expect(
            base.superblock.feature_incompat & format.feature_incompat_metabox != 0,
        );
        try std.testing.expect(
            base.superblock.feature_incompat & format.feature_incompat_48bit != 0,
        );
        try std.testing.expect(base.superblock.root_nid >> 63 != 0);
        try std.testing.expect(base.superblock.metabox_nid != 0);
        try std.testing.expectEqual(@as(u64, 0), base.superblock.metabox_nid >> 63);
        try std.testing.expectError(error.ErofsMissingMetabox, base.rootInode());

        const metabox_inode = try base.inode(base.superblock.metabox_nid);
        try std.testing.expectEqual(
            if (compression == .stored)
                format.Layout.flat_plain
            else
                format.Layout.compressed_full,
            metabox_inode.layout,
        );
        try std.testing.expect(metabox_inode.file_size >= block_size);
        try std.testing.expectEqual(@as(usize, 0), metabox_inode.file_size % block_size);
        try std.testing.expectError(
            error.OutputLimitExceeded,
            base.loadMetaboxAllocLimited(
                allocator,
                metabox_inode.file_size - 1,
                block_size,
            ),
        );

        var loaded = try base.loadMetaboxAllocLimited(
            allocator,
            metabox_inode.file_size,
            block_size,
        );
        defer loaded.deinit();
        const parsed = loaded.archive;
        const root_inode = try parsed.rootInode();
        try std.testing.expect(root_inode.in_metabox);
        var root_attributes = try parsed.readXattrsAllocLimited(
            allocator,
            root_inode,
            1,
            64,
        );
        defer root_attributes.deinit();
        try std.testing.expectEqualStrings(
            "root-value",
            root_attributes.find("user.vort.root").?.value,
        );

        const config_inode = try parsed.lookup(
            allocator,
            "etc/config",
            payload.len,
            block_size,
        );
        try std.testing.expect(config_inode.in_metabox);
        var attributes = try parsed.readXattrsAllocLimited(
            allocator,
            config_inode,
            2,
            128,
        );
        defer attributes.deinit();
        try std.testing.expectEqualStrings(
            "vort",
            attributes.find("user.vort.author").?.value,
        );
        try std.testing.expectEqualStrings(
            "u:object_r:system_file:s0",
            attributes.find("security.selinux").?.value,
        );
        const decoded = try parsed.extractByPathAllocLimited(
            allocator,
            "etc/config",
            payload.len,
            block_size,
        );
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, payload, decoded);
        const link = try parsed.extractByPathAllocLimited(
            allocator,
            "link",
            10,
            block_size,
        );
        defer allocator.free(link);
        try std.testing.expectEqualStrings("etc/config", link);
    }
}

test "EROFS metabox writer rejects unsupported layout combinations" {
    const allocator = std.testing.allocator;
    const entries = [_]writer.Entry{.{
        .path = "file",
        .data = "payload",
    }};
    try std.testing.expectError(
        error.InvalidErofs,
        writer.encodeAlloc(allocator, &entries, .{
            .compression = .lz4,
            .tail_packing = .fragments,
            .metabox = true,
        }),
    );
    try std.testing.expectError(
        error.InvalidErofs,
        writer.encodeAlloc(allocator, &entries, .{
            .compression = .lz4,
            .tail_packing = .compressed_inline,
            .metabox = true,
        }),
    );
    try std.testing.expectError(
        error.InvalidErofs,
        writer.encodeAlloc(allocator, &entries, .{
            .chunk_size = block_size,
            .metabox = true,
        }),
    );
    try std.testing.expectError(
        error.InvalidErofs,
        writer.encodeExternalChunksAlloc(allocator, &entries, .{
            .chunk_size = block_size,
            .metabox = true,
        }),
    );
}

test "EROFS writer spans multi-block metabox and directory data" {
    const allocator = std.testing.allocator;
    var entries: std.ArrayList(writer.Entry) = .empty;
    defer entries.deinit(allocator);
    var paths: std.ArrayList([]u8) = .empty;
    defer {
        for (paths.items) |path| allocator.free(path);
        paths.deinit(allocator);
    }
    for (0..300) |index| {
        const path = try std.fmt.allocPrint(allocator, "item-{d:0>3}", .{index});
        try paths.append(allocator, path);
        try entries.append(allocator, .{ .path = path });
    }

    const encoded = try writer.encodeAlloc(allocator, entries.items, .{
        .compression = .lz4,
        .metabox = true,
    });
    defer allocator.free(encoded);
    const base = try archive.Archive.init(encoded);
    const metabox_inode = try base.inode(base.superblock.metabox_nid);
    try std.testing.expect(metabox_inode.file_size > block_size);
    var loaded = try base.loadMetaboxAllocLimited(
        allocator,
        metabox_inode.file_size,
        block_size,
    );
    defer loaded.deinit();
    const root_inode = try loaded.archive.rootInode();
    var root = try loaded.archive.readDirectoryAlloc(
        allocator,
        root_inode,
        16 * 1024,
    );
    defer root.deinit();
    try std.testing.expectEqual(@as(usize, 300), root.entries.len);
    try std.testing.expectEqualStrings("item-000", root.entries[0].name);
    try std.testing.expectEqualStrings("item-299", root.entries[299].name);
    const last = try loaded.archive.lookup(
        allocator,
        "item-299",
        0,
        16 * 1024,
    );
    try std.testing.expect(last.in_metabox);
}

test "EROFS metabox writer releases every allocation failure" {
    const allocator = std.testing.allocator;
    const Test = struct {
        fn run(failing_allocator: std.mem.Allocator) !void {
            const encoded = try writer.encodeAlloc(failing_allocator, &.{.{
                .path = "nested/file",
                .data = "allocation failure metabox payload" ** 32,
                .xattrs = &.{.{ .name = "user.vort.test", .value = "value" }},
            }}, .{
                .compression = .lz4,
                .root_xattrs = &.{.{ .name = "user.root", .value = "root" }},
                .xattr_prefixes = &.{"user.vort."},
                .metabox = true,
            });
            defer failing_allocator.free(encoded);
            const base = try archive.Archive.init(encoded);
            var loaded = try base.loadMetaboxAllocLimited(
                failing_allocator,
                16 * 1024,
                block_size,
            );
            defer loaded.deinit();
            const decoded = try loaded.archive.extractByPathAllocLimited(
                failing_allocator,
                "nested/file",
                2048,
                block_size,
            );
            defer failing_allocator.free(decoded);
            try std.testing.expectEqualStrings(
                "allocation failure metabox payload" ** 32,
                decoded,
            );
        }
    };
    try std.testing.checkAllAllocationFailures(allocator, Test.run, .{});
}
