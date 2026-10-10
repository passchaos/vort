const std = @import("std");
const core = @import("../core.zig");

pub const Error = core.Error || error{
    InvalidErofs,
    UnsupportedErofsFeature,
    UnsupportedErofsLayout,
};

pub const magic: u32 = 0xe0f5_e1e2;
pub const super_offset: usize = 1024;
pub const super_base_size: usize = 128;
pub const inode_slot_size: usize = 32;
pub const name_max: usize = 255;

pub const Layout = enum(u3) {
    flat_plain = 0,
    compressed_full = 1,
    flat_inline = 2,
    compressed_compact = 3,
    chunk_based = 4,
};

pub const FileType = enum(u8) {
    unknown = 0,
    regular = 1,
    directory = 2,
    character_device = 3,
    block_device = 4,
    fifo = 5,
    socket = 6,
    symlink = 7,
};

pub const Compression = enum(u8) {
    lz4 = 0,
    lzma = 1,
    deflate = 2,
    zstandard = 3,
};

pub const Superblock = struct {
    checksum: u32,
    feature_compat: u32,
    feature_incompat: u32,
    block_bits: u8,
    block_size: usize,
    super_size: usize,
    root_nid: u64,
    inode_count: u64,
    epoch: u64,
    fixed_nsec: u32,
    block_count: u64,
    meta_block: u32,
    xattr_block: u32,
    available_compression_algorithms: u16,
    build_time: u32,

    pub fn imageSize(self: Superblock) Error!usize {
        return std.math.mul(usize, @intCast(self.block_count), self.block_size) catch
            return error.IntegerOverflow;
    }
};

pub fn parseSuperblock(input: []const u8) Error!Superblock {
    if (input.len < super_offset + super_base_size) return error.TruncatedFrame;
    const bytes = input[super_offset..];
    if (readU32(bytes, 0) != magic) return error.InvalidMagic;
    const block_bits = bytes[12];
    if (block_bits < 9 or block_bits > 16) return error.InvalidErofs;
    const block_size: usize = @as(usize, 1) << @intCast(block_bits);
    const super_size = std.math.add(
        usize,
        super_base_size,
        std.math.mul(usize, bytes[13], 16) catch return error.IntegerOverflow,
    ) catch return error.IntegerOverflow;
    if (super_size > block_size -| super_offset or super_offset + super_size > input.len)
        return error.InvalidErofs;
    const feature_incompat = readU32(bytes, 80);
    // The foundational reader handles legacy LZ4 padding and compressor
    // configuration records. Other incompatible features alter addressing.
    if (feature_incompat & ~@as(u32, 0x0000_0003) != 0)
        return error.UnsupportedErofsFeature;
    if (readU16(bytes, 86) != 0) return error.UnsupportedErofsFeature;
    const blocks: u64 = readU32(bytes, 36);
    const image_size = std.math.mul(usize, @intCast(blocks), block_size) catch
        return error.IntegerOverflow;
    if (blocks == 0 or image_size > input.len) return error.TruncatedFrame;
    const feature_compat = readU32(bytes, 8);
    const checksum = readU32(bytes, 4);
    if (feature_compat & 1 != 0) {
        const checksum_len = if (block_size > super_offset)
            block_size - super_offset
        else
            block_size;
        if (super_offset + checksum_len > input.len) return error.TruncatedFrame;
        var state: u32 = 0xffff_ffff;
        for (input[super_offset..][0..checksum_len], 0..) |byte, index| {
            const value: u8 = if (index >= 4 and index < 8) 0 else byte;
            state ^= value;
            for (0..8) |_| state = (state >> 1) ^
                (if (state & 1 != 0) @as(u32, 0x82f6_3b78) else 0);
        }
        if (state != checksum) return error.ChecksumMismatch;
    }
    const root_nid: u64 = readU16(bytes, 14);
    const inode_count = readU64(bytes, 16);
    const meta_block = readU32(bytes, 40);
    if (inode_count == 0 or meta_block >= blocks)
        return error.InvalidErofs;
    return .{
        .checksum = checksum,
        .feature_compat = feature_compat,
        .feature_incompat = feature_incompat,
        .block_bits = block_bits,
        .block_size = block_size,
        .super_size = super_size,
        .root_nid = root_nid,
        .inode_count = inode_count,
        .epoch = readU64(bytes, 24),
        .fixed_nsec = readU32(bytes, 32),
        .block_count = blocks,
        .meta_block = meta_block,
        .xattr_block = readU32(bytes, 44),
        .available_compression_algorithms = readU16(bytes, 84),
        .build_time = readU32(bytes, 108),
    };
}

pub fn readU16(input: []const u8, offset: usize) u16 {
    return std.mem.readInt(u16, input[offset..][0..2], .little);
}

pub fn readU32(input: []const u8, offset: usize) u32 {
    return std.mem.readInt(u32, input[offset..][0..4], .little);
}

pub fn readU64(input: []const u8, offset: usize) u64 {
    return std.mem.readInt(u64, input[offset..][0..8], .little);
}

test "EROFS rejects truncated and unknown incompatible superblocks" {
    try std.testing.expectError(error.TruncatedFrame, parseSuperblock(""));
    var bytes: [2048]u8 = @splat(0);
    std.mem.writeInt(u32, bytes[1024..1028], magic, .little);
    bytes[1036] = 12;
    std.mem.writeInt(u32, bytes[1060..1064], 1, .little);
    std.mem.writeInt(u64, bytes[1040..1048], 1, .little);
    std.mem.writeInt(u32, bytes[1104..1108], 0x8000_0000, .little);
    try std.testing.expectError(error.UnsupportedErofsFeature, parseSuperblock(&bytes));
}
