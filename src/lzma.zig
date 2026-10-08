const decoder = @import("lzma/decoder.zig");

pub const Error = decoder.Error;
pub const Header = decoder.Header;
pub const DecodeOptions = decoder.DecodeOptions;
pub const parseHeader = decoder.parseHeader;
pub const decodeInto = decoder.decodeInto;
pub const decodeAlloc = decoder.decodeAlloc;
pub const decodeAllocLimited = decoder.decodeAllocLimited;
pub const decodeAllocWithOptions = decoder.decodeAllocWithOptions;
pub const decodedSize = decoder.decodedSize;
pub const decodedSizeLimited = decoder.decodedSizeLimited;
pub const decodeZipPayloadInto = decoder.decodeZipPayloadInto;
pub const decodeZipPayloadAllocLimited = decoder.decodeZipPayloadAllocLimited;

test {
    _ = decoder;
}
