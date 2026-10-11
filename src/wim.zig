const std = @import("std");
const format = @import("wim/format.zig");
const codec = @import("wim/codec.zig");
const archive = @import("wim/archive.zig");

pub const Error = format.Error || codec.Error || archive.Error || std.mem.Allocator.Error;
pub const Archive = archive.Archive;
pub const Compression = format.Compression;
pub const Header = format.Header;
pub const LookupEntry = archive.LookupEntry;
pub const LookupTable = archive.LookupTable;
pub const ResourceHeader = format.ResourceHeader;
pub const parse = archive.Archive.init;
pub const parseHeader = format.parseHeader;

test {
    _ = format;
    _ = codec;
    _ = archive;
}
