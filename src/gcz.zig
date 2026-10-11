const format = @import("gcz/format.zig");
const archive = @import("gcz/archive.zig");
const writer = @import("gcz/writer.zig");

pub const Error = format.Error || archive.Error || writer.Error;
pub const Header = format.Header;
pub const Block = archive.Block;
pub const Archive = archive.Archive;
pub const OpenOptions = archive.OpenOptions;
pub const Compression = writer.Compression;
pub const EncodeOptions = writer.EncodeOptions;
pub const magic = format.magic;
pub const parseHeader = format.parseHeader;
pub const parse = archive.Archive.init;
pub const encodeAlloc = writer.encodeAlloc;

test {
    _ = format;
    _ = archive;
    _ = writer;
    _ = @import("gcz/test.zig");
}
