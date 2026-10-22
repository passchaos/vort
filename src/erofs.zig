const std = @import("std");

const format = @import("erofs/format.zig");
const archive = @import("erofs/archive.zig");
const codec = @import("erofs/codec.zig");
const writer = @import("erofs/writer.zig");
const xattr = @import("erofs/xattr.zig");

pub const Error = format.Error || archive.Error || writer.Error || xattr.Error || std.mem.Allocator.Error;
pub const Archive = archive.Archive;
pub const Directory = archive.Directory;
pub const DirectoryEntry = archive.DirectoryEntry;
pub const Entry = writer.Entry;
pub const EntryKind = writer.EntryKind;
pub const FileType = format.FileType;
pub const Inode = archive.Inode;
pub const ReadLimits = archive.ReadLimits;
pub const Xattr = xattr.Attribute;
pub const Xattrs = xattr.Attributes;
pub const Layout = format.Layout;
pub const Superblock = format.Superblock;
pub const WriterCompression = writer.Compression;
pub const WriterOptions = writer.Options;
pub const WriterTailPacking = writer.TailPacking;
pub const encodeAlloc = writer.encodeAlloc;
pub const parse = archive.Archive.init;
pub const parseSuperblock = format.parseSuperblock;
pub const defaultPackedExtentLimit = archive.default_packed_extent_limit;

test {
    _ = format;
    _ = archive;
    _ = @import("erofs/archive_tests.zig");
    _ = codec;
    _ = writer;
    _ = @import("erofs/writer_fragment_tests.zig");
    _ = @import("erofs/writer_tail_tests.zig");
    _ = xattr;
}
