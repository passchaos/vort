const format = @import("cso/format.zig");
const archive = @import("cso/archive.zig");
const writer = @import("cso/writer.zig");

pub const Error = format.Error || archive.Error || writer.Error;
pub const Format = format.Format;
pub const Codec = format.Codec;
pub const Header = format.Header;
pub const Block = archive.Block;
pub const Archive = archive.Archive;
pub const OpenOptions = archive.OpenOptions;
pub const Compression = writer.Compression;
pub const EncodeOptions = writer.EncodeOptions;
pub const parseHeader = format.parseHeader;
pub const parse = archive.Archive.init;
pub const encodeAlloc = writer.encodeAlloc;

test {
    _ = format;
    _ = archive;
    _ = writer;
    _ = @import("cso/test.zig");
}
