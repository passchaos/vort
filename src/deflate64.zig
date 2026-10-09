const decoder = @import("deflate64/decoder.zig");
const encoder = @import("deflate64/encoder.zig");

pub const Error = decoder.Error || encoder.Error;
pub const DecodeResult = decoder.DecodeResult;
pub const decodeInto = decoder.decodeInto;
pub const decodeAlloc = decoder.decodeAlloc;
pub const decodeAllocLimited = decoder.decodeAllocLimited;
pub const decodedSize = decoder.decodedSize;
pub const decodedSizeLimited = decoder.decodedSizeLimited;
pub const EncodeOptions = encoder.EncodeOptions;
pub const encodedBound = encoder.encodedBound;
pub const encodeAlloc = encoder.encodeAlloc;
pub const encodeAppend = encoder.encodeAppend;
pub const encodeInto = encoder.encodeInto;
pub const encodeStoredAlloc = encoder.encodeStoredAlloc;
pub const encodeStoredAppend = encoder.encodeStoredAppend;
pub const encodeStoredInto = encoder.encodeStoredInto;

test {
    _ = decoder;
    _ = encoder;
}
