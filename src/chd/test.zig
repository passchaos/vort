const std = @import("std");
const archive_mod = @import("archive.zig");
const bzip2 = @import("../bzip2.zig");
const format = @import("format.zig");
const writer = @import("writer.zig");

test "CHD v5 decodes pinned chdman LZMA Huffman and Zstd hunks" {
    const allocator = std.testing.allocator;
    const cases = .{
        .{ "testdata/chdman-0.289-lzma.chd.bz2.b64", format.Codec.lzma },
        .{ "testdata/chdman-0.289-huff.chd.bz2.b64", format.Codec.huffman },
        .{ "testdata/chdman-0.289-zstd.chd.bz2.b64", format.Codec.zstd },
    };
    inline for (cases) |case| {
        const image = try decodeFixture(case[0], 64 * 1024);
        defer allocator.free(image);
        var archive = try archive_mod.Archive.initAlloc(allocator, image, .{});
        defer archive.deinit();
        try std.testing.expectEqual(case[1], try archive.header.codec(0));
        try std.testing.expectEqual(@as(usize, 8), archive.map.len);
        try std.testing.expectEqual(format.MapType.self, archive.map[3].kind);
        try std.testing.expectEqual(format.MapType.self, archive.map[5].kind);
        const decoded = try archive.decodeAllocLimited(allocator, 32768);
        defer allocator.free(decoded);
        try expectPinnedDigest(decoded);
    }
}

test "CHD v5 decodes pinned chdman metadata and parent map" {
    const allocator = std.testing.allocator;
    const parent_image = try decodeFixture(
        "testdata/chdman-0.289-parent.chd.bz2.b64",
        64 * 1024,
    );
    defer allocator.free(parent_image);
    var parent = try archive_mod.Archive.initAlloc(allocator, parent_image, .{});
    defer parent.deinit();
    try std.testing.expectEqual(@as(usize, 1), parent.metadata.len);
    try std.testing.expectEqual(format.tag("GDDD"), parent.metadata[0].tag);
    try std.testing.expectEqualStrings(
        "CYLS:1,HEADS:2,SECS:32,BPS:512\x00",
        parent.metadata[0].data,
    );

    const child_image = try decodeFixture(
        "testdata/chdman-0.289-child.chd.bz2.b64",
        4096,
    );
    defer allocator.free(child_image);
    try std.testing.expectError(
        error.MissingChdParent,
        archive_mod.Archive.initAlloc(allocator, child_image, .{}),
    );
    var child = try archive_mod.Archive.initAlloc(allocator, child_image, .{
        .parent = &parent,
    });
    defer child.deinit();
    for (child.map) |entry|
        try std.testing.expectEqual(format.MapType.parent, entry.kind);
    const decoded = try child.decodeAllocLimited(allocator, 32768);
    defer allocator.free(decoded);
    try expectPinnedDigest(decoded);

    const corrupt_metadata = try allocator.dupe(u8, child_image);
    defer allocator.free(corrupt_metadata);
    const metadata_offset: usize = @intCast(format.readU64Be(corrupt_metadata, 48));
    corrupt_metadata[metadata_offset + format.metadata_header_size] ^= 1;
    var corrupt_child = try archive_mod.Archive.initAlloc(
        allocator,
        corrupt_metadata,
        .{ .parent = &parent },
    );
    defer corrupt_child.deinit();
    try std.testing.expectError(
        error.ChecksumMismatch,
        corrupt_child.decodeAllocLimited(allocator, 32768),
    );

    const shifted_image = try decodeFixture(
        "testdata/chdman-0.289-shifted-child.chd.bz2.b64",
        8192,
    );
    defer allocator.free(shifted_image);
    var shifted = try archive_mod.Archive.initAlloc(allocator, shifted_image, .{
        .parent = &parent,
    });
    defer shifted.deinit();
    for (shifted.map[0..7], 0..) |entry, index| {
        try std.testing.expectEqual(format.MapType.parent, entry.kind);
        try std.testing.expectEqual(@as(u64, index * 8 + 1), entry.offset);
    }
    try std.testing.expectEqual(format.MapType.codec_0, shifted.map[7].kind);
    const shifted_decoded = try shifted.decodeAllocLimited(allocator, 32768);
    defer allocator.free(shifted_decoded);
    var shifted_digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(shifted_decoded, &shifted_digest, .{});
    var expected_shifted_digest: [32]u8 = undefined;
    _ = try std.fmt.hexToBytes(
        &expected_shifted_digest,
        "230a29790c7b8ed672ba4edc49eb47fc9e810d9fb4488809664555a9052a89cb",
    );
    try std.testing.expectEqual(expected_shifted_digest, shifted_digest);
}

test "CHD v5 writer round trips every compression mode" {
    const allocator = std.testing.allocator;
    const input = try allocator.alloc(u8, 4096 * 4 + 137);
    defer allocator.free(input);
    @memset(input, 0);
    @memcpy(input[0..4096], ("Vort CHD payload\n" ** 256)[0..4096]);
    @memcpy(input[4096 * 2 .. 4096 * 3], input[0..4096]);
    var random = std.Random.DefaultPrng.init(0x43484435);
    random.fill(input[4096 * 3 ..]);

    inline for (.{
        writer.Compression.none,
        writer.Compression.zlib,
        writer.Compression.lzma,
        writer.Compression.huffman,
        writer.Compression.zstd,
        writer.Compression.auto,
    }) |compression| {
        const encoded = try writer.encodeAlloc(allocator, input, .{
            .compression = compression,
        });
        defer allocator.free(encoded);
        var archive = try archive_mod.Archive.initAlloc(allocator, encoded, .{});
        defer archive.deinit();
        const decoded = try archive.decodeAllocLimited(allocator, input.len);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
        if (compression == .auto) {
            try std.testing.expectEqual(
                [_]u32{
                    @intFromEnum(format.Codec.zlib),
                    @intFromEnum(format.Codec.lzma),
                    @intFromEnum(format.Codec.huffman),
                    @intFromEnum(format.Codec.zstd),
                },
                archive.header.compressors,
            );
        } else if (compression != .none) {
            const expected: format.Codec = switch (compression) {
                .zlib => .zlib,
                .lzma => .lzma,
                .huffman => .huffman,
                .zstd => .zstd,
                else => unreachable,
            };
            try std.testing.expectEqual(expected, try archive.header.codec(0));
        }

        const range = try archive.readRangeAllocLimited(
            allocator,
            4011,
            5000,
            5000,
        );
        defer allocator.free(range);
        try std.testing.expectEqualSlices(u8, input[4011..9011], range);
        if (compression != .none) {
            try std.testing.expectEqual(format.MapType.self, archive.map[2].kind);
            try std.testing.expectEqual(@as(u64, 0), archive.map[2].offset);
        }
    }
}

test "CHD v5 LZMA writer supports hunks above its match-finder window" {
    const allocator = std.testing.allocator;
    const input = ("large CHD LZMA hunk payload 0123456789\n" ** 4096)[0..70_000];
    const encoded = try writer.encodeAlloc(allocator, input, .{
        .compression = .lzma,
        .hunk_bytes = 128 * 1024,
        .unit_bytes = 512,
    });
    defer allocator.free(encoded);
    var archive = try archive_mod.Archive.initAlloc(allocator, encoded, .{});
    defer archive.deinit();
    try std.testing.expectEqual(format.Codec.lzma, try archive.header.codec(0));
    try std.testing.expectEqual(format.MapType.codec_0, archive.map[0].kind);
    const decoded = try archive.decodeAllocLimited(allocator, input.len);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}

test "CHD v5 auto writer selects every codec slot raw and self" {
    const allocator = std.testing.allocator;
    const hunk_bytes = 4096;
    const input = try allocator.alloc(u8, 6 * hunk_bytes);
    defer allocator.free(input);
    var prng = std.Random.DefaultPrng.init(0x434844);
    for (input[0..hunk_bytes]) |*byte|
        byte.* = if (prng.random().boolean()) 'A' else 'B';
    for (input[hunk_bytes .. 2 * hunk_bytes], 0..) |*byte, index|
        byte.* = if (index % 10 == 0) @truncate(index * 31) else 0;
    for (input[2 * hunk_bytes .. 3 * hunk_bytes], 0..) |*byte, index|
        byte.* = @truncate((index * 17 + index / 19) % 13);
    for (input[3 * hunk_bytes .. 4 * hunk_bytes], 0..) |*byte, index|
        byte.* = @truncate(index / 16);
    prng.random().bytes(input[4 * hunk_bytes .. 5 * hunk_bytes]);
    @memcpy(input[5 * hunk_bytes .. 6 * hunk_bytes], input[0..hunk_bytes]);

    const encoded = try writer.encodeAlloc(allocator, input, .{
        .compression = .auto,
    });
    defer allocator.free(encoded);
    var archive = try archive_mod.Archive.initAlloc(allocator, encoded, .{});
    defer archive.deinit();
    var kinds: [6]format.MapType = undefined;
    for (archive.map, 0..) |entry, index| kinds[index] = entry.kind;
    try std.testing.expectEqualSlices(format.MapType, &.{
        .codec_2,
        .codec_3,
        .codec_0,
        .codec_1,
        .uncompressed,
        .self,
    }, &kinds);
    const decoded = try archive.decodeAllocLimited(allocator, input.len);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}

test "CHD v5 writer handles empty and partial hunks" {
    const allocator = std.testing.allocator;
    inline for (.{
        writer.Compression.none,
        writer.Compression.auto,
    }) |compression| {
        const empty = try writer.encodeAlloc(allocator, "", .{
            .compression = compression,
        });
        defer allocator.free(empty);
        var empty_archive = try archive_mod.Archive.initAlloc(allocator, empty, .{});
        defer empty_archive.deinit();
        const decoded_empty = try empty_archive.decodeAllocLimited(allocator, 0);
        defer allocator.free(decoded_empty);
        try std.testing.expectEqual(@as(usize, 0), decoded_empty.len);

        const encoded = try writer.encodeAlloc(allocator, "partial", .{
            .compression = compression,
            .hunk_bytes = 4096,
            .unit_bytes = 512,
        });
        defer allocator.free(encoded);
        var archive = try archive_mod.Archive.initAlloc(allocator, encoded, .{});
        defer archive.deinit();
        const decoded = try archive.decodeAllocLimited(allocator, 7);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, "partial", decoded);
    }
}

test "CHD v5 compressed map and hunk corruption are detected" {
    const allocator = std.testing.allocator;
    var input: [4096]u8 = undefined;
    var random = std.Random.DefaultPrng.init(0x4348_4443_5243);
    random.fill(&input);
    const encoded = try writer.encodeAlloc(
        allocator,
        &input,
        .{ .compression = .auto },
    );
    defer allocator.free(encoded);

    const bad_map = try allocator.dupe(u8, encoded);
    defer allocator.free(bad_map);
    const map_offset: usize = @intCast(format.readU64Be(bad_map, 40));
    bad_map[map_offset + 10] ^= 1;
    try std.testing.expectError(
        error.ChecksumMismatch,
        archive_mod.Archive.initAlloc(allocator, bad_map, .{}),
    );

    const bad_hunk = try allocator.dupe(u8, encoded);
    defer allocator.free(bad_hunk);
    var original = try archive_mod.Archive.initAlloc(allocator, encoded, .{});
    defer original.deinit();
    try std.testing.expectEqual(format.MapType.uncompressed, original.map[0].kind);
    bad_hunk[format.header_size] ^= 1;
    var archive = try archive_mod.Archive.initAlloc(allocator, bad_hunk, .{});
    defer archive.deinit();
    try std.testing.expectError(
        error.ChecksumMismatch,
        archive.decodeAllocLimited(allocator, 1 << 20),
    );
}

test "CHD v5 writer emits linked checksummed metadata" {
    const allocator = std.testing.allocator;
    const input = "CHD metadata writer payload\n" ** 256;
    const metadata = [_]writer.EncodeMetadata{
        .{ .tag = format.tag("TEST"), .data = "checked-second" },
        .{ .tag = format.tag("AAAA"), .data = "checked-first" },
        .{
            .tag = format.tag("NOTE"),
            .flags = 0,
            .data = "not-in-overall-sha1",
        },
    };
    try std.testing.expectError(
        error.OutputLimitExceeded,
        writer.encodeAlloc(allocator, input, .{
            .metadata = &metadata,
            .max_metadata_entries = 2,
        }),
    );
    inline for (.{ writer.Compression.none, writer.Compression.auto }) |compression| {
        const encoded = try writer.encodeAlloc(allocator, input, .{
            .compression = compression,
            .metadata = &metadata,
        });
        defer allocator.free(encoded);
        var archive = try archive_mod.Archive.initAlloc(allocator, encoded, .{});
        defer archive.deinit();
        try std.testing.expectEqual(@as(usize, metadata.len), archive.metadata.len);
        for (archive.metadata, metadata) |actual, expected| {
            try std.testing.expectEqual(expected.tag, actual.tag);
            try std.testing.expectEqual(expected.flags, actual.flags);
            try std.testing.expectEqualSlices(u8, expected.data, actual.data);
        }
        const decoded = try archive.decodeAllocLimited(allocator, input.len);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);

        const corrupt_checked = try allocator.dupe(u8, encoded);
        defer allocator.free(corrupt_checked);
        const first_metadata: usize = @intCast(format.readU64Be(corrupt_checked, 48));
        corrupt_checked[first_metadata + format.metadata_header_size] ^= 1;
        var corrupt_archive = try archive_mod.Archive.initAlloc(
            allocator,
            corrupt_checked,
            .{},
        );
        defer corrupt_archive.deinit();
        try std.testing.expectError(
            error.ChecksumMismatch,
            corrupt_archive.decodeAllocLimited(allocator, input.len),
        );

        const corrupt_unchecked = try allocator.dupe(u8, encoded);
        defer allocator.free(corrupt_unchecked);
        corrupt_unchecked[archive.metadata[2].offset + format.metadata_header_size] ^= 1;
        var unchecked_archive = try archive_mod.Archive.initAlloc(
            allocator,
            corrupt_unchecked,
            .{},
        );
        defer unchecked_archive.deinit();
        const unchecked_decoded = try unchecked_archive.decodeAllocLimited(
            allocator,
            input.len,
        );
        defer allocator.free(unchecked_decoded);
        try std.testing.expectEqualSlices(u8, input, unchecked_decoded);
    }
}

test "CHD v5 writer emits compressed parent hunk references" {
    const allocator = std.testing.allocator;
    const hunk_bytes = 4096;
    const parent_input = try allocator.alloc(u8, 4 * hunk_bytes);
    defer allocator.free(parent_input);
    for (0..4) |hunk|
        @memset(parent_input[hunk * hunk_bytes ..][0..hunk_bytes], @intCast('A' + hunk));
    const parent_encoded = try writer.encodeAlloc(allocator, parent_input, .{
        .compression = .auto,
    });
    defer allocator.free(parent_encoded);
    var parent = try archive_mod.Archive.initAlloc(allocator, parent_encoded, .{});
    defer parent.deinit();

    try std.testing.expectError(
        error.OutputLimitExceeded,
        writer.encodeAlloc(allocator, parent_input, .{
            .parent = &parent,
            .max_parent_hunks = 3,
        }),
    );

    const child_input = try allocator.alloc(u8, 4 * hunk_bytes);
    defer allocator.free(child_input);
    @memcpy(child_input[0 * hunk_bytes ..][0..hunk_bytes], parent_input[2 * hunk_bytes ..][0..hunk_bytes]);
    @memcpy(child_input[1 * hunk_bytes ..][0..hunk_bytes], parent_input[0 * hunk_bytes ..][0..hunk_bytes]);
    @memset(child_input[2 * hunk_bytes ..][0..hunk_bytes], 'E');
    @memcpy(child_input[3 * hunk_bytes ..][0..hunk_bytes], parent_input[2 * hunk_bytes ..][0..hunk_bytes]);
    const child_encoded = try writer.encodeAlloc(allocator, child_input, .{
        .compression = .auto,
        .parent = &parent,
    });
    defer allocator.free(child_encoded);
    try std.testing.expectError(
        error.MissingChdParent,
        archive_mod.Archive.initAlloc(allocator, child_encoded, .{}),
    );
    var child = try archive_mod.Archive.initAlloc(allocator, child_encoded, .{
        .parent = &parent,
    });
    defer child.deinit();
    try std.testing.expectEqualSlices(u8, &parent.header.combined_sha1, &child.header.parent_sha1);
    try std.testing.expectEqual(format.MapType.parent, child.map[0].kind);
    try std.testing.expectEqual(format.MapType.parent, child.map[1].kind);
    try std.testing.expect(@intFromEnum(child.map[2].kind) <= @intFromEnum(format.MapType.uncompressed));
    try std.testing.expectEqual(format.MapType.parent, child.map[3].kind);
    try std.testing.expectEqual(@as(u64, 16), child.map[0].offset);
    try std.testing.expectEqual(@as(u64, 0), child.map[1].offset);
    try std.testing.expectEqual(@as(u64, 16), child.map[3].offset);
    const decoded = try child.decodeAllocLimited(allocator, child_input.len);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, child_input, decoded);
}

test "CHD v5 uncompressed parent map stores explicit zero overrides" {
    const allocator = std.testing.allocator;
    const hunk_bytes = 4096;
    const parent_input = ("parent raw hunk bytes\n" ** 512)[0 .. 2 * hunk_bytes];
    const parent_encoded = try writer.encodeAlloc(allocator, parent_input, .{
        .compression = .auto,
    });
    defer allocator.free(parent_encoded);
    var parent = try archive_mod.Archive.initAlloc(allocator, parent_encoded, .{});
    defer parent.deinit();
    const child_input = try allocator.alloc(u8, 2 * hunk_bytes);
    defer allocator.free(child_input);
    @memcpy(child_input[0..hunk_bytes], parent_input[0..hunk_bytes]);
    @memset(child_input[hunk_bytes..], 0);
    const child_encoded = try writer.encodeAlloc(allocator, child_input, .{
        .compression = .none,
        .parent = &parent,
    });
    defer allocator.free(child_encoded);
    var child = try archive_mod.Archive.initAlloc(allocator, child_encoded, .{
        .parent = &parent,
    });
    defer child.deinit();
    try std.testing.expectEqual(@as(u64, 0), child.map[0].offset);
    try std.testing.expect(child.map[1].offset != 0);
    const decoded = try child.decodeAllocLimited(allocator, child_input.len);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, child_input, decoded);
}

fn decodeFixture(comptime path: []const u8, max_output: usize) ![]u8 {
    const allocator = std.testing.allocator;
    const text = @embedFile(path);
    const base64 = std.base64.standard.decoderWithIgnore(" \r\n\t");
    const encoded = try allocator.alloc(u8, base64.calcSizeUpperBound(text.len));
    defer allocator.free(encoded);
    const encoded_len = try base64.decode(encoded, text);
    return bzip2.decodeAllocLimited(
        allocator,
        encoded[0..encoded_len],
        max_output,
    );
}

fn expectPinnedDigest(input: []const u8) !void {
    var actual: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(input, &actual, .{});
    var expected: [32]u8 = undefined;
    _ = try std.fmt.hexToBytes(
        &expected,
        "0dcde7c94a6d08ba49304eb929e45dbf9460e018db91060efd692cd516750824",
    );
    try std.testing.expectEqual(expected, actual);
}
