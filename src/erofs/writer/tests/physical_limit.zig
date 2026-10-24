const std = @import("std");
const writer = @import("../../writer.zig");
const archive = @import("../../archive.zig");
const format = @import("../../format.zig");
const prefix = @import("../prefix.zig");

const block_size = 4096;

fn payload() [12 * 1024 + 40 * 1024 + 37]u8 {
    var data: [12 * 1024 + 40 * 1024 + 37]u8 = undefined;
    var prng = std.Random.DefaultPrng.init(0x4341_5041_4349_5459);
    prng.random().bytes(data[0 .. 12 * 1024]);
    @memset(data[12 * 1024 ..], 'R');
    return data;
}

fn expectPhysicalBound(metadata: []const u8, inode: archive.Inode, capacity: usize) !void {
    if (inode.layout != .compressed_full or
        (inode.fragment_offset != null and inode.fragment_logical_start == 0)) return;
    const count = (inode.file_size + block_size - 1) / block_size;
    for (0..count) |index| {
        const logical = index * block_size;
        if (inode.fragment_offset != null and logical >= inode.fragment_logical_start) continue;
        if (inode.compressed_inline_size != 0 and logical >= inode.compressed_inline_logical_start) continue;
        const offset = inode.compressed_index_start + index * 8;
        const kind = format.readU16(metadata, offset) & 3;
        if (kind == 2) continue;
        var blocks: usize = 1;
        if (kind == 1 and index + 1 < count and format.readU16(metadata, offset + 8) & 3 == 2) {
            const delta = format.readU16(metadata, offset + 12);
            try std.testing.expect(delta & 0x800 != 0);
            blocks = delta & ~@as(u16, 0x800);
        }
        try std.testing.expect(blocks > 0 and blocks * block_size <= capacity);
    }
}

test "EROFS physical capacity bounds every pcluster across all codecs" {
    const allocator = std.testing.allocator;
    const data = payload();
    inline for (.{ writer.Compression.lz4, .lzma, .deflate, .zstandard }) |compression| {
        for ([_]usize{ 4096, 8192, 12288 }) |capacity| {
            const options = writer.Options{ .compression = compression, .compression_extent_size = 32768, .max_pcluster_size = capacity };
            const entries = [_]writer.Entry{
                .{ .path = "data", .data = &data },
                .{ .path = "tiny", .data = "T" },
                .{ .path = "empty" },
            };
            const encoded = try writer.encodeAlloc(allocator, &entries, options);
            defer allocator.free(encoded);
            const repeated = try writer.encodeAlloc(allocator, &entries, options);
            defer allocator.free(repeated);
            try std.testing.expectEqualSlices(u8, encoded, repeated);
            const parsed = try archive.Archive.init(encoded);
            for (entries) |entry| {
                const inode = try parsed.lookup(allocator, entry.path, entry.data.len, block_size);
                try expectPhysicalBound(encoded, inode, capacity);
                const decoded = try parsed.readFlatAllocLimited(allocator, inode, entry.data.len);
                defer allocator.free(decoded);
                try std.testing.expectEqualSlices(u8, entry.data, decoded);
                if (std.mem.eql(u8, entry.path, "tiny"))
                    try std.testing.expectEqual(@as(u16, 0), format.readU16(encoded, inode.compressed_index_start) & 3);
            }
            if (compression == .lz4)
                try std.testing.expectEqual(@as(u16, @intCast(capacity / block_size)), format.readU16(encoded, format.super_offset + 128 + 4));
        }
    }
}

test "EROFS physical capacity supports tails directories extended inodes and metabox" {
    const allocator = std.testing.allocator;
    const data = payload();
    const entries = [_]writer.Entry{
        .{ .path = "dir/data", .data = &data, .uid = 70_000 },
        .{ .path = "tiny", .data = "T" },
        .{ .path = "link", .kind = .symlink, .target = "dir/data" },
    };
    inline for (.{ writer.Compression.lz4, .lzma, .deflate, .zstandard }) |compression| {
        for ([_]writer.Options{
            .{ .tail_packing = .fragments },
            .{ .tail_packing = .compressed_inline },
            .{ .metabox = true, .compress_directories = true },
        }) |variant| {
            var options = variant;
            options.compression = compression;
            options.compression_extent_size = 32768;
            options.max_pcluster_size = 4096;
            options.inode_version = .automatic;
            options.force_48bit = true;
            options.shared_xattrs = true;
            const encoded = try writer.encodeAlloc(allocator, &entries, options);
            defer allocator.free(encoded);
            const base = try archive.Archive.init(encoded);
            var loaded = if (variant.metabox) blk: {
                const metadata_inode = try base.inode(base.superblock.metabox_nid);
                try expectPhysicalBound(encoded, metadata_inode, 4096);
                break :blk try base.loadMetaboxAllocLimited(allocator, metadata_inode.file_size, 1024 * 1024);
            } else null;
            defer if (loaded) |*owner| owner.deinit();
            const parsed = if (loaded) |owner| owner.archive else base;
            for (entries) |entry| {
                const expected = if (entry.kind == .symlink) entry.target else entry.data;
                const inode = try parsed.lookup(allocator, entry.path, expected.len, block_size);
                try expectPhysicalBound(parsed.metabox_bytes orelse encoded, inode, 4096);
                const decoded = try parsed.readFlatAllocLimited(allocator, inode, expected.len);
                defer allocator.free(decoded);
                try std.testing.expectEqualSlices(u8, expected, decoded);
            }
        }
    }
}

test "EROFS physical capacity validates limits and works with default logical groups" {
    const allocator = std.testing.allocator;
    for ([_]usize{ 0, 4095, 4097, 1024 * 1024 + 4096 }) |capacity|
        try std.testing.expectError(error.InvalidErofs, writer.encodeAlloc(allocator, &.{}, .{ .compression = .lz4, .max_pcluster_size = capacity }));
    try std.testing.expectError(error.InvalidErofs, writer.encodeAlloc(allocator, &.{}, .{ .max_pcluster_size = 4096 }));
    const encoded = try writer.encodeAlloc(allocator, &.{.{ .path = "data", .data = "D" ** 8192 }}, .{ .compression = .lz4, .max_pcluster_size = 4096 });
    defer allocator.free(encoded);
    const parsed = try archive.Archive.init(encoded);
    try std.testing.expectEqual(@as(u16, 1), format.readU16(encoded, format.super_offset + 128 + 4));
    const inode = try parsed.lookup(allocator, "data", 8192, block_size);
    try expectPhysicalBound(encoded, inode, 4096);
    const decoded = try parsed.readFlatAllocLimited(allocator, inode, 8192);
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings("D" ** 8192, decoded);
}

test "EROFS frame capacity selection handles nonmonotonic encoded sizes" {
    const FakeEncoder = struct {
        bytes: [16]u8 = @splat(0),
        pub fn encodeScratch(self: *@This(), input: []const u8) ![]const u8 {
            const size: usize = switch (input.len) {
                16 => 9,
                12 => 5,
                8 => 8,
                4 => 2,
                else => unreachable,
            };
            return self.bytes[0..size];
        }
    };
    var encoder = FakeEncoder{};
    const result = try prefix.selectFrames(&encoder, &([_]u8{0} ** 16), 6, 4);
    try std.testing.expectEqual(@as(usize, 12), result.consumed);
    try std.testing.expectEqual(@as(usize, 5), result.bytes.len);
}

test "EROFS physical capacity releases every allocation failure" {
    const Test = struct {
        fn run(allocator: std.mem.Allocator, compression: writer.Compression) !void {
            const data = payload();
            const encoded = try writer.encodeAlloc(allocator, &.{.{ .path = "dir/data", .data = data[0..16384], .uid = 70_000 }}, .{
                .compression = compression,
                .compression_extent_size = 16384,
                .max_pcluster_size = 4096,
                .metabox = true,
                .compress_directories = true,
                .inode_version = .automatic,
            });
            defer allocator.free(encoded);
        }
    };
    inline for (.{ writer.Compression.lz4, .lzma, .deflate, .zstandard }) |compression|
        try std.testing.checkAllAllocationFailures(std.testing.allocator, Test.run, .{compression});
}
