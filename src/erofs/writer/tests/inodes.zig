const std = @import("std");
const archive = @import("../../archive.zig");
const format = @import("../../format.zig");
const writer = @import("../../writer.zig");

const block_size: usize = 4096;

test "EROFS writer emits extended inodes for every codec" {
    const allocator = std.testing.allocator;
    const repeated = [_]writer.Xattr{.{
        .name = "user.shared",
        .value = "extended-shared-value",
    }};
    const payload = "extended inode payload 0123456789\n" ** 180;
    const entries = [_]writer.Entry{
        .{
            .path = "file",
            .data = payload,
            .uid = 70_000,
            .gid = 80_000,
            .modification_time = 23,
            .modification_nsec = 456_789_012,
            .xattrs = &repeated,
        },
        .{
            .path = "dir",
            .kind = .directory,
            .uid = 90_000,
            .gid = 100_000,
            .modification_time = 24,
            .modification_nsec = 456_789_013,
            .xattrs = &repeated,
        },
        .{ .path = "dir/child" },
        .{
            .path = "link",
            .kind = .symlink,
            .target = "file",
            .uid = 110_000,
            .gid = 120_000,
            .modification_time = 25,
            .modification_nsec = 456_789_014,
        },
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
            .epoch = 1_700_000_000,
            .fixed_nsec = 111,
            .root_uid = 130_000,
            .root_gid = 140_000,
            .root_modification_time = 22,
            .root_modification_nsec = 456_789_011,
            .inode_version = .extended,
            .shared_xattrs = true,
        });
        defer allocator.free(encoded);
        const parsed = try archive.Archive.init(encoded);

        const root_inode = try parsed.rootInode();
        try std.testing.expectEqual(@as(usize, 64), root_inode.inode_size);
        try std.testing.expectEqual(@as(u32, 3), root_inode.link_count);
        try std.testing.expectEqual(@as(u32, 130_000), root_inode.uid);
        try std.testing.expectEqual(@as(u32, 140_000), root_inode.gid);
        try std.testing.expectEqual(@as(u64, 1_700_000_022), root_inode.modification_time);
        try std.testing.expectEqual(@as(u32, 456_789_011), root_inode.modification_nsec);

        const file_inode = try parsed.lookup(allocator, "file", payload.len, block_size);
        try std.testing.expectEqual(@as(usize, 64), file_inode.inode_size);
        try std.testing.expectEqual(@as(u32, 70_000), file_inode.uid);
        try std.testing.expectEqual(@as(u32, 80_000), file_inode.gid);
        try std.testing.expectEqual(@as(u64, 1_700_000_023), file_inode.modification_time);
        try std.testing.expectEqual(@as(u32, 456_789_012), file_inode.modification_nsec);
        try std.testing.expect(format.readU16(encoded, file_inode.location) & 1 != 0);
        try std.testing.expectEqualSlices(
            u8,
            &([_]u8{0} ** 16),
            encoded[file_inode.location + 48 .. file_inode.location + 64],
        );
        var attributes = try parsed.readXattrsAllocLimited(
            allocator,
            file_inode,
            1,
            64,
        );
        defer attributes.deinit();
        try std.testing.expectEqualStrings(
            "extended-shared-value",
            attributes.find("user.shared").?.value,
        );
        const decoded = try parsed.extractByPathAllocLimited(
            allocator,
            "file",
            payload.len,
            block_size,
        );
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, payload, decoded);

        const directory_inode = try parsed.lookup(allocator, "dir", 0, block_size);
        try std.testing.expectEqual(@as(usize, 64), directory_inode.inode_size);
        try std.testing.expectEqual(@as(u32, 2), directory_inode.link_count);
        try std.testing.expectEqual(@as(u32, 90_000), directory_inode.uid);
        try std.testing.expectEqual(@as(u32, 100_000), directory_inode.gid);

        const link_inode = try parsed.lookup(allocator, "link", 4, block_size);
        try std.testing.expectEqual(@as(usize, 64), link_inode.inode_size);
        try std.testing.expectEqual(@as(u32, 110_000), link_inode.uid);
        try std.testing.expectEqual(@as(u32, 120_000), link_inode.gid);
    }
}

test "EROFS automatic inode version upgrades only lossy compact metadata" {
    const allocator = std.testing.allocator;
    const entries = [_]writer.Entry{
        .{
            .path = "compact",
            .uid = std.math.maxInt(u16),
            .gid = std.math.maxInt(u16),
            .modification_time = std.math.maxInt(u32),
        },
        .{ .path = "uid", .uid = @as(u32, std.math.maxInt(u16)) + 1 },
        .{ .path = "gid", .gid = @as(u32, std.math.maxInt(u16)) + 1 },
        .{ .path = "nsec", .modification_nsec = 8 },
        .{ .path = "time", .modification_time = @as(u64, std.math.maxInt(u32)) + 1 },
    };
    const encoded = try writer.encodeAlloc(allocator, &entries, .{
        .epoch = 10,
        .fixed_nsec = 7,
        .inode_version = .automatic,
    });
    defer allocator.free(encoded);
    const parsed = try archive.Archive.init(encoded);
    const compact = try parsed.lookup(allocator, "compact", 0, block_size);
    try std.testing.expectEqual(@as(usize, 32), compact.inode_size);
    try std.testing.expectEqual(@as(u64, @as(u64, std.math.maxInt(u32)) + 10), compact.modification_time);
    try std.testing.expectEqual(@as(u32, 7), compact.modification_nsec);
    inline for (.{ "uid", "gid", "nsec", "time" }) |path| {
        const inode_value = try parsed.lookup(allocator, path, 0, block_size);
        try std.testing.expectEqual(@as(usize, 64), inode_value.inode_size);
    }
    const nsec = try parsed.lookup(allocator, "nsec", 0, block_size);
    try std.testing.expectEqual(@as(u32, 8), nsec.modification_nsec);
    const time = try parsed.lookup(allocator, "time", 0, block_size);
    try std.testing.expectEqual(
        @as(u64, std.math.maxInt(u32)) + 11,
        time.modification_time,
    );

    const ordinary = try writer.encodeAlloc(allocator, &.{.{
        .path = "ordinary",
        .data = "compact",
    }}, .{});
    defer allocator.free(ordinary);
    const automatic = try writer.encodeAlloc(allocator, &.{.{
        .path = "ordinary",
        .data = "compact",
    }}, .{ .inode_version = .automatic });
    defer allocator.free(automatic);
    try std.testing.expectEqualSlices(u8, ordinary, automatic);
}

test "EROFS compact inode policy rejects metadata it cannot represent" {
    const allocator = std.testing.allocator;
    inline for (.{
        writer.Entry{ .path = "uid", .uid = @as(u32, std.math.maxInt(u16)) + 1 },
        writer.Entry{ .path = "gid", .gid = @as(u32, std.math.maxInt(u16)) + 1 },
        writer.Entry{ .path = "nsec", .modification_nsec = 1 },
        writer.Entry{ .path = "time", .modification_time = @as(u64, std.math.maxInt(u32)) + 1 },
    }) |entry| {
        try std.testing.expectError(
            error.InvalidErofs,
            writer.encodeAlloc(allocator, &.{entry}, .{}),
        );
    }
    try std.testing.expectError(
        error.InvalidErofs,
        writer.encodeAlloc(allocator, &.{.{
            .path = "bad-nsec",
            .modification_nsec = 1_000_000_000,
        }}, .{ .inode_version = .extended }),
    );
    try std.testing.expectError(
        error.InvalidErofs,
        writer.encodeAlloc(allocator, &.{}, .{
            .root_uid = @as(u32, std.math.maxInt(u16)) + 1,
        }),
    );
}

test "EROFS extended inodes preserve local and external chunk indexes" {
    const allocator = std.testing.allocator;
    const payload = "extended chunk payload\n" ** 300;
    const entries = [_]writer.Entry{.{
        .path = "chunked",
        .data = payload,
        .uid = 70_000,
        .gid = 80_000,
    }};
    const local = try writer.encodeAlloc(allocator, &entries, .{
        .chunk_size = block_size,
        .inode_version = .extended,
    });
    defer allocator.free(local);
    const local_archive = try archive.Archive.init(local);
    const local_inode = try local_archive.lookup(allocator, "chunked", payload.len, block_size);
    try std.testing.expectEqual(@as(usize, 64), local_inode.inode_size);
    try std.testing.expectEqual(format.Layout.chunk_based, local_inode.layout);
    const local_decoded = try local_archive.extractByPathAllocLimited(
        allocator,
        "chunked",
        payload.len,
        block_size,
    );
    defer allocator.free(local_decoded);
    try std.testing.expectEqualSlices(u8, payload, local_decoded);

    var external = try writer.encodeExternalChunksAlloc(allocator, &entries, .{
        .chunk_size = block_size,
        .inode_version = .extended,
    });
    defer external.deinit(allocator);
    const devices = [_][]const u8{external.device};
    const external_archive = try archive.Archive.initWithDevices(external.image, &devices);
    const external_inode = try external_archive.lookup(
        allocator,
        "chunked",
        payload.len,
        block_size,
    );
    try std.testing.expectEqual(@as(usize, 64), external_inode.inode_size);
    const external_decoded = try external_archive.extractByPathAllocLimited(
        allocator,
        "chunked",
        payload.len,
        block_size,
    );
    defer allocator.free(external_decoded);
    try std.testing.expectEqualSlices(u8, payload, external_decoded);
}

test "EROFS extended metabox directory metadata round trips" {
    const allocator = std.testing.allocator;
    const entries = [_]writer.Entry{
        .{ .path = "dir/a", .uid = 70_000, .gid = 80_000 },
        .{ .path = "dir/b" },
        .{ .path = "dir/c" },
    };
    const encoded = try writer.encodeAlloc(allocator, &entries, .{
        .compression = .zstandard,
        .metabox = true,
        .compress_directories = true,
        .inode_version = .extended,
    });
    defer allocator.free(encoded);
    const base = try archive.Archive.init(encoded);
    const metabox_inode = try base.inode(base.superblock.metabox_nid);
    try std.testing.expectEqual(@as(usize, 64), metabox_inode.inode_size);
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
        block_size,
    );
    try std.testing.expect(directory_inode.in_metabox);
    try std.testing.expectEqual(@as(usize, 64), directory_inode.inode_size);
    var directory = try loaded.archive.readDirectoryAlloc(
        allocator,
        directory_inode,
        block_size,
    );
    defer directory.deinit();
    try std.testing.expectEqual(@as(usize, 3), directory.entries.len);
    const child = try loaded.archive.lookup(allocator, "dir/a", 0, block_size);
    try std.testing.expectEqual(@as(u32, 70_000), child.uid);
    try std.testing.expectEqual(@as(u32, 80_000), child.gid);
}

test "EROFS extended inode writer releases every allocation failure" {
    const allocator = std.testing.allocator;
    const Test = struct {
        fn run(failing_allocator: std.mem.Allocator) !void {
            const encoded = try writer.encodeAlloc(failing_allocator, &.{.{
                .path = "file",
                .data = "extended allocation payload",
                .uid = 70_000,
                .gid = 80_000,
                .modification_time = 123,
                .modification_nsec = 456,
                .xattrs = &.{.{ .name = "user.extended", .value = "value" }},
            }}, .{
                .compression = .deflate,
                .inode_version = .automatic,
            });
            defer failing_allocator.free(encoded);
            const parsed = try archive.Archive.init(encoded);
            const inode_value = try parsed.lookup(
                failing_allocator,
                "file",
                64,
                block_size,
            );
            try std.testing.expectEqual(@as(usize, 64), inode_value.inode_size);
            const decoded = try parsed.extractByPathAllocLimited(
                failing_allocator,
                "file",
                64,
                block_size,
            );
            defer failing_allocator.free(decoded);
            try std.testing.expectEqualStrings("extended allocation payload", decoded);
        }
    };
    try std.testing.checkAllAllocationFailures(allocator, Test.run, .{});
}

test "EROFS inode time boundaries reject overflow and invalid root nanoseconds" {
    const allocator = std.testing.allocator;
    inline for (.{ writer.InodeVersion.compact, .extended, .automatic }) |policy| {
        try std.testing.expectError(error.InvalidErofs, writer.encodeAlloc(allocator, &.{.{
            .path = "overflow",
            .modification_time = 1,
        }}, .{ .epoch = std.math.maxInt(u64), .inode_version = policy }));
        try std.testing.expectError(error.InvalidErofs, writer.encodeAlloc(allocator, &.{}, .{
            .root_modification_nsec = 1_000_000_000,
            .inode_version = policy,
        }));
    }
    const encoded = try writer.encodeAlloc(allocator, &.{.{
        .path = "last-second",
        .modification_time = 1,
        .modification_nsec = 999_999_999,
    }}, .{
        .epoch = std.math.maxInt(u64) - 1,
        .inode_version = .automatic,
        .root_mode = 0o750,
    });
    defer allocator.free(encoded);
    const parsed = try archive.Archive.init(encoded);
    const root_inode = try parsed.rootInode();
    try std.testing.expectEqual(@as(u16, 0o40750), root_inode.mode);
    const file = try parsed.lookup(allocator, "last-second", 0, block_size);
    try std.testing.expectEqual(std.math.maxInt(u64), file.modification_time);
    try std.testing.expectEqual(@as(u32, 999_999_999), file.modification_nsec);
}

test "EROFS extended inode tails remain after the complete inode and xattrs" {
    const allocator = std.testing.allocator;
    const payload = "extended inode tail payload\n" ** 210;
    inline for (.{ writer.TailPacking.fragments, .compressed_inline }) |tail_packing| {
        const encoded = try writer.encodeAlloc(allocator, &.{.{
            .path = "tail",
            .data = payload,
            .uid = 70_000,
            .xattrs = &.{.{ .name = "user.tail", .value = "value" }},
        }}, .{
            .compression = .lz4,
            .inode_version = .automatic,
            .tail_packing = tail_packing,
        });
        defer allocator.free(encoded);
        const parsed = try archive.Archive.init(encoded);
        const inode_value = try parsed.lookup(allocator, "tail", payload.len, block_size);
        try std.testing.expectEqual(@as(usize, 64), inode_value.inode_size);
        const decoded = try parsed.extractByPathAllocLimited(allocator, "tail", payload.len, block_size);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, payload, decoded);
    }
}
