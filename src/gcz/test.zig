const std = @import("std");
const bzip2 = @import("../bzip2.zig");
const archive_mod = @import("archive.zig");
const format = @import("format.zig");
const writer = @import("writer.zig");

const allocator = std.testing.allocator;

test "GCZ decodes pinned DolphinTool e2ad09306e6d image" {
    const text = @embedFile("testdata/dolphin-e2ad09306e6d.gcz.bz2.b64");
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
        128 * 1024,
    );
    defer allocator.free(image);
    var image_digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(image, &image_digest, .{});
    var expected_digest: [32]u8 = undefined;
    _ = try std.fmt.hexToBytes(
        &expected_digest,
        "b5fddeefa25271055d467cdc7cee6f10400d443d21d7989c8094efcb9d8d12f1",
    );
    try std.testing.expectEqual(expected_digest, image_digest);

    const archive = try archive_mod.Archive.init(image, .{});
    try std.testing.expectEqual(@as(u32, 16384), archive.header.block_size);
    try std.testing.expectEqual(@as(usize, 4), archive.header.block_count);
    const logical_size = 3 * 16384 + 137;
    const decoded = try archive.decodeAllocLimited(allocator, logical_size);
    defer allocator.free(decoded);
    for (decoded, 0..) |byte, index|
        try std.testing.expectEqual(@as(u8, @truncate(index * 29 + index / 31)), byte);
}

test "GCZ raw zlib and automatic writers round trip mixed partial blocks" {
    const block_size = 4096;
    const input = try makeInput(4 * block_size + 137, block_size);
    defer allocator.free(input);
    inline for (.{
        writer.Compression.raw,
        writer.Compression.zlib,
        writer.Compression.auto,
    }) |compression| {
        const encoded = try writer.encodeAlloc(allocator, input, .{
            .compression = compression,
            .block_size = block_size,
            .sub_type = 7,
        });
        defer allocator.free(encoded);
        const archive = try archive_mod.Archive.init(encoded, .{});
        try std.testing.expectEqual(@as(u32, 7), archive.header.sub_type);
        try std.testing.expectEqual(@as(usize, 5), archive.header.block_count);
        const decoded = try archive.decodeAllocLimited(allocator, input.len);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
        const range = try archive.readRangeAllocLimited(
            allocator,
            block_size - 31,
            2 * block_size + 73,
            2 * block_size + 73,
        );
        defer allocator.free(range);
        try std.testing.expectEqualSlices(
            u8,
            input[block_size - 31 ..][0 .. 2 * block_size + 73],
            range,
        );
    }
}

test "GCZ automatic writer marks raw blocks and hashes stored bytes" {
    const block_size = 4096;
    const input = try makeInput(3 * block_size, block_size);
    defer allocator.free(input);
    const first = try writer.encodeAlloc(allocator, input, .{
        .block_size = block_size,
    });
    defer allocator.free(first);
    const second = try writer.encodeAlloc(allocator, input, .{
        .block_size = block_size,
    });
    defer allocator.free(second);
    try std.testing.expectEqualSlices(u8, first, second);
    const archive = try archive_mod.Archive.init(first, .{});
    try std.testing.expect(!(try archive.block(0)).raw);
    try std.testing.expect((try archive.block(1)).raw);
    for (0..archive.header.block_count) |block_index| {
        const block = try archive.block(block_index);
        try std.testing.expectEqual(
            block.hash,
            @import("../checksum.zig").adler32(
                first[block.offset..][0..block.stored_size],
            ),
        );
    }
}

test "GCZ detects block hash and zlib corruption" {
    const input = "GCZ checksum payload\n" ** 500;
    const encoded = try writer.encodeAlloc(allocator, input, .{
        .compression = .zlib,
        .block_size = 4096,
    });
    defer allocator.free(encoded);
    const corrupt = try allocator.dupe(u8, encoded);
    defer allocator.free(corrupt);
    const archive = try archive_mod.Archive.init(corrupt, .{});
    const first = try archive.block(0);
    corrupt[first.offset] ^= 1;
    const damaged = try archive_mod.Archive.init(corrupt, .{});
    const output = try allocator.alloc(u8, input.len);
    defer allocator.free(output);
    try std.testing.expectError(
        error.ChecksumMismatch,
        damaged.readRangeInto(allocator, 0, output),
    );
    const unchecked = try archive_mod.Archive.init(corrupt, .{
        .verify_hashes = false,
    });
    try std.testing.expectError(
        error.BadZlibHeader,
        unchecked.readRangeInto(allocator, 0, output),
    );
}

test "GCZ rejects empty images and malformed pointer geometry" {
    try std.testing.expectError(
        error.InvalidGcz,
        writer.encodeAlloc(allocator, "", .{}),
    );
    try std.testing.expectError(
        error.OutputLimitExceeded,
        writer.encodeAlloc(allocator, "x", .{
            .block_size = 4096,
            .max_block_size = 2048,
        }),
    );
    const input = "GCZ malformed pointer payload\n" ** 400;
    const encoded = try writer.encodeAlloc(allocator, input, .{
        .block_size = 4096,
    });
    defer allocator.free(encoded);
    try std.testing.expectError(
        error.TruncatedFrame,
        archive_mod.Archive.init(encoded[0..format.header_size], .{}),
    );
    const corrupt = try allocator.dupe(u8, encoded);
    defer allocator.free(corrupt);
    format.writeU64Le(corrupt, format.header_size, 1);
    try std.testing.expectError(
        error.InvalidGcz,
        archive_mod.Archive.init(corrupt, .{}),
    );
    @memcpy(corrupt, encoded);
    format.writeU32Le(corrupt, 28, 1);
    try std.testing.expectError(
        error.InvalidGcz,
        archive_mod.Archive.init(corrupt, .{}),
    );
}

fn makeInput(size: usize, block_size: usize) ![]u8 {
    const input = try allocator.alloc(u8, size);
    @memset(input, 0);
    for (input[0..@min(input.len, block_size)], 0..) |*byte, index|
        byte.* = "GCZ repetitive block\n"[index % 21];
    if (input.len > block_size) {
        var prng = std.Random.DefaultPrng.init(0x4743_5a31);
        prng.random().bytes(input[block_size..@min(input.len, 2 * block_size)]);
    }
    if (input.len > 3 * block_size) {
        for (input[3 * block_size ..], 0..) |*byte, index|
            byte.* = @truncate(index * 19 + index / 23);
    }
    return input;
}
