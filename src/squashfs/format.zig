const std = @import("std");
const core = @import("../core.zig");

pub const Error = core.Error || error{
    InvalidSquashfs,
    UnsupportedSquashfsVersion,
    UnsupportedSquashfsCompression,
};

pub const magic: u32 = 0x7371_7368;
pub const superblock_size: usize = 96;
pub const metadata_size: usize = 8192;
pub const invalid_table: u64 = 0xffff_ffff_ffff_ffff;
pub const invalid_fragment: u32 = 0xffff_ffff;

pub const Compression = enum(u16) {
    gzip = 1,
    lzma = 2,
    lzo = 3,
    xz = 4,
    lz4 = 5,
    zstandard = 6,
};

pub const InodeKind = enum(u16) {
    directory = 1,
    regular = 2,
    symlink = 3,
    block_device = 4,
    character_device = 5,
    fifo = 6,
    socket = 7,
    long_directory = 8,
    long_regular = 9,
    long_symlink = 10,
    long_block_device = 11,
    long_character_device = 12,
    long_fifo = 13,
    long_socket = 14,
};

pub const Flags = struct {
    value: u16,

    pub fn uncompressedInodes(self: Flags) bool {
        return self.value & (1 << 0) != 0;
    }

    pub fn uncompressedData(self: Flags) bool {
        return self.value & (1 << 1) != 0;
    }

    pub fn checkData(self: Flags) bool {
        return self.value & (1 << 2) != 0;
    }

    pub fn uncompressedFragments(self: Flags) bool {
        return self.value & (1 << 3) != 0;
    }

    pub fn noFragments(self: Flags) bool {
        return self.value & (1 << 4) != 0;
    }

    pub fn compressorOptions(self: Flags) bool {
        return self.value & (1 << 10) != 0;
    }
};

pub const Superblock = struct {
    inode_count: u32,
    modification_time: u32,
    block_size: usize,
    fragment_count: u32,
    compression: Compression,
    block_log: u16,
    flags: Flags,
    id_count: u16,
    root_inode: u64,
    bytes_used: usize,
    id_table_start: u64,
    xattr_id_table_start: u64,
    inode_table_start: usize,
    directory_table_start: usize,
    fragment_table_start: u64,
    lookup_table_start: u64,

    pub fn rootBlock(self: Superblock) u32 {
        return @truncate(self.root_inode >> 16);
    }

    pub fn rootOffset(self: Superblock) u16 {
        return @truncate(self.root_inode);
    }
};

pub fn parseSuperblock(input: []const u8) Error!Superblock {
    if (input.len < superblock_size) return error.TruncatedFrame;
    if (readU32(input, 0) != magic) return error.InvalidMagic;
    const major = readU16(input, 28);
    const minor = readU16(input, 30);
    if (major != 4 or minor != 0) return error.UnsupportedSquashfsVersion;
    const compression = std.enums.fromInt(Compression, readU16(input, 20)) orelse
        return error.UnsupportedSquashfsCompression;
    const flags_value = readU16(input, 24);
    if (flags_value & ~@as(u16, 0x0fff) != 0) return error.InvalidSquashfs;
    const block_size: usize = readU32(input, 12);
    if (block_size < 4096 or block_size > 1024 * 1024 or
        !std.math.isPowerOfTwo(block_size))
        return error.InvalidSquashfs;
    const block_log = readU16(input, 22);
    if (@as(usize, 1) << @intCast(block_log) != block_size)
        return error.InvalidSquashfs;
    const bytes_used = try u64ToUsize(readU64(input, 40));
    if (bytes_used < superblock_size or bytes_used > input.len)
        return error.TruncatedFrame;
    const inode_table_start = try u64ToUsize(readU64(input, 64));
    const directory_table_start = try u64ToUsize(readU64(input, 72));
    if (inode_table_start < superblock_size or inode_table_start >= bytes_used or
        directory_table_start <= inode_table_start or directory_table_start >= bytes_used)
        return error.InvalidSquashfs;
    return .{
        .inode_count = readU32(input, 4),
        .modification_time = readU32(input, 8),
        .block_size = block_size,
        .fragment_count = readU32(input, 16),
        .compression = compression,
        .block_log = block_log,
        .flags = .{ .value = flags_value },
        .id_count = readU16(input, 26),
        .root_inode = readU64(input, 32),
        .bytes_used = bytes_used,
        .id_table_start = readU64(input, 48),
        .xattr_id_table_start = readU64(input, 56),
        .inode_table_start = inode_table_start,
        .directory_table_start = directory_table_start,
        .fragment_table_start = readU64(input, 80),
        .lookup_table_start = readU64(input, 88),
    };
}

pub fn tableEnd(superblock: Superblock, start: usize) usize {
    var end = superblock.bytes_used;
    inline for (.{
        superblock.id_table_start,
        superblock.xattr_id_table_start,
        @as(u64, @intCast(superblock.inode_table_start)),
        @as(u64, @intCast(superblock.directory_table_start)),
        superblock.fragment_table_start,
        superblock.lookup_table_start,
    }) |candidate| {
        if (candidate != invalid_table and candidate > start and candidate < end)
            end = @intCast(candidate);
    }
    return end;
}

pub fn inodeReference(block: u32, offset: u16) u64 {
    return @as(u64, block) << 16 | offset;
}

pub fn readU16(input: []const u8, offset: usize) u16 {
    return std.mem.readInt(u16, input[offset..][0..2], .little);
}

pub fn readI16(input: []const u8, offset: usize) i16 {
    return @bitCast(readU16(input, offset));
}

pub fn readU32(input: []const u8, offset: usize) u32 {
    return std.mem.readInt(u32, input[offset..][0..4], .little);
}

pub fn readU64(input: []const u8, offset: usize) u64 {
    return std.mem.readInt(u64, input[offset..][0..8], .little);
}

fn u64ToUsize(value: u64) Error!usize {
    return std.math.cast(usize, value) orelse error.IntegerOverflow;
}

test "SquashFS superblock rejects invalid versions and block sizes" {
    var bytes: [superblock_size]u8 = @splat(0);
    std.mem.writeInt(u32, bytes[0..4], magic, .little);
    std.mem.writeInt(u32, bytes[12..16], 131072, .little);
    std.mem.writeInt(u16, bytes[20..22], 1, .little);
    std.mem.writeInt(u16, bytes[22..24], 17, .little);
    std.mem.writeInt(u16, bytes[28..30], 3, .little);
    std.mem.writeInt(u64, bytes[40..48], bytes.len, .little);
    std.mem.writeInt(u64, bytes[64..72], 96, .little);
    std.mem.writeInt(u64, bytes[72..80], 97, .little);
    try std.testing.expectError(error.UnsupportedSquashfsVersion, parseSuperblock(&bytes));
}
