const std = @import("std");
const bzip2 = @import("../bzip2.zig");
const archive_mod = @import("archive.zig");
const format = @import("format.zig");
const writer = @import("writer.zig");

const allocator = std.testing.allocator;

test "VHDX decodes pinned QEMU 9.2 dynamic image" {
    const text = @embedFile("testdata/qemu-9.2-dynamic.vhdx.bz2.b64");
    const base64 = std.base64.standard.decoderWithIgnore(" \r\n\t");
    const compressed = try allocator.alloc(u8, base64.calcSizeUpperBound(text.len));
    defer allocator.free(compressed);
    const compressed_len = try base64.decode(compressed, text);
    const image = try bzip2.decodeAllocLimited(
        allocator,
        compressed[0..compressed_len],
        12 * format.mib,
    );
    defer allocator.free(image);
    const archive = try archive_mod.Archive.init(image, .{});
    try std.testing.expectEqual(@as(u64, 32768), archive.metadata.virtual_disk_size);
    try std.testing.expectEqual(@as(u32, format.mib), archive.metadata.block_size);
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

test "VHDX dynamic and fixed writers round trip sparse payloads" {
    const block_size = format.mib;
    const input = try allocator.alloc(u8, 2 * block_size + 137);
    defer allocator.free(input);
    @memset(input, 0);
    for (input[0..block_size], 0..) |*byte, index|
        byte.* = "VHDX allocated payload\n"[index % 23];
    for (input[2 * block_size ..], 0..) |*byte, index|
        byte.* = @truncate(index * 17);
    inline for (.{ writer.ImageType.dynamic, writer.ImageType.fixed }) |image_type| {
        const encoded = try writer.encodeAlloc(allocator, input, .{
            .image_type = image_type,
            .block_size = block_size,
        });
        defer allocator.free(encoded);
        const archive = try archive_mod.Archive.init(encoded, .{});
        try std.testing.expectEqual(@as(u64, 2), archive.header.sequence_number);
        try std.testing.expectEqual(@as(u32, block_size), archive.metadata.block_size);
        try std.testing.expectEqual(
            image_type == .fixed,
            archive.metadata.leave_blocks_allocated,
        );
        const virtual_size = std.mem.alignForward(usize, input.len, 512);
        const decoded = try archive.decodeAllocLimited(allocator, virtual_size);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded[0..input.len]);
        for (decoded[input.len..]) |byte| try std.testing.expectEqual(@as(u8, 0), byte);
        const range = try archive.readRangeAllocLimited(
            allocator,
            block_size - 31,
            block_size + 73,
            block_size + 73,
        );
        defer allocator.free(range);
        try std.testing.expectEqualSlices(
            u8,
            decoded[block_size - 31 ..][0 .. block_size + 73],
            range,
        );
    }
}

test "VHDX reader falls back across redundant headers and region tables" {
    const input = [_]u8{'X'} ** 8192;
    const encoded = try writer.encodeAlloc(allocator, &input, .{
        .block_size = format.mib,
    });
    defer allocator.free(encoded);
    const patched = try allocator.dupe(u8, encoded);
    defer allocator.free(patched);
    patched[format.header1_offset + 200] ^= 1;
    _ = try archive_mod.Archive.init(patched, .{});
    patched[format.header2_offset + 200] ^= 1;
    try std.testing.expectError(
        error.InvalidVhdx,
        archive_mod.Archive.init(patched, .{}),
    );

    @memcpy(patched, encoded);
    patched[format.region1_offset + 200] ^= 1;
    _ = try archive_mod.Archive.init(patched, .{});
    patched[format.region2_offset + 200] ^= 1;
    try std.testing.expectError(
        error.InvalidVhdx,
        archive_mod.Archive.init(patched, .{}),
    );
}

test "VHDX writer handles empty disks and 4096-byte logical sectors" {
    const empty = try writer.encodeAlloc(allocator, "", .{});
    defer allocator.free(empty);
    const empty_archive = try archive_mod.Archive.init(empty, .{});
    try std.testing.expectEqual(@as(u64, 0), empty_archive.metadata.virtual_disk_size);
    const empty_decoded = try empty_archive.decodeAllocLimited(allocator, 0);
    defer allocator.free(empty_decoded);
    try std.testing.expectEqual(@as(usize, 0), empty_decoded.len);

    const encoded = try writer.encodeAlloc(allocator, "4k-sector-payload", .{
        .block_size = format.mib,
        .logical_sector_size = 4096,
        .physical_sector_size = 4096,
    });
    defer allocator.free(encoded);
    const archive = try archive_mod.Archive.init(encoded, .{});
    try std.testing.expectEqual(@as(u32, 4096), archive.metadata.logical_sector_size);
    const decoded = try archive.decodeAllocLimited(allocator, 4096);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "4k-sector-payload", decoded[0..17]);
    for (decoded[17..]) |byte| try std.testing.expectEqual(@as(u8, 0), byte);
}

test "VHDX differencing writer merges parent sectors through bitmap" {
    const block_size = format.mib;
    const parent_input = try allocator.alloc(u8, 3 * block_size);
    defer allocator.free(parent_input);
    for (parent_input, 0..) |*byte, index| byte.* = @truncate(index * 29 + index / 31);
    const parent_encoded = try writer.encodeAlloc(allocator, parent_input, .{
        .image_type = .dynamic,
        .block_size = block_size,
    });
    defer allocator.free(parent_encoded);
    const parent = try archive_mod.Archive.init(parent_encoded, .{});

    const child_input = try allocator.dupe(u8, parent_input);
    defer allocator.free(child_input);
    @memset(child_input[block_size + 3 * 512 ..][0..512], 0xa5);
    for (child_input[2 * block_size ..]) |*byte| byte.* ^= 0xff;
    const child_encoded = try writer.encodeAlloc(allocator, child_input, .{
        .image_type = .differencing,
        .block_size = block_size,
        .parent = &parent,
    });
    defer allocator.free(child_encoded);
    try std.testing.expectError(
        error.MissingVhdxParent,
        archive_mod.Archive.init(child_encoded, .{}),
    );
    const child = try archive_mod.Archive.init(child_encoded, .{
        .parent = &parent,
    });
    try std.testing.expect(child.metadata.has_parent);
    try std.testing.expectEqualSlices(
        u8,
        &parent.header.data_write_guid,
        &child.metadata.parent_linkage.?,
    );
    const bat = child.regions.bat.offset;
    try std.testing.expectEqual(
        @intFromEnum(format.PayloadState.not_present),
        format.readU64Le(child_encoded, bat) & 7,
    );
    try std.testing.expectEqual(
        @intFromEnum(format.PayloadState.partially_present),
        format.readU64Le(child_encoded, bat + 8) & 7,
    );
    try std.testing.expectEqual(
        @intFromEnum(format.PayloadState.fully_present),
        format.readU64Le(child_encoded, bat + 16) & 7,
    );
    const bitmap_entry = format.readU64Le(
        child_encoded,
        bat + archive_mod.sectorBitmapBatIndex(0, child.metadata.chunk_ratio) * 8,
    );
    const bitmap_offset: usize = @intCast(bitmap_entry & format.bat_file_offset_mask);
    const bitmap = child_encoded[bitmap_offset..][0..format.mib];
    try std.testing.expect(!archive_mod.bitmapBit(bitmap, 2048 + 2));
    try std.testing.expect(archive_mod.bitmapBit(bitmap, 2048 + 3));
    const decoded = try child.decodeAllocLimited(allocator, child_input.len);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, child_input, decoded);

    const wrong_input = [_]u8{0} ** 512;
    const wrong_encoded = try writer.encodeAlloc(allocator, &wrong_input, .{
        .block_size = block_size,
    });
    defer allocator.free(wrong_encoded);
    const wrong_parent = try archive_mod.Archive.init(wrong_encoded, .{});
    try std.testing.expectError(
        error.MissingVhdxParent,
        archive_mod.Archive.init(child_encoded, .{ .parent = &wrong_parent }),
    );
}

test "VHDX parser rejects unsupported parents and malformed BAT offsets" {
    const input = [_]u8{'B'} ** 8192;
    const encoded = try writer.encodeAlloc(allocator, &input, .{
        .block_size = format.mib,
    });
    defer allocator.free(encoded);
    const patched = try allocator.dupe(u8, encoded);
    defer allocator.free(patched);
    const archive = try archive_mod.Archive.init(patched, .{});
    const params_offset = archive.regions.metadata.offset + format.metadata_table_area_size;
    format.writeU32Le(patched, params_offset + 4, 2);
    try std.testing.expectError(
        error.InvalidVhdx,
        archive_mod.Archive.init(patched, .{}),
    );

    @memcpy(patched, encoded);
    format.writeU64Le(
        patched,
        archive.regions.bat.offset,
        (@as(u64, format.mib) | @intFromEnum(format.PayloadState.fully_present)),
    );
    try std.testing.expectError(
        error.TruncatedFrame,
        archive_mod.Archive.init(patched, .{}),
    );
}
