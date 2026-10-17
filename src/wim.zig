const std = @import("std");
const format = @import("wim/format.zig");
const codec = @import("wim/codec.zig");
const metadata = @import("wim/metadata.zig");
const archive = @import("wim/archive.zig");
const set = @import("wim/set.zig");

pub const Error = format.Error || codec.Error || metadata.Error || archive.Error || set.Error ||
    std.mem.Allocator.Error;
pub const Archive = archive.Archive;
pub const ArchiveSet = set.ArchiveSet;
pub const Compression = format.Compression;
pub const Dentry = metadata.Dentry;
pub const Directory = metadata.Directory;
pub const ExtraStream = metadata.ExtraStream;
pub const ExtraStreamIterator = metadata.ExtraStreamIterator;
pub const Header = format.Header;
pub const ImageMetadata = metadata.ImageMetadata;
pub const LookupEntry = archive.LookupEntry;
pub const LookupKind = archive.LookupKind;
pub const LookupTable = archive.LookupTable;
pub const PathLimits = archive.PathLimits;
pub const ResourceHeader = format.ResourceHeader;
pub const SecurityData = metadata.SecurityData;
pub const SolidResource = archive.SolidResource;
pub const StreamSelector = archive.StreamSelector;
pub const parse = archive.Archive.init;
pub const parseHeader = format.parseHeader;
pub const parseImageMetadataOwned = metadata.ImageMetadata.fromOwnedBytes;
pub const solidResourceMagic = archive.solid_resource_magic;

test {
    _ = format;
    _ = codec;
    _ = metadata;
    _ = archive;
    _ = set;
}
