const format = @import("ewf/format.zig");
const archive = @import("ewf/archive.zig");
const writer = @import("ewf/writer.zig");

pub const Error = format.Error || archive.Error || writer.Error;
pub const FileHeader = format.FileHeader;
pub const Section = format.Section;
pub const Geometry = format.Geometry;
pub const Chunk = archive.Chunk;
pub const Archive = archive.Archive;
pub const OpenOptions = archive.OpenOptions;
pub const Compression = writer.Compression;
pub const EncodeOptions = writer.EncodeOptions;
pub const EncodedSegments = writer.EncodedSegments;
pub const signature = format.ewf1_signature;
pub const parseFileHeader = format.parseFileHeader;
pub const parseOneAlloc = archive.Archive.initOneAlloc;
pub const parseSegmentsAlloc = archive.Archive.initAlloc;
pub const encodeAlloc = writer.encodeAlloc;
pub const encodeSegmentsAlloc = writer.encodeSegmentsAlloc;

test {
    _ = format;
    _ = archive;
    _ = writer;
    _ = @import("ewf/test.zig");
}
