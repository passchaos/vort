const std = @import("std");
const archive_mod = @import("archive.zig");
const format = @import("format.zig");
const writer = @import("writer.zig");

const limits: archive_mod.PathLimits = .{
    .max_metadata_bytes = 1024 * 1024,
    .max_lookup_entries = 128,
    .max_lookup_bytes = 128 * format.lookup_entry_size,
    .max_directory_entries = 128,
    .max_path_depth = 16,
};

test "WIM image replacement preserves index, boot identity and exact references" {
    const allocator = std.testing.allocator;
    const shared = "replacement shared payload\n" ** 64;
    const old_unique = "old target payload\n" ** 32;
    const replacement_unique = "new target payload\n" ** 32;
    const first_entries = [_]writer.Entry{
        .{ .path = "first.txt", .data = "first remains\n" },
        .{ .path = "shared.bin", .data = shared },
    };
    const target_entries = [_]writer.Entry{
        .{ .path = "old.txt", .data = old_unique },
        .{ .path = "shared.bin", .data = shared },
    };
    const third_entries = [_]writer.Entry{
        .{ .path = "third.txt", .data = "third remains\n" },
        .{ .path = "shared.bin", .data = shared },
    };
    const images = [_]writer.Image{
        .{ .name = "first", .entries = &first_entries },
        .{ .name = "target", .entries = &target_entries },
        .{ .name = "third", .entries = &third_entries },
    };
    const source = try writer.encodeImagesAlloc(allocator, &images, .{
        .compression = .xpress,
        .boot_index = 2,
    });
    defer allocator.free(source);
    const replacement_entries = [_]writer.Entry{
        .{ .path = "new.txt", .data = replacement_unique },
        .{ .path = "shared.bin", .data = shared },
    };
    const replacement: writer.Image = .{
        .name = "target",
        .entries = &replacement_entries,
        .creation_time = 123,
        .last_modification_time = 456,
    };
    const updated = try writer.replaceImageAlloc(
        allocator,
        source,
        2,
        replacement,
        .{},
    );
    defer allocator.free(updated);
    const repeated = try writer.replaceImageAlloc(
        allocator,
        source,
        2,
        replacement,
        .{},
    );
    defer allocator.free(repeated);
    try std.testing.expectEqualSlices(u8, updated, repeated);
    const source_archive = try archive_mod.Archive.init(source);
    var source_lookup = try source_archive.readLookupTableRawAlloc(
        allocator,
        128,
        8192,
    );
    defer source_lookup.deinit();
    const bounded = try writer.replaceImageAlloc(
        allocator,
        source,
        2,
        replacement,
        .{
            .max_lookup_entries = source_lookup.entries.len,
            .max_lookup_bytes = source_lookup.entries.len * format.lookup_entry_size,
        },
    );
    defer allocator.free(bounded);
    try std.testing.expectEqualSlices(u8, updated, bounded);
    try std.testing.expectEqualSlices(
        u8,
        source[format.header_size..],
        updated[format.header_size..source.len],
    );

    const archive = try archive_mod.Archive.init(updated);
    try std.testing.expectEqual(@as(u32, 3), archive.header.image_count);
    try std.testing.expectEqual(@as(u32, 2), archive.header.boot_index);
    var lookup = try archive.readLookupTableAlloc(allocator, 128, 8192);
    defer lookup.deinit();
    try expectBootMatchesMetadata(archive.header, lookup.entries);

    var shared_hash: [20]u8 = undefined;
    std.crypto.hash.Sha1.hash(shared, &shared_hash, .{});
    try std.testing.expectEqual(
        @as(u32, 3),
        lookup.findData(&shared_hash).?.reference_count,
    );
    var old_hash: [20]u8 = undefined;
    std.crypto.hash.Sha1.hash(old_unique, &old_hash, .{});
    try std.testing.expect(lookup.findData(&old_hash) == null);
    var new_hash: [20]u8 = undefined;
    std.crypto.hash.Sha1.hash(replacement_unique, &new_hash, .{});
    try std.testing.expectEqual(
        @as(u32, 1),
        lookup.findData(&new_hash).?.reference_count,
    );

    try expectPath(allocator, archive, 1, "first.txt", "first remains\n");
    try expectPath(allocator, archive, 2, "new.txt", replacement_unique);
    try expectPath(allocator, archive, 2, "shared.bin", shared);
    try expectPath(allocator, archive, 3, "third.txt", "third remains\n");
    try std.testing.expectError(
        error.WimPathNotFound,
        archive.extractByPathAllocLimited(
            allocator,
            2,
            "old.txt",
            old_unique.len,
            limits,
        ),
    );
    const xml = try archive.readXmlAllocLimited(allocator, 64 * 1024);
    defer allocator.free(xml);
    try std.testing.expectEqual(@as(usize, 1), countUtf16Ascii(xml, "<NAME>target</NAME>"));
    try std.testing.expect(utf16ContainsAscii(xml, "IMAGE INDEX=\"2\""));
    try verifyIntegrity(updated, archive.header);
}

test "WIM image replacement handles one-image archives and explicit boot policy" {
    const allocator = std.testing.allocator;
    const original_entries = [_]writer.Entry{.{ .path = "old", .data = "old" }};
    const source = try writer.encodeAlloc(allocator, &original_entries, .{
        .compression = .stored,
        .image_name = "same-name",
        .bootable = true,
        .integrity = false,
    });
    defer allocator.free(source);
    const new_entries = [_]writer.Entry{.{ .path = "new", .data = "new" }};
    const replacement: writer.Image = .{
        .name = "same-name",
        .entries = &new_entries,
    };
    const preserved = try writer.replaceImageAlloc(
        allocator,
        source,
        1,
        replacement,
        .{},
    );
    defer allocator.free(preserved);
    const preserved_archive = try archive_mod.Archive.init(preserved);
    try std.testing.expectEqual(@as(u32, 1), preserved_archive.header.image_count);
    try std.testing.expectEqual(@as(u32, 1), preserved_archive.header.boot_index);
    try std.testing.expect(preserved_archive.header.integrity_table.isZero());
    var lookup = try preserved_archive.readLookupTableAlloc(allocator, 16, 4096);
    defer lookup.deinit();
    try expectBootMatchesMetadata(preserved_archive.header, lookup.entries);
    try expectPath(allocator, preserved_archive, 1, "new", "new");

    const cleared = try writer.replaceImageAlloc(
        allocator,
        source,
        1,
        replacement,
        .{ .bootable = false },
    );
    defer allocator.free(cleared);
    const cleared_archive = try archive_mod.Archive.init(cleared);
    try std.testing.expectEqual(@as(u32, 0), cleared_archive.header.boot_index);
    try std.testing.expect(cleared_archive.header.boot_metadata.isZero());

    const nonboot_source = try writer.encodeAlloc(allocator, &original_entries, .{
        .compression = .stored,
        .image_name = "same-name",
        .integrity = false,
    });
    defer allocator.free(nonboot_source);
    const promoted = try writer.replaceImageAlloc(
        allocator,
        nonboot_source,
        1,
        replacement,
        .{ .bootable = true },
    );
    defer allocator.free(promoted);
    const promoted_archive = try archive_mod.Archive.init(promoted);
    try std.testing.expectEqual(@as(u32, 1), promoted_archive.header.boot_index);
}

test "WIM solid image replacement retains routing and drops dead blobs" {
    const allocator = std.testing.allocator;
    const shared = "solid replacement shared\n" ** 128;
    const old_unique = "solid old unique\n" ** 128;
    const first_entries = [_]writer.Entry{
        .{ .path = "old.bin", .data = old_unique },
        .{ .path = "shared.bin", .data = shared },
    };
    const second_entries = [_]writer.Entry{
        .{ .path = "second.bin", .data = "solid second remains\n" ** 128 },
        .{ .path = "shared.bin", .data = shared },
    };
    const images = [_]writer.Image{
        .{ .name = "replace", .entries = &first_entries },
        .{ .name = "second", .entries = &second_entries },
    };
    const source = try writer.encodeImagesSolidAlloc(allocator, &images, .{
        .metadata_chunk_size = 32 * 1024,
        .solid_chunk_size = 32 * 1024,
        .boot_index = 2,
    });
    defer allocator.free(source);
    const new_unique = "solid new unique\n" ** 128;
    const replacement_entries = [_]writer.Entry{
        .{ .path = "new.bin", .data = new_unique },
        .{ .path = "shared.bin", .data = shared },
    };
    const updated = try writer.replaceImageAlloc(
        allocator,
        source,
        1,
        .{ .name = "replace", .entries = &replacement_entries },
        .{ .solid_chunk_size = 32 * 1024 },
    );
    defer allocator.free(updated);
    const archive = try archive_mod.Archive.init(updated);
    try std.testing.expectEqual(format.solid_version, archive.header.version);
    try std.testing.expectEqual(@as(u32, 2), archive.header.boot_index);
    var lookup = try archive.readLookupTableAlloc(allocator, 64, 8192);
    defer lookup.deinit();
    var resource_count: usize = 0;
    for (lookup.entries) |entry|
        resource_count += @intFromBool(entry.kind == .solid_resource);
    try std.testing.expectEqual(@as(usize, 2), resource_count);
    var old_hash: [20]u8 = undefined;
    std.crypto.hash.Sha1.hash(old_unique, &old_hash, .{});
    try std.testing.expect(lookup.findData(&old_hash) == null);
    try expectPath(allocator, archive, 1, "new.bin", new_unique);
    try expectPath(
        allocator,
        archive,
        2,
        "second.bin",
        "solid second remains\n" ** 128,
    );
    try expectPath(allocator, archive, 2, "shared.bin", shared);
    try verifyIntegrity(updated, archive.header);
}

test "WIM image replacement APIs are transactional and reject unsupported input" {
    const allocator = std.testing.allocator;
    const base_entries = [_]writer.Entry{.{ .path = "base", .data = "base" }};
    const second_entries = [_]writer.Entry{.{ .path = "second", .data = "second" }};
    const images = [_]writer.Image{
        .{ .name = "first", .entries = &base_entries },
        .{ .name = "second", .entries = &second_entries },
    };
    const source = try writer.encodeImagesAlloc(allocator, &images, .{
        .compression = .stored,
        .integrity = false,
    });
    defer allocator.free(source);
    const replacement_entries = [_]writer.Entry{.{ .path = "replacement", .data = "new" }};
    const replacement: writer.Image = .{
        .name = "replacement",
        .entries = &replacement_entries,
    };
    const expected = try writer.replaceImageAlloc(
        allocator,
        source,
        1,
        replacement,
        .{},
    );
    defer allocator.free(expected);

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(allocator);
    try appended.appendSlice(allocator, "prefix");
    const written = try writer.replaceImageAppend(
        allocator,
        &appended,
        source,
        1,
        replacement,
        .{},
    );
    try std.testing.expectEqual(expected.len, written);
    try std.testing.expectEqualStrings("prefix", appended.items[0..6]);
    try std.testing.expectEqualSlices(u8, expected, appended.items[6..]);

    const exact = try allocator.alloc(u8, expected.len);
    defer allocator.free(exact);
    try std.testing.expectEqual(
        expected.len,
        try writer.replaceImageInto(
            allocator,
            source,
            1,
            replacement,
            exact,
            .{},
        ),
    );
    try std.testing.expectEqualSlices(u8, expected, exact);
    const too_small = try allocator.alloc(u8, expected.len - 1);
    defer allocator.free(too_small);
    @memset(too_small, 0xa5);
    try std.testing.expectError(
        error.OutputTooSmall,
        writer.replaceImageInto(
            allocator,
            source,
            1,
            replacement,
            too_small,
            .{},
        ),
    );
    try std.testing.expect(std.mem.allEqual(u8, too_small, 0xa5));

    try std.testing.expectError(
        error.InvalidWimWriterOptions,
        writer.replaceImageAlloc(allocator, source, 1, .{
            .name = "SECOND",
            .entries = &replacement_entries,
        }, .{}),
    );
    try std.testing.expectError(
        error.UnsupportedWimUpdateInput,
        writer.replaceImageAlloc(allocator, source, 0, replacement, .{}),
    );
    try std.testing.expectError(
        error.UnsupportedWimUpdateInput,
        writer.replaceImageAlloc(allocator, source, 3, replacement, .{}),
    );
    try std.testing.expectError(
        error.InvalidWimWriterOptions,
        writer.replaceImageAlloc(allocator, source, 1, replacement, .{
            .max_metadata_bytes = 0,
        }),
    );

    const pipable = try writer.encodeImagesPipableAlloc(
        allocator,
        &images,
        .{ .compression = .stored },
        .{},
    );
    defer allocator.free(pipable);
    try std.testing.expectError(
        error.UnsupportedWimUpdateInput,
        writer.replaceImageAlloc(allocator, pipable, 1, replacement, .{}),
    );
    const split_header = try allocator.dupe(u8, source);
    defer allocator.free(split_header);
    std.mem.writeInt(u16, split_header[42..44], 2, .little);
    try std.testing.expectError(
        error.UnsupportedWimUpdateInput,
        writer.replaceImageAlloc(allocator, split_header, 1, replacement, .{}),
    );

    const before_error = appended.items.len;
    try std.testing.expectError(
        error.InvalidWimWriterOptions,
        writer.replaceImageAppend(allocator, &appended, source, 1, .{
            .name = "second",
            .entries = &replacement_entries,
        }, .{}),
    );
    try std.testing.expectEqual(before_error, appended.items.len);
}

test "WIM image replacement is allocation failure safe" {
    const allocator = std.testing.allocator;
    const old_entries = [_]writer.Entry{
        .{ .path = "old", .data = "old replacement OOM data" },
        .{ .path = "shared", .data = "shared replacement OOM data" },
    };
    const source = try writer.encodeAlloc(allocator, &old_entries, .{
        .compression = .stored,
        .image_name = "same",
        .integrity = false,
    });
    defer allocator.free(source);
    const AllocationTest = struct {
        fn run(failing_allocator: std.mem.Allocator, archive_bytes: []const u8) !void {
            const new_entries = [_]writer.Entry{
                .{ .path = "new", .data = "new replacement OOM data" },
                .{ .path = "shared", .data = "shared replacement OOM data" },
            };
            const updated = try writer.replaceImageAlloc(
                failing_allocator,
                archive_bytes,
                1,
                .{ .name = "same", .entries = &new_entries },
                .{},
            );
            defer failing_allocator.free(updated);
            const archive = try archive_mod.Archive.init(updated);
            const extracted = try archive.extractByPathAllocLimited(
                failing_allocator,
                1,
                "new",
                1024,
                limits,
            );
            defer failing_allocator.free(extracted);
            try std.testing.expectEqualStrings("new replacement OOM data", extracted);
        }
    };
    try std.testing.checkAllAllocationFailures(
        allocator,
        AllocationTest.run,
        .{source},
    );
}

fn expectPath(
    allocator: std.mem.Allocator,
    archive: archive_mod.Archive,
    image_index: u32,
    path: []const u8,
    expected: []const u8,
) !void {
    const extracted = try archive.extractByPathAllocLimited(
        allocator,
        image_index,
        path,
        expected.len,
        limits,
    );
    defer allocator.free(extracted);
    try std.testing.expectEqualSlices(u8, expected, extracted);
}

fn expectBootMatchesMetadata(
    header: format.Header,
    entries: []const archive_mod.LookupEntry,
) !void {
    if (header.boot_index == 0) {
        try std.testing.expect(header.boot_metadata.isZero());
        return;
    }
    var metadata_index: u32 = 0;
    for (entries) |entry| {
        if (!entry.resource.isMetadata()) continue;
        metadata_index += 1;
        if (metadata_index == header.boot_index) {
            try expectResourceEqual(header.boot_metadata, entry.resource);
            return;
        }
    }
    return error.TestExpectedEqual;
}

fn expectResourceEqual(
    expected: format.ResourceHeader,
    actual: format.ResourceHeader,
) !void {
    try std.testing.expectEqual(expected.size_in_wim, actual.size_in_wim);
    try std.testing.expectEqual(expected.flags, actual.flags);
    try std.testing.expectEqual(expected.offset_in_wim, actual.offset_in_wim);
    try std.testing.expectEqual(expected.uncompressed_size, actual.uncompressed_size);
}

fn utf16ContainsAscii(utf16: []const u8, ascii: []const u8) bool {
    return countUtf16Ascii(utf16, ascii) != 0;
}

fn countUtf16Ascii(utf16: []const u8, ascii: []const u8) usize {
    if (ascii.len == 0 or utf16.len < ascii.len * 2) return 0;
    var count: usize = 0;
    var start: usize = 0;
    while (start + ascii.len * 2 <= utf16.len) : (start += 2) {
        var matches = true;
        for (ascii, 0..) |byte, index| {
            if (utf16[start + index * 2] != byte or
                utf16[start + index * 2 + 1] != 0)
            {
                matches = false;
                break;
            }
        }
        count += @intFromBool(matches);
    }
    return count;
}

fn verifyIntegrity(bytes: []const u8, header: format.Header) !void {
    const resource = header.integrity_table;
    const offset: usize = @intCast(resource.offset_in_wim);
    const size: usize = @intCast(resource.size_in_wim);
    const table = bytes[offset..][0..size];
    try std.testing.expectEqual(size, format.readU32(table, 0));
    const count: usize = format.readU32(table, 4);
    const chunk_size: usize = format.readU32(table, 8);
    const lookup_end: usize = @intCast(
        header.lookup_table.offset_in_wim + header.lookup_table.size_in_wim,
    );
    const checked_len = lookup_end - format.header_size;
    const expected_count = if (checked_len == 0)
        0
    else
        1 + (checked_len - 1) / chunk_size;
    try std.testing.expectEqual(expected_count, count);
    for (0..count) |index| {
        const start = format.header_size + index * chunk_size;
        const end = @min(lookup_end, start + chunk_size);
        var actual: [20]u8 = undefined;
        std.crypto.hash.Sha1.hash(bytes[start..end], &actual, .{});
        try std.testing.expectEqualSlices(
            u8,
            &actual,
            table[12 + index * 20 ..][0..20],
        );
    }
}
