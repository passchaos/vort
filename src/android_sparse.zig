const format = @import("android_sparse/format.zig");
const archive = @import("android_sparse/archive.zig");
const writer = @import("android_sparse/writer.zig");

pub const Error = format.Error || archive.Error || writer.Error;
pub const ChunkType = format.ChunkType;
pub const Header = format.Header;
pub const Chunk = format.Chunk;
pub const Archive = archive.Archive;
pub const OpenOptions = archive.OpenOptions;
pub const EncodeOptions = writer.EncodeOptions;
pub const parseAlloc = archive.Archive.initAlloc;
pub const encodeAlloc = writer.encodeAlloc;

test {
    _ = format;
    _ = archive;
    _ = writer;
    _ = @import("android_sparse/test.zig");
}
