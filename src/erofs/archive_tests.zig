const std = @import("std");
const archive_mod = @import("archive.zig");
const format = @import("format.zig");

const Archive = archive_mod.Archive;

fn fixtureAlloc(allocator: std.mem.Allocator, encoded_base64: []const u8) ![]u8 {
    const decoder = std.base64.standard.decoderWithIgnore(" \r\n\t");
    const bytes = try allocator.alloc(
        u8,
        decoder.calcSizeUpperBound(encoded_base64.len),
    );
    errdefer allocator.free(bytes);
    const written = try decoder.decode(bytes, encoded_base64);
    return allocator.realloc(bytes, written);
}

test "EROFS compact LZ4 two-byte indexes decode a large reference file" {
    const allocator = std.testing.allocator;
    const bytes = try fixtureAlloc(
        allocator,
        @embedFile("testdata/lz4-compact-big.erofs.b64"),
    );
    defer allocator.free(bytes);
    const archive = try Archive.init(bytes);
    try std.testing.expectEqual(@as(usize, 4096), archive.superblock.block_size);
    var root = try archive.readDirectoryAlloc(
        allocator,
        try archive.rootInode(),
        1024 * 1024,
    );
    defer root.deinit();
    try std.testing.expectEqual(@as(usize, 1), root.entries.len);
    const decoded = try archive.extractByPathAllocLimited(
        allocator,
        "big.bin",
        250_000,
        1024 * 1024,
    );
    defer allocator.free(decoded);
    const pattern = "EROFS compact two-byte index payload 0123456789\n";
    try std.testing.expectEqual(@as(usize, 250_000), decoded.len);
    for (decoded, 0..) |byte, index|
        try std.testing.expectEqual(pattern[index % pattern.len], byte);
}

test "EROFS validates superblock checksum and output limits" {
    const allocator = std.testing.allocator;
    const bytes = try fixtureAlloc(
        allocator,
        @embedFile("testdata/lz4-compact-big.erofs.b64"),
    );
    defer allocator.free(bytes);
    bytes[1024 + 20] ^= 1;
    try std.testing.expectError(error.ChecksumMismatch, Archive.init(bytes));
    bytes[1024 + 20] ^= 1;
    const archive = try Archive.init(bytes);
    try std.testing.expectError(
        error.OutputLimitExceeded,
        archive.extractByPathAllocLimited(
            allocator,
            "big.bin",
            249_999,
            1024 * 1024,
        ),
    );
}

test "EROFS reads inline and shared xattrs from erofs-utils" {
    const allocator = std.testing.allocator;
    const bytes = try fixtureAlloc(
        allocator,
        @embedFile("testdata/xattr-inline-shared.erofs.b64"),
    );
    defer allocator.free(bytes);
    const archive = try Archive.init(bytes);

    const inline_inode = try archive.lookup(allocator, "inline", 0, 4096);
    try std.testing.expectEqual(@as(usize, 36), inline_inode.xattr_size);
    var inline_xattrs = try archive.readXattrsAllocLimited(
        allocator,
        inline_inode,
        1,
        64,
    );
    defer inline_xattrs.deinit();
    try std.testing.expectEqual(@as(usize, 1), inline_xattrs.entries.len);
    try std.testing.expectEqualStrings(
        "inline-value",
        inline_xattrs.find("user.unique").?.value,
    );

    inline for (.{ "shared-a", "shared-b", "shared-c" }) |path| {
        const inode_value = try archive.lookup(allocator, path, 0, 4096);
        try std.testing.expectEqual(@as(usize, 16), inode_value.xattr_size);
        var shared_xattrs = try archive.readXattrsAllocLimited(
            allocator,
            inode_value,
            1,
            64,
        );
        defer shared_xattrs.deinit();
        try std.testing.expectEqualStrings(
            "shared-value",
            shared_xattrs.find("user.repeat").?.value,
        );
    }

    const empty_inode = try archive.lookup(allocator, "sub/leaf", 0, 4096);
    var empty_xattrs = try archive.readXattrsAllocLimited(
        allocator,
        empty_inode,
        1,
        16,
    );
    defer empty_xattrs.deinit();
    try std.testing.expectEqual(@as(usize, 0), empty_xattrs.find("user.empty").?.value.len);

    try std.testing.expectError(
        error.OutputLimitExceeded,
        archive.readXattrsAllocLimited(allocator, inline_inode, 0, 64),
    );
    try std.testing.expectError(
        error.OutputLimitExceeded,
        archive.readXattrsAllocLimited(allocator, inline_inode, 1, 22),
    );
}

test "EROFS xattr reader rejects malformed ibodies and shared references" {
    const allocator = std.testing.allocator;
    const bytes = try fixtureAlloc(
        allocator,
        @embedFile("testdata/xattr-inline-shared.erofs.b64"),
    );
    defer allocator.free(bytes);
    const archive = try Archive.init(bytes);
    const inline_inode = try archive.lookup(allocator, "inline", 0, 4096);
    const inline_start = inline_inode.location + inline_inode.inode_size;

    bytes[inline_start + 5] = 1;
    try std.testing.expectError(
        error.InvalidErofs,
        archive.readXattrsAllocLimited(allocator, inline_inode, 8, 1024),
    );
    bytes[inline_start + 5] = 0;

    bytes[inline_start + 12 + 1] = 0x81;
    try std.testing.expectError(
        error.InvalidErofs,
        archive.readXattrsAllocLimited(allocator, inline_inode, 8, 1024),
    );
    bytes[inline_start + 12 + 1] = 1;

    bytes[inline_start + 12 + 1] = 2;
    try std.testing.expectError(
        error.InvalidErofs,
        archive.readXattrsAllocLimited(allocator, inline_inode, 8, 1024),
    );
    bytes[inline_start + 12 + 1] = 1;

    const shared_inode = try archive.lookup(allocator, "shared-a", 0, 4096);
    const shared_start = shared_inode.location + shared_inode.inode_size;
    bytes[shared_start + 4] = 2;
    try std.testing.expectError(
        error.InvalidErofs,
        archive.readXattrsAllocLimited(allocator, shared_inode, 8, 1024),
    );
    bytes[shared_start + 4] = 1;
    std.mem.writeInt(u32, bytes[shared_start + 12 ..][0..4], std.math.maxInt(u32), .little);
    try std.testing.expectError(
        error.InvalidErofs,
        archive.readXattrsAllocLimited(allocator, shared_inode, 8, 1024),
    );
}

test "EROFS xattr reader releases every allocation failure" {
    const allocator = std.testing.allocator;
    const bytes = try fixtureAlloc(
        allocator,
        @embedFile("testdata/xattr-inline-shared.erofs.b64"),
    );
    defer allocator.free(bytes);
    const Test = struct {
        fn run(failing_allocator: std.mem.Allocator, image: []const u8) !void {
            const archive = try Archive.init(image);
            const inode_value = try archive.lookup(failing_allocator, "inline", 0, 4096);
            var attributes = try archive.readXattrsAllocLimited(
                failing_allocator,
                inode_value,
                8,
                1024,
            );
            defer attributes.deinit();
            try std.testing.expectEqualStrings(
                "inline-value",
                attributes.find("user.unique").?.value,
            );
        }
    };
    try std.testing.checkAllAllocationFailures(allocator, Test.run, .{bytes});
}

test "EROFS reads erofs-utils long xattr prefixes with bounded ownership" {
    const allocator = std.testing.allocator;
    const bytes = try fixtureAlloc(
        allocator,
        @embedFile("testdata/xattr-long-prefix.erofs.b64"),
    );
    defer allocator.free(bytes);
    const archive = try Archive.init(bytes);
    try std.testing.expectEqual(@as(u8, 1), archive.superblock.xattr_prefix_count);
    try std.testing.expectEqual(@as(u32, 0x120), archive.superblock.xattr_prefix_start);
    try std.testing.expect(
        archive.superblock.feature_incompat & format.feature_incompat_xattr_prefixes != 0,
    );

    const inode_value = try archive.lookup(allocator, "file", 0, 4096);
    var attributes = try archive.readXattrsAllocLimited(
        allocator,
        inode_value,
        2,
        128,
    );
    defer attributes.deinit();
    try std.testing.expectEqual(@as(usize, 2), attributes.entries.len);
    try std.testing.expectEqualStrings(
        "first-value",
        attributes.find("user.vort.long.first").?.value,
    );
    try std.testing.expectEqualStrings(
        "second-value",
        attributes.find("user.vort.long.second").?.value,
    );
    try std.testing.expectError(
        error.OutputLimitExceeded,
        archive.readXattrsAllocLimited(allocator, inode_value, 1, 128),
    );
    try std.testing.expectError(
        error.OutputLimitExceeded,
        archive.readXattrsAllocLimited(allocator, inode_value, 2, 63),
    );
}

test "EROFS rejects malformed long xattr prefix tables and references" {
    const allocator = std.testing.allocator;
    const bytes = try fixtureAlloc(
        allocator,
        @embedFile("testdata/xattr-long-prefix.erofs.b64"),
    );
    defer allocator.free(bytes);

    bytes[0x480] = 0;
    bytes[0x481] = 0;
    refreshFixtureChecksum(bytes);
    try std.testing.expectError(error.InvalidErofs, Archive.init(bytes));
    bytes[0x480] = 11;
    bytes[0x481] = 0;

    bytes[0x482] = 7;
    refreshFixtureChecksum(bytes);
    try std.testing.expectError(error.UnsupportedErofsFeature, Archive.init(bytes));
    bytes[0x482] = 1;

    const compat = format.readU32(bytes, format.super_offset + 8);
    std.mem.writeInt(
        u32,
        bytes[format.super_offset + 8 ..][0..4],
        compat & ~format.feature_compat_plain_xattr_prefixes,
        .little,
    );
    refreshFixtureChecksum(bytes);
    try std.testing.expectError(error.UnsupportedErofsFeature, Archive.init(bytes));
    std.mem.writeInt(u32, bytes[format.super_offset + 8 ..][0..4], compat, .little);
    refreshFixtureChecksum(bytes);

    const archive = try Archive.init(bytes);
    const inode_value = try archive.lookup(allocator, "file", 0, 4096);
    const ibody_start = inode_value.location + inode_value.inode_size;
    bytes[ibody_start + 12 + 1] = 0x81;
    try std.testing.expectError(
        error.InvalidErofs,
        archive.readXattrsAllocLimited(allocator, inode_value, 8, 1024),
    );
}

test "EROFS long xattr prefix reader releases every allocation failure" {
    const allocator = std.testing.allocator;
    const bytes = try fixtureAlloc(
        allocator,
        @embedFile("testdata/xattr-long-prefix.erofs.b64"),
    );
    defer allocator.free(bytes);
    const Test = struct {
        fn run(failing_allocator: std.mem.Allocator, image: []const u8) !void {
            const archive = try Archive.init(image);
            const inode_value = try archive.lookup(failing_allocator, "file", 0, 4096);
            var attributes = try archive.readXattrsAllocLimited(
                failing_allocator,
                inode_value,
                2,
                128,
            );
            defer attributes.deinit();
            try std.testing.expectEqualStrings(
                "second-value",
                attributes.find("user.vort.long.second").?.value,
            );
        }
    };
    try std.testing.checkAllAllocationFailures(allocator, Test.run, .{bytes});
}

test "EROFS reads whole and partial packed fragments with bounded scratch" {
    const allocator = std.testing.allocator;
    const bytes = try fixtureAlloc(
        allocator,
        @embedFile("testdata/fragments-packed.erofs.b64"),
    );
    defer allocator.free(bytes);
    const archive = try Archive.init(bytes);
    try std.testing.expectEqual(@as(u64, 44), archive.superblock.packed_nid);
    try std.testing.expect(
        archive.superblock.feature_incompat & format.feature_incompat_fragments != 0,
    );

    const packed_inode = try archive.inode(archive.superblock.packed_nid);
    try std.testing.expectEqual(format.Layout.compressed_compact, packed_inode.layout);
    try std.testing.expectEqual(@as(usize, 4422), packed_inode.file_size);
    try std.testing.expectEqual(@as(u16, 0x11), packed_inode.compressed_advise);

    const partial_inode = try archive.lookup(allocator, "partial.bin", 8496, 4096);
    try std.testing.expectEqual(@as(?u64, 0), partial_inode.fragment_offset);
    try std.testing.expectEqual(@as(usize, 4096), partial_inode.fragment_logical_start);
    var expected_partial: [8496]u8 = undefined;
    fillFragmentRandom(expected_partial[0..4096]);
    const tail = "PARTIAL-FRAGMENT-TAIL-" ** 200;
    @memcpy(expected_partial[4096..], tail);
    const partial = try archive.readFlatAllocWithLimits(allocator, partial_inode, .{
        .max_output_len = expected_partial.len,
        .max_packed_extent_len = packed_inode.file_size,
    });
    defer allocator.free(partial);
    try std.testing.expectEqualSlices(u8, &expected_partial, partial);

    const whole_inode = try archive.lookup(allocator, "whole.txt", 22, 4096);
    try std.testing.expectEqual(@as(?u64, 4400), whole_inode.fragment_offset);
    try std.testing.expectEqual(@as(usize, 0), whole_inode.fragment_logical_start);
    const whole = try archive.readFlatAllocLimited(allocator, whole_inode, 22);
    defer allocator.free(whole);
    try std.testing.expectEqualStrings("whole packed fragment\n", whole);

    try std.testing.expectError(
        error.OutputLimitExceeded,
        archive.readFlatAllocWithLimits(allocator, whole_inode, .{
            .max_output_len = 22,
            .max_packed_extent_len = packed_inode.file_size - 1,
        }),
    );
}

test "EROFS packed fragments reject missing and out-of-range packed data" {
    const allocator = std.testing.allocator;
    const bytes = try fixtureAlloc(
        allocator,
        @embedFile("testdata/fragments-packed.erofs.b64"),
    );
    defer allocator.free(bytes);

    std.mem.writeInt(u64, bytes[format.super_offset + 96 ..][0..8], 0, .little);
    refreshFixtureChecksum(bytes);
    const missing = try Archive.init(bytes);
    try std.testing.expectError(error.InvalidErofs, missing.lookup(allocator, "whole.txt", 22, 4096));
    std.mem.writeInt(u64, bytes[format.super_offset + 96 ..][0..8], 44, .little);
    refreshFixtureChecksum(bytes);

    const incompat = format.readU32(bytes, format.super_offset + 80);
    std.mem.writeInt(
        u32,
        bytes[format.super_offset + 80 ..][0..4],
        incompat & ~format.feature_incompat_fragments,
        .little,
    );
    refreshFixtureChecksum(bytes);
    try std.testing.expectError(error.InvalidErofs, Archive.init(bytes));
    std.mem.writeInt(u32, bytes[format.super_offset + 80 ..][0..4], incompat, .little);
    refreshFixtureChecksum(bytes);

    const archive = try Archive.init(bytes);
    const whole_entry = blk: {
        var root = try archive.readDirectoryAlloc(allocator, try archive.rootInode(), 4096);
        defer root.deinit();
        break :blk root.find("whole.txt").?;
    };
    const original = try archive.inode(whole_entry.nid);
    const header_start = std.mem.alignForward(
        usize,
        original.location + original.inode_size + original.xattr_size,
        8,
    );
    std.mem.writeInt(
        u64,
        bytes[header_start..][0..8],
        (@as(u64, 1) << 63) | 0x7fff_ffff,
        .little,
    );
    const malformed = try archive.inode(whole_entry.nid);
    try std.testing.expectError(
        error.InvalidErofs,
        archive.readFlatAllocLimited(allocator, malformed, 22),
    );
}

test "EROFS packed fragment reader releases every allocation failure" {
    const allocator = std.testing.allocator;
    const bytes = try fixtureAlloc(
        allocator,
        @embedFile("testdata/fragments-packed.erofs.b64"),
    );
    defer allocator.free(bytes);
    const Test = struct {
        fn run(failing_allocator: std.mem.Allocator, image: []const u8) !void {
            const archive = try Archive.init(image);
            const inode_value = try archive.lookup(
                failing_allocator,
                "partial.bin",
                8496,
                4096,
            );
            const decoded = try archive.readFlatAllocWithLimits(
                failing_allocator,
                inode_value,
                .{ .max_output_len = 8496, .max_packed_extent_len = 4422 },
            );
            defer failing_allocator.free(decoded);
            try std.testing.expectEqualStrings("PARTIAL-FRAGMENT-TAIL-", decoded[4096..4118]);
        }
    };
    try std.testing.checkAllAllocationFailures(allocator, Test.run, .{bytes});
}

test "EROFS decodes compressed inline tail packing" {
    const allocator = std.testing.allocator;
    const bytes = try fixtureAlloc(
        allocator,
        @embedFile("testdata/ztailpacking-lz4.erofs.b64"),
    );
    defer allocator.free(bytes);
    const archive = try Archive.init(bytes);
    try std.testing.expect(
        archive.superblock.feature_incompat & format.feature_incompat_ztailpacking != 0,
    );
    const inode_value = try archive.lookup(allocator, "large", 13_520, 4096);
    try std.testing.expectEqual(@as(usize, 106), inode_value.compressed_inline_size);
    try std.testing.expectEqual(@as(usize, 0), inode_value.compressed_inline_logical_start);
    const decoded = try archive.readFlatAllocLimited(allocator, inode_value, 13_520);
    defer allocator.free(decoded);
    const expected = ("fragment-prefix-0123456789\n" ** 500) ++ "TAIL-FRAGMENT-UNIQUE";
    try std.testing.expectEqualSlices(u8, expected, decoded);

    const incompat = format.readU32(bytes, format.super_offset + 80);
    std.mem.writeInt(
        u32,
        bytes[format.super_offset + 80 ..][0..4],
        incompat & ~format.feature_incompat_ztailpacking,
        .little,
    );
    refreshFixtureChecksum(bytes);
    const missing = try Archive.init(bytes);
    try std.testing.expectError(error.InvalidErofs, missing.lookup(allocator, "large", 13_520, 4096));
    std.mem.writeInt(u32, bytes[format.super_offset + 80 ..][0..4], incompat, .little);
    refreshFixtureChecksum(bytes);

    bytes[inode_value.compressed_header_start + 2] = 0;
    bytes[inode_value.compressed_header_start + 3] = 0;
    try std.testing.expectError(error.InvalidErofs, archive.inode(inode_value.nid));
}

test "EROFS compressed inline tail reader releases every allocation failure" {
    const allocator = std.testing.allocator;
    const bytes = try fixtureAlloc(
        allocator,
        @embedFile("testdata/ztailpacking-lz4.erofs.b64"),
    );
    defer allocator.free(bytes);
    const Test = struct {
        fn run(failing_allocator: std.mem.Allocator, image: []const u8) !void {
            const archive = try Archive.init(image);
            const inode_value = try archive.lookup(failing_allocator, "large", 13_520, 4096);
            const decoded = try archive.readFlatAllocLimited(
                failing_allocator,
                inode_value,
                13_520,
            );
            defer failing_allocator.free(decoded);
            try std.testing.expectEqualStrings("TAIL-FRAGMENT-UNIQUE", decoded[13_500..]);
        }
    };
    try std.testing.checkAllAllocationFailures(allocator, Test.run, .{bytes});
}

fn refreshFixtureChecksum(bytes: []u8) void {
    const base = format.super_offset;
    const block_size: usize = @as(usize, 1) << @intCast(bytes[base + 12]);
    const checksum = format.computeSuperblockChecksum(bytes[base..block_size]);
    std.mem.writeInt(u32, bytes[base + 4 ..][0..4], checksum, .little);
}

fn fillFragmentRandom(output: []u8) void {
    var state: u32 = 0x1234_5678;
    for (output) |*byte| {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        byte.* = @truncate(state);
    }
}
