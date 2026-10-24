const std = @import("std");
const archive_mod = @import("archive.zig");
const format = @import("format.zig");
const writer = @import("writer.zig");

const limits: archive_mod.PathLimits = .{
    .max_metadata_bytes = 1024 * 1024,
    .max_solid_chunk_bytes = 1024 * 1024,
    .max_lookup_entries = 128,
    .max_lookup_bytes = 128 * format.lookup_entry_size,
    .max_directory_entries = 128,
    .max_path_depth = 16,
};

test "WIM compaction removes stale ordinary resources and is idempotent" {
    const allocator = std.testing.allocator;
    const shared = "compact shared bytes\n" ** 64;
    const old_payload = "dead ordinary resource\n" ** 64;
    const first_entries = [_]writer.Entry{
        .{ .path = "old.bin", .data = old_payload },
        .{ .path = "shared.bin", .data = shared },
    };
    const second_entries = [_]writer.Entry{
        .{ .path = "second.bin", .data = "second survives compaction\n" },
        .{ .path = "shared.bin", .data = shared },
    };
    const images = [_]writer.Image{
        .{ .name = "replace", .entries = &first_entries },
        .{ .name = "second", .entries = &second_entries },
    };
    const base = try writer.encodeImagesAlloc(allocator, &images, .{
        .compression = .stored,
        .boot_index = 1,
    });
    defer allocator.free(base);
    const new_payload = "replacement survives compaction\n" ** 32;
    const replacement_entries = [_]writer.Entry{
        .{ .path = "new.bin", .data = new_payload },
        .{ .path = "shared.bin", .data = shared },
    };
    const updated = try writer.replaceImageAlloc(
        allocator,
        base,
        1,
        .{ .name = "replace", .entries = &replacement_entries },
        .{},
    );
    defer allocator.free(updated);
    try std.testing.expect(std.mem.indexOf(u8, updated, old_payload) != null);

    const compacted = try writer.compactAlloc(allocator, updated, .{});
    defer allocator.free(compacted);
    try std.testing.expect(compacted.len < updated.len);
    try std.testing.expect(std.mem.indexOf(u8, compacted, old_payload) == null);
    const repeated = try writer.compactAlloc(allocator, compacted, .{});
    defer allocator.free(repeated);
    try std.testing.expectEqualSlices(u8, compacted, repeated);

    const archive = try archive_mod.Archive.init(compacted);
    try std.testing.expectEqual(@as(u32, 2), archive.header.image_count);
    try std.testing.expectEqual(@as(u32, 1), archive.header.boot_index);
    try expectPath(allocator, archive, 1, "new.bin", new_payload);
    try expectPath(allocator, archive, 1, "shared.bin", shared);
    try expectPath(
        allocator,
        archive,
        2,
        "second.bin",
        "second survives compaction\n",
    );
    try std.testing.expectError(
        error.WimPathNotFound,
        archive.extractByPathAllocLimited(
            allocator,
            1,
            "old.bin",
            old_payload.len,
            limits,
        ),
    );
    var lookup = try archive.readLookupTableAlloc(allocator, 128, 8192);
    defer lookup.deinit();
    try expectBootMatchesMetadata(archive.header, lookup.entries);
    var shared_hash: [20]u8 = undefined;
    std.crypto.hash.Sha1.hash(shared, &shared_hash, .{});
    try std.testing.expectEqual(
        @as(u32, 2),
        lookup.findData(&shared_hash).?.reference_count,
    );
    try verifyIntegrity(compacted, archive.header);
}

test "WIM solid compaction removes an empty middle resource and rebases later blobs" {
    const allocator = std.testing.allocator;
    const base_payload = "solid base survives\n" ** 97;
    const middle_payload = "solid middle is deleted\n" ** 113;
    const final_payload = "solid final survives and moves\n" ** 131;
    const base_entries = [_]writer.Entry{.{
        .path = "base.bin",
        .data = base_payload,
    }};
    const base = try writer.encodeSolidAlloc(allocator, &base_entries, .{
        .metadata_chunk_size = 32 * 1024,
        .solid_chunk_size = 32 * 1024,
        .image_name = "base",
    });
    defer allocator.free(base);
    const middle_entries = [_]writer.Entry{.{
        .path = "middle.bin",
        .data = middle_payload,
    }};
    const with_middle = try writer.appendImageAlloc(allocator, base, .{
        .name = "middle",
        .entries = &middle_entries,
    }, .{ .solid_chunk_size = 32 * 1024 });
    defer allocator.free(with_middle);
    const final_entries = [_]writer.Entry{.{
        .path = "final.bin",
        .data = final_payload,
    }};
    const with_final = try writer.appendImageAlloc(allocator, with_middle, .{
        .name = "final",
        .entries = &final_entries,
    }, .{
        .bootable = true,
        .solid_chunk_size = 32 * 1024,
    });
    defer allocator.free(with_final);
    const deleted = try writer.deleteImageAlloc(allocator, with_final, 2, .{});
    defer allocator.free(deleted);
    const deleted_archive = try archive_mod.Archive.init(deleted);
    var deleted_lookup = try deleted_archive.readLookupTableAlloc(
        allocator,
        64,
        8192,
    );
    defer deleted_lookup.deinit();
    try std.testing.expectEqual(@as(usize, 3), solidResourceCount(deleted_lookup.entries));
    var final_hash: [20]u8 = undefined;
    std.crypto.hash.Sha1.hash(final_payload, &final_hash, .{});
    const old_final_offset = deleted_lookup.findData(&final_hash).?.resource.offset_in_wim;

    const compacted = try writer.compactAlloc(allocator, deleted, .{});
    defer allocator.free(compacted);
    try std.testing.expect(compacted.len < deleted.len);
    const archive = try archive_mod.Archive.init(compacted);
    try std.testing.expectEqual(format.solid_version, archive.header.version);
    try std.testing.expectEqual(@as(u32, 2), archive.header.image_count);
    try std.testing.expectEqual(@as(u32, 2), archive.header.boot_index);
    var lookup = try archive.readLookupTableAlloc(allocator, 64, 8192);
    defer lookup.deinit();
    try std.testing.expectEqual(@as(usize, 2), solidResourceCount(lookup.entries));
    const new_final_offset = lookup.findData(&final_hash).?.resource.offset_in_wim;
    try std.testing.expectEqual(
        @as(u64, middle_payload.len),
        old_final_offset - new_final_offset,
    );
    try expectPath(allocator, archive, 1, "base.bin", base_payload);
    try expectPath(allocator, archive, 2, "final.bin", final_payload);
    try expectBootMatchesMetadata(archive.header, lookup.entries);
    try verifyIntegrity(compacted, archive.header);
}

test "WIM compaction supports solid archives without packed data" {
    const allocator = std.testing.allocator;
    const images = [_]writer.Image{
        .{ .name = "empty-a", .entries = &.{} },
        .{ .name = "empty-b", .entries = &.{} },
    };
    const source = try writer.encodeImagesSolidAlloc(allocator, &images, .{
        .metadata_chunk_size = 32 * 1024,
        .solid_chunk_size = 32 * 1024,
        .integrity = false,
    });
    defer allocator.free(source);
    const compacted = try writer.compactAlloc(allocator, source, .{});
    defer allocator.free(compacted);
    const archive = try archive_mod.Archive.init(compacted);
    var lookup = try archive.readLookupTableAlloc(allocator, 16, 4096);
    defer lookup.deinit();
    try std.testing.expectEqual(@as(usize, 0), solidResourceCount(lookup.entries));
    try std.testing.expectEqual(@as(u32, 2), archive.header.image_count);
    try std.testing.expect(archive.header.integrity_table.isZero());
}

test "WIM compaction APIs are transactional and validate update inputs" {
    const allocator = std.testing.allocator;
    const entries = [_]writer.Entry{.{ .path = "data", .data = "compact data" }};
    const source = try writer.encodeAlloc(allocator, &entries, .{
        .compression = .stored,
    });
    defer allocator.free(source);
    const expected = try writer.compactAlloc(allocator, source, .{});
    defer allocator.free(expected);

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(allocator);
    try appended.appendSlice(allocator, "prefix");
    const written = try writer.compactAppend(allocator, &appended, source, .{});
    try std.testing.expectEqual(expected.len, written);
    try std.testing.expectEqualStrings("prefix", appended.items[0..6]);
    try std.testing.expectEqualSlices(u8, expected, appended.items[6..]);

    const exact = try allocator.alloc(u8, expected.len);
    defer allocator.free(exact);
    try std.testing.expectEqual(
        expected.len,
        try writer.compactInto(allocator, source, exact, .{}),
    );
    try std.testing.expectEqualSlices(u8, expected, exact);
    const too_small = try allocator.alloc(u8, expected.len - 1);
    defer allocator.free(too_small);
    @memset(too_small, 0xa5);
    try std.testing.expectError(
        error.OutputTooSmall,
        writer.compactInto(allocator, source, too_small, .{}),
    );
    try std.testing.expect(std.mem.allEqual(u8, too_small, 0xa5));

    const no_integrity = try writer.compactAlloc(
        allocator,
        source,
        .{ .integrity = false },
    );
    defer allocator.free(no_integrity);
    const no_integrity_archive = try archive_mod.Archive.init(no_integrity);
    try std.testing.expect(no_integrity_archive.header.integrity_table.isZero());
    const restored_integrity = try writer.compactAlloc(
        allocator,
        no_integrity,
        .{ .integrity = true },
    );
    defer allocator.free(restored_integrity);
    const restored_archive = try archive_mod.Archive.init(restored_integrity);
    try std.testing.expect(!restored_archive.header.integrity_table.isZero());
    try verifyIntegrity(restored_integrity, restored_archive.header);

    try std.testing.expectError(
        error.InvalidWimWriterOptions,
        writer.compactAlloc(allocator, source, .{ .max_lookup_entries = 0 }),
    );
    const pipable = try writer.encodePipableAlloc(
        allocator,
        &entries,
        .{ .compression = .stored },
        .{},
    );
    defer allocator.free(pipable);
    try std.testing.expectError(
        error.UnsupportedWimUpdateInput,
        writer.compactAlloc(allocator, pipable, .{}),
    );
    const split_header = try allocator.dupe(u8, source);
    defer allocator.free(split_header);
    std.mem.writeInt(u16, split_header[42..44], 2, .little);
    try std.testing.expectError(
        error.UnsupportedWimUpdateInput,
        writer.compactAlloc(allocator, split_header, .{}),
    );

    const before_error = appended.items.len;
    try std.testing.expectError(
        error.InvalidWimWriterOptions,
        writer.compactAppend(allocator, &appended, source, .{
            .max_xml_bytes = 0,
        }),
    );
    try std.testing.expectEqual(before_error, appended.items.len);
}

test "WIM compaction is allocation failure safe" {
    const allocator = std.testing.allocator;
    const old_entries = [_]writer.Entry{.{
        .path = "old",
        .data = "dead compact OOM data",
    }};
    const base = try writer.encodeAlloc(allocator, &old_entries, .{
        .compression = .stored,
        .integrity = false,
    });
    defer allocator.free(base);
    const live_entries = [_]writer.Entry{.{
        .path = "live",
        .data = "live compact OOM data",
    }};
    const updated = try writer.appendImageAlloc(allocator, base, .{
        .name = "live",
        .entries = &live_entries,
    }, .{});
    defer allocator.free(updated);
    const deleted = try writer.deleteImageAlloc(allocator, updated, 1, .{});
    defer allocator.free(deleted);
    const AllocationTest = struct {
        fn run(failing_allocator: std.mem.Allocator, archive_bytes: []const u8) !void {
            const compacted = try writer.compactAlloc(
                failing_allocator,
                archive_bytes,
                .{},
            );
            defer failing_allocator.free(compacted);
            const archive = try archive_mod.Archive.init(compacted);
            const extracted = try archive.extractByPathAllocLimited(
                failing_allocator,
                1,
                "live",
                1024,
                limits,
            );
            defer failing_allocator.free(extracted);
            try std.testing.expectEqualStrings("live compact OOM data", extracted);
        }
    };
    try std.testing.checkAllAllocationFailures(
        allocator,
        AllocationTest.run,
        .{deleted},
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

fn solidResourceCount(entries: []const archive_mod.LookupEntry) usize {
    var count: usize = 0;
    for (entries) |entry|
        count += @intFromBool(entry.kind == .solid_resource);
    return count;
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
