const container = @import("xz/container.zig");
const incremental_decoder = @import("xz/incremental_decoder.zig");
const incremental_encoder = @import("xz/incremental_encoder.zig");
const incremental_encoder_tests = @import("xz/incremental_encoder_tests.zig");
const incremental_filters = @import("xz/incremental_filters.zig");
const incremental_tests = @import("xz/incremental_tests.zig");
const lzma2_incremental_decoder = @import("xz/lzma2_incremental_decoder.zig");
const lzma2_incremental_encoder = @import("xz/lzma2_incremental_encoder.zig");
const lzma2_writer = @import("xz/lzma2_writer.zig");
const writer = @import("xz/writer.zig");

pub const Error = container.Error || writer.Error || incremental_decoder.Decoder.Error ||
    incremental_encoder.Encoder.Error || lzma2_incremental_decoder.Decoder.Error ||
    lzma2_incremental_encoder.Encoder.Error;
pub const Check = container.Check;
pub const StreamInfo = container.StreamInfo;
pub const IncrementalDecoder = incremental_decoder.Decoder;
pub const IncrementalEncoder = incremental_encoder.Encoder;
pub const RawLzma2IncrementalDecoder = lzma2_incremental_decoder.Decoder;
pub const RawLzma2IncrementalEncoder = lzma2_incremental_encoder.Encoder;
pub const IncrementalFilterDecoder = incremental_filters.Decoder;
pub const IncrementalFilterEncoder = incremental_filters.Encoder;
pub const EncodeOptions = writer.EncodeOptions;
pub const Parser = writer.Parser;
pub const Filter = writer.Filter;
pub const max_encode_dictionary_size = lzma2_writer.max_dictionary_size;
pub const encodeAlloc = writer.encodeAlloc;
pub const encodeLazyAlloc = writer.encodeLazyAlloc;
pub const encodeLazyAppend = writer.encodeLazyAppend;
pub const encodeLazyInto = writer.encodeLazyInto;
pub const encodeAppend = writer.encodeAppend;
pub const encodeInto = writer.encodeInto;
pub const encodeStoredAlloc = writer.encodeStoredAlloc;
pub const encodeStoredAppend = writer.encodeStoredAppend;
pub const encodeStoredInto = writer.encodeStoredInto;
pub const inspect = container.inspect;
pub const decodeInto = container.decodeInto;
pub const decodeAlloc = container.decodeAlloc;
pub const decodeAllocLimited = container.decodeAllocLimited;
pub const decodeAllocWithLimits = container.decodeAllocWithLimits;
pub const decodedSize = container.decodedSize;
pub const decodedSizeLimited = container.decodedSizeLimited;
pub const decodeConcatenatedInto = container.decodeConcatenatedInto;
pub const decodeConcatenatedAlloc = container.decodeConcatenatedAlloc;
pub const decodeConcatenatedAllocLimited = container.decodeConcatenatedAllocLimited;
pub const decodedSizeConcatenated = container.decodedSizeConcatenated;
pub const decodedSizeConcatenatedLimited = container.decodedSizeConcatenatedLimited;

test {
    _ = container;
    _ = incremental_decoder;
    _ = incremental_encoder;
    _ = incremental_encoder_tests;
    _ = incremental_filters;
    _ = incremental_tests;
    _ = lzma2_incremental_decoder;
    _ = lzma2_incremental_encoder;
    _ = lzma2_writer;
    _ = writer;
}
