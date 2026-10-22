const std = @import("std");
const writer = @import("../../writer.zig");
const format = @import("../../format.zig");
const writer_codec = @import("../codec.zig");
const block_size: usize = 4096;
const encodeAlloc = writer.encodeAlloc;
const Entry = writer.Entry;
const Compression = writer.Compression;
const Xattr = writer.Xattr;

fn fillPseudoRandom(output: []u8) void {
    var state: u32 = 0x1234_5678;
    for (output) |*byte| {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        byte.* = @truncate(state);
    }
}

test "EROFS writer round trips stored trees deterministically" {
    const archive = @import("../../archive.zig");
    const allocator = std.testing.allocator;
    var random: [8193]u8 = undefined;
    fillPseudoRandom(&random);
    const repeated = "EROFS writer repeated payload 0123456789\n" ** 300;
    const entries = [_]Entry{
        .{ .path = "small.txt", .data = "small payload\n", .modification_time = 11 },
        .{ .path = "nested", .kind = .directory, .mode = 0o750 },
        .{ .path = "nested/large.bin", .data = repeated },
        .{ .path = "nested/random.bin", .data = &random },
        .{ .path = "nested/link", .kind = .symlink, .target = "../small.txt" },
        .{ .path = "empty", .kind = .directory },
    };
    const first = try encodeAlloc(allocator, &entries, .{ .volume_name = "stored-test" });
    defer allocator.free(first);
    const second = try encodeAlloc(allocator, &entries, .{ .volume_name = "stored-test" });
    defer allocator.free(second);
    try std.testing.expectEqualSlices(u8, first, second);

    const parsed = try archive.Archive.init(first);
    try std.testing.expectEqual(@as(usize, block_size), parsed.superblock.block_size);
    try std.testing.expectEqual(@as(u64, entries.len + 1), parsed.superblock.inode_count);
    var root = try parsed.readDirectoryAlloc(allocator, try parsed.rootInode(), block_size);
    defer root.deinit();
    try std.testing.expectEqual(@as(usize, 3), root.entries.len);
    try std.testing.expect(root.find("empty") != null);
    try std.testing.expect(root.find("nested") != null);
    try std.testing.expect(root.find("small.txt") != null);

    const small = try parsed.extractByPathAllocLimited(
        allocator,
        "small.txt",
        128,
        block_size,
    );
    defer allocator.free(small);
    try std.testing.expectEqualStrings("small payload\n", small);
    const small_inode = try parsed.lookup(allocator, "small.txt", 128, block_size);
    try std.testing.expectEqual(@as(u64, 11), small_inode.modification_time);

    const large = try parsed.extractByPathAllocLimited(
        allocator,
        "nested/large.bin",
        repeated.len,
        block_size,
    );
    defer allocator.free(large);
    try std.testing.expectEqualSlices(u8, repeated, large);
    const random_decoded = try parsed.extractByPathAllocLimited(
        allocator,
        "nested/random.bin",
        random.len,
        block_size,
    );
    defer allocator.free(random_decoded);
    try std.testing.expectEqualSlices(u8, &random, random_decoded);
    const link = try parsed.extractByPathAllocLimited(
        allocator,
        "nested/link",
        128,
        block_size,
    );
    defer allocator.free(link);
    try std.testing.expectEqualStrings("../small.txt", link);
}

test "EROFS writer codecs use compressed and plain full indexes" {
    const archive = @import("../../archive.zig");
    const allocator = std.testing.allocator;
    var random: [8193]u8 = undefined;
    fillPseudoRandom(&random);
    const repeated = "compress this EROFS logical cluster\n" ** 400;
    const entries = [_]Entry{
        .{ .path = "repeat.bin", .data = repeated },
        .{ .path = "random.bin", .data = &random },
        .{ .path = "tiny.txt", .data = "tiny" },
    };
    inline for (.{ Compression.lz4, .lzma, .deflate, .zstandard }) |compression| {
        const encoded = try encodeAlloc(allocator, &entries, .{
            .compression = compression,
            .volume_name = "codec-test",
        });
        defer allocator.free(encoded);
        const parsed = try archive.Archive.init(encoded);
        try std.testing.expectEqual(
            writer_codec.featureIncompat(compression),
            parsed.superblock.feature_incompat,
        );
        try std.testing.expectEqual(
            writer_codec.compressionField(compression),
            parsed.superblock.available_compression_algorithms,
        );

        const repeated_inode = try parsed.lookup(allocator, "repeat.bin", repeated.len, block_size);
        try std.testing.expectEqual(format.Layout.compressed_full, repeated_inode.layout);
        try std.testing.expectEqual(writer_codec.algorithm(compression).?, repeated_inode.compressed_algorithms[0].?);
        try std.testing.expectEqual(
            @as(u16, 1),
            format.readU16(encoded, repeated_inode.compressed_index_start) & 3,
        );
        const repeated_decoded = try parsed.extractByPathAllocLimited(
            allocator,
            "repeat.bin",
            repeated.len,
            block_size,
        );
        defer allocator.free(repeated_decoded);
        try std.testing.expectEqualSlices(u8, repeated, repeated_decoded);

        const random_inode = try parsed.lookup(allocator, "random.bin", random.len, block_size);
        try std.testing.expectEqual(format.Layout.compressed_full, random_inode.layout);
        try std.testing.expectEqual(
            @as(u16, 0),
            format.readU16(encoded, random_inode.compressed_index_start) & 3,
        );
        const random_decoded = try parsed.extractByPathAllocLimited(
            allocator,
            "random.bin",
            random.len,
            block_size,
        );
        defer allocator.free(random_decoded);
        try std.testing.expectEqualSlices(u8, &random, random_decoded);

        const tiny = try parsed.extractByPathAllocLimited(
            allocator,
            "tiny.txt",
            4,
            block_size,
        );
        defer allocator.free(tiny);
        try std.testing.expectEqualStrings("tiny", tiny);
    }
}

test "EROFS writer rejects unsafe and duplicate paths" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(
        error.InvalidErofs,
        encodeAlloc(allocator, &.{.{ .path = "/absolute" }}, .{}),
    );
    try std.testing.expectError(
        error.InvalidErofs,
        encodeAlloc(allocator, &.{.{ .path = "a/../b" }}, .{}),
    );
    try std.testing.expectError(
        error.InvalidErofs,
        encodeAlloc(allocator, &.{ .{ .path = "same" }, .{ .path = "same" } }, .{}),
    );
    try std.testing.expectError(
        error.InvalidErofs,
        encodeAlloc(allocator, &.{ .{ .path = "parent" }, .{ .path = "parent/child" } }, .{}),
    );
}

test "EROFS writer emits an empty root filesystem" {
    const archive = @import("../../archive.zig");
    const allocator = std.testing.allocator;
    const encoded = try encodeAlloc(allocator, &.{}, .{});
    defer allocator.free(encoded);
    try std.testing.expectEqual(@as(usize, block_size), encoded.len);
    const parsed = try archive.Archive.init(encoded);
    var root = try parsed.readDirectoryAlloc(allocator, try parsed.rootInode(), block_size);
    defer root.deinit();
    try std.testing.expectEqual(@as(usize, 0), root.entries.len);
}

test "EROFS writer packs multi-block directories" {
    const archive = @import("../../archive.zig");
    const allocator = std.testing.allocator;
    var entries: std.ArrayList(Entry) = .empty;
    defer entries.deinit(allocator);
    var paths: std.ArrayList([]u8) = .empty;
    defer {
        for (paths.items) |path| allocator.free(path);
        paths.deinit(allocator);
    }
    for (0..400) |index| {
        const path = try std.fmt.allocPrint(allocator, "wide/item-{d:0>3}", .{index});
        try paths.append(allocator, path);
        try entries.append(allocator, .{ .path = path });
    }
    const encoded = try encodeAlloc(allocator, entries.items, .{});
    defer allocator.free(encoded);
    const parsed = try archive.Archive.init(encoded);
    const wide_inode = try parsed.lookup(allocator, "wide", 0, 16 * 1024);
    var wide = try parsed.readDirectoryAlloc(allocator, wide_inode, 16 * 1024);
    defer wide.deinit();
    try std.testing.expectEqual(@as(usize, 400), wide.entries.len);
    try std.testing.expectEqualStrings("item-000", wide.entries[0].name);
    try std.testing.expectEqualStrings("item-399", wide.entries[399].name);
    const last = try parsed.extractByPathAllocLimited(
        allocator,
        "wide/item-399",
        0,
        16 * 1024,
    );
    defer allocator.free(last);
    try std.testing.expectEqual(@as(usize, 0), last.len);
}

test "EROFS writer round trips root file directory and symlink xattrs" {
    const archive = @import("../../archive.zig");
    const allocator = std.testing.allocator;
    const file_xattrs = [_]Xattr{
        .{ .name = "user.author", .value = "vort" },
        .{ .name = "user.empty", .value = &.{} },
        .{ .name = "security.selinux", .value = "u:object_r:system_file:s0" },
        .{ .name = "trusted.vort", .value = "trusted" },
        .{ .name = "lustre.vort", .value = "lustre" },
        .{ .name = "system.posix_acl_access", .value = &.{ 1, 2 } },
        .{ .name = "system.posix_acl_default", .value = &.{ 3, 4 } },
        .{ .name = "system.vort", .value = &.{ 0, 1, 2, 3 } },
    };
    const root_xattrs = [_]Xattr{.{ .name = "user.root", .value = "root-value" }};
    const entries = [_]Entry{
        .{ .path = "small", .data = "inline payload", .xattrs = &file_xattrs },
        .{ .path = "dir", .kind = .directory, .xattrs = &.{.{ .name = "user.dir", .value = "d" }} },
        .{ .path = "link", .kind = .symlink, .target = "small", .xattrs = &.{.{ .name = "user.link", .value = "l" }} },
    };

    inline for (.{ Compression.stored, .lz4, .lzma, .deflate, .zstandard }) |compression| {
        const encoded = try encodeAlloc(allocator, &entries, .{
            .compression = compression,
            .root_xattrs = &root_xattrs,
        });
        defer allocator.free(encoded);
        const parsed = try archive.Archive.init(encoded);

        const root_inode = try parsed.rootInode();
        var root_attributes = try parsed.readXattrsAllocLimited(allocator, root_inode, 4, 128);
        defer root_attributes.deinit();
        try std.testing.expectEqualStrings(
            "root-value",
            root_attributes.find("user.root").?.value,
        );

        const small_inode = try parsed.lookup(allocator, "small", 32, block_size);
        var small_attributes = try parsed.readXattrsAllocLimited(allocator, small_inode, 8, 512);
        defer small_attributes.deinit();
        try std.testing.expectEqual(@as(usize, 8), small_attributes.entries.len);
        try std.testing.expectEqualStrings("vort", small_attributes.find("user.author").?.value);
        try std.testing.expectEqual(@as(usize, 0), small_attributes.find("user.empty").?.value.len);
        try std.testing.expectEqualStrings(
            "u:object_r:system_file:s0",
            small_attributes.find("security.selinux").?.value,
        );
        try std.testing.expectEqualStrings("trusted", small_attributes.find("trusted.vort").?.value);
        try std.testing.expectEqualStrings("lustre", small_attributes.find("lustre.vort").?.value);
        try std.testing.expectEqualSlices(
            u8,
            &.{ 1, 2 },
            small_attributes.find("system.posix_acl_access").?.value,
        );
        try std.testing.expectEqualSlices(
            u8,
            &.{ 3, 4 },
            small_attributes.find("system.posix_acl_default").?.value,
        );
        try std.testing.expectEqualSlices(
            u8,
            &.{ 0, 1, 2, 3 },
            small_attributes.find("system.vort").?.value,
        );
        const decoded = try parsed.readFlatAllocLimited(allocator, small_inode, 32);
        defer allocator.free(decoded);
        try std.testing.expectEqualStrings("inline payload", decoded);

        const directory_inode = try parsed.lookup(allocator, "dir", 0, block_size);
        var directory_attributes = try parsed.readXattrsAllocLimited(allocator, directory_inode, 1, 32);
        defer directory_attributes.deinit();
        try std.testing.expectEqualStrings("d", directory_attributes.find("user.dir").?.value);

        const link_inode = try parsed.lookup(allocator, "link", 32, block_size);
        var link_attributes = try parsed.readXattrsAllocLimited(allocator, link_inode, 1, 32);
        defer link_attributes.deinit();
        try std.testing.expectEqualStrings("l", link_attributes.find("user.link").?.value);
    }
}

test "EROFS writer rejects invalid duplicate and oversized xattrs" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(
        error.InvalidErofs,
        encodeAlloc(allocator, &.{.{
            .path = "empty-name",
            .xattrs = &.{.{ .name = "", .value = "x" }},
        }}, .{}),
    );
    try std.testing.expectError(
        error.InvalidErofs,
        encodeAlloc(allocator, &.{.{
            .path = "duplicate",
            .xattrs = &.{
                .{ .name = "user.same", .value = "a" },
                .{ .name = "user.same", .value = "b" },
            },
        }}, .{}),
    );
    try std.testing.expectError(
        error.InvalidErofs,
        encodeAlloc(allocator, &.{.{
            .path = "empty-suffix",
            .xattrs = &.{.{ .name = "user.", .value = "x" }},
        }}, .{}),
    );
    var oversized: [std.math.maxInt(u16) + 1]u8 = @splat(0);
    try std.testing.expectError(
        error.InvalidErofs,
        encodeAlloc(allocator, &.{.{
            .path = "oversized",
            .xattrs = &.{.{ .name = "user.large", .value = &oversized }},
        }}, .{}),
    );

    const duplicate_prefixes = [_][]const u8{ "user.vort.", "user.vort." };
    try std.testing.expectError(
        error.InvalidErofs,
        encodeAlloc(allocator, &.{}, .{ .xattr_prefixes = &duplicate_prefixes }),
    );
    const nul_prefixes = [_][]const u8{"user.vort\x00bad"};
    try std.testing.expectError(
        error.InvalidErofs,
        encodeAlloc(allocator, &.{}, .{ .xattr_prefixes = &nul_prefixes }),
    );
    var oversized_prefix: [format.name_max + 1]u8 = @splat('a');
    try std.testing.expectError(
        error.InvalidErofs,
        encodeAlloc(allocator, &.{}, .{ .xattr_prefixes = &.{&oversized_prefix} }),
    );
    const too_many_prefixes: [0x81][]const u8 = @splat("user.vort.");
    try std.testing.expectError(
        error.InvalidErofs,
        encodeAlloc(allocator, &.{}, .{ .xattr_prefixes = &too_many_prefixes }),
    );
}

test "EROFS writer emits plain long xattr prefix tables for every codec" {
    const archive = @import("../../archive.zig");
    const allocator = std.testing.allocator;
    const prefixes = [_][]const u8{
        "user.vort.long.",
        "security.vort.",
        "system.vort.",
    };
    const attributes = [_]Xattr{
        .{ .name = "user.vort.long.alpha", .value = "alpha-value" },
        .{ .name = "security.vort.label", .value = "security-value" },
        .{ .name = "system.vort.hidden", .value = "generic-value" },
        .{ .name = "user.short", .value = "short-value" },
    };
    const entries = [_]Entry{.{
        .path = "file",
        .data = "long-prefix payload",
        .xattrs = &attributes,
    }};

    inline for (.{ Compression.stored, .lz4, .lzma, .deflate, .zstandard }) |compression| {
        const encoded = try encodeAlloc(allocator, &entries, .{
            .compression = compression,
            .xattr_prefixes = &prefixes,
        });
        defer allocator.free(encoded);
        const parsed = try archive.Archive.init(encoded);
        try std.testing.expectEqual(@as(u8, prefixes.len), parsed.superblock.xattr_prefix_count);
        try std.testing.expect(
            parsed.superblock.feature_compat & format.feature_compat_plain_xattr_prefixes != 0,
        );
        try std.testing.expect(
            parsed.superblock.feature_incompat & format.feature_incompat_xattr_prefixes != 0,
        );

        const inode_value = try parsed.lookup(allocator, "file", 64, block_size);
        const ibody_start = inode_value.location + inode_value.inode_size;
        try std.testing.expectEqual(@as(u8, 0x80), encoded[ibody_start + 13]);
        var decoded = try parsed.readXattrsAllocLimited(allocator, inode_value, 4, 512);
        defer decoded.deinit();
        try std.testing.expectEqualStrings(
            "alpha-value",
            decoded.find("user.vort.long.alpha").?.value,
        );
        try std.testing.expectEqualStrings(
            "security-value",
            decoded.find("security.vort.label").?.value,
        );
        try std.testing.expectEqualStrings(
            "generic-value",
            decoded.find("system.vort.hidden").?.value,
        );
        try std.testing.expectEqualStrings(
            "short-value",
            decoded.find("user.short").?.value,
        );
        const payload = try parsed.readFlatAllocLimited(allocator, inode_value, 64);
        defer allocator.free(payload);
        try std.testing.expectEqualStrings("long-prefix payload", payload);
    }
}

test "EROFS xattr writer releases every allocation failure" {
    const allocator = std.testing.allocator;
    const Test = struct {
        fn run(failing_allocator: std.mem.Allocator) !void {
            const encoded = try encodeAlloc(failing_allocator, &.{.{
                .path = "file",
                .data = "payload",
                .xattrs = &.{.{ .name = "user.test", .value = "value" }},
            }}, .{
                .root_xattrs = &.{.{ .name = "user.root", .value = "root" }},
                .xattr_prefixes = &.{"user."},
            });
            defer failing_allocator.free(encoded);
            const parsed = try @import("../../archive.zig").Archive.init(encoded);
            const inode_value = try parsed.lookup(failing_allocator, "file", 32, block_size);
            var attributes = try parsed.readXattrsAllocLimited(
                failing_allocator,
                inode_value,
                4,
                64,
            );
            defer attributes.deinit();
            try std.testing.expectEqualStrings("value", attributes.find("user.test").?.value);
        }
    };
    try std.testing.checkAllAllocationFailures(allocator, Test.run, .{});
}
