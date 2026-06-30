//! Vort: next-generation compression experiments and compatibility-oriented primitives.

pub const checksum = @import("checksum.zig");
pub const core = @import("core.zig");
pub const store = @import("store.zig");
pub const fuzz = @import("fuzz.zig");
pub const deflate = @import("deflate.zig");
pub const bitstream = @import("bitstream.zig");
pub const huffman = @import("huffman.zig");

pub const Adler32 = checksum.Adler32;
pub const Crc32 = checksum.Crc32;
pub const Crc32C = checksum.Crc32C;
pub const adler32 = checksum.adler32;
pub const crc32 = checksum.crc32;
pub const crc32c = checksum.crc32c;

pub const Error = core.Error;
pub const FrameInfo = core.FrameInfo;
pub const Progress = core.Progress;
pub const StepResult = core.StepResult;

pub const storeEncode = store.encode;
pub const storeDecode = store.decode;
pub const storeEncodeAlloc = store.encodeAlloc;
pub const storeDecodeAlloc = store.decodeAlloc;
pub const storeDecodeConcatenatedAlloc = store.decodeConcatenatedAlloc;

pub const encodeRawStoredDeflate = deflate.encodeRawStored;
pub const decodeRawStoredDeflate = deflate.decodeRawStored;
pub const encodeRawStoredDeflateAlloc = deflate.encodeRawStoredAlloc;
pub const decodeRawStoredDeflateAlloc = deflate.decodeRawStoredAlloc;
pub const decodeRawFixed = deflate.decodeRawFixed;
pub const decodeRawFixedAlloc = deflate.decodeRawFixedAllocStrict;
pub const decodeRawDeflateAlloc = deflate.decodeRawAutoAlloc;
pub const encodeZlibStored = deflate.encodeZlibStored;
pub const decodeZlibStored = deflate.decodeZlibStored;
pub const encodeZlibStoredAlloc = deflate.encodeZlibStoredAlloc;
pub const decodeZlibStoredAlloc = deflate.decodeZlibStoredAlloc;
pub const decodeZlibAlloc = deflate.decodeZlibAlloc;
pub const encodeGzipStored = deflate.encodeGzipStored;
pub const decodeGzipStored = deflate.decodeGzipStored;
pub const encodeGzipStoredAlloc = deflate.encodeGzipStoredAlloc;
pub const decodeGzipStoredAlloc = deflate.decodeGzipStoredAlloc;
pub const decodeGzipAlloc = deflate.decodeGzipAlloc;

test {
    _ = checksum;
    _ = core;
    _ = store;
    _ = fuzz;
    _ = deflate;
    _ = bitstream;
    _ = huffman;
}
