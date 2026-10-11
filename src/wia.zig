const format = @import("wia/format.zig");
const archive = @import("wia/archive.zig");
const writer = @import("wia/writer.zig");

pub const Error = format.Error || archive.Error || writer.Error;
pub const Container = format.Container;
pub const Compression = format.Compression;
pub const Header1 = format.Header1;
pub const Header2 = format.Header2;
pub const RawEntry = format.RawEntry;
pub const GroupEntry = format.GroupEntry;
pub const Archive = archive.Archive;
pub const OpenOptions = archive.OpenOptions;
pub const EncodeOptions = writer.EncodeOptions;
pub const parseHeader1 = format.parseHeader1;
pub const parseAlloc = archive.Archive.initAlloc;
pub const encodeAlloc = writer.encodeAlloc;

test {
    _ = format;
    _ = @import("wia/codec.zig");
    _ = @import("wia/rvz_pack.zig");
    _ = archive;
    _ = writer;
    _ = @import("wia/test.zig");
}
