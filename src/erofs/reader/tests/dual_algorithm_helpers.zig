const std = @import("std");
const format = @import("../../format.zig");

pub const algorithms = [_]format.Compression{ .lz4, .lzma, .deflate, .zstandard };
pub const Layout = enum { full, compact, inline_full, inline_compact, partial_full };
pub const first = "primary algorithm history and literals\n" ** 128;
pub const second = "secondary algorithm history and literals\n" ** 128;
pub const root_nid = 64;
pub const file_nid = 96;
pub const header_start = file_nid * 32 + 32;

const blocks = [4][3][]const u8{
    .{ @embedFile("../../testdata/dual-lz4-first.bin.b64"), @embedFile("../../testdata/dual-lz4-second.bin.b64"), @embedFile("../../testdata/dual-lz4-inline.bin.b64") },
    .{ @embedFile("../../testdata/dual-lzma-first.bin.b64"), @embedFile("../../testdata/dual-lzma-second.bin.b64"), @embedFile("../../testdata/dual-lzma-inline.bin.b64") },
    .{ @embedFile("../../testdata/dual-deflate-first.bin.b64"), @embedFile("../../testdata/dual-deflate-second.bin.b64"), @embedFile("../../testdata/dual-deflate-inline.bin.b64") },
    .{ @embedFile("../../testdata/dual-zstd-first.bin.b64"), @embedFile("../../testdata/dual-zstd-second.bin.b64"), @embedFile("../../testdata/dual-zstd-inline.bin.b64") },
};

fn encodedBlock(algorithm: format.Compression, index: usize, buffer: []u8) ![]const u8 {
    const decoder = std.base64.standard.decoderWithIgnore(" \r\n\t");
    return buffer[0..try decoder.decode(buffer, blocks[@intFromEnum(algorithm)][index])];
}

pub fn expectedAlloc(allocator: std.mem.Allocator, layout: Layout) ![]u8 {
    if (layout == .partial_full) return allocator.dupe(u8, second[0..17]);
    const tail_size: usize = if (layout == .inline_full or layout == .inline_compact) 123 else 4096;
    return std.mem.concat(allocator, u8, &.{ first[0..4096], second[0..tail_size] });
}

pub fn build(allocator: std.mem.Allocator, primary: format.Compression, secondary: format.Compression, layout: Layout) ![]u8 {
    const inline_tail = layout == .inline_full or layout == .inline_compact;
    const compact = layout == .compact or layout == .inline_compact;
    const partial = layout == .partial_full;
    const image = try allocator.alloc(u8, if (inline_tail or partial) 8192 else 12288);
    errdefer allocator.free(image);
    @memset(image, 0);
    std.mem.writeInt(u32, image[1024..1028], format.magic, .little);
    std.mem.writeInt(u32, image[1032..1036], 3, .little);
    image[1036] = 12;
    std.mem.writeInt(u16, image[1038..1040], root_nid, .little);
    std.mem.writeInt(u64, image[1040..1048], 2, .little);
    std.mem.writeInt(u32, image[1060..1064], @intCast(image.len / 4096), .little);
    std.mem.writeInt(u32, image[1104..1108], 3 | (if (inline_tail) @as(u32, format.feature_incompat_ztailpacking) else 0), .little);
    const mask = (@as(u16, 1) << @as(u4, @intCast(@intFromEnum(primary)))) | (@as(u16, 1) << @as(u4, @intCast(@intFromEnum(secondary))));
    std.mem.writeInt(u16, image[1108..1110], mask, .little);
    var configuration: usize = 1152;
    for (algorithms) |algorithm| {
        if (mask & (@as(u16, 1) << @as(u4, @intCast(@intFromEnum(algorithm)))) == 0) continue;
        if (algorithm == .lz4) {
            std.mem.writeInt(u16, image[configuration..][0..2], 14, .little);
            std.mem.writeInt(u16, image[configuration + 2 ..][0..2], 0xffff, .little);
            std.mem.writeInt(u16, image[configuration + 4 ..][0..2], 1, .little);
            configuration += 16;
        } else {
            const bytes: []const u8 = switch (algorithm) {
                .lzma => &.{ 14, 0, 0, 128, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
                .deflate => &.{ 6, 0, 15, 0, 0, 0, 0, 0 },
                .zstandard => &.{ 6, 0, 0, 5, 0, 0, 0, 0 },
                .lz4 => unreachable,
            };
            @memcpy(image[configuration..][0..bytes.len], bytes);
            configuration += bytes.len;
        }
    }
    const root = root_nid * 32;
    std.mem.writeInt(u16, image[root..][0..2], 4, .little);
    std.mem.writeInt(u16, image[root + 4 ..][0..2], 0x41ed, .little);
    std.mem.writeInt(u16, image[root + 6 ..][0..2], 2, .little);
    std.mem.writeInt(u32, image[root + 8 ..][0..4], 43, .little);
    std.mem.writeInt(u32, image[root + 16 ..][0..4], 0xffffffff, .little);
    const directory = root + 32;
    std.mem.writeInt(u64, image[directory..][0..8], root_nid, .little);
    std.mem.writeInt(u16, image[directory + 8 ..][0..2], 36, .little);
    image[directory + 10] = 2;
    std.mem.writeInt(u64, image[directory + 12 ..][0..8], root_nid, .little);
    std.mem.writeInt(u16, image[directory + 20 ..][0..2], 37, .little);
    image[directory + 22] = 2;
    std.mem.writeInt(u64, image[directory + 24 ..][0..8], file_nid, .little);
    std.mem.writeInt(u16, image[directory + 32 ..][0..2], 39, .little);
    image[directory + 34] = 1;
    @memcpy(image[directory + 36 ..][0..7], "...file");
    const node = file_nid * 32;
    std.mem.writeInt(u16, image[node..][0..2], if (compact) 6 else 2, .little);
    std.mem.writeInt(u16, image[node + 4 ..][0..2], 0x81a4, .little);
    std.mem.writeInt(u16, image[node + 6 ..][0..2], 1, .little);
    const file_size: u32 = if (partial) 17 else if (inline_tail) 4219 else 8192;
    std.mem.writeInt(u32, image[node + 8 ..][0..4], file_size, .little);
    std.mem.writeInt(u32, image[node + 16 ..][0..4], if (inline_tail or partial) 1 else 2, .little);
    image[header_start + 6] = @intFromEnum(primary) | (@as(u8, @intFromEnum(secondary)) << 4);
    const indices = header_start + (if (compact) @as(usize, 8) else 16);
    if (compact) {
        std.mem.writeInt(u16, image[indices..][0..2], 1 << 12, .little);
        std.mem.writeInt(u16, image[indices + 2 ..][0..2], 3 << 12, .little);
        std.mem.writeInt(u32, image[indices + 4 ..][0..4], 0, .little);
    } else {
        std.mem.writeInt(u16, image[indices..][0..2], if (partial) 0x8003 else 1, .little);
        std.mem.writeInt(u32, image[indices + 4 ..][0..4], 1, .little);
        if (!partial) {
            std.mem.writeInt(u16, image[indices + 8 ..][0..2], 3, .little);
            std.mem.writeInt(u32, image[indices + 12 ..][0..4], if (inline_tail) 0 else 2, .little);
        }
    }
    var scratch: [256]u8 = undefined;
    const encoded_first = if (partial) try encodedBlock(secondary, 1, &scratch) else try encodedBlock(primary, 0, &scratch);
    if (encoded_first.len >= 4096) return error.InvalidErofs;
    @memcpy(image[8192 - encoded_first.len .. 8192], encoded_first);
    if (!partial) {
        const encoded_second = try encodedBlock(secondary, if (inline_tail) 2 else 1, &scratch);
        if (encoded_second.len >= 4096) return error.InvalidErofs;
        if (inline_tail) {
            const inline_start = indices + (if (compact) @as(usize, 8) else 16);
            std.mem.writeInt(u16, image[header_start + 2 ..][0..2], @intCast(encoded_second.len), .little);
            std.mem.writeInt(u16, image[header_start + 4 ..][0..2], 8, .little);
            @memcpy(image[inline_start..][0..encoded_second.len], encoded_second);
        } else @memcpy(image[12288 - encoded_second.len .. 12288], encoded_second);
    }
    refresh(image);
    return image;
}

pub fn refresh(image: []u8) void {
    std.mem.writeInt(u32, image[1028..1032], format.computeSuperblockChecksum(image[1024..4096]), .little);
}

/// Store the visible metadata in a flat hidden metabox inode while preserving
/// primary physical extent addresses. This is an independent format layout.
pub fn wrapMetabox(allocator: std.mem.Allocator, original: []const u8) ![]u8 {
    const image = try allocator.alloc(u8, original.len + 4096);
    errdefer allocator.free(image);
    @memcpy(image[0..original.len], original);
    @memcpy(image[original.len..], original[0..4096]);
    const metadata = image[original.len..];
    const high = @as(u64, 1) << 63;
    const directory = root_nid * 32 + 32;
    for (0..3) |index| {
        const offset = directory + index * 12;
        std.mem.writeInt(u64, metadata[offset..][0..8], format.readU64(metadata, offset) | high, .little);
    }
    const hidden: usize = 80 * 32;
    @memset(image[hidden..][0..32], 0);
    std.mem.writeInt(u16, image[hidden + 4 ..][0..2], 0x81a4, .little);
    std.mem.writeInt(u16, image[hidden + 6 ..][0..2], 1, .little);
    std.mem.writeInt(u32, image[hidden + 8 ..][0..4], 4096, .little);
    std.mem.writeInt(u32, image[hidden + 16 ..][0..4], @intCast(original.len / 4096), .little);
    // Relocate the configuration area beyond the metabox superblock extension.
    std.mem.copyBackwards(u8, image[1168..1296], image[1152..1280]);
    @memset(image[1152..1168], 0);
    image[1037] = 1;
    std.mem.writeInt(u16, image[1038..1040], 0, .little);
    std.mem.writeInt(u64, image[1040..1048], 3, .little);
    std.mem.writeInt(u32, image[1060..1064], @intCast(image.len / 4096), .little);
    std.mem.writeInt(u32, image[1104..1108], format.readU32(image, 1104) | format.feature_incompat_metabox | format.feature_incompat_48bit, .little);
    std.mem.writeInt(u64, image[1136..1144], root_nid | high, .little);
    std.mem.writeInt(u64, image[1152..1160], 80, .little);
    refresh(image);
    return image;
}
