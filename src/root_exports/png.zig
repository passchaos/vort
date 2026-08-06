const std = @import("std");
const deflate = @import("../deflate.zig");
const png = @import("../png.zig");

pub const PngAdam7Info = png.PngAdam7Info;
pub const PngAdam7PassInfo = png.PngAdam7PassInfo;
pub const PngAdam7Row = deflate.PngAdam7Row;
pub const PngAdam7RowCallback = deflate.PngAdam7RowCallback;
pub const PngAdam7RowsDecodeResult = deflate.PngAdam7RowsDecodeResult;
pub const PngAdam7StreamingRowsSnapshot = deflate.PngAdam7StreamingRowsSnapshot;
pub const PngAdam7StreamingZlibChunkedRowDecoder = deflate.PngAdam7StreamingZlibChunkedRowDecoder;
pub const PngAdam7StreamingZlibRowDecoder = deflate.PngAdam7StreamingZlibRowDecoder;
pub const PngColorType = png.PngColorType;
pub const PngFilterMethod = png.PngFilterMethod;
pub const PngImageInfo = png.PngImageInfo;
pub const PngZlibDecodeBufferSizes = png.PngZlibDecodeBufferSizes;
pub const PngStoredZlibChunkedScanlineDecoder = deflate.PngStoredZlibChunkedScanlineDecoder;
pub const PngStoredZlibScanlineDecoder = deflate.PngStoredZlibScanlineDecoder;
pub const PngStreamingZlibChunkedScanlineDecoder = deflate.PngStreamingZlibChunkedScanlineDecoder;
pub const PngStreamingZlibScanlineDecoder = deflate.PngStreamingZlibScanlineDecoder;
pub const PngZlibScanlineDecoder = deflate.PngZlibScanlineDecoder;
pub const PngAdam7ImageDecodeResult = deflate.PngAdam7ImageDecodeResult;
pub const PngImageDecodeResult = deflate.PngImageDecodeResult;
pub const parsePngColorType = png.parsePngColorType;
pub const pngImageInfo = png.pngImageInfo;
pub const pngImageInfoFromColorType = png.pngImageInfoFromColorType;
pub const pngIdatChunksScratchLen = deflate.pngIdatChunksScratchLen;
pub const pngAdam7Info = png.pngAdam7Info;
pub const pngAdam7InfoFromColorType = png.pngAdam7InfoFromColorType;
pub const pngAdam7DecodeBufferSizes = png.pngAdam7DecodeBufferSizes;
pub const placePngAdam7Row = png.placePngAdam7Row;
pub const placePngAdam7Pass = png.placePngAdam7Pass;
pub const pngZlibDecodeBufferSizes = png.pngZlibDecodeBufferSizes;
pub const decodePngStoredZlibImage = deflate.decodePngStoredZlibImage;
pub const decodePngStoredZlibImageWithOptions = deflate.decodePngStoredZlibImageWithOptions;
pub const decodePngStoredZlibImageFromChunksDirect = deflate.decodePngStoredZlibImageFromChunksDirect;
pub const decodePngStoredZlibImageFromChunksWithOptionsDirect = deflate.decodePngStoredZlibImageFromChunksWithOptionsDirect;
pub const decodePngStreamingZlibImage = deflate.decodePngStreamingZlibImage;
pub const decodePngStreamingZlibImageWithOptions = deflate.decodePngStreamingZlibImageWithOptions;
pub const decodePngStreamingZlibImageFromChunksDirect = deflate.decodePngStreamingZlibImageFromChunksDirect;
pub const decodePngStreamingZlibImageFromChunksWithOptionsDirect = deflate.decodePngStreamingZlibImageFromChunksWithOptionsDirect;
pub const decodePngZlibImage = deflate.decodePngZlibImage;
pub const decodePngZlibImageWithOptions = deflate.decodePngZlibImageWithOptions;
pub const decodePngZlibImageParallelWithOptions = deflate.decodePngZlibImageParallelWithOptions;
pub const decodePngFilter0DynamicZlibImageWithOptions = deflate.decodePngFilter0DynamicZlibImageWithOptions;
pub const decodePngZlibImageFromChunks = deflate.decodePngZlibImageFromChunks;
pub const decodePngZlibImageFromChunksDirect = deflate.decodePngZlibImageFromChunksDirect;
pub const decodePngZlibImageFromChunksWithOptionsDirect = deflate.decodePngZlibImageFromChunksWithOptionsDirect;
pub const decodePngAdam7ZlibImage = deflate.decodePngAdam7ZlibImage;
pub const decodePngAdam7ZlibImageFromChunks = deflate.decodePngAdam7ZlibImageFromChunks;
pub const decodePngAdam7ZlibImageFromChunksDirect = deflate.decodePngAdam7ZlibImageFromChunksDirect;
pub const decodePngAdam7ZlibImageFromChunksWithOptionsDirect = deflate.decodePngAdam7ZlibImageFromChunksWithOptionsDirect;
pub const decodePngAdam7StreamingZlibImage = deflate.decodePngAdam7StreamingZlibImage;
pub const decodePngAdam7StreamingZlibImageWithOptions = deflate.decodePngAdam7StreamingZlibImageWithOptions;
pub const decodePngAdam7StreamingZlibImageFromChunksDirect = deflate.decodePngAdam7StreamingZlibImageFromChunksDirect;
pub const decodePngAdam7StreamingZlibImageFromChunksWithOptionsDirect = deflate.decodePngAdam7StreamingZlibImageFromChunksWithOptionsDirect;
pub const streamPngAdam7ZlibRows = deflate.streamPngAdam7ZlibRows;
pub const streamPngAdam7ZlibRowsWithOptions = deflate.streamPngAdam7ZlibRowsWithOptions;
pub const streamPngAdam7ZlibRowsFromChunksDirect = deflate.streamPngAdam7ZlibRowsFromChunksDirect;
pub const streamPngAdam7ZlibRowsFromChunksWithOptionsDirect = deflate.streamPngAdam7ZlibRowsFromChunksWithOptionsDirect;
pub const reconstructPngScanline = png.reconstructPngScanline;

/// Verify that root-level PNG aliases injected from this module remain usable.
///
/// Keeping this logic next to the alias table lets `src/root.zig` stay small
/// while still proving that the explicit root aliases expose both low-level PNG
/// primitives and deflate-backed PNG/zlib wrapper types through the public root.
pub fn smokeRootExports(comptime Root: type) !void {
    comptime {
        _ = Root.png;
        _ = Root.PngFilterMethod;
        _ = Root.PngColorType;
        _ = Root.PngImageInfo;
        _ = Root.PngZlibDecodeBufferSizes;
        _ = Root.PngAdam7PassInfo;
        _ = Root.PngAdam7Info;
        _ = Root.PngZlibScanlineDecoder;
        _ = Root.PngStreamingZlibScanlineDecoder;
    }

    const info = try Root.pngImageInfo(2, 1, 8, .truecolor);
    try std.testing.expectEqual(Root.PngColorType.truecolor, info.color_type);
    try std.testing.expectEqual(@as(usize, 6), info.row_len);
    try std.testing.expectEqual(@as(usize, 3), info.bytes_per_pixel);
    const sizes = try Root.pngZlibDecodeBufferSizes(info);
    try std.testing.expectEqual(@as(usize, 7), sizes.zlib_scratch_len);
    try std.testing.expectEqual(@as(usize, 6), sizes.image_output_len);

    const filtered = [_]u8{ 1, 2, 3, 4, 5, 6 };
    var reconstructed: [filtered.len]u8 = undefined;
    try std.testing.expectEqual(
        filtered.len,
        try Root.reconstructPngScanline(@intFromEnum(Root.PngFilterMethod.none), &filtered, null, info.bytes_per_pixel, &reconstructed),
    );
    try std.testing.expectEqualSlices(u8, &filtered, &reconstructed);

    const adam7 = try Root.pngAdam7Info(1, 1, 8, .grayscale);
    const adam7_sizes = Root.pngAdam7DecodeBufferSizes(adam7);
    try std.testing.expectEqual(@as(usize, 2), adam7_sizes.zlib_scratch_len);
    var image: [1]u8 = undefined;
    try Root.placePngAdam7Row(adam7, adam7.passes[0], 0, &.{0x7b}, &image);
    try std.testing.expectEqual(@as(u8, 0x7b), image[0]);
}
