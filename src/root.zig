//! Vort: next-generation compression experiments and compatibility-oriented primitives.

pub const checksum = @import("checksum.zig");
pub const core = @import("core.zig");
pub const store = @import("store.zig");
pub const fuzz = @import("fuzz.zig");
pub const deflate = @import("deflate.zig");
pub const bitstream = @import("bitstream.zig");
pub const huffman = @import("huffman.zig");
pub const lz77 = @import("lz77.zig");
pub const dictionary = @import("dictionary.zig");
pub const long_distance = @import("long_distance.zig");
pub const planner = @import("planner.zig");

pub const Adler32 = checksum.Adler32;
pub const Crc32 = checksum.Crc32;
pub const Crc32C = checksum.Crc32C;
pub const adler32 = checksum.adler32;
pub const crc32 = checksum.crc32;
pub const crc32Slice4 = checksum.crc32Slice4;
pub const crc32Best = checksum.crc32Best;
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
pub const storeEncodeSkippableAlloc = store.encodeSkippableAlloc;
pub const storeBuildFrameIndexAlloc = store.buildFrameIndexAlloc;
pub const storeEncodeFrameIndexAlloc = store.encodeFrameIndexAlloc;
pub const storeDecodeFrameIndexAlloc = store.decodeFrameIndexAlloc;
pub const storeFindFrameForOffset = store.findFrameForOffset;
pub const storeDecodeRangeAlloc = store.decodeRangeAlloc;

pub const encodeRawStoredDeflate = deflate.encodeRawStored;
pub const decodeRawStoredDeflate = deflate.decodeRawStored;
pub const encodeRawFixedDeflateAlloc = deflate.encodeRawFixedAlloc;
pub const encodeRawFixedWithOptionsAlloc = deflate.encodeRawFixedWithOptionsAlloc;
pub const CompressionOptions = deflate.CompressionOptions;
pub const ParserMode = deflate.ParserMode;
pub const encodeRawStoredDeflateAlloc = deflate.encodeRawStoredAlloc;
pub const decodeRawStoredDeflateAlloc = deflate.decodeRawStoredAlloc;
pub const decodeRawFixed = deflate.decodeRawFixed;
pub const decodeRawFixedAlloc = deflate.decodeRawFixedAllocStrict;
pub const decodeRawDeflateAlloc = deflate.decodeRawAutoAlloc;
pub const decodeRawDynamicAlloc = deflate.decodeRawDynamicAllocStrict;
pub const encodeZlibStored = deflate.encodeZlibStored;
pub const encodeZlibFixedAlloc = deflate.encodeZlibFixedAlloc;
pub const encodeZlibFixedWithOptionsAlloc = deflate.encodeZlibFixedWithOptionsAlloc;
pub const decodeZlibStored = deflate.decodeZlibStored;
pub const encodeZlibStoredAlloc = deflate.encodeZlibStoredAlloc;
pub const decodeZlibStoredAlloc = deflate.decodeZlibStoredAlloc;
pub const decodeZlibAlloc = deflate.decodeZlibAlloc;
pub const encodeGzipStored = deflate.encodeGzipStored;
pub const encodeGzipFixedAlloc = deflate.encodeGzipFixedAlloc;
pub const encodeGzipFixedWithOptionsAlloc = deflate.encodeGzipFixedWithOptionsAlloc;
pub const decodeGzipStored = deflate.decodeGzipStored;
pub const encodeGzipStoredAlloc = deflate.encodeGzipStoredAlloc;
pub const decodeGzipStoredAlloc = deflate.decodeGzipStoredAlloc;
pub const decodeGzipAlloc = deflate.decodeGzipAlloc;

pub const Lz77Token = lz77.Token;
pub const greedyLz77PlanAlloc = lz77.greedyPlanAlloc;
pub const lazyGreedyLz77PlanAlloc = lz77.lazyGreedyPlanAlloc;
pub const optimalLz77PlanAlloc = lz77.optimalPlanAlloc;

pub const DictionaryId = dictionary.DictionaryId;
pub const DictionaryMetadata = dictionary.Metadata;
pub const trainDictionaryAlloc = dictionary.trainAlloc;
pub const findLongDistanceCandidatesAlloc = long_distance.findCandidatesAlloc;
pub const planBlocksAlloc = planner.planBlocksAlloc;

test {
    _ = checksum;
    _ = core;
    _ = store;
    _ = fuzz;
    _ = deflate;
    _ = bitstream;
    _ = huffman;
    _ = lz77;
    _ = dictionary;
    _ = long_distance;
    _ = planner;
}
