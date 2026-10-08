//! Vort: next-generation compression experiments and compatibility-oriented primitives.

const std = @import("std");

pub const checksum = @import("checksum.zig");
pub const core = @import("core.zig");
pub const store = @import("store.zig");
pub const fuzz = @import("fuzz.zig");
pub const deflate = @import("deflate.zig");
pub const png = @import("png.zig");
const png_exports = @import("root_exports/png.zig");
pub const br = @import("br.zig");
pub const snappy = @import("snappy.zig");
pub const bitstream = @import("bitstream.zig");
pub const huffman = @import("huffman.zig");
pub const lz77 = @import("lz77.zig");
pub const dictionary = @import("dictionary.zig");
pub const long_distance = @import("long_distance.zig");
pub const planner = @import("planner.zig");
pub const lz4 = @import("lz4.zig");
pub const zstd = @import("zstd.zig");
pub const zip = @import("zip.zig");
pub const bzip2 = @import("bzip2.zig");
pub const xz = @import("xz.zig");
pub const lzma = @import("lzma.zig");
pub const tar = @import("tar.zig");
pub const compress_z = @import("compress_z.zig");
pub const lzip = @import("lzip.zig");
pub const lzo1x = @import("lzo1x.zig");
pub const lzop = @import("lzop.zig");
pub const seven_zip = @import("seven_zip.zig");

pub const Adler32 = checksum.Adler32;
pub const Crc32 = checksum.Crc32;
pub const Crc32Best = checksum.Crc32Best;
pub const Crc32C = checksum.Crc32C;
pub const adler32 = checksum.adler32;
pub const adler32Combine = checksum.adler32Combine;
pub const bestAdler32Backend = checksum.bestAdler32Backend;
pub const crc32 = checksum.crc32;
pub const crc32Slice4 = checksum.crc32Slice4;
pub const crc32Slice8 = checksum.crc32Slice8;
pub const crc32Slice16 = checksum.crc32Slice16;
pub const crc32Slice32 = checksum.crc32Slice32;
pub const crc32Best = checksum.crc32Best;
pub const crc32UpdateBest = checksum.crc32UpdateBest;
pub const crc32Combine = checksum.crc32Combine;
pub const checksumCpuFeatureReport = checksum.cpuFeatureReport;
pub const crc32c = checksum.crc32c;
pub const crc32cSlice8 = checksum.crc32cSlice8;
pub const crc32cSlice16 = checksum.crc32cSlice16;
pub const crc32cSlice32 = checksum.crc32cSlice32;
pub const crc32cBest = checksum.crc32cBest;
pub const crc32cCombine = checksum.crc32cCombine;

pub const ZipError = zip.Error;
pub const ZipArchive = zip.Archive;
pub const ZipEntry = zip.Entry;
pub const ZipIterator = zip.Iterator;
pub const ZipCompressionMethod = zip.CompressionMethod;
pub const Zip64Mode = zip.Zip64Mode;
pub const ZipEncodeEntry = zip.EncodeEntry;
pub const ZipEncodeOptions = zip.EncodeOptions;
pub const parseZipArchive = zip.parse;
pub const zipEncodeAlloc = zip.encodeAlloc;
pub const zipEncodeAppend = zip.encodeAppend;
pub const zipExtractEntryInto = zip.extractEntryInto;
pub const zipExtractEntryIntoWithAllocator = zip.extractEntryIntoWithAllocator;
pub const zipExtractEntryAlloc = zip.extractEntryAlloc;
pub const zipExtractEntryAllocLimited = zip.extractEntryAllocLimited;
pub const zipExtractByNameAlloc = zip.extractByNameAlloc;
pub const zipExtractByNameAllocLimited = zip.extractByNameAllocLimited;

pub const Bzip2Error = bzip2.Error;
pub const Bzip2EncodeOptions = bzip2.EncodeOptions;
pub const encodeBzip2Alloc = bzip2.encodeAlloc;
pub const encodeBzip2Append = bzip2.encodeAppend;
pub const encodeBzip2Into = bzip2.encodeInto;
pub const decodeBzip2Into = bzip2.decodeInto;
pub const decodeBzip2Alloc = bzip2.decodeAlloc;
pub const decodeBzip2AllocLimited = bzip2.decodeAllocLimited;
pub const bzip2DecodedSize = bzip2.decodedSize;
pub const bzip2DecodedSizeLimited = bzip2.decodedSizeLimited;
pub const decodeBzip2ConcatenatedInto = bzip2.decodeConcatenatedInto;
pub const decodeBzip2ConcatenatedAlloc = bzip2.decodeConcatenatedAlloc;
pub const decodeBzip2ConcatenatedAllocLimited = bzip2.decodeConcatenatedAllocLimited;
pub const bzip2DecodedSizeConcatenated = bzip2.decodedSizeConcatenated;
pub const bzip2DecodedSizeConcatenatedLimited = bzip2.decodedSizeConcatenatedLimited;

pub const XzError = xz.Error;
pub const XzCheck = xz.Check;
pub const XzStreamInfo = xz.StreamInfo;
pub const XzEncodeOptions = xz.EncodeOptions;
pub const XzFilter = xz.Filter;
pub const encodeXzStoredAlloc = xz.encodeStoredAlloc;
pub const encodeXzStoredAppend = xz.encodeStoredAppend;
pub const encodeXzStoredInto = xz.encodeStoredInto;
pub const inspectXz = xz.inspect;
pub const decodeXzInto = xz.decodeInto;
pub const decodeXzAlloc = xz.decodeAlloc;
pub const decodeXzAllocLimited = xz.decodeAllocLimited;
pub const xzDecodedSize = xz.decodedSize;
pub const xzDecodedSizeLimited = xz.decodedSizeLimited;
pub const decodeXzConcatenatedInto = xz.decodeConcatenatedInto;
pub const decodeXzConcatenatedAlloc = xz.decodeConcatenatedAlloc;
pub const decodeXzConcatenatedAllocLimited = xz.decodeConcatenatedAllocLimited;
pub const xzDecodedSizeConcatenated = xz.decodedSizeConcatenated;
pub const xzDecodedSizeConcatenatedLimited = xz.decodedSizeConcatenatedLimited;

pub const LzmaError = lzma.Error;
pub const LzmaHeader = lzma.Header;
pub const LzmaDecodeOptions = lzma.DecodeOptions;
pub const parseLzmaHeader = lzma.parseHeader;
pub const decodeLzmaInto = lzma.decodeInto;
pub const decodeLzmaAlloc = lzma.decodeAlloc;
pub const decodeLzmaAllocLimited = lzma.decodeAllocLimited;
pub const decodeLzmaAllocWithOptions = lzma.decodeAllocWithOptions;
pub const lzmaDecodedSize = lzma.decodedSize;
pub const lzmaDecodedSizeLimited = lzma.decodedSizeLimited;

pub const TarError = tar.Error;
pub const TarKind = tar.Kind;
pub const TarPath = tar.Path;
pub const TarEntry = tar.Entry;
pub const TarArchive = tar.Archive;
pub const TarIterator = tar.Iterator;
pub const TarEncodeEntry = tar.EncodeEntry;
pub const TarCompression = tar.Compression;
pub const TarCompressedEncodeOptions = tar.CompressedEncodeOptions;
pub const TarOwnedArchive = tar.OwnedArchive;
pub const parseTarArchive = tar.parse;
pub const encodeTarAlloc = tar.encodeAlloc;
pub const encodeTarAppend = tar.encodeAppend;
pub const tarExtractEntryInto = tar.extractEntryInto;
pub const tarExtractEntryAlloc = tar.extractEntryAlloc;
pub const tarExtractByNameAlloc = tar.extractByNameAlloc;
pub const tarExtractByNameAllocLimited = tar.extractByNameAllocLimited;
pub const detectTarCompression = tar.detectCompression;
pub const encodeCompressedTarAlloc = tar.encodeCompressedAlloc;
pub const encodeCompressedTarAppend = tar.encodeCompressedAppend;
pub const decodeCompressedTarAlloc = tar.decodeCompressedAlloc;
pub const decodeTarAutoAlloc = tar.decodeAutoAlloc;

pub const CompressZError = compress_z.Error;
pub const CompressZHeader = compress_z.Header;
pub const CompressZEncodeOptions = compress_z.EncodeOptions;
pub const parseCompressZHeader = compress_z.parseHeader;
pub const encodeCompressZAlloc = compress_z.encodeAlloc;
pub const encodeCompressZAppend = compress_z.encodeAppend;
pub const encodeCompressZInto = compress_z.encodeInto;
pub const decodeCompressZInto = compress_z.decodeInto;
pub const decodeCompressZAlloc = compress_z.decodeAlloc;
pub const decodeCompressZAllocLimited = compress_z.decodeAllocLimited;
pub const compressZDecodedSize = compress_z.decodedSize;
pub const compressZDecodedSizeLimited = compress_z.decodedSizeLimited;

pub const LzipError = lzip.Error;
pub const LzipHeader = lzip.Header;
pub const LzipFileInfo = lzip.FileInfo;
pub const LzipDecodeOptions = lzip.DecodeOptions;
pub const parseLzipHeader = lzip.parseHeader;
pub const inspectLzip = lzip.inspect;
pub const decodeLzipInto = lzip.decodeInto;
pub const decodeLzipAlloc = lzip.decodeAlloc;
pub const decodeLzipAllocLimited = lzip.decodeAllocLimited;
pub const decodeLzipAllocWithOptions = lzip.decodeAllocWithOptions;
pub const lzipDecodedSize = lzip.decodedSize;
pub const lzipDecodedSizeLimited = lzip.decodedSizeLimited;
pub const lzipDecodedSizeWithOptions = lzip.decodedSizeWithOptions;

pub const Lzo1xError = lzo1x.Error;
pub const decodeLzo1xInto = lzo1x.decodeInto;
pub const LzopError = lzop.Error;
pub const LzopHeader = lzop.Header;
pub const LzopMethod = lzop.Method;
pub const LzopDecodeOptions = lzop.DecodeOptions;
pub const LzopFileInfo = lzop.FileInfo;
pub const LzopChecksum = lzop.Checksum;
pub const LzopEncodeOptions = lzop.EncodeOptions;
pub const parseLzopHeader = lzop.parseHeader;
pub const inspectLzop = lzop.inspect;
pub const decodeLzopInto = lzop.decodeInto;
pub const decodeLzopAlloc = lzop.decodeAlloc;
pub const decodeLzopAllocLimited = lzop.decodeAllocLimited;
pub const decodeLzopAllocWithOptions = lzop.decodeAllocWithOptions;
pub const lzopDecodedSize = lzop.decodedSize;
pub const lzopDecodedSizeLimited = lzop.decodedSizeLimited;
pub const lzopDecodedSizeWithOptions = lzop.decodedSizeWithOptions;
pub const encodeLzopStoredAlloc = lzop.encodeStoredAlloc;
pub const encodeLzopStoredAppend = lzop.encodeStoredAppend;
pub const encodeLzopStoredInto = lzop.encodeStoredInto;

pub const SevenZipError = seven_zip.Error;
pub const SevenZipKind = seven_zip.Kind;
pub const SevenZipEntry = seven_zip.Entry;
pub const SevenZipArchive = seven_zip.Archive;
pub const SevenZipDecodeOptions = seven_zip.DecodeOptions;
pub const SevenZipParseOptions = seven_zip.ParseOptions;
pub const SevenZipEncodeEntry = seven_zip.EncodeEntry;
pub const SevenZipEncodeOptions = seven_zip.EncodeOptions;
pub const parseSevenZipArchiveAlloc = seven_zip.parseAlloc;
pub const parseSevenZipArchiveAllocWithOptions = seven_zip.parseAllocWithOptions;
pub const sevenZipExtractByNameAlloc = seven_zip.extractByNameAlloc;
pub const sevenZipExtractByNameAllocLimited = seven_zip.extractByNameAllocLimited;
pub const encodeSevenZipStoredAlloc = seven_zip.encodeStoredAlloc;
pub const encodeSevenZipStoredAppend = seven_zip.encodeStoredAppend;
pub const encodeSevenZipStoredInto = seven_zip.encodeStoredInto;

pub const BrotliError = br.Error;
pub const BrotliDecodeOptions = br.DecodeOptions;
pub const brotliMaxUncompressedMetaBlockLen = br.max_uncompressed_meta_block_len;
pub const brotliDefaultWindowBits = br.default_window_bits;
pub const brEncodedStoredStreamBound = br.encodedStoredStreamBound;
pub const brEncodedStoredStreamBoundWithOptions = br.encodedStoredStreamBoundWithOptions;
pub const brEncodedStoredStreamChunksBound = br.encodedStoredStreamChunksBound;
pub const brEncodedStoredStreamChunksBoundWithOptions = br.encodedStoredStreamChunksBoundWithOptions;
pub const brEncodeStoredStreamAlloc = br.encodeStoredStreamAlloc;
pub const brEncodeStoredStreamAppend = br.encodeStoredStreamAppend;
pub const brEncodeStoredStreamInto = br.encodeStoredStreamInto;
pub const brEncodedRleStreamBound = br.encodedRleStreamBound;
pub const brEncodeRleStreamAlloc = br.encodeRleStreamAlloc;
pub const brEncodeRleStreamAppend = br.encodeRleStreamAppend;
pub const brEncodeRleStreamInto = br.encodeRleStreamInto;
pub const brEncodeAbabaStreamAlloc = br.encodeAbabaStreamAlloc;
pub const brEncodeAbabaPatternStreamAlloc = br.encodeAbabaPatternStreamAlloc;
pub const brEncodeAlternatingStreamAlloc = br.encodeAlternatingStreamAlloc;
pub const brEncodeRepeatedPrefixStreamAlloc = br.encodeRepeatedPrefixStreamAlloc;
pub const brEncodePlannedStreamAlloc = br.encodePlannedStreamAlloc;
pub const brEncodePlannedStreamLazyAlloc = br.encodePlannedStreamLazyAlloc;
pub const brEncodePlannedStreamRatioAlloc = br.encodePlannedStreamRatioAlloc;
pub const brProfilePlannedRatioBlockAlloc = br.profilePlannedRatioBlockAlloc;
pub const brEncodePlannedStreamAllocWithStats = br.encodePlannedStreamAllocWithStats;
pub const brEncodePlannedStreamAllocWithStatsTimed = br.encodePlannedStreamAllocWithStatsTimed;
pub const BrotliPlannedEncodeStats = br.PlannedEncodeStats;
pub const BrotliRatioEncodeProfile = br.RatioEncodeProfile;
pub const BrotliPlannedCompressionLevel = br.PlannedCompressionLevel;
pub const BrotliPlannedEncodeOptions = br.PlannedEncodeOptions;
pub const brotliMaxExtendedDictionaryProbes = br.max_extended_dictionary_probes;
pub const BrotliPlannedStreamChunksOptions = br.PlannedStreamChunksOptions;
pub const BrotliPlannedParserOptions = br.PlannedParserOptions;
pub const brEncodePlannedStreamWithOptionsAlloc = br.encodePlannedStreamWithOptionsAlloc;
pub const brEncodedPlannedStreamBound = br.encodedPlannedStreamBound;
pub const brEncodedPlannedStreamBoundWithOptions = br.encodedPlannedStreamBoundWithOptions;
pub const brEncodedPlannedStreamChunksBound = br.encodedPlannedStreamChunksBound;
pub const brEncodedPlannedStreamChunksBoundWithOptions = br.encodedPlannedStreamChunksBoundWithOptions;
pub const brEncodePlannedStreamInto = br.encodePlannedStreamInto;
pub const brEncodePlannedStreamWithOptionsInto = br.encodePlannedStreamWithOptionsInto;
pub const brEncodePlannedStreamChunksAlloc = br.encodePlannedStreamChunksAlloc;
pub const brEncodePlannedStreamChunksWithOptionsAlloc = br.encodePlannedStreamChunksWithOptionsAlloc;
pub const brEncodePlannedStreamChunksAppend = br.encodePlannedStreamChunksAppend;
pub const brEncodePlannedStreamChunksWithOptionsAppend = br.encodePlannedStreamChunksWithOptionsAppend;
pub const brEncodePlannedStreamChunksInto = br.encodePlannedStreamChunksInto;
pub const brEncodePlannedStreamChunksWithOptionsInto = br.encodePlannedStreamChunksWithOptionsInto;
pub const brEncodePlannedStreamLazyWithOptionsAlloc = br.encodePlannedStreamLazyWithOptionsAlloc;
pub const brEncodePlannedStreamStaticDictionaryAlloc = br.encodePlannedStreamStaticDictionaryAlloc;
pub const brPlannedStaticDictionaryIndexBytes = br.plannedStaticDictionaryIndexBytes;
pub const brEncodePlannedStreamWithScratchAlloc = br.encodePlannedStreamWithScratchAlloc;
pub const BrotliPlannedStreamEncoder = br.PlannedStreamEncoder;
pub const brEncodedSimpleStreamBound = br.encodedSimpleStreamBound;
pub const brEncodeSimpleStreamAlloc = br.encodeSimpleStreamAlloc;
pub const brEncodeSimpleStreamAppend = br.encodeSimpleStreamAppend;
pub const brEncodeSimpleStreamInto = br.encodeSimpleStreamInto;
pub const brEncodeStoredStreamWithOptionsAlloc = br.encodeStoredStreamWithOptionsAlloc;
pub const brEncodeStoredStreamWithOptionsAppend = br.encodeStoredStreamWithOptionsAppend;
pub const brEncodeStoredStreamWithOptionsInto = br.encodeStoredStreamWithOptionsInto;
pub const brEncodeStoredStreamChunksAlloc = br.encodeStoredStreamChunksAlloc;
pub const brEncodeStoredStreamChunksAppend = br.encodeStoredStreamChunksAppend;
pub const brEncodeStoredStreamChunksInto = br.encodeStoredStreamChunksInto;
pub const brEncodeStoredStreamChunksWithOptionsAlloc = br.encodeStoredStreamChunksWithOptionsAlloc;
pub const brEncodeStoredStreamChunksWithOptionsAppend = br.encodeStoredStreamChunksWithOptionsAppend;
pub const brEncodeStoredStreamChunksWithOptionsInto = br.encodeStoredStreamChunksWithOptionsInto;
pub const BrotliStoredStreamOptions = br.StoredStreamOptions;
pub const BrotliStreamSummary = br.StreamSummary;
pub const BrotliStreamSummaryDiagnostics = br.StreamSummaryDiagnostics;
pub const BrotliStreamSummaryErrorPhase = br.StreamSummaryErrorPhase;
pub const BrotliStreamProbeResult = br.StreamProbeResult;
pub const BrotliStaticDictionaryEntry = br.StaticDictionaryEntry;
pub const BrotliCompressedSupportLimits = br.CompressedSupportLimits;
pub const BrotliPrefixCode = br.PrefixCode;
pub const BrotliStoredStreamEncoder = br.StoredStreamEncoder;
pub const BrotliStreamDecoder = br.StreamDecoder;
pub const BrotliIncrementalStreamDecoder = br.IncrementalStreamDecoder;
pub const BrotliIncrementalLiteralStreamDecoder = br.IncrementalLiteralStreamDecoder;
pub const BrotliIncrementalCopyStreamDecoder = br.IncrementalCopyStreamDecoder;
pub const brotliDefaultIncrementalCompressedHeaderBytes = br.default_incremental_compressed_header_bytes;
pub const BrotliIncrementalRleStreamDecoder = br.IncrementalRleStreamDecoder;
pub const BrotliIncrementalStoredStreamDecoder = br.IncrementalStoredStreamDecoder;
pub const BrotliIncrementalStoredStreamEncoder = br.IncrementalStoredStreamEncoder;
pub const BrotliIncrementalPlannedStreamEncoder = br.IncrementalPlannedStreamEncoder;

test "root Brotli incremental decoder continues framed payloads" {
    const first = try br.IncrementalTestSupport.encodeStored(std.testing.allocator, "one");
    defer std.testing.allocator.free(first);
    const second = try br.IncrementalTestSupport.encodeStored(std.testing.allocator, "two");
    defer std.testing.allocator.free(second);
    var decoder = BrotliIncrementalStreamDecoder.initExactCompressedSize(std.testing.allocator, .{ .expected_output_len = 3 }, first.len);
    defer decoder.deinit();
    var output: [3]u8 = undefined;
    _ = try decoder.step(first, &.{});
    _ = try decoder.step("", &output);
    try decoder.nextFrameExactCompressedSize(.{ .expected_output_len = 3 }, second.len);
    _ = try decoder.step(second, &.{});
    _ = try decoder.step("", &output);
    try std.testing.expectEqual(@as(usize, 2), decoder.snapshot().frame_count);
}

test "root Brotli incremental RLE decoder streams compressed output" {
    const payload = "r" ** 128;
    const encoded = try br.encodeRleStreamAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);
    var decoder = BrotliIncrementalRleStreamDecoder.initWithOptions(.{ .expected_output_len = payload.len });
    var output: [payload.len]u8 = undefined;
    var written: usize = 0;
    var input_offset: usize = 0;
    while (decoder.snapshot().phase != .done) {
        const input_end = @min(encoded.len, input_offset + 1);
        const result = try decoder.step(encoded[input_offset..input_end], output[written..][0..@min(7, output.len - written)]);
        input_offset += result.progress.input_read;
        written += result.progress.output_written;
    }
    try decoder.finish();
    try std.testing.expectEqualSlices(u8, payload, &output);
}

test "root Brotli incremental literal decoder streams Huffman output" {
    const encoded = try br.IncrementalTestSupport.encodeCompressedLiteralCycle(std.testing.allocator, 64);
    defer std.testing.allocator.free(encoded);
    var decoder = BrotliIncrementalLiteralStreamDecoder.initWithOptions(.{ .expected_output_len = 64 });
    var output: [64]u8 = undefined;
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (decoder.snapshot().phase != .done) {
        const input_end = @min(encoded.len, input_offset + 2);
        const result = try decoder.step(encoded[input_offset..input_end], output[output_offset..][0..@min(5, output.len - output_offset)]);
        input_offset += result.progress.input_read;
        output_offset += result.progress.output_written;
    }
    try decoder.finish();
    for (output, 0..) |byte, i| try std.testing.expectEqual("abcd"[i & 3], byte);
}

test "root Brotli incremental copy decoder streams across output buffers" {
    const expected = "xy" ** 64;
    const encoded = try br.encodeAlternatingStreamAlloc(std.testing.allocator, 'x', 'y', expected.len);
    defer std.testing.allocator.free(encoded);
    var history: [2]u8 = undefined;
    var decoder = BrotliIncrementalCopyStreamDecoder.initWithOptions(&history, .{ .expected_output_len = expected.len });
    var output: [expected.len]u8 = undefined;
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (decoder.snapshot().phase != .done) {
        const input_end = @min(encoded.len, input_offset + 1);
        const result = try decoder.step(encoded[input_offset..input_end], output[output_offset..][0..@min(3, output.len - output_offset)]);
        input_offset += result.progress.input_read;
        output_offset += result.progress.output_written;
    }
    try decoder.finish();
    try std.testing.expectEqualSlices(u8, expected, &output);
}

test "root Brotli incremental stored encoder continues streams" {
    var encoder = BrotliIncrementalStoredStreamEncoder.init(std.testing.allocator);
    defer encoder.deinit();
    var output: [64]u8 = undefined;
    _ = try encoder.step("one", &output);
    try encoder.finish();
    while ((try encoder.step("", &output)).status != .done) {}
    try encoder.nextStream(.{ .stream = .{ .window_bits = 20 } });
    try std.testing.expectEqual(@as(usize, 1), encoder.snapshot().stream_index);
}

test "root Brotli stored decoder continues streams" {
    const encoded = try br.IncrementalTestSupport.encodeStored(std.testing.allocator, "one");
    defer std.testing.allocator.free(encoded);
    var decoder = BrotliIncrementalStoredStreamDecoder.init();
    var output: [3]u8 = undefined;
    _ = try decoder.step(encoded, &output);
    try decoder.finish();
    try decoder.nextStream(.{});
    try std.testing.expectEqual(@as(usize, 1), decoder.snapshot().stream_index);
}
pub const brCompressedSupportLimits = br.compressedSupportLimits;
pub const brMinimalStaticDictionaryCoverage = br.minimalStaticDictionaryCoverage;
pub const brMinimalStaticDictionarySizeBits = br.minimalStaticDictionarySizeBits;
pub const brDecodeStreamAlloc = br.decodeStreamAlloc;
pub const brDecodeStreamAllocWithOptions = br.decodeStreamAllocWithOptions;
pub const brDecodeStreamAllocExactSize = br.decodeStreamAllocExactSize;
pub const brDecodeStreamAllocExactSizeWithOptions = br.decodeStreamAllocExactSizeWithOptions;
pub const brDecodeStreamAllocLimited = br.decodeStreamAllocLimited;
pub const brDecodeStreamAllocLimitedWithOptions = br.decodeStreamAllocLimitedWithOptions;
pub const brDecodeStreamAppend = br.decodeStreamAppend;
pub const brDecodeStreamAppendWithOptions = br.decodeStreamAppendWithOptions;
pub const brDecodeStreamAppendExactSize = br.decodeStreamAppendExactSize;
pub const brDecodeStreamAppendExactSizeWithOptions = br.decodeStreamAppendExactSizeWithOptions;
pub const brDecodeStreamAppendLimited = br.decodeStreamAppendLimited;
pub const brDecodeStreamAppendLimitedWithOptions = br.decodeStreamAppendLimitedWithOptions;
pub const brDecodeStreamInto = br.decodeStreamInto;
pub const brDecodeStreamIntoWithOptions = br.decodeStreamIntoWithOptions;
pub const brDecodeStreamIntoExactSize = br.decodeStreamIntoExactSize;
pub const brDecodeStreamIntoExactSizeWithOptions = br.decodeStreamIntoExactSizeWithOptions;
pub const brDecodeStreamIntoLimited = br.decodeStreamIntoLimited;
pub const brDecodeStreamIntoLimitedWithOptions = br.decodeStreamIntoLimitedWithOptions;
pub const brDecodedStreamSize = br.decodedStreamSize;
pub const brDecodedStreamSizeWithOptions = br.decodedStreamSizeWithOptions;
pub const brDecodedStreamSizeLimited = br.decodedStreamSizeLimited;
pub const brDecodedStreamSizeLimitedWithOptions = br.decodedStreamSizeLimitedWithOptions;
pub const brSummarizeStream = br.summarizeStream;
pub const brSummarizeStreamWithOptions = br.summarizeStreamWithOptions;
pub const brSummarizeStreamLimited = br.summarizeStreamLimited;
pub const brSummarizeStreamLimitedWithOptions = br.summarizeStreamLimitedWithOptions;
pub const brSummarizeStreamLimitedWithOptionsAndDiagnostics = br.summarizeStreamLimitedWithOptionsAndDiagnostics;
pub const brSummarizeStreamWithDiagnostics = br.summarizeStreamWithDiagnostics;
pub const brSummarizeStreamWithOptionsAndDiagnostics = br.summarizeStreamWithOptionsAndDiagnostics;
pub const brSummarizeStreamLimitedWithDiagnostics = br.summarizeStreamLimitedWithDiagnostics;
pub const brSummarizeStreamWithHistory = br.summarizeStreamWithHistory;
pub const brSummarizeStreamWithHistoryAndOptions = br.summarizeStreamWithHistoryAndOptions;
pub const brSummarizeStreamLimitedWithHistory = br.summarizeStreamLimitedWithHistory;
pub const brSummarizeStreamLimitedWithHistoryAndOptions = br.summarizeStreamLimitedWithHistoryAndOptions;
pub const brSummarizeStreamWithHistoryAndDiagnostics = br.summarizeStreamWithHistoryAndDiagnostics;
pub const brSummarizeStreamWithHistoryAndOptionsAndDiagnostics = br.summarizeStreamWithHistoryAndOptionsAndDiagnostics;
pub const brSummarizeStreamLimitedWithHistoryAndDiagnostics = br.summarizeStreamLimitedWithHistoryAndDiagnostics;
pub const brSummarizeStreamLimitedWithHistoryAndOptionsAndDiagnostics = br.summarizeStreamLimitedWithHistoryAndOptionsAndDiagnostics;
pub const brSummarizeStreamAlloc = br.summarizeStreamAlloc;
pub const brSummarizeStreamAllocWithOptions = br.summarizeStreamAllocWithOptions;
pub const brSummarizeStreamAllocLimited = br.summarizeStreamAllocLimited;
pub const brSummarizeStreamAllocLimitedWithOptions = br.summarizeStreamAllocLimitedWithOptions;
pub const brSummarizeStreamAllocWithDiagnostics = br.summarizeStreamAllocWithDiagnostics;
pub const brSummarizeStreamAllocWithOptionsAndDiagnostics = br.summarizeStreamAllocWithOptionsAndDiagnostics;
pub const brSummarizeStreamAllocLimitedWithDiagnostics = br.summarizeStreamAllocLimitedWithDiagnostics;
pub const brSummarizeStreamAllocLimitedWithOptionsAndDiagnostics = br.summarizeStreamAllocLimitedWithOptionsAndDiagnostics;
pub const brProbeStream = br.probeStream;
pub const brProbeStreamWithOptions = br.probeStreamWithOptions;
pub const brProbeStreamLimited = br.probeStreamLimited;
pub const brProbeStreamLimitedWithOptions = br.probeStreamLimitedWithOptions;
pub const brProbeStreamExactSize = br.probeStreamExactSize;
pub const brProbeStreamExactSizeWithOptions = br.probeStreamExactSizeWithOptions;
pub const brDecodeStreamChunksAlloc = br.decodeStreamChunksAlloc;
pub const brDecodeStreamChunksAllocWithOptions = br.decodeStreamChunksAllocWithOptions;
pub const brDecodeStreamChunksAllocExactSize = br.decodeStreamChunksAllocExactSize;
pub const brDecodeStreamChunksAllocExactSizeWithOptions = br.decodeStreamChunksAllocExactSizeWithOptions;
pub const brDecodeStreamChunksAllocLimited = br.decodeStreamChunksAllocLimited;
pub const brDecodeStreamChunksAllocLimitedWithOptions = br.decodeStreamChunksAllocLimitedWithOptions;
pub const brDecodeStreamChunksAppend = br.decodeStreamChunksAppend;
pub const brDecodeStreamChunksAppendWithOptions = br.decodeStreamChunksAppendWithOptions;
pub const brDecodeStreamChunksAppendExactSize = br.decodeStreamChunksAppendExactSize;
pub const brDecodeStreamChunksAppendExactSizeWithOptions = br.decodeStreamChunksAppendExactSizeWithOptions;
pub const brDecodeStreamChunksAppendLimited = br.decodeStreamChunksAppendLimited;
pub const brDecodeStreamChunksAppendLimitedWithOptions = br.decodeStreamChunksAppendLimitedWithOptions;
pub const brDecodeStreamChunksInto = br.decodeStreamChunksInto;
pub const brDecodeStreamChunksIntoWithOptions = br.decodeStreamChunksIntoWithOptions;
pub const brDecodeStreamChunksIntoExactSize = br.decodeStreamChunksIntoExactSize;
pub const brDecodeStreamChunksIntoExactSizeWithOptions = br.decodeStreamChunksIntoExactSizeWithOptions;
pub const brDecodeStreamChunksIntoLimited = br.decodeStreamChunksIntoLimited;
pub const brDecodeStreamChunksIntoLimitedWithOptions = br.decodeStreamChunksIntoLimitedWithOptions;
pub const brDecodedStreamChunksSize = br.decodedStreamChunksSize;
pub const brDecodedStreamChunksSizeWithOptions = br.decodedStreamChunksSizeWithOptions;
pub const brDecodedStreamChunksSizeLimited = br.decodedStreamChunksSizeLimited;
pub const brDecodedStreamChunksSizeLimitedWithOptions = br.decodedStreamChunksSizeLimitedWithOptions;
pub const brSummarizeStreamChunks = br.summarizeStreamChunks;
pub const brSummarizeStreamChunksWithOptions = br.summarizeStreamChunksWithOptions;
pub const brSummarizeStreamChunksLimited = br.summarizeStreamChunksLimited;
pub const brSummarizeStreamChunksLimitedWithOptions = br.summarizeStreamChunksLimitedWithOptions;
pub const brSummarizeStreamChunksWithDiagnostics = br.summarizeStreamChunksWithDiagnostics;
pub const brSummarizeStreamChunksWithOptionsAndDiagnostics = br.summarizeStreamChunksWithOptionsAndDiagnostics;
pub const brSummarizeStreamChunksLimitedWithDiagnostics = br.summarizeStreamChunksLimitedWithDiagnostics;
pub const brSummarizeStreamChunksLimitedWithOptionsAndDiagnostics = br.summarizeStreamChunksLimitedWithOptionsAndDiagnostics;
pub const brSummarizeStreamChunksWithHistory = br.summarizeStreamChunksWithHistory;
pub const brSummarizeStreamChunksWithHistoryAndOptions = br.summarizeStreamChunksWithHistoryAndOptions;
pub const brSummarizeStreamChunksLimitedWithHistory = br.summarizeStreamChunksLimitedWithHistory;
pub const brSummarizeStreamChunksLimitedWithHistoryAndOptions = br.summarizeStreamChunksLimitedWithHistoryAndOptions;
pub const brSummarizeStreamChunksWithHistoryAndDiagnostics = br.summarizeStreamChunksWithHistoryAndDiagnostics;
pub const brSummarizeStreamChunksWithHistoryAndOptionsAndDiagnostics = br.summarizeStreamChunksWithHistoryAndOptionsAndDiagnostics;
pub const brSummarizeStreamChunksLimitedWithHistoryAndDiagnostics = br.summarizeStreamChunksLimitedWithHistoryAndDiagnostics;
pub const brSummarizeStreamChunksLimitedWithHistoryAndOptionsAndDiagnostics = br.summarizeStreamChunksLimitedWithHistoryAndOptionsAndDiagnostics;
pub const brProbeStreamChunks = br.probeStreamChunks;
pub const brProbeStreamChunksWithOptions = br.probeStreamChunksWithOptions;
pub const brProbeStreamChunksLimited = br.probeStreamChunksLimited;
pub const brProbeStreamChunksLimitedWithOptions = br.probeStreamChunksLimitedWithOptions;
pub const brProbeStreamChunksExactSize = br.probeStreamChunksExactSize;
pub const brProbeStreamChunksExactSizeWithOptions = br.probeStreamChunksExactSizeWithOptions;

pub const SnappyError = snappy.Error;
pub const snappyMaxUncompressedChunkLen = snappy.max_uncompressed_chunk_len;
pub const snappyEncodeBlockAlloc = snappy.encodeBlockAlloc;
pub const snappyEncodeBlockAppend = snappy.encodeBlockAppend;
pub const snappyEncodeBlockInto = snappy.encodeBlockInto;
pub const snappyEncodedBlockBound = snappy.encodedBlockBound;
pub const snappyEncodeFrameAlloc = snappy.encodeFrameAlloc;
pub const snappyEncodeFrameAppend = snappy.encodeFrameAppend;
pub const snappyEncodeFrameInto = snappy.encodeFrameInto;
pub const snappyEncodedFrameBound = snappy.encodedFrameBound;
pub const SnappyEncoder = snappy.Encoder;
pub const SnappyIncrementalFrameDecoder = snappy.IncrementalFrameDecoder;
pub const SnappyIncrementalFrameEncoder = snappy.IncrementalFrameEncoder;

test "root incremental Snappy streams continue" {
    var encoder = SnappyIncrementalFrameEncoder.init(std.testing.allocator);
    defer encoder.deinit();
    var output: [128]u8 = undefined;
    _ = try encoder.step("one", &output);
    try encoder.finish();
    while ((try encoder.step("", &output)).status != .done) {}
    try encoder.nextStreamExactSize(.{}, 3);
    try std.testing.expectEqual(@as(usize, 1), encoder.snapshot().stream_index);

    var decoder = SnappyIncrementalFrameDecoder.init(std.testing.allocator);
    defer decoder.deinit();
    try std.testing.expectError(error.InvalidBlockPlan, decoder.nextStream(.{}));
}
pub const SnappyFrameSummary = snappy.FrameSummary;
pub const SnappyBlockSummary = snappy.BlockSummary;
pub const snappySummarizeBlock = snappy.summarizeBlock;
pub const snappySummarizeBlockLimited = snappy.summarizeBlockLimited;
pub const snappySummarizeBlockChunks = snappy.summarizeBlockChunks;
pub const snappySummarizeFrame = snappy.summarizeFrame;
pub const snappySummarizeFrameChunks = snappy.summarizeFrameChunks;
pub const snappyDecodeBlockAlloc = snappy.decodeBlockAlloc;
pub const snappyDecodeBlockAllocExactSize = snappy.decodeBlockAllocExactSize;
pub const snappyDecodeBlockAllocLimited = snappy.decodeBlockAllocLimited;
pub const snappyDecodeBlockAppend = snappy.decodeBlockAppend;
pub const snappyDecodeBlockAppendExactSize = snappy.decodeBlockAppendExactSize;
pub const snappyDecodeBlockAppendLimited = snappy.decodeBlockAppendLimited;
pub const snappyDecodeBlockInto = snappy.decodeBlockInto;
pub const snappyDecodeBlockIntoExactSize = snappy.decodeBlockIntoExactSize;
pub const snappyDecodedBlockSize = snappy.decodedBlockSize;
pub const snappyDecodedBlockSizeLimited = snappy.decodedBlockSizeLimited;
pub const snappyDecodeBlockChunksAlloc = snappy.decodeBlockChunksAlloc;
pub const snappyDecodeBlockChunksAllocExactSize = snappy.decodeBlockChunksAllocExactSize;
pub const snappyDecodeBlockChunksAllocLimited = snappy.decodeBlockChunksAllocLimited;
pub const snappyDecodeBlockChunksAppend = snappy.decodeBlockChunksAppend;
pub const snappyDecodeBlockChunksAppendExactSize = snappy.decodeBlockChunksAppendExactSize;
pub const snappyDecodeBlockChunksAppendLimited = snappy.decodeBlockChunksAppendLimited;
pub const snappyDecodeBlockChunksInto = snappy.decodeBlockChunksInto;
pub const snappyDecodeBlockChunksIntoExactSize = snappy.decodeBlockChunksIntoExactSize;
pub const snappyDecodedBlockChunksSize = snappy.decodedBlockChunksSize;
pub const snappyDecodedBlockChunksSizeLimited = snappy.decodedBlockChunksSizeLimited;
pub const snappyDecodeFrameAlloc = snappy.decodeFrameAlloc;
pub const snappyDecodeFrameAllocExactSize = snappy.decodeFrameAllocExactSize;
pub const snappyDecodeFrameAllocLimited = snappy.decodeFrameAllocLimited;
pub const snappyDecodeFrameAppend = snappy.decodeFrameAppend;
pub const snappyDecodeFrameAppendExactSize = snappy.decodeFrameAppendExactSize;
pub const snappyDecodeFrameAppendLimited = snappy.decodeFrameAppendLimited;
pub const snappyDecodeFrameInto = snappy.decodeFrameInto;
pub const snappyDecodeFrameIntoExactSize = snappy.decodeFrameIntoExactSize;
pub const snappyDecodedFrameSize = snappy.decodedFrameSize;
pub const snappyDecodedFrameSizeLimited = snappy.decodedFrameSizeLimited;
pub const snappyDecodeFrameChunksAlloc = snappy.decodeFrameChunksAlloc;
pub const snappyDecodeFrameChunksAllocExactSize = snappy.decodeFrameChunksAllocExactSize;
pub const snappyDecodeFrameChunksAllocLimited = snappy.decodeFrameChunksAllocLimited;
pub const snappyDecodeFrameChunksAppend = snappy.decodeFrameChunksAppend;
pub const snappyDecodeFrameChunksAppendExactSize = snappy.decodeFrameChunksAppendExactSize;
pub const snappyDecodeFrameChunksAppendLimited = snappy.decodeFrameChunksAppendLimited;
pub const snappyDecodeFrameChunksInto = snappy.decodeFrameChunksInto;
pub const snappyDecodeFrameChunksIntoExactSize = snappy.decodeFrameChunksIntoExactSize;
pub const snappyDecodedFrameChunksSize = snappy.decodedFrameChunksSize;
pub const snappyDecodedFrameChunksSizeLimited = snappy.decodedFrameChunksSizeLimited;

pub const Lz4Error = lz4.Error;
pub const lz4DefaultCompressionLevel = lz4.default_compression_level;
pub const lz4EncodeFrameAlloc = lz4.encodeFrameAlloc;
pub const lz4EncodeFrameWithLevelAlloc = lz4.encodeFrameWithLevelAlloc;
pub const lz4EncodeFrameWithOptionsAlloc = lz4.encodeFrameWithOptionsAlloc;
pub const lz4EncodeFrameWithLevelAndOptionsAlloc = lz4.encodeFrameWithLevelAndOptionsAlloc;
pub const lz4EncodePureFrameAlloc = lz4.encodePureFrameAlloc;
pub const lz4EncodePureFrameWithOptionsAlloc = lz4.encodePureFrameWithOptionsAlloc;
pub const lz4EncodePureFrameAppend = lz4.encodePureFrameAppend;
pub const lz4EncodeNativeFrameAlloc = lz4.encodeNativeFrameAlloc;
pub const lz4EncodeNativeFrameWithOptionsAlloc = lz4.encodeNativeFrameWithOptionsAlloc;
pub const lz4EncodeNativeFrameAppend = lz4.encodeNativeFrameAppend;
pub const lz4EncodeNativeFrameIntoSlice = lz4.encodeNativeFrameIntoSlice;
pub const lz4EncodedSkippableFrameBound = lz4.encodedSkippableFrameBound;
pub const lz4EncodeSkippableFrameAlloc = lz4.encodeSkippableFrameAlloc;
pub const lz4EncodeSkippableFrameAppend = lz4.encodeSkippableFrameAppend;
pub const lz4EncodeSkippableFrameIntoSlice = lz4.encodeSkippableFrameIntoSlice;
pub const Lz4FrameOptions = lz4.FrameOptions;
pub const Lz4NativeFrameOptions = lz4.NativeFrameOptions;
pub const lz4NativeMaxChainDepth = lz4.native_max_chain_depth;
pub const Lz4NativeFrameHeader = lz4.NativeFrameHeader;
pub const Lz4NativeFrameBlockHeader = lz4.NativeFrameBlockHeader;
pub const Lz4NativeFrameBlockSummary = lz4.NativeFrameBlockSummary;
pub const Lz4BlockSummary = lz4.BlockSummary;
pub const Lz4NativeStreamSummary = lz4.NativeStreamSummary;
pub const Lz4NativeStreamSummaryErrorDiagnostics = lz4.NativeStreamSummaryErrorDiagnostics;
pub const Lz4NativeStreamSummaryErrorPhase = lz4.NativeStreamSummaryErrorPhase;
pub const Lz4NativeSkippableFrameHeader = lz4.NativeSkippableFrameHeader;
pub const Lz4NativeFrameBlockIterator = lz4.NativeFrameBlockIterator;
pub const Lz4NativeStreamFrame = lz4.NativeStreamFrame;
pub const Lz4NativeStreamSkippableFrame = lz4.NativeStreamSkippableFrame;
pub const Lz4NativeStreamElement = lz4.NativeStreamElement;
pub const Lz4NativeStreamIterator = lz4.NativeStreamIterator;
pub const lz4NativeDictionaryWindowLen = lz4.native_dictionary_window_len;
pub const lz4InspectNativeFrameHeader = lz4.inspectNativeFrameHeader;
pub const lz4InspectNativeFrameFirstBlock = lz4.inspectNativeFrameFirstBlock;
pub const lz4InspectNativeFrameBlockAt = lz4.inspectNativeFrameBlockAt;
pub const lz4SummarizeNativeFrameBlocks = lz4.summarizeNativeFrameBlocks;
pub const lz4SummarizeNativeStream = lz4.summarizeNativeStream;
pub const lz4SummarizeNativeStreamWithDiagnostics = lz4.summarizeNativeStreamWithDiagnostics;
pub const lz4InspectNativeSkippableFrame = lz4.inspectNativeSkippableFrame;
pub const lz4IterateNativeFrameBlocks = lz4.iterateNativeFrameBlocks;
pub const lz4IterateNativeStream = lz4.iterateNativeStream;
pub const Lz4BlockSizeId = lz4.BlockSizeId;
pub const Lz4BlockMode = lz4.BlockMode;
pub const Lz4BlockEncoder = lz4.BlockEncoder;
pub const Lz4BlockDecoder = lz4.BlockDecoder;
pub const Lz4NativeFrameEncoder = lz4.NativeFrameEncoder;
pub const Lz4NativeIncrementalFrameEncoder = lz4.NativeIncrementalFrameEncoder;

test "root LZ4 incremental encoder continues frames" {
    var encoder = try Lz4NativeIncrementalFrameEncoder.initExactSize(std.testing.allocator, .{ .include_content_size = true }, 3);
    defer encoder.deinit();
    var output: [128]u8 = undefined;
    _ = try encoder.step("one", &output);
    encoder.finish();
    while ((try encoder.step("", &output)).status != .done) {}
    try encoder.nextFrameExactSize(.{ .include_content_size = true }, 3);
    try std.testing.expectEqual(@as(usize, 1), encoder.snapshot().frame_index);
}
pub const Lz4NativeFrameDecoder = lz4.NativeFrameDecoder;
pub const Lz4NativeIncrementalFrameDecoder = lz4.NativeIncrementalFrameDecoder;
pub const Lz4NativeDictionary = lz4.NativeDictionary;
pub const Lz4NativeDictionaryTrainOptions = lz4.NativeDictionaryTrainOptions;
pub const Lz4OwnedNativeDictionary = lz4.OwnedNativeDictionary;
pub const Lz4NativeDictionarySet = lz4.NativeDictionarySet;
pub const Lz4OwnedNativeDictionarySet = lz4.OwnedNativeDictionarySet;
pub const lz4TrainNativeDictionaryAlloc = lz4.trainNativeDictionaryAlloc;
pub const lz4NativeDictionarySetFromMetadataAlloc = lz4.nativeDictionarySetFromMetadataAlloc;
pub const lz4DecodeFrameAlloc = lz4.decodeFrameAlloc;
pub const lz4DecodeFrameAppend = lz4.decodeFrameAppend;
pub const lz4DecodeFrameAppendExactSize = lz4.decodeFrameAppendExactSize;
pub const lz4DecodeFrameAppendLimited = lz4.decodeFrameAppendLimited;
pub const lz4DecodeFrameAllocLimited = lz4.decodeFrameAllocLimited;
pub const lz4DecodeFrameAllocExactSize = lz4.decodeFrameAllocExactSize;
pub const lz4DecodedFrameSize = lz4.decodedFrameSize;
pub const lz4DecodedFrameSizeLimited = lz4.decodedFrameSizeLimited;
pub const lz4DecodeFrameInto = lz4.decodeFrameInto;
pub const lz4DecodeFrameIntoExactSize = lz4.decodeFrameIntoExactSize;
pub const lz4DecodeFrameAllocWithDictionary = lz4.decodeFrameAllocWithDictionary;
pub const lz4DecodeFrameAppendWithDictionary = lz4.decodeFrameAppendWithDictionary;
pub const lz4DecodeFrameAppendExactSizeWithDictionary = lz4.decodeFrameAppendExactSizeWithDictionary;
pub const lz4DecodeFrameAppendLimitedWithDictionary = lz4.decodeFrameAppendLimitedWithDictionary;
pub const lz4DecodeFrameAllocLimitedWithDictionary = lz4.decodeFrameAllocLimitedWithDictionary;
pub const lz4DecodeFrameAllocWithDictionaryExactSize = lz4.decodeFrameAllocWithDictionaryExactSize;
pub const lz4DecodeFrameIntoWithDictionary = lz4.decodeFrameIntoWithDictionary;
pub const lz4DecodeFrameIntoWithDictionaryExactSize = lz4.decodeFrameIntoWithDictionaryExactSize;
pub const lz4DecodedFrameSizeWithDictionary = lz4.decodedFrameSizeWithDictionary;
pub const lz4DecodedFrameSizeLimitedWithDictionary = lz4.decodedFrameSizeLimitedWithDictionary;
pub const lz4DecodeFrameAllocWithDictionarySet = lz4.decodeFrameAllocWithDictionarySet;
pub const lz4DecodeFrameAppendWithDictionarySet = lz4.decodeFrameAppendWithDictionarySet;
pub const lz4DecodeFrameAppendExactSizeWithDictionarySet = lz4.decodeFrameAppendExactSizeWithDictionarySet;
pub const lz4DecodeFrameAppendLimitedWithDictionarySet = lz4.decodeFrameAppendLimitedWithDictionarySet;
pub const lz4DecodeFrameAllocLimitedWithDictionarySet = lz4.decodeFrameAllocLimitedWithDictionarySet;
pub const lz4DecodeFrameAllocWithDictionarySetExactSize = lz4.decodeFrameAllocWithDictionarySetExactSize;
pub const lz4DecodeFrameIntoWithDictionarySet = lz4.decodeFrameIntoWithDictionarySet;
pub const lz4DecodeFrameIntoWithDictionarySetExactSize = lz4.decodeFrameIntoWithDictionarySetExactSize;
pub const lz4DecodedFrameSizeWithDictionarySet = lz4.decodedFrameSizeWithDictionarySet;
pub const lz4DecodedFrameSizeLimitedWithDictionarySet = lz4.decodedFrameSizeLimitedWithDictionarySet;
pub const lz4DecodeFrameChunksAlloc = lz4.decodeFrameChunksAlloc;
pub const lz4DecodeFrameChunksAllocExactSize = lz4.decodeFrameChunksAllocExactSize;
pub const lz4DecodeFrameChunksAllocLimited = lz4.decodeFrameChunksAllocLimited;
pub const lz4DecodeFrameChunksAppend = lz4.decodeFrameChunksAppend;
pub const lz4DecodeFrameChunksAppendExactSize = lz4.decodeFrameChunksAppendExactSize;
pub const lz4DecodeFrameChunksAppendLimited = lz4.decodeFrameChunksAppendLimited;
pub const lz4DecodeFrameChunksInto = lz4.decodeFrameChunksInto;
pub const lz4DecodeFrameChunksIntoExactSize = lz4.decodeFrameChunksIntoExactSize;
pub const lz4DecodedFrameChunksSize = lz4.decodedFrameChunksSize;
pub const lz4DecodedFrameChunksSizeLimited = lz4.decodedFrameChunksSizeLimited;
pub const lz4DecodeFrameChunksAllocWithDictionary = lz4.decodeFrameChunksAllocWithDictionary;
pub const lz4DecodeFrameChunksAllocWithDictionaryExactSize = lz4.decodeFrameChunksAllocWithDictionaryExactSize;
pub const lz4DecodeFrameChunksAllocWithDictionaryLimited = lz4.decodeFrameChunksAllocWithDictionaryLimited;
pub const lz4DecodeFrameChunksAppendWithDictionary = lz4.decodeFrameChunksAppendWithDictionary;
pub const lz4DecodeFrameChunksAppendExactSizeWithDictionary = lz4.decodeFrameChunksAppendExactSizeWithDictionary;
pub const lz4DecodeFrameChunksAppendLimitedWithDictionary = lz4.decodeFrameChunksAppendLimitedWithDictionary;
pub const lz4DecodeFrameChunksIntoWithDictionary = lz4.decodeFrameChunksIntoWithDictionary;
pub const lz4DecodeFrameChunksIntoWithDictionaryExactSize = lz4.decodeFrameChunksIntoExactSizeWithDictionary;
pub const lz4DecodedFrameChunksSizeWithDictionary = lz4.decodedFrameChunksSizeWithDictionary;
pub const lz4DecodedFrameChunksSizeLimitedWithDictionary = lz4.decodedFrameChunksSizeLimitedWithDictionary;
pub const lz4DecodeFrameChunksAllocWithDictionarySet = lz4.decodeFrameChunksAllocWithDictionarySet;
pub const lz4DecodeFrameChunksAllocWithDictionarySetExactSize = lz4.decodeFrameChunksAllocWithDictionarySetExactSize;
pub const lz4DecodeFrameChunksAllocWithDictionarySetLimited = lz4.decodeFrameChunksAllocWithDictionarySetLimited;
pub const lz4DecodeFrameChunksAppendWithDictionarySet = lz4.decodeFrameChunksAppendWithDictionarySet;
pub const lz4DecodeFrameChunksAppendExactSizeWithDictionarySet = lz4.decodeFrameChunksAppendExactSizeWithDictionarySet;
pub const lz4DecodeFrameChunksAppendLimitedWithDictionarySet = lz4.decodeFrameChunksAppendLimitedWithDictionarySet;
pub const lz4DecodeFrameChunksIntoWithDictionarySet = lz4.decodeFrameChunksIntoWithDictionarySet;
pub const lz4DecodeFrameChunksIntoWithDictionarySetExactSize = lz4.decodeFrameChunksIntoExactSizeWithDictionarySet;
pub const lz4DecodedFrameChunksSizeWithDictionarySet = lz4.decodedFrameChunksSizeWithDictionarySet;
pub const lz4DecodedFrameChunksSizeLimitedWithDictionarySet = lz4.decodedFrameChunksSizeLimitedWithDictionarySet;
pub const lz4DecodeNativeFrameAlloc = lz4.decodeNativeFrameAlloc;
pub const lz4DecodeNativeFrameAppend = lz4.decodeNativeFrameAppend;
pub const lz4DecodeNativeFrameAppendExactSize = lz4.decodeNativeFrameAppendExactSize;
pub const lz4DecodeNativeFrameAppendLimited = lz4.decodeNativeFrameAppendLimited;
pub const lz4DecodeNativeFrameAllocLimited = lz4.decodeNativeFrameAllocLimited;
pub const lz4DecodeNativeFrameAllocExactSize = lz4.decodeNativeFrameAllocExactSize;
pub const lz4DecodeNativeFrameInto = lz4.decodeNativeFrameInto;
pub const lz4DecodeNativeFrameIntoExactSize = lz4.decodeNativeFrameIntoExactSize;
pub const lz4DecodedNativeFrameSize = lz4.decodedNativeFrameSize;
pub const lz4DecodedNativeFrameSizeLimited = lz4.decodedNativeFrameSizeLimited;
pub const lz4DecodeNativeFrameChunksAlloc = lz4.decodeNativeFrameChunksAlloc;
pub const lz4DecodeNativeFrameChunksAllocExactSize = lz4.decodeNativeFrameChunksAllocExactSize;
pub const lz4DecodeNativeFrameChunksAllocLimited = lz4.decodeNativeFrameChunksAllocLimited;
pub const lz4DecodeNativeFrameChunksAppend = lz4.decodeNativeFrameChunksAppend;
pub const lz4DecodeNativeFrameChunksAppendExactSize = lz4.decodeNativeFrameChunksAppendExactSize;
pub const lz4DecodeNativeFrameChunksAppendLimited = lz4.decodeNativeFrameChunksAppendLimited;
pub const lz4DecodeNativeFrameChunksInto = lz4.decodeNativeFrameChunksInto;
pub const lz4DecodeNativeFrameChunksIntoExactSize = lz4.decodeNativeFrameChunksIntoExactSize;
pub const lz4DecodedNativeFrameChunksSize = lz4.decodedNativeFrameChunksSize;
pub const lz4DecodedNativeFrameChunksSizeLimited = lz4.decodedNativeFrameChunksSizeLimited;
pub const lz4DecodeNativeFrameChunksAllocWithDictionary = lz4.decodeNativeFrameChunksAllocWithDictionary;
pub const lz4DecodeNativeFrameChunksAllocWithDictionaryExactSize = lz4.decodeNativeFrameChunksAllocWithDictionaryExactSize;
pub const lz4DecodeNativeFrameChunksAllocWithDictionaryLimited = lz4.decodeNativeFrameChunksAllocWithDictionaryLimited;
pub const lz4DecodeNativeFrameChunksAppendWithDictionary = lz4.decodeNativeFrameChunksAppendWithDictionary;
pub const lz4DecodeNativeFrameChunksAppendExactSizeWithDictionary = lz4.decodeNativeFrameChunksAppendExactSizeWithDictionary;
pub const lz4DecodeNativeFrameChunksAppendLimitedWithDictionary = lz4.decodeNativeFrameChunksAppendLimitedWithDictionary;
pub const lz4DecodeNativeFrameChunksIntoWithDictionary = lz4.decodeNativeFrameChunksIntoWithDictionary;
pub const lz4DecodeNativeFrameChunksIntoExactSizeWithDictionary = lz4.decodeNativeFrameChunksIntoExactSizeWithDictionary;
pub const lz4DecodeNativeFrameChunksIntoWithDictionaryExactSize = lz4.decodeNativeFrameChunksIntoWithDictionaryExactSize;
pub const lz4DecodedNativeFrameChunksSizeWithDictionary = lz4.decodedNativeFrameChunksSizeWithDictionary;
pub const lz4DecodedNativeFrameChunksSizeLimitedWithDictionary = lz4.decodedNativeFrameChunksSizeLimitedWithDictionary;
pub const lz4DecodeNativeFrameChunksAllocWithDictionarySet = lz4.decodeNativeFrameChunksAllocWithDictionarySet;
pub const lz4DecodeNativeFrameChunksAllocWithDictionarySetExactSize = lz4.decodeNativeFrameChunksAllocWithDictionarySetExactSize;
pub const lz4DecodeNativeFrameChunksAllocWithDictionarySetLimited = lz4.decodeNativeFrameChunksAllocWithDictionarySetLimited;
pub const lz4DecodeNativeFrameChunksAppendWithDictionarySet = lz4.decodeNativeFrameChunksAppendWithDictionarySet;
pub const lz4DecodeNativeFrameChunksAppendExactSizeWithDictionarySet = lz4.decodeNativeFrameChunksAppendExactSizeWithDictionarySet;
pub const lz4DecodeNativeFrameChunksAppendLimitedWithDictionarySet = lz4.decodeNativeFrameChunksAppendLimitedWithDictionarySet;
pub const lz4DecodeNativeFrameChunksIntoWithDictionarySet = lz4.decodeNativeFrameChunksIntoWithDictionarySet;
pub const lz4DecodeNativeFrameChunksIntoExactSizeWithDictionarySet = lz4.decodeNativeFrameChunksIntoExactSizeWithDictionarySet;
pub const lz4DecodeNativeFrameChunksIntoWithDictionarySetExactSize = lz4.decodeNativeFrameChunksIntoWithDictionarySetExactSize;
pub const lz4DecodedNativeFrameChunksSizeWithDictionarySet = lz4.decodedNativeFrameChunksSizeWithDictionarySet;
pub const lz4DecodedNativeFrameChunksSizeLimitedWithDictionarySet = lz4.decodedNativeFrameChunksSizeLimitedWithDictionarySet;
pub const lz4DecodeNativeFrameAllocWithDictionary = lz4.decodeNativeFrameAllocWithDictionary;
pub const lz4DecodeNativeFrameAppendWithDictionary = lz4.decodeNativeFrameAppendWithDictionary;
pub const lz4DecodeNativeFrameAppendExactSizeWithDictionary = lz4.decodeNativeFrameAppendExactSizeWithDictionary;
pub const lz4DecodeNativeFrameAppendLimitedWithDictionary = lz4.decodeNativeFrameAppendLimitedWithDictionary;
pub const lz4DecodeNativeFrameAllocLimitedWithDictionary = lz4.decodeNativeFrameAllocLimitedWithDictionary;
pub const lz4DecodeNativeFrameAllocWithDictionaryExactSize = lz4.decodeNativeFrameAllocWithDictionaryExactSize;
pub const lz4DecodeNativeFrameIntoWithDictionary = lz4.decodeNativeFrameIntoWithDictionary;
pub const lz4DecodeNativeFrameIntoWithDictionaryExactSize = lz4.decodeNativeFrameIntoWithDictionaryExactSize;
pub const lz4DecodedNativeFrameSizeWithDictionary = lz4.decodedNativeFrameSizeWithDictionary;
pub const lz4DecodedNativeFrameSizeLimitedWithDictionary = lz4.decodedNativeFrameSizeLimitedWithDictionary;
pub const lz4DecodeNativeFrameAllocWithDictionarySet = lz4.decodeNativeFrameAllocWithDictionarySet;
pub const lz4DecodeNativeFrameAppendWithDictionarySet = lz4.decodeNativeFrameAppendWithDictionarySet;
pub const lz4DecodeNativeFrameAppendExactSizeWithDictionarySet = lz4.decodeNativeFrameAppendExactSizeWithDictionarySet;
pub const lz4DecodeNativeFrameAppendLimitedWithDictionarySet = lz4.decodeNativeFrameAppendLimitedWithDictionarySet;
pub const lz4DecodeNativeFrameAllocLimitedWithDictionarySet = lz4.decodeNativeFrameAllocLimitedWithDictionarySet;
pub const lz4DecodeNativeFrameAllocWithDictionarySetExactSize = lz4.decodeNativeFrameAllocWithDictionarySetExactSize;
pub const lz4DecodeNativeFrameIntoWithDictionarySet = lz4.decodeNativeFrameIntoWithDictionarySet;
pub const lz4DecodeNativeFrameIntoWithDictionarySetExactSize = lz4.decodeNativeFrameIntoWithDictionarySetExactSize;
pub const lz4DecodedNativeFrameSizeWithDictionarySet = lz4.decodedNativeFrameSizeWithDictionarySet;
pub const lz4DecodedNativeFrameSizeLimitedWithDictionarySet = lz4.decodedNativeFrameSizeLimitedWithDictionarySet;
pub const lz4DecodeConcatenatedFrameAlloc = lz4.decodeConcatenatedFrameAlloc;
pub const lz4DecodeConcatenatedFrameAppend = lz4.decodeConcatenatedFrameAppend;
pub const lz4DecodeConcatenatedFrameAppendExactSize = lz4.decodeConcatenatedFrameAppendExactSize;
pub const lz4DecodeConcatenatedFrameAppendLimited = lz4.decodeConcatenatedFrameAppendLimited;
pub const lz4DecodeConcatenatedFrameAllocLimited = lz4.decodeConcatenatedFrameAllocLimited;
pub const lz4DecodeConcatenatedFrameAllocExactSize = lz4.decodeConcatenatedFrameAllocExactSize;
pub const lz4DecodedConcatenatedFrameSize = lz4.decodedConcatenatedFrameSize;
pub const lz4DecodedConcatenatedFrameSizeLimited = lz4.decodedConcatenatedFrameSizeLimited;
pub const lz4DecodeConcatenatedFrameInto = lz4.decodeConcatenatedFrameInto;
pub const lz4DecodeConcatenatedFrameIntoExactSize = lz4.decodeConcatenatedFrameIntoExactSize;
pub const lz4DecodeConcatenatedFrameAllocWithDictionary = lz4.decodeConcatenatedFrameAllocWithDictionary;
pub const lz4DecodeConcatenatedFrameAppendWithDictionary = lz4.decodeConcatenatedFrameAppendWithDictionary;
pub const lz4DecodeConcatenatedFrameAppendExactSizeWithDictionary = lz4.decodeConcatenatedFrameAppendExactSizeWithDictionary;
pub const lz4DecodeConcatenatedFrameAppendLimitedWithDictionary = lz4.decodeConcatenatedFrameAppendLimitedWithDictionary;
pub const lz4DecodeConcatenatedFrameAllocLimitedWithDictionary = lz4.decodeConcatenatedFrameAllocLimitedWithDictionary;
pub const lz4DecodeConcatenatedFrameAllocWithDictionaryExactSize = lz4.decodeConcatenatedFrameAllocWithDictionaryExactSize;
pub const lz4DecodeConcatenatedFrameIntoWithDictionary = lz4.decodeConcatenatedFrameIntoWithDictionary;
pub const lz4DecodeConcatenatedFrameIntoWithDictionaryExactSize = lz4.decodeConcatenatedFrameIntoWithDictionaryExactSize;
pub const lz4DecodedConcatenatedFrameSizeWithDictionary = lz4.decodedConcatenatedFrameSizeWithDictionary;
pub const lz4DecodedConcatenatedFrameSizeLimitedWithDictionary = lz4.decodedConcatenatedFrameSizeLimitedWithDictionary;
pub const lz4DecodeConcatenatedFrameAllocWithDictionarySet = lz4.decodeConcatenatedFrameAllocWithDictionarySet;
pub const lz4DecodeConcatenatedFrameAppendWithDictionarySet = lz4.decodeConcatenatedFrameAppendWithDictionarySet;
pub const lz4DecodeConcatenatedFrameAppendExactSizeWithDictionarySet = lz4.decodeConcatenatedFrameAppendExactSizeWithDictionarySet;
pub const lz4DecodeConcatenatedFrameAppendLimitedWithDictionarySet = lz4.decodeConcatenatedFrameAppendLimitedWithDictionarySet;
pub const lz4DecodeConcatenatedFrameAllocLimitedWithDictionarySet = lz4.decodeConcatenatedFrameAllocLimitedWithDictionarySet;
pub const lz4DecodeConcatenatedFrameAllocWithDictionarySetExactSize = lz4.decodeConcatenatedFrameAllocWithDictionarySetExactSize;
pub const lz4DecodeConcatenatedFrameIntoWithDictionarySet = lz4.decodeConcatenatedFrameIntoWithDictionarySet;
pub const lz4DecodeConcatenatedFrameIntoWithDictionarySetExactSize = lz4.decodeConcatenatedFrameIntoWithDictionarySetExactSize;
pub const lz4DecodedConcatenatedFrameSizeWithDictionarySet = lz4.decodedConcatenatedFrameSizeWithDictionarySet;
pub const lz4DecodedConcatenatedFrameSizeLimitedWithDictionarySet = lz4.decodedConcatenatedFrameSizeLimitedWithDictionarySet;
pub const lz4DecodeConcatenatedFrameChunksAlloc = lz4.decodeConcatenatedFrameChunksAlloc;
pub const lz4DecodeConcatenatedFrameChunksAllocExactSize = lz4.decodeConcatenatedFrameChunksAllocExactSize;
pub const lz4DecodeConcatenatedFrameChunksAllocLimited = lz4.decodeConcatenatedFrameChunksAllocLimited;
pub const lz4DecodeConcatenatedFrameChunksAppend = lz4.decodeConcatenatedFrameChunksAppend;
pub const lz4DecodeConcatenatedFrameChunksAppendExactSize = lz4.decodeConcatenatedFrameChunksAppendExactSize;
pub const lz4DecodeConcatenatedFrameChunksAppendLimited = lz4.decodeConcatenatedFrameChunksAppendLimited;
pub const lz4DecodeConcatenatedFrameChunksInto = lz4.decodeConcatenatedFrameChunksInto;
pub const lz4DecodeConcatenatedFrameChunksIntoExactSize = lz4.decodeConcatenatedFrameChunksIntoExactSize;
pub const lz4DecodedConcatenatedFrameChunksSize = lz4.decodedConcatenatedFrameChunksSize;
pub const lz4DecodedConcatenatedFrameChunksSizeLimited = lz4.decodedConcatenatedFrameChunksSizeLimited;
pub const lz4DecodeConcatenatedFrameChunksAllocWithDictionary = lz4.decodeConcatenatedFrameChunksAllocWithDictionary;
pub const lz4DecodeConcatenatedFrameChunksAllocWithDictionaryExactSize = lz4.decodeConcatenatedFrameChunksAllocWithDictionaryExactSize;
pub const lz4DecodeConcatenatedFrameChunksAllocWithDictionaryLimited = lz4.decodeConcatenatedFrameChunksAllocWithDictionaryLimited;
pub const lz4DecodeConcatenatedFrameChunksAppendWithDictionary = lz4.decodeConcatenatedFrameChunksAppendWithDictionary;
pub const lz4DecodeConcatenatedFrameChunksAppendExactSizeWithDictionary = lz4.decodeConcatenatedFrameChunksAppendExactSizeWithDictionary;
pub const lz4DecodeConcatenatedFrameChunksAppendLimitedWithDictionary = lz4.decodeConcatenatedFrameChunksAppendLimitedWithDictionary;
pub const lz4DecodeConcatenatedFrameChunksIntoWithDictionary = lz4.decodeConcatenatedFrameChunksIntoWithDictionary;
pub const lz4DecodeConcatenatedFrameChunksIntoWithDictionaryExactSize = lz4.decodeConcatenatedFrameChunksIntoExactSizeWithDictionary;
pub const lz4DecodedConcatenatedFrameChunksSizeWithDictionary = lz4.decodedConcatenatedFrameChunksSizeWithDictionary;
pub const lz4DecodedConcatenatedFrameChunksSizeLimitedWithDictionary = lz4.decodedConcatenatedFrameChunksSizeLimitedWithDictionary;
pub const lz4DecodeConcatenatedFrameChunksAllocWithDictionarySet = lz4.decodeConcatenatedFrameChunksAllocWithDictionarySet;
pub const lz4DecodeConcatenatedFrameChunksAllocWithDictionarySetExactSize = lz4.decodeConcatenatedFrameChunksAllocWithDictionarySetExactSize;
pub const lz4DecodeConcatenatedFrameChunksAllocWithDictionarySetLimited = lz4.decodeConcatenatedFrameChunksAllocWithDictionarySetLimited;
pub const lz4DecodeConcatenatedFrameChunksAppendWithDictionarySet = lz4.decodeConcatenatedFrameChunksAppendWithDictionarySet;
pub const lz4DecodeConcatenatedFrameChunksAppendExactSizeWithDictionarySet = lz4.decodeConcatenatedFrameChunksAppendExactSizeWithDictionarySet;
pub const lz4DecodeConcatenatedFrameChunksAppendLimitedWithDictionarySet = lz4.decodeConcatenatedFrameChunksAppendLimitedWithDictionarySet;
pub const lz4DecodeConcatenatedFrameChunksIntoWithDictionarySet = lz4.decodeConcatenatedFrameChunksIntoWithDictionarySet;
pub const lz4DecodeConcatenatedFrameChunksIntoWithDictionarySetExactSize = lz4.decodeConcatenatedFrameChunksIntoExactSizeWithDictionarySet;
pub const lz4DecodedConcatenatedFrameChunksSizeWithDictionarySet = lz4.decodedConcatenatedFrameChunksSizeWithDictionarySet;
pub const lz4DecodedConcatenatedFrameChunksSizeLimitedWithDictionarySet = lz4.decodedConcatenatedFrameChunksSizeLimitedWithDictionarySet;
pub const lz4DecodeNativeConcatenatedFrameAlloc = lz4.decodeNativeConcatenatedFrameAlloc;
pub const lz4DecodeNativeConcatenatedFrameAppend = lz4.decodeNativeConcatenatedFrameAppend;
pub const lz4DecodeNativeConcatenatedFrameAppendExactSize = lz4.decodeNativeConcatenatedFrameAppendExactSize;
pub const lz4DecodeNativeConcatenatedFrameAppendLimited = lz4.decodeNativeConcatenatedFrameAppendLimited;
pub const lz4DecodeNativeConcatenatedFrameAllocLimited = lz4.decodeNativeConcatenatedFrameAllocLimited;
pub const lz4DecodeNativeConcatenatedFrameAllocExactSize = lz4.decodeNativeConcatenatedFrameAllocExactSize;
pub const lz4DecodeNativeConcatenatedFrameInto = lz4.decodeNativeConcatenatedFrameInto;
pub const lz4DecodeNativeConcatenatedFrameIntoExactSize = lz4.decodeNativeConcatenatedFrameIntoExactSize;
pub const lz4DecodedNativeConcatenatedFrameSize = lz4.decodedNativeConcatenatedFrameSize;
pub const lz4DecodedNativeConcatenatedFrameSizeLimited = lz4.decodedNativeConcatenatedFrameSizeLimited;
pub const lz4DecodeNativeConcatenatedFrameAllocWithDictionary = lz4.decodeNativeConcatenatedFrameAllocWithDictionary;
pub const lz4DecodeNativeConcatenatedFrameAppendWithDictionary = lz4.decodeNativeConcatenatedFrameAppendWithDictionary;
pub const lz4DecodeNativeConcatenatedFrameAppendExactSizeWithDictionary = lz4.decodeNativeConcatenatedFrameAppendExactSizeWithDictionary;
pub const lz4DecodeNativeConcatenatedFrameAppendLimitedWithDictionary = lz4.decodeNativeConcatenatedFrameAppendLimitedWithDictionary;
pub const lz4DecodeNativeConcatenatedFrameAllocLimitedWithDictionary = lz4.decodeNativeConcatenatedFrameAllocLimitedWithDictionary;
pub const lz4DecodeNativeConcatenatedFrameAllocWithDictionaryExactSize = lz4.decodeNativeConcatenatedFrameAllocWithDictionaryExactSize;
pub const lz4DecodeNativeConcatenatedFrameIntoWithDictionaryExactSize = lz4.decodeNativeConcatenatedFrameIntoWithDictionaryExactSize;
pub const lz4DecodeNativeConcatenatedFrameIntoWithDictionary = lz4.decodeNativeConcatenatedFrameIntoWithDictionary;
pub const lz4DecodedNativeConcatenatedFrameSizeWithDictionary = lz4.decodedNativeConcatenatedFrameSizeWithDictionary;
pub const lz4DecodedNativeConcatenatedFrameSizeLimitedWithDictionary = lz4.decodedNativeConcatenatedFrameSizeLimitedWithDictionary;
pub const lz4DecodeNativeConcatenatedFrameAllocWithDictionarySet = lz4.decodeNativeConcatenatedFrameAllocWithDictionarySet;
pub const lz4DecodeNativeConcatenatedFrameAppendWithDictionarySet = lz4.decodeNativeConcatenatedFrameAppendWithDictionarySet;
pub const lz4DecodeNativeConcatenatedFrameAppendExactSizeWithDictionarySet = lz4.decodeNativeConcatenatedFrameAppendExactSizeWithDictionarySet;
pub const lz4DecodeNativeConcatenatedFrameAppendLimitedWithDictionarySet = lz4.decodeNativeConcatenatedFrameAppendLimitedWithDictionarySet;
pub const lz4DecodeNativeConcatenatedFrameAllocLimitedWithDictionarySet = lz4.decodeNativeConcatenatedFrameAllocLimitedWithDictionarySet;
pub const lz4DecodeNativeConcatenatedFrameAllocWithDictionarySetExactSize = lz4.decodeNativeConcatenatedFrameAllocWithDictionarySetExactSize;
pub const lz4DecodeNativeConcatenatedFrameIntoWithDictionarySetExactSize = lz4.decodeNativeConcatenatedFrameIntoWithDictionarySetExactSize;
pub const lz4DecodeNativeConcatenatedFrameIntoWithDictionarySet = lz4.decodeNativeConcatenatedFrameIntoWithDictionarySet;
pub const lz4DecodedNativeConcatenatedFrameSizeWithDictionarySet = lz4.decodedNativeConcatenatedFrameSizeWithDictionarySet;
pub const lz4DecodedNativeConcatenatedFrameSizeLimitedWithDictionarySet = lz4.decodedNativeConcatenatedFrameSizeLimitedWithDictionarySet;
pub const lz4DecodeNativeConcatenatedFrameChunksAlloc = lz4.decodeNativeConcatenatedFrameChunksAlloc;
pub const lz4DecodeNativeConcatenatedFrameChunksAllocExactSize = lz4.decodeNativeConcatenatedFrameChunksAllocExactSize;
pub const lz4DecodeNativeConcatenatedFrameChunksAllocLimited = lz4.decodeNativeConcatenatedFrameChunksAllocLimited;
pub const lz4DecodeNativeConcatenatedFrameChunksAppend = lz4.decodeNativeConcatenatedFrameChunksAppend;
pub const lz4DecodeNativeConcatenatedFrameChunksAppendExactSize = lz4.decodeNativeConcatenatedFrameChunksAppendExactSize;
pub const lz4DecodeNativeConcatenatedFrameChunksAppendLimited = lz4.decodeNativeConcatenatedFrameChunksAppendLimited;
pub const lz4DecodeNativeConcatenatedFrameChunksInto = lz4.decodeNativeConcatenatedFrameChunksInto;
pub const lz4DecodeNativeConcatenatedFrameChunksIntoExactSize = lz4.decodeNativeConcatenatedFrameChunksIntoExactSize;
pub const lz4DecodedNativeConcatenatedFrameChunksSize = lz4.decodedNativeConcatenatedFrameChunksSize;
pub const lz4DecodedNativeConcatenatedFrameChunksSizeLimited = lz4.decodedNativeConcatenatedFrameChunksSizeLimited;
pub const lz4DecodeNativeConcatenatedFrameChunksAllocWithDictionary = lz4.decodeNativeConcatenatedFrameChunksAllocWithDictionary;
pub const lz4DecodeNativeConcatenatedFrameChunksAllocWithDictionaryExactSize = lz4.decodeNativeConcatenatedFrameChunksAllocWithDictionaryExactSize;
pub const lz4DecodeNativeConcatenatedFrameChunksAllocWithDictionaryLimited = lz4.decodeNativeConcatenatedFrameChunksAllocWithDictionaryLimited;
pub const lz4DecodeNativeConcatenatedFrameChunksAppendWithDictionary = lz4.decodeNativeConcatenatedFrameChunksAppendWithDictionary;
pub const lz4DecodeNativeConcatenatedFrameChunksAppendExactSizeWithDictionary = lz4.decodeNativeConcatenatedFrameChunksAppendExactSizeWithDictionary;
pub const lz4DecodeNativeConcatenatedFrameChunksAppendLimitedWithDictionary = lz4.decodeNativeConcatenatedFrameChunksAppendLimitedWithDictionary;
pub const lz4DecodeNativeConcatenatedFrameChunksIntoWithDictionary = lz4.decodeNativeConcatenatedFrameChunksIntoWithDictionary;
pub const lz4DecodeNativeConcatenatedFrameChunksIntoExactSizeWithDictionary = lz4.decodeNativeConcatenatedFrameChunksIntoExactSizeWithDictionary;
pub const lz4DecodeNativeConcatenatedFrameChunksIntoWithDictionaryExactSize = lz4.decodeNativeConcatenatedFrameChunksIntoWithDictionaryExactSize;
pub const lz4DecodedNativeConcatenatedFrameChunksSizeWithDictionary = lz4.decodedNativeConcatenatedFrameChunksSizeWithDictionary;
pub const lz4DecodedNativeConcatenatedFrameChunksSizeLimitedWithDictionary = lz4.decodedNativeConcatenatedFrameChunksSizeLimitedWithDictionary;
pub const lz4DecodeNativeConcatenatedFrameChunksAllocWithDictionarySet = lz4.decodeNativeConcatenatedFrameChunksAllocWithDictionarySet;
pub const lz4DecodeNativeConcatenatedFrameChunksAllocWithDictionarySetExactSize = lz4.decodeNativeConcatenatedFrameChunksAllocWithDictionarySetExactSize;
pub const lz4DecodeNativeConcatenatedFrameChunksAllocWithDictionarySetLimited = lz4.decodeNativeConcatenatedFrameChunksAllocWithDictionarySetLimited;
pub const lz4DecodeNativeConcatenatedFrameChunksAppendWithDictionarySet = lz4.decodeNativeConcatenatedFrameChunksAppendWithDictionarySet;
pub const lz4DecodeNativeConcatenatedFrameChunksAppendExactSizeWithDictionarySet = lz4.decodeNativeConcatenatedFrameChunksAppendExactSizeWithDictionarySet;
pub const lz4DecodeNativeConcatenatedFrameChunksAppendLimitedWithDictionarySet = lz4.decodeNativeConcatenatedFrameChunksAppendLimitedWithDictionarySet;
pub const lz4DecodeNativeConcatenatedFrameChunksIntoWithDictionarySet = lz4.decodeNativeConcatenatedFrameChunksIntoWithDictionarySet;
pub const lz4DecodeNativeConcatenatedFrameChunksIntoExactSizeWithDictionarySet = lz4.decodeNativeConcatenatedFrameChunksIntoExactSizeWithDictionarySet;
pub const lz4DecodeNativeConcatenatedFrameChunksIntoWithDictionarySetExactSize = lz4.decodeNativeConcatenatedFrameChunksIntoWithDictionarySetExactSize;
pub const lz4DecodedNativeConcatenatedFrameChunksSizeWithDictionarySet = lz4.decodedNativeConcatenatedFrameChunksSizeWithDictionarySet;
pub const lz4DecodedNativeConcatenatedFrameChunksSizeLimitedWithDictionarySet = lz4.decodedNativeConcatenatedFrameChunksSizeLimitedWithDictionarySet;
pub const lz4EncodedNativeFrameBound = lz4.encodedNativeFrameBound;
pub const lz4EncodedNativeFrameBoundWithOptions = lz4.encodedNativeFrameBoundWithOptions;
pub const lz4EncodedNativeFrameBoundWithDictionary = lz4.encodedNativeFrameBoundWithDictionary;
pub const lz4EncodedNativeFrameBoundWithDictionarySet = lz4.encodedNativeFrameBoundWithDictionarySet;
pub const lz4EncodeNativeFrameWithDictionaryAlloc = lz4.encodeNativeFrameWithDictionaryAlloc;
pub const lz4EncodeNativeFrameWithDictionarySetAlloc = lz4.encodeNativeFrameWithDictionarySetAlloc;
pub const lz4EncodeNativeFrameAppendWithDictionary = lz4.encodeNativeFrameAppendWithDictionary;
pub const lz4EncodeNativeFrameAppendWithDictionarySet = lz4.encodeNativeFrameAppendWithDictionarySet;
pub const lz4EncodeNativeFrameIntoSliceWithDictionary = lz4.encodeNativeFrameIntoSliceWithDictionary;
pub const lz4EncodeNativeFrameIntoSliceWithDictionarySet = lz4.encodeNativeFrameIntoSliceWithDictionarySet;
pub const lz4EncodeBlockAlloc = lz4.encodeBlockAlloc;
pub const lz4EncodeBlockWithChainDepthAlloc = lz4.encodeBlockWithChainDepthAlloc;
pub const lz4EncodeBlockWithPrefixAlloc = lz4.encodeBlockWithPrefixAlloc;
pub const lz4EncodeBlockWithPrefixAndChainDepthAlloc = lz4.encodeBlockWithPrefixAndChainDepthAlloc;
pub const lz4EncodeBlockIntoSlice = lz4.encodeBlockIntoSlice;
pub const lz4EncodeBlockIntoSliceWithChainDepth = lz4.encodeBlockIntoSliceWithChainDepth;
pub const lz4EncodeBlockWithPrefixIntoSlice = lz4.encodeBlockWithPrefixIntoSlice;
pub const lz4EncodeBlockWithPrefixIntoSliceAndChainDepth = lz4.encodeBlockWithPrefixIntoSliceAndChainDepth;
pub const lz4DecodeBlockAlloc = lz4.decodeBlockAlloc;
pub const lz4DecodeBlockWithPrefixAlloc = lz4.decodeBlockWithPrefixAlloc;
pub const lz4DecodeBlockAppend = lz4.decodeBlockAppend;
pub const lz4DecodeBlockAppendLimited = lz4.decodeBlockAppendLimited;
pub const lz4DecodeBlockWithPrefixAppend = lz4.decodeBlockWithPrefixAppend;
pub const lz4DecodeBlockWithPrefixAppendLimited = lz4.decodeBlockWithPrefixAppendLimited;
pub const lz4DecodeBlockIntoSlice = lz4.decodeBlockIntoSlice;
pub const lz4DecodeBlockWithPrefixIntoSlice = lz4.decodeBlockWithPrefixIntoSlice;
pub const lz4DecodeBlockWithPrefixIntoSliceNoAlloc = lz4.decodeBlockWithPrefixIntoSliceNoAlloc;
pub const lz4DecodedBlockSize = lz4.decodedBlockSize;
pub const lz4DecodedBlockSizeLimited = lz4.decodedBlockSizeLimited;
pub const lz4DecodedBlockSizeWithPrefix = lz4.decodedBlockSizeWithPrefix;
pub const lz4DecodedBlockSizeWithPrefixLimited = lz4.decodedBlockSizeWithPrefixLimited;
pub const lz4SummarizeBlock = lz4.summarizeBlock;
pub const lz4SummarizeBlockLimited = lz4.summarizeBlockLimited;
pub const lz4SummarizeBlockWithPrefix = lz4.summarizeBlockWithPrefix;
pub const lz4SummarizeBlockWithPrefixLimited = lz4.summarizeBlockWithPrefixLimited;
pub const lz4EncodedBlockBound = lz4.encodedBlockBound;

pub const ZstdError = zstd.Error;
pub const zstdDefaultCompressionLevel = zstd.default_compression_level;
pub const zstdMinCompressionLevel = zstd.min_compression_level;
pub const zstdMaxCompressionLevel = zstd.max_compression_level;
pub const zstdEncodeFrameAlloc = zstd.encodeFrameAlloc;
pub const zstdEncodeFrameWithLevelAlloc = zstd.encodeFrameWithLevelAlloc;
pub const zstdEncodeFrameWithOptionsAlloc = zstd.encodeFrameWithOptionsAlloc;
pub const zstdEncodeFrameWithLevelAndOptionsAlloc = zstd.encodeFrameWithLevelAndOptionsAlloc;
pub const zstdEncodedFrameBound = zstd.encodedFrameBound;
pub const zstdEncodedFrameBoundWithLevel = zstd.encodedFrameBoundWithLevel;
pub const zstdEncodedFrameBoundWithOptions = zstd.encodedFrameBoundWithOptions;
pub const zstdEncodedFrameBoundWithLevelAndOptions = zstd.encodedFrameBoundWithLevelAndOptions;
pub const zstdEncodeFrameAppend = zstd.encodeFrameAppend;
pub const zstdEncodeFrameAppendWithLevel = zstd.encodeFrameAppendWithLevel;
pub const zstdEncodeFrameAppendWithOptions = zstd.encodeFrameAppendWithOptions;
pub const zstdEncodeFrameAppendWithLevelAndOptions = zstd.encodeFrameAppendWithLevelAndOptions;
pub const zstdEncodeFrameIntoSlice = zstd.encodeFrameIntoSlice;
pub const zstdEncodeFrameIntoSliceWithLevel = zstd.encodeFrameIntoSliceWithLevel;
pub const zstdEncodeFrameIntoSliceWithOptions = zstd.encodeFrameIntoSliceWithOptions;
pub const zstdEncodeFrameIntoSliceWithLevelAndOptions = zstd.encodeFrameIntoSliceWithLevelAndOptions;
pub const zstdEncodedFrameBoundWithDictionary = zstd.encodedFrameBoundWithDictionary;
pub const zstdEncodedFrameBoundWithOptionsAndDictionary = zstd.encodedFrameBoundWithOptionsAndDictionary;
pub const zstdEncodedFrameBoundWithLevelAndOptionsAndDictionary = zstd.encodedFrameBoundWithLevelAndOptionsAndDictionary;
pub const zstdEncodeFrameWithDictionaryAlloc = zstd.encodeFrameWithDictionaryAlloc;
pub const zstdEncodeFrameWithOptionsAndDictionaryAlloc = zstd.encodeFrameWithOptionsAndDictionaryAlloc;
pub const zstdEncodeFrameWithLevelAndOptionsAndDictionaryAlloc = zstd.encodeFrameWithLevelAndOptionsAndDictionaryAlloc;
pub const zstdEncodeFrameAppendWithDictionary = zstd.encodeFrameAppendWithDictionary;
pub const zstdEncodeFrameAppendWithOptionsAndDictionary = zstd.encodeFrameAppendWithOptionsAndDictionary;
pub const zstdEncodeFrameAppendWithLevelAndOptionsAndDictionary = zstd.encodeFrameAppendWithLevelAndOptionsAndDictionary;
pub const zstdEncodeFrameIntoSliceWithDictionary = zstd.encodeFrameIntoSliceWithDictionary;
pub const zstdEncodeFrameIntoSliceWithOptionsAndDictionary = zstd.encodeFrameIntoSliceWithOptionsAndDictionary;
pub const zstdEncodeFrameIntoSliceWithLevelAndOptionsAndDictionary = zstd.encodeFrameIntoSliceWithLevelAndOptionsAndDictionary;
pub const zstdEncodedFrameBoundWithDictionarySet = zstd.encodedFrameBoundWithDictionarySet;
pub const zstdEncodedFrameBoundWithOptionsAndDictionarySet = zstd.encodedFrameBoundWithOptionsAndDictionarySet;
pub const zstdEncodedFrameBoundWithLevelAndOptionsAndDictionarySet = zstd.encodedFrameBoundWithLevelAndOptionsAndDictionarySet;
pub const zstdEncodeFrameWithDictionarySetAlloc = zstd.encodeFrameWithDictionarySetAlloc;
pub const zstdEncodeFrameWithOptionsAndDictionarySetAlloc = zstd.encodeFrameWithOptionsAndDictionarySetAlloc;
pub const zstdEncodeFrameWithLevelAndOptionsAndDictionarySetAlloc = zstd.encodeFrameWithLevelAndOptionsAndDictionarySetAlloc;
pub const zstdEncodeFrameAppendWithDictionarySet = zstd.encodeFrameAppendWithDictionarySet;
pub const zstdEncodeFrameAppendWithOptionsAndDictionarySet = zstd.encodeFrameAppendWithOptionsAndDictionarySet;
pub const zstdEncodeFrameAppendWithLevelAndOptionsAndDictionarySet = zstd.encodeFrameAppendWithLevelAndOptionsAndDictionarySet;
pub const zstdEncodeFrameIntoSliceWithDictionarySet = zstd.encodeFrameIntoSliceWithDictionarySet;
pub const zstdEncodeFrameIntoSliceWithOptionsAndDictionarySet = zstd.encodeFrameIntoSliceWithOptionsAndDictionarySet;
pub const zstdEncodeFrameIntoSliceWithLevelAndOptionsAndDictionarySet = zstd.encodeFrameIntoSliceWithLevelAndOptionsAndDictionarySet;
pub const zstdDecodeFrameAlloc = zstd.decodeFrameAlloc;
pub const zstdDecodeFrameAllocExactSize = zstd.decodeFrameAllocExactSize;
pub const zstdDecodeFrameAllocLimited = zstd.decodeFrameAllocLimited;
pub const zstdDecodeFrameAppend = zstd.decodeFrameAppend;
pub const zstdDecodeFrameAppendExactSize = zstd.decodeFrameAppendExactSize;
pub const zstdDecodeFrameAppendLimited = zstd.decodeFrameAppendLimited;
pub const zstdDecodeFrameInto = zstd.decodeFrameInto;
pub const zstdDecodeFrameIntoLimited = zstd.decodeFrameIntoLimited;
pub const zstdDecodeFrameIntoExactSize = zstd.decodeFrameIntoExactSize;
pub const zstdDecodedFrameSize = zstd.decodedFrameSize;
pub const zstdDecodedFrameSizeLimited = zstd.decodedFrameSizeLimited;
pub const zstdDecodeFrameChunksAlloc = zstd.decodeFrameChunksAlloc;
pub const zstdDecodeFrameChunksAllocExactSize = zstd.decodeFrameChunksAllocExactSize;
pub const zstdDecodeFrameChunksAllocLimited = zstd.decodeFrameChunksAllocLimited;
pub const zstdDecodeFrameChunksAppend = zstd.decodeFrameChunksAppend;
pub const zstdDecodeFrameChunksAppendExactSize = zstd.decodeFrameChunksAppendExactSize;
pub const zstdDecodeFrameChunksAppendLimited = zstd.decodeFrameChunksAppendLimited;
pub const zstdDecodeFrameChunksInto = zstd.decodeFrameChunksInto;
pub const zstdDecodeFrameChunksIntoLimited = zstd.decodeFrameChunksIntoLimited;
pub const zstdDecodeFrameChunksIntoExactSize = zstd.decodeFrameChunksIntoExactSize;
pub const zstdDecodedFrameChunksSize = zstd.decodedFrameChunksSize;
pub const zstdDecodedFrameChunksSizeLimited = zstd.decodedFrameChunksSizeLimited;
pub const zstdDecodeFrameChunksAllocWithDictionary = zstd.decodeFrameChunksAllocWithDictionary;
pub const zstdDecodeFrameChunksAllocWithDictionaryExactSize = zstd.decodeFrameChunksAllocWithDictionaryExactSize;
pub const zstdDecodeFrameChunksAllocWithDictionaryLimited = zstd.decodeFrameChunksAllocWithDictionaryLimited;
pub const zstdDecodeFrameChunksAppendWithDictionary = zstd.decodeFrameChunksAppendWithDictionary;
pub const zstdDecodeFrameChunksAppendExactSizeWithDictionary = zstd.decodeFrameChunksAppendExactSizeWithDictionary;
pub const zstdDecodeFrameChunksAppendLimitedWithDictionary = zstd.decodeFrameChunksAppendLimitedWithDictionary;
pub const zstdDecodeFrameChunksIntoWithDictionary = zstd.decodeFrameChunksIntoWithDictionary;
pub const zstdDecodeFrameChunksIntoWithDictionaryLimited = zstd.decodeFrameChunksIntoWithDictionaryLimited;
pub const zstdDecodeFrameChunksIntoWithDictionaryExactSize = zstd.decodeFrameChunksIntoWithDictionaryExactSize;
pub const zstdDecodedFrameChunksSizeWithDictionary = zstd.decodedFrameChunksSizeWithDictionary;
pub const zstdDecodedFrameChunksSizeLimitedWithDictionary = zstd.decodedFrameChunksSizeLimitedWithDictionary;
pub const zstdDecodeFrameChunksAllocWithDictionarySet = zstd.decodeFrameChunksAllocWithDictionarySet;
pub const zstdDecodeFrameChunksAllocWithDictionarySetExactSize = zstd.decodeFrameChunksAllocWithDictionarySetExactSize;
pub const zstdDecodeFrameChunksAllocWithDictionarySetLimited = zstd.decodeFrameChunksAllocWithDictionarySetLimited;
pub const zstdDecodeFrameChunksAppendWithDictionarySet = zstd.decodeFrameChunksAppendWithDictionarySet;
pub const zstdDecodeFrameChunksAppendExactSizeWithDictionarySet = zstd.decodeFrameChunksAppendExactSizeWithDictionarySet;
pub const zstdDecodeFrameChunksAppendLimitedWithDictionarySet = zstd.decodeFrameChunksAppendLimitedWithDictionarySet;
pub const zstdDecodeFrameChunksIntoWithDictionarySet = zstd.decodeFrameChunksIntoWithDictionarySet;
pub const zstdDecodeFrameChunksIntoWithDictionarySetLimited = zstd.decodeFrameChunksIntoWithDictionarySetLimited;
pub const zstdDecodeFrameChunksIntoWithDictionarySetExactSize = zstd.decodeFrameChunksIntoWithDictionarySetExactSize;
pub const zstdDecodedFrameChunksSizeWithDictionarySet = zstd.decodedFrameChunksSizeWithDictionarySet;
pub const zstdDecodedFrameChunksSizeLimitedWithDictionarySet = zstd.decodedFrameChunksSizeLimitedWithDictionarySet;
pub const zstdDecodeFrameAllocWithDictionary = zstd.decodeFrameAllocWithDictionary;
pub const zstdDecodeFrameAllocWithDictionaryExactSize = zstd.decodeFrameAllocWithDictionaryExactSize;
pub const zstdDecodeFrameAllocWithDictionaryLimited = zstd.decodeFrameAllocWithDictionaryLimited;
pub const zstdDecodeFrameAppendWithDictionary = zstd.decodeFrameAppendWithDictionary;
pub const zstdDecodeFrameAppendExactSizeWithDictionary = zstd.decodeFrameAppendExactSizeWithDictionary;
pub const zstdDecodeFrameAppendLimitedWithDictionary = zstd.decodeFrameAppendLimitedWithDictionary;
pub const zstdDecodeFrameIntoWithDictionary = zstd.decodeFrameIntoWithDictionary;
pub const zstdDecodeFrameIntoWithDictionaryLimited = zstd.decodeFrameIntoWithDictionaryLimited;
pub const zstdDecodeFrameIntoWithDictionaryExactSize = zstd.decodeFrameIntoWithDictionaryExactSize;
pub const zstdDecodedFrameSizeWithDictionary = zstd.decodedFrameSizeWithDictionary;
pub const zstdDecodedFrameSizeLimitedWithDictionary = zstd.decodedFrameSizeLimitedWithDictionary;
pub const zstdDecodeFrameAllocWithDictionarySet = zstd.decodeFrameAllocWithDictionarySet;
pub const zstdDecodeFrameAllocWithDictionarySetExactSize = zstd.decodeFrameAllocWithDictionarySetExactSize;
pub const zstdDecodeFrameAllocWithDictionarySetLimited = zstd.decodeFrameAllocWithDictionarySetLimited;
pub const zstdDecodeFrameAppendWithDictionarySet = zstd.decodeFrameAppendWithDictionarySet;
pub const zstdDecodeFrameAppendExactSizeWithDictionarySet = zstd.decodeFrameAppendExactSizeWithDictionarySet;
pub const zstdDecodeFrameAppendLimitedWithDictionarySet = zstd.decodeFrameAppendLimitedWithDictionarySet;
pub const zstdDecodeFrameIntoWithDictionarySet = zstd.decodeFrameIntoWithDictionarySet;
pub const zstdDecodeFrameIntoWithDictionarySetLimited = zstd.decodeFrameIntoWithDictionarySetLimited;
pub const zstdDecodeFrameIntoWithDictionarySetExactSize = zstd.decodeFrameIntoWithDictionarySetExactSize;
pub const zstdDecodedFrameSizeWithDictionarySet = zstd.decodedFrameSizeWithDictionarySet;
pub const zstdDecodedFrameSizeLimitedWithDictionarySet = zstd.decodedFrameSizeLimitedWithDictionarySet;
pub const zstdDecodeConcatenatedFrameAlloc = zstd.decodeConcatenatedFrameAlloc;
pub const zstdDecodeConcatenatedFrameAllocExactSize = zstd.decodeConcatenatedFrameAllocExactSize;
pub const zstdDecodeConcatenatedFrameAllocLimited = zstd.decodeConcatenatedFrameAllocLimited;
pub const zstdDecodeConcatenatedFrameAppend = zstd.decodeConcatenatedFrameAppend;
pub const zstdDecodeConcatenatedFrameAppendExactSize = zstd.decodeConcatenatedFrameAppendExactSize;
pub const zstdDecodeConcatenatedFrameAppendLimited = zstd.decodeConcatenatedFrameAppendLimited;
pub const zstdDecodeConcatenatedFrameInto = zstd.decodeConcatenatedFrameInto;
pub const zstdDecodeConcatenatedFrameIntoLimited = zstd.decodeConcatenatedFrameIntoLimited;
pub const zstdDecodeConcatenatedFrameIntoExactSize = zstd.decodeConcatenatedFrameIntoExactSize;
pub const zstdDecodedConcatenatedFrameSize = zstd.decodedConcatenatedFrameSize;
pub const zstdDecodedConcatenatedFrameSizeLimited = zstd.decodedConcatenatedFrameSizeLimited;
pub const zstdDecodeConcatenatedFrameAllocWithDictionary = zstd.decodeConcatenatedFrameAllocWithDictionary;
pub const zstdDecodeConcatenatedFrameAllocWithDictionaryExactSize = zstd.decodeConcatenatedFrameAllocWithDictionaryExactSize;
pub const zstdDecodeConcatenatedFrameAllocLimitedWithDictionary = zstd.decodeConcatenatedFrameAllocLimitedWithDictionary;
pub const zstdDecodeConcatenatedFrameAppendWithDictionary = zstd.decodeConcatenatedFrameAppendWithDictionary;
pub const zstdDecodeConcatenatedFrameAppendExactSizeWithDictionary = zstd.decodeConcatenatedFrameAppendExactSizeWithDictionary;
pub const zstdDecodeConcatenatedFrameAppendLimitedWithDictionary = zstd.decodeConcatenatedFrameAppendLimitedWithDictionary;
pub const zstdDecodeConcatenatedFrameIntoWithDictionary = zstd.decodeConcatenatedFrameIntoWithDictionary;
pub const zstdDecodeConcatenatedFrameIntoWithDictionaryLimited = zstd.decodeConcatenatedFrameIntoWithDictionaryLimited;
pub const zstdDecodeConcatenatedFrameIntoWithDictionaryExactSize = zstd.decodeConcatenatedFrameIntoWithDictionaryExactSize;
pub const zstdDecodedConcatenatedFrameSizeWithDictionary = zstd.decodedConcatenatedFrameSizeWithDictionary;
pub const zstdDecodedConcatenatedFrameSizeLimitedWithDictionary = zstd.decodedConcatenatedFrameSizeLimitedWithDictionary;
pub const zstdDecodeConcatenatedFrameAllocWithDictionarySet = zstd.decodeConcatenatedFrameAllocWithDictionarySet;
pub const zstdDecodeConcatenatedFrameAllocWithDictionarySetExactSize = zstd.decodeConcatenatedFrameAllocWithDictionarySetExactSize;
pub const zstdDecodeConcatenatedFrameAllocLimitedWithDictionarySet = zstd.decodeConcatenatedFrameAllocLimitedWithDictionarySet;
pub const zstdDecodeConcatenatedFrameAppendWithDictionarySet = zstd.decodeConcatenatedFrameAppendWithDictionarySet;
pub const zstdDecodeConcatenatedFrameAppendExactSizeWithDictionarySet = zstd.decodeConcatenatedFrameAppendExactSizeWithDictionarySet;
pub const zstdDecodeConcatenatedFrameAppendLimitedWithDictionarySet = zstd.decodeConcatenatedFrameAppendLimitedWithDictionarySet;
pub const zstdDecodeConcatenatedFrameIntoWithDictionarySet = zstd.decodeConcatenatedFrameIntoWithDictionarySet;
pub const zstdDecodeConcatenatedFrameIntoWithDictionarySetLimited = zstd.decodeConcatenatedFrameIntoWithDictionarySetLimited;
pub const zstdDecodeConcatenatedFrameIntoWithDictionarySetExactSize = zstd.decodeConcatenatedFrameIntoWithDictionarySetExactSize;
pub const zstdDecodedConcatenatedFrameSizeWithDictionarySet = zstd.decodedConcatenatedFrameSizeWithDictionarySet;
pub const zstdDecodedConcatenatedFrameSizeLimitedWithDictionarySet = zstd.decodedConcatenatedFrameSizeLimitedWithDictionarySet;
pub const zstdDecodeConcatenatedFrameChunksAlloc = zstd.decodeConcatenatedFrameChunksAlloc;
pub const zstdDecodeConcatenatedFrameChunksAllocExactSize = zstd.decodeConcatenatedFrameChunksAllocExactSize;
pub const zstdDecodeConcatenatedFrameChunksAllocLimited = zstd.decodeConcatenatedFrameChunksAllocLimited;
pub const zstdDecodeConcatenatedFrameChunksAppend = zstd.decodeConcatenatedFrameChunksAppend;
pub const zstdDecodeConcatenatedFrameChunksAppendExactSize = zstd.decodeConcatenatedFrameChunksAppendExactSize;
pub const zstdDecodeConcatenatedFrameChunksAppendLimited = zstd.decodeConcatenatedFrameChunksAppendLimited;
pub const zstdDecodeConcatenatedFrameChunksInto = zstd.decodeConcatenatedFrameChunksInto;
pub const zstdDecodeConcatenatedFrameChunksIntoLimited = zstd.decodeConcatenatedFrameChunksIntoLimited;
pub const zstdDecodeConcatenatedFrameChunksIntoExactSize = zstd.decodeConcatenatedFrameChunksIntoExactSize;
pub const zstdDecodedConcatenatedFrameChunksSize = zstd.decodedConcatenatedFrameChunksSize;
pub const zstdDecodedConcatenatedFrameChunksSizeLimited = zstd.decodedConcatenatedFrameChunksSizeLimited;
pub const zstdDecodeConcatenatedFrameChunksAllocWithDictionary = zstd.decodeConcatenatedFrameChunksAllocWithDictionary;
pub const zstdDecodeConcatenatedFrameChunksAllocWithDictionaryExactSize = zstd.decodeConcatenatedFrameChunksAllocWithDictionaryExactSize;
pub const zstdDecodeConcatenatedFrameChunksAllocWithDictionaryLimited = zstd.decodeConcatenatedFrameChunksAllocWithDictionaryLimited;
pub const zstdDecodeConcatenatedFrameChunksAppendWithDictionary = zstd.decodeConcatenatedFrameChunksAppendWithDictionary;
pub const zstdDecodeConcatenatedFrameChunksAppendExactSizeWithDictionary = zstd.decodeConcatenatedFrameChunksAppendExactSizeWithDictionary;
pub const zstdDecodeConcatenatedFrameChunksAppendLimitedWithDictionary = zstd.decodeConcatenatedFrameChunksAppendLimitedWithDictionary;
pub const zstdDecodeConcatenatedFrameChunksIntoWithDictionary = zstd.decodeConcatenatedFrameChunksIntoWithDictionary;
pub const zstdDecodeConcatenatedFrameChunksIntoWithDictionaryLimited = zstd.decodeConcatenatedFrameChunksIntoWithDictionaryLimited;
pub const zstdDecodeConcatenatedFrameChunksIntoWithDictionaryExactSize = zstd.decodeConcatenatedFrameChunksIntoWithDictionaryExactSize;
pub const zstdDecodedConcatenatedFrameChunksSizeWithDictionary = zstd.decodedConcatenatedFrameChunksSizeWithDictionary;
pub const zstdDecodedConcatenatedFrameChunksSizeLimitedWithDictionary = zstd.decodedConcatenatedFrameChunksSizeLimitedWithDictionary;
pub const zstdDecodeConcatenatedFrameChunksAllocWithDictionarySet = zstd.decodeConcatenatedFrameChunksAllocWithDictionarySet;
pub const zstdDecodeConcatenatedFrameChunksAllocWithDictionarySetExactSize = zstd.decodeConcatenatedFrameChunksAllocWithDictionarySetExactSize;
pub const zstdDecodeConcatenatedFrameChunksAllocWithDictionarySetLimited = zstd.decodeConcatenatedFrameChunksAllocWithDictionarySetLimited;
pub const zstdDecodeConcatenatedFrameChunksAppendWithDictionarySet = zstd.decodeConcatenatedFrameChunksAppendWithDictionarySet;
pub const zstdDecodeConcatenatedFrameChunksAppendExactSizeWithDictionarySet = zstd.decodeConcatenatedFrameChunksAppendExactSizeWithDictionarySet;
pub const zstdDecodeConcatenatedFrameChunksAppendLimitedWithDictionarySet = zstd.decodeConcatenatedFrameChunksAppendLimitedWithDictionarySet;
pub const zstdDecodeConcatenatedFrameChunksIntoWithDictionarySet = zstd.decodeConcatenatedFrameChunksIntoWithDictionarySet;
pub const zstdDecodeConcatenatedFrameChunksIntoWithDictionarySetLimited = zstd.decodeConcatenatedFrameChunksIntoWithDictionarySetLimited;
pub const zstdDecodeConcatenatedFrameChunksIntoWithDictionarySetExactSize = zstd.decodeConcatenatedFrameChunksIntoWithDictionarySetExactSize;
pub const zstdDecodedConcatenatedFrameChunksSizeWithDictionarySet = zstd.decodedConcatenatedFrameChunksSizeWithDictionarySet;
pub const zstdDecodedConcatenatedFrameChunksSizeLimitedWithDictionarySet = zstd.decodedConcatenatedFrameChunksSizeLimitedWithDictionarySet;
pub const zstdEncodedFrameBoundWithAdvancedOptions = zstd.encodedFrameBoundWithAdvancedOptions;
pub const zstdEncodedFrameBoundWithAdvancedOptionsAndDictionary = zstd.encodedFrameBoundWithAdvancedOptionsAndDictionary;
pub const zstdEncodedFrameBoundWithAdvancedOptionsAndDictionarySet = zstd.encodedFrameBoundWithAdvancedOptionsAndDictionarySet;
pub const zstdEncodeFrameWithAdvancedOptionsAlloc = zstd.encodeFrameWithAdvancedOptionsAlloc;
pub const zstdEncodeFrameWithAdvancedOptionsAndDictionaryAlloc = zstd.encodeFrameWithAdvancedOptionsAndDictionaryAlloc;
pub const zstdEncodeFrameWithAdvancedOptionsAndDictionarySetAlloc = zstd.encodeFrameWithAdvancedOptionsAndDictionarySetAlloc;
pub const zstdEncodeFrameAppendWithAdvancedOptions = zstd.encodeFrameAppendWithAdvancedOptions;
pub const zstdEncodeFrameAppendWithAdvancedOptionsAndDictionary = zstd.encodeFrameAppendWithAdvancedOptionsAndDictionary;
pub const zstdEncodeFrameAppendWithAdvancedOptionsAndDictionarySet = zstd.encodeFrameAppendWithAdvancedOptionsAndDictionarySet;
pub const zstdEncodeFrameIntoSliceWithAdvancedOptions = zstd.encodeFrameIntoSliceWithAdvancedOptions;
pub const zstdEncodeFrameIntoSliceWithAdvancedOptionsAndDictionary = zstd.encodeFrameIntoSliceWithAdvancedOptionsAndDictionary;
pub const zstdEncodeFrameIntoSliceWithAdvancedOptionsAndDictionarySet = zstd.encodeFrameIntoSliceWithAdvancedOptionsAndDictionarySet;
pub const ZstdFrameOptions = zstd.FrameOptions;
pub const ZstdFrameSelection = zstd.FrameSelection;
pub const ZstdAdvancedFrameOptions = zstd.AdvancedFrameOptions;
pub const ZstdFrameMode = zstd.FrameMode;
pub const ZstdFrameEncodeResult = zstd.FrameEncodeResult;
pub const ZstdFrameEncodeIntoResult = zstd.FrameEncodeIntoResult;
pub const ZstdFrameEncodeScratchResult = zstd.FrameEncodeScratchResult;
pub const ZstdFrameEncoder = zstd.FrameEncoder;
pub const ZstdSeekableStreamEncoder = zstd.SeekableStreamEncoder;
pub const ZstdFrameDecoder = zstd.FrameDecoder;
pub const ZstdIncrementalFrameDecoder = zstd.IncrementalFrameDecoder;
pub const ZstdDictionary = zstd.Dictionary;
pub const ZstdDictionaryKind = zstd.DictionaryKind;
pub const ZstdDictionaryTrainOptions = zstd.DictionaryTrainOptions;
pub const ZstdOwnedDictionary = zstd.OwnedDictionary;
pub const ZstdDictionarySet = zstd.DictionarySet;
pub const ZstdOwnedDictionarySet = zstd.OwnedDictionarySet;
pub const ZstdStandardDictionaryView = zstd.StandardDictionaryView;
pub const ZstdStandardDictionaryEntropySummary = zstd.StandardDictionaryEntropySummary;
pub const ZstdStandardDictionaryNativeView = zstd.StandardDictionaryNativeView;
pub const ZstdOwnedStandardDictionary = zstd.OwnedStandardDictionary;
pub const zstdInspectStandardDictionary = zstd.inspectStandardDictionary;
pub const zstdIsStandardDictionary = zstd.isStandardDictionary;
pub const zstdStandardDictionaryId = zstd.standardDictionaryId;
pub const zstdSummarizeStandardDictionary = zstd.summarizeStandardDictionary;
pub const zstdStandardDictionaryHeaderLen = zstd.standard_dictionary_header_len;
pub const zstdStandardDictionaryFromContentBound = zstd.standardDictionaryFromContentBound;
pub const zstdStandardDictionaryFromContentInto = zstd.standardDictionaryFromContentInto;
pub const zstdStandardDictionaryFromContentAlloc = zstd.standardDictionaryFromContentAlloc;
pub const zstdTrainStandardDictionaryAlloc = zstd.trainStandardDictionaryAlloc;
pub const zstdTrainValidatedStandardDictionaryAlloc = zstd.trainValidatedStandardDictionaryAlloc;
pub const zstdTrainDictionaryAlloc = zstd.trainDictionaryAlloc;
pub const zstdDictionarySetFromMetadataAlloc = zstd.dictionarySetFromMetadataAlloc;
pub const zstdEncodeRawOrRleFrameAlloc = zstd.encodeRawOrRleFrameAlloc;
pub const zstdEncodeRawOrRleFrameWithOptionsAlloc = zstd.encodeRawOrRleFrameWithOptionsAlloc;
pub const zstdEncodeRawOrRleFrameAppend = zstd.encodeRawOrRleFrameAppend;
pub const zstdEncodeRawOrRleFrameIntoSlice = zstd.encodeRawOrRleFrameIntoSlice;
pub const zstdEncodeLiteralOnlyFrameAlloc = zstd.encodeLiteralOnlyFrameAlloc;
pub const zstdEncodeLiteralOnlyFrameWithOptionsAlloc = zstd.encodeLiteralOnlyFrameWithOptionsAlloc;
pub const zstdEncodeLiteralOnlyFrameAppend = zstd.encodeLiteralOnlyFrameAppend;
pub const zstdEncodeLiteralOnlyFrameIntoSlice = zstd.encodeLiteralOnlyFrameIntoSlice;
pub const zstdEncodedSkippableFrameBound = zstd.encodedSkippableFrameBound;
pub const zstdEncodeSkippableFrameAlloc = zstd.encodeSkippableFrameAlloc;
pub const zstdEncodeSkippableFrameAppend = zstd.encodeSkippableFrameAppend;
pub const zstdEncodeSkippableFrameIntoSlice = zstd.encodeSkippableFrameIntoSlice;
pub const ZstdNativeFrameOptions = zstd.NativeFrameOptions;
pub const zstdNativeMaxMatchSearchBudget = zstd.native_max_match_search_budget;
pub const zstdNativeMaxDirectHuffmanSymbol = zstd.native_max_direct_huffman_symbol;
pub const zstdNativeDictionaryWindowLen = zstd.native_dictionary_window_len;
pub const ZstdNativeFrameSelection = zstd.NativeFrameSelection;
pub const ZstdNativeFrameMode = zstd.NativeFrameMode;
pub const ZstdNativeFrameEncodeResult = zstd.NativeFrameEncodeResult;
pub const ZstdNativeFrameEncodeIntoResult = zstd.NativeFrameEncodeIntoResult;
pub const ZstdNativeFrameEncodeScratchResult = zstd.NativeFrameEncodeScratchResult;
pub const ZstdNativeFrameEncoder = zstd.NativeFrameEncoder;
pub const ZstdLevelFrameEncoder = zstd.LevelFrameEncoder;
pub const ZstdNativeIncrementalFrameEncoder = zstd.NativeIncrementalFrameEncoder;

test "root Zstd incremental encoder continues frames" {
    var encoder = try ZstdNativeIncrementalFrameEncoder.initExactSize(std.testing.allocator, .{ .include_content_size = true }, 3);
    defer encoder.deinit();
    var output: [128]u8 = undefined;
    _ = try encoder.step("one", &output);
    encoder.finish();
    while ((try encoder.step("", &output)).status != .done) {}
    try encoder.nextFrameExactSize(.{ .include_content_size = true }, 3);
    try std.testing.expectEqual(@as(usize, 1), encoder.snapshot().frame_index);
}
pub const ZstdNativeFrameDecoder = zstd.NativeFrameDecoder;
pub const ZstdNativeIncrementalFrameDecoder = zstd.NativeIncrementalFrameDecoder;
pub const ZstdNativeDictionary = zstd.NativeDictionary;
pub const ZstdNativeDictionaryTrainOptions = zstd.NativeDictionaryTrainOptions;
pub const ZstdOwnedNativeDictionary = zstd.OwnedNativeDictionary;
pub const ZstdNativeDictionarySet = zstd.NativeDictionarySet;
pub const ZstdOwnedNativeDictionarySet = zstd.OwnedNativeDictionarySet;
pub const zstdTrainNativeDictionaryAlloc = zstd.trainNativeDictionaryAlloc;
pub const zstdNativeDictionarySetFromMetadataAlloc = zstd.nativeDictionarySetFromMetadataAlloc;
pub const ZstdNativeFrameHeader = zstd.NativeFrameHeader;
pub const ZstdNativeFrameBlockHeader = zstd.NativeFrameBlockHeader;
pub const ZstdNativeFrameBlockSummary = zstd.NativeFrameBlockSummary;
pub const ZstdNativeLiteralsKind = zstd.NativeLiteralsKind;
pub const ZstdNativeSequenceTableMode = zstd.NativeSequenceTableMode;
pub const ZstdNativeSequenceModeSummary = zstd.NativeSequenceModeSummary;
pub const ZstdNativeStreamSummary = zstd.NativeStreamSummary;
pub const ZstdNativeStreamSummaryErrorDiagnostics = zstd.NativeStreamSummaryErrorDiagnostics;
pub const ZstdNativeStreamSummaryErrorPhase = zstd.NativeStreamSummaryErrorPhase;
pub const ZstdNativeSkippableFrameHeader = zstd.NativeSkippableFrameHeader;
pub const ZstdNativeSeekTable = zstd.NativeSeekTable;
pub const ZstdNativeSeekTableEntry = zstd.NativeSeekTableEntry;
pub const ZstdNativeSeekTableIterator = zstd.NativeSeekTableIterator;
pub const ZstdNativeSeekTableFrameSize = zstd.NativeSeekTableFrameSize;
pub const ZstdNativeSeekIndex = zstd.NativeSeekIndex;
pub const ZstdNativeSeekableOptions = zstd.NativeSeekableOptions;
pub const ZstdNativeSeekableStreamEncoder = zstd.NativeSeekableStreamEncoder;
pub const zstdNativeSeekableParallelWorkersMax = zstd.native_seekable_parallel_workers_max;
pub const ZstdNativeFrameBlockIterator = zstd.NativeFrameBlockIterator;
pub const ZstdNativeStreamFrame = zstd.NativeStreamFrame;
pub const ZstdNativeStreamSkippableFrame = zstd.NativeStreamSkippableFrame;
pub const ZstdNativeStreamElement = zstd.NativeStreamElement;
pub const ZstdNativeStreamIterator = zstd.NativeStreamIterator;
pub const ZstdNativeBlockType = zstd.NativeBlockType;
pub const zstdInspectNativeFrameHeader = zstd.inspectNativeFrameHeader;
pub const zstdInspectNativeFrameFirstBlock = zstd.inspectNativeFrameFirstBlock;
pub const zstdInspectNativeFrameBlockAt = zstd.inspectNativeFrameBlockAt;
pub const zstdInspectNativeFrameBlockSequenceModes = zstd.inspectNativeFrameBlockSequenceModes;
pub const zstdInspectNativeFrameBlockSequenceModesWithDictionary = zstd.inspectNativeFrameBlockSequenceModesWithDictionary;
pub const zstdInspectNativeFrameBlockSequenceModesWithDictionarySet = zstd.inspectNativeFrameBlockSequenceModesWithDictionarySet;
pub const zstdSummarizeNativeFrameBlocks = zstd.summarizeNativeFrameBlocks;
pub const zstdSummarizeNativeStream = zstd.summarizeNativeStream;
pub const zstdSummarizeNativeStreamWithDiagnostics = zstd.summarizeNativeStreamWithDiagnostics;
pub const zstdSummarizeNativeStreamWithDictionarySet = zstd.summarizeNativeStreamWithDictionarySet;
pub const zstdSummarizeNativeStreamWithDictionary = zstd.summarizeNativeStreamWithDictionary;
pub const zstdSummarizeNativeStreamWithDictionaryDiagnostics = zstd.summarizeNativeStreamWithDictionaryDiagnostics;
pub const zstdSummarizeNativeStreamWithDictionarySetAndDiagnostics = zstd.summarizeNativeStreamWithDictionarySetAndDiagnostics;
pub const zstdInspectNativeSkippableFrame = zstd.inspectNativeSkippableFrame;
pub const zstdInspectNativeSeekTable = zstd.inspectNativeSeekTable;
pub const zstdNativeSeekTableFrameIndexForOffset = zstd.nativeSeekTableFrameIndexForOffset;
pub const zstdBuildNativeSeekIndex = zstd.buildNativeSeekIndex;
pub const zstdEncodedNativeSeekTableBound = zstd.encodedNativeSeekTableBound;
pub const zstdEncodeNativeSeekTableAlloc = zstd.encodeNativeSeekTableAlloc;
pub const zstdEncodeNativeSeekTableAppend = zstd.encodeNativeSeekTableAppend;
pub const zstdEncodeNativeSeekTableInto = zstd.encodeNativeSeekTableInto;
pub const zstdEncodedNativeSeekableStreamBound = zstd.encodedNativeSeekableStreamBound;
pub const zstdEncodedNativeSeekableStreamBoundWithDictionary = zstd.encodedNativeSeekableStreamBoundWithDictionary;
pub const zstdEncodedNativeSeekableStreamBoundWithDictionarySet = zstd.encodedNativeSeekableStreamBoundWithDictionarySet;
pub const zstdEncodeNativeSeekableStreamAlloc = zstd.encodeNativeSeekableStreamAlloc;
pub const zstdEncodeNativeSeekableStreamParallelAlloc = zstd.encodeNativeSeekableStreamParallelAlloc;
pub const zstdEncodeNativeSeekableStreamAppend = zstd.encodeNativeSeekableStreamAppend;
pub const zstdEncodeNativeSeekableStreamIntoSlice = zstd.encodeNativeSeekableStreamIntoSlice;
pub const zstdEncodeNativeSeekableStreamWithDictionaryAlloc = zstd.encodeNativeSeekableStreamWithDictionaryAlloc;
pub const zstdEncodeNativeSeekableStreamParallelWithDictionaryAlloc = zstd.encodeNativeSeekableStreamParallelWithDictionaryAlloc;
pub const zstdEncodeNativeSeekableStreamAppendWithDictionary = zstd.encodeNativeSeekableStreamAppendWithDictionary;
pub const zstdEncodeNativeSeekableStreamIntoSliceWithDictionary = zstd.encodeNativeSeekableStreamIntoSliceWithDictionary;
pub const zstdEncodeNativeSeekableStreamWithDictionarySetAlloc = zstd.encodeNativeSeekableStreamWithDictionarySetAlloc;
pub const zstdEncodeNativeSeekableStreamParallelWithDictionarySetAlloc = zstd.encodeNativeSeekableStreamParallelWithDictionarySetAlloc;
pub const zstdEncodeNativeSeekableStreamAppendWithDictionarySet = zstd.encodeNativeSeekableStreamAppendWithDictionarySet;
pub const zstdEncodeNativeSeekableStreamIntoSliceWithDictionarySet = zstd.encodeNativeSeekableStreamIntoSliceWithDictionarySet;
pub const zstdNativeSeekableRangeScratchLen = zstd.nativeSeekableRangeScratchLen;
pub const zstdNativeSeekableRangeScratchLenWithIndex = zstd.nativeSeekableRangeScratchLenWithIndex;
pub const zstdDecodeNativeSeekableRangeInto = zstd.decodeNativeSeekableRangeInto;
pub const zstdDecodeNativeSeekableRangeAlloc = zstd.decodeNativeSeekableRangeAlloc;
pub const zstdDecodeNativeSeekableRangeIntoWithDictionary = zstd.decodeNativeSeekableRangeIntoWithDictionary;
pub const zstdDecodeNativeSeekableRangeAllocWithDictionary = zstd.decodeNativeSeekableRangeAllocWithDictionary;
pub const zstdDecodeNativeSeekableRangeIntoWithDictionarySet = zstd.decodeNativeSeekableRangeIntoWithDictionarySet;
pub const zstdDecodeNativeSeekableRangeAllocWithDictionarySet = zstd.decodeNativeSeekableRangeAllocWithDictionarySet;
pub const zstdDecodeNativeSeekableRangeIntoWithIndex = zstd.decodeNativeSeekableRangeIntoWithIndex;
pub const zstdDecodeNativeSeekableRangeAllocWithIndex = zstd.decodeNativeSeekableRangeAllocWithIndex;
pub const zstdDecodeNativeSeekableRangeIntoWithIndexAndDictionary = zstd.decodeNativeSeekableRangeIntoWithIndexAndDictionary;
pub const zstdDecodeNativeSeekableRangeAllocWithIndexAndDictionary = zstd.decodeNativeSeekableRangeAllocWithIndexAndDictionary;
pub const zstdDecodeNativeSeekableRangeIntoWithIndexAndDictionarySet = zstd.decodeNativeSeekableRangeIntoWithIndexAndDictionarySet;
pub const zstdDecodeNativeSeekableRangeAllocWithIndexAndDictionarySet = zstd.decodeNativeSeekableRangeAllocWithIndexAndDictionarySet;
pub const zstdIterateNativeFrameBlocks = zstd.iterateNativeFrameBlocks;
pub const zstdIterateNativeStream = zstd.iterateNativeStream;
pub const zstdEncodedNativeFrameBound = zstd.encodedNativeFrameBound;
pub const zstdEncodedNativeFrameBoundWithOptions = zstd.encodedNativeFrameBoundWithOptions;
pub const zstdEncodedNativeFrameBoundWithDictionary = zstd.encodedNativeFrameBoundWithDictionary;
pub const zstdEncodedNativeFrameBoundWithDictionarySet = zstd.encodedNativeFrameBoundWithDictionarySet;
pub const zstdEncodeNativeFrameWithOptionsAlloc = zstd.encodeNativeFrameWithOptionsAlloc;
pub const zstdEncodeNativeFrameWithDictionaryAlloc = zstd.encodeNativeFrameWithDictionaryAlloc;
pub const zstdEncodeNativeFrameWithDictionarySetAlloc = zstd.encodeNativeFrameWithDictionarySetAlloc;
pub const zstdEncodeNativeFrameAppend = zstd.encodeNativeFrameAppend;
pub const zstdEncodeNativeFrameAppendWithDictionary = zstd.encodeNativeFrameAppendWithDictionary;
pub const zstdEncodeNativeFrameAppendWithDictionarySet = zstd.encodeNativeFrameAppendWithDictionarySet;
pub const zstdEncodeNativeFrameIntoSlice = zstd.encodeNativeFrameIntoSlice;
pub const zstdEncodeNativeFrameIntoSliceWithDictionary = zstd.encodeNativeFrameIntoSliceWithDictionary;
pub const zstdEncodeNativeFrameIntoSliceWithDictionarySet = zstd.encodeNativeFrameIntoSliceWithDictionarySet;
pub const zstdDecodeRawOrRleFrameAlloc = zstd.decodeRawOrRleFrameAlloc;
pub const zstdDecodeRawOrRleFrameAppend = zstd.decodeRawOrRleFrameAppend;
pub const zstdDecodeRawOrRleFrameAppendExactSize = zstd.decodeRawOrRleFrameAppendExactSize;
pub const zstdDecodeRawOrRleFrameAppendLimited = zstd.decodeRawOrRleFrameAppendLimited;
pub const zstdDecodeRawOrRleFrameAllocLimited = zstd.decodeRawOrRleFrameAllocLimited;
pub const zstdDecodeRawOrRleFrameAllocExactSize = zstd.decodeRawOrRleFrameAllocExactSize;
pub const zstdDecodedRawOrRleFrameSize = zstd.decodedRawOrRleFrameSize;
pub const zstdDecodedRawOrRleFrameSizeLimited = zstd.decodedRawOrRleFrameSizeLimited;
pub const zstdDecodeRawOrRleFrameInto = zstd.decodeRawOrRleFrameInto;
pub const zstdDecodeRawOrRleFrameIntoLimited = zstd.decodeRawOrRleFrameIntoLimited;
pub const zstdDecodeRawOrRleFrameIntoExactSize = zstd.decodeRawOrRleFrameIntoExactSize;
pub const zstdDecodeRawOrRleFrameAllocWithDictionary = zstd.decodeRawOrRleFrameAllocWithDictionary;
pub const zstdDecodeRawOrRleFrameAppendWithDictionary = zstd.decodeRawOrRleFrameAppendWithDictionary;
pub const zstdDecodeRawOrRleFrameAppendExactSizeWithDictionary = zstd.decodeRawOrRleFrameAppendExactSizeWithDictionary;
pub const zstdDecodeRawOrRleFrameAppendLimitedWithDictionary = zstd.decodeRawOrRleFrameAppendLimitedWithDictionary;
pub const zstdDecodeRawOrRleFrameAllocLimitedWithDictionary = zstd.decodeRawOrRleFrameAllocLimitedWithDictionary;
pub const zstdDecodeRawOrRleFrameAllocWithDictionaryExactSize = zstd.decodeRawOrRleFrameAllocWithDictionaryExactSize;
pub const zstdDecodedRawOrRleFrameSizeWithDictionary = zstd.decodedRawOrRleFrameSizeWithDictionary;
pub const zstdDecodedRawOrRleFrameSizeLimitedWithDictionary = zstd.decodedRawOrRleFrameSizeLimitedWithDictionary;
pub const zstdDecodeRawOrRleFrameIntoWithDictionary = zstd.decodeRawOrRleFrameIntoWithDictionary;
pub const zstdDecodeRawOrRleFrameIntoWithDictionaryLimited = zstd.decodeRawOrRleFrameIntoWithDictionaryLimited;
pub const zstdDecodeRawOrRleFrameIntoWithDictionaryExactSize = zstd.decodeRawOrRleFrameIntoWithDictionaryExactSize;
pub const zstdDecodeRawOrRleFrameAllocWithDictionarySet = zstd.decodeRawOrRleFrameAllocWithDictionarySet;
pub const zstdDecodeRawOrRleFrameAppendWithDictionarySet = zstd.decodeRawOrRleFrameAppendWithDictionarySet;
pub const zstdDecodeRawOrRleFrameAppendExactSizeWithDictionarySet = zstd.decodeRawOrRleFrameAppendExactSizeWithDictionarySet;
pub const zstdDecodeRawOrRleFrameAppendLimitedWithDictionarySet = zstd.decodeRawOrRleFrameAppendLimitedWithDictionarySet;
pub const zstdDecodeRawOrRleFrameAllocLimitedWithDictionarySet = zstd.decodeRawOrRleFrameAllocLimitedWithDictionarySet;
pub const zstdDecodeRawOrRleFrameAllocWithDictionarySetExactSize = zstd.decodeRawOrRleFrameAllocWithDictionarySetExactSize;
pub const zstdDecodedRawOrRleFrameSizeWithDictionarySet = zstd.decodedRawOrRleFrameSizeWithDictionarySet;
pub const zstdDecodedRawOrRleFrameSizeLimitedWithDictionarySet = zstd.decodedRawOrRleFrameSizeLimitedWithDictionarySet;
pub const zstdDecodeRawOrRleFrameIntoWithDictionarySet = zstd.decodeRawOrRleFrameIntoWithDictionarySet;
pub const zstdDecodeRawOrRleFrameIntoWithDictionarySetLimited = zstd.decodeRawOrRleFrameIntoWithDictionarySetLimited;
pub const zstdDecodeRawOrRleFrameIntoWithDictionarySetExactSize = zstd.decodeRawOrRleFrameIntoWithDictionarySetExactSize;
pub const zstdDecodeRawOrRleFrameChunksAlloc = zstd.decodeRawOrRleFrameChunksAlloc;
pub const zstdDecodeRawOrRleFrameChunksAllocExactSize = zstd.decodeRawOrRleFrameChunksAllocExactSize;
pub const zstdDecodeRawOrRleFrameChunksAllocLimited = zstd.decodeRawOrRleFrameChunksAllocLimited;
pub const zstdDecodeRawOrRleFrameChunksAppend = zstd.decodeRawOrRleFrameChunksAppend;
pub const zstdDecodeRawOrRleFrameChunksAppendExactSize = zstd.decodeRawOrRleFrameChunksAppendExactSize;
pub const zstdDecodeRawOrRleFrameChunksAppendLimited = zstd.decodeRawOrRleFrameChunksAppendLimited;
pub const zstdDecodeRawOrRleFrameChunksInto = zstd.decodeRawOrRleFrameChunksInto;
pub const zstdDecodeRawOrRleFrameChunksIntoLimited = zstd.decodeRawOrRleFrameChunksIntoLimited;
pub const zstdDecodeRawOrRleFrameChunksIntoExactSize = zstd.decodeRawOrRleFrameChunksIntoExactSize;
pub const zstdDecodedRawOrRleFrameChunksSize = zstd.decodedRawOrRleFrameChunksSize;
pub const zstdDecodedRawOrRleFrameChunksSizeLimited = zstd.decodedRawOrRleFrameChunksSizeLimited;
pub const zstdDecodeRawOrRleFrameChunksAllocWithDictionary = zstd.decodeRawOrRleFrameChunksAllocWithDictionary;
pub const zstdDecodeRawOrRleFrameChunksAllocWithDictionaryExactSize = zstd.decodeRawOrRleFrameChunksAllocWithDictionaryExactSize;
pub const zstdDecodeRawOrRleFrameChunksAllocWithDictionaryLimited = zstd.decodeRawOrRleFrameChunksAllocWithDictionaryLimited;
pub const zstdDecodeRawOrRleFrameChunksAppendWithDictionary = zstd.decodeRawOrRleFrameChunksAppendWithDictionary;
pub const zstdDecodeRawOrRleFrameChunksAppendExactSizeWithDictionary = zstd.decodeRawOrRleFrameChunksAppendExactSizeWithDictionary;
pub const zstdDecodeRawOrRleFrameChunksAppendLimitedWithDictionary = zstd.decodeRawOrRleFrameChunksAppendLimitedWithDictionary;
pub const zstdDecodeRawOrRleFrameChunksIntoWithDictionary = zstd.decodeRawOrRleFrameChunksIntoWithDictionary;
pub const zstdDecodeRawOrRleFrameChunksIntoWithDictionaryLimited = zstd.decodeRawOrRleFrameChunksIntoWithDictionaryLimited;
pub const zstdDecodeRawOrRleFrameChunksIntoWithDictionaryExactSize = zstd.decodeRawOrRleFrameChunksIntoExactSizeWithDictionary;
pub const zstdDecodedRawOrRleFrameChunksSizeWithDictionary = zstd.decodedRawOrRleFrameChunksSizeWithDictionary;
pub const zstdDecodedRawOrRleFrameChunksSizeLimitedWithDictionary = zstd.decodedRawOrRleFrameChunksSizeLimitedWithDictionary;
pub const zstdDecodeRawOrRleFrameChunksAllocWithDictionarySet = zstd.decodeRawOrRleFrameChunksAllocWithDictionarySet;
pub const zstdDecodeRawOrRleFrameChunksAllocWithDictionarySetExactSize = zstd.decodeRawOrRleFrameChunksAllocWithDictionarySetExactSize;
pub const zstdDecodeRawOrRleFrameChunksAllocWithDictionarySetLimited = zstd.decodeRawOrRleFrameChunksAllocWithDictionarySetLimited;
pub const zstdDecodeRawOrRleFrameChunksAppendWithDictionarySet = zstd.decodeRawOrRleFrameChunksAppendWithDictionarySet;
pub const zstdDecodeRawOrRleFrameChunksAppendExactSizeWithDictionarySet = zstd.decodeRawOrRleFrameChunksAppendExactSizeWithDictionarySet;
pub const zstdDecodeRawOrRleFrameChunksAppendLimitedWithDictionarySet = zstd.decodeRawOrRleFrameChunksAppendLimitedWithDictionarySet;
pub const zstdDecodeRawOrRleFrameChunksIntoWithDictionarySet = zstd.decodeRawOrRleFrameChunksIntoWithDictionarySet;
pub const zstdDecodeRawOrRleFrameChunksIntoWithDictionarySetLimited = zstd.decodeRawOrRleFrameChunksIntoWithDictionarySetLimited;
pub const zstdDecodeRawOrRleFrameChunksIntoWithDictionarySetExactSize = zstd.decodeRawOrRleFrameChunksIntoExactSizeWithDictionarySet;
pub const zstdDecodedRawOrRleFrameChunksSizeWithDictionarySet = zstd.decodedRawOrRleFrameChunksSizeWithDictionarySet;
pub const zstdDecodedRawOrRleFrameChunksSizeLimitedWithDictionarySet = zstd.decodedRawOrRleFrameChunksSizeLimitedWithDictionarySet;
pub const zstdEncodeNativeFrameAlloc = zstd.encodeNativeFrameAlloc;
pub const zstdDecodeNativeFrameAlloc = zstd.decodeNativeFrameAlloc;
pub const zstdDecodeNativeFrameAppend = zstd.decodeNativeFrameAppend;
pub const zstdDecodeNativeFrameAppendLimited = zstd.decodeNativeFrameAppendLimited;
pub const zstdDecodeNativeFrameAllocLimited = zstd.decodeNativeFrameAllocLimited;
pub const zstdDecodeNativeFrameAllocExactSize = zstd.decodeNativeFrameAllocExactSize;
pub const zstdDecodeNativeFrameInto = zstd.decodeNativeFrameInto;
pub const zstdDecodeNativeFrameIntoLimited = zstd.decodeNativeFrameIntoLimited;
pub const zstdDecodeNativeFrameIntoExactSize = zstd.decodeNativeFrameIntoExactSize;
pub const zstdDecodeNativeFrameAppendExactSize = zstd.decodeNativeFrameAppendExactSize;
pub const zstdDecodeNativeFrameChunksAlloc = zstd.decodeNativeFrameChunksAlloc;
pub const zstdDecodeNativeFrameChunksAllocExactSize = zstd.decodeNativeFrameChunksAllocExactSize;
pub const zstdDecodeNativeFrameChunksAllocLimited = zstd.decodeNativeFrameChunksAllocLimited;
pub const zstdDecodeNativeFrameChunksAppend = zstd.decodeNativeFrameChunksAppend;
pub const zstdDecodeNativeFrameChunksAppendExactSize = zstd.decodeNativeFrameChunksAppendExactSize;
pub const zstdDecodeNativeFrameChunksAppendLimited = zstd.decodeNativeFrameChunksAppendLimited;
pub const zstdDecodeNativeFrameChunksInto = zstd.decodeNativeFrameChunksInto;
pub const zstdDecodeNativeFrameChunksIntoLimited = zstd.decodeNativeFrameChunksIntoLimited;
pub const zstdDecodeNativeFrameChunksIntoExactSize = zstd.decodeNativeFrameChunksIntoExactSize;
pub const zstdDecodedNativeFrameChunksSize = zstd.decodedNativeFrameChunksSize;
pub const zstdDecodedNativeFrameChunksSizeLimited = zstd.decodedNativeFrameChunksSizeLimited;
pub const zstdDecodeNativeFrameChunksAllocWithDictionary = zstd.decodeNativeFrameChunksAllocWithDictionary;
pub const zstdDecodeNativeFrameChunksAllocWithDictionaryExactSize = zstd.decodeNativeFrameChunksAllocWithDictionaryExactSize;
pub const zstdDecodeNativeFrameChunksAllocWithDictionaryLimited = zstd.decodeNativeFrameChunksAllocWithDictionaryLimited;
pub const zstdDecodeNativeFrameChunksAppendWithDictionary = zstd.decodeNativeFrameChunksAppendWithDictionary;
pub const zstdDecodeNativeFrameChunksAppendExactSizeWithDictionary = zstd.decodeNativeFrameChunksAppendExactSizeWithDictionary;
pub const zstdDecodeNativeFrameChunksAppendLimitedWithDictionary = zstd.decodeNativeFrameChunksAppendLimitedWithDictionary;
pub const zstdDecodeNativeFrameChunksIntoWithDictionary = zstd.decodeNativeFrameChunksIntoWithDictionary;
pub const zstdDecodeNativeFrameChunksIntoWithDictionaryLimited = zstd.decodeNativeFrameChunksIntoWithDictionaryLimited;
pub const zstdDecodeNativeFrameChunksIntoExactSizeWithDictionary = zstd.decodeNativeFrameChunksIntoExactSizeWithDictionary;
pub const zstdDecodeNativeFrameChunksIntoWithDictionaryExactSize = zstd.decodeNativeFrameChunksIntoWithDictionaryExactSize;
pub const zstdDecodedNativeFrameChunksSizeWithDictionary = zstd.decodedNativeFrameChunksSizeWithDictionary;
pub const zstdDecodedNativeFrameChunksSizeLimitedWithDictionary = zstd.decodedNativeFrameChunksSizeLimitedWithDictionary;
pub const zstdDecodeNativeFrameChunksAllocWithDictionarySet = zstd.decodeNativeFrameChunksAllocWithDictionarySet;
pub const zstdDecodeNativeFrameChunksAllocWithDictionarySetExactSize = zstd.decodeNativeFrameChunksAllocWithDictionarySetExactSize;
pub const zstdDecodeNativeFrameChunksAllocWithDictionarySetLimited = zstd.decodeNativeFrameChunksAllocWithDictionarySetLimited;
pub const zstdDecodeNativeFrameChunksAppendWithDictionarySet = zstd.decodeNativeFrameChunksAppendWithDictionarySet;
pub const zstdDecodeNativeFrameChunksAppendExactSizeWithDictionarySet = zstd.decodeNativeFrameChunksAppendExactSizeWithDictionarySet;
pub const zstdDecodeNativeFrameChunksAppendLimitedWithDictionarySet = zstd.decodeNativeFrameChunksAppendLimitedWithDictionarySet;
pub const zstdDecodeNativeFrameChunksIntoWithDictionarySet = zstd.decodeNativeFrameChunksIntoWithDictionarySet;
pub const zstdDecodeNativeFrameChunksIntoWithDictionarySetLimited = zstd.decodeNativeFrameChunksIntoWithDictionarySetLimited;
pub const zstdDecodeNativeFrameChunksIntoExactSizeWithDictionarySet = zstd.decodeNativeFrameChunksIntoExactSizeWithDictionarySet;
pub const zstdDecodeNativeFrameChunksIntoWithDictionarySetExactSize = zstd.decodeNativeFrameChunksIntoWithDictionarySetExactSize;
pub const zstdDecodedNativeFrameChunksSizeWithDictionarySet = zstd.decodedNativeFrameChunksSizeWithDictionarySet;
pub const zstdDecodedNativeFrameChunksSizeLimitedWithDictionarySet = zstd.decodedNativeFrameChunksSizeLimitedWithDictionarySet;
pub const zstdDecodeNativeFrameAllocWithDictionary = zstd.decodeNativeFrameAllocWithDictionary;
pub const zstdDecodeNativeFrameAppendWithDictionary = zstd.decodeNativeFrameAppendWithDictionary;
pub const zstdDecodeNativeFrameAppendExactSizeWithDictionary = zstd.decodeNativeFrameAppendExactSizeWithDictionary;
pub const zstdDecodeNativeFrameAppendLimitedWithDictionary = zstd.decodeNativeFrameAppendLimitedWithDictionary;
pub const zstdDecodeNativeFrameAllocLimitedWithDictionary = zstd.decodeNativeFrameAllocLimitedWithDictionary;
pub const zstdDecodeNativeFrameAllocWithDictionaryExactSize = zstd.decodeNativeFrameAllocWithDictionaryExactSize;
pub const zstdDecodeNativeFrameIntoWithDictionary = zstd.decodeNativeFrameIntoWithDictionary;
pub const zstdDecodeNativeFrameIntoWithDictionaryLimited = zstd.decodeNativeFrameIntoWithDictionaryLimited;
pub const zstdDecodeNativeFrameIntoWithDictionaryExactSize = zstd.decodeNativeFrameIntoWithDictionaryExactSize;
pub const zstdDecodeNativeFrameAllocWithDictionarySet = zstd.decodeNativeFrameAllocWithDictionarySet;
pub const zstdDecodeNativeFrameAppendWithDictionarySet = zstd.decodeNativeFrameAppendWithDictionarySet;
pub const zstdDecodeNativeFrameAppendExactSizeWithDictionarySet = zstd.decodeNativeFrameAppendExactSizeWithDictionarySet;
pub const zstdDecodeNativeFrameAppendLimitedWithDictionarySet = zstd.decodeNativeFrameAppendLimitedWithDictionarySet;
pub const zstdDecodeNativeFrameAllocLimitedWithDictionarySet = zstd.decodeNativeFrameAllocLimitedWithDictionarySet;
pub const zstdDecodeNativeFrameAllocWithDictionarySetExactSize = zstd.decodeNativeFrameAllocWithDictionarySetExactSize;
pub const zstdDecodeNativeFrameIntoWithDictionarySet = zstd.decodeNativeFrameIntoWithDictionarySet;
pub const zstdDecodeNativeFrameIntoWithDictionarySetLimited = zstd.decodeNativeFrameIntoWithDictionarySetLimited;
pub const zstdDecodeNativeFrameIntoWithDictionarySetExactSize = zstd.decodeNativeFrameIntoWithDictionarySetExactSize;
pub const zstdDecodeNativeConcatenatedFrameAlloc = zstd.decodeNativeConcatenatedFrameAlloc;
pub const zstdDecodeNativeConcatenatedFrameAppend = zstd.decodeNativeConcatenatedFrameAppend;
pub const zstdDecodeNativeConcatenatedFrameAppendExactSize = zstd.decodeNativeConcatenatedFrameAppendExactSize;
pub const zstdDecodeNativeConcatenatedFrameAppendLimited = zstd.decodeNativeConcatenatedFrameAppendLimited;
pub const zstdDecodeNativeConcatenatedFrameAllocLimited = zstd.decodeNativeConcatenatedFrameAllocLimited;
pub const zstdDecodeNativeConcatenatedFrameAllocExactSize = zstd.decodeNativeConcatenatedFrameAllocExactSize;
pub const zstdDecodeNativeConcatenatedFrameInto = zstd.decodeNativeConcatenatedFrameInto;
pub const zstdDecodeNativeConcatenatedFrameIntoLimited = zstd.decodeNativeConcatenatedFrameIntoLimited;
pub const zstdDecodeNativeConcatenatedFrameIntoExactSize = zstd.decodeNativeConcatenatedFrameIntoExactSize;
pub const zstdDecodeNativeConcatenatedFrameAllocWithDictionary = zstd.decodeNativeConcatenatedFrameAllocWithDictionary;
pub const zstdDecodeNativeConcatenatedFrameAppendWithDictionary = zstd.decodeNativeConcatenatedFrameAppendWithDictionary;
pub const zstdDecodeNativeConcatenatedFrameAppendExactSizeWithDictionary = zstd.decodeNativeConcatenatedFrameAppendExactSizeWithDictionary;
pub const zstdDecodeNativeConcatenatedFrameAppendLimitedWithDictionary = zstd.decodeNativeConcatenatedFrameAppendLimitedWithDictionary;
pub const zstdDecodeNativeConcatenatedFrameAllocLimitedWithDictionary = zstd.decodeNativeConcatenatedFrameAllocLimitedWithDictionary;
pub const zstdDecodeNativeConcatenatedFrameAllocWithDictionaryExactSize = zstd.decodeNativeConcatenatedFrameAllocWithDictionaryExactSize;
pub const zstdDecodeNativeConcatenatedFrameIntoWithDictionaryExactSize = zstd.decodeNativeConcatenatedFrameIntoWithDictionaryExactSize;
pub const zstdDecodeNativeConcatenatedFrameIntoWithDictionary = zstd.decodeNativeConcatenatedFrameIntoWithDictionary;
pub const zstdDecodeNativeConcatenatedFrameIntoWithDictionaryLimited = zstd.decodeNativeConcatenatedFrameIntoWithDictionaryLimited;
pub const zstdDecodeNativeConcatenatedFrameAllocWithDictionarySet = zstd.decodeNativeConcatenatedFrameAllocWithDictionarySet;
pub const zstdDecodeNativeConcatenatedFrameAppendWithDictionarySet = zstd.decodeNativeConcatenatedFrameAppendWithDictionarySet;
pub const zstdDecodeNativeConcatenatedFrameAppendExactSizeWithDictionarySet = zstd.decodeNativeConcatenatedFrameAppendExactSizeWithDictionarySet;
pub const zstdDecodeNativeConcatenatedFrameAppendLimitedWithDictionarySet = zstd.decodeNativeConcatenatedFrameAppendLimitedWithDictionarySet;
pub const zstdDecodeNativeConcatenatedFrameAllocLimitedWithDictionarySet = zstd.decodeNativeConcatenatedFrameAllocLimitedWithDictionarySet;
pub const zstdDecodeNativeConcatenatedFrameAllocWithDictionarySetExactSize = zstd.decodeNativeConcatenatedFrameAllocWithDictionarySetExactSize;
pub const zstdDecodeNativeConcatenatedFrameIntoWithDictionarySetExactSize = zstd.decodeNativeConcatenatedFrameIntoWithDictionarySetExactSize;
pub const zstdDecodeNativeConcatenatedFrameIntoWithDictionarySet = zstd.decodeNativeConcatenatedFrameIntoWithDictionarySet;
pub const zstdDecodeNativeConcatenatedFrameIntoWithDictionarySetLimited = zstd.decodeNativeConcatenatedFrameIntoWithDictionarySetLimited;
pub const zstdDecodedNativeFrameSize = zstd.decodedNativeFrameSize;
pub const zstdDecodedNativeFrameSizeLimited = zstd.decodedNativeFrameSizeLimited;
pub const zstdDecodedNativeFrameSizeWithDictionary = zstd.decodedNativeFrameSizeWithDictionary;
pub const zstdDecodedNativeFrameSizeLimitedWithDictionary = zstd.decodedNativeFrameSizeLimitedWithDictionary;
pub const zstdDecodedNativeFrameSizeWithDictionarySet = zstd.decodedNativeFrameSizeWithDictionarySet;
pub const zstdDecodedNativeFrameSizeLimitedWithDictionarySet = zstd.decodedNativeFrameSizeLimitedWithDictionarySet;
pub const zstdDecodedNativeConcatenatedFrameSize = zstd.decodedNativeConcatenatedFrameSize;
pub const zstdDecodedNativeConcatenatedFrameSizeLimited = zstd.decodedNativeConcatenatedFrameSizeLimited;
pub const zstdDecodedNativeConcatenatedFrameSizeWithDictionary = zstd.decodedNativeConcatenatedFrameSizeWithDictionary;
pub const zstdDecodedNativeConcatenatedFrameSizeLimitedWithDictionary = zstd.decodedNativeConcatenatedFrameSizeLimitedWithDictionary;
pub const zstdDecodedNativeConcatenatedFrameSizeWithDictionarySet = zstd.decodedNativeConcatenatedFrameSizeWithDictionarySet;
pub const zstdDecodedNativeConcatenatedFrameSizeLimitedWithDictionarySet = zstd.decodedNativeConcatenatedFrameSizeLimitedWithDictionarySet;
pub const zstdDecodeNativeConcatenatedFrameChunksAlloc = zstd.decodeNativeConcatenatedFrameChunksAlloc;
pub const zstdDecodeNativeConcatenatedFrameChunksAllocExactSize = zstd.decodeNativeConcatenatedFrameChunksAllocExactSize;
pub const zstdDecodeNativeConcatenatedFrameChunksAllocLimited = zstd.decodeNativeConcatenatedFrameChunksAllocLimited;
pub const zstdDecodeNativeConcatenatedFrameChunksAppend = zstd.decodeNativeConcatenatedFrameChunksAppend;
pub const zstdDecodeNativeConcatenatedFrameChunksAppendExactSize = zstd.decodeNativeConcatenatedFrameChunksAppendExactSize;
pub const zstdDecodeNativeConcatenatedFrameChunksAppendLimited = zstd.decodeNativeConcatenatedFrameChunksAppendLimited;
pub const zstdDecodeNativeConcatenatedFrameChunksInto = zstd.decodeNativeConcatenatedFrameChunksInto;
pub const zstdDecodeNativeConcatenatedFrameChunksIntoLimited = zstd.decodeNativeConcatenatedFrameChunksIntoLimited;
pub const zstdDecodeNativeConcatenatedFrameChunksIntoExactSize = zstd.decodeNativeConcatenatedFrameChunksIntoExactSize;
pub const zstdDecodedNativeConcatenatedFrameChunksSize = zstd.decodedNativeConcatenatedFrameChunksSize;
pub const zstdDecodedNativeConcatenatedFrameChunksSizeLimited = zstd.decodedNativeConcatenatedFrameChunksSizeLimited;
pub const zstdDecodeNativeConcatenatedFrameChunksAllocWithDictionary = zstd.decodeNativeConcatenatedFrameChunksAllocWithDictionary;
pub const zstdDecodeNativeConcatenatedFrameChunksAllocWithDictionaryExactSize = zstd.decodeNativeConcatenatedFrameChunksAllocWithDictionaryExactSize;
pub const zstdDecodeNativeConcatenatedFrameChunksAllocWithDictionaryLimited = zstd.decodeNativeConcatenatedFrameChunksAllocWithDictionaryLimited;
pub const zstdDecodeNativeConcatenatedFrameChunksAppendWithDictionary = zstd.decodeNativeConcatenatedFrameChunksAppendWithDictionary;
pub const zstdDecodeNativeConcatenatedFrameChunksAppendExactSizeWithDictionary = zstd.decodeNativeConcatenatedFrameChunksAppendExactSizeWithDictionary;
pub const zstdDecodeNativeConcatenatedFrameChunksAppendLimitedWithDictionary = zstd.decodeNativeConcatenatedFrameChunksAppendLimitedWithDictionary;
pub const zstdDecodeNativeConcatenatedFrameChunksIntoWithDictionary = zstd.decodeNativeConcatenatedFrameChunksIntoWithDictionary;
pub const zstdDecodeNativeConcatenatedFrameChunksIntoWithDictionaryLimited = zstd.decodeNativeConcatenatedFrameChunksIntoWithDictionaryLimited;
pub const zstdDecodeNativeConcatenatedFrameChunksIntoExactSizeWithDictionary = zstd.decodeNativeConcatenatedFrameChunksIntoExactSizeWithDictionary;
pub const zstdDecodeNativeConcatenatedFrameChunksIntoWithDictionaryExactSize = zstd.decodeNativeConcatenatedFrameChunksIntoWithDictionaryExactSize;
pub const zstdDecodedNativeConcatenatedFrameChunksSizeWithDictionary = zstd.decodedNativeConcatenatedFrameChunksSizeWithDictionary;
pub const zstdDecodedNativeConcatenatedFrameChunksSizeLimitedWithDictionary = zstd.decodedNativeConcatenatedFrameChunksSizeLimitedWithDictionary;
pub const zstdDecodeNativeConcatenatedFrameChunksAllocWithDictionarySet = zstd.decodeNativeConcatenatedFrameChunksAllocWithDictionarySet;
pub const zstdDecodeNativeConcatenatedFrameChunksAllocWithDictionarySetExactSize = zstd.decodeNativeConcatenatedFrameChunksAllocWithDictionarySetExactSize;
pub const zstdDecodeNativeConcatenatedFrameChunksAllocWithDictionarySetLimited = zstd.decodeNativeConcatenatedFrameChunksAllocWithDictionarySetLimited;
pub const zstdDecodeNativeConcatenatedFrameChunksAppendWithDictionarySet = zstd.decodeNativeConcatenatedFrameChunksAppendWithDictionarySet;
pub const zstdDecodeNativeConcatenatedFrameChunksAppendExactSizeWithDictionarySet = zstd.decodeNativeConcatenatedFrameChunksAppendExactSizeWithDictionarySet;
pub const zstdDecodeNativeConcatenatedFrameChunksAppendLimitedWithDictionarySet = zstd.decodeNativeConcatenatedFrameChunksAppendLimitedWithDictionarySet;
pub const zstdDecodeNativeConcatenatedFrameChunksIntoWithDictionarySet = zstd.decodeNativeConcatenatedFrameChunksIntoWithDictionarySet;
pub const zstdDecodeNativeConcatenatedFrameChunksIntoWithDictionarySetLimited = zstd.decodeNativeConcatenatedFrameChunksIntoWithDictionarySetLimited;
pub const zstdDecodeNativeConcatenatedFrameChunksIntoExactSizeWithDictionarySet = zstd.decodeNativeConcatenatedFrameChunksIntoExactSizeWithDictionarySet;
pub const zstdDecodeNativeConcatenatedFrameChunksIntoWithDictionarySetExactSize = zstd.decodeNativeConcatenatedFrameChunksIntoWithDictionarySetExactSize;
pub const zstdDecodedNativeConcatenatedFrameChunksSizeWithDictionarySet = zstd.decodedNativeConcatenatedFrameChunksSizeWithDictionarySet;
pub const zstdDecodedNativeConcatenatedFrameChunksSizeLimitedWithDictionarySet = zstd.decodedNativeConcatenatedFrameChunksSizeLimitedWithDictionarySet;

pub const Error = core.Error;
pub const DeflateError = deflate.Error;
pub const maxStoredDeflateBlockLen = deflate.max_stored_block_len;
pub const FrameInfo = core.FrameInfo;
pub const Progress = core.Progress;
pub const StepResult = core.StepResult;
pub const StreamingDiagnostics = core.StreamingDiagnostics;

pub const frameModeName = store.frameModeName;
pub const StoreFrameInspection = store.FrameInspection;
pub const StoreEncoder = store.Encoder;
pub const StoreDecoder = store.Decoder;
pub const StoreIncrementalDecoder = store.IncrementalDecoder;
pub const StoreAnyDecoder = store.AnyDecoder;
pub const storeInspectHeader = store.inspectHeader;
pub const storeInspectFrame = store.inspectFrame;
pub const storeInspectFrameExact = store.inspectFrameExact;
pub const storeEncode = store.encode;
pub const storeDecode = store.decode;
pub const storeEncodeAlloc = store.encodeAlloc;
pub const storeEncodeDeflateAlloc = store.encodeDeflateAlloc;
pub const storeEncodeRleAlloc = store.encodeRleAlloc;
pub const storeEncodeDictionaryPatchAlloc = store.encodeDictionaryPatchAlloc;
pub const storeEncodeDictionaryDeflateAlloc = store.encodeDictionaryDeflateAlloc;
pub const storeEncodeLongDistanceAlloc = store.encodeLongDistanceAlloc;
pub const storeEncodeBestWithLongDistanceAlloc = store.encodeBestWithLongDistanceAlloc;
pub const storeEncodeBestWithDictionaryAlloc = store.encodeBestWithDictionaryAlloc;
pub const storeEncodeBestAlloc = store.encodeBestAlloc;
pub const storeDecodeAnyAlloc = store.decodeAnyAlloc;
pub const storeDecodeAnyAllocExactSize = store.decodeAnyAllocExactSize;
pub const storeDecodeAnyAllocLimited = store.decodeAnyAllocLimited;
pub const storeDecodeAnyInto = store.decodeAnyInto;
pub const storeDecodeRleInto = store.decodeRleInto;
pub const storeDecodeLongDistanceInto = store.decodeLongDistanceInto;
pub const storeDecodeDictionaryPatchAlloc = store.decodeDictionaryPatchAlloc;
pub const storeDecodeDictionaryPatchAllocExactSize = store.decodeDictionaryPatchAllocExactSize;
pub const storeDecodeDictionaryPatchAllocLimited = store.decodeDictionaryPatchAllocLimited;
pub const storeDecodeDictionaryPatchInto = store.decodeDictionaryPatchInto;
pub const storeDecodeDictionaryPatchIntoWithPatchScratch = store.decodeDictionaryPatchIntoWithPatchScratch;
pub const storeDecodeAlloc = store.decodeAlloc;
pub const storeDecodeConcatenatedAlloc = store.decodeConcatenatedAlloc;
pub const storeDecodeConcatenatedAllocExactSize = store.decodeConcatenatedAllocExactSize;
pub const storeDecodeConcatenatedAllocLimited = store.decodeConcatenatedAllocLimited;
pub const storeDecodeConcatenatedWithDictionaryAlloc = store.decodeConcatenatedWithDictionaryAlloc;
pub const storeDecodeConcatenatedWithDictionaryAllocExactSize = store.decodeConcatenatedWithDictionaryAllocExactSize;
pub const storeDecodeConcatenatedWithDictionaryAllocLimited = store.decodeConcatenatedWithDictionaryAllocLimited;
pub const storeDecodeConcatenatedAutoAlloc = store.decodeConcatenatedAutoAlloc;
pub const storeDecodeConcatenatedAutoAllocExactSize = store.decodeConcatenatedAutoAllocExactSize;
pub const storeDecodeConcatenatedAutoAllocLimited = store.decodeConcatenatedAutoAllocLimited;
pub const storeDecodeConcatenatedInto = store.decodeConcatenatedInto;
pub const storeDecodeConcatenatedWithDictionaryInto = store.decodeConcatenatedWithDictionaryInto;
pub const storeDecodeConcatenatedAutoInto = store.decodeConcatenatedAutoInto;
pub const storeEncodeSkippableAlloc = store.encodeSkippableAlloc;
pub const storeBuildFrameIndexAlloc = store.buildFrameIndexAlloc;
pub const storeEncodeFrameIndexAlloc = store.encodeFrameIndexAlloc;
pub const storeFrameIndexEntryCount = store.frameIndexEntryCount;
pub const storeDecodeFrameIndex = store.decodeFrameIndex;
pub const storeDecodeFrameIndexAlloc = store.decodeFrameIndexAlloc;
pub const StoreEmbeddedIndexView = store.EmbeddedIndexView;
pub const StoreEmbeddedIndexDecodeResult = store.EmbeddedIndexDecodeResult;
pub const StoreFrameIndexEntry = store.FrameIndexEntry;
pub const storeViewEmbeddedIndex = store.viewEmbeddedIndex;
pub const storeDecodeEmbeddedIndex = store.decodeEmbeddedIndex;
pub const storeFindFrameForOffset = store.findFrameForOffset;
pub const storeValidateFrameIndex = store.validateFrameIndex;
pub const StoreFrameIndexSummary = store.FrameIndexSummary;
pub const storeSummarizeFrameIndex = store.summarizeFrameIndex;
pub const storeFrameIndexCombinedChecksum = store.frameIndexCombinedChecksum;
pub const storeDecodeRangeAlloc = store.decodeRangeAlloc;
pub const storeDecodeRangeInto = store.decodeRangeInto;
pub const storeDecodeRangeIntoWithPayloadScratch = store.decodeRangeIntoWithPayloadScratch;
pub const storeDecodeRangesInto = store.decodeRangesInto;
pub const storeDecodeRangesIntoWithPayloadScratch = store.decodeRangesIntoWithPayloadScratch;
pub const storeSidecarIndexedStream = store.SidecarIndexedStream;
pub const storeEncodeSidecarIndexedStreamAlloc = store.encodeSidecarIndexedStreamAlloc;
pub const storeEncodeIndexedStreamAlloc = store.encodeIndexedStreamAlloc;
pub const storeEncodeIndexedDeflateStreamAlloc = store.encodeIndexedDeflateStreamAlloc;
pub const storeEncodeIndexedLongDistanceStreamAlloc = store.encodeIndexedLongDistanceStreamAlloc;
pub const storeEncodeBlockedDeflateStreamAlloc = store.encodeBlockedDeflateStreamAlloc;
pub const storeEncodeSidecarBlockedBestStreamAlloc = store.encodeSidecarBlockedBestStreamAlloc;
pub const storeEncodeSidecarBlockedBestStreamWithOptionsAlloc = store.encodeSidecarBlockedBestStreamWithOptionsAlloc;
pub const storeEncodeBlockedBestStreamAlloc = store.encodeBlockedBestStreamAlloc;
pub const storeEncodeBlockedBestStreamWithOptionsAlloc = store.encodeBlockedBestStreamWithOptionsAlloc;
pub const storeEncodeSidecarBlockedBestStreamWithLdmAlloc = store.encodeSidecarBlockedBestStreamWithLdmAlloc;
pub const storeEncodeBlockedBestStreamWithLdmAlloc = store.encodeBlockedBestStreamWithLdmAlloc;
pub const storeEncodeBlockedBestStreamWithLdmSummaryAlloc = store.encodeBlockedBestStreamWithLdmSummaryAlloc;
pub const storeEncodeBlockedBestWithDictionaryStreamAlloc = store.encodeBlockedBestWithDictionaryStreamAlloc;
pub const storeEncodeSidecarSelfContainedDictionaryStreamAlloc = store.encodeSidecarSelfContainedDictionaryStreamAlloc;
pub const storeEncodeSelfContainedDictionaryStreamAlloc = store.encodeSelfContainedDictionaryStreamAlloc;
pub const storeEncodeBestTrainedDictionaryStreamAlloc = store.encodeBestTrainedDictionaryStreamAlloc;
pub const storeEncodePlannedDeflateStreamAlloc = store.encodePlannedDeflateStreamAlloc;
pub const storeEncodeParallelDeflateStreamAlloc = store.encodeParallelDeflateStreamAlloc;
pub const storeEncodeThreadPoolDeflateStreamAlloc = store.encodeThreadPoolDeflateStreamAlloc;
pub const storeEncodeWorkStealingDeflateStreamAlloc = store.encodeWorkStealingDeflateStreamAlloc;
pub const SeekableNativeOptions = store.SeekableNativeOptions;
pub const SeekabilityTier = store.SeekableNativeOptions.SeekabilityTier;
pub const storeEncodeSeekableNativeStreamAlloc = store.encodeSeekableNativeStreamAlloc;
pub const storeEncodeSeekableNativeSidecarStreamAlloc = store.encodeSeekableNativeSidecarStreamAlloc;
pub const storeDecodeIndexedRangeAlloc = store.decodeIndexedRangeAlloc;
pub const storeDecodeIndexedRangeWithSummaryAlloc = store.decodeIndexedRangeWithSummaryAlloc;
pub const storeDecodeIndexedRangesWithSummaryAlloc = store.decodeIndexedRangesWithSummaryAlloc;
pub const storeDecodeIndexedRangeInto = store.decodeIndexedRangeInto;
pub const storeDecodeIndexedRangeIntoWithIndexBuffer = store.decodeIndexedRangeIntoWithIndexBuffer;
pub const storeDecodeIndexedRangesInto = store.decodeIndexedRangesInto;
pub const storeDecodeIndexedRangesIntoWithIndexBuffer = store.decodeIndexedRangesIntoWithIndexBuffer;
pub const storeDecodeIndexedRangeIntoWithBuffers = store.decodeIndexedRangeIntoWithBuffers;
pub const storeDecodeIndexedRangesIntoWithBuffers = store.decodeIndexedRangesIntoWithBuffers;
pub const StoreRangeRequest = store.RangeRequest;
pub const StoreRangeIntoRequest = store.RangeIntoRequest;
pub const StoreRangeDecodeBuffers = store.RangeDecodeBuffers;
pub const StoreRangeBufferSizes = store.RangeBufferSizes;
pub const storeRangeBufferSizesForIndex = store.rangeBufferSizesForIndex;
pub const storeRangeBufferSizesForSidecarIndex = store.rangeBufferSizesForSidecarIndex;
pub const storeRangeBufferSizesForEmbeddedIndex = store.rangeBufferSizesForEmbeddedIndex;
pub const StoreDictionaryRangeDecodeBuffers = store.DictionaryRangeDecodeBuffers;
pub const StoreDictionaryRangeBufferSizes = store.DictionaryRangeBufferSizes;
pub const storeDictionaryRangeBufferSizesForIndex = store.dictionaryRangeBufferSizesForIndex;
pub const storeDictionaryRangeBufferSizesForSidecarIndex = store.dictionaryRangeBufferSizesForSidecarIndex;
pub const storeDictionaryRangeBufferSizesForEmbeddedIndex = store.dictionaryRangeBufferSizesForEmbeddedIndex;
pub const StoreRangeDecodeResult = store.RangeDecodeResult;
pub const StoreRangeBatchDecodeResult = store.RangeBatchDecodeResult;
pub const StoreRangeDecodeIntoResult = store.RangeDecodeIntoResult;
pub const StoreConcatenatedDecodeIntoResult = store.ConcatenatedDecodeIntoResult;
pub const StoreConcatenatedInspectionSummary = store.ConcatenatedInspectionSummary;
pub const StoreConcatenatedInspectionOptions = store.ConcatenatedInspectionOptions;
pub const SidecarValidationMode = store.SidecarValidationMode;
pub const SidecarValidationOptions = store.SidecarValidationOptions;
pub const SidecarValidationBuffers = store.SidecarValidationBuffers;
pub const SidecarValidationBufferSizes = store.SidecarValidationBufferSizes;
pub const storeSidecarValidationBufferSizesForIndex = store.sidecarValidationBufferSizesForIndex;
pub const storeSidecarValidationBufferSizesForSidecarIndex = store.sidecarValidationBufferSizesForSidecarIndex;
pub const storeSidecarValidationBufferSizesForEmbeddedIndex = store.sidecarValidationBufferSizesForEmbeddedIndex;
pub const ValidationStage = store.ValidationStage;
pub const ValidationHint = store.ValidationHint;
pub const ValidationReport = store.ValidationReport;
pub const storeValidateSidecarIndexAlloc = store.validateSidecarIndexAlloc;
pub const storeValidateSidecarIndexMetadataAlloc = store.validateSidecarIndexMetadataAlloc;
pub const storeValidateSidecarIndexWithOptionsAlloc = store.validateSidecarIndexWithOptionsAlloc;
pub const storeValidateSidecarIndexWithOptionsAndBuffersAlloc = store.validateSidecarIndexWithOptionsAndBuffersAlloc;
pub const storeValidateSidecarIndexWithDictionaryAlloc = store.validateSidecarIndexWithDictionaryAlloc;
pub const storeValidateSidecarIndexReportAlloc = store.validateSidecarIndexReportAlloc;
pub const storeValidateSidecarIndexReportWithOptionsAndBuffersAlloc = store.validateSidecarIndexReportWithOptionsAndBuffersAlloc;
pub const storeValidateEmbeddedIndexAlloc = store.validateEmbeddedIndexAlloc;
pub const storeValidateEmbeddedIndexMetadataAlloc = store.validateEmbeddedIndexMetadataAlloc;
pub const storeValidateEmbeddedIndexWithOptionsAlloc = store.validateEmbeddedIndexWithOptionsAlloc;
pub const storeValidateEmbeddedIndexWithOptionsAndBuffersAlloc = store.validateEmbeddedIndexWithOptionsAndBuffersAlloc;
pub const storeValidateEmbeddedIndexReportAlloc = store.validateEmbeddedIndexReportAlloc;
pub const storeValidateEmbeddedIndexReportWithOptionsAndBuffersAlloc = store.validateEmbeddedIndexReportWithOptionsAndBuffersAlloc;
pub const storeDecodeSidecarIndexedRangeAlloc = store.decodeSidecarIndexedRangeAlloc;
pub const storeDecodeSidecarIndexedRangeWithSummaryAlloc = store.decodeSidecarIndexedRangeWithSummaryAlloc;
pub const storeDecodeSidecarIndexedRangesWithSummaryAlloc = store.decodeSidecarIndexedRangesWithSummaryAlloc;
pub const storeDecodeSidecarIndexedRangeInto = store.decodeSidecarIndexedRangeInto;
pub const storeDecodeSidecarIndexedRangeIntoWithIndexBuffer = store.decodeSidecarIndexedRangeIntoWithIndexBuffer;
pub const storeDecodeSidecarIndexedRangesInto = store.decodeSidecarIndexedRangesInto;
pub const storeDecodeSidecarIndexedRangesIntoWithIndexBuffer = store.decodeSidecarIndexedRangesIntoWithIndexBuffer;
pub const storeDecodeSidecarIndexedRangeIntoWithBuffers = store.decodeSidecarIndexedRangeIntoWithBuffers;
pub const storeDecodeSidecarIndexedRangesIntoWithBuffers = store.decodeSidecarIndexedRangesIntoWithBuffers;
pub const storeDecodeSidecarIndexedRangeWithDictionaryAlloc = store.decodeSidecarIndexedRangeWithDictionaryAlloc;
pub const storeDecodeSidecarIndexedRangeWithDictionarySummaryAlloc = store.decodeSidecarIndexedRangeWithDictionarySummaryAlloc;
pub const storeDecodeSidecarIndexedRangesWithDictionarySummaryAlloc = store.decodeSidecarIndexedRangesWithDictionarySummaryAlloc;
pub const storeDecodeSidecarIndexedRangeWithDictionaryInto = store.decodeSidecarIndexedRangeWithDictionaryInto;
pub const storeDecodeSidecarIndexedRangeWithDictionaryIntoWithIndexBuffer = store.decodeSidecarIndexedRangeWithDictionaryIntoWithIndexBuffer;
pub const storeDecodeSidecarIndexedRangeWithDictionaryIntoWithBuffers = store.decodeSidecarIndexedRangeWithDictionaryIntoWithBuffers;
pub const storeDecodeSidecarIndexedRangesWithDictionaryInto = store.decodeSidecarIndexedRangesWithDictionaryInto;
pub const storeDecodeSidecarIndexedRangesWithDictionaryIntoWithIndexBuffer = store.decodeSidecarIndexedRangesWithDictionaryIntoWithIndexBuffer;
pub const storeDecodeSidecarIndexedRangesWithDictionaryIntoWithBuffers = store.decodeSidecarIndexedRangesWithDictionaryIntoWithBuffers;
pub const storeDecodeSidecarIndexedRangeAutoAlloc = store.decodeSidecarIndexedRangeAutoAlloc;
pub const storeDecodeSidecarIndexedRangeAutoWithSummaryAlloc = store.decodeSidecarIndexedRangeAutoWithSummaryAlloc;
pub const storeDecodeSidecarIndexedRangesAutoWithSummaryAlloc = store.decodeSidecarIndexedRangesAutoWithSummaryAlloc;
pub const storeDecodeSidecarIndexedRangeAutoInto = store.decodeSidecarIndexedRangeAutoInto;
pub const storeDecodeSidecarIndexedRangeAutoIntoWithIndexBuffer = store.decodeSidecarIndexedRangeAutoIntoWithIndexBuffer;
pub const storeDecodeSidecarIndexedRangeAutoIntoWithBuffers = store.decodeSidecarIndexedRangeAutoIntoWithBuffers;
pub const storeDecodeSidecarIndexedRangesAutoInto = store.decodeSidecarIndexedRangesAutoInto;
pub const storeDecodeSidecarIndexedRangesAutoIntoWithIndexBuffer = store.decodeSidecarIndexedRangesAutoIntoWithIndexBuffer;
pub const storeDecodeSidecarIndexedRangesAutoIntoWithBuffers = store.decodeSidecarIndexedRangesAutoIntoWithBuffers;
pub const storeDecodeIndexedRangeWithDictionaryAlloc = store.decodeIndexedRangeWithDictionaryAlloc;
pub const storeDecodeIndexedRangeWithDictionarySummaryAlloc = store.decodeIndexedRangeWithDictionarySummaryAlloc;
pub const storeDecodeIndexedRangesWithDictionarySummaryAlloc = store.decodeIndexedRangesWithDictionarySummaryAlloc;
pub const storeDecodeIndexedRangeWithDictionaryInto = store.decodeIndexedRangeWithDictionaryInto;
pub const storeDecodeIndexedRangeWithDictionaryIntoWithIndexBuffer = store.decodeIndexedRangeWithDictionaryIntoWithIndexBuffer;
pub const storeDecodeIndexedRangeWithDictionaryIntoWithBuffers = store.decodeIndexedRangeWithDictionaryIntoWithBuffers;
pub const storeDecodeIndexedRangesWithDictionaryInto = store.decodeIndexedRangesWithDictionaryInto;
pub const storeDecodeIndexedRangesWithDictionaryIntoWithIndexBuffer = store.decodeIndexedRangesWithDictionaryIntoWithIndexBuffer;
pub const storeDecodeIndexedRangesWithDictionaryIntoWithBuffers = store.decodeIndexedRangesWithDictionaryIntoWithBuffers;
pub const storeDecodeSelfContainedDictionaryRangeAlloc = store.decodeSelfContainedDictionaryRangeAlloc;
pub const storeDecodeSelfContainedDictionaryRangeWithSummaryAlloc = store.decodeSelfContainedDictionaryRangeWithSummaryAlloc;
pub const storeDecodeSelfContainedDictionaryRangesWithSummaryAlloc = store.decodeSelfContainedDictionaryRangesWithSummaryAlloc;
pub const storeDecodeSelfContainedDictionaryRangeInto = store.decodeSelfContainedDictionaryRangeInto;
pub const storeDecodeSelfContainedDictionaryRangeIntoWithIndexBuffer = store.decodeSelfContainedDictionaryRangeIntoWithIndexBuffer;
pub const storeDecodeSelfContainedDictionaryRangeIntoWithBuffers = store.decodeSelfContainedDictionaryRangeIntoWithBuffers;
pub const storeDecodeSelfContainedDictionaryRangesInto = store.decodeSelfContainedDictionaryRangesInto;
pub const storeDecodeSelfContainedDictionaryRangesIntoWithIndexBuffer = store.decodeSelfContainedDictionaryRangesIntoWithIndexBuffer;
pub const storeDecodeSelfContainedDictionaryRangesIntoWithBuffers = store.decodeSelfContainedDictionaryRangesIntoWithBuffers;
pub const storeDecodeIndexedRangeAutoAlloc = store.decodeIndexedRangeAutoAlloc;
pub const storeDecodeIndexedRangeAutoWithSummaryAlloc = store.decodeIndexedRangeAutoWithSummaryAlloc;
pub const storeDecodeIndexedRangesAutoWithSummaryAlloc = store.decodeIndexedRangesAutoWithSummaryAlloc;
pub const storeDecodeIndexedRangeAutoInto = store.decodeIndexedRangeAutoInto;
pub const storeDecodeIndexedRangeAutoIntoWithIndexBuffer = store.decodeIndexedRangeAutoIntoWithIndexBuffer;
pub const storeDecodeIndexedRangeAutoIntoWithBuffers = store.decodeIndexedRangeAutoIntoWithBuffers;
pub const storeDecodeIndexedRangesAutoInto = store.decodeIndexedRangesAutoInto;
pub const storeDecodeIndexedRangesAutoIntoWithIndexBuffer = store.decodeIndexedRangesAutoIntoWithIndexBuffer;
pub const storeDecodeIndexedRangesAutoIntoWithBuffers = store.decodeIndexedRangesAutoIntoWithBuffers;
pub const StoreEmbeddedDictionaryInspection = store.EmbeddedDictionaryInspection;
pub const StoreEmbeddedDictionaryView = store.EmbeddedDictionaryView;
pub const StoreEmbeddedDictionaryInspectionOptions = store.EmbeddedDictionaryInspectionOptions;
pub const storeViewEmbeddedDictionary = store.viewEmbeddedDictionary;
pub const storeViewEmbeddedDictionaryWithOptions = store.viewEmbeddedDictionaryWithOptions;
pub const storeInspectEmbeddedDictionary = store.inspectEmbeddedDictionary;
pub const storeInspectEmbeddedDictionaryWithOptions = store.inspectEmbeddedDictionaryWithOptions;
pub const storeParseEmbeddedDictionary = store.parseEmbeddedDictionary;
pub const storeParseEmbeddedDictionaryAlloc = store.parseEmbeddedDictionaryAlloc;
pub const storeSummarizeModes = store.summarizeModes;
pub const storeInspectConcatenated = store.inspectConcatenated;
pub const storeInspectConcatenatedWithOptions = store.inspectConcatenatedWithOptions;
pub const storeParseEmbeddedLdmSummary = store.parseEmbeddedLdmSummary;

pub const encodeRawStoredDeflate = deflate.encodeRawStored;
pub const decodeRawStoredDeflate = deflate.decodeRawStored;
pub const encodeRawFixedDeflateAlloc = deflate.encodeRawFixedAlloc;
pub const encodeRawFixedDeflateAppend = deflate.encodeRawFixedAppend;
pub const encodeRawFixedSplitAlloc = deflate.encodeRawFixedSplitAlloc;
pub const encodeRawFixedSplitAppend = deflate.encodeRawFixedSplitAppend;
pub const encodeRawFixedSplitWithDictionaryAlloc = deflate.encodeRawFixedSplitWithDictionaryAlloc;
pub const encodeRawFixedSplitWithDictionaryAppend = deflate.encodeRawFixedSplitWithDictionaryAppend;
pub const encodeRawFixedWithDictionaryAlloc = deflate.encodeRawFixedWithDictionaryAlloc;
pub const encodeRawFixedWithDictionaryAppend = deflate.encodeRawFixedWithDictionaryAppend;
pub const encodeRawBestAlloc = deflate.encodeRawBestAlloc;
pub const encodeRawBestAppend = deflate.encodeRawBestAppend;
pub const encodeRawBestWithDictionaryAlloc = deflate.encodeRawBestWithDictionaryAlloc;
pub const encodeRawBestWithDictionaryAppend = deflate.encodeRawBestWithDictionaryAppend;
pub const encodeRawLevelAlloc = deflate.encodeRawLevelAlloc;
pub const encodeRawLevelAppend = deflate.encodeRawLevelAppend;
pub const encodeRawLevelWithDictionaryAlloc = deflate.encodeRawLevelWithDictionaryAlloc;
pub const encodeRawLevelWithDictionaryAppend = deflate.encodeRawLevelWithDictionaryAppend;
pub const encodeRawBestSplitAlloc = deflate.encodeRawBestSplitAlloc;
pub const encodeRawBestSplitAppend = deflate.encodeRawBestSplitAppend;
pub const encodeRawBestSplitWithDictionaryAlloc = deflate.encodeRawBestSplitWithDictionaryAlloc;
pub const encodeRawBestSplitWithDictionaryAppend = deflate.encodeRawBestSplitWithDictionaryAppend;
pub const encodeRawBestAdaptiveSplitAlloc = deflate.encodeRawBestAdaptiveSplitAlloc;
pub const encodeRawBestAdaptiveSplitAppend = deflate.encodeRawBestAdaptiveSplitAppend;
pub const encodeRawBestAdaptiveSplitWithDictionaryAlloc = deflate.encodeRawBestAdaptiveSplitWithDictionaryAlloc;
pub const encodeRawBestAdaptiveSplitWithDictionaryAppend = deflate.encodeRawBestAdaptiveSplitWithDictionaryAppend;
pub const encodeRawDynamicLiteralAlloc = deflate.encodeRawDynamicLiteralAlloc;
pub const encodeRawDynamicLiteralAppend = deflate.encodeRawDynamicLiteralAppend;
pub const encodeRawDynamicWithOptionsAlloc = deflate.encodeRawDynamicWithOptionsAlloc;
pub const encodeRawDynamicWithOptionsAppend = deflate.encodeRawDynamicWithOptionsAppend;
pub const encodeRawDynamicWithDictionaryAlloc = deflate.encodeRawDynamicWithDictionaryAlloc;
pub const encodeRawDynamicWithDictionaryAppend = deflate.encodeRawDynamicWithDictionaryAppend;
pub const encodeRawDynamicSplitAlloc = deflate.encodeRawDynamicSplitAlloc;
pub const encodeRawDynamicSplitAppend = deflate.encodeRawDynamicSplitAppend;
pub const encodeRawDynamicSplitWithDictionaryAlloc = deflate.encodeRawDynamicSplitWithDictionaryAlloc;
pub const encodeRawDynamicSplitWithDictionaryAppend = deflate.encodeRawDynamicSplitWithDictionaryAppend;
pub const encodeRawDynamicTokensAlloc = deflate.encodeRawDynamicTokensAlloc;
pub const encodeRawFixedWithOptionsAlloc = deflate.encodeRawFixedWithOptionsAlloc;
pub const encodeRawFixedWithOptionsAppend = deflate.encodeRawFixedWithOptionsAppend;
pub const encodeRawFixedSyncFlushAppend = deflate.encodeRawFixedSyncFlushAppend;
pub const encodeRawFixedSyncFlushChunksAppend = deflate.encodeRawFixedSyncFlushChunksAppend;
pub const RawFixedSyncFlushEncoder = deflate.RawFixedSyncFlushEncoder;
pub const encodeRawFixedTokensAlloc = deflate.encodeRawFixedTokensAlloc;
pub const RawDeflateEncoder = deflate.RawDeflateEncoder;
pub const RawDeflateIncrementalStoredEncoder = deflate.RawDeflateIncrementalStoredEncoder;
pub const RawDeflateIncrementalFixedEncoder = deflate.RawDeflateIncrementalFixedEncoder;
pub const RawDeflateIncrementalBestEncoder = deflate.RawDeflateIncrementalBestEncoder;
pub const ZlibIncrementalFixedEncoder = deflate.ZlibIncrementalFixedEncoder;
pub const GzipIncrementalFixedEncoder = deflate.GzipIncrementalFixedEncoder;
pub const ZlibIncrementalBestEncoder = deflate.ZlibIncrementalBestEncoder;
pub const GzipIncrementalBestEncoder = deflate.GzipIncrementalBestEncoder;
pub const RawDeflateIncrementalStoredDecoder = deflate.RawDeflateIncrementalStoredDecoder;
pub const RawDeflateIncrementalFixedLiteralDecoder = deflate.RawDeflateIncrementalFixedLiteralDecoder;
pub const ZlibIncrementalDecoder = deflate.ZlibIncrementalDecoder;
pub const ZlibDictionaryEntry = deflate.ZlibDictionaryEntry;
pub const ZlibDictionarySet = deflate.ZlibDictionarySet;
pub const GzipIncrementalDecoder = deflate.GzipIncrementalDecoder;
pub const zlibIncrementalBestOptionsForLevel = deflate.zlibIncrementalBestOptionsForLevel;
pub const gzipIncrementalBestOptionsForLevel = deflate.gzipIncrementalBestOptionsForLevel;
pub const RawDeflateDecoder = deflate.RawDeflateDecoder;
pub const DeflateDecodeResult = deflate.DecodeResult;
pub const DeflateOwnedDecodeResult = deflate.OwnedDecodeResult;
pub const RawDeflateProbeResult = deflate.RawDeflateProbeResult;
pub const DecodeProbeResult = deflate.DecodeProbeResult;
pub const CompressionOptions = deflate.CompressionOptions;
pub const CompressionStrategy = deflate.CompressionStrategy;
pub const AdaptiveSplitOptions = deflate.AdaptiveSplitOptions;
pub const BlockSelection = deflate.BlockSelection;
pub const CompressionLevel = deflate.CompressionLevel;
pub const optionsForCompressionLevel = deflate.optionsForLevel;

test "root gzip incremental fixed encoder exposes member continuation" {
    var encoder = GzipIncrementalFixedEncoder.init(std.testing.allocator);
    defer encoder.deinit();
    var output: [128]u8 = undefined;
    _ = try encoder.step("one", &output);
    encoder.finish();
    while ((try encoder.step("", &output)).status != .done) {}
    try encoder.nextMember(.{ .filename = "two.txt" });
    try std.testing.expectEqual(@as(usize, 1), encoder.snapshot().member_index);
}

test "root incremental zlib decoder exposes dictionary-set selection" {
    const preset = "root incremental zlib set dictionary";
    const payload = "root incremental zlib set dictionary payload";
    const encoded = try encodeZlibFixedWithDictionaryAlloc(std.testing.allocator, payload, preset, .{});
    defer std.testing.allocator.free(encoded);
    const entries = [_]ZlibDictionaryEntry{ZlibDictionarySet.entry(preset)};
    var history: [32 * 1024]u8 = undefined;
    var decoder = try ZlibIncrementalDecoder.initWithDictionarySet(.{ .expected_output_len = payload.len }, &history, ZlibDictionarySet.fromEntries(&entries));
    var output: [payload.len]u8 = undefined;
    const result = try decoder.step(encoded, &output);
    try std.testing.expectEqual(core.StepResult.Status.done, result.status);
    try std.testing.expectEqual(encoded.len, result.progress.input_read);
    try std.testing.expectEqual(payload.len, result.progress.output_written);
    try decoder.finish();
    try std.testing.expectEqualSlices(u8, payload, &output);
}
pub const optionsForZlibLevel = deflate.optionsForZlibLevel;
pub const normalizeCompressionOptionsForStrategy = deflate.normalizeOptionsForStrategy;
pub const usesStoredFastPath = deflate.usesStoredFastPath;
pub const ParserMode = deflate.ParserMode;
pub const RawDeflateBlockType = deflate.RawDeflateBlockType;
pub const RawDeflateHeaderInfo = deflate.RawDeflateHeaderInfo;
pub const parseRawDeflateHeaderInfo = deflate.parseRawDeflateHeaderInfo;
pub const parseRawDeflateHeaderInfoFromChunks = deflate.parseRawDeflateHeaderInfoFromChunks;
pub const DynamicDecodeProfile = deflate.DynamicDecodeProfile;
pub const profileFirstDynamicDeflateBlock = deflate.profileFirstDynamicDeflateBlock;
pub const profileDynamicDeflateBlocks = deflate.profileDynamicDeflateBlocks;
pub const profileDeflateBlocks = deflate.profileDeflateBlocks;
pub const DynamicPlanStats = deflate.DynamicPlanStats;
pub const dynamicDeflatePlanStatsAlloc = deflate.dynamicPlanStatsAlloc;
pub const encodeRawStoredDeflateAlloc = deflate.encodeRawStoredAlloc;
pub const rawStoredDeflateEncodedSize = deflate.rawStoredEncodedSize;
pub const rawStoredDeflateChunksEncodedSize = deflate.rawStoredChunksEncodedSize;
pub const encodeRawStoredDeflateChunks = deflate.encodeRawStoredChunks;
pub const encodeRawStoredDeflateChunksAlloc = deflate.encodeRawStoredChunksAlloc;
pub const encodeRawStoredDeflateChunksAppend = deflate.encodeRawStoredChunksAppend;
pub const encodeRawStoredDeflateAppend = deflate.encodeRawStoredAppend;
pub const decodeRawStoredDeflateAlloc = deflate.decodeRawStoredAlloc;
pub const decodeRawStoredDeflateAllocExactSize = deflate.decodeRawStoredAllocExactSize;
pub const decodeRawStoredDeflateAllocLimited = deflate.decodeRawStoredAllocLimited;
pub const decodeRawStoredDeflateAllocPartial = deflate.decodeRawStoredAllocPartial;
pub const decodeRawFixed = deflate.decodeRawFixed;
pub const decodeRawFixedAlloc = deflate.decodeRawFixedAllocStrict;
pub const decodeRawFixedAllocPartial = deflate.decodeRawFixedAlloc;
pub const decodeRawDeflate = deflate.decodeRawAuto;
pub const decodeRawDeflateWithDictionary = deflate.decodeRawAutoWithDictionary;
pub const decodeRawDeflateChunks = deflate.decodeRawChunks;
pub const decodeRawDeflateChunksWithDictionary = deflate.decodeRawChunksWithDictionary;
pub const decodeRawDeflateAlloc = deflate.decodeRawAutoAlloc;
pub const decodeRawDeflateAllocPartial = deflate.decodeRawAutoAllocPartial;
pub const decodeRawDeflateAllocExactSize = deflate.decodeRawAutoAllocExactSize;
pub const decodeRawDeflateAllocLimited = deflate.decodeRawAutoAllocLimited;
pub const decodeRawDeflateAllocWithDictionary = deflate.decodeRawAutoAllocWithDictionary;
pub const decodeRawDeflateAllocWithDictionaryExactSize = deflate.decodeRawAutoAllocWithDictionaryExactSize;
pub const decodeRawDeflateAllocWithDictionaryLimited = deflate.decodeRawAutoAllocWithDictionaryLimited;
pub const decodeRawDeflateAppend = deflate.decodeRawAutoAppend;
pub const decodeRawDeflateAppendWithDictionary = deflate.decodeRawAutoAppendWithDictionary;
pub const decodeRawDeflateAppendExactSize = deflate.decodeRawAutoAppendExactSize;
pub const decodeRawDeflateAppendWithDictionaryExactSize = deflate.decodeRawAutoAppendWithDictionaryExactSize;
pub const decodeRawDeflateAppendLimited = deflate.decodeRawAutoAppendLimited;
pub const decodeRawDeflateAppendWithDictionaryLimited = deflate.decodeRawAutoAppendWithDictionaryLimited;
pub const decodeRawDeflateChunksAlloc = deflate.decodeRawChunksAlloc;
pub const decodeRawDeflateChunksAllocExactSize = deflate.decodeRawChunksAllocExactSize;
pub const decodeRawDeflateChunksAllocLimited = deflate.decodeRawChunksAllocLimited;
pub const decodeRawDeflateChunksAllocWithDictionary = deflate.decodeRawChunksAllocWithDictionary;
pub const decodeRawDeflateChunksAllocWithDictionaryExactSize = deflate.decodeRawChunksAllocWithDictionaryExactSize;
pub const decodeRawDeflateChunksAllocWithDictionaryLimited = deflate.decodeRawChunksAllocWithDictionaryLimited;
pub const decodeRawDeflateChunksAppend = deflate.decodeRawChunksAppend;
pub const decodeRawDeflateChunksAppendWithDictionary = deflate.decodeRawChunksAppendWithDictionary;
pub const decodeRawDeflateChunksAppendExactSize = deflate.decodeRawChunksAppendExactSize;
pub const decodeRawDeflateChunksAppendWithDictionaryExactSize = deflate.decodeRawChunksAppendWithDictionaryExactSize;
pub const decodeRawDeflateChunksAppendLimited = deflate.decodeRawChunksAppendLimited;
pub const decodeRawDeflateChunksAppendWithDictionaryLimited = deflate.decodeRawChunksAppendWithDictionaryLimited;
pub const decodedRawDeflateSize = deflate.decodedRawAutoSize;
pub const decodedRawDeflateSizeWithDictionary = deflate.decodedRawAutoSizeWithDictionary;
pub const decodedRawDeflateChunksSize = deflate.decodedRawChunksSize;
pub const decodedRawDeflateChunksSizeWithDictionary = deflate.decodedRawChunksSizeWithDictionary;
pub const probeRawDeflate = deflate.probeRawAuto;
pub const probeRawDeflateWithDictionary = deflate.probeRawAutoWithDictionary;
pub const probeRawDeflateExactSize = deflate.probeRawAutoExactSize;
pub const probeRawDeflateWithDictionaryExactSize = deflate.probeRawAutoWithDictionaryExactSize;
pub const probeRawDeflateChunks = deflate.probeRawChunks;
pub const probeRawDeflateChunksWithDictionary = deflate.probeRawChunksWithDictionary;
pub const probeRawDeflateChunksExactSize = deflate.probeRawChunksExactSize;
pub const probeRawDeflateChunksWithDictionaryExactSize = deflate.probeRawChunksWithDictionaryExactSize;
pub const decodeRawDynamicAlloc = deflate.decodeRawDynamicAllocStrict;
pub const decodeRawDynamicAllocPartial = deflate.decodeRawDynamicAlloc;
pub const encodeZlibStored = deflate.encodeZlibStored;
pub const zlibStoredEncodedSize = deflate.zlibStoredEncodedSize;
pub const zlibStoredWithDictionaryEncodedSize = deflate.zlibStoredWithDictionaryEncodedSize;
pub const zlibStoredChunksEncodedSize = deflate.zlibStoredChunksEncodedSize;
pub const zlibStoredWithDictionaryChunksEncodedSize = deflate.zlibStoredWithDictionaryChunksEncodedSize;
pub const encodeZlibStoredChunks = deflate.encodeZlibStoredChunks;
pub const encodeZlibStoredWithDictionaryChunks = deflate.encodeZlibStoredWithDictionaryChunks;
pub const encodeZlibStoredWithDictionary = deflate.encodeZlibStoredWithDictionary;
pub const encodeZlibFixedAlloc = deflate.encodeZlibFixedAlloc;
pub const encodeZlibFixedAppend = deflate.encodeZlibFixedAppend;
pub const encodeZlibFixedWithDictionaryAlloc = deflate.encodeZlibFixedWithDictionaryAlloc;
pub const encodeZlibFixedWithDictionaryAppend = deflate.encodeZlibFixedWithDictionaryAppend;
pub const encodeZlibFixedSplitAlloc = deflate.encodeZlibFixedSplitAlloc;
pub const encodeZlibFixedSplitAppend = deflate.encodeZlibFixedSplitAppend;
pub const encodeZlibFixedSplitWithDictionaryAlloc = deflate.encodeZlibFixedSplitWithDictionaryAlloc;
pub const encodeZlibFixedSplitWithDictionaryAppend = deflate.encodeZlibFixedSplitWithDictionaryAppend;
pub const encodeZlibBestAlloc = deflate.encodeZlibBestAlloc;
pub const encodeZlibPngUltraFastAlloc = deflate.encodeZlibPngUltraFastAlloc;
pub const encodeZlibBestAppend = deflate.encodeZlibBestAppend;
pub const encodeZlibBestWithDictionaryAlloc = deflate.encodeZlibBestWithDictionaryAlloc;
pub const encodeZlibBestWithDictionaryAppend = deflate.encodeZlibBestWithDictionaryAppend;
pub const encodeZlibLevelAlloc = deflate.encodeZlibLevelAlloc;
pub const encodeZlibLevelAppend = deflate.encodeZlibLevelAppend;
pub const encodeZlibLevelWithDictionaryAlloc = deflate.encodeZlibLevelWithDictionaryAlloc;
pub const encodeZlibLevelWithDictionaryAppend = deflate.encodeZlibLevelWithDictionaryAppend;
pub const encodeZlibBestSplitAlloc = deflate.encodeZlibBestSplitAlloc;
pub const encodeZlibBestSplitAppend = deflate.encodeZlibBestSplitAppend;
pub const encodeZlibBestSplitWithDictionaryAlloc = deflate.encodeZlibBestSplitWithDictionaryAlloc;
pub const encodeZlibBestSplitWithDictionaryAppend = deflate.encodeZlibBestSplitWithDictionaryAppend;
pub const encodeZlibBestAdaptiveSplitAlloc = deflate.encodeZlibBestAdaptiveSplitAlloc;
pub const encodeZlibBestAdaptiveSplitAppend = deflate.encodeZlibBestAdaptiveSplitAppend;
pub const encodeZlibBestAdaptiveSplitWithDictionaryAlloc = deflate.encodeZlibBestAdaptiveSplitWithDictionaryAlloc;
pub const encodeZlibBestAdaptiveSplitWithDictionaryAppend = deflate.encodeZlibBestAdaptiveSplitWithDictionaryAppend;
pub const encodeZlibDynamicLiteralAlloc = deflate.encodeZlibDynamicLiteralAlloc;
pub const encodeZlibDynamicLiteralAppend = deflate.encodeZlibDynamicLiteralAppend;
pub const encodeZlibDynamicWithOptionsAlloc = deflate.encodeZlibDynamicWithOptionsAlloc;
pub const encodeZlibDynamicWithOptionsAppend = deflate.encodeZlibDynamicWithOptionsAppend;
pub const encodeZlibDynamicWithDictionaryAlloc = deflate.encodeZlibDynamicWithDictionaryAlloc;
pub const encodeZlibDynamicWithDictionaryAppend = deflate.encodeZlibDynamicWithDictionaryAppend;
pub const encodeZlibDynamicSplitAlloc = deflate.encodeZlibDynamicSplitAlloc;
pub const encodeZlibDynamicSplitAppend = deflate.encodeZlibDynamicSplitAppend;
pub const encodeZlibDynamicSplitWithDictionaryAlloc = deflate.encodeZlibDynamicSplitWithDictionaryAlloc;
pub const encodeZlibDynamicSplitWithDictionaryAppend = deflate.encodeZlibDynamicSplitWithDictionaryAppend;
pub const encodeZlibFixedWithOptionsAlloc = deflate.encodeZlibFixedWithOptionsAlloc;
pub const encodeZlibFixedWithOptionsAppend = deflate.encodeZlibFixedWithOptionsAppend;
pub const ZlibHeaderInfo = deflate.ZlibHeaderInfo;
pub const ZlibStreamInfo = deflate.ZlibStreamInfo;
pub const ZlibDecodeOptions = deflate.ZlibDecodeOptions;
pub const parseZlibHeaderInfo = deflate.parseZlibHeaderInfo;
pub const parseZlibHeaderInfoFromChunks = deflate.parseZlibHeaderInfoFromChunks;
pub const inspectZlibStreamAlloc = deflate.inspectZlibStreamAlloc;
pub const inspectZlibStreamAllocLimited = deflate.inspectZlibStreamAllocLimited;
pub const inspectZlibStreamFromChunksAlloc = deflate.inspectZlibStreamFromChunksAlloc;
pub const inspectZlibStreamFromChunksAllocLimited = deflate.inspectZlibStreamFromChunksAllocLimited;
pub const inspectZlibStreamAllocWithDictionary = deflate.inspectZlibStreamAllocWithDictionary;
pub const inspectZlibStreamAllocWithDictionaryLimited = deflate.inspectZlibStreamAllocWithDictionaryLimited;
pub const inspectZlibStreamFromChunksAllocWithDictionary = deflate.inspectZlibStreamFromChunksAllocWithDictionary;
pub const inspectZlibStreamFromChunksAllocWithDictionaryLimited = deflate.inspectZlibStreamFromChunksAllocWithDictionaryLimited;
pub const decodeZlibStored = deflate.decodeZlibStored;
pub const decodeZlibStoredWithDictionary = deflate.decodeZlibStoredWithDictionary;
pub const ZlibEncoder = deflate.ZlibEncoder;
pub const ZlibDecoder = deflate.ZlibDecoder;
pub const PngAdam7Info = png_exports.PngAdam7Info;
pub const PngAdam7PassInfo = png_exports.PngAdam7PassInfo;
pub const PngAdam7Row = png_exports.PngAdam7Row;
pub const PngAdam7RowCallback = png_exports.PngAdam7RowCallback;
pub const PngAdam7RowsDecodeResult = png_exports.PngAdam7RowsDecodeResult;
pub const PngAdam7StreamingRowsSnapshot = png_exports.PngAdam7StreamingRowsSnapshot;
pub const PngAdam7StreamingZlibChunkedRowDecoder = png_exports.PngAdam7StreamingZlibChunkedRowDecoder;
pub const PngAdam7StreamingZlibRowDecoder = png_exports.PngAdam7StreamingZlibRowDecoder;
pub const PngColorType = png_exports.PngColorType;
pub const PngFilterMethod = png_exports.PngFilterMethod;
pub const PngImageInfo = png_exports.PngImageInfo;
pub const PngZlibDecodeBufferSizes = png_exports.PngZlibDecodeBufferSizes;
pub const PngStoredZlibChunkedScanlineDecoder = png_exports.PngStoredZlibChunkedScanlineDecoder;
pub const PngStoredZlibScanlineDecoder = png_exports.PngStoredZlibScanlineDecoder;
pub const PngStreamingZlibChunkedScanlineDecoder = png_exports.PngStreamingZlibChunkedScanlineDecoder;
pub const PngStreamingZlibScanlineDecoder = png_exports.PngStreamingZlibScanlineDecoder;
pub const PngZlibScanlineDecoder = png_exports.PngZlibScanlineDecoder;
pub const PngAdam7ImageDecodeResult = png_exports.PngAdam7ImageDecodeResult;
pub const PngImageDecodeResult = png_exports.PngImageDecodeResult;
pub const parsePngColorType = png_exports.parsePngColorType;
pub const pngImageInfo = png_exports.pngImageInfo;
pub const pngImageInfoFromColorType = png_exports.pngImageInfoFromColorType;
pub const pngIdatChunksScratchLen = png_exports.pngIdatChunksScratchLen;
pub const png_windowed_history_scratch_len =
    png_exports.png_windowed_history_scratch_len;
pub const png_windowed_rle258_history_scratch_len =
    png_exports.png_windowed_rle258_history_scratch_len;
pub const pngAdam7Info = png_exports.pngAdam7Info;
pub const pngAdam7InfoFromColorType = png_exports.pngAdam7InfoFromColorType;
pub const pngAdam7DecodeBufferSizes = png_exports.pngAdam7DecodeBufferSizes;
pub const placePngAdam7Row = png_exports.placePngAdam7Row;
pub const placePngAdam7Pass = png_exports.placePngAdam7Pass;
pub const pngZlibDecodeBufferSizes = png_exports.pngZlibDecodeBufferSizes;
pub const decodePngStoredZlibImage = png_exports.decodePngStoredZlibImage;
pub const decodePngStoredZlibImageWithOptions = png_exports.decodePngStoredZlibImageWithOptions;
pub const decodePngStoredZlibImageFromChunksDirect = png_exports.decodePngStoredZlibImageFromChunksDirect;
pub const decodePngStoredZlibImageFromChunksWithOptionsDirect = png_exports.decodePngStoredZlibImageFromChunksWithOptionsDirect;
pub const decodePngStreamingZlibImage = png_exports.decodePngStreamingZlibImage;
pub const decodePngStreamingZlibImageWithOptions = png_exports.decodePngStreamingZlibImageWithOptions;
pub const decodePngWindowedZlibImageWithOptions = png_exports.decodePngWindowedZlibImageWithOptions;
pub const decodePngWindowedRle258ZlibImageWithOptions = png_exports.decodePngWindowedRle258ZlibImageWithOptions;
pub const decodePngStreamingZlibImageFromChunksDirect = png_exports.decodePngStreamingZlibImageFromChunksDirect;
pub const decodePngStreamingZlibImageFromChunksWithOptionsDirect = png_exports.decodePngStreamingZlibImageFromChunksWithOptionsDirect;
pub const decodePngZlibImage = png_exports.decodePngZlibImage;
pub const decodePngZlibImageWithOptions = png_exports.decodePngZlibImageWithOptions;
pub const decodePngZlibImageParallelWithOptions = png_exports.decodePngZlibImageParallelWithOptions;
pub const decodePngFilter0DynamicZlibImageWithOptions = png_exports.decodePngFilter0DynamicZlibImageWithOptions;
pub const decodePngZlibImageFromChunks = png_exports.decodePngZlibImageFromChunks;
pub const decodePngZlibImageFromChunksDirect = png_exports.decodePngZlibImageFromChunksDirect;
pub const decodePngZlibImageFromChunksWithOptionsDirect = png_exports.decodePngZlibImageFromChunksWithOptionsDirect;
pub const decodePngAdam7ZlibImage = png_exports.decodePngAdam7ZlibImage;
pub const decodePngAdam7ZlibImageFromChunks = png_exports.decodePngAdam7ZlibImageFromChunks;
pub const decodePngAdam7ZlibImageFromChunksDirect = png_exports.decodePngAdam7ZlibImageFromChunksDirect;
pub const decodePngAdam7ZlibImageFromChunksWithOptionsDirect = png_exports.decodePngAdam7ZlibImageFromChunksWithOptionsDirect;
pub const decodePngAdam7StreamingZlibImage = png_exports.decodePngAdam7StreamingZlibImage;
pub const decodePngAdam7StreamingZlibImageWithOptions = png_exports.decodePngAdam7StreamingZlibImageWithOptions;
pub const decodePngAdam7StreamingZlibImageFromChunksDirect = png_exports.decodePngAdam7StreamingZlibImageFromChunksDirect;
pub const decodePngAdam7StreamingZlibImageFromChunksWithOptionsDirect = png_exports.decodePngAdam7StreamingZlibImageFromChunksWithOptionsDirect;
pub const streamPngAdam7ZlibRows = png_exports.streamPngAdam7ZlibRows;
pub const streamPngAdam7ZlibRowsWithOptions = png_exports.streamPngAdam7ZlibRowsWithOptions;
pub const streamPngAdam7ZlibRowsFromChunksDirect = png_exports.streamPngAdam7ZlibRowsFromChunksDirect;
pub const streamPngAdam7ZlibRowsFromChunksWithOptionsDirect = png_exports.streamPngAdam7ZlibRowsFromChunksWithOptionsDirect;
pub const reconstructPngScanline = png_exports.reconstructPngScanline;
pub const encodeZlibStoredAlloc = deflate.encodeZlibStoredAlloc;
pub const encodeZlibStoredChunksAlloc = deflate.encodeZlibStoredChunksAlloc;
pub const encodeZlibStoredAppend = deflate.encodeZlibStoredAppend;
pub const encodeZlibStoredChunksAppend = deflate.encodeZlibStoredChunksAppend;
pub const encodeZlibStoredWithDictionaryAlloc = deflate.encodeZlibStoredWithDictionaryAlloc;
pub const encodeZlibStoredWithDictionaryChunksAlloc = deflate.encodeZlibStoredWithDictionaryChunksAlloc;
pub const encodeZlibStoredWithDictionaryAppend = deflate.encodeZlibStoredWithDictionaryAppend;
pub const encodeZlibStoredWithDictionaryChunksAppend = deflate.encodeZlibStoredWithDictionaryChunksAppend;
pub const decodeZlibStoredAlloc = deflate.decodeZlibStoredAlloc;
pub const decodeZlibStoredAllocExactSize = deflate.decodeZlibStoredAllocExactSize;
pub const decodeZlibStoredAllocLimited = deflate.decodeZlibStoredAllocLimited;
pub const decodeZlibStoredAllocWithDictionary = deflate.decodeZlibStoredAllocWithDictionary;
pub const decodeZlibStoredAllocWithDictionaryExactSize = deflate.decodeZlibStoredAllocWithDictionaryExactSize;
pub const decodeZlibStoredAllocWithDictionaryLimited = deflate.decodeZlibStoredAllocWithDictionaryLimited;
pub const decodeZlib = deflate.decodeZlib;
pub const decodeZlibWithDictionary = deflate.decodeZlibWithDictionary;
pub const decodeZlibWithOptions = deflate.decodeZlibWithOptions;
pub const decodeZlibWithDictionaryAndOptions = deflate.decodeZlibWithDictionaryAndOptions;
pub const decodeZlibAppend = deflate.decodeZlibAppend;
pub const decodeZlibAppendWithDictionary = deflate.decodeZlibAppendWithDictionary;
pub const decodeZlibAppendWithOptions = deflate.decodeZlibAppendWithOptions;
pub const decodeZlibAppendWithDictionaryAndOptions = deflate.decodeZlibAppendWithDictionaryAndOptions;
pub const decodeZlibAppendExactSize = deflate.decodeZlibAppendExactSize;
pub const decodeZlibAppendWithDictionaryExactSize = deflate.decodeZlibAppendWithDictionaryExactSize;
pub const decodeZlibAppendWithOptionsExactSize = deflate.decodeZlibAppendWithOptionsExactSize;
pub const decodeZlibAppendWithDictionaryAndOptionsExactSize = deflate.decodeZlibAppendWithDictionaryAndOptionsExactSize;
pub const decodeZlibAppendLimited = deflate.decodeZlibAppendLimited;
pub const decodeZlibAppendWithDictionaryLimited = deflate.decodeZlibAppendWithDictionaryLimited;
pub const decodeZlibAppendWithOptionsLimited = deflate.decodeZlibAppendWithOptionsLimited;
pub const decodeZlibAppendWithDictionaryAndOptionsLimited = deflate.decodeZlibAppendWithDictionaryAndOptionsLimited;
pub const decodeZlibChunks = deflate.decodeZlibChunks;
pub const decodeZlibChunksWithDictionary = deflate.decodeZlibChunksWithDictionary;
pub const decodeZlibChunksWithOptions = deflate.decodeZlibChunksWithOptions;
pub const decodeZlibChunksWithDictionaryAndOptions = deflate.decodeZlibChunksWithDictionaryAndOptions;
pub const decodeZlibChunksInto = deflate.decodeZlibChunksInto;
pub const decodeZlibChunksIntoWithDictionary = deflate.decodeZlibChunksIntoWithDictionary;
pub const decodeZlibChunksIntoWithOptions = deflate.decodeZlibChunksIntoWithOptions;
pub const decodeZlibChunksIntoWithDictionaryAndOptions = deflate.decodeZlibChunksIntoWithDictionaryAndOptions;
pub const decodeZlibAlloc = deflate.decodeZlibAlloc;
pub const decodeZlibAllocExactSize = deflate.decodeZlibAllocExactSize;
pub const decodeZlibAllocLimited = deflate.decodeZlibAllocLimited;
pub const decodeZlibConcatenated = deflate.decodeZlibConcatenated;
pub const decodeZlibConcatenatedWithOptions = deflate.decodeZlibConcatenatedWithOptions;
pub const decodeZlibConcatenatedWithDictionary = deflate.decodeZlibConcatenatedWithDictionary;
pub const decodeZlibConcatenatedWithDictionaryAndOptions = deflate.decodeZlibConcatenatedWithDictionaryAndOptions;
pub const decodeZlibConcatenatedWithDictionarySet = deflate.decodeZlibConcatenatedWithDictionarySet;
pub const decodeZlibConcatenatedWithDictionarySetAndOptions = deflate.decodeZlibConcatenatedWithDictionarySetAndOptions;
pub const decodeZlibConcatenatedAllocWithDictionarySetExactSize = deflate.decodeZlibConcatenatedAllocWithDictionarySetExactSize;
pub const decodeZlibConcatenatedAlloc = deflate.decodeZlibConcatenatedAlloc;
pub const decodeZlibConcatenatedAllocExactSize = deflate.decodeZlibConcatenatedAllocExactSize;
pub const decodeZlibConcatenatedAllocLimited = deflate.decodeZlibConcatenatedAllocLimited;
pub const decodeZlibConcatenatedAllocWithOptions = deflate.decodeZlibConcatenatedAllocWithOptions;
pub const decodeZlibConcatenatedAllocWithOptionsExactSize = deflate.decodeZlibConcatenatedAllocWithOptionsExactSize;
pub const decodeZlibConcatenatedAllocWithOptionsLimited = deflate.decodeZlibConcatenatedAllocWithOptionsLimited;
pub const decodeZlibConcatenatedAllocWithDictionary = deflate.decodeZlibConcatenatedAllocWithDictionary;
pub const decodeZlibConcatenatedAllocWithDictionaryExactSize = deflate.decodeZlibConcatenatedAllocWithDictionaryExactSize;
pub const decodeZlibConcatenatedAllocWithDictionaryLimited = deflate.decodeZlibConcatenatedAllocWithDictionaryLimited;
pub const decodeZlibConcatenatedAllocWithDictionaryAndOptions = deflate.decodeZlibConcatenatedAllocWithDictionaryAndOptions;
pub const decodeZlibConcatenatedAllocWithDictionaryAndOptionsExactSize = deflate.decodeZlibConcatenatedAllocWithDictionaryAndOptionsExactSize;
pub const decodeZlibConcatenatedAllocWithDictionaryAndOptionsLimited = deflate.decodeZlibConcatenatedAllocWithDictionaryAndOptionsLimited;
pub const decodeZlibConcatenatedAppend = deflate.decodeZlibConcatenatedAppend;
pub const decodeZlibConcatenatedAppendWithDictionary = deflate.decodeZlibConcatenatedAppendWithDictionary;
pub const decodeZlibConcatenatedAppendWithOptions = deflate.decodeZlibConcatenatedAppendWithOptions;
pub const decodeZlibConcatenatedAppendWithDictionaryAndOptions = deflate.decodeZlibConcatenatedAppendWithDictionaryAndOptions;
pub const decodeZlibConcatenatedAppendExactSize = deflate.decodeZlibConcatenatedAppendExactSize;
pub const decodeZlibConcatenatedAppendWithDictionaryExactSize = deflate.decodeZlibConcatenatedAppendWithDictionaryExactSize;
pub const decodeZlibConcatenatedAppendWithOptionsExactSize = deflate.decodeZlibConcatenatedAppendWithOptionsExactSize;
pub const decodeZlibConcatenatedAppendWithDictionaryAndOptionsExactSize = deflate.decodeZlibConcatenatedAppendWithDictionaryAndOptionsExactSize;
pub const decodeZlibConcatenatedAppendLimited = deflate.decodeZlibConcatenatedAppendLimited;
pub const decodeZlibConcatenatedAppendWithDictionaryLimited = deflate.decodeZlibConcatenatedAppendWithDictionaryLimited;
pub const decodeZlibConcatenatedAppendWithOptionsLimited = deflate.decodeZlibConcatenatedAppendWithOptionsLimited;
pub const decodeZlibConcatenatedAppendWithDictionaryAndOptionsLimited = deflate.decodeZlibConcatenatedAppendWithDictionaryAndOptionsLimited;
pub const decodeZlibConcatenatedChunksAppend = deflate.decodeZlibConcatenatedChunksAppend;
pub const decodeZlibConcatenatedChunksAppendWithDictionary = deflate.decodeZlibConcatenatedChunksAppendWithDictionary;
pub const decodeZlibConcatenatedChunksAppendWithOptions = deflate.decodeZlibConcatenatedChunksAppendWithOptions;
pub const decodeZlibConcatenatedChunksAppendWithDictionaryAndOptions = deflate.decodeZlibConcatenatedChunksAppendWithDictionaryAndOptions;
pub const decodeZlibConcatenatedChunksAppendExactSize = deflate.decodeZlibConcatenatedChunksAppendExactSize;
pub const decodeZlibConcatenatedChunksAppendWithDictionaryExactSize = deflate.decodeZlibConcatenatedChunksAppendWithDictionaryExactSize;
pub const decodeZlibConcatenatedChunksAppendWithOptionsExactSize = deflate.decodeZlibConcatenatedChunksAppendWithOptionsExactSize;
pub const decodeZlibConcatenatedChunksAppendWithDictionaryAndOptionsExactSize = deflate.decodeZlibConcatenatedChunksAppendWithDictionaryAndOptionsExactSize;
pub const decodeZlibConcatenatedChunksAppendLimited = deflate.decodeZlibConcatenatedChunksAppendLimited;
pub const decodeZlibConcatenatedChunksAppendWithDictionaryLimited = deflate.decodeZlibConcatenatedChunksAppendWithDictionaryLimited;
pub const decodeZlibConcatenatedChunksAppendWithOptionsLimited = deflate.decodeZlibConcatenatedChunksAppendWithOptionsLimited;
pub const decodeZlibConcatenatedChunksAppendWithDictionaryAndOptionsLimited = deflate.decodeZlibConcatenatedChunksAppendWithDictionaryAndOptionsLimited;
pub const probeZlib = deflate.probeZlib;
pub const probeZlibWithDictionary = deflate.probeZlibWithDictionary;
pub const probeZlibWithOptions = deflate.probeZlibWithOptions;
pub const probeZlibWithDictionaryAndOptions = deflate.probeZlibWithDictionaryAndOptions;
pub const probeZlibExactSize = deflate.probeZlibExactSize;
pub const probeZlibWithDictionaryExactSize = deflate.probeZlibWithDictionaryExactSize;
pub const probeZlibWithOptionsExactSize = deflate.probeZlibWithOptionsExactSize;
pub const probeZlibWithDictionaryAndOptionsExactSize = deflate.probeZlibWithDictionaryAndOptionsExactSize;
pub const probeZlibChunks = deflate.probeZlibChunks;
pub const probeZlibChunksWithDictionary = deflate.probeZlibChunksWithDictionary;
pub const probeZlibChunksWithOptions = deflate.probeZlibChunksWithOptions;
pub const probeZlibChunksWithDictionaryAndOptions = deflate.probeZlibChunksWithDictionaryAndOptions;
pub const probeZlibChunksExactSize = deflate.probeZlibChunksExactSize;
pub const probeZlibChunksWithDictionaryExactSize = deflate.probeZlibChunksWithDictionaryExactSize;
pub const probeZlibChunksWithOptionsExactSize = deflate.probeZlibChunksWithOptionsExactSize;
pub const probeZlibChunksWithDictionaryAndOptionsExactSize = deflate.probeZlibChunksWithDictionaryAndOptionsExactSize;
pub const probeZlibConcatenated = deflate.probeZlibConcatenated;
pub const probeZlibConcatenatedWithDictionary = deflate.probeZlibConcatenatedWithDictionary;
pub const probeZlibConcatenatedWithOptions = deflate.probeZlibConcatenatedWithOptions;
pub const probeZlibConcatenatedWithDictionaryAndOptions = deflate.probeZlibConcatenatedWithDictionaryAndOptions;
pub const probeZlibConcatenatedExactSize = deflate.probeZlibConcatenatedExactSize;
pub const probeZlibConcatenatedWithDictionaryExactSize = deflate.probeZlibConcatenatedWithDictionaryExactSize;
pub const probeZlibConcatenatedWithOptionsExactSize = deflate.probeZlibConcatenatedWithOptionsExactSize;
pub const probeZlibConcatenatedWithDictionaryAndOptionsExactSize = deflate.probeZlibConcatenatedWithDictionaryAndOptionsExactSize;
pub const probeZlibConcatenatedChunks = deflate.probeZlibConcatenatedChunks;
pub const probeZlibConcatenatedChunksWithDictionary = deflate.probeZlibConcatenatedChunksWithDictionary;
pub const probeZlibConcatenatedChunksWithOptions = deflate.probeZlibConcatenatedChunksWithOptions;
pub const probeZlibConcatenatedChunksWithDictionaryAndOptions = deflate.probeZlibConcatenatedChunksWithDictionaryAndOptions;
pub const probeZlibConcatenatedChunksExactSize = deflate.probeZlibConcatenatedChunksExactSize;
pub const probeZlibConcatenatedChunksWithDictionaryExactSize = deflate.probeZlibConcatenatedChunksWithDictionaryExactSize;
pub const probeZlibConcatenatedChunksWithOptionsExactSize = deflate.probeZlibConcatenatedChunksWithOptionsExactSize;
pub const probeZlibConcatenatedChunksWithDictionaryAndOptionsExactSize = deflate.probeZlibConcatenatedChunksWithDictionaryAndOptionsExactSize;
pub const decodedZlibSize = deflate.decodedZlibSize;
pub const decodedZlibSizeWithOptions = deflate.decodedZlibSizeWithOptions;
pub const decodedZlibSizeWithDictionary = deflate.decodedZlibSizeWithDictionary;
pub const decodedZlibSizeWithDictionaryAndOptions = deflate.decodedZlibSizeWithDictionaryAndOptions;
pub const decodedZlibChunksSize = deflate.decodedZlibChunksSize;
pub const decodedZlibChunksSizeWithOptions = deflate.decodedZlibChunksSizeWithOptions;
pub const decodedZlibChunksSizeWithDictionary = deflate.decodedZlibChunksSizeWithDictionary;
pub const decodedZlibChunksSizeWithDictionaryAndOptions = deflate.decodedZlibChunksSizeWithDictionaryAndOptions;
pub const decodedZlibConcatenatedSize = deflate.decodedZlibConcatenatedSize;
pub const decodedZlibConcatenatedSizeWithOptions = deflate.decodedZlibConcatenatedSizeWithOptions;
pub const decodedZlibConcatenatedSizeWithDictionary = deflate.decodedZlibConcatenatedSizeWithDictionary;
pub const decodedZlibConcatenatedSizeWithDictionaryAndOptions = deflate.decodedZlibConcatenatedSizeWithDictionaryAndOptions;
pub const decodedZlibConcatenatedChunksSize = deflate.decodedZlibConcatenatedChunksSize;
pub const decodedZlibConcatenatedChunksSizeWithOptions = deflate.decodedZlibConcatenatedChunksSizeWithOptions;
pub const decodedZlibConcatenatedChunksSizeWithDictionary = deflate.decodedZlibConcatenatedChunksSizeWithDictionary;
pub const decodedZlibConcatenatedChunksSizeWithDictionaryAndOptions = deflate.decodedZlibConcatenatedChunksSizeWithDictionaryAndOptions;
pub const decodeZlibAllocWithDictionary = deflate.decodeZlibAllocWithDictionary;
pub const decodeZlibAllocWithDictionaryExactSize = deflate.decodeZlibAllocWithDictionaryExactSize;
pub const decodeZlibAllocWithDictionaryLimited = deflate.decodeZlibAllocWithDictionaryLimited;
pub const decodeZlibAllocWithOptions = deflate.decodeZlibAllocWithOptions;
pub const decodeZlibAllocWithOptionsExactSize = deflate.decodeZlibAllocWithOptionsExactSize;
pub const decodeZlibAllocWithOptionsLimited = deflate.decodeZlibAllocWithOptionsLimited;
pub const decodeZlibAllocWithDictionaryAndOptions = deflate.decodeZlibAllocWithDictionaryAndOptions;
pub const decodeZlibAllocWithDictionaryAndOptionsExactSize = deflate.decodeZlibAllocWithDictionaryAndOptionsExactSize;
pub const decodeZlibAllocWithDictionaryAndOptionsLimited = deflate.decodeZlibAllocWithDictionaryAndOptionsLimited;
pub const decodeZlibChunksAlloc = deflate.decodeZlibChunksAlloc;
pub const decodeZlibChunksAllocExactSize = deflate.decodeZlibChunksAllocExactSize;
pub const decodeZlibChunksAllocLimited = deflate.decodeZlibChunksAllocLimited;
pub const decodeZlibChunksAllocWithDictionary = deflate.decodeZlibChunksAllocWithDictionary;
pub const decodeZlibChunksAllocWithDictionaryExactSize = deflate.decodeZlibChunksAllocWithDictionaryExactSize;
pub const decodeZlibChunksAllocWithDictionaryLimited = deflate.decodeZlibChunksAllocWithDictionaryLimited;
pub const decodeZlibChunksAllocWithOptions = deflate.decodeZlibChunksAllocWithOptions;
pub const decodeZlibChunksAllocWithOptionsExactSize = deflate.decodeZlibChunksAllocWithOptionsExactSize;
pub const decodeZlibChunksAllocWithOptionsLimited = deflate.decodeZlibChunksAllocWithOptionsLimited;
pub const decodeZlibChunksAllocWithDictionaryAndOptions = deflate.decodeZlibChunksAllocWithDictionaryAndOptions;
pub const decodeZlibChunksAllocWithDictionaryAndOptionsExactSize = deflate.decodeZlibChunksAllocWithDictionaryAndOptionsExactSize;
pub const decodeZlibChunksAllocWithDictionaryAndOptionsLimited = deflate.decodeZlibChunksAllocWithDictionaryAndOptionsLimited;
pub const decodeZlibChunksAppend = deflate.decodeZlibChunksAppend;
pub const decodeZlibChunksAppendWithDictionary = deflate.decodeZlibChunksAppendWithDictionary;
pub const decodeZlibChunksAppendWithOptions = deflate.decodeZlibChunksAppendWithOptions;
pub const decodeZlibChunksAppendWithDictionaryAndOptions = deflate.decodeZlibChunksAppendWithDictionaryAndOptions;
pub const decodeZlibChunksAppendExactSize = deflate.decodeZlibChunksAppendExactSize;
pub const decodeZlibChunksAppendWithDictionaryExactSize = deflate.decodeZlibChunksAppendWithDictionaryExactSize;
pub const decodeZlibChunksAppendWithOptionsExactSize = deflate.decodeZlibChunksAppendWithOptionsExactSize;
pub const decodeZlibChunksAppendWithDictionaryAndOptionsExactSize = deflate.decodeZlibChunksAppendWithDictionaryAndOptionsExactSize;
pub const decodeZlibChunksAppendLimited = deflate.decodeZlibChunksAppendLimited;
pub const decodeZlibChunksAppendWithDictionaryLimited = deflate.decodeZlibChunksAppendWithDictionaryLimited;
pub const decodeZlibChunksAppendWithOptionsLimited = deflate.decodeZlibChunksAppendWithOptionsLimited;
pub const decodeZlibChunksAppendWithDictionaryAndOptionsLimited = deflate.decodeZlibChunksAppendWithDictionaryAndOptionsLimited;
pub const encodeGzipStored = deflate.encodeGzipStored;
pub const encodeGzipFixedAlloc = deflate.encodeGzipFixedAlloc;
pub const encodeGzipFixedAppend = deflate.encodeGzipFixedAppend;
pub const encodeGzipBestAlloc = deflate.encodeGzipBestAlloc;
pub const encodeGzipBestAppend = deflate.encodeGzipBestAppend;
pub const encodeGzipLevelAlloc = deflate.encodeGzipLevelAlloc;
pub const encodeGzipLevelAppend = deflate.encodeGzipLevelAppend;
pub const encodeGzipBestSplitAlloc = deflate.encodeGzipBestSplitAlloc;
pub const encodeGzipBestSplitAppend = deflate.encodeGzipBestSplitAppend;
pub const encodeGzipBestAdaptiveSplitAlloc = deflate.encodeGzipBestAdaptiveSplitAlloc;
pub const encodeGzipBestAdaptiveSplitAppend = deflate.encodeGzipBestAdaptiveSplitAppend;
pub const GzipEncoder = deflate.GzipEncoder;
pub const GzipDecoder = deflate.GzipDecoder;
pub const GzipDecodeOptions = deflate.GzipDecodeOptions;
pub const GzipHeaderOptions = deflate.GzipHeaderOptions;
pub const GzipHeaderInfo = deflate.GzipHeaderInfo;
pub const GzipMemberInfo = deflate.GzipMemberInfo;
pub const parseGzipHeaderInfo = deflate.parseGzipHeaderInfo;
pub const parseGzipHeaderInfoFromChunks = deflate.parseGzipHeaderInfoFromChunks;
pub const inspectGzipMemberAlloc = deflate.inspectGzipMemberAlloc;
pub const inspectGzipMemberAllocLimited = deflate.inspectGzipMemberAllocLimited;
pub const inspectGzipMemberFromChunksAlloc = deflate.inspectGzipMemberFromChunksAlloc;
pub const inspectGzipMemberFromChunksAllocLimited = deflate.inspectGzipMemberFromChunksAllocLimited;
pub const gzipStoredEncodedSize = deflate.gzipStoredEncodedSize;
pub const gzipStoredEncodedSizeWithHeader = deflate.gzipStoredEncodedSizeWithHeader;
pub const gzipStoredChunksEncodedSize = deflate.gzipStoredChunksEncodedSize;
pub const gzipStoredChunksEncodedSizeWithHeader = deflate.gzipStoredChunksEncodedSizeWithHeader;
pub const encodeGzipStoredWithHeader = deflate.encodeGzipStoredWithHeader;
pub const encodeGzipStoredChunks = deflate.encodeGzipStoredChunks;
pub const encodeGzipStoredChunksWithHeader = deflate.encodeGzipStoredChunksWithHeader;
pub const encodeGzipStoredWithHeaderAlloc = deflate.encodeGzipStoredWithHeaderAlloc;
pub const encodeGzipStoredChunksWithHeaderAlloc = deflate.encodeGzipStoredChunksWithHeaderAlloc;
pub const encodeGzipStoredWithHeaderAppend = deflate.encodeGzipStoredWithHeaderAppend;
pub const encodeGzipStoredChunksWithHeaderAppend = deflate.encodeGzipStoredChunksWithHeaderAppend;
pub const encodeGzipFixedWithHeaderAlloc = deflate.encodeGzipFixedWithHeaderAlloc;
pub const encodeGzipFixedWithHeaderAppend = deflate.encodeGzipFixedWithHeaderAppend;
pub const encodeGzipFixedSplitWithHeaderAlloc = deflate.encodeGzipFixedSplitWithHeaderAlloc;
pub const encodeGzipFixedSplitWithHeaderAppend = deflate.encodeGzipFixedSplitWithHeaderAppend;
pub const encodeGzipDynamicLiteralWithHeaderAlloc = deflate.encodeGzipDynamicLiteralWithHeaderAlloc;
pub const encodeGzipDynamicLiteralWithHeaderAppend = deflate.encodeGzipDynamicLiteralWithHeaderAppend;
pub const encodeGzipDynamicWithHeaderAlloc = deflate.encodeGzipDynamicWithHeaderAlloc;
pub const encodeGzipDynamicWithHeaderAppend = deflate.encodeGzipDynamicWithHeaderAppend;
pub const encodeGzipDynamicSplitWithHeaderAlloc = deflate.encodeGzipDynamicSplitWithHeaderAlloc;
pub const encodeGzipDynamicSplitWithHeaderAppend = deflate.encodeGzipDynamicSplitWithHeaderAppend;
pub const encodeGzipBestWithHeaderAlloc = deflate.encodeGzipBestWithHeaderAlloc;
pub const encodeGzipBestWithHeaderAppend = deflate.encodeGzipBestWithHeaderAppend;
pub const encodeGzipLevelWithHeaderAlloc = deflate.encodeGzipLevelWithHeaderAlloc;
pub const encodeGzipLevelWithHeaderAppend = deflate.encodeGzipLevelWithHeaderAppend;
pub const encodeGzipBestSplitWithHeaderAlloc = deflate.encodeGzipBestSplitWithHeaderAlloc;
pub const encodeGzipBestSplitWithHeaderAppend = deflate.encodeGzipBestSplitWithHeaderAppend;
pub const encodeGzipBestAdaptiveSplitWithHeaderAlloc = deflate.encodeGzipBestAdaptiveSplitWithHeaderAlloc;
pub const encodeGzipBestAdaptiveSplitWithHeaderAppend = deflate.encodeGzipBestAdaptiveSplitWithHeaderAppend;
pub const encodeGzipDynamicLiteralAlloc = deflate.encodeGzipDynamicLiteralAlloc;
pub const encodeGzipDynamicLiteralAppend = deflate.encodeGzipDynamicLiteralAppend;
pub const encodeGzipDynamicWithOptionsAlloc = deflate.encodeGzipDynamicWithOptionsAlloc;
pub const encodeGzipDynamicWithOptionsAppend = deflate.encodeGzipDynamicWithOptionsAppend;
pub const encodeGzipDynamicSplitAlloc = deflate.encodeGzipDynamicSplitAlloc;
pub const encodeGzipDynamicSplitAppend = deflate.encodeGzipDynamicSplitAppend;
pub const encodeGzipFixedSplitAlloc = deflate.encodeGzipFixedSplitAlloc;
pub const encodeGzipFixedSplitAppend = deflate.encodeGzipFixedSplitAppend;
pub const encodeGzipFixedWithOptionsAlloc = deflate.encodeGzipFixedWithOptionsAlloc;
pub const encodeGzipFixedWithOptionsAppend = deflate.encodeGzipFixedWithOptionsAppend;
pub const decodeGzipStored = deflate.decodeGzipStored;
pub const encodeGzipStoredAlloc = deflate.encodeGzipStoredAlloc;
pub const encodeGzipStoredChunksAlloc = deflate.encodeGzipStoredChunksAlloc;
pub const encodeGzipStoredAppend = deflate.encodeGzipStoredAppend;
pub const encodeGzipStoredChunksAppend = deflate.encodeGzipStoredChunksAppend;
pub const decodeGzipStoredAlloc = deflate.decodeGzipStoredAlloc;
pub const decodeGzipStoredAllocExactSize = deflate.decodeGzipStoredAllocExactSize;
pub const decodeGzipStoredAllocLimited = deflate.decodeGzipStoredAllocLimited;
pub const decodeGzip = deflate.decodeGzip;
pub const decodeGzipWithOptions = deflate.decodeGzipWithOptions;
pub const decodeGzipAppend = deflate.decodeGzipAppend;
pub const decodeGzipAppendWithOptions = deflate.decodeGzipAppendWithOptions;
pub const decodeGzipAppendExactSize = deflate.decodeGzipAppendExactSize;
pub const decodeGzipAppendWithOptionsExactSize = deflate.decodeGzipAppendWithOptionsExactSize;
pub const decodeGzipAppendLimited = deflate.decodeGzipAppendLimited;
pub const decodeGzipAppendWithOptionsLimited = deflate.decodeGzipAppendWithOptionsLimited;
pub const decodeGzipChunks = deflate.decodeGzipChunks;
pub const decodeGzipChunksWithOptions = deflate.decodeGzipChunksWithOptions;
pub const decodeGzipChunksAlloc = deflate.decodeGzipChunksAlloc;
pub const decodeGzipChunksAllocExactSize = deflate.decodeGzipChunksAllocExactSize;
pub const decodeGzipChunksAllocLimited = deflate.decodeGzipChunksAllocLimited;
pub const decodeGzipChunksAllocWithOptions = deflate.decodeGzipChunksAllocWithOptions;
pub const decodeGzipChunksAllocWithOptionsExactSize = deflate.decodeGzipChunksAllocWithOptionsExactSize;
pub const decodeGzipChunksAllocWithOptionsLimited = deflate.decodeGzipChunksAllocWithOptionsLimited;
pub const decodeGzipChunksAppend = deflate.decodeGzipChunksAppend;
pub const decodeGzipChunksAppendWithOptions = deflate.decodeGzipChunksAppendWithOptions;
pub const decodeGzipChunksAppendExactSize = deflate.decodeGzipChunksAppendExactSize;
pub const decodeGzipChunksAppendWithOptionsExactSize = deflate.decodeGzipChunksAppendWithOptionsExactSize;
pub const decodeGzipChunksAppendLimited = deflate.decodeGzipChunksAppendLimited;
pub const decodeGzipChunksAppendWithOptionsLimited = deflate.decodeGzipChunksAppendWithOptionsLimited;
pub const decodeGzipAlloc = deflate.decodeGzipAlloc;
pub const decodeGzipAllocExactSize = deflate.decodeGzipAllocExactSize;
pub const decodeGzipAllocLimited = deflate.decodeGzipAllocLimited;
pub const decodeGzipAllocWithOptions = deflate.decodeGzipAllocWithOptions;
pub const decodeGzipAllocWithOptionsExactSize = deflate.decodeGzipAllocWithOptionsExactSize;
pub const decodeGzipAllocWithOptionsLimited = deflate.decodeGzipAllocWithOptionsLimited;
pub const decodeGzipConcatenated = deflate.decodeGzipConcatenated;
pub const decodeGzipConcatenatedWithOptions = deflate.decodeGzipConcatenatedWithOptions;
pub const decodeGzipConcatenatedChunks = deflate.decodeGzipConcatenatedChunks;
pub const decodeGzipConcatenatedChunksWithOptions = deflate.decodeGzipConcatenatedChunksWithOptions;
pub const decodeGzipConcatenatedChunksAlloc = deflate.decodeGzipConcatenatedChunksAlloc;
pub const decodeGzipConcatenatedChunksAllocExactSize = deflate.decodeGzipConcatenatedChunksAllocExactSize;
pub const decodeGzipConcatenatedChunksAllocLimited = deflate.decodeGzipConcatenatedChunksAllocLimited;
pub const decodeGzipConcatenatedChunksAllocWithOptions = deflate.decodeGzipConcatenatedChunksAllocWithOptions;
pub const decodeGzipConcatenatedChunksAllocWithOptionsExactSize = deflate.decodeGzipConcatenatedChunksAllocWithOptionsExactSize;
pub const decodeGzipConcatenatedChunksAllocWithOptionsLimited = deflate.decodeGzipConcatenatedChunksAllocWithOptionsLimited;
pub const decodeGzipConcatenatedAlloc = deflate.decodeGzipConcatenatedAlloc;
pub const decodeGzipConcatenatedAllocExactSize = deflate.decodeGzipConcatenatedAllocExactSize;
pub const decodeGzipConcatenatedAllocLimited = deflate.decodeGzipConcatenatedAllocLimited;
pub const decodeGzipConcatenatedAllocWithOptions = deflate.decodeGzipConcatenatedAllocWithOptions;
pub const decodeGzipConcatenatedAllocWithOptionsExactSize = deflate.decodeGzipConcatenatedAllocWithOptionsExactSize;
pub const decodeGzipConcatenatedAllocWithOptionsLimited = deflate.decodeGzipConcatenatedAllocWithOptionsLimited;
pub const decodeGzipConcatenatedAppend = deflate.decodeGzipConcatenatedAppend;
pub const decodeGzipConcatenatedAppendWithOptions = deflate.decodeGzipConcatenatedAppendWithOptions;
pub const decodeGzipConcatenatedAppendExactSize = deflate.decodeGzipConcatenatedAppendExactSize;
pub const decodeGzipConcatenatedAppendWithOptionsExactSize = deflate.decodeGzipConcatenatedAppendWithOptionsExactSize;
pub const decodeGzipConcatenatedAppendLimited = deflate.decodeGzipConcatenatedAppendLimited;
pub const decodeGzipConcatenatedAppendWithOptionsLimited = deflate.decodeGzipConcatenatedAppendWithOptionsLimited;
pub const decodeGzipConcatenatedChunksAppend = deflate.decodeGzipConcatenatedChunksAppend;
pub const decodeGzipConcatenatedChunksAppendWithOptions = deflate.decodeGzipConcatenatedChunksAppendWithOptions;
pub const decodeGzipConcatenatedChunksAppendExactSize = deflate.decodeGzipConcatenatedChunksAppendExactSize;
pub const decodeGzipConcatenatedChunksAppendWithOptionsExactSize = deflate.decodeGzipConcatenatedChunksAppendWithOptionsExactSize;
pub const decodeGzipConcatenatedChunksAppendLimited = deflate.decodeGzipConcatenatedChunksAppendLimited;
pub const decodeGzipConcatenatedChunksAppendWithOptionsLimited = deflate.decodeGzipConcatenatedChunksAppendWithOptionsLimited;
pub const probeGzip = deflate.probeGzip;
pub const probeGzipWithOptions = deflate.probeGzipWithOptions;
pub const probeGzipExactSize = deflate.probeGzipExactSize;
pub const probeGzipWithOptionsExactSize = deflate.probeGzipWithOptionsExactSize;
pub const probeGzipChunks = deflate.probeGzipChunks;
pub const probeGzipChunksWithOptions = deflate.probeGzipChunksWithOptions;
pub const probeGzipChunksExactSize = deflate.probeGzipChunksExactSize;
pub const probeGzipChunksWithOptionsExactSize = deflate.probeGzipChunksWithOptionsExactSize;
pub const probeGzipConcatenated = deflate.probeGzipConcatenated;
pub const probeGzipConcatenatedWithOptions = deflate.probeGzipConcatenatedWithOptions;
pub const probeGzipConcatenatedExactSize = deflate.probeGzipConcatenatedExactSize;
pub const probeGzipConcatenatedWithOptionsExactSize = deflate.probeGzipConcatenatedWithOptionsExactSize;
pub const probeGzipConcatenatedChunks = deflate.probeGzipConcatenatedChunks;
pub const probeGzipConcatenatedChunksWithOptions = deflate.probeGzipConcatenatedChunksWithOptions;
pub const probeGzipConcatenatedChunksExactSize = deflate.probeGzipConcatenatedChunksExactSize;
pub const probeGzipConcatenatedChunksWithOptionsExactSize = deflate.probeGzipConcatenatedChunksWithOptionsExactSize;
pub const decodedGzipSize = deflate.decodedGzipSize;
pub const decodedGzipSizeWithOptions = deflate.decodedGzipSizeWithOptions;
pub const decodedGzipChunksSize = deflate.decodedGzipChunksSize;
pub const decodedGzipChunksSizeWithOptions = deflate.decodedGzipChunksSizeWithOptions;
pub const decodedGzipConcatenatedSize = deflate.decodedGzipConcatenatedSize;
pub const decodedGzipConcatenatedSizeWithOptions = deflate.decodedGzipConcatenatedSizeWithOptions;
pub const decodedGzipConcatenatedChunksSize = deflate.decodedGzipConcatenatedChunksSize;
pub const decodedGzipConcatenatedChunksSizeWithOptions = deflate.decodedGzipConcatenatedChunksSizeWithOptions;

pub const Lz77Token = lz77.Token;
pub const fixedLz77BitCost = lz77.fixedBitCost;
pub const hashGreedyLz77PlanAlloc = lz77.hashGreedyPlanAlloc;
pub const greedyLz77PlanAlloc = lz77.greedyPlanAlloc;
pub const lazyGreedyLz77PlanAlloc = lz77.lazyGreedyPlanAlloc;
pub const filteredLz77PlanAlloc = lz77.filteredPlanAlloc;
pub const literalLz77PlanAlloc = lz77.literalPlanAlloc;
pub const runLengthLz77PlanAlloc = lz77.runLengthPlanAlloc;
pub const optimalLz77PlanAlloc = lz77.optimalPlanAlloc;

pub const DictionaryId = dictionary.DictionaryId;
pub const DictionaryMetadata = dictionary.Metadata;
pub const DictionaryMetadataDecodeResult = dictionary.MetadataDecodeResult;
pub const DictionaryMetadataCatalogDecodeResult = dictionary.MetadataCatalogDecodeResult;
pub const DictionaryMetadataCatalogAllocDecodeResult = dictionary.MetadataCatalogAllocDecodeResult;
pub const dictionaryMetadataEncodedLen = dictionary.metadata_encoded_len;
pub const dictionaryMetadataCatalogHeaderEncodedLen = dictionary.metadata_catalog_header_encoded_len;
pub const encodeDictionaryMetadataAlloc = dictionary.encodeMetadataAlloc;
pub const encodeDictionaryMetadataInto = dictionary.encodeMetadataInto;
pub const decodeDictionaryMetadata = dictionary.decodeMetadata;
pub const decodeDictionaryMetadataPrefix = dictionary.decodeMetadataPrefix;
pub const encodedDictionaryMetadataCatalogLen = dictionary.encodedMetadataCatalogLen;
pub const encodeDictionaryMetadataCatalogAlloc = dictionary.encodeMetadataCatalogAlloc;
pub const encodeDictionaryMetadataCatalogInto = dictionary.encodeMetadataCatalogInto;
pub const decodedDictionaryMetadataCatalogCount = dictionary.decodedMetadataCatalogCount;
pub const decodeDictionaryMetadataCatalogAlloc = dictionary.decodeMetadataCatalogAlloc;
pub const decodeDictionaryMetadataCatalogInto = dictionary.decodeMetadataCatalogInto;
pub const decodeDictionaryMetadataCatalogPrefixAlloc = dictionary.decodeMetadataCatalogPrefixAlloc;
pub const decodeDictionaryMetadataCatalogPrefixInto = dictionary.decodeMetadataCatalogPrefixInto;
pub const trainDictionaryAlloc = dictionary.trainAlloc;
pub const findDictionaryMatchesAlloc = dictionary.findMatchesAlloc;
pub const summarizeDictionaryMatchesAlloc = dictionary.summarizeMatchesAlloc;
pub const summarizeDictionaryMatches = dictionary.summarizeMatches;
pub const encodeDictionaryPatchAlloc = dictionary.encodePatchAlloc;
pub const decodedDictionaryPatchSize = dictionary.decodedPatchSize;
pub const maxDictionaryPatchSizeForDecodedLen = dictionary.maxPatchSizeForDecodedLen;
pub const decodeDictionaryPatch = dictionary.decodePatch;
pub const decodeDictionaryPatchInto = dictionary.decodePatchInto;
pub const decodeDictionaryPatchAlloc = dictionary.decodePatchAlloc;
pub const findLongDistanceCandidatesAlloc = long_distance.findCandidatesAlloc;
pub const summarizeLongDistanceAlloc = long_distance.summarizeAlloc;
pub const planBlocksAlloc = planner.planBlocksAlloc;
pub const planBlocksWithLongDistanceAlloc = planner.planBlocksWithLongDistanceAlloc;
pub const planBlocksAligningLongDistanceAlloc = planner.planBlocksAligningLongDistanceAlloc;

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
    _ = lz4;
    _ = zstd;
    _ = zip;
    _ = bzip2;
    _ = xz;
    _ = lzma;
    _ = tar;
    _ = compress_z;
    _ = lzip;
    _ = lzo1x;
    _ = lzop;
    _ = seven_zip;
}

test "root 7z exports create list and extract Copy archives" {
    const entries = [_]SevenZipEncodeEntry{
        .{ .name = "hello.txt", .data = "seven zip root API" },
        .{ .name = "empty", .kind = .directory },
    };
    const encoded = try encodeSevenZipStoredAlloc(std.testing.allocator, &entries, .{});
    defer std.testing.allocator.free(encoded);
    const archive = try parseSevenZipArchiveAlloc(std.testing.allocator, encoded);
    defer archive.deinit();
    try std.testing.expectEqual(@as(usize, 2), archive.entries.len);
    const decoded = try sevenZipExtractByNameAlloc(std.testing.allocator, encoded, "hello.txt");
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, entries[0].data, decoded);
}

test "root Unix compress exports round trip .Z streams" {
    const input = "Vort Unix compress root API" ** 32;
    const encoded = try encodeCompressZAlloc(std.testing.allocator, input, .{
        .max_code_bits = 12,
        .block_mode = true,
    });
    defer std.testing.allocator.free(encoded);
    const header = try parseCompressZHeader(encoded);
    try std.testing.expectEqual(@as(u5, 12), header.max_code_bits);
    try std.testing.expect(header.block_mode);
    const decoded = try decodeCompressZAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}

test "root lzip exports decode reference members" {
    const encoded_hex = "4c5a4950010c00341949ee8de9148a6a3e85eb7b90eba1fffffbfde0003a319d3216000000000000003100000000000000";
    var encoded: [encoded_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&encoded, encoded_hex);
    const info = try inspectLzip(std.testing.allocator, &encoded);
    try std.testing.expectEqual(@as(usize, 1), info.member_count);
    const decoded = try decodeLzipAlloc(std.testing.allocator, &encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "hello lzip\nhello lzip\n", decoded);
}

test "root LZOP exports round trip stored blocks" {
    const input = "Vort LZOP root API" ** 32;
    const encoded = try encodeLzopStoredAlloc(std.testing.allocator, input, .{ .block_size = 128 });
    defer std.testing.allocator.free(encoded);
    const info = try inspectLzop(encoded);
    try std.testing.expectEqual(@as(usize, 1), info.stream_count);
    const decoded = try decodeLzopAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}

test "root exports lz4 and zstd codec helpers" {
    // The codec modules remain available as namespaces, while these aliases keep
    // the one-shot and caller-owned native surfaces discoverable from `vort`.
    _ = DictionaryId;
    _ = DictionaryMetadata;
    _ = DictionaryMetadataDecodeResult;
    _ = DictionaryMetadataCatalogDecodeResult;
    _ = DictionaryMetadataCatalogAllocDecodeResult;
    _ = dictionaryMetadataEncodedLen;
    _ = dictionaryMetadataCatalogHeaderEncodedLen;
    _ = encodeDictionaryMetadataAlloc;
    _ = encodeDictionaryMetadataInto;
    _ = decodeDictionaryMetadata;
    _ = decodeDictionaryMetadataPrefix;
    _ = encodedDictionaryMetadataCatalogLen;
    _ = encodeDictionaryMetadataCatalogAlloc;
    _ = encodeDictionaryMetadataCatalogInto;
    _ = decodedDictionaryMetadataCatalogCount;
    _ = decodeDictionaryMetadataCatalogAlloc;
    _ = decodeDictionaryMetadataCatalogInto;
    _ = decodeDictionaryMetadataCatalogPrefixAlloc;
    _ = decodeDictionaryMetadataCatalogPrefixInto;
    _ = trainDictionaryAlloc;
    _ = findDictionaryMatchesAlloc;
    _ = summarizeDictionaryMatchesAlloc;
    _ = summarizeDictionaryMatches;
    _ = encodeDictionaryPatchAlloc;
    _ = decodedDictionaryPatchSize;
    _ = maxDictionaryPatchSizeForDecodedLen;
    _ = decodeDictionaryPatch;
    _ = decodeDictionaryPatchInto;
    _ = decodeDictionaryPatchAlloc;

    _ = BrotliError;
    _ = BrotliDecodeOptions;
    try std.testing.expectEqual(@as(usize, 1 << 24), brotliMaxUncompressedMetaBlockLen);
    try std.testing.expectEqual(@as(u5, 16), brotliDefaultWindowBits);
    _ = brEncodedStoredStreamBound;
    _ = brEncodedStoredStreamBoundWithOptions;
    _ = brEncodedStoredStreamChunksBound;
    _ = brEncodedStoredStreamChunksBoundWithOptions;
    _ = brEncodeStoredStreamAlloc;
    _ = brEncodeStoredStreamAppend;
    _ = brEncodeStoredStreamInto;
    _ = brEncodeStoredStreamWithOptionsAlloc;
    _ = brEncodeStoredStreamWithOptionsAppend;
    _ = brEncodeStoredStreamWithOptionsInto;
    _ = brEncodeStoredStreamChunksAlloc;
    _ = brEncodeStoredStreamChunksAppend;
    _ = brEncodeStoredStreamChunksInto;
    _ = brEncodeStoredStreamChunksWithOptionsAlloc;
    _ = brEncodeStoredStreamChunksWithOptionsAppend;
    _ = brEncodeStoredStreamChunksWithOptionsInto;
    _ = brEncodedPlannedStreamChunksBound;
    _ = brEncodePlannedStreamChunksAlloc;
    _ = brEncodePlannedStreamChunksAppend;
    _ = brEncodePlannedStreamChunksInto;
    _ = BrotliStoredStreamOptions;
    _ = BrotliStreamSummary;
    _ = BrotliStreamSummaryDiagnostics;
    _ = BrotliStreamSummaryErrorPhase;
    _ = BrotliStreamProbeResult;
    _ = BrotliStaticDictionaryEntry;
    _ = BrotliCompressedSupportLimits;
    _ = BrotliPrefixCode;
    _ = BrotliStoredStreamEncoder;
    _ = BrotliIncrementalPlannedStreamEncoder;
    _ = BrotliStreamDecoder;
    _ = brCompressedSupportLimits;
    _ = brMinimalStaticDictionaryCoverage;
    _ = brMinimalStaticDictionarySizeBits;
    _ = brDecodeStreamAlloc;
    _ = brDecodeStreamAllocWithOptions;
    _ = brDecodeStreamAllocExactSize;
    _ = brDecodeStreamAllocExactSizeWithOptions;
    _ = brDecodeStreamAllocLimited;
    _ = brDecodeStreamAllocLimitedWithOptions;
    _ = brDecodeStreamAppend;
    _ = brDecodeStreamAppendWithOptions;
    _ = brDecodeStreamAppendExactSize;
    _ = brDecodeStreamAppendExactSizeWithOptions;
    _ = brDecodeStreamAppendLimited;
    _ = brDecodeStreamAppendLimitedWithOptions;
    _ = brDecodeStreamInto;
    _ = brDecodeStreamIntoWithOptions;
    _ = brDecodeStreamIntoExactSize;
    _ = brDecodeStreamIntoExactSizeWithOptions;
    _ = brDecodeStreamIntoLimited;
    _ = brDecodeStreamIntoLimitedWithOptions;
    _ = brDecodedStreamSize;
    _ = brDecodedStreamSizeWithOptions;
    _ = brDecodedStreamSizeLimited;
    _ = brDecodedStreamSizeLimitedWithOptions;
    _ = brSummarizeStream;
    _ = brSummarizeStreamWithOptions;
    _ = brSummarizeStreamLimited;
    _ = brSummarizeStreamLimitedWithOptions;
    _ = brSummarizeStreamLimitedWithOptionsAndDiagnostics;
    _ = brSummarizeStreamWithDiagnostics;
    _ = brSummarizeStreamWithOptionsAndDiagnostics;
    _ = brSummarizeStreamLimitedWithDiagnostics;
    _ = brSummarizeStreamWithHistory;
    _ = brSummarizeStreamWithHistoryAndOptions;
    _ = brSummarizeStreamLimitedWithHistory;
    _ = brSummarizeStreamLimitedWithHistoryAndOptions;
    _ = brSummarizeStreamWithHistoryAndDiagnostics;
    _ = brSummarizeStreamWithHistoryAndOptionsAndDiagnostics;
    _ = brSummarizeStreamLimitedWithHistoryAndDiagnostics;
    _ = brSummarizeStreamLimitedWithHistoryAndOptionsAndDiagnostics;
    _ = brSummarizeStreamAlloc;
    _ = brSummarizeStreamAllocWithOptions;
    _ = brSummarizeStreamAllocLimited;
    _ = brSummarizeStreamAllocLimitedWithOptions;
    _ = brSummarizeStreamAllocWithDiagnostics;
    _ = brSummarizeStreamAllocWithOptionsAndDiagnostics;
    _ = brSummarizeStreamAllocLimitedWithDiagnostics;
    _ = brSummarizeStreamAllocLimitedWithOptionsAndDiagnostics;
    _ = brProbeStream;
    _ = brProbeStreamWithOptions;
    _ = brProbeStreamLimited;
    _ = brProbeStreamLimitedWithOptions;
    _ = brProbeStreamExactSize;
    _ = brProbeStreamExactSizeWithOptions;
    _ = brDecodeStreamChunksAlloc;
    _ = brDecodeStreamChunksAllocWithOptions;
    _ = brDecodeStreamChunksAllocExactSize;
    _ = brDecodeStreamChunksAllocExactSizeWithOptions;
    _ = brDecodeStreamChunksAllocLimited;
    _ = brDecodeStreamChunksAllocLimitedWithOptions;
    _ = brDecodeStreamChunksAppend;
    _ = brDecodeStreamChunksAppendWithOptions;
    _ = brDecodeStreamChunksAppendExactSize;
    _ = brDecodeStreamChunksAppendExactSizeWithOptions;
    _ = brDecodeStreamChunksAppendLimited;
    _ = brDecodeStreamChunksAppendLimitedWithOptions;
    _ = brDecodeStreamChunksInto;
    _ = brDecodeStreamChunksIntoWithOptions;
    _ = brDecodeStreamChunksIntoExactSize;
    _ = brDecodeStreamChunksIntoExactSizeWithOptions;
    _ = brDecodeStreamChunksIntoLimited;
    _ = brDecodeStreamChunksIntoLimitedWithOptions;
    _ = brDecodedStreamChunksSize;
    _ = brDecodedStreamChunksSizeWithOptions;
    _ = brDecodedStreamChunksSizeLimited;
    _ = brDecodedStreamChunksSizeLimitedWithOptions;
    _ = brSummarizeStreamChunks;
    _ = brSummarizeStreamChunksWithOptions;
    _ = brSummarizeStreamChunksLimited;
    _ = brSummarizeStreamChunksLimitedWithOptions;
    _ = brSummarizeStreamChunksWithDiagnostics;
    _ = brSummarizeStreamChunksWithOptionsAndDiagnostics;
    _ = brSummarizeStreamChunksLimitedWithDiagnostics;
    _ = brSummarizeStreamChunksLimitedWithOptionsAndDiagnostics;
    _ = brSummarizeStreamChunksWithHistory;
    _ = brSummarizeStreamChunksWithHistoryAndOptions;
    _ = brSummarizeStreamChunksLimitedWithHistory;
    _ = brSummarizeStreamChunksLimitedWithHistoryAndOptions;
    _ = brSummarizeStreamChunksWithHistoryAndDiagnostics;
    _ = brSummarizeStreamChunksWithHistoryAndOptionsAndDiagnostics;
    _ = brSummarizeStreamChunksLimitedWithHistoryAndDiagnostics;
    _ = brSummarizeStreamChunksLimitedWithHistoryAndOptionsAndDiagnostics;
    _ = brProbeStreamChunks;
    _ = brProbeStreamChunksWithOptions;
    _ = brProbeStreamChunksLimited;
    _ = brProbeStreamChunksLimitedWithOptions;
    _ = brProbeStreamChunksExactSize;
    _ = brProbeStreamChunksExactSizeWithOptions;

    _ = SnappyError;
    try std.testing.expectEqual(@as(usize, 64 * 1024), snappyMaxUncompressedChunkLen);
    _ = snappyEncodeBlockAlloc;
    _ = snappyEncodeBlockAppend;
    _ = snappyEncodeBlockInto;
    _ = snappyEncodedBlockBound;
    _ = snappyEncodeFrameAlloc;
    _ = snappyEncodeFrameAppend;
    _ = snappyEncodeFrameInto;
    _ = snappyEncodedFrameBound;
    _ = SnappyEncoder;
    _ = SnappyFrameSummary;
    _ = SnappyBlockSummary;
    _ = snappySummarizeBlock;
    _ = snappySummarizeBlockLimited;
    _ = snappySummarizeBlockChunks;
    _ = snappySummarizeFrame;
    _ = snappySummarizeFrameChunks;
    _ = snappyDecodeBlockAlloc;
    _ = snappyDecodeBlockAllocExactSize;
    _ = snappyDecodeBlockAllocLimited;
    _ = snappyDecodeBlockAppend;
    _ = snappyDecodeBlockAppendExactSize;
    _ = snappyDecodeBlockAppendLimited;
    _ = snappyDecodeBlockInto;
    _ = snappyDecodeBlockIntoExactSize;
    _ = snappyDecodedBlockSize;
    _ = snappyDecodedBlockSizeLimited;
    _ = snappyDecodeBlockChunksAlloc;
    _ = snappyDecodeBlockChunksAllocExactSize;
    _ = snappyDecodeBlockChunksAllocLimited;
    _ = snappyDecodeBlockChunksAppend;
    _ = snappyDecodeBlockChunksAppendExactSize;
    _ = snappyDecodeBlockChunksAppendLimited;
    _ = snappyDecodeBlockChunksInto;
    _ = snappyDecodeBlockChunksIntoExactSize;
    _ = snappyDecodedBlockChunksSize;
    _ = snappyDecodedBlockChunksSizeLimited;
    _ = snappyDecodeFrameAlloc;
    _ = snappyDecodeFrameAllocExactSize;
    _ = snappyDecodeFrameAllocLimited;
    _ = snappyDecodeFrameAppend;
    _ = snappyDecodeFrameAppendExactSize;
    _ = snappyDecodeFrameAppendLimited;
    _ = snappyDecodeFrameInto;
    _ = snappyDecodeFrameIntoExactSize;
    _ = snappyDecodedFrameSize;
    _ = snappyDecodedFrameSizeLimited;
    _ = snappyDecodeFrameChunksAlloc;
    _ = snappyDecodeFrameChunksAllocExactSize;
    _ = snappyDecodeFrameChunksAllocLimited;
    _ = snappyDecodeFrameChunksAppend;
    _ = snappyDecodeFrameChunksAppendExactSize;
    _ = snappyDecodeFrameChunksAppendLimited;
    _ = snappyDecodeFrameChunksInto;
    _ = snappyDecodeFrameChunksIntoExactSize;
    _ = snappyDecodedFrameChunksSize;
    _ = snappyDecodedFrameChunksSizeLimited;

    _ = Lz4Error;
    try std.testing.expectEqual(@as(c_int, 10), lz4DefaultCompressionLevel);
    _ = lz4EncodeFrameAlloc;
    _ = lz4EncodeFrameWithLevelAlloc;
    _ = lz4EncodeFrameWithOptionsAlloc;
    _ = lz4EncodeFrameWithLevelAndOptionsAlloc;
    _ = lz4EncodePureFrameAlloc;
    _ = lz4EncodePureFrameWithOptionsAlloc;
    _ = lz4EncodePureFrameAppend;
    _ = lz4EncodeNativeFrameAlloc;
    _ = lz4EncodeNativeFrameWithOptionsAlloc;
    _ = lz4EncodeNativeFrameAppend;
    _ = lz4EncodeNativeFrameIntoSlice;
    _ = lz4EncodedSkippableFrameBound;
    _ = lz4EncodeSkippableFrameAlloc;
    _ = lz4EncodeSkippableFrameAppend;
    _ = lz4EncodeSkippableFrameIntoSlice;
    _ = Lz4FrameOptions;
    _ = Lz4NativeFrameOptions;
    _ = lz4NativeMaxChainDepth;
    _ = Lz4NativeFrameHeader;
    _ = Lz4NativeFrameBlockHeader;
    _ = Lz4NativeFrameBlockSummary;
    _ = Lz4BlockSummary;
    _ = Lz4NativeStreamSummary;
    _ = Lz4NativeStreamSummaryErrorDiagnostics;
    _ = Lz4NativeStreamSummaryErrorPhase;
    _ = Lz4NativeSkippableFrameHeader;
    _ = lz4NativeDictionaryWindowLen;
    _ = lz4InspectNativeFrameHeader;
    _ = lz4InspectNativeFrameFirstBlock;
    _ = lz4InspectNativeFrameBlockAt;
    _ = lz4SummarizeNativeFrameBlocks;
    _ = lz4SummarizeNativeStream;
    _ = lz4SummarizeNativeStreamWithDiagnostics;
    _ = lz4InspectNativeSkippableFrame;
    _ = Lz4BlockSizeId;
    _ = Lz4BlockMode;
    _ = Lz4BlockEncoder;
    _ = Lz4BlockDecoder;
    _ = Lz4NativeFrameEncoder;
    _ = Lz4NativeFrameDecoder;
    _ = Lz4NativeIncrementalFrameDecoder;
    _ = Lz4NativeDictionary;
    _ = Lz4NativeDictionaryTrainOptions;
    _ = Lz4OwnedNativeDictionary;
    _ = Lz4NativeDictionarySet;
    _ = Lz4OwnedNativeDictionarySet;
    _ = lz4TrainNativeDictionaryAlloc;
    _ = lz4NativeDictionarySetFromMetadataAlloc;
    _ = lz4DecodeFrameAlloc;
    _ = lz4DecodeFrameAppend;
    _ = lz4DecodeFrameAppendExactSize;
    _ = lz4DecodeFrameAppendLimited;
    _ = lz4DecodeFrameAllocLimited;
    _ = lz4DecodeFrameAllocExactSize;
    _ = lz4DecodeFrameAllocWithDictionary;
    _ = lz4DecodeFrameAppendWithDictionary;
    _ = lz4DecodeFrameAppendExactSizeWithDictionary;
    _ = lz4DecodeFrameAppendLimitedWithDictionary;
    _ = lz4DecodeFrameAllocLimitedWithDictionary;
    _ = lz4DecodeFrameAllocWithDictionaryExactSize;
    _ = lz4DecodeFrameIntoWithDictionary;
    _ = lz4DecodeFrameIntoWithDictionaryExactSize;
    _ = lz4DecodedFrameSizeWithDictionary;
    _ = lz4DecodedFrameSizeLimitedWithDictionary;
    _ = lz4DecodeFrameAllocWithDictionarySetExactSize;
    _ = lz4DecodedFrameSize;
    _ = lz4DecodedFrameSizeLimited;
    _ = lz4DecodeFrameInto;
    _ = lz4DecodeFrameIntoExactSize;
    _ = lz4DecodeFrameAllocWithDictionarySet;
    _ = lz4DecodeFrameAppendWithDictionarySet;
    _ = lz4DecodeFrameAppendExactSizeWithDictionarySet;
    _ = lz4DecodeFrameAppendLimitedWithDictionarySet;
    _ = lz4DecodeFrameAllocLimitedWithDictionarySet;
    _ = lz4DecodeFrameIntoWithDictionarySet;
    _ = lz4DecodeFrameIntoWithDictionarySetExactSize;
    _ = lz4DecodedFrameSizeWithDictionarySet;
    _ = lz4DecodedFrameSizeLimitedWithDictionarySet;
    _ = lz4DecodeFrameChunksAlloc;
    _ = lz4DecodeFrameChunksAllocExactSize;
    _ = lz4DecodeFrameChunksAllocLimited;
    _ = lz4DecodeFrameChunksAppend;
    _ = lz4DecodeFrameChunksAppendExactSize;
    _ = lz4DecodeFrameChunksAppendLimited;
    _ = lz4DecodeFrameChunksInto;
    _ = lz4DecodeFrameChunksIntoExactSize;
    _ = lz4DecodedFrameChunksSize;
    _ = lz4DecodedFrameChunksSizeLimited;
    _ = lz4DecodeFrameChunksAllocWithDictionary;
    _ = lz4DecodeFrameChunksAllocWithDictionaryExactSize;
    _ = lz4DecodeFrameChunksAllocWithDictionaryLimited;
    _ = lz4DecodeFrameChunksAppendWithDictionary;
    _ = lz4DecodeFrameChunksAppendExactSizeWithDictionary;
    _ = lz4DecodeFrameChunksAppendLimitedWithDictionary;
    _ = lz4DecodeFrameChunksIntoWithDictionary;
    _ = lz4DecodeFrameChunksIntoWithDictionaryExactSize;
    _ = lz4DecodedFrameChunksSizeWithDictionary;
    _ = lz4DecodedFrameChunksSizeLimitedWithDictionary;
    _ = lz4DecodeFrameChunksAllocWithDictionarySet;
    _ = lz4DecodeFrameChunksAllocWithDictionarySetExactSize;
    _ = lz4DecodeFrameChunksAllocWithDictionarySetLimited;
    _ = lz4DecodeFrameChunksAppendWithDictionarySet;
    _ = lz4DecodeFrameChunksAppendExactSizeWithDictionarySet;
    _ = lz4DecodeFrameChunksAppendLimitedWithDictionarySet;
    _ = lz4DecodeFrameChunksIntoWithDictionarySet;
    _ = lz4DecodeFrameChunksIntoWithDictionarySetExactSize;
    _ = lz4DecodedFrameChunksSizeWithDictionarySet;
    _ = lz4DecodedFrameChunksSizeLimitedWithDictionarySet;
    _ = lz4DecodeNativeFrameAlloc;
    _ = lz4DecodeNativeFrameAppend;
    _ = lz4DecodeNativeFrameAppendExactSize;
    _ = lz4DecodeNativeFrameAppendLimited;
    _ = lz4DecodeNativeFrameAllocLimited;
    _ = lz4DecodeNativeFrameAllocExactSize;
    _ = lz4DecodeNativeFrameIntoExactSize;
    _ = lz4DecodeNativeFrameAllocWithDictionary;
    _ = lz4DecodedNativeFrameSize;
    _ = lz4DecodedNativeFrameSizeLimited;
    _ = lz4DecodeNativeFrameAppendWithDictionary;
    _ = lz4DecodeNativeFrameAppendExactSizeWithDictionary;
    _ = lz4DecodeNativeFrameAppendLimitedWithDictionary;
    _ = lz4DecodeNativeFrameAllocLimitedWithDictionary;
    _ = lz4DecodeNativeFrameAllocWithDictionaryExactSize;
    _ = lz4DecodeNativeFrameIntoWithDictionaryExactSize;
    _ = lz4DecodeNativeFrameIntoWithDictionary;
    _ = lz4DecodedNativeFrameSizeWithDictionary;
    _ = lz4DecodedNativeFrameSizeLimitedWithDictionary;
    _ = lz4DecodeNativeFrameInto;
    _ = lz4DecodeNativeFrameAllocWithDictionarySet;
    _ = lz4DecodeNativeFrameAppendWithDictionarySet;
    _ = lz4DecodeNativeFrameAppendExactSizeWithDictionarySet;
    _ = lz4DecodeNativeFrameAppendLimitedWithDictionarySet;
    _ = lz4DecodeNativeFrameAllocLimitedWithDictionarySet;
    _ = lz4DecodeNativeFrameAllocWithDictionarySetExactSize;
    _ = lz4DecodeNativeFrameIntoWithDictionarySetExactSize;
    _ = lz4DecodeNativeFrameIntoWithDictionarySet;
    _ = lz4DecodedNativeFrameSizeWithDictionarySet;
    _ = lz4DecodedNativeFrameSizeLimitedWithDictionarySet;
    _ = lz4DecodeNativeFrameChunksAlloc;
    _ = lz4DecodeNativeFrameChunksAllocExactSize;
    _ = lz4DecodeNativeFrameChunksAllocLimited;
    _ = lz4DecodeNativeFrameChunksAppend;
    _ = lz4DecodeNativeFrameChunksAppendExactSize;
    _ = lz4DecodeNativeFrameChunksAppendLimited;
    _ = lz4DecodeNativeFrameChunksInto;
    _ = lz4DecodeNativeFrameChunksIntoExactSize;
    _ = lz4DecodedNativeFrameChunksSize;
    _ = lz4DecodedNativeFrameChunksSizeLimited;
    _ = lz4DecodeNativeFrameChunksAllocWithDictionary;
    _ = lz4DecodeNativeFrameChunksAllocWithDictionaryExactSize;
    _ = lz4DecodeNativeFrameChunksAllocWithDictionaryLimited;
    _ = lz4DecodeNativeFrameChunksAppendWithDictionary;
    _ = lz4DecodeNativeFrameChunksAppendExactSizeWithDictionary;
    _ = lz4DecodeNativeFrameChunksAppendLimitedWithDictionary;
    _ = lz4DecodeNativeFrameChunksIntoWithDictionary;
    _ = lz4DecodeNativeFrameChunksIntoExactSizeWithDictionary;
    _ = lz4DecodeNativeFrameChunksIntoWithDictionaryExactSize;
    _ = lz4DecodedNativeFrameChunksSizeWithDictionary;
    _ = lz4DecodedNativeFrameChunksSizeLimitedWithDictionary;
    _ = lz4DecodeNativeFrameChunksAllocWithDictionarySet;
    _ = lz4DecodeNativeFrameChunksAllocWithDictionarySetExactSize;
    _ = lz4DecodeNativeFrameChunksAllocWithDictionarySetLimited;
    _ = lz4DecodeNativeFrameChunksAppendWithDictionarySet;
    _ = lz4DecodeNativeFrameChunksAppendExactSizeWithDictionarySet;
    _ = lz4DecodeNativeFrameChunksAppendLimitedWithDictionarySet;
    _ = lz4DecodeNativeFrameChunksIntoWithDictionarySet;
    _ = lz4DecodeNativeFrameChunksIntoExactSizeWithDictionarySet;
    _ = lz4DecodeNativeFrameChunksIntoWithDictionarySetExactSize;
    _ = lz4DecodedNativeFrameChunksSizeWithDictionarySet;
    _ = lz4DecodedNativeFrameChunksSizeLimitedWithDictionarySet;
    _ = lz4DecodeConcatenatedFrameAlloc;
    _ = lz4DecodeConcatenatedFrameAppend;
    _ = lz4DecodeConcatenatedFrameAppendExactSize;
    _ = lz4DecodeConcatenatedFrameAppendLimited;
    _ = lz4DecodeConcatenatedFrameAllocLimited;
    _ = lz4DecodeConcatenatedFrameAllocExactSize;
    _ = lz4DecodeConcatenatedFrameAllocWithDictionary;
    _ = lz4DecodeConcatenatedFrameAppendWithDictionary;
    _ = lz4DecodeConcatenatedFrameAppendExactSizeWithDictionary;
    _ = lz4DecodeConcatenatedFrameAppendLimitedWithDictionary;
    _ = lz4DecodeConcatenatedFrameAllocLimitedWithDictionary;
    _ = lz4DecodeConcatenatedFrameAllocWithDictionaryExactSize;
    _ = lz4DecodeConcatenatedFrameIntoWithDictionary;
    _ = lz4DecodeConcatenatedFrameIntoWithDictionaryExactSize;
    _ = lz4DecodedConcatenatedFrameSizeWithDictionary;
    _ = lz4DecodedConcatenatedFrameSizeLimitedWithDictionary;
    _ = lz4DecodeConcatenatedFrameAllocWithDictionarySetExactSize;
    _ = lz4DecodedConcatenatedFrameSize;
    _ = lz4DecodedConcatenatedFrameSizeLimited;
    _ = lz4DecodeConcatenatedFrameInto;
    _ = lz4DecodeConcatenatedFrameIntoExactSize;
    _ = lz4DecodeConcatenatedFrameAllocWithDictionarySet;
    _ = lz4DecodeConcatenatedFrameAppendWithDictionarySet;
    _ = lz4DecodeConcatenatedFrameAppendExactSizeWithDictionarySet;
    _ = lz4DecodeConcatenatedFrameAppendLimitedWithDictionarySet;
    _ = lz4DecodeConcatenatedFrameAllocLimitedWithDictionarySet;
    _ = lz4DecodeConcatenatedFrameIntoWithDictionarySet;
    _ = lz4DecodeConcatenatedFrameIntoWithDictionarySetExactSize;
    _ = lz4DecodedConcatenatedFrameSizeWithDictionarySet;
    _ = lz4DecodedConcatenatedFrameSizeLimitedWithDictionarySet;
    _ = lz4DecodeConcatenatedFrameChunksAlloc;
    _ = lz4DecodeConcatenatedFrameChunksAllocExactSize;
    _ = lz4DecodeConcatenatedFrameChunksAllocLimited;
    _ = lz4DecodeConcatenatedFrameChunksAppend;
    _ = lz4DecodeConcatenatedFrameChunksAppendExactSize;
    _ = lz4DecodeConcatenatedFrameChunksAppendLimited;
    _ = lz4DecodeConcatenatedFrameChunksInto;
    _ = lz4DecodeConcatenatedFrameChunksIntoExactSize;
    _ = lz4DecodedConcatenatedFrameChunksSize;
    _ = lz4DecodedConcatenatedFrameChunksSizeLimited;
    _ = lz4DecodeConcatenatedFrameChunksAllocWithDictionary;
    _ = lz4DecodeConcatenatedFrameChunksAllocWithDictionaryExactSize;
    _ = lz4DecodeConcatenatedFrameChunksAllocWithDictionaryLimited;
    _ = lz4DecodeConcatenatedFrameChunksAppendWithDictionary;
    _ = lz4DecodeConcatenatedFrameChunksAppendExactSizeWithDictionary;
    _ = lz4DecodeConcatenatedFrameChunksAppendLimitedWithDictionary;
    _ = lz4DecodeConcatenatedFrameChunksIntoWithDictionary;
    _ = lz4DecodeConcatenatedFrameChunksIntoWithDictionaryExactSize;
    _ = lz4DecodedConcatenatedFrameChunksSizeWithDictionary;
    _ = lz4DecodedConcatenatedFrameChunksSizeLimitedWithDictionary;
    _ = lz4DecodeConcatenatedFrameChunksAllocWithDictionarySet;
    _ = lz4DecodeConcatenatedFrameChunksAllocWithDictionarySetExactSize;
    _ = lz4DecodeConcatenatedFrameChunksAllocWithDictionarySetLimited;
    _ = lz4DecodeConcatenatedFrameChunksAppendWithDictionarySet;
    _ = lz4DecodeConcatenatedFrameChunksAppendExactSizeWithDictionarySet;
    _ = lz4DecodeConcatenatedFrameChunksAppendLimitedWithDictionarySet;
    _ = lz4DecodeConcatenatedFrameChunksIntoWithDictionarySet;
    _ = lz4DecodeConcatenatedFrameChunksIntoWithDictionarySetExactSize;
    _ = lz4DecodedConcatenatedFrameChunksSizeWithDictionarySet;
    _ = lz4DecodedConcatenatedFrameChunksSizeLimitedWithDictionarySet;
    _ = lz4DecodeNativeConcatenatedFrameAlloc;
    _ = lz4DecodeNativeConcatenatedFrameAppend;
    _ = lz4DecodeNativeConcatenatedFrameAppendExactSize;
    _ = lz4DecodeNativeConcatenatedFrameAppendLimited;
    _ = lz4DecodeNativeConcatenatedFrameAllocLimited;
    _ = lz4DecodeNativeConcatenatedFrameAllocExactSize;
    _ = lz4DecodedNativeConcatenatedFrameSize;
    _ = lz4DecodedNativeConcatenatedFrameSizeLimited;
    _ = lz4DecodeNativeConcatenatedFrameIntoExactSize;
    _ = lz4DecodeNativeConcatenatedFrameAllocWithDictionary;
    _ = lz4DecodeNativeConcatenatedFrameAppendWithDictionary;
    _ = lz4DecodeNativeConcatenatedFrameAppendExactSizeWithDictionary;
    _ = lz4DecodeNativeConcatenatedFrameAppendLimitedWithDictionary;
    _ = lz4DecodeNativeConcatenatedFrameAllocLimitedWithDictionary;
    _ = lz4DecodeNativeConcatenatedFrameAllocWithDictionaryExactSize;
    _ = lz4DecodeNativeConcatenatedFrameIntoWithDictionaryExactSize;
    _ = lz4DecodeNativeConcatenatedFrameIntoWithDictionary;
    _ = lz4DecodedNativeConcatenatedFrameSizeWithDictionary;
    _ = lz4DecodedNativeConcatenatedFrameSizeLimitedWithDictionary;
    _ = lz4DecodeNativeConcatenatedFrameInto;
    _ = lz4DecodeNativeConcatenatedFrameIntoExactSize;
    _ = lz4DecodeNativeConcatenatedFrameAllocWithDictionarySet;
    _ = lz4DecodeNativeConcatenatedFrameAppendWithDictionarySet;
    _ = lz4DecodeNativeConcatenatedFrameAppendExactSizeWithDictionarySet;
    _ = lz4DecodeNativeConcatenatedFrameAppendLimitedWithDictionarySet;
    _ = lz4DecodeNativeConcatenatedFrameAllocLimitedWithDictionarySet;
    _ = lz4DecodeNativeConcatenatedFrameAllocWithDictionarySetExactSize;
    _ = lz4DecodeNativeConcatenatedFrameIntoWithDictionarySetExactSize;
    _ = lz4DecodeNativeConcatenatedFrameIntoWithDictionarySet;
    _ = lz4DecodedNativeConcatenatedFrameSizeWithDictionarySet;
    _ = lz4DecodedNativeConcatenatedFrameSizeLimitedWithDictionarySet;
    _ = lz4DecodeNativeConcatenatedFrameChunksAlloc;
    _ = lz4DecodeNativeConcatenatedFrameChunksAppend;
    _ = lz4DecodeNativeConcatenatedFrameChunksAppendExactSize;
    _ = lz4DecodeNativeConcatenatedFrameChunksAppendLimited;
    _ = lz4DecodeNativeConcatenatedFrameChunksAppendWithDictionary;
    _ = lz4DecodeNativeConcatenatedFrameChunksAppendExactSizeWithDictionary;
    _ = lz4DecodeNativeConcatenatedFrameChunksAppendLimitedWithDictionary;
    _ = lz4DecodeNativeConcatenatedFrameChunksAppendWithDictionarySet;
    _ = lz4DecodeNativeConcatenatedFrameChunksAppendExactSizeWithDictionarySet;
    _ = lz4DecodeNativeConcatenatedFrameChunksAppendLimitedWithDictionarySet;
    _ = lz4DecodeNativeConcatenatedFrameChunksAllocExactSize;
    _ = lz4DecodeNativeConcatenatedFrameChunksAllocLimited;
    _ = lz4DecodeNativeConcatenatedFrameChunksInto;
    _ = lz4DecodeNativeConcatenatedFrameChunksIntoExactSize;
    _ = lz4DecodedNativeConcatenatedFrameChunksSize;
    _ = lz4DecodedNativeConcatenatedFrameChunksSizeLimited;
    _ = lz4DecodeNativeConcatenatedFrameChunksAllocWithDictionary;
    _ = lz4DecodeNativeConcatenatedFrameChunksAllocWithDictionaryExactSize;
    _ = lz4DecodeNativeConcatenatedFrameChunksAllocWithDictionaryLimited;
    _ = lz4DecodeNativeConcatenatedFrameChunksIntoWithDictionary;
    _ = lz4DecodeNativeConcatenatedFrameChunksIntoExactSizeWithDictionary;
    _ = lz4DecodeNativeConcatenatedFrameChunksIntoWithDictionaryExactSize;
    _ = lz4DecodedNativeConcatenatedFrameChunksSizeWithDictionary;
    _ = lz4DecodedNativeConcatenatedFrameChunksSizeLimitedWithDictionary;
    _ = lz4DecodeNativeConcatenatedFrameChunksAllocWithDictionarySet;
    _ = lz4DecodeNativeConcatenatedFrameChunksAllocWithDictionarySetExactSize;
    _ = lz4DecodeNativeConcatenatedFrameChunksAllocWithDictionarySetLimited;
    _ = lz4DecodeNativeConcatenatedFrameChunksIntoWithDictionarySet;
    _ = lz4DecodeNativeConcatenatedFrameChunksIntoExactSizeWithDictionarySet;
    _ = lz4DecodeNativeConcatenatedFrameChunksIntoWithDictionarySetExactSize;
    _ = lz4DecodedNativeConcatenatedFrameChunksSizeWithDictionarySet;
    _ = lz4DecodedNativeConcatenatedFrameChunksSizeLimitedWithDictionarySet;
    _ = lz4EncodedNativeFrameBound;
    _ = lz4EncodedNativeFrameBoundWithOptions;
    _ = lz4EncodedNativeFrameBoundWithDictionary;
    _ = lz4EncodedNativeFrameBoundWithDictionarySet;
    _ = lz4EncodeNativeFrameWithDictionaryAlloc;
    _ = lz4EncodeNativeFrameAppendWithDictionary;
    _ = lz4EncodeNativeFrameIntoSliceWithDictionary;
    _ = lz4EncodeNativeFrameWithDictionarySetAlloc;
    _ = lz4EncodeNativeFrameAppendWithDictionarySet;
    _ = lz4EncodeNativeFrameIntoSliceWithDictionarySet;
    _ = lz4EncodeBlockAlloc;
    _ = lz4EncodeBlockWithChainDepthAlloc;
    _ = lz4EncodeBlockWithPrefixAlloc;
    _ = lz4EncodeBlockWithPrefixAndChainDepthAlloc;
    _ = lz4EncodeBlockIntoSlice;
    _ = lz4EncodeBlockIntoSliceWithChainDepth;
    _ = lz4EncodeBlockWithPrefixIntoSlice;
    _ = lz4EncodeBlockWithPrefixIntoSliceAndChainDepth;
    _ = lz4DecodeBlockAlloc;
    _ = lz4DecodeBlockWithPrefixAlloc;
    _ = lz4DecodeBlockAppend;
    _ = lz4DecodeBlockAppendLimited;
    _ = lz4DecodeBlockWithPrefixAppend;
    _ = lz4DecodeBlockWithPrefixAppendLimited;
    _ = lz4DecodeBlockIntoSlice;
    _ = lz4DecodeBlockWithPrefixIntoSlice;
    _ = lz4DecodeBlockWithPrefixIntoSliceNoAlloc;
    _ = lz4DecodedBlockSize;
    _ = lz4DecodedBlockSizeLimited;
    _ = lz4DecodedBlockSizeWithPrefix;
    _ = lz4DecodedBlockSizeWithPrefixLimited;
    _ = lz4SummarizeBlock;
    _ = lz4SummarizeBlockLimited;
    _ = lz4SummarizeBlockWithPrefix;
    _ = lz4SummarizeBlockWithPrefixLimited;
    _ = lz4EncodedBlockBound;

    _ = ZstdError;
    try std.testing.expectEqual(@as(c_int, 1), zstdDefaultCompressionLevel);
    _ = zstdEncodeFrameAlloc;
    _ = zstdEncodeFrameWithLevelAlloc;
    _ = zstdEncodeFrameWithOptionsAlloc;
    _ = zstdEncodeFrameWithLevelAndOptionsAlloc;
    _ = zstdEncodedFrameBound;
    _ = zstdEncodedFrameBoundWithLevel;
    _ = zstdEncodedFrameBoundWithOptions;
    _ = zstdEncodedFrameBoundWithLevelAndOptions;
    _ = zstdEncodeFrameAppend;
    _ = zstdEncodeFrameAppendWithLevel;
    _ = zstdEncodeFrameAppendWithOptions;
    _ = zstdEncodeFrameAppendWithLevelAndOptions;
    _ = zstdEncodeFrameIntoSlice;
    _ = zstdEncodeFrameIntoSliceWithLevel;
    _ = zstdEncodeFrameIntoSliceWithOptions;
    _ = zstdEncodeFrameIntoSliceWithLevelAndOptions;
    _ = zstdEncodedFrameBoundWithDictionary;
    _ = zstdEncodedFrameBoundWithOptionsAndDictionary;
    _ = zstdEncodedFrameBoundWithLevelAndOptionsAndDictionary;
    _ = zstdEncodeFrameWithDictionaryAlloc;
    _ = zstdEncodeFrameWithOptionsAndDictionaryAlloc;
    _ = zstdEncodeFrameWithLevelAndOptionsAndDictionaryAlloc;
    _ = zstdEncodeFrameAppendWithDictionary;
    _ = zstdEncodeFrameAppendWithOptionsAndDictionary;
    _ = zstdEncodeFrameAppendWithLevelAndOptionsAndDictionary;
    _ = zstdEncodeFrameIntoSliceWithDictionary;
    _ = zstdEncodeFrameIntoSliceWithOptionsAndDictionary;
    _ = zstdEncodeFrameIntoSliceWithLevelAndOptionsAndDictionary;
    _ = zstdEncodedFrameBoundWithDictionarySet;
    _ = zstdEncodedFrameBoundWithOptionsAndDictionarySet;
    _ = zstdEncodedFrameBoundWithLevelAndOptionsAndDictionarySet;
    _ = zstdEncodeFrameWithDictionarySetAlloc;
    _ = zstdEncodeFrameWithOptionsAndDictionarySetAlloc;
    _ = zstdEncodeFrameWithLevelAndOptionsAndDictionarySetAlloc;
    _ = zstdEncodeFrameAppendWithDictionarySet;
    _ = zstdEncodeFrameAppendWithOptionsAndDictionarySet;
    _ = zstdEncodeFrameAppendWithLevelAndOptionsAndDictionarySet;
    _ = zstdEncodeFrameIntoSliceWithDictionarySet;
    _ = zstdEncodeFrameIntoSliceWithOptionsAndDictionarySet;
    _ = zstdEncodeFrameIntoSliceWithLevelAndOptionsAndDictionarySet;
    _ = zstdDecodeFrameAlloc;
    _ = zstdDecodeFrameAllocExactSize;
    _ = zstdDecodeFrameAllocLimited;
    _ = zstdDecodeFrameAppend;
    _ = zstdDecodeFrameAppendExactSize;
    _ = zstdDecodeFrameAppendLimited;
    _ = zstdDecodeFrameInto;
    _ = zstdDecodeFrameIntoLimited;
    _ = zstdDecodeFrameIntoExactSize;
    _ = zstdDecodedFrameSize;
    _ = zstdDecodedFrameSizeLimited;
    _ = zstdDecodeFrameChunksAlloc;
    _ = zstdDecodeFrameChunksAllocExactSize;
    _ = zstdDecodeFrameChunksAllocLimited;
    _ = zstdDecodeFrameChunksAppend;
    _ = zstdDecodeFrameChunksAppendExactSize;
    _ = zstdDecodeFrameChunksAppendLimited;
    _ = zstdDecodeFrameChunksInto;
    _ = zstdDecodeFrameChunksIntoLimited;
    _ = zstdDecodeFrameChunksIntoExactSize;
    _ = zstdDecodedFrameChunksSize;
    _ = zstdDecodedFrameChunksSizeLimited;
    _ = zstdDecodeFrameChunksAllocWithDictionary;
    _ = zstdDecodeFrameChunksAllocWithDictionaryExactSize;
    _ = zstdDecodeFrameChunksAllocWithDictionaryLimited;
    _ = zstdDecodeFrameChunksAppendWithDictionary;
    _ = zstdDecodeFrameChunksAppendExactSizeWithDictionary;
    _ = zstdDecodeFrameChunksAppendLimitedWithDictionary;
    _ = zstdDecodeFrameChunksIntoWithDictionary;
    _ = zstdDecodeFrameChunksIntoWithDictionaryLimited;
    _ = zstdDecodeFrameChunksIntoWithDictionaryExactSize;
    _ = zstdDecodedFrameChunksSizeWithDictionary;
    _ = zstdDecodedFrameChunksSizeLimitedWithDictionary;
    _ = zstdDecodeFrameChunksAllocWithDictionarySet;
    _ = zstdDecodeFrameChunksAllocWithDictionarySetExactSize;
    _ = zstdDecodeFrameChunksAllocWithDictionarySetLimited;
    _ = zstdDecodeFrameChunksAppendWithDictionarySet;
    _ = zstdDecodeFrameChunksAppendExactSizeWithDictionarySet;
    _ = zstdDecodeFrameChunksAppendLimitedWithDictionarySet;
    _ = zstdDecodeFrameChunksIntoWithDictionarySet;
    _ = zstdDecodeFrameChunksIntoWithDictionarySetLimited;
    _ = zstdDecodeFrameChunksIntoWithDictionarySetExactSize;
    _ = zstdDecodedFrameChunksSizeWithDictionarySet;
    _ = zstdDecodedFrameChunksSizeLimitedWithDictionarySet;
    _ = zstdDecodeFrameAllocWithDictionary;
    _ = zstdDecodeFrameAllocWithDictionaryExactSize;
    _ = zstdDecodeFrameAllocWithDictionaryLimited;
    _ = zstdDecodeFrameAppendWithDictionary;
    _ = zstdDecodeFrameAppendExactSizeWithDictionary;
    _ = zstdDecodeFrameAppendLimitedWithDictionary;
    _ = zstdDecodeFrameIntoWithDictionary;
    _ = zstdDecodeFrameIntoWithDictionaryLimited;
    _ = zstdDecodeFrameIntoWithDictionaryExactSize;
    _ = zstdDecodedFrameSizeWithDictionary;
    _ = zstdDecodedFrameSizeLimitedWithDictionary;
    _ = zstdDecodeFrameAllocWithDictionarySet;
    _ = zstdDecodeFrameAllocWithDictionarySetExactSize;
    _ = zstdDecodeFrameAllocWithDictionarySetLimited;
    _ = zstdDecodeFrameAppendWithDictionarySet;
    _ = zstdDecodeFrameAppendExactSizeWithDictionarySet;
    _ = zstdDecodeFrameAppendLimitedWithDictionarySet;
    _ = zstdDecodeFrameIntoWithDictionarySet;
    _ = zstdDecodeFrameIntoWithDictionarySetLimited;
    _ = zstdDecodeFrameIntoWithDictionarySetExactSize;
    _ = zstdDecodedFrameSizeWithDictionarySet;
    _ = zstdDecodedFrameSizeLimitedWithDictionarySet;
    _ = zstdDecodeConcatenatedFrameAlloc;
    _ = zstdDecodeConcatenatedFrameAllocExactSize;
    _ = zstdDecodeConcatenatedFrameAllocLimited;
    _ = zstdDecodeConcatenatedFrameAppend;
    _ = zstdDecodeConcatenatedFrameAppendExactSize;
    _ = zstdDecodeConcatenatedFrameAppendLimited;
    _ = zstdDecodeConcatenatedFrameInto;
    _ = zstdDecodeConcatenatedFrameIntoLimited;
    _ = zstdDecodeConcatenatedFrameIntoExactSize;
    _ = zstdDecodedConcatenatedFrameSize;
    _ = zstdDecodedConcatenatedFrameSizeLimited;
    _ = zstdDecodeConcatenatedFrameAllocWithDictionary;
    _ = zstdDecodeConcatenatedFrameAllocWithDictionaryExactSize;
    _ = zstdDecodeConcatenatedFrameAllocLimitedWithDictionary;
    _ = zstdDecodeConcatenatedFrameAppendWithDictionary;
    _ = zstdDecodeConcatenatedFrameAppendExactSizeWithDictionary;
    _ = zstdDecodeConcatenatedFrameAppendLimitedWithDictionary;
    _ = zstdDecodeConcatenatedFrameIntoWithDictionary;
    _ = zstdDecodeConcatenatedFrameIntoWithDictionaryLimited;
    _ = zstdDecodeConcatenatedFrameIntoWithDictionaryExactSize;
    _ = zstdDecodedConcatenatedFrameSizeWithDictionary;
    _ = zstdDecodedConcatenatedFrameSizeLimitedWithDictionary;
    _ = zstdDecodeConcatenatedFrameAllocWithDictionarySet;
    _ = zstdDecodeConcatenatedFrameAllocWithDictionarySetExactSize;
    _ = zstdDecodeConcatenatedFrameAllocLimitedWithDictionarySet;
    _ = zstdDecodeConcatenatedFrameAppendWithDictionarySet;
    _ = zstdDecodeConcatenatedFrameAppendExactSizeWithDictionarySet;
    _ = zstdDecodeConcatenatedFrameAppendLimitedWithDictionarySet;
    _ = zstdDecodeConcatenatedFrameIntoWithDictionarySet;
    _ = zstdDecodeConcatenatedFrameIntoWithDictionarySetLimited;
    _ = zstdDecodeConcatenatedFrameIntoWithDictionarySetExactSize;
    _ = zstdDecodedConcatenatedFrameSizeWithDictionarySet;
    _ = zstdDecodedConcatenatedFrameSizeLimitedWithDictionarySet;
    _ = zstdDecodeConcatenatedFrameChunksAlloc;
    _ = zstdDecodeConcatenatedFrameChunksAllocExactSize;
    _ = zstdDecodeConcatenatedFrameChunksAllocLimited;
    _ = zstdDecodeConcatenatedFrameChunksAppend;
    _ = zstdDecodeConcatenatedFrameChunksAppendExactSize;
    _ = zstdDecodeConcatenatedFrameChunksAppendLimited;
    _ = zstdDecodeConcatenatedFrameChunksInto;
    _ = zstdDecodeConcatenatedFrameChunksIntoLimited;
    _ = zstdDecodeConcatenatedFrameChunksIntoExactSize;
    _ = zstdDecodedConcatenatedFrameChunksSize;
    _ = zstdDecodedConcatenatedFrameChunksSizeLimited;
    _ = zstdDecodeConcatenatedFrameChunksAllocWithDictionary;
    _ = zstdDecodeConcatenatedFrameChunksAllocWithDictionaryExactSize;
    _ = zstdDecodeConcatenatedFrameChunksAllocWithDictionaryLimited;
    _ = zstdDecodeConcatenatedFrameChunksAppendWithDictionary;
    _ = zstdDecodeConcatenatedFrameChunksAppendExactSizeWithDictionary;
    _ = zstdDecodeConcatenatedFrameChunksAppendLimitedWithDictionary;
    _ = zstdDecodeConcatenatedFrameChunksIntoWithDictionary;
    _ = zstdDecodeConcatenatedFrameChunksIntoWithDictionaryLimited;
    _ = zstdDecodeConcatenatedFrameChunksIntoWithDictionaryExactSize;
    _ = zstdDecodedConcatenatedFrameChunksSizeWithDictionary;
    _ = zstdDecodedConcatenatedFrameChunksSizeLimitedWithDictionary;
    _ = zstdDecodeConcatenatedFrameChunksAllocWithDictionarySet;
    _ = zstdDecodeConcatenatedFrameChunksAllocWithDictionarySetExactSize;
    _ = zstdDecodeConcatenatedFrameChunksAllocWithDictionarySetLimited;
    _ = zstdDecodeConcatenatedFrameChunksAppendWithDictionarySet;
    _ = zstdDecodeConcatenatedFrameChunksAppendExactSizeWithDictionarySet;
    _ = zstdDecodeConcatenatedFrameChunksAppendLimitedWithDictionarySet;
    _ = zstdDecodeConcatenatedFrameChunksIntoWithDictionarySet;
    _ = zstdDecodeConcatenatedFrameChunksIntoWithDictionarySetLimited;
    _ = zstdDecodeConcatenatedFrameChunksIntoWithDictionarySetExactSize;
    _ = zstdDecodedConcatenatedFrameChunksSizeWithDictionarySet;
    _ = zstdDecodedConcatenatedFrameChunksSizeLimitedWithDictionarySet;
    _ = zstdEncodedFrameBoundWithAdvancedOptions;
    _ = zstdEncodedFrameBoundWithAdvancedOptionsAndDictionary;
    _ = zstdEncodedFrameBoundWithAdvancedOptionsAndDictionarySet;
    _ = zstdEncodeFrameWithAdvancedOptionsAlloc;
    _ = zstdEncodeFrameWithAdvancedOptionsAndDictionaryAlloc;
    _ = zstdEncodeFrameWithAdvancedOptionsAndDictionarySetAlloc;
    _ = zstdEncodeFrameAppendWithAdvancedOptions;
    _ = zstdEncodeFrameAppendWithAdvancedOptionsAndDictionary;
    _ = zstdEncodeFrameAppendWithAdvancedOptionsAndDictionarySet;
    _ = zstdEncodeFrameIntoSliceWithAdvancedOptions;
    _ = zstdEncodeFrameIntoSliceWithAdvancedOptionsAndDictionary;
    _ = zstdEncodeFrameIntoSliceWithAdvancedOptionsAndDictionarySet;
    _ = ZstdFrameOptions;
    _ = ZstdFrameSelection;
    _ = ZstdAdvancedFrameOptions;
    _ = ZstdFrameMode;
    _ = ZstdFrameEncodeResult;
    _ = ZstdFrameEncodeIntoResult;
    _ = ZstdFrameEncodeScratchResult;
    _ = ZstdFrameEncoder;
    _ = ZstdSeekableStreamEncoder;
    _ = ZstdFrameDecoder;
    _ = ZstdIncrementalFrameDecoder;
    _ = ZstdDictionary;
    _ = ZstdDictionaryTrainOptions;
    _ = ZstdOwnedDictionary;
    _ = ZstdDictionarySet;
    _ = ZstdOwnedDictionarySet;
    _ = zstdDecodeNativeSeekableRangeIntoWithDictionary;
    _ = zstdDecodeNativeSeekableRangeAllocWithDictionary;
    _ = zstdDecodeNativeSeekableRangeIntoWithIndexAndDictionary;
    _ = zstdDecodeNativeSeekableRangeAllocWithIndexAndDictionary;
    _ = zstdTrainDictionaryAlloc;
    _ = zstdStandardDictionaryHeaderLen;
    _ = zstdStandardDictionaryFromContentBound;
    _ = zstdStandardDictionaryFromContentInto;
    _ = zstdStandardDictionaryFromContentAlloc;
    _ = zstdTrainStandardDictionaryAlloc;
    _ = zstdTrainValidatedStandardDictionaryAlloc;
    _ = zstdDictionarySetFromMetadataAlloc;
    _ = zstdEncodeRawOrRleFrameAlloc;
    _ = zstdEncodeRawOrRleFrameWithOptionsAlloc;
    _ = zstdEncodeRawOrRleFrameAppend;
    _ = zstdEncodeRawOrRleFrameIntoSlice;
    _ = zstdEncodeLiteralOnlyFrameAlloc;
    _ = zstdEncodeLiteralOnlyFrameWithOptionsAlloc;
    _ = zstdEncodeLiteralOnlyFrameAppend;
    _ = zstdEncodeLiteralOnlyFrameIntoSlice;
    _ = zstdEncodedSkippableFrameBound;
    _ = zstdEncodeSkippableFrameAlloc;
    _ = zstdEncodeSkippableFrameAppend;
    _ = zstdEncodeSkippableFrameIntoSlice;
    _ = ZstdNativeFrameOptions;
    _ = zstdNativeMaxMatchSearchBudget;
    _ = zstdNativeMaxDirectHuffmanSymbol;
    _ = zstdNativeDictionaryWindowLen;
    _ = ZstdNativeFrameSelection;
    _ = ZstdNativeFrameMode;
    _ = ZstdNativeFrameEncodeResult;
    _ = ZstdNativeFrameEncodeIntoResult;
    _ = ZstdNativeFrameEncodeScratchResult;
    _ = ZstdNativeFrameEncoder;
    _ = ZstdLevelFrameEncoder;
    _ = ZstdNativeFrameDecoder;
    _ = ZstdNativeIncrementalFrameDecoder;
    _ = ZstdNativeDictionary;
    _ = ZstdNativeDictionaryTrainOptions;
    _ = ZstdOwnedNativeDictionary;
    _ = ZstdNativeDictionarySet;
    _ = ZstdOwnedNativeDictionarySet;
    _ = zstdTrainNativeDictionaryAlloc;
    _ = zstdNativeDictionarySetFromMetadataAlloc;
    _ = ZstdNativeFrameHeader;
    _ = ZstdNativeFrameBlockHeader;
    _ = ZstdNativeFrameBlockSummary;
    _ = ZstdNativeLiteralsKind;
    _ = ZstdNativeSequenceTableMode;
    _ = ZstdNativeSequenceModeSummary;
    _ = ZstdNativeStreamSummary;
    _ = ZstdNativeStreamSummaryErrorDiagnostics;
    _ = ZstdNativeStreamSummaryErrorPhase;
    _ = ZstdNativeSkippableFrameHeader;
    _ = ZstdNativeSeekTable;
    _ = ZstdNativeSeekTableEntry;
    _ = ZstdNativeSeekTableIterator;
    _ = ZstdNativeSeekTableFrameSize;
    _ = ZstdNativeSeekIndex;
    _ = ZstdNativeSeekableOptions;
    _ = ZstdNativeSeekableStreamEncoder;
    _ = zstdNativeSeekableParallelWorkersMax;
    _ = ZstdNativeBlockType;
    _ = zstdInspectNativeFrameHeader;
    _ = zstdInspectNativeFrameFirstBlock;
    _ = zstdInspectNativeFrameBlockAt;
    _ = zstdInspectNativeFrameBlockSequenceModes;
    _ = zstdInspectNativeFrameBlockSequenceModesWithDictionary;
    _ = zstdInspectNativeFrameBlockSequenceModesWithDictionarySet;
    _ = zstdSummarizeNativeFrameBlocks;
    _ = zstdSummarizeNativeStream;
    _ = zstdSummarizeNativeStreamWithDiagnostics;
    _ = zstdSummarizeNativeStreamWithDictionary;
    _ = zstdSummarizeNativeStreamWithDictionaryDiagnostics;
    _ = zstdSummarizeNativeStreamWithDictionarySet;
    _ = zstdSummarizeNativeStreamWithDictionarySetAndDiagnostics;
    _ = zstdInspectNativeSkippableFrame;
    _ = zstdInspectNativeSeekTable;
    _ = zstdNativeSeekTableFrameIndexForOffset;
    _ = zstdBuildNativeSeekIndex;
    _ = zstdEncodedNativeSeekTableBound;
    _ = zstdEncodeNativeSeekTableAlloc;
    _ = zstdEncodeNativeSeekTableAppend;
    _ = zstdEncodeNativeSeekTableInto;
    _ = zstdEncodedNativeSeekableStreamBound;
    _ = zstdEncodedNativeSeekableStreamBoundWithDictionary;
    _ = zstdEncodedNativeSeekableStreamBoundWithDictionarySet;
    _ = zstdEncodeNativeSeekableStreamAlloc;
    _ = zstdEncodeNativeSeekableStreamParallelAlloc;
    _ = zstdEncodeNativeSeekableStreamAppend;
    _ = zstdEncodeNativeSeekableStreamIntoSlice;
    _ = zstdEncodeNativeSeekableStreamWithDictionaryAlloc;
    _ = zstdEncodeNativeSeekableStreamParallelWithDictionaryAlloc;
    _ = zstdEncodeNativeSeekableStreamAppendWithDictionary;
    _ = zstdEncodeNativeSeekableStreamIntoSliceWithDictionary;
    _ = zstdEncodeNativeSeekableStreamWithDictionarySetAlloc;
    _ = zstdEncodeNativeSeekableStreamParallelWithDictionarySetAlloc;
    _ = zstdEncodeNativeSeekableStreamAppendWithDictionarySet;
    _ = zstdEncodeNativeSeekableStreamIntoSliceWithDictionarySet;
    _ = zstdNativeSeekableRangeScratchLen;
    _ = zstdNativeSeekableRangeScratchLenWithIndex;
    _ = zstdDecodeNativeSeekableRangeInto;
    _ = zstdDecodeNativeSeekableRangeAlloc;
    _ = zstdDecodeNativeSeekableRangeIntoWithDictionarySet;
    _ = zstdDecodeNativeSeekableRangeAllocWithDictionarySet;
    _ = zstdDecodeNativeSeekableRangeIntoWithIndex;
    _ = zstdDecodeNativeSeekableRangeAllocWithIndex;
    _ = zstdDecodeNativeSeekableRangeIntoWithIndexAndDictionarySet;
    _ = zstdDecodeNativeSeekableRangeAllocWithIndexAndDictionarySet;
    _ = zstdEncodedNativeFrameBound;
    _ = zstdEncodedNativeFrameBoundWithOptions;
    _ = zstdEncodedNativeFrameBoundWithDictionary;
    _ = zstdEncodedNativeFrameBoundWithDictionarySet;
    _ = zstdEncodeNativeFrameWithOptionsAlloc;
    _ = zstdEncodeNativeFrameAppend;
    _ = zstdEncodeNativeFrameIntoSlice;
    _ = zstdEncodeNativeFrameWithDictionaryAlloc;
    _ = zstdEncodeNativeFrameAppendWithDictionary;
    _ = zstdEncodeNativeFrameIntoSliceWithDictionary;
    _ = zstdEncodeNativeFrameWithDictionarySetAlloc;
    _ = zstdEncodeNativeFrameAppendWithDictionarySet;
    _ = zstdEncodeNativeFrameIntoSliceWithDictionarySet;
    _ = zstdDecodeRawOrRleFrameAlloc;
    _ = zstdDecodeRawOrRleFrameAppend;
    _ = zstdDecodeRawOrRleFrameAppendExactSize;
    _ = zstdDecodeRawOrRleFrameAppendLimited;
    _ = zstdDecodeRawOrRleFrameAllocLimited;
    _ = zstdDecodeRawOrRleFrameAllocExactSize;
    _ = zstdDecodeRawOrRleFrameAllocWithDictionary;
    _ = zstdDecodeRawOrRleFrameAppendWithDictionary;
    _ = zstdDecodeRawOrRleFrameAllocWithDictionaryExactSize;
    _ = zstdDecodeRawOrRleFrameAllocWithDictionarySetExactSize;
    _ = zstdDecodedRawOrRleFrameSize;
    _ = zstdDecodedRawOrRleFrameSizeLimited;
    _ = zstdDecodeRawOrRleFrameInto;
    _ = zstdDecodeRawOrRleFrameIntoLimited;
    _ = zstdDecodeRawOrRleFrameIntoExactSize;
    _ = zstdDecodeRawOrRleFrameIntoWithDictionary;
    _ = zstdDecodeRawOrRleFrameIntoWithDictionaryLimited;
    _ = zstdDecodeRawOrRleFrameIntoWithDictionaryExactSize;
    _ = zstdDecodeRawOrRleFrameAllocWithDictionarySet;
    _ = zstdDecodeRawOrRleFrameAppendWithDictionarySet;
    _ = zstdDecodeRawOrRleFrameAppendExactSizeWithDictionarySet;
    _ = zstdDecodeRawOrRleFrameAppendLimitedWithDictionarySet;
    _ = zstdDecodeRawOrRleFrameAllocLimitedWithDictionarySet;
    _ = zstdDecodeRawOrRleFrameAppendExactSizeWithDictionary;
    _ = zstdDecodedRawOrRleFrameSizeWithDictionarySet;
    _ = zstdDecodedRawOrRleFrameSizeLimitedWithDictionarySet;
    _ = zstdDecodeRawOrRleFrameIntoWithDictionarySet;
    _ = zstdDecodeRawOrRleFrameIntoWithDictionarySetLimited;
    _ = zstdDecodeRawOrRleFrameIntoWithDictionarySetExactSize;
    _ = zstdDecodeRawOrRleFrameChunksAlloc;
    _ = zstdDecodeRawOrRleFrameChunksAllocExactSize;
    _ = zstdDecodeRawOrRleFrameChunksAllocLimited;
    _ = zstdDecodeRawOrRleFrameChunksAppend;
    _ = zstdDecodeRawOrRleFrameChunksAppendExactSize;
    _ = zstdDecodeRawOrRleFrameChunksAppendLimited;
    _ = zstdDecodeRawOrRleFrameChunksInto;
    _ = zstdDecodeRawOrRleFrameChunksIntoLimited;
    _ = zstdDecodeRawOrRleFrameChunksIntoExactSize;
    _ = zstdDecodedRawOrRleFrameChunksSize;
    _ = zstdDecodedRawOrRleFrameChunksSizeLimited;
    _ = zstdDecodeRawOrRleFrameChunksAllocWithDictionary;
    _ = zstdDecodeRawOrRleFrameChunksAllocWithDictionaryExactSize;
    _ = zstdDecodeRawOrRleFrameChunksAllocWithDictionaryLimited;
    _ = zstdDecodeRawOrRleFrameChunksAppendWithDictionary;
    _ = zstdDecodeRawOrRleFrameChunksAppendExactSizeWithDictionary;
    _ = zstdDecodeRawOrRleFrameChunksAppendLimitedWithDictionary;
    _ = zstdDecodeRawOrRleFrameChunksIntoWithDictionary;
    _ = zstdDecodeRawOrRleFrameChunksIntoWithDictionaryLimited;
    _ = zstdDecodeRawOrRleFrameChunksIntoWithDictionaryExactSize;
    _ = zstdDecodedRawOrRleFrameChunksSizeWithDictionary;
    _ = zstdDecodedRawOrRleFrameChunksSizeLimitedWithDictionary;
    _ = zstdDecodeRawOrRleFrameChunksAllocWithDictionarySet;
    _ = zstdDecodeRawOrRleFrameChunksAllocWithDictionarySetExactSize;
    _ = zstdDecodeRawOrRleFrameChunksAllocWithDictionarySetLimited;
    _ = zstdDecodeRawOrRleFrameChunksAppendWithDictionarySet;
    _ = zstdDecodeRawOrRleFrameChunksAppendExactSizeWithDictionarySet;
    _ = zstdDecodeRawOrRleFrameChunksAppendLimitedWithDictionarySet;
    _ = zstdDecodeRawOrRleFrameChunksIntoWithDictionarySet;
    _ = zstdDecodeRawOrRleFrameChunksIntoWithDictionarySetLimited;
    _ = zstdDecodeRawOrRleFrameChunksIntoWithDictionarySetExactSize;
    _ = zstdDecodedRawOrRleFrameChunksSizeWithDictionarySet;
    _ = zstdDecodedRawOrRleFrameChunksSizeLimitedWithDictionarySet;
    _ = zstdEncodeNativeFrameAlloc;
    _ = zstdDecodeNativeFrameAlloc;
    _ = zstdDecodeNativeFrameAppend;
    _ = zstdDecodeNativeFrameAppendExactSize;
    _ = zstdDecodeNativeFrameAppendLimited;
    _ = zstdDecodeNativeFrameAllocLimited;
    _ = zstdDecodeNativeFrameAllocExactSize;
    _ = zstdDecodeNativeFrameIntoExactSize;
    _ = zstdDecodeNativeFrameAllocWithDictionary;
    _ = zstdDecodeNativeFrameAppendWithDictionary;
    _ = zstdDecodeNativeFrameAppendLimitedWithDictionary;
    _ = zstdDecodeNativeFrameAllocLimitedWithDictionary;
    _ = zstdDecodeNativeFrameAllocWithDictionaryExactSize;
    _ = zstdDecodeNativeFrameIntoWithDictionaryExactSize;
    _ = zstdDecodeNativeFrameIntoWithDictionary;
    _ = zstdDecodeNativeFrameIntoWithDictionaryLimited;
    _ = zstdDecodedNativeFrameSizeWithDictionary;
    _ = zstdDecodedNativeFrameSizeLimitedWithDictionary;
    _ = zstdDecodeNativeFrameInto;
    _ = zstdDecodeNativeFrameIntoLimited;
    _ = zstdDecodeNativeFrameAllocWithDictionarySet;
    _ = zstdDecodeNativeFrameAppendWithDictionarySet;
    _ = zstdDecodeNativeFrameAppendExactSizeWithDictionarySet;
    _ = zstdDecodeNativeFrameAppendLimitedWithDictionarySet;
    _ = zstdDecodeNativeFrameAllocLimitedWithDictionarySet;
    _ = zstdDecodeNativeFrameAppendExactSizeWithDictionary;
    _ = zstdDecodeNativeFrameAllocWithDictionarySetExactSize;
    _ = zstdDecodeNativeFrameIntoWithDictionarySetExactSize;
    _ = zstdDecodeNativeFrameIntoWithDictionarySet;
    _ = zstdDecodeNativeFrameIntoWithDictionarySetLimited;
    _ = zstdDecodedNativeFrameSizeWithDictionarySet;
    _ = zstdDecodedNativeFrameSizeLimitedWithDictionarySet;
    _ = zstdDecodeNativeFrameChunksAlloc;
    _ = zstdDecodeNativeFrameChunksAllocExactSize;
    _ = zstdDecodeNativeFrameChunksAllocLimited;
    _ = zstdDecodeNativeFrameChunksAppend;
    _ = zstdDecodeNativeFrameChunksAppendExactSize;
    _ = zstdDecodeNativeFrameChunksAppendLimited;
    _ = zstdDecodeNativeFrameChunksInto;
    _ = zstdDecodeNativeFrameChunksIntoLimited;
    _ = zstdDecodeNativeFrameChunksIntoExactSize;
    _ = zstdDecodedNativeFrameChunksSize;
    _ = zstdDecodedNativeFrameChunksSizeLimited;
    _ = zstdDecodeNativeFrameChunksAllocWithDictionary;
    _ = zstdDecodeNativeFrameChunksAllocWithDictionaryExactSize;
    _ = zstdDecodeNativeFrameChunksAllocWithDictionaryLimited;
    _ = zstdDecodeNativeFrameChunksAppendWithDictionary;
    _ = zstdDecodeNativeFrameChunksAppendExactSizeWithDictionary;
    _ = zstdDecodeNativeFrameChunksAppendLimitedWithDictionary;
    _ = zstdDecodeNativeFrameChunksIntoWithDictionary;
    _ = zstdDecodeNativeFrameChunksIntoWithDictionaryLimited;
    _ = zstdDecodeNativeFrameChunksIntoExactSizeWithDictionary;
    _ = zstdDecodeNativeFrameChunksIntoWithDictionaryExactSize;
    _ = zstdDecodedNativeFrameChunksSizeWithDictionary;
    _ = zstdDecodedNativeFrameChunksSizeLimitedWithDictionary;
    _ = zstdDecodeNativeFrameChunksAllocWithDictionarySet;
    _ = zstdDecodeNativeFrameChunksAllocWithDictionarySetExactSize;
    _ = zstdDecodeNativeFrameChunksAllocWithDictionarySetLimited;
    _ = zstdDecodeNativeFrameChunksAppendWithDictionarySet;
    _ = zstdDecodeNativeFrameChunksAppendExactSizeWithDictionarySet;
    _ = zstdDecodeNativeFrameChunksAppendLimitedWithDictionarySet;
    _ = zstdDecodeNativeFrameChunksIntoWithDictionarySet;
    _ = zstdDecodeNativeFrameChunksIntoWithDictionarySetLimited;
    _ = zstdDecodeNativeFrameChunksIntoExactSizeWithDictionarySet;
    _ = zstdDecodeNativeFrameChunksIntoWithDictionarySetExactSize;
    _ = zstdDecodedNativeFrameChunksSizeWithDictionarySet;
    _ = zstdDecodedNativeFrameChunksSizeLimitedWithDictionarySet;
    _ = zstdDecodeNativeConcatenatedFrameAlloc;
    _ = zstdDecodeNativeConcatenatedFrameAppend;
    _ = zstdDecodeNativeConcatenatedFrameAppendExactSize;
    _ = zstdDecodeNativeConcatenatedFrameAppendLimited;
    _ = zstdDecodeNativeConcatenatedFrameAllocLimited;
    _ = zstdDecodeNativeConcatenatedFrameAllocExactSize;
    _ = zstdDecodeNativeConcatenatedFrameIntoExactSize;
    _ = zstdDecodeNativeConcatenatedFrameAllocWithDictionary;
    _ = zstdDecodeNativeConcatenatedFrameAppendWithDictionary;
    _ = zstdDecodeNativeConcatenatedFrameAppendLimitedWithDictionary;
    _ = zstdDecodeNativeConcatenatedFrameAllocLimitedWithDictionary;
    _ = zstdDecodeNativeConcatenatedFrameAllocWithDictionaryExactSize;
    _ = zstdDecodeNativeConcatenatedFrameIntoWithDictionaryExactSize;
    _ = zstdDecodeNativeConcatenatedFrameIntoWithDictionary;
    _ = zstdDecodeNativeConcatenatedFrameIntoWithDictionaryLimited;
    _ = zstdDecodedNativeConcatenatedFrameSizeWithDictionary;
    _ = zstdDecodedNativeConcatenatedFrameSizeLimitedWithDictionary;
    _ = zstdDecodeNativeConcatenatedFrameInto;
    _ = zstdDecodeNativeConcatenatedFrameIntoLimited;
    _ = zstdDecodeNativeConcatenatedFrameIntoExactSize;
    _ = zstdDecodeNativeConcatenatedFrameAllocWithDictionarySet;
    _ = zstdDecodeNativeConcatenatedFrameAppendWithDictionarySet;
    _ = zstdDecodeNativeConcatenatedFrameAppendExactSizeWithDictionarySet;
    _ = zstdDecodeNativeConcatenatedFrameAppendLimitedWithDictionarySet;
    _ = zstdDecodeNativeConcatenatedFrameAllocLimitedWithDictionarySet;
    _ = zstdDecodeNativeConcatenatedFrameAppendExactSizeWithDictionary;
    _ = zstdDecodeNativeConcatenatedFrameAllocWithDictionarySetExactSize;
    _ = zstdDecodeNativeConcatenatedFrameIntoWithDictionarySetExactSize;
    _ = zstdDecodeNativeConcatenatedFrameIntoWithDictionarySet;
    _ = zstdDecodeNativeConcatenatedFrameIntoWithDictionarySetLimited;
    _ = zstdDecodedNativeFrameSize;
    _ = zstdDecodedNativeFrameSizeLimited;
    _ = zstdDecodedNativeConcatenatedFrameSize;
    _ = zstdDecodedNativeConcatenatedFrameSizeLimited;
    _ = zstdDecodedNativeConcatenatedFrameSizeWithDictionarySet;
    _ = zstdDecodeNativeConcatenatedFrameChunksAppend;
    _ = zstdDecodeNativeConcatenatedFrameChunksAppendExactSize;
    _ = zstdDecodeNativeConcatenatedFrameChunksAppendLimited;
    _ = zstdDecodeNativeConcatenatedFrameChunksAppendWithDictionary;
    _ = zstdDecodeNativeConcatenatedFrameChunksAppendExactSizeWithDictionary;
    _ = zstdDecodeNativeConcatenatedFrameChunksAppendLimitedWithDictionary;
    _ = zstdDecodeNativeConcatenatedFrameChunksAppendWithDictionarySet;
    _ = zstdDecodeNativeConcatenatedFrameChunksAppendExactSizeWithDictionarySet;
    _ = zstdDecodeNativeConcatenatedFrameChunksAppendLimitedWithDictionarySet;
    _ = zstdDecodedNativeConcatenatedFrameSizeLimitedWithDictionarySet;
    _ = zstdDecodeNativeConcatenatedFrameChunksAlloc;
    _ = zstdDecodeNativeConcatenatedFrameChunksAllocExactSize;
    _ = zstdDecodeNativeConcatenatedFrameChunksAllocLimited;
    _ = zstdDecodeNativeConcatenatedFrameChunksInto;
    _ = zstdDecodeNativeConcatenatedFrameChunksIntoLimited;
    _ = zstdDecodeNativeConcatenatedFrameChunksIntoExactSize;
    _ = zstdDecodedNativeConcatenatedFrameChunksSize;
    _ = zstdDecodedNativeConcatenatedFrameChunksSizeLimited;
    _ = zstdDecodeNativeConcatenatedFrameChunksAllocWithDictionary;
    _ = zstdDecodeNativeConcatenatedFrameChunksAllocWithDictionaryExactSize;
    _ = zstdDecodeNativeConcatenatedFrameChunksAllocWithDictionaryLimited;
    _ = zstdDecodeNativeConcatenatedFrameChunksIntoWithDictionary;
    _ = zstdDecodeNativeConcatenatedFrameChunksIntoWithDictionaryLimited;
    _ = zstdDecodeNativeConcatenatedFrameChunksIntoExactSizeWithDictionary;
    _ = zstdDecodeNativeConcatenatedFrameChunksIntoWithDictionaryExactSize;
    _ = zstdDecodedNativeConcatenatedFrameChunksSizeWithDictionary;
    _ = zstdDecodedNativeConcatenatedFrameChunksSizeLimitedWithDictionary;
    _ = zstdDecodeNativeConcatenatedFrameChunksAllocWithDictionarySet;
    _ = zstdDecodeNativeConcatenatedFrameChunksAllocWithDictionarySetExactSize;
    _ = zstdDecodeNativeConcatenatedFrameChunksAllocWithDictionarySetLimited;
    _ = zstdDecodeNativeConcatenatedFrameChunksIntoWithDictionarySet;
    _ = zstdDecodeNativeConcatenatedFrameChunksIntoWithDictionarySetLimited;
    _ = zstdDecodeNativeConcatenatedFrameChunksIntoExactSizeWithDictionarySet;
    _ = zstdDecodeNativeConcatenatedFrameChunksIntoWithDictionarySetExactSize;
    _ = zstdDecodedNativeConcatenatedFrameChunksSizeWithDictionarySet;
    _ = zstdDecodedNativeConcatenatedFrameChunksSizeLimitedWithDictionarySet;
}

test "root brotli stream helpers expose exact and chunked decode variants" {
    const payload = "root brotli stream helper payload" ** 3;
    const options: BrotliStoredStreamOptions = .{
        .metadata = "root-br-metadata",
    };
    const encoded_bound = try brEncodedStoredStreamBoundWithOptions(payload.len, options);
    const encoded = try brEncodeStoredStreamWithOptionsAlloc(std.testing.allocator, payload, options);
    defer std.testing.allocator.free(encoded);
    try std.testing.expectEqual(encoded.len, encoded_bound);
    const default_encoded = try brEncodeStoredStreamAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(default_encoded);
    try std.testing.expectEqual(default_encoded.len, try brEncodedStoredStreamBound(payload.len));
    const into_encoded = try std.testing.allocator.alloc(u8, encoded_bound);
    defer std.testing.allocator.free(into_encoded);
    try std.testing.expectEqual(encoded.len, try brEncodeStoredStreamWithOptionsInto(payload, into_encoded, options));
    try std.testing.expectEqualSlices(u8, encoded, into_encoded[0..encoded.len]);
    try std.testing.expectError(error.OutOfMemory, brEncodeStoredStreamWithOptionsInto(payload, into_encoded[0 .. encoded.len - 1], options));
    try std.testing.expectError(error.InvalidBlockPlan, brEncodedStoredStreamBoundWithOptions(payload.len, .{ .window_bits = 9 }));
    try std.testing.expectError(error.InvalidBlockPlan, brEncodedStoredStreamBoundWithOptions(payload.len, .{ .metadata = &([_]u8{0} ** 0x1_0001) }));

    const input_chunks = [_][]const u8{
        payload[0..11],
        payload[11..31],
        payload[31..],
    };
    const chunk_encoded_bound = try brEncodedStoredStreamChunksBoundWithOptions(&input_chunks, options);
    const chunk_encoded = try brEncodeStoredStreamChunksWithOptionsAlloc(std.testing.allocator, &input_chunks, options);
    defer std.testing.allocator.free(chunk_encoded);
    try std.testing.expectEqual(chunk_encoded.len, chunk_encoded_bound);
    const chunk_decoded = try brDecodeStreamAllocExactSize(std.testing.allocator, chunk_encoded, payload.len);
    defer std.testing.allocator.free(chunk_decoded);
    try std.testing.expectEqualSlices(u8, payload, chunk_decoded);
    var chunk_append_encoded: std.ArrayList(u8) = .empty;
    defer chunk_append_encoded.deinit(std.testing.allocator);
    try chunk_append_encoded.appendSlice(std.testing.allocator, "prefix:");
    try brEncodeStoredStreamChunksWithOptionsAppend(std.testing.allocator, &chunk_append_encoded, &input_chunks, options);
    try std.testing.expectEqualSlices(u8, "prefix:", chunk_append_encoded.items[0.."prefix:".len]);
    try std.testing.expectEqualSlices(u8, chunk_encoded, chunk_append_encoded.items["prefix:".len..]);
    const chunk_into_encoded = try std.testing.allocator.alloc(u8, chunk_encoded_bound);
    defer std.testing.allocator.free(chunk_into_encoded);
    try std.testing.expectEqual(chunk_encoded.len, try brEncodeStoredStreamChunksWithOptionsInto(&input_chunks, chunk_into_encoded, options));
    try std.testing.expectEqualSlices(u8, chunk_encoded, chunk_into_encoded[0..chunk_encoded.len]);
    try std.testing.expectError(error.OutOfMemory, brEncodeStoredStreamChunksWithOptionsInto(&input_chunks, chunk_into_encoded[0 .. chunk_encoded.len - 1], options));
    const default_chunk_bound = try brEncodedStoredStreamChunksBound(&input_chunks);
    const default_chunk_encoded = try brEncodeStoredStreamChunksAlloc(std.testing.allocator, &input_chunks);
    defer std.testing.allocator.free(default_chunk_encoded);
    try std.testing.expectEqual(default_chunk_encoded.len, default_chunk_bound);
    var default_chunk_appended: std.ArrayList(u8) = .empty;
    defer default_chunk_appended.deinit(std.testing.allocator);
    try brEncodeStoredStreamChunksAppend(std.testing.allocator, &default_chunk_appended, &input_chunks);
    try std.testing.expectEqualSlices(u8, default_chunk_encoded, default_chunk_appended.items);
    const default_chunk_into = try std.testing.allocator.alloc(u8, default_chunk_bound);
    defer std.testing.allocator.free(default_chunk_into);
    try std.testing.expectEqual(default_chunk_encoded.len, try brEncodeStoredStreamChunksInto(&input_chunks, default_chunk_into));
    try std.testing.expectEqualSlices(u8, default_chunk_encoded, default_chunk_into[0..default_chunk_encoded.len]);

    const summary = try brSummarizeStream(encoded);
    try std.testing.expectEqual(@as(u5, 16), summary.window_bits);
    try std.testing.expectEqual(encoded.len, summary.input_bytes);
    try std.testing.expectEqual(payload.len, summary.decoded_bytes);
    try std.testing.expectEqual(@as(usize, 3), summary.meta_block_count);
    try std.testing.expectEqual(@as(usize, 1), summary.empty_meta_block_count);
    try std.testing.expectEqual(@as(usize, 1), summary.metadata_meta_block_count);
    try std.testing.expectEqual(@as(usize, 1), summary.uncompressed_meta_block_count);
    try std.testing.expectEqual(@as(usize, 0), summary.compressed_meta_block_count);
    try std.testing.expectEqual(@as(usize, "root-br-metadata".len), summary.metadata_bytes);
    try std.testing.expect(summary.uses_metadata);
    try std.testing.expect(summary.uses_uncompressed_meta_blocks);
    try std.testing.expect(!summary.uses_compressed_meta_blocks);
    try std.testing.expect(!summary.uses_static_dictionary);
    try std.testing.expect(!summary.stored_only);
    try std.testing.expectEqual(payload.len, (try brSummarizeStreamLimited(encoded, payload.len)).decoded_bytes);
    try std.testing.expectError(error.OutputLimitExceeded, brSummarizeStreamLimited(encoded, payload.len - 1));

    const exact = try brDecodeStreamAllocExactSize(std.testing.allocator, encoded, payload.len);
    defer std.testing.allocator.free(exact);
    try std.testing.expectEqualSlices(u8, payload, exact);
    try std.testing.expectError(error.SizeMismatch, brDecodeStreamAllocExactSize(std.testing.allocator, encoded, payload.len + 1));

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(std.testing.allocator);
    try appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(payload.len, try brDecodeStreamAppend(std.testing.allocator, &appended, encoded));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ payload, appended.items);
    appended.clearRetainingCapacity();
    try appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(payload.len, try brDecodeStreamAppendExactSize(std.testing.allocator, &appended, encoded, payload.len));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ payload, appended.items);
    try std.testing.expectError(error.SizeMismatch, brDecodeStreamAppendExactSize(std.testing.allocator, &appended, encoded, payload.len - 1));
    appended.clearRetainingCapacity();
    try appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(payload.len, try brDecodeStreamAppendLimited(std.testing.allocator, &appended, encoded, payload.len));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ payload, appended.items);
    try std.testing.expectError(error.OutputLimitExceeded, brDecodeStreamAppendLimited(std.testing.allocator, &appended, encoded, payload.len - 1));

    var into: [payload.len]u8 = undefined;
    try std.testing.expectEqual(payload.len, try brDecodeStreamInto(encoded, &into));
    try std.testing.expectEqualSlices(u8, payload, &into);
    @memset(&into, 0xaa);
    try std.testing.expectEqual(payload.len, try brDecodeStreamIntoLimited(encoded, &into, payload.len));
    try std.testing.expectEqualSlices(u8, payload, &into);
    @memset(&into, 0xaa);
    try std.testing.expectError(error.OutputLimitExceeded, brDecodeStreamIntoLimited(encoded, &into, payload.len - 1));
    try std.testing.expectEqualSlices(u8, &([_]u8{0xaa} ** payload.len), &into);
    try std.testing.expectEqual(payload.len, try brDecodeStreamIntoExactSize(encoded, &into, payload.len));
    try std.testing.expectEqualSlices(u8, payload, &into);
    try std.testing.expectError(error.SizeMismatch, brDecodeStreamIntoExactSize(encoded, &into, payload.len - 1));

    const chunks = [_][]const u8{
        encoded[0..2],
        encoded[2..@min(encoded.len, 11)],
        encoded[@min(encoded.len, 11)..],
    };
    const join = try std.testing.allocator.alloc(u8, encoded.len);
    defer std.testing.allocator.free(join);

    try std.testing.expectEqual(payload.len, try brDecodedStreamChunksSize(&chunks, join));
    try std.testing.expectEqual(payload.len, try brDecodedStreamChunksSizeLimited(&chunks, join, payload.len));
    try std.testing.expectError(error.OutputLimitExceeded, brDecodedStreamChunksSizeLimited(&chunks, join, payload.len - 1));
    const chunked_summary = try brSummarizeStreamChunks(&chunks, join);
    try std.testing.expectEqual(summary.decoded_bytes, chunked_summary.decoded_bytes);
    try std.testing.expectEqual(summary.meta_block_count, chunked_summary.meta_block_count);
    try std.testing.expectEqual(summary.empty_meta_block_count, chunked_summary.empty_meta_block_count);
    try std.testing.expectEqual(summary.metadata_bytes, chunked_summary.metadata_bytes);
    try std.testing.expectEqual(payload.len, (try brSummarizeStreamChunksLimited(&chunks, join, payload.len)).decoded_bytes);
    try std.testing.expectError(error.OutputLimitExceeded, brSummarizeStreamChunksLimited(&chunks, join, payload.len - 1));

    const chunked = try brDecodeStreamChunksAlloc(std.testing.allocator, &chunks, join);
    defer std.testing.allocator.free(chunked);
    try std.testing.expectEqualSlices(u8, payload, chunked);
    const chunked_exact = try brDecodeStreamChunksAllocExactSize(std.testing.allocator, &chunks, join, payload.len);
    defer std.testing.allocator.free(chunked_exact);
    try std.testing.expectEqualSlices(u8, payload, chunked_exact);
    try std.testing.expectError(error.SizeMismatch, brDecodeStreamChunksAllocExactSize(std.testing.allocator, &chunks, join, payload.len + 1));
    const chunked_limited = try brDecodeStreamChunksAllocLimited(std.testing.allocator, &chunks, join, payload.len);
    defer std.testing.allocator.free(chunked_limited);
    try std.testing.expectEqualSlices(u8, payload, chunked_limited);
    try std.testing.expectError(error.OutputLimitExceeded, brDecodeStreamChunksAllocLimited(std.testing.allocator, &chunks, join, payload.len - 1));

    var chunked_append: std.ArrayList(u8) = .empty;
    defer chunked_append.deinit(std.testing.allocator);
    try chunked_append.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(payload.len, try brDecodeStreamChunksAppend(std.testing.allocator, &chunked_append, &chunks, join));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ payload, chunked_append.items);
    chunked_append.clearRetainingCapacity();
    try chunked_append.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(payload.len, try brDecodeStreamChunksAppendExactSize(std.testing.allocator, &chunked_append, &chunks, join, payload.len));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ payload, chunked_append.items);
    try std.testing.expectError(error.SizeMismatch, brDecodeStreamChunksAppendExactSize(std.testing.allocator, &chunked_append, &chunks, join, payload.len + 1));
    chunked_append.clearRetainingCapacity();
    try chunked_append.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(payload.len, try brDecodeStreamChunksAppendLimited(std.testing.allocator, &chunked_append, &chunks, join, payload.len));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ payload, chunked_append.items);
    try std.testing.expectError(error.OutputLimitExceeded, brDecodeStreamChunksAppendLimited(std.testing.allocator, &chunked_append, &chunks, join, payload.len - 1));

    @memset(&into, 0);
    try std.testing.expectEqual(payload.len, try brDecodeStreamChunksInto(&chunks, join, &into));
    try std.testing.expectEqualSlices(u8, payload, &into);
    @memset(&into, 0);
    try std.testing.expectEqual(payload.len, try brDecodeStreamChunksIntoLimited(&chunks, join, &into, payload.len));
    try std.testing.expectEqualSlices(u8, payload, &into);
    @memset(&into, 0xaa);
    try std.testing.expectError(error.OutputLimitExceeded, brDecodeStreamChunksIntoLimited(&chunks, join, &into, payload.len - 1));
    try std.testing.expectEqualSlices(u8, &([_]u8{0xaa} ** payload.len), &into);
    @memset(&into, 0);
    try std.testing.expectEqual(payload.len, try brDecodeStreamChunksIntoExactSize(&chunks, join, &into, payload.len));
    try std.testing.expectEqualSlices(u8, payload, &into);
    try std.testing.expectError(error.SizeMismatch, brDecodeStreamChunksIntoExactSize(&chunks, join, &into, payload.len - 1));
}

test "root brotli static dictionary introspection exposes coverage" {
    const coverage = brMinimalStaticDictionaryCoverage();
    try std.testing.expect(coverage.len > 0);
    try std.testing.expectEqual(@as(?u5, 10), brMinimalStaticDictionarySizeBits(5));
    try std.testing.expectEqual(@as(?u5, 11), brMinimalStaticDictionarySizeBits(6));
    try std.testing.expectEqual(@as(?u5, null), brMinimalStaticDictionarySizeBits(3));

    var found_hello = false;
    var found_dictionary_space = false;
    for (coverage) |entry| {
        if (entry.transform == 0 and entry.copy_len == 5 and entry.word_index == 719 and std.mem.eql(u8, entry.word, "hello")) {
            found_hello = true;
        }
        if (entry.transform == 1 and entry.copy_len == 10 and entry.word_index == 205 and std.mem.eql(u8, entry.word, "dictionary ")) {
            found_dictionary_space = true;
        }
    }
    try std.testing.expect(found_hello);
    try std.testing.expect(found_dictionary_space);
}

test "root brotli prefix code type decodes single symbol" {
    const Prefix = BrotliPrefixCode(256);
    const prefix = Prefix{ .single_symbol = 'Z' };
    var reader = bitstream.BitReader.init(&.{});
    try std.testing.expectEqual(@as(u16, 'Z'), try prefix.decode(&reader));
}

test "root brotli stored stream encoder reuses scratch" {
    const payload = "root brotli reusable encoder payload" ** 2;
    const options: BrotliStoredStreamOptions = .{
        .metadata = "reusable-meta",
        .window_bits = 18,
    };
    const expected = try brEncodeStoredStreamWithOptionsAlloc(std.testing.allocator, payload, options);
    defer std.testing.allocator.free(expected);

    var encoder = BrotliStoredStreamEncoder.init(std.testing.allocator);
    defer encoder.deinit();

    const owned = try encoder.encodeWithOptionsAlloc(payload, options);
    defer std.testing.allocator.free(owned);
    try std.testing.expectEqualSlices(u8, expected, owned);

    const scratch = try encoder.encodeScratchWithOptions(payload, options);
    try std.testing.expectEqualSlices(u8, expected, scratch);

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(std.testing.allocator);
    try appended.appendSlice(std.testing.allocator, "prefix:");
    try encoder.encodeWithOptionsAppend(&appended, payload, options);
    try std.testing.expectEqualSlices(u8, "prefix:", appended.items[0.."prefix:".len]);
    try std.testing.expectEqualSlices(u8, expected, appended.items["prefix:".len..]);

    const into = try std.testing.allocator.alloc(u8, try brEncodedStoredStreamBoundWithOptions(payload.len, options));
    defer std.testing.allocator.free(into);
    try std.testing.expectEqual(expected.len, try encoder.encodeWithOptionsIntoSlice(payload, options, into));
    try std.testing.expectEqualSlices(u8, expected, into[0..expected.len]);

    const chunks = [_][]const u8{
        payload[0..9],
        payload[9..27],
        payload[27..],
    };
    const expected_chunks = try brEncodeStoredStreamChunksWithOptionsAlloc(std.testing.allocator, &chunks, options);
    defer std.testing.allocator.free(expected_chunks);
    const chunk_owned = try encoder.encodeChunksWithOptionsAlloc(&chunks, options);
    defer std.testing.allocator.free(chunk_owned);
    try std.testing.expectEqualSlices(u8, expected_chunks, chunk_owned);
    const chunk_scratch = try encoder.encodeChunksScratchWithOptions(&chunks, options);
    try std.testing.expectEqualSlices(u8, expected_chunks, chunk_scratch);
    var chunk_appended: std.ArrayList(u8) = .empty;
    defer chunk_appended.deinit(std.testing.allocator);
    try encoder.encodeChunksWithOptionsAppend(&chunk_appended, &chunks, options);
    try std.testing.expectEqualSlices(u8, expected_chunks, chunk_appended.items);
    const chunk_into = try std.testing.allocator.alloc(u8, try brEncodedStoredStreamChunksBoundWithOptions(&chunks, options));
    defer std.testing.allocator.free(chunk_into);
    try std.testing.expectEqual(expected_chunks.len, try encoder.encodeChunksWithOptionsIntoSlice(&chunks, options, chunk_into));
    try std.testing.expectEqualSlices(u8, expected_chunks, chunk_into[0..expected_chunks.len]);

    const decoded = try brDecodeStreamAllocExactSize(std.testing.allocator, chunk_scratch, payload.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);

    const default_expected = try brEncodeStoredStreamAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(default_expected);
    const default_scratch = try encoder.encodeScratch(payload);
    try std.testing.expectEqualSlices(u8, default_expected, default_scratch);
    const default_owned = try encoder.encodeAlloc(payload);
    defer std.testing.allocator.free(default_owned);
    try std.testing.expectEqualSlices(u8, default_expected, default_owned);
    var default_appended: std.ArrayList(u8) = .empty;
    defer default_appended.deinit(std.testing.allocator);
    try encoder.encodeAppend(&default_appended, payload);
    try std.testing.expectEqualSlices(u8, default_expected, default_appended.items);
    const default_into = try std.testing.allocator.alloc(u8, try brEncodedStoredStreamBound(payload.len));
    defer std.testing.allocator.free(default_into);
    try std.testing.expectEqual(default_expected.len, try encoder.encodeIntoSlice(payload, default_into));
    try std.testing.expectEqualSlices(u8, default_expected, default_into[0..default_expected.len]);

    const default_chunks_expected = try brEncodeStoredStreamChunksAlloc(std.testing.allocator, &chunks);
    defer std.testing.allocator.free(default_chunks_expected);
    const default_chunks_scratch = try encoder.encodeChunksScratch(&chunks);
    try std.testing.expectEqualSlices(u8, default_chunks_expected, default_chunks_scratch);
    const default_chunks_owned = try encoder.encodeChunksAlloc(&chunks);
    defer std.testing.allocator.free(default_chunks_owned);
    try std.testing.expectEqualSlices(u8, default_chunks_expected, default_chunks_owned);
    var default_chunks_appended: std.ArrayList(u8) = .empty;
    defer default_chunks_appended.deinit(std.testing.allocator);
    try encoder.encodeChunksAppend(&default_chunks_appended, &chunks);
    try std.testing.expectEqualSlices(u8, default_chunks_expected, default_chunks_appended.items);
    const default_chunks_into = try std.testing.allocator.alloc(u8, try brEncodedStoredStreamChunksBound(&chunks));
    defer std.testing.allocator.free(default_chunks_into);
    try std.testing.expectEqual(default_chunks_expected.len, try encoder.encodeChunksIntoSlice(&chunks, default_chunks_into));
    try std.testing.expectEqualSlices(u8, default_chunks_expected, default_chunks_into[0..default_chunks_expected.len]);
}

test "root brotli stream summary exposes capability flags" {
    const stored_payload = "stored only brotli payload";
    const stored = try brEncodeStoredStreamAlloc(std.testing.allocator, stored_payload);
    defer std.testing.allocator.free(stored);
    const stored_summary = try brSummarizeStream(stored);
    try std.testing.expect(stored_summary.stored_only);
    try std.testing.expect(stored_summary.uses_uncompressed_meta_blocks);
    try std.testing.expect(!stored_summary.uses_metadata);
    try std.testing.expect(!stored_summary.uses_compressed_meta_blocks);
    try std.testing.expect(!stored_summary.uses_static_dictionary);
    try std.testing.expectEqual(@as(usize, 0), stored_summary.static_dictionary_copy_count);
    try std.testing.expectEqual(@as(usize, 0), stored_summary.static_dictionary_bytes);
    try std.testing.expectEqual(@as(usize, 0), stored_summary.command_count);
    try std.testing.expectEqual(@as(usize, 0), stored_summary.zero_insert_command_count);
    try std.testing.expectEqual(@as(usize, 0), stored_summary.single_literal_insert_command_count);
    try std.testing.expectEqual(@as(usize, 0), stored_summary.implicit_distance_command_count);
    try std.testing.expectEqual(@as(usize, 0), stored_summary.implicit_distance_copy_count);
    try std.testing.expectEqual(@as(usize, 0), stored_summary.short_distance_copy_count);
    try std.testing.expectEqual(@as(usize, 0), stored_summary.direct_distance_copy_count);
    try std.testing.expectEqual(@as(usize, 0), stored_summary.regular_distance_copy_count);
    try std.testing.expectEqual(@as(u2, 0), stored_summary.max_distance_postfix_bits);
    try std.testing.expectEqual(@as(u16, 0), stored_summary.max_direct_distance_codes);
    try std.testing.expectEqual([_]usize{ 0, 0, 0, 0, 0, 0, 0, 0, 0 }, stored_summary.copy_length_log2_histogram);
    try std.testing.expectEqual(@as(usize, 0), stored_summary.lz77_copy_count);
    try std.testing.expectEqual(@as(usize, 0), stored_summary.lz77_copy_bytes);
    try std.testing.expectEqual([_]usize{ 0, 0, 0, 0 }, stored_summary.literal_context_mode_bytes);

    const static_dictionary_frame = [_]u8{
        0xa1, 0xc0, 0x00, 0x00, 0x20, 0xe0, 0x38, 0xbc,
        0xde, 0xdd, 0x77, 0x5f, 0x44, 0xa4, 0x1a, 0x24,
        0x9f, 0x6a, 0x3c, 0xa7, 0x83, 0xd6, 0xc7, 0x00,
    };
    const static_summary = try brSummarizeStream(&static_dictionary_frame);
    try std.testing.expect(!static_summary.stored_only);
    try std.testing.expect(static_summary.uses_compressed_meta_blocks);
    try std.testing.expect(static_summary.uses_static_dictionary);
    try std.testing.expect(static_summary.static_dictionary_copy_count > 0);
    try std.testing.expect(static_summary.static_dictionary_bytes > 0);
    try std.testing.expectEqual(
        static_summary.lz77_copy_count + static_summary.static_dictionary_copy_count,
        static_summary.implicit_distance_copy_count + static_summary.short_distance_copy_count +
            static_summary.direct_distance_copy_count + static_summary.regular_distance_copy_count,
    );
}

test "root brotli compressed support limits expose current bounded capacities" {
    const limits: BrotliCompressedSupportLimits = brCompressedSupportLimits();
    try std.testing.expectEqual(@as(usize, 256), limits.max_literal_block_types);
    try std.testing.expectEqual(@as(usize, 256), limits.max_literal_context_trees);
    try std.testing.expectEqual(@as(usize, 256), limits.max_command_block_types);
    try std.testing.expectEqual(@as(usize, 256), limits.max_distance_block_types);
    try std.testing.expectEqual(@as(usize, 256), limits.max_distance_context_trees);
    try std.testing.expect(limits.max_distance_alphabet_size >= 16 + 120 + (48 << 3));
}

test "root brotli stream summary exposes compressed tree coverage" {
    const encoded = try brEncodeRleStreamAlloc(std.testing.allocator, "z" ** 128);
    defer std.testing.allocator.free(encoded);
    const summary = try brSummarizeStream(encoded);
    try std.testing.expectEqual(@as(usize, 1), summary.max_literal_context_trees);
    try std.testing.expectEqual(@as(usize, 1), summary.command_count);
    try std.testing.expectEqual(@as(usize, 0), summary.zero_insert_command_count);
    try std.testing.expectEqual(@as(usize, 1), summary.single_literal_insert_command_count);
    try std.testing.expectEqual(@as(usize, 0), summary.implicit_distance_command_count);
    try std.testing.expectEqual(@as(usize, 0), summary.implicit_distance_copy_count);
    try std.testing.expectEqual(
        @as(usize, 1),
        summary.short_distance_copy_count + summary.direct_distance_copy_count +
            summary.regular_distance_copy_count,
    );
    try std.testing.expect(summary.max_distance_postfix_bits <= 3);
    try std.testing.expect(summary.max_direct_distance_codes <= 120);
    try std.testing.expectEqual([_]usize{ 0, 0, 0, 0, 0, 0, 1, 0, 0 }, summary.copy_length_log2_histogram);
    try std.testing.expectEqual(@as(usize, 1), summary.lz77_copy_count);
    try std.testing.expectEqual(@as(usize, 127), summary.lz77_copy_bytes);
}

test "root brotli stream summary diagnostics report failure phases" {
    var diagnostics: BrotliStreamSummaryDiagnostics = .{};
    try std.testing.expectError(error.TruncatedFrame, brSummarizeStreamWithDiagnostics("", &diagnostics));
    try std.testing.expectEqual(BrotliStreamSummaryErrorPhase.window_bits, diagnostics.phase);
    try std.testing.expectEqual(@as(usize, 0), diagnostics.offset);
    try std.testing.expectEqual(@as(usize, 0), diagnostics.meta_block_index);

    const truncated_compressed = [_]u8{ 0x00, 0x00, 0x00 };
    diagnostics = .{};
    try std.testing.expectError(error.TruncatedFrame, brSummarizeStreamWithDiagnostics(&truncated_compressed, &diagnostics));
    try std.testing.expectEqual(BrotliStreamSummaryErrorPhase.compressed_meta_block, diagnostics.phase);
    try std.testing.expectEqual(@as(usize, 0), diagnostics.meta_block_index);

    diagnostics = .{};
    try std.testing.expectError(error.TrailingData, brSummarizeStreamWithDiagnostics(&.{ 0x06, 0x00 }, &diagnostics));
    try std.testing.expectEqual(BrotliStreamSummaryErrorPhase.padding, diagnostics.phase);
    try std.testing.expectEqual(@as(usize, 0), diagnostics.meta_block_index);

    const payload = "brotli summary diagnostic payload";
    const encoded = try brEncodeStoredStreamAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);
    diagnostics = .{};
    const summary = try brSummarizeStreamWithDiagnostics(encoded, &diagnostics);
    try std.testing.expectEqual(payload.len, summary.decoded_bytes);
    try std.testing.expectEqual(BrotliStreamSummaryErrorPhase.stream, diagnostics.phase);
    try std.testing.expectEqual(@as(usize, 0), diagnostics.offset);

    diagnostics = .{};
    try std.testing.expectError(error.OutputLimitExceeded, brSummarizeStreamLimitedWithDiagnostics(encoded, payload.len - 1, &diagnostics));
    try std.testing.expectEqual(BrotliStreamSummaryErrorPhase.meta_block_header, diagnostics.phase);
    try std.testing.expectEqual(@as(usize, 0), diagnostics.meta_block_index);

    const chunks = [_][]const u8{
        encoded[0..1],
        encoded[1..@min(encoded.len, 7)],
        encoded[@min(encoded.len, 7)..],
    };
    const join = try std.testing.allocator.alloc(u8, encoded.len);
    defer std.testing.allocator.free(join);
    diagnostics = .{};
    try std.testing.expectError(error.OutputLimitExceeded, brSummarizeStreamChunksLimitedWithDiagnostics(&chunks, join, payload.len - 1, &diagnostics));
    try std.testing.expectEqual(BrotliStreamSummaryErrorPhase.meta_block_header, diagnostics.phase);
    try std.testing.expectEqual(@as(usize, 0), diagnostics.meta_block_index);
}

test "root brotli planned chunked encoder produces one multi-block stream" {
    const first = "root planned first block " ** 32;
    const middle = "qzxwvbnm1234567890QZXWVBNM!@#$%^&*";
    const last = "root planned last block " ** 32;
    const chunks = [_][]const u8{ first, middle, last };
    const expected = first ++ middle ++ last;
    const encoded = try brEncodePlannedStreamChunksAlloc(std.testing.allocator, &chunks);
    defer std.testing.allocator.free(encoded);
    const bound = try brEncodedPlannedStreamChunksBound(&chunks);
    try std.testing.expect(encoded.len <= bound);

    const output = try std.testing.allocator.alloc(u8, bound);
    defer std.testing.allocator.free(output);
    const written = try brEncodePlannedStreamChunksInto(&chunks, output);
    try std.testing.expectEqualSlices(u8, encoded, output[0..written]);

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(std.testing.allocator);
    try brEncodePlannedStreamChunksAppend(std.testing.allocator, &appended, &chunks);
    try std.testing.expectEqualSlices(u8, encoded, appended.items);
    const decoded = try brDecodeStreamAllocExactSize(std.testing.allocator, encoded, expected.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, expected, decoded);
}

test "root brotli caller-history summaries cover contiguous and chunked streams" {
    const payload = "caller-owned Brotli summary history" ** 64;
    const encoded = try brEncodePlannedStreamAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);

    var history: [64]u8 = undefined;
    const expected = try brSummarizeStream(encoded);
    const direct = try brSummarizeStreamWithHistory(encoded, &history);
    try std.testing.expectEqual(expected, direct);
    try std.testing.expectEqual(payload.len, (try brSummarizeStreamLimitedWithHistory(encoded, &history, payload.len)).decoded_bytes);
    try std.testing.expectError(error.OutputLimitExceeded, brSummarizeStreamLimitedWithHistory(encoded, &history, payload.len - 1));

    var diagnostics: BrotliStreamSummaryDiagnostics = undefined;
    const empty_history = try brSummarizeStreamWithHistoryAndDiagnostics(encoded, &.{}, &diagnostics);
    try std.testing.expectEqual(expected, empty_history);
    try std.testing.expectEqual(BrotliStreamSummaryErrorPhase.stream, diagnostics.phase);

    const chunks = [_][]const u8{ encoded[0..1], encoded[1 .. encoded.len - 1], encoded[encoded.len - 1 ..] };
    const joined = try std.testing.allocator.alloc(u8, encoded.len);
    defer std.testing.allocator.free(joined);
    const chunked = try brSummarizeStreamChunksWithHistory(&chunks, joined, &history);
    try std.testing.expectEqual(expected, chunked);
    try std.testing.expectEqual(payload.len, (try brSummarizeStreamChunksLimitedWithHistory(&chunks, joined, &history, payload.len)).decoded_bytes);
    try std.testing.expectError(error.OutputLimitExceeded, brSummarizeStreamChunksLimitedWithHistoryAndDiagnostics(&chunks, joined, &history, payload.len - 1, &diagnostics));
    try std.testing.expectEqual(BrotliStreamSummaryErrorPhase.meta_block_header, diagnostics.phase);
}

test "root brotli stream probe returns non-throwing support results" {
    const payload = "brotli probe payload";
    const encoded = try brEncodeStoredStreamAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);

    const ok = brProbeStream(encoded);
    try std.testing.expect(ok.ok);
    try std.testing.expectEqualStrings("", ok.error_name);
    try std.testing.expectEqual(payload.len, ok.summary.?.decoded_bytes);
    try std.testing.expectEqual(BrotliStreamSummaryErrorPhase.stream, ok.diagnostics.phase);
    const exact_ok = brProbeStreamExactSize(encoded, payload.len);
    try std.testing.expect(exact_ok.ok);
    try std.testing.expectEqual(payload.len, exact_ok.summary.?.decoded_bytes);
    const exact_bad = brProbeStreamExactSize(encoded, payload.len + 1);
    try std.testing.expect(!exact_bad.ok);
    try std.testing.expectEqualStrings("SizeMismatch", exact_bad.error_name);
    try std.testing.expectEqual(BrotliStreamSummaryErrorPhase.output_size, exact_bad.diagnostics.phase);
    try std.testing.expectEqual(payload.len, exact_bad.summary.?.decoded_bytes);

    const limited = brProbeStreamLimited(encoded, payload.len - 1);
    try std.testing.expect(!limited.ok);
    try std.testing.expect(limited.summary == null);
    try std.testing.expectEqualStrings("OutputLimitExceeded", limited.error_name);
    try std.testing.expectEqual(BrotliStreamSummaryErrorPhase.meta_block_header, limited.diagnostics.phase);

    const truncated = brProbeStream("");
    try std.testing.expect(!truncated.ok);
    try std.testing.expectEqualStrings("TruncatedFrame", truncated.error_name);
    try std.testing.expectEqual(BrotliStreamSummaryErrorPhase.window_bits, truncated.diagnostics.phase);

    const chunks = [_][]const u8{
        encoded[0..2],
        encoded[2..@min(encoded.len, 8)],
        encoded[@min(encoded.len, 8)..],
    };
    const join = try std.testing.allocator.alloc(u8, encoded.len);
    defer std.testing.allocator.free(join);
    const chunked_ok = brProbeStreamChunks(&chunks, join);
    try std.testing.expect(chunked_ok.ok);
    try std.testing.expectEqual(payload.len, chunked_ok.summary.?.decoded_bytes);
    const chunked_exact_bad = brProbeStreamChunksExactSize(&chunks, join, payload.len - 1);
    try std.testing.expect(!chunked_exact_bad.ok);
    try std.testing.expectEqualStrings("SizeMismatch", chunked_exact_bad.error_name);
    try std.testing.expectEqual(BrotliStreamSummaryErrorPhase.output_size, chunked_exact_bad.diagnostics.phase);
    const chunked_limited = brProbeStreamChunksLimited(&chunks, join, payload.len - 1);
    try std.testing.expect(!chunked_limited.ok);
    try std.testing.expectEqualStrings("OutputLimitExceeded", chunked_limited.error_name);
}

test "root brotli stream decoder drains caller-owned scratch and resets" {
    const first_payload = "brotli reusable decoder first payload";
    const first_encoded = try brEncodeStoredStreamAlloc(std.testing.allocator, first_payload);
    defer std.testing.allocator.free(first_encoded);
    var scratch: [first_payload.len + 16]u8 = undefined;
    var decoder = try BrotliStreamDecoder.initExactSize(first_encoded, &scratch, first_payload.len);

    var first_out: [first_payload.len]u8 = undefined;
    var step = try decoder.step(first_out[0..7]);
    try std.testing.expectEqual(core.StepResult.Status.need_output, step.status);
    try std.testing.expectEqual(@as(usize, 0), step.progress.input_read);
    try std.testing.expectEqual(@as(usize, 7), step.progress.output_written);
    step = try decoder.step(first_out[7..]);
    try std.testing.expectEqual(core.StepResult.Status.done, step.status);
    try std.testing.expectEqual(first_encoded.len, step.progress.input_read);
    try std.testing.expectEqual(first_payload.len - 7, step.progress.output_written);
    try std.testing.expectEqualSlices(u8, first_payload, &first_out);
    const done_snapshot = decoder.snapshot();
    try std.testing.expect(done_snapshot.done);
    try std.testing.expectEqual(first_payload.len, done_snapshot.output_written);
    try std.testing.expectEqual(@as(usize, 0), done_snapshot.payload_remaining);
    const done_diagnostics = decoder.diagnostics();
    try std.testing.expectEqualStrings("done", done_diagnostics.phase_name);
    try std.testing.expectEqual(first_encoded.len, done_diagnostics.frame_input_read.?);

    const second_payload = "second brotli payload through chunks";
    const second_encoded = try brEncodeStoredStreamWithOptionsAlloc(std.testing.allocator, second_payload, .{
        .metadata = "second-meta",
    });
    defer std.testing.allocator.free(second_encoded);
    const chunks = [_][]const u8{
        second_encoded[0..1],
        second_encoded[1..@min(second_encoded.len, 9)],
        second_encoded[@min(second_encoded.len, 9)..],
    };
    const compressed_scratch = try std.testing.allocator.alloc(u8, second_encoded.len);
    defer std.testing.allocator.free(compressed_scratch);
    try decoder.resetFromChunksLimited(&chunks, compressed_scratch, scratch[0..], second_payload.len);

    var second_out: [second_payload.len]u8 = undefined;
    step = try decoder.step(&second_out);
    try std.testing.expectEqual(core.StepResult.Status.done, step.status);
    try std.testing.expectEqual(second_encoded.len, step.progress.input_read);
    try std.testing.expectEqual(second_payload.len, step.progress.output_written);
    try std.testing.expectEqualSlices(u8, second_payload, &second_out);

    try std.testing.expectError(error.SizeMismatch, decoder.resetExactSize(first_encoded, &scratch, first_payload.len + 1));
    const error_snapshot = decoder.snapshot();
    try std.testing.expectEqualStrings("SizeMismatch", error_snapshot.last_error_name);
    const error_diagnostics = decoder.diagnostics();
    try std.testing.expectEqualStrings("payload_corrupt", error_diagnostics.recoverability_hint_name);
}

test "root snappy raw block helpers round trip" {
    const encoded = try snappyEncodeBlockAlloc(std.testing.allocator, "hello");
    defer std.testing.allocator.free(encoded);

    try std.testing.expect(encoded.len <= try snappyEncodedBlockBound("hello".len));
    const summary = try snappySummarizeBlock(encoded);
    try std.testing.expectEqual(@as(usize, 5), summary.decoded_bytes);
    try std.testing.expectEqual(@as(usize, 1), summary.literal_count);
    try std.testing.expectEqual(@as(usize, 0), summary.copy_count);
    const limited_summary = try snappySummarizeBlockLimited(encoded, 5);
    try std.testing.expectEqual(summary.decoded_bytes, limited_summary.decoded_bytes);
    try std.testing.expectEqual(summary.literal_count, limited_summary.literal_count);
    try std.testing.expectError(error.OutputLimitExceeded, snappySummarizeBlockLimited(encoded, 4));
    try std.testing.expectEqual(@as(usize, 5), try snappyDecodedBlockSize(encoded));
    try std.testing.expectError(error.OutputLimitExceeded, snappyDecodedBlockSizeLimited(encoded, 4));

    var decoded: [5]u8 = undefined;
    try std.testing.expectEqual(@as(usize, decoded.len), try snappyDecodeBlockInto(encoded, &decoded));
    try std.testing.expectEqualSlices(u8, "hello", &decoded);
    try std.testing.expectEqual(@as(usize, decoded.len), try snappyDecodeBlockIntoExactSize(encoded, &decoded, decoded.len));
    try std.testing.expectError(error.SizeMismatch, snappyDecodeBlockIntoExactSize(encoded, &decoded, decoded.len - 1));

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(std.testing.allocator);
    try appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectError(error.SizeMismatch, snappyDecodeBlockAppendExactSize(std.testing.allocator, &appended, encoded, 4));
    try std.testing.expectEqual(@as(usize, 5), try snappyDecodeBlockAppendExactSize(std.testing.allocator, &appended, encoded, 5));
    try std.testing.expectEqualSlices(u8, "prefix:hello", appended.items);

    const exact = try snappyDecodeBlockAllocExactSize(std.testing.allocator, encoded, 5);
    defer std.testing.allocator.free(exact);
    try std.testing.expectEqualSlices(u8, "hello", exact);

    const block_bound = try snappyEncodedBlockBound("hello".len);
    const encoded_into = try std.testing.allocator.alloc(u8, block_bound);
    defer std.testing.allocator.free(encoded_into);
    const encoded_written = try snappyEncodeBlockInto("hello", encoded_into);
    try std.testing.expectEqual(encoded.len, encoded_written);
    try std.testing.expectEqualSlices(u8, encoded, encoded_into[0..encoded_written]);
}

test "root snappy framed stream helpers round trip" {
    const encoded = try snappyEncodeFrameAlloc(std.testing.allocator, "hello");
    defer std.testing.allocator.free(encoded);

    try std.testing.expect(encoded.len <= try snappyEncodedFrameBound("hello".len));
    const summary = try snappySummarizeFrame(encoded);
    try std.testing.expectEqual(@as(usize, 1), summary.stream_identifier_count);
    try std.testing.expectEqual(@as(usize, 5), summary.decoded_bytes);
    try std.testing.expectEqual(@as(usize, 5), try snappyDecodedFrameSize(encoded));
    try std.testing.expectError(error.OutputLimitExceeded, snappyDecodedFrameSizeLimited(encoded, 4));

    var decoded: [5]u8 = undefined;
    try std.testing.expectEqual(@as(usize, decoded.len), try snappyDecodeFrameInto(encoded, &decoded));
    try std.testing.expectEqualSlices(u8, "hello", &decoded);
    try std.testing.expectEqual(@as(usize, decoded.len), try snappyDecodeFrameIntoExactSize(encoded, &decoded, decoded.len));
    var larger_decoded: [6]u8 = undefined;
    try std.testing.expectError(error.SizeMismatch, snappyDecodeFrameIntoExactSize(encoded, &larger_decoded, larger_decoded.len));

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(std.testing.allocator);
    try appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectError(error.SizeMismatch, snappyDecodeFrameAppendExactSize(std.testing.allocator, &appended, encoded, 4));
    try std.testing.expectEqual(@as(usize, 5), try snappyDecodeFrameAppendExactSize(std.testing.allocator, &appended, encoded, 5));
    try std.testing.expectEqualSlices(u8, "prefix:hello", appended.items);

    const exact = try snappyDecodeFrameAllocExactSize(std.testing.allocator, encoded, 5);
    defer std.testing.allocator.free(exact);
    try std.testing.expectEqualSlices(u8, "hello", exact);

    const frame_bound = try snappyEncodedFrameBound("hello".len);
    const encoded_into = try std.testing.allocator.alloc(u8, frame_bound);
    defer std.testing.allocator.free(encoded_into);
    const encoded_written = try snappyEncodeFrameInto("hello", encoded_into);
    try std.testing.expectEqual(encoded.len, encoded_written);
    try std.testing.expectEqualSlices(u8, encoded, encoded_into[0..encoded_written]);
}

test "root snappy chunked decode helpers round trip" {
    const payload = "root snappy chunked payload " ** 64;
    const block = try snappyEncodeBlockAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(block);
    const block_chunks = [_][]const u8{ block[0..2], block[2..@min(block.len, 17)], block[@min(block.len, 17)..] };
    const block_scratch = try std.testing.allocator.alloc(u8, block.len);
    defer std.testing.allocator.free(block_scratch);

    try std.testing.expectEqual(payload.len, try snappyDecodedBlockChunksSize(&block_chunks, block_scratch));
    const block_summary = try snappySummarizeBlockChunks(&block_chunks, block_scratch);
    try std.testing.expectEqual(payload.len, block_summary.decoded_bytes);
    try std.testing.expect(block_summary.copy_count > 0);
    var block_output: [payload.len]u8 = undefined;
    try std.testing.expectEqual(payload.len, try snappyDecodeBlockChunksInto(&block_chunks, block_scratch, &block_output));
    try std.testing.expectEqualSlices(u8, payload, &block_output);
    const block_decoded = try snappyDecodeBlockChunksAllocLimited(std.testing.allocator, &block_chunks, block_scratch, payload.len);
    defer std.testing.allocator.free(block_decoded);
    try std.testing.expectEqualSlices(u8, payload, block_decoded);
    const block_exact = try snappyDecodeBlockChunksAllocExactSize(std.testing.allocator, &block_chunks, block_scratch, payload.len);
    defer std.testing.allocator.free(block_exact);
    try std.testing.expectEqualSlices(u8, payload, block_exact);
    try std.testing.expectError(error.SizeMismatch, snappyDecodeBlockChunksIntoExactSize(&block_chunks, block_scratch, &block_output, payload.len - 1));

    const frame = try snappyEncodeFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(frame);
    const frame_chunks = [_][]const u8{ frame[0..5], frame[5..@min(frame.len, 19)], frame[@min(frame.len, 19)..] };
    const frame_scratch = try std.testing.allocator.alloc(u8, frame.len);
    defer std.testing.allocator.free(frame_scratch);

    try std.testing.expectEqual(payload.len, try snappyDecodedFrameChunksSize(&frame_chunks, frame_scratch));
    const frame_summary = try snappySummarizeFrameChunks(&frame_chunks, frame_scratch);
    try std.testing.expectEqual(payload.len, frame_summary.decoded_bytes);
    try std.testing.expectEqual(@as(usize, 1), frame_summary.stream_identifier_count);
    var frame_output: [payload.len]u8 = undefined;
    try std.testing.expectEqual(payload.len, try snappyDecodeFrameChunksInto(&frame_chunks, frame_scratch, &frame_output));
    try std.testing.expectEqualSlices(u8, payload, &frame_output);
    try std.testing.expectEqual(payload.len, try snappyDecodeFrameChunksIntoExactSize(&frame_chunks, frame_scratch, &frame_output, payload.len));
    try std.testing.expectError(error.SizeMismatch, snappyDecodeFrameChunksAllocExactSize(std.testing.allocator, &frame_chunks, frame_scratch, payload.len + 1));

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(std.testing.allocator);
    try appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectError(error.SizeMismatch, snappyDecodeFrameChunksAppendExactSize(std.testing.allocator, &appended, &frame_chunks, frame_scratch, payload.len - 1));
    try std.testing.expectEqual(payload.len, try snappyDecodeFrameChunksAppendExactSize(std.testing.allocator, &appended, &frame_chunks, frame_scratch, payload.len));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ payload, appended.items);
}

test "root snappy reusable encoder round trip" {
    var encoder = SnappyEncoder.init(std.testing.allocator);
    defer encoder.deinit();

    const payload = "root reusable snappy payload " ** 128;
    const block = try encoder.encodeBlockAlloc(payload);
    defer std.testing.allocator.free(block);
    const decoded_block = try snappyDecodeBlockAlloc(std.testing.allocator, block);
    defer std.testing.allocator.free(decoded_block);
    try std.testing.expectEqualSlices(u8, payload, decoded_block);

    const frame = try encoder.encodeFrameAlloc(payload);
    defer std.testing.allocator.free(frame);
    const decoded_frame = try snappyDecodeFrameAlloc(std.testing.allocator, frame);
    defer std.testing.allocator.free(decoded_frame);
    try std.testing.expectEqualSlices(u8, payload, decoded_frame);
}

test "root lz4 frame options round trip" {
    const payload = "root lz4 frame options payload" ** 2;
    const encoded = try lz4EncodeFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .include_content_size = false,
        .content_checksum = false,
        .block_checksum = true,
        .block_size_id = .max64kb,
        .block_mode = .independent,
    });
    defer std.testing.allocator.free(encoded);

    const decoded = try lz4DecodeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    try std.testing.expectEqual(payload.len, try lz4DecodedFrameSizeLimited(encoded, payload.len));
    try std.testing.expectError(error.OutputLimitExceeded, lz4DecodedFrameSizeLimited(encoded, payload.len - 1));
    var lib_into: [payload.len]u8 = undefined;
    try std.testing.expectEqual(payload.len, try lz4DecodeFrameIntoExactSize(encoded, &lib_into, payload.len));
    try std.testing.expectEqualSlices(u8, payload, &lib_into);
    try std.testing.expectError(error.OutputTooSmall, lz4DecodeFrameIntoExactSize(encoded, lib_into[0 .. lib_into.len - 1], payload.len));
    try std.testing.expectError(error.SizeMismatch, lz4DecodeFrameIntoExactSize(encoded, &lib_into, payload.len - 1));
    var lib_appended: std.ArrayList(u8) = .empty;
    defer lib_appended.deinit(std.testing.allocator);
    try lib_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(payload.len, try lz4DecodeFrameAppendExactSize(std.testing.allocator, &lib_appended, encoded, payload.len));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ payload, lib_appended.items);
    lib_appended.clearRetainingCapacity();
    try std.testing.expectError(error.SizeMismatch, lz4DecodeFrameAppendExactSize(std.testing.allocator, &lib_appended, encoded, payload.len - 1));
    const lib_chunks = [_][]const u8{
        encoded[0..4],
        encoded[4 .. encoded.len - 2],
        encoded[encoded.len - 2 ..],
    };
    const lib_join = try std.testing.allocator.alloc(u8, encoded.len);
    defer std.testing.allocator.free(lib_join);
    var lib_chunked_into: [payload.len]u8 = undefined;
    try std.testing.expectEqual(payload.len, try lz4DecodeFrameChunksIntoExactSize(&lib_chunks, lib_join, &lib_chunked_into, payload.len));
    try std.testing.expectEqualSlices(u8, payload, &lib_chunked_into);
    try std.testing.expectError(error.OutputTooSmall, lz4DecodeFrameChunksIntoExactSize(&lib_chunks, lib_join, lib_chunked_into[0 .. lib_chunked_into.len - 1], payload.len));
    try std.testing.expectError(error.SizeMismatch, lz4DecodeFrameChunksIntoExactSize(&lib_chunks, lib_join, &lib_chunked_into, payload.len - 1));
    const pure_encoded = try lz4EncodePureFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(pure_encoded);
    const pure_decoded = try lz4DecodeFrameAlloc(std.testing.allocator, pure_encoded);
    defer std.testing.allocator.free(pure_decoded);
    try std.testing.expectEqualSlices(u8, payload, pure_decoded);
    const pure_with_options = try lz4EncodePureFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .include_content_size = false,
        .content_checksum = false,
        .block_size_id = .max64kb,
    });
    defer std.testing.allocator.free(pure_with_options);
    const pure_with_options_decoded = try lz4DecodeFrameAlloc(std.testing.allocator, pure_with_options);
    defer std.testing.allocator.free(pure_with_options_decoded);
    try std.testing.expectEqualSlices(u8, payload, pure_with_options_decoded);
    var pure_appended: std.ArrayList(u8) = .empty;
    defer pure_appended.deinit(std.testing.allocator);
    try lz4EncodePureFrameAppend(std.testing.allocator, &pure_appended, payload, .{});
    const pure_appended_decoded = try lz4DecodeFrameAlloc(std.testing.allocator, pure_appended.items);
    defer std.testing.allocator.free(pure_appended_decoded);
    try std.testing.expectEqualSlices(u8, payload, pure_appended_decoded);
    const native_encoded = try lz4EncodeNativeFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(native_encoded);
    const native_with_options = try lz4EncodeNativeFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .include_content_size = false,
        .content_checksum = false,
        .block_size_id = .max64kb,
    });
    defer std.testing.allocator.free(native_with_options);
    const native_with_options_decoded = try lz4DecodeNativeFrameAlloc(std.testing.allocator, native_with_options);
    defer std.testing.allocator.free(native_with_options_decoded);
    try std.testing.expectEqualSlices(u8, payload, native_with_options_decoded);
    try std.testing.expectEqual(payload.len, try lz4DecodedNativeFrameSize(native_with_options));
    try std.testing.expectEqual(payload.len, try lz4DecodedNativeFrameSizeLimited(native_with_options, payload.len));
    try std.testing.expectError(error.OutputLimitExceeded, lz4DecodedNativeFrameSizeLimited(native_with_options, payload.len - 1));
    var native_appended: std.ArrayList(u8) = .empty;
    defer native_appended.deinit(std.testing.allocator);
    try native_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(payload.len, try lz4DecodeNativeFrameAppendExactSize(std.testing.allocator, &native_appended, native_with_options, payload.len));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ payload, native_appended.items);
    native_appended.clearRetainingCapacity();
    try std.testing.expectError(error.SizeMismatch, lz4DecodeNativeFrameAppendExactSize(std.testing.allocator, &native_appended, native_with_options, payload.len - 1));

    const native_second = try lz4EncodeNativeFrameWithOptionsAlloc(std.testing.allocator, "second", .{
        .include_content_size = false,
        .content_checksum = false,
        .block_size_id = .max64kb,
    });
    defer std.testing.allocator.free(native_second);
    var native_stream: std.ArrayList(u8) = .empty;
    defer native_stream.deinit(std.testing.allocator);
    try native_stream.appendSlice(std.testing.allocator, native_with_options);
    try native_stream.appendSlice(std.testing.allocator, native_second);
    const native_stream_len = payload.len + "second".len;
    try std.testing.expectEqual(native_stream_len, try lz4DecodedNativeConcatenatedFrameSize(native_stream.items));
    try std.testing.expectEqual(native_stream_len, try lz4DecodedNativeConcatenatedFrameSizeLimited(native_stream.items, native_stream_len));
    try std.testing.expectError(error.OutputLimitExceeded, lz4DecodedNativeConcatenatedFrameSizeLimited(native_stream.items, native_stream_len - 1));
    var native_stream_into: [native_stream_len]u8 = undefined;
    try std.testing.expectEqual(native_stream_len, try lz4DecodeConcatenatedFrameIntoExactSize(native_stream.items, &native_stream_into, native_stream_len));
    try std.testing.expectEqualSlices(u8, payload ++ "second", &native_stream_into);
    try std.testing.expectError(error.SizeMismatch, lz4DecodeConcatenatedFrameIntoExactSize(native_stream.items, &native_stream_into, native_stream_len - 1));
    try std.testing.expect(native_encoded.len <= try lz4EncodedNativeFrameBound(payload.len));
    try std.testing.expect(native_encoded.len <= try lz4EncodedNativeFrameBoundWithOptions(payload.len, .{
        .block_size_id = .max64kb,
        .block_checksum = true,
    }));

    const raw_match = [_]u8{ 0x33, 'a', 'b', 'c', 3, 0 };
    try std.testing.expect(raw_match.len <= try lz4EncodedBlockBound(10));
    try std.testing.expectEqual(@as(usize, 10), try lz4DecodedBlockSize(&raw_match));
    try std.testing.expectEqual(@as(usize, 10), try lz4DecodedBlockSizeLimited(&raw_match, 10));
    try std.testing.expectError(error.OutputLimitExceeded, lz4DecodedBlockSizeLimited(&raw_match, 9));
    const prefix_match = [_]u8{ 0x04, 4, 0 };
    try std.testing.expectError(error.InvalidMatch, lz4DecodedBlockSize(&prefix_match));
    try std.testing.expectEqual(@as(usize, 8), try lz4DecodedBlockSizeWithPrefix(&prefix_match, "abcdefghijklmnop"));
    try std.testing.expectEqual(@as(usize, 8), try lz4DecodedBlockSizeWithPrefixLimited(&prefix_match, "abcdefghijklmnop", 8));
    try std.testing.expectError(error.OutputLimitExceeded, lz4DecodedBlockSizeWithPrefixLimited(&prefix_match, "abcdefghijklmnop", 7));
    var prefix_out: [8]u8 = undefined;
    const prefix_written = try lz4DecodeBlockWithPrefixIntoSlice(std.testing.allocator, &prefix_match, &prefix_out, 8, "abcdefghijklmnop");
    try std.testing.expectEqual(@as(usize, 8), prefix_written);
    try std.testing.expectEqualSlices(u8, "mnopmnop", &prefix_out);
    @memset(&prefix_out, 0);
    const prefix_noalloc_written = try lz4DecodeBlockWithPrefixIntoSliceNoAlloc(&prefix_match, &prefix_out, 8, "abcdefghijklmnop");
    try std.testing.expectEqual(@as(usize, 8), prefix_noalloc_written);
    try std.testing.expectEqualSlices(u8, "mnopmnop", &prefix_out);
    var raw_encoded_into: [16]u8 = undefined;
    const raw_written = try lz4EncodeBlockIntoSlice(std.testing.allocator, "abcabcabca", &raw_encoded_into);
    try std.testing.expect(raw_written <= try lz4EncodedBlockBound(10));
    const depth_encoded = try lz4EncodeBlockWithChainDepthAlloc(std.testing.allocator, "abcabcabca", 4);
    defer std.testing.allocator.free(depth_encoded);
    const depth_decoded = try lz4DecodeBlockAlloc(std.testing.allocator, depth_encoded, "abcabcabca".len);
    defer std.testing.allocator.free(depth_decoded);
    try std.testing.expectEqualSlices(u8, "abcabcabca", depth_decoded);
    var depth_into: [16]u8 = undefined;
    const depth_written = try lz4EncodeBlockIntoSliceWithChainDepth(std.testing.allocator, "abcabcabca", &depth_into, 4);
    try std.testing.expectEqualSlices(u8, depth_encoded, depth_into[0..depth_written]);
    const prefix_depth_encoded = try lz4EncodeBlockWithPrefixAndChainDepthAlloc(std.testing.allocator, "payload", "previous payload history", 4);
    defer std.testing.allocator.free(prefix_depth_encoded);
    const prefix_depth_decoded = try lz4DecodeBlockWithPrefixAlloc(std.testing.allocator, prefix_depth_encoded, "payload".len, "previous payload history");
    defer std.testing.allocator.free(prefix_depth_decoded);
    try std.testing.expectEqualSlices(u8, "payload", prefix_depth_decoded);
}

test "root zstd frame options round trip" {
    const payload = "root zstd frame options payload" ** 4;
    const encoded = try zstdEncodeFrameWithLevelAndOptionsAlloc(std.testing.allocator, payload, zstd.default_compression_level, .{
        .include_content_size = false,
        .content_checksum = true,
    });
    defer std.testing.allocator.free(encoded);

    const decoded = try zstdDecodeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    const bound = try zstdDecodedFrameSize(encoded);
    try std.testing.expect(bound >= payload.len);
    const into_buffer = try std.testing.allocator.alloc(u8, bound);
    defer std.testing.allocator.free(into_buffer);
    const written = try zstdDecodeFrameInto(encoded, into_buffer);
    try std.testing.expectEqual(decoded.len, written);
    try std.testing.expectEqualSlices(u8, payload, into_buffer[0..written]);
    try std.testing.expectEqual(bound, try zstdDecodedFrameSizeLimited(encoded, bound));
    try std.testing.expectError(error.OutputLimitExceeded, zstdDecodedFrameSizeLimited(encoded, bound - 1));
}

test "root zstd frame facade exposes append into and bound encode helpers" {
    const payload = "root zstd encode facade helper payload" ** 3;
    const options: ZstdFrameOptions = .{ .content_checksum = true };

    const bound = try zstdEncodedFrameBoundWithOptions(payload.len, options);
    const alloc_encoded = try zstdEncodeFrameWithOptionsAlloc(std.testing.allocator, payload, options);
    defer std.testing.allocator.free(alloc_encoded);
    try std.testing.expect(alloc_encoded.len <= bound);

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(std.testing.allocator);
    try appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(alloc_encoded.len, try zstdEncodeFrameAppendWithOptions(std.testing.allocator, &appended, payload, options));
    try std.testing.expectEqualSlices(u8, "prefix:", appended.items[0.."prefix:".len]);
    try std.testing.expectEqualSlices(u8, alloc_encoded, appended.items["prefix:".len..]);

    const into = try std.testing.allocator.alloc(u8, bound);
    defer std.testing.allocator.free(into);
    const written = try zstdEncodeFrameIntoSliceWithOptions(std.testing.allocator, payload, options, into);
    try std.testing.expectEqualSlices(u8, alloc_encoded, into[0..written]);
    try std.testing.expectError(error.OutputTooSmall, zstdEncodeFrameIntoSliceWithOptions(std.testing.allocator, payload, options, into[0 .. written - 1]));

    const decoded = try zstdDecodeFrameAllocExactSize(std.testing.allocator, into[0..written], payload.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
}

test "root zstd frame facade exposes dictionary encode helpers" {
    const zstd_dictionary = ZstdNativeDictionary.init(0x7a44, "dictionary-prefix-");
    const payload = "dictionary-prefix-payload dictionary-prefix-tail";
    const options: ZstdFrameOptions = .{ .content_checksum = true };

    const bound = try zstdEncodedFrameBoundWithOptionsAndDictionary(payload.len, options, zstd_dictionary);
    const encoded = try zstdEncodeFrameWithOptionsAndDictionaryAlloc(std.testing.allocator, payload, options, zstd_dictionary);
    defer std.testing.allocator.free(encoded);
    try std.testing.expect(encoded.len <= bound);

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(std.testing.allocator);
    try appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(encoded.len, try zstdEncodeFrameAppendWithOptionsAndDictionary(std.testing.allocator, &appended, payload, options, zstd_dictionary));
    try std.testing.expectEqualSlices(u8, "prefix:", appended.items[0.."prefix:".len]);
    try std.testing.expectEqualSlices(u8, encoded, appended.items["prefix:".len..]);

    const into = try std.testing.allocator.alloc(u8, bound);
    defer std.testing.allocator.free(into);
    const written = try zstdEncodeFrameIntoSliceWithOptionsAndDictionary(std.testing.allocator, payload, options, zstd_dictionary, into);
    try std.testing.expectEqualSlices(u8, encoded, into[0..written]);

    const decoded = try zstdDecodeNativeFrameAllocWithDictionaryExactSize(std.testing.allocator, into[0..written], zstd_dictionary, payload.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);

    try std.testing.expectEqual(payload.len, try zstdDecodedFrameSizeWithDictionary(encoded, zstd_dictionary));
    try std.testing.expectEqual(payload.len, try zstdDecodedFrameSizeLimitedWithDictionary(encoded, zstd_dictionary, payload.len));
    try std.testing.expectError(error.OutputLimitExceeded, zstdDecodedFrameSizeLimitedWithDictionary(encoded, zstd_dictionary, payload.len - 1));
    const facade_decoded_default = try zstdDecodeFrameAllocWithDictionary(std.testing.allocator, encoded, zstd_dictionary);
    defer std.testing.allocator.free(facade_decoded_default);
    try std.testing.expectEqualSlices(u8, payload, facade_decoded_default);

    const chunk_scratch = try std.testing.allocator.alloc(u8, encoded.len);
    defer std.testing.allocator.free(chunk_scratch);
    const chunks = [_][]const u8{
        encoded[0..3],
        encoded[3 .. encoded.len - 2],
        encoded[encoded.len - 2 ..],
    };
    try std.testing.expectEqual(payload.len, try zstdDecodedFrameChunksSizeWithDictionary(&chunks, chunk_scratch, zstd_dictionary));
    try std.testing.expectEqual(payload.len, try zstdDecodedFrameChunksSizeLimitedWithDictionary(&chunks, chunk_scratch, zstd_dictionary, payload.len));
    try std.testing.expectError(error.OutputLimitExceeded, zstdDecodedFrameChunksSizeLimitedWithDictionary(&chunks, chunk_scratch, zstd_dictionary, payload.len - 1));
    const chunk_decoded_default = try zstdDecodeFrameChunksAllocWithDictionary(std.testing.allocator, &chunks, chunk_scratch, zstd_dictionary);
    defer std.testing.allocator.free(chunk_decoded_default);
    try std.testing.expectEqualSlices(u8, payload, chunk_decoded_default);
    const chunk_decoded_exact = try zstdDecodeFrameChunksAllocWithDictionaryExactSize(std.testing.allocator, &chunks, chunk_scratch, zstd_dictionary, payload.len);
    defer std.testing.allocator.free(chunk_decoded_exact);
    try std.testing.expectEqualSlices(u8, payload, chunk_decoded_exact);
    const chunk_decoded_limited = try zstdDecodeFrameChunksAllocWithDictionaryLimited(std.testing.allocator, &chunks, chunk_scratch, zstd_dictionary, payload.len);
    defer std.testing.allocator.free(chunk_decoded_limited);
    try std.testing.expectEqualSlices(u8, payload, chunk_decoded_limited);
    try std.testing.expectError(error.OutputLimitExceeded, zstdDecodeFrameChunksAllocWithDictionaryLimited(std.testing.allocator, &chunks, chunk_scratch, zstd_dictionary, payload.len - 1));
    var chunk_append: std.ArrayList(u8) = .empty;
    defer chunk_append.deinit(std.testing.allocator);
    try chunk_append.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(payload.len, try zstdDecodeFrameChunksAppendWithDictionary(std.testing.allocator, &chunk_append, &chunks, chunk_scratch, zstd_dictionary));
    try std.testing.expectEqualSlices(u8, payload, chunk_append.items["prefix:".len..]);
    var chunk_append_exact: std.ArrayList(u8) = .empty;
    defer chunk_append_exact.deinit(std.testing.allocator);
    try chunk_append_exact.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(payload.len, try zstdDecodeFrameChunksAppendExactSizeWithDictionary(std.testing.allocator, &chunk_append_exact, &chunks, chunk_scratch, zstd_dictionary, payload.len));
    try std.testing.expectEqualSlices(u8, payload, chunk_append_exact.items["prefix:".len..]);
    var chunk_append_limited: std.ArrayList(u8) = .empty;
    defer chunk_append_limited.deinit(std.testing.allocator);
    try chunk_append_limited.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(payload.len, try zstdDecodeFrameChunksAppendLimitedWithDictionary(std.testing.allocator, &chunk_append_limited, &chunks, chunk_scratch, zstd_dictionary, payload.len));
    try std.testing.expectEqualSlices(u8, payload, chunk_append_limited.items["prefix:".len..]);
    try std.testing.expectError(error.OutputLimitExceeded, zstdDecodeFrameChunksAppendLimitedWithDictionary(std.testing.allocator, &chunk_append_limited, &chunks, chunk_scratch, zstd_dictionary, payload.len - 1));
    var chunk_into_default: [payload.len]u8 = undefined;
    try std.testing.expectEqual(payload.len, try zstdDecodeFrameChunksIntoWithDictionary(&chunks, chunk_scratch, &chunk_into_default, zstd_dictionary));
    try std.testing.expectEqualSlices(u8, payload, &chunk_into_default);
    @memset(&chunk_into_default, 0xaa);
    try std.testing.expectEqual(payload.len, try zstdDecodeFrameChunksIntoWithDictionaryLimited(&chunks, chunk_scratch, &chunk_into_default, zstd_dictionary, payload.len));
    try std.testing.expectEqualSlices(u8, payload, &chunk_into_default);
    @memset(&chunk_into_default, 0xaa);
    try std.testing.expectError(error.OutputLimitExceeded, zstdDecodeFrameChunksIntoWithDictionaryLimited(&chunks, chunk_scratch, &chunk_into_default, zstd_dictionary, payload.len - 1));
    try std.testing.expectEqualSlices(u8, &([_]u8{0xaa} ** payload.len), &chunk_into_default);
    var chunk_into_exact: [payload.len]u8 = undefined;
    try std.testing.expectEqual(payload.len, try zstdDecodeFrameChunksIntoWithDictionaryExactSize(&chunks, chunk_scratch, &chunk_into_exact, zstd_dictionary, payload.len));
    try std.testing.expectEqualSlices(u8, payload, &chunk_into_exact);

    const facade_decoded = try zstdDecodeFrameAllocWithDictionaryExactSize(std.testing.allocator, encoded, zstd_dictionary, payload.len);
    defer std.testing.allocator.free(facade_decoded);
    try std.testing.expectEqualSlices(u8, payload, facade_decoded);
    const facade_limited = try zstdDecodeFrameAllocWithDictionaryLimited(std.testing.allocator, encoded, zstd_dictionary, payload.len);
    defer std.testing.allocator.free(facade_limited);
    try std.testing.expectEqualSlices(u8, payload, facade_limited);
    try std.testing.expectError(error.OutputLimitExceeded, zstdDecodeFrameAllocWithDictionaryLimited(std.testing.allocator, encoded, zstd_dictionary, payload.len - 1));
    var decoded_append_default: std.ArrayList(u8) = .empty;
    defer decoded_append_default.deinit(std.testing.allocator);
    try decoded_append_default.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(payload.len, try zstdDecodeFrameAppendWithDictionary(std.testing.allocator, &decoded_append_default, encoded, zstd_dictionary));
    try std.testing.expectEqualSlices(u8, payload, decoded_append_default.items["prefix:".len..]);
    var decoded_append: std.ArrayList(u8) = .empty;
    defer decoded_append.deinit(std.testing.allocator);
    try decoded_append.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(payload.len, try zstdDecodeFrameAppendExactSizeWithDictionary(std.testing.allocator, &decoded_append, encoded, zstd_dictionary, payload.len));
    try std.testing.expectEqualSlices(u8, "prefix:", decoded_append.items[0.."prefix:".len]);
    try std.testing.expectEqualSlices(u8, payload, decoded_append.items["prefix:".len..]);
    var decoded_append_limited: std.ArrayList(u8) = .empty;
    defer decoded_append_limited.deinit(std.testing.allocator);
    try decoded_append_limited.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(payload.len, try zstdDecodeFrameAppendLimitedWithDictionary(std.testing.allocator, &decoded_append_limited, encoded, zstd_dictionary, payload.len));
    try std.testing.expectEqualSlices(u8, payload, decoded_append_limited.items["prefix:".len..]);
    try std.testing.expectError(error.OutputLimitExceeded, zstdDecodeFrameAppendLimitedWithDictionary(std.testing.allocator, &decoded_append_limited, encoded, zstd_dictionary, payload.len - 1));
    var decoded_into_default: [payload.len]u8 = undefined;
    try std.testing.expectEqual(payload.len, try zstdDecodeFrameIntoWithDictionary(encoded, &decoded_into_default, zstd_dictionary));
    try std.testing.expectEqualSlices(u8, payload, &decoded_into_default);
    @memset(&decoded_into_default, 0xaa);
    try std.testing.expectEqual(payload.len, try zstdDecodeFrameIntoWithDictionaryLimited(encoded, &decoded_into_default, zstd_dictionary, payload.len));
    try std.testing.expectEqualSlices(u8, payload, &decoded_into_default);
    @memset(&decoded_into_default, 0xaa);
    try std.testing.expectError(error.OutputLimitExceeded, zstdDecodeFrameIntoWithDictionaryLimited(encoded, &decoded_into_default, zstd_dictionary, payload.len - 1));
    try std.testing.expectEqualSlices(u8, &([_]u8{0xaa} ** payload.len), &decoded_into_default);
    var decoded_into: [payload.len]u8 = undefined;
    try std.testing.expectEqual(payload.len, try zstdDecodeFrameIntoWithDictionaryExactSize(encoded, &decoded_into, zstd_dictionary, payload.len));
    try std.testing.expectEqualSlices(u8, payload, &decoded_into);
}

test "root zstd frame facade exposes dictionary-set encode helpers" {
    const dict = ZstdNativeDictionary.init(0x7a55, "set-dictionary-prefix-");
    const other = ZstdNativeDictionary.init(0x7a56, "other-prefix-");
    const dictionary_set = ZstdNativeDictionarySet.init(&.{ dict, other });
    const payload = "set-dictionary-prefix-payload set-dictionary-prefix-tail";
    const options: ZstdFrameOptions = .{ .content_checksum = true };

    const bound = try zstdEncodedFrameBoundWithOptionsAndDictionarySet(payload.len, options, dictionary_set, dict.id);
    const encoded = try zstdEncodeFrameWithOptionsAndDictionarySetAlloc(std.testing.allocator, payload, options, dictionary_set, dict.id);
    defer std.testing.allocator.free(encoded);
    try std.testing.expect(encoded.len <= bound);
    try std.testing.expectError(error.NeedDictionary, zstdEncodedFrameBoundWithDictionarySet(payload.len, dictionary_set, 0xeeee));

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(std.testing.allocator);
    try appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(encoded.len, try zstdEncodeFrameAppendWithOptionsAndDictionarySet(std.testing.allocator, &appended, payload, options, dictionary_set, dict.id));
    try std.testing.expectEqualSlices(u8, "prefix:", appended.items[0.."prefix:".len]);
    try std.testing.expectEqualSlices(u8, encoded, appended.items["prefix:".len..]);

    const into = try std.testing.allocator.alloc(u8, bound);
    defer std.testing.allocator.free(into);
    const written = try zstdEncodeFrameIntoSliceWithOptionsAndDictionarySet(std.testing.allocator, payload, options, dictionary_set, dict.id, into);
    try std.testing.expectEqualSlices(u8, encoded, into[0..written]);

    const decoded = try zstdDecodeNativeFrameAllocWithDictionarySetExactSize(std.testing.allocator, into[0..written], dictionary_set, payload.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);

    try std.testing.expectEqual(payload.len, try zstdDecodedFrameSizeWithDictionarySet(encoded, dictionary_set));
    try std.testing.expectEqual(payload.len, try zstdDecodedFrameSizeLimitedWithDictionarySet(encoded, dictionary_set, payload.len));
    try std.testing.expectError(error.OutputLimitExceeded, zstdDecodedFrameSizeLimitedWithDictionarySet(encoded, dictionary_set, payload.len - 1));
    const facade_decoded_default = try zstdDecodeFrameAllocWithDictionarySet(std.testing.allocator, encoded, dictionary_set);
    defer std.testing.allocator.free(facade_decoded_default);
    try std.testing.expectEqualSlices(u8, payload, facade_decoded_default);

    const chunk_scratch = try std.testing.allocator.alloc(u8, encoded.len);
    defer std.testing.allocator.free(chunk_scratch);
    const chunks = [_][]const u8{
        encoded[0..3],
        encoded[3 .. encoded.len - 2],
        encoded[encoded.len - 2 ..],
    };
    try std.testing.expectEqual(payload.len, try zstdDecodedFrameChunksSizeWithDictionarySet(&chunks, chunk_scratch, dictionary_set));
    try std.testing.expectEqual(payload.len, try zstdDecodedFrameChunksSizeLimitedWithDictionarySet(&chunks, chunk_scratch, dictionary_set, payload.len));
    try std.testing.expectError(error.OutputLimitExceeded, zstdDecodedFrameChunksSizeLimitedWithDictionarySet(&chunks, chunk_scratch, dictionary_set, payload.len - 1));
    const chunk_decoded_default = try zstdDecodeFrameChunksAllocWithDictionarySet(std.testing.allocator, &chunks, chunk_scratch, dictionary_set);
    defer std.testing.allocator.free(chunk_decoded_default);
    try std.testing.expectEqualSlices(u8, payload, chunk_decoded_default);
    const chunk_decoded_exact = try zstdDecodeFrameChunksAllocWithDictionarySetExactSize(std.testing.allocator, &chunks, chunk_scratch, dictionary_set, payload.len);
    defer std.testing.allocator.free(chunk_decoded_exact);
    try std.testing.expectEqualSlices(u8, payload, chunk_decoded_exact);
    const chunk_decoded_limited = try zstdDecodeFrameChunksAllocWithDictionarySetLimited(std.testing.allocator, &chunks, chunk_scratch, dictionary_set, payload.len);
    defer std.testing.allocator.free(chunk_decoded_limited);
    try std.testing.expectEqualSlices(u8, payload, chunk_decoded_limited);
    try std.testing.expectError(error.OutputLimitExceeded, zstdDecodeFrameChunksAllocWithDictionarySetLimited(std.testing.allocator, &chunks, chunk_scratch, dictionary_set, payload.len - 1));
    var chunk_append: std.ArrayList(u8) = .empty;
    defer chunk_append.deinit(std.testing.allocator);
    try chunk_append.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(payload.len, try zstdDecodeFrameChunksAppendWithDictionarySet(std.testing.allocator, &chunk_append, &chunks, chunk_scratch, dictionary_set));
    try std.testing.expectEqualSlices(u8, payload, chunk_append.items["prefix:".len..]);
    var chunk_append_exact: std.ArrayList(u8) = .empty;
    defer chunk_append_exact.deinit(std.testing.allocator);
    try chunk_append_exact.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(payload.len, try zstdDecodeFrameChunksAppendExactSizeWithDictionarySet(std.testing.allocator, &chunk_append_exact, &chunks, chunk_scratch, dictionary_set, payload.len));
    try std.testing.expectEqualSlices(u8, payload, chunk_append_exact.items["prefix:".len..]);
    var chunk_append_limited: std.ArrayList(u8) = .empty;
    defer chunk_append_limited.deinit(std.testing.allocator);
    try chunk_append_limited.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(payload.len, try zstdDecodeFrameChunksAppendLimitedWithDictionarySet(std.testing.allocator, &chunk_append_limited, &chunks, chunk_scratch, dictionary_set, payload.len));
    try std.testing.expectEqualSlices(u8, payload, chunk_append_limited.items["prefix:".len..]);
    try std.testing.expectError(error.OutputLimitExceeded, zstdDecodeFrameChunksAppendLimitedWithDictionarySet(std.testing.allocator, &chunk_append_limited, &chunks, chunk_scratch, dictionary_set, payload.len - 1));
    var chunk_into_default: [payload.len]u8 = undefined;
    try std.testing.expectEqual(payload.len, try zstdDecodeFrameChunksIntoWithDictionarySet(&chunks, chunk_scratch, &chunk_into_default, dictionary_set));
    try std.testing.expectEqualSlices(u8, payload, &chunk_into_default);
    @memset(&chunk_into_default, 0xaa);
    try std.testing.expectEqual(payload.len, try zstdDecodeFrameChunksIntoWithDictionarySetLimited(&chunks, chunk_scratch, &chunk_into_default, dictionary_set, payload.len));
    try std.testing.expectEqualSlices(u8, payload, &chunk_into_default);
    @memset(&chunk_into_default, 0xaa);
    try std.testing.expectError(error.OutputLimitExceeded, zstdDecodeFrameChunksIntoWithDictionarySetLimited(&chunks, chunk_scratch, &chunk_into_default, dictionary_set, payload.len - 1));
    try std.testing.expectEqualSlices(u8, &([_]u8{0xaa} ** payload.len), &chunk_into_default);
    var chunk_into_exact: [payload.len]u8 = undefined;
    try std.testing.expectEqual(payload.len, try zstdDecodeFrameChunksIntoWithDictionarySetExactSize(&chunks, chunk_scratch, &chunk_into_exact, dictionary_set, payload.len));
    try std.testing.expectEqualSlices(u8, payload, &chunk_into_exact);

    const facade_decoded = try zstdDecodeFrameAllocWithDictionarySetExactSize(std.testing.allocator, encoded, dictionary_set, payload.len);
    defer std.testing.allocator.free(facade_decoded);
    try std.testing.expectEqualSlices(u8, payload, facade_decoded);
    const facade_limited = try zstdDecodeFrameAllocWithDictionarySetLimited(std.testing.allocator, encoded, dictionary_set, payload.len);
    defer std.testing.allocator.free(facade_limited);
    try std.testing.expectEqualSlices(u8, payload, facade_limited);
    try std.testing.expectError(error.OutputLimitExceeded, zstdDecodeFrameAllocWithDictionarySetLimited(std.testing.allocator, encoded, dictionary_set, payload.len - 1));
    var decoded_append_default: std.ArrayList(u8) = .empty;
    defer decoded_append_default.deinit(std.testing.allocator);
    try decoded_append_default.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(payload.len, try zstdDecodeFrameAppendWithDictionarySet(std.testing.allocator, &decoded_append_default, encoded, dictionary_set));
    try std.testing.expectEqualSlices(u8, payload, decoded_append_default.items["prefix:".len..]);
    var decoded_append: std.ArrayList(u8) = .empty;
    defer decoded_append.deinit(std.testing.allocator);
    try decoded_append.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(payload.len, try zstdDecodeFrameAppendExactSizeWithDictionarySet(std.testing.allocator, &decoded_append, encoded, dictionary_set, payload.len));
    try std.testing.expectEqualSlices(u8, "prefix:", decoded_append.items[0.."prefix:".len]);
    try std.testing.expectEqualSlices(u8, payload, decoded_append.items["prefix:".len..]);
    var decoded_append_limited: std.ArrayList(u8) = .empty;
    defer decoded_append_limited.deinit(std.testing.allocator);
    try decoded_append_limited.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(payload.len, try zstdDecodeFrameAppendLimitedWithDictionarySet(std.testing.allocator, &decoded_append_limited, encoded, dictionary_set, payload.len));
    try std.testing.expectEqualSlices(u8, payload, decoded_append_limited.items["prefix:".len..]);
    try std.testing.expectError(error.OutputLimitExceeded, zstdDecodeFrameAppendLimitedWithDictionarySet(std.testing.allocator, &decoded_append_limited, encoded, dictionary_set, payload.len - 1));
    var decoded_into_default: [payload.len]u8 = undefined;
    try std.testing.expectEqual(payload.len, try zstdDecodeFrameIntoWithDictionarySet(encoded, &decoded_into_default, dictionary_set));
    try std.testing.expectEqualSlices(u8, payload, &decoded_into_default);
    @memset(&decoded_into_default, 0xaa);
    try std.testing.expectEqual(payload.len, try zstdDecodeFrameIntoWithDictionarySetLimited(encoded, &decoded_into_default, dictionary_set, payload.len));
    try std.testing.expectEqualSlices(u8, payload, &decoded_into_default);
    @memset(&decoded_into_default, 0xaa);
    try std.testing.expectError(error.OutputLimitExceeded, zstdDecodeFrameIntoWithDictionarySetLimited(encoded, &decoded_into_default, dictionary_set, payload.len - 1));
    try std.testing.expectEqualSlices(u8, &([_]u8{0xaa} ** payload.len), &decoded_into_default);
    var decoded_into: [payload.len]u8 = undefined;
    try std.testing.expectEqual(payload.len, try zstdDecodeFrameIntoWithDictionarySetExactSize(encoded, &decoded_into, dictionary_set, payload.len));
    try std.testing.expectEqualSlices(u8, payload, &decoded_into);
}

test "root zstd frame facade exposes append exact and chunked decode helpers" {
    const payload = "root zstd public facade helper coverage" ** 3;
    const encoded = try zstdEncodeFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .content_checksum = true,
    });
    defer std.testing.allocator.free(encoded);

    const exact = try zstdDecodeFrameAllocExactSize(std.testing.allocator, encoded, payload.len);
    defer std.testing.allocator.free(exact);
    try std.testing.expectEqualSlices(u8, payload, exact);
    try std.testing.expectError(error.SizeMismatch, zstdDecodeFrameAllocExactSize(std.testing.allocator, encoded, payload.len - 1));

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(std.testing.allocator);
    try appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(payload.len, try zstdDecodeFrameAppend(std.testing.allocator, &appended, encoded));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ payload, appended.items);
    appended.clearRetainingCapacity();
    try appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(payload.len, try zstdDecodeFrameAppendExactSize(std.testing.allocator, &appended, encoded, payload.len));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ payload, appended.items);
    try std.testing.expectError(error.SizeMismatch, zstdDecodeFrameAppendExactSize(std.testing.allocator, &appended, encoded, payload.len + 1));
    appended.clearRetainingCapacity();
    try appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(payload.len, try zstdDecodeFrameAppendLimited(std.testing.allocator, &appended, encoded, payload.len));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ payload, appended.items);
    try std.testing.expectError(error.OutputLimitExceeded, zstdDecodeFrameAppendLimited(std.testing.allocator, &appended, encoded, payload.len - 1));

    var into: [payload.len]u8 = undefined;
    try std.testing.expectEqual(payload.len, try zstdDecodeFrameInto(encoded, &into));
    try std.testing.expectEqualSlices(u8, payload, &into);
    @memset(&into, 0xaa);
    try std.testing.expectEqual(payload.len, try zstdDecodeFrameIntoLimited(encoded, &into, payload.len));
    try std.testing.expectEqualSlices(u8, payload, &into);
    @memset(&into, 0xaa);
    try std.testing.expectError(error.OutputLimitExceeded, zstdDecodeFrameIntoLimited(encoded, &into, payload.len - 1));
    try std.testing.expectEqualSlices(u8, &([_]u8{0xaa} ** payload.len), &into);
    try std.testing.expectError(error.OutputTooSmall, zstdDecodeFrameIntoLimited(encoded, into[0 .. payload.len - 1], payload.len));
    try std.testing.expectEqual(payload.len, try zstdDecodeFrameIntoExactSize(encoded, &into, payload.len));
    try std.testing.expectEqualSlices(u8, payload, &into);
    try std.testing.expectError(error.SizeMismatch, zstdDecodeFrameIntoExactSize(encoded, &into, payload.len - 1));

    const chunks = [_][]const u8{
        encoded[0..5],
        encoded[5 .. encoded.len - 3],
        encoded[encoded.len - 3 ..],
    };
    const join = try std.testing.allocator.alloc(u8, encoded.len);
    defer std.testing.allocator.free(join);
    try std.testing.expectEqual(payload.len, try zstdDecodedFrameChunksSize(&chunks, join));
    try std.testing.expectEqual(payload.len, try zstdDecodedFrameChunksSizeLimited(&chunks, join, payload.len));
    try std.testing.expectError(error.OutputLimitExceeded, zstdDecodedFrameChunksSizeLimited(&chunks, join, payload.len - 1));

    const chunked = try zstdDecodeFrameChunksAlloc(std.testing.allocator, &chunks, join);
    defer std.testing.allocator.free(chunked);
    try std.testing.expectEqualSlices(u8, payload, chunked);
    const chunked_exact = try zstdDecodeFrameChunksAllocExactSize(std.testing.allocator, &chunks, join, payload.len);
    defer std.testing.allocator.free(chunked_exact);
    try std.testing.expectEqualSlices(u8, payload, chunked_exact);
    try std.testing.expectError(error.SizeMismatch, zstdDecodeFrameChunksAllocExactSize(std.testing.allocator, &chunks, join, payload.len + 1));
    const chunked_limited = try zstdDecodeFrameChunksAllocLimited(std.testing.allocator, &chunks, join, payload.len);
    defer std.testing.allocator.free(chunked_limited);
    try std.testing.expectEqualSlices(u8, payload, chunked_limited);
    try std.testing.expectError(error.OutputLimitExceeded, zstdDecodeFrameChunksAllocLimited(std.testing.allocator, &chunks, join, payload.len - 1));

    var chunked_append: std.ArrayList(u8) = .empty;
    defer chunked_append.deinit(std.testing.allocator);
    try chunked_append.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(payload.len, try zstdDecodeFrameChunksAppend(std.testing.allocator, &chunked_append, &chunks, join));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ payload, chunked_append.items);
    chunked_append.clearRetainingCapacity();
    try chunked_append.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(payload.len, try zstdDecodeFrameChunksAppendExactSize(std.testing.allocator, &chunked_append, &chunks, join, payload.len));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ payload, chunked_append.items);
    try std.testing.expectError(error.SizeMismatch, zstdDecodeFrameChunksAppendExactSize(std.testing.allocator, &chunked_append, &chunks, join, payload.len + 1));
    chunked_append.clearRetainingCapacity();
    try chunked_append.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(payload.len, try zstdDecodeFrameChunksAppendLimited(std.testing.allocator, &chunked_append, &chunks, join, payload.len));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ payload, chunked_append.items);
    try std.testing.expectError(error.OutputLimitExceeded, zstdDecodeFrameChunksAppendLimited(std.testing.allocator, &chunked_append, &chunks, join, payload.len - 1));

    @memset(&into, 0);
    try std.testing.expectEqual(payload.len, try zstdDecodeFrameChunksInto(&chunks, join, &into));
    try std.testing.expectEqualSlices(u8, payload, &into);
    @memset(&into, 0);
    try std.testing.expectEqual(payload.len, try zstdDecodeFrameChunksIntoLimited(&chunks, join, &into, payload.len));
    try std.testing.expectEqualSlices(u8, payload, &into);
    @memset(&into, 0xaa);
    try std.testing.expectError(error.OutputLimitExceeded, zstdDecodeFrameChunksIntoLimited(&chunks, join, &into, payload.len - 1));
    try std.testing.expectEqualSlices(u8, &([_]u8{0xaa} ** payload.len), &into);
    @memset(&into, 0);
    try std.testing.expectEqual(payload.len, try zstdDecodeFrameChunksIntoExactSize(&chunks, join, &into, payload.len));
    try std.testing.expectEqualSlices(u8, payload, &into);
    try std.testing.expectError(error.SizeMismatch, zstdDecodeFrameChunksIntoExactSize(&chunks, join, &into, payload.len - 1));
}

test "root zstd public reusable aliases expose dictionary helpers" {
    const samples = [_][]const u8{
        "root zstd public dictionary sample alpha alpha alpha",
        "root zstd public dictionary sample beta beta beta",
        "root zstd public dictionary sample gamma gamma gamma",
    };
    const train_options: ZstdDictionaryTrainOptions = .{ .target_size = 32 };
    const trained = try zstdTrainDictionaryAlloc(std.testing.allocator, &samples, train_options);
    defer trained.deinit(std.testing.allocator);
    const dict: ZstdDictionary = trained.asDictionary();
    const metadata = trained.metadata();
    var metadata_dicts: [1]ZstdDictionary = undefined;
    const metadata_set: ZstdDictionarySet = try ZstdDictionarySet.initFromMetadata(&metadata_dicts, &.{metadata}, &.{dict.content});
    const owned_set: ZstdOwnedDictionarySet = try zstdDictionarySetFromMetadataAlloc(std.testing.allocator, &.{metadata}, &.{dict.content});
    defer owned_set.deinit(std.testing.allocator);
    try std.testing.expectEqual(dict.id, metadata_set.dictionaries[0].id);
    try std.testing.expectEqual(dict.id, owned_set.asDictionarySet().dictionaries[0].id);

    const standard = try zstdStandardDictionaryFromContentAlloc(std.testing.allocator, dict.content, dict.id);
    defer standard.deinit(std.testing.allocator);
    try std.testing.expectEqual(ZstdDictionaryKind.standard_full, standard.asDictionary().kind());
    try std.testing.expectEqual(dict.id, zstdStandardDictionaryId(standard.bytes).?);
    try std.testing.expectEqualSlices(u8, dict.content, standard.view.content);
    const trained_standard = try zstdTrainStandardDictionaryAlloc(
        std.testing.allocator,
        &samples,
        train_options,
        dict.id +% 1,
    );
    defer trained_standard.deinit(std.testing.allocator);
    try std.testing.expectEqual(ZstdDictionaryKind.standard_full, trained_standard.asDictionary().kind());
    const validated_standard = try zstdTrainValidatedStandardDictionaryAlloc(
        std.testing.allocator,
        &samples,
        &.{"root zstd public dictionary sample alpha beta"},
        train_options,
        dict.id +% 2,
    );
    defer validated_standard.deinit(std.testing.allocator);
    try std.testing.expectEqual(ZstdDictionaryKind.standard_full, validated_standard.asDictionary().kind());

    var options: ZstdAdvancedFrameOptions = .{
        .selection = .literal_only,
        .content_checksum = true,
    };
    try std.testing.expectEqual(ZstdFrameSelection.literal_only, options.selection);
    const payload = "root zstd public dictionary sample alpha gamma payload";
    const bound = try zstdEncodedNativeFrameBoundWithDictionary(payload.len, options, dict);

    var encoder = ZstdFrameEncoder.init(std.testing.allocator);
    defer encoder.deinit();
    const encoded = try encoder.encodeWithDictionaryAlloc(payload, options, dict);
    defer std.testing.allocator.free(encoded.frame);
    try std.testing.expectEqual(ZstdFrameMode.literal_only, encoded.mode);
    try std.testing.expect(encoded.frame.len <= bound);

    var into = try std.testing.allocator.alloc(u8, bound);
    defer std.testing.allocator.free(into);
    const encoded_into: ZstdFrameEncodeIntoResult = try encoder.encodeIntoSliceWithDictionary(payload, options, dict, into);
    try std.testing.expectEqual(encoded.mode, encoded_into.mode);
    try std.testing.expectEqualSlices(u8, encoded.frame, into[0..encoded_into.written]);
    const scratch: ZstdFrameEncodeScratchResult = try encoder.encodeScratchWithDictionary(payload, options, dict);
    try std.testing.expectEqual(encoded.mode, scratch.mode);
    try std.testing.expectEqualSlices(u8, encoded.frame, scratch.frame);
    const owned_result: ZstdFrameEncodeResult = encoded;
    try std.testing.expectEqual(ZstdFrameMode.literal_only, owned_result.mode);

    const fast_options: ZstdAdvancedFrameOptions = .{
        .selection = .fast_compressed,
        .content_checksum = true,
    };
    const fast_encoded = try zstdEncodeFrameWithAdvancedOptionsAlloc(std.testing.allocator, payload, fast_options);
    defer std.testing.allocator.free(fast_encoded.frame);
    try std.testing.expectEqual(ZstdFrameMode.fast_compressed, fast_encoded.mode);
    const fast_decoded = try zstdDecodeFrameAlloc(std.testing.allocator, fast_encoded.frame);
    defer std.testing.allocator.free(fast_decoded);
    try std.testing.expectEqualSlices(u8, payload, fast_decoded);

    var decoder = ZstdFrameDecoder.init(std.testing.allocator);
    defer decoder.deinit();
    const decoded = try decoder.decodeAllocWithDictionaryExactSize(encoded.frame, dict, payload.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    try std.testing.expectEqual(payload.len, try decoder.decodedSizeWithDictionary(encoded.frame, dict));
    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(std.testing.allocator);
    try appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(payload.len, try decoder.decodeAppendExactSizeWithDictionary(&appended, encoded.frame, dict, payload.len));
    try std.testing.expectEqualSlices(u8, payload, appended.items["prefix:".len..]);

    var incremental = ZstdIncrementalFrameDecoder.initWithDictionaryAndOptions(std.testing.allocator, dict, .{
        .expected_output_len = payload.len,
    });
    defer incremental.deinit();
    var output: [payload.len]u8 = undefined;
    var written_total: usize = 0;
    var input_offset: usize = 0;
    while (true) {
        const input_end = @min(encoded.frame.len, input_offset + 5);
        const output_end = @min(output.len, written_total + 7);
        const result = try incremental.step(encoded.frame[input_offset..input_end], output[written_total..output_end]);
        input_offset += result.progress.input_read;
        written_total += result.progress.output_written;
        if (result.status == .done) break;
        try std.testing.expect(result.status == .need_input or result.status == .need_output);
    }
    try std.testing.expectEqual(payload.len, written_total);
    try std.testing.expectEqualSlices(u8, payload, &output);
    try std.testing.expectEqualSlices(u8, "done", incremental.diagnostics().phase_name);

    options.selection = .raw_or_rle;
    try std.testing.expectEqual(ZstdFrameSelection.raw_or_rle, options.selection);
}

test "root zstd advanced encode facade exposes public helpers" {
    const first_dict = ZstdDictionary.init(0x7a71, "advanced-first-prefix-");
    const second_dict = ZstdDictionary.init(0x7a72, "advanced-second-prefix-");
    const dictionary_set = ZstdDictionarySet.init(&.{ first_dict, second_dict });
    const plain_payload = "advanced plain payload plain payload plain payload";
    const dict_payload = "advanced-first-prefix-payload advanced-first-prefix-tail";
    const set_payload = "advanced-second-prefix-payload advanced-second-prefix-tail";
    const options: ZstdAdvancedFrameOptions = .{
        .selection = .literal_only,
        .content_checksum = true,
        .include_content_size = true,
    };

    const plain_bound = try zstdEncodedFrameBoundWithAdvancedOptions(plain_payload.len, options);
    const plain_encoded = try zstdEncodeFrameWithAdvancedOptionsAlloc(std.testing.allocator, plain_payload, options);
    defer std.testing.allocator.free(plain_encoded.frame);
    try std.testing.expectEqual(ZstdFrameMode.literal_only, plain_encoded.mode);
    try std.testing.expect(plain_encoded.frame.len <= plain_bound);
    const plain_decoded = try zstdDecodeFrameAllocExactSize(std.testing.allocator, plain_encoded.frame, plain_payload.len);
    defer std.testing.allocator.free(plain_decoded);
    try std.testing.expectEqualSlices(u8, plain_payload, plain_decoded);
    var plain_appended: std.ArrayList(u8) = .empty;
    defer plain_appended.deinit(std.testing.allocator);
    try plain_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(ZstdFrameMode.literal_only, try zstdEncodeFrameAppendWithAdvancedOptions(std.testing.allocator, &plain_appended, plain_payload, options));
    try std.testing.expectEqualSlices(u8, plain_encoded.frame, plain_appended.items["prefix:".len..]);
    const plain_into = try std.testing.allocator.alloc(u8, plain_bound);
    defer std.testing.allocator.free(plain_into);
    const plain_into_result = try zstdEncodeFrameIntoSliceWithAdvancedOptions(std.testing.allocator, plain_payload, options, plain_into);
    try std.testing.expectEqual(ZstdFrameMode.literal_only, plain_into_result.mode);
    try std.testing.expectEqualSlices(u8, plain_encoded.frame, plain_into[0..plain_into_result.written]);

    const dict_bound = try zstdEncodedFrameBoundWithAdvancedOptionsAndDictionary(dict_payload.len, options, first_dict);
    const dict_encoded = try zstdEncodeFrameWithAdvancedOptionsAndDictionaryAlloc(std.testing.allocator, dict_payload, options, first_dict);
    defer std.testing.allocator.free(dict_encoded.frame);
    try std.testing.expectEqual(ZstdFrameMode.literal_only, dict_encoded.mode);
    try std.testing.expect(dict_encoded.frame.len <= dict_bound);
    const dict_decoded = try zstdDecodeFrameAllocWithDictionaryExactSize(std.testing.allocator, dict_encoded.frame, first_dict, dict_payload.len);
    defer std.testing.allocator.free(dict_decoded);
    try std.testing.expectEqualSlices(u8, dict_payload, dict_decoded);
    var dict_appended: std.ArrayList(u8) = .empty;
    defer dict_appended.deinit(std.testing.allocator);
    try dict_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(ZstdFrameMode.literal_only, try zstdEncodeFrameAppendWithAdvancedOptionsAndDictionary(std.testing.allocator, &dict_appended, dict_payload, options, first_dict));
    try std.testing.expectEqualSlices(u8, dict_encoded.frame, dict_appended.items["prefix:".len..]);
    const dict_into = try std.testing.allocator.alloc(u8, dict_bound);
    defer std.testing.allocator.free(dict_into);
    const dict_into_result = try zstdEncodeFrameIntoSliceWithAdvancedOptionsAndDictionary(std.testing.allocator, dict_payload, options, first_dict, dict_into);
    try std.testing.expectEqual(ZstdFrameMode.literal_only, dict_into_result.mode);
    try std.testing.expectEqualSlices(u8, dict_encoded.frame, dict_into[0..dict_into_result.written]);

    const set_bound = try zstdEncodedFrameBoundWithAdvancedOptionsAndDictionarySet(set_payload.len, options, dictionary_set, second_dict.id);
    const set_encoded = try zstdEncodeFrameWithAdvancedOptionsAndDictionarySetAlloc(std.testing.allocator, set_payload, options, dictionary_set, second_dict.id);
    defer std.testing.allocator.free(set_encoded.frame);
    try std.testing.expectEqual(ZstdFrameMode.literal_only, set_encoded.mode);
    try std.testing.expect(set_encoded.frame.len <= set_bound);
    const set_decoded = try zstdDecodeFrameAllocWithDictionarySetExactSize(std.testing.allocator, set_encoded.frame, dictionary_set, set_payload.len);
    defer std.testing.allocator.free(set_decoded);
    try std.testing.expectEqualSlices(u8, set_payload, set_decoded);
    var set_appended: std.ArrayList(u8) = .empty;
    defer set_appended.deinit(std.testing.allocator);
    try set_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(ZstdFrameMode.literal_only, try zstdEncodeFrameAppendWithAdvancedOptionsAndDictionarySet(std.testing.allocator, &set_appended, set_payload, options, dictionary_set, second_dict.id));
    try std.testing.expectEqualSlices(u8, set_encoded.frame, set_appended.items["prefix:".len..]);
    const set_into = try std.testing.allocator.alloc(u8, set_bound);
    defer std.testing.allocator.free(set_into);
    const set_into_result = try zstdEncodeFrameIntoSliceWithAdvancedOptionsAndDictionarySet(std.testing.allocator, set_payload, options, dictionary_set, second_dict.id, set_into);
    try std.testing.expectEqual(ZstdFrameMode.literal_only, set_into_result.mode);
    try std.testing.expectEqualSlices(u8, set_encoded.frame, set_into[0..set_into_result.written]);
    try std.testing.expectError(error.NeedDictionary, zstdEncodedFrameBoundWithAdvancedOptionsAndDictionarySet(set_payload.len, options, dictionary_set, 0xffff));
}

test "root zstd concatenated frame facade exposes public helpers" {
    const first_payload = "root zstd concatenated first payload " ** 2;
    const second_payload = "root zstd concatenated second payload " ** 2;
    const expected = first_payload ++ second_payload;

    const first = try zstdEncodeFrameWithOptionsAlloc(std.testing.allocator, first_payload, .{ .content_checksum = true });
    defer std.testing.allocator.free(first);
    const second = try zstdEncodeFrameWithOptionsAlloc(std.testing.allocator, second_payload, .{ .content_checksum = true });
    defer std.testing.allocator.free(second);

    var stream: std.ArrayList(u8) = .empty;
    defer stream.deinit(std.testing.allocator);
    try stream.appendSlice(std.testing.allocator, first);
    try stream.appendSlice(std.testing.allocator, second);

    try std.testing.expectEqual(expected.len, try zstdDecodedConcatenatedFrameSize(stream.items));
    try std.testing.expectEqual(expected.len, try zstdDecodedConcatenatedFrameSizeLimited(stream.items, expected.len));
    try std.testing.expectError(error.OutputLimitExceeded, zstdDecodedConcatenatedFrameSizeLimited(stream.items, expected.len - 1));
    const decoded = try zstdDecodeConcatenatedFrameAllocExactSize(std.testing.allocator, stream.items, expected.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, expected, decoded);
    const limited = try zstdDecodeConcatenatedFrameAllocLimited(std.testing.allocator, stream.items, expected.len);
    defer std.testing.allocator.free(limited);
    try std.testing.expectEqualSlices(u8, expected, limited);
    try std.testing.expectError(error.OutputLimitExceeded, zstdDecodeConcatenatedFrameAllocLimited(std.testing.allocator, stream.items, expected.len - 1));
    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(std.testing.allocator);
    try appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(expected.len, try zstdDecodeConcatenatedFrameAppendLimited(std.testing.allocator, &appended, stream.items, expected.len));
    try std.testing.expectEqualSlices(u8, "prefix:", appended.items[0.."prefix:".len]);
    try std.testing.expectEqualSlices(u8, expected, appended.items["prefix:".len..]);
    var into: [expected.len]u8 = undefined;
    try std.testing.expectEqual(expected.len, try zstdDecodeConcatenatedFrameIntoExactSize(stream.items, &into, expected.len));
    try std.testing.expectEqualSlices(u8, expected, &into);

    const chunks = [_][]const u8{
        stream.items[0..5],
        stream.items[5 .. stream.items.len - 7],
        stream.items[stream.items.len - 7 ..],
    };
    const chunk_scratch = try std.testing.allocator.alloc(u8, stream.items.len);
    defer std.testing.allocator.free(chunk_scratch);
    try std.testing.expectEqual(expected.len, try zstdDecodedConcatenatedFrameChunksSize(&chunks, chunk_scratch));
    try std.testing.expectEqual(expected.len, try zstdDecodedConcatenatedFrameChunksSizeLimited(&chunks, chunk_scratch, expected.len));
    try std.testing.expectError(error.OutputLimitExceeded, zstdDecodedConcatenatedFrameChunksSizeLimited(&chunks, chunk_scratch, expected.len - 1));
    const chunked = try zstdDecodeConcatenatedFrameChunksAllocExactSize(std.testing.allocator, &chunks, chunk_scratch, expected.len);
    defer std.testing.allocator.free(chunked);
    try std.testing.expectEqualSlices(u8, expected, chunked);
    var chunked_into: [expected.len]u8 = undefined;
    try std.testing.expectEqual(expected.len, try zstdDecodeConcatenatedFrameChunksIntoExactSize(&chunks, chunk_scratch, &chunked_into, expected.len));
    try std.testing.expectEqualSlices(u8, expected, &chunked_into);
}

test "root zstd concatenated dictionary facade exposes public helpers" {
    const dict = ZstdNativeDictionary.init(0x7a61, "zstd-concat-dict-prefix-");
    const first_payload = "zstd-concat-dict-prefix-first";
    const second_payload = "zstd-concat-dict-prefix-second";
    const expected = first_payload ++ second_payload;

    const first = try zstdEncodeFrameWithOptionsAndDictionaryAlloc(std.testing.allocator, first_payload, .{ .content_checksum = true }, dict);
    defer std.testing.allocator.free(first);
    const second = try zstdEncodeFrameWithOptionsAndDictionaryAlloc(std.testing.allocator, second_payload, .{ .content_checksum = true }, dict);
    defer std.testing.allocator.free(second);

    var stream: std.ArrayList(u8) = .empty;
    defer stream.deinit(std.testing.allocator);
    try stream.appendSlice(std.testing.allocator, first);
    try stream.appendSlice(std.testing.allocator, second);

    try std.testing.expectEqual(expected.len, try zstdDecodedConcatenatedFrameSizeWithDictionary(stream.items, dict));
    try std.testing.expectEqual(expected.len, try zstdDecodedConcatenatedFrameSizeLimitedWithDictionary(stream.items, expected.len, dict));
    try std.testing.expectError(error.OutputLimitExceeded, zstdDecodedConcatenatedFrameSizeLimitedWithDictionary(stream.items, expected.len - 1, dict));
    const decoded = try zstdDecodeConcatenatedFrameAllocWithDictionaryExactSize(std.testing.allocator, stream.items, dict, expected.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, expected, decoded);
    const limited = try zstdDecodeConcatenatedFrameAllocLimitedWithDictionary(std.testing.allocator, stream.items, expected.len, dict);
    defer std.testing.allocator.free(limited);
    try std.testing.expectEqualSlices(u8, expected, limited);
    try std.testing.expectError(error.OutputLimitExceeded, zstdDecodeConcatenatedFrameAllocLimitedWithDictionary(std.testing.allocator, stream.items, expected.len - 1, dict));
    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(std.testing.allocator);
    try appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(expected.len, try zstdDecodeConcatenatedFrameAppendExactSizeWithDictionary(std.testing.allocator, &appended, stream.items, dict, expected.len));
    try std.testing.expectEqualSlices(u8, expected, appended.items["prefix:".len..]);
    var into: [expected.len]u8 = undefined;
    try std.testing.expectEqual(expected.len, try zstdDecodeConcatenatedFrameIntoWithDictionaryExactSize(stream.items, &into, dict, expected.len));
    try std.testing.expectEqualSlices(u8, expected, &into);

    const chunks = [_][]const u8{
        stream.items[0..5],
        stream.items[5 .. stream.items.len - 7],
        stream.items[stream.items.len - 7 ..],
    };
    const chunk_scratch = try std.testing.allocator.alloc(u8, stream.items.len);
    defer std.testing.allocator.free(chunk_scratch);
    try std.testing.expectEqual(expected.len, try zstdDecodedConcatenatedFrameChunksSizeWithDictionary(&chunks, chunk_scratch, dict));
    try std.testing.expectEqual(expected.len, try zstdDecodedConcatenatedFrameChunksSizeLimitedWithDictionary(&chunks, chunk_scratch, expected.len, dict));
    try std.testing.expectError(error.OutputLimitExceeded, zstdDecodedConcatenatedFrameChunksSizeLimitedWithDictionary(&chunks, chunk_scratch, expected.len - 1, dict));
    const chunked = try zstdDecodeConcatenatedFrameChunksAllocWithDictionaryExactSize(std.testing.allocator, &chunks, chunk_scratch, dict, expected.len);
    defer std.testing.allocator.free(chunked);
    try std.testing.expectEqualSlices(u8, expected, chunked);
    var chunked_into: [expected.len]u8 = undefined;
    try std.testing.expectEqual(expected.len, try zstdDecodeConcatenatedFrameChunksIntoWithDictionaryExactSize(&chunks, chunk_scratch, &chunked_into, dict, expected.len));
    try std.testing.expectEqualSlices(u8, expected, &chunked_into);
}

test "root zstd concatenated dictionary-set facade exposes public helpers" {
    const first_dict = ZstdNativeDictionary.init(0x7a62, "zstd-concat-set-first-");
    const second_dict = ZstdNativeDictionary.init(0x7a63, "zstd-concat-set-second-");
    const dictionary_set = ZstdNativeDictionarySet.init(&.{ first_dict, second_dict });
    const first_payload = "zstd-concat-set-first-payload";
    const second_payload = "zstd-concat-set-second-payload";
    const expected = first_payload ++ second_payload;

    const first = try zstdEncodeFrameWithOptionsAndDictionarySetAlloc(std.testing.allocator, first_payload, .{ .content_checksum = true }, dictionary_set, first_dict.id);
    defer std.testing.allocator.free(first);
    const second = try zstdEncodeFrameWithOptionsAndDictionarySetAlloc(std.testing.allocator, second_payload, .{ .content_checksum = true }, dictionary_set, second_dict.id);
    defer std.testing.allocator.free(second);

    var stream: std.ArrayList(u8) = .empty;
    defer stream.deinit(std.testing.allocator);
    try stream.appendSlice(std.testing.allocator, first);
    try stream.appendSlice(std.testing.allocator, second);

    try std.testing.expectEqual(expected.len, try zstdDecodedConcatenatedFrameSizeWithDictionarySet(stream.items, dictionary_set));
    try std.testing.expectEqual(expected.len, try zstdDecodedConcatenatedFrameSizeLimitedWithDictionarySet(stream.items, expected.len, dictionary_set));
    try std.testing.expectError(error.OutputLimitExceeded, zstdDecodedConcatenatedFrameSizeLimitedWithDictionarySet(stream.items, expected.len - 1, dictionary_set));
    const decoded = try zstdDecodeConcatenatedFrameAllocWithDictionarySetExactSize(std.testing.allocator, stream.items, dictionary_set, expected.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, expected, decoded);
    const limited = try zstdDecodeConcatenatedFrameAllocLimitedWithDictionarySet(std.testing.allocator, stream.items, expected.len, dictionary_set);
    defer std.testing.allocator.free(limited);
    try std.testing.expectEqualSlices(u8, expected, limited);
    try std.testing.expectError(error.OutputLimitExceeded, zstdDecodeConcatenatedFrameAllocLimitedWithDictionarySet(std.testing.allocator, stream.items, expected.len - 1, dictionary_set));
    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(std.testing.allocator);
    try appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(expected.len, try zstdDecodeConcatenatedFrameAppendExactSizeWithDictionarySet(std.testing.allocator, &appended, stream.items, dictionary_set, expected.len));
    try std.testing.expectEqualSlices(u8, expected, appended.items["prefix:".len..]);
    var into: [expected.len]u8 = undefined;
    try std.testing.expectEqual(expected.len, try zstdDecodeConcatenatedFrameIntoWithDictionarySetExactSize(stream.items, &into, dictionary_set, expected.len));
    try std.testing.expectEqualSlices(u8, expected, &into);

    const chunks = [_][]const u8{
        stream.items[0..5],
        stream.items[5 .. stream.items.len - 7],
        stream.items[stream.items.len - 7 ..],
    };
    const chunk_scratch = try std.testing.allocator.alloc(u8, stream.items.len);
    defer std.testing.allocator.free(chunk_scratch);
    try std.testing.expectEqual(expected.len, try zstdDecodedConcatenatedFrameChunksSizeWithDictionarySet(&chunks, chunk_scratch, dictionary_set));
    try std.testing.expectEqual(expected.len, try zstdDecodedConcatenatedFrameChunksSizeLimitedWithDictionarySet(&chunks, chunk_scratch, expected.len, dictionary_set));
    try std.testing.expectError(error.OutputLimitExceeded, zstdDecodedConcatenatedFrameChunksSizeLimitedWithDictionarySet(&chunks, chunk_scratch, expected.len - 1, dictionary_set));
    const chunked = try zstdDecodeConcatenatedFrameChunksAllocWithDictionarySetExactSize(std.testing.allocator, &chunks, chunk_scratch, dictionary_set, expected.len);
    defer std.testing.allocator.free(chunked);
    try std.testing.expectEqualSlices(u8, expected, chunked);
    var chunked_into: [expected.len]u8 = undefined;
    try std.testing.expectEqual(expected.len, try zstdDecodeConcatenatedFrameChunksIntoWithDictionarySetExactSize(&chunks, chunk_scratch, &chunked_into, dictionary_set, expected.len));
    try std.testing.expectEqualSlices(u8, expected, &chunked_into);
}

test "root zstd native size preflight covers compressed blocks" {
    const payload = ("ab" ** 12) ++ ("cdef" ** 20) ++ "tail";
    const encoded = try zstdEncodeNativeFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .selection = .literal_only,
    });
    defer std.testing.allocator.free(encoded.frame);

    const decoded_len = try zstdDecodedNativeFrameSize(encoded.frame);
    try std.testing.expectEqual(payload.len, decoded_len);
    try std.testing.expectEqual(payload.len, try zstdDecodedNativeFrameSizeLimited(encoded.frame, payload.len));
    try std.testing.expectError(error.OutputLimitExceeded, zstdDecodedNativeFrameSizeLimited(encoded.frame, payload.len - 1));
}

test "root zstd explicit native encode-into helpers round trip" {
    const raw_payload = "rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr";
    const raw_bound = try zstdEncodedNativeFrameBoundWithOptions(raw_payload.len, .{ .selection = .raw_or_rle });
    const raw_into = try std.testing.allocator.alloc(u8, raw_bound);
    defer std.testing.allocator.free(raw_into);
    const raw_written = try zstdEncodeRawOrRleFrameIntoSlice(std.testing.allocator, raw_payload, .{}, raw_into);
    const raw_decoded = try zstdDecodeNativeFrameAlloc(std.testing.allocator, raw_into[0..raw_written]);
    defer std.testing.allocator.free(raw_decoded);
    try std.testing.expectEqualSlices(u8, raw_payload, raw_decoded);

    const literal_payload = "prefix-abcdefghijklmno-middle-abcdefghijklmno-tail";
    const literal_bound = try zstdEncodedNativeFrameBoundWithOptions(literal_payload.len, .{ .selection = .literal_only });
    const literal_into = try std.testing.allocator.alloc(u8, literal_bound);
    defer std.testing.allocator.free(literal_into);
    const literal_written = try zstdEncodeLiteralOnlyFrameIntoSlice(std.testing.allocator, literal_payload, .{}, literal_into);
    const literal_decoded = try zstdDecodeNativeFrameAlloc(std.testing.allocator, literal_into[0..literal_written]);
    defer std.testing.allocator.free(literal_decoded);
    try std.testing.expectEqualSlices(u8, literal_payload, literal_decoded);
}

test "root zstd native incremental decoder round trip" {
    const payload = "root zstd incremental payload " ** 3;
    const encoded = try zstdEncodeNativeFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .selection = .literal_only,
        .content_checksum = false,
    });
    defer std.testing.allocator.free(encoded.frame);

    var decoder = ZstdNativeIncrementalFrameDecoder.init(std.testing.allocator);
    defer decoder.deinit();
    var output: [payload.len]u8 = undefined;

    const first = try decoder.step(encoded.frame[0..5], output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_input, first.status);
    try std.testing.expectEqual(@as(usize, 5), first.progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), first.progress.output_written);

    const second = try decoder.step(encoded.frame[5..], output[0..13]);
    try std.testing.expectEqual(StepResult.Status.need_output, second.status);
    try std.testing.expectEqual(encoded.frame.len - 5, second.progress.input_read);
    try std.testing.expectEqual(@as(usize, 13), second.progress.output_written);

    var written = second.progress.output_written;
    while (true) {
        const end = @min(output.len, written + 11);
        const result = try decoder.step("", output[written..end]);
        written += result.progress.output_written;
        if (result.status == .done) break;
        try std.testing.expectEqual(StepResult.Status.need_output, result.status);
    }
    try std.testing.expectEqual(payload.len, written);
    try std.testing.expectEqualSlices(u8, payload, &output);
    try std.testing.expectEqualSlices(u8, "done", decoder.diagnostics().phase_name);
}

test "root native incremental decoders wait on split skippable headers" {
    const lz4_payload = "root-lz4-split-skippable";
    const lz4_skip = try lz4EncodeSkippableFrameAlloc(std.testing.allocator, 4, "root-lz4-skippable-metadata");
    defer std.testing.allocator.free(lz4_skip);
    const lz4_frame = try lz4EncodeNativeFrameWithOptionsAlloc(std.testing.allocator, lz4_payload, .{
        .content_checksum = false,
        .include_content_size = true,
        .block_checksum = true,
    });
    defer std.testing.allocator.free(lz4_frame);
    const lz4_tail = try std.mem.concat(std.testing.allocator, u8, &.{ lz4_skip[5..], lz4_frame });
    defer std.testing.allocator.free(lz4_tail);

    var lz4_decoder = Lz4NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = lz4_payload.len,
        .max_decoded_buffer_len = lz4_payload.len,
    });
    defer lz4_decoder.deinit();
    var lz4_output: [lz4_payload.len]u8 = undefined;

    // Split immediately after the magic plus one size byte. This is the point
    // where a transport chunk has identified a skippable frame but not enough
    // bytes to know the metadata length yet, so both native decoders must stay
    // resumable in the public frame phase.
    const lz4_partial = try lz4_decoder.step(lz4_skip[0..5], lz4_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_input, lz4_partial.status);
    try std.testing.expectEqual(@as(usize, 5), lz4_partial.progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), lz4_partial.progress.output_written);
    try std.testing.expectEqualSlices(u8, "frame", lz4_decoder.diagnostics().phase_name);

    const lz4_done = try lz4_decoder.step(lz4_tail, &lz4_output);
    try std.testing.expectEqual(StepResult.Status.done, lz4_done.status);
    try std.testing.expectEqual(lz4_tail.len, lz4_done.progress.input_read);
    try std.testing.expectEqual(lz4_payload.len, lz4_done.progress.output_written);
    try std.testing.expectEqualSlices(u8, lz4_payload, &lz4_output);
    try lz4_decoder.finish();

    const zstd_payload = "root-zstd-split-skippable";
    const zstd_skip = try zstdEncodeSkippableFrameAlloc(std.testing.allocator, 5, "root-zstd-skippable-metadata");
    defer std.testing.allocator.free(zstd_skip);
    const zstd_frame = try zstdEncodeNativeFrameWithOptionsAlloc(std.testing.allocator, zstd_payload, .{
        .selection = .literal_only,
        .content_checksum = false,
    });
    defer std.testing.allocator.free(zstd_frame.frame);
    const zstd_tail = try std.mem.concat(std.testing.allocator, u8, &.{ zstd_skip[5..], zstd_frame.frame });
    defer std.testing.allocator.free(zstd_tail);

    var zstd_decoder = ZstdNativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = zstd_payload.len,
        .max_decoded_buffer_len = zstd_payload.len,
    });
    defer zstd_decoder.deinit();
    var zstd_output: [zstd_payload.len]u8 = undefined;

    const zstd_partial = try zstd_decoder.step(zstd_skip[0..5], zstd_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_input, zstd_partial.status);
    try std.testing.expectEqual(@as(usize, 5), zstd_partial.progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), zstd_partial.progress.output_written);
    try std.testing.expectEqualSlices(u8, "frame", zstd_decoder.diagnostics().phase_name);

    const zstd_done = try zstd_decoder.step(zstd_tail, &zstd_output);
    try std.testing.expectEqual(StepResult.Status.done, zstd_done.status);
    try std.testing.expectEqual(zstd_tail.len, zstd_done.progress.input_read);
    try std.testing.expectEqual(zstd_payload.len, zstd_done.progress.output_written);
    try std.testing.expectEqualSlices(u8, zstd_payload, &zstd_output);
    try zstd_decoder.finish();
}

test "root native incremental decoders reject truncated skippable metadata on finish" {
    const lz4_skip = try lz4EncodeSkippableFrameAlloc(std.testing.allocator, 6, "root-lz4-truncated-skippable");
    defer std.testing.allocator.free(lz4_skip);
    const lz4_truncated = lz4_skip[0 .. lz4_skip.len - 1];

    var lz4_decoder = Lz4NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = 0,
        .max_decoded_buffer_len = 0,
    });
    defer lz4_decoder.deinit();
    var lz4_output: [1]u8 = undefined;

    // The full skippable header is present, but the advertised metadata body is
    // one byte short. `step` must keep the stream resumable; `finish` is the
    // caller's explicit signal that no more input is coming and should surface
    // the truncation with frame-phase diagnostics.
    const lz4_wait = try lz4_decoder.step(lz4_truncated, lz4_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_input, lz4_wait.status);
    try std.testing.expectEqual(lz4_truncated.len, lz4_wait.progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), lz4_wait.progress.output_written);
    try std.testing.expectEqualSlices(u8, "frame", lz4_decoder.diagnostics().phase_name);
    try std.testing.expectError(error.TruncatedFrame, lz4_decoder.finish());
    try std.testing.expectEqualSlices(u8, "TruncatedFrame", lz4_decoder.diagnostics().last_error_name);
    try std.testing.expectEqualSlices(u8, "frame", lz4_decoder.diagnostics().last_error_phase_name);
    lz4_decoder.reset();
    try std.testing.expectEqualSlices(u8, "", lz4_decoder.diagnostics().last_error_name);
    const lz4_recovered = try lz4_decoder.step(lz4_skip, lz4_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.done, lz4_recovered.status);
    try std.testing.expectEqual(lz4_skip.len, lz4_recovered.progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), lz4_recovered.progress.output_written);
    try lz4_decoder.finish();

    const zstd_skip = try zstdEncodeSkippableFrameAlloc(std.testing.allocator, 7, "root-zstd-truncated-skippable");
    defer std.testing.allocator.free(zstd_skip);
    const zstd_truncated = zstd_skip[0 .. zstd_skip.len - 1];

    var zstd_decoder = ZstdNativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = 0,
        .max_decoded_buffer_len = 0,
    });
    defer zstd_decoder.deinit();
    var zstd_output: [1]u8 = undefined;

    const zstd_wait = try zstd_decoder.step(zstd_truncated, zstd_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_input, zstd_wait.status);
    try std.testing.expectEqual(zstd_truncated.len, zstd_wait.progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), zstd_wait.progress.output_written);
    try std.testing.expectEqualSlices(u8, "frame", zstd_decoder.diagnostics().phase_name);
    try std.testing.expectError(error.TruncatedFrame, zstd_decoder.finish());
    try std.testing.expectEqualSlices(u8, "TruncatedFrame", zstd_decoder.diagnostics().last_error_name);
    try std.testing.expectEqualSlices(u8, "frame", zstd_decoder.diagnostics().last_error_phase_name);
    zstd_decoder.reset();
    try std.testing.expectEqualSlices(u8, "", zstd_decoder.diagnostics().last_error_name);
    const zstd_recovered = try zstd_decoder.step(zstd_skip, zstd_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.done, zstd_recovered.status);
    try std.testing.expectEqual(zstd_skip.len, zstd_recovered.progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), zstd_recovered.progress.output_written);
    try zstd_decoder.finish();
}

test "root native incremental decoders finish skippable-only streams with zero expected output" {
    const lz4_skip = try lz4EncodeSkippableFrameAlloc(std.testing.allocator, 6, "root-lz4-skippable-only");
    defer std.testing.allocator.free(lz4_skip);
    var lz4_decoder = Lz4NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = 0,
        .max_decoded_buffer_len = 0,
    });
    defer lz4_decoder.deinit();
    var lz4_output: [1]u8 = undefined;
    const lz4_done = try lz4_decoder.step(lz4_skip, lz4_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.done, lz4_done.status);
    try std.testing.expectEqual(lz4_skip.len, lz4_done.progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), lz4_done.progress.output_written);
    try std.testing.expectEqual(lz4_skip.len, lz4_decoder.diagnostics().frame_input_read);
    try std.testing.expectEqual(@as(usize, 0), lz4_decoder.diagnostics().output_written);
    try lz4_decoder.finish();

    const lz4_second_skip = try lz4EncodeSkippableFrameAlloc(std.testing.allocator, 7, "root-lz4-skippable-only-two");
    defer std.testing.allocator.free(lz4_second_skip);
    const lz4_stream = try std.mem.concat(std.testing.allocator, u8, &.{ lz4_skip, lz4_second_skip });
    defer std.testing.allocator.free(lz4_stream);
    var lz4_multi_decoder = Lz4NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = 0,
        .max_decoded_buffer_len = 0,
    });
    defer lz4_multi_decoder.deinit();
    const lz4_multi_done = try lz4_multi_decoder.step(lz4_stream, lz4_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.done, lz4_multi_done.status);
    try std.testing.expectEqual(lz4_stream.len, lz4_multi_done.progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), lz4_multi_done.progress.output_written);
    try std.testing.expectEqual(lz4_stream.len, lz4_multi_decoder.diagnostics().frame_input_read);
    try std.testing.expectEqual(@as(usize, 0), lz4_multi_decoder.diagnostics().output_written);
    try lz4_multi_decoder.finish();

    var lz4_split_decoder = Lz4NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = 0,
        .max_decoded_buffer_len = 0,
    });
    defer lz4_split_decoder.deinit();
    const lz4_split_first = try lz4_split_decoder.step(lz4_stream[0 .. lz4_skip.len + 5], lz4_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_input, lz4_split_first.status);
    try std.testing.expectEqual(lz4_skip.len + 5, lz4_split_first.progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), lz4_split_first.progress.output_written);
    try std.testing.expectEqualSlices(u8, "frame", lz4_split_decoder.diagnostics().phase_name);
    const lz4_split_done = try lz4_split_decoder.step(lz4_stream[lz4_skip.len + 5 ..], lz4_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.done, lz4_split_done.status);
    try std.testing.expectEqual(lz4_stream.len - lz4_skip.len - 5, lz4_split_done.progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), lz4_split_done.progress.output_written);
    try std.testing.expectEqual(lz4_stream.len, lz4_split_decoder.diagnostics().frame_input_read);
    try std.testing.expectEqual(@as(usize, 0), lz4_split_decoder.diagnostics().output_written);
    try lz4_split_decoder.finish();

    const zstd_skip = try zstdEncodeSkippableFrameAlloc(std.testing.allocator, 7, "root-zstd-skippable-only");
    defer std.testing.allocator.free(zstd_skip);
    var zstd_decoder = ZstdNativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = 0,
        .max_decoded_buffer_len = 0,
    });
    defer zstd_decoder.deinit();
    var zstd_output: [1]u8 = undefined;
    const zstd_done = try zstd_decoder.step(zstd_skip, zstd_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.done, zstd_done.status);
    try std.testing.expectEqual(zstd_skip.len, zstd_done.progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), zstd_done.progress.output_written);
    try std.testing.expectEqual(zstd_skip.len, zstd_decoder.diagnostics().frame_input_read);
    try std.testing.expectEqual(@as(usize, 0), zstd_decoder.diagnostics().output_written);
    try zstd_decoder.finish();

    const zstd_second_skip = try zstdEncodeSkippableFrameAlloc(std.testing.allocator, 8, "root-zstd-skippable-only-two");
    defer std.testing.allocator.free(zstd_second_skip);
    const zstd_stream = try std.mem.concat(std.testing.allocator, u8, &.{ zstd_skip, zstd_second_skip });
    defer std.testing.allocator.free(zstd_stream);
    var zstd_multi_decoder = ZstdNativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = 0,
        .max_decoded_buffer_len = 0,
    });
    defer zstd_multi_decoder.deinit();
    const zstd_multi_done = try zstd_multi_decoder.step(zstd_stream, zstd_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.done, zstd_multi_done.status);
    try std.testing.expectEqual(zstd_stream.len, zstd_multi_done.progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), zstd_multi_done.progress.output_written);
    try std.testing.expectEqual(zstd_stream.len, zstd_multi_decoder.diagnostics().frame_input_read);
    try std.testing.expectEqual(@as(usize, 0), zstd_multi_decoder.diagnostics().output_written);
    try zstd_multi_decoder.finish();

    var zstd_split_decoder = ZstdNativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = 0,
        .max_decoded_buffer_len = 0,
    });
    defer zstd_split_decoder.deinit();
    const zstd_split_first = try zstd_split_decoder.step(zstd_stream[0 .. zstd_skip.len + 5], zstd_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_input, zstd_split_first.status);
    try std.testing.expectEqual(zstd_skip.len + 5, zstd_split_first.progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), zstd_split_first.progress.output_written);
    try std.testing.expectEqualSlices(u8, "frame", zstd_split_decoder.diagnostics().phase_name);
    const zstd_split_done = try zstd_split_decoder.step(zstd_stream[zstd_skip.len + 5 ..], zstd_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.done, zstd_split_done.status);
    try std.testing.expectEqual(zstd_stream.len - zstd_skip.len - 5, zstd_split_done.progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), zstd_split_done.progress.output_written);
    try std.testing.expectEqual(zstd_stream.len, zstd_split_decoder.diagnostics().frame_input_read);
    try std.testing.expectEqual(@as(usize, 0), zstd_split_decoder.diagnostics().output_written);
    try zstd_split_decoder.finish();
}

test "root native incremental decoders handle consecutive split skippable frames" {
    const lz4_payload = "root-lz4-consecutive-skippables";
    const lz4_first_skip = try lz4EncodeSkippableFrameAlloc(std.testing.allocator, 8, "root-lz4-first-skip");
    defer std.testing.allocator.free(lz4_first_skip);
    const lz4_second_skip = try lz4EncodeSkippableFrameAlloc(std.testing.allocator, 9, "root-lz4-second-skip");
    defer std.testing.allocator.free(lz4_second_skip);
    const lz4_frame = try lz4EncodeNativeFrameWithOptionsAlloc(std.testing.allocator, lz4_payload, .{
        .content_checksum = false,
        .include_content_size = true,
        .block_checksum = true,
    });
    defer std.testing.allocator.free(lz4_frame);
    const lz4_first_chunk = try std.mem.concat(std.testing.allocator, u8, &.{ lz4_first_skip, lz4_second_skip[0..5] });
    defer std.testing.allocator.free(lz4_first_chunk);
    const lz4_second_chunk = try std.mem.concat(std.testing.allocator, u8, &.{ lz4_second_skip[5..], lz4_frame });
    defer std.testing.allocator.free(lz4_second_chunk);

    var lz4_decoder = Lz4NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = lz4_payload.len,
        .max_decoded_buffer_len = lz4_payload.len,
    });
    defer lz4_decoder.deinit();
    var lz4_output: [lz4_payload.len]u8 = undefined;

    // Consume one whole skippable frame and then stop mid-header in the next.
    // This protects the state machine path that discards already-complete
    // metadata while preserving a partial following frame in the scratch buffer.
    const lz4_wait = try lz4_decoder.step(lz4_first_chunk, lz4_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_input, lz4_wait.status);
    try std.testing.expectEqual(lz4_first_chunk.len, lz4_wait.progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), lz4_wait.progress.output_written);
    try std.testing.expectEqualSlices(u8, "frame", lz4_decoder.diagnostics().phase_name);

    const lz4_done = try lz4_decoder.step(lz4_second_chunk, &lz4_output);
    try std.testing.expectEqual(StepResult.Status.done, lz4_done.status);
    try std.testing.expectEqual(lz4_second_chunk.len, lz4_done.progress.input_read);
    try std.testing.expectEqual(lz4_payload.len, lz4_done.progress.output_written);
    try std.testing.expectEqual(lz4_first_chunk.len + lz4_second_chunk.len, lz4_decoder.diagnostics().frame_input_read);
    try std.testing.expectEqualSlices(u8, lz4_payload, &lz4_output);
    try lz4_decoder.finish();

    const zstd_payload = "root-zstd-consecutive-skippables";
    const zstd_first_skip = try zstdEncodeSkippableFrameAlloc(std.testing.allocator, 8, "root-zstd-first-skip");
    defer std.testing.allocator.free(zstd_first_skip);
    const zstd_second_skip = try zstdEncodeSkippableFrameAlloc(std.testing.allocator, 9, "root-zstd-second-skip");
    defer std.testing.allocator.free(zstd_second_skip);
    const zstd_frame = try zstdEncodeNativeFrameWithOptionsAlloc(std.testing.allocator, zstd_payload, .{
        .selection = .literal_only,
        .content_checksum = false,
    });
    defer std.testing.allocator.free(zstd_frame.frame);
    const zstd_first_chunk = try std.mem.concat(std.testing.allocator, u8, &.{ zstd_first_skip, zstd_second_skip[0..5] });
    defer std.testing.allocator.free(zstd_first_chunk);
    const zstd_second_chunk = try std.mem.concat(std.testing.allocator, u8, &.{ zstd_second_skip[5..], zstd_frame.frame });
    defer std.testing.allocator.free(zstd_second_chunk);

    var zstd_decoder = ZstdNativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = zstd_payload.len,
        .max_decoded_buffer_len = zstd_payload.len,
    });
    defer zstd_decoder.deinit();
    var zstd_output: [zstd_payload.len]u8 = undefined;

    const zstd_wait = try zstd_decoder.step(zstd_first_chunk, zstd_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_input, zstd_wait.status);
    try std.testing.expectEqual(zstd_first_chunk.len, zstd_wait.progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), zstd_wait.progress.output_written);
    try std.testing.expectEqualSlices(u8, "frame", zstd_decoder.diagnostics().phase_name);

    const zstd_done = try zstd_decoder.step(zstd_second_chunk, &zstd_output);
    try std.testing.expectEqual(StepResult.Status.done, zstd_done.status);
    try std.testing.expectEqual(zstd_second_chunk.len, zstd_done.progress.input_read);
    try std.testing.expectEqual(zstd_payload.len, zstd_done.progress.output_written);
    try std.testing.expectEqual(zstd_first_chunk.len + zstd_second_chunk.len, zstd_decoder.diagnostics().frame_input_read);
    try std.testing.expectEqualSlices(u8, zstd_payload, &zstd_output);
    try zstd_decoder.finish();
}

test "root native incremental decoders enforce compressed limits on skippable frames" {
    const lz4_skip = try lz4EncodeSkippableFrameAlloc(std.testing.allocator, 10, "root-lz4-limit-skippable");
    defer std.testing.allocator.free(lz4_skip);

    var lz4_decoder = Lz4NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = 0,
        .max_decoded_buffer_len = 0,
        .max_compressed_buffer_len = 8,
    });
    defer lz4_decoder.deinit();
    var lz4_output: [1]u8 = undefined;

    // Both native formats now consume skippable payloads incrementally after
    // retaining only the eight-byte header.
    const lz4_skipped = try lz4_decoder.step(lz4_skip, lz4_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.done, lz4_skipped.status);
    try std.testing.expectEqual(lz4_skip.len, lz4_skipped.progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), lz4_skipped.progress.output_written);
    try std.testing.expectEqual(@as(usize, lz4_skip.len - 8), lz4_decoder.snapshot().skippable_total);
    try std.testing.expectEqualSlices(u8, "", lz4_decoder.diagnostics().last_error_name);
    try lz4_decoder.finish();
    const lz4_small_skip = try lz4EncodeSkippableFrameAlloc(std.testing.allocator, 10, "");
    defer std.testing.allocator.free(lz4_small_skip);
    lz4_decoder.reset();
    try std.testing.expectEqualSlices(u8, "", lz4_decoder.diagnostics().last_error_name);
    const lz4_recovered = try lz4_decoder.step(lz4_small_skip, lz4_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.done, lz4_recovered.status);
    try std.testing.expectEqual(lz4_small_skip.len, lz4_recovered.progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), lz4_recovered.progress.output_written);
    try lz4_decoder.finish();

    var lz4_header_limited = Lz4NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = 0,
        .max_decoded_buffer_len = 0,
        .max_compressed_buffer_len = 7,
    });
    defer lz4_header_limited.deinit();
    try std.testing.expectError(error.OutputLimitExceeded, lz4_header_limited.step(lz4_skip, lz4_output[0..0]));
    try std.testing.expectEqual(@as(usize, 7), lz4_header_limited.snapshot().input_received);
    try std.testing.expectEqualSlices(u8, "frame", lz4_header_limited.diagnostics().last_error_phase_name);

    const zstd_skip = try zstdEncodeSkippableFrameAlloc(std.testing.allocator, 11, "root-zstd-limit-skippable");
    defer std.testing.allocator.free(zstd_skip);

    var zstd_decoder = ZstdNativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = 0,
        .max_decoded_buffer_len = 0,
        .max_compressed_buffer_len = 8,
    });
    defer zstd_decoder.deinit();
    var zstd_output: [1]u8 = undefined;

    // Zstd skippable payloads are consumed incrementally after their eight-byte
    // header, so metadata of any size can pass through a header-sized scratch
    // limit without producing decoded output.
    const zstd_skipped = try zstd_decoder.step(zstd_skip, zstd_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.done, zstd_skipped.status);
    try std.testing.expectEqual(zstd_skip.len, zstd_skipped.progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), zstd_skipped.progress.output_written);
    try std.testing.expectEqual(zstd_skip.len, zstd_decoder.snapshot().input_received);
    try std.testing.expectEqual(@as(usize, zstd_skip.len - 8), zstd_decoder.snapshot().skippable_total);
    try std.testing.expectEqualSlices(u8, "", zstd_decoder.diagnostics().last_error_name);
    try zstd_decoder.finish();
    const zstd_small_skip = try zstdEncodeSkippableFrameAlloc(std.testing.allocator, 11, "");
    defer std.testing.allocator.free(zstd_small_skip);
    zstd_decoder.reset();
    try std.testing.expectEqualSlices(u8, "", zstd_decoder.diagnostics().last_error_name);
    const zstd_recovered = try zstd_decoder.step(zstd_small_skip, zstd_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.done, zstd_recovered.status);
    try std.testing.expectEqual(zstd_small_skip.len, zstd_recovered.progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), zstd_recovered.progress.output_written);
    try zstd_decoder.finish();
}

test "root native incremental decoders use expected size after skippable no-size frames" {
    const lz4_payload = "root-lz4-skippable-nosize";
    const lz4_skip = try lz4EncodeSkippableFrameAlloc(std.testing.allocator, 12, "root-lz4-nosize-skip");
    defer std.testing.allocator.free(lz4_skip);
    const lz4_frame = try lz4EncodeNativeFrameWithOptionsAlloc(std.testing.allocator, lz4_payload, .{
        .include_content_size = false,
        .content_checksum = true,
        .block_checksum = true,
    });
    defer std.testing.allocator.free(lz4_frame);
    const lz4_stream = try std.mem.concat(std.testing.allocator, u8, &.{ lz4_skip, lz4_frame });
    defer std.testing.allocator.free(lz4_stream);

    var lz4_decoder = Lz4NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = lz4_payload.len,
        .max_decoded_buffer_len = lz4_payload.len,
    });
    defer lz4_decoder.deinit();
    var lz4_output: [lz4_payload.len]u8 = undefined;

    // The no-content-size frame carries no decoded-length promise of its own.
    // After skipping metadata, the direct-output path should still use the
    // caller's expected length as the bounded output contract.
    const lz4_initial = try lz4_decoder.step(lz4_stream, lz4_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_output, lz4_initial.status);
    try std.testing.expectEqual(lz4_stream.len, lz4_initial.progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), lz4_initial.progress.output_written);
    try std.testing.expectEqualSlices(u8, "direct_output", lz4_decoder.diagnostics().phase_name);
    try std.testing.expectEqual(@as(?usize, lz4_payload.len), lz4_decoder.snapshot().decoded_len);

    const lz4_done = try lz4_decoder.step("", &lz4_output);
    try std.testing.expectEqual(StepResult.Status.done, lz4_done.status);
    try std.testing.expectEqual(lz4_payload.len, lz4_done.progress.output_written);
    try std.testing.expectEqualSlices(u8, lz4_payload, &lz4_output);
    try lz4_decoder.finish();

    const zstd_payload = "root-zstd-skippable-nosize";
    const zstd_skip = try zstdEncodeSkippableFrameAlloc(std.testing.allocator, 13, "root-zstd-nosize-skip");
    defer std.testing.allocator.free(zstd_skip);
    const zstd_frame = try zstdEncodeNativeFrameWithOptionsAlloc(std.testing.allocator, zstd_payload, .{
        .include_content_size = false,
        .selection = .literal_only,
        .content_checksum = true,
    });
    defer std.testing.allocator.free(zstd_frame.frame);
    const zstd_stream = try std.mem.concat(std.testing.allocator, u8, &.{ zstd_skip, zstd_frame.frame });
    defer std.testing.allocator.free(zstd_stream);

    var zstd_decoder = ZstdNativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = zstd_payload.len,
        .max_decoded_buffer_len = zstd_payload.len,
    });
    defer zstd_decoder.deinit();
    var zstd_output: [zstd_payload.len]u8 = undefined;

    const zstd_initial = try zstd_decoder.step(zstd_stream, zstd_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_output, zstd_initial.status);
    try std.testing.expectEqual(zstd_stream.len, zstd_initial.progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), zstd_initial.progress.output_written);
    try std.testing.expectEqualSlices(u8, "direct_output", zstd_decoder.diagnostics().phase_name);
    try std.testing.expectEqual(@as(?usize, zstd_payload.len), zstd_decoder.snapshot().decoded_len);

    const zstd_done = try zstd_decoder.step("", &zstd_output);
    try std.testing.expectEqual(StepResult.Status.done, zstd_done.status);
    try std.testing.expectEqual(zstd_payload.len, zstd_done.progress.output_written);
    try std.testing.expectEqualSlices(u8, zstd_payload, &zstd_output);
    try zstd_decoder.finish();
}

test "root native incremental no-size streams diagnose expected size mismatches" {
    const lz4_payload = "root-lz4-nosize-size-mismatch";
    const lz4_skip = try lz4EncodeSkippableFrameAlloc(std.testing.allocator, 14, "root-lz4-mismatch-skip");
    defer std.testing.allocator.free(lz4_skip);
    const lz4_frame = try lz4EncodeNativeFrameWithOptionsAlloc(std.testing.allocator, lz4_payload, .{
        .include_content_size = false,
        .content_checksum = true,
        .block_checksum = true,
    });
    defer std.testing.allocator.free(lz4_frame);
    const lz4_stream = try std.mem.concat(std.testing.allocator, u8, &.{ lz4_skip, lz4_frame });
    defer std.testing.allocator.free(lz4_stream);
    var lz4_output: [lz4_payload.len]u8 = undefined;

    var lz4_too_small = Lz4NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = lz4_payload.len - 1,
        .max_decoded_buffer_len = lz4_payload.len,
    });
    defer lz4_too_small.deinit();
    // Without a content-size field, `expected_output_len` is the only exact-size
    // contract. Exceeding it during frame preflight should be diagnosed as a
    // logical size mismatch rather than a generic decoded-buffer limit.
    try std.testing.expectError(error.SizeMismatch, lz4_too_small.step(lz4_stream, lz4_output[0..0]));
    try std.testing.expectEqualSlices(u8, "SizeMismatch", lz4_too_small.diagnostics().last_error_name);
    try std.testing.expectEqualSlices(u8, "frame", lz4_too_small.diagnostics().last_error_phase_name);

    var lz4_too_large = Lz4NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = lz4_payload.len + 1,
        .max_decoded_buffer_len = lz4_payload.len + 1,
    });
    defer lz4_too_large.deinit();
    const lz4_initial = try lz4_too_large.step(lz4_stream, lz4_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_output, lz4_initial.status);
    const lz4_pending = try lz4_too_large.step("", &lz4_output);
    try std.testing.expectEqual(StepResult.Status.need_input, lz4_pending.status);
    try std.testing.expectEqualSlices(u8, lz4_payload, &lz4_output);
    try std.testing.expectError(error.SizeMismatch, lz4_too_large.finish());
    try std.testing.expectEqualSlices(u8, "SizeMismatch", lz4_too_large.diagnostics().last_error_name);
    try std.testing.expectEqualSlices(u8, "output", lz4_too_large.diagnostics().last_error_phase_name);

    const zstd_payload = "root-zstd-nosize-size-mismatch";
    const zstd_skip = try zstdEncodeSkippableFrameAlloc(std.testing.allocator, 15, "root-zstd-mismatch-skip");
    defer std.testing.allocator.free(zstd_skip);
    const zstd_frame = try zstdEncodeNativeFrameWithOptionsAlloc(std.testing.allocator, zstd_payload, .{
        .include_content_size = false,
        .selection = .literal_only,
        .content_checksum = true,
    });
    defer std.testing.allocator.free(zstd_frame.frame);
    const zstd_stream = try std.mem.concat(std.testing.allocator, u8, &.{ zstd_skip, zstd_frame.frame });
    defer std.testing.allocator.free(zstd_stream);
    var zstd_output: [zstd_payload.len]u8 = undefined;

    var zstd_too_small = ZstdNativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = zstd_payload.len - 1,
        .max_decoded_buffer_len = zstd_payload.len,
    });
    defer zstd_too_small.deinit();
    try std.testing.expectError(error.SizeMismatch, zstd_too_small.step(zstd_stream, zstd_output[0..0]));
    try std.testing.expectEqualSlices(u8, "SizeMismatch", zstd_too_small.diagnostics().last_error_name);
    try std.testing.expectEqualSlices(u8, "frame", zstd_too_small.diagnostics().last_error_phase_name);

    var zstd_too_large = ZstdNativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = zstd_payload.len + 1,
        .max_decoded_buffer_len = zstd_payload.len + 1,
    });
    defer zstd_too_large.deinit();
    const zstd_initial = try zstd_too_large.step(zstd_stream, zstd_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_output, zstd_initial.status);
    const zstd_pending = try zstd_too_large.step("", &zstd_output);
    try std.testing.expectEqual(StepResult.Status.need_input, zstd_pending.status);
    try std.testing.expectEqualSlices(u8, zstd_payload, &zstd_output);
    try std.testing.expectError(error.SizeMismatch, zstd_too_large.finish());
    try std.testing.expectEqualSlices(u8, "SizeMismatch", zstd_too_large.diagnostics().last_error_name);
    try std.testing.expectEqualSlices(u8, "output", zstd_too_large.diagnostics().last_error_phase_name);
}

test "root native incremental reset recovers after extra input size mismatch" {
    const lz4_payload = "root-lz4-extra-input-reset" ** 3;
    const lz4_frame = try lz4EncodeNativeFrameWithOptionsAlloc(std.testing.allocator, lz4_payload, .{
        .content_checksum = false,
        .include_content_size = true,
        .block_checksum = true,
    });
    defer std.testing.allocator.free(lz4_frame);
    var lz4_decoder = Lz4NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = lz4_payload.len,
        .max_decoded_buffer_len = lz4_payload.len,
    });
    defer lz4_decoder.deinit();
    var lz4_output: [lz4_payload.len]u8 = undefined;
    _ = try lz4_decoder.step(lz4_frame, lz4_output[0..0]);
    const lz4_done = try lz4_decoder.step("", &lz4_output);
    try std.testing.expectEqual(StepResult.Status.done, lz4_done.status);
    try std.testing.expectError(error.SizeMismatch, lz4_decoder.step(lz4_frame[0..1], lz4_output[0..0]));
    try std.testing.expectEqualSlices(u8, "SizeMismatch", lz4_decoder.diagnostics().last_error_name);
    try std.testing.expectEqualSlices(u8, "frame", lz4_decoder.diagnostics().last_error_phase_name);
    lz4_decoder.reset();
    const lz4_reused_initial = try lz4_decoder.step(lz4_frame, lz4_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_output, lz4_reused_initial.status);
    const lz4_reused_done = try lz4_decoder.step("", &lz4_output);
    try std.testing.expectEqual(StepResult.Status.done, lz4_reused_done.status);
    try std.testing.expectEqualSlices(u8, lz4_payload, &lz4_output);

    const zstd_payload = "root-zstd-extra-input-reset" ** 3;
    const zstd_frame = try zstdEncodeNativeFrameWithOptionsAlloc(std.testing.allocator, zstd_payload, .{
        .selection = .literal_only,
        .content_checksum = false,
    });
    defer std.testing.allocator.free(zstd_frame.frame);
    var zstd_decoder = ZstdNativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = zstd_payload.len,
        .max_decoded_buffer_len = zstd_payload.len,
    });
    defer zstd_decoder.deinit();
    var zstd_output: [zstd_payload.len]u8 = undefined;
    _ = try zstd_decoder.step(zstd_frame.frame, zstd_output[0..0]);
    const zstd_done = try zstd_decoder.step("", &zstd_output);
    try std.testing.expectEqual(StepResult.Status.done, zstd_done.status);
    try std.testing.expectError(error.SizeMismatch, zstd_decoder.step(zstd_frame.frame[0..1], zstd_output[0..0]));
    try std.testing.expectEqualSlices(u8, "SizeMismatch", zstd_decoder.diagnostics().last_error_name);
    try std.testing.expectEqualSlices(u8, "frame", zstd_decoder.diagnostics().last_error_phase_name);
    zstd_decoder.reset();
    const zstd_reused_initial = try zstd_decoder.step(zstd_frame.frame, zstd_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_output, zstd_reused_initial.status);
    const zstd_reused_done = try zstd_decoder.step("", &zstd_output);
    try std.testing.expectEqual(StepResult.Status.done, zstd_reused_done.status);
    try std.testing.expectEqualSlices(u8, zstd_payload, &zstd_output);
}

test "root native incremental finish reports direct-output not drained" {
    const lz4_payload = "root-lz4-finish-output-too-small" ** 4;
    const lz4_frame = try lz4EncodeNativeFrameWithOptionsAlloc(std.testing.allocator, lz4_payload, .{
        .content_checksum = false,
        .include_content_size = true,
        .block_checksum = true,
    });
    defer std.testing.allocator.free(lz4_frame);
    var lz4_decoder = Lz4NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = lz4_payload.len,
        .max_decoded_buffer_len = lz4_payload.len,
    });
    defer lz4_decoder.deinit();
    var lz4_output: [1]u8 = undefined;
    const lz4_initial = try lz4_decoder.step(lz4_frame, lz4_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_output, lz4_initial.status);
    try std.testing.expectEqualSlices(u8, "direct_output", lz4_decoder.diagnostics().phase_name);
    try std.testing.expectError(error.OutputTooSmall, lz4_decoder.finish());
    try std.testing.expectEqualSlices(u8, "OutputTooSmall", lz4_decoder.diagnostics().last_error_name);
    try std.testing.expectEqualSlices(u8, "direct_output", lz4_decoder.diagnostics().last_error_phase_name);
    lz4_decoder.reset();
    try std.testing.expectEqualSlices(u8, "", lz4_decoder.diagnostics().last_error_name);
    var lz4_recovered_output: [lz4_payload.len]u8 = undefined;
    const lz4_recovered_initial = try lz4_decoder.step(lz4_frame, lz4_recovered_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_output, lz4_recovered_initial.status);
    const lz4_recovered_done = try lz4_decoder.step("", &lz4_recovered_output);
    try std.testing.expectEqual(StepResult.Status.done, lz4_recovered_done.status);
    try std.testing.expectEqualSlices(u8, lz4_payload, &lz4_recovered_output);

    var lz4_partial_decoder = Lz4NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = lz4_payload.len,
        .max_decoded_buffer_len = lz4_payload.len,
    });
    defer lz4_partial_decoder.deinit();
    var lz4_partial_output: [lz4_payload.len]u8 = undefined;
    _ = try lz4_partial_decoder.step(lz4_frame, lz4_partial_output[0..0]);
    const lz4_partial = try lz4_partial_decoder.step("", lz4_partial_output[0..5]);
    try std.testing.expectEqual(StepResult.Status.need_output, lz4_partial.status);
    try std.testing.expectEqual(@as(usize, 5), lz4_partial.progress.output_written);
    try std.testing.expectError(error.OutputTooSmall, lz4_partial_decoder.finish());
    try std.testing.expectEqualSlices(u8, "OutputTooSmall", lz4_partial_decoder.diagnostics().last_error_name);
    try std.testing.expectEqualSlices(u8, "direct_output", lz4_partial_decoder.diagnostics().last_error_phase_name);

    const zstd_payload = "root-zstd-finish-output-too-small" ** 4;
    const zstd_frame = try zstdEncodeNativeFrameWithOptionsAlloc(std.testing.allocator, zstd_payload, .{
        .selection = .literal_only,
        .content_checksum = true,
    });
    defer std.testing.allocator.free(zstd_frame.frame);
    var zstd_decoder = ZstdNativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = zstd_payload.len,
        .max_decoded_buffer_len = zstd_payload.len,
    });
    defer zstd_decoder.deinit();
    var zstd_output: [1]u8 = undefined;
    const zstd_initial = try zstd_decoder.step(zstd_frame.frame, zstd_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_output, zstd_initial.status);
    try std.testing.expectEqualSlices(u8, "direct_output", zstd_decoder.diagnostics().phase_name);
    try std.testing.expectError(error.OutputTooSmall, zstd_decoder.finish());
    try std.testing.expectEqualSlices(u8, "OutputTooSmall", zstd_decoder.diagnostics().last_error_name);
    try std.testing.expectEqualSlices(u8, "direct_output", zstd_decoder.diagnostics().last_error_phase_name);
    zstd_decoder.reset();
    try std.testing.expectEqualSlices(u8, "", zstd_decoder.diagnostics().last_error_name);
    var zstd_recovered_output: [zstd_payload.len]u8 = undefined;
    const zstd_recovered_initial = try zstd_decoder.step(zstd_frame.frame, zstd_recovered_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_output, zstd_recovered_initial.status);
    const zstd_recovered_done = try zstd_decoder.step("", &zstd_recovered_output);
    try std.testing.expectEqual(StepResult.Status.done, zstd_recovered_done.status);
    try std.testing.expectEqualSlices(u8, zstd_payload, &zstd_recovered_output);

    var zstd_partial_decoder = ZstdNativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = zstd_payload.len,
        .max_decoded_buffer_len = zstd_payload.len,
    });
    defer zstd_partial_decoder.deinit();
    var zstd_partial_output: [zstd_payload.len]u8 = undefined;
    _ = try zstd_partial_decoder.step(zstd_frame.frame, zstd_partial_output[0..0]);
    const zstd_partial = try zstd_partial_decoder.step("", zstd_partial_output[0..5]);
    try std.testing.expectEqual(StepResult.Status.need_output, zstd_partial.status);
    try std.testing.expectEqual(@as(usize, 5), zstd_partial.progress.output_written);
    try std.testing.expectError(error.OutputTooSmall, zstd_partial_decoder.finish());
    try std.testing.expectEqualSlices(u8, "OutputTooSmall", zstd_partial_decoder.diagnostics().last_error_name);
    try std.testing.expectEqualSlices(u8, "direct_output", zstd_partial_decoder.diagnostics().last_error_phase_name);
}

test "root native incremental direct-output waits across split block boundaries" {
    const lz4_payload = ("root-lz4-direct-boundary-" ** 8) ** 8;
    const lz4_frame = try lz4EncodeNativeFrameWithOptionsAlloc(std.testing.allocator, lz4_payload, .{
        .content_checksum = false,
        .include_content_size = true,
        .block_checksum = true,
    });
    defer std.testing.allocator.free(lz4_frame);
    const lz4_first_block = (try lz4InspectNativeFrameFirstBlock(lz4_frame)) orelse return error.CorruptFrame;
    try std.testing.expect(lz4_first_block.is_compressed);
    try std.testing.expect(lz4_first_block.block_checksum_offset != null);
    try std.testing.expect(lz4_first_block.payload_len > 2);

    var lz4_decoder = Lz4NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = lz4_payload.len,
        .max_decoded_buffer_len = lz4_payload.len,
    });
    defer lz4_decoder.deinit();
    var lz4_output: [lz4_payload.len]u8 = undefined;

    // Feed the frame in pieces that stop inside the LZ4 block header, payload,
    // and block checksum. The current incremental facade starts direct output
    // only after a whole frame is available, so these boundaries should remain
    // resumable in the public frame phase rather than attempting an early decode.
    const lz4_block_header_split = lz4_first_block.header_offset + 2;
    const lz4_payload_split = lz4_first_block.payload_offset + 1;
    const lz4_checksum_split = lz4_first_block.block_checksum_offset.? + 2;
    const lz4_first = try lz4_decoder.step(lz4_frame[0..lz4_block_header_split], lz4_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_input, lz4_first.status);
    try std.testing.expectEqual(lz4_block_header_split, lz4_first.progress.input_read);
    try std.testing.expectEqualSlices(u8, "frame", lz4_decoder.diagnostics().phase_name);
    const lz4_second = try lz4_decoder.step(lz4_frame[lz4_block_header_split..lz4_payload_split], lz4_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_input, lz4_second.status);
    try std.testing.expectEqual(lz4_payload_split - lz4_block_header_split, lz4_second.progress.input_read);
    try std.testing.expectEqualSlices(u8, "frame", lz4_decoder.diagnostics().phase_name);
    const lz4_third = try lz4_decoder.step(lz4_frame[lz4_payload_split..lz4_checksum_split], lz4_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_input, lz4_third.status);
    try std.testing.expectEqual(lz4_checksum_split - lz4_payload_split, lz4_third.progress.input_read);
    try std.testing.expectEqualSlices(u8, "frame", lz4_decoder.diagnostics().phase_name);
    const lz4_ready = try lz4_decoder.step(lz4_frame[lz4_checksum_split..], lz4_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_output, lz4_ready.status);
    try std.testing.expectEqual(lz4_frame.len - lz4_checksum_split, lz4_ready.progress.input_read);
    try std.testing.expectEqualSlices(u8, "direct_output", lz4_decoder.diagnostics().phase_name);
    const lz4_done = try lz4_decoder.step("", &lz4_output);
    try std.testing.expectEqual(StepResult.Status.done, lz4_done.status);
    try std.testing.expectEqualSlices(u8, lz4_payload, &lz4_output);
    try lz4_decoder.finish();

    const zstd_payload = ("root-zstd-direct-boundary-" ** 8) ** 8;
    const zstd_frame = try zstdEncodeNativeFrameWithOptionsAlloc(std.testing.allocator, zstd_payload, .{
        .selection = .literal_only,
        .content_checksum = true,
    });
    defer std.testing.allocator.free(zstd_frame.frame);
    const zstd_first_block = try zstdInspectNativeFrameFirstBlock(zstd_frame.frame);
    try std.testing.expectEqual(ZstdNativeBlockType.compressed, zstd_first_block.block_type);
    try std.testing.expect(zstd_first_block.last);
    try std.testing.expect(zstd_first_block.payload_len > 2);

    var zstd_decoder = ZstdNativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = zstd_payload.len,
        .max_decoded_buffer_len = zstd_payload.len,
    });
    defer zstd_decoder.deinit();
    var zstd_output: [zstd_payload.len]u8 = undefined;

    // Zstd has a 3-byte block header and a frame-level content checksum. Split
    // both, plus the compressed payload, to ensure the same resumable frame
    // accounting that the LZ4 path guarantees above.
    const zstd_block_header_split = zstd_first_block.header_offset + 1;
    const zstd_payload_split = zstd_first_block.payload_offset + 1;
    const zstd_checksum_split = zstd_first_block.next_header_offset + 2;
    const zstd_first = try zstd_decoder.step(zstd_frame.frame[0..zstd_block_header_split], zstd_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_input, zstd_first.status);
    try std.testing.expectEqual(zstd_block_header_split, zstd_first.progress.input_read);
    try std.testing.expectEqualSlices(u8, "frame", zstd_decoder.diagnostics().phase_name);
    const zstd_second = try zstd_decoder.step(zstd_frame.frame[zstd_block_header_split..zstd_payload_split], zstd_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_input, zstd_second.status);
    try std.testing.expectEqual(zstd_payload_split - zstd_block_header_split, zstd_second.progress.input_read);
    try std.testing.expectEqualSlices(u8, "frame", zstd_decoder.diagnostics().phase_name);
    const zstd_third = try zstd_decoder.step(zstd_frame.frame[zstd_payload_split..zstd_checksum_split], zstd_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_input, zstd_third.status);
    try std.testing.expectEqual(zstd_checksum_split - zstd_payload_split, zstd_third.progress.input_read);
    try std.testing.expectEqualSlices(u8, "frame", zstd_decoder.diagnostics().phase_name);
    const zstd_ready = try zstd_decoder.step(zstd_frame.frame[zstd_checksum_split..], zstd_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_output, zstd_ready.status);
    try std.testing.expectEqual(zstd_frame.frame.len - zstd_checksum_split, zstd_ready.progress.input_read);
    try std.testing.expectEqualSlices(u8, "direct_output", zstd_decoder.diagnostics().phase_name);
    const zstd_done = try zstd_decoder.step("", &zstd_output);
    try std.testing.expectEqual(StepResult.Status.done, zstd_done.status);
    try std.testing.expectEqualSlices(u8, zstd_payload, &zstd_output);
    try zstd_decoder.finish();
}

test "root native incremental direct-output reports checksum mismatches" {
    const lz4_payload = ("root-lz4-direct-checksum-" ** 8) ** 8;
    const lz4_block_frame = try lz4EncodeNativeFrameWithOptionsAlloc(std.testing.allocator, lz4_payload, .{
        .content_checksum = false,
        .include_content_size = true,
        .block_checksum = true,
    });
    defer std.testing.allocator.free(lz4_block_frame);
    const lz4_first_block = (try lz4InspectNativeFrameFirstBlock(lz4_block_frame)) orelse return error.CorruptFrame;
    try std.testing.expect(lz4_first_block.block_checksum_offset != null);
    var lz4_bad_block = try std.testing.allocator.dupe(u8, lz4_block_frame);
    defer std.testing.allocator.free(lz4_bad_block);
    lz4_bad_block[lz4_first_block.block_checksum_offset.?] ^= 0x01;

    var lz4_block_decoder = Lz4NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = lz4_payload.len,
        .max_decoded_buffer_len = lz4_payload.len,
    });
    defer lz4_block_decoder.deinit();
    var lz4_output: [lz4_payload.len]u8 = undefined;
    try std.testing.expectError(error.ChecksumMismatch, lz4_block_decoder.step(lz4_bad_block, lz4_output[0..0]));
    try std.testing.expectEqualSlices(u8, "ChecksumMismatch", lz4_block_decoder.diagnostics().last_error_name);
    try std.testing.expectEqualSlices(u8, "frame", lz4_block_decoder.diagnostics().last_error_phase_name);

    const lz4_content_frame = try lz4EncodeNativeFrameWithOptionsAlloc(std.testing.allocator, lz4_payload, .{
        .content_checksum = true,
        .include_content_size = false,
        .block_checksum = true,
    });
    defer std.testing.allocator.free(lz4_content_frame);
    var lz4_bad_content = try std.testing.allocator.dupe(u8, lz4_content_frame);
    defer std.testing.allocator.free(lz4_bad_content);
    lz4_bad_content[lz4_bad_content.len - 1] ^= 0x01;
    var lz4_content_decoder = Lz4NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = lz4_payload.len,
        .max_decoded_buffer_len = lz4_payload.len,
    });
    defer lz4_content_decoder.deinit();
    const lz4_ready = try lz4_content_decoder.step(lz4_bad_content, lz4_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_output, lz4_ready.status);
    try std.testing.expectEqualSlices(u8, "direct_output", lz4_content_decoder.diagnostics().phase_name);
    try std.testing.expectError(error.ChecksumMismatch, lz4_content_decoder.step("", &lz4_output));
    try std.testing.expectEqualSlices(u8, "ChecksumMismatch", lz4_content_decoder.diagnostics().last_error_name);
    try std.testing.expectEqualSlices(u8, "direct_output", lz4_content_decoder.diagnostics().last_error_phase_name);

    const zstd_payload = ("root-zstd-direct-checksum-" ** 8) ** 8;
    const zstd_frame = try zstdEncodeNativeFrameWithOptionsAlloc(std.testing.allocator, zstd_payload, .{
        .include_content_size = false,
        .selection = .literal_only,
        .content_checksum = true,
    });
    defer std.testing.allocator.free(zstd_frame.frame);
    var zstd_bad_content = try std.testing.allocator.dupe(u8, zstd_frame.frame);
    defer std.testing.allocator.free(zstd_bad_content);
    zstd_bad_content[zstd_bad_content.len - 1] ^= 0x01;

    var zstd_decoder = ZstdNativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = zstd_payload.len,
        .max_decoded_buffer_len = zstd_payload.len,
    });
    defer zstd_decoder.deinit();
    var zstd_output: [zstd_payload.len]u8 = undefined;
    const zstd_ready = try zstd_decoder.step(zstd_bad_content, zstd_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_output, zstd_ready.status);
    try std.testing.expectEqualSlices(u8, "direct_output", zstd_decoder.diagnostics().phase_name);
    try std.testing.expectError(error.ChecksumMismatch, zstd_decoder.step("", &zstd_output));
    try std.testing.expectEqualSlices(u8, "ChecksumMismatch", zstd_decoder.diagnostics().last_error_name);
    try std.testing.expectEqualSlices(u8, "direct_output", zstd_decoder.diagnostics().last_error_phase_name);
}

test "root native incremental direct-output advances across exact frame output boundaries" {
    const lz4_first_payload = "root-lz4-boundary-first-" ** 4;
    const lz4_second_payload = "root-lz4-boundary-second-" ** 5;
    const lz4_options: Lz4NativeFrameOptions = .{
        .content_checksum = false,
        .include_content_size = true,
        .block_checksum = true,
    };
    const lz4_first = try lz4EncodeNativeFrameWithOptionsAlloc(std.testing.allocator, lz4_first_payload, lz4_options);
    defer std.testing.allocator.free(lz4_first);
    const lz4_second = try lz4EncodeNativeFrameWithOptionsAlloc(std.testing.allocator, lz4_second_payload, lz4_options);
    defer std.testing.allocator.free(lz4_second);
    const lz4_skip = try lz4EncodeSkippableFrameAlloc(std.testing.allocator, 7, "root-lz4-exact-boundary");
    defer std.testing.allocator.free(lz4_skip);
    const lz4_stream = try std.mem.concat(std.testing.allocator, u8, &.{ lz4_first, lz4_skip, lz4_second });
    defer std.testing.allocator.free(lz4_stream);
    const lz4_expected = lz4_first_payload ++ lz4_second_payload;

    var lz4_decoder = Lz4NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = lz4_expected.len,
        .max_decoded_buffer_len = @max(lz4_first_payload.len, lz4_second_payload.len),
    });
    defer lz4_decoder.deinit();
    var lz4_output: [lz4_expected.len]u8 = undefined;
    const lz4_initial = try lz4_decoder.step(lz4_stream, lz4_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_output, lz4_initial.status);
    try std.testing.expectEqual(lz4_stream.len, lz4_initial.progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), lz4_initial.progress.output_written);
    try std.testing.expectEqualSlices(u8, "direct_output", lz4_decoder.diagnostics().phase_name);

    const lz4_first_out = try lz4_decoder.step("", lz4_output[0..lz4_first_payload.len]);
    try std.testing.expectEqual(StepResult.Status.need_output, lz4_first_out.status);
    try std.testing.expectEqual(lz4_first_payload.len, lz4_first_out.progress.output_written);
    try std.testing.expectEqualSlices(u8, lz4_first_payload, lz4_output[0..lz4_first_payload.len]);
    try std.testing.expectEqualSlices(u8, "direct_output", lz4_decoder.diagnostics().phase_name);

    const lz4_done = try lz4_decoder.step("", lz4_output[lz4_first_payload.len..]);
    try std.testing.expectEqual(StepResult.Status.done, lz4_done.status);
    try std.testing.expectEqual(lz4_second_payload.len, lz4_done.progress.output_written);
    try std.testing.expectEqualSlices(u8, lz4_expected, &lz4_output);
    try lz4_decoder.finish();

    const zstd_first_payload = "root-zstd-boundary-first-" ** 4;
    const zstd_second_payload = "root-zstd-boundary-second-" ** 5;
    const zstd_options: ZstdNativeFrameOptions = .{
        .selection = .literal_only,
        .content_checksum = false,
    };
    const zstd_first = try zstdEncodeNativeFrameWithOptionsAlloc(std.testing.allocator, zstd_first_payload, zstd_options);
    defer std.testing.allocator.free(zstd_first.frame);
    const zstd_second = try zstdEncodeNativeFrameWithOptionsAlloc(std.testing.allocator, zstd_second_payload, zstd_options);
    defer std.testing.allocator.free(zstd_second.frame);
    const zstd_skip = try zstdEncodeSkippableFrameAlloc(std.testing.allocator, 7, "root-zstd-exact-boundary");
    defer std.testing.allocator.free(zstd_skip);
    const zstd_stream = try std.mem.concat(std.testing.allocator, u8, &.{ zstd_first.frame, zstd_skip, zstd_second.frame });
    defer std.testing.allocator.free(zstd_stream);
    const zstd_expected = zstd_first_payload ++ zstd_second_payload;

    var zstd_decoder = ZstdNativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = zstd_expected.len,
        .max_decoded_buffer_len = @max(zstd_first_payload.len, zstd_second_payload.len),
    });
    defer zstd_decoder.deinit();
    var zstd_output: [zstd_expected.len]u8 = undefined;
    const zstd_initial = try zstd_decoder.step(zstd_stream, zstd_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_output, zstd_initial.status);
    try std.testing.expectEqual(zstd_stream.len, zstd_initial.progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), zstd_initial.progress.output_written);
    try std.testing.expectEqualSlices(u8, "direct_output", zstd_decoder.diagnostics().phase_name);

    const zstd_first_out = try zstd_decoder.step("", zstd_output[0..zstd_first_payload.len]);
    try std.testing.expectEqual(StepResult.Status.need_output, zstd_first_out.status);
    try std.testing.expectEqual(zstd_first_payload.len, zstd_first_out.progress.output_written);
    try std.testing.expectEqualSlices(u8, zstd_first_payload, zstd_output[0..zstd_first_payload.len]);
    try std.testing.expectEqualSlices(u8, "direct_output", zstd_decoder.diagnostics().phase_name);

    const zstd_done = try zstd_decoder.step("", zstd_output[zstd_first_payload.len..]);
    try std.testing.expectEqual(StepResult.Status.done, zstd_done.status);
    try std.testing.expectEqual(zstd_second_payload.len, zstd_done.progress.output_written);
    try std.testing.expectEqualSlices(u8, zstd_expected, &zstd_output);
    try zstd_decoder.finish();
}

test "root native incremental direct-output reports checksum mismatches in later members" {
    const lz4_first_payload = "root-lz4-later-checksum-first-" ** 4;
    const lz4_second_payload = ("root-lz4-later-checksum-second-" ** 8) ** 4;
    const lz4_options: Lz4NativeFrameOptions = .{
        .content_checksum = true,
        .include_content_size = true,
        .block_checksum = false,
    };
    const lz4_first = try lz4EncodeNativeFrameWithOptionsAlloc(std.testing.allocator, lz4_first_payload, lz4_options);
    defer std.testing.allocator.free(lz4_first);
    const lz4_second = try lz4EncodeNativeFrameWithOptionsAlloc(std.testing.allocator, lz4_second_payload, lz4_options);
    defer std.testing.allocator.free(lz4_second);
    const lz4_second_block = (try lz4InspectNativeFrameFirstBlock(lz4_second)) orelse return error.CorruptFrame;
    try std.testing.expect(lz4_second_block.is_compressed);
    var lz4_bad_second = try std.testing.allocator.dupe(u8, lz4_second);
    defer std.testing.allocator.free(lz4_bad_second);
    lz4_bad_second[lz4_bad_second.len - 1] ^= 0x01;
    const lz4_skip = try lz4EncodeSkippableFrameAlloc(std.testing.allocator, 8, "root-lz4-later-checksum");
    defer std.testing.allocator.free(lz4_skip);
    const lz4_stream = try std.mem.concat(std.testing.allocator, u8, &.{ lz4_first, lz4_skip, lz4_bad_second });
    defer std.testing.allocator.free(lz4_stream);
    const lz4_expected = lz4_first_payload ++ lz4_second_payload;

    var lz4_decoder = Lz4NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = lz4_expected.len,
        .max_decoded_buffer_len = @max(lz4_first_payload.len, lz4_second_payload.len),
    });
    defer lz4_decoder.deinit();
    var lz4_output: [lz4_expected.len]u8 = undefined;
    const lz4_initial = try lz4_decoder.step(lz4_stream, lz4_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_output, lz4_initial.status);

    const lz4_first_out = try lz4_decoder.step("", lz4_output[0..lz4_first_payload.len]);
    try std.testing.expectEqual(StepResult.Status.need_output, lz4_first_out.status);
    try std.testing.expectEqualSlices(u8, lz4_first_payload, lz4_output[0..lz4_first_payload.len]);
    try std.testing.expectEqualSlices(u8, "direct_output", lz4_decoder.diagnostics().phase_name);
    try std.testing.expectError(error.ChecksumMismatch, lz4_decoder.step("", lz4_output[lz4_first_payload.len..]));
    try std.testing.expectEqualSlices(u8, lz4_second_payload, lz4_output[lz4_first_payload.len..]);
    try std.testing.expectEqualSlices(u8, "ChecksumMismatch", lz4_decoder.diagnostics().last_error_name);
    try std.testing.expectEqualSlices(u8, "direct_output", lz4_decoder.diagnostics().last_error_phase_name);

    const zstd_first_payload = "root-zstd-later-checksum-first-" ** 4;
    const zstd_second_payload = ("root-zstd-later-checksum-second-" ** 8) ** 4;
    const zstd_options: ZstdNativeFrameOptions = .{
        .selection = .literal_only,
        .content_checksum = true,
    };
    const zstd_first = try zstdEncodeNativeFrameWithOptionsAlloc(std.testing.allocator, zstd_first_payload, zstd_options);
    defer std.testing.allocator.free(zstd_first.frame);
    const zstd_second = try zstdEncodeNativeFrameWithOptionsAlloc(std.testing.allocator, zstd_second_payload, zstd_options);
    defer std.testing.allocator.free(zstd_second.frame);
    const zstd_second_block = try zstdInspectNativeFrameFirstBlock(zstd_second.frame);
    try std.testing.expectEqual(ZstdNativeBlockType.compressed, zstd_second_block.block_type);
    var zstd_bad_second = try std.testing.allocator.dupe(u8, zstd_second.frame);
    defer std.testing.allocator.free(zstd_bad_second);
    zstd_bad_second[zstd_bad_second.len - 1] ^= 0x01;
    const zstd_skip = try zstdEncodeSkippableFrameAlloc(std.testing.allocator, 8, "root-zstd-later-checksum");
    defer std.testing.allocator.free(zstd_skip);
    const zstd_stream = try std.mem.concat(std.testing.allocator, u8, &.{ zstd_first.frame, zstd_skip, zstd_bad_second });
    defer std.testing.allocator.free(zstd_stream);
    const zstd_expected = zstd_first_payload ++ zstd_second_payload;

    var zstd_decoder = ZstdNativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = zstd_expected.len,
        .max_decoded_buffer_len = @max(zstd_first_payload.len, zstd_second_payload.len),
    });
    defer zstd_decoder.deinit();
    var zstd_output: [zstd_expected.len]u8 = undefined;
    const zstd_initial = try zstd_decoder.step(zstd_stream, zstd_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_output, zstd_initial.status);

    const zstd_first_out = try zstd_decoder.step("", zstd_output[0..zstd_first_payload.len]);
    try std.testing.expectEqual(StepResult.Status.need_output, zstd_first_out.status);
    try std.testing.expectEqualSlices(u8, zstd_first_payload, zstd_output[0..zstd_first_payload.len]);
    try std.testing.expectEqualSlices(u8, "direct_output", zstd_decoder.diagnostics().phase_name);
    try std.testing.expectError(error.ChecksumMismatch, zstd_decoder.step("", zstd_output[zstd_first_payload.len..]));
    try std.testing.expectEqualSlices(u8, zstd_second_payload, zstd_output[zstd_first_payload.len..]);
    try std.testing.expectEqualSlices(u8, "ChecksumMismatch", zstd_decoder.diagnostics().last_error_name);
    try std.testing.expectEqualSlices(u8, "direct_output", zstd_decoder.diagnostics().last_error_phase_name);
}

test "root native incremental direct-output paths round trip" {
    var lz4_payload: [4096]u8 = undefined;
    var state: u32 = 0x1020_3040;
    for (&lz4_payload) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    const lz4_frame = try lz4EncodeNativeFrameWithOptionsAlloc(std.testing.allocator, &lz4_payload, .{
        .content_checksum = false,
        .block_checksum = false,
        .block_mode = .independent,
        .block_size_id = .max64kb,
    });
    defer std.testing.allocator.free(lz4_frame);
    var lz4_decoder = Lz4NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = lz4_payload.len,
        .max_decoded_buffer_len = lz4_payload.len,
    });
    defer lz4_decoder.deinit();
    var lz4_output: [lz4_payload.len]u8 = undefined;
    const lz4_initial = try lz4_decoder.step(lz4_frame, lz4_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_output, lz4_initial.status);
    try std.testing.expectEqualSlices(u8, "direct_output", lz4_decoder.diagnostics().phase_name);
    const lz4_done = try lz4_decoder.step("", &lz4_output);
    try std.testing.expectEqual(StepResult.Status.done, lz4_done.status);
    try std.testing.expectEqualSlices(u8, &lz4_payload, &lz4_output);
    try lz4_decoder.finish();

    var zstd_payload: [3000]u8 = undefined;
    state = 0x5566_7788;
    for (&zstd_payload) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    const zstd_frame = try zstdEncodeNativeFrameWithOptionsAlloc(std.testing.allocator, &zstd_payload, .{
        .selection = .raw_or_rle,
        .content_checksum = true,
        .block_size_max = 1024,
    });
    defer std.testing.allocator.free(zstd_frame.frame);
    var zstd_decoder = ZstdNativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = zstd_payload.len,
        .max_decoded_buffer_len = zstd_payload.len,
    });
    defer zstd_decoder.deinit();
    var zstd_output: [zstd_payload.len]u8 = undefined;
    const zstd_initial = try zstd_decoder.step(zstd_frame.frame, zstd_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_output, zstd_initial.status);
    try std.testing.expectEqualSlices(u8, "direct_output", zstd_decoder.diagnostics().phase_name);
    var zstd_written: usize = 0;
    while (true) {
        const end = @min(zstd_output.len, zstd_written + 257);
        const result = try zstd_decoder.step("", zstd_output[zstd_written..end]);
        zstd_written += result.progress.output_written;
        if (result.status == .done) break;
        try std.testing.expectEqual(StepResult.Status.need_output, result.status);
    }
    try std.testing.expectEqual(zstd_payload.len, zstd_written);
    try std.testing.expectEqualSlices(u8, &zstd_payload, &zstd_output);
}

test "root native no-size incremental direct-output paths round trip" {
    const lz4_payload = ("lz4-root-nosize-direct" ** 8) ** 32;
    const lz4_frame = try lz4EncodeNativeFrameWithOptionsAlloc(std.testing.allocator, lz4_payload, .{
        .include_content_size = false,
        .content_checksum = true,
        .block_checksum = true,
        .block_mode = .independent,
        .block_size_id = .max64kb,
    });
    defer std.testing.allocator.free(lz4_frame);
    const lz4_header = try lz4InspectNativeFrameHeader(lz4_frame);
    try std.testing.expectEqual(@as(?u64, null), lz4_header.expected_content_size);
    const lz4_first_block = (try lz4InspectNativeFrameFirstBlock(lz4_frame)) orelse return error.CorruptFrame;
    try std.testing.expect(lz4_first_block.is_compressed);

    var lz4_decoder = Lz4NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = lz4_payload.len,
    });
    defer lz4_decoder.deinit();
    var lz4_output: [lz4_payload.len]u8 = undefined;
    const lz4_initial = try lz4_decoder.step(lz4_frame, lz4_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_output, lz4_initial.status);
    try std.testing.expectEqualSlices(u8, "direct_output", lz4_decoder.diagnostics().phase_name);
    try std.testing.expectEqual(@as(?usize, lz4_payload.len), lz4_decoder.snapshot().decoded_len);
    const lz4_done = try lz4_decoder.step("", &lz4_output);
    try std.testing.expectEqual(StepResult.Status.done, lz4_done.status);
    try std.testing.expectEqualSlices(u8, lz4_payload, &lz4_output);

    const zstd_payload = ("zstd-root-nosize-direct" ** 8) ** 32;
    const zstd_frame = try zstdEncodeNativeFrameWithOptionsAlloc(std.testing.allocator, zstd_payload, .{
        .include_content_size = false,
        .selection = .literal_only,
        .content_checksum = true,
    });
    defer std.testing.allocator.free(zstd_frame.frame);
    const zstd_header = try zstdInspectNativeFrameHeader(zstd_frame.frame);
    try std.testing.expectEqual(@as(?u64, null), zstd_header.content_size);
    const zstd_first_block = try zstdInspectNativeFrameFirstBlock(zstd_frame.frame);
    try std.testing.expectEqual(ZstdNativeBlockType.compressed, zstd_first_block.block_type);

    var zstd_decoder = ZstdNativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = zstd_payload.len,
    });
    defer zstd_decoder.deinit();
    var zstd_output: [zstd_payload.len]u8 = undefined;
    const zstd_initial = try zstd_decoder.step(zstd_frame.frame, zstd_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_output, zstd_initial.status);
    try std.testing.expectEqualSlices(u8, "direct_output", zstd_decoder.diagnostics().phase_name);
    try std.testing.expectEqual(@as(?usize, zstd_payload.len), zstd_decoder.snapshot().decoded_len);
    const zstd_done = try zstd_decoder.step("", &zstd_output);
    try std.testing.expectEqual(StepResult.Status.done, zstd_done.status);
    try std.testing.expectEqualSlices(u8, zstd_payload, &zstd_output);
}

test "root native no-size dictionary direct-output paths round trip" {
    const lz4_dict = Lz4NativeDictionary.init(0x5151, "abcdefghijklmnop");
    const lz4_payload = "abcdefghijklmnop-nosize-tail";
    const lz4_frame = try lz4EncodeNativeFrameWithDictionaryAlloc(std.testing.allocator, lz4_payload, .{
        .include_content_size = false,
        .content_checksum = true,
        .block_checksum = true,
    }, lz4_dict);
    defer std.testing.allocator.free(lz4_frame);
    const lz4_header = try lz4InspectNativeFrameHeader(lz4_frame);
    try std.testing.expectEqual(@as(?u64, null), lz4_header.expected_content_size);
    try std.testing.expectEqual(@as(?u32, lz4_dict.id), lz4_header.dictionary_id);
    const lz4_first_block = (try lz4InspectNativeFrameFirstBlock(lz4_frame)) orelse return error.CorruptFrame;
    try std.testing.expect(lz4_first_block.is_compressed);

    var lz4_decoder = Lz4NativeIncrementalFrameDecoder.initWithDictionaryAndOptions(std.testing.allocator, lz4_dict, .{
        .expected_output_len = lz4_payload.len,
    });
    defer lz4_decoder.deinit();
    var lz4_output: [lz4_payload.len]u8 = undefined;
    const lz4_initial = try lz4_decoder.step(lz4_frame, lz4_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_output, lz4_initial.status);
    try std.testing.expectEqualSlices(u8, "direct_output", lz4_decoder.diagnostics().phase_name);
    try std.testing.expectEqual(@as(?usize, lz4_payload.len), lz4_decoder.snapshot().decoded_len);
    const lz4_done = try lz4_decoder.step("", &lz4_output);
    try std.testing.expectEqual(StepResult.Status.done, lz4_done.status);
    try std.testing.expectEqualSlices(u8, lz4_payload, &lz4_output);
    var lz4_corrupt = try std.testing.allocator.dupe(u8, lz4_frame);
    defer std.testing.allocator.free(lz4_corrupt);
    lz4_corrupt[lz4_corrupt.len - 1] ^= 0x01;
    lz4_decoder.reset();
    const lz4_corrupt_initial = try lz4_decoder.step(lz4_corrupt, lz4_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_output, lz4_corrupt_initial.status);
    try std.testing.expectError(error.ChecksumMismatch, lz4_decoder.step("", &lz4_output));
    try std.testing.expectEqualSlices(u8, "ChecksumMismatch", lz4_decoder.diagnostics().last_error_name);
    lz4_decoder.reset();
    const lz4_reused_initial = try lz4_decoder.step(lz4_frame, lz4_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_output, lz4_reused_initial.status);
    const lz4_reused_done = try lz4_decoder.step("", &lz4_output);
    try std.testing.expectEqual(StepResult.Status.done, lz4_reused_done.status);
    try std.testing.expectEqualSlices(u8, lz4_payload, &lz4_output);

    var lz4_missing = Lz4NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = lz4_payload.len,
    });
    defer lz4_missing.deinit();
    try std.testing.expectError(error.NeedDictionary, lz4_missing.step(lz4_frame, lz4_output[0..0]));
    try std.testing.expectEqualSlices(u8, "NeedDictionary", lz4_missing.diagnostics().last_error_name);

    const zstd_dict = ZstdNativeDictionary.init(0x6161, "abcdefghijklmnop");
    const zstd_payload = "pfx-abcdefghijklmnop-nosize-tail";
    const zstd_frame = try zstdEncodeNativeFrameWithDictionaryAlloc(std.testing.allocator, zstd_payload, .{
        .include_content_size = false,
        .selection = .literal_only,
        .content_checksum = true,
    }, zstd_dict);
    defer std.testing.allocator.free(zstd_frame.frame);
    const zstd_header = try zstdInspectNativeFrameHeader(zstd_frame.frame);
    try std.testing.expectEqual(@as(?u64, null), zstd_header.content_size);
    try std.testing.expectEqual(zstd_dict.id, zstd_header.dictionary_id);
    const zstd_first_block = try zstdInspectNativeFrameFirstBlock(zstd_frame.frame);
    try std.testing.expectEqual(ZstdNativeBlockType.compressed, zstd_first_block.block_type);

    var zstd_decoder = ZstdNativeIncrementalFrameDecoder.initWithDictionaryAndOptions(std.testing.allocator, zstd_dict, .{
        .expected_output_len = zstd_payload.len,
    });
    defer zstd_decoder.deinit();
    var zstd_output: [zstd_payload.len]u8 = undefined;
    const zstd_initial = try zstd_decoder.step(zstd_frame.frame, zstd_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_output, zstd_initial.status);
    try std.testing.expectEqualSlices(u8, "direct_output", zstd_decoder.diagnostics().phase_name);
    try std.testing.expectEqual(@as(?usize, zstd_payload.len), zstd_decoder.snapshot().decoded_len);
    const zstd_done = try zstd_decoder.step("", &zstd_output);
    try std.testing.expectEqual(StepResult.Status.done, zstd_done.status);
    try std.testing.expectEqualSlices(u8, zstd_payload, &zstd_output);
    var zstd_corrupt = try std.testing.allocator.dupe(u8, zstd_frame.frame);
    defer std.testing.allocator.free(zstd_corrupt);
    zstd_corrupt[zstd_corrupt.len - 1] ^= 0x01;
    zstd_decoder.reset();
    const zstd_corrupt_initial = try zstd_decoder.step(zstd_corrupt, zstd_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_output, zstd_corrupt_initial.status);
    try std.testing.expectError(error.ChecksumMismatch, zstd_decoder.step("", &zstd_output));
    try std.testing.expectEqualSlices(u8, "ChecksumMismatch", zstd_decoder.diagnostics().last_error_name);
    zstd_decoder.reset();
    const zstd_reused_initial = try zstd_decoder.step(zstd_frame.frame, zstd_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_output, zstd_reused_initial.status);
    const zstd_reused_done = try zstd_decoder.step("", &zstd_output);
    try std.testing.expectEqual(StepResult.Status.done, zstd_reused_done.status);
    try std.testing.expectEqualSlices(u8, zstd_payload, &zstd_output);

    var zstd_missing = ZstdNativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = zstd_payload.len,
    });
    defer zstd_missing.deinit();
    try std.testing.expectError(error.NeedDictionary, zstd_missing.step(zstd_frame.frame, zstd_output[0..0]));
    try std.testing.expectEqualSlices(u8, "NeedDictionary", zstd_missing.diagnostics().last_error_name);
}

test "root native no-size dictionary-set direct-output paths round trip" {
    const lz4_first_dict = Lz4NativeDictionary.init(0x5251, "abcdefghijklmnop");
    const lz4_second_dict = Lz4NativeDictionary.init(0x5252, "QRSTUVWXYZabcdef");
    const lz4_dictionary_set = Lz4NativeDictionarySet.init(&.{ lz4_first_dict, lz4_second_dict });
    const lz4_first_payload = "abcdefghijklmnop-nosize-one";
    const lz4_second_payload = "QRSTUVWXYZabcdef-nosize-two";
    const lz4_options: Lz4NativeFrameOptions = .{
        .include_content_size = false,
        .content_checksum = true,
        .block_checksum = true,
    };
    const lz4_first = try lz4EncodeNativeFrameWithDictionaryAlloc(std.testing.allocator, lz4_first_payload, lz4_options, lz4_first_dict);
    defer std.testing.allocator.free(lz4_first);
    const lz4_second = try lz4EncodeNativeFrameWithDictionaryAlloc(std.testing.allocator, lz4_second_payload, lz4_options, lz4_second_dict);
    defer std.testing.allocator.free(lz4_second);
    const lz4_skip = try lz4EncodeSkippableFrameAlloc(std.testing.allocator, 4, "root-nosize-set-lz4");
    defer std.testing.allocator.free(lz4_skip);
    var lz4_stream: std.ArrayList(u8) = .empty;
    defer lz4_stream.deinit(std.testing.allocator);
    try lz4_stream.appendSlice(std.testing.allocator, lz4_first);
    try lz4_stream.appendSlice(std.testing.allocator, lz4_skip);
    try lz4_stream.appendSlice(std.testing.allocator, lz4_second);
    const lz4_expected = lz4_first_payload ++ lz4_second_payload;

    var lz4_decoder = Lz4NativeIncrementalFrameDecoder.initWithDictionarySetAndOptions(std.testing.allocator, lz4_dictionary_set, .{
        .expected_output_len = lz4_expected.len,
        .max_decoded_buffer_len = @max(lz4_first_payload.len, lz4_second_payload.len),
    });
    defer lz4_decoder.deinit();
    var lz4_output: [lz4_expected.len]u8 = undefined;
    const lz4_initial = try lz4_decoder.step(lz4_stream.items, lz4_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_output, lz4_initial.status);
    try std.testing.expectEqualSlices(u8, "direct_output", lz4_decoder.diagnostics().phase_name);
    try std.testing.expectEqual(@as(?usize, lz4_first_payload.len), lz4_decoder.snapshot().decoded_len);
    const lz4_done = try lz4_decoder.step("", &lz4_output);
    try std.testing.expectEqual(StepResult.Status.done, lz4_done.status);
    try std.testing.expectEqualSlices(u8, lz4_expected, &lz4_output);
    try lz4_decoder.finish();
    var lz4_corrupt_stream = try std.testing.allocator.dupe(u8, lz4_stream.items);
    defer std.testing.allocator.free(lz4_corrupt_stream);
    lz4_corrupt_stream[lz4_corrupt_stream.len - 1] ^= 0x01;
    lz4_decoder.reset();
    const lz4_corrupt_initial = try lz4_decoder.step(lz4_corrupt_stream, lz4_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_output, lz4_corrupt_initial.status);
    try std.testing.expectError(error.ChecksumMismatch, lz4_decoder.step("", &lz4_output));
    try std.testing.expectEqualSlices(u8, "ChecksumMismatch", lz4_decoder.diagnostics().last_error_name);
    lz4_decoder.reset();
    const lz4_reused_initial = try lz4_decoder.step(lz4_stream.items, lz4_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_output, lz4_reused_initial.status);
    const lz4_reused_done = try lz4_decoder.step("", &lz4_output);
    try std.testing.expectEqual(StepResult.Status.done, lz4_reused_done.status);
    try std.testing.expectEqualSlices(u8, lz4_expected, &lz4_output);

    const zstd_first_dict = ZstdNativeDictionary.init(0x6261, "abcdefghijklmnop");
    const zstd_second_dict = ZstdNativeDictionary.init(0x6262, "QRSTUVWXYZabcdef");
    const zstd_dictionary_set = ZstdNativeDictionarySet.init(&.{ zstd_first_dict, zstd_second_dict });
    const zstd_first_payload = "pfx-abcdefghijklmnop-nosize-one";
    const zstd_second_payload = "pfx-QRSTUVWXYZabcdef-nosize-two";
    const zstd_options: ZstdNativeFrameOptions = .{
        .include_content_size = false,
        .selection = .literal_only,
        .content_checksum = true,
    };
    const zstd_first = try zstdEncodeNativeFrameWithDictionaryAlloc(std.testing.allocator, zstd_first_payload, zstd_options, zstd_first_dict);
    defer std.testing.allocator.free(zstd_first.frame);
    const zstd_second = try zstdEncodeNativeFrameWithDictionaryAlloc(std.testing.allocator, zstd_second_payload, zstd_options, zstd_second_dict);
    defer std.testing.allocator.free(zstd_second.frame);
    const zstd_skip = try zstdEncodeSkippableFrameAlloc(std.testing.allocator, 4, "root-nosize-set-zstd");
    defer std.testing.allocator.free(zstd_skip);
    var zstd_stream: std.ArrayList(u8) = .empty;
    defer zstd_stream.deinit(std.testing.allocator);
    try zstd_stream.appendSlice(std.testing.allocator, zstd_first.frame);
    try zstd_stream.appendSlice(std.testing.allocator, zstd_skip);
    try zstd_stream.appendSlice(std.testing.allocator, zstd_second.frame);
    const zstd_expected = zstd_first_payload ++ zstd_second_payload;

    var zstd_decoder = ZstdNativeIncrementalFrameDecoder.initWithDictionarySetAndOptions(std.testing.allocator, zstd_dictionary_set, .{
        .expected_output_len = zstd_expected.len,
        .max_decoded_buffer_len = @max(zstd_first_payload.len, zstd_second_payload.len),
    });
    defer zstd_decoder.deinit();
    var zstd_output: [zstd_expected.len]u8 = undefined;
    const zstd_initial = try zstd_decoder.step(zstd_stream.items, zstd_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_output, zstd_initial.status);
    try std.testing.expectEqualSlices(u8, "direct_output", zstd_decoder.diagnostics().phase_name);
    try std.testing.expectEqual(@as(?usize, zstd_first_payload.len), zstd_decoder.snapshot().decoded_len);
    const zstd_done = try zstd_decoder.step("", &zstd_output);
    try std.testing.expectEqual(StepResult.Status.done, zstd_done.status);
    try std.testing.expectEqualSlices(u8, zstd_expected, &zstd_output);
    try zstd_decoder.finish();
    var zstd_corrupt_stream = try std.testing.allocator.dupe(u8, zstd_stream.items);
    defer std.testing.allocator.free(zstd_corrupt_stream);
    zstd_corrupt_stream[zstd_corrupt_stream.len - 1] ^= 0x01;
    zstd_decoder.reset();
    const zstd_corrupt_initial = try zstd_decoder.step(zstd_corrupt_stream, zstd_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_output, zstd_corrupt_initial.status);
    try std.testing.expectError(error.ChecksumMismatch, zstd_decoder.step("", &zstd_output));
    try std.testing.expectEqualSlices(u8, "ChecksumMismatch", zstd_decoder.diagnostics().last_error_name);
    zstd_decoder.reset();
    const zstd_reused_initial = try zstd_decoder.step(zstd_stream.items, zstd_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_output, zstd_reused_initial.status);
    const zstd_reused_done = try zstd_decoder.step("", &zstd_output);
    try std.testing.expectEqual(StepResult.Status.done, zstd_reused_done.status);
    try std.testing.expectEqualSlices(u8, zstd_expected, &zstd_output);
}

test "root native no-size dictionary-set streams diagnose expected size mismatches" {
    const lz4_first_dict = Lz4NativeDictionary.init(0x5351, "abcdefghijklmnop");
    const lz4_second_dict = Lz4NativeDictionary.init(0x5352, "QRSTUVWXYZabcdef");
    const lz4_dictionary_set = Lz4NativeDictionarySet.init(&.{ lz4_first_dict, lz4_second_dict });
    const lz4_first_payload = "abcdefghijklmnop-nosize-mismatch-one";
    const lz4_second_payload = "QRSTUVWXYZabcdef-nosize-mismatch-two";
    const lz4_options: Lz4NativeFrameOptions = .{
        .include_content_size = false,
        .content_checksum = true,
        .block_checksum = true,
    };
    const lz4_first = try lz4EncodeNativeFrameWithDictionaryAlloc(std.testing.allocator, lz4_first_payload, lz4_options, lz4_first_dict);
    defer std.testing.allocator.free(lz4_first);
    const lz4_second = try lz4EncodeNativeFrameWithDictionaryAlloc(std.testing.allocator, lz4_second_payload, lz4_options, lz4_second_dict);
    defer std.testing.allocator.free(lz4_second);
    const lz4_skip = try lz4EncodeSkippableFrameAlloc(std.testing.allocator, 5, "root-nosize-set-mismatch-lz4");
    defer std.testing.allocator.free(lz4_skip);
    var lz4_stream: std.ArrayList(u8) = .empty;
    defer lz4_stream.deinit(std.testing.allocator);
    try lz4_stream.appendSlice(std.testing.allocator, lz4_first);
    try lz4_stream.appendSlice(std.testing.allocator, lz4_skip);
    try lz4_stream.appendSlice(std.testing.allocator, lz4_second);
    const lz4_expected = lz4_first_payload ++ lz4_second_payload;
    var lz4_output: [lz4_expected.len]u8 = undefined;

    var lz4_too_small = Lz4NativeIncrementalFrameDecoder.initWithDictionarySetAndOptions(std.testing.allocator, lz4_dictionary_set, .{
        .expected_output_len = lz4_expected.len - 1,
        .max_decoded_buffer_len = @max(lz4_first_payload.len, lz4_second_payload.len),
    });
    defer lz4_too_small.deinit();
    // The first frame fits, then the second dictionary-selected no-size frame
    // proves the caller's total expected length is one byte short. This checks
    // the cumulative expected-output contract across concatenated members.
    const lz4_initial = try lz4_too_small.step(lz4_stream.items, lz4_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_output, lz4_initial.status);
    try std.testing.expectError(error.SizeMismatch, lz4_too_small.step("", &lz4_output));
    try std.testing.expectEqualSlices(u8, "SizeMismatch", lz4_too_small.diagnostics().last_error_name);
    try std.testing.expectEqualSlices(u8, "frame", lz4_too_small.diagnostics().last_error_phase_name);

    var lz4_too_large = Lz4NativeIncrementalFrameDecoder.initWithDictionarySetAndOptions(std.testing.allocator, lz4_dictionary_set, .{
        .expected_output_len = lz4_expected.len + 1,
        .max_decoded_buffer_len = @max(lz4_first_payload.len, lz4_second_payload.len),
    });
    defer lz4_too_large.deinit();
    const lz4_large_initial = try lz4_too_large.step(lz4_stream.items, lz4_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_output, lz4_large_initial.status);
    const lz4_pending = try lz4_too_large.step("", &lz4_output);
    try std.testing.expectEqual(StepResult.Status.need_input, lz4_pending.status);
    try std.testing.expectEqualSlices(u8, lz4_expected, &lz4_output);
    try std.testing.expectError(error.SizeMismatch, lz4_too_large.finish());
    try std.testing.expectEqualSlices(u8, "SizeMismatch", lz4_too_large.diagnostics().last_error_name);
    try std.testing.expectEqualSlices(u8, "output", lz4_too_large.diagnostics().last_error_phase_name);

    const zstd_first_dict = ZstdNativeDictionary.init(0x6361, "abcdefghijklmnop");
    const zstd_second_dict = ZstdNativeDictionary.init(0x6362, "QRSTUVWXYZabcdef");
    const zstd_dictionary_set = ZstdNativeDictionarySet.init(&.{ zstd_first_dict, zstd_second_dict });
    const zstd_first_payload = "pfx-abcdefghijklmnop-nosize-mismatch-one";
    const zstd_second_payload = "pfx-QRSTUVWXYZabcdef-nosize-mismatch-two";
    const zstd_options: ZstdNativeFrameOptions = .{
        .include_content_size = false,
        .selection = .literal_only,
        .content_checksum = true,
    };
    const zstd_first = try zstdEncodeNativeFrameWithDictionaryAlloc(std.testing.allocator, zstd_first_payload, zstd_options, zstd_first_dict);
    defer std.testing.allocator.free(zstd_first.frame);
    const zstd_second = try zstdEncodeNativeFrameWithDictionaryAlloc(std.testing.allocator, zstd_second_payload, zstd_options, zstd_second_dict);
    defer std.testing.allocator.free(zstd_second.frame);
    const zstd_skip = try zstdEncodeSkippableFrameAlloc(std.testing.allocator, 5, "root-nosize-set-mismatch-zstd");
    defer std.testing.allocator.free(zstd_skip);
    var zstd_stream: std.ArrayList(u8) = .empty;
    defer zstd_stream.deinit(std.testing.allocator);
    try zstd_stream.appendSlice(std.testing.allocator, zstd_first.frame);
    try zstd_stream.appendSlice(std.testing.allocator, zstd_skip);
    try zstd_stream.appendSlice(std.testing.allocator, zstd_second.frame);
    const zstd_expected = zstd_first_payload ++ zstd_second_payload;
    var zstd_output: [zstd_expected.len]u8 = undefined;

    var zstd_too_small = ZstdNativeIncrementalFrameDecoder.initWithDictionarySetAndOptions(std.testing.allocator, zstd_dictionary_set, .{
        .expected_output_len = zstd_expected.len - 1,
        .max_decoded_buffer_len = @max(zstd_first_payload.len, zstd_second_payload.len),
    });
    defer zstd_too_small.deinit();
    const zstd_initial = try zstd_too_small.step(zstd_stream.items, zstd_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_output, zstd_initial.status);
    try std.testing.expectError(error.SizeMismatch, zstd_too_small.step("", &zstd_output));
    try std.testing.expectEqualSlices(u8, "SizeMismatch", zstd_too_small.diagnostics().last_error_name);
    try std.testing.expectEqualSlices(u8, "frame", zstd_too_small.diagnostics().last_error_phase_name);

    var zstd_too_large = ZstdNativeIncrementalFrameDecoder.initWithDictionarySetAndOptions(std.testing.allocator, zstd_dictionary_set, .{
        .expected_output_len = zstd_expected.len + 1,
        .max_decoded_buffer_len = @max(zstd_first_payload.len, zstd_second_payload.len),
    });
    defer zstd_too_large.deinit();
    const zstd_large_initial = try zstd_too_large.step(zstd_stream.items, zstd_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_output, zstd_large_initial.status);
    const zstd_pending = try zstd_too_large.step("", &zstd_output);
    try std.testing.expectEqual(StepResult.Status.need_input, zstd_pending.status);
    try std.testing.expectEqualSlices(u8, zstd_expected, &zstd_output);
    try std.testing.expectError(error.SizeMismatch, zstd_too_large.finish());
    try std.testing.expectEqualSlices(u8, "SizeMismatch", zstd_too_large.diagnostics().last_error_name);
    try std.testing.expectEqualSlices(u8, "output", zstd_too_large.diagnostics().last_error_phase_name);
}

test "root native no-size dictionary-set streams diagnose missing later dictionaries" {
    const lz4_first_dict = Lz4NativeDictionary.init(0x5451, "abcdefghijklmnop");
    const lz4_second_dict = Lz4NativeDictionary.init(0x5452, "QRSTUVWXYZabcdef");
    const lz4_full_set = Lz4NativeDictionarySet.init(&.{ lz4_first_dict, lz4_second_dict });
    const lz4_missing_set = Lz4NativeDictionarySet.init(&.{lz4_first_dict});
    const lz4_first_payload = "abcdefghijklmnop-nosize-present-one";
    const lz4_second_payload = "QRSTUVWXYZabcdef-nosize-missing-two";
    const lz4_options: Lz4NativeFrameOptions = .{
        .include_content_size = false,
        .content_checksum = true,
        .block_checksum = true,
    };
    const lz4_first = try lz4EncodeNativeFrameWithDictionarySetAlloc(std.testing.allocator, lz4_first_payload, lz4_options, lz4_full_set, lz4_first_dict.id);
    defer std.testing.allocator.free(lz4_first);
    const lz4_second = try lz4EncodeNativeFrameWithDictionarySetAlloc(std.testing.allocator, lz4_second_payload, lz4_options, lz4_full_set, lz4_second_dict.id);
    defer std.testing.allocator.free(lz4_second);
    const lz4_skip = try lz4EncodeSkippableFrameAlloc(std.testing.allocator, 6, "root-nosize-set-missing-lz4");
    defer std.testing.allocator.free(lz4_skip);
    var lz4_stream: std.ArrayList(u8) = .empty;
    defer lz4_stream.deinit(std.testing.allocator);
    try lz4_stream.appendSlice(std.testing.allocator, lz4_first);
    try lz4_stream.appendSlice(std.testing.allocator, lz4_skip);
    try lz4_stream.appendSlice(std.testing.allocator, lz4_second);
    const lz4_expected = lz4_first_payload ++ lz4_second_payload;
    var lz4_output: [lz4_expected.len]u8 = undefined;

    var lz4_missing = Lz4NativeIncrementalFrameDecoder.initWithDictionarySetAndOptions(std.testing.allocator, lz4_missing_set, .{
        .expected_output_len = lz4_expected.len,
        .max_decoded_buffer_len = @max(lz4_first_payload.len, lz4_second_payload.len),
    });
    defer lz4_missing.deinit();
    // The first dictionary is available, so callers can drain the first no-size
    // frame. The missing dictionary for the later frame must then be reported in
    // the frame phase without being masked by the still-unsatisfied expected
    // output length.
    const lz4_initial = try lz4_missing.step(lz4_stream.items, lz4_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_output, lz4_initial.status);
    const lz4_split = 5;
    const lz4_first_out = try lz4_missing.step("", lz4_output[0..lz4_split]);
    try std.testing.expectEqual(StepResult.Status.need_output, lz4_first_out.status);
    try std.testing.expectError(error.NeedDictionary, lz4_missing.step("", lz4_output[lz4_split..]));
    try std.testing.expectEqualSlices(u8, lz4_first_payload, lz4_output[0..lz4_first_payload.len]);
    try std.testing.expectEqualSlices(u8, "NeedDictionary", lz4_missing.diagnostics().last_error_name);
    try std.testing.expectEqualSlices(u8, "frame", lz4_missing.diagnostics().last_error_phase_name);

    const zstd_first_dict = ZstdNativeDictionary.init(0x6461, "abcdefghijklmnop");
    const zstd_second_dict = ZstdNativeDictionary.init(0x6462, "QRSTUVWXYZabcdef");
    const zstd_full_set = ZstdNativeDictionarySet.init(&.{ zstd_first_dict, zstd_second_dict });
    const zstd_missing_set = ZstdNativeDictionarySet.init(&.{zstd_first_dict});
    const zstd_first_payload = "pfx-abcdefghijklmnop-nosize-present-one";
    const zstd_second_payload = "pfx-QRSTUVWXYZabcdef-nosize-missing-two";
    const zstd_options: ZstdNativeFrameOptions = .{
        .include_content_size = false,
        .selection = .literal_only,
        .content_checksum = true,
    };
    const zstd_first = try zstdEncodeNativeFrameWithDictionarySetAlloc(std.testing.allocator, zstd_first_payload, zstd_options, zstd_full_set, zstd_first_dict.id);
    defer std.testing.allocator.free(zstd_first.frame);
    const zstd_second = try zstdEncodeNativeFrameWithDictionarySetAlloc(std.testing.allocator, zstd_second_payload, zstd_options, zstd_full_set, zstd_second_dict.id);
    defer std.testing.allocator.free(zstd_second.frame);
    const zstd_skip = try zstdEncodeSkippableFrameAlloc(std.testing.allocator, 6, "root-nosize-set-missing-zstd");
    defer std.testing.allocator.free(zstd_skip);
    var zstd_stream: std.ArrayList(u8) = .empty;
    defer zstd_stream.deinit(std.testing.allocator);
    try zstd_stream.appendSlice(std.testing.allocator, zstd_first.frame);
    try zstd_stream.appendSlice(std.testing.allocator, zstd_skip);
    try zstd_stream.appendSlice(std.testing.allocator, zstd_second.frame);
    const zstd_expected = zstd_first_payload ++ zstd_second_payload;
    var zstd_output: [zstd_expected.len]u8 = undefined;

    var zstd_missing = ZstdNativeIncrementalFrameDecoder.initWithDictionarySetAndOptions(std.testing.allocator, zstd_missing_set, .{
        .expected_output_len = zstd_expected.len,
        .max_decoded_buffer_len = @max(zstd_first_payload.len, zstd_second_payload.len),
    });
    defer zstd_missing.deinit();
    const zstd_initial = try zstd_missing.step(zstd_stream.items, zstd_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_output, zstd_initial.status);
    const zstd_split = 5;
    const zstd_first_out = try zstd_missing.step("", zstd_output[0..zstd_split]);
    try std.testing.expectEqual(StepResult.Status.need_output, zstd_first_out.status);
    try std.testing.expectError(error.NeedDictionary, zstd_missing.step("", zstd_output[zstd_split..]));
    try std.testing.expectEqualSlices(u8, zstd_first_payload, zstd_output[0..zstd_first_payload.len]);
    try std.testing.expectEqualSlices(u8, "NeedDictionary", zstd_missing.diagnostics().last_error_name);
    try std.testing.expectEqualSlices(u8, "frame", zstd_missing.diagnostics().last_error_phase_name);
}

test "root lz4 linked direct-output switches to cursor for small output" {
    var lz4_payload: [64 * 1024 + 4096]u8 = undefined;
    var state: u32 = 0x1234_abcd;
    for (lz4_payload[0 .. 64 * 1024]) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    @memcpy(lz4_payload[64 * 1024 ..], lz4_payload[60 * 1024 .. 64 * 1024]);
    const encoded = try lz4EncodeNativeFrameWithOptionsAlloc(std.testing.allocator, &lz4_payload, .{
        .content_checksum = false,
        .block_checksum = true,
        .block_mode = .linked,
        .block_size_id = .max64kb,
    });
    defer std.testing.allocator.free(encoded);
    const first_block = (try lz4InspectNativeFrameFirstBlock(encoded)) orelse return error.CorruptFrame;
    const second_block = (try lz4InspectNativeFrameBlockAt(encoded, first_block.next_header_offset)) orelse return error.CorruptFrame;
    try std.testing.expect(!first_block.is_compressed);
    try std.testing.expect(second_block.is_compressed);

    var decoder = Lz4NativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = lz4_payload.len,
        .max_decoded_buffer_len = lz4_payload.len,
    });
    defer decoder.deinit();
    var output: [lz4_payload.len]u8 = undefined;
    const initial = try decoder.step(encoded, output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_output, initial.status);
    try std.testing.expectEqualSlices(u8, "direct_output", decoder.diagnostics().phase_name);
    const first = try decoder.step("", output[0 .. 64 * 1024]);
    try std.testing.expectEqual(StepResult.Status.need_output, first.status);
    try std.testing.expectEqual(@as(usize, 64 * 1024), first.progress.output_written);
    try std.testing.expectEqual(@as(usize, 0), decoder.decoded_scratch.items.len);
    const partial = try decoder.step("", output[64 * 1024 ..][0..127]);
    try std.testing.expectEqual(StepResult.Status.need_output, partial.status);
    try std.testing.expectEqual(@as(usize, 127), partial.progress.output_written);
    try std.testing.expectEqual(lz4_payload.len, decoder.snapshot().decoded_len.?);
    try std.testing.expect(decoder.isBlockStreaming());
    try std.testing.expect(decoder.isCompressedBlockStreaming());
    try std.testing.expectEqual(@as(usize, 0), decoder.decodedBufferedBytes());
    try std.testing.expectEqual(@as(usize, 0), decoder.decodedBufferCapacity());
    const done = try decoder.step("", output[64 * 1024 + 127 ..]);
    try std.testing.expectEqual(StepResult.Status.done, done.status);
    try std.testing.expectEqualSlices(u8, &lz4_payload, &output);
}

test "root zstd multi-block direct-output switches for small output" {
    const payload = "a" ** 264;
    const encoded = try zstdEncodeNativeFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .selection = .literal_only,
        .content_checksum = true,
        .block_size_max = payload.len / 2,
    });
    defer std.testing.allocator.free(encoded.frame);
    const first_block = try zstdInspectNativeFrameFirstBlock(encoded.frame);
    try std.testing.expectEqual(ZstdNativeBlockType.compressed, first_block.block_type);
    const second_block = try zstdInspectNativeFrameBlockAt(encoded.frame, first_block.next_header_offset);
    try std.testing.expectEqual(ZstdNativeBlockType.compressed, second_block.block_type);
    try std.testing.expect(second_block.last);

    var decoder = ZstdNativeIncrementalFrameDecoder.initWithOptions(std.testing.allocator, .{
        .expected_output_len = payload.len,
        .max_decoded_buffer_len = payload.len,
    });
    defer decoder.deinit();
    var output: [payload.len]u8 = undefined;
    const initial = try decoder.step(encoded.frame, output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_output, initial.status);
    try std.testing.expectEqualSlices(u8, "direct_output", decoder.diagnostics().phase_name);
    try std.testing.expectEqual(@as(usize, 0), decoder.decoded_scratch.items.len);
    const partial = try decoder.step("", output[0..17]);
    try std.testing.expectEqual(StepResult.Status.need_output, partial.status);
    try std.testing.expectEqual(@as(usize, 17), partial.progress.output_written);
    try std.testing.expectEqual(payload.len, decoder.snapshot().decoded_len.?);
    try std.testing.expectEqual(@as(usize, 0), decoder.decodedBufferedBytes());
    try std.testing.expectEqual(@as(usize, 0), decoder.decodedBufferCapacity());
    const done = try decoder.step("", output[17..]);
    try std.testing.expectEqual(StepResult.Status.done, done.status);
    try std.testing.expectEqualSlices(u8, payload, &output);
}

test "root native dictionary direct-output handles small output" {
    const lz4_dict = Lz4NativeDictionary.init(0x5351, "abcdefghijklmnop");
    const lz4_payload = "abcdefghijklmnop-small-output-tail";
    const lz4_frame = try lz4EncodeNativeFrameWithDictionaryAlloc(std.testing.allocator, lz4_payload, .{
        .content_checksum = false,
        .block_checksum = true,
    }, lz4_dict);
    defer std.testing.allocator.free(lz4_frame);
    const lz4_first_block = (try lz4InspectNativeFrameFirstBlock(lz4_frame)) orelse return error.CorruptFrame;
    try std.testing.expect(lz4_first_block.is_compressed);

    var lz4_decoder = Lz4NativeIncrementalFrameDecoder.initWithDictionaryAndOptions(std.testing.allocator, lz4_dict, .{
        .expected_output_len = lz4_payload.len,
        .max_decoded_buffer_len = lz4_payload.len,
    });
    defer lz4_decoder.deinit();
    var lz4_output: [lz4_payload.len]u8 = undefined;
    const lz4_initial = try lz4_decoder.step(lz4_frame, lz4_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_output, lz4_initial.status);
    try std.testing.expectEqualSlices(u8, "direct_output", lz4_decoder.diagnostics().phase_name);
    const lz4_partial = try lz4_decoder.step("", lz4_output[0..5]);
    try std.testing.expectEqual(StepResult.Status.need_output, lz4_partial.status);
    try std.testing.expectEqual(@as(usize, 5), lz4_partial.progress.output_written);
    try std.testing.expectEqual(lz4_payload.len, lz4_decoder.snapshot().decoded_len.?);
    try std.testing.expect(lz4_decoder.isBlockStreaming());
    try std.testing.expect(lz4_decoder.isCompressedBlockStreaming());
    try std.testing.expectEqual(@as(usize, 0), lz4_decoder.decodedBufferedBytes());
    try std.testing.expectEqual(@as(usize, 0), lz4_decoder.decodedBufferCapacity());
    const lz4_done = try lz4_decoder.step("", lz4_output[5..]);
    try std.testing.expectEqual(StepResult.Status.done, lz4_done.status);
    try std.testing.expectEqualSlices(u8, lz4_payload, &lz4_output);

    const zstd_dict = ZstdNativeDictionary.init(0x6361, "abcdefghijklmnop");
    const zstd_payload = "pfx-abcdefghijklmnop-small-output-tail";
    const zstd_frame = try zstdEncodeNativeFrameWithDictionaryAlloc(std.testing.allocator, zstd_payload, .{
        .selection = .literal_only,
        .content_checksum = false,
    }, zstd_dict);
    defer std.testing.allocator.free(zstd_frame.frame);
    const zstd_first_block = try zstdInspectNativeFrameFirstBlock(zstd_frame.frame);
    try std.testing.expectEqual(ZstdNativeBlockType.compressed, zstd_first_block.block_type);

    var zstd_decoder = ZstdNativeIncrementalFrameDecoder.initWithDictionaryAndOptions(std.testing.allocator, zstd_dict, .{
        .expected_output_len = zstd_payload.len,
        .max_decoded_buffer_len = zstd_payload.len,
    });
    defer zstd_decoder.deinit();
    var zstd_output: [zstd_payload.len]u8 = undefined;
    const zstd_initial = try zstd_decoder.step(zstd_frame.frame, zstd_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_output, zstd_initial.status);
    try std.testing.expectEqualSlices(u8, "direct_output", zstd_decoder.diagnostics().phase_name);
    const zstd_partial = try zstd_decoder.step("", zstd_output[0..5]);
    try std.testing.expectEqual(StepResult.Status.need_output, zstd_partial.status);
    try std.testing.expectEqual(@as(usize, 5), zstd_partial.progress.output_written);
    try std.testing.expectEqual(zstd_payload.len, zstd_decoder.snapshot().decoded_len.?);
    try std.testing.expectEqual(@as(usize, 0), zstd_decoder.decodedBufferedBytes());
    try std.testing.expectEqual(@as(usize, 0), zstd_decoder.decodedBufferCapacity());
    const zstd_done = try zstd_decoder.step("", zstd_output[5..]);
    try std.testing.expectEqual(StepResult.Status.done, zstd_done.status);
    try std.testing.expectEqualSlices(u8, zstd_payload, &zstd_output);
}

test "root native dictionary-set direct-output handles small output" {
    const lz4_dict = Lz4NativeDictionary.init(0x5451, "abcdefghijklmnop");
    const lz4_other_dict = Lz4NativeDictionary.init(0x5452, "QRSTUVWXYZabcdef");
    const lz4_dictionary_set = Lz4NativeDictionarySet.init(&.{ lz4_dict, lz4_other_dict });
    const lz4_payload = "abcdefghijklmnop-set-small-output-tail";
    const lz4_frame = try lz4EncodeNativeFrameWithDictionaryAlloc(std.testing.allocator, lz4_payload, .{
        .content_checksum = false,
        .block_checksum = true,
    }, lz4_dict);
    defer std.testing.allocator.free(lz4_frame);
    const lz4_first_block = (try lz4InspectNativeFrameFirstBlock(lz4_frame)) orelse return error.CorruptFrame;
    try std.testing.expect(lz4_first_block.is_compressed);

    var lz4_decoder = Lz4NativeIncrementalFrameDecoder.initWithDictionarySetAndOptions(std.testing.allocator, lz4_dictionary_set, .{
        .expected_output_len = lz4_payload.len,
        .max_decoded_buffer_len = lz4_payload.len,
    });
    defer lz4_decoder.deinit();
    var lz4_output: [lz4_payload.len]u8 = undefined;
    const lz4_initial = try lz4_decoder.step(lz4_frame, lz4_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_output, lz4_initial.status);
    try std.testing.expectEqualSlices(u8, "direct_output", lz4_decoder.diagnostics().phase_name);
    const lz4_partial = try lz4_decoder.step("", lz4_output[0..5]);
    try std.testing.expectEqual(StepResult.Status.need_output, lz4_partial.status);
    try std.testing.expectEqual(@as(usize, 5), lz4_partial.progress.output_written);
    try std.testing.expectEqual(lz4_payload.len, lz4_decoder.snapshot().decoded_len.?);
    try std.testing.expect(lz4_decoder.isBlockStreaming());
    try std.testing.expect(lz4_decoder.isCompressedBlockStreaming());
    try std.testing.expectEqual(@as(usize, 0), lz4_decoder.decodedBufferedBytes());
    try std.testing.expectEqual(@as(usize, 0), lz4_decoder.decodedBufferCapacity());
    const lz4_done = try lz4_decoder.step("", lz4_output[5..]);
    try std.testing.expectEqual(StepResult.Status.done, lz4_done.status);
    try std.testing.expectEqualSlices(u8, lz4_payload, &lz4_output);

    const zstd_dict = ZstdNativeDictionary.init(0x6461, "abcdefghijklmnop");
    const zstd_other_dict = ZstdNativeDictionary.init(0x6462, "QRSTUVWXYZabcdef");
    const zstd_dictionary_set = ZstdNativeDictionarySet.init(&.{ zstd_dict, zstd_other_dict });
    const zstd_payload = "pfx-abcdefghijklmnop-set-small-output-tail";
    const zstd_frame = try zstdEncodeNativeFrameWithDictionaryAlloc(std.testing.allocator, zstd_payload, .{
        .selection = .literal_only,
        .content_checksum = false,
    }, zstd_dict);
    defer std.testing.allocator.free(zstd_frame.frame);
    const zstd_first_block = try zstdInspectNativeFrameFirstBlock(zstd_frame.frame);
    try std.testing.expectEqual(ZstdNativeBlockType.compressed, zstd_first_block.block_type);

    var zstd_decoder = ZstdNativeIncrementalFrameDecoder.initWithDictionarySetAndOptions(std.testing.allocator, zstd_dictionary_set, .{
        .expected_output_len = zstd_payload.len,
        .max_decoded_buffer_len = zstd_payload.len,
    });
    defer zstd_decoder.deinit();
    var zstd_output: [zstd_payload.len]u8 = undefined;
    const zstd_initial = try zstd_decoder.step(zstd_frame.frame, zstd_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_output, zstd_initial.status);
    try std.testing.expectEqualSlices(u8, "direct_output", zstd_decoder.diagnostics().phase_name);
    const zstd_partial = try zstd_decoder.step("", zstd_output[0..5]);
    try std.testing.expectEqual(StepResult.Status.need_output, zstd_partial.status);
    try std.testing.expectEqual(@as(usize, 5), zstd_partial.progress.output_written);
    try std.testing.expectEqual(zstd_payload.len, zstd_decoder.snapshot().decoded_len.?);
    try std.testing.expectEqual(@as(usize, 0), zstd_decoder.decodedBufferedBytes());
    try std.testing.expectEqual(@as(usize, 0), zstd_decoder.decodedBufferCapacity());
    const zstd_done = try zstd_decoder.step("", zstd_output[5..]);
    try std.testing.expectEqual(StepResult.Status.done, zstd_done.status);
    try std.testing.expectEqualSlices(u8, zstd_payload, &zstd_output);
}

test "root native dictionary incremental direct-output paths round trip" {
    const lz4_dict = Lz4NativeDictionary.init(0x5051, "abcdefghijklmnop");
    const lz4_payload = "abcdefghijklmnop-root-tail";
    const lz4_options: Lz4NativeFrameOptions = .{
        .content_checksum = true,
        .block_checksum = true,
    };
    const lz4_frame = try lz4EncodeNativeFrameWithDictionaryAlloc(std.testing.allocator, lz4_payload, lz4_options, lz4_dict);
    defer std.testing.allocator.free(lz4_frame);
    const lz4_first_block = (try lz4InspectNativeFrameFirstBlock(lz4_frame)) orelse return error.CorruptFrame;
    try std.testing.expect(lz4_first_block.is_compressed);
    var lz4_appended: std.ArrayList(u8) = .empty;
    defer lz4_appended.deinit(std.testing.allocator);
    try lz4EncodeNativeFrameAppendWithDictionary(std.testing.allocator, &lz4_appended, lz4_payload, lz4_options, lz4_dict);
    try std.testing.expectEqualSlices(u8, lz4_frame, lz4_appended.items);
    const lz4_bound = try lz4EncodedNativeFrameBoundWithDictionary(lz4_payload.len, lz4_options, lz4_dict);
    const lz4_into = try std.testing.allocator.alloc(u8, lz4_bound);
    defer std.testing.allocator.free(lz4_into);
    const lz4_into_written = try lz4EncodeNativeFrameIntoSliceWithDictionary(std.testing.allocator, lz4_payload, lz4_options, lz4_dict, lz4_into);
    try std.testing.expectEqualSlices(u8, lz4_frame, lz4_into[0..lz4_into_written]);
    try std.testing.expectError(error.OutputTooSmall, lz4EncodeNativeFrameIntoSliceWithDictionary(
        std.testing.allocator,
        lz4_payload,
        lz4_options,
        lz4_dict,
        lz4_into[0 .. lz4_into_written - 1],
    ));
    var lz4_reusable_encoder = try Lz4NativeFrameEncoder.init(std.testing.allocator);
    defer lz4_reusable_encoder.deinit();
    const lz4_reusable_owned = try lz4_reusable_encoder.encodeWithDictionaryAlloc(lz4_payload, lz4_options, lz4_dict);
    defer std.testing.allocator.free(lz4_reusable_owned);
    try std.testing.expectEqualSlices(u8, lz4_frame, lz4_reusable_owned);
    const lz4_reusable_scratch = try lz4_reusable_encoder.encodeScratchWithDictionary(lz4_payload, lz4_options, lz4_dict);
    try std.testing.expectEqualSlices(u8, lz4_frame, lz4_reusable_scratch);
    const lz4_reusable_into_written = try lz4_reusable_encoder.encodeIntoSliceWithDictionary(lz4_payload, lz4_options, lz4_dict, lz4_into);
    try std.testing.expectEqualSlices(u8, lz4_frame, lz4_into[0..lz4_reusable_into_written]);
    try std.testing.expectError(error.OutputTooSmall, lz4_reusable_encoder.encodeIntoSliceWithDictionary(
        lz4_payload,
        lz4_options,
        lz4_dict,
        lz4_into[0 .. lz4_reusable_into_written - 1],
    ));

    var lz4_decoder = Lz4NativeIncrementalFrameDecoder.initWithDictionaryAndOptions(std.testing.allocator, lz4_dict, .{
        .expected_output_len = lz4_payload.len,
        .max_decoded_buffer_len = lz4_payload.len,
    });
    defer lz4_decoder.deinit();
    var lz4_output: [lz4_payload.len]u8 = undefined;
    const lz4_initial = try lz4_decoder.step(lz4_frame, lz4_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_output, lz4_initial.status);
    try std.testing.expectEqualSlices(u8, "direct_output", lz4_decoder.diagnostics().phase_name);
    const lz4_done = try lz4_decoder.step("", &lz4_output);
    try std.testing.expectEqual(StepResult.Status.done, lz4_done.status);
    try std.testing.expectEqualSlices(u8, lz4_payload, &lz4_output);

    const lz4_second_dict = Lz4NativeDictionary.init(0x5052, "qrstuvwxyz123456");
    const lz4_dictionary_set = Lz4NativeDictionarySet.init(&.{ lz4_dict, lz4_second_dict });
    const lz4_second_payload = "qrstuvwxyz123456-root-two";
    const lz4_second = try lz4EncodeNativeFrameWithDictionaryAlloc(std.testing.allocator, lz4_second_payload, .{
        .content_checksum = false,
        .block_checksum = true,
    }, lz4_second_dict);
    defer std.testing.allocator.free(lz4_second);
    const lz4_skip = try lz4EncodeSkippableFrameAlloc(std.testing.allocator, 3, "root-direct-lz4");
    defer std.testing.allocator.free(lz4_skip);
    var lz4_stream: std.ArrayList(u8) = .empty;
    defer lz4_stream.deinit(std.testing.allocator);
    try lz4_stream.appendSlice(std.testing.allocator, lz4_frame);
    try lz4_stream.appendSlice(std.testing.allocator, lz4_skip);
    try lz4_stream.appendSlice(std.testing.allocator, lz4_second);
    const lz4_expected = lz4_payload ++ lz4_second_payload;
    var lz4_set_decoder = Lz4NativeIncrementalFrameDecoder.initWithDictionarySetAndOptions(std.testing.allocator, lz4_dictionary_set, .{
        .expected_output_len = lz4_expected.len,
        .max_decoded_buffer_len = @max(lz4_payload.len, lz4_second_payload.len),
    });
    defer lz4_set_decoder.deinit();
    var lz4_set_output: [lz4_expected.len]u8 = undefined;
    const lz4_set_initial = try lz4_set_decoder.step(lz4_stream.items, lz4_set_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_output, lz4_set_initial.status);
    try std.testing.expectEqualSlices(u8, "direct_output", lz4_set_decoder.diagnostics().phase_name);
    const lz4_set_done = try lz4_set_decoder.step("", &lz4_set_output);
    try std.testing.expectEqual(StepResult.Status.done, lz4_set_done.status);
    try std.testing.expectEqualSlices(u8, lz4_expected, &lz4_set_output);

    const zstd_dict = ZstdNativeDictionary.init(0x6061, "abcdefghijklmnop");
    const zstd_payload = "pfx-abcdefghijklmnop-root-tail";
    const zstd_options: ZstdNativeFrameOptions = .{
        .selection = .literal_only,
        .content_checksum = true,
    };
    const zstd_frame = try zstdEncodeNativeFrameWithDictionaryAlloc(std.testing.allocator, zstd_payload, zstd_options, zstd_dict);
    defer std.testing.allocator.free(zstd_frame.frame);
    const zstd_first_block = try zstdInspectNativeFrameFirstBlock(zstd_frame.frame);
    try std.testing.expectEqual(ZstdNativeBlockType.compressed, zstd_first_block.block_type);
    var zstd_appended: std.ArrayList(u8) = .empty;
    defer zstd_appended.deinit(std.testing.allocator);
    const zstd_appended_mode = try zstdEncodeNativeFrameAppendWithDictionary(std.testing.allocator, &zstd_appended, zstd_payload, zstd_options, zstd_dict);
    try std.testing.expectEqual(zstd_frame.mode, zstd_appended_mode);
    try std.testing.expectEqualSlices(u8, zstd_frame.frame, zstd_appended.items);
    const zstd_bound = try zstdEncodedNativeFrameBoundWithDictionary(zstd_payload.len, zstd_options, zstd_dict);
    const zstd_into = try std.testing.allocator.alloc(u8, zstd_bound);
    defer std.testing.allocator.free(zstd_into);
    const zstd_into_result = try zstdEncodeNativeFrameIntoSliceWithDictionary(std.testing.allocator, zstd_payload, zstd_options, zstd_dict, zstd_into);
    try std.testing.expectEqual(zstd_frame.mode, zstd_into_result.mode);
    try std.testing.expectEqualSlices(u8, zstd_frame.frame, zstd_into[0..zstd_into_result.written]);
    try std.testing.expectError(error.OutputTooSmall, zstdEncodeNativeFrameIntoSliceWithDictionary(
        std.testing.allocator,
        zstd_payload,
        zstd_options,
        zstd_dict,
        zstd_into[0 .. zstd_into_result.written - 1],
    ));
    var zstd_reusable_encoder = ZstdNativeFrameEncoder.init(std.testing.allocator);
    defer zstd_reusable_encoder.deinit();
    const zstd_reusable_owned = try zstd_reusable_encoder.encodeWithDictionaryAlloc(zstd_payload, zstd_options, zstd_dict);
    defer std.testing.allocator.free(zstd_reusable_owned.frame);
    try std.testing.expectEqual(zstd_frame.mode, zstd_reusable_owned.mode);
    try std.testing.expectEqualSlices(u8, zstd_frame.frame, zstd_reusable_owned.frame);
    const zstd_reusable_scratch = try zstd_reusable_encoder.encodeScratchWithDictionary(zstd_payload, zstd_options, zstd_dict);
    try std.testing.expectEqual(zstd_frame.mode, zstd_reusable_scratch.mode);
    try std.testing.expectEqualSlices(u8, zstd_frame.frame, zstd_reusable_scratch.frame);
    const zstd_reusable_into_result = try zstd_reusable_encoder.encodeIntoSliceWithDictionary(zstd_payload, zstd_options, zstd_dict, zstd_into);
    try std.testing.expectEqual(zstd_frame.mode, zstd_reusable_into_result.mode);
    try std.testing.expectEqualSlices(u8, zstd_frame.frame, zstd_into[0..zstd_reusable_into_result.written]);
    try std.testing.expectError(error.OutputTooSmall, zstd_reusable_encoder.encodeIntoSliceWithDictionary(
        zstd_payload,
        zstd_options,
        zstd_dict,
        zstd_into[0 .. zstd_reusable_into_result.written - 1],
    ));

    var zstd_decoder = ZstdNativeIncrementalFrameDecoder.initWithDictionaryAndOptions(std.testing.allocator, zstd_dict, .{
        .expected_output_len = zstd_payload.len,
        .max_decoded_buffer_len = zstd_payload.len,
    });
    defer zstd_decoder.deinit();
    var zstd_output: [zstd_payload.len]u8 = undefined;
    const zstd_initial = try zstd_decoder.step(zstd_frame.frame, zstd_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_output, zstd_initial.status);
    try std.testing.expectEqualSlices(u8, "direct_output", zstd_decoder.diagnostics().phase_name);
    const zstd_done = try zstd_decoder.step("", &zstd_output);
    try std.testing.expectEqual(StepResult.Status.done, zstd_done.status);
    try std.testing.expectEqualSlices(u8, zstd_payload, &zstd_output);

    const zstd_second_dict = ZstdNativeDictionary.init(0x6062, "QRSTUVWXYZabcd1234");
    const zstd_dictionary_set = ZstdNativeDictionarySet.init(&.{ zstd_dict, zstd_second_dict });
    const zstd_second_payload = "pfx-QRSTUVWXYZabcd1234-root-two";
    const zstd_second = try zstdEncodeNativeFrameWithDictionaryAlloc(std.testing.allocator, zstd_second_payload, .{
        .selection = .literal_only,
        .content_checksum = false,
    }, zstd_second_dict);
    defer std.testing.allocator.free(zstd_second.frame);
    const zstd_skip = try zstdEncodeSkippableFrameAlloc(std.testing.allocator, 3, "root-direct-zstd");
    defer std.testing.allocator.free(zstd_skip);
    var zstd_stream: std.ArrayList(u8) = .empty;
    defer zstd_stream.deinit(std.testing.allocator);
    try zstd_stream.appendSlice(std.testing.allocator, zstd_frame.frame);
    try zstd_stream.appendSlice(std.testing.allocator, zstd_skip);
    try zstd_stream.appendSlice(std.testing.allocator, zstd_second.frame);
    const zstd_expected = zstd_payload ++ zstd_second_payload;
    var zstd_set_decoder = ZstdNativeIncrementalFrameDecoder.initWithDictionarySetAndOptions(std.testing.allocator, zstd_dictionary_set, .{
        .expected_output_len = zstd_expected.len,
        .max_decoded_buffer_len = @max(zstd_payload.len, zstd_second_payload.len),
    });
    defer zstd_set_decoder.deinit();
    var zstd_set_output: [zstd_expected.len]u8 = undefined;
    const zstd_set_initial = try zstd_set_decoder.step(zstd_stream.items, zstd_set_output[0..0]);
    try std.testing.expectEqual(StepResult.Status.need_output, zstd_set_initial.status);
    try std.testing.expectEqualSlices(u8, "direct_output", zstd_set_decoder.diagnostics().phase_name);
    const zstd_set_done = try zstd_set_decoder.step("", &zstd_set_output);
    try std.testing.expectEqual(StepResult.Status.done, zstd_set_done.status);
    try std.testing.expectEqualSlices(u8, zstd_expected, &zstd_set_output);
}

test "root native dictionary set APIs resolve concatenated frame dictionaries" {
    const lz4_first_dict = Lz4NativeDictionary.init(0x1010, "abcdefghijklmnop");
    const lz4_second_dict = Lz4NativeDictionary.init(0x2020, "qrstuvwxyz123456");
    const lz4_dictionary_set = Lz4NativeDictionarySet.init(&.{ lz4_first_dict, lz4_second_dict });
    const lz4_options: Lz4NativeFrameOptions = .{
        .content_checksum = false,
        .block_checksum = true,
    };
    const lz4_first_payload = "abcdefghijklmnop-one";
    const lz4_second_payload = "qrstuvwxyz123456-two";
    const lz4_first = try lz4EncodeNativeFrameWithDictionaryAlloc(std.testing.allocator, lz4_first_payload, lz4_options, lz4_first_dict);
    defer std.testing.allocator.free(lz4_first);
    const lz4_second = try lz4EncodeNativeFrameWithDictionaryAlloc(std.testing.allocator, lz4_second_payload, lz4_options, lz4_second_dict);
    defer std.testing.allocator.free(lz4_second);
    const lz4_skip = try lz4EncodeSkippableFrameAlloc(std.testing.allocator, 1, "root-lz4-dict-set");
    defer std.testing.allocator.free(lz4_skip);

    var lz4_stream: std.ArrayList(u8) = .empty;
    defer lz4_stream.deinit(std.testing.allocator);
    try lz4_stream.appendSlice(std.testing.allocator, lz4_first);
    try lz4_stream.appendSlice(std.testing.allocator, lz4_skip);
    try lz4_stream.appendSlice(std.testing.allocator, lz4_second);

    const lz4_expected = lz4_first_payload ++ lz4_second_payload;
    const lz4_set_bound = try lz4EncodedNativeFrameBoundWithDictionarySet(lz4_first_payload.len, lz4_options, lz4_dictionary_set, lz4_first_dict.id);
    try std.testing.expect(lz4_first.len <= lz4_set_bound);
    try std.testing.expectError(error.NeedDictionary, lz4EncodedNativeFrameBoundWithDictionarySet(lz4_first_payload.len, lz4_options, lz4_dictionary_set, 0xeeee));
    const lz4_set_encoded = try lz4EncodeNativeFrameWithDictionarySetAlloc(std.testing.allocator, lz4_first_payload, lz4_options, lz4_dictionary_set, lz4_first_dict.id);
    defer std.testing.allocator.free(lz4_set_encoded);
    try std.testing.expectEqualSlices(u8, lz4_first, lz4_set_encoded);
    var lz4_set_appended: std.ArrayList(u8) = .empty;
    defer lz4_set_appended.deinit(std.testing.allocator);
    try lz4EncodeNativeFrameAppendWithDictionarySet(std.testing.allocator, &lz4_set_appended, lz4_first_payload, lz4_options, lz4_dictionary_set, lz4_first_dict.id);
    try std.testing.expectEqualSlices(u8, lz4_first, lz4_set_appended.items);
    const lz4_set_into = try std.testing.allocator.alloc(u8, lz4_set_bound);
    defer std.testing.allocator.free(lz4_set_into);
    const lz4_set_into_written = try lz4EncodeNativeFrameIntoSliceWithDictionarySet(std.testing.allocator, lz4_first_payload, lz4_options, lz4_dictionary_set, lz4_first_dict.id, lz4_set_into);
    try std.testing.expectEqualSlices(u8, lz4_first, lz4_set_into[0..lz4_set_into_written]);
    var lz4_set_encoder = try Lz4NativeFrameEncoder.init(std.testing.allocator);
    defer lz4_set_encoder.deinit();
    const lz4_set_reusable = try lz4_set_encoder.encodeWithDictionarySetAlloc(lz4_first_payload, lz4_options, lz4_dictionary_set, lz4_first_dict.id);
    defer std.testing.allocator.free(lz4_set_reusable);
    try std.testing.expectEqualSlices(u8, lz4_first, lz4_set_reusable);
    const lz4_set_scratch = try lz4_set_encoder.encodeScratchWithDictionarySet(lz4_first_payload, lz4_options, lz4_dictionary_set, lz4_first_dict.id);
    try std.testing.expectEqualSlices(u8, lz4_first, lz4_set_scratch);
    const lz4_set_reusable_into = try lz4_set_encoder.encodeIntoSliceWithDictionarySet(lz4_first_payload, lz4_options, lz4_dictionary_set, lz4_first_dict.id, lz4_set_into);
    try std.testing.expectEqualSlices(u8, lz4_first, lz4_set_into[0..lz4_set_reusable_into]);
    try std.testing.expectError(error.NeedDictionary, lz4EncodeNativeFrameWithDictionarySetAlloc(std.testing.allocator, lz4_first_payload, lz4_options, lz4_dictionary_set, 0xeeee));
    const lz4_decoded = try lz4DecodeNativeConcatenatedFrameAllocWithDictionarySet(std.testing.allocator, lz4_stream.items, lz4_dictionary_set);
    defer std.testing.allocator.free(lz4_decoded);
    try std.testing.expectEqualSlices(u8, lz4_expected, lz4_decoded);
    var lz4_single_appended: std.ArrayList(u8) = .empty;
    defer lz4_single_appended.deinit(std.testing.allocator);
    try lz4_single_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(lz4_first_payload.len, try lz4DecodeNativeFrameAppendExactSizeWithDictionarySet(std.testing.allocator, &lz4_single_appended, lz4_first, lz4_dictionary_set, lz4_first_payload.len));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ lz4_first_payload, lz4_single_appended.items);
    lz4_single_appended.clearRetainingCapacity();
    try std.testing.expectError(error.SizeMismatch, lz4DecodeNativeFrameAppendExactSizeWithDictionarySet(std.testing.allocator, &lz4_single_appended, lz4_first, lz4_dictionary_set, lz4_first_payload.len - 1));
    const lz4_single_chunks = [_][]const u8{
        lz4_first[0..3],
        lz4_first[3..],
    };
    const lz4_single_join = try std.testing.allocator.alloc(u8, lz4_first.len);
    defer std.testing.allocator.free(lz4_single_join);
    try std.testing.expectEqual(lz4_first_payload.len, try lz4DecodedNativeFrameChunksSizeWithDictionary(&lz4_single_chunks, lz4_single_join, lz4_first_dict));
    try std.testing.expectEqual(lz4_first_payload.len, try lz4DecodedNativeFrameChunksSizeLimitedWithDictionarySet(&lz4_single_chunks, lz4_single_join, lz4_first_payload.len, lz4_dictionary_set));
    try std.testing.expectError(error.OutputLimitExceeded, lz4DecodedNativeFrameChunksSizeLimitedWithDictionarySet(&lz4_single_chunks, lz4_single_join, lz4_first_payload.len - 1, lz4_dictionary_set));
    const lz4_single_chunked = try lz4DecodeNativeFrameChunksAllocWithDictionary(std.testing.allocator, &lz4_single_chunks, lz4_single_join, lz4_first_dict);
    defer std.testing.allocator.free(lz4_single_chunked);
    try std.testing.expectEqualSlices(u8, lz4_first_payload, lz4_single_chunked);
    const lz4_single_chunked_set = try lz4DecodeNativeFrameChunksAllocWithDictionarySetExactSize(std.testing.allocator, &lz4_single_chunks, lz4_single_join, lz4_dictionary_set, lz4_first_payload.len);
    defer std.testing.allocator.free(lz4_single_chunked_set);
    try std.testing.expectEqualSlices(u8, lz4_first_payload, lz4_single_chunked_set);
    var lz4_single_chunked_into: [lz4_first_payload.len]u8 = undefined;
    try std.testing.expectEqual(lz4_first_payload.len, try lz4DecodeNativeFrameChunksIntoWithDictionarySet(&lz4_single_chunks, lz4_single_join, &lz4_single_chunked_into, lz4_dictionary_set));
    try std.testing.expectEqualSlices(u8, lz4_first_payload, &lz4_single_chunked_into);
    var lz4_single_chunked_appended: std.ArrayList(u8) = .empty;
    defer lz4_single_chunked_appended.deinit(std.testing.allocator);
    try lz4_single_chunked_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(lz4_first_payload.len, try lz4DecodeNativeFrameChunksAppendExactSizeWithDictionary(std.testing.allocator, &lz4_single_chunked_appended, &lz4_single_chunks, lz4_single_join, lz4_first_dict, lz4_first_payload.len));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ lz4_first_payload, lz4_single_chunked_appended.items);
    lz4_single_chunked_appended.clearRetainingCapacity();
    try std.testing.expectError(error.SizeMismatch, lz4DecodeNativeFrameChunksAppendExactSizeWithDictionary(std.testing.allocator, &lz4_single_chunked_appended, &lz4_single_chunks, lz4_single_join, lz4_first_dict, lz4_first_payload.len - 1));
    var lz4_reusable_decoder = Lz4NativeFrameDecoder.init(std.testing.allocator);
    defer lz4_reusable_decoder.deinit();
    try std.testing.expectEqual(lz4_first_payload.len, try lz4_reusable_decoder.decodedChunksSizeWithDictionary(&lz4_single_chunks, lz4_single_join, lz4_first_dict));
    try std.testing.expectEqual(lz4_first_payload.len, try lz4_reusable_decoder.decodedChunksSizeLimitedWithDictionarySet(&lz4_single_chunks, lz4_single_join, lz4_first_payload.len, lz4_dictionary_set));
    try std.testing.expectError(error.OutputLimitExceeded, lz4_reusable_decoder.decodedChunksSizeLimitedWithDictionarySet(&lz4_single_chunks, lz4_single_join, lz4_first_payload.len - 1, lz4_dictionary_set));
    const lz4_reusable_single_exact = try lz4_reusable_decoder.decodeChunksAllocExactSizeWithDictionarySet(&lz4_single_chunks, lz4_single_join, lz4_dictionary_set, lz4_first_payload.len);
    defer std.testing.allocator.free(lz4_reusable_single_exact);
    try std.testing.expectEqualSlices(u8, lz4_first_payload, lz4_reusable_single_exact);
    const lz4_reusable_single_scratch = try lz4_reusable_decoder.decodeChunksScratchWithDictionary(&lz4_single_chunks, lz4_single_join, lz4_first_dict);
    try std.testing.expectEqualSlices(u8, lz4_first_payload, lz4_reusable_single_scratch);
    const lz4_reusable_single_scratch_limited = try lz4_reusable_decoder.decodeChunksScratchLimitedWithDictionarySet(&lz4_single_chunks, lz4_single_join, lz4_first_payload.len, lz4_dictionary_set);
    try std.testing.expectEqualSlices(u8, lz4_first_payload, lz4_reusable_single_scratch_limited);
    try std.testing.expectError(error.OutputLimitExceeded, lz4_reusable_decoder.decodeChunksScratchLimitedWithDictionarySet(&lz4_single_chunks, lz4_single_join, lz4_first_payload.len - 1, lz4_dictionary_set));
    var lz4_reusable_single_appended: std.ArrayList(u8) = .empty;
    defer lz4_reusable_single_appended.deinit(std.testing.allocator);
    try lz4_reusable_single_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(lz4_first_payload.len, try lz4_reusable_decoder.decodeChunksAppendWithDictionarySet(&lz4_reusable_single_appended, &lz4_single_chunks, lz4_single_join, lz4_dictionary_set));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ lz4_first_payload, lz4_reusable_single_appended.items);
    lz4_reusable_single_appended.clearRetainingCapacity();
    try lz4_reusable_single_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(lz4_first_payload.len, try lz4_reusable_decoder.decodeChunksAppendLimitedWithDictionary(&lz4_reusable_single_appended, &lz4_single_chunks, lz4_single_join, lz4_first_payload.len, lz4_first_dict));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ lz4_first_payload, lz4_reusable_single_appended.items);
    lz4_reusable_single_appended.clearRetainingCapacity();
    try std.testing.expectError(error.SizeMismatch, lz4_reusable_decoder.decodeChunksAppendExactSizeWithDictionarySet(&lz4_reusable_single_appended, &lz4_single_chunks, lz4_single_join, lz4_dictionary_set, lz4_first_payload.len - 1));
    @memset(&lz4_single_chunked_into, 0);
    try std.testing.expectEqual(lz4_first_payload.len, try lz4_reusable_decoder.decodeChunksIntoSliceWithDictionarySet(&lz4_single_chunks, lz4_single_join, &lz4_single_chunked_into, lz4_dictionary_set));
    try std.testing.expectEqualSlices(u8, lz4_first_payload, &lz4_single_chunked_into);
    const lz4_reusable_scratch = try lz4_reusable_decoder.decodeConcatenatedScratchWithDictionarySet(lz4_stream.items, lz4_dictionary_set);
    try std.testing.expectEqualSlices(u8, lz4_expected, lz4_reusable_scratch);
    try std.testing.expectEqual(lz4_first_payload.len, try lz4_reusable_decoder.decodedSizeWithDictionarySet(lz4_first, lz4_dictionary_set));
    try std.testing.expectEqual(lz4_first_payload.len, try lz4_reusable_decoder.decodedSizeLimitedWithDictionarySet(lz4_first, lz4_first_payload.len, lz4_dictionary_set));
    try std.testing.expectError(error.OutputLimitExceeded, lz4_reusable_decoder.decodedSizeLimitedWithDictionarySet(lz4_first, lz4_first_payload.len - 1, lz4_dictionary_set));
    try std.testing.expectEqual(lz4_expected.len, try lz4_reusable_decoder.decodedConcatenatedSizeWithDictionarySet(lz4_stream.items, lz4_dictionary_set));
    try std.testing.expectEqual(lz4_expected.len, try lz4_reusable_decoder.decodedConcatenatedSizeLimitedWithDictionarySet(lz4_stream.items, lz4_expected.len, lz4_dictionary_set));
    try std.testing.expectError(error.OutputLimitExceeded, lz4_reusable_decoder.decodedConcatenatedSizeLimitedWithDictionarySet(lz4_stream.items, lz4_expected.len - 1, lz4_dictionary_set));
    var lz4_reusable_append: std.ArrayList(u8) = .empty;
    defer lz4_reusable_append.deinit(std.testing.allocator);
    try lz4_reusable_append.appendSlice(std.testing.allocator, "prefix:");
    const lz4_reusable_appended = try lz4_reusable_decoder.decodeConcatenatedAppendWithDictionarySet(&lz4_reusable_append, lz4_stream.items, lz4_dictionary_set);
    try std.testing.expectEqual(lz4_expected.len, lz4_reusable_appended);
    try std.testing.expectEqualSlices(u8, "prefix:", lz4_reusable_append.items[0.."prefix:".len]);
    try std.testing.expectEqualSlices(u8, lz4_expected, lz4_reusable_append.items["prefix:".len..]);
    const lz4_exact_decoded = try lz4DecodeNativeConcatenatedFrameAllocWithDictionarySetExactSize(std.testing.allocator, lz4_stream.items, lz4_dictionary_set, lz4_expected.len);
    defer std.testing.allocator.free(lz4_exact_decoded);
    try std.testing.expectEqualSlices(u8, lz4_expected, lz4_exact_decoded);
    try std.testing.expectError(error.SizeMismatch, lz4DecodeNativeConcatenatedFrameAllocWithDictionarySetExactSize(
        std.testing.allocator,
        lz4_stream.items,
        lz4_dictionary_set,
        lz4_expected.len - 1,
    ));
    try std.testing.expectEqual(lz4_expected.len, try lz4DecodedNativeConcatenatedFrameSizeWithDictionarySet(lz4_stream.items, lz4_dictionary_set));
    var lz4_into: [lz4_expected.len]u8 = undefined;
    try std.testing.expectEqual(lz4_expected.len, try lz4DecodeNativeConcatenatedFrameIntoWithDictionarySet(lz4_stream.items, &lz4_into, lz4_dictionary_set));
    try std.testing.expectEqualSlices(u8, lz4_expected, &lz4_into);
    @memset(&lz4_into, 0);
    try std.testing.expectEqual(lz4_expected.len, try lz4DecodeConcatenatedFrameIntoWithDictionarySetExactSize(lz4_stream.items, &lz4_into, lz4_dictionary_set, lz4_expected.len));
    try std.testing.expectEqualSlices(u8, lz4_expected, &lz4_into);
    try std.testing.expectError(error.OutputTooSmall, lz4DecodeConcatenatedFrameIntoWithDictionarySetExactSize(lz4_stream.items, lz4_into[0 .. lz4_into.len - 1], lz4_dictionary_set, lz4_expected.len));
    try std.testing.expectError(error.SizeMismatch, lz4DecodeConcatenatedFrameIntoWithDictionarySetExactSize(lz4_stream.items, &lz4_into, lz4_dictionary_set, lz4_expected.len - 1));
    @memset(&lz4_into, 0);
    const lz4_reusable_into = try lz4_reusable_decoder.decodeConcatenatedIntoSliceWithDictionarySet(lz4_stream.items, &lz4_into, lz4_dictionary_set);
    try std.testing.expectEqual(lz4_expected.len, lz4_reusable_into);
    try std.testing.expectEqualSlices(u8, lz4_expected, &lz4_into);
    const lz4_chunks = [_][]const u8{
        lz4_stream.items[0..5],
        lz4_stream.items[5 .. lz4_stream.items.len - 3],
        lz4_stream.items[lz4_stream.items.len - 3 ..],
    };
    const lz4_join = try std.testing.allocator.alloc(u8, lz4_stream.items.len);
    defer std.testing.allocator.free(lz4_join);
    const lz4_chunked = try lz4DecodeConcatenatedFrameChunksAllocWithDictionarySet(std.testing.allocator, &lz4_chunks, lz4_join, lz4_dictionary_set);
    defer std.testing.allocator.free(lz4_chunked);
    try std.testing.expectEqualSlices(u8, lz4_expected, lz4_chunked);
    var lz4_chunked_appended: std.ArrayList(u8) = .empty;
    defer lz4_chunked_appended.deinit(std.testing.allocator);
    try lz4_chunked_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(lz4_expected.len, try lz4DecodeNativeConcatenatedFrameChunksAppendWithDictionarySet(std.testing.allocator, &lz4_chunked_appended, &lz4_chunks, lz4_join, lz4_dictionary_set));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ lz4_expected, lz4_chunked_appended.items);
    lz4_chunked_appended.clearRetainingCapacity();
    try lz4_chunked_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(lz4_expected.len, try lz4DecodeNativeConcatenatedFrameChunksAppendExactSizeWithDictionarySet(std.testing.allocator, &lz4_chunked_appended, &lz4_chunks, lz4_join, lz4_dictionary_set, lz4_expected.len));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ lz4_expected, lz4_chunked_appended.items);
    lz4_chunked_appended.clearRetainingCapacity();
    try std.testing.expectError(error.SizeMismatch, lz4DecodeNativeConcatenatedFrameChunksAppendExactSizeWithDictionarySet(std.testing.allocator, &lz4_chunked_appended, &lz4_chunks, lz4_join, lz4_dictionary_set, lz4_expected.len - 1));
    lz4_chunked_appended.clearRetainingCapacity();
    try lz4_chunked_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(lz4_expected.len, try lz4DecodeNativeConcatenatedFrameChunksAppendLimitedWithDictionarySet(std.testing.allocator, &lz4_chunked_appended, &lz4_chunks, lz4_join, lz4_expected.len, lz4_dictionary_set));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ lz4_expected, lz4_chunked_appended.items);
    lz4_chunked_appended.clearRetainingCapacity();
    try std.testing.expectError(error.OutputLimitExceeded, lz4DecodeNativeConcatenatedFrameChunksAppendLimitedWithDictionarySet(std.testing.allocator, &lz4_chunked_appended, &lz4_chunks, lz4_join, lz4_expected.len - 1, lz4_dictionary_set));
    const lz4_reusable_chunked_exact = try lz4_reusable_decoder.decodeConcatenatedChunksAllocExactSizeWithDictionarySet(&lz4_chunks, lz4_join, lz4_dictionary_set, lz4_expected.len);
    defer std.testing.allocator.free(lz4_reusable_chunked_exact);
    try std.testing.expectEqualSlices(u8, lz4_expected, lz4_reusable_chunked_exact);
    try std.testing.expectError(error.SizeMismatch, lz4_reusable_decoder.decodeConcatenatedChunksAllocExactSizeWithDictionarySet(&lz4_chunks, lz4_join, lz4_dictionary_set, lz4_expected.len - 1));
    try std.testing.expectEqual(lz4_expected.len, try lz4DecodedConcatenatedFrameChunksSizeWithDictionarySet(&lz4_chunks, lz4_join, lz4_dictionary_set));
    try std.testing.expectEqual(lz4_expected.len, try lz4DecodedConcatenatedFrameChunksSizeLimitedWithDictionarySet(&lz4_chunks, lz4_join, lz4_expected.len, lz4_dictionary_set));
    try std.testing.expectEqual(lz4_expected.len, try lz4DecodedNativeConcatenatedFrameChunksSizeWithDictionarySet(&lz4_chunks, lz4_join, lz4_dictionary_set));
    try std.testing.expectEqual(lz4_expected.len, try lz4DecodedNativeConcatenatedFrameChunksSizeLimitedWithDictionarySet(&lz4_chunks, lz4_join, lz4_expected.len, lz4_dictionary_set));
    try std.testing.expectError(error.OutputLimitExceeded, lz4DecodedNativeConcatenatedFrameChunksSizeLimitedWithDictionarySet(&lz4_chunks, lz4_join, lz4_expected.len - 1, lz4_dictionary_set));
    try std.testing.expectEqual(lz4_expected.len, try lz4_reusable_decoder.decodedConcatenatedChunksSizeWithDictionarySet(&lz4_chunks, lz4_join, lz4_dictionary_set));
    try std.testing.expectEqual(lz4_expected.len, try lz4_reusable_decoder.decodedConcatenatedChunksSizeLimitedWithDictionarySet(&lz4_chunks, lz4_join, lz4_expected.len, lz4_dictionary_set));
    var lz4_chunked_into: [lz4_expected.len]u8 = undefined;
    try std.testing.expectEqual(lz4_expected.len, try lz4DecodeConcatenatedFrameChunksIntoWithDictionarySet(&lz4_chunks, lz4_join, &lz4_chunked_into, lz4_dictionary_set));
    try std.testing.expectEqualSlices(u8, lz4_expected, &lz4_chunked_into);
    const lz4_reusable_chunked_scratch = try lz4_reusable_decoder.decodeConcatenatedChunksScratchWithDictionarySet(&lz4_chunks, lz4_join, lz4_dictionary_set);
    try std.testing.expectEqualSlices(u8, lz4_expected, lz4_reusable_chunked_scratch);
    var lz4_reusable_chunked_append: std.ArrayList(u8) = .empty;
    defer lz4_reusable_chunked_append.deinit(std.testing.allocator);
    try lz4_reusable_chunked_append.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(lz4_expected.len, try lz4_reusable_decoder.decodeConcatenatedChunksAppendWithDictionarySet(&lz4_reusable_chunked_append, &lz4_chunks, lz4_join, lz4_dictionary_set));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ lz4_expected, lz4_reusable_chunked_append.items);
    lz4_reusable_chunked_append.clearRetainingCapacity();
    try lz4_reusable_chunked_append.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(lz4_expected.len, try lz4_reusable_decoder.decodeConcatenatedChunksAppendExactSizeWithDictionarySet(&lz4_reusable_chunked_append, &lz4_chunks, lz4_join, lz4_dictionary_set, lz4_expected.len));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ lz4_expected, lz4_reusable_chunked_append.items);
    lz4_reusable_chunked_append.clearRetainingCapacity();
    try std.testing.expectError(error.SizeMismatch, lz4_reusable_decoder.decodeConcatenatedChunksAppendExactSizeWithDictionarySet(&lz4_reusable_chunked_append, &lz4_chunks, lz4_join, lz4_dictionary_set, lz4_expected.len - 1));
    @memset(&lz4_chunked_into, 0);
    try std.testing.expectEqual(lz4_expected.len, try lz4_reusable_decoder.decodeConcatenatedChunksIntoSliceWithDictionarySet(&lz4_chunks, lz4_join, &lz4_chunked_into, lz4_dictionary_set));
    try std.testing.expectEqualSlices(u8, lz4_expected, &lz4_chunked_into);
    try std.testing.expectError(error.OutputTooSmall, lz4DecodeConcatenatedFrameChunksAllocWithDictionarySet(std.testing.allocator, &lz4_chunks, lz4_join[0 .. lz4_join.len - 1], lz4_dictionary_set));
    try std.testing.expectError(error.NeedDictionary, lz4DecodeNativeConcatenatedFrameAllocWithDictionarySet(
        std.testing.allocator,
        lz4_stream.items,
        Lz4NativeDictionarySet.init(&.{lz4_first_dict}),
    ));

    const zstd_first_dict = ZstdNativeDictionary.init(0x3030, "abcdefghijklmnop");
    const zstd_second_dict = ZstdNativeDictionary.init(0x4040, "QRSTUVWXYZabcd1234");
    const zstd_dictionary_set = ZstdNativeDictionarySet.init(&.{ zstd_first_dict, zstd_second_dict });
    const zstd_options: ZstdNativeFrameOptions = .{
        .selection = .literal_only,
        .content_checksum = false,
    };
    const zstd_first_payload = "pfx-abcdefghijklmnop-tail";
    const zstd_second_payload = "pfx-QRSTUVWXYZabcd1234-tail";
    const zstd_first = try zstdEncodeNativeFrameWithDictionaryAlloc(std.testing.allocator, zstd_first_payload, zstd_options, zstd_first_dict);
    defer std.testing.allocator.free(zstd_first.frame);
    const zstd_second = try zstdEncodeNativeFrameWithDictionaryAlloc(std.testing.allocator, zstd_second_payload, zstd_options, zstd_second_dict);
    defer std.testing.allocator.free(zstd_second.frame);
    const zstd_skip = try zstdEncodeSkippableFrameAlloc(std.testing.allocator, 1, "root-zstd-dict-set");
    defer std.testing.allocator.free(zstd_skip);

    var zstd_stream: std.ArrayList(u8) = .empty;
    defer zstd_stream.deinit(std.testing.allocator);
    try zstd_stream.appendSlice(std.testing.allocator, zstd_first.frame);
    try zstd_stream.appendSlice(std.testing.allocator, zstd_skip);
    try zstd_stream.appendSlice(std.testing.allocator, zstd_second.frame);

    const zstd_expected = zstd_first_payload ++ zstd_second_payload;
    const zstd_set_bound = try zstdEncodedNativeFrameBoundWithDictionarySet(zstd_first_payload.len, zstd_options, zstd_dictionary_set, zstd_first_dict.id);
    try std.testing.expect(zstd_first.frame.len <= zstd_set_bound);
    try std.testing.expectError(error.NeedDictionary, zstdEncodedNativeFrameBoundWithDictionarySet(zstd_first_payload.len, zstd_options, zstd_dictionary_set, 0xeeee));
    const zstd_set_encoded = try zstdEncodeNativeFrameWithDictionarySetAlloc(std.testing.allocator, zstd_first_payload, zstd_options, zstd_dictionary_set, zstd_first_dict.id);
    defer std.testing.allocator.free(zstd_set_encoded.frame);
    try std.testing.expectEqual(zstd_first.mode, zstd_set_encoded.mode);
    try std.testing.expectEqualSlices(u8, zstd_first.frame, zstd_set_encoded.frame);
    var zstd_set_appended: std.ArrayList(u8) = .empty;
    defer zstd_set_appended.deinit(std.testing.allocator);
    const zstd_set_appended_mode = try zstdEncodeNativeFrameAppendWithDictionarySet(std.testing.allocator, &zstd_set_appended, zstd_first_payload, zstd_options, zstd_dictionary_set, zstd_first_dict.id);
    try std.testing.expectEqual(zstd_first.mode, zstd_set_appended_mode);
    try std.testing.expectEqualSlices(u8, zstd_first.frame, zstd_set_appended.items);
    const zstd_set_into = try std.testing.allocator.alloc(u8, zstd_set_bound);
    defer std.testing.allocator.free(zstd_set_into);
    const zstd_set_into_result = try zstdEncodeNativeFrameIntoSliceWithDictionarySet(std.testing.allocator, zstd_first_payload, zstd_options, zstd_dictionary_set, zstd_first_dict.id, zstd_set_into);
    try std.testing.expectEqual(zstd_first.mode, zstd_set_into_result.mode);
    try std.testing.expectEqualSlices(u8, zstd_first.frame, zstd_set_into[0..zstd_set_into_result.written]);
    var zstd_set_encoder = ZstdNativeFrameEncoder.init(std.testing.allocator);
    defer zstd_set_encoder.deinit();
    const zstd_set_reusable = try zstd_set_encoder.encodeWithDictionarySetAlloc(zstd_first_payload, zstd_options, zstd_dictionary_set, zstd_first_dict.id);
    defer std.testing.allocator.free(zstd_set_reusable.frame);
    try std.testing.expectEqual(zstd_first.mode, zstd_set_reusable.mode);
    try std.testing.expectEqualSlices(u8, zstd_first.frame, zstd_set_reusable.frame);
    const zstd_set_scratch = try zstd_set_encoder.encodeScratchWithDictionarySet(zstd_first_payload, zstd_options, zstd_dictionary_set, zstd_first_dict.id);
    try std.testing.expectEqual(zstd_first.mode, zstd_set_scratch.mode);
    try std.testing.expectEqualSlices(u8, zstd_first.frame, zstd_set_scratch.frame);
    const zstd_set_reusable_into = try zstd_set_encoder.encodeIntoSliceWithDictionarySet(zstd_first_payload, zstd_options, zstd_dictionary_set, zstd_first_dict.id, zstd_set_into);
    try std.testing.expectEqual(zstd_first.mode, zstd_set_reusable_into.mode);
    try std.testing.expectEqualSlices(u8, zstd_first.frame, zstd_set_into[0..zstd_set_reusable_into.written]);
    try std.testing.expectError(error.NeedDictionary, zstdEncodeNativeFrameWithDictionarySetAlloc(std.testing.allocator, zstd_first_payload, zstd_options, zstd_dictionary_set, 0xeeee));
    const zstd_decoded = try zstdDecodeNativeConcatenatedFrameAllocWithDictionarySet(std.testing.allocator, zstd_stream.items, zstd_dictionary_set);
    defer std.testing.allocator.free(zstd_decoded);
    try std.testing.expectEqualSlices(u8, zstd_expected, zstd_decoded);
    const zstd_single_chunks = [_][]const u8{
        zstd_first.frame[0..4],
        zstd_first.frame[4..],
    };
    const zstd_single_join = try std.testing.allocator.alloc(u8, zstd_first.frame.len);
    defer std.testing.allocator.free(zstd_single_join);
    try std.testing.expectEqual(zstd_first_payload.len, try zstdDecodedNativeFrameChunksSizeWithDictionary(&zstd_single_chunks, zstd_single_join, zstd_first_dict));
    try std.testing.expectEqual(zstd_first_payload.len, try zstdDecodedNativeFrameChunksSizeLimitedWithDictionarySet(&zstd_single_chunks, zstd_single_join, zstd_first_payload.len, zstd_dictionary_set));
    try std.testing.expectError(error.OutputLimitExceeded, zstdDecodedNativeFrameChunksSizeLimitedWithDictionarySet(&zstd_single_chunks, zstd_single_join, zstd_first_payload.len - 1, zstd_dictionary_set));
    const zstd_single_chunked = try zstdDecodeNativeFrameChunksAllocWithDictionary(std.testing.allocator, &zstd_single_chunks, zstd_single_join, zstd_first_dict);
    defer std.testing.allocator.free(zstd_single_chunked);
    try std.testing.expectEqualSlices(u8, zstd_first_payload, zstd_single_chunked);
    const zstd_single_chunked_set = try zstdDecodeNativeFrameChunksAllocWithDictionarySetExactSize(std.testing.allocator, &zstd_single_chunks, zstd_single_join, zstd_dictionary_set, zstd_first_payload.len);
    defer std.testing.allocator.free(zstd_single_chunked_set);
    try std.testing.expectEqualSlices(u8, zstd_first_payload, zstd_single_chunked_set);
    var zstd_single_chunked_into: [zstd_first_payload.len]u8 = undefined;
    try std.testing.expectEqual(zstd_first_payload.len, try zstdDecodeNativeFrameChunksIntoWithDictionarySet(&zstd_single_chunks, zstd_single_join, &zstd_single_chunked_into, zstd_dictionary_set));
    try std.testing.expectEqualSlices(u8, zstd_first_payload, &zstd_single_chunked_into);
    var zstd_single_chunked_appended: std.ArrayList(u8) = .empty;
    defer zstd_single_chunked_appended.deinit(std.testing.allocator);
    try zstd_single_chunked_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(zstd_first_payload.len, try zstdDecodeNativeFrameChunksAppendExactSizeWithDictionary(std.testing.allocator, &zstd_single_chunked_appended, &zstd_single_chunks, zstd_single_join, zstd_first_dict, zstd_first_payload.len));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ zstd_first_payload, zstd_single_chunked_appended.items);
    zstd_single_chunked_appended.clearRetainingCapacity();
    try std.testing.expectError(error.SizeMismatch, zstdDecodeNativeFrameChunksAppendExactSizeWithDictionary(std.testing.allocator, &zstd_single_chunked_appended, &zstd_single_chunks, zstd_single_join, zstd_first_dict, zstd_first_payload.len - 1));
    var zstd_reusable_decoder = ZstdNativeFrameDecoder.init(std.testing.allocator);
    defer zstd_reusable_decoder.deinit();
    try std.testing.expectEqual(zstd_first_payload.len, try zstd_reusable_decoder.decodedChunksSizeWithDictionary(&zstd_single_chunks, zstd_single_join, zstd_first_dict));
    try std.testing.expectEqual(zstd_first_payload.len, try zstd_reusable_decoder.decodedChunksSizeLimitedWithDictionarySet(&zstd_single_chunks, zstd_single_join, zstd_first_payload.len, zstd_dictionary_set));
    try std.testing.expectError(error.OutputLimitExceeded, zstd_reusable_decoder.decodedChunksSizeLimitedWithDictionarySet(&zstd_single_chunks, zstd_single_join, zstd_first_payload.len - 1, zstd_dictionary_set));
    const zstd_reusable_single_exact = try zstd_reusable_decoder.decodeChunksAllocExactSizeWithDictionarySet(&zstd_single_chunks, zstd_single_join, zstd_dictionary_set, zstd_first_payload.len);
    defer std.testing.allocator.free(zstd_reusable_single_exact);
    try std.testing.expectEqualSlices(u8, zstd_first_payload, zstd_reusable_single_exact);
    const zstd_reusable_single_scratch = try zstd_reusable_decoder.decodeChunksScratchWithDictionary(&zstd_single_chunks, zstd_single_join, zstd_first_dict);
    try std.testing.expectEqualSlices(u8, zstd_first_payload, zstd_reusable_single_scratch);
    const zstd_reusable_single_scratch_limited = try zstd_reusable_decoder.decodeChunksScratchLimitedWithDictionarySet(&zstd_single_chunks, zstd_single_join, zstd_first_payload.len, zstd_dictionary_set);
    try std.testing.expectEqualSlices(u8, zstd_first_payload, zstd_reusable_single_scratch_limited);
    try std.testing.expectError(error.OutputLimitExceeded, zstd_reusable_decoder.decodeChunksScratchLimitedWithDictionarySet(&zstd_single_chunks, zstd_single_join, zstd_first_payload.len - 1, zstd_dictionary_set));
    var zstd_reusable_single_appended: std.ArrayList(u8) = .empty;
    defer zstd_reusable_single_appended.deinit(std.testing.allocator);
    try zstd_reusable_single_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(zstd_first_payload.len, try zstd_reusable_decoder.decodeChunksAppendWithDictionarySet(&zstd_reusable_single_appended, &zstd_single_chunks, zstd_single_join, zstd_dictionary_set));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ zstd_first_payload, zstd_reusable_single_appended.items);
    zstd_reusable_single_appended.clearRetainingCapacity();
    try zstd_reusable_single_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(zstd_first_payload.len, try zstd_reusable_decoder.decodeChunksAppendLimitedWithDictionary(&zstd_reusable_single_appended, &zstd_single_chunks, zstd_single_join, zstd_first_payload.len, zstd_first_dict));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ zstd_first_payload, zstd_reusable_single_appended.items);
    zstd_reusable_single_appended.clearRetainingCapacity();
    try std.testing.expectError(error.SizeMismatch, zstd_reusable_decoder.decodeChunksAppendExactSizeWithDictionarySet(&zstd_reusable_single_appended, &zstd_single_chunks, zstd_single_join, zstd_dictionary_set, zstd_first_payload.len - 1));
    @memset(&zstd_single_chunked_into, 0);
    try std.testing.expectEqual(zstd_first_payload.len, try zstd_reusable_decoder.decodeChunksIntoSliceWithDictionarySet(&zstd_single_chunks, zstd_single_join, &zstd_single_chunked_into, zstd_dictionary_set));
    try std.testing.expectEqualSlices(u8, zstd_first_payload, &zstd_single_chunked_into);
    const zstd_reusable_scratch = try zstd_reusable_decoder.decodeConcatenatedScratchWithDictionarySet(zstd_stream.items, zstd_dictionary_set);
    try std.testing.expectEqualSlices(u8, zstd_expected, zstd_reusable_scratch);
    try std.testing.expectEqual(zstd_first_payload.len, try zstdDecodedRawOrRleFrameSizeWithDictionary(zstd_first.frame, zstd_first_dict));
    try std.testing.expectEqual(zstd_first_payload.len, try zstdDecodedRawOrRleFrameSizeLimitedWithDictionary(zstd_first.frame, zstd_first_payload.len, zstd_first_dict));
    try std.testing.expectError(error.OutputLimitExceeded, zstdDecodedRawOrRleFrameSizeLimitedWithDictionary(zstd_first.frame, zstd_first_payload.len - 1, zstd_first_dict));
    try std.testing.expectEqual(zstd_expected.len, try zstdDecodedRawOrRleFrameSizeWithDictionarySet(zstd_stream.items, zstd_dictionary_set));
    try std.testing.expectEqual(zstd_expected.len, try zstdDecodedRawOrRleFrameSizeLimitedWithDictionarySet(zstd_stream.items, zstd_expected.len, zstd_dictionary_set));
    try std.testing.expectError(error.OutputLimitExceeded, zstdDecodedRawOrRleFrameSizeLimitedWithDictionarySet(zstd_stream.items, zstd_expected.len - 1, zstd_dictionary_set));
    try std.testing.expectEqual(zstd_first_payload.len, try zstd_reusable_decoder.decodedSizeWithDictionarySet(zstd_first.frame, zstd_dictionary_set));
    try std.testing.expectEqual(zstd_first_payload.len, try zstd_reusable_decoder.decodedSizeLimitedWithDictionarySet(zstd_first.frame, zstd_first_payload.len, zstd_dictionary_set));
    try std.testing.expectError(error.OutputLimitExceeded, zstd_reusable_decoder.decodedSizeLimitedWithDictionarySet(zstd_first.frame, zstd_first_payload.len - 1, zstd_dictionary_set));
    try std.testing.expectEqual(zstd_expected.len, try zstd_reusable_decoder.decodedConcatenatedSizeWithDictionarySet(zstd_stream.items, zstd_dictionary_set));
    try std.testing.expectEqual(zstd_expected.len, try zstd_reusable_decoder.decodedConcatenatedSizeLimitedWithDictionarySet(zstd_stream.items, zstd_expected.len, zstd_dictionary_set));
    try std.testing.expectError(error.OutputLimitExceeded, zstd_reusable_decoder.decodedConcatenatedSizeLimitedWithDictionarySet(zstd_stream.items, zstd_expected.len - 1, zstd_dictionary_set));
    var zstd_reusable_append: std.ArrayList(u8) = .empty;
    defer zstd_reusable_append.deinit(std.testing.allocator);
    try zstd_reusable_append.appendSlice(std.testing.allocator, "prefix:");
    const zstd_reusable_appended = try zstd_reusable_decoder.decodeConcatenatedAppendWithDictionarySet(&zstd_reusable_append, zstd_stream.items, zstd_dictionary_set);
    try std.testing.expectEqual(zstd_expected.len, zstd_reusable_appended);
    try std.testing.expectEqualSlices(u8, "prefix:", zstd_reusable_append.items[0.."prefix:".len]);
    try std.testing.expectEqualSlices(u8, zstd_expected, zstd_reusable_append.items["prefix:".len..]);
    const zstd_exact_decoded = try zstdDecodeNativeConcatenatedFrameAllocWithDictionarySetExactSize(std.testing.allocator, zstd_stream.items, zstd_dictionary_set, zstd_expected.len);
    defer std.testing.allocator.free(zstd_exact_decoded);
    try std.testing.expectEqualSlices(u8, zstd_expected, zstd_exact_decoded);
    try std.testing.expectError(error.SizeMismatch, zstdDecodeNativeConcatenatedFrameAllocWithDictionarySetExactSize(
        std.testing.allocator,
        zstd_stream.items,
        zstd_dictionary_set,
        zstd_expected.len - 1,
    ));
    try std.testing.expectEqual(zstd_expected.len, try zstdDecodedNativeConcatenatedFrameSizeWithDictionarySet(zstd_stream.items, zstd_dictionary_set));
    var zstd_into: [zstd_expected.len]u8 = undefined;
    try std.testing.expectEqual(zstd_expected.len, try zstdDecodeNativeConcatenatedFrameIntoWithDictionarySet(zstd_stream.items, &zstd_into, zstd_dictionary_set));
    try std.testing.expectEqualSlices(u8, zstd_expected, &zstd_into);
    @memset(&zstd_into, 0);
    const zstd_reusable_into = try zstd_reusable_decoder.decodeConcatenatedIntoSliceWithDictionarySet(zstd_stream.items, &zstd_into, zstd_dictionary_set);
    try std.testing.expectEqual(zstd_expected.len, zstd_reusable_into);
    try std.testing.expectEqualSlices(u8, zstd_expected, &zstd_into);
    const zstd_chunks = [_][]const u8{
        zstd_stream.items[0..7],
        zstd_stream.items[7 .. zstd_stream.items.len - 4],
        zstd_stream.items[zstd_stream.items.len - 4 ..],
    };
    const zstd_join = try std.testing.allocator.alloc(u8, zstd_stream.items.len);
    defer std.testing.allocator.free(zstd_join);
    const zstd_chunked = try zstdDecodeRawOrRleFrameChunksAllocWithDictionarySet(std.testing.allocator, &zstd_chunks, zstd_join, zstd_dictionary_set);
    defer std.testing.allocator.free(zstd_chunked);
    try std.testing.expectEqualSlices(u8, zstd_expected, zstd_chunked);
    var zstd_chunked_appended: std.ArrayList(u8) = .empty;
    defer zstd_chunked_appended.deinit(std.testing.allocator);
    try zstd_chunked_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(zstd_expected.len, try zstdDecodeNativeConcatenatedFrameChunksAppendWithDictionarySet(std.testing.allocator, &zstd_chunked_appended, &zstd_chunks, zstd_join, zstd_dictionary_set));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ zstd_expected, zstd_chunked_appended.items);
    zstd_chunked_appended.clearRetainingCapacity();
    try zstd_chunked_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(zstd_expected.len, try zstdDecodeNativeConcatenatedFrameChunksAppendExactSizeWithDictionarySet(std.testing.allocator, &zstd_chunked_appended, &zstd_chunks, zstd_join, zstd_dictionary_set, zstd_expected.len));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ zstd_expected, zstd_chunked_appended.items);
    zstd_chunked_appended.clearRetainingCapacity();
    try std.testing.expectError(error.SizeMismatch, zstdDecodeNativeConcatenatedFrameChunksAppendExactSizeWithDictionarySet(std.testing.allocator, &zstd_chunked_appended, &zstd_chunks, zstd_join, zstd_dictionary_set, zstd_expected.len - 1));
    zstd_chunked_appended.clearRetainingCapacity();
    try zstd_chunked_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(zstd_expected.len, try zstdDecodeNativeConcatenatedFrameChunksAppendLimitedWithDictionarySet(std.testing.allocator, &zstd_chunked_appended, &zstd_chunks, zstd_join, zstd_expected.len, zstd_dictionary_set));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ zstd_expected, zstd_chunked_appended.items);
    zstd_chunked_appended.clearRetainingCapacity();
    try std.testing.expectError(error.OutputLimitExceeded, zstdDecodeNativeConcatenatedFrameChunksAppendLimitedWithDictionarySet(std.testing.allocator, &zstd_chunked_appended, &zstd_chunks, zstd_join, zstd_expected.len - 1, zstd_dictionary_set));
    const zstd_reusable_chunked_exact = try zstd_reusable_decoder.decodeConcatenatedChunksAllocExactSizeWithDictionarySet(&zstd_chunks, zstd_join, zstd_dictionary_set, zstd_expected.len);
    defer std.testing.allocator.free(zstd_reusable_chunked_exact);
    try std.testing.expectEqualSlices(u8, zstd_expected, zstd_reusable_chunked_exact);
    try std.testing.expectError(error.SizeMismatch, zstd_reusable_decoder.decodeConcatenatedChunksAllocExactSizeWithDictionarySet(&zstd_chunks, zstd_join, zstd_dictionary_set, zstd_expected.len - 1));
    try std.testing.expectEqual(zstd_expected.len, try zstdDecodedRawOrRleFrameChunksSizeWithDictionarySet(&zstd_chunks, zstd_join, zstd_dictionary_set));
    try std.testing.expectEqual(zstd_expected.len, try zstdDecodedRawOrRleFrameChunksSizeLimitedWithDictionarySet(&zstd_chunks, zstd_join, zstd_expected.len, zstd_dictionary_set));
    try std.testing.expectError(error.OutputLimitExceeded, zstdDecodedRawOrRleFrameChunksSizeLimitedWithDictionarySet(&zstd_chunks, zstd_join, zstd_expected.len - 1, zstd_dictionary_set));
    try std.testing.expectEqual(zstd_expected.len, try zstdDecodedNativeConcatenatedFrameChunksSizeWithDictionarySet(&zstd_chunks, zstd_join, zstd_dictionary_set));
    try std.testing.expectEqual(zstd_expected.len, try zstdDecodedNativeConcatenatedFrameChunksSizeLimitedWithDictionarySet(&zstd_chunks, zstd_join, zstd_expected.len, zstd_dictionary_set));
    try std.testing.expectError(error.OutputLimitExceeded, zstdDecodedNativeConcatenatedFrameChunksSizeLimitedWithDictionarySet(&zstd_chunks, zstd_join, zstd_expected.len - 1, zstd_dictionary_set));
    try std.testing.expectEqual(zstd_expected.len, try zstd_reusable_decoder.decodedConcatenatedChunksSizeWithDictionarySet(&zstd_chunks, zstd_join, zstd_dictionary_set));
    try std.testing.expectEqual(zstd_expected.len, try zstd_reusable_decoder.decodedConcatenatedChunksSizeLimitedWithDictionarySet(&zstd_chunks, zstd_join, zstd_expected.len, zstd_dictionary_set));
    var zstd_chunked_into: [zstd_expected.len]u8 = undefined;
    try std.testing.expectEqual(zstd_expected.len, try zstdDecodeRawOrRleFrameChunksIntoWithDictionarySet(&zstd_chunks, zstd_join, &zstd_chunked_into, zstd_dictionary_set));
    try std.testing.expectEqualSlices(u8, zstd_expected, &zstd_chunked_into);
    const zstd_reusable_chunked_scratch = try zstd_reusable_decoder.decodeConcatenatedChunksScratchWithDictionarySet(&zstd_chunks, zstd_join, zstd_dictionary_set);
    try std.testing.expectEqualSlices(u8, zstd_expected, zstd_reusable_chunked_scratch);
    var zstd_reusable_chunked_append: std.ArrayList(u8) = .empty;
    defer zstd_reusable_chunked_append.deinit(std.testing.allocator);
    try zstd_reusable_chunked_append.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(zstd_expected.len, try zstd_reusable_decoder.decodeConcatenatedChunksAppendWithDictionarySet(&zstd_reusable_chunked_append, &zstd_chunks, zstd_join, zstd_dictionary_set));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ zstd_expected, zstd_reusable_chunked_append.items);
    zstd_reusable_chunked_append.clearRetainingCapacity();
    try zstd_reusable_chunked_append.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(zstd_expected.len, try zstd_reusable_decoder.decodeConcatenatedChunksAppendExactSizeWithDictionarySet(&zstd_reusable_chunked_append, &zstd_chunks, zstd_join, zstd_dictionary_set, zstd_expected.len));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ zstd_expected, zstd_reusable_chunked_append.items);
    zstd_reusable_chunked_append.clearRetainingCapacity();
    try std.testing.expectError(error.SizeMismatch, zstd_reusable_decoder.decodeConcatenatedChunksAppendExactSizeWithDictionarySet(&zstd_reusable_chunked_append, &zstd_chunks, zstd_join, zstd_dictionary_set, zstd_expected.len - 1));
    @memset(&zstd_chunked_into, 0);
    try std.testing.expectEqual(zstd_expected.len, try zstd_reusable_decoder.decodeConcatenatedChunksIntoSliceWithDictionarySet(&zstd_chunks, zstd_join, &zstd_chunked_into, zstd_dictionary_set));
    try std.testing.expectEqualSlices(u8, zstd_expected, &zstd_chunked_into);
    try std.testing.expectError(error.OutputTooSmall, zstdDecodeRawOrRleFrameChunksAllocWithDictionarySet(std.testing.allocator, &zstd_chunks, zstd_join[0 .. zstd_join.len - 1], zstd_dictionary_set));
    try std.testing.expectError(error.NeedDictionary, zstdDecodeNativeConcatenatedFrameAllocWithDictionarySet(
        std.testing.allocator,
        zstd_stream.items,
        ZstdNativeDictionarySet.init(&.{zstd_first_dict}),
    ));
}

test "root exports png primitives" {
    try png_exports.smokeRootExports(@This());
}

test "root exports chunked compatibility decode helpers" {
    // Keep the README/API-sketch split-input helpers tied to root exports. These
    // references are intentionally compile-time only: codec behavior is covered
    // in deflate.zig, while this test catches accidental public API drift.
    _ = RawDeflateEncoder;
    _ = ZlibEncoder;
    _ = GzipEncoder;
    _ = RawDeflateDecoder;
    _ = DeflateError;
    try std.testing.expectEqual(@as(usize, std.math.maxInt(u16)), maxStoredDeflateBlockLen);
    _ = DeflateDecodeResult;
    _ = DeflateOwnedDecodeResult;
    _ = RawDeflateProbeResult;
    _ = DecodeProbeResult;
    _ = parseRawDeflateHeaderInfoFromChunks;
    _ = decodeRawDeflateChunks;
    _ = decodeRawDeflateChunksWithDictionary;
    _ = decodeRawDeflateChunksAlloc;
    _ = decodeRawDeflateChunksAllocExactSize;
    _ = decodeRawDeflateChunksAllocLimited;
    _ = decodeRawDeflateChunksAllocWithDictionary;
    _ = decodeRawDeflateChunksAllocWithDictionaryExactSize;
    _ = decodeRawDeflateChunksAllocWithDictionaryLimited;
    _ = decodeRawDeflateAppend;
    _ = decodeRawDeflateAppendWithDictionary;
    _ = decodeRawDeflateAppendExactSize;
    _ = decodeRawDeflateAppendWithDictionaryExactSize;
    _ = decodeRawDeflateAppendLimited;
    _ = decodeRawDeflateAppendWithDictionaryLimited;
    _ = decodeRawDeflateChunksAppend;
    _ = decodeRawDeflateChunksAppendWithDictionary;
    _ = decodeRawDeflateChunksAppendExactSize;
    _ = decodeRawDeflateChunksAppendWithDictionaryExactSize;
    _ = decodeRawDeflateChunksAppendLimited;
    _ = decodeRawDeflateChunksAppendWithDictionaryLimited;
    _ = decodedRawDeflateSize;
    _ = decodedRawDeflateSizeWithDictionary;
    _ = decodedRawDeflateChunksSize;
    _ = decodedRawDeflateChunksSizeWithDictionary;
    _ = probeRawDeflate;
    _ = probeRawDeflateWithDictionary;
    _ = probeRawDeflateExactSize;
    _ = probeRawDeflateWithDictionaryExactSize;
    _ = probeRawDeflateChunks;
    _ = probeRawDeflateChunksWithDictionary;
    _ = probeRawDeflateChunksExactSize;
    _ = probeRawDeflateChunksWithDictionaryExactSize;
    _ = encodeRawStoredDeflateAppend;
    _ = encodeRawDynamicTokensAlloc;
    _ = encodeRawFixedTokensAlloc;
    _ = rawStoredDeflateEncodedSize;
    _ = rawStoredDeflateChunksEncodedSize;
    _ = encodeRawStoredDeflateChunks;
    _ = encodeRawStoredDeflateChunksAlloc;
    _ = encodeRawStoredDeflateChunksAppend;
    _ = decodeRawStoredDeflateAllocPartial;
    _ = decodeRawFixedAllocPartial;
    _ = decodeRawDynamicAllocPartial;
    _ = decodeRawDeflateAllocPartial;

    _ = decodeZlibChunks;
    _ = decodeZlibChunksWithDictionary;
    _ = decodeZlibChunksWithOptions;
    _ = decodeZlibChunksWithDictionaryAndOptions;
    _ = decodeZlibChunksInto;
    _ = decodeZlibChunksIntoWithDictionary;
    _ = decodeZlibChunksIntoWithOptions;
    _ = decodeZlibChunksIntoWithDictionaryAndOptions;
    _ = decodeZlibChunksAlloc;
    _ = decodeZlibChunksAllocExactSize;
    _ = decodeZlibChunksAllocLimited;
    _ = decodeZlibChunksAllocWithDictionary;
    _ = decodeZlibChunksAllocWithDictionaryExactSize;
    _ = decodeZlibChunksAllocWithDictionaryLimited;
    _ = decodeZlibChunksAllocWithOptions;
    _ = decodeZlibChunksAllocWithOptionsExactSize;
    _ = decodeZlibChunksAllocWithOptionsLimited;
    _ = decodeZlibChunksAllocWithDictionaryAndOptions;
    _ = decodeZlibChunksAllocWithDictionaryAndOptionsExactSize;
    _ = decodeZlibChunksAllocWithDictionaryAndOptionsLimited;
    _ = decodeZlibAppend;
    _ = decodeZlibAppendWithDictionary;
    _ = decodeZlibAppendWithOptions;
    _ = decodeZlibAppendWithDictionaryAndOptions;
    _ = decodeZlibAppendExactSize;
    _ = decodeZlibAppendWithDictionaryExactSize;
    _ = decodeZlibAppendWithOptionsExactSize;
    _ = decodeZlibAppendWithDictionaryAndOptionsExactSize;
    _ = decodeZlibAppendLimited;
    _ = decodeZlibAppendWithDictionaryLimited;
    _ = decodeZlibAppendWithOptionsLimited;
    _ = decodeZlibAppendWithDictionaryAndOptionsLimited;
    _ = decodeZlibChunksAppend;
    _ = decodeZlibChunksAppendWithDictionary;
    _ = decodeZlibChunksAppendWithOptions;
    _ = decodeZlibChunksAppendWithDictionaryAndOptions;
    _ = decodeZlibChunksAppendExactSize;
    _ = decodeZlibChunksAppendWithDictionaryExactSize;
    _ = decodeZlibChunksAppendWithOptionsExactSize;
    _ = decodeZlibChunksAppendWithDictionaryAndOptionsExactSize;
    _ = decodeZlibChunksAppendLimited;
    _ = decodeZlibChunksAppendWithDictionaryLimited;
    _ = decodeZlibChunksAppendWithOptionsLimited;
    _ = decodeZlibChunksAppendWithDictionaryAndOptionsLimited;
    _ = decodeZlibConcatenatedAppend;
    _ = decodeZlibConcatenatedAppendWithDictionary;
    _ = decodeZlibConcatenatedAppendWithOptions;
    _ = decodeZlibConcatenatedAppendWithDictionaryAndOptions;
    _ = decodeZlibConcatenatedAppendExactSize;
    _ = decodeZlibConcatenatedAppendWithDictionaryExactSize;
    _ = decodeZlibConcatenatedAppendWithOptionsExactSize;
    _ = decodeZlibConcatenatedAppendWithDictionaryAndOptionsExactSize;
    _ = decodeZlibConcatenatedAppendLimited;
    _ = decodeZlibConcatenatedAppendWithDictionaryLimited;
    _ = decodeZlibConcatenatedAppendWithOptionsLimited;
    _ = decodeZlibConcatenatedAppendWithDictionaryAndOptionsLimited;
    _ = decodeZlibConcatenatedChunksAppend;
    _ = decodeZlibConcatenatedChunksAppendWithDictionary;
    _ = decodeZlibConcatenatedChunksAppendWithOptions;
    _ = decodeZlibConcatenatedChunksAppendWithDictionaryAndOptions;
    _ = decodeZlibConcatenatedChunksAppendExactSize;
    _ = decodeZlibConcatenatedChunksAppendWithDictionaryExactSize;
    _ = decodeZlibConcatenatedChunksAppendWithOptionsExactSize;
    _ = decodeZlibConcatenatedChunksAppendWithDictionaryAndOptionsExactSize;
    _ = decodeZlibConcatenatedChunksAppendLimited;
    _ = decodeZlibConcatenatedChunksAppendWithDictionaryLimited;
    _ = decodeZlibConcatenatedChunksAppendWithOptionsLimited;
    _ = decodeZlibConcatenatedChunksAppendWithDictionaryAndOptionsLimited;
    _ = probeZlib;
    _ = probeZlibWithDictionary;
    _ = probeZlibWithOptions;
    _ = probeZlibWithDictionaryAndOptions;
    _ = probeZlibExactSize;
    _ = probeZlibWithDictionaryExactSize;
    _ = probeZlibWithOptionsExactSize;
    _ = probeZlibWithDictionaryAndOptionsExactSize;
    _ = probeZlibChunks;
    _ = probeZlibChunksWithDictionary;
    _ = probeZlibChunksWithOptions;
    _ = probeZlibChunksWithDictionaryAndOptions;
    _ = probeZlibChunksExactSize;
    _ = probeZlibChunksWithDictionaryExactSize;
    _ = probeZlibChunksWithOptionsExactSize;
    _ = probeZlibChunksWithDictionaryAndOptionsExactSize;
    _ = probeZlibConcatenated;
    _ = probeZlibConcatenatedWithDictionary;
    _ = probeZlibConcatenatedWithOptions;
    _ = probeZlibConcatenatedWithDictionaryAndOptions;
    _ = probeZlibConcatenatedExactSize;
    _ = probeZlibConcatenatedWithDictionaryExactSize;
    _ = probeZlibConcatenatedWithOptionsExactSize;
    _ = probeZlibConcatenatedWithDictionaryAndOptionsExactSize;
    _ = probeZlibConcatenatedChunks;
    _ = probeZlibConcatenatedChunksWithDictionary;
    _ = probeZlibConcatenatedChunksWithOptions;
    _ = probeZlibConcatenatedChunksWithDictionaryAndOptions;
    _ = probeZlibConcatenatedChunksExactSize;
    _ = probeZlibConcatenatedChunksWithDictionaryExactSize;
    _ = probeZlibConcatenatedChunksWithOptionsExactSize;
    _ = probeZlibConcatenatedChunksWithDictionaryAndOptionsExactSize;
    _ = decodedZlibSize;
    _ = decodedZlibSizeWithOptions;
    _ = decodedZlibSizeWithDictionary;
    _ = decodedZlibSizeWithDictionaryAndOptions;
    _ = decodedZlibChunksSize;
    _ = decodedZlibChunksSizeWithOptions;
    _ = decodedZlibChunksSizeWithDictionary;
    _ = decodedZlibChunksSizeWithDictionaryAndOptions;
    _ = decodedZlibConcatenatedSize;
    _ = decodedZlibConcatenatedSizeWithOptions;
    _ = decodedZlibConcatenatedSizeWithDictionary;
    _ = decodedZlibConcatenatedSizeWithDictionaryAndOptions;
    _ = decodedZlibConcatenatedChunksSize;
    _ = decodedZlibConcatenatedChunksSizeWithOptions;
    _ = decodedZlibConcatenatedChunksSizeWithDictionary;
    _ = decodedZlibConcatenatedChunksSizeWithDictionaryAndOptions;
    _ = parseZlibHeaderInfoFromChunks;
    _ = inspectZlibStreamFromChunksAlloc;
    _ = inspectZlibStreamFromChunksAllocLimited;
    _ = inspectZlibStreamFromChunksAllocWithDictionary;
    _ = inspectZlibStreamFromChunksAllocWithDictionaryLimited;

    _ = decodeGzipAppend;
    _ = decodeGzipAppendWithOptions;
    _ = decodeGzipAppendExactSize;
    _ = decodeGzipAppendWithOptionsExactSize;
    _ = decodeGzipAppendLimited;
    _ = decodeGzipAppendWithOptionsLimited;
    _ = decodeGzipChunksAppend;
    _ = decodeGzipChunksAppendWithOptions;
    _ = decodeGzipChunksAppendExactSize;
    _ = decodeGzipChunksAppendWithOptionsExactSize;
    _ = decodeGzipChunksAppendLimited;
    _ = decodeGzipChunksAppendWithOptionsLimited;
    _ = decodeGzipConcatenatedAppend;
    _ = decodeGzipConcatenatedAppendWithOptions;
    _ = decodeGzipConcatenatedAppendExactSize;
    _ = decodeGzipConcatenatedAppendWithOptionsExactSize;
    _ = decodeGzipConcatenatedAppendLimited;
    _ = decodeGzipConcatenatedAppendWithOptionsLimited;
    _ = decodeGzipConcatenatedChunksAppend;
    _ = decodeGzipConcatenatedChunksAppendWithOptions;
    _ = decodeGzipConcatenatedChunksAppendExactSize;
    _ = decodeGzipConcatenatedChunksAppendWithOptionsExactSize;
    _ = decodeGzipConcatenatedChunksAppendLimited;
    _ = decodeGzipConcatenatedChunksAppendWithOptionsLimited;
    _ = probeGzip;
    _ = probeGzipWithOptions;
    _ = probeGzipExactSize;
    _ = probeGzipWithOptionsExactSize;
    _ = probeGzipChunks;
    _ = probeGzipChunksWithOptions;
    _ = probeGzipChunksExactSize;
    _ = probeGzipChunksWithOptionsExactSize;
    _ = probeGzipConcatenated;
    _ = probeGzipConcatenatedWithOptions;
    _ = probeGzipConcatenatedExactSize;
    _ = probeGzipConcatenatedWithOptionsExactSize;
    _ = probeGzipConcatenatedChunks;
    _ = probeGzipConcatenatedChunksWithOptions;
    _ = probeGzipConcatenatedChunksExactSize;
    _ = probeGzipConcatenatedChunksWithOptionsExactSize;
    _ = decodedGzipSize;
    _ = decodedGzipSizeWithOptions;
    _ = decodedGzipChunksSize;
    _ = decodedGzipChunksSizeWithOptions;
    _ = decodedGzipConcatenatedSize;
    _ = decodedGzipConcatenatedSizeWithOptions;
    _ = decodedGzipConcatenatedChunksSize;
    _ = decodedGzipConcatenatedChunksSizeWithOptions;
    _ = decodeGzipChunks;
    _ = decodeGzipChunksWithOptions;
    _ = decodeGzipChunksAlloc;
    _ = decodeGzipChunksAllocExactSize;
    _ = decodeGzipChunksAllocLimited;
    _ = decodeGzipChunksAllocWithOptions;
    _ = decodeGzipChunksAllocWithOptionsExactSize;
    _ = decodeGzipChunksAllocWithOptionsLimited;
    _ = decodeGzipConcatenatedChunks;
    _ = decodeGzipConcatenatedChunksWithOptions;
    _ = decodeGzipConcatenatedChunksAlloc;
    _ = decodeGzipConcatenatedChunksAllocExactSize;
    _ = decodeGzipConcatenatedChunksAllocLimited;
    _ = decodeGzipConcatenatedChunksAllocWithOptions;
    _ = decodeGzipConcatenatedChunksAllocWithOptionsExactSize;
    _ = decodeGzipConcatenatedChunksAllocWithOptionsLimited;
    _ = parseGzipHeaderInfoFromChunks;
    _ = inspectGzipMemberFromChunksAlloc;
    _ = inspectGzipMemberFromChunksAllocLimited;
    _ = encodeZlibStoredAppend;
    _ = encodeZlibStoredWithDictionaryAppend;
    _ = zlibStoredEncodedSize;
    _ = zlibStoredWithDictionaryEncodedSize;
    _ = zlibStoredChunksEncodedSize;
    _ = zlibStoredWithDictionaryChunksEncodedSize;
    _ = encodeZlibStoredChunks;
    _ = encodeZlibStoredWithDictionaryChunks;
    _ = encodeZlibStoredChunksAlloc;
    _ = encodeZlibStoredWithDictionaryChunksAlloc;
    _ = encodeZlibStoredChunksAppend;
    _ = encodeZlibStoredWithDictionaryChunksAppend;
    _ = encodeGzipStoredAppend;
    _ = encodeGzipStoredWithHeaderAppend;
    _ = gzipStoredEncodedSize;
    _ = gzipStoredChunksEncodedSize;
    _ = gzipStoredChunksEncodedSizeWithHeader;
    _ = encodeGzipStoredChunks;
    _ = encodeGzipStoredChunksWithHeader;
    _ = encodeGzipStoredChunksAlloc;
    _ = encodeGzipStoredChunksWithHeaderAlloc;
    _ = encodeGzipStoredChunksAppend;
    _ = encodeGzipStoredChunksWithHeaderAppend;
}

test "root raw deflate append decode helpers preserve prefixes" {
    const payload = "root raw deflate append payload " ** 2;
    const encoded = try encodeRawBestAlloc(std.testing.allocator, payload, .{});
    defer std.testing.allocator.free(encoded);

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(std.testing.allocator);
    try appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(payload.len, try decodeRawDeflateAppend(std.testing.allocator, &appended, encoded));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ payload, appended.items);

    appended.clearRetainingCapacity();
    try appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(payload.len, try decodeRawDeflateAppendExactSize(std.testing.allocator, &appended, encoded, payload.len));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ payload, appended.items);
    try std.testing.expectError(error.SizeMismatch, decodeRawDeflateAppendExactSize(std.testing.allocator, &appended, encoded, payload.len + 1));

    appended.clearRetainingCapacity();
    try appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(payload.len, try decodeRawDeflateAppendLimited(std.testing.allocator, &appended, encoded, payload.len));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ payload, appended.items);
    try std.testing.expectError(error.OutputLimitExceeded, decodeRawDeflateAppendLimited(std.testing.allocator, &appended, encoded, payload.len - 1));

    const chunks = [_][]const u8{
        encoded[0..1],
        encoded[1..@min(encoded.len, 13)],
        encoded[@min(encoded.len, 13)..],
    };
    const join = try std.testing.allocator.alloc(u8, encoded.len);
    defer std.testing.allocator.free(join);

    appended.clearRetainingCapacity();
    try appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(payload.len, try decodeRawDeflateChunksAppend(std.testing.allocator, &appended, &chunks, join));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ payload, appended.items);

    appended.clearRetainingCapacity();
    try appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(payload.len, try decodeRawDeflateChunksAppendExactSize(std.testing.allocator, &appended, &chunks, join, payload.len));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ payload, appended.items);
    try std.testing.expectError(error.SizeMismatch, decodeRawDeflateChunksAppendExactSize(std.testing.allocator, &appended, &chunks, join, payload.len - 1));

    appended.clearRetainingCapacity();
    try appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(payload.len, try decodeRawDeflateChunksAppendLimited(std.testing.allocator, &appended, &chunks, join, payload.len));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ payload, appended.items);
    try std.testing.expectError(error.OutputLimitExceeded, decodeRawDeflateChunksAppendLimited(std.testing.allocator, &appended, &chunks, join, payload.len - 1));
}

test "root raw deflate token encoders round trip planned tokens" {
    const payload = "token-level root encode token-level root encode";
    const plan = try literalLz77PlanAlloc(std.testing.allocator, payload);
    defer plan.deinit(std.testing.allocator);

    const fixed = try encodeRawFixedTokensAlloc(std.testing.allocator, plan.tokens);
    defer std.testing.allocator.free(fixed);
    const fixed_decoded = try decodeRawDeflateAlloc(std.testing.allocator, fixed);
    defer std.testing.allocator.free(fixed_decoded);
    try std.testing.expectEqualSlices(u8, payload, fixed_decoded);

    const dynamic = try encodeRawDynamicTokensAlloc(std.testing.allocator, plan.tokens);
    defer std.testing.allocator.free(dynamic);
    const dynamic_decoded = try decodeRawDeflateAlloc(std.testing.allocator, dynamic);
    defer std.testing.allocator.free(dynamic_decoded);
    try std.testing.expectEqualSlices(u8, payload, dynamic_decoded);
}

test "root raw deflate partial alloc helpers report consumed input" {
    const trailing = "trailing bytes";

    const stored = try encodeRawStoredDeflateAlloc(std.testing.allocator, "stored partial payload");
    defer std.testing.allocator.free(stored);
    const stored_with_trailing = try std.mem.concat(std.testing.allocator, u8, &.{ stored, trailing });
    defer std.testing.allocator.free(stored_with_trailing);
    const stored_partial = try decodeRawStoredDeflateAllocPartial(std.testing.allocator, stored_with_trailing);
    defer stored_partial.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, stored.len), stored_partial.input_read);
    try std.testing.expectEqualSlices(u8, "stored partial payload", stored_partial.bytes);
    try std.testing.expectError(error.TrailingData, decodeRawStoredDeflateAlloc(std.testing.allocator, stored_with_trailing));

    const fixed = try encodeRawFixedDeflateAlloc(std.testing.allocator, "fixed partial payload");
    defer std.testing.allocator.free(fixed);
    const fixed_with_trailing = try std.mem.concat(std.testing.allocator, u8, &.{ fixed, trailing });
    defer std.testing.allocator.free(fixed_with_trailing);
    const fixed_partial = try decodeRawFixedAllocPartial(std.testing.allocator, fixed_with_trailing);
    defer fixed_partial.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, fixed.len), fixed_partial.input_read);
    try std.testing.expectEqualSlices(u8, "fixed partial payload", fixed_partial.bytes);
    try std.testing.expectError(error.TrailingData, decodeRawFixedAlloc(std.testing.allocator, fixed_with_trailing));

    const dynamic = try encodeRawDynamicLiteralAlloc(std.testing.allocator, "dynamic partial payload");
    defer std.testing.allocator.free(dynamic);
    const dynamic_with_trailing = try std.mem.concat(std.testing.allocator, u8, &.{ dynamic, trailing });
    defer std.testing.allocator.free(dynamic_with_trailing);
    const dynamic_partial = try decodeRawDynamicAllocPartial(std.testing.allocator, dynamic_with_trailing);
    defer dynamic_partial.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, dynamic.len), dynamic_partial.input_read);
    try std.testing.expectEqualSlices(u8, "dynamic partial payload", dynamic_partial.bytes);
    try std.testing.expectError(error.TrailingData, decodeRawDynamicAlloc(std.testing.allocator, dynamic_with_trailing));

    const auto_partial = try decodeRawDeflateAllocPartial(std.testing.allocator, dynamic_with_trailing);
    defer auto_partial.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, dynamic.len), auto_partial.input_read);
    try std.testing.expectEqualSlices(u8, "dynamic partial payload", auto_partial.bytes);
    try std.testing.expectError(error.TrailingData, decodeRawDeflateAlloc(std.testing.allocator, dynamic_with_trailing));
}

test "root stored deflate wrapper append encode helpers preserve prefixes" {
    const payload = "root stored wrapper append encode payload " ** 2;
    const preset_dictionary = "root stored wrapper dictionary";
    const chunks = [_][]const u8{
        payload[0..9],
        payload[9..37],
        payload[37..],
    };

    const raw_expected = try encodeRawStoredDeflateAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(raw_expected);
    var raw_appended: std.ArrayList(u8) = .empty;
    defer raw_appended.deinit(std.testing.allocator);
    try raw_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(raw_expected.len, try encodeRawStoredDeflateAppend(std.testing.allocator, &raw_appended, payload));
    try std.testing.expectEqualSlices(u8, "prefix:", raw_appended.items[0.."prefix:".len]);
    try std.testing.expectEqualSlices(u8, raw_expected, raw_appended.items["prefix:".len..]);
    const raw_decoded = try decodeRawDeflateAlloc(std.testing.allocator, raw_appended.items["prefix:".len..]);
    defer std.testing.allocator.free(raw_decoded);
    try std.testing.expectEqualSlices(u8, payload, raw_decoded);
    try std.testing.expectEqual(raw_expected.len, try rawStoredDeflateEncodedSize(payload.len));
    try std.testing.expectEqual(raw_expected.len, try rawStoredDeflateChunksEncodedSize(&chunks));
    const raw_chunks = try encodeRawStoredDeflateChunksAlloc(std.testing.allocator, &chunks);
    defer std.testing.allocator.free(raw_chunks);
    try std.testing.expectEqualSlices(u8, raw_expected, raw_chunks);
    var raw_chunks_appended: std.ArrayList(u8) = .empty;
    defer raw_chunks_appended.deinit(std.testing.allocator);
    try raw_chunks_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(raw_expected.len, try encodeRawStoredDeflateChunksAppend(std.testing.allocator, &raw_chunks_appended, &chunks));
    try std.testing.expectEqualSlices(u8, raw_expected, raw_chunks_appended.items["prefix:".len..]);
    const raw_chunks_into = try std.testing.allocator.alloc(u8, raw_expected.len);
    defer std.testing.allocator.free(raw_chunks_into);
    try std.testing.expectEqual(raw_expected.len, try encodeRawStoredDeflateChunks(&chunks, raw_chunks_into));
    try std.testing.expectEqualSlices(u8, raw_expected, raw_chunks_into);
    try std.testing.expectError(error.OutputTooSmall, encodeRawStoredDeflateChunks(&chunks, raw_chunks_into[0 .. raw_expected.len - 1]));

    const zlib_expected = try encodeZlibStoredAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(zlib_expected);
    var zlib_appended: std.ArrayList(u8) = .empty;
    defer zlib_appended.deinit(std.testing.allocator);
    try zlib_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(zlib_expected.len, try encodeZlibStoredAppend(std.testing.allocator, &zlib_appended, payload));
    try std.testing.expectEqualSlices(u8, "prefix:", zlib_appended.items[0.."prefix:".len]);
    try std.testing.expectEqualSlices(u8, zlib_expected, zlib_appended.items["prefix:".len..]);
    const zlib_decoded = try decodeZlibStoredAlloc(std.testing.allocator, zlib_appended.items["prefix:".len..]);
    defer std.testing.allocator.free(zlib_decoded);
    try std.testing.expectEqualSlices(u8, payload, zlib_decoded);
    try std.testing.expectEqual(zlib_expected.len, try zlibStoredEncodedSize(payload.len));
    try std.testing.expectEqual(zlib_expected.len, try zlibStoredChunksEncodedSize(&chunks));
    const zlib_chunks = try encodeZlibStoredChunksAlloc(std.testing.allocator, &chunks);
    defer std.testing.allocator.free(zlib_chunks);
    try std.testing.expectEqualSlices(u8, zlib_expected, zlib_chunks);
    var zlib_chunks_appended: std.ArrayList(u8) = .empty;
    defer zlib_chunks_appended.deinit(std.testing.allocator);
    try zlib_chunks_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(zlib_expected.len, try encodeZlibStoredChunksAppend(std.testing.allocator, &zlib_chunks_appended, &chunks));
    try std.testing.expectEqualSlices(u8, zlib_expected, zlib_chunks_appended.items["prefix:".len..]);
    const zlib_chunks_into = try std.testing.allocator.alloc(u8, zlib_expected.len);
    defer std.testing.allocator.free(zlib_chunks_into);
    try std.testing.expectEqual(zlib_expected.len, try encodeZlibStoredChunks(&chunks, zlib_chunks_into));
    try std.testing.expectEqualSlices(u8, zlib_expected, zlib_chunks_into);

    const zlib_dict_expected = try encodeZlibStoredWithDictionaryAlloc(std.testing.allocator, payload, preset_dictionary);
    defer std.testing.allocator.free(zlib_dict_expected);
    var zlib_dict_appended: std.ArrayList(u8) = .empty;
    defer zlib_dict_appended.deinit(std.testing.allocator);
    try zlib_dict_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(zlib_dict_expected.len, try encodeZlibStoredWithDictionaryAppend(std.testing.allocator, &zlib_dict_appended, payload, preset_dictionary));
    try std.testing.expectEqualSlices(u8, "prefix:", zlib_dict_appended.items[0.."prefix:".len]);
    try std.testing.expectEqualSlices(u8, zlib_dict_expected, zlib_dict_appended.items["prefix:".len..]);
    const zlib_dict_decoded = try decodeZlibStoredAllocWithDictionary(std.testing.allocator, zlib_dict_appended.items["prefix:".len..], preset_dictionary);
    defer std.testing.allocator.free(zlib_dict_decoded);
    try std.testing.expectEqualSlices(u8, payload, zlib_dict_decoded);
    try std.testing.expectEqual(zlib_dict_expected.len, try zlibStoredWithDictionaryEncodedSize(payload.len));
    try std.testing.expectEqual(zlib_dict_expected.len, try zlibStoredWithDictionaryChunksEncodedSize(&chunks));
    const zlib_dict_chunks = try encodeZlibStoredWithDictionaryChunksAlloc(std.testing.allocator, &chunks, preset_dictionary);
    defer std.testing.allocator.free(zlib_dict_chunks);
    try std.testing.expectEqualSlices(u8, zlib_dict_expected, zlib_dict_chunks);
    var zlib_dict_chunks_appended: std.ArrayList(u8) = .empty;
    defer zlib_dict_chunks_appended.deinit(std.testing.allocator);
    try zlib_dict_chunks_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(zlib_dict_expected.len, try encodeZlibStoredWithDictionaryChunksAppend(std.testing.allocator, &zlib_dict_chunks_appended, &chunks, preset_dictionary));
    try std.testing.expectEqualSlices(u8, zlib_dict_expected, zlib_dict_chunks_appended.items["prefix:".len..]);
    const zlib_dict_chunks_into = try std.testing.allocator.alloc(u8, zlib_dict_expected.len);
    defer std.testing.allocator.free(zlib_dict_chunks_into);
    try std.testing.expectEqual(zlib_dict_expected.len, try encodeZlibStoredWithDictionaryChunks(&chunks, zlib_dict_chunks_into, preset_dictionary));
    try std.testing.expectEqualSlices(u8, zlib_dict_expected, zlib_dict_chunks_into);

    const gzip_expected = try encodeGzipStoredAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(gzip_expected);
    var gzip_appended: std.ArrayList(u8) = .empty;
    defer gzip_appended.deinit(std.testing.allocator);
    try gzip_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(gzip_expected.len, try encodeGzipStoredAppend(std.testing.allocator, &gzip_appended, payload));
    try std.testing.expectEqualSlices(u8, "prefix:", gzip_appended.items[0.."prefix:".len]);
    try std.testing.expectEqualSlices(u8, gzip_expected, gzip_appended.items["prefix:".len..]);
    const gzip_decoded = try decodeGzipStoredAlloc(std.testing.allocator, gzip_appended.items["prefix:".len..]);
    defer std.testing.allocator.free(gzip_decoded);
    try std.testing.expectEqualSlices(u8, payload, gzip_decoded);
    try std.testing.expectEqual(gzip_expected.len, try gzipStoredEncodedSize(payload.len));
    try std.testing.expectEqual(gzip_expected.len, try gzipStoredChunksEncodedSize(&chunks));
    const gzip_chunks = try encodeGzipStoredChunksAlloc(std.testing.allocator, &chunks);
    defer std.testing.allocator.free(gzip_chunks);
    try std.testing.expectEqualSlices(u8, gzip_expected, gzip_chunks);
    var gzip_chunks_appended: std.ArrayList(u8) = .empty;
    defer gzip_chunks_appended.deinit(std.testing.allocator);
    try gzip_chunks_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(gzip_expected.len, try encodeGzipStoredChunksAppend(std.testing.allocator, &gzip_chunks_appended, &chunks));
    try std.testing.expectEqualSlices(u8, gzip_expected, gzip_chunks_appended.items["prefix:".len..]);
    const gzip_chunks_into = try std.testing.allocator.alloc(u8, gzip_expected.len);
    defer std.testing.allocator.free(gzip_chunks_into);
    try std.testing.expectEqual(gzip_expected.len, try encodeGzipStoredChunks(&chunks, gzip_chunks_into));
    try std.testing.expectEqualSlices(u8, gzip_expected, gzip_chunks_into);

    const header_options: GzipHeaderOptions = .{
        .filename = "stored-append.txt",
        .comment = "root append helper",
        .header_crc = true,
    };
    const gzip_header_expected = try encodeGzipStoredWithHeaderAlloc(std.testing.allocator, payload, header_options);
    defer std.testing.allocator.free(gzip_header_expected);
    try std.testing.expectEqual(gzip_header_expected.len, try gzipStoredEncodedSizeWithHeader(payload.len, header_options));
    var gzip_header_appended: std.ArrayList(u8) = .empty;
    defer gzip_header_appended.deinit(std.testing.allocator);
    try gzip_header_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(gzip_header_expected.len, try encodeGzipStoredWithHeaderAppend(std.testing.allocator, &gzip_header_appended, payload, header_options));
    try std.testing.expectEqualSlices(u8, "prefix:", gzip_header_appended.items[0.."prefix:".len]);
    try std.testing.expectEqualSlices(u8, gzip_header_expected, gzip_header_appended.items["prefix:".len..]);
    const gzip_header_decoded = try decodeGzipStoredAlloc(std.testing.allocator, gzip_header_appended.items["prefix:".len..]);
    defer std.testing.allocator.free(gzip_header_decoded);
    try std.testing.expectEqualSlices(u8, payload, gzip_header_decoded);
    try std.testing.expectEqual(gzip_header_expected.len, try gzipStoredChunksEncodedSizeWithHeader(&chunks, header_options));
    const gzip_header_chunks = try encodeGzipStoredChunksWithHeaderAlloc(std.testing.allocator, &chunks, header_options);
    defer std.testing.allocator.free(gzip_header_chunks);
    try std.testing.expectEqualSlices(u8, gzip_header_expected, gzip_header_chunks);
    var gzip_header_chunks_appended: std.ArrayList(u8) = .empty;
    defer gzip_header_chunks_appended.deinit(std.testing.allocator);
    try gzip_header_chunks_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(gzip_header_expected.len, try encodeGzipStoredChunksWithHeaderAppend(std.testing.allocator, &gzip_header_chunks_appended, &chunks, header_options));
    try std.testing.expectEqualSlices(u8, gzip_header_expected, gzip_header_chunks_appended.items["prefix:".len..]);
    const gzip_header_chunks_into = try std.testing.allocator.alloc(u8, gzip_header_expected.len);
    defer std.testing.allocator.free(gzip_header_chunks_into);
    try std.testing.expectEqual(gzip_header_expected.len, try encodeGzipStoredChunksWithHeader(&chunks, gzip_header_chunks_into, header_options));
    try std.testing.expectEqualSlices(u8, gzip_header_expected, gzip_header_chunks_into);
}

test "root raw deflate non-stored append encode helpers preserve prefixes" {
    const prefix = "prefix:";
    const payload = "root raw non-stored append encode payload " ** 2;
    const preset_dictionary = "root raw non-stored append dictionary";
    const dict_payload = "root raw non-stored append dictionary payload";
    const fixed_options = optionsForCompressionLevel(.fast);
    const dynamic_options = optionsForCompressionLevel(.default);
    const best_options = optionsForCompressionLevel(.fastest);
    const adaptive_split_options: AdaptiveSplitOptions = .{
        .min_block_len = 16,
        .max_block_len = 32,
        .sample_len = 8,
        .search_step = 8,
    };

    const fixed_expected = try encodeRawFixedDeflateAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(fixed_expected);
    var fixed_appended: std.ArrayList(u8) = .empty;
    defer fixed_appended.deinit(std.testing.allocator);
    try fixed_appended.appendSlice(std.testing.allocator, prefix);
    try std.testing.expectEqual(fixed_expected.len, try encodeRawFixedDeflateAppend(std.testing.allocator, &fixed_appended, payload));
    try std.testing.expectEqualSlices(u8, fixed_expected, fixed_appended.items[prefix.len..]);

    const fixed_options_expected = try encodeRawFixedWithOptionsAlloc(std.testing.allocator, payload, fixed_options);
    defer std.testing.allocator.free(fixed_options_expected);
    var fixed_options_appended: std.ArrayList(u8) = .empty;
    defer fixed_options_appended.deinit(std.testing.allocator);
    try fixed_options_appended.appendSlice(std.testing.allocator, prefix);
    try std.testing.expectEqual(fixed_options_expected.len, try encodeRawFixedWithOptionsAppend(std.testing.allocator, &fixed_options_appended, payload, fixed_options));
    try std.testing.expectEqualSlices(u8, fixed_options_expected, fixed_options_appended.items[prefix.len..]);

    const fixed_split_expected = try encodeRawFixedSplitAlloc(std.testing.allocator, payload, 23, fixed_options);
    defer std.testing.allocator.free(fixed_split_expected);
    var fixed_split_appended: std.ArrayList(u8) = .empty;
    defer fixed_split_appended.deinit(std.testing.allocator);
    try fixed_split_appended.appendSlice(std.testing.allocator, prefix);
    try std.testing.expectEqual(fixed_split_expected.len, try encodeRawFixedSplitAppend(std.testing.allocator, &fixed_split_appended, payload, 23, fixed_options));
    try std.testing.expectEqualSlices(u8, fixed_split_expected, fixed_split_appended.items[prefix.len..]);
    try std.testing.expectError(error.InvalidBlockPlan, encodeRawFixedSplitAppend(std.testing.allocator, &fixed_split_appended, payload, 0, fixed_options));

    const fixed_dict_expected = try encodeRawFixedWithDictionaryAlloc(std.testing.allocator, dict_payload, preset_dictionary, fixed_options);
    defer std.testing.allocator.free(fixed_dict_expected);
    var fixed_dict_appended: std.ArrayList(u8) = .empty;
    defer fixed_dict_appended.deinit(std.testing.allocator);
    try fixed_dict_appended.appendSlice(std.testing.allocator, prefix);
    try std.testing.expectEqual(fixed_dict_expected.len, try encodeRawFixedWithDictionaryAppend(std.testing.allocator, &fixed_dict_appended, dict_payload, preset_dictionary, fixed_options));
    try std.testing.expectEqualSlices(u8, fixed_dict_expected, fixed_dict_appended.items[prefix.len..]);

    const fixed_dict_split_expected = try encodeRawFixedSplitWithDictionaryAlloc(std.testing.allocator, dict_payload, preset_dictionary, 17, fixed_options);
    defer std.testing.allocator.free(fixed_dict_split_expected);
    var fixed_dict_split_appended: std.ArrayList(u8) = .empty;
    defer fixed_dict_split_appended.deinit(std.testing.allocator);
    try fixed_dict_split_appended.appendSlice(std.testing.allocator, prefix);
    try std.testing.expectEqual(fixed_dict_split_expected.len, try encodeRawFixedSplitWithDictionaryAppend(std.testing.allocator, &fixed_dict_split_appended, dict_payload, preset_dictionary, 17, fixed_options));
    try std.testing.expectEqualSlices(u8, fixed_dict_split_expected, fixed_dict_split_appended.items[prefix.len..]);

    const best_expected = try encodeRawBestAlloc(std.testing.allocator, payload, best_options);
    defer std.testing.allocator.free(best_expected);
    var best_appended: std.ArrayList(u8) = .empty;
    defer best_appended.deinit(std.testing.allocator);
    try best_appended.appendSlice(std.testing.allocator, prefix);
    try std.testing.expectEqual(best_expected.len, try encodeRawBestAppend(std.testing.allocator, &best_appended, payload, best_options));
    try std.testing.expectEqualSlices(u8, best_expected, best_appended.items[prefix.len..]);

    const best_split_expected = try encodeRawBestSplitAlloc(std.testing.allocator, payload, 31, best_options);
    defer std.testing.allocator.free(best_split_expected);
    var best_split_appended: std.ArrayList(u8) = .empty;
    defer best_split_appended.deinit(std.testing.allocator);
    try best_split_appended.appendSlice(std.testing.allocator, prefix);
    try std.testing.expectEqual(best_split_expected.len, try encodeRawBestSplitAppend(std.testing.allocator, &best_split_appended, payload, 31, best_options));
    try std.testing.expectEqualSlices(u8, best_split_expected, best_split_appended.items[prefix.len..]);

    const best_adaptive_expected = try encodeRawBestAdaptiveSplitAlloc(std.testing.allocator, payload, best_options, adaptive_split_options);
    defer std.testing.allocator.free(best_adaptive_expected);
    var best_adaptive_appended: std.ArrayList(u8) = .empty;
    defer best_adaptive_appended.deinit(std.testing.allocator);
    try best_adaptive_appended.appendSlice(std.testing.allocator, prefix);
    try std.testing.expectEqual(best_adaptive_expected.len, try encodeRawBestAdaptiveSplitAppend(std.testing.allocator, &best_adaptive_appended, payload, best_options, adaptive_split_options));
    try std.testing.expectEqualSlices(u8, best_adaptive_expected, best_adaptive_appended.items[prefix.len..]);

    const best_dict_expected = try encodeRawBestWithDictionaryAlloc(std.testing.allocator, dict_payload, preset_dictionary, best_options);
    defer std.testing.allocator.free(best_dict_expected);
    var best_dict_appended: std.ArrayList(u8) = .empty;
    defer best_dict_appended.deinit(std.testing.allocator);
    try best_dict_appended.appendSlice(std.testing.allocator, prefix);
    try std.testing.expectEqual(best_dict_expected.len, try encodeRawBestWithDictionaryAppend(std.testing.allocator, &best_dict_appended, dict_payload, preset_dictionary, best_options));
    try std.testing.expectEqualSlices(u8, best_dict_expected, best_dict_appended.items[prefix.len..]);

    const best_dict_split_expected = try encodeRawBestSplitWithDictionaryAlloc(std.testing.allocator, dict_payload, preset_dictionary, 17, best_options);
    defer std.testing.allocator.free(best_dict_split_expected);
    var best_dict_split_appended: std.ArrayList(u8) = .empty;
    defer best_dict_split_appended.deinit(std.testing.allocator);
    try best_dict_split_appended.appendSlice(std.testing.allocator, prefix);
    try std.testing.expectEqual(best_dict_split_expected.len, try encodeRawBestSplitWithDictionaryAppend(std.testing.allocator, &best_dict_split_appended, dict_payload, preset_dictionary, 17, best_options));
    try std.testing.expectEqualSlices(u8, best_dict_split_expected, best_dict_split_appended.items[prefix.len..]);

    const best_dict_adaptive_expected = try encodeRawBestAdaptiveSplitWithDictionaryAlloc(std.testing.allocator, dict_payload, preset_dictionary, best_options, adaptive_split_options);
    defer std.testing.allocator.free(best_dict_adaptive_expected);
    var best_dict_adaptive_appended: std.ArrayList(u8) = .empty;
    defer best_dict_adaptive_appended.deinit(std.testing.allocator);
    try best_dict_adaptive_appended.appendSlice(std.testing.allocator, prefix);
    try std.testing.expectEqual(best_dict_adaptive_expected.len, try encodeRawBestAdaptiveSplitWithDictionaryAppend(std.testing.allocator, &best_dict_adaptive_appended, dict_payload, preset_dictionary, best_options, adaptive_split_options));
    try std.testing.expectEqualSlices(u8, best_dict_adaptive_expected, best_dict_adaptive_appended.items[prefix.len..]);

    const level_expected = try encodeRawLevelAlloc(std.testing.allocator, payload, 1);
    defer std.testing.allocator.free(level_expected);
    var level_appended: std.ArrayList(u8) = .empty;
    defer level_appended.deinit(std.testing.allocator);
    try level_appended.appendSlice(std.testing.allocator, prefix);
    try std.testing.expectEqual(level_expected.len, try encodeRawLevelAppend(std.testing.allocator, &level_appended, payload, 1));
    try std.testing.expectEqualSlices(u8, level_expected, level_appended.items[prefix.len..]);
    try std.testing.expectError(error.InvalidBlockPlan, encodeRawLevelAppend(std.testing.allocator, &level_appended, payload, 10));

    const level_dict_expected = try encodeRawLevelWithDictionaryAlloc(std.testing.allocator, dict_payload, preset_dictionary, 1);
    defer std.testing.allocator.free(level_dict_expected);
    var level_dict_appended: std.ArrayList(u8) = .empty;
    defer level_dict_appended.deinit(std.testing.allocator);
    try level_dict_appended.appendSlice(std.testing.allocator, prefix);
    try std.testing.expectEqual(level_dict_expected.len, try encodeRawLevelWithDictionaryAppend(std.testing.allocator, &level_dict_appended, dict_payload, preset_dictionary, 1));
    try std.testing.expectEqualSlices(u8, level_dict_expected, level_dict_appended.items[prefix.len..]);

    const dynamic_literal_expected = try encodeRawDynamicLiteralAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(dynamic_literal_expected);
    var dynamic_literal_appended: std.ArrayList(u8) = .empty;
    defer dynamic_literal_appended.deinit(std.testing.allocator);
    try dynamic_literal_appended.appendSlice(std.testing.allocator, prefix);
    try std.testing.expectEqual(dynamic_literal_expected.len, try encodeRawDynamicLiteralAppend(std.testing.allocator, &dynamic_literal_appended, payload));
    try std.testing.expectEqualSlices(u8, dynamic_literal_expected, dynamic_literal_appended.items[prefix.len..]);

    const dynamic_expected = try encodeRawDynamicWithOptionsAlloc(std.testing.allocator, payload, dynamic_options);
    defer std.testing.allocator.free(dynamic_expected);
    var dynamic_appended: std.ArrayList(u8) = .empty;
    defer dynamic_appended.deinit(std.testing.allocator);
    try dynamic_appended.appendSlice(std.testing.allocator, prefix);
    try std.testing.expectEqual(dynamic_expected.len, try encodeRawDynamicWithOptionsAppend(std.testing.allocator, &dynamic_appended, payload, dynamic_options));
    try std.testing.expectEqualSlices(u8, dynamic_expected, dynamic_appended.items[prefix.len..]);

    const dynamic_split_expected = try encodeRawDynamicSplitAlloc(std.testing.allocator, payload, 23, dynamic_options);
    defer std.testing.allocator.free(dynamic_split_expected);
    var dynamic_split_appended: std.ArrayList(u8) = .empty;
    defer dynamic_split_appended.deinit(std.testing.allocator);
    try dynamic_split_appended.appendSlice(std.testing.allocator, prefix);
    try std.testing.expectEqual(dynamic_split_expected.len, try encodeRawDynamicSplitAppend(std.testing.allocator, &dynamic_split_appended, payload, 23, dynamic_options));
    try std.testing.expectEqualSlices(u8, dynamic_split_expected, dynamic_split_appended.items[prefix.len..]);

    const dynamic_dict_expected = try encodeRawDynamicWithDictionaryAlloc(std.testing.allocator, dict_payload, preset_dictionary, dynamic_options);
    defer std.testing.allocator.free(dynamic_dict_expected);
    var dynamic_dict_appended: std.ArrayList(u8) = .empty;
    defer dynamic_dict_appended.deinit(std.testing.allocator);
    try dynamic_dict_appended.appendSlice(std.testing.allocator, prefix);
    try std.testing.expectEqual(dynamic_dict_expected.len, try encodeRawDynamicWithDictionaryAppend(std.testing.allocator, &dynamic_dict_appended, dict_payload, preset_dictionary, dynamic_options));
    try std.testing.expectEqualSlices(u8, dynamic_dict_expected, dynamic_dict_appended.items[prefix.len..]);

    const dynamic_dict_split_expected = try encodeRawDynamicSplitWithDictionaryAlloc(std.testing.allocator, dict_payload, preset_dictionary, 17, dynamic_options);
    defer std.testing.allocator.free(dynamic_dict_split_expected);
    var dynamic_dict_split_appended: std.ArrayList(u8) = .empty;
    defer dynamic_dict_split_appended.deinit(std.testing.allocator);
    try dynamic_dict_split_appended.appendSlice(std.testing.allocator, prefix);
    try std.testing.expectEqual(dynamic_dict_split_expected.len, try encodeRawDynamicSplitWithDictionaryAppend(std.testing.allocator, &dynamic_dict_split_appended, dict_payload, preset_dictionary, 17, dynamic_options));
    try std.testing.expectEqualSlices(u8, dynamic_dict_split_expected, dynamic_dict_split_appended.items[prefix.len..]);

    const decoded = try decodeRawDeflateAllocExactSize(std.testing.allocator, dynamic_split_appended.items[prefix.len..], payload.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    const dict_decoded = try decodeRawDeflateAllocWithDictionaryExactSize(std.testing.allocator, dynamic_dict_split_appended.items[prefix.len..], preset_dictionary, dict_payload.len);
    defer std.testing.allocator.free(dict_decoded);
    try std.testing.expectEqualSlices(u8, dict_payload, dict_decoded);
}

test "root zlib non-stored append encode helpers preserve prefixes" {
    const prefix = "prefix:";
    const payload = "root zlib non-stored append encode payload " ** 2;
    const preset_dictionary = "root zlib non-stored append dictionary";
    const fixed_options = optionsForCompressionLevel(.fast);
    const dynamic_options = optionsForCompressionLevel(.default);
    const best_options = optionsForCompressionLevel(.fastest);
    const adaptive_split_options: AdaptiveSplitOptions = .{
        .min_block_len = 16,
        .max_block_len = 32,
        .sample_len = 8,
        .search_step = 8,
    };

    const fixed_expected = try encodeZlibFixedAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(fixed_expected);
    var fixed_appended: std.ArrayList(u8) = .empty;
    defer fixed_appended.deinit(std.testing.allocator);
    try fixed_appended.appendSlice(std.testing.allocator, prefix);
    try std.testing.expectEqual(fixed_expected.len, try encodeZlibFixedAppend(std.testing.allocator, &fixed_appended, payload));
    try std.testing.expectEqualSlices(u8, fixed_expected, fixed_appended.items[prefix.len..]);

    const fixed_options_expected = try encodeZlibFixedWithOptionsAlloc(std.testing.allocator, payload, fixed_options);
    defer std.testing.allocator.free(fixed_options_expected);
    var fixed_options_appended: std.ArrayList(u8) = .empty;
    defer fixed_options_appended.deinit(std.testing.allocator);
    try fixed_options_appended.appendSlice(std.testing.allocator, prefix);
    try std.testing.expectEqual(fixed_options_expected.len, try encodeZlibFixedWithOptionsAppend(std.testing.allocator, &fixed_options_appended, payload, fixed_options));
    try std.testing.expectEqualSlices(u8, fixed_options_expected, fixed_options_appended.items[prefix.len..]);

    const fixed_split_expected = try encodeZlibFixedSplitAlloc(std.testing.allocator, payload, 23, fixed_options);
    defer std.testing.allocator.free(fixed_split_expected);
    var fixed_split_appended: std.ArrayList(u8) = .empty;
    defer fixed_split_appended.deinit(std.testing.allocator);
    try fixed_split_appended.appendSlice(std.testing.allocator, prefix);
    try std.testing.expectEqual(fixed_split_expected.len, try encodeZlibFixedSplitAppend(std.testing.allocator, &fixed_split_appended, payload, 23, fixed_options));
    try std.testing.expectEqualSlices(u8, fixed_split_expected, fixed_split_appended.items[prefix.len..]);
    try std.testing.expectError(error.InvalidBlockPlan, encodeZlibFixedSplitAppend(std.testing.allocator, &fixed_split_appended, payload, 0, fixed_options));

    const fixed_dict_expected = try encodeZlibFixedWithDictionaryAlloc(std.testing.allocator, payload, preset_dictionary, fixed_options);
    defer std.testing.allocator.free(fixed_dict_expected);
    var fixed_dict_appended: std.ArrayList(u8) = .empty;
    defer fixed_dict_appended.deinit(std.testing.allocator);
    try fixed_dict_appended.appendSlice(std.testing.allocator, prefix);
    try std.testing.expectEqual(fixed_dict_expected.len, try encodeZlibFixedWithDictionaryAppend(std.testing.allocator, &fixed_dict_appended, payload, preset_dictionary, fixed_options));
    try std.testing.expectEqualSlices(u8, fixed_dict_expected, fixed_dict_appended.items[prefix.len..]);

    const fixed_dict_split_expected = try encodeZlibFixedSplitWithDictionaryAlloc(std.testing.allocator, payload, preset_dictionary, 19, fixed_options);
    defer std.testing.allocator.free(fixed_dict_split_expected);
    var fixed_dict_split_appended: std.ArrayList(u8) = .empty;
    defer fixed_dict_split_appended.deinit(std.testing.allocator);
    try fixed_dict_split_appended.appendSlice(std.testing.allocator, prefix);
    try std.testing.expectEqual(fixed_dict_split_expected.len, try encodeZlibFixedSplitWithDictionaryAppend(std.testing.allocator, &fixed_dict_split_appended, payload, preset_dictionary, 19, fixed_options));
    try std.testing.expectEqualSlices(u8, fixed_dict_split_expected, fixed_dict_split_appended.items[prefix.len..]);

    const best_expected = try encodeZlibBestAlloc(std.testing.allocator, payload, best_options);
    defer std.testing.allocator.free(best_expected);
    var best_appended: std.ArrayList(u8) = .empty;
    defer best_appended.deinit(std.testing.allocator);
    try best_appended.appendSlice(std.testing.allocator, prefix);
    try std.testing.expectEqual(best_expected.len, try encodeZlibBestAppend(std.testing.allocator, &best_appended, payload, best_options));
    try std.testing.expectEqualSlices(u8, best_expected, best_appended.items[prefix.len..]);

    const best_split_expected = try encodeZlibBestSplitAlloc(std.testing.allocator, payload, 29, best_options);
    defer std.testing.allocator.free(best_split_expected);
    var best_split_appended: std.ArrayList(u8) = .empty;
    defer best_split_appended.deinit(std.testing.allocator);
    try best_split_appended.appendSlice(std.testing.allocator, prefix);
    try std.testing.expectEqual(best_split_expected.len, try encodeZlibBestSplitAppend(std.testing.allocator, &best_split_appended, payload, 29, best_options));
    try std.testing.expectEqualSlices(u8, best_split_expected, best_split_appended.items[prefix.len..]);

    const best_adaptive_expected = try encodeZlibBestAdaptiveSplitAlloc(std.testing.allocator, payload, best_options, adaptive_split_options);
    defer std.testing.allocator.free(best_adaptive_expected);
    var best_adaptive_appended: std.ArrayList(u8) = .empty;
    defer best_adaptive_appended.deinit(std.testing.allocator);
    try best_adaptive_appended.appendSlice(std.testing.allocator, prefix);
    try std.testing.expectEqual(best_adaptive_expected.len, try encodeZlibBestAdaptiveSplitAppend(std.testing.allocator, &best_adaptive_appended, payload, best_options, adaptive_split_options));
    try std.testing.expectEqualSlices(u8, best_adaptive_expected, best_adaptive_appended.items[prefix.len..]);

    const best_dict_expected = try encodeZlibBestWithDictionaryAlloc(std.testing.allocator, payload, preset_dictionary, best_options);
    defer std.testing.allocator.free(best_dict_expected);
    var best_dict_appended: std.ArrayList(u8) = .empty;
    defer best_dict_appended.deinit(std.testing.allocator);
    try best_dict_appended.appendSlice(std.testing.allocator, prefix);
    try std.testing.expectEqual(best_dict_expected.len, try encodeZlibBestWithDictionaryAppend(std.testing.allocator, &best_dict_appended, payload, preset_dictionary, best_options));
    try std.testing.expectEqualSlices(u8, best_dict_expected, best_dict_appended.items[prefix.len..]);

    const best_dict_split_expected = try encodeZlibBestSplitWithDictionaryAlloc(std.testing.allocator, payload, preset_dictionary, 19, best_options);
    defer std.testing.allocator.free(best_dict_split_expected);
    var best_dict_split_appended: std.ArrayList(u8) = .empty;
    defer best_dict_split_appended.deinit(std.testing.allocator);
    try best_dict_split_appended.appendSlice(std.testing.allocator, prefix);
    try std.testing.expectEqual(best_dict_split_expected.len, try encodeZlibBestSplitWithDictionaryAppend(std.testing.allocator, &best_dict_split_appended, payload, preset_dictionary, 19, best_options));
    try std.testing.expectEqualSlices(u8, best_dict_split_expected, best_dict_split_appended.items[prefix.len..]);

    const best_dict_adaptive_expected = try encodeZlibBestAdaptiveSplitWithDictionaryAlloc(std.testing.allocator, payload, preset_dictionary, best_options, adaptive_split_options);
    defer std.testing.allocator.free(best_dict_adaptive_expected);
    var best_dict_adaptive_appended: std.ArrayList(u8) = .empty;
    defer best_dict_adaptive_appended.deinit(std.testing.allocator);
    try best_dict_adaptive_appended.appendSlice(std.testing.allocator, prefix);
    try std.testing.expectEqual(best_dict_adaptive_expected.len, try encodeZlibBestAdaptiveSplitWithDictionaryAppend(std.testing.allocator, &best_dict_adaptive_appended, payload, preset_dictionary, best_options, adaptive_split_options));
    try std.testing.expectEqualSlices(u8, best_dict_adaptive_expected, best_dict_adaptive_appended.items[prefix.len..]);

    const level_expected = try encodeZlibLevelAlloc(std.testing.allocator, payload, 1);
    defer std.testing.allocator.free(level_expected);
    var level_appended: std.ArrayList(u8) = .empty;
    defer level_appended.deinit(std.testing.allocator);
    try level_appended.appendSlice(std.testing.allocator, prefix);
    try std.testing.expectEqual(level_expected.len, try encodeZlibLevelAppend(std.testing.allocator, &level_appended, payload, 1));
    try std.testing.expectEqualSlices(u8, level_expected, level_appended.items[prefix.len..]);
    try std.testing.expectError(error.InvalidBlockPlan, encodeZlibLevelAppend(std.testing.allocator, &level_appended, payload, 10));

    const level_dict_expected = try encodeZlibLevelWithDictionaryAlloc(std.testing.allocator, payload, preset_dictionary, 1);
    defer std.testing.allocator.free(level_dict_expected);
    var level_dict_appended: std.ArrayList(u8) = .empty;
    defer level_dict_appended.deinit(std.testing.allocator);
    try level_dict_appended.appendSlice(std.testing.allocator, prefix);
    try std.testing.expectEqual(level_dict_expected.len, try encodeZlibLevelWithDictionaryAppend(std.testing.allocator, &level_dict_appended, payload, preset_dictionary, 1));
    try std.testing.expectEqualSlices(u8, level_dict_expected, level_dict_appended.items[prefix.len..]);

    const dynamic_literal_expected = try encodeZlibDynamicLiteralAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(dynamic_literal_expected);
    var dynamic_literal_appended: std.ArrayList(u8) = .empty;
    defer dynamic_literal_appended.deinit(std.testing.allocator);
    try dynamic_literal_appended.appendSlice(std.testing.allocator, prefix);
    try std.testing.expectEqual(dynamic_literal_expected.len, try encodeZlibDynamicLiteralAppend(std.testing.allocator, &dynamic_literal_appended, payload));
    try std.testing.expectEqualSlices(u8, dynamic_literal_expected, dynamic_literal_appended.items[prefix.len..]);

    const dynamic_expected = try encodeZlibDynamicWithOptionsAlloc(std.testing.allocator, payload, dynamic_options);
    defer std.testing.allocator.free(dynamic_expected);
    var dynamic_appended: std.ArrayList(u8) = .empty;
    defer dynamic_appended.deinit(std.testing.allocator);
    try dynamic_appended.appendSlice(std.testing.allocator, prefix);
    try std.testing.expectEqual(dynamic_expected.len, try encodeZlibDynamicWithOptionsAppend(std.testing.allocator, &dynamic_appended, payload, dynamic_options));
    try std.testing.expectEqualSlices(u8, dynamic_expected, dynamic_appended.items[prefix.len..]);

    const dynamic_split_expected = try encodeZlibDynamicSplitAlloc(std.testing.allocator, payload, 23, dynamic_options);
    defer std.testing.allocator.free(dynamic_split_expected);
    var dynamic_split_appended: std.ArrayList(u8) = .empty;
    defer dynamic_split_appended.deinit(std.testing.allocator);
    try dynamic_split_appended.appendSlice(std.testing.allocator, prefix);
    try std.testing.expectEqual(dynamic_split_expected.len, try encodeZlibDynamicSplitAppend(std.testing.allocator, &dynamic_split_appended, payload, 23, dynamic_options));
    try std.testing.expectEqualSlices(u8, dynamic_split_expected, dynamic_split_appended.items[prefix.len..]);

    const dynamic_dict_expected = try encodeZlibDynamicWithDictionaryAlloc(std.testing.allocator, payload, preset_dictionary, dynamic_options);
    defer std.testing.allocator.free(dynamic_dict_expected);
    var dynamic_dict_appended: std.ArrayList(u8) = .empty;
    defer dynamic_dict_appended.deinit(std.testing.allocator);
    try dynamic_dict_appended.appendSlice(std.testing.allocator, prefix);
    try std.testing.expectEqual(dynamic_dict_expected.len, try encodeZlibDynamicWithDictionaryAppend(std.testing.allocator, &dynamic_dict_appended, payload, preset_dictionary, dynamic_options));
    try std.testing.expectEqualSlices(u8, dynamic_dict_expected, dynamic_dict_appended.items[prefix.len..]);

    const dynamic_dict_split_expected = try encodeZlibDynamicSplitWithDictionaryAlloc(std.testing.allocator, payload, preset_dictionary, 19, dynamic_options);
    defer std.testing.allocator.free(dynamic_dict_split_expected);
    var dynamic_dict_split_appended: std.ArrayList(u8) = .empty;
    defer dynamic_dict_split_appended.deinit(std.testing.allocator);
    try dynamic_dict_split_appended.appendSlice(std.testing.allocator, prefix);
    try std.testing.expectEqual(dynamic_dict_split_expected.len, try encodeZlibDynamicSplitWithDictionaryAppend(std.testing.allocator, &dynamic_dict_split_appended, payload, preset_dictionary, 19, dynamic_options));
    try std.testing.expectEqualSlices(u8, dynamic_dict_split_expected, dynamic_dict_split_appended.items[prefix.len..]);

    const decoded = try decodeZlibAllocExactSize(std.testing.allocator, dynamic_split_appended.items[prefix.len..], payload.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    const dict_decoded = try decodeZlibAllocWithDictionaryExactSize(std.testing.allocator, dynamic_dict_split_appended.items[prefix.len..], preset_dictionary, payload.len);
    defer std.testing.allocator.free(dict_decoded);
    try std.testing.expectEqualSlices(u8, payload, dict_decoded);
}

test "root gzip non-stored append encode helpers preserve prefixes" {
    const prefix = "prefix:";
    const payload = "root gzip non-stored append encode payload " ** 2;
    const header_options: GzipHeaderOptions = .{
        .filename = "gzip-non-stored-append.txt",
        .comment = "root gzip non-stored append",
        .header_crc = true,
    };
    const fixed_options = optionsForCompressionLevel(.fast);
    const dynamic_options = optionsForCompressionLevel(.default);
    const best_options = optionsForCompressionLevel(.fastest);
    const adaptive_split_options: AdaptiveSplitOptions = .{
        .min_block_len = 16,
        .max_block_len = 32,
        .sample_len = 8,
        .search_step = 8,
    };

    const fixed_expected = try encodeGzipFixedAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(fixed_expected);
    var fixed_appended: std.ArrayList(u8) = .empty;
    defer fixed_appended.deinit(std.testing.allocator);
    try fixed_appended.appendSlice(std.testing.allocator, prefix);
    try std.testing.expectEqual(fixed_expected.len, try encodeGzipFixedAppend(std.testing.allocator, &fixed_appended, payload));
    try std.testing.expectEqualSlices(u8, fixed_expected, fixed_appended.items[prefix.len..]);

    const fixed_options_expected = try encodeGzipFixedWithOptionsAlloc(std.testing.allocator, payload, fixed_options);
    defer std.testing.allocator.free(fixed_options_expected);
    var fixed_options_appended: std.ArrayList(u8) = .empty;
    defer fixed_options_appended.deinit(std.testing.allocator);
    try fixed_options_appended.appendSlice(std.testing.allocator, prefix);
    try std.testing.expectEqual(fixed_options_expected.len, try encodeGzipFixedWithOptionsAppend(std.testing.allocator, &fixed_options_appended, payload, fixed_options));
    try std.testing.expectEqualSlices(u8, fixed_options_expected, fixed_options_appended.items[prefix.len..]);

    const fixed_header_expected = try encodeGzipFixedWithHeaderAlloc(std.testing.allocator, payload, fixed_options, header_options);
    defer std.testing.allocator.free(fixed_header_expected);
    var fixed_header_appended: std.ArrayList(u8) = .empty;
    defer fixed_header_appended.deinit(std.testing.allocator);
    try fixed_header_appended.appendSlice(std.testing.allocator, prefix);
    try std.testing.expectEqual(fixed_header_expected.len, try encodeGzipFixedWithHeaderAppend(std.testing.allocator, &fixed_header_appended, payload, fixed_options, header_options));
    try std.testing.expectEqualSlices(u8, fixed_header_expected, fixed_header_appended.items[prefix.len..]);

    const fixed_split_expected = try encodeGzipFixedSplitAlloc(std.testing.allocator, payload, 23, fixed_options);
    defer std.testing.allocator.free(fixed_split_expected);
    var fixed_split_appended: std.ArrayList(u8) = .empty;
    defer fixed_split_appended.deinit(std.testing.allocator);
    try fixed_split_appended.appendSlice(std.testing.allocator, prefix);
    try std.testing.expectEqual(fixed_split_expected.len, try encodeGzipFixedSplitAppend(std.testing.allocator, &fixed_split_appended, payload, 23, fixed_options));
    try std.testing.expectEqualSlices(u8, fixed_split_expected, fixed_split_appended.items[prefix.len..]);
    try std.testing.expectError(error.InvalidBlockPlan, encodeGzipFixedSplitAppend(std.testing.allocator, &fixed_split_appended, payload, 0, fixed_options));

    const fixed_split_header_expected = try encodeGzipFixedSplitWithHeaderAlloc(std.testing.allocator, payload, 23, fixed_options, header_options);
    defer std.testing.allocator.free(fixed_split_header_expected);
    var fixed_split_header_appended: std.ArrayList(u8) = .empty;
    defer fixed_split_header_appended.deinit(std.testing.allocator);
    try fixed_split_header_appended.appendSlice(std.testing.allocator, prefix);
    try std.testing.expectEqual(fixed_split_header_expected.len, try encodeGzipFixedSplitWithHeaderAppend(std.testing.allocator, &fixed_split_header_appended, payload, 23, fixed_options, header_options));
    try std.testing.expectEqualSlices(u8, fixed_split_header_expected, fixed_split_header_appended.items[prefix.len..]);

    const best_expected = try encodeGzipBestAlloc(std.testing.allocator, payload, best_options);
    defer std.testing.allocator.free(best_expected);
    var best_appended: std.ArrayList(u8) = .empty;
    defer best_appended.deinit(std.testing.allocator);
    try best_appended.appendSlice(std.testing.allocator, prefix);
    try std.testing.expectEqual(best_expected.len, try encodeGzipBestAppend(std.testing.allocator, &best_appended, payload, best_options));
    try std.testing.expectEqualSlices(u8, best_expected, best_appended.items[prefix.len..]);

    const best_header_expected = try encodeGzipBestWithHeaderAlloc(std.testing.allocator, payload, best_options, header_options);
    defer std.testing.allocator.free(best_header_expected);
    var best_header_appended: std.ArrayList(u8) = .empty;
    defer best_header_appended.deinit(std.testing.allocator);
    try best_header_appended.appendSlice(std.testing.allocator, prefix);
    try std.testing.expectEqual(best_header_expected.len, try encodeGzipBestWithHeaderAppend(std.testing.allocator, &best_header_appended, payload, best_options, header_options));
    try std.testing.expectEqualSlices(u8, best_header_expected, best_header_appended.items[prefix.len..]);

    const best_split_expected = try encodeGzipBestSplitAlloc(std.testing.allocator, payload, 29, best_options);
    defer std.testing.allocator.free(best_split_expected);
    var best_split_appended: std.ArrayList(u8) = .empty;
    defer best_split_appended.deinit(std.testing.allocator);
    try best_split_appended.appendSlice(std.testing.allocator, prefix);
    try std.testing.expectEqual(best_split_expected.len, try encodeGzipBestSplitAppend(std.testing.allocator, &best_split_appended, payload, 29, best_options));
    try std.testing.expectEqualSlices(u8, best_split_expected, best_split_appended.items[prefix.len..]);

    const best_split_header_expected = try encodeGzipBestSplitWithHeaderAlloc(std.testing.allocator, payload, 29, best_options, header_options);
    defer std.testing.allocator.free(best_split_header_expected);
    var best_split_header_appended: std.ArrayList(u8) = .empty;
    defer best_split_header_appended.deinit(std.testing.allocator);
    try best_split_header_appended.appendSlice(std.testing.allocator, prefix);
    try std.testing.expectEqual(best_split_header_expected.len, try encodeGzipBestSplitWithHeaderAppend(std.testing.allocator, &best_split_header_appended, payload, 29, best_options, header_options));
    try std.testing.expectEqualSlices(u8, best_split_header_expected, best_split_header_appended.items[prefix.len..]);

    const best_adaptive_expected = try encodeGzipBestAdaptiveSplitAlloc(std.testing.allocator, payload, best_options, adaptive_split_options);
    defer std.testing.allocator.free(best_adaptive_expected);
    var best_adaptive_appended: std.ArrayList(u8) = .empty;
    defer best_adaptive_appended.deinit(std.testing.allocator);
    try best_adaptive_appended.appendSlice(std.testing.allocator, prefix);
    try std.testing.expectEqual(best_adaptive_expected.len, try encodeGzipBestAdaptiveSplitAppend(std.testing.allocator, &best_adaptive_appended, payload, best_options, adaptive_split_options));
    try std.testing.expectEqualSlices(u8, best_adaptive_expected, best_adaptive_appended.items[prefix.len..]);

    const best_adaptive_header_expected = try encodeGzipBestAdaptiveSplitWithHeaderAlloc(std.testing.allocator, payload, best_options, adaptive_split_options, header_options);
    defer std.testing.allocator.free(best_adaptive_header_expected);
    var best_adaptive_header_appended: std.ArrayList(u8) = .empty;
    defer best_adaptive_header_appended.deinit(std.testing.allocator);
    try best_adaptive_header_appended.appendSlice(std.testing.allocator, prefix);
    try std.testing.expectEqual(best_adaptive_header_expected.len, try encodeGzipBestAdaptiveSplitWithHeaderAppend(std.testing.allocator, &best_adaptive_header_appended, payload, best_options, adaptive_split_options, header_options));
    try std.testing.expectEqualSlices(u8, best_adaptive_header_expected, best_adaptive_header_appended.items[prefix.len..]);

    const level_expected = try encodeGzipLevelAlloc(std.testing.allocator, payload, 1);
    defer std.testing.allocator.free(level_expected);
    var level_appended: std.ArrayList(u8) = .empty;
    defer level_appended.deinit(std.testing.allocator);
    try level_appended.appendSlice(std.testing.allocator, prefix);
    try std.testing.expectEqual(level_expected.len, try encodeGzipLevelAppend(std.testing.allocator, &level_appended, payload, 1));
    try std.testing.expectEqualSlices(u8, level_expected, level_appended.items[prefix.len..]);
    try std.testing.expectError(error.InvalidBlockPlan, encodeGzipLevelAppend(std.testing.allocator, &level_appended, payload, 10));

    const level_header_expected = try encodeGzipLevelWithHeaderAlloc(std.testing.allocator, payload, 1, header_options);
    defer std.testing.allocator.free(level_header_expected);
    var level_header_appended: std.ArrayList(u8) = .empty;
    defer level_header_appended.deinit(std.testing.allocator);
    try level_header_appended.appendSlice(std.testing.allocator, prefix);
    try std.testing.expectEqual(level_header_expected.len, try encodeGzipLevelWithHeaderAppend(std.testing.allocator, &level_header_appended, payload, 1, header_options));
    try std.testing.expectEqualSlices(u8, level_header_expected, level_header_appended.items[prefix.len..]);

    const dynamic_literal_expected = try encodeGzipDynamicLiteralAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(dynamic_literal_expected);
    var dynamic_literal_appended: std.ArrayList(u8) = .empty;
    defer dynamic_literal_appended.deinit(std.testing.allocator);
    try dynamic_literal_appended.appendSlice(std.testing.allocator, prefix);
    try std.testing.expectEqual(dynamic_literal_expected.len, try encodeGzipDynamicLiteralAppend(std.testing.allocator, &dynamic_literal_appended, payload));
    try std.testing.expectEqualSlices(u8, dynamic_literal_expected, dynamic_literal_appended.items[prefix.len..]);

    const dynamic_literal_header_expected = try encodeGzipDynamicLiteralWithHeaderAlloc(std.testing.allocator, payload, header_options);
    defer std.testing.allocator.free(dynamic_literal_header_expected);
    var dynamic_literal_header_appended: std.ArrayList(u8) = .empty;
    defer dynamic_literal_header_appended.deinit(std.testing.allocator);
    try dynamic_literal_header_appended.appendSlice(std.testing.allocator, prefix);
    try std.testing.expectEqual(dynamic_literal_header_expected.len, try encodeGzipDynamicLiteralWithHeaderAppend(std.testing.allocator, &dynamic_literal_header_appended, payload, header_options));
    try std.testing.expectEqualSlices(u8, dynamic_literal_header_expected, dynamic_literal_header_appended.items[prefix.len..]);

    const dynamic_expected = try encodeGzipDynamicWithOptionsAlloc(std.testing.allocator, payload, dynamic_options);
    defer std.testing.allocator.free(dynamic_expected);
    var dynamic_appended: std.ArrayList(u8) = .empty;
    defer dynamic_appended.deinit(std.testing.allocator);
    try dynamic_appended.appendSlice(std.testing.allocator, prefix);
    try std.testing.expectEqual(dynamic_expected.len, try encodeGzipDynamicWithOptionsAppend(std.testing.allocator, &dynamic_appended, payload, dynamic_options));
    try std.testing.expectEqualSlices(u8, dynamic_expected, dynamic_appended.items[prefix.len..]);

    const dynamic_header_expected = try encodeGzipDynamicWithHeaderAlloc(std.testing.allocator, payload, dynamic_options, header_options);
    defer std.testing.allocator.free(dynamic_header_expected);
    var dynamic_header_appended: std.ArrayList(u8) = .empty;
    defer dynamic_header_appended.deinit(std.testing.allocator);
    try dynamic_header_appended.appendSlice(std.testing.allocator, prefix);
    try std.testing.expectEqual(dynamic_header_expected.len, try encodeGzipDynamicWithHeaderAppend(std.testing.allocator, &dynamic_header_appended, payload, dynamic_options, header_options));
    try std.testing.expectEqualSlices(u8, dynamic_header_expected, dynamic_header_appended.items[prefix.len..]);

    const dynamic_split_expected = try encodeGzipDynamicSplitAlloc(std.testing.allocator, payload, 23, dynamic_options);
    defer std.testing.allocator.free(dynamic_split_expected);
    var dynamic_split_appended: std.ArrayList(u8) = .empty;
    defer dynamic_split_appended.deinit(std.testing.allocator);
    try dynamic_split_appended.appendSlice(std.testing.allocator, prefix);
    try std.testing.expectEqual(dynamic_split_expected.len, try encodeGzipDynamicSplitAppend(std.testing.allocator, &dynamic_split_appended, payload, 23, dynamic_options));
    try std.testing.expectEqualSlices(u8, dynamic_split_expected, dynamic_split_appended.items[prefix.len..]);

    const dynamic_split_header_expected = try encodeGzipDynamicSplitWithHeaderAlloc(std.testing.allocator, payload, 23, dynamic_options, header_options);
    defer std.testing.allocator.free(dynamic_split_header_expected);
    var dynamic_split_header_appended: std.ArrayList(u8) = .empty;
    defer dynamic_split_header_appended.deinit(std.testing.allocator);
    try dynamic_split_header_appended.appendSlice(std.testing.allocator, prefix);
    try std.testing.expectEqual(dynamic_split_header_expected.len, try encodeGzipDynamicSplitWithHeaderAppend(std.testing.allocator, &dynamic_split_header_appended, payload, 23, dynamic_options, header_options));
    try std.testing.expectEqualSlices(u8, dynamic_split_header_expected, dynamic_split_header_appended.items[prefix.len..]);

    const decoded = try decodeGzipAllocExactSize(std.testing.allocator, dynamic_split_appended.items[prefix.len..], payload.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    const header_decoded = try decodeGzipAllocExactSize(std.testing.allocator, dynamic_split_header_appended.items[prefix.len..], payload.len);
    defer std.testing.allocator.free(header_decoded);
    try std.testing.expectEqualSlices(u8, payload, header_decoded);
}

test "root raw deflate encoder reuses stored scratch" {
    const payload = "root raw deflate reusable stored encoder payload" ** 2;
    const chunks = [_][]const u8{
        payload[0..13],
        payload[13..41],
        payload[41..],
    };
    const expected = try encodeRawStoredDeflateAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(expected);
    const expected_chunks = try encodeRawStoredDeflateChunksAlloc(std.testing.allocator, &chunks);
    defer std.testing.allocator.free(expected_chunks);
    try std.testing.expectEqualSlices(u8, expected, expected_chunks);

    var encoder = RawDeflateEncoder.init(std.testing.allocator);
    defer encoder.deinit();

    const owned = try encoder.encodeStoredAlloc(payload);
    defer std.testing.allocator.free(owned);
    try std.testing.expectEqualSlices(u8, expected, owned);
    const scratch = try encoder.encodeStoredScratch(payload);
    try std.testing.expectEqualSlices(u8, expected, scratch);
    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(std.testing.allocator);
    try appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(expected.len, try encoder.encodeStoredAppend(&appended, payload));
    try std.testing.expectEqualSlices(u8, expected, appended.items["prefix:".len..]);
    const into = try std.testing.allocator.alloc(u8, try rawStoredDeflateChunksEncodedSize(&chunks));
    defer std.testing.allocator.free(into);
    try std.testing.expectEqual(expected.len, try encoder.encodeStoredIntoSlice(payload, into));
    try std.testing.expectEqualSlices(u8, expected, into[0..expected.len]);

    const chunks_owned = try encoder.encodeStoredChunksAlloc(&chunks);
    defer std.testing.allocator.free(chunks_owned);
    try std.testing.expectEqualSlices(u8, expected_chunks, chunks_owned);
    const chunks_scratch = try encoder.encodeStoredChunksScratch(&chunks);
    try std.testing.expectEqualSlices(u8, expected_chunks, chunks_scratch);
    const decoded = try decodeRawDeflateAllocExactSize(std.testing.allocator, chunks_scratch, payload.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    var chunks_appended: std.ArrayList(u8) = .empty;
    defer chunks_appended.deinit(std.testing.allocator);
    _ = try encoder.encodeStoredChunksAppend(&chunks_appended, &chunks);
    try std.testing.expectEqualSlices(u8, expected_chunks, chunks_appended.items);
    const chunks_into = try std.testing.allocator.alloc(u8, expected_chunks.len);
    defer std.testing.allocator.free(chunks_into);
    try std.testing.expectEqual(expected_chunks.len, try encoder.encodeStoredChunksIntoSlice(&chunks, chunks_into));
    try std.testing.expectEqualSlices(u8, expected_chunks, chunks_into[0..expected_chunks.len]);
    try std.testing.expectError(error.OutputTooSmall, encoder.encodeStoredChunksIntoSlice(&chunks, chunks_into[0 .. chunks_into.len - 1]));

    const fixed_expected = try encodeRawFixedDeflateAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(fixed_expected);
    const fixed_owned = try encoder.encodeFixedAlloc(payload);
    defer std.testing.allocator.free(fixed_owned);
    try std.testing.expectEqualSlices(u8, fixed_expected, fixed_owned);
    const fixed_scratch = try encoder.encodeFixedScratch(payload);
    try std.testing.expectEqualSlices(u8, fixed_expected, fixed_scratch);
    var fixed_appended: std.ArrayList(u8) = .empty;
    defer fixed_appended.deinit(std.testing.allocator);
    try fixed_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(fixed_expected.len, try encoder.encodeFixedAppend(&fixed_appended, payload));
    try std.testing.expectEqualSlices(u8, fixed_expected, fixed_appended.items["prefix:".len..]);

    const fixed_options = optionsForCompressionLevel(.fast);
    const fixed_options_expected = try encodeRawFixedWithOptionsAlloc(std.testing.allocator, payload, fixed_options);
    defer std.testing.allocator.free(fixed_options_expected);
    const fixed_options_owned = try encoder.encodeFixedWithOptionsAlloc(payload, fixed_options);
    defer std.testing.allocator.free(fixed_options_owned);
    try std.testing.expectEqualSlices(u8, fixed_options_expected, fixed_options_owned);
    const fixed_options_scratch = try encoder.encodeFixedWithOptionsScratch(payload, fixed_options);
    try std.testing.expectEqualSlices(u8, fixed_options_expected, fixed_options_scratch);
    var fixed_options_appended: std.ArrayList(u8) = .empty;
    defer fixed_options_appended.deinit(std.testing.allocator);
    try std.testing.expectEqual(fixed_options_expected.len, try encoder.encodeFixedWithOptionsAppend(&fixed_options_appended, payload, fixed_options));
    try std.testing.expectEqualSlices(u8, fixed_options_expected, fixed_options_appended.items);

    const fixed_split_expected = try encodeRawFixedSplitAlloc(std.testing.allocator, payload, 23, fixed_options);
    defer std.testing.allocator.free(fixed_split_expected);
    const fixed_split_owned = try encoder.encodeFixedSplitAlloc(payload, 23, fixed_options);
    defer std.testing.allocator.free(fixed_split_owned);
    try std.testing.expectEqualSlices(u8, fixed_split_expected, fixed_split_owned);
    const fixed_split_scratch = try encoder.encodeFixedSplitScratch(payload, 23, fixed_options);
    try std.testing.expectEqualSlices(u8, fixed_split_expected, fixed_split_scratch);
    const fixed_split_decoded = try decodeRawDeflateAllocExactSize(std.testing.allocator, fixed_split_scratch, payload.len);
    defer std.testing.allocator.free(fixed_split_decoded);
    try std.testing.expectEqualSlices(u8, payload, fixed_split_decoded);
    var fixed_split_appended: std.ArrayList(u8) = .empty;
    defer fixed_split_appended.deinit(std.testing.allocator);
    try fixed_split_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(fixed_split_expected.len, try encoder.encodeFixedSplitAppend(&fixed_split_appended, payload, 23, fixed_options));
    try std.testing.expectEqualSlices(u8, fixed_split_expected, fixed_split_appended.items["prefix:".len..]);
    try std.testing.expectError(error.InvalidBlockPlan, encoder.encodeFixedSplitAlloc(payload, 0, fixed_options));

    const best_options = optionsForCompressionLevel(.fastest);
    const best_expected = try encodeRawBestAlloc(std.testing.allocator, payload, best_options);
    defer std.testing.allocator.free(best_expected);
    const best_owned = try encoder.encodeBestAlloc(payload, best_options);
    defer std.testing.allocator.free(best_owned);
    try std.testing.expectEqualSlices(u8, best_expected, best_owned);
    const best_scratch = try encoder.encodeBestScratch(payload, best_options);
    try std.testing.expectEqualSlices(u8, best_expected, best_scratch);
    var best_appended: std.ArrayList(u8) = .empty;
    defer best_appended.deinit(std.testing.allocator);
    try std.testing.expectEqual(best_expected.len, try encoder.encodeBestAppend(&best_appended, payload, best_options));
    try std.testing.expectEqualSlices(u8, best_expected, best_appended.items);

    const split_block_len: usize = 31;
    const best_split_expected = try encodeRawBestSplitAlloc(std.testing.allocator, payload, split_block_len, best_options);
    defer std.testing.allocator.free(best_split_expected);
    const best_split_owned = try encoder.encodeBestSplitAlloc(payload, split_block_len, best_options);
    defer std.testing.allocator.free(best_split_owned);
    try std.testing.expectEqualSlices(u8, best_split_expected, best_split_owned);
    const best_split_scratch = try encoder.encodeBestSplitScratch(payload, split_block_len, best_options);
    try std.testing.expectEqualSlices(u8, best_split_expected, best_split_scratch);
    const best_split_decoded = try decodeRawDeflateAllocExactSize(std.testing.allocator, best_split_scratch, payload.len);
    defer std.testing.allocator.free(best_split_decoded);
    try std.testing.expectEqualSlices(u8, payload, best_split_decoded);
    var best_split_appended: std.ArrayList(u8) = .empty;
    defer best_split_appended.deinit(std.testing.allocator);
    try best_split_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(best_split_expected.len, try encoder.encodeBestSplitAppend(&best_split_appended, payload, split_block_len, best_options));
    try std.testing.expectEqualSlices(u8, best_split_expected, best_split_appended.items["prefix:".len..]);
    try std.testing.expectError(error.InvalidBlockPlan, encoder.encodeBestSplitAlloc(payload, 0, best_options));

    const adaptive_split_options: AdaptiveSplitOptions = .{
        .min_block_len = 16,
        .max_block_len = 32,
        .sample_len = 8,
        .search_step = 8,
    };
    const best_adaptive_expected = try encodeRawBestAdaptiveSplitAlloc(std.testing.allocator, payload, best_options, adaptive_split_options);
    defer std.testing.allocator.free(best_adaptive_expected);
    const best_adaptive_owned = try encoder.encodeBestAdaptiveSplitAlloc(payload, best_options, adaptive_split_options);
    defer std.testing.allocator.free(best_adaptive_owned);
    try std.testing.expectEqualSlices(u8, best_adaptive_expected, best_adaptive_owned);
    const best_adaptive_scratch = try encoder.encodeBestAdaptiveSplitScratch(payload, best_options, adaptive_split_options);
    try std.testing.expectEqualSlices(u8, best_adaptive_expected, best_adaptive_scratch);
    const best_adaptive_decoded = try decodeRawDeflateAllocExactSize(std.testing.allocator, best_adaptive_scratch, payload.len);
    defer std.testing.allocator.free(best_adaptive_decoded);
    try std.testing.expectEqualSlices(u8, payload, best_adaptive_decoded);
    var best_adaptive_appended: std.ArrayList(u8) = .empty;
    defer best_adaptive_appended.deinit(std.testing.allocator);
    try std.testing.expectEqual(best_adaptive_expected.len, try encoder.encodeBestAdaptiveSplitAppend(&best_adaptive_appended, payload, best_options, adaptive_split_options));
    try std.testing.expectEqualSlices(u8, best_adaptive_expected, best_adaptive_appended.items);
    try std.testing.expectError(error.InvalidBlockPlan, encoder.encodeBestAdaptiveSplitAlloc(payload, best_options, .{ .min_block_len = 0 }));

    const level_expected = try encodeRawLevelAlloc(std.testing.allocator, payload, 1);
    defer std.testing.allocator.free(level_expected);
    const level_owned = try encoder.encodeLevelAlloc(payload, 1);
    defer std.testing.allocator.free(level_owned);
    try std.testing.expectEqualSlices(u8, level_expected, level_owned);
    const level_scratch = try encoder.encodeLevelScratch(payload, 1);
    try std.testing.expectEqualSlices(u8, level_expected, level_scratch);
    var level_appended: std.ArrayList(u8) = .empty;
    defer level_appended.deinit(std.testing.allocator);
    try std.testing.expectEqual(level_expected.len, try encoder.encodeLevelAppend(&level_appended, payload, 1));
    try std.testing.expectEqualSlices(u8, level_expected, level_appended.items);
    try std.testing.expectError(error.InvalidBlockPlan, encoder.encodeLevelAlloc(payload, 10));

    const preset_dictionary = "root raw deflate reusable dictionary";
    const dict_payload = "root raw deflate reusable dictionary payload";
    const dict_options = optionsForCompressionLevel(.fast);
    const fixed_dict_expected = try encodeRawFixedWithDictionaryAlloc(std.testing.allocator, dict_payload, preset_dictionary, dict_options);
    defer std.testing.allocator.free(fixed_dict_expected);
    const fixed_dict_owned = try encoder.encodeFixedWithDictionaryAlloc(dict_payload, preset_dictionary, dict_options);
    defer std.testing.allocator.free(fixed_dict_owned);
    try std.testing.expectEqualSlices(u8, fixed_dict_expected, fixed_dict_owned);
    const fixed_dict_scratch = try encoder.encodeFixedWithDictionaryScratch(dict_payload, preset_dictionary, dict_options);
    try std.testing.expectEqualSlices(u8, fixed_dict_expected, fixed_dict_scratch);
    var fixed_dict_appended: std.ArrayList(u8) = .empty;
    defer fixed_dict_appended.deinit(std.testing.allocator);
    try std.testing.expectEqual(fixed_dict_expected.len, try encoder.encodeFixedWithDictionaryAppend(&fixed_dict_appended, dict_payload, preset_dictionary, dict_options));
    try std.testing.expectEqualSlices(u8, fixed_dict_expected, fixed_dict_appended.items);

    const fixed_dict_split_expected = try encodeRawFixedSplitWithDictionaryAlloc(std.testing.allocator, dict_payload, preset_dictionary, 17, dict_options);
    defer std.testing.allocator.free(fixed_dict_split_expected);
    const fixed_dict_split_owned = try encoder.encodeFixedSplitWithDictionaryAlloc(dict_payload, preset_dictionary, 17, dict_options);
    defer std.testing.allocator.free(fixed_dict_split_owned);
    try std.testing.expectEqualSlices(u8, fixed_dict_split_expected, fixed_dict_split_owned);
    const fixed_dict_split_scratch = try encoder.encodeFixedSplitWithDictionaryScratch(dict_payload, preset_dictionary, 17, dict_options);
    try std.testing.expectEqualSlices(u8, fixed_dict_split_expected, fixed_dict_split_scratch);
    const fixed_dict_split_decoded = try decodeRawDeflateAllocWithDictionaryExactSize(std.testing.allocator, fixed_dict_split_scratch, preset_dictionary, dict_payload.len);
    defer std.testing.allocator.free(fixed_dict_split_decoded);
    try std.testing.expectEqualSlices(u8, dict_payload, fixed_dict_split_decoded);
    var fixed_dict_split_appended: std.ArrayList(u8) = .empty;
    defer fixed_dict_split_appended.deinit(std.testing.allocator);
    try std.testing.expectEqual(fixed_dict_split_expected.len, try encoder.encodeFixedSplitWithDictionaryAppend(&fixed_dict_split_appended, dict_payload, preset_dictionary, 17, dict_options));
    try std.testing.expectEqualSlices(u8, fixed_dict_split_expected, fixed_dict_split_appended.items);
    try std.testing.expectError(error.InvalidBlockPlan, encoder.encodeFixedSplitWithDictionaryAlloc(dict_payload, preset_dictionary, 0, dict_options));

    const best_dict_expected = try encodeRawBestWithDictionaryAlloc(std.testing.allocator, dict_payload, preset_dictionary, dict_options);
    defer std.testing.allocator.free(best_dict_expected);
    const best_dict_owned = try encoder.encodeBestWithDictionaryAlloc(dict_payload, preset_dictionary, dict_options);
    defer std.testing.allocator.free(best_dict_owned);
    try std.testing.expectEqualSlices(u8, best_dict_expected, best_dict_owned);
    const best_dict_scratch = try encoder.encodeBestWithDictionaryScratch(dict_payload, preset_dictionary, dict_options);
    try std.testing.expectEqualSlices(u8, best_dict_expected, best_dict_scratch);
    var best_dict_appended: std.ArrayList(u8) = .empty;
    defer best_dict_appended.deinit(std.testing.allocator);
    try std.testing.expectEqual(best_dict_expected.len, try encoder.encodeBestWithDictionaryAppend(&best_dict_appended, dict_payload, preset_dictionary, dict_options));
    try std.testing.expectEqualSlices(u8, best_dict_expected, best_dict_appended.items);

    const best_dict_split_expected = try encodeRawBestSplitWithDictionaryAlloc(std.testing.allocator, dict_payload, preset_dictionary, 17, dict_options);
    defer std.testing.allocator.free(best_dict_split_expected);
    const best_dict_split_owned = try encoder.encodeBestSplitWithDictionaryAlloc(dict_payload, preset_dictionary, 17, dict_options);
    defer std.testing.allocator.free(best_dict_split_owned);
    try std.testing.expectEqualSlices(u8, best_dict_split_expected, best_dict_split_owned);
    const best_dict_split_scratch = try encoder.encodeBestSplitWithDictionaryScratch(dict_payload, preset_dictionary, 17, dict_options);
    try std.testing.expectEqualSlices(u8, best_dict_split_expected, best_dict_split_scratch);
    const best_dict_split_decoded = try decodeRawDeflateAllocWithDictionaryExactSize(std.testing.allocator, best_dict_split_scratch, preset_dictionary, dict_payload.len);
    defer std.testing.allocator.free(best_dict_split_decoded);
    try std.testing.expectEqualSlices(u8, dict_payload, best_dict_split_decoded);
    var best_dict_split_appended: std.ArrayList(u8) = .empty;
    defer best_dict_split_appended.deinit(std.testing.allocator);
    try std.testing.expectEqual(best_dict_split_expected.len, try encoder.encodeBestSplitWithDictionaryAppend(&best_dict_split_appended, dict_payload, preset_dictionary, 17, dict_options));
    try std.testing.expectEqualSlices(u8, best_dict_split_expected, best_dict_split_appended.items);
    try std.testing.expectError(error.InvalidBlockPlan, encoder.encodeBestSplitWithDictionaryAlloc(dict_payload, preset_dictionary, 0, dict_options));

    const dict_adaptive_split_options: AdaptiveSplitOptions = .{
        .min_block_len = 8,
        .max_block_len = 24,
        .sample_len = 8,
        .search_step = 8,
    };
    const best_dict_adaptive_expected = try encodeRawBestAdaptiveSplitWithDictionaryAlloc(std.testing.allocator, dict_payload, preset_dictionary, dict_options, dict_adaptive_split_options);
    defer std.testing.allocator.free(best_dict_adaptive_expected);
    const best_dict_adaptive_owned = try encoder.encodeBestAdaptiveSplitWithDictionaryAlloc(dict_payload, preset_dictionary, dict_options, dict_adaptive_split_options);
    defer std.testing.allocator.free(best_dict_adaptive_owned);
    try std.testing.expectEqualSlices(u8, best_dict_adaptive_expected, best_dict_adaptive_owned);
    const best_dict_adaptive_scratch = try encoder.encodeBestAdaptiveSplitWithDictionaryScratch(dict_payload, preset_dictionary, dict_options, dict_adaptive_split_options);
    try std.testing.expectEqualSlices(u8, best_dict_adaptive_expected, best_dict_adaptive_scratch);
    const best_dict_adaptive_decoded = try decodeRawDeflateAllocWithDictionaryExactSize(std.testing.allocator, best_dict_adaptive_scratch, preset_dictionary, dict_payload.len);
    defer std.testing.allocator.free(best_dict_adaptive_decoded);
    try std.testing.expectEqualSlices(u8, dict_payload, best_dict_adaptive_decoded);
    var best_dict_adaptive_appended: std.ArrayList(u8) = .empty;
    defer best_dict_adaptive_appended.deinit(std.testing.allocator);
    try best_dict_adaptive_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(best_dict_adaptive_expected.len, try encoder.encodeBestAdaptiveSplitWithDictionaryAppend(&best_dict_adaptive_appended, dict_payload, preset_dictionary, dict_options, dict_adaptive_split_options));
    try std.testing.expectEqualSlices(u8, best_dict_adaptive_expected, best_dict_adaptive_appended.items["prefix:".len..]);
    try std.testing.expectError(error.InvalidBlockPlan, encoder.encodeBestAdaptiveSplitWithDictionaryAlloc(dict_payload, preset_dictionary, dict_options, .{ .min_block_len = 32, .max_block_len = 16 }));

    const level_dict_expected = try encodeRawLevelWithDictionaryAlloc(std.testing.allocator, dict_payload, preset_dictionary, 1);
    defer std.testing.allocator.free(level_dict_expected);
    const level_dict_owned = try encoder.encodeLevelWithDictionaryAlloc(dict_payload, preset_dictionary, 1);
    defer std.testing.allocator.free(level_dict_owned);
    try std.testing.expectEqualSlices(u8, level_dict_expected, level_dict_owned);
    const level_dict_scratch = try encoder.encodeLevelWithDictionaryScratch(dict_payload, preset_dictionary, 1);
    try std.testing.expectEqualSlices(u8, level_dict_expected, level_dict_scratch);
    var level_dict_appended: std.ArrayList(u8) = .empty;
    defer level_dict_appended.deinit(std.testing.allocator);
    try std.testing.expectEqual(level_dict_expected.len, try encoder.encodeLevelWithDictionaryAppend(&level_dict_appended, dict_payload, preset_dictionary, 1));
    try std.testing.expectEqualSlices(u8, level_dict_expected, level_dict_appended.items);
    try std.testing.expectError(error.InvalidBlockPlan, encoder.encodeLevelWithDictionaryAlloc(dict_payload, preset_dictionary, 10));

    const dict_decoded = try decodeRawDeflateAllocWithDictionaryExactSize(std.testing.allocator, best_dict_scratch, preset_dictionary, dict_payload.len);
    defer std.testing.allocator.free(dict_decoded);
    try std.testing.expectEqualSlices(u8, dict_payload, dict_decoded);

    const dynamic_literal_expected = try encodeRawDynamicLiteralAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(dynamic_literal_expected);
    const dynamic_literal_owned = try encoder.encodeDynamicLiteralAlloc(payload);
    defer std.testing.allocator.free(dynamic_literal_owned);
    try std.testing.expectEqualSlices(u8, dynamic_literal_expected, dynamic_literal_owned);
    const dynamic_literal_scratch = try encoder.encodeDynamicLiteralScratch(payload);
    try std.testing.expectEqualSlices(u8, dynamic_literal_expected, dynamic_literal_scratch);
    var dynamic_literal_appended: std.ArrayList(u8) = .empty;
    defer dynamic_literal_appended.deinit(std.testing.allocator);
    try dynamic_literal_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(dynamic_literal_expected.len, try encoder.encodeDynamicLiteralAppend(&dynamic_literal_appended, payload));
    try std.testing.expectEqualSlices(u8, dynamic_literal_expected, dynamic_literal_appended.items["prefix:".len..]);

    const dynamic_options = optionsForCompressionLevel(.default);
    const dynamic_expected = try encodeRawDynamicWithOptionsAlloc(std.testing.allocator, payload, dynamic_options);
    defer std.testing.allocator.free(dynamic_expected);
    const dynamic_owned = try encoder.encodeDynamicWithOptionsAlloc(payload, dynamic_options);
    defer std.testing.allocator.free(dynamic_owned);
    try std.testing.expectEqualSlices(u8, dynamic_expected, dynamic_owned);
    const dynamic_scratch = try encoder.encodeDynamicWithOptionsScratch(payload, dynamic_options);
    try std.testing.expectEqualSlices(u8, dynamic_expected, dynamic_scratch);
    var dynamic_appended: std.ArrayList(u8) = .empty;
    defer dynamic_appended.deinit(std.testing.allocator);
    try std.testing.expectEqual(dynamic_expected.len, try encoder.encodeDynamicWithOptionsAppend(&dynamic_appended, payload, dynamic_options));
    try std.testing.expectEqualSlices(u8, dynamic_expected, dynamic_appended.items);

    const dynamic_decoded = try decodeRawDeflateAllocExactSize(std.testing.allocator, dynamic_scratch, payload.len);
    defer std.testing.allocator.free(dynamic_decoded);
    try std.testing.expectEqualSlices(u8, payload, dynamic_decoded);

    const dynamic_split_expected = try encodeRawDynamicSplitAlloc(std.testing.allocator, payload, 23, dynamic_options);
    defer std.testing.allocator.free(dynamic_split_expected);
    const dynamic_split_owned = try encoder.encodeDynamicSplitAlloc(payload, 23, dynamic_options);
    defer std.testing.allocator.free(dynamic_split_owned);
    try std.testing.expectEqualSlices(u8, dynamic_split_expected, dynamic_split_owned);
    const dynamic_split_scratch = try encoder.encodeDynamicSplitScratch(payload, 23, dynamic_options);
    try std.testing.expectEqualSlices(u8, dynamic_split_expected, dynamic_split_scratch);
    const dynamic_split_decoded = try decodeRawDeflateAllocExactSize(std.testing.allocator, dynamic_split_scratch, payload.len);
    defer std.testing.allocator.free(dynamic_split_decoded);
    try std.testing.expectEqualSlices(u8, payload, dynamic_split_decoded);
    var dynamic_split_appended: std.ArrayList(u8) = .empty;
    defer dynamic_split_appended.deinit(std.testing.allocator);
    try dynamic_split_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(dynamic_split_expected.len, try encoder.encodeDynamicSplitAppend(&dynamic_split_appended, payload, 23, dynamic_options));
    try std.testing.expectEqualSlices(u8, dynamic_split_expected, dynamic_split_appended.items["prefix:".len..]);
    try std.testing.expectError(error.InvalidBlockPlan, encoder.encodeDynamicSplitAlloc(payload, 0, dynamic_options));

    const dynamic_dict_expected = try encodeRawDynamicWithDictionaryAlloc(std.testing.allocator, dict_payload, preset_dictionary, dynamic_options);
    defer std.testing.allocator.free(dynamic_dict_expected);
    const dynamic_dict_owned = try encoder.encodeDynamicWithDictionaryAlloc(dict_payload, preset_dictionary, dynamic_options);
    defer std.testing.allocator.free(dynamic_dict_owned);
    try std.testing.expectEqualSlices(u8, dynamic_dict_expected, dynamic_dict_owned);
    const dynamic_dict_scratch = try encoder.encodeDynamicWithDictionaryScratch(dict_payload, preset_dictionary, dynamic_options);
    try std.testing.expectEqualSlices(u8, dynamic_dict_expected, dynamic_dict_scratch);
    var dynamic_dict_appended: std.ArrayList(u8) = .empty;
    defer dynamic_dict_appended.deinit(std.testing.allocator);
    try dynamic_dict_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(dynamic_dict_expected.len, try encoder.encodeDynamicWithDictionaryAppend(&dynamic_dict_appended, dict_payload, preset_dictionary, dynamic_options));
    try std.testing.expectEqualSlices(u8, dynamic_dict_expected, dynamic_dict_appended.items["prefix:".len..]);

    const dynamic_dict_decoded = try decodeRawDeflateAllocWithDictionaryExactSize(std.testing.allocator, dynamic_dict_scratch, preset_dictionary, dict_payload.len);
    defer std.testing.allocator.free(dynamic_dict_decoded);
    try std.testing.expectEqualSlices(u8, dict_payload, dynamic_dict_decoded);

    const dynamic_dict_split_expected = try encodeRawDynamicSplitWithDictionaryAlloc(std.testing.allocator, dict_payload, preset_dictionary, 17, dynamic_options);
    defer std.testing.allocator.free(dynamic_dict_split_expected);
    const dynamic_dict_split_owned = try encoder.encodeDynamicSplitWithDictionaryAlloc(dict_payload, preset_dictionary, 17, dynamic_options);
    defer std.testing.allocator.free(dynamic_dict_split_owned);
    try std.testing.expectEqualSlices(u8, dynamic_dict_split_expected, dynamic_dict_split_owned);
    const dynamic_dict_split_scratch = try encoder.encodeDynamicSplitWithDictionaryScratch(dict_payload, preset_dictionary, 17, dynamic_options);
    try std.testing.expectEqualSlices(u8, dynamic_dict_split_expected, dynamic_dict_split_scratch);
    const dynamic_dict_split_decoded = try decodeRawDeflateAllocWithDictionaryExactSize(std.testing.allocator, dynamic_dict_split_scratch, preset_dictionary, dict_payload.len);
    defer std.testing.allocator.free(dynamic_dict_split_decoded);
    try std.testing.expectEqualSlices(u8, dict_payload, dynamic_dict_split_decoded);
    var dynamic_dict_split_appended: std.ArrayList(u8) = .empty;
    defer dynamic_dict_split_appended.deinit(std.testing.allocator);
    try dynamic_dict_split_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(dynamic_dict_split_expected.len, try encoder.encodeDynamicSplitWithDictionaryAppend(&dynamic_dict_split_appended, dict_payload, preset_dictionary, 17, dynamic_options));
    try std.testing.expectEqualSlices(u8, dynamic_dict_split_expected, dynamic_dict_split_appended.items["prefix:".len..]);
    try std.testing.expectError(error.InvalidBlockPlan, encoder.encodeDynamicSplitWithDictionaryAlloc(dict_payload, preset_dictionary, 0, dynamic_options));
}

test "root zlib encoder reuses stored scratch" {
    const payload = "root zlib reusable stored encoder payload" ** 2;
    const preset_dictionary = "root zlib reusable stored dictionary";
    const chunks = [_][]const u8{
        payload[0..11],
        payload[11..39],
        payload[39..],
    };
    const expected = try encodeZlibStoredAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(expected);
    const expected_dict = try encodeZlibStoredWithDictionaryAlloc(std.testing.allocator, payload, preset_dictionary);
    defer std.testing.allocator.free(expected_dict);
    const expected_chunks = try encodeZlibStoredChunksAlloc(std.testing.allocator, &chunks);
    defer std.testing.allocator.free(expected_chunks);
    const expected_dict_chunks = try encodeZlibStoredWithDictionaryChunksAlloc(std.testing.allocator, &chunks, preset_dictionary);
    defer std.testing.allocator.free(expected_dict_chunks);
    try std.testing.expectEqualSlices(u8, expected, expected_chunks);
    try std.testing.expectEqualSlices(u8, expected_dict, expected_dict_chunks);

    var encoder = ZlibEncoder.init(std.testing.allocator);
    defer encoder.deinit();

    const owned = try encoder.encodeStoredAlloc(payload);
    defer std.testing.allocator.free(owned);
    try std.testing.expectEqualSlices(u8, expected, owned);
    const scratch = try encoder.encodeStoredScratch(payload);
    try std.testing.expectEqualSlices(u8, expected, scratch);
    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(std.testing.allocator);
    try appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(expected.len, try encoder.encodeStoredAppend(&appended, payload));
    try std.testing.expectEqualSlices(u8, expected, appended.items["prefix:".len..]);
    const into = try std.testing.allocator.alloc(u8, try zlibStoredChunksEncodedSize(&chunks));
    defer std.testing.allocator.free(into);
    try std.testing.expectEqual(expected.len, try encoder.encodeStoredIntoSlice(payload, into));
    try std.testing.expectEqualSlices(u8, expected, into[0..expected.len]);

    const dict_owned = try encoder.encodeStoredWithDictionaryAlloc(payload, preset_dictionary);
    defer std.testing.allocator.free(dict_owned);
    try std.testing.expectEqualSlices(u8, expected_dict, dict_owned);
    const dict_scratch = try encoder.encodeStoredWithDictionaryScratch(payload, preset_dictionary);
    try std.testing.expectEqualSlices(u8, expected_dict, dict_scratch);
    var dict_appended: std.ArrayList(u8) = .empty;
    defer dict_appended.deinit(std.testing.allocator);
    try std.testing.expectEqual(expected_dict.len, try encoder.encodeStoredWithDictionaryAppend(&dict_appended, payload, preset_dictionary));
    try std.testing.expectEqualSlices(u8, expected_dict, dict_appended.items);
    const dict_into = try std.testing.allocator.alloc(u8, try zlibStoredWithDictionaryChunksEncodedSize(&chunks));
    defer std.testing.allocator.free(dict_into);
    try std.testing.expectEqual(expected_dict.len, try encoder.encodeStoredWithDictionaryIntoSlice(payload, preset_dictionary, dict_into));
    try std.testing.expectEqualSlices(u8, expected_dict, dict_into[0..expected_dict.len]);

    const chunks_owned = try encoder.encodeStoredChunksAlloc(&chunks);
    defer std.testing.allocator.free(chunks_owned);
    try std.testing.expectEqualSlices(u8, expected_chunks, chunks_owned);
    const chunks_scratch = try encoder.encodeStoredChunksScratch(&chunks);
    try std.testing.expectEqualSlices(u8, expected_chunks, chunks_scratch);
    const decoded = try decodeZlibStoredAlloc(std.testing.allocator, chunks_scratch);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    var chunks_appended: std.ArrayList(u8) = .empty;
    defer chunks_appended.deinit(std.testing.allocator);
    _ = try encoder.encodeStoredChunksAppend(&chunks_appended, &chunks);
    try std.testing.expectEqualSlices(u8, expected_chunks, chunks_appended.items);
    const chunks_into = try std.testing.allocator.alloc(u8, expected_chunks.len);
    defer std.testing.allocator.free(chunks_into);
    try std.testing.expectEqual(expected_chunks.len, try encoder.encodeStoredChunksIntoSlice(&chunks, chunks_into));
    try std.testing.expectEqualSlices(u8, expected_chunks, chunks_into[0..expected_chunks.len]);

    const dict_chunks_owned = try encoder.encodeStoredChunksWithDictionaryAlloc(&chunks, preset_dictionary);
    defer std.testing.allocator.free(dict_chunks_owned);
    try std.testing.expectEqualSlices(u8, expected_dict_chunks, dict_chunks_owned);
    const dict_chunks_scratch = try encoder.encodeStoredChunksWithDictionaryScratch(&chunks, preset_dictionary);
    try std.testing.expectEqualSlices(u8, expected_dict_chunks, dict_chunks_scratch);
    const decoded_dict = try decodeZlibStoredAllocWithDictionary(std.testing.allocator, dict_chunks_scratch, preset_dictionary);
    defer std.testing.allocator.free(decoded_dict);
    try std.testing.expectEqualSlices(u8, payload, decoded_dict);
    var dict_chunks_appended: std.ArrayList(u8) = .empty;
    defer dict_chunks_appended.deinit(std.testing.allocator);
    _ = try encoder.encodeStoredChunksWithDictionaryAppend(&dict_chunks_appended, &chunks, preset_dictionary);
    try std.testing.expectEqualSlices(u8, expected_dict_chunks, dict_chunks_appended.items);
    const dict_chunks_into = try std.testing.allocator.alloc(u8, expected_dict_chunks.len);
    defer std.testing.allocator.free(dict_chunks_into);
    try std.testing.expectEqual(expected_dict_chunks.len, try encoder.encodeStoredChunksWithDictionaryIntoSlice(&chunks, preset_dictionary, dict_chunks_into));
    try std.testing.expectEqualSlices(u8, expected_dict_chunks, dict_chunks_into[0..expected_dict_chunks.len]);

    const fixed_expected = try encodeZlibFixedAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(fixed_expected);
    const fixed_owned = try encoder.encodeFixedAlloc(payload);
    defer std.testing.allocator.free(fixed_owned);
    try std.testing.expectEqualSlices(u8, fixed_expected, fixed_owned);
    const fixed_scratch = try encoder.encodeFixedScratch(payload);
    try std.testing.expectEqualSlices(u8, fixed_expected, fixed_scratch);
    var fixed_appended: std.ArrayList(u8) = .empty;
    defer fixed_appended.deinit(std.testing.allocator);
    try fixed_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(fixed_expected.len, try encoder.encodeFixedAppend(&fixed_appended, payload));
    try std.testing.expectEqualSlices(u8, fixed_expected, fixed_appended.items["prefix:".len..]);

    const fixed_options = optionsForCompressionLevel(.fast);
    const fixed_options_expected = try encodeZlibFixedWithOptionsAlloc(std.testing.allocator, payload, fixed_options);
    defer std.testing.allocator.free(fixed_options_expected);
    const fixed_options_owned = try encoder.encodeFixedWithOptionsAlloc(payload, fixed_options);
    defer std.testing.allocator.free(fixed_options_owned);
    try std.testing.expectEqualSlices(u8, fixed_options_expected, fixed_options_owned);
    const fixed_options_scratch = try encoder.encodeFixedWithOptionsScratch(payload, fixed_options);
    try std.testing.expectEqualSlices(u8, fixed_options_expected, fixed_options_scratch);
    var fixed_options_appended: std.ArrayList(u8) = .empty;
    defer fixed_options_appended.deinit(std.testing.allocator);
    try std.testing.expectEqual(fixed_options_expected.len, try encoder.encodeFixedWithOptionsAppend(&fixed_options_appended, payload, fixed_options));
    try std.testing.expectEqualSlices(u8, fixed_options_expected, fixed_options_appended.items);

    const fixed_split_expected = try encodeZlibFixedSplitAlloc(std.testing.allocator, payload, 23, fixed_options);
    defer std.testing.allocator.free(fixed_split_expected);
    const fixed_split_owned = try encoder.encodeFixedSplitAlloc(payload, 23, fixed_options);
    defer std.testing.allocator.free(fixed_split_owned);
    try std.testing.expectEqualSlices(u8, fixed_split_expected, fixed_split_owned);
    const fixed_split_scratch = try encoder.encodeFixedSplitScratch(payload, 23, fixed_options);
    try std.testing.expectEqualSlices(u8, fixed_split_expected, fixed_split_scratch);
    const fixed_split_decoded = try decodeZlibAllocExactSize(std.testing.allocator, fixed_split_scratch, payload.len);
    defer std.testing.allocator.free(fixed_split_decoded);
    try std.testing.expectEqualSlices(u8, payload, fixed_split_decoded);
    var fixed_split_appended: std.ArrayList(u8) = .empty;
    defer fixed_split_appended.deinit(std.testing.allocator);
    try fixed_split_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(fixed_split_expected.len, try encoder.encodeFixedSplitAppend(&fixed_split_appended, payload, 23, fixed_options));
    try std.testing.expectEqualSlices(u8, fixed_split_expected, fixed_split_appended.items["prefix:".len..]);
    try std.testing.expectError(error.InvalidBlockPlan, encoder.encodeFixedSplitAlloc(payload, 0, fixed_options));

    const best_options = optionsForCompressionLevel(.fastest);
    const best_expected = try encodeZlibBestAlloc(std.testing.allocator, payload, best_options);
    defer std.testing.allocator.free(best_expected);
    const best_owned = try encoder.encodeBestAlloc(payload, best_options);
    defer std.testing.allocator.free(best_owned);
    try std.testing.expectEqualSlices(u8, best_expected, best_owned);
    const best_scratch = try encoder.encodeBestScratch(payload, best_options);
    try std.testing.expectEqualSlices(u8, best_expected, best_scratch);
    var best_appended: std.ArrayList(u8) = .empty;
    defer best_appended.deinit(std.testing.allocator);
    try std.testing.expectEqual(best_expected.len, try encoder.encodeBestAppend(&best_appended, payload, best_options));
    try std.testing.expectEqualSlices(u8, best_expected, best_appended.items);

    const split_block_len: usize = 29;
    const best_split_expected = try encodeZlibBestSplitAlloc(std.testing.allocator, payload, split_block_len, best_options);
    defer std.testing.allocator.free(best_split_expected);
    const best_split_owned = try encoder.encodeBestSplitAlloc(payload, split_block_len, best_options);
    defer std.testing.allocator.free(best_split_owned);
    try std.testing.expectEqualSlices(u8, best_split_expected, best_split_owned);
    const best_split_scratch = try encoder.encodeBestSplitScratch(payload, split_block_len, best_options);
    try std.testing.expectEqualSlices(u8, best_split_expected, best_split_scratch);
    const best_split_decoded = try decodeZlibAllocExactSize(std.testing.allocator, best_split_scratch, payload.len);
    defer std.testing.allocator.free(best_split_decoded);
    try std.testing.expectEqualSlices(u8, payload, best_split_decoded);
    var best_split_appended: std.ArrayList(u8) = .empty;
    defer best_split_appended.deinit(std.testing.allocator);
    try best_split_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(best_split_expected.len, try encoder.encodeBestSplitAppend(&best_split_appended, payload, split_block_len, best_options));
    try std.testing.expectEqualSlices(u8, best_split_expected, best_split_appended.items["prefix:".len..]);
    try std.testing.expectError(error.InvalidBlockPlan, encoder.encodeBestSplitAlloc(payload, 0, best_options));

    const adaptive_split_options: AdaptiveSplitOptions = .{
        .min_block_len = 16,
        .max_block_len = 32,
        .sample_len = 8,
        .search_step = 8,
    };
    const best_adaptive_expected = try encodeZlibBestAdaptiveSplitAlloc(std.testing.allocator, payload, best_options, adaptive_split_options);
    defer std.testing.allocator.free(best_adaptive_expected);
    const best_adaptive_owned = try encoder.encodeBestAdaptiveSplitAlloc(payload, best_options, adaptive_split_options);
    defer std.testing.allocator.free(best_adaptive_owned);
    try std.testing.expectEqualSlices(u8, best_adaptive_expected, best_adaptive_owned);
    const best_adaptive_scratch = try encoder.encodeBestAdaptiveSplitScratch(payload, best_options, adaptive_split_options);
    try std.testing.expectEqualSlices(u8, best_adaptive_expected, best_adaptive_scratch);
    const best_adaptive_decoded = try decodeZlibAllocExactSize(std.testing.allocator, best_adaptive_scratch, payload.len);
    defer std.testing.allocator.free(best_adaptive_decoded);
    try std.testing.expectEqualSlices(u8, payload, best_adaptive_decoded);
    var best_adaptive_appended: std.ArrayList(u8) = .empty;
    defer best_adaptive_appended.deinit(std.testing.allocator);
    try std.testing.expectEqual(best_adaptive_expected.len, try encoder.encodeBestAdaptiveSplitAppend(&best_adaptive_appended, payload, best_options, adaptive_split_options));
    try std.testing.expectEqualSlices(u8, best_adaptive_expected, best_adaptive_appended.items);
    try std.testing.expectError(error.InvalidBlockPlan, encoder.encodeBestAdaptiveSplitAlloc(payload, best_options, .{ .min_block_len = 0 }));

    const level_expected = try encodeZlibLevelAlloc(std.testing.allocator, payload, 1);
    defer std.testing.allocator.free(level_expected);
    const level_owned = try encoder.encodeLevelAlloc(payload, 1);
    defer std.testing.allocator.free(level_owned);
    try std.testing.expectEqualSlices(u8, level_expected, level_owned);
    const level_scratch = try encoder.encodeLevelScratch(payload, 1);
    try std.testing.expectEqualSlices(u8, level_expected, level_scratch);
    var level_appended: std.ArrayList(u8) = .empty;
    defer level_appended.deinit(std.testing.allocator);
    try std.testing.expectEqual(level_expected.len, try encoder.encodeLevelAppend(&level_appended, payload, 1));
    try std.testing.expectEqualSlices(u8, level_expected, level_appended.items);
    try std.testing.expectError(error.InvalidBlockPlan, encoder.encodeLevelAlloc(payload, 10));

    const dict_options = optionsForCompressionLevel(.fast);
    const fixed_dict_expected = try encodeZlibFixedWithDictionaryAlloc(std.testing.allocator, payload, preset_dictionary, dict_options);
    defer std.testing.allocator.free(fixed_dict_expected);
    const fixed_dict_owned = try encoder.encodeFixedWithDictionaryAlloc(payload, preset_dictionary, dict_options);
    defer std.testing.allocator.free(fixed_dict_owned);
    try std.testing.expectEqualSlices(u8, fixed_dict_expected, fixed_dict_owned);
    const fixed_dict_scratch = try encoder.encodeFixedWithDictionaryScratch(payload, preset_dictionary, dict_options);
    try std.testing.expectEqualSlices(u8, fixed_dict_expected, fixed_dict_scratch);
    var fixed_dict_appended: std.ArrayList(u8) = .empty;
    defer fixed_dict_appended.deinit(std.testing.allocator);
    try std.testing.expectEqual(fixed_dict_expected.len, try encoder.encodeFixedWithDictionaryAppend(&fixed_dict_appended, payload, preset_dictionary, dict_options));
    try std.testing.expectEqualSlices(u8, fixed_dict_expected, fixed_dict_appended.items);

    const fixed_dict_split_expected = try encodeZlibFixedSplitWithDictionaryAlloc(std.testing.allocator, payload, preset_dictionary, 19, dict_options);
    defer std.testing.allocator.free(fixed_dict_split_expected);
    const fixed_dict_split_owned = try encoder.encodeFixedSplitWithDictionaryAlloc(payload, preset_dictionary, 19, dict_options);
    defer std.testing.allocator.free(fixed_dict_split_owned);
    try std.testing.expectEqualSlices(u8, fixed_dict_split_expected, fixed_dict_split_owned);
    const fixed_dict_split_scratch = try encoder.encodeFixedSplitWithDictionaryScratch(payload, preset_dictionary, 19, dict_options);
    try std.testing.expectEqualSlices(u8, fixed_dict_split_expected, fixed_dict_split_scratch);
    const fixed_dict_split_decoded = try decodeZlibAllocWithDictionaryExactSize(std.testing.allocator, fixed_dict_split_scratch, preset_dictionary, payload.len);
    defer std.testing.allocator.free(fixed_dict_split_decoded);
    try std.testing.expectEqualSlices(u8, payload, fixed_dict_split_decoded);
    var fixed_dict_split_appended: std.ArrayList(u8) = .empty;
    defer fixed_dict_split_appended.deinit(std.testing.allocator);
    try std.testing.expectEqual(fixed_dict_split_expected.len, try encoder.encodeFixedSplitWithDictionaryAppend(&fixed_dict_split_appended, payload, preset_dictionary, 19, dict_options));
    try std.testing.expectEqualSlices(u8, fixed_dict_split_expected, fixed_dict_split_appended.items);
    try std.testing.expectError(error.InvalidBlockPlan, encoder.encodeFixedSplitWithDictionaryAlloc(payload, preset_dictionary, 0, dict_options));

    const best_dict_expected = try encodeZlibBestWithDictionaryAlloc(std.testing.allocator, payload, preset_dictionary, dict_options);
    defer std.testing.allocator.free(best_dict_expected);
    const best_dict_owned = try encoder.encodeBestWithDictionaryAlloc(payload, preset_dictionary, dict_options);
    defer std.testing.allocator.free(best_dict_owned);
    try std.testing.expectEqualSlices(u8, best_dict_expected, best_dict_owned);
    const best_dict_scratch = try encoder.encodeBestWithDictionaryScratch(payload, preset_dictionary, dict_options);
    try std.testing.expectEqualSlices(u8, best_dict_expected, best_dict_scratch);
    var best_dict_appended: std.ArrayList(u8) = .empty;
    defer best_dict_appended.deinit(std.testing.allocator);
    try std.testing.expectEqual(best_dict_expected.len, try encoder.encodeBestWithDictionaryAppend(&best_dict_appended, payload, preset_dictionary, dict_options));
    try std.testing.expectEqualSlices(u8, best_dict_expected, best_dict_appended.items);

    const best_dict_split_expected = try encodeZlibBestSplitWithDictionaryAlloc(std.testing.allocator, payload, preset_dictionary, 19, dict_options);
    defer std.testing.allocator.free(best_dict_split_expected);
    const best_dict_split_owned = try encoder.encodeBestSplitWithDictionaryAlloc(payload, preset_dictionary, 19, dict_options);
    defer std.testing.allocator.free(best_dict_split_owned);
    try std.testing.expectEqualSlices(u8, best_dict_split_expected, best_dict_split_owned);
    const best_dict_split_scratch = try encoder.encodeBestSplitWithDictionaryScratch(payload, preset_dictionary, 19, dict_options);
    try std.testing.expectEqualSlices(u8, best_dict_split_expected, best_dict_split_scratch);
    const best_dict_split_decoded = try decodeZlibAllocWithDictionaryExactSize(std.testing.allocator, best_dict_split_scratch, preset_dictionary, payload.len);
    defer std.testing.allocator.free(best_dict_split_decoded);
    try std.testing.expectEqualSlices(u8, payload, best_dict_split_decoded);
    var best_dict_split_appended: std.ArrayList(u8) = .empty;
    defer best_dict_split_appended.deinit(std.testing.allocator);
    try std.testing.expectEqual(best_dict_split_expected.len, try encoder.encodeBestSplitWithDictionaryAppend(&best_dict_split_appended, payload, preset_dictionary, 19, dict_options));
    try std.testing.expectEqualSlices(u8, best_dict_split_expected, best_dict_split_appended.items);
    try std.testing.expectError(error.InvalidBlockPlan, encoder.encodeBestSplitWithDictionaryAlloc(payload, preset_dictionary, 0, dict_options));

    const dict_adaptive_split_options: AdaptiveSplitOptions = .{
        .min_block_len = 16,
        .max_block_len = 32,
        .sample_len = 8,
        .search_step = 8,
    };
    const best_dict_adaptive_expected = try encodeZlibBestAdaptiveSplitWithDictionaryAlloc(std.testing.allocator, payload, preset_dictionary, dict_options, dict_adaptive_split_options);
    defer std.testing.allocator.free(best_dict_adaptive_expected);
    const best_dict_adaptive_owned = try encoder.encodeBestAdaptiveSplitWithDictionaryAlloc(payload, preset_dictionary, dict_options, dict_adaptive_split_options);
    defer std.testing.allocator.free(best_dict_adaptive_owned);
    try std.testing.expectEqualSlices(u8, best_dict_adaptive_expected, best_dict_adaptive_owned);
    const best_dict_adaptive_scratch = try encoder.encodeBestAdaptiveSplitWithDictionaryScratch(payload, preset_dictionary, dict_options, dict_adaptive_split_options);
    try std.testing.expectEqualSlices(u8, best_dict_adaptive_expected, best_dict_adaptive_scratch);
    const best_dict_adaptive_decoded = try decodeZlibAllocWithDictionaryExactSize(std.testing.allocator, best_dict_adaptive_scratch, preset_dictionary, payload.len);
    defer std.testing.allocator.free(best_dict_adaptive_decoded);
    try std.testing.expectEqualSlices(u8, payload, best_dict_adaptive_decoded);
    var best_dict_adaptive_appended: std.ArrayList(u8) = .empty;
    defer best_dict_adaptive_appended.deinit(std.testing.allocator);
    try best_dict_adaptive_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(best_dict_adaptive_expected.len, try encoder.encodeBestAdaptiveSplitWithDictionaryAppend(&best_dict_adaptive_appended, payload, preset_dictionary, dict_options, dict_adaptive_split_options));
    try std.testing.expectEqualSlices(u8, best_dict_adaptive_expected, best_dict_adaptive_appended.items["prefix:".len..]);
    try std.testing.expectError(error.InvalidBlockPlan, encoder.encodeBestAdaptiveSplitWithDictionaryAlloc(payload, preset_dictionary, dict_options, .{ .min_block_len = 32, .max_block_len = 16 }));

    const level_dict_expected = try encodeZlibLevelWithDictionaryAlloc(std.testing.allocator, payload, preset_dictionary, 1);
    defer std.testing.allocator.free(level_dict_expected);
    const level_dict_owned = try encoder.encodeLevelWithDictionaryAlloc(payload, preset_dictionary, 1);
    defer std.testing.allocator.free(level_dict_owned);
    try std.testing.expectEqualSlices(u8, level_dict_expected, level_dict_owned);
    const level_dict_scratch = try encoder.encodeLevelWithDictionaryScratch(payload, preset_dictionary, 1);
    try std.testing.expectEqualSlices(u8, level_dict_expected, level_dict_scratch);
    var level_dict_appended: std.ArrayList(u8) = .empty;
    defer level_dict_appended.deinit(std.testing.allocator);
    try std.testing.expectEqual(level_dict_expected.len, try encoder.encodeLevelWithDictionaryAppend(&level_dict_appended, payload, preset_dictionary, 1));
    try std.testing.expectEqualSlices(u8, level_dict_expected, level_dict_appended.items);
    try std.testing.expectError(error.InvalidBlockPlan, encoder.encodeLevelWithDictionaryAlloc(payload, preset_dictionary, 10));

    const dict_decoded = try decodeZlibAllocWithDictionaryExactSize(std.testing.allocator, best_dict_scratch, preset_dictionary, payload.len);
    defer std.testing.allocator.free(dict_decoded);
    try std.testing.expectEqualSlices(u8, payload, dict_decoded);

    const dynamic_literal_expected = try encodeZlibDynamicLiteralAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(dynamic_literal_expected);
    const dynamic_literal_owned = try encoder.encodeDynamicLiteralAlloc(payload);
    defer std.testing.allocator.free(dynamic_literal_owned);
    try std.testing.expectEqualSlices(u8, dynamic_literal_expected, dynamic_literal_owned);
    const dynamic_literal_scratch = try encoder.encodeDynamicLiteralScratch(payload);
    try std.testing.expectEqualSlices(u8, dynamic_literal_expected, dynamic_literal_scratch);
    var dynamic_literal_appended: std.ArrayList(u8) = .empty;
    defer dynamic_literal_appended.deinit(std.testing.allocator);
    try dynamic_literal_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(dynamic_literal_expected.len, try encoder.encodeDynamicLiteralAppend(&dynamic_literal_appended, payload));
    try std.testing.expectEqualSlices(u8, dynamic_literal_expected, dynamic_literal_appended.items["prefix:".len..]);

    const dynamic_options = optionsForCompressionLevel(.default);
    const dynamic_expected = try encodeZlibDynamicWithOptionsAlloc(std.testing.allocator, payload, dynamic_options);
    defer std.testing.allocator.free(dynamic_expected);
    const dynamic_owned = try encoder.encodeDynamicWithOptionsAlloc(payload, dynamic_options);
    defer std.testing.allocator.free(dynamic_owned);
    try std.testing.expectEqualSlices(u8, dynamic_expected, dynamic_owned);
    const dynamic_scratch = try encoder.encodeDynamicWithOptionsScratch(payload, dynamic_options);
    try std.testing.expectEqualSlices(u8, dynamic_expected, dynamic_scratch);
    var dynamic_appended: std.ArrayList(u8) = .empty;
    defer dynamic_appended.deinit(std.testing.allocator);
    try std.testing.expectEqual(dynamic_expected.len, try encoder.encodeDynamicWithOptionsAppend(&dynamic_appended, payload, dynamic_options));
    try std.testing.expectEqualSlices(u8, dynamic_expected, dynamic_appended.items);

    const dynamic_decoded = try decodeZlibAllocExactSize(std.testing.allocator, dynamic_scratch, payload.len);
    defer std.testing.allocator.free(dynamic_decoded);
    try std.testing.expectEqualSlices(u8, payload, dynamic_decoded);

    const dynamic_split_expected = try encodeZlibDynamicSplitAlloc(std.testing.allocator, payload, 23, dynamic_options);
    defer std.testing.allocator.free(dynamic_split_expected);
    const dynamic_split_owned = try encoder.encodeDynamicSplitAlloc(payload, 23, dynamic_options);
    defer std.testing.allocator.free(dynamic_split_owned);
    try std.testing.expectEqualSlices(u8, dynamic_split_expected, dynamic_split_owned);
    const dynamic_split_scratch = try encoder.encodeDynamicSplitScratch(payload, 23, dynamic_options);
    try std.testing.expectEqualSlices(u8, dynamic_split_expected, dynamic_split_scratch);
    const dynamic_split_decoded = try decodeZlibAllocExactSize(std.testing.allocator, dynamic_split_scratch, payload.len);
    defer std.testing.allocator.free(dynamic_split_decoded);
    try std.testing.expectEqualSlices(u8, payload, dynamic_split_decoded);
    var dynamic_split_appended: std.ArrayList(u8) = .empty;
    defer dynamic_split_appended.deinit(std.testing.allocator);
    try dynamic_split_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(dynamic_split_expected.len, try encoder.encodeDynamicSplitAppend(&dynamic_split_appended, payload, 23, dynamic_options));
    try std.testing.expectEqualSlices(u8, dynamic_split_expected, dynamic_split_appended.items["prefix:".len..]);
    try std.testing.expectError(error.InvalidBlockPlan, encoder.encodeDynamicSplitAlloc(payload, 0, dynamic_options));

    const dynamic_dict_expected = try encodeZlibDynamicWithDictionaryAlloc(std.testing.allocator, payload, preset_dictionary, dynamic_options);
    defer std.testing.allocator.free(dynamic_dict_expected);
    const dynamic_dict_owned = try encoder.encodeDynamicWithDictionaryAlloc(payload, preset_dictionary, dynamic_options);
    defer std.testing.allocator.free(dynamic_dict_owned);
    try std.testing.expectEqualSlices(u8, dynamic_dict_expected, dynamic_dict_owned);
    const dynamic_dict_scratch = try encoder.encodeDynamicWithDictionaryScratch(payload, preset_dictionary, dynamic_options);
    try std.testing.expectEqualSlices(u8, dynamic_dict_expected, dynamic_dict_scratch);
    var dynamic_dict_appended: std.ArrayList(u8) = .empty;
    defer dynamic_dict_appended.deinit(std.testing.allocator);
    try std.testing.expectEqual(dynamic_dict_expected.len, try encoder.encodeDynamicWithDictionaryAppend(&dynamic_dict_appended, payload, preset_dictionary, dynamic_options));
    try std.testing.expectEqualSlices(u8, dynamic_dict_expected, dynamic_dict_appended.items);

    const dynamic_dict_decoded = try decodeZlibAllocWithDictionaryExactSize(std.testing.allocator, dynamic_dict_scratch, preset_dictionary, payload.len);
    defer std.testing.allocator.free(dynamic_dict_decoded);
    try std.testing.expectEqualSlices(u8, payload, dynamic_dict_decoded);

    const dynamic_dict_split_expected = try encodeZlibDynamicSplitWithDictionaryAlloc(std.testing.allocator, payload, preset_dictionary, 19, dynamic_options);
    defer std.testing.allocator.free(dynamic_dict_split_expected);
    const dynamic_dict_split_owned = try encoder.encodeDynamicSplitWithDictionaryAlloc(payload, preset_dictionary, 19, dynamic_options);
    defer std.testing.allocator.free(dynamic_dict_split_owned);
    try std.testing.expectEqualSlices(u8, dynamic_dict_split_expected, dynamic_dict_split_owned);
    const dynamic_dict_split_scratch = try encoder.encodeDynamicSplitWithDictionaryScratch(payload, preset_dictionary, 19, dynamic_options);
    try std.testing.expectEqualSlices(u8, dynamic_dict_split_expected, dynamic_dict_split_scratch);
    const dynamic_dict_split_decoded = try decodeZlibAllocWithDictionaryExactSize(std.testing.allocator, dynamic_dict_split_scratch, preset_dictionary, payload.len);
    defer std.testing.allocator.free(dynamic_dict_split_decoded);
    try std.testing.expectEqualSlices(u8, payload, dynamic_dict_split_decoded);
    var dynamic_dict_split_appended: std.ArrayList(u8) = .empty;
    defer dynamic_dict_split_appended.deinit(std.testing.allocator);
    try dynamic_dict_split_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(dynamic_dict_split_expected.len, try encoder.encodeDynamicSplitWithDictionaryAppend(&dynamic_dict_split_appended, payload, preset_dictionary, 19, dynamic_options));
    try std.testing.expectEqualSlices(u8, dynamic_dict_split_expected, dynamic_dict_split_appended.items["prefix:".len..]);
    try std.testing.expectError(error.InvalidBlockPlan, encoder.encodeDynamicSplitWithDictionaryAlloc(payload, preset_dictionary, 0, dynamic_options));
}

test "root gzip encoder reuses stored scratch" {
    const payload = "root gzip reusable stored encoder payload" ** 2;
    const header_options: GzipHeaderOptions = .{
        .filename = "gzip-reusable.txt",
        .comment = "root gzip reusable",
        .header_crc = true,
    };
    const chunks = [_][]const u8{
        payload[0..12],
        payload[12..43],
        payload[43..],
    };
    const expected = try encodeGzipStoredAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(expected);
    const expected_header = try encodeGzipStoredWithHeaderAlloc(std.testing.allocator, payload, header_options);
    defer std.testing.allocator.free(expected_header);
    const expected_chunks = try encodeGzipStoredChunksAlloc(std.testing.allocator, &chunks);
    defer std.testing.allocator.free(expected_chunks);
    const expected_header_chunks = try encodeGzipStoredChunksWithHeaderAlloc(std.testing.allocator, &chunks, header_options);
    defer std.testing.allocator.free(expected_header_chunks);
    try std.testing.expectEqualSlices(u8, expected, expected_chunks);
    try std.testing.expectEqualSlices(u8, expected_header, expected_header_chunks);

    var encoder = GzipEncoder.init(std.testing.allocator);
    defer encoder.deinit();

    const owned = try encoder.encodeStoredAlloc(payload);
    defer std.testing.allocator.free(owned);
    try std.testing.expectEqualSlices(u8, expected, owned);
    const scratch = try encoder.encodeStoredScratch(payload);
    try std.testing.expectEqualSlices(u8, expected, scratch);
    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(std.testing.allocator);
    try appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(expected.len, try encoder.encodeStoredAppend(&appended, payload));
    try std.testing.expectEqualSlices(u8, expected, appended.items["prefix:".len..]);
    const into = try std.testing.allocator.alloc(u8, try gzipStoredChunksEncodedSize(&chunks));
    defer std.testing.allocator.free(into);
    try std.testing.expectEqual(expected.len, try encoder.encodeStoredIntoSlice(payload, into));
    try std.testing.expectEqualSlices(u8, expected, into[0..expected.len]);

    const header_owned = try encoder.encodeStoredWithHeaderAlloc(payload, header_options);
    defer std.testing.allocator.free(header_owned);
    try std.testing.expectEqualSlices(u8, expected_header, header_owned);
    const header_scratch = try encoder.encodeStoredWithHeaderScratch(payload, header_options);
    try std.testing.expectEqualSlices(u8, expected_header, header_scratch);
    var header_appended: std.ArrayList(u8) = .empty;
    defer header_appended.deinit(std.testing.allocator);
    try std.testing.expectEqual(expected_header.len, try encoder.encodeStoredWithHeaderAppend(&header_appended, payload, header_options));
    try std.testing.expectEqualSlices(u8, expected_header, header_appended.items);
    const header_into = try std.testing.allocator.alloc(u8, try gzipStoredChunksEncodedSizeWithHeader(&chunks, header_options));
    defer std.testing.allocator.free(header_into);
    try std.testing.expectEqual(expected_header.len, try encoder.encodeStoredWithHeaderIntoSlice(payload, header_options, header_into));
    try std.testing.expectEqualSlices(u8, expected_header, header_into[0..expected_header.len]);

    const chunks_owned = try encoder.encodeStoredChunksAlloc(&chunks);
    defer std.testing.allocator.free(chunks_owned);
    try std.testing.expectEqualSlices(u8, expected_chunks, chunks_owned);
    const chunks_scratch = try encoder.encodeStoredChunksScratch(&chunks);
    try std.testing.expectEqualSlices(u8, expected_chunks, chunks_scratch);
    const decoded = try decodeGzipStoredAlloc(std.testing.allocator, chunks_scratch);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    var chunks_appended: std.ArrayList(u8) = .empty;
    defer chunks_appended.deinit(std.testing.allocator);
    _ = try encoder.encodeStoredChunksAppend(&chunks_appended, &chunks);
    try std.testing.expectEqualSlices(u8, expected_chunks, chunks_appended.items);
    const chunks_into = try std.testing.allocator.alloc(u8, expected_chunks.len);
    defer std.testing.allocator.free(chunks_into);
    try std.testing.expectEqual(expected_chunks.len, try encoder.encodeStoredChunksIntoSlice(&chunks, chunks_into));
    try std.testing.expectEqualSlices(u8, expected_chunks, chunks_into[0..expected_chunks.len]);

    const header_chunks_owned = try encoder.encodeStoredChunksWithHeaderAlloc(&chunks, header_options);
    defer std.testing.allocator.free(header_chunks_owned);
    try std.testing.expectEqualSlices(u8, expected_header_chunks, header_chunks_owned);
    const header_chunks_scratch = try encoder.encodeStoredChunksWithHeaderScratch(&chunks, header_options);
    try std.testing.expectEqualSlices(u8, expected_header_chunks, header_chunks_scratch);
    const decoded_header = try decodeGzipStoredAlloc(std.testing.allocator, header_chunks_scratch);
    defer std.testing.allocator.free(decoded_header);
    try std.testing.expectEqualSlices(u8, payload, decoded_header);
    var header_chunks_appended: std.ArrayList(u8) = .empty;
    defer header_chunks_appended.deinit(std.testing.allocator);
    _ = try encoder.encodeStoredChunksWithHeaderAppend(&header_chunks_appended, &chunks, header_options);
    try std.testing.expectEqualSlices(u8, expected_header_chunks, header_chunks_appended.items);
    const header_chunks_into = try std.testing.allocator.alloc(u8, expected_header_chunks.len);
    defer std.testing.allocator.free(header_chunks_into);
    try std.testing.expectEqual(expected_header_chunks.len, try encoder.encodeStoredChunksWithHeaderIntoSlice(&chunks, header_options, header_chunks_into));
    try std.testing.expectEqualSlices(u8, expected_header_chunks, header_chunks_into[0..expected_header_chunks.len]);

    const fixed_expected = try encodeGzipFixedAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(fixed_expected);
    const fixed_owned = try encoder.encodeFixedAlloc(payload);
    defer std.testing.allocator.free(fixed_owned);
    try std.testing.expectEqualSlices(u8, fixed_expected, fixed_owned);
    const fixed_scratch = try encoder.encodeFixedScratch(payload);
    try std.testing.expectEqualSlices(u8, fixed_expected, fixed_scratch);
    var fixed_appended: std.ArrayList(u8) = .empty;
    defer fixed_appended.deinit(std.testing.allocator);
    try fixed_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(fixed_expected.len, try encoder.encodeFixedAppend(&fixed_appended, payload));
    try std.testing.expectEqualSlices(u8, fixed_expected, fixed_appended.items["prefix:".len..]);

    const fixed_options = optionsForCompressionLevel(.fast);
    const fixed_options_expected = try encodeGzipFixedWithOptionsAlloc(std.testing.allocator, payload, fixed_options);
    defer std.testing.allocator.free(fixed_options_expected);
    const fixed_options_owned = try encoder.encodeFixedWithOptionsAlloc(payload, fixed_options);
    defer std.testing.allocator.free(fixed_options_owned);
    try std.testing.expectEqualSlices(u8, fixed_options_expected, fixed_options_owned);
    const fixed_options_scratch = try encoder.encodeFixedWithOptionsScratch(payload, fixed_options);
    try std.testing.expectEqualSlices(u8, fixed_options_expected, fixed_options_scratch);
    var fixed_options_appended: std.ArrayList(u8) = .empty;
    defer fixed_options_appended.deinit(std.testing.allocator);
    try std.testing.expectEqual(fixed_options_expected.len, try encoder.encodeFixedWithOptionsAppend(&fixed_options_appended, payload, fixed_options));
    try std.testing.expectEqualSlices(u8, fixed_options_expected, fixed_options_appended.items);

    const fixed_header_expected = try encodeGzipFixedWithHeaderAlloc(std.testing.allocator, payload, fixed_options, header_options);
    defer std.testing.allocator.free(fixed_header_expected);
    const fixed_header_owned = try encoder.encodeFixedWithHeaderAlloc(payload, fixed_options, header_options);
    defer std.testing.allocator.free(fixed_header_owned);
    try std.testing.expectEqualSlices(u8, fixed_header_expected, fixed_header_owned);
    const fixed_header_scratch = try encoder.encodeFixedWithHeaderScratch(payload, fixed_options, header_options);
    try std.testing.expectEqualSlices(u8, fixed_header_expected, fixed_header_scratch);
    var fixed_header_appended: std.ArrayList(u8) = .empty;
    defer fixed_header_appended.deinit(std.testing.allocator);
    try std.testing.expectEqual(fixed_header_expected.len, try encoder.encodeFixedWithHeaderAppend(&fixed_header_appended, payload, fixed_options, header_options));
    try std.testing.expectEqualSlices(u8, fixed_header_expected, fixed_header_appended.items);

    const fixed_split_expected = try encodeGzipFixedSplitAlloc(std.testing.allocator, payload, 23, fixed_options);
    defer std.testing.allocator.free(fixed_split_expected);
    const fixed_split_owned = try encoder.encodeFixedSplitAlloc(payload, 23, fixed_options);
    defer std.testing.allocator.free(fixed_split_owned);
    try std.testing.expectEqualSlices(u8, fixed_split_expected, fixed_split_owned);
    const fixed_split_scratch = try encoder.encodeFixedSplitScratch(payload, 23, fixed_options);
    try std.testing.expectEqualSlices(u8, fixed_split_expected, fixed_split_scratch);
    const fixed_split_decoded = try decodeGzipAllocExactSize(std.testing.allocator, fixed_split_scratch, payload.len);
    defer std.testing.allocator.free(fixed_split_decoded);
    try std.testing.expectEqualSlices(u8, payload, fixed_split_decoded);
    var fixed_split_appended: std.ArrayList(u8) = .empty;
    defer fixed_split_appended.deinit(std.testing.allocator);
    try fixed_split_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(fixed_split_expected.len, try encoder.encodeFixedSplitAppend(&fixed_split_appended, payload, 23, fixed_options));
    try std.testing.expectEqualSlices(u8, fixed_split_expected, fixed_split_appended.items["prefix:".len..]);
    try std.testing.expectError(error.InvalidBlockPlan, encoder.encodeFixedSplitAlloc(payload, 0, fixed_options));

    const fixed_split_header_expected = try encodeGzipFixedSplitWithHeaderAlloc(std.testing.allocator, payload, 23, fixed_options, header_options);
    defer std.testing.allocator.free(fixed_split_header_expected);
    const fixed_split_header_owned = try encoder.encodeFixedSplitWithHeaderAlloc(payload, 23, fixed_options, header_options);
    defer std.testing.allocator.free(fixed_split_header_owned);
    try std.testing.expectEqualSlices(u8, fixed_split_header_expected, fixed_split_header_owned);
    const fixed_split_header_scratch = try encoder.encodeFixedSplitWithHeaderScratch(payload, 23, fixed_options, header_options);
    try std.testing.expectEqualSlices(u8, fixed_split_header_expected, fixed_split_header_scratch);
    const fixed_split_header_decoded = try decodeGzipAllocExactSize(std.testing.allocator, fixed_split_header_scratch, payload.len);
    defer std.testing.allocator.free(fixed_split_header_decoded);
    try std.testing.expectEqualSlices(u8, payload, fixed_split_header_decoded);
    var fixed_split_header_appended: std.ArrayList(u8) = .empty;
    defer fixed_split_header_appended.deinit(std.testing.allocator);
    try std.testing.expectEqual(fixed_split_header_expected.len, try encoder.encodeFixedSplitWithHeaderAppend(&fixed_split_header_appended, payload, 23, fixed_options, header_options));
    try std.testing.expectEqualSlices(u8, fixed_split_header_expected, fixed_split_header_appended.items);

    const best_options = optionsForCompressionLevel(.fastest);
    const best_expected = try encodeGzipBestAlloc(std.testing.allocator, payload, best_options);
    defer std.testing.allocator.free(best_expected);
    const best_owned = try encoder.encodeBestAlloc(payload, best_options);
    defer std.testing.allocator.free(best_owned);
    try std.testing.expectEqualSlices(u8, best_expected, best_owned);
    const best_scratch = try encoder.encodeBestScratch(payload, best_options);
    try std.testing.expectEqualSlices(u8, best_expected, best_scratch);
    var best_appended: std.ArrayList(u8) = .empty;
    defer best_appended.deinit(std.testing.allocator);
    try std.testing.expectEqual(best_expected.len, try encoder.encodeBestAppend(&best_appended, payload, best_options));
    try std.testing.expectEqualSlices(u8, best_expected, best_appended.items);

    const best_header_expected = try encodeGzipBestWithHeaderAlloc(std.testing.allocator, payload, best_options, header_options);
    defer std.testing.allocator.free(best_header_expected);
    const best_header_owned = try encoder.encodeBestWithHeaderAlloc(payload, best_options, header_options);
    defer std.testing.allocator.free(best_header_owned);
    try std.testing.expectEqualSlices(u8, best_header_expected, best_header_owned);
    const best_header_scratch = try encoder.encodeBestWithHeaderScratch(payload, best_options, header_options);
    try std.testing.expectEqualSlices(u8, best_header_expected, best_header_scratch);
    var best_header_appended: std.ArrayList(u8) = .empty;
    defer best_header_appended.deinit(std.testing.allocator);
    try std.testing.expectEqual(best_header_expected.len, try encoder.encodeBestWithHeaderAppend(&best_header_appended, payload, best_options, header_options));
    try std.testing.expectEqualSlices(u8, best_header_expected, best_header_appended.items);

    const split_block_len: usize = 27;
    const best_split_expected = try encodeGzipBestSplitAlloc(std.testing.allocator, payload, split_block_len, best_options);
    defer std.testing.allocator.free(best_split_expected);
    const best_split_owned = try encoder.encodeBestSplitAlloc(payload, split_block_len, best_options);
    defer std.testing.allocator.free(best_split_owned);
    try std.testing.expectEqualSlices(u8, best_split_expected, best_split_owned);
    const best_split_scratch = try encoder.encodeBestSplitScratch(payload, split_block_len, best_options);
    try std.testing.expectEqualSlices(u8, best_split_expected, best_split_scratch);
    const best_split_decoded = try decodeGzipAllocExactSize(std.testing.allocator, best_split_scratch, payload.len);
    defer std.testing.allocator.free(best_split_decoded);
    try std.testing.expectEqualSlices(u8, payload, best_split_decoded);
    var best_split_appended: std.ArrayList(u8) = .empty;
    defer best_split_appended.deinit(std.testing.allocator);
    try best_split_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(best_split_expected.len, try encoder.encodeBestSplitAppend(&best_split_appended, payload, split_block_len, best_options));
    try std.testing.expectEqualSlices(u8, best_split_expected, best_split_appended.items["prefix:".len..]);
    try std.testing.expectError(error.InvalidBlockPlan, encoder.encodeBestSplitAlloc(payload, 0, best_options));

    const best_split_header_expected = try encodeGzipBestSplitWithHeaderAlloc(std.testing.allocator, payload, split_block_len, best_options, header_options);
    defer std.testing.allocator.free(best_split_header_expected);
    const best_split_header_owned = try encoder.encodeBestSplitWithHeaderAlloc(payload, split_block_len, best_options, header_options);
    defer std.testing.allocator.free(best_split_header_owned);
    try std.testing.expectEqualSlices(u8, best_split_header_expected, best_split_header_owned);
    const best_split_header_scratch = try encoder.encodeBestSplitWithHeaderScratch(payload, split_block_len, best_options, header_options);
    try std.testing.expectEqualSlices(u8, best_split_header_expected, best_split_header_scratch);
    const best_split_header_decoded = try decodeGzipAllocExactSize(std.testing.allocator, best_split_header_scratch, payload.len);
    defer std.testing.allocator.free(best_split_header_decoded);
    try std.testing.expectEqualSlices(u8, payload, best_split_header_decoded);
    var best_split_header_appended: std.ArrayList(u8) = .empty;
    defer best_split_header_appended.deinit(std.testing.allocator);
    try std.testing.expectEqual(best_split_header_expected.len, try encoder.encodeBestSplitWithHeaderAppend(&best_split_header_appended, payload, split_block_len, best_options, header_options));
    try std.testing.expectEqualSlices(u8, best_split_header_expected, best_split_header_appended.items);

    const adaptive_split_options: AdaptiveSplitOptions = .{
        .min_block_len = 16,
        .max_block_len = 32,
        .sample_len = 8,
        .search_step = 8,
    };
    const best_adaptive_expected = try encodeGzipBestAdaptiveSplitAlloc(std.testing.allocator, payload, best_options, adaptive_split_options);
    defer std.testing.allocator.free(best_adaptive_expected);
    const best_adaptive_owned = try encoder.encodeBestAdaptiveSplitAlloc(payload, best_options, adaptive_split_options);
    defer std.testing.allocator.free(best_adaptive_owned);
    try std.testing.expectEqualSlices(u8, best_adaptive_expected, best_adaptive_owned);
    const best_adaptive_scratch = try encoder.encodeBestAdaptiveSplitScratch(payload, best_options, adaptive_split_options);
    try std.testing.expectEqualSlices(u8, best_adaptive_expected, best_adaptive_scratch);
    const best_adaptive_decoded = try decodeGzipAllocExactSize(std.testing.allocator, best_adaptive_scratch, payload.len);
    defer std.testing.allocator.free(best_adaptive_decoded);
    try std.testing.expectEqualSlices(u8, payload, best_adaptive_decoded);
    var best_adaptive_appended: std.ArrayList(u8) = .empty;
    defer best_adaptive_appended.deinit(std.testing.allocator);
    try std.testing.expectEqual(best_adaptive_expected.len, try encoder.encodeBestAdaptiveSplitAppend(&best_adaptive_appended, payload, best_options, adaptive_split_options));
    try std.testing.expectEqualSlices(u8, best_adaptive_expected, best_adaptive_appended.items);
    try std.testing.expectError(error.InvalidBlockPlan, encoder.encodeBestAdaptiveSplitAlloc(payload, best_options, .{ .min_block_len = 0 }));

    const best_adaptive_header_expected = try encodeGzipBestAdaptiveSplitWithHeaderAlloc(std.testing.allocator, payload, best_options, adaptive_split_options, header_options);
    defer std.testing.allocator.free(best_adaptive_header_expected);
    const best_adaptive_header_owned = try encoder.encodeBestAdaptiveSplitWithHeaderAlloc(payload, best_options, adaptive_split_options, header_options);
    defer std.testing.allocator.free(best_adaptive_header_owned);
    try std.testing.expectEqualSlices(u8, best_adaptive_header_expected, best_adaptive_header_owned);
    const best_adaptive_header_scratch = try encoder.encodeBestAdaptiveSplitWithHeaderScratch(payload, best_options, adaptive_split_options, header_options);
    try std.testing.expectEqualSlices(u8, best_adaptive_header_expected, best_adaptive_header_scratch);
    const best_adaptive_header_decoded = try decodeGzipAllocExactSize(std.testing.allocator, best_adaptive_header_scratch, payload.len);
    defer std.testing.allocator.free(best_adaptive_header_decoded);
    try std.testing.expectEqualSlices(u8, payload, best_adaptive_header_decoded);
    var best_adaptive_header_appended: std.ArrayList(u8) = .empty;
    defer best_adaptive_header_appended.deinit(std.testing.allocator);
    try best_adaptive_header_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(best_adaptive_header_expected.len, try encoder.encodeBestAdaptiveSplitWithHeaderAppend(&best_adaptive_header_appended, payload, best_options, adaptive_split_options, header_options));
    try std.testing.expectEqualSlices(u8, best_adaptive_header_expected, best_adaptive_header_appended.items["prefix:".len..]);
    try std.testing.expectError(error.InvalidBlockPlan, encoder.encodeBestAdaptiveSplitWithHeaderAlloc(payload, best_options, .{ .min_block_len = 32, .max_block_len = 16 }, header_options));

    const level_expected = try encodeGzipLevelAlloc(std.testing.allocator, payload, 1);
    defer std.testing.allocator.free(level_expected);
    const level_owned = try encoder.encodeLevelAlloc(payload, 1);
    defer std.testing.allocator.free(level_owned);
    try std.testing.expectEqualSlices(u8, level_expected, level_owned);
    const level_scratch = try encoder.encodeLevelScratch(payload, 1);
    try std.testing.expectEqualSlices(u8, level_expected, level_scratch);
    var level_appended: std.ArrayList(u8) = .empty;
    defer level_appended.deinit(std.testing.allocator);
    try std.testing.expectEqual(level_expected.len, try encoder.encodeLevelAppend(&level_appended, payload, 1));
    try std.testing.expectEqualSlices(u8, level_expected, level_appended.items);

    const level_header_expected = try encodeGzipLevelWithHeaderAlloc(std.testing.allocator, payload, 1, header_options);
    defer std.testing.allocator.free(level_header_expected);
    const level_header_owned = try encoder.encodeLevelWithHeaderAlloc(payload, 1, header_options);
    defer std.testing.allocator.free(level_header_owned);
    try std.testing.expectEqualSlices(u8, level_header_expected, level_header_owned);
    const level_header_scratch = try encoder.encodeLevelWithHeaderScratch(payload, 1, header_options);
    try std.testing.expectEqualSlices(u8, level_header_expected, level_header_scratch);
    var level_header_appended: std.ArrayList(u8) = .empty;
    defer level_header_appended.deinit(std.testing.allocator);
    try std.testing.expectEqual(level_header_expected.len, try encoder.encodeLevelWithHeaderAppend(&level_header_appended, payload, 1, header_options));
    try std.testing.expectEqualSlices(u8, level_header_expected, level_header_appended.items);
    try std.testing.expectError(error.InvalidBlockPlan, encoder.encodeLevelAlloc(payload, 10));

    const dynamic_literal_expected = try encodeGzipDynamicLiteralAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(dynamic_literal_expected);
    const dynamic_literal_owned = try encoder.encodeDynamicLiteralAlloc(payload);
    defer std.testing.allocator.free(dynamic_literal_owned);
    try std.testing.expectEqualSlices(u8, dynamic_literal_expected, dynamic_literal_owned);
    const dynamic_literal_scratch = try encoder.encodeDynamicLiteralScratch(payload);
    try std.testing.expectEqualSlices(u8, dynamic_literal_expected, dynamic_literal_scratch);
    var dynamic_literal_appended: std.ArrayList(u8) = .empty;
    defer dynamic_literal_appended.deinit(std.testing.allocator);
    try dynamic_literal_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(dynamic_literal_expected.len, try encoder.encodeDynamicLiteralAppend(&dynamic_literal_appended, payload));
    try std.testing.expectEqualSlices(u8, dynamic_literal_expected, dynamic_literal_appended.items["prefix:".len..]);

    const dynamic_literal_header_expected = try encodeGzipDynamicLiteralWithHeaderAlloc(std.testing.allocator, payload, header_options);
    defer std.testing.allocator.free(dynamic_literal_header_expected);
    const dynamic_literal_header_owned = try encoder.encodeDynamicLiteralWithHeaderAlloc(payload, header_options);
    defer std.testing.allocator.free(dynamic_literal_header_owned);
    try std.testing.expectEqualSlices(u8, dynamic_literal_header_expected, dynamic_literal_header_owned);
    const dynamic_literal_header_scratch = try encoder.encodeDynamicLiteralWithHeaderScratch(payload, header_options);
    try std.testing.expectEqualSlices(u8, dynamic_literal_header_expected, dynamic_literal_header_scratch);
    var dynamic_literal_header_appended: std.ArrayList(u8) = .empty;
    defer dynamic_literal_header_appended.deinit(std.testing.allocator);
    try std.testing.expectEqual(dynamic_literal_header_expected.len, try encoder.encodeDynamicLiteralWithHeaderAppend(&dynamic_literal_header_appended, payload, header_options));
    try std.testing.expectEqualSlices(u8, dynamic_literal_header_expected, dynamic_literal_header_appended.items);

    const dynamic_options = optionsForCompressionLevel(.default);
    const dynamic_expected = try encodeGzipDynamicWithOptionsAlloc(std.testing.allocator, payload, dynamic_options);
    defer std.testing.allocator.free(dynamic_expected);
    const dynamic_owned = try encoder.encodeDynamicWithOptionsAlloc(payload, dynamic_options);
    defer std.testing.allocator.free(dynamic_owned);
    try std.testing.expectEqualSlices(u8, dynamic_expected, dynamic_owned);
    const dynamic_scratch = try encoder.encodeDynamicWithOptionsScratch(payload, dynamic_options);
    try std.testing.expectEqualSlices(u8, dynamic_expected, dynamic_scratch);
    const dynamic_decoded = try decodeGzipAllocExactSize(std.testing.allocator, dynamic_scratch, payload.len);
    defer std.testing.allocator.free(dynamic_decoded);
    try std.testing.expectEqualSlices(u8, payload, dynamic_decoded);
    var dynamic_appended: std.ArrayList(u8) = .empty;
    defer dynamic_appended.deinit(std.testing.allocator);
    try std.testing.expectEqual(dynamic_expected.len, try encoder.encodeDynamicWithOptionsAppend(&dynamic_appended, payload, dynamic_options));
    try std.testing.expectEqualSlices(u8, dynamic_expected, dynamic_appended.items);

    const dynamic_split_expected = try encodeGzipDynamicSplitAlloc(std.testing.allocator, payload, 23, dynamic_options);
    defer std.testing.allocator.free(dynamic_split_expected);
    const dynamic_split_owned = try encoder.encodeDynamicSplitAlloc(payload, 23, dynamic_options);
    defer std.testing.allocator.free(dynamic_split_owned);
    try std.testing.expectEqualSlices(u8, dynamic_split_expected, dynamic_split_owned);
    const dynamic_split_scratch = try encoder.encodeDynamicSplitScratch(payload, 23, dynamic_options);
    try std.testing.expectEqualSlices(u8, dynamic_split_expected, dynamic_split_scratch);
    const dynamic_split_decoded = try decodeGzipAllocExactSize(std.testing.allocator, dynamic_split_scratch, payload.len);
    defer std.testing.allocator.free(dynamic_split_decoded);
    try std.testing.expectEqualSlices(u8, payload, dynamic_split_decoded);
    var dynamic_split_appended: std.ArrayList(u8) = .empty;
    defer dynamic_split_appended.deinit(std.testing.allocator);
    try dynamic_split_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(dynamic_split_expected.len, try encoder.encodeDynamicSplitAppend(&dynamic_split_appended, payload, 23, dynamic_options));
    try std.testing.expectEqualSlices(u8, dynamic_split_expected, dynamic_split_appended.items["prefix:".len..]);
    try std.testing.expectError(error.InvalidBlockPlan, encoder.encodeDynamicSplitAlloc(payload, 0, dynamic_options));

    const dynamic_header_expected = try encodeGzipDynamicWithHeaderAlloc(std.testing.allocator, payload, dynamic_options, header_options);
    defer std.testing.allocator.free(dynamic_header_expected);
    const dynamic_header_owned = try encoder.encodeDynamicWithHeaderAlloc(payload, dynamic_options, header_options);
    defer std.testing.allocator.free(dynamic_header_owned);
    try std.testing.expectEqualSlices(u8, dynamic_header_expected, dynamic_header_owned);
    const dynamic_header_scratch = try encoder.encodeDynamicWithHeaderScratch(payload, dynamic_options, header_options);
    try std.testing.expectEqualSlices(u8, dynamic_header_expected, dynamic_header_scratch);
    var dynamic_header_appended: std.ArrayList(u8) = .empty;
    defer dynamic_header_appended.deinit(std.testing.allocator);
    try std.testing.expectEqual(dynamic_header_expected.len, try encoder.encodeDynamicWithHeaderAppend(&dynamic_header_appended, payload, dynamic_options, header_options));
    try std.testing.expectEqualSlices(u8, dynamic_header_expected, dynamic_header_appended.items);

    const dynamic_split_header_expected = try encodeGzipDynamicSplitWithHeaderAlloc(std.testing.allocator, payload, 23, dynamic_options, header_options);
    defer std.testing.allocator.free(dynamic_split_header_expected);
    const dynamic_split_header_owned = try encoder.encodeDynamicSplitWithHeaderAlloc(payload, 23, dynamic_options, header_options);
    defer std.testing.allocator.free(dynamic_split_header_owned);
    try std.testing.expectEqualSlices(u8, dynamic_split_header_expected, dynamic_split_header_owned);
    const dynamic_split_header_scratch = try encoder.encodeDynamicSplitWithHeaderScratch(payload, 23, dynamic_options, header_options);
    try std.testing.expectEqualSlices(u8, dynamic_split_header_expected, dynamic_split_header_scratch);
    const dynamic_split_header_decoded = try decodeGzipAllocExactSize(std.testing.allocator, dynamic_split_header_scratch, payload.len);
    defer std.testing.allocator.free(dynamic_split_header_decoded);
    try std.testing.expectEqualSlices(u8, payload, dynamic_split_header_decoded);
    var dynamic_split_header_appended: std.ArrayList(u8) = .empty;
    defer dynamic_split_header_appended.deinit(std.testing.allocator);
    try std.testing.expectEqual(dynamic_split_header_expected.len, try encoder.encodeDynamicSplitWithHeaderAppend(&dynamic_split_header_appended, payload, 23, dynamic_options, header_options));
    try std.testing.expectEqualSlices(u8, dynamic_split_header_expected, dynamic_split_header_appended.items);
}

test "root raw deflate decoder drains caller-owned scratch and resets" {
    const payload = "raw deflate reusable decoder payload " ** 2;
    const encoded = try encodeRawBestAlloc(std.testing.allocator, payload, .{});
    defer std.testing.allocator.free(encoded);
    var scratch: [payload.len + 8]u8 = undefined;
    var decoder = try RawDeflateDecoder.initExactSize(encoded, &scratch, payload.len);

    var out: [payload.len]u8 = undefined;
    var step = try decoder.step(out[0..9]);
    try std.testing.expectEqual(StepResult.Status.need_output, step.status);
    try std.testing.expectEqual(@as(usize, 0), step.progress.input_read);
    try std.testing.expectEqual(@as(usize, 9), step.progress.output_written);
    step = try decoder.step(out[9..]);
    try std.testing.expectEqual(StepResult.Status.done, step.status);
    try std.testing.expectEqual(encoded.len, step.progress.input_read);
    try std.testing.expectEqual(payload.len - 9, step.progress.output_written);
    try std.testing.expectEqualSlices(u8, payload, &out);
    const done_diagnostics = decoder.diagnostics();
    try std.testing.expectEqualStrings("done", done_diagnostics.phase_name);
    try std.testing.expectEqual(encoded.len, done_diagnostics.frame_input_read.?);

    const chunk_payload = "raw deflate chunked reset payload";
    const chunk_encoded = try encodeRawBestAlloc(std.testing.allocator, chunk_payload, .{});
    defer std.testing.allocator.free(chunk_encoded);
    const chunks = [_][]const u8{
        chunk_encoded[0..1],
        chunk_encoded[1..@min(chunk_encoded.len, 10)],
        chunk_encoded[@min(chunk_encoded.len, 10)..],
    };
    const join = try std.testing.allocator.alloc(u8, chunk_encoded.len);
    defer std.testing.allocator.free(join);
    try decoder.resetFromChunksExactSize(&chunks, join, &scratch, chunk_payload.len);
    var chunk_out: [chunk_payload.len]u8 = undefined;
    step = try decoder.step(&chunk_out);
    try std.testing.expectEqual(StepResult.Status.done, step.status);
    try std.testing.expectEqual(chunk_encoded.len, step.progress.input_read);
    try std.testing.expectEqual(chunk_payload.len, step.progress.output_written);
    try std.testing.expectEqualSlices(u8, chunk_payload, &chunk_out);

    try std.testing.expectError(error.SizeMismatch, decoder.resetExactSize(encoded, &scratch, payload.len + 1));
    try std.testing.expectEqualStrings("SizeMismatch", decoder.snapshot().last_error_name);
    try std.testing.expectEqualStrings("payload_corrupt", decoder.diagnostics().recoverability_hint_name);
}

test "root raw deflate probe reports support and size mismatches" {
    const payload = "raw deflate probe payload" ** 2;
    const encoded = try encodeRawBestAlloc(std.testing.allocator, payload, .{});
    defer std.testing.allocator.free(encoded);
    var scratch: [payload.len + 8]u8 = undefined;

    const ok = probeRawDeflate(encoded, &scratch);
    try std.testing.expect(ok.ok);
    try std.testing.expectEqualStrings("", ok.error_name);
    try std.testing.expectEqual(payload.len, ok.decoded_bytes.?);
    try std.testing.expectEqual(payload.len, try decodedRawDeflateSize(encoded, &scratch));

    const exact_ok = probeRawDeflateExactSize(encoded, &scratch, payload.len);
    try std.testing.expect(exact_ok.ok);
    try std.testing.expectEqual(payload.len, exact_ok.decoded_bytes.?);

    const exact_bad = probeRawDeflateExactSize(encoded, &scratch, payload.len + 1);
    try std.testing.expect(!exact_bad.ok);
    try std.testing.expectEqualStrings("SizeMismatch", exact_bad.error_name);
    try std.testing.expectEqual(payload.len, exact_bad.decoded_bytes.?);
    try std.testing.expectEqualStrings("output_size", exact_bad.diagnostics.phase_name);

    const truncated = probeRawDeflate("", &scratch);
    try std.testing.expect(!truncated.ok);
    try std.testing.expectEqualStrings("TruncatedFrame", truncated.error_name);
    try std.testing.expectEqualStrings("truncated_input", truncated.diagnostics.recoverability_hint_name);

    const chunks = [_][]const u8{
        encoded[0..1],
        encoded[1..@min(encoded.len, 9)],
        encoded[@min(encoded.len, 9)..],
    };
    const join = try std.testing.allocator.alloc(u8, encoded.len);
    defer std.testing.allocator.free(join);
    const chunked = probeRawDeflateChunksExactSize(&chunks, join, &scratch, payload.len);
    try std.testing.expect(chunked.ok);
    try std.testing.expectEqual(payload.len, chunked.decoded_bytes.?);
    try std.testing.expectEqual(payload.len, try decodedRawDeflateChunksSize(&chunks, join, &scratch));

    const dictionary_bytes = "raw probe shared dictionary";
    const dict_payload = "raw probe shared dictionary payload";
    const dict_encoded = try encodeRawBestWithDictionaryAlloc(std.testing.allocator, dict_payload, dictionary_bytes, .{});
    defer std.testing.allocator.free(dict_encoded);
    var dict_scratch: [dict_payload.len + 8]u8 = undefined;
    try std.testing.expectEqual(dict_payload.len, try decodedRawDeflateSizeWithDictionary(dict_encoded, dictionary_bytes, &dict_scratch));
}

test "root zlib and gzip probes report support and size mismatches" {
    const payload = "wrapper probe payload" ** 2;
    const zlib_encoded = try encodeZlibBestAlloc(std.testing.allocator, payload, .{});
    defer std.testing.allocator.free(zlib_encoded);
    var zlib_scratch: [payload.len + 8]u8 = undefined;

    const zlib_ok = probeZlib(zlib_encoded, &zlib_scratch);
    try std.testing.expect(zlib_ok.ok);
    try std.testing.expectEqualStrings("", zlib_ok.error_name);
    try std.testing.expectEqual(payload.len, zlib_ok.decoded_bytes.?);
    try std.testing.expectEqual(payload.len, try decodedZlibSize(zlib_encoded, &zlib_scratch));

    const zlib_exact_bad = probeZlibExactSize(zlib_encoded, &zlib_scratch, payload.len + 1);
    try std.testing.expect(!zlib_exact_bad.ok);
    try std.testing.expectEqualStrings("SizeMismatch", zlib_exact_bad.error_name);
    try std.testing.expectEqual(payload.len, zlib_exact_bad.decoded_bytes.?);
    try std.testing.expectEqualStrings("output_size", zlib_exact_bad.diagnostics.phase_name);

    const zlib_truncated = probeZlib("", &zlib_scratch);
    try std.testing.expect(!zlib_truncated.ok);
    try std.testing.expectEqualStrings("TruncatedFrame", zlib_truncated.error_name);
    const zlib_bad_header = [_]u8{ 0, 0 };
    const zlib_header_bad = probeZlib(&zlib_bad_header, &zlib_scratch);
    try std.testing.expect(!zlib_header_bad.ok);
    try std.testing.expectEqualStrings("BadZlibHeader", zlib_header_bad.error_name);
    try std.testing.expectEqualStrings("header", zlib_header_bad.diagnostics.phase_name);

    const zlib_chunks = [_][]const u8{
        zlib_encoded[0..2],
        zlib_encoded[2..@min(zlib_encoded.len, 12)],
        zlib_encoded[@min(zlib_encoded.len, 12)..],
    };
    const zlib_join = try std.testing.allocator.alloc(u8, zlib_encoded.len);
    defer std.testing.allocator.free(zlib_join);
    const zlib_chunked = probeZlibChunksExactSize(&zlib_chunks, zlib_join, &zlib_scratch, payload.len);
    try std.testing.expect(zlib_chunked.ok);
    try std.testing.expectEqual(payload.len, zlib_chunked.decoded_bytes.?);
    try std.testing.expectEqual(payload.len, try decodedZlibChunksSize(&zlib_chunks, zlib_join, &zlib_scratch));

    const probe_dictionary = "wrapper probe shared dictionary";
    const dict_payload = "wrapper probe shared dictionary payload";
    const zlib_dict = try encodeZlibBestWithDictionaryAlloc(std.testing.allocator, dict_payload, probe_dictionary, .{});
    defer std.testing.allocator.free(zlib_dict);
    var zlib_dict_scratch: [dict_payload.len + 8]u8 = undefined;
    const dict_ok = probeZlibWithDictionaryExactSize(zlib_dict, probe_dictionary, &zlib_dict_scratch, dict_payload.len);
    try std.testing.expect(dict_ok.ok);
    try std.testing.expectEqual(dict_payload.len, dict_ok.decoded_bytes.?);
    try std.testing.expectEqual(dict_payload.len, try decodedZlibSizeWithDictionary(zlib_dict, probe_dictionary, &zlib_dict_scratch));
    const dict_missing = probeZlibExactSize(zlib_dict, &zlib_dict_scratch, dict_payload.len);
    try std.testing.expect(!dict_missing.ok);
    try std.testing.expectEqualStrings("NeedDictionary", dict_missing.error_name);
    try std.testing.expectEqualStrings("header", dict_missing.diagnostics.phase_name);

    const zlib_bad_checksum = try std.testing.allocator.dupe(u8, zlib_encoded);
    defer std.testing.allocator.free(zlib_bad_checksum);
    zlib_bad_checksum[zlib_bad_checksum.len - 1] ^= 1;
    const zlib_footer_bad = probeZlib(zlib_bad_checksum, &zlib_scratch);
    try std.testing.expect(!zlib_footer_bad.ok);
    try std.testing.expectEqualStrings("ChecksumMismatch", zlib_footer_bad.error_name);
    try std.testing.expectEqualStrings("footer", zlib_footer_bad.diagnostics.phase_name);

    const gzip_encoded = try encodeGzipBestAlloc(std.testing.allocator, payload, .{});
    defer std.testing.allocator.free(gzip_encoded);
    var gzip_scratch: [payload.len + 8]u8 = undefined;

    const gzip_ok = probeGzip(gzip_encoded, &gzip_scratch);
    try std.testing.expect(gzip_ok.ok);
    try std.testing.expectEqualStrings("", gzip_ok.error_name);
    try std.testing.expectEqual(payload.len, gzip_ok.decoded_bytes.?);
    try std.testing.expectEqual(payload.len, try decodedGzipSize(gzip_encoded, &gzip_scratch));

    const gzip_exact_bad = probeGzipExactSize(gzip_encoded, &gzip_scratch, payload.len - 1);
    try std.testing.expect(!gzip_exact_bad.ok);
    try std.testing.expectEqualStrings("SizeMismatch", gzip_exact_bad.error_name);
    try std.testing.expectEqual(payload.len, gzip_exact_bad.decoded_bytes.?);
    try std.testing.expectEqualStrings("output_size", gzip_exact_bad.diagnostics.phase_name);

    const gzip_truncated = probeGzip("", &gzip_scratch);
    try std.testing.expect(!gzip_truncated.ok);
    try std.testing.expectEqualStrings("TruncatedFrame", gzip_truncated.error_name);
    const gzip_bad_header: [10]u8 = @splat(0);
    const gzip_header_bad = probeGzip(&gzip_bad_header, &gzip_scratch);
    try std.testing.expect(!gzip_header_bad.ok);
    try std.testing.expectEqualStrings("BadGzipHeader", gzip_header_bad.error_name);
    try std.testing.expectEqualStrings("header", gzip_header_bad.diagnostics.phase_name);

    const gzip_bad_checksum = try std.testing.allocator.dupe(u8, gzip_encoded);
    defer std.testing.allocator.free(gzip_bad_checksum);
    gzip_bad_checksum[gzip_bad_checksum.len - 8] ^= 1;
    const gzip_footer_bad = probeGzip(gzip_bad_checksum, &gzip_scratch);
    try std.testing.expect(!gzip_footer_bad.ok);
    try std.testing.expectEqualStrings("ChecksumMismatch", gzip_footer_bad.error_name);
    try std.testing.expectEqualStrings("footer", gzip_footer_bad.diagnostics.phase_name);

    const gzip_chunks = [_][]const u8{
        gzip_encoded[0..3],
        gzip_encoded[3..@min(gzip_encoded.len, 16)],
        gzip_encoded[@min(gzip_encoded.len, 16)..],
    };
    const gzip_join = try std.testing.allocator.alloc(u8, gzip_encoded.len);
    defer std.testing.allocator.free(gzip_join);
    const gzip_chunked = probeGzipChunksExactSize(&gzip_chunks, gzip_join, &gzip_scratch, payload.len);
    try std.testing.expect(gzip_chunked.ok);
    try std.testing.expectEqual(payload.len, gzip_chunked.decoded_bytes.?);
    try std.testing.expectEqual(payload.len, try decodedGzipChunksSize(&gzip_chunks, gzip_join, &gzip_scratch));
}

test "root zlib and gzip concatenated probes report support and size mismatches" {
    const first = "first probe member ";
    const second = "second probe member";
    const expected = first ++ second;

    const zlib_first = try encodeZlibBestAlloc(std.testing.allocator, first, .{});
    defer std.testing.allocator.free(zlib_first);
    const zlib_second = try encodeZlibBestAlloc(std.testing.allocator, second, .{});
    defer std.testing.allocator.free(zlib_second);
    var zlib_stream: std.ArrayList(u8) = .empty;
    defer zlib_stream.deinit(std.testing.allocator);
    try zlib_stream.appendSlice(std.testing.allocator, zlib_first);
    try zlib_stream.appendSlice(std.testing.allocator, zlib_second);
    var zlib_scratch: [expected.len + 8]u8 = undefined;
    const zlib_ok = probeZlibConcatenated(zlib_stream.items, &zlib_scratch);
    try std.testing.expect(zlib_ok.ok);
    try std.testing.expectEqual(expected.len, zlib_ok.decoded_bytes.?);
    try std.testing.expectEqual(expected.len, try decodedZlibConcatenatedSize(zlib_stream.items, &zlib_scratch));
    try std.testing.expectEqual(@as(usize, 2), zlib_ok.member_count.?);
    try std.testing.expectEqual(zlib_stream.items.len, zlib_ok.stream_input_bytes.?);
    try std.testing.expectEqual(zlib_first.len, zlib_ok.last_member_offset.?);
    const zlib_exact_bad = probeZlibConcatenatedExactSize(zlib_stream.items, &zlib_scratch, expected.len + 1);
    try std.testing.expect(!zlib_exact_bad.ok);
    try std.testing.expectEqualStrings("SizeMismatch", zlib_exact_bad.error_name);
    try std.testing.expectEqual(expected.len, zlib_exact_bad.decoded_bytes.?);
    try std.testing.expectEqual(@as(usize, 2), zlib_exact_bad.member_count.?);
    try std.testing.expectEqual(zlib_stream.items.len, zlib_exact_bad.stream_input_bytes.?);
    try std.testing.expectEqual(zlib_first.len, zlib_exact_bad.last_member_offset.?);

    const zlib_bad_second = try std.testing.allocator.dupe(u8, zlib_stream.items);
    defer std.testing.allocator.free(zlib_bad_second);
    zlib_bad_second[zlib_bad_second.len - 1] ^= 1;
    const zlib_second_bad = probeZlibConcatenated(zlib_bad_second, &zlib_scratch);
    try std.testing.expect(!zlib_second_bad.ok);
    try std.testing.expectEqualStrings("ChecksumMismatch", zlib_second_bad.error_name);
    try std.testing.expectEqual(@as(usize, 1), zlib_second_bad.member_index.?);
    try std.testing.expectEqual(zlib_first.len, zlib_second_bad.member_offset.?);
    try std.testing.expectEqualStrings("footer", zlib_second_bad.diagnostics.phase_name);

    const zlib_chunks = [_][]const u8{
        zlib_stream.items[0..3],
        zlib_stream.items[3..@min(zlib_stream.items.len, 21)],
        zlib_stream.items[@min(zlib_stream.items.len, 21)..],
    };
    const zlib_join = try std.testing.allocator.alloc(u8, zlib_stream.items.len);
    defer std.testing.allocator.free(zlib_join);
    const zlib_chunked = probeZlibConcatenatedChunksExactSize(&zlib_chunks, zlib_join, &zlib_scratch, expected.len);
    try std.testing.expect(zlib_chunked.ok);
    try std.testing.expectEqual(expected.len, zlib_chunked.decoded_bytes.?);
    try std.testing.expectEqual(expected.len, try decodedZlibConcatenatedChunksSize(&zlib_chunks, zlib_join, &zlib_scratch));
    try std.testing.expectEqual(@as(usize, 2), zlib_chunked.member_count.?);
    try std.testing.expectEqual(zlib_stream.items.len, zlib_chunked.stream_input_bytes.?);
    try std.testing.expectEqual(zlib_first.len, zlib_chunked.last_member_offset.?);

    const concatenated_dictionary = "concatenated probe dictionary";
    const dict_first_payload = "concatenated probe dictionary first";
    const dict_second_payload = "concatenated probe dictionary second";
    const dict_expected = dict_first_payload ++ dict_second_payload;
    const zlib_dict_first = try encodeZlibBestWithDictionaryAlloc(std.testing.allocator, dict_first_payload, concatenated_dictionary, .{});
    defer std.testing.allocator.free(zlib_dict_first);
    const zlib_dict_second = try encodeZlibBestWithDictionaryAlloc(std.testing.allocator, dict_second_payload, concatenated_dictionary, .{});
    defer std.testing.allocator.free(zlib_dict_second);
    var zlib_dict_stream: std.ArrayList(u8) = .empty;
    defer zlib_dict_stream.deinit(std.testing.allocator);
    try zlib_dict_stream.appendSlice(std.testing.allocator, zlib_dict_first);
    try zlib_dict_stream.appendSlice(std.testing.allocator, zlib_dict_second);
    var zlib_dict_scratch: [dict_expected.len + 8]u8 = undefined;
    const zlib_dict_ok = probeZlibConcatenatedWithDictionaryExactSize(zlib_dict_stream.items, concatenated_dictionary, &zlib_dict_scratch, dict_expected.len);
    try std.testing.expect(zlib_dict_ok.ok);
    try std.testing.expectEqual(dict_expected.len, zlib_dict_ok.decoded_bytes.?);
    try std.testing.expectEqual(dict_expected.len, try decodedZlibConcatenatedSizeWithDictionary(zlib_dict_stream.items, concatenated_dictionary, &zlib_dict_scratch));
    const zlib_dict_missing = probeZlibConcatenatedExactSize(zlib_dict_stream.items, &zlib_dict_scratch, dict_expected.len);
    try std.testing.expect(!zlib_dict_missing.ok);
    try std.testing.expectEqualStrings("NeedDictionary", zlib_dict_missing.error_name);

    const gzip_first = try encodeGzipBestAlloc(std.testing.allocator, first, .{});
    defer std.testing.allocator.free(gzip_first);
    const gzip_second = try encodeGzipBestAlloc(std.testing.allocator, second, .{});
    defer std.testing.allocator.free(gzip_second);
    var gzip_stream: std.ArrayList(u8) = .empty;
    defer gzip_stream.deinit(std.testing.allocator);
    try gzip_stream.appendSlice(std.testing.allocator, gzip_first);
    try gzip_stream.appendSlice(std.testing.allocator, gzip_second);
    var gzip_scratch: [expected.len + 8]u8 = undefined;
    const gzip_ok = probeGzipConcatenated(gzip_stream.items, &gzip_scratch);
    try std.testing.expect(gzip_ok.ok);
    try std.testing.expectEqual(expected.len, gzip_ok.decoded_bytes.?);
    try std.testing.expectEqual(expected.len, try decodedGzipConcatenatedSize(gzip_stream.items, &gzip_scratch));
    try std.testing.expectEqual(@as(usize, 2), gzip_ok.member_count.?);
    try std.testing.expectEqual(gzip_stream.items.len, gzip_ok.stream_input_bytes.?);
    try std.testing.expectEqual(gzip_first.len, gzip_ok.last_member_offset.?);
    const gzip_exact_bad = probeGzipConcatenatedExactSize(gzip_stream.items, &gzip_scratch, expected.len - 1);
    try std.testing.expect(!gzip_exact_bad.ok);
    try std.testing.expectEqualStrings("SizeMismatch", gzip_exact_bad.error_name);
    try std.testing.expectEqual(expected.len, gzip_exact_bad.decoded_bytes.?);
    try std.testing.expectEqual(@as(usize, 2), gzip_exact_bad.member_count.?);
    try std.testing.expectEqual(gzip_stream.items.len, gzip_exact_bad.stream_input_bytes.?);
    try std.testing.expectEqual(gzip_first.len, gzip_exact_bad.last_member_offset.?);

    const gzip_bad_second = try std.testing.allocator.dupe(u8, gzip_stream.items);
    defer std.testing.allocator.free(gzip_bad_second);
    gzip_bad_second[gzip_bad_second.len - 8] ^= 1;
    const gzip_second_bad = probeGzipConcatenated(gzip_bad_second, &gzip_scratch);
    try std.testing.expect(!gzip_second_bad.ok);
    try std.testing.expectEqualStrings("ChecksumMismatch", gzip_second_bad.error_name);
    try std.testing.expectEqual(@as(usize, 1), gzip_second_bad.member_index.?);
    try std.testing.expectEqual(gzip_first.len, gzip_second_bad.member_offset.?);
    try std.testing.expectEqualStrings("footer", gzip_second_bad.diagnostics.phase_name);

    const gzip_chunks = [_][]const u8{
        gzip_stream.items[0..5],
        gzip_stream.items[5..@min(gzip_stream.items.len, 25)],
        gzip_stream.items[@min(gzip_stream.items.len, 25)..],
    };
    const gzip_join = try std.testing.allocator.alloc(u8, gzip_stream.items.len);
    defer std.testing.allocator.free(gzip_join);
    const gzip_chunked = probeGzipConcatenatedChunksExactSize(&gzip_chunks, gzip_join, &gzip_scratch, expected.len);
    try std.testing.expect(gzip_chunked.ok);
    try std.testing.expectEqual(expected.len, gzip_chunked.decoded_bytes.?);
    try std.testing.expectEqual(expected.len, try decodedGzipConcatenatedChunksSize(&gzip_chunks, gzip_join, &gzip_scratch));
    try std.testing.expectEqual(@as(usize, 2), gzip_chunked.member_count.?);
    try std.testing.expectEqual(gzip_stream.items.len, gzip_chunked.stream_input_bytes.?);
    try std.testing.expectEqual(gzip_first.len, gzip_chunked.last_member_offset.?);
}

test "root zlib and gzip append decode helpers preserve prefixes" {
    const payload = "root wrapper append payload " ** 2;

    const zlib_encoded = try encodeZlibBestAlloc(std.testing.allocator, payload, .{});
    defer std.testing.allocator.free(zlib_encoded);
    var zlib_appended: std.ArrayList(u8) = .empty;
    defer zlib_appended.deinit(std.testing.allocator);
    try zlib_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(payload.len, try decodeZlibAppend(std.testing.allocator, &zlib_appended, zlib_encoded));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ payload, zlib_appended.items);

    zlib_appended.clearRetainingCapacity();
    try zlib_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(payload.len, try decodeZlibAppendExactSize(std.testing.allocator, &zlib_appended, zlib_encoded, payload.len));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ payload, zlib_appended.items);
    try std.testing.expectError(error.SizeMismatch, decodeZlibAppendExactSize(std.testing.allocator, &zlib_appended, zlib_encoded, payload.len + 1));

    zlib_appended.clearRetainingCapacity();
    try zlib_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(payload.len, try decodeZlibAppendLimited(std.testing.allocator, &zlib_appended, zlib_encoded, payload.len));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ payload, zlib_appended.items);
    try std.testing.expectError(error.OutputLimitExceeded, decodeZlibAppendLimited(std.testing.allocator, &zlib_appended, zlib_encoded, payload.len - 1));

    const gzip_encoded = try encodeGzipBestAlloc(std.testing.allocator, payload, .{});
    defer std.testing.allocator.free(gzip_encoded);
    var gzip_appended: std.ArrayList(u8) = .empty;
    defer gzip_appended.deinit(std.testing.allocator);
    try gzip_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(payload.len, try decodeGzipAppend(std.testing.allocator, &gzip_appended, gzip_encoded));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ payload, gzip_appended.items);

    gzip_appended.clearRetainingCapacity();
    try gzip_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(payload.len, try decodeGzipAppendExactSize(std.testing.allocator, &gzip_appended, gzip_encoded, payload.len));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ payload, gzip_appended.items);
    try std.testing.expectError(error.SizeMismatch, decodeGzipAppendExactSize(std.testing.allocator, &gzip_appended, gzip_encoded, payload.len - 1));

    gzip_appended.clearRetainingCapacity();
    try gzip_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(payload.len, try decodeGzipAppendLimited(std.testing.allocator, &gzip_appended, gzip_encoded, payload.len));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ payload, gzip_appended.items);
    try std.testing.expectError(error.OutputLimitExceeded, decodeGzipAppendLimited(std.testing.allocator, &gzip_appended, gzip_encoded, payload.len - 1));
}

test "root zlib and gzip chunked append decode helpers preserve prefixes" {
    const payload = "root wrapper chunked append payload " ** 2;

    const zlib_encoded = try encodeZlibBestAlloc(std.testing.allocator, payload, .{});
    defer std.testing.allocator.free(zlib_encoded);
    const zlib_chunks = [_][]const u8{
        zlib_encoded[0..2],
        zlib_encoded[2..@min(zlib_encoded.len, 11)],
        zlib_encoded[@min(zlib_encoded.len, 11)..],
    };
    var zlib_appended: std.ArrayList(u8) = .empty;
    defer zlib_appended.deinit(std.testing.allocator);
    try zlib_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(payload.len, try decodeZlibChunksAppend(std.testing.allocator, &zlib_appended, &zlib_chunks));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ payload, zlib_appended.items);

    zlib_appended.clearRetainingCapacity();
    try zlib_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(payload.len, try decodeZlibChunksAppendExactSize(std.testing.allocator, &zlib_appended, &zlib_chunks, payload.len));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ payload, zlib_appended.items);
    try std.testing.expectError(error.SizeMismatch, decodeZlibChunksAppendExactSize(std.testing.allocator, &zlib_appended, &zlib_chunks, payload.len - 1));

    zlib_appended.clearRetainingCapacity();
    try zlib_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(payload.len, try decodeZlibChunksAppendLimited(std.testing.allocator, &zlib_appended, &zlib_chunks, payload.len));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ payload, zlib_appended.items);
    try std.testing.expectError(error.OutputLimitExceeded, decodeZlibChunksAppendLimited(std.testing.allocator, &zlib_appended, &zlib_chunks, payload.len - 1));

    const gzip_encoded = try encodeGzipBestAlloc(std.testing.allocator, payload, .{});
    defer std.testing.allocator.free(gzip_encoded);
    const gzip_chunks = [_][]const u8{
        gzip_encoded[0..4],
        gzip_encoded[4..@min(gzip_encoded.len, 17)],
        gzip_encoded[@min(gzip_encoded.len, 17)..],
    };
    const gzip_join = try std.testing.allocator.alloc(u8, gzip_encoded.len);
    defer std.testing.allocator.free(gzip_join);
    var gzip_appended: std.ArrayList(u8) = .empty;
    defer gzip_appended.deinit(std.testing.allocator);
    try gzip_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(payload.len, try decodeGzipChunksAppend(std.testing.allocator, &gzip_appended, &gzip_chunks, gzip_join));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ payload, gzip_appended.items);

    gzip_appended.clearRetainingCapacity();
    try gzip_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(payload.len, try decodeGzipChunksAppendExactSize(std.testing.allocator, &gzip_appended, &gzip_chunks, gzip_join, payload.len));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ payload, gzip_appended.items);
    try std.testing.expectError(error.SizeMismatch, decodeGzipChunksAppendExactSize(std.testing.allocator, &gzip_appended, &gzip_chunks, gzip_join, payload.len + 1));

    gzip_appended.clearRetainingCapacity();
    try gzip_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(payload.len, try decodeGzipChunksAppendLimited(std.testing.allocator, &gzip_appended, &gzip_chunks, gzip_join, payload.len));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ payload, gzip_appended.items);
    try std.testing.expectError(error.OutputLimitExceeded, decodeGzipChunksAppendLimited(std.testing.allocator, &gzip_appended, &gzip_chunks, gzip_join, payload.len - 1));
}

test "root zlib and gzip concatenated append decode helpers preserve prefixes" {
    const first = "first concatenated wrapper payload ";
    const second = "second concatenated wrapper payload";
    const expected = first ++ second;

    const zlib_first = try encodeZlibBestAlloc(std.testing.allocator, first, .{});
    defer std.testing.allocator.free(zlib_first);
    const zlib_second = try encodeZlibBestAlloc(std.testing.allocator, second, .{});
    defer std.testing.allocator.free(zlib_second);
    var zlib_stream: std.ArrayList(u8) = .empty;
    defer zlib_stream.deinit(std.testing.allocator);
    try zlib_stream.appendSlice(std.testing.allocator, zlib_first);
    try zlib_stream.appendSlice(std.testing.allocator, zlib_second);

    var zlib_appended: std.ArrayList(u8) = .empty;
    defer zlib_appended.deinit(std.testing.allocator);
    try zlib_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(expected.len, try decodeZlibConcatenatedAppend(std.testing.allocator, &zlib_appended, zlib_stream.items));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ expected, zlib_appended.items);

    zlib_appended.clearRetainingCapacity();
    try zlib_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(expected.len, try decodeZlibConcatenatedAppendExactSize(std.testing.allocator, &zlib_appended, zlib_stream.items, expected.len));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ expected, zlib_appended.items);
    try std.testing.expectError(error.SizeMismatch, decodeZlibConcatenatedAppendExactSize(std.testing.allocator, &zlib_appended, zlib_stream.items, expected.len + 1));

    zlib_appended.clearRetainingCapacity();
    try zlib_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(expected.len, try decodeZlibConcatenatedAppendLimited(std.testing.allocator, &zlib_appended, zlib_stream.items, expected.len));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ expected, zlib_appended.items);
    try std.testing.expectError(error.OutputLimitExceeded, decodeZlibConcatenatedAppendLimited(std.testing.allocator, &zlib_appended, zlib_stream.items, expected.len - 1));

    const gzip_first = try encodeGzipBestAlloc(std.testing.allocator, first, .{});
    defer std.testing.allocator.free(gzip_first);
    const gzip_second = try encodeGzipBestAlloc(std.testing.allocator, second, .{});
    defer std.testing.allocator.free(gzip_second);
    var gzip_stream: std.ArrayList(u8) = .empty;
    defer gzip_stream.deinit(std.testing.allocator);
    try gzip_stream.appendSlice(std.testing.allocator, gzip_first);
    try gzip_stream.appendSlice(std.testing.allocator, gzip_second);

    var gzip_appended: std.ArrayList(u8) = .empty;
    defer gzip_appended.deinit(std.testing.allocator);
    try gzip_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(expected.len, try decodeGzipConcatenatedAppend(std.testing.allocator, &gzip_appended, gzip_stream.items));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ expected, gzip_appended.items);

    gzip_appended.clearRetainingCapacity();
    try gzip_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(expected.len, try decodeGzipConcatenatedAppendExactSize(std.testing.allocator, &gzip_appended, gzip_stream.items, expected.len));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ expected, gzip_appended.items);
    try std.testing.expectError(error.SizeMismatch, decodeGzipConcatenatedAppendExactSize(std.testing.allocator, &gzip_appended, gzip_stream.items, expected.len - 1));

    gzip_appended.clearRetainingCapacity();
    try gzip_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(expected.len, try decodeGzipConcatenatedAppendLimited(std.testing.allocator, &gzip_appended, gzip_stream.items, expected.len));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ expected, gzip_appended.items);
    try std.testing.expectError(error.OutputLimitExceeded, decodeGzipConcatenatedAppendLimited(std.testing.allocator, &gzip_appended, gzip_stream.items, expected.len - 1));
}

test "root zlib and gzip concatenated chunked append decode helpers preserve prefixes" {
    const first = "first chunked concatenated wrapper payload ";
    const second = "second chunked concatenated wrapper payload";
    const expected = first ++ second;

    const zlib_first = try encodeZlibBestAlloc(std.testing.allocator, first, .{});
    defer std.testing.allocator.free(zlib_first);
    const zlib_second = try encodeZlibBestAlloc(std.testing.allocator, second, .{});
    defer std.testing.allocator.free(zlib_second);
    var zlib_stream: std.ArrayList(u8) = .empty;
    defer zlib_stream.deinit(std.testing.allocator);
    try zlib_stream.appendSlice(std.testing.allocator, zlib_first);
    try zlib_stream.appendSlice(std.testing.allocator, zlib_second);
    const zlib_chunks = [_][]const u8{
        zlib_stream.items[0..3],
        zlib_stream.items[3..@min(zlib_stream.items.len, 19)],
        zlib_stream.items[@min(zlib_stream.items.len, 19)..],
    };
    const zlib_join = try std.testing.allocator.alloc(u8, zlib_stream.items.len);
    defer std.testing.allocator.free(zlib_join);
    var zlib_appended: std.ArrayList(u8) = .empty;
    defer zlib_appended.deinit(std.testing.allocator);
    try zlib_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(expected.len, try decodeZlibConcatenatedChunksAppend(std.testing.allocator, &zlib_appended, &zlib_chunks, zlib_join));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ expected, zlib_appended.items);

    zlib_appended.clearRetainingCapacity();
    try zlib_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(expected.len, try decodeZlibConcatenatedChunksAppendExactSize(std.testing.allocator, &zlib_appended, &zlib_chunks, zlib_join, expected.len));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ expected, zlib_appended.items);
    try std.testing.expectError(error.SizeMismatch, decodeZlibConcatenatedChunksAppendExactSize(std.testing.allocator, &zlib_appended, &zlib_chunks, zlib_join, expected.len + 1));

    zlib_appended.clearRetainingCapacity();
    try zlib_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(expected.len, try decodeZlibConcatenatedChunksAppendLimited(std.testing.allocator, &zlib_appended, &zlib_chunks, zlib_join, expected.len));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ expected, zlib_appended.items);
    try std.testing.expectError(error.OutputLimitExceeded, decodeZlibConcatenatedChunksAppendLimited(std.testing.allocator, &zlib_appended, &zlib_chunks, zlib_join, expected.len - 1));

    const gzip_first = try encodeGzipBestAlloc(std.testing.allocator, first, .{});
    defer std.testing.allocator.free(gzip_first);
    const gzip_second = try encodeGzipBestAlloc(std.testing.allocator, second, .{});
    defer std.testing.allocator.free(gzip_second);
    var gzip_stream: std.ArrayList(u8) = .empty;
    defer gzip_stream.deinit(std.testing.allocator);
    try gzip_stream.appendSlice(std.testing.allocator, gzip_first);
    try gzip_stream.appendSlice(std.testing.allocator, gzip_second);
    const gzip_chunks = [_][]const u8{
        gzip_stream.items[0..5],
        gzip_stream.items[5..@min(gzip_stream.items.len, 23)],
        gzip_stream.items[@min(gzip_stream.items.len, 23)..],
    };
    const gzip_join = try std.testing.allocator.alloc(u8, gzip_stream.items.len);
    defer std.testing.allocator.free(gzip_join);
    var gzip_appended: std.ArrayList(u8) = .empty;
    defer gzip_appended.deinit(std.testing.allocator);
    try gzip_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(expected.len, try decodeGzipConcatenatedChunksAppend(std.testing.allocator, &gzip_appended, &gzip_chunks, gzip_join));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ expected, gzip_appended.items);

    gzip_appended.clearRetainingCapacity();
    try gzip_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(expected.len, try decodeGzipConcatenatedChunksAppendExactSize(std.testing.allocator, &gzip_appended, &gzip_chunks, gzip_join, expected.len));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ expected, gzip_appended.items);
    try std.testing.expectError(error.SizeMismatch, decodeGzipConcatenatedChunksAppendExactSize(std.testing.allocator, &gzip_appended, &gzip_chunks, gzip_join, expected.len - 1));

    gzip_appended.clearRetainingCapacity();
    try gzip_appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(expected.len, try decodeGzipConcatenatedChunksAppendLimited(std.testing.allocator, &gzip_appended, &gzip_chunks, gzip_join, expected.len));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ expected, gzip_appended.items);
    try std.testing.expectError(error.OutputLimitExceeded, decodeGzipConcatenatedChunksAppendLimited(std.testing.allocator, &gzip_appended, &gzip_chunks, gzip_join, expected.len - 1));
}
