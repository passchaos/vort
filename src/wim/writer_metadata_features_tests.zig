const std = @import("std");
const archive_mod = @import("archive.zig");
const format = @import("format.zig");
const metadata = @import("metadata.zig");
const writer = @import("writer.zig");

const limits: archive_mod.PathLimits = .{
    .max_metadata_bytes = 1024 * 1024,
    .max_solid_chunk_bytes = 1024 * 1024,
    .max_lookup_entries = 128,
    .max_lookup_bytes = 128 * format.lookup_entry_size,
    .max_directory_entries = 128,
    .max_path_depth = 16,
};

test "WIM writer round trips short names and generic tagged metadata" {
    const allocator = std.testing.allocator;
    const object_id = writer.encodeObjectId(.{
        .object_id = .{
            0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
            0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f,
        },
        .birth_volume_id = @splat(0x55),
        .birth_object_id = @splat(0x55),
        .domain_id = @splat(0x55),
    });
    const unix_data = writer.encodeUnixMetadata(.{
        .uid = 1000,
        .gid = 1001,
        .mode = 0o100640,
        .rdev = 7,
    });
    const xattr_bytes = try writer.encodeXattrsAlloc(allocator, &.{
        .{ .name = "user.vort", .value = "xattr-value" },
        .{ .name = "user.empty", .value = &.{}, .need_ea = true },
    });
    defer allocator.free(xattr_bytes);
    const root_tags = [_]writer.TaggedItem{.{
        .tag = 0xaabb_ccdd,
        .data = "root-tag",
    }};
    const directory_tags = [_]writer.TaggedItem{.{
        .tag = metadata.tagged_item_wimlib_unix_data,
        .data = &unix_data,
    }};
    const file_tags = [_]writer.TaggedItem{
        .{ .tag = metadata.tagged_item_object_id, .data = &object_id },
        .{ .tag = metadata.tagged_item_wimlib_unix_data, .data = &unix_data },
        .{ .tag = metadata.tagged_item_xattrs, .data = xattr_bytes },
        .{ .tag = 0x1020_3040, .data = "opaque tagged bytes" },
        .{ .tag = 0x5060_7080, .data = &.{} },
    };
    const payload = "short-name path payload\n";
    const entries = [_]writer.Entry{
        .{
            .path = "Program Files",
            .kind = .directory,
            .short_name = "PROGRA~1",
            .tagged_items = &directory_tags,
        },
        .{
            .path = "Program Files/readme-long-name.txt",
            .data = payload,
            .short_name = "README~1.TXT",
            .tagged_items = &file_tags,
        },
    };
    const encoded = try writer.encodeAlloc(allocator, &entries, .{
        .compression = .stored,
        .root_tagged_items = &root_tags,
    });
    defer allocator.free(encoded);
    const repeated = try writer.encodeAlloc(allocator, &entries, .{
        .compression = .stored,
        .root_tagged_items = &root_tags,
    });
    defer allocator.free(repeated);
    try std.testing.expectEqualSlices(u8, encoded, repeated);

    const archive = try archive_mod.Archive.init(encoded);
    var image = try archive.readImageMetadataAlloc(allocator, 1, limits);
    defer image.deinit();
    const root_item = (try image.root.findTaggedItem(0xaabb_ccdd, 0)).?;
    try std.testing.expectEqualStrings("root-tag", root_item.data);

    const directory = try image.lookup(
        allocator,
        "/PROGRA~1",
        128,
        16,
    );
    const directory_short = try directory.shortNameUtf8Alloc(allocator);
    defer allocator.free(directory_short);
    try std.testing.expectEqualStrings("PROGRA~1", directory_short);
    const directory_unix = (try directory.unixMetadata()).?;
    try std.testing.expectEqual(@as(u32, 1000), directory_unix.uid);
    try std.testing.expectEqual(@as(u32, 0o100640), directory_unix.mode);

    const file = try image.lookup(
        allocator,
        "/PROGRA~1/README~1.TXT",
        128,
        16,
    );
    const short_name = try file.shortNameUtf8Alloc(allocator);
    defer allocator.free(short_name);
    try std.testing.expectEqualStrings("README~1.TXT", short_name);
    try std.testing.expectEqualSlices(u8, &object_id, (try file.objectId()).?);
    const object_info = (try file.objectIdInfo()).?;
    try std.testing.expectEqualSlices(u8, object_id[0..16], &object_info.object_id);
    const unix = (try file.unixMetadata()).?;
    try std.testing.expectEqual(@as(u32, 1000), unix.uid);
    try std.testing.expectEqual(@as(u32, 1001), unix.gid);
    try std.testing.expectEqual(@as(u32, 0o100640), unix.mode);
    try std.testing.expectEqual(@as(u32, 7), unix.rdev);
    try std.testing.expectEqualStrings(
        "opaque tagged bytes",
        (try file.findTaggedItem(0x1020_3040, 1)).?.data,
    );
    try std.testing.expectEqual(@as(usize, 0), (try file.findTaggedItem(
        0x5060_7080,
        0,
    )).?.data.len);
    var xattrs = (try file.xattrs()).?;
    const first_xattr = (try xattrs.next()).?;
    try std.testing.expectEqualStrings("user.vort", first_xattr.name);
    try std.testing.expectEqualStrings("xattr-value", first_xattr.value);
    const second_xattr = (try xattrs.next()).?;
    try std.testing.expectEqualStrings("user.empty", second_xattr.name);
    try std.testing.expectEqual(@as(usize, 0), second_xattr.value.len);
    try std.testing.expect(second_xattr.need_ea);
    try std.testing.expect((try xattrs.next()) == null);
    var item_count: usize = 0;
    var items = file.taggedItems();
    while (try items.next()) |_| item_count += 1;
    try std.testing.expectEqual(@as(usize, 5), item_count);

    const extracted = try archive.extractByPathAllocLimited(
        allocator,
        1,
        "/PROGRA~1/README~1.TXT",
        payload.len,
        limits,
    );
    defer allocator.free(extracted);
    try std.testing.expectEqualStrings(payload, extracted);
}

test "WIM solid writer preserves short names and tagged items" {
    const allocator = std.testing.allocator;
    const tags = [_]writer.TaggedItem{.{
        .tag = 0xdead_beef,
        .data = "solid-tag",
    }};
    const entries = [_]writer.Entry{.{
        .path = "long-solid-name.bin",
        .short_name = "SOLIDN~1.BIN",
        .tagged_items = &tags,
        .data = "solid short-name payload" ** 64,
    }};
    const encoded = try writer.encodeSolidAlloc(allocator, &entries, .{
        .metadata_chunk_size = 32 * 1024,
        .solid_chunk_size = 32 * 1024,
    });
    defer allocator.free(encoded);
    const archive = try archive_mod.Archive.init(encoded);
    var image = try archive.readImageMetadataAlloc(allocator, 1, limits);
    defer image.deinit();
    const dentry = try image.lookup(allocator, "SOLIDN~1.BIN", 16, 8);
    try std.testing.expectEqualStrings(
        "solid-tag",
        (try dentry.findTaggedItem(0xdead_beef, 0)).?.data,
    );
    const extracted = try archive.extractByPathAllocLimited(
        allocator,
        1,
        "SOLIDN~1.BIN",
        ("solid short-name payload" ** 64).len,
        limits,
    );
    defer allocator.free(extracted);
    try std.testing.expectEqualStrings("solid short-name payload" ** 64, extracted);
}

test "WIM writer validates short-name aliases and hard-link tagged metadata" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(
        error.InvalidWimEntry,
        writer.encodeAlloc(allocator, &.{.{
            .path = "file",
            .short_name = "ABCDEFGHIJKLM",
        }}, .{}),
    );
    try std.testing.expectError(
        error.InvalidWimEntry,
        writer.encodeAlloc(allocator, &.{.{
            .path = "file",
            .short_name = "BAD/NAME",
        }}, .{}),
    );
    try std.testing.expectError(
        error.InvalidWimEntry,
        writer.encodeXattrsAlloc(allocator, &.{.{
            .name = "",
            .value = "invalid",
        }}),
    );
    const conflicting_long = [_]writer.Entry{
        .{ .path = "FIRST~1.TXT" },
        .{ .path = "second.txt", .short_name = "first~1.txt" },
    };
    try std.testing.expectError(
        error.InvalidWimEntry,
        writer.encodeAlloc(allocator, &conflicting_long, .{}),
    );
    const conflicting_short = [_]writer.Entry{
        .{ .path = "first.txt", .short_name = "SHARED~1" },
        .{ .path = "second.txt", .short_name = "shared~1" },
    };
    try std.testing.expectError(
        error.InvalidWimEntry,
        writer.encodeAlloc(allocator, &conflicting_short, .{}),
    );

    const first_tags = [_]writer.TaggedItem{.{ .tag = 1, .data = "first" }};
    const second_tags = [_]writer.TaggedItem{.{ .tag = 1, .data = "second" }};
    const mismatched_links = [_]writer.Entry{
        .{
            .path = "one-long-name",
            .short_name = "ONE~1",
            .data = "linked",
            .tagged_items = &first_tags,
            .hard_link_id = 1,
        },
        .{
            .path = "two-long-name",
            .short_name = "TWO~1",
            .data = "linked",
            .tagged_items = &second_tags,
            .hard_link_id = 1,
        },
    };
    try std.testing.expectError(
        error.InvalidWimEntry,
        writer.encodeAlloc(allocator, &mismatched_links, .{}),
    );
    var matching_links = mismatched_links;
    matching_links[1].tagged_items = &first_tags;
    const encoded = try writer.encodeAlloc(allocator, &matching_links, .{});
    defer allocator.free(encoded);
    _ = try archive_mod.Archive.init(encoded);
}

test "WIM metadata rejects truncated tagged items" {
    const allocator = std.testing.allocator;
    const tags = [_]writer.TaggedItem{.{ .tag = 7, .data = "tag-data" }};
    const source = try writer.encodeAlloc(allocator, &.{.{
        .path = "tagged",
        .tagged_items = &tags,
    }}, .{
        .compression = .stored,
        .integrity = false,
    });
    defer allocator.free(source);
    const archive = try archive_mod.Archive.init(source);
    var image = try archive.readImageMetadataAlloc(allocator, 1, limits);
    defer image.deinit();
    const dentry = try image.lookup(allocator, "tagged", 8, 8);
    const tagged_offset = dentry.tagged_items_offset;
    const corrupted_bytes = try allocator.dupe(u8, image.bytes);
    std.mem.writeInt(
        u32,
        corrupted_bytes[tagged_offset + 4 ..][0..4],
        std.math.maxInt(u32),
        .little,
    );
    var corrupted = try metadata.ImageMetadata.fromOwnedBytes(
        allocator,
        corrupted_bytes,
    );
    defer corrupted.deinit();
    try std.testing.expectError(
        error.InvalidWimMetadata,
        corrupted.readDirectoryAlloc(allocator, corrupted.root, 8),
    );
}

test "WIM metadata rejects malformed typed xattrs" {
    const allocator = std.testing.allocator;
    const xattr_bytes = try writer.encodeXattrsAlloc(allocator, &.{.{
        .name = "user.invalid",
        .value = "value",
    }});
    defer allocator.free(xattr_bytes);
    const tags = [_]writer.TaggedItem{.{
        .tag = metadata.tagged_item_xattrs,
        .data = xattr_bytes,
    }};
    const source = try writer.encodeAlloc(allocator, &.{.{
        .path = "tagged",
        .tagged_items = &tags,
    }}, .{
        .compression = .stored,
        .integrity = false,
    });
    defer allocator.free(source);
    const archive = try archive_mod.Archive.init(source);
    var image = try archive.readImageMetadataAlloc(allocator, 1, limits);
    defer image.deinit();
    const dentry = try image.lookup(allocator, "tagged", 8, 8);
    const item = (try dentry.findTaggedItem(metadata.tagged_item_xattrs, 0)).?;
    const data_offset = @intFromPtr(item.data.ptr) - @intFromPtr(image.bytes.ptr);
    const corrupted_bytes = try allocator.dupe(u8, image.bytes);
    corrupted_bytes[data_offset + 3] = 1;
    var corrupted = try metadata.ImageMetadata.fromOwnedBytes(
        allocator,
        corrupted_bytes,
    );
    defer corrupted.deinit();
    const corrupted_dentry = try corrupted.lookup(allocator, "tagged", 8, 8);
    try std.testing.expectError(
        error.InvalidWimMetadata,
        corrupted_dentry.xattrs(),
    );
}

test "WIM short-name and tagged metadata writing is allocation failure safe" {
    const AllocationTest = struct {
        fn run(allocator: std.mem.Allocator) !void {
            const unix_data = writer.encodeUnixMetadata(.{
                .uid = 42,
                .gid = 43,
                .mode = 0o100600,
                .rdev = 0,
            });
            const xattr_bytes = try writer.encodeXattrsAlloc(allocator, &.{.{
                .name = "user.oom",
                .value = "xattr OOM value",
            }});
            defer allocator.free(xattr_bytes);
            const tags = [_]writer.TaggedItem{
                .{
                    .tag = metadata.tagged_item_wimlib_unix_data,
                    .data = &unix_data,
                },
                .{ .tag = metadata.tagged_item_xattrs, .data = xattr_bytes },
                .{ .tag = 0x1234_5678, .data = "opaque" },
            };
            const entries = [_]writer.Entry{.{
                .path = "long-file-name.txt",
                .short_name = "LONGFI~1.TXT",
                .tagged_items = &tags,
                .data = "OOM payload",
            }};
            const encoded = try writer.encodeAlloc(allocator, &entries, .{
                .compression = .xpress,
                .root_tagged_items = tags[1..],
            });
            defer allocator.free(encoded);
            const archive = try archive_mod.Archive.init(encoded);
            var image = try archive.readImageMetadataAlloc(allocator, 1, limits);
            defer image.deinit();
            const dentry = try image.lookup(allocator, "LONGFI~1.TXT", 8, 8);
            try std.testing.expectEqual(@as(u32, 42), (try dentry.unixMetadata()).?.uid);
            var xattrs = (try dentry.xattrs()).?;
            try std.testing.expectEqualStrings("user.oom", (try xattrs.next()).?.name);
        }
    };
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        AllocationTest.run,
        .{},
    );
}
