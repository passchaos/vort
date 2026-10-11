const std = @import("std");
const bzip2 = @import("../bzip2.zig");
const archive_mod = @import("archive.zig");
const format = @import("format.zig");
const writer = @import("writer.zig");

const allocator = std.testing.allocator;

test "VHD decodes pinned QEMU 9.2 dynamic image" {
    const text = @embedFile("testdata/qemu-9.2-dynamic.vhd.bz2.b64");
    const base64 = std.base64.standard.decoderWithIgnore(" \r\n\t");
    const compressed = try allocator.alloc(u8, base64.calcSizeUpperBound(text.len));
    defer allocator.free(compressed);
    const compressed_len = try base64.decode(compressed, text);
    const image = try bzip2.decodeAllocLimited(
        allocator,
        compressed[0..compressed_len],
        3 * 1024 * 1024,
    );
    defer allocator.free(image);
    const archive = try archive_mod.Archive.init(image, .{});
    try std.testing.expectEqual(format.DiskType.dynamic, archive.footer.disk_type);
    try std.testing.expectEqual(@as(u32, 2 * 1024 * 1024), archive.dynamic_header.?.block_size);
    const decoded = try archive.decodeAllocLimited(allocator, 32768);
    defer allocator.free(decoded);
    var actual: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(decoded, &actual, .{});
    var expected: [32]u8 = undefined;
    _ = try std.fmt.hexToBytes(
        &expected,
        "0dcde7c94a6d08ba49304eb929e45dbf9460e018db91060efd692cd516750824",
    );
    try std.testing.expectEqual(expected, actual);
}

test "VHD fixed and dynamic writers round trip sparse media" {
    const input = try makeInput(allocator, 4 * 4096 + 137);
    defer allocator.free(input);
    inline for (.{ format.DiskType.fixed, format.DiskType.dynamic }) |disk_type| {
        const encoded = try writer.encodeAlloc(allocator, input, .{
            .disk_type = disk_type,
            .block_size = 4096,
        });
        defer allocator.free(encoded);
        const archive = try archive_mod.Archive.init(encoded, .{});
        try std.testing.expectEqual(disk_type, archive.footer.disk_type);
        const media_size = std.mem.alignForward(usize, input.len, format.sector_size);
        try std.testing.expectEqual(@as(u64, media_size), archive.footer.current_size);
        const decoded = try archive.decodeAllocLimited(allocator, media_size);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded[0..input.len]);
        for (decoded[input.len..]) |byte| try std.testing.expectEqual(@as(u8, 0), byte);

        const range = try archive.readRangeAllocLimited(
            allocator,
            4096 - 29,
            4096 + 71,
            4096 + 71,
        );
        defer allocator.free(range);
        try std.testing.expectEqualSlices(
            u8,
            decoded[4096 - 29 ..][0 .. 4096 + 71],
            range,
        );
    }
}

test "VHD differencing writer uses sector bitmap parent overrides" {
    const block_size = 4096;
    const parent_input = try makeInput(allocator, 3 * block_size);
    defer allocator.free(parent_input);
    const parent_encoded = try writer.encodeAlloc(allocator, parent_input, .{
        .disk_type = .dynamic,
        .block_size = block_size,
    });
    defer allocator.free(parent_encoded);
    const parent = try archive_mod.Archive.init(parent_encoded, .{});

    const child_input = try allocator.dupe(u8, parent_input);
    defer allocator.free(child_input);
    @memset(child_input[block_size + 512 ..][0..512], 0x5a);
    @memset(child_input[2 * block_size ..][0..512], 0);
    const child_encoded = try writer.encodeAlloc(allocator, child_input, .{
        .disk_type = .differencing,
        .block_size = block_size,
        .parent = &parent,
    });
    defer allocator.free(child_encoded);
    try std.testing.expectError(
        error.MissingVhdParent,
        archive_mod.Archive.init(child_encoded, .{}),
    );
    const child = try archive_mod.Archive.init(child_encoded, .{
        .parent = &parent,
    });
    try std.testing.expectEqual(format.DiskType.differencing, child.footer.disk_type);
    try std.testing.expectEqualSlices(
        u8,
        &parent.footer.unique_id,
        &child.dynamic_header.?.parent_unique_id,
    );
    try std.testing.expectEqual(
        format.unallocated_bat_entry,
        format.readU32Be(child_encoded, child.bat_offset),
    );
    const second_bat = format.readU32Be(child_encoded, child.bat_offset + 4);
    try std.testing.expect(second_bat != format.unallocated_bat_entry);
    const second_bitmap: usize = second_bat * format.sector_size;
    try std.testing.expect(!archive_mod.bitmapBit(
        child_encoded[second_bitmap..][0..format.sector_size],
        0,
    ));
    try std.testing.expect(archive_mod.bitmapBit(
        child_encoded[second_bitmap..][0..format.sector_size],
        1,
    ));
    const decoded = try child.decodeAllocLimited(allocator, child_input.len);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, child_input, decoded);
}

test "VHD parser rejects footer header and BAT corruption" {
    const input = [_]u8{'V'} ** 8192;
    const encoded = try writer.encodeAlloc(allocator, &input, .{
        .disk_type = .dynamic,
        .block_size = 4096,
    });
    defer allocator.free(encoded);
    const corrupt = try allocator.dupe(u8, encoded);
    defer allocator.free(corrupt);
    corrupt[corrupt.len - 1] ^= 1;
    try std.testing.expectError(
        error.ChecksumMismatch,
        archive_mod.Archive.init(corrupt, .{}),
    );

    @memcpy(corrupt, encoded);
    corrupt[format.footer_size + 100] ^= 1;
    try std.testing.expectError(
        error.ChecksumMismatch,
        archive_mod.Archive.init(corrupt, .{}),
    );

    @memcpy(corrupt, encoded);
    format.writeU32Be(
        corrupt,
        format.footer_size + format.dynamic_header_size,
        1,
    );
    try std.testing.expectError(
        error.TruncatedFrame,
        archive_mod.Archive.init(corrupt, .{}),
    );
}

fn makeInput(alloc: std.mem.Allocator, size: usize) ![]u8 {
    const input = try alloc.alloc(u8, size);
    @memset(input, 0);
    for (input[0..@min(input.len, 4096)], 0..) |*byte, index|
        byte.* = "VHD dynamic block payload\n"[index % 26];
    if (input.len > 8192) {
        var prng = std.Random.DefaultPrng.init(0x5648_4431);
        prng.random().bytes(input[8192..@min(input.len, 12288)]);
    }
    if (input.len > 12288) {
        for (input[12288..], 0..) |*byte, index| byte.* = @truncate(index * 13);
    }
    return input;
}
