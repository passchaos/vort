const std = @import("std");
const qcow2 = @import("../qcow2.zig");

const allocator = std.testing.allocator;

test "QCOW2 decodes pinned QEMU Zstd compressed image" {
    const text = @embedFile("testdata/qemu-v3-zstd-512.qcow2.b64");
    const base64 = std.base64.standard.decoderWithIgnore(" \r\n\t");
    const encoded = try allocator.alloc(u8, base64.calcSizeUpperBound(text.len));
    defer allocator.free(encoded);
    const encoded_len = try base64.decode(encoded, text);
    const archive = try qcow2.parse(encoded[0..encoded_len], .{});
    try std.testing.expectEqual(@as(u32, 3), archive.header.version);
    try std.testing.expectEqual(@as(usize, 512), archive.header.cluster_size);
    try std.testing.expectEqual(qcow2.CompressionType.zstd, archive.header.compression_type);
    const decoded = try archive.decodeAllocLimited(allocator, 512);
    defer allocator.free(decoded);
    const expected = ("QEMU QCOW2 Zstd fixture\\n" ** 32)[0..512];
    try std.testing.expectEqualSlices(u8, expected, decoded);
}

test "QCOW2 writer emits an empty image without an L1 table" {
    const encoded = try qcow2.encodeAlloc(allocator, "", .{
        .version = 3,
        .cluster_bits = 12,
        .compression = .zstd,
    });
    defer allocator.free(encoded);
    const archive = try qcow2.parse(encoded, .{});
    try std.testing.expectEqual(@as(u64, 0), archive.header.virtual_size);
    try std.testing.expectEqual(@as(usize, 0), archive.header.l1_size);
    try std.testing.expectEqual(@as(u64, 0), archive.header.l1_table_offset);
    const decoded = try archive.decodeAllocLimited(allocator, 0);
    defer allocator.free(decoded);
    try std.testing.expectEqual(@as(usize, 0), decoded.len);
}

test "QCOW2 writer and reader round trip v2 and v3 compression" {
    const input = try makeInput(allocator, 2 * 4096 + 137);
    defer allocator.free(input);
    const cases = .{
        .{ @as(u32, 2), qcow2.Compression.none },
        .{ @as(u32, 2), qcow2.Compression.zlib },
        .{ @as(u32, 3), qcow2.Compression.zlib },
        .{ @as(u32, 3), qcow2.Compression.zstd },
    };
    inline for (cases) |case| {
        const virtual_size = std.mem.alignForward(usize, input.len, 512);
        const encoded = try qcow2.encodeAlloc(allocator, input, .{
            .version = case[0],
            .cluster_bits = 12,
            .compression = case[1],
        });
        defer allocator.free(encoded);
        const archive = try qcow2.parse(encoded, .{});
        try std.testing.expectEqual(@as(u64, virtual_size), archive.header.virtual_size);
        const decoded = try archive.decodeAllocLimited(allocator, virtual_size);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded[0..input.len]);
        for (decoded[input.len..]) |byte|
            try std.testing.expectEqual(@as(u8, 0), byte);
        const range_offset = 4096 - 31;
        const range_len = 4096 + 89;
        const range = try archive.readRangeAllocLimited(
            allocator,
            range_offset,
            range_len,
            range_len,
        );
        defer allocator.free(range);
        try std.testing.expectEqualSlices(
            u8,
            input[range_offset..][0..range_len],
            range,
        );
    }
}

test "QCOW2 unallocated clusters read from an explicit backing image" {
    const backing = "QCOW2 backing file bytes\n" ** 160;
    const zeros = [_]u8{0} ** 4096;
    const encoded = try qcow2.encodeAlloc(allocator, &zeros, .{
        .version = 3,
        .cluster_bits = 12,
        .compression = .none,
    });
    defer allocator.free(encoded);
    var patched = try allocator.dupe(u8, encoded);
    defer allocator.free(patched);
    std.mem.writeInt(u64, patched[8..16], 128, .big);
    std.mem.writeInt(u32, patched[16..20], 4, .big);
    @memcpy(patched[128..132], "base");
    @memset(patched[4 * 4096 ..][0..8], 0);

    const missing = try qcow2.parse(patched, .{});
    try std.testing.expectError(
        error.MissingQcow2BackingFile,
        missing.decodeAllocLimited(allocator, zeros.len),
    );
    const archive = try qcow2.parse(patched, .{ .backing_file = backing });
    const decoded = try archive.decodeAllocLimited(allocator, zeros.len);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, backing, decoded[0..backing.len]);
    for (decoded[backing.len..]) |byte| try std.testing.expectEqual(@as(u8, 0), byte);
}

test "QCOW2 external raw data file maps guest cluster zero" {
    const input = try makeInput(allocator, 2 * 4096);
    defer allocator.free(input);
    const encoded = try qcow2.encodeAlloc(allocator, input, .{
        .version = 3,
        .cluster_bits = 12,
        .compression = .none,
    });
    defer allocator.free(encoded);
    var patched = try allocator.dupe(u8, encoded);
    defer allocator.free(patched);
    std.mem.writeInt(u64, patched[72..80], @as(u64, 1) << 2, .big);
    std.mem.writeInt(u64, patched[88..96], @as(u64, 1) << 1, .big);
    std.mem.writeInt(u64, patched[4 * 4096 ..][0..8], @as(u64, 1) << 63, .big);
    std.mem.writeInt(
        u64,
        patched[4 * 4096 + 8 ..][0..8],
        (@as(u64, 1) << 63) | 4096,
        .big,
    );

    const missing = try qcow2.parse(patched, .{});
    try std.testing.expectError(
        error.MissingQcow2DataFile,
        missing.decodeAllocLimited(allocator, input.len),
    );
    const archive = try qcow2.parse(patched, .{ .external_data_file = input });
    const decoded = try archive.decodeAllocLimited(allocator, input.len);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}

test "QCOW2 writer supports L1 tables spanning multiple clusters" {
    const cluster_size = 512;
    const guest_clusters = 65 * (cluster_size / 8);
    const input = try allocator.alloc(u8, guest_clusters * cluster_size);
    defer allocator.free(input);
    @memset(input, 0);
    input[0] = 0x51;
    input[input.len - 1] = 0xfb;
    const encoded = try qcow2.encodeAlloc(allocator, input, .{
        .version = 3,
        .cluster_bits = 9,
        .compression = .none,
    });
    defer allocator.free(encoded);
    const archive = try qcow2.parse(encoded, .{});
    try std.testing.expectEqual(@as(usize, 65), archive.header.l1_size);
    const first = try archive.readRangeAllocLimited(allocator, 0, 1, 1);
    defer allocator.free(first);
    try std.testing.expectEqualSlices(u8, input[0..1], first);
    const last = try archive.readRangeAllocLimited(
        allocator,
        input.len - 1,
        1,
        1,
    );
    defer allocator.free(last);
    try std.testing.expectEqualSlices(u8, input[input.len - 1 ..], last);
}

test "QCOW2 reader rejects malformed cluster descriptors and short L1 coverage" {
    const compressible = [_]u8{'Q'} ** 4096;
    const compressed = try qcow2.encodeAlloc(allocator, &compressible, .{
        .version = 3,
        .cluster_bits = 12,
        .compression = .zlib,
    });
    defer allocator.free(compressed);
    var patched = try allocator.dupe(u8, compressed);
    defer allocator.free(patched);
    const l2_offset = 4 * 4096;
    const compressed_entry = std.mem.readInt(u64, patched[l2_offset..][0..8], .big);
    std.mem.writeInt(
        u64,
        patched[l2_offset..][0..8],
        compressed_entry | (@as(u64, 1) << 63),
        .big,
    );
    var archive = try qcow2.parse(patched, .{});
    var output: [1]u8 = undefined;
    try std.testing.expectError(
        error.InvalidQcow2,
        archive.readRangeInto(allocator, 0, &output),
    );

    std.mem.writeInt(
        u64,
        patched[l2_offset..][0..8],
        compressed_entry | (@as(u64, 1) << 56),
        .big,
    );
    archive = try qcow2.parse(patched, .{});
    try std.testing.expectError(
        error.InvalidQcow2,
        archive.readRangeInto(allocator, 0, &output),
    );

    const normal = try qcow2.encodeAlloc(allocator, &compressible, .{
        .version = 3,
        .cluster_bits = 12,
        .compression = .none,
    });
    defer allocator.free(normal);
    @memcpy(patched, normal);
    const normal_entry = std.mem.readInt(u64, patched[l2_offset..][0..8], .big);
    std.mem.writeInt(u64, patched[l2_offset..][0..8], normal_entry | 512, .big);
    archive = try qcow2.parse(patched, .{});
    try std.testing.expectError(
        error.InvalidQcow2,
        archive.readRangeInto(allocator, 0, &output),
    );

    std.mem.writeInt(u64, patched[24..32], 513 * 4096, .big);
    try std.testing.expectError(error.InvalidQcow2, qcow2.parse(patched, .{}));
}

test "QCOW2 parser rejects malformed headers encryption and features" {
    try std.testing.expectError(error.TruncatedFrame, qcow2.parseHeader("QFI\xfb"));
    var header = [_]u8{0} ** 4096;
    std.mem.writeInt(u32, header[0..4], qcow2.magic, .big);
    std.mem.writeInt(u32, header[4..8], 3, .big);
    std.mem.writeInt(u32, header[20..24], 12, .big);
    std.mem.writeInt(u64, header[24..32], 4096, .big);
    std.mem.writeInt(u32, header[36..40], 1, .big);
    std.mem.writeInt(u64, header[40..48], 4096, .big);
    std.mem.writeInt(u32, header[96..100], 4, .big);
    std.mem.writeInt(u32, header[100..104], 104, .big);
    try std.testing.expectError(error.TruncatedFrame, qcow2.parse(&header, .{}));

    header[0] ^= 1;
    try std.testing.expectError(error.InvalidMagic, qcow2.parseHeader(&header));
    header[0] ^= 1;
    std.mem.writeInt(u32, header[32..36], 1, .big);
    try std.testing.expectError(error.EncryptedQcow2, qcow2.parseHeader(&header));
    std.mem.writeInt(u32, header[32..36], 0, .big);
    std.mem.writeInt(u64, header[72..80], @as(u64, 1) << 20, .big);
    try std.testing.expectError(
        error.UnsupportedQcow2Feature,
        qcow2.parseHeader(&header),
    );
    std.mem.writeInt(u64, header[72..80], 0, .big);
    std.mem.writeInt(u64, header[88..96], @as(u64, 1) << 1, .big);
    try std.testing.expectError(error.InvalidQcow2, qcow2.parseHeader(&header));
}

fn makeInput(alloc: std.mem.Allocator, size: usize) ![]u8 {
    const output = try alloc.alloc(u8, size);
    for (output[0..4096], 0..) |*byte, index|
        byte.* = "QCOW2-compressed-pattern\n"[index % 25];
    var state: u32 = 0x5146_49fb;
    for (output[4096..8192]) |*byte| {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        byte.* = @truncate(state);
    }
    @memset(output[8192..], 0);
    return output;
}
