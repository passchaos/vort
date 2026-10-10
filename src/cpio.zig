const archive = @import("cpio/archive.zig");
const compressed = @import("cpio/compressed.zig");
const writer = @import("cpio/writer.zig");

pub const Error = archive.Error || writer.Error || compressed.Error;
pub const Format = archive.Format;
pub const Kind = archive.Kind;
pub const Entry = archive.Entry;
pub const Archive = archive.Archive;
pub const Iterator = archive.Iterator;
pub const EncodeEntry = writer.EncodeEntry;
pub const EncodeOptions = writer.EncodeOptions;
pub const parse = archive.parse;
pub const encodeAlloc = writer.encodeAlloc;
pub const encodeAppend = writer.encodeAppend;
pub const encodeInto = writer.encodeInto;
pub const byteSum = archive.byteSum;
pub const isSafePath = archive.isSafePath;
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
    _ = compressed;
    _ = writer;
}
