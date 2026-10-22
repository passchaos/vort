const std = @import("std");
const archive_mod = @import("archive.zig");
const format = @import("format.zig");
const writer = @import("writer.zig");

const Archive = archive_mod.Archive;
const Compression = writer.Compression;
const Entry = writer.Entry;
const encodeAlloc = writer.encodeAlloc;
const block_size: usize = 4096;

test "EROFS writer emits deterministic whole and partial packed fragments" {
    const allocator = std.testing.allocator;
    const exact = "E" ** 8192;
    var random: [8193]u8 = undefined;
    fillPseudoRandom(&random);
    const entries = [_]Entry{
        .{ .path = "exact", .data = exact },
        .{ .path = "random", .data = &random },
        .{
            .path = "tiny",
            .data = "tiny",
            .xattrs = &.{.{ .name = "user.fragment", .value = "yes" }},
        },
    };

    inline for (.{ Compression.lz4, .deflate, .zstandard }) |compression| {
        const encoded = try encodeAlloc(allocator, &entries, .{
            .compression = compression,
            .tail_packing = .fragments,
        });
        defer allocator.free(encoded);
        const repeated = try encodeAlloc(allocator, &entries, .{
            .compression = compression,
            .tail_packing = .fragments,
        });
        defer allocator.free(repeated);
        try std.testing.expectEqualSlices(u8, encoded, repeated);

        const parsed = try Archive.init(encoded);
        try std.testing.expect(
            parsed.superblock.feature_incompat & format.feature_incompat_fragments != 0,
        );
        try std.testing.expect(parsed.superblock.packed_nid != 0);
        try std.testing.expectEqual(@as(u64, entries.len + 2), parsed.superblock.inode_count);
        const packed_inode = try parsed.inode(parsed.superblock.packed_nid);
        try std.testing.expectEqual(format.FileType.regular, try packed_inode.fileType());

        var root = try parsed.readDirectoryAlloc(allocator, try parsed.rootInode(), block_size);
        defer root.deinit();
        try std.testing.expectEqual(@as(usize, entries.len), root.entries.len);
        try std.testing.expect(root.find("$vort-packed") == null);

        const exact_inode = try parsed.lookup(allocator, "exact", exact.len, block_size);
        try std.testing.expect(exact_inode.fragment_offset != null);
        try std.testing.expect(exact_inode.fragment_logical_start != 0);
        const exact_decoded = try parsed.readFlatAllocLimited(allocator, exact_inode, exact.len);
        defer allocator.free(exact_decoded);
        try std.testing.expectEqualSlices(u8, exact, exact_decoded);

        const random_inode = try parsed.lookup(allocator, "random", random.len, block_size);
        try std.testing.expectEqual(@as(usize, 8192), random_inode.fragment_logical_start);
        const random_decoded = try parsed.readFlatAllocLimited(allocator, random_inode, random.len);
        defer allocator.free(random_decoded);
        try std.testing.expectEqualSlices(u8, &random, random_decoded);

        const tiny_inode = try parsed.lookup(allocator, "tiny", 4, block_size);
        try std.testing.expectEqual(@as(usize, 0), tiny_inode.fragment_logical_start);
        const tiny_decoded = try parsed.readFlatAllocLimited(allocator, tiny_inode, 4);
        defer allocator.free(tiny_decoded);
        try std.testing.expectEqualStrings("tiny", tiny_decoded);
        var tiny_xattrs = try parsed.readXattrsAllocLimited(allocator, tiny_inode, 1, 32);
        defer tiny_xattrs.deinit();
        try std.testing.expectEqualStrings("yes", tiny_xattrs.find("user.fragment").?.value);
    }
}

test "EROFS fragment writer validates mode and releases allocation failures" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(
        error.InvalidErofs,
        encodeAlloc(allocator, &.{.{ .path = "file", .data = "payload" }}, .{
            .compression = .stored,
            .tail_packing = .fragments,
        }),
    );
    const empty_default = try encodeAlloc(allocator, &.{}, .{ .compression = .lz4 });
    defer allocator.free(empty_default);
    const empty_fragments = try encodeAlloc(allocator, &.{}, .{
        .compression = .lz4,
        .tail_packing = .fragments,
    });
    defer allocator.free(empty_fragments);
    try std.testing.expectEqualSlices(u8, empty_default, empty_fragments);
    const Test = struct {
        fn run(failing_allocator: std.mem.Allocator) !void {
            const encoded = try encodeAlloc(
                failing_allocator,
                &.{
                    .{ .path = "large", .data = "fragment writer payload\n" ** 300 },
                    .{ .path = "tiny", .data = "tiny" },
                },
                .{ .compression = .lz4, .tail_packing = .fragments },
            );
            defer failing_allocator.free(encoded);
            const parsed = try @import("archive.zig").Archive.init(encoded);
            const decoded = try parsed.extractByPathAllocLimited(
                failing_allocator,
                "large",
                8192,
                block_size,
            );
            defer failing_allocator.free(decoded);
            try std.testing.expectEqualStrings("fragment writer payload\n", decoded[0..24]);
        }
    };
    try std.testing.checkAllAllocationFailures(allocator, Test.run, .{});
}

fn fillPseudoRandom(output: []u8) void {
    var state: u32 = 0x1234_5678;
    for (output) |*byte| {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        byte.* = @truncate(state);
    }
}
