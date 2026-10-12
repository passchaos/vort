const format = @import("wbfs/format.zig");
const archive = @import("wbfs/archive.zig");
const writer = @import("wbfs/writer.zig");

pub const Error = format.Error || archive.Error || writer.Error;
pub const Header = format.Header;
pub const Archive = archive.Archive;
pub const OpenOptions = archive.OpenOptions;
pub const EncodeOptions = writer.EncodeOptions;
pub const logical_size = format.logical_size;
pub const parseAlloc = archive.Archive.initAlloc;
pub const parsePartsAlloc = archive.Archive.initPartsAlloc;
pub const encodeAlloc = writer.encodeAlloc;

test {
    _ = format;
    _ = archive;
    _ = writer;
    _ = @import("wbfs/test.zig");
}
