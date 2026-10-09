const container = @import("xz/container.zig");
const writer = @import("xz/writer.zig");

pub const Error = container.Error || writer.Error;
pub const Check = container.Check;
pub const StreamInfo = container.StreamInfo;
pub const EncodeOptions = writer.EncodeOptions;
pub const Filter = writer.Filter;
pub const encodeAlloc = writer.encodeAlloc;
pub const encodeAppend = writer.encodeAppend;
pub const encodeInto = writer.encodeInto;
pub const encodeStoredAlloc = writer.encodeStoredAlloc;
pub const encodeStoredAppend = writer.encodeStoredAppend;
pub const encodeStoredInto = writer.encodeStoredInto;
pub const inspect = container.inspect;
pub const decodeInto = container.decodeInto;
pub const decodeAlloc = container.decodeAlloc;
pub const decodeAllocLimited = container.decodeAllocLimited;
pub const decodedSize = container.decodedSize;
pub const decodedSizeLimited = container.decodedSizeLimited;
pub const decodeConcatenatedInto = container.decodeConcatenatedInto;
pub const decodeConcatenatedAlloc = container.decodeConcatenatedAlloc;
pub const decodeConcatenatedAllocLimited = container.decodeConcatenatedAllocLimited;
pub const decodedSizeConcatenated = container.decodedSizeConcatenated;
pub const decodedSizeConcatenatedLimited = container.decodedSizeConcatenatedLimited;

test {
    _ = container;
    _ = writer;
}
