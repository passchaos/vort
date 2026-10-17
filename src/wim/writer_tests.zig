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
