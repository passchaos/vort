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

test "QCOW2 writer emits v3 backing chains with inherited and zero clusters" {
    const cluster_size = 4096;
    const parent = try allocator.alloc(u8, 3 * cluster_size);
    defer allocator.free(parent);
    for (parent, 0..) |*byte, index| byte.* = @truncate(index * 29 + 7);
    const child = try allocator.dupe(u8, parent);
    defer allocator.free(child);
    for (child[cluster_size .. 2 * cluster_size], 0..) |*byte, index|
        byte.* ^= @truncate(index * 13 + 0x51);
    @memset(child[2 * cluster_size ..], 0);

    const encoded = try qcow2.encodeAlloc(allocator, child, .{
        .version = 3,
        .cluster_bits = 12,
        .compression = .zlib,
        .backing_file = parent,
        .backing_file_name = "parent.raw",
    });
    defer allocator.free(encoded);
    const header = try qcow2.parseHeader(encoded);
    try std.testing.expectEqualStrings("parent.raw", header.backing_file_name);
    try std.testing.expectEqual(@as(u32, 0xe279_2aca), std.mem.readInt(
        u32,
        encoded[112..116],
        .big,
    ));
    try std.testing.expectEqualStrings("raw", encoded[120..123]);
    const l2_offset = 4 * cluster_size;
    try std.testing.expectEqual(@as(u64, 0), std.mem.readInt(
        u64,
        encoded[l2_offset..][0..8],
        .big,
    ));
    try std.testing.expect(std.mem.readInt(
        u64,
        encoded[l2_offset + 8 ..][0..8],
        .big,
    ) != 0);
    try std.testing.expectEqual(@as(u64, 1), std.mem.readInt(
        u64,
        encoded[l2_offset + 16 ..][0..8],
        .big,
    ));
    const missing = try qcow2.parse(encoded, .{});
    try std.testing.expectError(
        error.MissingQcow2BackingFile,
        missing.decodeAllocLimited(allocator, child.len),
    );
    const archive = try qcow2.parse(encoded, .{ .backing_file = parent });
    const decoded = try archive.decodeAllocLimited(allocator, child.len);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, child, decoded);
}

test "QCOW2 v2 backing writer allocates explicit zero overrides" {
    const parent = [_]u8{0xa5} ** 4096;
    const child = [_]u8{0} ** 4096;
    const encoded = try qcow2.encodeAlloc(allocator, &child, .{
        .version = 2,
        .cluster_bits = 12,
        .compression = .none,
        .backing_file = &parent,
        .backing_file_name = "parent.raw",
    });
    defer allocator.free(encoded);
    const header = try qcow2.parseHeader(encoded);
    try std.testing.expectEqualStrings("parent.raw", header.backing_file_name);
    try std.testing.expectEqual(@as(u32, 0xe279_2aca), std.mem.readInt(
        u32,
        encoded[72..76],
        .big,
    ));
    const l2_entry = std.mem.readInt(u64, encoded[4 * 4096 ..][0..8], .big);
    try std.testing.expect(l2_entry & (@as(u64, 1) << 63) != 0);
    const archive = try qcow2.parse(encoded, .{ .backing_file = &parent });
    const decoded = try archive.decodeAllocLimited(allocator, child.len);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &child, decoded);
}

test "QCOW2 backing writer inherits partial final sectors with zero extension" {
    const parent = ("partial-backing-sector\n" ** 32)[0..600];
    const encoded = try qcow2.encodeAlloc(allocator, parent, .{
        .version = 3,
        .cluster_bits = 12,
        .compression = .none,
        .backing_file = parent,
        .backing_file_name = "parent.raw",
    });
    defer allocator.free(encoded);
    const archive = try qcow2.parse(encoded, .{ .backing_file = parent });
    try std.testing.expectEqual(@as(u64, 1024), archive.header.virtual_size);
    try std.testing.expectEqual(@as(u64, 0), std.mem.readInt(
        u64,
        encoded[4 * 4096 ..][0..8],
        .big,
    ));
    const decoded = try archive.decodeAllocLimited(allocator, 1024);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, parent, decoded[0..parent.len]);
    for (decoded[parent.len..]) |byte| try std.testing.expectEqual(@as(u8, 0), byte);
}

test "QCOW2 backing writer validates paired metadata and header capacity" {
    const data = [_]u8{0} ** 512;
    try std.testing.expectError(
        error.InvalidQcow2,
        qcow2.encodeAlloc(allocator, &data, .{ .backing_file = &data }),
    );
    try std.testing.expectError(
        error.InvalidQcow2,
        qcow2.encodeAlloc(allocator, &data, .{ .backing_file_name = "base.raw" }),
    );
    try std.testing.expectError(
        error.InvalidQcow2,
        qcow2.encodeAlloc(allocator, &data, .{
            .backing_file = &data,
            .backing_file_name = "bad\x00name",
        }),
    );
    const long_name = [_]u8{'a'} ** 417;
    try std.testing.expectError(
        error.InvalidQcow2,
        qcow2.encodeAlloc(allocator, &data, .{
            .version = 2,
            .cluster_bits = 9,
            .backing_file = &data,
            .backing_file_name = &long_name,
        }),
    );
}

test "QCOW2 backing writer releases every allocation failure" {
    const parent = ("parent-cluster-pattern\n" ** 512)[0 .. 2 * 4096];
    var child: [2 * 4096]u8 = parent.*;
    @memset(child[4096..], 0);
    const Test = struct {
        fn run(
            failing_allocator: std.mem.Allocator,
            source: []const u8,
            backing: []const u8,
        ) !void {
            const encoded = try qcow2.encodeAlloc(failing_allocator, source, .{
                .version = 3,
                .cluster_bits = 12,
                .compression = .zlib,
                .backing_file = backing,
                .backing_file_name = "parent.raw",
            });
            defer failing_allocator.free(encoded);
            const archive = try qcow2.parse(encoded, .{ .backing_file = backing });
            const decoded = try archive.decodeAllocLimited(
                failing_allocator,
                source.len,
            );
            defer failing_allocator.free(decoded);
            try std.testing.expectEqualSlices(u8, source, decoded);
        }
    };
    try std.testing.checkAllAllocationFailures(
        allocator,
        Test.run,
        .{ &child, parent },
    );
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

test "QCOW2 external-data writer emits raw guest mappings" {
    const input = try makeInput(allocator, 2 * 4096 + 137);
    defer allocator.free(input);
    var encoded = try qcow2.encodeExternalDataAlloc(allocator, input, .{
        .cluster_bits = 12,
        .data_file_name = "payload.raw",
    });
    defer encoded.deinit(allocator);
    const virtual_size = std.mem.alignForward(usize, input.len, 512);
    try std.testing.expectEqual(virtual_size, encoded.data_file.len);
    try std.testing.expectEqualSlices(u8, input, encoded.data_file[0..input.len]);
    for (encoded.data_file[input.len..]) |byte|
        try std.testing.expectEqual(@as(u8, 0), byte);
    const header = try qcow2.parseHeader(encoded.image);
    try std.testing.expect(header.hasRawExternalDataFile());
    try std.testing.expectEqualStrings("payload.raw", header.data_file_name);
    try std.testing.expectEqual(@as(u32, 0x4441_5441), std.mem.readInt(
        u32,
        encoded.image[112..116],
        .big,
    ));
    const l2_offset = 4 * 4096;
    inline for (0..3) |cluster_index| {
        const expected = (@as(u64, 1) << 63) | cluster_index * 4096;
        try std.testing.expectEqual(expected, std.mem.readInt(
            u64,
            encoded.image[l2_offset + cluster_index * 8 ..][0..8],
            .big,
        ));
    }
    const missing = try qcow2.parse(encoded.image, .{});
    try std.testing.expectError(
        error.MissingQcow2DataFile,
        missing.decodeAllocLimited(allocator, virtual_size),
    );
    const archive = try qcow2.parse(encoded.image, .{
        .external_data_file = encoded.data_file,
    });
    const decoded = try archive.decodeAllocLimited(allocator, virtual_size);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, encoded.data_file, decoded);
    const range = try archive.readRangeAllocLimited(
        allocator,
        4096 - 31,
        4096 + 89,
        4096 + 89,
    );
    defer allocator.free(range);
    try std.testing.expectEqualSlices(
        u8,
        encoded.data_file[4096 - 31 ..][0 .. 4096 + 89],
        range,
    );
}

test "QCOW2 external-data writer handles empty images and validates names" {
    var empty = try qcow2.encodeExternalDataAlloc(allocator, "", .{
        .cluster_bits = 12,
        .data_file_name = "empty.raw",
    });
    defer empty.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 0), empty.data_file.len);
    const archive = try qcow2.parse(empty.image, .{
        .external_data_file = empty.data_file,
    });
    try std.testing.expectEqual(@as(u64, 0), archive.header.virtual_size);
    try std.testing.expectEqualStrings("empty.raw", archive.header.data_file_name);

    try std.testing.expectError(
        error.InvalidQcow2,
        qcow2.encodeExternalDataAlloc(allocator, "data", .{
            .data_file_name = "",
        }),
    );
    try std.testing.expectError(
        error.InvalidQcow2,
        qcow2.encodeExternalDataAlloc(allocator, "data", .{
            .data_file_name = "bad\x00name",
        }),
    );
    const long_name = [_]u8{'x'} ** 385;
    try std.testing.expectError(
        error.InvalidQcow2,
        qcow2.encodeExternalDataAlloc(allocator, "data", .{
            .cluster_bits = 9,
            .data_file_name = &long_name,
        }),
    );
}

test "QCOW2 external-data writer rejects malformed extension bounds" {
    var encoded = try qcow2.encodeExternalDataAlloc(allocator, "data", .{
        .cluster_bits = 12,
        .data_file_name = "payload.raw",
    });
    defer encoded.deinit(allocator);
    std.mem.writeInt(u32, encoded.image[116..120], 0xffff_ffff, .big);
    try std.testing.expectError(
        error.InvalidQcow2,
        qcow2.parseHeader(encoded.image),
    );
}

test "QCOW2 external-data writer releases every allocation failure" {
    const input = try makeInput(allocator, 2 * 4096 + 137);
    defer allocator.free(input);
    const Test = struct {
        fn run(failing_allocator: std.mem.Allocator, source: []const u8) !void {
            var encoded = try qcow2.encodeExternalDataAlloc(
                failing_allocator,
                source,
                .{ .cluster_bits = 12, .data_file_name = "payload.raw" },
            );
            defer encoded.deinit(failing_allocator);
            const archive = try qcow2.parse(encoded.image, .{
                .external_data_file = encoded.data_file,
            });
            const decoded = try archive.decodeAllocLimited(
                failing_allocator,
                encoded.data_file.len,
            );
            defer failing_allocator.free(decoded);
            try std.testing.expectEqualSlices(u8, encoded.data_file, decoded);
        }
    };
    try std.testing.checkAllAllocationFailures(allocator, Test.run, .{input});
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
