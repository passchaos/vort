const std = @import("std");
const bzip2 = @import("../bzip2.zig");
const vmdk = @import("../vmdk.zig");

const allocator = std.testing.allocator;

test "VMDK decodes pinned QEMU version 3 streamOptimized image" {
    const text = @embedFile("testdata/qemu-iotest-version3.vmdk.bz2.b64");
    const base64 = std.base64.standard.decoderWithIgnore(" \r\n\t");
    const compressed = try allocator.alloc(u8, base64.calcSizeUpperBound(text.len));
    defer allocator.free(compressed);
    const compressed_len = try base64.decode(compressed, text);
    const image = try bzip2.decodeAllocLimited(
        allocator,
        compressed[0..compressed_len],
        300_000,
    );
    defer allocator.free(image);
    const archive = try vmdk.parse(image, .{});
    try std.testing.expectEqual(@as(u32, 3), archive.header.version);
    try std.testing.expect(archive.header.isCompressed());
    try std.testing.expect(archive.header.from_footer);
    try std.testing.expectEqual(@as(u64, 16 * 1024 * 1024 * 1024), archive.header.virtual_size);
    for (0..100) |index| {
        const offset = index * 64 * 1024 * 10 + index * 512;
        const decoded = try archive.readRangeAllocLimited(
            allocator,
            offset,
            512,
            512,
        );
        defer allocator.free(decoded);
        for (decoded) |byte|
            try std.testing.expectEqual(@as(u8, @intCast(index % 10 + 0x30)), byte);
    }
}

test "VMDK sparse and streamOptimized writer round trip" {
    const input = try makeInput(allocator, 3 * 4096 + 137);
    defer allocator.free(input);
    inline for (.{ vmdk.Compression.none, vmdk.Compression.zlib }) |compression| {
        const encoded = try vmdk.encodeAlloc(allocator, input, .{
            .compression = compression,
            .grain_sectors = 8,
        });
        defer allocator.free(encoded);
        const archive = try vmdk.parse(encoded, .{});
        const virtual_size = std.mem.alignForward(usize, input.len, 512);
        try std.testing.expectEqual(@as(u64, virtual_size), archive.header.virtual_size);
        try std.testing.expectEqual(@as(usize, 4096), archive.header.grain_size);
        try std.testing.expectEqual(
            compression == .zlib,
            archive.header.isCompressed(),
        );
        try std.testing.expectEqualStrings(
            if (compression == .zlib) "streamOptimized" else "monolithicSparse",
            archive.descriptor.create_type,
        );
        const decoded = try archive.decodeAllocLimited(allocator, virtual_size);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded[0..input.len]);
        for (decoded[input.len..]) |byte|
            try std.testing.expectEqual(@as(u8, 0), byte);

        const range_offset = 4096 - 37;
        const range_len = 4096 + 91;
        const range = try archive.readRangeAllocLimited(
            allocator,
            range_offset,
            range_len,
            range_len,
        );
        defer allocator.free(range);
        try std.testing.expectEqualSlices(
            u8,
            decoded[range_offset..][0..range_len],
            range,
        );
    }
}

test "VMDK unallocated grains use explicit logical backing bytes" {
    const zeros = [_]u8{0} ** 4096;
    const encoded = try vmdk.encodeAlloc(allocator, &zeros, .{
        .compression = .none,
        .grain_sectors = 8,
    });
    defer allocator.free(encoded);
    var patched = try allocator.dupe(u8, encoded);
    defer allocator.free(patched);
    const parent = std.mem.indexOf(u8, patched, "parentCID=ffffffff") orelse
        return error.TestUnexpectedResult;
    @memcpy(patched[parent + 10 ..][0..8], "00000001");
    const header = try vmdk.parseHeader(patched);
    const gd_offset: usize = @intCast(header.gd_offset * 512);
    const gt_sector = std.mem.readInt(u32, patched[gd_offset..][0..4], .little);
    const gt_offset: usize = @as(usize, gt_sector) * 512;
    std.mem.writeInt(u32, patched[gt_offset..][0..4], 0, .little);

    const missing = try vmdk.parse(patched, .{});
    try std.testing.expectError(
        error.MissingVmdkBackingFile,
        missing.decodeAllocLimited(allocator, zeros.len),
    );
    const backing = "VMDK logical backing bytes\n" ** 150;
    const archive = try vmdk.parse(patched, .{ .backing_file = backing });
    const decoded = try archive.decodeAllocLimited(allocator, zeros.len);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, backing, decoded[0..backing.len]);
    for (decoded[backing.len..]) |byte|
        try std.testing.expectEqual(@as(u8, 0), byte);
}

test "VMDK parser rejects malformed headers markers and compressed grains" {
    try std.testing.expectError(error.TruncatedFrame, vmdk.parseHeader("KDMV"));
    var header = [_]u8{0} ** 512;
    std.mem.writeInt(u32, header[0..4], vmdk.magic, .little);
    std.mem.writeInt(u32, header[4..8], 3, .little);
    std.mem.writeInt(u32, header[8..12], (@as(u32, 1) << 16), .little);
    std.mem.writeInt(u64, header[20..28], 8, .little);
    std.mem.writeInt(u32, header[44..48], 512, .little);
    std.mem.writeInt(u16, header[77..79], 1, .little);
    try std.testing.expectError(error.InvalidVmdk, vmdk.parseHeader(&header));

    const input = [_]u8{'V'} ** 4096;
    const encoded = try vmdk.encodeAlloc(allocator, &input, .{
        .compression = .zlib,
        .grain_sectors = 8,
    });
    defer allocator.free(encoded);
    var patched = try allocator.dupe(u8, encoded);
    defer allocator.free(patched);
    patched[patched.len - 512 + 12] = 3;
    try std.testing.expectError(error.InvalidVmdk, vmdk.parse(patched, .{}));

    @memcpy(patched, encoded);
    const archive = try vmdk.parse(patched, .{});
    const gd_offset: usize = @intCast(archive.header.gd_offset * 512);
    const gt_sector = std.mem.readInt(u32, patched[gd_offset..][0..4], .little);
    const gt_offset: usize = @as(usize, gt_sector) * 512;
    const grain_sector = std.mem.readInt(u32, patched[gt_offset..][0..4], .little);
    const grain_offset: usize = @as(usize, grain_sector) * 512;
    patched[grain_offset] ^= 1;
    const corrupt = try vmdk.parse(patched, .{});
    var byte: [1]u8 = undefined;
    try std.testing.expectError(
        error.InvalidVmdk,
        corrupt.readRangeInto(allocator, 0, &byte),
    );
}

test "VMDK empty images retain a valid sparse mapping" {
    inline for (.{ vmdk.Compression.none, vmdk.Compression.zlib }) |compression| {
        const encoded = try vmdk.encodeAlloc(allocator, "", .{
            .compression = compression,
        });
        defer allocator.free(encoded);
        const archive = try vmdk.parse(encoded, .{});
        try std.testing.expectEqual(@as(u64, 0), archive.header.virtual_size);
        const decoded = try archive.decodeAllocLimited(allocator, 0);
        defer allocator.free(decoded);
        try std.testing.expectEqual(@as(usize, 0), decoded.len);
    }
}

fn makeInput(alloc: std.mem.Allocator, size: usize) ![]u8 {
    const output = try alloc.alloc(u8, size);
    for (output[0..4096], 0..) |*byte, index|
        byte.* = "VMDK-compressed-grain\n"[index % 22];
    var state: u32 = 0x564d_444b;
    for (output[4096..8192]) |*byte| {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        byte.* = @truncate(state);
    }
    @memset(output[8192..], 0);
    return output;
}
