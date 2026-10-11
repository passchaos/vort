const std = @import("std");
const bzip2 = @import("../bzip2.zig");
const archive_mod = @import("archive.zig");
const format = @import("format.zig");
const wii = @import("wii_partition.zig");
const writer = @import("writer.zig");

const allocator = std.testing.allocator;

test "WIA reconstructs independently generated encrypted Wii partition" {
    const text = @embedFile("testdata/python-partition-bzip2.wia.bz2.b64");
    const image = try decodeFixtureAlloc(text, 3 * 1024 * 1024);
    defer allocator.free(image);
    try expectSha256(
        image,
        "1380f2ef05967e11ef608b249b7211f3952880101e9f1698c60d1b71ae3c7c27",
    );

    var archive = try archive_mod.Archive.initAlloc(allocator, image, .{});
    defer archive.deinit();
    try std.testing.expectEqual(@as(usize, 1), archive.partitions.len);
    const decoded = try archive.decodeAllocLimited(allocator, 3 * 1024 * 1024);
    defer allocator.free(decoded);
    try expectSha256(
        decoded,
        "7ed1e69506a89dc1455c8b4dc50d79469fe1b921d6b73beb070549ea55f6bc54",
    );

    const range = try archive.readRangeAllocLimited(
        allocator,
        format.wii_block_size - 37,
        format.wii_block_size + 91,
        format.wii_block_size + 91,
    );
    defer allocator.free(range);
    try std.testing.expectEqualSlices(
        u8,
        decoded[format.wii_block_size - 37 ..][0 .. format.wii_block_size + 91],
        range,
    );
}

test "RVZ reconstructs Wii hash exceptions from small partition chunks" {
    const text = @embedFile("testdata/python-partition-smallchunks.rvz.bz2.b64");
    const image = try decodeFixtureAlloc(text, 3 * 1024 * 1024);
    defer allocator.free(image);
    try expectSha256(
        image,
        "d6c151201f0ca55ad24ff454742848c8b6b0909b590f4f357f7f3d3e1f8010c6",
    );

    var archive = try archive_mod.Archive.initAlloc(allocator, image, .{});
    defer archive.deinit();
    try std.testing.expectEqual(format.Container.rvz, archive.header1.container);
    try std.testing.expectEqual(@as(u32, 128 * 1024), archive.header2.chunk_size);
    try std.testing.expectEqual(@as(usize, 1), archive.partitions.len);
    try std.testing.expectEqual(
        @as(usize, 16),
        archive.partitions[0].data[0].group_count,
    );
    try std.testing.expectEqual(@as(usize, 17), archive.groups.len);
    const decoded = try archive.decodeAllocLimited(allocator, 3 * 1024 * 1024);
    defer allocator.free(decoded);
    try expectSha256(
        decoded,
        "5366ef2365a409b77a272f5932ee488dba52e03f10cf39f92e13b50bd8e44ef7",
    );

    // The fixture's exception belongs to sector 12, which is subchunk 3 of
    // the first reconstructed Wii group. Exercise that boundary directly.
    const range_offset = 13 * format.wii_block_size - 37;
    const range_length = 2 * format.wii_block_size + 91;
    const range = try archive.readRangeAllocLimited(
        allocator,
        range_offset,
        range_length,
        range_length,
    );
    defer allocator.free(range);
    try std.testing.expectEqualSlices(
        u8,
        decoded[range_offset..][0..range_length],
        range,
    );
}

test "WIA and RVZ partition writers preserve encrypted Wii sectors" {
    const text = @embedFile("testdata/python-partition-smallchunks.rvz.bz2.b64");
    const fixture = try decodeFixtureAlloc(text, 3 * 1024 * 1024);
    defer allocator.free(fixture);
    var source_archive = try archive_mod.Archive.initAlloc(
        allocator,
        fixture,
        .{},
    );
    defer source_archive.deinit();
    const source = try source_archive.decodeAllocLimited(
        allocator,
        3 * 1024 * 1024,
    );
    defer allocator.free(source);
    const source_partition = source_archive.partitions[0];
    const partition = writer.Partition{
        .key = source_partition.key,
        .data = .{
            .{
                .offset = source_partition.data[0].logicalOffset(),
                .size = source_partition.data[0].logicalSize(),
            },
            .{ .offset = 0, .size = 0 },
        },
    };

    inline for (.{
        .{ format.Container.wia, format.Compression.none, @as(u32, 2 * 1024 * 1024) },
        .{ format.Container.wia, format.Compression.purge, @as(u32, 2 * 1024 * 1024) },
        .{ format.Container.wia, format.Compression.bzip2, @as(u32, 2 * 1024 * 1024) },
        .{ format.Container.wia, format.Compression.lzma, @as(u32, 2 * 1024 * 1024) },
        .{ format.Container.wia, format.Compression.lzma2, @as(u32, 2 * 1024 * 1024) },
        .{ format.Container.rvz, format.Compression.none, @as(u32, 128 * 1024) },
        .{ format.Container.rvz, format.Compression.bzip2, @as(u32, 128 * 1024) },
        .{ format.Container.rvz, format.Compression.lzma, @as(u32, 128 * 1024) },
        .{ format.Container.rvz, format.Compression.lzma2, @as(u32, 128 * 1024) },
        .{ format.Container.rvz, format.Compression.zstd, @as(u32, 128 * 1024) },
    }) |case| {
        const encoded = try writer.encodeWithPartitionsAlloc(
            allocator,
            source,
            &.{partition},
            .{
                .container = case[0],
                .compression = case[1],
                .compression_level = if (case[1] == .zstd) 5 else 6,
                .chunk_size = case[2],
            },
        );
        defer allocator.free(encoded);
        var archive = try archive_mod.Archive.initAlloc(allocator, encoded, .{});
        defer archive.deinit();
        try std.testing.expectEqual(@as(usize, 1), archive.partitions.len);
        try std.testing.expectEqual(case[0], archive.header1.container);
        try std.testing.expectEqual(case[1], archive.header2.compression);
        const decoded = try archive.decodeAllocLimited(
            allocator,
            source.len,
        );
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, source, decoded);
    }
}

test "WIA partition writer rejects invalid layouts" {
    const input = [_]u8{0} ** (3 * format.wii_block_size);
    const key: [16]u8 = @splat(0);
    try std.testing.expectError(
        error.InvalidWia,
        writer.encodeWithPartitionsAlloc(
            allocator,
            &input,
            &.{.{
                .key = key,
                .data = .{
                    .{ .offset = format.wii_block_size + 1, .size = format.wii_block_size },
                    .{ .offset = 0, .size = 0 },
                },
            }},
            .{},
        ),
    );
    try std.testing.expectError(
        error.OutputLimitExceeded,
        writer.encodeWithPartitionsAlloc(
            allocator,
            &input,
            &.{.{
                .key = key,
                .data = .{
                    .{ .offset = format.wii_block_size, .size = format.wii_block_size },
                    .{ .offset = 0, .size = 0 },
                },
            }},
            .{ .max_partitions = 0 },
        ),
    );
    const overlapping = writer.Partition{
        .key = key,
        .data = .{
            .{ .offset = format.wii_block_size, .size = format.wii_block_size },
            .{ .offset = 0, .size = 0 },
        },
    };
    try std.testing.expectError(
        error.InvalidWia,
        writer.encodeWithPartitionsAlloc(
            allocator,
            &input,
            &.{ overlapping, overlapping },
            .{},
        ),
    );
}

test "WIA partition writer handles large chunks split entries and partial groups" {
    const text = @embedFile("testdata/python-partition-smallchunks.rvz.bz2.b64");
    const fixture = try decodeFixtureAlloc(text, 3 * 1024 * 1024);
    defer allocator.free(fixture);
    var fixture_archive = try archive_mod.Archive.initAlloc(
        allocator,
        fixture,
        .{},
    );
    defer fixture_archive.deinit();
    const single = try fixture_archive.decodeAllocLimited(
        allocator,
        3 * 1024 * 1024,
    );
    defer allocator.free(single);
    const key = fixture_archive.partitions[0].key;
    const partition_offset = format.wii_block_size;
    const encrypted_group = single[partition_offset..];

    const doubled = try allocator.alloc(
        u8,
        partition_offset + 2 * format.wii_group_size,
    );
    defer allocator.free(doubled);
    @memcpy(doubled[0..partition_offset], single[0..partition_offset]);
    @memcpy(
        doubled[partition_offset..][0..format.wii_group_size],
        encrypted_group,
    );
    @memcpy(
        doubled[partition_offset + format.wii_group_size ..],
        encrypted_group,
    );

    try expectPartitionWriterRoundTrip(
        doubled,
        &.{.{
            .key = key,
            .data = .{
                .{ .offset = partition_offset, .size = 2 * format.wii_group_size },
                .{ .offset = 0, .size = 0 },
            },
        }},
        .{
            .container = .wia,
            .compression = .bzip2,
            .compression_level = 6,
            .chunk_size = 4 * 1024 * 1024,
        },
    );
    try expectPartitionWriterRoundTrip(
        doubled,
        &.{.{
            .key = key,
            .data = .{
                .{ .offset = partition_offset, .size = format.wii_group_size },
                .{
                    .offset = partition_offset + format.wii_group_size,
                    .size = format.wii_group_size,
                },
            },
        }},
        .{
            .container = .rvz,
            .compression = .zstd,
            .compression_level = 5,
            .chunk_size = 128 * 1024,
        },
    );
    try expectPartitionWriterRoundTrip(
        doubled,
        &.{
            .{
                .key = key,
                .data = .{
                    .{ .offset = partition_offset, .size = format.wii_group_size },
                    .{ .offset = 0, .size = 0 },
                },
            },
            .{
                .key = key,
                .data = .{
                    .{
                        .offset = partition_offset + format.wii_group_size,
                        .size = format.wii_group_size,
                    },
                    .{ .offset = 0, .size = 0 },
                },
            },
        },
        .{
            .container = .rvz,
            .compression = .none,
            .compression_level = 0,
            .chunk_size = 2 * 1024 * 1024,
        },
    );

    try expectPartitionWriterRoundTrip(
        single,
        &.{.{
            .key = key,
            .data = .{
                .{
                    .offset = partition_offset,
                    .size = 20 * format.wii_block_size,
                },
                .{ .offset = 0, .size = 0 },
            },
        }},
        .{
            .container = .rvz,
            .compression = .bzip2,
            .compression_level = 6,
            .chunk_size = 128 * 1024,
        },
    );
}

test "RVZ partition writer emits zero-group sentinels" {
    const key: [16]u8 = @splat(0x5a);
    const encrypted = try wii.reconstructEncryptedGroupAlloc(
        allocator,
        &.{},
        &key,
        &.{},
    );
    defer allocator.free(encrypted);
    const input = try allocator.alloc(
        u8,
        format.wii_block_size + encrypted.len,
    );
    defer allocator.free(input);
    @memset(input[0..format.wii_block_size], 0);
    @memcpy(input[format.wii_block_size..], encrypted);
    const encoded = try writer.encodeWithPartitionsAlloc(
        allocator,
        input,
        &.{.{
            .key = key,
            .data = .{
                .{ .offset = format.wii_block_size, .size = encrypted.len },
                .{ .offset = 0, .size = 0 },
            },
        }},
        .{
            .container = .rvz,
            .compression = .zstd,
            .compression_level = 5,
            .chunk_size = 128 * 1024,
        },
    );
    defer allocator.free(encoded);
    var archive = try archive_mod.Archive.initAlloc(allocator, encoded, .{});
    defer archive.deinit();
    for (archive.groups) |group|
        try std.testing.expectEqual(@as(usize, 0), group.stored_size);
    const decoded = try archive.decodeAllocLimited(allocator, input.len);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}

test "WIA and RVZ decode pinned DolphinTool e2ad09306e6d images" {
    inline for (.{
        .{
            "testdata/dolphin-e2ad09306e6d-lzma2.wia.bz2.b64",
            "30474fa5642f455fa20db84bf2e95880eb22561e106d80eb576fcb44c6985d28",
            format.Container.wia,
            format.Compression.lzma2,
        },
        .{
            "testdata/dolphin-e2ad09306e6d-zstd.rvz.bz2.b64",
            "0786deb6750e7c334c645a5273c45a5f3e7297614268df4ea220eda635921b91",
            format.Container.rvz,
            format.Compression.zstd,
        },
    }) |case| {
        const text = @embedFile(case[0]);
        const base64 = std.base64.standard.decoderWithIgnore(" \r\n\t");
        const compressed = try allocator.alloc(
            u8,
            base64.calcSizeUpperBound(text.len),
        );
        defer allocator.free(compressed);
        const compressed_len = try base64.decode(compressed, text);
        const image = try bzip2.decodeAllocLimited(
            allocator,
            compressed[0..compressed_len],
            256 * 1024,
        );
        defer allocator.free(image);
        var image_digest: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(image, &image_digest, .{});
        var expected_digest: [32]u8 = undefined;
        _ = try std.fmt.hexToBytes(&expected_digest, case[1]);
        try std.testing.expectEqual(expected_digest, image_digest);

        var archive = try archive_mod.Archive.initAlloc(allocator, image, .{});
        defer archive.deinit();
        try std.testing.expectEqual(case[2], archive.header1.container);
        try std.testing.expectEqual(case[3], archive.header2.compression);
        const logical_size = 65536 + 137;
        const decoded = try archive.decodeAllocLimited(allocator, logical_size);
        defer allocator.free(decoded);
        for (decoded, 0..) |byte, index|
            try std.testing.expectEqual(
                @as(u8, @truncate(index * 29 + index / 31)),
                byte,
            );
    }
}

test "WIA and RVZ raw-data writers round trip supported codecs" {
    const input = try makeInput(2 * 1024 * 1024 + 137);
    defer allocator.free(input);
    inline for (.{
        .{ format.Container.wia, format.Compression.none, @as(u32, 2 * 1024 * 1024) },
        .{ format.Container.wia, format.Compression.purge, @as(u32, 2 * 1024 * 1024) },
        .{ format.Container.wia, format.Compression.bzip2, @as(u32, 2 * 1024 * 1024) },
        .{ format.Container.wia, format.Compression.lzma, @as(u32, 2 * 1024 * 1024) },
        .{ format.Container.wia, format.Compression.lzma2, @as(u32, 2 * 1024 * 1024) },
        .{ format.Container.rvz, format.Compression.none, @as(u32, 128 * 1024) },
        .{ format.Container.rvz, format.Compression.bzip2, @as(u32, 128 * 1024) },
        .{ format.Container.rvz, format.Compression.lzma, @as(u32, 128 * 1024) },
        .{ format.Container.rvz, format.Compression.lzma2, @as(u32, 128 * 1024) },
        .{ format.Container.rvz, format.Compression.zstd, @as(u32, 128 * 1024) },
    }) |case| {
        const encoded = try writer.encodeAlloc(allocator, input, .{
            .container = case[0],
            .compression = case[1],
            .chunk_size = case[2],
            .compression_level = if (case[1] == .zstd) 5 else 6,
        });
        defer allocator.free(encoded);
        var archive = try archive_mod.Archive.initAlloc(allocator, encoded, .{});
        defer archive.deinit();
        try std.testing.expectEqual(case[0], archive.header1.container);
        try std.testing.expectEqual(case[1], archive.header2.compression);
        const decoded = try archive.decodeAllocLimited(allocator, input.len);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
        const range = try archive.readRangeAllocLimited(
            allocator,
            128 * 1024 - 31,
            256 * 1024 + 73,
            256 * 1024 + 73,
        );
        defer allocator.free(range);
        try std.testing.expectEqualSlices(
            u8,
            input[128 * 1024 - 31 ..][0 .. 256 * 1024 + 73],
            range,
        );
    }
}

test "RVZ writer falls back per group and uses zero groups" {
    const chunk_size = 32 * 1024;
    const input = try allocator.alloc(u8, 3 * chunk_size);
    defer allocator.free(input);
    @memset(input, 0);
    var prng = std.Random.DefaultPrng.init(0x5256_5a31);
    prng.random().bytes(input[chunk_size .. 2 * chunk_size]);
    const encoded = try writer.encodeAlloc(allocator, input, .{
        .container = .rvz,
        .compression = .zstd,
        .chunk_size = chunk_size,
    });
    defer allocator.free(encoded);
    var archive = try archive_mod.Archive.initAlloc(allocator, encoded, .{});
    defer archive.deinit();
    try std.testing.expectEqual(@as(usize, 3), archive.groups.len);
    try std.testing.expectEqual(@as(usize, 0), archive.groups[0].stored_size);
    try std.testing.expect(!archive.groups[1].compressed);
    try std.testing.expectEqual(@as(usize, 0), archive.groups[2].stored_size);
    const decoded = try archive.decodeAllocLimited(allocator, input.len);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}

test "WIA parser rejects corrupt headers and tables" {
    try std.testing.expectError(
        error.InvalidWia,
        writer.encodeAlloc(allocator, "x" ** 128, .{
            .container = .wia,
            .compression = .bzip2,
            .compression_level = 0,
            .chunk_size = 2 * 1024 * 1024,
        }),
    );
    const input = "WIA malformed payload\n" ** 20_000;
    const encoded = try writer.encodeAlloc(allocator, input, .{
        .container = .rvz,
        .compression = .zstd,
        .chunk_size = 128 * 1024,
    });
    defer allocator.free(encoded);
    const corrupt = try allocator.dupe(u8, encoded);
    defer allocator.free(corrupt);
    corrupt[52] ^= 1;
    try std.testing.expectError(
        error.ChecksumMismatch,
        archive_mod.Archive.initAlloc(allocator, corrupt, .{}),
    );
    @memcpy(corrupt, encoded);
    corrupt[16] ^= 1;
    try std.testing.expectError(
        error.ChecksumMismatch,
        archive_mod.Archive.initAlloc(allocator, corrupt, .{}),
    );
    @memcpy(corrupt, encoded);
    format.writeU32Be(corrupt, format.header1_size + 144, 1);
    updateHeaderHashes(corrupt);
    try std.testing.expectError(
        error.ChecksumMismatch,
        archive_mod.Archive.initAlloc(allocator, corrupt, .{}),
    );
}

fn updateHeaderHashes(bytes: []u8) void {
    var header2_hash: [20]u8 = undefined;
    std.crypto.hash.Sha1.hash(
        bytes[format.header1_size..][0..format.header2_size],
        &header2_hash,
        .{},
    );
    @memcpy(bytes[16..36], &header2_hash);
    var header1_hash: [20]u8 = undefined;
    std.crypto.hash.Sha1.hash(bytes[0..52], &header1_hash, .{});
    @memcpy(bytes[52..72], &header1_hash);
}

fn decodeFixtureAlloc(text: []const u8, max_output_len: usize) ![]u8 {
    const base64 = std.base64.standard.decoderWithIgnore(" \r\n\t");
    const compressed = try allocator.alloc(
        u8,
        base64.calcSizeUpperBound(text.len),
    );
    defer allocator.free(compressed);
    const compressed_len = try base64.decode(compressed, text);
    return bzip2.decodeAllocLimited(
        allocator,
        compressed[0..compressed_len],
        max_output_len,
    );
}

fn expectSha256(bytes: []const u8, expected_hex: *const [64:0]u8) !void {
    var actual: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &actual, .{});
    var expected: [32]u8 = undefined;
    _ = try std.fmt.hexToBytes(&expected, expected_hex);
    try std.testing.expectEqual(expected, actual);
}

fn expectPartitionWriterRoundTrip(
    input: []const u8,
    partitions: []const writer.Partition,
    options: writer.EncodeOptions,
) !void {
    const encoded = try writer.encodeWithPartitionsAlloc(
        allocator,
        input,
        partitions,
        options,
    );
    defer allocator.free(encoded);
    var archive = try archive_mod.Archive.initAlloc(allocator, encoded, .{});
    defer archive.deinit();
    const decoded = try archive.decodeAllocLimited(allocator, input.len);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}

fn makeInput(size: usize) ![]u8 {
    const input = try allocator.alloc(u8, size);
    @memset(input, 0);
    for (input[0..@min(input.len, 512 * 1024)], 0..) |*byte, index|
        byte.* = "WIA RVZ repetitive data\n"[index % 24];
    if (input.len > 512 * 1024) {
        var prng = std.Random.DefaultPrng.init(0x5749_4131);
        prng.random().bytes(input[512 * 1024 .. @min(input.len, 768 * 1024)]);
    }
    if (input.len > 1024 * 1024) {
        for (input[1024 * 1024 ..], 0..) |*byte, index|
            byte.* = @truncate(index * 17 + index / 31);
    }
    return input;
}
