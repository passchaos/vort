const std = @import("std");
const archive = @import("archive.zig");
const writer = @import("writer.zig");
const bzip2 = @import("../bzip2.zig");
const br = @import("../br.zig");
const compress_z = @import("../compress_z.zig");
const deflate = @import("../deflate.zig");
const lz4 = @import("../lz4.zig");
const lz4_legacy = @import("../lz4_legacy.zig");
const lzip = @import("../lzip.zig");
const lzf = @import("../lzf.zig");
const lzma = @import("../lzma.zig");
const lzop = @import("../lzop.zig");
const xz = @import("../xz.zig");
const zstd = @import("../zstd.zig");

pub const Error = archive.Error || writer.Error || bzip2.Error || br.Error || compress_z.Error || lz4.Error || lz4_legacy.Error || lzip.Error || lzf.Error || lzma.Error || lzop.Error || xz.Error || zstd.Error || deflate.Error || error{
    UnknownTarCompression,
};

pub const Compression = enum {
    none,
    gzip,
    bzip2,
    brotli,
    compress_z,
    lzma,
    xz,
    lz4,
    lzip,
    lzf,
    zstandard,
    lzop,
};

pub const EncodeOptions = struct {
    compression: Compression = .none,
    gzip_options: deflate.CompressionOptions = deflate.optionsForLevel(.default),
    bzip2_options: bzip2.EncodeOptions = .{},
    compress_z_options: compress_z.EncodeOptions = .{},
    lzma_options: lzma.EncodeOptions = .{},
    xz_options: xz.EncodeOptions = .{},
    lz4_level: c_int = lz4.default_compression_level,
    lz4_options: lz4.FrameOptions = .{},
    lzip_options: lzip.EncodeOptions = .{},
    lzf_options: lzf.EncodeOptions = .{},
    zstd_level: c_int = zstd.default_compression_level,
    zstd_options: zstd.FrameOptions = .{},
    lzop_options: lzop.EncodeOptions = .{},
};

pub const OwnedArchive = struct {
    bytes: []u8,
    archive: archive.Archive,
    compression: Compression,

    pub fn deinit(self: OwnedArchive, allocator: std.mem.Allocator) void {
        allocator.free(self.bytes);
    }
};

pub fn detect(input: []const u8) Compression {
    // LZMA-Alone and Brotli have no magic. Prefer a structurally valid
    // uncompressed TAR before examining wrapper signatures or the heuristic
    // LZMA header. Brotli is deliberately left to decodeAutoAlloc's bounded
    // decode-and-validate fallback.
    if (archive.parse(input)) |_| return .none else |_| {}
    if (input.len >= 2 and input[0] == 0x1f and input[1] == 0x8b) return .gzip;
    if (input.len >= 2 and input[0] == 0x1f and input[1] == 0x9d) return .compress_z;
    if (input.len >= 3 and std.mem.eql(u8, input[0..3], "BZh")) return .bzip2;
    if (input.len >= 6 and std.mem.eql(u8, input[0..6], &.{ 0xfd, '7', 'z', 'X', 'Z', 0 })) return .xz;
    if (input.len >= 4 and (std.mem.readInt(u32, input[0..4], .little) == 0x184d_2204 or
        lz4_legacy.isLegacy(input))) return .lz4;
    if (input.len >= 4 and std.mem.eql(u8, input[0..4], "LZIP")) return .lzip;
    if (input.len >= 2 and std.mem.eql(u8, input[0..2], "ZV")) return .lzf;
    if (input.len >= 4 and std.mem.readInt(u32, input[0..4], .little) == 0xfd2f_b528) return .zstandard;
    if (input.len >= 9 and std.mem.eql(u8, input[0..9], &lzop.header_magic)) return .lzop;
    if (looksLikeLzmaTar(input)) return .lzma;
    return .none;
}

fn looksLikeLzmaTar(input: []const u8) bool {
    const header = lzma.parseHeader(input) catch return false;
    const size = header.uncompressed_size orelse return true;
    // Every complete TAR is 512-byte aligned. Requiring at least the standard
    // two end blocks prevents ordinary short data with a syntactically valid
    // LZMA property byte from being auto-classified as `.tar.lzma`.
    return size >= 2 * 512 and size % 512 == 0;
}

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    entries: []const writer.EncodeEntry,
    options: EncodeOptions,
) ![]u8 {
    const tar_bytes = try writer.encodeAlloc(allocator, entries);
    if (options.compression == .none) return tar_bytes;
    defer allocator.free(tar_bytes);
    return switch (options.compression) {
        .none => unreachable,
        .gzip => deflate.encodeGzipBestAlloc(allocator, tar_bytes, options.gzip_options),
        .bzip2 => bzip2.encodeAlloc(allocator, tar_bytes, options.bzip2_options),
        .brotli => br.encodeSimpleStreamAlloc(allocator, tar_bytes),
        .compress_z => compress_z.encodeAlloc(allocator, tar_bytes, options.compress_z_options),
        .lzma => lzma.encodeAlloc(allocator, tar_bytes, options.lzma_options),
        .xz => xz.encodeAlloc(allocator, tar_bytes, options.xz_options),
        .lz4 => lz4.encodeFrameWithLevelAndOptionsAlloc(
            allocator,
            tar_bytes,
            options.lz4_level,
            options.lz4_options,
        ),
        .lzip => lzip.encodeAlloc(allocator, tar_bytes, options.lzip_options),
        .lzf => lzf.encodeAlloc(allocator, tar_bytes, options.lzf_options),
        .zstandard => zstd.encodeFrameWithLevelAndOptionsAlloc(
            allocator,
            tar_bytes,
            options.zstd_level,
            options.zstd_options,
        ),
        .lzop => lzop.encodeAlloc(allocator, tar_bytes, options.lzop_options),
    };
}

pub fn encodeAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    entries: []const writer.EncodeEntry,
    options: EncodeOptions,
) !usize {
    const encoded = try encodeAlloc(allocator, entries, options);
    defer allocator.free(encoded);
    try output.ensureUnusedCapacity(allocator, encoded.len);
    output.appendSliceAssumeCapacity(encoded);
    return encoded.len;
}

pub fn decodeAutoAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    max_tar_size: usize,
) !OwnedArchive {
    const compression = detect(input);
    if (compression != .none) return decodeAlloc(allocator, input, compression, max_tar_size);
    if (archive.parse(input)) |_| return decodeAlloc(allocator, input, .none, max_tar_size) else |_| {}

    const bytes = br.decodeStreamAllocLimited(allocator, input, max_tar_size) catch |err| switch (err) {
        error.OutOfMemory, error.OutputLimitExceeded => return err,
        else => return error.UnknownTarCompression,
    };
    errdefer allocator.free(bytes);
    return .{
        .bytes = bytes,
        .archive = try archive.parse(bytes),
        .compression = .brotli,
    };
}

pub fn decodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    compression: Compression,
    max_tar_size: usize,
) !OwnedArchive {
    const bytes = switch (compression) {
        .none => blk: {
            if (input.len > max_tar_size) return error.OutputLimitExceeded;
            break :blk try allocator.dupe(u8, input);
        },
        .gzip => try deflate.decodeGzipAllocLimited(allocator, input, max_tar_size),
        .bzip2 => try bzip2.decodeAllocLimited(allocator, input, max_tar_size),
        .brotli => try br.decodeStreamAllocLimited(allocator, input, max_tar_size),
        .compress_z => try compress_z.decodeAllocLimited(allocator, input, max_tar_size),
        .lzma => try lzma.decodeAllocLimited(allocator, input, max_tar_size),
        .xz => try xz.decodeAllocLimited(allocator, input, max_tar_size),
        .lz4 => if (lz4_legacy.isLegacy(input))
            try lz4_legacy.decodeAllocLimited(allocator, input, max_tar_size)
        else
            try lz4.decodeFrameAllocLimited(allocator, input, max_tar_size),
        .lzip => try lzip.decodeAllocLimited(allocator, input, max_tar_size),
        .lzf => try lzf.decodeAllocLimited(allocator, input, max_tar_size),
        .zstandard => try zstd.decodeFrameAllocLimited(allocator, input, max_tar_size),
        .lzop => try lzop.decodeAllocLimited(allocator, input, max_tar_size),
    };
    errdefer allocator.free(bytes);
    return .{
        .bytes = bytes,
        .archive = try archive.parse(bytes),
        .compression = compression,
    };
}

test "compressed TAR wrappers round trip every available encoder" {
    const allocator = std.testing.allocator;
    const sparse_extents = [_]writer.SparseDataExtent{
        .{ .offset = 0, .data = "HEAD" },
        .{ .offset = 8188, .data = "TAIL" },
    };
    const entries = [_]writer.EncodeEntry{
        .{ .name = "folder/", .kind = .directory },
        .{ .name = "folder/data.txt", .data = "tarball payload " ** 64 },
        .{
            .name = "folder/sparse.bin",
            .sparse = .{ .logical_size = 8192, .extents = &sparse_extents },
        },
    };
    inline for (.{ Compression.none, .gzip, .bzip2, .brotli, .compress_z, .lzma, .xz, .lz4, .lzip, .lzf, .zstandard, .lzop }) |compression| {
        const encoded = try encodeAlloc(allocator, &entries, .{ .compression = compression });
        defer allocator.free(encoded);
        if (compression == .brotli)
            try std.testing.expectEqual(Compression.none, detect(encoded))
        else
            try std.testing.expectEqual(compression, detect(encoded));
        if (compression == .lzop)
            try std.testing.expect((try lzop.inspect(encoded)).compressed_block_count != 0);
        if (compression == .lzip)
            try std.testing.expectEqual(@as(usize, 1), (try lzip.inspect(allocator, encoded)).member_count);
        if (compression == .lzf)
            try std.testing.expect((try lzf.inspect(encoded)).block_count != 0);
        if (compression == .xz) {
            const tar_bytes = try writer.encodeAlloc(allocator, &entries);
            defer allocator.free(tar_bytes);
            const stored = try xz.encodeStoredAlloc(allocator, tar_bytes, .{});
            defer allocator.free(stored);
            try std.testing.expect(encoded.len < stored.len);
        }
        const decoded = try decodeAutoAlloc(allocator, encoded, 1024 * 1024);
        defer decoded.deinit(allocator);
        try std.testing.expectEqual(compression, decoded.compression);
        try std.testing.expectEqual(@as(usize, 3), decoded.archive.entry_count);
        const payload = try decoded.archive.extractByNameAlloc(allocator, "folder/data.txt");
        defer allocator.free(payload);
        try std.testing.expectEqualSlices(u8, entries[1].data, payload);
        const sparse_payload = try decoded.archive.extractByNameAlloc(
            allocator,
            "folder/sparse.bin",
        );
        defer allocator.free(sparse_payload);
        try std.testing.expectEqual(@as(usize, 8192), sparse_payload.len);
        try std.testing.expectEqualSlices(u8, "HEAD", sparse_payload[0..4]);
        try std.testing.expectEqualSlices(u8, "TAIL", sparse_payload[8188..]);
    }
}

test "TAR Brotli auto decode is bounded and requires a TAR payload" {
    const allocator = std.testing.allocator;
    const entries = [_]writer.EncodeEntry{.{ .name = "payload", .data = "bounded tar brotli" ** 32 }};
    const raw = try writer.encodeAlloc(allocator, &entries);
    defer allocator.free(raw);
    const encoded = try br.encodeSimpleStreamAlloc(allocator, raw);
    defer allocator.free(encoded);

    try std.testing.expectError(
        error.OutputLimitExceeded,
        decodeAutoAlloc(allocator, encoded, raw.len - 1),
    );
    const decoded = try decodeAutoAlloc(allocator, encoded, raw.len);
    defer decoded.deinit(allocator);
    try std.testing.expectEqual(Compression.brotli, decoded.compression);
    try std.testing.expectEqualSlices(u8, raw, decoded.bytes);

    const non_tar = try br.encodeStoredStreamAlloc(allocator, "valid Brotli but not TAR");
    defer allocator.free(non_tar);
    try std.testing.expectError(
        error.TruncatedFrame,
        decodeAutoAlloc(allocator, non_tar, 1024 * 1024),
    );
    try std.testing.expectError(
        error.UnknownTarCompression,
        decodeAutoAlloc(allocator, "not compressed data", 1024 * 1024),
    );
}

test "TAR compression detection distinguishes raw TAR and LZMA-Alone headers" {
    const allocator = std.testing.allocator;
    const entries = [_]writer.EncodeEntry{.{ .name = "payload", .data = "tar detection" }};
    const raw = try writer.encodeAlloc(allocator, &entries);
    defer allocator.free(raw);
    try std.testing.expectEqual(Compression.none, detect(raw));

    const unknown_size = try lzma.encodeAlloc(allocator, raw, .{ .size_mode = .end_marker });
    defer allocator.free(unknown_size);
    try std.testing.expectEqual(Compression.lzma, detect(unknown_size));

    const known_size = try lzma.encodeAlloc(allocator, raw, .{ .size_mode = .known });
    defer allocator.free(known_size);
    try std.testing.expectEqual(Compression.lzma, detect(known_size));

    var false_positive: [13]u8 = @splat(0);
    false_positive[0] = 0x5d;
    std.mem.writeInt(u32, false_positive[1..5], 32 * 1024, .little);
    std.mem.writeInt(u64, false_positive[5..13], 123, .little);
    try std.testing.expectEqual(Compression.none, detect(&false_positive));
}

test "TAR auto decode accepts LZ4 legacy frames" {
    const allocator = std.testing.allocator;
    const entries = [_]writer.EncodeEntry{.{ .name = "payload", .data = "legacy LZ4 tar" }};
    const raw = try writer.encodeAlloc(allocator, &entries);
    defer allocator.free(raw);
    const encoded = try lz4_legacy.encodeAlloc(allocator, raw, .{ .block_size = 1024 });
    defer allocator.free(encoded);
    try std.testing.expectEqual(Compression.lz4, detect(encoded));
    const decoded = try decodeAutoAlloc(allocator, encoded, raw.len);
    defer decoded.deinit(allocator);
    try std.testing.expectEqual(Compression.lz4, decoded.compression);
    try std.testing.expectEqualSlices(u8, raw, decoded.bytes);
}
