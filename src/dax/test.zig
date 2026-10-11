const std = @import("std");
const bzip2 = @import("../bzip2.zig");
const archive_mod = @import("archive.zig");
const format = @import("format.zig");
const writer = @import("writer.zig");

const allocator = std.testing.allocator;

test "DAX decodes pinned maxcso 1.13.0 image" {
    const text = @embedFile("testdata/maxcso-1.13.0.dax.bz2.b64");
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
        "aa4510f57beb1be20b7905667d8386f1a0f181a96c61ab7265688fedcaa97417",
    );
    try std.testing.expectEqual(expected_digest, image_digest);

    const archive = try archive_mod.Archive.init(image, .{});
    try std.testing.expectEqual(@as(u32, 0), archive.header.version);
    try std.testing.expectEqual(@as(usize, 3), archive.header.frame_count);
    const decoded = try archive.decodeAllocLimited(allocator, 3 * format.frame_size);
    defer allocator.free(decoded);
    for (decoded, 0..) |byte, index|
        try std.testing.expectEqual(@as(u8, @truncate(index * 17 + index / 23)), byte);
}

test "DAX zlib raw and automatic writers round trip partial frames" {
    const input = try makeInput(4 * format.frame_size + 137);
    defer allocator.free(input);
    inline for (.{
        writer.Compression.zlib,
        writer.Compression.raw,
        writer.Compression.auto,
    }) |compression| {
        const encoded = try writer.encodeAlloc(allocator, input, .{
            .compression = compression,
        });
        defer allocator.free(encoded);
        const archive = try archive_mod.Archive.init(encoded, .{});
        try std.testing.expectEqual(@as(usize, 5), archive.header.frame_count);
        try std.testing.expectEqual(
            compression != .zlib,
            archive.header.version == 1,
        );
        const decoded = try archive.decodeAllocLimited(allocator, input.len);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);

        const range = try archive.readRangeAllocLimited(
            allocator,
            format.frame_size - 37,
            2 * format.frame_size + 91,
            2 * format.frame_size + 91,
        );
        defer allocator.free(range);
        try std.testing.expectEqualSlices(
            u8,
            input[format.frame_size - 37 ..][0 .. 2 * format.frame_size + 91],
            range,
        );
    }
}

test "DAX automatic writer groups consecutive raw frames deterministically" {
    var input = [_]u8{0} ** (4 * format.frame_size);
    var prng = std.Random.DefaultPrng.init(0x4441_5831);
    prng.random().bytes(input[format.frame_size .. 3 * format.frame_size]);
    const first = try writer.encodeAlloc(allocator, &input, .{});
    defer allocator.free(first);
    const second = try writer.encodeAlloc(allocator, &input, .{});
    defer allocator.free(second);
    try std.testing.expectEqualSlices(u8, first, second);
    const archive = try archive_mod.Archive.init(first, .{});
    try std.testing.expectEqual(@as(u32, 1), archive.header.version);
    try std.testing.expectEqual(@as(usize, 1), archive.header.nc_area_count);
    const area = try archive.nonCompressedArea(0);
    try std.testing.expectEqual(@as(usize, 1), area.start);
    try std.testing.expectEqual(@as(usize, 2), area.count);
    try std.testing.expect(!(try archive.frame(0)).raw);
    try std.testing.expect((try archive.frame(1)).raw);
    try std.testing.expect((try archive.frame(2)).raw);
    try std.testing.expect(!(try archive.frame(3)).raw);
}

test "DAX writer handles empty input and validates limits" {
    const encoded = try writer.encodeAlloc(allocator, "", .{});
    defer allocator.free(encoded);
    const archive = try archive_mod.Archive.init(encoded, .{});
    try std.testing.expectEqual(@as(usize, 0), archive.header.frame_count);
    const decoded = try archive.decodeAllocLimited(allocator, 0);
    defer allocator.free(decoded);
    try std.testing.expectEqual(@as(usize, 0), decoded.len);
    try std.testing.expectError(
        error.InvalidDax,
        writer.encodeAlloc(allocator, "x", .{ .compression_level = 0 }),
    );
    try std.testing.expectError(
        error.OutputLimitExceeded,
        writer.encodeAlloc(allocator, "x", .{ .max_frames = 0 }),
    );
}

test "DAX parser rejects malformed tables areas extents and streams" {
    const input = "DAX malformed zlib frame\n" ** 400;
    const encoded = try writer.encodeAlloc(allocator, input, .{
        .compression = .zlib,
    });
    defer allocator.free(encoded);
    try std.testing.expectError(
        error.TruncatedFrame,
        archive_mod.Archive.init(encoded[0..format.header_size], .{}),
    );

    const corrupt = try allocator.dupe(u8, encoded);
    defer allocator.free(corrupt);
    format.writeU32Le(corrupt, format.header_size, 1);
    try std.testing.expectError(
        error.InvalidDax,
        archive_mod.Archive.init(corrupt, .{}),
    );

    @memcpy(corrupt, encoded);
    const archive = try archive_mod.Archive.init(corrupt, .{});
    const first = try archive.frame(0);
    corrupt[first.offset] ^= 0xff;
    const damaged = try archive_mod.Archive.init(corrupt, .{});
    const output = try allocator.alloc(u8, input.len);
    defer allocator.free(output);
    try std.testing.expectError(
        error.BadZlibHeader,
        damaged.readRangeInto(allocator, 0, output),
    );

    const raw = try writer.encodeAlloc(allocator, input, .{
        .compression = .raw,
    });
    defer allocator.free(raw);
    const bad_area = try allocator.dupe(u8, raw);
    defer allocator.free(bad_area);
    const raw_archive = try archive_mod.Archive.init(raw, .{});
    format.writeU32Le(bad_area, raw_archive.areas_offset + 4, 0);
    try std.testing.expectError(
        error.InvalidDax,
        archive_mod.Archive.init(bad_area, .{}),
    );
}

fn makeInput(size: usize) ![]u8 {
    const input = try allocator.alloc(u8, size);
    @memset(input, 0);
    for (input[0..@min(input.len, format.frame_size)], 0..) |*byte, index|
        byte.* = "DAX repetitive frame\n"[index % 21];
    if (input.len > format.frame_size) {
        var prng = std.Random.DefaultPrng.init(0x4458_4131);
        prng.random().bytes(
            input[format.frame_size..@min(input.len, 2 * format.frame_size)],
        );
    }
    if (input.len > 3 * format.frame_size) {
        for (input[3 * format.frame_size ..], 0..) |*byte, index|
            byte.* = @truncate(index * 13 + index / 17);
    }
    return input;
}
