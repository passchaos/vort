const plain = @import("xpress/plain.zig");

pub const Error = plain.Error;
pub const PlainEncodeOptions = plain.EncodeOptions;
pub const PlainSummary = plain.Summary;

pub const plainEncodedBound = plain.encodedBound;
pub const summarizePlain = plain.summarize;
pub const summarizePlainLimited = plain.summarizeLimited;
pub const plainDecodedSize = plain.decodedSize;
pub const plainDecodedSizeLimited = plain.decodedSizeLimited;
pub const decodePlainInto = plain.decodeInto;
pub const decodePlainAlloc = plain.decodeAlloc;
pub const decodePlainAllocLimited = plain.decodeAllocLimited;
pub const encodePlainInto = plain.encodeInto;
pub const encodePlainAppend = plain.encodeAppend;
pub const encodePlainAlloc = plain.encodeAlloc;

test {
    _ = plain;
}
