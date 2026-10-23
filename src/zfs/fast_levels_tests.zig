const std = @import("std");
const block = @import("block.zig");
const zstd = @import("../zstd.zig");

const fast_levels = [_]c_int{
    -1,    -2,  -3,  -4,  -5,  -6,  -7,  -8,  -9,   -10,
    -20,   -30, -40, -50, -60, -70, -80, -90, -100, -500,
    -1000,
};

test "ZFS signed Zstd levels preserve default positive wire" {
    const input = "ZFS signed Zstd level payload abcdefghijklmnopqrstuvwxyz\n" ** 512;
    const encoded = try block.encodeAlloc(std.testing.allocator, .zstd, input, .{});
    defer std.testing.allocator.free(encoded);
    const explicit = try block.encodeAlloc(std.testing.allocator, .zstd, input, .{ .zstd_level = 3 });
    defer std.testing.allocator.free(explicit);
    try std.testing.expectEqualSlices(u8, encoded, explicit);
    try std.testing.expectEqual(@as(usize, 80), encoded.len);
    var actual: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(encoded, &actual, .{});
    var expected: [32]u8 = undefined;
    _ = try std.fmt.hexToBytes(&expected, "dbef3774431140d2c57dbc6b99068b29619240943552f71b2ef697a87923fa58");
    try std.testing.expectEqual(expected, actual);
}

test "ZFS signed Zstd levels map every OpenZFS fast enum and round trip padded blocks" {
    const input = "ZFS OpenZFS fast level reference payload!\n" ** 1024;
    for (fast_levels, 0..) |level, index| {
        const encoded = try block.encodeAlloc(std.testing.allocator, .zstd, input, .{ .zstd_level = level });
        defer std.testing.allocator.free(encoded);
        const metadata = try block.parseZstdMetadata(encoded);
        const wire_level: u8 = @intCast(103 + index);
        try std.testing.expectEqual(wire_level, metadata.level);
        try std.testing.expectEqual(@as(u32, 10507), metadata.version);
        try std.testing.expectEqual(encoded.len - 8, metadata.compressed_size);
        try std.testing.expectEqual(wire_level, encoded[4]);
        try std.testing.expectEqual(@as(u32, 10507), std.mem.readInt(u32, encoded[4..8], .big) & 0x00ff_ffff);

        const frame = try zstd.encodeFrameWithLevelAndOptionsAlloc(
            std.testing.allocator,
            input,
            level,
            .{ .include_content_size = false, .content_checksum = false },
        );
        defer std.testing.allocator.free(frame);
        try std.testing.expectEqualSlices(u8, frame[4..], encoded[8..]);
        const padded = try std.testing.allocator.alloc(u8, encoded.len + 32);
        defer std.testing.allocator.free(padded);
        @memcpy(padded[0..encoded.len], encoded);
        @memset(padded[encoded.len..], 0xa5);
        const decoded = try block.decodeAllocExactSize(std.testing.allocator, .zstd, padded, input.len);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualStrings(input, decoded);

        // OpenZFS also accepts the historical opposite version/level layout.
        padded[4] = 0;
        padded[5] = 0x29;
        padded[6] = 0x0b;
        padded[7] = wire_level;
        const historical = try block.parseZstdMetadata(padded);
        try std.testing.expectEqual(wire_level, historical.level);
        try std.testing.expectEqual(@as(u32, 10507), historical.version);
        const historical_decoded = try block.decodeAllocExactSize(std.testing.allocator, .zstd, padded, input.len);
        defer std.testing.allocator.free(historical_decoded);
        try std.testing.expectEqualStrings(input, historical_decoded);
    }
}

test "ZFS signed Zstd levels reject gaps and unrepresentable controls before allocation" {
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    const allocator = failing.allocator();
    for ([_]c_int{
        std.math.minInt(c_int), -131072, -1001, -999, -501, -499,
        -101,                   -99,     -91,   -89,  -81,  -79,
        -71,                    -69,     -61,   -59,  -51,  -49,
        -41,                    -39,     -31,   -29,  -21,  -19,
        -11,                    0,       20,    22,   103,  123,
        std.math.maxInt(c_int),
    }) |level| {
        try std.testing.expectError(error.InvalidZfsBlock, block.encodeAlloc(allocator, .zstd, "payload", .{
            .zstd_level = level,
        }));
    }
    try std.testing.expectError(error.InvalidZfsBlock, block.encodeAlloc(allocator, .zstd, "payload", .{
        .zstd_level = -1,
        .zstd_version = 0x0100_0000,
    }));
    try std.testing.expect(!failing.has_induced_failure);
}

test "ZFS signed Zstd levels decode pinned upstream fast frames and validate wire metadata" {
    // zstd CLI 1.4.8, --fast=1/20 --no-check --no-content-size -c,
    // over the exact 21,504-byte payload below. Both upstream levels emit this
    // same frame; only the surrounding OpenZFS wire enum differs.
    const input = "ZFS OpenZFS fast level reference payload!\n" ** 512;
    const frame_hex = "28b52ffd00489d0100a4025a4653204f70656e5a46532066617374206c6576656c207265666572656e6365207061796c6f6164210a01009a9edaaeca";
    var frame: [frame_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&frame, frame_hex);
    var encoded: [8 + frame.len - 4]u8 = undefined;
    std.mem.writeInt(u32, encoded[0..4], frame.len - 4, .big);
    @memcpy(encoded[8..], frame[4..]);
    for ([_]u8{ 103, 113 }) |wire_level| {
        std.mem.writeInt(u32, encoded[4..8], (@as(u32, wire_level) << 24) | 10507, .big);
        const decoded = try block.decodeAllocExactSize(std.testing.allocator, .zstd, &encoded, input.len);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualStrings(input, decoded);
    }
    for ([_]u8{ 0, 20, 22, 101, 102, 124, 251, 255 }) |wire_level| {
        std.mem.writeInt(u32, encoded[4..8], (@as(u32, wire_level) << 24) | 10507, .big);
        try std.testing.expectError(error.InvalidZfsBlock, block.parseZstdMetadata(&encoded));
    }
    std.mem.writeInt(u32, encoded[4..8], (@as(u32, 103) << 24) | 10507, .big);
    std.mem.writeInt(u32, encoded[0..4], encoded.len - 7, .big);
    try std.testing.expectError(error.InvalidZfsBlock, block.parseZstdMetadata(&encoded));
    try std.testing.expectError(error.TruncatedFrame, block.parseZstdMetadata(encoded[0..7]));
}
