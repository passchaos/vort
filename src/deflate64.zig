const decoder = @import("deflate64/decoder.zig");

pub const Error = decoder.Error;
pub const DecodeResult = decoder.DecodeResult;
pub const decodeInto = decoder.decodeInto;
pub const decodeAlloc = decoder.decodeAlloc;
pub const decodeAllocLimited = decoder.decodeAllocLimited;
pub const decodedSize = decoder.decodedSize;
pub const decodedSizeLimited = decoder.decodedSizeLimited;

test {
    _ = decoder;
}
