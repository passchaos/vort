const block = @import("lzf/block.zig");
const frame = @import("lzf/frame.zig");

pub const Error = block.Error || frame.Error;
pub const EncodeOptions = frame.EncodeOptions;
pub const FileInfo = frame.FileInfo;
pub const max_block_size = frame.max_block_size;

pub const blockEncodedBound = block.encodedBound;
pub const blockDecodedSize = block.decodedSize;
pub const blockDecodedSizeLimited = block.decodedSizeLimited;
pub const decodeBlockInto = block.decodeInto;
pub const decodeBlockAlloc = block.decodeAlloc;
pub const decodeBlockAllocLimited = block.decodeAllocLimited;
pub const encodeBlockInto = block.encodeInto;
pub const encodeBlockAppend = block.encodeAppend;
pub const encodeBlockAlloc = block.encodeAlloc;

pub const encodedBound = frame.encodedBound;
pub const inspect = frame.inspect;
pub const decodedSize = frame.decodedSize;
pub const decodedSizeLimited = frame.decodedSizeLimited;
pub const decodeInto = frame.decodeInto;
pub const decodeAlloc = frame.decodeAlloc;
pub const decodeAllocLimited = frame.decodeAllocLimited;
pub const encodeInto = frame.encodeInto;
pub const encodeAppend = frame.encodeAppend;
pub const encodeAlloc = frame.encodeAlloc;

test {
    _ = block;
    _ = frame;
}
