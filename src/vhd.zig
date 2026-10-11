const format = @import("vhd/format.zig");
const archive = @import("vhd/archive.zig");
const writer = @import("vhd/writer.zig");

pub const Error = format.Error || archive.Error || writer.Error;
pub const DiskType = format.DiskType;
pub const Geometry = format.Geometry;
pub const Footer = format.Footer;
pub const DynamicHeader = format.DynamicHeader;
pub const Archive = archive.Archive;
pub const OpenOptions = archive.OpenOptions;
pub const EncodeOptions = writer.EncodeOptions;
pub const parseFooter = format.parseFooter;
pub const parse = archive.Archive.init;
pub const encodeAlloc = writer.encodeAlloc;

test {
    _ = format;
    _ = archive;
    _ = writer;
    _ = @import("vhd/test.zig");
}
