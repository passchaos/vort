const archive = @import("tar/archive.zig");
const compressed = @import("tar/compressed.zig");
const writer = @import("tar/writer.zig");

pub const Error = archive.Error || writer.Error || compressed.Error;
pub const Kind = archive.Kind;
pub const Path = archive.Path;
pub const Entry = archive.Entry;
pub const SparseFormat = archive.SparseFormat;
pub const SparseExtent = archive.SparseExtent;
pub const SparseInfo = archive.SparseInfo;
pub const Archive = archive.Archive;
pub const Iterator = archive.Iterator;
pub const parse = archive.parse;
pub const extractEntryInto = archive.extractEntryInto;
pub const extractEntryAlloc = archive.extractEntryAlloc;
pub const extractByNameAlloc = archive.extractByNameAlloc;
pub const extractByNameAllocLimited = archive.extractByNameAllocLimited;
pub const EncodeEntry = writer.EncodeEntry;
pub const SparseDataExtent = writer.SparseDataExtent;
pub const SparseWriteFormat = writer.SparseWriteFormat;
pub const SparseEncodeOptions = writer.SparseOptions;
pub const encodeAlloc = writer.encodeAlloc;
pub const encodeAppend = writer.encodeAppend;
pub const Compression = compressed.Compression;
pub const CompressedEncodeOptions = compressed.EncodeOptions;
pub const OwnedArchive = compressed.OwnedArchive;
pub const detectCompression = compressed.detect;
pub const encodeCompressedAlloc = compressed.encodeAlloc;
pub const encodeCompressedAppend = compressed.encodeAppend;
pub const decodeCompressedAlloc = compressed.decodeAlloc;
pub const decodeAutoAlloc = compressed.decodeAutoAlloc;

test {
    _ = archive;
    _ = writer;
    _ = compressed;
}
