const std = @import("std");
const core = @import("../../core.zig");
const format = @import("../format.zig");
pub const Error = core.Error || format.Error || error{InvalidErofs};

pub const DeviceInfo = struct {
    blocks: u64,
    unified_start: u64,
    tag: [64]u8,
};

pub const Inode = struct {
    nid: u64,
    in_metabox: bool = false,
    location: usize,
    inode_size: usize,
    xattr_size: usize,
    layout: format.Layout,
    mode: u16,
    uid: u32,
    gid: u32,
    link_count: u32,
    file_size: usize,
    modification_time: u64,
    modification_nsec: u32,
    data_block: u64,
    compressed_algorithms: [2]?format.Compression = .{ null, null },
    compressed_cluster_bits: u8 = 0,
    compressed_advise: u16 = 0,
    compressed_header_start: usize = 0,
    compressed_index_start: usize = 0,
    compressed_inline_start: usize = 0,
    compressed_inline_size: usize = 0,
    compressed_inline_logical_start: usize = 0,
    compressed_inline_kind: u2 = 0,
    fragment_offset: ?u64 = null,
    fragment_logical_start: usize = 0,
    chunk_format: u16 = 0,
    chunk_bits: u8 = 0,
    chunk_index_start: usize = 0,
    chunk_index_size: u8 = 0,
    compressed_extent_start: usize = 0,
    compressed_extent_count: usize = 0,
    compressed_extent_record_size: u8 = 0,

    pub fn fileType(self: Inode) Error!format.FileType {
        return switch (self.mode & 0xf000) {
            0x8000 => .regular,
            0x4000 => .directory,
            0xa000 => .symlink,
            0x2000 => .character_device,
            0x6000 => .block_device,
            0x1000 => .fifo,
            0xc000 => .socket,
            else => error.InvalidErofs,
        };
    }
};

pub const DirectoryEntry = struct {
    nid: u64,
    name: []const u8,
    file_type: format.FileType,
};

pub const Directory = struct {
    allocator: std.mem.Allocator,
    bytes: []u8,
    entries: []DirectoryEntry,

    pub fn deinit(self: *Directory) void {
        self.allocator.free(self.entries);
        self.allocator.free(self.bytes);
        self.* = undefined;
    }

    pub fn find(self: Directory, name: []const u8) ?DirectoryEntry {
        for (self.entries) |entry|
            if (std.mem.eql(u8, entry.name, name)) return entry;
        return null;
    }
};
