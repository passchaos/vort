const format = @import("xar/format.zig");
const xml = @import("xar/xml.zig");
const archive = @import("xar/archive.zig");
const writer = @import("xar/writer.zig");

pub const Error = format.Error || xml.Error || archive.Error || writer.Error;
pub const ChecksumAlgorithm = format.ChecksumAlgorithm;
pub const Digest = format.Digest;
pub const Header = format.Header;
pub const Encoding = format.Encoding;
pub const EntryKind = format.EntryKind;
pub const Data = format.Data;
pub const Entry = format.Entry;
pub const Archive = archive.Archive;
pub const ParseOptions = archive.ParseOptions;
pub const Compression = writer.Compression;
pub const EncodeEntryKind = writer.EntryKind;
pub const EncodeEntry = writer.EncodeEntry;
pub const EncodeOptions = writer.EncodeOptions;
pub const magic = format.magic;
pub const parseHeader = format.parseHeader;
pub const parseAlloc = archive.Archive.parseAlloc;
pub const encodeAlloc = writer.encodeAlloc;
pub const encodeAppend = writer.encodeAppend;
pub const encodeInto = writer.encodeInto;

test {
    _ = format;
    _ = xml;
    _ = archive;
    _ = writer;
    _ = @import("xar/test.zig");
}
