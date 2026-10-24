const std = @import("std");
const archive_module = @import("../../archive.zig");
const format = @import("../../format.zig");

pub const Kind = enum { partial, whole_fragment, mixed, holes };
pub const algorithms = [_]format.Compression{ .lz4, .lzma, .deflate, .zstandard };
pub const fixtures = [_][]const u8{
    @embedFile("../../testdata/partial-extent-lz4.erofs.b64"),
    @embedFile("../../testdata/partial-extent-lzma.erofs.b64"),
    @embedFile("../../testdata/partial-extent-deflate.erofs.b64"),
    @embedFile("../../testdata/partial-extent-zstd.erofs.b64"),
};

pub fn fixtureAlloc(allocator: std.mem.Allocator, index: usize) ![]u8 {
    const decoder = std.base64.standard.decoderWithIgnore(" \r\n\t");
    const storage = try allocator.alloc(u8, decoder.calcSizeUpperBound(fixtures[index].len));
    errdefer allocator.free(storage);
    return allocator.realloc(storage, try decoder.decode(storage, fixtures[index]));
}

pub fn fullPrefixAlloc(allocator: std.mem.Allocator, index: usize) ![]u8 {
    var extent = try firstExtentAlloc(allocator, index);
    defer extent.deinit(allocator);
    return allocator.dupe(u8, extent.decoded[0..4096]);
}

pub const Extent = struct {
    encoded: []u8,
    decoded: []u8,
    pub fn deinit(self: *Extent, allocator: std.mem.Allocator) void {
        allocator.free(self.encoded);
        allocator.free(self.decoded);
    }
};

pub fn firstExtentAlloc(allocator: std.mem.Allocator, index: usize) !Extent {
    const image = try fixtureAlloc(allocator, index);
    defer allocator.free(image);
    const archive = try archive_module.Archive.init(image);
    const value = try archive.inode(archive.superblock.packed_nid);
    var reader = try archive.initExtractor(allocator, value, .{ .max_output_len = value.file_size });
    defer reader.deinit();
    var byte: [1]u8 = undefined;
    _ = try reader.read(&byte);
    const segment = reader.segment orelse return error.InvalidErofs;
    const encoded = segment.content.encoded;
    const bytes = try allocator.dupe(u8, image[@intCast(encoded.start)..][0..encoded.encoded_size]);
    errdefer allocator.free(bytes);
    return .{ .encoded = bytes, .decoded = try allocator.dupe(u8, reader.cached orelse return error.InvalidErofs) };
}

pub fn refresh(image: []u8) void {
    std.mem.writeInt(u32, image[1028..1032], format.computeSuperblockChecksum(image[1024..4096]), .little);
}

pub fn header(image: []const u8) !usize {
    const archive = try archive_module.Archive.init(image);
    return (try archive.inode(96)).compressed_header_start;
}

pub fn expectedAlloc(allocator: std.mem.Allocator, full: []const u8, size: u8, kind: Kind, prefix_len: usize) ![]u8 {
    const prefix = if (size <= 8 and size != 0) full.len else 17;
    const leading = if (size <= 8) full.len else 5;
    return switch (kind) {
        .partial => allocator.dupe(u8, full[0..prefix_len]),
        .whole_fragment => allocator.dupe(u8, full[8..17]),
        .mixed => std.mem.concat(allocator, u8, &.{ full[0..prefix], full[8..17] }),
        .holes => output: {
            const bytes = try allocator.alloc(u8, leading + prefix + 7);
            @memset(bytes, 0);
            @memcpy(bytes[leading..][0..prefix], full[0..prefix]);
            break :output bytes;
        },
    };
}

fn record(image: []u8, start: usize, size: u8, plen: u32, physical: u64, logical: usize) void {
    std.mem.writeInt(u32, image[start..][0..4], plen, .little);
    if (size >= 8) std.mem.writeInt(u32, image[start + 4 ..][0..4], @truncate(physical), .little);
    if (size >= 16) {
        std.mem.writeInt(u32, image[start + 8 ..][0..4], @truncate(physical >> 32), .little);
        std.mem.writeInt(u32, image[start + 12 ..][0..4], @truncate(logical), .little);
    }
    if (size == 32) std.mem.writeInt(u32, image[start + 16 ..][0..4], @truncate(@as(u64, logical) >> 32), .little);
}

/// Size zero selects the legacy full-index PARTIAL_REF head. Other sizes
/// construct independently fsck-validated modern layouts from immutable data.
pub fn build(allocator: std.mem.Allocator, index: usize, size: u8, kind: Kind, prefix_len: usize) ![]u8 {
    const image = try fixtureAlloc(allocator, index);
    errdefer allocator.free(image);
    const archive = try archive_module.Archive.init(image);
    const inode = try archive.inode(96);
    const full = try fullPrefixAlloc(allocator, index);
    defer allocator.free(full);
    const expected = try expectedAlloc(allocator, full, size, kind, prefix_len);
    defer allocator.free(expected);
    if (inode.inode_size == 32) std.mem.writeInt(u32, image[inode.location + 8 ..][0..4], @intCast(expected.len), .little) else std.mem.writeInt(u64, image[inode.location + 8 ..][0..8], expected.len, .little);
    const head = inode.compressed_header_start;
    @memset(image[head..][0..160], 0);
    if (size == 0) {
        if (kind != .partial) return error.InvalidErofs;
        image[head + 6] = @intFromEnum(algorithms[index]);
        std.mem.writeInt(u16, image[head + 16 ..][0..2], 0x8001, .little);
        std.mem.writeInt(u32, image[head + 20 ..][0..4], 1, .little);
    } else {
        const count: u32 = switch (kind) {
            .partial, .whole_fragment => 1,
            .mixed => 2,
            .holes => 3,
        };
        const bits: u16 = switch (size) {
            4 => 0,
            8 => 1,
            16 => 2,
            32 => 3,
            else => return error.InvalidErofs,
        };
        const fragment = kind == .whole_fragment or kind == .mixed;
        std.mem.writeInt(u32, image[head..][0..4], count, .little);
        std.mem.writeInt(u16, image[head + 4 ..][0..2], 1 | (bits << 1) | (if (fragment) @as(u16, 0x20) else 0), .little);
        const start = std.mem.alignForward(usize, head + 8, size);
        const base = start + (if (size == 4) @as(usize, 8) else 0);
        if (size == 4) std.mem.writeInt(u64, image[start..][0..8], 4096, .little);
        const word: u32 = 4096 | (@as(u32, @intFromEnum(algorithms[index]) + 1) << 28) | (1 << 27);
        const prefix: usize = if (size <= 8) 4096 else 17;
        const leading: usize = if (size <= 8) 4096 else 5;
        switch (kind) {
            .partial => record(image, base, size, word, 4096, 0),
            .whole_fragment => record(image, base, size, 8, 0, 0),
            .mixed => {
                record(image, base, size, word, 4096, 0);
                record(image, base + size, size, 8, 0, prefix);
            },
            .holes => {
                record(image, base, size, 0, std.math.maxInt(u64), 0);
                record(image, base + size, size, word, 4096, leading);
                record(image, base + size * 2, size, 0, std.math.maxInt(u64), leading + prefix);
            },
        }
    }
    refresh(image);
    return image;
}
