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
pub const feature_compat_plain_xattr_prefixes: u32 = 0x0000_0010;
pub const feature_compat_shared_xattrs_in_metabox: u32 = 0x0000_0008;
pub const feature_incompat_compression_config: u32 = 0x0000_0002;
pub const feature_incompat_chunked_file: u32 = 0x0000_0004;
pub const feature_incompat_device_table: u32 = 0x0000_0008;
pub const feature_incompat_ztailpacking: u32 = 0x0000_0010;
pub const feature_incompat_fragments: u32 = 0x0000_0020;
pub const feature_incompat_xattr_prefixes: u32 = 0x0000_0040;
pub const feature_incompat_48bit: u32 = 0x0000_0080;
pub const feature_incompat_metabox: u32 = 0x0000_0100;

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
    xattr_prefix_count: u8,
    xattr_prefix_start: u32,
    packed_nid: u64,
    metabox_nid: u64,
    extra_devices: u16,
    device_slot_offset: u16,
    available_compression_algorithms: u16,
    build_time: u32,

    pub fn imageSize(self: Superblock) Error!usize {
        const count = std.math.cast(usize, self.block_count) orelse return error.IntegerOverflow;
        return std.math.mul(usize, count, self.block_size) catch
            return error.IntegerOverflow;
    }

    pub fn imageSize64(self: Superblock) Error!u64 {
        return std.math.mul(u64, self.block_count, self.block_size) catch return error.IntegerOverflow;
    }
};

pub fn parseSuperblock(input: []const u8) Error!Superblock {
    return parseSuperblockInternal(input, input.len, true);
}

/// Parses a resident superblock/checksum region against the declared stable
/// input length, allowing Source users to retain only the header block.
pub fn parseSuperblockWithLength(input: []const u8, input_len: u64) Error!Superblock {
    return parseSuperblockInternal(input, input_len, false);
}

fn parseSuperblockInternal(input: []const u8, input_len: u64, host_size: bool) Error!Superblock {
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
    const feature_compat = readU32(bytes, 8);
    // The foundational reader handles legacy LZ4 padding and compressor
    // configuration records and long-xattr-prefix tables. Other
    // incompatible features alter addressing.
    if (feature_incompat & ~@as(u32, 0x0000_01ff) != 0)
        return error.UnsupportedErofsFeature;
    const extra_devices = readU16(bytes, 86);
    const device_slot_offset = readU16(bytes, 88);
    if (extra_devices != 0 and feature_incompat & feature_incompat_device_table == 0)
        return error.InvalidErofs;
    if (extra_devices == 0 and
        (feature_incompat & feature_incompat_device_table != 0 or device_slot_offset != 0))
        return error.InvalidErofs;
    const xattr_prefix_count = bytes[91];
    const xattr_prefix_start = readU32(bytes, 92);
    const packed_nid = readU64(bytes, 96);
    if (packed_nid >> 63 != 0) return error.InvalidErofs;
    if (feature_incompat & feature_incompat_fragments == 0 and packed_nid != 0)
        return error.InvalidErofs;
    const metabox_nid = if (feature_incompat & feature_incompat_metabox != 0) blk: {
        if (super_size < 136) return error.InvalidErofs;
        const value = readU64(bytes, 128);
        if (value == 0 or value >> 63 != 0) return error.InvalidErofs;
        break :blk value;
    } else 0;
    if (feature_incompat & feature_incompat_xattr_prefixes != 0) {
        if (xattr_prefix_count == 0 or xattr_prefix_count > 0x80)
            return error.InvalidErofs;
    } else if (xattr_prefix_count != 0 or xattr_prefix_start != 0) {
        return error.InvalidErofs;
    }
    const root_nid_8 = readU64(bytes, 112);
    const uses_high_addresses = feature_incompat & feature_incompat_48bit != 0 and
        root_nid_8 != 0;
    const blocks: u64 = @as(u64, readU32(bytes, 36)) |
        (if (uses_high_addresses) @as(u64, readU16(bytes, 14)) << 32 else 0);
    const image_size = std.math.mul(u64, blocks, block_size) catch
        return error.IntegerOverflow;
    if (host_size) _ = std.math.cast(usize, image_size) orelse return error.IntegerOverflow;
    if (blocks == 0 or image_size > input_len) return error.TruncatedFrame;
    const checksum = readU32(bytes, 4);
    if (feature_compat & 1 != 0) {
        const checksum_len = if (block_size > super_offset)
            block_size - super_offset
        else
            block_size;
        if (super_offset + checksum_len > input.len) return error.TruncatedFrame;
        if (computeSuperblockChecksum(input[super_offset..][0..checksum_len]) != checksum)
            return error.ChecksumMismatch;
    }
    const root_nid: u64 = if (uses_high_addresses) root_nid_8 else readU16(bytes, 14);
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
        .xattr_prefix_count = xattr_prefix_count,
        .xattr_prefix_start = xattr_prefix_start,
        .packed_nid = packed_nid,
        .metabox_nid = metabox_nid,
        .extra_devices = extra_devices,
        .device_slot_offset = device_slot_offset,
        .available_compression_algorithms = readU16(bytes, 84),
        .build_time = readU32(bytes, 108),
    };
}

pub fn computeSuperblockChecksum(block_tail: []const u8) u32 {
    var state: u32 = 0xffff_ffff;
    for (block_tail, 0..) |byte, index| {
        const value: u8 = if (index >= 4 and index < 8) 0 else byte;
        state ^= value;
        for (0..8) |_| state = (state >> 1) ^
            (if (state & 1 != 0) @as(u32, 0x82f6_3b78) else 0);
    }
    return state;
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
