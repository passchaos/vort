const std = @import("std");

const format = @import("erofs/format.zig");
const archive = @import("erofs/archive.zig");
const codec = @import("erofs/codec.zig");

pub const Error = format.Error || archive.Error || std.mem.Allocator.Error;
pub const Archive = archive.Archive;
pub const Directory = archive.Directory;
pub const DirectoryEntry = archive.DirectoryEntry;
pub const FileType = format.FileType;
pub const Inode = archive.Inode;
pub const Layout = format.Layout;
pub const Superblock = format.Superblock;
pub const parse = archive.Archive.init;
pub const parseSuperblock = format.parseSuperblock;

test {
    _ = format;
    _ = archive;
    _ = codec;
}
