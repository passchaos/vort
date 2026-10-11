const format = @import("vmdk/format.zig");
const archive = @import("vmdk/archive.zig");
const writer = @import("vmdk/writer.zig");

pub const Error = format.Error || archive.Error || writer.Error;
pub const Header = format.Header;
pub const Descriptor = format.Descriptor;
pub const Marker = format.Marker;
pub const MarkerType = format.MarkerType;
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
    _ = @import("vmdk/test.zig");
}
