const std = @import("std");
const archive_module = @import("../../archive.zig");
const format = @import("../../format.zig");
const indices = @import("../../compression_index.zig");
const partial = @import("partial_helpers.zig");

pub const mapping_start: u32 = 64;
pub const Owner = struct {
    image: []u8,
    blob: []u8,
    pub fn deinit(self: *Owner, allocator: std.mem.Allocator) void {
        allocator.free(self.image);
        allocator.free(self.blob);
    }
};

pub fn refresh(image: []u8) void {
    std.mem.writeInt(u32, image[1028..1032], format.computeSuperblockChecksum(image[1024..4096]), .little);
}

pub fn addTable(image: []u8, table: usize, blocks: usize) void {
    @memset(image[table..][0..128], 0);
    @memcpy(image[table..][0..4], "vort");
    std.mem.writeInt(u32, image[table + 64 ..][0..4], @intCast(blocks), .little);
    std.mem.writeInt(u32, image[table + 68 ..][0..4], mapping_start, .little);
    std.mem.writeInt(u32, image[1104..1108], format.readU32(image, 1104) | format.feature_incompat_device_table, .little);
    std.mem.writeInt(u16, image[1110..1112], 1, .little);
    std.mem.writeInt(u16, image[1112..1114], @intCast(table / 128), .little);
}

fn address(original: u64, within: usize) !u64 {
    if (original < 4096) return error.InvalidErofs;
    return mapping_start * @as(u64, 4096) + original - 4096 + within;
}

/// Offload a normal data inode or its packed owner. Metadata stays in the
/// primary image and the encoded bytes remain immutable reference data.
pub fn offload(allocator: std.mem.Allocator, original: []const u8, target: archive_module.Inode, within: usize) !Owner {
    if (target.in_metabox) return error.InvalidErofs;
    const image = try allocator.alloc(u8, original.len + 4096);
    errdefer allocator.free(image);
    @memset(image, 0);
    @memcpy(image[0..original.len], original);
    const blob_size = std.mem.alignForward(usize, original.len - 4096 + within, 4096);
    const blob = try allocator.alloc(u8, blob_size);
    errdefer allocator.free(blob);
    @memset(blob, 0);
    @memcpy(blob[within..][0 .. original.len - 4096], original[4096..]);
    const base = try archive_module.Archive.init(original);
    const value = if (target.fragment_offset != null) try base.inode(base.superblock.packed_nid) else target;
    if (value.layout == .flat_plain or value.layout == .flat_inline) {
        if (within != 0) return error.InvalidErofs;
        const mapped = try address(value.data_block * 4096, 0);
        std.mem.writeInt(u32, image[value.location + 16 ..][0..4], @intCast(mapped / 4096), .little);
    } else if (value.compressed_extent_record_size != 0) {
        const size = value.compressed_extent_record_size;
        if (size == 4) {
            const old = format.readU64(image, value.compressed_extent_start);
            std.mem.writeInt(u64, image[value.compressed_extent_start..][0..8], try address(old, within), .little);
        } else for (0..value.compressed_extent_count) |index| {
            if (value.compressed_advise & 0x20 != 0 and index + 1 == value.compressed_extent_count) continue;
            const start = value.compressed_extent_start + index * size;
            if (format.readU32(image, start) & 0x001f_ffff == 0) continue;
            const old = @as(u64, format.readU32(image, start + 4)) | (if (size >= 16) @as(u64, format.readU32(image, start + 8)) << 32 else 0);
            const mapped = try address(old, within);
            std.mem.writeInt(u32, image[start + 4 ..][0..4], @truncate(mapped), .little);
            if (size >= 16) std.mem.writeInt(u32, image[start + 8 ..][0..4], @truncate(mapped >> 32), .little);
        }
    } else {
        if (within != 0) return error.InvalidErofs;
        const count = (value.file_size + 4095) / 4096;
        if (value.layout == .compressed_full) {
            for (0..count) |index| {
                const start = value.compressed_index_start + index * 8;
                if (format.readU16(image, start) & 3 == 2) continue;
                const block = format.readU32(image, start + 4);
                std.mem.writeInt(u32, image[start + 4 ..][0..4], @intCast((try address(@as(u64, block) * 4096, 0)) / 4096), .little);
            }
        } else if (value.layout == .compressed_compact) {
            const view = indices.View{ .index_start = value.compressed_index_start, .cluster_bits = value.compressed_cluster_bits, .advise = value.compressed_advise, .block_size = 4096 };
            var previous: ?usize = null;
            for (0..count) |index| {
                const offset = try indices.compactPhysicalBaseOffset(view, index, count);
                if (previous == offset) continue;
                previous = offset;
                const block = format.readU32(image, offset);
                std.mem.writeInt(u32, image[offset..][0..4], block + mapping_start - 1, .little);
            }
        } else return error.UnsupportedErofsLayout;
    }
    addTable(image, original.len, blob_size / 4096);
    std.mem.writeInt(u32, image[1060..1064], @intCast(image.len / 4096), .little);
    refresh(image);
    return .{ .image = image, .blob = blob };
}

pub fn modern(allocator: std.mem.Allocator, index: usize, size: u8, within: usize) !Owner {
    const original = try partial.build(allocator, index, size, .partial, 17);
    defer allocator.free(original);
    const archive = try archive_module.Archive.init(original);
    return offload(allocator, original, try archive.inode(96), within);
}
