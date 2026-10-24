const format = @import("qcow2/format.zig");
const archive = @import("qcow2/archive.zig");
const writer = @import("qcow2/writer.zig");

pub const Error = format.Error || archive.Error || writer.Error;
pub const CompressionType = format.CompressionType;
pub const Header = format.Header;
pub const Archive = archive.Archive;
pub const OpenOptions = archive.OpenOptions;
pub const Compression = writer.Compression;
pub const EncodeOptions = writer.EncodeOptions;
pub const ExternalDataEncodeOptions = writer.ExternalDataEncodeOptions;
pub const EncodedExternalData = writer.EncodedExternalData;
pub const magic = format.magic;
pub const parseHeader = format.parseHeader;
pub const parse = archive.Archive.init;
pub const encodeAlloc = writer.encodeAlloc;
pub const encodeExternalDataAlloc = writer.encodeExternalDataAlloc;

test {
    _ = format;
    _ = archive;
    _ = writer;
    _ = @import("qcow2/test.zig");
}
