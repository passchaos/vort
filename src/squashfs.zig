const std = @import("std");

const format = @import("squashfs/format.zig");
const codec = @import("squashfs/codec.zig");
const metadata = @import("squashfs/metadata.zig");
const archive = @import("squashfs/archive.zig");

pub const Error = format.Error || codec.Error || std.mem.Allocator.Error;
pub const Compression = format.Compression;
pub const Flags = format.Flags;
pub const InodeKind = format.InodeKind;
pub const Superblock = format.Superblock;
pub const Archive = archive.Archive;
pub const Directory = archive.Directory;
pub const DirectoryEntry = archive.DirectoryEntry;
pub const Inode = archive.Inode;
pub const parseSuperblock = format.parseSuperblock;
pub const parse = archive.Archive.init;

test {
    _ = format;
    _ = codec;
    _ = metadata;
    _ = archive;
}
