const format = @import("chd/format.zig");
const huffman = @import("chd/huffman.zig");
const archive = @import("chd/archive.zig");
const writer = @import("chd/writer.zig");

pub const Error = format.Error || huffman.Error || archive.Error || writer.Error;
pub const Codec = format.Codec;
pub const MapType = format.MapType;
pub const Header = format.Header;
pub const CompressedMapHeader = format.CompressedMapHeader;
pub const MapEntry = format.MapEntry;
pub const Metadata = format.Metadata;
pub const Archive = archive.Archive;
pub const OpenOptions = archive.OpenOptions;
pub const Compression = writer.Compression;
pub const EncodeMetadata = writer.EncodeMetadata;
pub const EncodeOptions = writer.EncodeOptions;
pub const signature = format.signature;
pub const metadata_checksum_flag = format.metadata_checksum_flag;
pub const tag = format.tag;
pub const parseHeader = format.parseHeader;
pub const crc16 = format.crc16;
pub const parseAlloc = archive.Archive.initAlloc;
pub const alignedLzmaDictionarySize = format.alignedLzmaDictionarySize;
pub const encodeAlloc = writer.encodeAlloc;

test {
    _ = format;
    _ = huffman;
    _ = archive;
    _ = writer;
    _ = @import("chd/test.zig");
}
