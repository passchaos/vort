const decoder = @import("bzip2/decoder.zig");
const encoder = @import("bzip2/encoder.zig");
const incremental_decoder = @import("bzip2/incremental_decoder.zig");
const incremental_tests = @import("bzip2/incremental_tests.zig");

pub const Error = decoder.Error || encoder.Error || incremental_decoder.Decoder.Error;
pub const EncodeOptions = encoder.EncodeOptions;
pub const IncrementalDecoder = incremental_decoder.Decoder;
pub const encodeAlloc = encoder.encodeAlloc;
pub const encodeAppend = encoder.encodeAppend;
pub const encodeInto = encoder.encodeInto;
pub const decodeInto = decoder.decodeInto;
pub const decodeAlloc = decoder.decodeAlloc;
pub const decodeAllocLimited = decoder.decodeAllocLimited;
pub const decodedSize = decoder.decodedSize;
pub const decodedSizeLimited = decoder.decodedSizeLimited;
pub const decodeConcatenatedInto = decoder.decodeConcatenatedInto;
pub const decodeConcatenatedAlloc = decoder.decodeConcatenatedAlloc;
pub const decodeConcatenatedAllocLimited = decoder.decodeConcatenatedAllocLimited;
pub const decodedSizeConcatenated = decoder.decodedSizeConcatenated;
pub const decodedSizeConcatenatedLimited = decoder.decodedSizeConcatenatedLimited;

test {
    _ = decoder;
    _ = encoder;
    _ = incremental_decoder;
    _ = incremental_tests;
}
