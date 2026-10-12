const std = @import("std");
const core = @import("../core.zig");

pub const Error = core.Error || error{
    InvalidWdf,
    UnsupportedWdfFeature,
};

pub const magic = "WII\x01DISC";
pub const magic_size: usize = 8;
pub const header_size: usize = 56;
pub const v1_chunk_size: usize = 28;
pub const v2_chunk_size: usize = 24;
pub const default_alignment: u32 = 4;
pub const max_alignment: u32 = 1 << 30;

pub const Version = enum(u32) {
    v1 = 1,
    v2 = 2,

    pub fn chunkSize(self: Version) usize {
        return switch (self) {
            .v1 => v1_chunk_size,
            .v2 => v2_chunk_size,
        };
    }
};

pub const Header = struct {
    version: Version,
    head_size: u32,
    align_factor: u32,
    compatible_version: u32,
    logical_size: u64,
    data_size: u64,
    chunk_count: usize,
    chunk_offset: u64,
    physical_size: u64,
};

pub const Chunk = struct {
    file_pos: u64,
    data_offset: u64,
    data_size: u64,

    pub fn logicalEnd(self: Chunk) Error!u64 {
        return add(self.file_pos, self.data_size);
    }

    pub fn physicalEnd(self: Chunk) Error!u64 {
        return add(self.data_offset, self.data_size);
    }
};

pub fn readU32Be(input: []const u8, offset: usize) u32 {
    return std.mem.readInt(u32, input[offset..][0..4], .big);
}

pub fn readU64Be(input: []const u8, offset: usize) u64 {
    return std.mem.readInt(u64, input[offset..][0..8], .big);
}

pub fn writeU32Be(output: []u8, offset: usize, value: u32) void {
    std.mem.writeInt(u32, output[offset..][0..4], value, .big);
}

pub fn writeU64Be(output: []u8, offset: usize, value: u64) void {
    std.mem.writeInt(u64, output[offset..][0..8], value, .big);
}

fn add(lhs: u64, rhs: u64) Error!u64 {
    return std.math.add(u64, lhs, rhs) catch error.IntegerOverflow;
}
