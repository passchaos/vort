const std = @import("std");
const archive_mod = @import("archive.zig");
const format = @import("format.zig");
const pipable = @import("pipable.zig");
const pipable_stream = @import("pipable_stream.zig");
const set_mod = @import("set.zig");
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

test "WIM writer emits deterministic mixed LZX chunks" {
    const allocator = std.testing.allocator;
    var payload: [70_000]u8 = undefined;
    const phrase = "Vort deterministic WIM LZX payload 0123456789\n";
    for (payload[0 .. 64 * 1024], 0..) |*byte, index|
        byte.* = phrase[index % phrase.len];
    var prng = std.Random.DefaultPrng.init(0x5749_4d4c_5a58);
    prng.random().bytes(payload[64 * 1024 ..]);
    const entries = [_]writer.Entry{.{ .path = "nested/payload.bin", .data = &payload }};
    const options: writer.Options = .{
        .compression = .lzx,
        .chunk_size = 64 * 1024,
        .integrity = false,
    };
    const encoded = try writer.encodeAlloc(allocator, &entries, options);
    defer allocator.free(encoded);
    const repeated = try writer.encodeAlloc(allocator, &entries, options);
    defer allocator.free(repeated);
    try std.testing.expectEqualSlices(u8, encoded, repeated);

    const archive = try archive_mod.Archive.init(encoded);
    try std.testing.expectEqual(format.Compression.lzx, archive.header.compression);
    try std.testing.expectEqual(@as(usize, 64 * 1024), archive.header.chunk_size);
    var lookup = try archive.readLookupTableAlloc(allocator, 64, 4096);
    defer lookup.deinit();
    var hash: [20]u8 = undefined;
    std.crypto.hash.Sha1.hash(&payload, &hash, .{});
    const entry = lookup.findData(&hash).?;
    try std.testing.expect(entry.resource.isCompressed());
    const resource_start: usize = @intCast(entry.resource.offset_in_wim);
    const first_end: usize = format.readU32(encoded, resource_start);
    try std.testing.expect(first_end < 64 * 1024);
    try std.testing.expectEqual(
        @as(u64, 4 + first_end + (payload.len - 64 * 1024)),
        entry.resource.size_in_wim,
    );
    const extracted = try archive.extractByPathAllocLimited(
        allocator,
        1,
        "nested/payload.bin",
        payload.len,
        limits,
    );
    defer allocator.free(extracted);
    try std.testing.expectEqualSlices(u8, &payload, extracted);
}

test "WIM writer preserves named reparse and encrypted raw streams" {
    const allocator = std.testing.allocator;
    const file_streams = [_]writer.NamedStream{
        .{ .name = "Zone.Identifier", .data = "shared stream bytes" },
        .{ .name = "空", .data = "" },
    };
    const directory_streams = [_]writer.NamedStream{.{
        .name = "directory.meta",
        .data = "directory ADS",
    }};
    const entries = [_]writer.Entry{
        .{
            .path = "multi.txt",
            .data = "shared stream bytes",
            .named_streams = &file_streams,
        },
        .{
            .path = "link",
            .reparse = .{
                .tag = 0xa000_000c,
                .data = "reparse payload",
                .reserved = 3,
                .flags = 4,
            },
        },
        .{
            .path = "dual.bin",
            .data = "ordinary reparse data",
            .reparse = .{ .tag = 0x8000_001b, .data = "dual reparse payload" },
        },
        .{
            .path = "junction",
            .kind = .directory,
            .reparse = .{ .tag = 0xa000_0003, .data = "directory reparse" },
        },
        .{
            .path = "ads-dir",
            .kind = .directory,
            .named_streams = &directory_streams,
        },
        .{ .path = "secret.dat", .encrypted_raw = "opaque EFSRPC bytes" },
        .{
            .path = "encrypted-dir",
            .kind = .directory,
            .encrypted_raw = "opaque directory EFSRPC bytes",
        },
    };
    const encoded = try writer.encodeAlloc(allocator, &entries, .{});
    defer allocator.free(encoded);
    const archive = try archive_mod.Archive.init(encoded);
    var lookup = try archive.readLookupTableAlloc(allocator, 64, 4096);
    defer lookup.deinit();
    var image = try archive.readImageMetadataAlloc(allocator, 1, limits);
    defer image.deinit();

    const multi = try image.lookup(allocator, "multi.txt", 64, 16);
    try std.testing.expectEqual(@as(u16, 3), multi.extra_stream_count);
    try std.testing.expect(std.mem.allEqual(u8, &multi.main_hash, 0));
    const default_data = try archive.extractByPathAllocLimited(
        allocator,
        1,
        "multi.txt",
        1024,
        limits,
    );
    defer allocator.free(default_data);
    try std.testing.expectEqualStrings("shared stream bytes", default_data);
    const zone = try archive.extractNamedStreamByPathAllocLimited(
        allocator,
        1,
        "multi.txt",
        "Zone.Identifier",
        1024,
        limits,
    );
    defer allocator.free(zone);
    try std.testing.expectEqualStrings("shared stream bytes", zone);
    const empty_named = try archive.extractNamedStreamByPathAllocLimited(
        allocator,
        1,
        "multi.txt",
        "空",
        0,
        limits,
    );
    defer allocator.free(empty_named);
    try std.testing.expectEqual(@as(usize, 0), empty_named.len);
    var shared_hash: [20]u8 = undefined;
    std.crypto.hash.Sha1.hash("shared stream bytes", &shared_hash, .{});
    try std.testing.expectEqual(@as(u32, 2), lookup.findData(&shared_hash).?.reference_count);

    const ads_dir = try archive.extractNamedStreamByPathAllocLimited(
        allocator,
        1,
        "ads-dir",
        "directory.meta",
        1024,
        limits,
    );
    defer allocator.free(ads_dir);
    try std.testing.expectEqualStrings("directory ADS", ads_dir);

    const link = try image.lookup(allocator, "link", 64, 16);
    try std.testing.expect(link.isReparsePoint());
    try std.testing.expectEqual(@as(?u32, 0xa000_000c), link.reparseTag());
    try std.testing.expectEqual(@as(u64, 0x0004_0003_a000_000c), link.reparse_or_hard_link);
    const link_data = try archive.extractReparseDataByPathAllocLimited(
        allocator,
        1,
        "link",
        1024,
        limits,
    );
    defer allocator.free(link_data);
    try std.testing.expectEqualStrings("reparse payload", link_data);

    const dual = try image.lookup(allocator, "dual.bin", 64, 16);
    try std.testing.expectEqual(@as(u16, 2), dual.extra_stream_count);
    try std.testing.expect(std.mem.allEqual(u8, &dual.main_hash, 0));
    const dual_reparse = try archive.extractReparseDataByPathAllocLimited(
        allocator,
        1,
        "dual.bin",
        1024,
        limits,
    );
    defer allocator.free(dual_reparse);
    try std.testing.expectEqualStrings("dual reparse payload", dual_reparse);
    const dual_default_hash = (try dual.defaultDataSha1()).?;
    const dual_default = try archive.extractBySha1AllocLimited(
        allocator,
        &dual_default_hash,
        1024,
        64,
        4096,
    );
    defer allocator.free(dual_default);
    try std.testing.expectEqualStrings("ordinary reparse data", dual_default);

    const junction_data = try archive.extractReparseDataByPathAllocLimited(
        allocator,
        1,
        "junction",
        1024,
        limits,
    );
    defer allocator.free(junction_data);
    try std.testing.expectEqualStrings("directory reparse", junction_data);

    const encrypted = try archive.extractEncryptedRawByPathAllocLimited(
        allocator,
        1,
        "secret.dat",
        1024,
        limits,
    );
    defer allocator.free(encrypted);
    try std.testing.expectEqualStrings("opaque EFSRPC bytes", encrypted);
    const encrypted_dir = try archive.extractEncryptedRawByPathAllocLimited(
        allocator,
        1,
        "encrypted-dir",
        1024,
        limits,
    );
    defer allocator.free(encrypted_dir);
    try std.testing.expectEqualStrings("opaque directory EFSRPC bytes", encrypted_dir);
}

test "WIM writer deduplicates security descriptors and preserves hard links" {
    const allocator = std.testing.allocator;
    const null_dacl = [_]u8{ 1, 0, 4, 0x80 } ++ [_]u8{0} ** 16;
    const world_owner = [_]u8{
        1,  0, 0, 0x80,
        20, 0, 0, 0,
        0,  0, 0, 0,
        0,  0, 0, 0,
        0,  0, 0, 0,
        1,  1, 0, 0,
        0,  0, 0, 1,
        0,  0, 0, 0,
    };
    const link_streams = [_]writer.NamedStream{.{
        .name = "link.ads",
        .data = "hard link ADS",
    }};
    const entries = [_]writer.Entry{
        .{
            .path = "hard/a.txt",
            .data = "hard linked payload",
            .named_streams = &link_streams,
            .security_descriptor = &null_dacl,
            .hard_link_id = 0x4242,
            .last_write_time = 9,
        },
        .{
            .path = "hard/b.txt",
            .data = "hard linked payload",
            .named_streams = &link_streams,
            .security_descriptor = &null_dacl,
            .hard_link_id = 0x4242,
            .last_write_time = 9,
        },
        .{
            .path = "independent.txt",
            .data = "hard linked payload",
            .security_descriptor = &world_owner,
        },
    };
    const encoded = try writer.encodeAlloc(allocator, &entries, .{
        .compression = .stored,
        .root_security_descriptor = &null_dacl,
    });
    defer allocator.free(encoded);
    const archive = try archive_mod.Archive.init(encoded);
    var image = try archive.readImageMetadataAlloc(allocator, 1, limits);
    defer image.deinit();
    try std.testing.expectEqual(@as(u32, 2), image.security.descriptor_count);
    try std.testing.expectEqualSlices(u8, &null_dacl, try image.security.descriptor(0));
    try std.testing.expectEqualSlices(u8, &world_owner, try image.security.descriptor(1));
    try std.testing.expectError(
        error.WimSecurityDescriptorNotFound,
        image.security.descriptor(2),
    );
    try std.testing.expectEqual(@as(u32, 0), image.root.security_id);

    const first = try image.lookup(allocator, "hard/a.txt", 64, 16);
    const second = try image.lookup(allocator, "hard/b.txt", 64, 16);
    const independent = try image.lookup(allocator, "independent.txt", 64, 16);
    try std.testing.expectEqual(@as(?u64, 0x4242), first.hardLinkId());
    try std.testing.expectEqual(@as(?u64, 0x4242), second.hardLinkId());
    try std.testing.expectEqual(@as(?u64, null), independent.hardLinkId());
    try std.testing.expectEqual(@as(u32, 0), first.security_id);
    try std.testing.expectEqual(@as(u32, 0), second.security_id);
    try std.testing.expectEqual(@as(u32, 1), independent.security_id);

    var lookup = try archive.readLookupTableAlloc(allocator, 64, 4096);
    defer lookup.deinit();
    var payload_hash: [20]u8 = undefined;
    std.crypto.hash.Sha1.hash("hard linked payload", &payload_hash, .{});
    try std.testing.expectEqual(@as(u32, 3), lookup.findData(&payload_hash).?.reference_count);
    var ads_hash: [20]u8 = undefined;
    std.crypto.hash.Sha1.hash("hard link ADS", &ads_hash, .{});
    try std.testing.expectEqual(@as(u32, 2), lookup.findData(&ads_hash).?.reference_count);

    const xml = try archive.readXmlAllocLimited(allocator, 16 * 1024);
    defer allocator.free(xml);
    const hard_link_bytes = "hard linked payload".len + "hard link ADS".len;
    const expected_xml = try std.fmt.allocPrint(
        allocator,
        "<HARDLINKBYTES>{d}</HARDLINKBYTES>",
        .{hard_link_bytes},
    );
    defer allocator.free(expected_xml);
    try std.testing.expect(utf16ContainsAscii(xml, expected_xml));
}

test "WIM writer emits ordered multi-image metadata and shared blobs" {
    const allocator = std.testing.allocator;
    const first_entries = [_]writer.Entry{
        .{ .path = "shared.txt", .data = "cross-image shared payload" },
        .{ .path = "first.txt", .data = "first image only" },
    };
    const second_entries = [_]writer.Entry{
        .{ .path = "shared.txt", .data = "cross-image shared payload" },
        .{ .path = "second.txt", .data = "second image only" },
    };
    const images = [_]writer.Image{
        .{ .name = "first", .entries = &first_entries, .creation_time = 1 },
        .{ .name = "second", .entries = &second_entries, .creation_time = 2 },
        .{ .name = "empty-a", .entries = &.{} },
        .{ .name = "empty-b", .entries = &.{} },
    };
    const options: writer.ImagesOptions = .{
        .compression = .xpress,
        .boot_index = 2,
    };
    const encoded = try writer.encodeImagesAlloc(allocator, &images, options);
    defer allocator.free(encoded);
    const repeated = try writer.encodeImagesAlloc(allocator, &images, options);
    defer allocator.free(repeated);
    try std.testing.expectEqualSlices(u8, encoded, repeated);

    const archive = try archive_mod.Archive.init(encoded);
    try std.testing.expectEqual(@as(u32, 4), archive.header.image_count);
    try std.testing.expectEqual(@as(u32, 2), archive.header.boot_index);
    var lookup = try archive.readLookupTableAlloc(allocator, 64, 4096);
    defer lookup.deinit();
    try std.testing.expectEqual(@as(usize, 7), lookup.entries.len);
    var shared_hash: [20]u8 = undefined;
    std.crypto.hash.Sha1.hash("cross-image shared payload", &shared_hash, .{});
    try std.testing.expectEqual(@as(u32, 2), lookup.findData(&shared_hash).?.reference_count);

    var metadata_index: usize = 0;
    for (lookup.entries) |entry| {
        if (!entry.resource.isMetadata()) continue;
        metadata_index += 1;
        if (metadata_index == 2)
            try expectResourceEqual(archive.header.boot_metadata, entry.resource);
    }
    try std.testing.expectEqual(@as(usize, 4), metadata_index);

    const first = try archive.extractByPathAllocLimited(
        allocator,
        1,
        "first.txt",
        1024,
        limits,
    );
    defer allocator.free(first);
    try std.testing.expectEqualStrings("first image only", first);
    const second = try archive.extractByPathAllocLimited(
        allocator,
        2,
        "second.txt",
        1024,
        limits,
    );
    defer allocator.free(second);
    try std.testing.expectEqualStrings("second image only", second);
    var empty_a = try archive.readImageMetadataAlloc(allocator, 3, limits);
    defer empty_a.deinit();
    var empty_b = try archive.readImageMetadataAlloc(allocator, 4, limits);
    defer empty_b.deinit();
    try std.testing.expectEqual(@as(usize, 0), empty_a.root.subdir_offset);
    try std.testing.expectEqual(@as(usize, 0), empty_b.root.subdir_offset);

    const xml = try archive.readXmlAllocLimited(allocator, 32 * 1024);
    defer allocator.free(xml);
    try std.testing.expect(utf16ContainsAscii(xml, "<IMAGE INDEX=\"4\"><NAME>empty-b</NAME>"));

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(allocator);
    try appended.appendSlice(allocator, "prefix");
    const written = try writer.encodeImagesAppend(allocator, &appended, &images, options);
    try std.testing.expectEqual(encoded.len, written);
    try std.testing.expectEqualSlices(u8, encoded, appended.items[6..]);
    const too_small = try allocator.alloc(u8, encoded.len - 1);
    defer allocator.free(too_small);
    @memset(too_small, 0xa5);
    try std.testing.expectError(
        error.OutputTooSmall,
        writer.encodeImagesInto(allocator, &images, too_small, options),
    );
    try std.testing.expect(std.mem.allEqual(u8, too_small, 0xa5));
}

test "WIM split writer emits local lookup tables and routes a SWM set" {
    const allocator = std.testing.allocator;
    const large = "L" ** 700;
    const shared = "S" ** 300;
    const second_only = "T" ** 400;
    const first_entries = [_]writer.Entry{
        .{ .path = "large.bin", .data = large },
        .{ .path = "shared.bin", .data = shared },
    };
    const second_entries = [_]writer.Entry{
        .{ .path = "second.bin", .data = second_only },
        .{ .path = "shared.bin", .data = shared },
    };
    const images = [_]writer.Image{
        .{ .name = "first", .entries = &first_entries },
        .{ .name = "second", .entries = &second_entries },
    };
    var split = try writer.encodeImagesSplitAlloc(
        allocator,
        &images,
        .{ .compression = .stored, .boot_index = 1 },
        .{ .max_part_size = 600 },
    );
    defer split.deinit();
    try std.testing.expect(split.parts.len >= 3);
    const archives = try allocator.alloc(archive_mod.Archive, split.parts.len);
    defer allocator.free(archives);
    for (split.parts, archives, 0..) |part, *archive, index| {
        archive.* = try archive_mod.Archive.init(part.bytes);
        try std.testing.expectEqual(@as(u16, @intCast(index + 1)), archive.header.part_number);
        try std.testing.expectEqual(@as(u16, @intCast(split.parts.len)), archive.header.total_parts);
        try std.testing.expectEqual(@as(u32, 2), archive.header.image_count);
        try std.testing.expectEqual(@as(u32, 0), archive.header.boot_index);
        try std.testing.expect(archive.header.flags & 0x08 != 0);
        try std.testing.expect(!archive.header.xml_data.isZero());
        var local_lookup = try archive.readLookupTableRawAlloc(allocator, 32, 4096);
        defer local_lookup.deinit();
        for (local_lookup.entries) |entry|
            try std.testing.expectEqual(archive.header.part_number, entry.part_number);
    }
    const set = try set_mod.ArchiveSet.init(archives);
    const extracted_large = try set.extractByPathAllocLimited(
        allocator,
        1,
        "large.bin",
        large.len,
        limits,
    );
    defer allocator.free(extracted_large);
    try std.testing.expectEqualSlices(u8, large, extracted_large);
    const extracted_second = try set.extractByPathAllocLimited(
        allocator,
        2,
        "second.bin",
        second_only.len,
        limits,
    );
    defer allocator.free(extracted_second);
    try std.testing.expectEqualSlices(u8, second_only, extracted_second);
    const extracted_shared = try set.extractByPathAllocLimited(
        allocator,
        2,
        "shared.bin",
        shared.len,
        limits,
    );
    defer allocator.free(extracted_shared);
    try std.testing.expectEqualSlices(u8, shared, extracted_shared);
    try std.testing.expectError(
        error.WimResourceInOtherPart,
        archives[0].extractByPathAllocLimited(
            allocator,
            1,
            "large.bin",
            large.len,
            limits,
        ),
    );

    var repeated = try writer.encodeImagesSplitAlloc(
        allocator,
        &images,
        .{ .compression = .stored, .boot_index = 1 },
        .{ .max_part_size = 600 },
    );
    defer repeated.deinit();
    try std.testing.expectEqual(split.parts.len, repeated.parts.len);
    for (split.parts, repeated.parts) |left, right|
        try std.testing.expectEqualSlices(u8, left.bytes, right.bytes);

    const standard = try writer.encodeImagesAlloc(allocator, &images, .{
        .compression = .stored,
        .boot_index = 1,
    });
    defer allocator.free(standard);
    var one_part = try writer.splitArchiveAlloc(allocator, standard, .{
        .max_part_size = std.math.maxInt(usize),
        .integrity = false,
    });
    defer one_part.deinit();
    try std.testing.expectEqual(@as(usize, 1), one_part.parts.len);
    const one = try archive_mod.Archive.init(one_part.parts[0].bytes);
    try std.testing.expectEqual(@as(u32, 1), one.header.boot_index);
    try std.testing.expect(!one.header.boot_metadata.isZero());
    try std.testing.expect(one.header.integrity_table.isZero());
    try std.testing.expect(one.header.flags & 0x08 == 0);
}

test "WIM pipable writer supports seekable and byte-progressive extraction" {
    const allocator = std.testing.allocator;
    const payload = "pipable XPRESS multi-chunk payload\n" ** 3000;
    var random: [70_000]u8 = undefined;
    var prng = std.Random.DefaultPrng.init(0x5049_5045);
    prng.random().bytes(&random);
    const entries = [_]writer.Entry{
        .{ .path = "nested/payload.bin", .data = payload },
        .{ .path = "random.bin", .data = &random },
        .{ .path = "empty" },
    };
    const options: writer.Options = .{
        .compression = .xpress,
        .integrity = false,
        .bootable = true,
    };
    const encoded = try writer.encodePipableAlloc(allocator, &entries, options, .{});
    defer allocator.free(encoded);
    try std.testing.expectEqualSlices(u8, &format.pipable_magic, encoded[0..8]);
    try std.testing.expectEqualSlices(
        u8,
        &format.pipable_magic,
        encoded[encoded.len - format.header_size ..][0..8],
    );
    const leading = try format.parsePipableLeadingHeader(encoded[0..format.header_size]);
    try std.testing.expect(leading.lookup_table.isZero());
    try std.testing.expectEqual(@as(u32, 1), leading.boot_index);
    try std.testing.expectEqual(
        pipable.blob_magic,
        format.readU64(encoded, format.header_size),
    );
    const leading_xml_len: usize = @intCast(format.readU64(
        encoded,
        format.header_size + 8,
    ));
    const leading_xml = encoded[format.header_size + pipable.blob_header_size ..][0..leading_xml_len];
    try std.testing.expectEqual(
        @as(usize, 1),
        countUtf16Ascii(leading_xml, "<TOTALBYTES>"),
    );

    const archive = try archive_mod.Archive.init(encoded);
    try std.testing.expect(archive.header.pipable);
    try std.testing.expectEqual(@as(u32, 1), archive.header.boot_index);
    const final_xml = try archive.readXmlAllocLimited(allocator, 32 * 1024);
    defer allocator.free(final_xml);
    const expected_total = try std.fmt.allocPrint(
        allocator,
        "<TOTALBYTES>{d}</TOTALBYTES></WIM>",
        .{archive.header.xml_data.offset_in_wim - pipable.blob_header_size},
    );
    defer allocator.free(expected_total);
    try std.testing.expect(utf16ContainsAscii(final_xml, expected_total));
    const seekable = try archive.extractByPathAllocLimited(
        allocator,
        1,
        "nested/payload.bin",
        payload.len,
        limits,
    );
    defer allocator.free(seekable);
    try std.testing.expectEqualSlices(u8, payload, seekable);
    const progressive = try extractPipableOneByteAlloc(
        allocator,
        encoded,
        1,
        "nested/payload.bin",
        payload.len,
    );
    defer allocator.free(progressive);
    try std.testing.expectEqualSlices(u8, payload, progressive);

    const standard = try writer.encodeAlloc(allocator, &entries, options);
    defer allocator.free(standard);
    const converted = try writer.toPipableAlloc(allocator, standard, .{});
    defer allocator.free(converted);
    try std.testing.expectEqualSlices(u8, encoded, converted);

    const with_integrity = try writer.toPipableAlloc(allocator, standard, .{
        .integrity = true,
    });
    defer allocator.free(with_integrity);
    const integrity_archive = try archive_mod.Archive.init(with_integrity);
    try std.testing.expect(!integrity_archive.header.integrity_table.isZero());

    const too_small = try allocator.alloc(u8, encoded.len - 1);
    defer allocator.free(too_small);
    @memset(too_small, 0xa5);
    try std.testing.expectError(
        error.OutputTooSmall,
        writer.encodePipableInto(allocator, &entries, too_small, options, .{}),
    );
    try std.testing.expect(std.mem.allEqual(u8, too_small, 0xa5));
    try std.testing.expectError(
        error.UnsupportedPipableWimInput,
        writer.toPipableAlloc(allocator, encoded, .{}),
    );
}

test "WIM pipable split writer streams across concatenated SWM parts" {
    const allocator = std.testing.allocator;
    const large = "L" ** 700;
    const shared = "S" ** 300;
    const second_only = "T" ** 400;
    const first_entries = [_]writer.Entry{
        .{ .path = "large.bin", .data = large },
        .{ .path = "shared.bin", .data = shared },
    };
    const second_entries = [_]writer.Entry{
        .{ .path = "second.bin", .data = second_only },
        .{ .path = "shared.bin", .data = shared },
    };
    const images = [_]writer.Image{
        .{ .name = "first", .entries = &first_entries },
        .{ .name = "second", .entries = &second_entries },
    };
    var split = try writer.encodeImagesPipableSplitAlloc(
        allocator,
        &images,
        .{ .compression = .stored, .boot_index = 2 },
        .{ .max_part_size = 600 },
        .{},
    );
    defer split.deinit();
    try std.testing.expect(split.parts.len >= 3);
    const archives = try allocator.alloc(archive_mod.Archive, split.parts.len);
    defer allocator.free(archives);
    var concatenated: std.ArrayList(u8) = .empty;
    defer concatenated.deinit(allocator);
    for (split.parts, archives, 0..) |part, *archive, index| {
        archive.* = try archive_mod.Archive.init(part.bytes);
        try std.testing.expect(archive.header.pipable);
        try std.testing.expectEqual(@as(u16, @intCast(index + 1)), archive.header.part_number);
        try std.testing.expectEqual(@as(u16, @intCast(split.parts.len)), archive.header.total_parts);
        try std.testing.expectEqual(@as(u32, 0), archive.header.boot_index);
        try concatenated.appendSlice(allocator, part.bytes);
    }
    const set = try set_mod.ArchiveSet.init(archives);
    const seekable = try set.extractByPathAllocLimited(
        allocator,
        2,
        "second.bin",
        second_only.len,
        limits,
    );
    defer allocator.free(seekable);
    try std.testing.expectEqualSlices(u8, second_only, seekable);
    const progressive = try extractPipableOneByteAlloc(
        allocator,
        concatenated.items,
        2,
        "second.bin",
        second_only.len,
    );
    defer allocator.free(progressive);
    try std.testing.expectEqualSlices(u8, second_only, progressive);
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
            .compression = .lzx,
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
    const duplicate_streams = [_]writer.NamedStream{
        .{ .name = "Name" },
        .{ .name = "name" },
    };
    const duplicate_named = [_]writer.Entry{.{
        .path = "named",
        .named_streams = &duplicate_streams,
    }};
    try std.testing.expectError(
        error.InvalidWimEntry,
        writer.encodeAlloc(std.testing.allocator, &duplicate_named, .{}),
    );
    const invalid_named_stream = [_]writer.NamedStream{.{ .name = "bad/name" }};
    const invalid_named = [_]writer.Entry{.{
        .path = "named",
        .named_streams = &invalid_named_stream,
    }};
    try std.testing.expectError(
        error.InvalidWimEntry,
        writer.encodeAlloc(std.testing.allocator, &invalid_named, .{}),
    );
    const invalid_encrypted = [_]writer.Entry{.{
        .path = "encrypted",
        .data = "plaintext",
        .encrypted_raw = "raw",
    }};
    try std.testing.expectError(
        error.InvalidWimEntry,
        writer.encodeAlloc(std.testing.allocator, &invalid_encrypted, .{}),
    );
    const empty_encrypted = [_]writer.Entry{.{
        .path = "encrypted",
        .encrypted_raw = "",
    }};
    try std.testing.expectError(
        error.InvalidWimEntry,
        writer.encodeAlloc(std.testing.allocator, &empty_encrypted, .{}),
    );
    const invalid_reparse = [_]writer.Entry{.{
        .path = "reparse",
        .reparse = .{ .tag = 0, .data = "raw" },
    }};
    try std.testing.expectError(
        error.InvalidWimEntry,
        writer.encodeAlloc(std.testing.allocator, &invalid_reparse, .{}),
    );
    const singleton_link = [_]writer.Entry{.{
        .path = "one",
        .hard_link_id = 1,
    }};
    try std.testing.expectError(
        error.InvalidWimEntry,
        writer.encodeAlloc(std.testing.allocator, &singleton_link, .{}),
    );
    const mismatched_links = [_]writer.Entry{
        .{ .path = "one", .data = "a", .hard_link_id = 1 },
        .{ .path = "two", .data = "b", .hard_link_id = 1 },
    };
    try std.testing.expectError(
        error.InvalidWimEntry,
        writer.encodeAlloc(std.testing.allocator, &mismatched_links, .{}),
    );
    const reparse_link = [_]writer.Entry{
        .{
            .path = "one",
            .hard_link_id = 1,
            .reparse = .{ .tag = 1, .data = "x" },
        },
        .{
            .path = "two",
            .hard_link_id = 1,
            .reparse = .{ .tag = 1, .data = "x" },
        },
    };
    try std.testing.expectError(
        error.InvalidWimEntry,
        writer.encodeAlloc(std.testing.allocator, &reparse_link, .{}),
    );
    const invalid_descriptor = [_]u8{ 1, 0, 0, 0 } ++ [_]u8{0} ** 16;
    const descriptor_entry = [_]writer.Entry{.{
        .path = "descriptor",
        .security_descriptor = &invalid_descriptor,
    }};
    try std.testing.expectError(
        error.InvalidWimEntry,
        writer.encodeAlloc(std.testing.allocator, &descriptor_entry, .{}),
    );
    try std.testing.expectError(
        error.InvalidWimWriterOptions,
        writer.encodeImagesAlloc(std.testing.allocator, &.{}, .{}),
    );
    const empty_image = [_]writer.Image{.{ .name = "one", .entries = &.{} }};
    try std.testing.expectError(
        error.InvalidWimWriterOptions,
        writer.encodeImagesAlloc(std.testing.allocator, &empty_image, .{
            .boot_index = 2,
        }),
    );
    const duplicate_images = [_]writer.Image{
        .{ .name = "Same", .entries = &.{} },
        .{ .name = "same", .entries = &.{} },
    };
    try std.testing.expectError(
        error.InvalidWimWriterOptions,
        writer.encodeImagesAlloc(std.testing.allocator, &duplicate_images, .{}),
    );
    try std.testing.expectError(
        error.InvalidWimSplitOptions,
        writer.encodeSplitAlloc(std.testing.allocator, &.{}, .{}, .{
            .max_part_size = 0,
        }),
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
            const descriptor = [_]u8{ 1, 0, 4, 0x80 } ++ [_]u8{0} ** 16;
            const entries = [_]writer.Entry{
                .{
                    .path = "nested/data.txt",
                    .data = "allocation failure coverage",
                    .named_streams = &.{.{
                        .name = "Zone.Identifier",
                        .data = "zone",
                    }},
                },
                .{
                    .path = "link",
                    .reparse = .{ .tag = 1, .data = "reparse" },
                },
                .{ .path = "encrypted", .encrypted_raw = "opaque" },
                .{
                    .path = "hard/a",
                    .data = "linked",
                    .security_descriptor = &descriptor,
                    .hard_link_id = 1,
                },
                .{
                    .path = "hard/b",
                    .data = "linked",
                    .security_descriptor = &descriptor,
                    .hard_link_id = 1,
                },
                .{ .path = "empty" },
            };
            const encoded = try writer.encodeAlloc(allocator, &entries, .{
                .compression = .stored,
                .root_security_descriptor = &descriptor,
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

test "WIM LZX writer is allocation failure safe" {
    const AllocationTest = struct {
        fn run(allocator: std.mem.Allocator) !void {
            const entries = [_]writer.Entry{.{
                .path = "repetitive.bin",
                .data = "WIM LZX allocation coverage\n" ** 128,
            }};
            const encoded = try writer.encodeAlloc(allocator, &entries, .{
                .compression = .lzx,
                .integrity = false,
            });
            defer allocator.free(encoded);
            const archive = try archive_mod.Archive.init(encoded);
            const extracted = try archive.extractByPathAllocLimited(
                allocator,
                1,
                "repetitive.bin",
                16 * 1024,
                limits,
            );
            defer allocator.free(extracted);
        }
    };
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        AllocationTest.run,
        .{},
    );
}

test "WIM multi-image writer is allocation failure safe" {
    const AllocationTest = struct {
        fn run(allocator: std.mem.Allocator) !void {
            const first = [_]writer.Entry{.{ .path = "shared", .data = "same" }};
            const second = [_]writer.Entry{
                .{ .path = "shared", .data = "same" },
                .{ .path = "other", .data = "different" },
            };
            const images = [_]writer.Image{
                .{ .name = "first", .entries = &first },
                .{ .name = "second", .entries = &second },
            };
            const encoded = try writer.encodeImagesAlloc(allocator, &images, .{
                .compression = .stored,
                .boot_index = 1,
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

test "WIM split writer is allocation failure safe" {
    const AllocationTest = struct {
        fn run(allocator: std.mem.Allocator) !void {
            const entries = [_]writer.Entry{
                .{ .path = "a", .data = "a" ** 256 },
                .{ .path = "b", .data = "b" ** 256 },
            };
            var split = try writer.encodeSplitAlloc(
                allocator,
                &entries,
                .{ .compression = .stored },
                .{ .max_part_size = 300 },
            );
            defer split.deinit();
            try std.testing.expect(split.parts.len >= 2);
        }
    };
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        AllocationTest.run,
        .{},
    );
}

test "WIM pipable writer is allocation failure safe" {
    const AllocationTest = struct {
        fn run(allocator: std.mem.Allocator) !void {
            const entries = [_]writer.Entry{
                .{ .path = "nested/data", .data = "pipable OOM" ** 64 },
                .{ .path = "empty" },
            };
            const encoded = try writer.encodePipableAlloc(
                allocator,
                &entries,
                .{ .compression = .xpress },
                .{},
            );
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

test "WIM pipable split writer is allocation failure safe" {
    const AllocationTest = struct {
        fn run(allocator: std.mem.Allocator) !void {
            const entries = [_]writer.Entry{
                .{ .path = "a", .data = "a" ** 256 },
                .{ .path = "b", .data = "b" ** 256 },
            };
            var split = try writer.encodePipableSplitAlloc(
                allocator,
                &entries,
                .{ .compression = .stored },
                .{ .max_part_size = 300 },
                .{},
            );
            defer split.deinit();
            try std.testing.expect(split.parts.len >= 2);
        }
    };
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        AllocationTest.run,
        .{},
    );
}

fn utf16ContainsAscii(utf16: []const u8, ascii: []const u8) bool {
    if (ascii.len == 0) return true;
    if (utf16.len < ascii.len * 2) return false;
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
        if (matches) return true;
    }
    return false;
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

fn extractPipableOneByteAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    image_index: u32,
    path: []const u8,
    expected_len: usize,
) ![]u8 {
    var extractor = pipable_stream.PathExtractor.init(allocator, .{
        .image_index = image_index,
        .path = path,
        .max_output_len = expected_len,
        .limits = .{
            .max_metadata_bytes = 1024 * 1024,
            .max_directory_entries = 64,
            .max_path_depth = 16,
            .max_chunk_bytes = 64 * 1024,
        },
    });
    defer extractor.deinit();
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    var input_offset: usize = 0;
    var scratch: [17]u8 = undefined;
    while (true) {
        const input_end = @min(input.len, input_offset + 1);
        const step = try extractor.step(input[input_offset..input_end], &scratch);
        input_offset += step.progress.input_read;
        try output.appendSlice(allocator, scratch[0..step.progress.output_written]);
        switch (step.status) {
            .done => break,
            .need_input => if (input_offset == input.len) {
                try extractor.finish();
                return error.TruncatedFrame;
            },
            .need_output => {},
        }
    }
    try std.testing.expectEqual(expected_len, output.items.len);
    return output.toOwnedSlice(allocator);
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
