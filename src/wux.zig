const format = @import("wux/format.zig");
const archive = @import("wux/archive.zig");
const writer = @import("wux/writer.zig");

pub const Error = format.Error || archive.Error || writer.Error;
pub const Header = format.Header;
pub const Archive = archive.Archive;
pub const OpenOptions = archive.OpenOptions;
pub const EncodeOptions = writer.EncodeOptions;
pub const standard_wud_size = format.standard_wud_size;
pub const parseAlloc = archive.Archive.initAlloc;
pub const encodeAlloc = writer.encodeAlloc;

test {
    _ = format;
    _ = archive;
    _ = writer;
    _ = @import("wux/test.zig");
}
