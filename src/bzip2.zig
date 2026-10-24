const decoder = @import("bzip2/decoder.zig");
const encoder = @import("bzip2/encoder.zig");
const incremental_decoder = @import("bzip2/incremental_decoder.zig");
const incremental_encoder = @import("bzip2/incremental_encoder.zig");
const incremental_encoder_tests = @import("bzip2/incremental_encoder_tests.zig");
const incremental_tests = @import("bzip2/incremental_tests.zig");

pub const Error = decoder.Error || encoder.Error || incremental_decoder.Decoder.Error || incremental_encoder.Encoder.Error;
pub const EncodeOptions = encoder.EncodeOptions;
pub const IncrementalDecoder = incremental_decoder.Decoder;
pub const IncrementalEncoder = incremental_encoder.Encoder;
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
    _ = @import("bzip2/inverse_bwt.zig");
    _ = @import("bzip2/output_cursor.zig");
    _ = @import("bzip2/incremental/contracts_tests.zig");
    _ = decoder;
    _ = encoder;
    _ = incremental_decoder;
    _ = incremental_encoder;
    _ = incremental_encoder_tests;
    _ = incremental_tests;
}
