const std = @import("std");
const archive = @import("../../archive.zig");
const format = @import("../../format.zig");
const writer = @import("../../writer.zig");

const block_size = 4096;
const extent_size = 64 * 1024;
const mixed_size = 16 * 1024 + 1367;

fn mixedPayload() [mixed_size]u8 {
    var input: [mixed_size]u8 = undefined;
    var prng = std.Random.DefaultPrng.init(0x5043_4c55_5354_4552);
    prng.random().bytes(input[0..8192]);
    @memcpy(input[8192..16384], input[0..8192]);
    @memcpy(input[16384..], input[0..1367]);
    return input;
}

test "EROFS grouped compression plans multi-block pclusters and shrinks stored geometry" {
    const allocator = std.testing.allocator;
    const repeated = "EROFS grouped compression payload\n" ** 6000;
    const mixed = mixedPayload();
    var random: [8193]u8 = undefined;
    var prng = std.Random.DefaultPrng.init(0x5241_5742_4c4f_434b);
    prng.random().bytes(&random);
    const entries = [_]writer.Entry{
        .{ .path = "repeated", .data = repeated },
        .{ .path = "mixed", .data = &mixed },
        .{ .path = "random", .data = &random },
        .{ .path = "empty" },
        .{ .path = "link", .kind = .symlink, .target = "repeated" },
    };
    inline for (.{ writer.Compression.lz4, .lzma, .deflate, .zstandard }) |compression| {
        const ordinary = try writer.encodeAlloc(allocator, &entries, .{ .compression = compression });
        defer allocator.free(ordinary);
        const encoded = try writer.encodeAlloc(allocator, &entries, .{ .compression = compression, .compression_extent_size = extent_size });
        defer allocator.free(encoded);
        const repeated_wire = try writer.encodeAlloc(allocator, &entries, .{ .compression = compression, .compression_extent_size = extent_size });
        defer allocator.free(repeated_wire);
        try std.testing.expectEqualSlices(u8, encoded, repeated_wire);
        try std.testing.expect(encoded.len < ordinary.len);
        const parsed = try archive.Archive.init(encoded);
        const mixed_inode = try parsed.lookup(allocator, "mixed", mixed.len, block_size);
        try std.testing.expect(mixed_inode.compressed_advise & 2 != 0);
        try std.testing.expect(format.readU32(encoded, mixed_inode.location + 16) >= 2);
        try std.testing.expectEqual(@as(u16, 2), format.readU16(encoded, mixed_inode.compressed_index_start + 8) & 3);
        if (compression == .lz4) {
            try std.testing.expectEqual(@as(u16, 1), parsed.superblock.available_compression_algorithms);
            try std.testing.expectEqual(@as(u16, 16), format.readU16(encoded, format.super_offset + 128 + 4));
        }
        for (entries) |entry| {
            const expected = if (entry.kind == .symlink) entry.target else entry.data;
            const decoded = try parsed.extractByPathAllocLimited(allocator, entry.path, expected.len, block_size);
            defer allocator.free(decoded);
            try std.testing.expectEqualSlices(u8, expected, decoded);
        }
    }
}

test "EROFS grouped compression preserves fragment and inline tails" {
    const allocator = std.testing.allocator;
    const mixed = mixedPayload();
    const entries = [_]writer.Entry{
        .{ .path = "mixed", .data = &mixed },
        .{ .path = "tiny", .data = "tiny" },
    };
    inline for (.{ writer.Compression.lz4, .lzma, .deflate, .zstandard }) |compression| {
        inline for (.{ writer.TailPacking.fragments, .compressed_inline }) |tail_packing| {
            const encoded = try writer.encodeAlloc(allocator, &entries, .{
                .compression = compression,
                .compression_extent_size = extent_size,
                .tail_packing = tail_packing,
                .inode_version = .extended,
                .force_48bit = true,
            });
            defer allocator.free(encoded);
            const parsed = try archive.Archive.init(encoded);
            const inode_value = try parsed.lookup(allocator, "mixed", mixed.len, block_size);
            try std.testing.expectEqual(@as(usize, 64), inode_value.inode_size);
            try std.testing.expect(inode_value.compressed_advise & 2 != 0);
            if (tail_packing == .fragments) {
                try std.testing.expect(inode_value.fragment_offset != null);
            } else {
                try std.testing.expect(inode_value.compressed_inline_size > 0);
            }
            for (entries) |entry| {
                const decoded = try parsed.extractByPathAllocLimited(allocator, entry.path, entry.data.len, block_size);
                defer allocator.free(decoded);
                try std.testing.expectEqualSlices(u8, entry.data, decoded);
            }
        }
    }
}

test "EROFS grouped metabox is encoded after visible physical addresses" {
    const allocator = std.testing.allocator;
    const mixed = mixedPayload();
    var large_attr: [9000]u8 = undefined;
    var prng = std.Random.DefaultPrng.init(0x4d45_5441_424f_5850);
    prng.random().bytes(&large_attr);
    const common = [_]writer.Xattr{.{ .name = "user.shared", .value = "shared attribute" }};
    const entries = [_]writer.Entry{
        .{ .path = "dir/mixed", .data = &mixed, .uid = 70_000, .xattrs = &common },
        .{ .path = "other", .data = "other", .xattrs = &common },
    };
    inline for (.{ writer.Compression.lz4, .lzma, .deflate, .zstandard }) |compression| {
        const encoded = try writer.encodeAlloc(allocator, &entries, .{
            .compression = compression,
            .compression_extent_size = extent_size,
            .metabox = true,
            .compress_directories = true,
            .inode_version = .automatic,
            .shared_xattrs = true,
            .xattr_prefixes = &.{"user."},
            .root_xattrs = &.{ .{ .name = "user.large", .value = &large_attr }, common[0] },
        });
        defer allocator.free(encoded);
        const base = try archive.Archive.init(encoded);
        const metadata_inode = try base.inode(base.superblock.metabox_nid);
        try std.testing.expect(format.readU32(encoded, metadata_inode.location + 16) >= 2);
        var loaded = try base.loadMetaboxAllocLimited(allocator, metadata_inode.file_size, 1024 * 1024);
        defer loaded.deinit();
        const mixed_inode = try loaded.archive.lookup(allocator, "dir/mixed", mixed.len, block_size);
        try std.testing.expectEqual(@as(u32, 70_000), mixed_inode.uid);
        for (entries) |entry| {
            const decoded = try loaded.archive.extractByPathAllocLimited(allocator, entry.path, entry.data.len, block_size);
            defer allocator.free(decoded);
            try std.testing.expectEqualSlices(u8, entry.data, decoded);
        }
        var attributes = try loaded.archive.readXattrsAllocLimited(allocator, try loaded.archive.rootInode(), 2, 10_000);
        defer attributes.deinit();
        try std.testing.expectEqualSlices(u8, &large_attr, attributes.find("user.large").?.value);
    }
}

test "EROFS grouped compression accepts one MiB extents and rejects invalid settings" {
    const allocator = std.testing.allocator;
    const input = try allocator.alloc(u8, 1024 * 1024 + 8192);
    defer allocator.free(input);
    @memset(input, 'A');
    inline for (.{ writer.Compression.lz4, .lzma, .deflate, .zstandard }) |compression| {
        const encoded = try writer.encodeAlloc(allocator, &.{.{ .path = "large", .data = input }}, .{
            .compression = compression,
            .compression_extent_size = 1024 * 1024,
        });
        defer allocator.free(encoded);
        const parsed = try archive.Archive.init(encoded);
        const decoded = try parsed.extractByPathAllocLimited(allocator, "large", input.len, block_size);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
    }
    for ([_]usize{ 0, 2048, 4097, 2 * 1024 * 1024 }) |invalid| {
        try std.testing.expectError(error.InvalidErofs, writer.encodeAlloc(allocator, &.{}, .{ .compression = .lz4, .compression_extent_size = invalid }));
    }
    try std.testing.expectError(error.InvalidErofs, writer.encodeAlloc(allocator, &.{}, .{ .compression_extent_size = extent_size }));
}

test "EROFS grouped metabox writer releases every allocation failure" {
    const Test = struct {
        fn run(allocator: std.mem.Allocator) !void {
            const mixed = mixedPayload();
            const encoded = try writer.encodeAlloc(allocator, &.{.{
                .path = "dir/mixed",
                .data = &mixed,
                .uid = 70_000,
            }}, .{
                .compression = .lzma,
                .compression_extent_size = extent_size,
                .metabox = true,
                .compress_directories = true,
                .inode_version = .automatic,
            });
            defer allocator.free(encoded);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Test.run, .{});
}
