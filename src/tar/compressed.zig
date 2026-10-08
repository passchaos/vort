const std = @import("std");
const archive = @import("archive.zig");
const writer = @import("writer.zig");
const bzip2 = @import("../bzip2.zig");
const deflate = @import("../deflate.zig");
const xz = @import("../xz.zig");
const zstd = @import("../zstd.zig");

pub const Error = archive.Error || writer.Error || bzip2.Error || xz.Error || zstd.Error || deflate.Error || error{
    UnknownTarCompression,
};

pub const Compression = enum {
    none,
    gzip,
    bzip2,
    xz,
    zstandard,
};

pub const EncodeOptions = struct {
    compression: Compression = .none,
    gzip_options: deflate.CompressionOptions = deflate.optionsForLevel(.default),
    bzip2_options: bzip2.EncodeOptions = .{},
    xz_options: xz.EncodeOptions = .{},
    zstd_level: c_int = zstd.default_compression_level,
    zstd_options: zstd.FrameOptions = .{},
};

pub const OwnedArchive = struct {
    bytes: []u8,
    archive: archive.Archive,

    pub fn deinit(self: OwnedArchive, allocator: std.mem.Allocator) void {
        allocator.free(self.bytes);
    }
};

pub fn detect(input: []const u8) Compression {
    if (input.len >= 2 and input[0] == 0x1f and input[1] == 0x8b) return .gzip;
    if (input.len >= 3 and std.mem.eql(u8, input[0..3], "BZh")) return .bzip2;
    if (input.len >= 6 and std.mem.eql(u8, input[0..6], &.{ 0xfd, '7', 'z', 'X', 'Z', 0 })) return .xz;
    if (input.len >= 4 and std.mem.readInt(u32, input[0..4], .little) == 0xfd2f_b528) return .zstandard;
    return .none;
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
        .xz => xz.encodeStoredAlloc(allocator, tar_bytes, options.xz_options),
        .zstandard => zstd.encodeFrameWithLevelAndOptionsAlloc(
            allocator,
            tar_bytes,
            options.zstd_level,
            options.zstd_options,
        ),
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
    return decodeAlloc(allocator, input, detect(input), max_tar_size);
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
        .xz => try xz.decodeAllocLimited(allocator, input, max_tar_size),
        .zstandard => try zstd.decodeFrameAllocLimited(allocator, input, max_tar_size),
    };
    errdefer allocator.free(bytes);
    return .{ .bytes = bytes, .archive = try archive.parse(bytes) };
}

test "compressed TAR wrappers round trip every available encoder" {
    const allocator = std.testing.allocator;
    const entries = [_]writer.EncodeEntry{
        .{ .name = "folder/", .kind = .directory },
        .{ .name = "folder/data.txt", .data = "tarball payload " ** 64 },
    };
    inline for (.{ Compression.none, .gzip, .bzip2, .xz, .zstandard }) |compression| {
        const encoded = try encodeAlloc(allocator, &entries, .{ .compression = compression });
        defer allocator.free(encoded);
        try std.testing.expectEqual(compression, detect(encoded));
        const decoded = try decodeAutoAlloc(allocator, encoded, 1024 * 1024);
        defer decoded.deinit(allocator);
        try std.testing.expectEqual(@as(usize, 2), decoded.archive.entry_count);
        const payload = try decoded.archive.extractByNameAlloc(allocator, "folder/data.txt");
        defer allocator.free(payload);
        try std.testing.expectEqualSlices(u8, entries[1].data, payload);
    }
}
