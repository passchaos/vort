const std = @import("std");
const archive = @import("archive.zig");
const format = @import("format.zig");
const writer = @import("writer.zig");

const block_size: usize = 4096;

test "EROFS writer deduplicates profitable shared xattrs for every codec" {
    const allocator = std.testing.allocator;
    const prefixes = [_][]const u8{"user.vort."};
    const repeated = [_]writer.Xattr{
        .{ .name = "user.vort.repeat", .value = "shared-value" },
        .{ .name = "system.posix_acl_access", .value = &.{} },
    };
    const distinct = [_]writer.Xattr{
        .{ .name = "user.vort.repeat", .value = "different-value" },
        .{ .name = "system.posix_acl_access", .value = &.{} },
    };
    const entries = [_]writer.Entry{
        .{ .path = "shared-a", .xattrs = &repeated },
        .{ .path = "shared-b", .xattrs = &repeated },
        .{ .path = "shared-c", .xattrs = &repeated },
        .{ .path = "distinct", .xattrs = &distinct },
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
            .xattr_prefixes = &prefixes,
            .shared_xattrs = true,
        });
        defer allocator.free(encoded);
        const parsed = try archive.Archive.init(encoded);
        try std.testing.expectEqual(@as(u32, 0), parsed.superblock.xattr_block);
        try std.testing.expect(
            parsed.superblock.feature_compat &
                format.feature_compat_shared_xattrs_in_metabox == 0,
        );

        var shared_id: ?u32 = null;
        inline for (.{ "shared-a", "shared-b", "shared-c" }) |path| {
            const inode_value = try parsed.lookup(allocator, path, 0, block_size);
            try std.testing.expectEqual(@as(usize, 20), inode_value.xattr_size);
            const ibody_start = inode_value.location + inode_value.inode_size;
            try std.testing.expectEqual(@as(u8, 1), encoded[ibody_start + 4]);
            const id = format.readU32(encoded, ibody_start + 12);
            if (shared_id) |expected|
                try std.testing.expectEqual(expected, id)
            else
                shared_id = id;

            var attributes = try parsed.readXattrsAllocLimited(
                allocator,
                inode_value,
                2,
                128,
            );
            defer attributes.deinit();
            try std.testing.expectEqualStrings(
                "shared-value",
                attributes.find("user.vort.repeat").?.value,
            );
            try std.testing.expectEqual(
                @as(usize, 0),
                attributes.find("system.posix_acl_access").?.value.len,
            );
        }

        const shared_offset = parsed.superblock.xattr_block * block_size +
            shared_id.? * 4;
        try std.testing.expectEqual(@as(u8, 0x80), encoded[shared_offset + 1]);
        const distinct_inode = try parsed.lookup(allocator, "distinct", 0, block_size);
        const distinct_ibody = distinct_inode.location + distinct_inode.inode_size;
        try std.testing.expectEqual(@as(u8, 0), encoded[distinct_ibody + 4]);
        var distinct_attributes = try parsed.readXattrsAllocLimited(
            allocator,
            distinct_inode,
            2,
            128,
        );
        defer distinct_attributes.deinit();
        try std.testing.expectEqualStrings(
            "different-value",
            distinct_attributes.find("user.vort.repeat").?.value,
        );
    }
}

test "EROFS metabox inodes reference primary shared xattr region" {
    const allocator = std.testing.allocator;
    const attributes = [_]writer.Xattr{
        .{ .name = "user.shared", .value = "metabox-shared-value" },
    };
    const entries = [_]writer.Entry{
        .{ .path = "a", .data = "a", .xattrs = &attributes },
        .{ .path = "b", .data = "b", .xattrs = &attributes },
        .{ .path = "c", .data = "c", .xattrs = &attributes },
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
            .metabox = true,
            .shared_xattrs = true,
        });
        defer allocator.free(encoded);
        const base = try archive.Archive.init(encoded);
        try std.testing.expect(
            base.superblock.feature_compat &
                format.feature_compat_shared_xattrs_in_metabox == 0,
        );
        const metabox_inode = try base.inode(base.superblock.metabox_nid);
        var loaded = try base.loadMetaboxAllocLimited(
            allocator,
            metabox_inode.file_size,
            block_size,
        );
        defer loaded.deinit();

        inline for (.{ "a", "b", "c" }) |path| {
            const inode_value = try loaded.archive.lookup(
                allocator,
                path,
                1,
                block_size,
            );
            try std.testing.expect(inode_value.in_metabox);
            try std.testing.expectEqual(@as(usize, 16), inode_value.xattr_size);
            var decoded = try loaded.archive.readXattrsAllocLimited(
                allocator,
                inode_value,
                1,
                64,
            );
            defer decoded.deinit();
            try std.testing.expectEqualStrings(
                "metabox-shared-value",
                decoded.find("user.shared").?.value,
            );
        }
    }
}

test "EROFS shared xattr option is a no-op without profitable duplicates" {
    const allocator = std.testing.allocator;
    const entries = [_]writer.Entry{
        .{ .path = "a", .xattrs = &.{.{ .name = "user.a", .value = "a" }} },
        .{ .path = "b", .xattrs = &.{.{ .name = "user.b", .value = "b" }} },
    };
    const ordinary = try writer.encodeAlloc(allocator, &entries, .{});
    defer allocator.free(ordinary);
    const planned = try writer.encodeAlloc(allocator, &entries, .{ .shared_xattrs = true });
    defer allocator.free(planned);
    try std.testing.expectEqualSlices(u8, ordinary, planned);

    try std.testing.expectError(
        error.InvalidErofs,
        writer.encodeAlloc(allocator, &.{.{
            .path = "duplicate",
            .xattrs = &.{
                .{ .name = "user.same", .value = "a" },
                .{ .name = "user.same", .value = "b" },
            },
        }}, .{ .shared_xattrs = true }),
    );
}

test "EROFS shared xattr IDs are relative to a nonzero xattr block" {
    const allocator = std.testing.allocator;
    var prefix_storage: [17][250]u8 = undefined;
    var prefixes: [prefix_storage.len][]const u8 = undefined;
    for (&prefix_storage, 0..) |*bytes, index| {
        @memset(bytes, 'a');
        @memcpy(bytes[0..5], "user.");
        bytes[5] = 'a' + @as(u8, @intCast(index));
        prefixes[index] = bytes;
    }
    var name: [254]u8 = undefined;
    @memcpy(name[0..250], prefixes[prefixes.len - 1]);
    @memcpy(name[250..], "tail");
    const attributes = [_]writer.Xattr{.{
        .name = &name,
        .value = "shared-across-prefix-blocks",
    }};
    const entries = [_]writer.Entry{
        .{ .path = "a", .xattrs = &attributes },
        .{ .path = "b", .xattrs = &attributes },
        .{ .path = "c", .xattrs = &attributes },
    };
    const encoded = try writer.encodeAlloc(allocator, &entries, .{
        .xattr_prefixes = &prefixes,
        .shared_xattrs = true,
    });
    defer allocator.free(encoded);
    const parsed = try archive.Archive.init(encoded);
    try std.testing.expect(parsed.superblock.xattr_block > 0);
    const inode_value = try parsed.lookup(allocator, "b", 0, block_size);
    const ibody_start = inode_value.location + inode_value.inode_size;
    const id = format.readU32(encoded, ibody_start + 12);
    const shared_offset = @as(usize, parsed.superblock.xattr_block) * block_size +
        @as(usize, id) * 4;
    try std.testing.expectEqual(@as(u8, 0x80 | (prefixes.len - 1)), encoded[shared_offset + 1]);
    var decoded = try parsed.readXattrsAllocLimited(
        allocator,
        inode_value,
        1,
        512,
    );
    defer decoded.deinit();
    try std.testing.expectEqualStrings(
        "shared-across-prefix-blocks",
        decoded.find(&name).?.value,
    );
}

test "EROFS shared xattr planner caps each ibody at 255 IDs" {
    const allocator = std.testing.allocator;
    var names: std.ArrayList([]u8) = .empty;
    defer {
        for (names.items) |name| allocator.free(name);
        names.deinit(allocator);
    }
    const attributes = try allocator.alloc(writer.Xattr, 260);
    defer allocator.free(attributes);
    for (attributes, 0..) |*attribute, index| {
        const name = try std.fmt.allocPrint(allocator, "user.shared-{d:0>3}", .{index});
        try names.append(allocator, name);
        attribute.* = .{ .name = name, .value = "shared-value" };
    }
    const entries = [_]writer.Entry{
        .{ .path = "a", .xattrs = attributes },
        .{ .path = "b", .xattrs = attributes },
        .{ .path = "c", .xattrs = attributes },
    };
    const encoded = try writer.encodeAlloc(allocator, &entries, .{ .shared_xattrs = true });
    defer allocator.free(encoded);
    const parsed = try archive.Archive.init(encoded);
    const inode_value = try parsed.lookup(allocator, "a", 0, block_size);
    const ibody_start = inode_value.location + inode_value.inode_size;
    try std.testing.expectEqual(std.math.maxInt(u8), encoded[ibody_start + 4]);
    var decoded = try parsed.readXattrsAllocLimited(
        allocator,
        inode_value,
        attributes.len,
        16 * 1024,
    );
    defer decoded.deinit();
    try std.testing.expectEqual(attributes.len, decoded.entries.len);
    try std.testing.expectEqualStrings(
        "shared-value",
        decoded.find("user.shared-259").?.value,
    );
}

test "EROFS shared xattr writer releases every allocation failure" {
    const allocator = std.testing.allocator;
    const Test = struct {
        fn run(failing_allocator: std.mem.Allocator) !void {
            const attributes = [_]writer.Xattr{
                .{ .name = "user.vort.repeat", .value = "shared-value" },
                .{ .name = "user.unique", .value = "inline-value" },
            };
            const encoded = try writer.encodeAlloc(failing_allocator, &.{
                .{ .path = "a", .xattrs = &attributes },
                .{ .path = "b", .xattrs = &attributes },
                .{ .path = "c", .xattrs = &attributes },
            }, .{
                .compression = .lz4,
                .xattr_prefixes = &.{"user.vort."},
                .shared_xattrs = true,
            });
            defer failing_allocator.free(encoded);
            const parsed = try archive.Archive.init(encoded);
            const inode_value = try parsed.lookup(
                failing_allocator,
                "b",
                0,
                block_size,
            );
            var decoded = try parsed.readXattrsAllocLimited(
                failing_allocator,
                inode_value,
                2,
                128,
            );
            defer decoded.deinit();
            try std.testing.expectEqualStrings(
                "shared-value",
                decoded.find("user.vort.repeat").?.value,
            );
        }
    };
    try std.testing.checkAllAllocationFailures(allocator, Test.run, .{});
}
