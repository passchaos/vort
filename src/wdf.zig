const format = @import("wdf/format.zig");
const archive = @import("wdf/archive.zig");
const writer = @import("wdf/writer.zig");

pub const Error = format.Error || archive.Error || writer.Error;
pub const Version = format.Version;
pub const Header = format.Header;
pub const Chunk = format.Chunk;
pub const Archive = archive.Archive;
pub const OpenOptions = archive.OpenOptions;
pub const EncodeOptions = writer.EncodeOptions;
pub const parseAlloc = archive.Archive.initAlloc;
pub const parsePartsAlloc = archive.Archive.initPartsAlloc;
pub const encodeAlloc = writer.encodeAlloc;

test {
    _ = format;
    _ = archive;
    _ = writer;
    _ = @import("wdf/test.zig");
}
