const format = @import("dax/format.zig");
const archive = @import("dax/archive.zig");
const writer = @import("dax/writer.zig");

pub const Error = format.Error || archive.Error || writer.Error;
pub const Header = format.Header;
pub const NonCompressedArea = format.NonCompressedArea;
pub const Frame = archive.Frame;
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
    _ = @import("dax/test.zig");
}
