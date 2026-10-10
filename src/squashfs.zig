const std = @import("std");

const format = @import("squashfs/format.zig");
const codec = @import("squashfs/codec.zig");
const metadata = @import("squashfs/metadata.zig");
const archive = @import("squashfs/archive.zig");
const writer = @import("squashfs/writer.zig");

pub const Error = format.Error || codec.Error || std.mem.Allocator.Error;
pub const Compression = format.Compression;
pub const Flags = format.Flags;
pub const InodeKind = format.InodeKind;
pub const Superblock = format.Superblock;
pub const Archive = archive.Archive;
pub const Directory = archive.Directory;
pub const DirectoryEntry = archive.DirectoryEntry;
pub const Inode = archive.Inode;
pub const EncodeEntry = writer.Entry;
pub const EncodeEntryKind = writer.EntryKind;
pub const EncodeMode = writer.Mode;
pub const EncodeOptions = writer.Options;
pub const parseSuperblock = format.parseSuperblock;
pub const parse = archive.Archive.init;
pub const encodeAlloc = writer.encodeAlloc;
pub const encodeAppend = writer.encodeAppend;

test {
    _ = format;
    _ = codec;
    _ = metadata;
    _ = archive;
    _ = writer;
}
