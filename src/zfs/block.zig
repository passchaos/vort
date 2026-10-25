const std = @import("std");
const deflate = @import("../deflate.zig");
const lz4 = @import("../lz4.zig");
const zstd = @import("../zstd.zig");
const lzjb = @import("lzjb.zig");
const zle = @import("zle.zig");

pub const Error = deflate.Error || lz4.Error || zstd.Error || lzjb.Error ||
    zle.Error || std.mem.Allocator.Error || error{
    InvalidZfsBlock,
    UnsupportedZfsCompression,
    IncompressibleZfsBlock,
};

pub const Algorithm = enum(u8) {
    inherit = 0,
    on = 1,
    off = 2,
    lzjb = 3,
    empty = 4,
    gzip_1 = 5,
    gzip_2 = 6,
    gzip_3 = 7,
    gzip_4 = 8,
    gzip_5 = 9,
    gzip_6 = 10,
    gzip_7 = 11,
    gzip_8 = 12,
    gzip_9 = 13,
    zle = 14,
    lz4 = 15,
    zstd = 16,

    pub fn gzipLevel(self: Algorithm) ?u4 {
        return switch (self) {
            .gzip_1 => 1,
            .gzip_2 => 2,
            .gzip_3 => 3,
            .gzip_4 => 4,
            .gzip_5 => 5,
            .gzip_6 => 6,
            .gzip_7 => 7,
            .gzip_8 => 8,
            .gzip_9 => 9,
            else => null,
        };
    }
};

pub const EncodeOptions = struct {
    /// Native Zstd level, restricted to levels OpenZFS can represent on disk:
    /// 1...19, -1...-10, -20...-100 in steps of 10, -500 and -1000.
    zstd_level: c_int = 3,
    zstd_version: u32 = 10507,
};

pub const ZstdMetadata = struct {
    compressed_size: usize,
    /// OpenZFS wire enum: positive levels are 1...19; fast levels 103...123.
    level: u8,
    version: u32,
};

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    algorithm: Algorithm,
    input: []const u8,
    options: EncodeOptions,
) Error![]u8 {
    if (input.len == 0 and algorithm != .off and algorithm != .empty)
        return error.InvalidZfsBlock;
    const encoded = switch (algorithm) {
        .inherit, .on => return error.UnsupportedZfsCompression,
        .off => return allocator.dupe(u8, input),
        .empty => blk: {
            for (input) |byte| if (byte != 0) return error.InvalidZfsBlock;
            break :blk try allocator.alloc(u8, 0);
        },
        .lzjb => try lzjb.encodeAlloc(allocator, input),
        .zle => try zle.encodeAlloc(allocator, input),
        .lz4 => try encodeLz4Alloc(allocator, input),
        .zstd => try encodeZstdAlloc(allocator, input, options),
        else => try deflate.encodeZlibLevelAlloc(
            allocator,
            input,
            algorithm.gzipLevel() orelse return error.UnsupportedZfsCompression,
        ),
    };
    errdefer allocator.free(encoded);
    if (algorithm != .off and algorithm != .empty and encoded.len >= input.len)
        return error.IncompressibleZfsBlock;
    return encoded;
}

pub fn decodeAllocExactSize(
    allocator: std.mem.Allocator,
    algorithm: Algorithm,
    input: []const u8,
    expected_size: usize,
) Error![]u8 {
    return switch (algorithm) {
        .inherit, .on => error.UnsupportedZfsCompression,
        .off => blk: {
            if (input.len != expected_size) return error.SizeMismatch;
            break :blk allocator.dupe(u8, input);
        },
        .empty => blk: {
            if (input.len != 0) return error.InvalidZfsBlock;
            const output = try allocator.alloc(u8, expected_size);
            @memset(output, 0);
            break :blk output;
        },
        .lzjb => lzjb.decodeAllocExactSize(allocator, input, expected_size),
        .zle => zle.decodeAllocExactSize(allocator, input, expected_size),
        .lz4 => decodeLz4Alloc(allocator, input, expected_size),
        .zstd => decodeZstdAlloc(allocator, input, expected_size),
        else => deflate.decodeZlibAllocWithOptionsExactSize(
            allocator,
            input,
            .{ .allow_trailing_data = true },
            expected_size,
        ),
    };
}

pub fn parseZstdMetadata(input: []const u8) Error!ZstdMetadata {
    if (input.len < 8) return error.TruncatedFrame;
    const compressed_size: usize = std.mem.readInt(u32, input[0..4], .big);
    if (compressed_size > input.len - 8) return error.InvalidZfsBlock;
    const raw = std.mem.readInt(u32, input[4..8], .big);
    const metadata = decodeZstdVersionLevel(raw);
    if (!validZstdLevel(metadata.level)) return error.InvalidZfsBlock;
    return .{
        .compressed_size = compressed_size,
        .level = metadata.level,
        .version = metadata.version,
    };
}

fn encodeLz4Alloc(
    allocator: std.mem.Allocator,
    input: []const u8,
) Error![]u8 {
    const compressed = try lz4.encodeBlockAlloc(allocator, input);
    defer allocator.free(compressed);
    const size = std.math.add(usize, 4, compressed.len) catch
        return error.IntegerOverflow;
    const output = try allocator.alloc(u8, size);
    errdefer allocator.free(output);
    std.mem.writeInt(
        u32,
        output[0..4],
        std.math.cast(u32, compressed.len) orelse return error.IntegerOverflow,
        .big,
    );
    @memcpy(output[4..], compressed);
    return output;
}

fn decodeLz4Alloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    expected_size: usize,
) Error![]u8 {
    if (input.len < 4) return error.TruncatedFrame;
    const compressed_size: usize = std.mem.readInt(u32, input[0..4], .big);
    if (compressed_size > input.len - 4) return error.InvalidZfsBlock;
    const output = try allocator.alloc(u8, expected_size);
    errdefer allocator.free(output);
    const written = try lz4.decodeBlockIntoSlice(
        input[4..][0..compressed_size],
        output,
        expected_size,
    );
    if (written != expected_size) return error.SizeMismatch;
    return output;
}

fn encodeZstdAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: EncodeOptions,
) Error![]u8 {
    const wire_level = zstdWireLevel(options.zstd_level) orelse
        return error.InvalidZfsBlock;
    if (options.zstd_version > 0x00ff_ffff) return error.InvalidZfsBlock;
    const payload = try zstd.encodeFrameWithLevelAndOptionsAlloc(
        allocator,
        input,
        options.zstd_level,
        .{ .format = .magicless, .include_content_size = false, .content_checksum = false },
    );
    defer allocator.free(payload);
    const compressed_size = payload.len;
    const output = try allocator.alloc(u8, 8 + compressed_size);
    errdefer allocator.free(output);
    std.mem.writeInt(
        u32,
        output[0..4],
        std.math.cast(u32, compressed_size) orelse return error.IntegerOverflow,
        .big,
    );
    const version_level = (@as(u32, wire_level) << 24) |
        options.zstd_version;
    std.mem.writeInt(u32, output[4..8], version_level, .big);
    @memcpy(output[8..], payload);
    return output;
}

fn decodeZstdAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    expected_size: usize,
) Error![]u8 {
    const metadata = try parseZstdMetadata(input);
    return zstd.decodeFrameAllocWithOptions(allocator, input[8..][0..metadata.compressed_size], .{
        .format = .magicless,
        .expected_output_len = expected_size,
        .max_output_len = expected_size,
    });
}

fn decodeZstdVersionLevel(raw: u32) struct { level: u8, version: u32 } {
    var zero_shift: usize = 0;
    while (zero_shift < 4 and @as(u8, @truncate(raw >> @intCast(8 * zero_shift))) != 0)
        zero_shift += 1;
    return switch (zero_shift) {
        0 => .{
            .level = @truncate(raw >> 24),
            .version = (@byteSwap(raw) >> 8) & 0x00ff_ffff,
        },
        1 => .{
            .level = @truncate(raw),
            .version = @byteSwap(raw) & 0x00ff_ffff,
        },
        2 => .{
            .level = @truncate(raw >> 24),
            .version = raw & 0x00ff_ffff,
        },
        3 => .{
            .level = @truncate(raw),
            .version = (raw >> 8) & 0x00ff_ffff,
        },
        else => .{ .level = 0, .version = 0 },
    };
}

// OpenZFS zfs-2.4.0 include/sys/zio_compress.h (zio_zstd_levels) and
// module/zstd/zfs_zstd.c (zstd_levels). FAST=102 is a property alias,
// while encoded blocks use the explicit FAST_1...FAST_1000 values 103...123.
fn zstdWireLevel(level: c_int) ?u8 {
    return switch (level) {
        1...19 => @intCast(level),
        -10...-1 => @intCast(102 - level),
        -20 => 113,
        -30 => 114,
        -40 => 115,
        -50 => 116,
        -60 => 117,
        -70 => 118,
        -80 => 119,
        -90 => 120,
        -100 => 121,
        -500 => 122,
        -1000 => 123,
        else => null,
    };
}

fn validZstdLevel(level: u8) bool {
    return (level >= 1 and level <= 19) or (level >= 103 and level <= 123);
}

test "ZFS block codecs round trip compressible data" {
    var input: [16 * 1024]u8 = @splat(0);
    for (0..256) |index| {
        const offset = index * 32;
        @memcpy(input[offset..][0..16], "ZFS-block-data!!");
    }
    const algorithms = [_]Algorithm{
        .lzjb,
        .gzip_1,
        .gzip_6,
        .gzip_9,
        .zle,
        .lz4,
        .zstd,
    };
    for (algorithms) |algorithm| {
        const encoded = try encodeAlloc(std.testing.allocator, algorithm, &input, .{});
        defer std.testing.allocator.free(encoded);
        try std.testing.expect(encoded.len < input.len);
        const decoded = try decodeAllocExactSize(
            std.testing.allocator,
            algorithm,
            encoded,
            input.len,
        );
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, &input, decoded);
    }
}

test "ZFS block adapters accept physical padding" {
    var input: [8192]u8 = @splat(0);
    for (0..64) |index|
        @memcpy(input[index * 32 ..][0..16], "ZFS-padding-data");
    inline for (.{ Algorithm.lzjb, Algorithm.gzip_6, Algorithm.zle, Algorithm.lz4, Algorithm.zstd }) |algorithm| {
        const encoded = try encodeAlloc(std.testing.allocator, algorithm, &input, .{});
        defer std.testing.allocator.free(encoded);
        const padded = try std.testing.allocator.alloc(u8, encoded.len + 64);
        defer std.testing.allocator.free(padded);
        @memcpy(padded[0..encoded.len], encoded);
        @memset(padded[encoded.len..], 0xa5);
        const decoded = try decodeAllocExactSize(
            std.testing.allocator,
            algorithm,
            padded,
            input.len,
        );
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, &input, decoded);
    }
}

test "ZFS empty and uncompressed block modes are exact" {
    const plain = "uncompressed ZFS block";
    const encoded = try encodeAlloc(std.testing.allocator, .off, plain, .{});
    defer std.testing.allocator.free(encoded);
    const decoded = try decodeAllocExactSize(std.testing.allocator, .off, encoded, plain.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualStrings(plain, decoded);

    const zeros = [_]u8{0} ** 4096;
    const empty = try encodeAlloc(std.testing.allocator, .empty, &zeros, .{});
    defer std.testing.allocator.free(empty);
    try std.testing.expectEqual(@as(usize, 0), empty.len);
    const expanded = try decodeAllocExactSize(std.testing.allocator, .empty, empty, zeros.len);
    defer std.testing.allocator.free(expanded);
    try std.testing.expectEqualSlices(u8, &zeros, expanded);
}

test "ZFS Zstd metadata reports level and version" {
    const input = "ZFS Zstd metadata payload" ** 128;
    const encoded = try encodeAlloc(std.testing.allocator, .zstd, input, .{
        .zstd_level = 3,
        .zstd_version = 10507,
    });
    defer std.testing.allocator.free(encoded);
    const metadata = try parseZstdMetadata(encoded);
    try std.testing.expectEqual(@as(u8, 3), metadata.level);
    try std.testing.expectEqual(@as(u32, 10507), metadata.version);
    try std.testing.expectEqual(encoded.len - 8, metadata.compressed_size);

    const historical = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(historical);
    historical[4] = 0;
    historical[5] = 0x29;
    historical[6] = 0x0b;
    historical[7] = 3;
    const historical_metadata = try parseZstdMetadata(historical);
    try std.testing.expectEqual(@as(u8, 3), historical_metadata.level);
    try std.testing.expectEqual(@as(u32, 10507), historical_metadata.version);
    const decoded = try decodeAllocExactSize(
        std.testing.allocator,
        .zstd,
        historical,
        input.len,
    );
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualStrings(input, decoded);
}

test {
    _ = @import("fast_levels_tests.zig");
}
