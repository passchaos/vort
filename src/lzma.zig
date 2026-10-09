const decoder = @import("lzma/decoder.zig");
const writer = @import("lzma/writer.zig");

pub const Error = decoder.Error || writer.Error;
pub const Header = decoder.Header;
pub const DecodeOptions = decoder.DecodeOptions;
pub const EncodeOptions = writer.EncodeOptions;
pub const Properties = writer.Properties;
pub const EncodeMode = writer.Mode;
pub const SizeMode = writer.SizeMode;
pub const parseHeader = decoder.parseHeader;
pub const decodeInto = decoder.decodeInto;
pub const decodeAlloc = decoder.decodeAlloc;
pub const decodeAllocLimited = decoder.decodeAllocLimited;
pub const decodeAllocWithOptions = decoder.decodeAllocWithOptions;
pub const decodedSize = decoder.decodedSize;
pub const decodedSizeLimited = decoder.decodedSizeLimited;
pub const decodeZipPayloadInto = decoder.decodeZipPayloadInto;
pub const decodeZipPayloadAllocLimited = decoder.decodeZipPayloadAllocLimited;
pub const encodeAlloc = writer.encodeAlloc;
pub const encodeAppend = writer.encodeAppend;
pub const encodeInto = writer.encodeInto;

test {
    _ = decoder;
    _ = writer;
}
