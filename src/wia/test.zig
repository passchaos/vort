const std = @import("std");
const bzip2 = @import("../bzip2.zig");
const archive_mod = @import("archive.zig");
const format = @import("format.zig");
const writer = @import("writer.zig");

const allocator = std.testing.allocator;

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

test "WIA parser rejects corrupt headers tables and unsupported partitions" {
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
        error.UnsupportedWiaFeature,
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
