const std = @import("std");
const archive_mod = @import("archive.zig");
const format = @import("format.zig");
const writer = @import("writer.zig");

const allocator = std.testing.allocator;

test "CSO1 ZSO and CSO2 writers round trip mixed and partial blocks" {
    const input = try makeInput(5 * 2048 + 137);
    defer allocator.free(input);
    inline for (.{
        format.Format.cso1,
        format.Format.zso,
        format.Format.cso2,
    }) |image_format| {
        const encoded = try writer.encodeAlloc(allocator, input, .{
            .format = image_format,
            .compression = .auto,
        });
        defer allocator.free(encoded);
        const archive = try archive_mod.Archive.init(encoded, .{});
        try std.testing.expectEqual(image_format, archive.header.format);
        try std.testing.expectEqual(@as(u64, input.len), archive.header.uncompressed_size);
        const decoded = try archive.decodeAllocLimited(allocator, input.len);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);

        var saw_raw = false;
        var saw_compressed = false;
        for (0..archive.header.block_count) |block_index| {
            const block_info = try archive.block(block_index);
            saw_raw = saw_raw or block_info.codec == .raw;
            saw_compressed = saw_compressed or block_info.codec != .raw;
        }
        try std.testing.expect(saw_raw);
        try std.testing.expect(saw_compressed);

        const range = try archive.readRangeAllocLimited(
            allocator,
            2048 - 31,
            2 * 2048 + 73,
            2 * 2048 + 73,
        );
        defer allocator.free(range);
        try std.testing.expectEqualSlices(
            u8,
            input[2048 - 31 ..][0 .. 2 * 2048 + 73],
            range,
        );
    }
}

test "CSO2 writes explicit DEFLATE and LZ4 block flags" {
    const input = "CSO2 codec selection payload\n" ** 300;
    inline for (.{ writer.Compression.deflate, writer.Compression.lz4 }) |compression| {
        const encoded = try writer.encodeAlloc(allocator, input, .{
            .format = .cso2,
            .compression = compression,
            .block_size = 4096,
        });
        defer allocator.free(encoded);
        const archive = try archive_mod.Archive.init(encoded, .{});
        const first = try archive.block(0);
        try std.testing.expectEqual(
            if (compression == .deflate) format.Codec.deflate else format.Codec.lz4,
            first.codec,
        );
        const decoded = try archive.decodeAllocLimited(allocator, input.len);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
    }
}

test "CSO alignment padding and raw fallback are deterministic" {
    var random = [_]u8{0} ** (2 * 2048);
    var prng = std.Random.DefaultPrng.init(0x4353_4f31);
    prng.random().bytes(&random);
    const first = try writer.encodeAlloc(allocator, &random, .{
        .format = .zso,
        .index_shift = 3,
    });
    defer allocator.free(first);
    const second = try writer.encodeAlloc(allocator, &random, .{
        .format = .zso,
        .index_shift = 3,
    });
    defer allocator.free(second);
    try std.testing.expectEqualSlices(u8, first, second);
    const archive = try archive_mod.Archive.init(first, .{});
    for (0..archive.header.block_count) |block_index| {
        const block_info = try archive.block(block_index);
        try std.testing.expectEqual(@as(usize, 0), block_info.offset % 8);
        try std.testing.expectEqual(format.Codec.raw, block_info.codec);
    }
    const decoded = try archive.decodeAllocLimited(allocator, random.len);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &random, decoded);
}

test "CSO writer handles empty input and codec validation" {
    const encoded = try writer.encodeAlloc(allocator, "", .{});
    defer allocator.free(encoded);
    const archive = try archive_mod.Archive.init(encoded, .{});
    try std.testing.expectEqual(@as(usize, 0), archive.header.block_count);
    const decoded = try archive.decodeAllocLimited(allocator, 0);
    defer allocator.free(decoded);
    try std.testing.expectEqual(@as(usize, 0), decoded.len);
    try std.testing.expectError(
        error.UnsupportedCsoCodec,
        writer.encodeAlloc(allocator, "x", .{
            .format = .cso1,
            .compression = .lz4,
        }),
    );
    try std.testing.expectError(
        error.UnsupportedCsoCodec,
        writer.encodeAlloc(allocator, "x", .{
            .format = .zso,
            .compression = .deflate,
        }),
    );
}

test "CSO parser rejects malformed headers indexes and block data" {
    const input = "malformed CSO block" ** 300;
    const encoded = try writer.encodeAlloc(allocator, input, .{
        .format = .cso1,
        .compression = .deflate,
    });
    defer allocator.free(encoded);
    try std.testing.expectError(
        error.TruncatedFrame,
        archive_mod.Archive.init(encoded[0..format.header_size], .{}),
    );

    const corrupt = try allocator.dupe(u8, encoded);
    defer allocator.free(corrupt);
    format.writeU32Le(corrupt, format.header_size + 4, 1);
    try std.testing.expectError(
        error.InvalidCso,
        archive_mod.Archive.init(corrupt, .{}),
    );

    @memcpy(corrupt, encoded);
    const archive = try archive_mod.Archive.init(corrupt, .{});
    const first = try archive.block(0);
    corrupt[first.offset] = (corrupt[first.offset] & 0xf8) | 0x07;
    const damaged = try archive_mod.Archive.init(corrupt, .{});
    const output = try allocator.alloc(u8, input.len);
    defer allocator.free(output);
    try std.testing.expectError(
        error.InvalidDeflateBlockType,
        damaged.readRangeInto(allocator, 0, output),
    );
}

fn makeInput(size: usize) ![]u8 {
    const input = try allocator.alloc(u8, size);
    @memset(input, 0);
    for (input[0..@min(input.len, 2048)], 0..) |*byte, index|
        byte.* = "CISO repetitive block\n"[index % 22];
    if (input.len > 2048) {
        var prng = std.Random.DefaultPrng.init(0x5a53_4f31);
        prng.random().bytes(input[2048..@min(input.len, 4096)]);
    }
    if (input.len > 6144) {
        for (input[6144..], 0..) |*byte, index|
            byte.* = @truncate(index * 17 + index / 19);
    }
    return input;
}
