const std = @import("std");
const archive = @import("archive.zig");
const writer = @import("writer.zig");
const bzip2 = @import("../bzip2.zig");
const br = @import("../br.zig");
const compress_z = @import("../compress_z.zig");
const deflate = @import("../deflate.zig");
const lz4 = @import("../lz4.zig");
const lzip = @import("../lzip.zig");
const lzf = @import("../lzf.zig");
const lzma = @import("../lzma.zig");
const lzop = @import("../lzop.zig");
const xz = @import("../xz.zig");
const zstd = @import("../zstd.zig");

pub const Error = archive.Error || writer.Error || bzip2.Error || br.Error || compress_z.Error || deflate.Error || lz4.Error || lzip.Error || lzf.Error || lzma.Error || lzop.Error || xz.Error || zstd.Error || error{
    UnknownCpioCompression,
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
    archive_options: writer.EncodeOptions = .{},
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
    if (archive.parse(input)) |_| return .none else |_| {}
    if (hasCpioMagic(input)) return .none;
    if (input.len >= 2 and input[0] == 0x1f and input[1] == 0x8b) return .gzip;
    if (input.len >= 2 and input[0] == 0x1f and input[1] == 0x9d) return .compress_z;
    if (input.len >= 3 and std.mem.eql(u8, input[0..3], "BZh")) return .bzip2;
    if (input.len >= 6 and std.mem.eql(u8, input[0..6], &.{ 0xfd, '7', 'z', 'X', 'Z', 0 })) return .xz;
    if (input.len >= 4 and std.mem.readInt(u32, input[0..4], .little) == 0x184d_2204) return .lz4;
    if (input.len >= 4 and std.mem.eql(u8, input[0..4], "LZIP")) return .lzip;
    if (input.len >= 2 and std.mem.eql(u8, input[0..2], "ZV")) return .lzf;
    if (input.len >= 4 and std.mem.readInt(u32, input[0..4], .little) == 0xfd2f_b528) return .zstandard;
    if (input.len >= 9 and std.mem.eql(u8, input[0..9], &lzop.header_magic)) return .lzop;
    if (looksLikeLzma(input)) return .lzma;
    return .none;
}

fn looksLikeLzma(input: []const u8) bool {
    const header = lzma.parseHeader(input) catch return false;
    return if (header.uncompressed_size) |size| size >= archive.binary_header_size else true;
}

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    entries: []const writer.EncodeEntry,
    options: EncodeOptions,
) ![]u8 {
    const cpio_bytes = try writer.encodeAlloc(allocator, entries, options.archive_options);
    if (options.compression == .none) return cpio_bytes;
    defer allocator.free(cpio_bytes);
    return switch (options.compression) {
        .none => unreachable,
        .gzip => deflate.encodeGzipBestAlloc(allocator, cpio_bytes, options.gzip_options),
        .bzip2 => bzip2.encodeAlloc(allocator, cpio_bytes, options.bzip2_options),
        .brotli => br.encodeSimpleStreamAlloc(allocator, cpio_bytes),
        .compress_z => compress_z.encodeAlloc(allocator, cpio_bytes, options.compress_z_options),
        .lzma => lzma.encodeAlloc(allocator, cpio_bytes, options.lzma_options),
        .xz => xz.encodeAlloc(allocator, cpio_bytes, options.xz_options),
        .lz4 => lz4.encodeFrameWithLevelAndOptionsAlloc(
            allocator,
            cpio_bytes,
            options.lz4_level,
            options.lz4_options,
        ),
        .lzip => lzip.encodeAlloc(allocator, cpio_bytes, options.lzip_options),
        .lzf => lzf.encodeAlloc(allocator, cpio_bytes, options.lzf_options),
        .zstandard => zstd.encodeFrameWithLevelAndOptionsAlloc(
            allocator,
            cpio_bytes,
            options.zstd_level,
            options.zstd_options,
        ),
        .lzop => lzop.encodeAlloc(allocator, cpio_bytes, options.lzop_options),
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
    try output.appendSlice(allocator, encoded);
    return encoded.len;
}

pub fn decodeAutoAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    max_cpio_size: usize,
) !OwnedArchive {
    const compression = detect(input);
    if (compression != .none) return decodeAlloc(allocator, input, compression, max_cpio_size);
    if (archive.parse(input)) |_| return decodeAlloc(allocator, input, .none, max_cpio_size) else |_| {}
    // Preserve structural CPIO diagnostics when the container magic is
    // present. Brotli has no magic and is only a fallback for inputs that do
    // not already identify themselves as a CPIO archive.
    if (hasCpioMagic(input)) return decodeAlloc(allocator, input, .none, max_cpio_size);

    const bytes = br.decodeStreamAllocLimited(allocator, input, max_cpio_size) catch |err| switch (err) {
        error.OutOfMemory, error.OutputLimitExceeded => return err,
        else => return error.UnknownCpioCompression,
    };
    errdefer allocator.free(bytes);
    return .{
        .bytes = bytes,
        .archive = try archive.parse(bytes),
        .compression = .brotli,
    };
}

fn hasCpioMagic(input: []const u8) bool {
    if (input.len >= 6 and (std.mem.eql(u8, input[0..6], archive.magic_newc) or
        std.mem.eql(u8, input[0..6], archive.magic_crc) or
        std.mem.eql(u8, input[0..6], archive.magic_odc))) return true;
    if (input.len < 2) return false;
    return std.mem.readInt(u16, input[0..2], .little) == archive.binary_magic or
        std.mem.readInt(u16, input[0..2], .big) == archive.binary_magic;
}

pub fn decodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    compression: Compression,
    max_cpio_size: usize,
) !OwnedArchive {
    const bytes = switch (compression) {
        .none => blk: {
            if (input.len > max_cpio_size) return error.OutputLimitExceeded;
            break :blk try allocator.dupe(u8, input);
        },
        .gzip => try deflate.decodeGzipAllocLimited(allocator, input, max_cpio_size),
        .bzip2 => try bzip2.decodeAllocLimited(allocator, input, max_cpio_size),
        .brotli => try br.decodeStreamAllocLimited(allocator, input, max_cpio_size),
        .compress_z => try compress_z.decodeAllocLimited(allocator, input, max_cpio_size),
        .lzma => try lzma.decodeAllocLimited(allocator, input, max_cpio_size),
        .xz => try xz.decodeAllocLimited(allocator, input, max_cpio_size),
        .lz4 => try lz4.decodeFrameAllocLimited(allocator, input, max_cpio_size),
        .lzip => try lzip.decodeAllocLimited(allocator, input, max_cpio_size),
        .lzf => try lzf.decodeAllocLimited(allocator, input, max_cpio_size),
        .zstandard => try zstd.decodeFrameAllocLimited(allocator, input, max_cpio_size),
        .lzop => try lzop.decodeAllocLimited(allocator, input, max_cpio_size),
    };
    errdefer allocator.free(bytes);
    return .{
        .bytes = bytes,
        .archive = try archive.parse(bytes),
        .compression = compression,
    };
}

test "compressed CPIO wrappers round trip every available encoder" {
    const allocator = std.testing.allocator;
    const entries = [_]writer.EncodeEntry{
        .{ .name = "folder", .kind = .directory },
        .{ .name = "folder/data.txt", .data = "cpio wrapper payload " ** 32 },
    };
    inline for (.{ Compression.none, .gzip, .bzip2, .brotli, .compress_z, .lzma, .xz, .lz4, .lzip, .lzf, .zstandard, .lzop }) |compression| {
        const encoded = try encodeAlloc(allocator, &entries, .{ .compression = compression });
        defer allocator.free(encoded);
        if (compression == .brotli)
            try std.testing.expectEqual(Compression.none, detect(encoded))
        else
            try std.testing.expectEqual(compression, detect(encoded));
        const decoded = try decodeAutoAlloc(allocator, encoded, 1024 * 1024);
        defer decoded.deinit(allocator);
        try std.testing.expectEqual(compression, decoded.compression);
        try std.testing.expectEqual(@as(usize, 2), decoded.archive.entry_count);
        const payload = try decoded.archive.extractByNameAllocLimited(
            allocator,
            "folder/data.txt",
            1024 * 1024,
        );
        defer allocator.free(payload);
        try std.testing.expectEqualSlices(u8, entries[1].data, payload);
    }
}

test "compressed CPIO auto decode is bounded and rejects non-CPIO Brotli" {
    const allocator = std.testing.allocator;
    const entries = [_]writer.EncodeEntry{.{ .name = "payload", .data = "bounded cpio" }};
    const raw = try writer.encodeAlloc(allocator, &entries, .{});
    defer allocator.free(raw);
    const encoded = try br.encodeSimpleStreamAlloc(allocator, raw);
    defer allocator.free(encoded);
    try std.testing.expectError(
        error.OutputLimitExceeded,
        decodeAutoAlloc(allocator, encoded, raw.len - 1),
    );
    try std.testing.expectError(
        error.TruncatedFrame,
        decodeAutoAlloc(allocator, raw[0..100], 1024 * 1024),
    );
    const non_cpio = try br.encodeStoredStreamAlloc(allocator, "valid Brotli but not CPIO");
    defer allocator.free(non_cpio);
    try std.testing.expectError(
        error.InvalidMagic,
        decodeAutoAlloc(allocator, non_cpio, 1024 * 1024),
    );
}
