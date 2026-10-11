const format = @import("vhdx/format.zig");
const archive = @import("vhdx/archive.zig");
const writer = @import("vhdx/writer.zig");

pub const Error = format.Error || archive.Error || writer.Error;
pub const Guid = format.Guid;
pub const Header = format.Header;
pub const Region = format.Region;
pub const Regions = format.Regions;
pub const Metadata = format.Metadata;
pub const PayloadState = format.PayloadState;
pub const Archive = archive.Archive;
pub const OpenOptions = archive.OpenOptions;
pub const ImageType = writer.ImageType;
pub const EncodeOptions = writer.EncodeOptions;
pub const parse = archive.Archive.init;
pub const encodeAlloc = writer.encodeAlloc;

test {
    _ = format;
    _ = archive;
    _ = writer;
    _ = @import("vhdx/test.zig");
}
