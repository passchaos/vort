const std = @import("std");
const archive_mod = @import("archive.zig");
const format = @import("format.zig");
const writer = @import("writer.zig");

const limits: archive_mod.PathLimits = .{
    .max_metadata_bytes = 1024 * 1024,
    .max_lookup_entries = 64,
    .max_lookup_bytes = 64 * format.lookup_entry_size,
    .max_directory_entries = 64,
    .max_path_depth = 16,
};

test "WIM writer creates a deterministic stored image with deduplicated blobs" {
    const allocator = std.testing.allocator;
    const shared = "shared WIM payload\n";
    const entries = [_]writer.Entry{
        .{ .path = "copy.txt", .data = shared },
        .{ .path = "docs/readme.txt", .data = shared, .last_write_time = 42 },
        .{ .path = "empty.bin" },
        .{ .path = "docs", .kind = .directory, .creation_time = 7 },
        .{ .path = "unicode/文件.txt", .data = "UTF-8 path" },
    };
    const options: writer.Options = .{
        .compression = .stored,
        .image_name = "A & B <stored>",
    };
    const encoded = try writer.encodeAlloc(allocator, &entries, options);
    defer allocator.free(encoded);
    const repeated = try writer.encodeAlloc(allocator, &entries, options);
    defer allocator.free(repeated);
    try std.testing.expectEqualSlices(u8, encoded, repeated);

    const archive = try archive_mod.Archive.init(encoded);
    try std.testing.expectEqual(format.Compression.none, archive.header.compression);
    try std.testing.expectEqual(@as(u32, 1), archive.header.image_count);
    try std.testing.expect(!archive.header.integrity_table.isZero());
    var lookup = try archive.readLookupTableAlloc(allocator, 64, 4096);
    defer lookup.deinit();
    try std.testing.expectEqual(@as(usize, 3), lookup.entries.len);

    var shared_hash: [20]u8 = undefined;
    std.crypto.hash.Sha1.hash(shared, &shared_hash, .{});
    const shared_entry = lookup.findData(&shared_hash).?;
    try std.testing.expectEqual(@as(u32, 2), shared_entry.reference_count);
    try std.testing.expect(!shared_entry.resource.isCompressed());

    const extracted = try archive.extractByPathAllocLimited(
        allocator,
        1,
        "/docs/readme.txt",
        1024,
        limits,
    );
    defer allocator.free(extracted);
    try std.testing.expectEqualStrings(shared, extracted);
    const empty = try archive.extractByPathAllocLimited(
        allocator,
        1,
        "empty.bin",
        0,
        limits,
    );
    defer allocator.free(empty);
    try std.testing.expectEqual(@as(usize, 0), empty.len);
    const unicode = try archive.extractByPathAllocLimited(
        allocator,
        1,
        "unicode/文件.txt",
        1024,
        limits,
    );
    defer allocator.free(unicode);
    try std.testing.expectEqualStrings("UTF-8 path", unicode);

    var image = try archive.readImageMetadataAlloc(allocator, 1, limits);
    defer image.deinit();
    const docs = try image.lookup(allocator, "docs", 64, 16);
    try std.testing.expectEqual(@as(u64, 7), docs.creation_time);
    const readme = try image.lookup(allocator, "docs/readme.txt", 64, 16);
    try std.testing.expectEqual(@as(u64, 42), readme.last_write_time);

    const xml = try archive.readXmlAllocLimited(allocator, 16 * 1024);
    defer allocator.free(xml);
    try std.testing.expect(std.mem.indexOf(
        u8,
        xml,
        &.{ '&', 0, 'a', 0, 'm', 0, 'p', 0, ';', 0 },
    ) != null);
    try verifyIntegrity(encoded, archive.header);
}

test "WIM writer emits multichunk XPRESS and transactional buffer APIs" {
    const allocator = std.testing.allocator;
    const payload = "XPRESS WIM multichunk payload 0123456789\n" ** 2500;
    const entries = [_]writer.Entry{
        .{ .path = "nested/payload.bin", .data = payload },
        .{ .path = "tiny.txt", .data = "tiny" },
    };
    const options: writer.Options = .{
        .compression = .xpress,
        .integrity = false,
        .guid = @splat(0x5a),
    };
    const encoded = try writer.encodeAlloc(allocator, &entries, options);
    defer allocator.free(encoded);
    const archive = try archive_mod.Archive.init(encoded);
    try std.testing.expectEqual(format.Compression.xpress, archive.header.compression);
    try std.testing.expectEqual(@as(usize, 32 * 1024), archive.header.chunk_size);
    try std.testing.expectEqualSlices(u8, &@as([16]u8, @splat(0x5a)), &archive.header.guid);
    try std.testing.expect(archive.header.integrity_table.isZero());
    var lookup = try archive.readLookupTableAlloc(allocator, 64, 4096);
    defer lookup.deinit();
    for (lookup.entries) |entry|
        try std.testing.expect(entry.resource.isCompressed());
    const extracted = try archive.extractByPathAllocLimited(
        allocator,
        1,
        "nested/payload.bin",
        payload.len,
        limits,
    );
    defer allocator.free(extracted);
    try std.testing.expectEqualSlices(u8, payload, extracted);

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(allocator);
    try appended.appendSlice(allocator, "prefix");
    const written = try writer.encodeAppend(allocator, &appended, &entries, options);
    try std.testing.expectEqual(encoded.len, written);
    try std.testing.expectEqualStrings("prefix", appended.items[0..6]);
    try std.testing.expectEqualSlices(u8, encoded, appended.items[6..]);

    const too_small = try allocator.alloc(u8, encoded.len - 1);
    defer allocator.free(too_small);
    @memset(too_small, 0xa5);
    try std.testing.expectError(
        error.OutputTooSmall,
        writer.encodeInto(allocator, &entries, too_small, options),
    );
    try std.testing.expect(std.mem.allEqual(u8, too_small, 0xa5));
    const into = try allocator.alloc(u8, encoded.len);
    defer allocator.free(into);
    const into_len = try writer.encodeInto(allocator, &entries, into, options);
    try std.testing.expectEqual(encoded.len, into_len);
    try std.testing.expectEqualSlices(u8, encoded, into);
}

test "WIM writer validates paths, XML and compression geometry" {
    const bad_path = [_]writer.Entry{.{ .path = "a//b" }};
    try std.testing.expectError(
        error.InvalidWimEntry,
        writer.encodeAlloc(std.testing.allocator, &bad_path, .{}),
    );
    const directory_data = [_]writer.Entry{.{
        .path = "dir",
        .kind = .directory,
        .data = "not allowed",
    }};
    try std.testing.expectError(
        error.InvalidWimEntry,
        writer.encodeAlloc(std.testing.allocator, &directory_data, .{}),
    );
    const aliases = [_]writer.Entry{
        .{ .path = "same" },
        .{ .path = "SAME" },
    };
    try std.testing.expectError(
        error.InvalidWimEntry,
        writer.encodeAlloc(std.testing.allocator, &aliases, .{}),
    );
    try std.testing.expectError(
        error.InvalidWimWriterOptions,
        writer.encodeAlloc(std.testing.allocator, &.{}, .{
            .compression = .stored,
            .chunk_size = 4096,
        }),
    );
    try std.testing.expectError(
        error.InvalidWimWriterOptions,
        writer.encodeAlloc(std.testing.allocator, &.{}, .{
            .image_name = "bad\x00name",
        }),
    );
    const unsupported_attributes = [_]writer.Entry{.{
        .path = "reparse",
        .attributes = 0x0000_0400,
    }};
    try std.testing.expectError(
        error.InvalidWimEntry,
        writer.encodeAlloc(std.testing.allocator, &unsupported_attributes, .{}),
    );

    var existing: std.ArrayList(u8) = .empty;
    defer existing.deinit(std.testing.allocator);
    try existing.appendSlice(std.testing.allocator, "kept");
    try std.testing.expectError(
        error.InvalidWimEntry,
        writer.encodeAppend(std.testing.allocator, &existing, &bad_path, .{}),
    );
    try std.testing.expectEqualStrings("kept", existing.items);
}

test "WIM writer is allocation failure safe" {
    const AllocationTest = struct {
        fn run(allocator: std.mem.Allocator) !void {
            const entries = [_]writer.Entry{
                .{ .path = "nested/data.txt", .data = "allocation failure coverage" },
                .{ .path = "empty" },
            };
            const encoded = try writer.encodeAlloc(allocator, &entries, .{
                .compression = .stored,
            });
            defer allocator.free(encoded);
            _ = try archive_mod.Archive.init(encoded);
        }
    };
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        AllocationTest.run,
        .{},
    );
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
