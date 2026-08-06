const std = @import("std");
const builtin = @import("builtin");
const core = @import("core.zig");

pub const Error = core.Error;

pub const PngFilterMethod = enum(u8) {
    none = 0,
    sub = 1,
    up = 2,
    average = 3,
    paeth = 4,
};

pub const PngColorType = enum(u8) {
    grayscale = 0,
    truecolor = 2,
    indexed = 3,
    grayscale_alpha = 4,
    truecolor_alpha = 6,
};

pub const PngImageInfo = struct {
    width: usize,
    height: usize,
    bit_depth: u8,
    color_type: PngColorType,
    samples_per_pixel: u8,
    bits_per_pixel: u16,
    /// Bytes in one filtered scanline after the leading PNG filter byte. This is
    /// ceil(width * samples_per_pixel * bit_depth / 8).
    row_len: usize,
    /// PNG filter predictor stride in bytes. For sub-byte formats PNG rounds
    /// this up to one byte, so callers can use the same row reconstruction
    /// surface for indexed/grayscale bit depths below 8.
    bytes_per_pixel: usize,
    /// Exact decoded zlib payload bytes for all scanlines, including one filter
    /// byte per row. Useful for exact-size zlib/IDAT decode preflight.
    zlib_payload_len: usize,
};

pub const PngZlibDecodeBufferSizes = struct {
    /// Exact decoded IDAT/zlib payload size, including one filter byte per row.
    zlib_scratch_len: usize,
    /// Scratch needed to hold one filtered row before PNG filter reconstruction.
    filtered_row_scratch_len: usize,
    /// Scratch needed to hold the previous reconstructed row for filters 2..4.
    previous_row_scratch_len: usize,
    /// Reconstructed image bytes produced by `decodePngZlibImage*`.
    image_output_len: usize,
};

pub const PngAdam7PassInfo = struct {
    pass_index: u8,
    x_start: usize,
    y_start: usize,
    x_step: usize,
    y_step: usize,
    width: usize,
    height: usize,
    row_len: usize,
    bytes_per_pixel: usize,
    zlib_payload_len: usize,
    reconstructed_len: usize,

    pub fn isEmpty(self: PngAdam7PassInfo) bool {
        return self.width == 0 or self.height == 0;
    }
};

pub const PngAdam7Info = struct {
    image: PngImageInfo,
    passes: [7]PngAdam7PassInfo,
    zlib_payload_len: usize,
    max_pass_row_len: usize,
    image_output_len: usize,
};

pub fn parsePngColorType(color_type: u8) Error!PngColorType {
    return switch (color_type) {
        0 => .grayscale,
        2 => .truecolor,
        3 => .indexed,
        4 => .grayscale_alpha,
        6 => .truecolor_alpha,
        else => error.CorruptFrame,
    };
}

fn pngSamplesPerPixelAndValidateDepth(color_type: PngColorType, bit_depth: u8) Error!u8 {
    return switch (color_type) {
        .grayscale => switch (bit_depth) {
            1, 2, 4, 8, 16 => 1,
            else => error.CorruptFrame,
        },
        .truecolor => switch (bit_depth) {
            8, 16 => 3,
            else => error.CorruptFrame,
        },
        .indexed => switch (bit_depth) {
            1, 2, 4, 8 => 1,
            else => error.CorruptFrame,
        },
        .grayscale_alpha => switch (bit_depth) {
            8, 16 => 2,
            else => error.CorruptFrame,
        },
        .truecolor_alpha => switch (bit_depth) {
            8, 16 => 4,
            else => error.CorruptFrame,
        },
    };
}

pub fn pngImageInfo(width: usize, height: usize, bit_depth: u8, color_type: PngColorType) Error!PngImageInfo {
    if (width == 0 or height == 0) return error.CorruptFrame;
    const samples_per_pixel = try pngSamplesPerPixelAndValidateDepth(color_type, bit_depth);
    const bits_per_pixel = @as(u16, samples_per_pixel) * @as(u16, bit_depth);
    const row_len = try pngPackedRowLen(width, bits_per_pixel);
    const bytes_per_pixel = @max(@as(usize, 1), (@as(usize, bits_per_pixel) + 7) / 8);
    return .{
        .width = width,
        .height = height,
        .bit_depth = bit_depth,
        .color_type = color_type,
        .samples_per_pixel = samples_per_pixel,
        .bits_per_pixel = bits_per_pixel,
        .row_len = row_len,
        .bytes_per_pixel = bytes_per_pixel,
        .zlib_payload_len = try pngScanlinePayloadLen(row_len, height),
    };
}

pub fn pngImageInfoFromColorType(width: usize, height: usize, bit_depth: u8, color_type: u8) Error!PngImageInfo {
    return pngImageInfo(width, height, bit_depth, try parsePngColorType(color_type));
}

fn pngPackedRowLen(width: usize, bits_per_pixel: usize) Error!usize {
    const total_row_bits = std.math.mul(usize, width, bits_per_pixel) catch return error.IntegerOverflow;
    const row_bits_with_rounding = std.math.add(usize, total_row_bits, 7) catch return error.IntegerOverflow;
    return row_bits_with_rounding / 8;
}

pub fn pngZlibDecodeBufferSizes(info: PngImageInfo) Error!PngZlibDecodeBufferSizes {
    return .{
        .zlib_scratch_len = info.zlib_payload_len,
        .filtered_row_scratch_len = info.row_len,
        .previous_row_scratch_len = info.row_len,
        .image_output_len = try pngImageOutputLen(info),
    };
}

const adam7_x_start = [_]usize{ 0, 4, 0, 2, 0, 1, 0 };
const adam7_y_start = [_]usize{ 0, 0, 4, 0, 2, 0, 1 };
const adam7_x_step = [_]usize{ 8, 8, 4, 4, 2, 2, 1 };
const adam7_y_step = [_]usize{ 8, 8, 8, 4, 4, 2, 2 };

pub fn pngAdam7Info(width: usize, height: usize, bit_depth: u8, color_type: PngColorType) Error!PngAdam7Info {
    const image = try pngImageInfo(width, height, bit_depth, color_type);
    var passes: [7]PngAdam7PassInfo = undefined;
    var total_payload: usize = 0;
    var max_pass_row_len: usize = 0;
    for (0..7) |i| {
        const pass_width = adam7PassDimension(width, adam7_x_start[i], adam7_x_step[i]);
        const pass_height = adam7PassDimension(height, adam7_y_start[i], adam7_y_step[i]);
        const row_len = if (pass_width == 0 or pass_height == 0) 0 else try pngPackedRowLen(pass_width, image.bits_per_pixel);
        const pass_payload = if (pass_width == 0 or pass_height == 0) 0 else try pngScanlinePayloadLen(row_len, pass_height);
        const reconstructed_len = std.math.mul(usize, row_len, pass_height) catch return error.IntegerOverflow;
        total_payload = std.math.add(usize, total_payload, pass_payload) catch return error.IntegerOverflow;
        max_pass_row_len = @max(max_pass_row_len, row_len);
        passes[i] = .{
            .pass_index = @intCast(i + 1),
            .x_start = adam7_x_start[i],
            .y_start = adam7_y_start[i],
            .x_step = adam7_x_step[i],
            .y_step = adam7_y_step[i],
            .width = pass_width,
            .height = pass_height,
            .row_len = row_len,
            .bytes_per_pixel = image.bytes_per_pixel,
            .zlib_payload_len = pass_payload,
            .reconstructed_len = reconstructed_len,
        };
    }
    return .{
        .image = image,
        .passes = passes,
        .zlib_payload_len = total_payload,
        .max_pass_row_len = max_pass_row_len,
        .image_output_len = try pngImageOutputLen(image),
    };
}

pub fn pngAdam7InfoFromColorType(width: usize, height: usize, bit_depth: u8, color_type: u8) Error!PngAdam7Info {
    return pngAdam7Info(width, height, bit_depth, try parsePngColorType(color_type));
}

pub fn pngAdam7DecodeBufferSizes(info: PngAdam7Info) PngZlibDecodeBufferSizes {
    return .{
        .zlib_scratch_len = info.zlib_payload_len,
        .filtered_row_scratch_len = info.max_pass_row_len,
        .previous_row_scratch_len = info.max_pass_row_len,
        .image_output_len = info.image_output_len,
    };
}

/// Scatter one reconstructed Adam7 pass row into the final non-interlaced image.
///
/// `row` is the reconstructed payload for one row of `pass` (filter byte already
/// removed and PNG filtering already reversed). `image` is the final packed image
/// buffer described by `info.image`. Byte-aligned formats copy whole pixels;
/// sub-byte grayscale/indexed formats copy individual packed pixels MSB-first.
pub fn placePngAdam7Row(info: PngAdam7Info, pass: PngAdam7PassInfo, pass_row_index: usize, row: []const u8, image: []u8) Error!void {
    if (pass.isEmpty()) return error.RangeOutOfBounds;
    if (pass_row_index >= pass.height) return error.RangeOutOfBounds;
    if (row.len < pass.row_len) return error.InputTooSmall;
    if (image.len < info.image_output_len) return error.OutputTooSmall;

    const dest_y = pass.y_start + pass_row_index * pass.y_step;
    if (dest_y >= info.image.height) return error.RangeOutOfBounds;
    const bits_per_pixel: usize = info.image.bits_per_pixel;
    if (bits_per_pixel >= 8) {
        if (bits_per_pixel % 8 != 0) return error.CorruptFrame;
        const pixel_bytes = bits_per_pixel / 8;
        for (0..pass.width) |pass_x| {
            const dest_x = pass.x_start + pass_x * pass.x_step;
            if (dest_x >= info.image.width) return error.RangeOutOfBounds;
            const src = row[pass_x * pixel_bytes ..][0..pixel_bytes];
            const dest_offset = dest_y * info.image.row_len + dest_x * pixel_bytes;
            @memcpy(image[dest_offset..][0..pixel_bytes], src);
        }
        return;
    }

    if (bits_per_pixel != 1 and bits_per_pixel != 2 and bits_per_pixel != 4) return error.CorruptFrame;
    for (0..pass.width) |pass_x| {
        const dest_x = pass.x_start + pass_x * pass.x_step;
        if (dest_x >= info.image.width) return error.RangeOutOfBounds;
        const value = readPngPackedPixel(row, pass_x, bits_per_pixel);
        writePngPackedPixel(image[dest_y * info.image.row_len ..][0..info.image.row_len], dest_x, bits_per_pixel, value);
    }
}

pub fn placePngAdam7Pass(info: PngAdam7Info, pass: PngAdam7PassInfo, pass_rows: []const u8, image: []u8) Error!void {
    if (pass.isEmpty()) {
        if (pass_rows.len != 0) return error.SizeMismatch;
        return;
    }
    if (pass_rows.len < pass.reconstructed_len) return error.InputTooSmall;
    for (0..pass.height) |row_index| {
        const row = pass_rows[row_index * pass.row_len ..][0..pass.row_len];
        try placePngAdam7Row(info, pass, row_index, row, image);
    }
}

fn readPngPackedPixel(row: []const u8, pixel_index: usize, bits_per_pixel: usize) u8 {
    const bit_offset = pixel_index * bits_per_pixel;
    const byte_index = bit_offset / 8;
    const bit_in_byte = bit_offset % 8;
    const shift: u3 = @intCast(8 - bits_per_pixel - bit_in_byte);
    const mask: u8 = @as(u8, @intCast((@as(u16, 1) << @intCast(bits_per_pixel)) - 1));
    return (row[byte_index] >> shift) & mask;
}

fn writePngPackedPixel(row: []u8, pixel_index: usize, bits_per_pixel: usize, value: u8) void {
    const bit_offset = pixel_index * bits_per_pixel;
    const byte_index = bit_offset / 8;
    const bit_in_byte = bit_offset % 8;
    const shift: u3 = @intCast(8 - bits_per_pixel - bit_in_byte);
    const mask: u8 = @as(u8, @intCast((@as(u16, 1) << @intCast(bits_per_pixel)) - 1));
    const shifted_mask = mask << shift;
    row[byte_index] = (row[byte_index] & ~shifted_mask) | ((value & mask) << shift);
}

fn adam7PassDimension(size: usize, start: usize, step: usize) usize {
    if (size <= start) return 0;
    return ((size - 1 - start) / step) + 1;
}

fn parsePngFilterMethod(filter: u8) Error!PngFilterMethod {
    return switch (filter) {
        0 => .none,
        1 => .sub,
        2 => .up,
        3 => .average,
        4 => .paeth,
        else => error.CorruptFrame,
    };
}

fn pngPaethPredictor(left: u8, up: u8, up_left: u8) u8 {
    return pngPaethPredictorStbi(left, up, up_left);
}

fn pngPaethPredictorReference(left: u8, up: u8, up_left: u8) u8 {
    const a: i32 = left;
    const b: i32 = up;
    const c: i32 = up_left;
    const p = a + b - c;
    const pa = absI32(p - a);
    const pb = absI32(p - b);
    const pc = absI32(p - c);
    if (pa <= pb and pa <= pc) return left;
    if (pb <= pc) return up;
    return up_left;
}

fn pngPaethPredictorStbi(left: u8, up: u8, up_left: u8) u8 {
    return pngPaethPredictorStbiI16(left, up, up_left);
}

inline fn pngPaethPredictorStbiI16(left: i16, up: i16, up_left: i16) u8 {
    // image-png uses this stb_image formulation on x86_64 because LLVM lowers
    // it to a less branchy dependency chain than the PNG specification's three
    // absolute-distance comparisons. The threshold form is exactly equivalent,
    // including PNG's left/up/up-left tie-breaking order.
    const threshold = up_left * 3 - (left + up);
    const low = @min(left, up);
    const high = @max(left, up);
    const first = if (high <= threshold) low else up_left;
    return @intCast(if (threshold <= low) high else first);
}

fn absI32(value: i32) i32 {
    return if (value < 0) -value else value;
}

/// Reconstruct one PNG scanline payload in caller-owned output storage.
///
/// `filtered` excludes the leading PNG filter byte; pass that byte separately as
/// `filter`. `previous` is the already-reconstructed previous row, or null for
/// the first row. `bytes_per_pixel` is PNG's filter byte stride, rounded up to at
/// least one byte by the caller for sub-byte color formats. Arithmetic is
/// modulo 256 as required by the PNG filter specification.
pub fn reconstructPngScanline(filter: u8, filtered: []const u8, previous: ?[]const u8, bytes_per_pixel: usize, output: []u8) Error!usize {
    const method = try parsePngFilterMethod(filter);
    if (bytes_per_pixel == 0) return error.CorruptFrame;
    if (output.len < filtered.len) return error.OutputTooSmall;
    if (previous) |prev| {
        if (prev.len != filtered.len) return error.SizeMismatch;
    }

    const reconstructed = output[0..filtered.len];
    if (method == .none) {
        copyPossiblyAliasedBytes(reconstructed, filtered);
        return filtered.len;
    }
    if (method == .sub) {
        reconstructPngSubScanline(filtered, bytes_per_pixel, reconstructed);
        return filtered.len;
    }
    if (method == .up) {
        if (previous) |prev| {
            reconstructPngUpScanline(filtered, prev, reconstructed);
        } else {
            copyPossiblyAliasedBytes(reconstructed, filtered);
        }
        return filtered.len;
    }
    if (method == .average) {
        reconstructPngAverageScanline(filtered, previous, bytes_per_pixel, reconstructed);
        return filtered.len;
    }
    if (method == .paeth and bytes_per_pixel == 1) {
        // bpp=1 covers indexed/low-bit grayscale scanline payloads after PNG's
        // "bytes per pixel is at least one" filter rule. Splitting it from the
        // generic loop avoids the per-byte stride branches while keeping the
        // same in-place behavior used by Adam7 pass reconstruction.
        reconstructPngPaethBpp1Scanline(filtered, previous, reconstructed);
        return filtered.len;
    }
    if (method == .paeth) {
        // Wider Paeth rows still have the same prefix/no-previous reductions as
        // the PNG spec's generic predictor, but spelling them out here removes
        // two hot-path stride checks per byte for common RGB/RGBA rows.
        reconstructPngPaethScanline(filtered, previous, bytes_per_pixel, reconstructed);
        return filtered.len;
    }

    for (filtered, 0..) |raw, i| {
        const left: u8 = if (i >= bytes_per_pixel) reconstructed[i - bytes_per_pixel] else 0;
        const up: u8 = if (previous) |prev| prev[i] else 0;
        const up_left: u8 = if (i >= bytes_per_pixel) blk: {
            if (previous) |prev| break :blk prev[i - bytes_per_pixel];
            break :blk 0;
        } else 0;
        const prediction: u8 = switch (method) {
            .none => 0,
            .sub => left,
            .up => up,
            .average => @intCast((@as(u16, left) + @as(u16, up)) / 2),
            .paeth => pngPaethPredictor(left, up, up_left),
        };
        reconstructed[i] = raw +% prediction;
    }
    return filtered.len;
}

fn reconstructPngUpScanline(filtered: []const u8, previous: []const u8, output: []u8) void {
    const lanes = 32;
    var i: usize = 0;
    while (i + lanes <= filtered.len) : (i += lanes) {
        const filtered_vec: @Vector(lanes, u8) = filtered[i..][0..lanes].*;
        const previous_vec: @Vector(lanes, u8) = previous[i..][0..lanes].*;
        output[i..][0..lanes].* = filtered_vec +% previous_vec;
    }
    while (i < filtered.len) : (i += 1) output[i] = filtered[i] +% previous[i];
}

fn reconstructPngAverageScanline(filtered: []const u8, previous: ?[]const u8, bytes_per_pixel: usize, output: []u8) void {
    switch (bytes_per_pixel) {
        2 => return reconstructPngAverageFixedBppScanline(2, filtered, previous, output),
        3 => return reconstructPngAverageBpp3Scanline(filtered, previous, output),
        4 => return reconstructPngAverageFixedBppScanline(4, filtered, previous, output),
        6 => return reconstructPngAverageFixedBppScanline(6, filtered, previous, output),
        8 => return reconstructPngAverageFixedBppScanline(8, filtered, previous, output),
        else => {},
    }
    return reconstructPngAverageScanlineReference(filtered, previous, bytes_per_pixel, output);
}

fn reconstructPngAverageScanlineReference(filtered: []const u8, previous: ?[]const u8, bytes_per_pixel: usize, output: []u8) void {
    if (previous) |prev| {
        const prefix = @min(bytes_per_pixel, filtered.len);
        var i: usize = 0;
        while (i < prefix) : (i += 1) output[i] = filtered[i] +% @as(u8, @intCast(@as(u16, prev[i]) >> 1));
        while (i < filtered.len) : (i += 1) {
            output[i] = filtered[i] +% @as(u8, @intCast((@as(u16, output[i - bytes_per_pixel]) + @as(u16, prev[i])) >> 1));
        }
    } else {
        const prefix = @min(bytes_per_pixel, filtered.len);
        copyPossiblyAliasedBytes(output[0..prefix], filtered[0..prefix]);
        var i: usize = prefix;
        while (i < filtered.len) : (i += 1) output[i] = filtered[i] +% (output[i - bytes_per_pixel] >> 1);
    }
}

fn reconstructPngAverageBpp3Scanline(filtered: []const u8, previous: ?[]const u8, output: []u8) void {
    reconstructPngAverageFixedBppScanline(3, filtered, previous, output);
}

fn reconstructPngAverageFixedBppScanline(comptime bytes_per_pixel: usize, filtered: []const u8, previous: ?[]const u8, output: []u8) void {
    // Match image-png's fixed-bpp Average loop: keep the previous reconstructed
    // pixel in registers instead of loading output[i - bpp] for every byte.
    // This removes a loop-carried memory dependency for common PNG strides
    // (grayscale, RGB/RGBA, and 16-bit variants) while the scalar tail preserves
    // malformed/non-pixel-aligned rows and in-place reconstruction.
    var left: [bytes_per_pixel]u8 = @splat(0);
    var i: usize = 0;
    if (previous) |prev| {
        while (i + bytes_per_pixel <= filtered.len) : (i += bytes_per_pixel) {
            inline for (0..bytes_per_pixel) |channel| {
                const value = filtered[i + channel] +% @as(u8, @intCast((@as(u16, left[channel]) + @as(u16, prev[i + channel])) >> 1));
                output[i + channel] = value;
                left[channel] = value;
            }
        }
        while (i < filtered.len) : (i += 1) {
            const channel = i % bytes_per_pixel;
            const value = filtered[i] +% @as(u8, @intCast((@as(u16, left[channel]) + @as(u16, prev[i])) >> 1));
            output[i] = value;
            left[channel] = value;
        }
    } else {
        while (i + bytes_per_pixel <= filtered.len) : (i += bytes_per_pixel) {
            inline for (0..bytes_per_pixel) |channel| {
                const value = filtered[i + channel] +% (left[channel] >> 1);
                output[i + channel] = value;
                left[channel] = value;
            }
        }
        while (i < filtered.len) : (i += 1) {
            const channel = i % bytes_per_pixel;
            const value = filtered[i] +% (left[channel] >> 1);
            output[i] = value;
            left[channel] = value;
        }
    }
}

fn reconstructPngPaethBpp1Scanline(filtered: []const u8, previous: ?[]const u8, output: []u8) void {
    if (previous) |prev| {
        if (filtered.len == 0) return;
        output[0] = filtered[0] +% prev[0];
        var i: usize = 1;
        while (i < filtered.len) : (i += 1) {
            output[i] = filtered[i] +% pngPaethPredictor(output[i - 1], prev[i], prev[i - 1]);
        }
    } else {
        reconstructPngSubBpp1Scanline(filtered, output);
    }
}

fn reconstructPngPaethScanline(filtered: []const u8, previous: ?[]const u8, bytes_per_pixel: usize, output: []u8) void {
    switch (bytes_per_pixel) {
        3 => return reconstructPngPaethFixedBppScanline(3, filtered, previous, output),
        4 => return reconstructPngPaethFixedBppScanline(4, filtered, previous, output),
        6 => return reconstructPngPaethFixedBppScanline(6, filtered, previous, output),
        8 => return reconstructPngPaethFixedBppScanline(8, filtered, previous, output),
        else => {},
    }
    if (previous) |prev| {
        const prefix = @min(bytes_per_pixel, filtered.len);
        var i: usize = 0;
        while (i < prefix) : (i += 1) output[i] = filtered[i] +% prev[i];
        while (i < filtered.len) : (i += 1) {
            output[i] = filtered[i] +% pngPaethPredictor(output[i - bytes_per_pixel], prev[i], prev[i - bytes_per_pixel]);
        }
    } else {
        reconstructPngSubScanline(filtered, bytes_per_pixel, output);
    }
}

fn reconstructPngPaethFixedBppScanline(comptime bytes_per_pixel: usize, filtered: []const u8, previous: ?[]const u8, output: []u8) void {
    if (previous) |prev| {
        return reconstructPngPaethFixedBppScanlineFast(bytes_per_pixel, filtered, prev, output);
    } else {
        reconstructPngSubScanline(filtered, bytes_per_pixel, output);
    }
}

fn reconstructPngPaethFixedBppScanlineFast(comptime bytes_per_pixel: usize, filtered: []const u8, previous: []const u8, output: []u8) void {
    // Keep the previous reconstructed pixel (`left`) and previous-row pixel
    // (`up_left`) in the i16 representation consumed by the threshold Paeth
    // predictor. This mirrors image-png's scalar kernel shape and removes one
    // output reload plus two u8->i16 extensions per channel from the
    // dependency-heavy loop on every target.
    var left: [bytes_per_pixel]i16 = @splat(0);
    var up_left: [bytes_per_pixel]i16 = @splat(0);
    var i: usize = 0;
    while (i + bytes_per_pixel <= filtered.len) : (i += bytes_per_pixel) {
        inline for (0..bytes_per_pixel) |lane| {
            const up: i16 = previous[i + lane];
            const value = filtered[i + lane] +% pngPaethPredictorStbiI16(left[lane], up, up_left[lane]);
            output[i + lane] = value;
            left[lane] = value;
            up_left[lane] = up;
        }
    }
    while (i < filtered.len) : (i += 1) {
        const lane = i % bytes_per_pixel;
        const up: i16 = previous[i];
        const value = filtered[i] +% pngPaethPredictorStbiI16(left[lane], up, up_left[lane]);
        output[i] = value;
        left[lane] = value;
        up_left[lane] = up;
    }
}

fn reconstructPngSubScanline(filtered: []const u8, bytes_per_pixel: usize, output: []u8) void {
    switch (bytes_per_pixel) {
        1 => return reconstructPngSubBpp1Scanline(filtered, output),
        2 => return reconstructPngSubFixedBppScanline(2, filtered, output),
        3 => return reconstructPngSubBpp3Scanline(filtered, output),
        4 => return reconstructPngSubFixedBppScanline(4, filtered, output),
        6 => return reconstructPngSubFixedBppScanline(6, filtered, output),
        8 => return reconstructPngSubFixedBppScanline(8, filtered, output),
        else => {},
    }
    const prefix = @min(bytes_per_pixel, filtered.len);
    copyPossiblyAliasedBytes(output[0..prefix], filtered[0..prefix]);
    var i: usize = prefix;
    while (i < filtered.len) : (i += 1) output[i] = filtered[i] +% output[i - bytes_per_pixel];
}

fn reconstructPngSubBpp3Scanline(filtered: []const u8, output: []u8) void {
    const prefix = @min(@as(usize, 3), filtered.len);
    copyPossiblyAliasedBytes(output[0..prefix], filtered[0..prefix]);
    if (filtered.len <= 3) return;

    // A 3-lane Zig vector is widened and shuffled inefficiently by the x86
    // backend. Keep the three RGB prefix sums in independent scalar registers
    // instead: each channel remains a serial dependency, while the processor
    // can advance all three channels in parallel without reloading the prior
    // pixel from output.
    var red = output[0];
    var green = output[1];
    var blue = output[2];
    var i: usize = 3;
    while (i + 3 <= filtered.len) : (i += 3) {
        red +%= filtered[i];
        green +%= filtered[i + 1];
        blue +%= filtered[i + 2];
        output[i] = red;
        output[i + 1] = green;
        output[i + 2] = blue;
    }
    if (i < filtered.len) {
        red +%= filtered[i];
        output[i] = red;
        i += 1;
    }
    if (i < filtered.len) {
        green +%= filtered[i];
        output[i] = green;
    }
}

fn reconstructPngSubFixedBppScanline(comptime bytes_per_pixel: usize, filtered: []const u8, output: []u8) void {
    // Keep one prefix-sum accumulator per channel. This removes the hot
    // output[i - bpp] reload used by the generic Sub recurrence and is stable
    // for the common 16-bit grayscale, RGBA, 16-bit RGB, and 16-bit RGBA rows.
    var left: [bytes_per_pixel]u8 = @splat(0);
    var i: usize = 0;
    while (i + bytes_per_pixel <= filtered.len) : (i += bytes_per_pixel) {
        inline for (0..bytes_per_pixel) |channel| {
            left[channel] +%= filtered[i + channel];
            output[i + channel] = left[channel];
        }
    }
    while (i < filtered.len) : (i += 1) {
        const channel = i % bytes_per_pixel;
        left[channel] +%= filtered[i];
        output[i] = left[channel];
    }
}

fn reconstructPngSubBpp1Scanline(filtered: []const u8, output: []u8) void {
    if (filtered.len == 0) return;
    copyPossiblyAliasedBytes(output[0..1], filtered[0..1]);
    var i: usize = 1;
    while (i < filtered.len) : (i += 1) output[i] = filtered[i] +% output[i - 1];
}

fn copyPossiblyAliasedBytes(output: []u8, input: []const u8) void {
    if (input.ptr == output.ptr) return;
    std.mem.copyForwards(u8, output, input);
}

pub fn pngScanlinePayloadLen(row_len: usize, row_count: usize) Error!usize {
    if (row_len == 0 or row_count == 0) return error.CorruptFrame;
    const stride = std.math.add(usize, row_len, 1) catch return error.IntegerOverflow;
    return std.math.mul(usize, stride, row_count) catch return error.IntegerOverflow;
}

pub fn pngImageOutputLen(info: PngImageInfo) Error!usize {
    if (info.row_len == 0 or info.height == 0) return error.CorruptFrame;
    return std.math.mul(usize, info.row_len, info.height) catch return error.IntegerOverflow;
}

fn pngReconstructionRow(comptime row_len: usize, row_index: usize) [row_len]u8 {
    var row: [row_len]u8 = undefined;
    for (&row, 0..) |*byte, i| {
        const value = @as(u32, @intCast(row_index)) * 29 + @as(u32, @intCast(i)) * 17 + @as(u32, @intCast(i / 3)) * 11;
        byte.* = @truncate(value);
    }
    return row;
}

fn filterPngScanlineForTest(filter: u8, row: []const u8, previous: ?[]const u8, bytes_per_pixel: usize, filtered: []u8) void {
    std.debug.assert(filtered.len == row.len);
    for (row, 0..) |pixel, i| {
        const left: u8 = if (i >= bytes_per_pixel) row[i - bytes_per_pixel] else 0;
        const up: u8 = if (previous) |prev| prev[i] else 0;
        const up_left: u8 = if (i >= bytes_per_pixel) blk: {
            if (previous) |prev| break :blk prev[i - bytes_per_pixel];
            break :blk 0;
        } else 0;
        const prediction: u8 = switch (filter) {
            0 => 0,
            1 => left,
            2 => up,
            3 => @intCast((@as(u16, left) + @as(u16, up)) / 2),
            4 => pngPaethPredictor(left, up, up_left),
            else => unreachable,
        };
        filtered[i] = pixel -% prediction;
    }
}

test "png scanline reconstruction filters round trip" {
    const bpp = 3;
    const row_len = 12;
    const row_count = 5;
    var rows: [row_count][row_len]u8 = undefined;
    var filtered_payload: [row_count * (row_len + 1)]u8 = undefined;

    var offset: usize = 0;
    var previous: ?[]const u8 = null;
    for (0..row_count) |row_index| {
        rows[row_index] = pngReconstructionRow(row_len, row_index);
        const filter: u8 = @intCast(row_index);
        filtered_payload[offset] = filter;
        filterPngScanlineForTest(filter, &rows[row_index], previous, bpp, filtered_payload[offset + 1 ..][0..row_len]);
        previous = &rows[row_index];
        offset += row_len + 1;
    }

    var reconstructed: [row_count][row_len]u8 = undefined;
    previous = null;
    offset = 0;
    for (0..row_count) |row_index| {
        const filter = filtered_payload[offset];
        const written = try reconstructPngScanline(filter, filtered_payload[offset + 1 ..][0..row_len], previous, bpp, &reconstructed[row_index]);
        try std.testing.expectEqual(row_len, written);
        try std.testing.expectEqualSlices(u8, &rows[row_index], &reconstructed[row_index]);
        previous = &reconstructed[row_index];
        offset += row_len + 1;
    }

    var short_output: [row_len - 1]u8 = undefined;
    try std.testing.expectError(error.OutputTooSmall, reconstructPngScanline(0, filtered_payload[1..][0..row_len], null, bpp, &short_output));
    try std.testing.expectError(error.CorruptFrame, reconstructPngScanline(5, filtered_payload[1..][0..row_len], null, bpp, &reconstructed[0]));
    try std.testing.expectError(error.CorruptFrame, reconstructPngScanline(0, filtered_payload[1..][0..row_len], null, 0, &reconstructed[0]));
    try std.testing.expectError(error.SizeMismatch, reconstructPngScanline(2, filtered_payload[1..][0..row_len], short_output[0..], bpp, &reconstructed[0]));
}

test "stb Paeth predictor matches PNG reference over the full byte domain" {
    var left: usize = 0;
    while (left < 256) : (left += 1) {
        var up: usize = 0;
        while (up < 256) : (up += 1) {
            var up_left: usize = 0;
            while (up_left < 256) : (up_left += 1) {
                const a: u8 = @intCast(left);
                const b: u8 = @intCast(up);
                const c: u8 = @intCast(up_left);
                try std.testing.expectEqual(
                    pngPaethPredictorReference(a, b, c),
                    pngPaethPredictorStbi(a, b, c),
                );
            }
        }
    }
}

test "png scanline reconstruction Paeth bpp1 supports in-place rows" {
    const row_len = 32;
    const previous = pngReconstructionRow(row_len, 1);
    var row = pngReconstructionRow(row_len, 2);
    var filtered: [row_len]u8 = undefined;

    filterPngScanlineForTest(4, &row, &previous, 1, &filtered);
    var in_place = filtered;
    try std.testing.expectEqual(row_len, try reconstructPngScanline(4, &in_place, &previous, 1, &in_place));
    try std.testing.expectEqualSlices(u8, &row, &in_place);

    // The first Paeth row has no `up` samples, so PNG reduces it to bpp=1 Sub
    // reconstruction. Exercise that branch with aliased input/output as well.
    row = pngReconstructionRow(row_len, 0);
    filterPngScanlineForTest(4, &row, null, 1, &filtered);
    in_place = filtered;
    try std.testing.expectEqual(row_len, try reconstructPngScanline(4, &in_place, null, 1, &in_place));
    try std.testing.expectEqualSlices(u8, &row, &in_place);
}

test "png scanline reconstruction Sub fixed bpp supports in-place rows" {
    inline for (.{ 1, 3, 4, 8 }) |bpp| {
        const row_len = 32;
        var row = pngReconstructionRow(row_len, bpp);
        var filtered: [row_len]u8 = undefined;

        filterPngScanlineForTest(1, &row, null, bpp, &filtered);
        var in_place = filtered;
        try std.testing.expectEqual(row_len, try reconstructPngScanline(1, &in_place, null, bpp, &in_place));
        try std.testing.expectEqualSlices(u8, &row, &in_place);
    }
}

test "png scanline reconstruction Sub bpp3 matches scalar reference" {
    var len: usize = 0;
    while (len <= 257) : (len += 1) {
        var filtered: [257]u8 = undefined;
        for (0..len) |i| {
            filtered[i] = @truncate(i *% 73 +% len *% 19 +% (i >> 2));
        }

        var optimized: [257]u8 = undefined;
        var reference: [257]u8 = undefined;
        for (0..len) |i| {
            const left: u8 = if (i >= 3) reference[i - 3] else 0;
            reference[i] = filtered[i] +% left;
        }
        reconstructPngSubBpp3Scanline(filtered[0..len], optimized[0..len]);
        try std.testing.expectEqualSlices(u8, reference[0..len], optimized[0..len]);

        // Direct row reconstruction permits input/output aliasing. Exercise
        // every possible modulo-three tail while retaining the scalar result.
        var in_place = filtered;
        reconstructPngSubBpp3Scanline(in_place[0..len], in_place[0..len]);
        try std.testing.expectEqualSlices(u8, reference[0..len], in_place[0..len]);
    }
}

test "png scanline reconstruction Paeth fixed bpp supports in-place rows" {
    const row_len = 32;
    inline for (.{ 3, 4, 6, 8 }) |bpp| {
        const previous = pngReconstructionRow(row_len, bpp + 1);
        var row = pngReconstructionRow(row_len, bpp + 2);
        var filtered: [row_len]u8 = undefined;

        filterPngScanlineForTest(4, &row, &previous, bpp, &filtered);
        var in_place = filtered;
        try std.testing.expectEqual(row_len, try reconstructPngScanline(4, &in_place, &previous, bpp, &in_place));
        try std.testing.expectEqualSlices(u8, &row, &in_place);

        // With no previous row, Paeth reduces to Sub using the same byte stride.
        row = pngReconstructionRow(row_len, 0);
        filterPngScanlineForTest(4, &row, null, bpp, &filtered);
        in_place = filtered;
        try std.testing.expectEqual(row_len, try reconstructPngScanline(4, &in_place, null, bpp, &in_place));
        try std.testing.expectEqualSlices(u8, &row, &in_place);
    }
}

test "png scanline reconstruction Average fixed bpp supports in-place and tail rows" {
    inline for (.{ 1, 2, 3, 4, 6, 8 }) |bpp| {
        inline for (.{ 32, 33, 34 }) |base_len| {
            const row_len = base_len + bpp - 3;
            const previous = pngReconstructionRow(row_len, 5 + bpp);
            var row = pngReconstructionRow(row_len, 6 + bpp);
            var filtered: [row_len]u8 = undefined;

            filterPngScanlineForTest(3, &row, &previous, bpp, &filtered);
            var in_place = filtered;
            try std.testing.expectEqual(row_len, try reconstructPngScanline(3, &in_place, &previous, bpp, &in_place));
            try std.testing.expectEqualSlices(u8, &row, &in_place);

            row = pngReconstructionRow(row_len, 0);
            filterPngScanlineForTest(3, &row, null, bpp, &filtered);
            in_place = filtered;
            try std.testing.expectEqual(row_len, try reconstructPngScanline(3, &in_place, null, bpp, &in_place));
            try std.testing.expectEqualSlices(u8, &row, &in_place);
        }
    }
}

test "png scanline reconstruction Average fixed bpp matches scalar reference" {
    var len: usize = 0;
    while (len <= 257) : (len += 1) {
        var filtered: [257]u8 = undefined;
        var previous: [257]u8 = undefined;
        for (0..len) |i| {
            filtered[i] = @truncate(i *% 73 +% len *% 19 +% (i >> 2));
            previous[i] = @truncate(i *% 29 +% len *% 41 +% (i << 1));
        }

        inline for (.{ 1, 2, 3, 4, 6, 8 }) |bpp| {
            var optimized: [257]u8 = undefined;
            var reference: [257]u8 = undefined;
            reconstructPngAverageFixedBppScanline(bpp, filtered[0..len], previous[0..len], optimized[0..len]);
            reconstructPngAverageScanlineReference(filtered[0..len], previous[0..len], bpp, reference[0..len]);
            try std.testing.expectEqualSlices(u8, reference[0..len], optimized[0..len]);

            reconstructPngAverageFixedBppScanline(bpp, filtered[0..len], null, optimized[0..len]);
            reconstructPngAverageScanlineReference(filtered[0..len], null, bpp, reference[0..len]);
            try std.testing.expectEqualSlices(u8, reference[0..len], optimized[0..len]);
        }
    }
}

test "png image info computes scanline metadata" {
    const rgb = try pngImageInfo(17, 5, 8, .truecolor);
    try std.testing.expectEqual(@as(u8, 3), rgb.samples_per_pixel);
    try std.testing.expectEqual(@as(u16, 24), rgb.bits_per_pixel);
    try std.testing.expectEqual(@as(usize, 51), rgb.row_len);
    try std.testing.expectEqual(@as(usize, 3), rgb.bytes_per_pixel);
    try std.testing.expectEqual(@as(usize, 260), rgb.zlib_payload_len);

    const rgba16 = try pngImageInfoFromColorType(2, 3, 16, 6);
    try std.testing.expectEqual(PngColorType.truecolor_alpha, rgba16.color_type);
    try std.testing.expectEqual(@as(u8, 4), rgba16.samples_per_pixel);
    try std.testing.expectEqual(@as(u16, 64), rgba16.bits_per_pixel);
    try std.testing.expectEqual(@as(usize, 16), rgba16.row_len);
    try std.testing.expectEqual(@as(usize, 8), rgba16.bytes_per_pixel);
    try std.testing.expectEqual(@as(usize, 51), rgba16.zlib_payload_len);

    const indexed1 = try pngImageInfo(13, 7, 1, .indexed);
    try std.testing.expectEqual(@as(usize, 2), indexed1.row_len);
    try std.testing.expectEqual(@as(usize, 1), indexed1.bytes_per_pixel);
    try std.testing.expectEqual(@as(usize, 21), indexed1.zlib_payload_len);
    const sizes = try pngZlibDecodeBufferSizes(indexed1);
    try std.testing.expectEqual(indexed1.zlib_payload_len, sizes.zlib_scratch_len);
    try std.testing.expectEqual(indexed1.row_len, sizes.filtered_row_scratch_len);
    try std.testing.expectEqual(indexed1.row_len, sizes.previous_row_scratch_len);
    try std.testing.expectEqual(@as(usize, 14), sizes.image_output_len);

    try std.testing.expectError(error.CorruptFrame, pngImageInfo(0, 1, 8, .truecolor));
    try std.testing.expectError(error.CorruptFrame, pngImageInfo(1, 0, 8, .truecolor));
    try std.testing.expectError(error.CorruptFrame, pngImageInfo(1, 1, 4, .truecolor));
    try std.testing.expectError(error.CorruptFrame, pngImageInfoFromColorType(1, 1, 8, 1));
    try std.testing.expectError(error.IntegerOverflow, pngImageInfo(std.math.maxInt(usize), 1, 16, .truecolor_alpha));
}

test "png adam7 metadata plans passes and buffers" {
    const info = try pngAdam7Info(17, 9, 8, .truecolor);
    try std.testing.expectEqual(@as(usize, 17), info.image.width);
    try std.testing.expectEqual(@as(usize, 9), info.image.height);
    try std.testing.expectEqual(@as(usize, 459), info.image_output_len);
    try std.testing.expectEqual(@as(usize, 51), info.max_pass_row_len);
    try std.testing.expectEqual(@as(usize, 478), info.zlib_payload_len);

    const expected = [_]struct { w: usize, h: usize, row: usize, payload: usize, out: usize }{
        .{ .w = 3, .h = 2, .row = 9, .payload = 20, .out = 18 },
        .{ .w = 2, .h = 2, .row = 6, .payload = 14, .out = 12 },
        .{ .w = 5, .h = 1, .row = 15, .payload = 16, .out = 15 },
        .{ .w = 4, .h = 3, .row = 12, .payload = 39, .out = 36 },
        .{ .w = 9, .h = 2, .row = 27, .payload = 56, .out = 54 },
        .{ .w = 8, .h = 5, .row = 24, .payload = 125, .out = 120 },
        .{ .w = 17, .h = 4, .row = 51, .payload = 208, .out = 204 },
    };
    for (expected, 0..) |case, i| {
        const pass = info.passes[i];
        try std.testing.expectEqual(@as(u8, @intCast(i + 1)), pass.pass_index);
        try std.testing.expectEqual(case.w, pass.width);
        try std.testing.expectEqual(case.h, pass.height);
        try std.testing.expectEqual(case.row, pass.row_len);
        try std.testing.expectEqual(case.payload, pass.zlib_payload_len);
        try std.testing.expectEqual(case.out, pass.reconstructed_len);
        try std.testing.expect(!pass.isEmpty());
    }
    const sizes = pngAdam7DecodeBufferSizes(info);
    try std.testing.expectEqual(info.zlib_payload_len, sizes.zlib_scratch_len);
    try std.testing.expectEqual(info.max_pass_row_len, sizes.filtered_row_scratch_len);
    try std.testing.expectEqual(info.max_pass_row_len, sizes.previous_row_scratch_len);
    try std.testing.expectEqual(info.image_output_len, sizes.image_output_len);

    const tiny = try pngAdam7InfoFromColorType(1, 1, 1, 3);
    try std.testing.expectEqual(@as(usize, 2), tiny.zlib_payload_len);
    try std.testing.expectEqual(@as(usize, 1), tiny.max_pass_row_len);
    try std.testing.expectEqual(@as(usize, 1), tiny.image_output_len);
    try std.testing.expectEqual(@as(usize, 1), tiny.passes[0].width);
    try std.testing.expectEqual(@as(usize, 1), tiny.passes[0].height);
    for (tiny.passes[1..]) |pass| try std.testing.expect(pass.isEmpty());

    try std.testing.expectError(error.CorruptFrame, pngAdam7InfoFromColorType(1, 1, 8, 1));
}

test "png adam7 placement scatters byte-aligned passes" {
    const info = try pngAdam7Info(5, 5, 8, .truecolor);
    var image: [5 * 5 * 3]u8 = @splat(0);
    var expected: [5 * 5 * 3]u8 = @splat(0);

    for (info.passes) |pass| {
        if (pass.isEmpty()) continue;
        var pass_rows: [32]u8 = @splat(0);
        var offset: usize = 0;
        for (0..pass.height) |row_index| {
            for (0..pass.width) |pass_x| {
                const dest_x = pass.x_start + pass_x * pass.x_step;
                const dest_y = pass.y_start + row_index * pass.y_step;
                const base: u8 = @intCast(dest_y * 16 + dest_x);
                pass_rows[offset + 0] = base;
                pass_rows[offset + 1] = base +% 1;
                pass_rows[offset + 2] = base +% 2;
                const dest = (dest_y * info.image.width + dest_x) * 3;
                expected[dest + 0] = pass_rows[offset + 0];
                expected[dest + 1] = pass_rows[offset + 1];
                expected[dest + 2] = pass_rows[offset + 2];
                offset += 3;
            }
        }
        try placePngAdam7Pass(info, pass, pass_rows[0..pass.reconstructed_len], &image);
    }

    try std.testing.expectEqualSlices(u8, &expected, &image);
    try std.testing.expectError(error.OutputTooSmall, placePngAdam7Row(info, info.passes[0], 0, image[0..info.passes[0].row_len], image[0 .. image.len - 1]));
    try std.testing.expectError(error.RangeOutOfBounds, placePngAdam7Row(info, info.passes[0], info.passes[0].height, image[0..info.passes[0].row_len], &image));
    try std.testing.expectError(error.InputTooSmall, placePngAdam7Pass(info, info.passes[0], image[0 .. info.passes[0].reconstructed_len - 1], &image));
}

test "png adam7 placement scatters sub-byte packed pixels" {
    const info = try pngAdam7Info(5, 5, 2, .indexed);
    var image: [10]u8 = @splat(0);
    var expected_pixels: [25]u8 = @splat(0);

    for (info.passes) |pass| {
        if (pass.isEmpty()) continue;
        var pass_rows: [8]u8 = @splat(0);
        for (0..pass.height) |row_index| {
            @memset(pass_rows[row_index * pass.row_len ..][0..pass.row_len], 0);
            for (0..pass.width) |pass_x| {
                const dest_x = pass.x_start + pass_x * pass.x_step;
                const dest_y = pass.y_start + row_index * pass.y_step;
                const value: u8 = @intCast((dest_x + dest_y * 2) & 0x3);
                expected_pixels[dest_y * info.image.width + dest_x] = value;
                writePngPackedPixel(pass_rows[row_index * pass.row_len ..][0..pass.row_len], pass_x, info.image.bits_per_pixel, value);
            }
        }
        try placePngAdam7Pass(info, pass, pass_rows[0..pass.reconstructed_len], &image);
    }

    var expected_image: [10]u8 = @splat(0);
    for (0..info.image.height) |y| {
        const row = expected_image[y * info.image.row_len ..][0..info.image.row_len];
        for (0..info.image.width) |x| {
            writePngPackedPixel(row, x, info.image.bits_per_pixel, expected_pixels[y * info.image.width + x]);
        }
    }
    try std.testing.expectEqualSlices(u8, &expected_image, &image);

    const tiny = try pngAdam7Info(1, 1, 1, .indexed);
    try std.testing.expectError(error.RangeOutOfBounds, placePngAdam7Row(tiny, tiny.passes[1], 0, "", image[0..1]));
}
