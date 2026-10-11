const format = @import("dmg/format.zig");
const blkx = @import("dmg/blkx.zig");
const plist = @import("dmg/plist.zig");
const archive = @import("dmg/archive.zig");
const writer = @import("dmg/writer.zig");

pub const Error = format.Error || blkx.Error || plist.Error || archive.Error ||
    writer.Error;
pub const ChunkKind = format.ChunkKind;
pub const Fork = format.Fork;
pub const Checksum = format.Checksum;
pub const Trailer = format.Trailer;
pub const Block = blkx.Block;
pub const Partition = blkx.Partition;
pub const Archive = archive.Archive;
pub const ParseOptions = archive.ParseOptions;
pub const Compression = writer.Compression;
pub const EncodeOptions = writer.EncodeOptions;
pub const sectorSize = format.sector_size;
pub const trailerSize = format.trailer_size;
pub const parseTrailer = format.parseTrailer;
pub const parseAlloc = archive.Archive.parseAlloc;
pub const encodeAlloc = writer.encodeAlloc;
pub const encodeAppend = writer.encodeAppend;
pub const encodeInto = writer.encodeInto;

test {
    _ = format;
    _ = blkx;
    _ = plist;
    _ = archive;
    _ = writer;
    _ = @import("dmg/test.zig");
}
