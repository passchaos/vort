const std = @import("std");
const core = @import("../core.zig");

pub const Error = core.Error || error{
    InvalidAndroidSparse,
    UnsupportedAndroidSparseFeature,
};

pub const magic: u32 = 0xed26_ff3a;
pub const major_version: u16 = 1;
pub const base_header_size: usize = 28;
pub const base_chunk_header_size: usize = 12;

pub const ChunkType = enum(u16) {
    raw = 0xcac1,
    fill = 0xcac2,
    dont_care = 0xcac3,
    crc32 = 0xcac4,
};

pub const Header = struct {
    major: u16,
    minor: u16,
    file_header_size: usize,
    chunk_header_size: usize,
    block_size: usize,
    total_blocks: usize,
    total_chunks: usize,
    image_checksum: u32,
    logical_size: u64,
    physical_size: usize,
};

pub const Chunk = struct {
    kind: ChunkType,
    logical_offset: u64,
    block_count: usize,
    logical_size: u64,
    payload_offset: usize,
    fill_value: u32,
};

pub fn readU16Le(input: []const u8, offset: usize) u16 {
    return std.mem.readInt(u16, input[offset..][0..2], .little);
}

pub fn readU32Le(input: []const u8, offset: usize) u32 {
    return std.mem.readInt(u32, input[offset..][0..4], .little);
}

pub fn writeU16Le(output: []u8, offset: usize, value: u16) void {
    std.mem.writeInt(u16, output[offset..][0..2], value, .little);
}

pub fn writeU32Le(output: []u8, offset: usize, value: u32) void {
    std.mem.writeInt(u32, output[offset..][0..4], value, .little);
}
