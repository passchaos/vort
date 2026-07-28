const std = @import("std");
const core = @import("core.zig");

pub const Error = core.Error || std.mem.Allocator.Error;

pub const default_compression_level: c_int = 1;

const frame_magic = [_]u8{ 0x28, 0xb5, 0x2f, 0xfd };
const frame_magic_u32: u32 = 0xfd2fb528;
const skippable_magic_min: u32 = 0x184d2a50;
const skippable_magic_max: u32 = 0x184d2a5f;
const min_rle_split_len = 12;
const initial_repeated_offsets = [3]usize{ 1, 4, 8 };

const ll_base = [_]usize{
    0,      1,      2,      3,       4,     5,     6,     7,
    8,      9,      10,     11,      12,    13,    14,    15,
    16,     18,     20,     22,      24,    28,    32,    40,
    48,     64,     0x80,   0x100,   0x200, 0x400, 0x800, 0x1000,
    0x2000, 0x4000, 0x8000, 0x10000,
};

const ll_bits = [_]u8{
    0,  0,  0,  0,  0, 0,  0,  0,
    0,  0,  0,  0,  0, 0,  0,  0,
    1,  1,  1,  1,  2, 2,  3,  3,
    4,  6,  7,  8,  9, 10, 11, 12,
    13, 14, 15, 16,
};

const ml_base = [_]usize{
    3,      4,      5,      6,      7,       8,     9,     10,
    11,     12,     13,     14,     15,      16,    17,    18,
    19,     20,     21,     22,     23,      24,    25,    26,
    27,     28,     29,     30,     31,      32,    33,    34,
    35,     37,     39,     41,     43,      47,    51,    59,
    67,     83,     99,     0x83,   0x103,   0x203, 0x403, 0x803,
    0x1003, 0x2003, 0x4003, 0x8003, 0x10003,
};

const ml_bits = [_]u8{
    0,  0,  0,  0,  0,  0, 0,  0,
    0,  0,  0,  0,  0,  0, 0,  0,
    0,  0,  0,  0,  0,  0, 0,  0,
    0,  0,  0,  0,  0,  0, 0,  0,
    1,  1,  1,  1,  2,  2, 3,  3,
    4,  4,  5,  7,  8,  9, 10, 11,
    12, 13, 14, 15, 16,
};

const of_base = [_]usize{
    0,        1,         1,         5,         0xD,       0x1D,       0x3D,       0x7D,
    0xFD,     0x1FD,     0x3FD,     0x7FD,     0xFFD,     0x1FFD,     0x3FFD,     0x7FFD,
    0xFFFD,   0x1FFFD,   0x3FFFD,   0x7FFFD,   0xFFFFD,   0x1FFFFD,   0x3FFFFD,   0x7FFFFD,
    0xFFFFFD, 0x1FFFFFD, 0x3FFFFFD, 0x7FFFFFD, 0xFFFFFFD, 0x1FFFFFFD, 0x3FFFFFFD, 0x7FFFFFFD,
};

const of_bits = [_]u8{
    0,  1,  2,  3,  4,  5,  6,  7,
    8,  9,  10, 11, 12, 13, 14, 15,
    16, 17, 18, 19, 20, 21, 22, 23,
    24, 25, 26, 27, 28, 29, 30, 31,
};

extern fn ZSTD_compressBound(srcSize: usize) usize;
extern fn ZSTD_compress(dst: *anyopaque, dstCapacity: usize, src: *const anyopaque, srcSize: usize, compressionLevel: c_int) usize;
extern fn ZSTD_createCCtx() ?*anyopaque;
extern fn ZSTD_freeCCtx(cctx: ?*anyopaque) usize;
extern fn ZSTD_CCtx_setParameter(cctx: *anyopaque, param: c_int, value: c_int) usize;
extern fn ZSTD_compress2(cctx: *anyopaque, dst: *anyopaque, dstCapacity: usize, src: *const anyopaque, srcSize: usize) usize;
extern fn ZSTD_getFrameContentSize(src: *const anyopaque, srcSize: usize) c_ulonglong;
extern fn ZSTD_decompressBound(src: *const anyopaque, srcSize: usize) c_ulonglong;
extern fn ZSTD_decompress(dst: *anyopaque, dstCapacity: usize, src: *const anyopaque, compressedSize: usize) usize;
extern fn ZSTD_isError(code: usize) c_uint;

const zstd_content_size_unknown = std.math.maxInt(c_ulonglong);
const zstd_content_size_error = std.math.maxInt(c_ulonglong) - 1;
const zstd_c_compression_level: c_int = 100;
const zstd_c_content_size_flag: c_int = 200;
const zstd_c_checksum_flag: c_int = 201;
const StdZstdLiteralsSection = std.compress.zstd.Decompress.LiteralsSection;
const StdZstdHuffmanTree = StdZstdLiteralsSection.HuffmanTree;

pub const LibFrameOptions = struct {
    include_content_size: bool = true,
    content_checksum: bool = false,
};

pub const NativeFrameSelection = enum {
    auto,
    raw_or_rle,
    literal_only,
};

pub const NativeFrameOptions = struct {
    content_checksum: bool = true,
    include_content_size: bool = true,
    selection: NativeFrameSelection = .auto,
};

pub const NativeFrameMode = enum {
    raw_or_rle,
    literal_only,
};

pub const NativeFrameEncodeResult = struct {
    frame: []u8,
    mode: NativeFrameMode,
};

/// Decode a Zstandard frame. Prefer libzstd's one-shot decoder because MCAP and
/// similar containers often know the decoded chunk size out-of-band and because
/// the one-shot path avoids Zig streaming allocator overhead. When the frame
/// omits its content size, use libzstd's conservative decompressed bound before
/// falling back to Zig std's streaming decoder for frames that cannot be bounded
/// by the linked library.
pub fn decodeFrameAlloc(allocator: std.mem.Allocator, frame: []const u8) Error![]u8 {
    return try decodeFrameAllocWithLimit(allocator, frame, null);
}

pub fn decodeFrameAllocLimited(allocator: std.mem.Allocator, frame: []const u8, max_output_len: usize) Error![]u8 {
    return try decodeFrameAllocWithLimit(allocator, frame, max_output_len);
}

pub fn decodeFrameInto(frame: []const u8, output: []u8) Error!usize {
    const content_size = ZSTD_getFrameContentSize(@ptrCast(frame.ptr), frame.len);
    if (content_size == zstd_content_size_error) return error.CorruptFrame;
    if (content_size != zstd_content_size_unknown) {
        const decoded_len = try checkedU64ToUsize(content_size);
        if (output.len < decoded_len) return error.OutputTooSmall;
        const written = ZSTD_decompress(@ptrCast(output.ptr), output.len, @ptrCast(frame.ptr), frame.len);
        if (ZSTD_isError(written) != 0) return error.CorruptFrame;
        if (written != decoded_len) return error.SizeMismatch;
        return written;
    }

    const bound = ZSTD_decompressBound(@ptrCast(frame.ptr), frame.len);
    if (bound == zstd_content_size_error) return error.UnsupportedZstdFeature;
    const capacity = try checkedU64ToUsize(bound);
    const written = ZSTD_decompress(@ptrCast(output.ptr), output.len, @ptrCast(frame.ptr), frame.len);
    if (ZSTD_isError(written) != 0) {
        // The bound is intentionally conservative when the frame omits content
        // size. A caller buffer smaller than the bound might still be large
        // enough, so only classify an actual libzstd failure as OutputTooSmall
        // when the advertised upper bound proves the buffer was not generous.
        if (output.len < capacity) return error.OutputTooSmall;
        return error.CorruptFrame;
    }
    if (written > output.len) return error.OutputTooSmall;
    return written;
}

pub fn decodedFrameSize(frame: []const u8) Error!usize {
    return try decodedFrameSizeLimited(frame, std.math.maxInt(usize));
}

pub fn decodedFrameSizeLimited(frame: []const u8, max_output_len: usize) Error!usize {
    const content_size = ZSTD_getFrameContentSize(@ptrCast(frame.ptr), frame.len);
    if (content_size == zstd_content_size_error) return error.CorruptFrame;
    const decoded_len = if (content_size != zstd_content_size_unknown)
        try checkedU64ToUsize(content_size)
    else blk: {
        const bound = ZSTD_decompressBound(@ptrCast(frame.ptr), frame.len);
        if (bound == zstd_content_size_error) return error.UnsupportedZstdFeature;
        break :blk try checkedU64ToUsize(bound);
    };
    if (decoded_len > max_output_len) return error.OutputLimitExceeded;
    return decoded_len;
}

fn decodeFrameAllocWithLimit(allocator: std.mem.Allocator, frame: []const u8, max_output_len: ?usize) Error![]u8 {
    const content_size = ZSTD_getFrameContentSize(@ptrCast(frame.ptr), frame.len);
    if (content_size == zstd_content_size_error) return error.CorruptFrame;
    if (content_size != zstd_content_size_unknown) {
        const decoded_len = try checkedU64ToUsize(content_size);
        if (max_output_len) |limit| {
            if (decoded_len > limit) return error.OutputLimitExceeded;
        }
        const out = try allocator.alloc(u8, decoded_len);
        errdefer allocator.free(out);
        const written = ZSTD_decompress(@ptrCast(out.ptr), out.len, @ptrCast(frame.ptr), frame.len);
        if (ZSTD_isError(written) != 0) return error.CorruptFrame;
        if (written != decoded_len) return error.SizeMismatch;
        return out;
    }

    const bound = ZSTD_decompressBound(@ptrCast(frame.ptr), frame.len);
    if (bound != zstd_content_size_error) {
        const bound_capacity = try checkedU64ToUsize(bound);
        const capacity = if (max_output_len) |limit| @min(bound_capacity, limit) else bound_capacity;
        if (max_output_len) |limit| {
            if (capacity > limit) return error.OutputLimitExceeded;
        }
        const out = try allocator.alloc(u8, capacity);
        errdefer allocator.free(out);
        const written = ZSTD_decompress(@ptrCast(out.ptr), out.len, @ptrCast(frame.ptr), frame.len);
        if (ZSTD_isError(written) != 0) {
            if (max_output_len != null and bound_capacity > capacity) return error.OutputLimitExceeded;
            return error.CorruptFrame;
        }
        if (max_output_len) |limit| {
            if (written > limit) return error.OutputLimitExceeded;
        }
        if (allocator.remap(out, written)) |shrunk| return shrunk;
        const exact = try allocator.dupe(u8, out[0..written]);
        allocator.free(out);
        return exact;
    }

    if (max_output_len) |limit| {
        const native = decodeRawOrRleFrameAllocLimited(allocator, frame, limit) catch |err| switch (err) {
            error.UnsupportedZstdFeature => null,
            else => return err,
        };
        if (native) |decoded| return decoded;
    }

    var input: std.Io.Reader = .fixed(frame);
    var zstd_stream: std.compress.zstd.Decompress = .init(&input, &.{}, .{});
    var output: std.Io.Writer.Allocating = .init(allocator);
    errdefer output.deinit();
    _ = zstd_stream.reader.streamRemaining(&output.writer) catch return error.CorruptFrame;
    if (zstd_stream.err) |_| return error.CorruptFrame;
    const decoded = output.toOwnedSlice() catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
    };
    errdefer allocator.free(decoded);
    if (max_output_len) |limit| {
        if (decoded.len > limit) return error.OutputLimitExceeded;
    }
    return decoded;
}

/// Dependency-free Zstandard decoder for the raw/RLE frame subset emitted by
/// `encodeRawOrRleFrameAlloc`, plus the growing native compressed-block subset
/// used by compatibility smoke tests. It accepts concatenated supported frames
/// and skippable frames, validates frame content sizes and optional content
/// checksums, and deliberately rejects unsupported sequence/FSE payloads instead
/// of silently falling back to a partial implementation.
pub fn decodeRawOrRleFrameAlloc(allocator: std.mem.Allocator, frame: []const u8) Error![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);

    var offset: usize = 0;
    while (offset < frame.len) {
        if (frame.len - offset < 4) return error.TruncatedFrame;
        const magic = std.mem.readInt(u32, frame[offset..][0..4], .little);
        offset += 4;
        if (magic == frame_magic_u32) {
            try decodeRawOrRleZstandardFrameInto(allocator, &out, frame, &offset);
        } else if (magic >= skippable_magic_min and magic <= skippable_magic_max) {
            if (frame.len - offset < 4) return error.TruncatedFrame;
            const skip_len: usize = @intCast(std.mem.readInt(u32, frame[offset..][0..4], .little));
            offset += 4;
            if (frame.len - offset < skip_len) return error.TruncatedFrame;
            offset += skip_len;
        } else {
            return error.InvalidMagic;
        }
    }

    return out.toOwnedSlice(allocator);
}

pub fn decodeRawOrRleFrameAllocLimited(
    allocator: std.mem.Allocator,
    frame: []const u8,
    max_output_len: usize,
) Error![]u8 {
    const decoded_len = try rawOrRleDecodedSizeLimited(frame, max_output_len);
    const out = try allocator.alloc(u8, decoded_len);
    errdefer allocator.free(out);
    const written = decodeRawOrRleFrameInto(frame, out) catch |err| switch (err) {
        error.OutputTooSmall => return error.OutputLimitExceeded,
        else => return err,
    };
    if (written != decoded_len) return error.SizeMismatch;
    return out;
}

pub fn decodedRawOrRleFrameSize(frame: []const u8) Error!usize {
    return try rawOrRleDecodedSizeLimited(frame, std.math.maxInt(usize));
}

/// Decode the raw/RLE Zstandard subset directly into caller-owned storage.
/// The returned length is the number of bytes written across all concatenated
/// non-skippable frames. This mirrors the allocator-returning fallback but lets
/// embedded/streaming callers preflight capacity and stay allocation-free while
/// still receiving exact checksum, size, and unsupported-feature errors.
pub fn decodeRawOrRleFrameInto(frame: []const u8, output: []u8) Error!usize {
    var offset: usize = 0;
    var written: usize = 0;
    while (offset < frame.len) {
        if (frame.len - offset < 4) return error.TruncatedFrame;
        const magic = std.mem.readInt(u32, frame[offset..][0..4], .little);
        offset += 4;
        if (magic == frame_magic_u32) {
            try decodeRawOrRleZstandardFrameIntoBuffer(frame, &offset, output, &written);
        } else if (magic >= skippable_magic_min and magic <= skippable_magic_max) {
            if (frame.len - offset < 4) return error.TruncatedFrame;
            const skip_len: usize = @intCast(std.mem.readInt(u32, frame[offset..][0..4], .little));
            offset += 4;
            if (frame.len - offset < skip_len) return error.TruncatedFrame;
            offset += skip_len;
        } else {
            return error.InvalidMagic;
        }
    }
    return written;
}

pub const decodeNativeFrameAlloc = decodeRawOrRleFrameAlloc;
pub const decodeNativeFrameAllocLimited = decodeRawOrRleFrameAllocLimited;
pub const decodeNativeFrameInto = decodeRawOrRleFrameInto;

/// Compress a complete Zstandard frame using the reference-compatible libzstd
/// encoder linked by Vort's build. Keeping this call surface in Vort centralizes
/// compression ownership for downstream formats such as MCAP while leaving room
/// to replace the backend with a pure Zig implementation ported from
/// `~/Work/zstd` internals later.
pub fn encodeFrameAlloc(allocator: std.mem.Allocator, input: []const u8) Error![]u8 {
    return try encodeFrameWithLevelAlloc(allocator, input, default_compression_level);
}

pub fn encodeFrameWithLevelAlloc(allocator: std.mem.Allocator, input: []const u8, level: c_int) Error![]u8 {
    return try encodeFrameWithLevelAndOptionsAlloc(allocator, input, level, .{});
}

pub fn encodeFrameWithOptionsAlloc(allocator: std.mem.Allocator, input: []const u8, options: LibFrameOptions) Error![]u8 {
    return try encodeFrameWithLevelAndOptionsAlloc(allocator, input, default_compression_level, options);
}

pub fn encodeFrameWithLevelAndOptionsAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    level: c_int,
    options: LibFrameOptions,
) Error![]u8 {
    const bound = ZSTD_compressBound(input.len);
    if (ZSTD_isError(bound) != 0) return error.CorruptFrame;
    var out = try allocator.alloc(u8, bound);
    errdefer allocator.free(out);

    const cctx = ZSTD_createCCtx() orelse return error.OutOfMemory;
    defer _ = ZSTD_freeCCtx(cctx);

    // Use the advanced one-shot API only when callers need frame policy
    // control. The default options preserve the historical ZSTD_compress()
    // behavior while allowing downstream containers such as MCAP to avoid
    // duplicating metadata they already carry at the format layer.
    if (ZSTD_isError(ZSTD_CCtx_setParameter(cctx, zstd_c_compression_level, level)) != 0) return error.CorruptFrame;
    if (ZSTD_isError(ZSTD_CCtx_setParameter(cctx, zstd_c_content_size_flag, if (options.include_content_size) 1 else 0)) != 0) return error.CorruptFrame;
    if (ZSTD_isError(ZSTD_CCtx_setParameter(cctx, zstd_c_checksum_flag, if (options.content_checksum) 1 else 0)) != 0) return error.CorruptFrame;

    const written = ZSTD_compress2(cctx, @ptrCast(out.ptr), out.len, @ptrCast(input.ptr), input.len);
    if (ZSTD_isError(written) != 0) return error.CorruptFrame;
    if (allocator.remap(out, written)) |shrunk| return shrunk;
    const exact = try allocator.dupe(u8, out[0..written]);
    allocator.free(out);
    return exact;
}

/// Emit a valid Zstandard frame composed of raw and RLE blocks.
///
/// This dependency-free fallback remains useful for bootstrapping and for tiny
/// repeated-byte payloads. General-purpose MCAP chunk writing uses
/// `encodeFrameAlloc()` so it benefits from the full zstd entropy encoder.
pub fn encodeRawOrRleFrameAlloc(allocator: std.mem.Allocator, input: []const u8) Error![]u8 {
    return try encodeRawOrRleFrameWithOptionsAlloc(allocator, input, .{});
}

pub fn encodeRawOrRleFrameWithOptionsAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: NativeFrameOptions,
) Error![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try emitFrameHeader(allocator, &out, try checkedUsizeToU64(input.len), options);
    if (input.len == 0) {
        try emitBlock(allocator, &out, "", true);
    } else {
        var offset: usize = 0;
        while (offset < input.len) {
            const search_end = @min(input.len, offset + std.compress.zstd.block_size_max);
            if (findRleRun(input[offset..search_end])) |run| {
                const run_start = offset + run.start;
                if (run_start > offset) try emitBlock(allocator, &out, input[offset..run_start], false);
                const run_end = run_start + run.len;
                try emitRleBlock(allocator, &out, input[run_start], run.len, run_end == input.len);
                offset = run_end;
            } else {
                try emitBlock(allocator, &out, input[offset..search_end], search_end == input.len);
                offset = search_end;
            }
        }
    }
    try emitContentChecksum(allocator, &out, input, options);
    return out.toOwnedSlice(allocator);
}

pub fn encodeLiteralOnlyFrameAlloc(allocator: std.mem.Allocator, input: []const u8) Error![]u8 {
    return try encodeLiteralOnlyFrameWithOptionsAlloc(allocator, input, .{});
}

pub fn encodeLiteralOnlyFrameWithOptionsAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: NativeFrameOptions,
) Error![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try emitFrameHeader(allocator, &out, try checkedUsizeToU64(input.len), options);

    var offset: usize = 0;
    if (input.len == 0) {
        try emitLiteralOnlyCompressedBlock(allocator, &out, "", true);
    } else {
        while (offset < input.len) {
            const block_end = @min(input.len, offset + std.compress.zstd.block_size_max);
            try emitLiteralOnlyCompressedBlock(allocator, &out, input[offset..block_end], block_end == input.len);
            offset = block_end;
        }
    }

    try emitContentChecksum(allocator, &out, input, options);
    return out.toOwnedSlice(allocator);
}

pub fn encodeSkippableFrameAlloc(allocator: std.mem.Allocator, skippable_id: u4, payload: []const u8) Error![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    var header: [8]u8 = undefined;
    std.mem.writeInt(u32, header[0..4], skippable_magic_min + @as(u32, skippable_id), .little);
    std.mem.writeInt(u32, header[4..8], try checkedUsizeToU32(payload.len), .little);
    try out.appendSlice(allocator, &header);
    try out.appendSlice(allocator, payload);
    return out.toOwnedSlice(allocator);
}

pub fn encodeNativeFrameAlloc(allocator: std.mem.Allocator, input: []const u8) Error![]u8 {
    const result = try encodeNativeFrameWithOptionsAlloc(allocator, input, .{});
    return result.frame;
}

pub fn encodeNativeFrameWithOptionsAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: NativeFrameOptions,
) Error!NativeFrameEncodeResult {
    switch (options.selection) {
        .raw_or_rle => return .{
            .frame = try encodeRawOrRleFrameWithOptionsAlloc(allocator, input, options),
            .mode = .raw_or_rle,
        },
        .literal_only => return .{
            .frame = try encodeLiteralOnlyFrameWithOptionsAlloc(allocator, input, options),
            .mode = .literal_only,
        },
        .auto => {},
    }

    const raw_or_rle = try encodeRawOrRleFrameWithOptionsAlloc(allocator, input, options);
    errdefer allocator.free(raw_or_rle);
    const literal_only = try encodeLiteralOnlyFrameWithOptionsAlloc(allocator, input, options);
    errdefer allocator.free(literal_only);

    // Keep this selector deliberately simple and deterministic while the native
    // Zstd implementation is still a bootstrap subset. It lets callers use one
    // native API and still benefit if a future literal-only compressed mode beats
    // raw/RLE framing, without hiding which mode was selected from tests/reports.
    if (literal_only.len < raw_or_rle.len) {
        allocator.free(raw_or_rle);
        return .{ .frame = literal_only, .mode = .literal_only };
    }

    allocator.free(literal_only);
    return .{ .frame = raw_or_rle, .mode = .raw_or_rle };
}

fn emitFrameHeader(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    content_len: u64,
    options: NativeFrameOptions,
) Error!void {
    try out.appendSlice(allocator, &frame_magic);

    if (!options.include_content_size) {
        try out.append(allocator, if (options.content_checksum) 0x04 else 0x00);
        try emitWindowDescriptor(allocator, out, content_len);
        return;
    }

    // Use the shortest single-segment Frame_Content_Size encoding permitted by
    // the Zstandard format. The previous bootstrap writer always spent eight
    // bytes here, which was easy to inspect but disproportionately expensive
    // for the tiny raw/RLE frames this dependency-free path is meant to cover.
    const checksum_flag: u8 = if (options.content_checksum) 0x04 else 0;
    if (content_len <= 255) {
        try out.append(allocator, 0x20 | checksum_flag); // fcs=1 byte, single segment
        try out.append(allocator, @intCast(content_len));
    } else if (content_len <= 256 + std.math.maxInt(u16)) {
        try out.append(allocator, 0x60 | checksum_flag); // fcs=2 bytes (+256), single segment
        var size_bytes: [2]u8 = undefined;
        std.mem.writeInt(u16, &size_bytes, @intCast(content_len - 256), .little);
        try out.appendSlice(allocator, &size_bytes);
    } else if (content_len <= std.math.maxInt(u32)) {
        try out.append(allocator, 0xa0 | checksum_flag); // fcs=4 bytes, single segment
        var size_bytes: [4]u8 = undefined;
        std.mem.writeInt(u32, &size_bytes, @intCast(content_len), .little);
        try out.appendSlice(allocator, &size_bytes);
    } else {
        try out.append(allocator, 0xe0 | checksum_flag); // fcs=8 bytes, single segment
        var size_bytes: [8]u8 = undefined;
        std.mem.writeInt(u64, &size_bytes, content_len, .little);
        try out.appendSlice(allocator, &size_bytes);
    }
}

fn emitWindowDescriptor(allocator: std.mem.Allocator, out: *std.ArrayList(u8), content_len: u64) Error!void {
    const window_size = @max(content_len, @as(u64, 1) << 10);
    var exponent: u8 = 0;
    while (exponent < 31) : (exponent += 1) {
        const base = @as(u64, 1) << @intCast(10 + exponent);
        const step = base / 8;
        if (window_size <= base + step * 7) {
            const delta = window_size - base;
            const mantissa: u8 = @intCast((delta + step - 1) / step);
            try out.append(allocator, (exponent << 3) | mantissa);
            return;
        }
    }
    return error.IntegerOverflow;
}

fn emitContentChecksum(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    input: []const u8,
    options: NativeFrameOptions,
) Error!void {
    if (!options.content_checksum) return;
    var checksum: [4]u8 = undefined;
    std.mem.writeInt(u32, &checksum, @truncate(std.hash.XxHash64.hash(0, input)), .little);
    try out.appendSlice(allocator, &checksum);
}

const RawOrRleFrameHeader = struct {
    content_size: ?u64,
    has_checksum: bool,
    block_size_max: usize,
};

fn validateBlockSize(header: RawOrRleFrameHeader, block_type: u32, block_len: usize) Error!void {
    // For raw/RLE blocks the header size is the regenerated byte count and must
    // fit the frame block limit directly. For compressed blocks it is the
    // compressed payload length; the literal-only decoder validates the
    // regenerated size after parsing the literals section.
    if (block_type == 2) {
        if (block_len > std.compress.zstd.block_size_max) return error.CorruptFrame;
    } else if (block_len > header.block_size_max) {
        return error.CorruptFrame;
    }
}

fn decodeRawOrRleZstandardFrameInto(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    frame: []const u8,
    offset: *usize,
) Error!void {
    const header = try parseRawOrRleFrameHeader(frame, offset);
    const frame_out_start = out.items.len;
    if (header.content_size) |size| try out.ensureUnusedCapacity(allocator, try checkedU64ToUsize(size));
    var frame_state: SequenceFrameState = .{};

    while (true) {
        if (frame.len - offset.* < 3) return error.TruncatedFrame;
        const block_header = std.mem.readInt(u24, frame[offset.*..][0..3], .little);
        offset.* += 3;
        const last = (block_header & 0x1) != 0;
        const block_type = (block_header >> 1) & 0x3;
        const block_len: usize = @intCast(block_header >> 3);
        try validateBlockSize(header, block_type, block_len);

        switch (block_type) {
            0 => {
                if (frame.len - offset.* < block_len) return error.TruncatedFrame;
                try out.appendSlice(allocator, frame[offset.*..][0..block_len]);
                offset.* += block_len;
            },
            1 => {
                if (block_len == 0) return error.CorruptFrame;
                if (frame.len - offset.* < 1) return error.TruncatedFrame;
                const byte = frame[offset.*];
                offset.* += 1;
                try out.appendNTimes(allocator, byte, block_len);
            },
            2 => {
                if (frame.len - offset.* < block_len) return error.TruncatedFrame;
                try decodeLiteralOnlyCompressedBlockInto(allocator, out, frame[offset.*..][0..block_len], header.block_size_max, frame_out_start, &frame_state);
                offset.* += block_len;
            },
            else => return error.CorruptFrame,
        }

        if (last) break;
    }

    const decoded = out.items[frame_out_start..];
    if (header.content_size) |size| {
        if (try checkedUsizeToU64(decoded.len) != size) return error.SizeMismatch;
    }

    if (header.has_checksum) {
        if (frame.len - offset.* < 4) return error.TruncatedFrame;
        const expected = std.mem.readInt(u32, frame[offset.*..][0..4], .little);
        const actual: u32 = @truncate(std.hash.XxHash64.hash(0, decoded));
        if (actual != expected) return error.ChecksumMismatch;
        offset.* += 4;
    }
}

fn decodeRawOrRleZstandardFrameIntoBuffer(
    frame: []const u8,
    offset: *usize,
    output: []u8,
    written: *usize,
) Error!void {
    const header = try parseRawOrRleFrameHeader(frame, offset);
    const frame_out_start = written.*;
    if (header.content_size) |size| {
        const needed = try checkedU64ToUsize(size);
        if (output.len - written.* < needed) return error.OutputTooSmall;
    }
    var frame_state: SequenceFrameState = .{};

    while (true) {
        if (frame.len - offset.* < 3) return error.TruncatedFrame;
        const block_header = std.mem.readInt(u24, frame[offset.*..][0..3], .little);
        offset.* += 3;
        const last = (block_header & 0x1) != 0;
        const block_type = (block_header >> 1) & 0x3;
        const block_len: usize = @intCast(block_header >> 3);
        try validateBlockSize(header, block_type, block_len);

        switch (block_type) {
            0 => {
                if (frame.len - offset.* < block_len) return error.TruncatedFrame;
                if (output.len - written.* < block_len) return error.OutputTooSmall;
                @memcpy(output[written.*..][0..block_len], frame[offset.*..][0..block_len]);
                written.* += block_len;
                offset.* += block_len;
            },
            1 => {
                if (block_len == 0) return error.CorruptFrame;
                if (frame.len - offset.* < 1) return error.TruncatedFrame;
                if (output.len - written.* < block_len) return error.OutputTooSmall;
                const byte = frame[offset.*];
                offset.* += 1;
                @memset(output[written.*..][0..block_len], byte);
                written.* += block_len;
            },
            2 => {
                if (frame.len - offset.* < block_len) return error.TruncatedFrame;
                try decodeLiteralOnlyCompressedBlockIntoBuffer(frame[offset.*..][0..block_len], output, written, header.block_size_max, frame_out_start, &frame_state);
                offset.* += block_len;
            },
            else => return error.CorruptFrame,
        }

        if (last) break;
    }

    const decoded = output[frame_out_start..written.*];
    if (header.content_size) |size| {
        if (try checkedUsizeToU64(decoded.len) != size) return error.SizeMismatch;
    }

    if (header.has_checksum) {
        if (frame.len - offset.* < 4) return error.TruncatedFrame;
        const expected = std.mem.readInt(u32, frame[offset.*..][0..4], .little);
        const actual: u32 = @truncate(std.hash.XxHash64.hash(0, decoded));
        if (actual != expected) return error.ChecksumMismatch;
        offset.* += 4;
    }
}

fn decodeLiteralOnlyCompressedBlockInto(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    block: []const u8,
    block_size_max: usize,
    frame_output_start: usize,
    frame_state: *SequenceFrameState,
) Error!void {
    const start = out.items.len;
    // Size preflight and decode both advance sequence-table and repeat-offset
    // state. Use a scratch copy for the preflight so the real state is advanced
    // exactly once by the decode path below.
    var preflight_state = frame_state.*;
    if (frame_output_start > out.items.len) return error.CorruptFrame;
    const frame_decoded_before_block = out.items.len - frame_output_start;
    const decoded_len = try compressedLiteralOnlyBlockDecodedSize(block, block_size_max, frame_decoded_before_block, &preflight_state);
    try out.ensureUnusedCapacity(allocator, decoded_len);
    var written = out.items.len;
    try decodeLiteralOnlyCompressedBlockIntoBuffer(block, out.items.ptr[0..out.capacity], &written, block_size_max, frame_output_start, frame_state);
    out.items.len = written;
    if (out.items.len - start != decoded_len) return error.SizeMismatch;
}

fn decodeLiteralOnlyCompressedBlockIntoBuffer(
    block: []const u8,
    output: []u8,
    written: *usize,
    block_size_max: usize,
    frame_output_start: usize,
    frame_state: *SequenceFrameState,
) Error!void {
    const section = try parseLiteralsSection(block, frame_state);
    if (section.regenerated_size > block_size_max) return error.CorruptFrame;
    try validateSupportedLiteralSection(section);
    if (section.sequence_count != 0) return try decodeRleSequencesCompressedBlockIntoBuffer(block, section, output, written, frame_output_start, frame_state);
    if (section.sequence_payload_offset != block.len) return error.UnsupportedZstdFeature;
    try copyLiteralsFromSection(block, section, 0, output, written, section.regenerated_size);
}

fn copyLiteralsFromSection(
    block: []const u8,
    section: LiteralOnlySection,
    literal_offset: usize,
    output: []u8,
    written: *usize,
    literal_len: usize,
) Error!void {
    if (literal_offset > section.regenerated_size or section.regenerated_size - literal_offset < literal_len) {
        return error.CorruptFrame;
    }
    if (literal_len == 0) {
        if (section.kind == .compressed and literal_offset == section.regenerated_size) {
            if (written.* > output.len) return error.OutputTooSmall;
            try copyHuffmanLiteralsFromSection(block, section, literal_offset, output[written.*..][0..0]);
        }
        return;
    }
    if (output.len - written.* < literal_len) return error.OutputTooSmall;
    switch (section.kind) {
        .raw => {
            @memcpy(
                output[written.*..][0..literal_len],
                block[section.literal_payload_offset + literal_offset ..][0..literal_len],
            );
        },
        .rle => {
            if (section.regenerated_size == 0) return error.CorruptFrame;
            @memset(output[written.*..][0..literal_len], block[section.literal_payload_offset]);
        },
        .compressed => try copyHuffmanLiteralsFromSection(
            block,
            section,
            literal_offset,
            output[written.*..][0..literal_len],
        ),
        .treeless => return error.UnsupportedZstdFeature,
    }
    written.* += literal_len;
}

fn copyHuffmanLiteralsFromSection(
    block: []const u8,
    section: LiteralOnlySection,
    literal_offset: usize,
    dest: []u8,
) Error!void {
    if (section.size_format != 0) return error.UnsupportedZstdFeature;
    const huffman_tree = section.huffman_tree orelse return error.CorruptFrame;
    const stream_end = std.math.add(usize, section.literal_payload_offset, section.compressed_size) catch return error.IntegerOverflow;
    if (section.huffman_stream_offset > stream_end or stream_end > block.len) return error.CorruptFrame;

    // Literal copies are requested in sequence order, but the current minimal
    // slice keeps no per-section cursor so preflight and decode can share the
    // same immutable `LiteralOnlySection`. Re-reading from the start is slower
    // for many small literal runs, yet it preserves exact behavior while this
    // native Zstd path is still correctness-first and sequence/FSE support is
    // incomplete.
    var reader = try ReverseBitReader.init(block[section.huffman_stream_offset..stream_end]);
    const end = std.math.add(usize, literal_offset, dest.len) catch return error.IntegerOverflow;
    var decoded_index: usize = 0;
    var output_index: usize = 0;
    while (decoded_index < end) : (decoded_index += 1) {
        const symbol = try readHuffmanLiteralSymbol(&reader, huffman_tree);
        if (decoded_index >= literal_offset) {
            dest[output_index] = symbol;
            output_index += 1;
        }
    }
    if (end == section.regenerated_size) try reader.expectEnd();
}

fn readHuffmanLiteralSymbol(reader: *ReverseBitReader, huffman_tree: StdZstdHuffmanTree) Error!u8 {
    const max_bit_count = huffman_tree.max_bit_count;
    const starting_bit_count = StdZstdHuffmanTree.weightToBitCount(
        huffman_tree.nodes[huffman_tree.symbol_count_minus_one].weight,
        max_bit_count,
    );
    var bits_read: u4 = 0;
    var huffman_tree_index: usize = huffman_tree.symbol_count_minus_one;
    var bit_count_to_read = starting_bit_count;
    var prefix: u16 = 0;
    while (true) {
        const new_bits = reader.read(bit_count_to_read) catch |err| switch (err) {
            error.TruncatedFrame => return error.CorruptFrame,
            else => |e| return e,
        };
        prefix <<= bit_count_to_read;
        prefix |= @intCast(new_bits);
        bits_read += bit_count_to_read;
        const result = huffman_tree.query(huffman_tree_index, prefix) catch return error.CorruptFrame;

        switch (result) {
            .symbol => |symbol| return symbol,
            .index => |index| {
                huffman_tree_index = index;
                const bit_count = StdZstdHuffmanTree.weightToBitCount(
                    huffman_tree.nodes[index].weight,
                    max_bit_count,
                );
                if (bit_count <= bits_read) return error.CorruptFrame;
                bit_count_to_read = bit_count - bits_read;
            },
        }
    }
}

fn compressedLiteralOnlyBlockDecodedSize(
    block: []const u8,
    block_size_max: usize,
    initial_output_len: usize,
    frame_state: *SequenceFrameState,
) Error!usize {
    const section = try parseLiteralsSection(block, frame_state);
    if (section.regenerated_size > block_size_max) return error.CorruptFrame;
    try validateSupportedLiteralSection(section);
    if (section.sequence_count == 0) {
        if (section.sequence_payload_offset != block.len) return error.UnsupportedZstdFeature;
        return section.regenerated_size;
    }
    return try rleSequencesCompressedBlockDecodedSize(block, section, initial_output_len, frame_state);
}

fn validateSupportedLiteralSection(section: LiteralOnlySection) Error!void {
    switch (section.kind) {
        .raw, .rle => {},
        .compressed => {
            if (section.size_format != 0) return error.UnsupportedZstdFeature;
            if (section.huffman_tree == null) return error.CorruptFrame;
        },
        .treeless => return error.UnsupportedZstdFeature,
    }
}

fn compressedLiteralOnlyBlockDecodedSizeLimited(
    block: []const u8,
    total: usize,
    frame_start: usize,
    max_output_len: usize,
    block_size_max: usize,
    frame_state: *SequenceFrameState,
) Error!usize {
    if (frame_start > total) return error.CorruptFrame;
    const decoded_len = try compressedLiteralOnlyBlockDecodedSize(block, block_size_max, total - frame_start, frame_state);
    return checkedAddWithinLimit(total, decoded_len, max_output_len);
}

const LiteralsKind = enum { raw, rle, compressed, treeless };

const LiteralOnlySection = struct {
    kind: LiteralsKind,
    size_format: u2,
    regenerated_size: usize,
    literal_payload_offset: usize,
    huffman_stream_offset: usize,
    compressed_size: usize = 0,
    sequence_count: usize,
    sequence_payload_offset: usize,
    huffman_tree: ?StdZstdHuffmanTree = null,
};

fn parseLiteralsSection(block: []const u8, frame_state: *SequenceFrameState) Error!LiteralOnlySection {
    var offset: usize = 0;
    const literal_header = try parseLiteralsHeader(block, &offset);
    const literal_payload_offset = offset;
    const literal_payload_len: usize = switch (literal_header.kind) {
        .raw => literal_header.regenerated_size,
        .rle => 1,
        .compressed, .treeless => literal_header.compressed_size,
    };
    if (block.len - offset < literal_payload_len) return error.TruncatedFrame;
    offset += literal_payload_len;
    if (literal_header.kind == .treeless and !frame_state.has_huffman_literals) {
        return error.CorruptFrame;
    }
    var huffman_tree: ?StdZstdHuffmanTree = null;
    var huffman_stream_offset = literal_payload_offset;
    if (literal_header.kind == .compressed) {
        if (literal_header.size_format != 0) return error.UnsupportedZstdFeature;
        const payload = block[literal_payload_offset..][0..literal_payload_len];
        var reader: std.Io.Reader = .fixed(payload);
        var remaining: std.Io.Limit = .limited(payload.len);
        // Zig std's Zstandard Huffman table builder is public and tracks the
        // same canonical tree invariants we need here. Keep the local code
        // focused on frame integration and bitstream traversal instead of
        // carrying a forked copy of the FSE/direct tree parser.
        huffman_tree = decodeStdZstdHuffmanTree(&reader, &remaining) catch |err| switch (err) {
            error.EndOfStream => return error.TruncatedFrame,
            else => return error.CorruptFrame,
        };
        huffman_stream_offset += reader.seek;
        frame_state.has_huffman_literals = true;
    }
    const sequence_count = try parseSequenceCount(block, &offset);
    return .{
        .kind = literal_header.kind,
        .size_format = literal_header.size_format,
        .regenerated_size = literal_header.regenerated_size,
        .literal_payload_offset = literal_payload_offset,
        .huffman_stream_offset = huffman_stream_offset,
        .compressed_size = literal_header.compressed_size,
        .sequence_count = sequence_count,
        .sequence_payload_offset = offset,
        .huffman_tree = huffman_tree,
    };
}

const LiteralsHeaderInfo = struct {
    kind: LiteralsKind,
    size_format: u2,
    regenerated_size: usize,
    compressed_size: usize = 0,
};

fn parseLiteralsHeader(block: []const u8, offset: *usize) Error!LiteralsHeaderInfo {
    if (offset.* >= block.len) return error.TruncatedFrame;
    const byte0 = block[offset.*];
    offset.* += 1;
    const block_type = byte0 & 0x03;
    const size_format: u2 = @intCast((byte0 >> 2) & 0x03);
    const kind: LiteralsKind = switch (block_type) {
        0 => .raw,
        1 => .rle,
        2 => .compressed,
        else => .treeless,
    };

    if (kind == .compressed or kind == .treeless) {
        return try parseHuffmanLiteralsHeader(block, offset, byte0, size_format, kind);
    }

    const regenerated_size: usize = switch (size_format) {
        0, 2 => byte0 >> 3,
        1 => blk: {
            if (block.len - offset.* < 1) return error.TruncatedFrame;
            const byte1 = block[offset.*];
            offset.* += 1;
            break :blk @as(usize, byte0 >> 4) + (@as(usize, byte1) << 4);
        },
        else => blk: {
            if (block.len - offset.* < 2) return error.TruncatedFrame;
            const byte1 = block[offset.*];
            const byte2 = block[offset.* + 1];
            offset.* += 2;
            break :blk @as(usize, byte0 >> 4) + (@as(usize, byte1) << 4) + (@as(usize, byte2) << 12);
        },
    };
    return .{ .kind = kind, .size_format = size_format, .regenerated_size = regenerated_size };
}

fn parseHuffmanLiteralsHeader(
    block: []const u8,
    offset: *usize,
    byte0: u8,
    size_format: u2,
    kind: LiteralsKind,
) Error!LiteralsHeaderInfo {
    return switch (size_format) {
        0, 1 => blk: {
            if (block.len - offset.* < 2) return error.TruncatedFrame;
            const byte1 = block[offset.*];
            const byte2 = block[offset.* + 1];
            offset.* += 2;
            const value = @as(usize, byte0 >> 4) |
                (@as(usize, byte1) << 4) |
                (@as(usize, byte2) << 12);
            const regenerated_size = value & 0x3ff;
            const compressed_size = (value >> 10) & 0x3ff;
            if (compressed_size == 0) return error.CorruptFrame;
            if (size_format == 1 and compressed_size < 10) return error.CorruptFrame;
            break :blk .{ .kind = kind, .size_format = size_format, .regenerated_size = regenerated_size, .compressed_size = compressed_size };
        },
        2 => blk: {
            if (block.len - offset.* < 3) return error.TruncatedFrame;
            const byte1 = block[offset.*];
            const byte2 = block[offset.* + 1];
            const byte3 = block[offset.* + 2];
            offset.* += 3;
            const value = @as(usize, byte0 >> 4) |
                (@as(usize, byte1) << 4) |
                (@as(usize, byte2) << 12) |
                (@as(usize, byte3) << 20);
            const regenerated_size = value & 0x3fff;
            const compressed_size = (value >> 14) & 0x3fff;
            if (compressed_size < 10) return error.CorruptFrame;
            break :blk .{ .kind = kind, .size_format = size_format, .regenerated_size = regenerated_size, .compressed_size = compressed_size };
        },
        else => blk: {
            if (block.len - offset.* < 4) return error.TruncatedFrame;
            const byte1 = block[offset.*];
            const byte2 = block[offset.* + 1];
            const byte3 = block[offset.* + 2];
            const byte4 = block[offset.* + 3];
            offset.* += 4;
            const value = @as(usize, byte0 >> 4) |
                (@as(usize, byte1) << 4) |
                (@as(usize, byte2) << 12) |
                (@as(usize, byte3) << 20) |
                (@as(usize, byte4) << 28);
            const regenerated_size = value & 0x3ffff;
            const compressed_size = (value >> 18) & 0x3ffff;
            if (compressed_size < 10) return error.CorruptFrame;
            break :blk .{ .kind = kind, .size_format = size_format, .regenerated_size = regenerated_size, .compressed_size = compressed_size };
        },
    };
}

fn decodeStdZstdHuffmanTree(
    reader: *std.Io.Reader,
    remaining: *std.Io.Limit,
) StdZstdHuffmanTree.DecodeError!StdZstdHuffmanTree {
    return try StdZstdHuffmanTree.decode(reader, remaining);
}

fn parseSequenceCount(block: []const u8, offset: *usize) Error!usize {
    if (offset.* >= block.len) return error.TruncatedFrame;
    const byte0 = block[offset.*];
    offset.* += 1;
    if (byte0 == 0) return 0;
    if (byte0 < 128) {
        return byte0;
    }
    if (byte0 < 255) {
        if (block.len - offset.* < 1) return error.TruncatedFrame;
        const count = (@as(usize, byte0 - 128) << 8) + block[offset.*];
        offset.* += 1;
        return count;
    }
    if (block.len - offset.* < 2) return error.TruncatedFrame;
    const count = @as(usize, block[offset.*]) + (@as(usize, block[offset.* + 1]) << 8) + 0x7f00;
    offset.* += 2;
    return count;
}

const SymbolMode = enum(u2) {
    predefined = 0,
    rle = 1,
    compressed = 2,
    repeat = 3,
};

const SequenceModeSpec = struct {
    ll_mode: SymbolMode,
    of_mode: SymbolMode,
    ml_mode: SymbolMode,
    literal_rle: ?SequenceSymbol,
    offset_rle: ?SequenceSymbol,
    match_rle: ?SequenceSymbol,
    bitstream_offset: usize,

    fn tables(self: SequenceModeSpec) SequenceTables {
        return .{
            .ll_mode = self.ll_mode,
            .of_mode = self.of_mode,
            .ml_mode = self.ml_mode,
            .literal_rle = self.literal_rle,
            .offset_rle = self.offset_rle,
            .match_rle = self.match_rle,
        };
    }
};

const SequenceSymbol = struct {
    base: usize,
    additional_bits: u8,
    next_state: usize,
    state_bits: u8,
};

const SequenceTables = struct {
    ll_mode: SymbolMode,
    of_mode: SymbolMode,
    ml_mode: SymbolMode,
    literal_rle: ?SequenceSymbol,
    offset_rle: ?SequenceSymbol,
    match_rle: ?SequenceSymbol,
};

const SequenceFrameState = struct {
    // Zstandard repeats both sequence tables and recent offsets across
    // compressed blocks in a frame. Raw/RLE blocks are intentionally skipped.
    // Keeping this small state object explicit makes the native fallback
    // decoder closer to the spec without hiding unsupported FSE tables.
    previous_tables: ?SequenceTables = null,
    repeated_offsets: [3]usize = initial_repeated_offsets,
    has_huffman_literals: bool = false,
};

const ResolvedSymbolTable = struct {
    mode: SymbolMode,
    rle: ?SequenceSymbol,
};

const default_ll_symbols = [_]SequenceSymbol{
    .{ .base = 0, .additional_bits = 0, .next_state = 0, .state_bits = 4 },
    .{ .base = 0, .additional_bits = 0, .next_state = 16, .state_bits = 4 },
    .{ .base = 1, .additional_bits = 0, .next_state = 32, .state_bits = 5 },
    .{ .base = 3, .additional_bits = 0, .next_state = 0, .state_bits = 5 },
    .{ .base = 4, .additional_bits = 0, .next_state = 0, .state_bits = 5 },
    .{ .base = 6, .additional_bits = 0, .next_state = 0, .state_bits = 5 },
    .{ .base = 7, .additional_bits = 0, .next_state = 0, .state_bits = 5 },
    .{ .base = 9, .additional_bits = 0, .next_state = 0, .state_bits = 5 },
    .{ .base = 10, .additional_bits = 0, .next_state = 0, .state_bits = 5 },
    .{ .base = 12, .additional_bits = 0, .next_state = 0, .state_bits = 5 },
    .{ .base = 14, .additional_bits = 0, .next_state = 0, .state_bits = 6 },
    .{ .base = 16, .additional_bits = 1, .next_state = 0, .state_bits = 5 },
    .{ .base = 20, .additional_bits = 1, .next_state = 0, .state_bits = 5 },
    .{ .base = 22, .additional_bits = 1, .next_state = 0, .state_bits = 5 },
    .{ .base = 28, .additional_bits = 2, .next_state = 0, .state_bits = 5 },
    .{ .base = 32, .additional_bits = 3, .next_state = 0, .state_bits = 5 },
    .{ .base = 48, .additional_bits = 4, .next_state = 0, .state_bits = 5 },
    .{ .base = 64, .additional_bits = 6, .next_state = 32, .state_bits = 5 },
    .{ .base = 128, .additional_bits = 7, .next_state = 0, .state_bits = 5 },
    .{ .base = 256, .additional_bits = 8, .next_state = 0, .state_bits = 6 },
    .{ .base = 1024, .additional_bits = 10, .next_state = 0, .state_bits = 6 },
    .{ .base = 4096, .additional_bits = 12, .next_state = 0, .state_bits = 6 },
    .{ .base = 0, .additional_bits = 0, .next_state = 32, .state_bits = 4 },
    .{ .base = 1, .additional_bits = 0, .next_state = 0, .state_bits = 4 },
    .{ .base = 2, .additional_bits = 0, .next_state = 0, .state_bits = 5 },
    .{ .base = 4, .additional_bits = 0, .next_state = 32, .state_bits = 5 },
    .{ .base = 5, .additional_bits = 0, .next_state = 0, .state_bits = 5 },
    .{ .base = 7, .additional_bits = 0, .next_state = 32, .state_bits = 5 },
    .{ .base = 8, .additional_bits = 0, .next_state = 0, .state_bits = 5 },
    .{ .base = 10, .additional_bits = 0, .next_state = 32, .state_bits = 5 },
    .{ .base = 11, .additional_bits = 0, .next_state = 0, .state_bits = 5 },
    .{ .base = 13, .additional_bits = 0, .next_state = 0, .state_bits = 6 },
    .{ .base = 16, .additional_bits = 1, .next_state = 32, .state_bits = 5 },
    .{ .base = 18, .additional_bits = 1, .next_state = 0, .state_bits = 5 },
    .{ .base = 22, .additional_bits = 1, .next_state = 32, .state_bits = 5 },
    .{ .base = 24, .additional_bits = 2, .next_state = 0, .state_bits = 5 },
    .{ .base = 32, .additional_bits = 3, .next_state = 32, .state_bits = 5 },
    .{ .base = 40, .additional_bits = 3, .next_state = 0, .state_bits = 5 },
    .{ .base = 64, .additional_bits = 6, .next_state = 0, .state_bits = 4 },
    .{ .base = 64, .additional_bits = 6, .next_state = 16, .state_bits = 4 },
    .{ .base = 128, .additional_bits = 7, .next_state = 32, .state_bits = 5 },
    .{ .base = 512, .additional_bits = 9, .next_state = 0, .state_bits = 6 },
    .{ .base = 2048, .additional_bits = 11, .next_state = 0, .state_bits = 6 },
    .{ .base = 0, .additional_bits = 0, .next_state = 48, .state_bits = 4 },
    .{ .base = 1, .additional_bits = 0, .next_state = 16, .state_bits = 4 },
    .{ .base = 2, .additional_bits = 0, .next_state = 32, .state_bits = 5 },
    .{ .base = 3, .additional_bits = 0, .next_state = 32, .state_bits = 5 },
    .{ .base = 5, .additional_bits = 0, .next_state = 32, .state_bits = 5 },
    .{ .base = 6, .additional_bits = 0, .next_state = 32, .state_bits = 5 },
    .{ .base = 8, .additional_bits = 0, .next_state = 32, .state_bits = 5 },
    .{ .base = 9, .additional_bits = 0, .next_state = 32, .state_bits = 5 },
    .{ .base = 11, .additional_bits = 0, .next_state = 32, .state_bits = 5 },
    .{ .base = 12, .additional_bits = 0, .next_state = 32, .state_bits = 5 },
    .{ .base = 15, .additional_bits = 0, .next_state = 0, .state_bits = 6 },
    .{ .base = 18, .additional_bits = 1, .next_state = 32, .state_bits = 5 },
    .{ .base = 20, .additional_bits = 1, .next_state = 32, .state_bits = 5 },
    .{ .base = 24, .additional_bits = 2, .next_state = 32, .state_bits = 5 },
    .{ .base = 28, .additional_bits = 2, .next_state = 32, .state_bits = 5 },
    .{ .base = 40, .additional_bits = 3, .next_state = 32, .state_bits = 5 },
    .{ .base = 48, .additional_bits = 4, .next_state = 32, .state_bits = 5 },
    .{ .base = 65536, .additional_bits = 16, .next_state = 0, .state_bits = 6 },
    .{ .base = 32768, .additional_bits = 15, .next_state = 0, .state_bits = 6 },
    .{ .base = 16384, .additional_bits = 14, .next_state = 0, .state_bits = 6 },
    .{ .base = 8192, .additional_bits = 13, .next_state = 0, .state_bits = 6 },
};

const default_of_symbols = [_]SequenceSymbol{
    .{ .base = 0, .additional_bits = 0, .next_state = 0, .state_bits = 5 },
    .{ .base = 61, .additional_bits = 6, .next_state = 0, .state_bits = 4 },
    .{ .base = 509, .additional_bits = 9, .next_state = 0, .state_bits = 5 },
    .{ .base = 32765, .additional_bits = 15, .next_state = 0, .state_bits = 5 },
    .{ .base = 2097149, .additional_bits = 21, .next_state = 0, .state_bits = 5 },
    .{ .base = 5, .additional_bits = 3, .next_state = 0, .state_bits = 5 },
    .{ .base = 125, .additional_bits = 7, .next_state = 0, .state_bits = 4 },
    .{ .base = 4093, .additional_bits = 12, .next_state = 0, .state_bits = 5 },
    .{ .base = 262141, .additional_bits = 18, .next_state = 0, .state_bits = 5 },
    .{ .base = 8388605, .additional_bits = 23, .next_state = 0, .state_bits = 5 },
    .{ .base = 29, .additional_bits = 5, .next_state = 0, .state_bits = 5 },
    .{ .base = 253, .additional_bits = 8, .next_state = 0, .state_bits = 4 },
    .{ .base = 16381, .additional_bits = 14, .next_state = 0, .state_bits = 5 },
    .{ .base = 1048573, .additional_bits = 20, .next_state = 0, .state_bits = 5 },
    .{ .base = 1, .additional_bits = 2, .next_state = 0, .state_bits = 5 },
    .{ .base = 125, .additional_bits = 7, .next_state = 16, .state_bits = 4 },
    .{ .base = 2045, .additional_bits = 11, .next_state = 0, .state_bits = 5 },
    .{ .base = 131069, .additional_bits = 17, .next_state = 0, .state_bits = 5 },
    .{ .base = 4194301, .additional_bits = 22, .next_state = 0, .state_bits = 5 },
    .{ .base = 13, .additional_bits = 4, .next_state = 0, .state_bits = 5 },
    .{ .base = 253, .additional_bits = 8, .next_state = 16, .state_bits = 4 },
    .{ .base = 8189, .additional_bits = 13, .next_state = 0, .state_bits = 5 },
    .{ .base = 524285, .additional_bits = 19, .next_state = 0, .state_bits = 5 },
    .{ .base = 1, .additional_bits = 1, .next_state = 0, .state_bits = 5 },
    .{ .base = 61, .additional_bits = 6, .next_state = 16, .state_bits = 4 },
    .{ .base = 1021, .additional_bits = 10, .next_state = 0, .state_bits = 5 },
    .{ .base = 65533, .additional_bits = 16, .next_state = 0, .state_bits = 5 },
    .{ .base = 268435453, .additional_bits = 28, .next_state = 0, .state_bits = 5 },
    .{ .base = 134217725, .additional_bits = 27, .next_state = 0, .state_bits = 5 },
    .{ .base = 67108861, .additional_bits = 26, .next_state = 0, .state_bits = 5 },
    .{ .base = 33554429, .additional_bits = 25, .next_state = 0, .state_bits = 5 },
    .{ .base = 16777213, .additional_bits = 24, .next_state = 0, .state_bits = 5 },
};

const default_ml_symbols = [_]SequenceSymbol{
    .{ .base = 3, .additional_bits = 0, .next_state = 0, .state_bits = 6 },
    .{ .base = 4, .additional_bits = 0, .next_state = 0, .state_bits = 4 },
    .{ .base = 5, .additional_bits = 0, .next_state = 32, .state_bits = 5 },
    .{ .base = 6, .additional_bits = 0, .next_state = 0, .state_bits = 5 },
    .{ .base = 8, .additional_bits = 0, .next_state = 0, .state_bits = 5 },
    .{ .base = 9, .additional_bits = 0, .next_state = 0, .state_bits = 5 },
    .{ .base = 11, .additional_bits = 0, .next_state = 0, .state_bits = 5 },
    .{ .base = 13, .additional_bits = 0, .next_state = 0, .state_bits = 6 },
    .{ .base = 16, .additional_bits = 0, .next_state = 0, .state_bits = 6 },
    .{ .base = 19, .additional_bits = 0, .next_state = 0, .state_bits = 6 },
    .{ .base = 22, .additional_bits = 0, .next_state = 0, .state_bits = 6 },
    .{ .base = 25, .additional_bits = 0, .next_state = 0, .state_bits = 6 },
    .{ .base = 28, .additional_bits = 0, .next_state = 0, .state_bits = 6 },
    .{ .base = 31, .additional_bits = 0, .next_state = 0, .state_bits = 6 },
    .{ .base = 34, .additional_bits = 0, .next_state = 0, .state_bits = 6 },
    .{ .base = 37, .additional_bits = 1, .next_state = 0, .state_bits = 6 },
    .{ .base = 41, .additional_bits = 1, .next_state = 0, .state_bits = 6 },
    .{ .base = 47, .additional_bits = 2, .next_state = 0, .state_bits = 6 },
    .{ .base = 59, .additional_bits = 3, .next_state = 0, .state_bits = 6 },
    .{ .base = 83, .additional_bits = 4, .next_state = 0, .state_bits = 6 },
    .{ .base = 131, .additional_bits = 7, .next_state = 0, .state_bits = 6 },
    .{ .base = 515, .additional_bits = 9, .next_state = 0, .state_bits = 6 },
    .{ .base = 4, .additional_bits = 0, .next_state = 16, .state_bits = 4 },
    .{ .base = 5, .additional_bits = 0, .next_state = 0, .state_bits = 4 },
    .{ .base = 6, .additional_bits = 0, .next_state = 32, .state_bits = 5 },
    .{ .base = 7, .additional_bits = 0, .next_state = 0, .state_bits = 5 },
    .{ .base = 9, .additional_bits = 0, .next_state = 32, .state_bits = 5 },
    .{ .base = 10, .additional_bits = 0, .next_state = 0, .state_bits = 5 },
    .{ .base = 12, .additional_bits = 0, .next_state = 0, .state_bits = 6 },
    .{ .base = 15, .additional_bits = 0, .next_state = 0, .state_bits = 6 },
    .{ .base = 18, .additional_bits = 0, .next_state = 0, .state_bits = 6 },
    .{ .base = 21, .additional_bits = 0, .next_state = 0, .state_bits = 6 },
    .{ .base = 24, .additional_bits = 0, .next_state = 0, .state_bits = 6 },
    .{ .base = 27, .additional_bits = 0, .next_state = 0, .state_bits = 6 },
    .{ .base = 30, .additional_bits = 0, .next_state = 0, .state_bits = 6 },
    .{ .base = 33, .additional_bits = 0, .next_state = 0, .state_bits = 6 },
    .{ .base = 35, .additional_bits = 1, .next_state = 0, .state_bits = 6 },
    .{ .base = 39, .additional_bits = 1, .next_state = 0, .state_bits = 6 },
    .{ .base = 43, .additional_bits = 2, .next_state = 0, .state_bits = 6 },
    .{ .base = 51, .additional_bits = 3, .next_state = 0, .state_bits = 6 },
    .{ .base = 67, .additional_bits = 4, .next_state = 0, .state_bits = 6 },
    .{ .base = 99, .additional_bits = 5, .next_state = 0, .state_bits = 6 },
    .{ .base = 259, .additional_bits = 8, .next_state = 0, .state_bits = 6 },
    .{ .base = 4, .additional_bits = 0, .next_state = 32, .state_bits = 4 },
    .{ .base = 4, .additional_bits = 0, .next_state = 48, .state_bits = 4 },
    .{ .base = 5, .additional_bits = 0, .next_state = 16, .state_bits = 4 },
    .{ .base = 7, .additional_bits = 0, .next_state = 32, .state_bits = 5 },
    .{ .base = 8, .additional_bits = 0, .next_state = 32, .state_bits = 5 },
    .{ .base = 10, .additional_bits = 0, .next_state = 32, .state_bits = 5 },
    .{ .base = 11, .additional_bits = 0, .next_state = 32, .state_bits = 5 },
    .{ .base = 14, .additional_bits = 0, .next_state = 0, .state_bits = 6 },
    .{ .base = 17, .additional_bits = 0, .next_state = 0, .state_bits = 6 },
    .{ .base = 20, .additional_bits = 0, .next_state = 0, .state_bits = 6 },
    .{ .base = 23, .additional_bits = 0, .next_state = 0, .state_bits = 6 },
    .{ .base = 26, .additional_bits = 0, .next_state = 0, .state_bits = 6 },
    .{ .base = 29, .additional_bits = 0, .next_state = 0, .state_bits = 6 },
    .{ .base = 32, .additional_bits = 0, .next_state = 0, .state_bits = 6 },
    .{ .base = 65539, .additional_bits = 16, .next_state = 0, .state_bits = 6 },
    .{ .base = 32771, .additional_bits = 15, .next_state = 0, .state_bits = 6 },
    .{ .base = 16387, .additional_bits = 14, .next_state = 0, .state_bits = 6 },
    .{ .base = 8195, .additional_bits = 13, .next_state = 0, .state_bits = 6 },
    .{ .base = 4099, .additional_bits = 12, .next_state = 0, .state_bits = 6 },
    .{ .base = 2051, .additional_bits = 11, .next_state = 0, .state_bits = 6 },
    .{ .base = 1027, .additional_bits = 10, .next_state = 0, .state_bits = 6 },
};

fn parseSequenceModeSpec(block: []const u8, offset: *usize, sequence_count: usize) Error!SequenceModeSpec {
    if (sequence_count == 0) return error.CorruptFrame;
    if (block.len - offset.* < 1) return error.TruncatedFrame;
    const mode = block[offset.*];
    offset.* += 1;
    if ((mode & 0x03) != 0) return error.CorruptFrame;
    const ll_mode: SymbolMode = @enumFromInt(mode >> 6);
    const of_mode: SymbolMode = @enumFromInt((mode >> 4) & 0x03);
    const ml_mode: SymbolMode = @enumFromInt((mode >> 2) & 0x03);

    const literal_rle = if (ll_mode == .rle) try readRleSymbolCode(block, offset, &ll_base, &ll_bits) else null;
    const offset_rle = if (of_mode == .rle) try readRleSymbolCode(block, offset, &of_base, &of_bits) else null;
    const match_rle = if (ml_mode == .rle) try readRleSymbolCode(block, offset, &ml_base, &ml_bits) else null;

    if (ll_mode == .compressed or of_mode == .compressed or ml_mode == .compressed) {
        return error.UnsupportedZstdFeature;
    }

    const bitstream_offset = offset.*;
    if (bitstream_offset >= block.len) return error.TruncatedFrame;
    offset.* = block.len;
    return .{
        .ll_mode = ll_mode,
        .of_mode = of_mode,
        .ml_mode = ml_mode,
        .literal_rle = literal_rle,
        .offset_rle = offset_rle,
        .match_rle = match_rle,
        .bitstream_offset = bitstream_offset,
    };
}

fn resolveSymbolTable(
    mode: SymbolMode,
    rle: ?SequenceSymbol,
    previous: ?SequenceTables,
    selector: enum { ll, of, ml },
) Error!ResolvedSymbolTable {
    return switch (mode) {
        .repeat => blk: {
            const tables = previous orelse return error.CorruptFrame;
            break :blk switch (selector) {
                .ll => .{ .mode = tables.ll_mode, .rle = tables.literal_rle },
                .of => .{ .mode = tables.of_mode, .rle = tables.offset_rle },
                .ml => .{ .mode = tables.ml_mode, .rle = tables.match_rle },
            };
        },
        else => .{ .mode = mode, .rle = rle },
    };
}

fn resolveSequenceModeSpec(spec: SequenceModeSpec, previous: ?SequenceTables) Error!SequenceModeSpec {
    const ll = try resolveSymbolTable(spec.ll_mode, spec.literal_rle, previous, .ll);
    const of = try resolveSymbolTable(spec.of_mode, spec.offset_rle, previous, .of);
    const ml = try resolveSymbolTable(spec.ml_mode, spec.match_rle, previous, .ml);
    return .{
        .ll_mode = ll.mode,
        .of_mode = of.mode,
        .ml_mode = ml.mode,
        .literal_rle = ll.rle,
        .offset_rle = of.rle,
        .match_rle = ml.rle,
        .bitstream_offset = spec.bitstream_offset,
    };
}

fn readRleSymbolCode(block: []const u8, offset: *usize, bases: []const usize, bits: []const u8) Error!SequenceSymbol {
    if (offset.* >= block.len) return error.TruncatedFrame;
    const code = block[offset.*];
    offset.* += 1;
    if (code >= bases.len) return error.CorruptFrame;
    return .{ .base = bases[code], .additional_bits = bits[code], .next_state = 0, .state_bits = 0 };
}

fn defaultLiteralLengthSymbol(state: usize) Error!SequenceSymbol {
    if (state >= default_ll_symbols.len) return error.UnsupportedZstdFeature;
    return default_ll_symbols[state];
}

fn defaultOffsetSymbol(state: usize) Error!SequenceSymbol {
    if (state >= default_of_symbols.len) return error.UnsupportedZstdFeature;
    return default_of_symbols[state];
}

fn defaultMatchLengthSymbol(state: usize) Error!SequenceSymbol {
    if (state >= default_ml_symbols.len) return error.UnsupportedZstdFeature;
    return default_ml_symbols[state];
}

const ReverseBitReader = struct {
    bytes: []const u8,
    remaining_bits: usize,

    fn init(bitstream: []const u8) Error!ReverseBitReader {
        if (bitstream.len == 0) return error.TruncatedFrame;
        const last = bitstream[bitstream.len - 1];
        if (last == 0) return error.CorruptFrame;

        const marker_bit = highBitIndex(last);
        const payload_bits = (bitstream.len - 1) * 8 + marker_bit;
        return .{ .bytes = bitstream, .remaining_bits = payload_bits };
    }

    fn read(self: *ReverseBitReader, bit_count: u8) Error!usize {
        if (bit_count == 0) return 0;
        if (bit_count > @bitSizeOf(usize)) return error.UnsupportedZstdFeature;
        if (bit_count > self.remaining_bits) return error.TruncatedFrame;
        var value: usize = 0;
        var bit = self.remaining_bits;
        while (bit > self.remaining_bits - bit_count) {
            bit -= 1;
            const byte = self.bytes[bit / 8];
            const bit_index: u3 = @intCast(bit & 7);
            value = (value << 1) | @as(usize, @intCast((byte >> bit_index) & 1));
        }
        self.remaining_bits -= bit_count;
        return value;
    }

    fn expectEnd(self: ReverseBitReader) Error!void {
        if (self.remaining_bits != 0) return error.CorruptFrame;
    }
};

fn highBitIndex(byte: u8) usize {
    var bit: usize = 8;
    while (bit > 0) {
        bit -= 1;
        if ((byte & (@as(u8, 1) << @as(u3, @intCast(bit)))) != 0) return bit;
    }
    unreachable;
}

fn decodeRleSequencesCompressedBlockIntoBuffer(
    block: []const u8,
    section: LiteralOnlySection,
    output: []u8,
    written: *usize,
    frame_output_start: usize,
    frame_state: *SequenceFrameState,
) Error!void {
    if (frame_output_start > written.*) return error.CorruptFrame;
    var offset = section.sequence_payload_offset;
    const parsed_spec = try parseSequenceModeSpec(block, &offset, section.sequence_count);
    const spec = try resolveSequenceModeSpec(parsed_spec, frame_state.previous_tables);
    if (offset != block.len) return error.UnsupportedZstdFeature;
    const bit_reader = try ReverseBitReader.init(block[spec.bitstream_offset..]);

    var state = try initSequenceDecodeState(spec, section.sequence_count, bit_reader, frame_state.repeated_offsets);
    var literal_offset: usize = 0;
    while (state.remaining != 0) {
        const sequence = try readModeSequence(&state);
        const literal_len = sequence.literal_len;
        try copyLiteralsFromSection(block, section, literal_offset, output, written, literal_len);
        literal_offset = std.math.add(usize, literal_offset, literal_len) catch return error.IntegerOverflow;
        try copyMatchFromOutputBuffer(output, written, frame_output_start, sequence.match_offset, sequence.match_len);
    }
    if (section.regenerated_size < literal_offset) return error.CorruptFrame;
    const last_literals = section.regenerated_size - literal_offset;
    try copyLiteralsFromSection(block, section, literal_offset, output, written, last_literals);
    frame_state.previous_tables = spec.tables();
    frame_state.repeated_offsets = state.repeated_offsets;
}

fn rleSequencesCompressedBlockDecodedSize(
    block: []const u8,
    section: LiteralOnlySection,
    initial_output_len: usize,
    frame_state: *SequenceFrameState,
) Error!usize {
    var offset = section.sequence_payload_offset;
    const parsed_spec = try parseSequenceModeSpec(block, &offset, section.sequence_count);
    const spec = try resolveSequenceModeSpec(parsed_spec, frame_state.previous_tables);
    if (offset != block.len) return error.UnsupportedZstdFeature;
    const bit_reader = try ReverseBitReader.init(block[spec.bitstream_offset..]);

    var state = try initSequenceDecodeState(spec, section.sequence_count, bit_reader, frame_state.repeated_offsets);
    var literal_offset: usize = 0;
    var produced: usize = 0;
    while (state.remaining != 0) {
        const sequence = try readModeSequence(&state);
        const literal_len = sequence.literal_len;
        if (literal_offset > section.regenerated_size or section.regenerated_size - literal_offset < literal_len) {
            return error.CorruptFrame;
        }
        literal_offset = std.math.add(usize, literal_offset, literal_len) catch return error.IntegerOverflow;
        produced = std.math.add(usize, produced, literal_len) catch return error.IntegerOverflow;
        const available = std.math.add(usize, initial_output_len, produced) catch return error.IntegerOverflow;
        if (sequence.match_offset == 0 or sequence.match_offset > available) return error.InvalidMatch;
        produced = std.math.add(usize, produced, sequence.match_len) catch return error.IntegerOverflow;
    }
    if (section.regenerated_size < literal_offset) return error.CorruptFrame;
    produced = std.math.add(usize, produced, section.regenerated_size - literal_offset) catch return error.IntegerOverflow;
    frame_state.previous_tables = spec.tables();
    frame_state.repeated_offsets = state.repeated_offsets;
    return produced;
}

const SequenceDecodeState = struct {
    spec: SequenceModeSpec,
    reader: ReverseBitReader,
    ll_state: usize = 0,
    of_state: usize = 0,
    ml_state: usize = 0,
    repeated_offsets: [3]usize = initial_repeated_offsets,
    remaining: usize,
};

fn initSequenceDecodeState(
    spec: SequenceModeSpec,
    sequence_count: usize,
    reader: ReverseBitReader,
    repeated_offsets: [3]usize,
) Error!SequenceDecodeState {
    var initialized_reader = reader;
    const ll_state = if (spec.ll_mode == .predefined) try initialized_reader.read(6) else 0;
    const of_state = if (spec.of_mode == .predefined) try initialized_reader.read(5) else 0;
    const ml_state = if (spec.ml_mode == .predefined) try initialized_reader.read(6) else 0;
    return .{
        .spec = spec,
        .reader = initialized_reader,
        .ll_state = ll_state,
        .of_state = of_state,
        .ml_state = ml_state,
        .repeated_offsets = repeated_offsets,
        .remaining = sequence_count,
    };
}

fn readModeSequence(state: *SequenceDecodeState) Error!DecodedSequence {
    if (state.remaining == 0) return error.CorruptFrame;

    const ll_symbol = try currentLiteralSymbol(state.*);
    const of_symbol = try currentOffsetSymbol(state.*);
    const ml_symbol = try currentMatchSymbol(state.*);

    const match_offset = try readSequenceOffset(&state.reader, of_symbol.base, of_symbol.additional_bits, ll_symbol.base, &state.repeated_offsets);
    const match_len = std.math.add(usize, ml_symbol.base, try state.reader.read(ml_symbol.additional_bits)) catch return error.IntegerOverflow;
    const literal_len = std.math.add(usize, ll_symbol.base, try state.reader.read(ll_symbol.additional_bits)) catch return error.IntegerOverflow;

    state.remaining -= 1;
    if (state.remaining != 0) {
        try updateLiteralState(state, ll_symbol);
        try updateMatchState(state, ml_symbol);
        try updateOffsetState(state, of_symbol);
    } else {
        try state.reader.expectEnd();
    }

    return .{ .literal_len = literal_len, .match_len = match_len, .match_offset = match_offset };
}

fn currentLiteralSymbol(state: SequenceDecodeState) Error!SequenceSymbol {
    return switch (state.spec.ll_mode) {
        .predefined => try defaultLiteralLengthSymbol(state.ll_state),
        .rle => state.spec.literal_rle orelse error.CorruptFrame,
        else => error.UnsupportedZstdFeature,
    };
}

fn currentOffsetSymbol(state: SequenceDecodeState) Error!SequenceSymbol {
    return switch (state.spec.of_mode) {
        .predefined => try defaultOffsetSymbol(state.of_state),
        .rle => state.spec.offset_rle orelse error.CorruptFrame,
        else => error.UnsupportedZstdFeature,
    };
}

fn currentMatchSymbol(state: SequenceDecodeState) Error!SequenceSymbol {
    return switch (state.spec.ml_mode) {
        .predefined => try defaultMatchLengthSymbol(state.ml_state),
        .rle => state.spec.match_rle orelse error.CorruptFrame,
        else => error.UnsupportedZstdFeature,
    };
}

fn updateLiteralState(state: *SequenceDecodeState, symbol: SequenceSymbol) Error!void {
    if (state.spec.ll_mode == .predefined) state.ll_state = try nextPredefinedState(&state.reader, symbol);
}

fn updateOffsetState(state: *SequenceDecodeState, symbol: SequenceSymbol) Error!void {
    if (state.spec.of_mode == .predefined) state.of_state = try nextPredefinedState(&state.reader, symbol);
}

fn updateMatchState(state: *SequenceDecodeState, symbol: SequenceSymbol) Error!void {
    if (state.spec.ml_mode == .predefined) state.ml_state = try nextPredefinedState(&state.reader, symbol);
}

const DecodedSequence = struct {
    literal_len: usize,
    match_len: usize,
    match_offset: usize,
};

fn nextPredefinedState(reader: *ReverseBitReader, symbol: SequenceSymbol) Error!usize {
    return std.math.add(usize, symbol.next_state, try reader.read(symbol.state_bits)) catch return error.IntegerOverflow;
}

fn readSequenceOffset(
    reader: *ReverseBitReader,
    offset_base: usize,
    offset_bits: u8,
    literal_base: usize,
    repeated_offsets: *[3]usize,
) Error!usize {
    if (offset_bits > 1) {
        const offset = std.math.add(usize, offset_base, try reader.read(offset_bits)) catch return error.IntegerOverflow;
        repeated_offsets.* = .{ offset, repeated_offsets[0], repeated_offsets[1] };
        return offset;
    }

    const literal_base_is_zero = literal_base == 0;
    if (offset_bits == 0) {
        const offset = if (literal_base_is_zero) repeated_offsets[1] else repeated_offsets[0];
        repeated_offsets[1] = repeated_offsets[if (literal_base_is_zero) 0 else 1];
        repeated_offsets[0] = offset;
        return offset;
    }

    const raw_base = std.math.add(usize, offset_base, if (literal_base_is_zero) 1 else 0) catch return error.IntegerOverflow;
    const raw_offset = std.math.add(
        usize,
        raw_base,
        try reader.read(1),
    ) catch return error.IntegerOverflow;
    const offset = if (raw_offset == 3) blk: {
        if (repeated_offsets[0] == 0) return error.InvalidMatch;
        break :blk repeated_offsets[0] - 1;
    } else if (raw_offset < repeated_offsets.len) blk: {
        break :blk repeated_offsets[raw_offset];
    } else {
        return error.UnsupportedZstdFeature;
    };
    if (offset == 0) return error.InvalidMatch;
    if (raw_offset != 1) repeated_offsets[2] = repeated_offsets[1];
    repeated_offsets[1] = repeated_offsets[0];
    repeated_offsets[0] = offset;
    return offset;
}

fn copyMatchFromOutputBuffer(
    output: []u8,
    written: *usize,
    frame_output_start: usize,
    match_offset: usize,
    match_len: usize,
) Error!void {
    if (frame_output_start > written.*) return error.CorruptFrame;
    const available_in_frame = written.* - frame_output_start;
    if (match_offset == 0 or match_offset > available_in_frame) return error.InvalidMatch;
    if (output.len - written.* < match_len) return error.OutputTooSmall;
    const repeat_start = written.* - match_offset;
    appendRepeatedMatch(output, written, repeat_start, match_len);
}

fn appendRepeatedMatch(output: []u8, written: *usize, repeat_start: usize, match_len: usize) void {
    const initial_available = written.* - repeat_start;
    const destination_start = written.*;
    written.* += match_len;
    var copied: usize = 0;
    while (copied < match_len) {
        const available = if (copied == 0) initial_available else copied;
        const copy_len = @min(available, match_len - copied);
        const source_start = if (copied == 0) repeat_start else destination_start;
        @memcpy(
            output[destination_start + copied ..][0..copy_len],
            output[source_start..][0..copy_len],
        );
        copied += copy_len;
    }
}

fn rawOrRleDecodedSizeLimited(frame: []const u8, max_output_len: usize) Error!usize {
    var offset: usize = 0;
    var total: usize = 0;
    while (offset < frame.len) {
        if (frame.len - offset < 4) return error.TruncatedFrame;
        const magic = std.mem.readInt(u32, frame[offset..][0..4], .little);
        offset += 4;
        if (magic == frame_magic_u32) {
            const header = try parseRawOrRleFrameHeader(frame, &offset);
            const frame_start = total;
            var frame_state: SequenceFrameState = .{};
            while (true) {
                if (frame.len - offset < 3) return error.TruncatedFrame;
                const block_header = std.mem.readInt(u24, frame[offset..][0..3], .little);
                offset += 3;
                const last = (block_header & 0x1) != 0;
                const block_type = (block_header >> 1) & 0x3;
                const block_len: usize = @intCast(block_header >> 3);
                try validateBlockSize(header, block_type, block_len);

                switch (block_type) {
                    0 => {
                        if (frame.len - offset < block_len) return error.TruncatedFrame;
                        offset += block_len;
                        total = try checkedAddWithinLimit(total, block_len, max_output_len);
                    },
                    1 => {
                        if (block_len == 0) return error.CorruptFrame;
                        if (frame.len - offset < 1) return error.TruncatedFrame;
                        offset += 1;
                        total = try checkedAddWithinLimit(total, block_len, max_output_len);
                    },
                    2 => {
                        if (frame.len - offset < block_len) return error.TruncatedFrame;
                        total = try compressedLiteralOnlyBlockDecodedSizeLimited(frame[offset..][0..block_len], total, frame_start, max_output_len, header.block_size_max, &frame_state);
                        offset += block_len;
                    },
                    else => return error.CorruptFrame,
                }
                if (last) break;
            }

            const frame_decoded_len = total - frame_start;
            if (header.content_size) |size| {
                if (try checkedUsizeToU64(frame_decoded_len) != size) return error.SizeMismatch;
            }
            if (header.has_checksum) {
                if (frame.len - offset < 4) return error.TruncatedFrame;
                offset += 4;
            }
        } else if (magic >= skippable_magic_min and magic <= skippable_magic_max) {
            if (frame.len - offset < 4) return error.TruncatedFrame;
            const skip_len: usize = @intCast(std.mem.readInt(u32, frame[offset..][0..4], .little));
            offset += 4;
            if (frame.len - offset < skip_len) return error.TruncatedFrame;
            offset += skip_len;
        } else {
            return error.InvalidMagic;
        }
    }
    return total;
}

fn checkedAddWithinLimit(current: usize, additional: usize, max: usize) Error!usize {
    const next = std.math.add(usize, current, additional) catch return error.IntegerOverflow;
    if (next > max) return error.OutputLimitExceeded;
    return next;
}

fn parseRawOrRleFrameHeader(frame: []const u8, offset: *usize) Error!RawOrRleFrameHeader {
    if (frame.len - offset.* < 1) return error.TruncatedFrame;
    const descriptor = frame[offset.*];
    offset.* += 1;

    if ((descriptor & 0x08) != 0) return error.CorruptFrame;
    if ((descriptor & 0x10) != 0) return error.UnsupportedZstdFeature;

    const dictionary_id_flag = descriptor & 0x03;
    const has_checksum = (descriptor & 0x04) != 0;
    const single_segment = (descriptor & 0x20) != 0;
    const content_size_flag = descriptor >> 6;

    const window_size = if (single_segment) null else blk: {
        if (frame.len - offset.* < 1) return error.TruncatedFrame;
        const window_descriptor = frame[offset.*];
        offset.* += 1;
        break :blk decodeWindowSize(window_descriptor);
    };

    const dictionary_id_len: usize = switch (dictionary_id_flag) {
        0 => 0,
        1 => 1,
        2 => 2,
        else => 4,
    };
    if (frame.len - offset.* < dictionary_id_len) return error.TruncatedFrame;
    if (dictionary_id_len != 0) return error.NeedDictionary;
    offset.* += dictionary_id_len;

    const content_size: ?u64 = if (single_segment or content_size_flag != 0) blk: {
        const field_size: usize = @as(usize, 1) << @intCast(content_size_flag);
        const encoded_size = try readU64Field(frame, offset, field_size);
        break :blk if (field_size == 2) encoded_size + 256 else encoded_size;
    } else null;

    const effective_window = if (single_segment) content_size.? else window_size.?;
    const block_size_max = @min(
        std.compress.zstd.block_size_max,
        try checkedU64ToUsize(effective_window),
    );

    return .{
        .content_size = content_size,
        .has_checksum = has_checksum,
        .block_size_max = block_size_max,
    };
}

fn decodeWindowSize(descriptor: u8) u64 {
    const exponent = (descriptor & 0b1111_1000) >> 3;
    const mantissa = descriptor & 0b0000_0111;
    const window_log = 10 + @as(u6, @intCast(exponent));
    const window_base = @as(u64, 1) << window_log;
    return window_base + (window_base / 8) * mantissa;
}

fn readU64Field(frame: []const u8, offset: *usize, field_size: usize) Error!u64 {
    if (frame.len - offset.* < field_size) return error.TruncatedFrame;
    var value: u64 = 0;
    for (frame[offset.*..][0..field_size], 0..) |byte, i| {
        value |= @as(u64, byte) << @as(u6, @intCast(i * 8));
    }
    offset.* += field_size;
    return value;
}

fn rleByte(block: []const u8) ?u8 {
    if (block.len < 2) return null;
    const first = block[0];
    for (block[1..]) |byte| {
        if (byte != first) return null;
    }
    return first;
}

const RleRun = struct {
    start: usize,
    len: usize,
};

fn findRleRun(block: []const u8) ?RleRun {
    var i: usize = 0;
    while (i < block.len) {
        const len = sameByteRunLen(block, i);
        if (len >= min_rle_split_len) return .{ .start = i, .len = len };
        i += @max(len, 1);
    }
    return null;
}

fn sameByteRunLen(block: []const u8, start: usize) usize {
    const byte = block[start];
    var end = start + 1;
    while (end < block.len and block[end] == byte) : (end += 1) {}
    return end - start;
}

fn emitBlock(allocator: std.mem.Allocator, out: *std.ArrayList(u8), block: []const u8, last: bool) Error!void {
    if (rleByte(block)) |byte| return try emitRleBlock(allocator, out, byte, block.len, last);
    return try emitRawBlock(allocator, out, block, last);
}

fn emitLiteralOnlyCompressedBlock(allocator: std.mem.Allocator, out: *std.ArrayList(u8), block: []const u8, last: bool) Error!void {
    const literal_kind: LiteralsKind = if (rleByte(block) != null) .rle else .raw;
    const literal_payload_len: usize = switch (literal_kind) {
        .raw => block.len,
        .rle => 1,
        .compressed, .treeless => unreachable,
    };
    const header_len = try literalsHeaderLen(block.len);
    const payload_prefix_len = std.math.add(usize, header_len, literal_payload_len) catch return error.IntegerOverflow;
    const payload_len = std.math.add(
        usize,
        payload_prefix_len,
        1, // sequence_count=0: the compressed block is literals-only.
    ) catch return error.IntegerOverflow;
    // The reference encoder avoids compressed blocks when entropy/literal
    // section headers erase the size win. Requiring an actual size reduction
    // also sidesteps deployed zstd CLI/lib builds that reject some
    // sequence-free compressed blocks once Block_Size exceeds the regenerated
    // block size.
    if (payload_len >= block.len) return try emitBlock(allocator, out, block, last);

    var payload: std.ArrayList(u8) = .empty;
    defer payload.deinit(allocator);
    if (literal_kind == .rle) {
        try emitLiteralsHeader(allocator, &payload, .rle, block.len);
        try payload.append(allocator, block[0]);
    } else {
        try emitLiteralsHeader(allocator, &payload, .raw, block.len);
        try payload.appendSlice(allocator, block);
    }
    try payload.append(allocator, 0); // sequence_count=0: the compressed block is literals-only.
    try emitBlockHeader(allocator, out, 2, payload.items.len, last);
    try out.appendSlice(allocator, payload.items);
}

fn emitLiteralsHeader(allocator: std.mem.Allocator, out: *std.ArrayList(u8), kind: LiteralsKind, regenerated_size: usize) Error!void {
    _ = try literalsHeaderLen(regenerated_size);
    const kind_bits: u8 = switch (kind) {
        .raw => 0,
        .rle => 1,
        .compressed, .treeless => return error.UnsupportedZstdFeature,
    };
    if (regenerated_size <= 31) {
        try out.append(allocator, kind_bits | @as(u8, @intCast(regenerated_size << 3)));
    } else if (regenerated_size <= 4095) {
        const low: u8 = @intCast(regenerated_size & 0x0f);
        const high: u8 = @intCast(regenerated_size >> 4);
        try out.append(allocator, kind_bits | (1 << 2) | (low << 4));
        try out.append(allocator, high);
    } else {
        const low: u8 = @intCast(regenerated_size & 0x0f);
        const mid: u8 = @intCast((regenerated_size >> 4) & 0xff);
        const high: u8 = @intCast(regenerated_size >> 12);
        try out.append(allocator, kind_bits | (3 << 2) | (low << 4));
        try out.append(allocator, mid);
        try out.append(allocator, high);
    }
}

fn literalsHeaderLen(regenerated_size: usize) Error!usize {
    if (regenerated_size > std.math.maxInt(u20)) return error.IntegerOverflow;
    if (regenerated_size <= 31) return 1;
    if (regenerated_size <= 4095) return 2;
    return 3;
}

fn emitRawBlock(allocator: std.mem.Allocator, out: *std.ArrayList(u8), block: []const u8, last: bool) Error!void {
    try emitBlockHeader(allocator, out, 0, block.len, last);
    try out.appendSlice(allocator, block);
}

fn emitRleBlock(allocator: std.mem.Allocator, out: *std.ArrayList(u8), byte: u8, len: usize, last: bool) Error!void {
    try emitBlockHeader(allocator, out, 1, len, last);
    try out.append(allocator, byte);
}

fn emitBlockHeader(allocator: std.mem.Allocator, out: *std.ArrayList(u8), block_type: u32, block_len: usize, last: bool) Error!void {
    if (block_len > std.compress.zstd.block_size_max) return error.IntegerOverflow;
    const header_value: u32 = (@as(u32, @intCast(block_len)) << 3) |
        (block_type << 1) |
        @as(u32, if (last) 1 else 0);
    const header: [3]u8 = .{
        @truncate(header_value),
        @truncate(header_value >> 8),
        @truncate(header_value >> 16),
    };
    try out.appendSlice(allocator, &header);
}

fn checkedUsizeToU64(value: usize) Error!u64 {
    return std.math.cast(u64, value) orelse error.IntegerOverflow;
}

fn checkedUsizeToU32(value: usize) Error!u32 {
    return std.math.cast(u32, value) orelse error.IntegerOverflow;
}

fn checkedU64ToUsize(value: u64) Error!usize {
    return std.math.cast(usize, value) orelse error.IntegerOverflow;
}

test "zstd lib encoder round trips and compresses repeated payloads" {
    const payload = "zstd payload zstd payload zstd payload zstd payload";
    const encoded = try encodeFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);
    const decoded = try decodeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    try std.testing.expect(encoded.len < payload.len);
}

test "zstd lib encoder frame options omit content size" {
    const payload = "zstd lib frame options payload" ** 8;
    const encoded = try encodeFrameWithOptionsAlloc(std.testing.allocator, payload, .{
        .include_content_size = false,
        .content_checksum = true,
    });
    defer std.testing.allocator.free(encoded);

    try std.testing.expectEqual(zstd_content_size_unknown, ZSTD_getFrameContentSize(@ptrCast(encoded.ptr), encoded.len));

    const decoded = try decodeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);

    const default_encoded = try encodeFrameWithLevelAndOptionsAlloc(std.testing.allocator, payload, default_compression_level, .{});
    defer std.testing.allocator.free(default_encoded);
    try std.testing.expectEqual(@as(c_ulonglong, payload.len), ZSTD_getFrameContentSize(@ptrCast(default_encoded.ptr), default_encoded.len));
}

test "zstd lib decoder enforces allocation limits" {
    const payload = "zstd limited decode payload" ** 8;

    const known_size = try encodeFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(known_size);
    try std.testing.expectEqual(payload.len, try decodedFrameSize(known_size));
    try std.testing.expectEqual(payload.len, try decodedFrameSizeLimited(known_size, payload.len));
    try std.testing.expectError(error.OutputLimitExceeded, decodedFrameSizeLimited(known_size, payload.len - 1));
    const known_decoded = try decodeFrameAllocLimited(std.testing.allocator, known_size, payload.len);
    defer std.testing.allocator.free(known_decoded);
    try std.testing.expectEqualSlices(u8, payload, known_decoded);
    try std.testing.expectError(error.OutputLimitExceeded, decodeFrameAllocLimited(std.testing.allocator, known_size, payload.len - 1));
    var known_into_buffer: [payload.len]u8 = undefined;
    const known_written = try decodeFrameInto(known_size, &known_into_buffer);
    try std.testing.expectEqual(payload.len, known_written);
    try std.testing.expectEqualSlices(u8, payload, known_into_buffer[0..known_written]);
    try std.testing.expectError(error.OutputTooSmall, decodeFrameInto(known_size, known_into_buffer[0 .. known_into_buffer.len - 1]));

    const no_size = try encodeFrameWithOptionsAlloc(std.testing.allocator, payload, .{ .include_content_size = false });
    defer std.testing.allocator.free(no_size);
    const no_size_bound = try decodedFrameSize(no_size);
    try std.testing.expect(no_size_bound >= payload.len);
    try std.testing.expectEqual(no_size_bound, try decodedFrameSizeLimited(no_size, no_size_bound));
    try std.testing.expectError(error.OutputLimitExceeded, decodedFrameSizeLimited(no_size, no_size_bound - 1));
    const no_size_decoded = try decodeFrameAllocLimited(std.testing.allocator, no_size, payload.len);
    defer std.testing.allocator.free(no_size_decoded);
    try std.testing.expectEqualSlices(u8, payload, no_size_decoded);
    try std.testing.expectError(error.OutputLimitExceeded, decodeFrameAllocLimited(std.testing.allocator, no_size, payload.len - 1));
    const no_size_into_buffer = try std.testing.allocator.alloc(u8, no_size_bound);
    defer std.testing.allocator.free(no_size_into_buffer);
    const no_size_written = try decodeFrameInto(no_size, no_size_into_buffer);
    try std.testing.expectEqual(payload.len, no_size_written);
    try std.testing.expectEqualSlices(u8, payload, no_size_into_buffer[0..no_size_written]);
    try std.testing.expectError(error.OutputTooSmall, decodeFrameInto(no_size, no_size_into_buffer[0 .. payload.len - 1]));
}

test "zstd raw/RLE frame writer round trips through std decompressor" {
    const payload = "zstd raw block payload zstd raw block payload";
    const encoded = try encodeRawOrRleFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);
    const decoded = try decodeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    const native_decoded = try decodeRawOrRleFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(native_decoded);
    try std.testing.expectEqualSlices(u8, payload, native_decoded);
    try std.testing.expectEqual(payload.len, try decodedRawOrRleFrameSize(encoded));
    const no_checksum = try encodeRawOrRleFrameWithOptionsAlloc(std.testing.allocator, payload, .{ .content_checksum = false });
    defer std.testing.allocator.free(no_checksum);
    try std.testing.expectEqual(@as(u8, 0x20), no_checksum[4]);
    const no_checksum_decoded = try decodeNativeFrameAlloc(std.testing.allocator, no_checksum);
    defer std.testing.allocator.free(no_checksum_decoded);
    try std.testing.expectEqualSlices(u8, payload, no_checksum_decoded);
    const no_size = try encodeRawOrRleFrameWithOptionsAlloc(std.testing.allocator, payload, .{ .include_content_size = false });
    defer std.testing.allocator.free(no_size);
    try std.testing.expectEqual(@as(u8, 0x04), no_size[4]);
    const no_size_decoded = try decodeNativeFrameAlloc(std.testing.allocator, no_size);
    defer std.testing.allocator.free(no_size_decoded);
    try std.testing.expectEqualSlices(u8, payload, no_size_decoded);
    const limited_decoded = try decodeRawOrRleFrameAllocLimited(std.testing.allocator, encoded, payload.len);
    defer std.testing.allocator.free(limited_decoded);
    try std.testing.expectEqualSlices(u8, payload, limited_decoded);
    try std.testing.expectError(
        error.OutputLimitExceeded,
        decodeRawOrRleFrameAllocLimited(std.testing.allocator, encoded, payload.len - 1),
    );
    var into_buffer: [payload.len]u8 = undefined;
    const into_written = try decodeRawOrRleFrameInto(encoded, &into_buffer);
    try std.testing.expectEqual(payload.len, into_written);
    try std.testing.expectEqualSlices(u8, payload, into_buffer[0..into_written]);
    try std.testing.expectError(error.OutputTooSmall, decodeRawOrRleFrameInto(encoded, into_buffer[0 .. into_buffer.len - 1]));
    try std.testing.expectEqual(@as(u8, 0x24), encoded[4]);
    try std.testing.expectEqual(@as(u8, payload.len), encoded[5]);

    const repeated = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
    const rle_encoded = try encodeRawOrRleFrameAlloc(std.testing.allocator, repeated);
    defer std.testing.allocator.free(rle_encoded);
    try std.testing.expect(rle_encoded.len < repeated.len);
    var rle_block_offset: usize = 4;
    _ = try parseRawOrRleFrameHeader(rle_encoded, &rle_block_offset);
    const first_block_header = std.mem.readInt(u24, rle_encoded[rle_block_offset..][0..3], .little);
    try std.testing.expectEqual(@as(u24, 1), (first_block_header >> 1) & 0x3);
    const rle_decoded = try decodeFrameAlloc(std.testing.allocator, rle_encoded);
    defer std.testing.allocator.free(rle_decoded);
    try std.testing.expectEqualSlices(u8, repeated, rle_decoded);
    const native_rle_decoded = try decodeRawOrRleFrameAlloc(std.testing.allocator, rle_encoded);
    defer std.testing.allocator.free(native_rle_decoded);
    try std.testing.expectEqualSlices(u8, repeated, native_rle_decoded);
    var rle_into_buffer: [repeated.len]u8 = undefined;
    const rle_into_written = try decodeNativeFrameInto(rle_encoded, &rle_into_buffer);
    try std.testing.expectEqual(repeated.len, rle_into_written);
    try std.testing.expectEqualSlices(u8, repeated, rle_into_buffer[0..rle_into_written]);
}

test "zstd raw/RLE native decoder handles skippable and concatenated frames" {
    const first = try encodeRawOrRleFrameAlloc(std.testing.allocator, "first");
    defer std.testing.allocator.free(first);
    const second = try encodeRawOrRleFrameAlloc(std.testing.allocator, "second");
    defer std.testing.allocator.free(second);

    var stream: std.ArrayList(u8) = .empty;
    defer stream.deinit(std.testing.allocator);
    try stream.appendSlice(std.testing.allocator, first);
    var skippable_header: [8]u8 = undefined;
    std.mem.writeInt(u32, skippable_header[0..4], skippable_magic_min + 3, .little);
    std.mem.writeInt(u32, skippable_header[4..8], 5, .little);
    try stream.appendSlice(std.testing.allocator, &skippable_header);
    try stream.appendSlice(std.testing.allocator, "noise");
    try stream.appendSlice(std.testing.allocator, second);

    const decoded = try decodeRawOrRleFrameAlloc(std.testing.allocator, stream.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "firstsecond", decoded);

    var into_buffer: ["firstsecond".len]u8 = undefined;
    const written = try decodeRawOrRleFrameInto(stream.items, &into_buffer);
    try std.testing.expectEqual(@as(usize, "firstsecond".len), written);
    try std.testing.expectEqualSlices(u8, "firstsecond", into_buffer[0..written]);
}

test "zstd skippable frame writer composes with native streams" {
    const first = try encodeRawOrRleFrameAlloc(std.testing.allocator, "first");
    defer std.testing.allocator.free(first);
    const skip = try encodeSkippableFrameAlloc(std.testing.allocator, 9, "metadata");
    defer std.testing.allocator.free(skip);
    const second = try encodeLiteralOnlyFrameAlloc(std.testing.allocator, "second");
    defer std.testing.allocator.free(second);

    var stream: std.ArrayList(u8) = .empty;
    defer stream.deinit(std.testing.allocator);
    try stream.appendSlice(std.testing.allocator, first);
    try stream.appendSlice(std.testing.allocator, skip);
    try stream.appendSlice(std.testing.allocator, second);

    try std.testing.expectEqual(skippable_magic_min + 9, std.mem.readInt(u32, skip[0..4], .little));
    try std.testing.expectEqual(@as(u32, "metadata".len), std.mem.readInt(u32, skip[4..8], .little));
    try std.testing.expectEqualSlices(u8, "metadata", skip[8..]);

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, stream.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "firstsecond", decoded);
}

test "zstd raw/RLE native decoder accepts no-size raw frames" {
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    try frame.appendSlice(std.testing.allocator, &frame_magic);
    try frame.append(std.testing.allocator, 0x00); // no checksum, no content size, window descriptor follows
    try frame.append(std.testing.allocator, 0x00); // 1 KiB window, enough for the small raw block
    try emitRawBlock(std.testing.allocator, &frame, "abc", true);

    const decoded = try decodeRawOrRleFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "abc", decoded);

    var into_buffer: [3]u8 = undefined;
    const written = try decodeRawOrRleFrameInto(frame.items, &into_buffer);
    try std.testing.expectEqual(@as(usize, 3), written);
    try std.testing.expectEqualSlices(u8, "abc", into_buffer[0..written]);
}

test "zstd native no-size writer chooses valid window descriptors" {
    const cases = [_]struct {
        len: usize,
        expected_descriptor: u8,
    }{
        .{ .len = 0, .expected_descriptor = 0x00 },
        .{ .len = 1024, .expected_descriptor = 0x00 },
        .{ .len = 1025, .expected_descriptor = 0x01 },
        .{ .len = 1152, .expected_descriptor = 0x01 },
        .{ .len = 2048, .expected_descriptor = 0x08 },
        .{ .len = 4096, .expected_descriptor = 0x10 },
        .{ .len = 128 * 1024, .expected_descriptor = 0x38 },
        .{ .len = 132 * 1024, .expected_descriptor = 0x39 },
    };

    for (cases) |case| {
        const payload = try std.testing.allocator.alloc(u8, case.len);
        defer std.testing.allocator.free(payload);
        @memset(payload, 'w');

        const encoded = try encodeRawOrRleFrameWithOptionsAlloc(
            std.testing.allocator,
            payload,
            .{ .include_content_size = false, .content_checksum = false },
        );
        defer std.testing.allocator.free(encoded);
        try std.testing.expectEqual(@as(u8, 0x00), encoded[4]);
        try std.testing.expectEqual(case.expected_descriptor, encoded[5]);

        const decoded = try decodeNativeFrameAlloc(std.testing.allocator, encoded);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, payload, decoded);
    }

    const multi_block_payload = try std.testing.allocator.alloc(u8, std.compress.zstd.block_size_max + 4096);
    defer std.testing.allocator.free(multi_block_payload);
    @memset(multi_block_payload, 'm');
    const multi_block = try encodeRawOrRleFrameWithOptionsAlloc(
        std.testing.allocator,
        multi_block_payload,
        .{ .include_content_size = false, .content_checksum = false },
    );
    defer std.testing.allocator.free(multi_block);
    try std.testing.expectEqual(@as(u8, 0x00), multi_block[4]);
    try std.testing.expectEqual(@as(u8, 0x39), multi_block[5]);
    const first_block_header = std.mem.readInt(u24, multi_block[6..][0..3], .little);
    try std.testing.expectEqual(@as(u24, std.compress.zstd.block_size_max), first_block_header >> 3);
    try std.testing.expectEqual(false, (first_block_header & 1) != 0);
    const decoded_multi = try decodeNativeFrameAlloc(std.testing.allocator, multi_block);
    defer std.testing.allocator.free(decoded_multi);
    try std.testing.expectEqualSlices(u8, multi_block_payload, decoded_multi);
}

test "zstd native decoder accepts literal-only compressed blocks" {
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    try emitFrameHeader(std.testing.allocator, &frame, 4, .{});
    try emitBlockHeader(std.testing.allocator, &frame, 2, 3, true);
    try frame.append(std.testing.allocator, (4 << 3) | 1); // RLE literals, one-byte size field, regenerated size=4
    try frame.append(std.testing.allocator, 'z');
    try frame.append(std.testing.allocator, 0); // sequence_count=0, so the block is literals-only
    var checksum: [4]u8 = undefined;
    std.mem.writeInt(u32, &checksum, @truncate(std.hash.XxHash64.hash(0, "zzzz")), .little);
    try frame.appendSlice(std.testing.allocator, &checksum);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, "zzzz", std_decoded);

    const native_decoded = try decodeNativeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(native_decoded);
    try std.testing.expectEqualSlices(u8, "zzzz", native_decoded);

    var into_buffer: [4]u8 = undefined;
    const written = try decodeNativeFrameInto(frame.items, &into_buffer);
    try std.testing.expectEqual(@as(usize, 4), written);
    try std.testing.expectEqualSlices(u8, "zzzz", into_buffer[0..written]);

    const limited = try decodeNativeFrameAllocLimited(std.testing.allocator, frame.items, 4);
    defer std.testing.allocator.free(limited);
    try std.testing.expectEqualSlices(u8, "zzzz", limited);
    try std.testing.expectError(error.OutputLimitExceeded, decodeNativeFrameAllocLimited(std.testing.allocator, frame.items, 3));
}

test "zstd native decoder accepts extended zero sequence counts" {
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    try emitFrameHeader(std.testing.allocator, &frame, 5, .{ .content_checksum = false });
    try emitBlockHeader(std.testing.allocator, &frame, 2, 4, true);
    try frame.append(std.testing.allocator, (5 << 3) | 1); // RLE literals, regenerated size=5.
    try frame.append(std.testing.allocator, 'z');
    try frame.appendSlice(std.testing.allocator, &.{ 0x80, 0x00 }); // two-byte encoding of sequence_count=0.

    const native_decoded = try decodeNativeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(native_decoded);
    try std.testing.expectEqualSlices(u8, "zzzzz", native_decoded);

    var into_buffer: [5]u8 = undefined;
    const written = try decodeNativeFrameInto(frame.items, &into_buffer);
    try std.testing.expectEqual(@as(usize, 5), written);
    try std.testing.expectEqualSlices(u8, "zzzzz", into_buffer[0..written]);

    const decoded_len = try decodedRawOrRleFrameSize(frame.items);
    try std.testing.expectEqual(@as(usize, 5), decoded_len);
}

test "zstd native decoder accepts RLE sequence compressed blocks" {
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    try emitFrameHeader(std.testing.allocator, &frame, 14, .{});
    try emitBlockHeader(std.testing.allocator, &frame, 2, 8, true);
    try frame.append(std.testing.allocator, (1 << 3) | 1); // RLE literals: one literal byte seeds the repeated match.
    try frame.append(std.testing.allocator, 'a');
    try frame.append(std.testing.allocator, 1); // one sequence.
    try frame.append(std.testing.allocator, 0x54); // LL, offset, and ML all use RLE_Mode.
    try frame.appendSlice(std.testing.allocator, &.{ 1, 0, 10 }); // literal_len=1, repeated offset code 0, match_len=13.
    try frame.append(std.testing.allocator, 1); // Minimal reverse bitstream end mark; RLE modes need no payload bits.
    var checksum: [4]u8 = undefined;
    std.mem.writeInt(u32, &checksum, @truncate(std.hash.XxHash64.hash(0, "aaaaaaaaaaaaaa")), .little);
    try frame.appendSlice(std.testing.allocator, &checksum);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, "aaaaaaaaaaaaaa", std_decoded);

    const native_decoded = try decodeNativeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(native_decoded);
    try std.testing.expectEqualSlices(u8, "aaaaaaaaaaaaaa", native_decoded);

    var into_buffer: [14]u8 = undefined;
    const written = try decodeNativeFrameInto(frame.items, &into_buffer);
    try std.testing.expectEqual(@as(usize, 14), written);
    try std.testing.expectEqualSlices(u8, "aaaaaaaaaaaaaa", into_buffer[0..written]);

    const decoded_len = try decodedRawOrRleFrameSize(frame.items);
    try std.testing.expectEqual(@as(usize, 14), decoded_len);
    try std.testing.expectError(error.OutputLimitExceeded, decodeNativeFrameAllocLimited(std.testing.allocator, frame.items, 13));
}

test "zstd native decoder reads RLE sequence additional bits" {
    const payload = "a" ** 37;
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    try emitFrameHeader(std.testing.allocator, &frame, payload.len, .{});
    try emitBlockHeader(std.testing.allocator, &frame, 2, 8, true);
    try frame.append(std.testing.allocator, (1 << 3) | 1); // RLE literals: one literal byte seeds the repeated match.
    try frame.append(std.testing.allocator, 'a');
    try frame.append(std.testing.allocator, 1); // one sequence.
    try frame.append(std.testing.allocator, 0x54); // LL, offset, and ML all use RLE_Mode.
    try frame.appendSlice(std.testing.allocator, &.{ 1, 0, 32 }); // ML code 32 has one additional bit over base length 35.
    try frame.append(std.testing.allocator, 0x03); // Reverse bitstream: payload bit=1 followed by the end mark.
    var checksum: [4]u8 = undefined;
    std.mem.writeInt(u32, &checksum, @truncate(std.hash.XxHash64.hash(0, payload)), .little);
    try frame.appendSlice(std.testing.allocator, &checksum);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, payload, std_decoded);

    const native_decoded = try decodeNativeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(native_decoded);
    try std.testing.expectEqualSlices(u8, payload, native_decoded);

    var into_buffer: [payload.len]u8 = undefined;
    const written = try decodeNativeFrameInto(frame.items, &into_buffer);
    try std.testing.expectEqual(payload.len, written);
    try std.testing.expectEqualSlices(u8, payload, into_buffer[0..written]);
}

test "zstd native decoder repeats RLE sequence tables across compressed blocks" {
    const payload = "a" ** 8;
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    try emitFrameHeader(std.testing.allocator, &frame, payload.len, .{});

    try emitBlockHeader(std.testing.allocator, &frame, 2, 8, false);
    try frame.append(std.testing.allocator, (1 << 3) | 1); // RLE literals: one literal byte seeds the match.
    try frame.append(std.testing.allocator, 'a');
    try frame.append(std.testing.allocator, 1); // one sequence.
    try frame.append(std.testing.allocator, 0x54); // LL, offset, and ML all use RLE_Mode.
    try frame.appendSlice(std.testing.allocator, &.{ 1, 0, 0 }); // literal_len=1, repeated offset code 0, match_len=3.
    try frame.append(std.testing.allocator, 1); // Minimal reverse bitstream end mark.

    try emitBlockHeader(std.testing.allocator, &frame, 2, 5, true);
    try frame.append(std.testing.allocator, (1 << 3) | 1);
    try frame.append(std.testing.allocator, 'a');
    try frame.append(std.testing.allocator, 1);
    try frame.append(std.testing.allocator, 0xfc); // Repeat_Mode for all sequence tables; no table payload follows.
    try frame.append(std.testing.allocator, 1);

    var checksum: [4]u8 = undefined;
    std.mem.writeInt(u32, &checksum, @truncate(std.hash.XxHash64.hash(0, payload)), .little);
    try frame.appendSlice(std.testing.allocator, &checksum);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, payload, std_decoded);

    const native_decoded = try decodeNativeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(native_decoded);
    try std.testing.expectEqualSlices(u8, payload, native_decoded);

    var into_buffer: [payload.len]u8 = undefined;
    const written = try decodeNativeFrameInto(frame.items, &into_buffer);
    try std.testing.expectEqual(payload.len, written);
    try std.testing.expectEqualSlices(u8, payload, into_buffer[0..written]);

    const decoded_len = try decodedRawOrRleFrameSize(frame.items);
    try std.testing.expectEqual(payload.len, decoded_len);

    var first_block_repeat: std.ArrayList(u8) = .empty;
    defer first_block_repeat.deinit(std.testing.allocator);
    try emitFrameHeader(std.testing.allocator, &first_block_repeat, 4, .{ .content_checksum = false });
    try emitBlockHeader(std.testing.allocator, &first_block_repeat, 2, 5, true);
    try first_block_repeat.append(std.testing.allocator, (1 << 3) | 1);
    try first_block_repeat.append(std.testing.allocator, 'a');
    try first_block_repeat.append(std.testing.allocator, 1);
    try first_block_repeat.append(std.testing.allocator, 0xfc);
    try first_block_repeat.append(std.testing.allocator, 1);
    try std.testing.expectError(error.CorruptFrame, decodeNativeFrameAlloc(std.testing.allocator, first_block_repeat.items));
}

test "zstd native decoder reads RLE offset additional bits" {
    const payload = "a" ** 14;
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    try emitFrameHeader(std.testing.allocator, &frame, payload.len, .{});
    try emitBlockHeader(std.testing.allocator, &frame, 2, 8, true);
    try frame.append(std.testing.allocator, (1 << 3) | 1); // RLE literals: one byte of history is enough for offset=1.
    try frame.append(std.testing.allocator, 'a');
    try frame.append(std.testing.allocator, 1);
    try frame.append(std.testing.allocator, 0x54); // LL, offset, and ML all use RLE_Mode.
    try frame.appendSlice(std.testing.allocator, &.{ 1, 2, 10 }); // Offset code 2 consumes two additional bits.
    try frame.append(std.testing.allocator, 0x04); // Reverse bitstream: offset extra bits=0, then end mark.
    var checksum: [4]u8 = undefined;
    std.mem.writeInt(u32, &checksum, @truncate(std.hash.XxHash64.hash(0, payload)), .little);
    try frame.appendSlice(std.testing.allocator, &checksum);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, payload, std_decoded);

    const native_decoded = try decodeNativeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(native_decoded);
    try std.testing.expectEqualSlices(u8, payload, native_decoded);

    var into_buffer: [payload.len]u8 = undefined;
    const written = try decodeNativeFrameInto(frame.items, &into_buffer);
    try std.testing.expectEqual(payload.len, written);
    try std.testing.expectEqualSlices(u8, payload, into_buffer[0..written]);
}

test "zstd native decoder accepts multiple RLE sequences" {
    const payload = "a" ** 8;
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    try emitFrameHeader(std.testing.allocator, &frame, payload.len, .{});
    try emitBlockHeader(std.testing.allocator, &frame, 2, 8, true);
    try frame.append(std.testing.allocator, (2 << 3) | 1); // Two regenerated RLE literals; each sequence consumes one.
    try frame.append(std.testing.allocator, 'a');
    try frame.append(std.testing.allocator, 2); // two sequences using the same RLE-coded symbol values.
    try frame.append(std.testing.allocator, 0x54); // LL, offset, and ML all use RLE_Mode.
    try frame.appendSlice(std.testing.allocator, &.{ 1, 0, 0 }); // literal_len=1, repeated offset code 0, match_len=3.
    try frame.append(std.testing.allocator, 1);
    var checksum: [4]u8 = undefined;
    std.mem.writeInt(u32, &checksum, @truncate(std.hash.XxHash64.hash(0, payload)), .little);
    try frame.appendSlice(std.testing.allocator, &checksum);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, payload, std_decoded);

    const native_decoded = try decodeNativeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(native_decoded);
    try std.testing.expectEqualSlices(u8, payload, native_decoded);

    var into_buffer: [payload.len]u8 = undefined;
    const written = try decodeNativeFrameInto(frame.items, &into_buffer);
    try std.testing.expectEqual(payload.len, written);
    try std.testing.expectEqualSlices(u8, payload, into_buffer[0..written]);

    const decoded_len = try decodedRawOrRleFrameSize(frame.items);
    try std.testing.expectEqual(payload.len, decoded_len);
}

test "zstd native decoder accepts minimal predefined sequence block" {
    const payload = "a" ** 132;
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    try emitFrameHeader(std.testing.allocator, &frame, payload.len, .{});
    try emitBlockHeader(std.testing.allocator, &frame, 2, 8, true);
    try frame.append(std.testing.allocator, (1 << 3) | 1); // RLE literals: one literal byte before the match.
    try frame.append(std.testing.allocator, 'a');
    try frame.append(std.testing.allocator, 1); // one sequence.
    try frame.append(std.testing.allocator, 0); // LL, offset, and ML all use Predefined_Mode.
    // Reverse bitstream layout: LL state=2, OF state=0, ML state=20, then
    // seven zero ML extra bits and the end mark. This is intentionally the
    // smallest predefined-table slice Vort recognizes before full FSE support.
    try frame.appendSlice(std.testing.allocator, &.{ 0x00, 0x0a, 0x08, 0x01 });
    var checksum: [4]u8 = undefined;
    std.mem.writeInt(u32, &checksum, @truncate(std.hash.XxHash64.hash(0, payload)), .little);
    try frame.appendSlice(std.testing.allocator, &checksum);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, payload, std_decoded);

    const native_decoded = try decodeNativeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(native_decoded);
    try std.testing.expectEqualSlices(u8, payload, native_decoded);

    var into_buffer: [payload.len]u8 = undefined;
    const written = try decodeNativeFrameInto(frame.items, &into_buffer);
    try std.testing.expectEqual(payload.len, written);
    try std.testing.expectEqualSlices(u8, payload, into_buffer[0..written]);

    const decoded_len = try decodedRawOrRleFrameSize(frame.items);
    try std.testing.expectEqual(payload.len, decoded_len);
}

test "zstd native decoder accepts multiple predefined sequences" {
    const payload = "a" ** 18;
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    try emitFrameHeader(std.testing.allocator, &frame, payload.len, .{});
    try emitBlockHeader(std.testing.allocator, &frame, 2, 9, true);
    try frame.append(std.testing.allocator, (2 << 3) | 1); // RLE literals: both sequences consume one literal.
    try frame.append(std.testing.allocator, 'a');
    try frame.append(std.testing.allocator, 2);
    try frame.append(std.testing.allocator, 0); // LL, offset, and ML all use Predefined_Mode.
    // Initial states decode to literal_len=1, offset=1, match_len=3. The state
    // update bits then select another literal_len=1, offset=1, and match_len=13
    // for the second sequence. This keeps the fixture small while exercising
    // predefined-table state transitions in the native decoder.
    try frame.appendSlice(std.testing.allocator, &.{ 0x00, 0x60, 0x07, 0x10, 0x02 });
    var checksum: [4]u8 = undefined;
    std.mem.writeInt(u32, &checksum, @truncate(std.hash.XxHash64.hash(0, payload)), .little);
    try frame.appendSlice(std.testing.allocator, &checksum);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, payload, std_decoded);

    const native_decoded = try decodeNativeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(native_decoded);
    try std.testing.expectEqualSlices(u8, payload, native_decoded);

    var into_buffer: [payload.len]u8 = undefined;
    const written = try decodeNativeFrameInto(frame.items, &into_buffer);
    try std.testing.expectEqual(payload.len, written);
    try std.testing.expectEqualSlices(u8, payload, into_buffer[0..written]);

    const decoded_len = try decodedRawOrRleFrameSize(frame.items);
    try std.testing.expectEqual(payload.len, decoded_len);
}

test "zstd native decoder streams several predefined sequences" {
    const payload = "a" ** 30;
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    try emitFrameHeader(std.testing.allocator, &frame, payload.len, .{});
    try emitBlockHeader(std.testing.allocator, &frame, 2, 14, true);
    try frame.append(std.testing.allocator, (5 << 3) | 1); // Five regenerated RLE literals feed five sequences.
    try frame.append(std.testing.allocator, 'a');
    try frame.append(std.testing.allocator, 5);
    try frame.append(std.testing.allocator, 0); // LL, offset, and ML all use Predefined_Mode.
    // Repeats the small LL state cycle 2 -> 44 -> 23 -> 2 while keeping OF/ML
    // states simple. The decoder now streams sequences directly into the
    // output/preflight paths instead of materializing a scratch sequence list.
    try frame.appendSlice(std.testing.allocator, &.{ 0x00, 0x60, 0x00, 0x10, 0x00, 0x1c, 0x00, 0xd8, 0x01, 0x84 });
    var checksum: [4]u8 = undefined;
    std.mem.writeInt(u32, &checksum, @truncate(std.hash.XxHash64.hash(0, payload)), .little);
    try frame.appendSlice(std.testing.allocator, &checksum);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, payload, std_decoded);

    const native_decoded = try decodeNativeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(native_decoded);
    try std.testing.expectEqualSlices(u8, payload, native_decoded);

    var into_buffer: [payload.len]u8 = undefined;
    const written = try decodeNativeFrameInto(frame.items, &into_buffer);
    try std.testing.expectEqual(payload.len, written);
    try std.testing.expectEqualSlices(u8, payload, into_buffer[0..written]);

    const decoded_len = try decodedRawOrRleFrameSize(frame.items);
    try std.testing.expectEqual(payload.len, decoded_len);
}

test "zstd native decoder accepts mixed RLE and predefined sequence modes" {
    const payload = "a" ** 132;
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    try emitFrameHeader(std.testing.allocator, &frame, payload.len, .{});
    try emitBlockHeader(std.testing.allocator, &frame, 2, 8, true);
    try frame.append(std.testing.allocator, (1 << 3) | 1); // RLE literals: one literal byte before the match.
    try frame.append(std.testing.allocator, 'a');
    try frame.append(std.testing.allocator, 1);
    try frame.append(std.testing.allocator, 0x50); // LL and offset use RLE_Mode; ML uses Predefined_Mode.
    try frame.appendSlice(std.testing.allocator, &.{ 1, 0 }); // literal_len=1, repeated offset code 0.
    try frame.appendSlice(std.testing.allocator, &.{ 0x00, 0x2a }); // ML predefined state 20 plus seven zero extra bits.
    var checksum: [4]u8 = undefined;
    std.mem.writeInt(u32, &checksum, @truncate(std.hash.XxHash64.hash(0, payload)), .little);
    try frame.appendSlice(std.testing.allocator, &checksum);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, payload, std_decoded);

    const native_decoded = try decodeNativeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(native_decoded);
    try std.testing.expectEqualSlices(u8, payload, native_decoded);

    var into_buffer: [payload.len]u8 = undefined;
    const written = try decodeNativeFrameInto(frame.items, &into_buffer);
    try std.testing.expectEqual(payload.len, written);
    try std.testing.expectEqualSlices(u8, payload, into_buffer[0..written]);

    const decoded_len = try decodedRawOrRleFrameSize(frame.items);
    try std.testing.expectEqual(payload.len, decoded_len);
}

test "zstd native decoder repeats mixed sequence tables across compressed blocks" {
    const payload = "a" ** 264;
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    try emitFrameHeader(std.testing.allocator, &frame, payload.len, .{ .content_checksum = false });

    try emitBlockHeader(std.testing.allocator, &frame, 2, 8, false);
    try frame.append(std.testing.allocator, (1 << 3) | 1);
    try frame.append(std.testing.allocator, 'a');
    try frame.append(std.testing.allocator, 1);
    try frame.append(std.testing.allocator, 0x50); // LL/OF are RLE tables; ML uses the default predefined table.
    try frame.appendSlice(std.testing.allocator, &.{ 1, 0 });
    try frame.appendSlice(std.testing.allocator, &.{ 0x00, 0x2a });

    try emitBlockHeader(std.testing.allocator, &frame, 2, 6, true);
    try frame.append(std.testing.allocator, (1 << 3) | 1);
    try frame.append(std.testing.allocator, 'a');
    try frame.append(std.testing.allocator, 1);
    try frame.append(std.testing.allocator, 0xfc); // Repeat_Mode for LL, OF, and ML.
    try frame.appendSlice(std.testing.allocator, &.{ 0x00, 0x2a });

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, payload, std_decoded);

    const native_decoded = try decodeNativeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(native_decoded);
    try std.testing.expectEqualSlices(u8, payload, native_decoded);

    var into_buffer: [payload.len]u8 = undefined;
    const written = try decodeNativeFrameInto(frame.items, &into_buffer);
    try std.testing.expectEqual(payload.len, written);
    try std.testing.expectEqualSlices(u8, payload, into_buffer[0..written]);

    const decoded_len = try decodedRawOrRleFrameSize(frame.items);
    try std.testing.expectEqual(payload.len, decoded_len);
}

test "zstd literal-only compressed block rejects malformed sections" {
    var non_zero_sequences: std.ArrayList(u8) = .empty;
    defer non_zero_sequences.deinit(std.testing.allocator);
    try emitFrameHeader(std.testing.allocator, &non_zero_sequences, 3, .{});
    try emitBlockHeader(std.testing.allocator, &non_zero_sequences, 2, 6, true);
    try non_zero_sequences.append(std.testing.allocator, 3 << 3);
    try non_zero_sequences.appendSlice(std.testing.allocator, "abc");
    try non_zero_sequences.appendSlice(std.testing.allocator, &.{ 1, 0x40 }); // one sequence, unsupported mixed mode byte
    var checksum: [4]u8 = undefined;
    std.mem.writeInt(u32, &checksum, @truncate(std.hash.XxHash64.hash(0, "abc")), .little);
    try non_zero_sequences.appendSlice(std.testing.allocator, &checksum);
    try std.testing.expectError(error.TruncatedFrame, decodeNativeFrameAlloc(std.testing.allocator, non_zero_sequences.items));

    var trailing_literal_payload: std.ArrayList(u8) = .empty;
    defer trailing_literal_payload.deinit(std.testing.allocator);
    try emitFrameHeader(std.testing.allocator, &trailing_literal_payload, 3, .{});
    try emitBlockHeader(std.testing.allocator, &trailing_literal_payload, 2, 6, true);
    try trailing_literal_payload.append(std.testing.allocator, 3 << 3);
    try trailing_literal_payload.appendSlice(std.testing.allocator, "abcd");
    try trailing_literal_payload.append(std.testing.allocator, 0);
    try trailing_literal_payload.appendSlice(std.testing.allocator, &checksum);
    try std.testing.expectError(error.TruncatedFrame, decodeNativeFrameAlloc(std.testing.allocator, trailing_literal_payload.items));

    var missing_literal_byte: std.ArrayList(u8) = .empty;
    defer missing_literal_byte.deinit(std.testing.allocator);
    try emitFrameHeader(std.testing.allocator, &missing_literal_byte, 3, .{});
    try emitBlockHeader(std.testing.allocator, &missing_literal_byte, 2, 2, true);
    try missing_literal_byte.append(std.testing.allocator, (3 << 3) | 1); // RLE literals need one payload byte.
    try missing_literal_byte.append(std.testing.allocator, 0);
    try missing_literal_byte.appendSlice(std.testing.allocator, &checksum);
    try std.testing.expectError(error.TruncatedFrame, decodeNativeFrameAlloc(std.testing.allocator, missing_literal_byte.items));
}

test "zstd native decoder rejects malformed Huffman literals" {
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    try emitFrameHeader(std.testing.allocator, &frame, 3, .{ .content_checksum = false });
    try emitBlockHeader(std.testing.allocator, &frame, 2, 4, true);
    try frame.appendSlice(std.testing.allocator, &.{ 0x32, 0x40, 0x00 }); // compressed literals: regenerated=3, compressed=1.
    try frame.append(std.testing.allocator, 1);
    try std.testing.expectError(error.TruncatedFrame, decodeNativeFrameAlloc(std.testing.allocator, frame.items));
    var output: [3]u8 = undefined;
    try std.testing.expectError(error.TruncatedFrame, decodeNativeFrameInto(frame.items, &output));
    try std.testing.expectError(error.TruncatedFrame, decodedRawOrRleFrameSize(frame.items));

    var zero_size: std.ArrayList(u8) = .empty;
    defer zero_size.deinit(std.testing.allocator);
    try emitFrameHeader(std.testing.allocator, &zero_size, 3, .{ .content_checksum = false });
    try emitBlockHeader(std.testing.allocator, &zero_size, 2, 3, true);
    try zero_size.appendSlice(std.testing.allocator, &.{ 0x32, 0x00, 0x00 });
    try std.testing.expectError(error.CorruptFrame, decodeNativeFrameAlloc(std.testing.allocator, zero_size.items));

    var treeless_first: std.ArrayList(u8) = .empty;
    defer treeless_first.deinit(std.testing.allocator);
    try emitFrameHeader(std.testing.allocator, &treeless_first, 3, .{ .content_checksum = false });
    try emitBlockHeader(std.testing.allocator, &treeless_first, 2, 4, true);
    try treeless_first.appendSlice(std.testing.allocator, &.{ 0x33, 0x40, 0x00 }); // treeless literals before any Huffman tree.
    try treeless_first.append(std.testing.allocator, 1);
    try std.testing.expectError(error.CorruptFrame, decodeNativeFrameAlloc(std.testing.allocator, treeless_first.items));
}

test "zstd native decoder accepts single-stream Huffman literals" {
    const unit = "{\"key\":\"value\",\"number\":123,\"array\":[1,2,3],\"text\":\"abcdefg\"}\n";
    const payload = unit ** 100;
    const frame_hex =
        "28b52ffd04680d0200e2c30d1290cf016c3325f0fdb0cddd2ce10b3339ce4e20b" ++
        "fb1a5123a279f76cdb7192d3a14f27ba43cef2102b95c08d2f8fea2efd493d" ++
        "fe58e0301007e7f411fa095c60c5d";
    var frame: [frame_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&frame, frame_hex);

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, &frame);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);

    var into_buffer: [payload.len]u8 = undefined;
    const written = try decodeNativeFrameInto(&frame, &into_buffer);
    try std.testing.expectEqual(payload.len, written);
    try std.testing.expectEqualSlices(u8, payload, into_buffer[0..written]);

    const limited = try decodeNativeFrameAllocLimited(std.testing.allocator, &frame, payload.len);
    defer std.testing.allocator.free(limited);
    try std.testing.expectEqualSlices(u8, payload, limited);
    try std.testing.expectError(error.OutputLimitExceeded, decodeNativeFrameAllocLimited(std.testing.allocator, &frame, payload.len - 1));

    const decoded_len = try decodedRawOrRleFrameSize(&frame);
    try std.testing.expectEqual(payload.len, decoded_len);
}

test "zstd native decoder rejects FSE compressed sequence tables" {
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    try emitFrameHeader(std.testing.allocator, &frame, 4, .{ .content_checksum = false });
    try emitBlockHeader(std.testing.allocator, &frame, 2, 5, true);
    try frame.append(std.testing.allocator, 1 << 3); // raw literals, one literal byte.
    try frame.append(std.testing.allocator, 'a');
    try frame.append(std.testing.allocator, 1); // one sequence.
    try frame.append(std.testing.allocator, 0x80); // LL uses FSE_Compressed_Mode; OF/ML are predefined.
    try frame.append(std.testing.allocator, 1);

    try std.testing.expectError(error.UnsupportedZstdFeature, decodeNativeFrameAlloc(std.testing.allocator, frame.items));
    var output: [4]u8 = undefined;
    try std.testing.expectError(error.UnsupportedZstdFeature, decodeNativeFrameInto(frame.items, &output));
    try std.testing.expectError(error.UnsupportedZstdFeature, decodedRawOrRleFrameSize(frame.items));
}

test "zstd literal-only frame writer falls back when compressed literals expand" {
    const payload = "literal-only zstd payload";
    const encoded = try encodeLiteralOnlyFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);

    var block_offset: usize = 4;
    _ = try parseRawOrRleFrameHeader(encoded, &block_offset);
    const block_header = std.mem.readInt(u24, encoded[block_offset..][0..3], .little);
    try std.testing.expectEqual(@as(u24, 0), (block_header >> 1) & 0x3);

    const std_decoded = try decodeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(std_decoded);
    try std.testing.expectEqualSlices(u8, payload, std_decoded);

    const native_decoded = try decodeNativeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(native_decoded);
    try std.testing.expectEqualSlices(u8, payload, native_decoded);

    var into_buffer: [payload.len]u8 = undefined;
    const written = try decodeNativeFrameInto(encoded, &into_buffer);
    try std.testing.expectEqual(payload.len, written);
    try std.testing.expectEqualSlices(u8, payload, into_buffer[0..written]);

    const limited = try decodeNativeFrameAllocLimited(std.testing.allocator, encoded, payload.len);
    defer std.testing.allocator.free(limited);
    try std.testing.expectEqualSlices(u8, payload, limited);

    const no_checksum = try encodeLiteralOnlyFrameWithOptionsAlloc(std.testing.allocator, payload, .{ .content_checksum = false });
    defer std.testing.allocator.free(no_checksum);
    try std.testing.expectEqual(@as(u8, 0x20), no_checksum[4]);
    const no_checksum_decoded = try decodeNativeFrameAlloc(std.testing.allocator, no_checksum);
    defer std.testing.allocator.free(no_checksum_decoded);
    try std.testing.expectEqualSlices(u8, payload, no_checksum_decoded);
}

test "zstd literal-only writer uses RLE literals for repeated blocks" {
    const payload = "zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz";
    const encoded = try encodeLiteralOnlyFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);

    var block_offset: usize = 4;
    _ = try parseRawOrRleFrameHeader(encoded, &block_offset);
    const block_header = std.mem.readInt(u24, encoded[block_offset..][0..3], .little);
    const block_len: usize = @intCast(block_header >> 3);
    try std.testing.expectEqual(@as(u24, 2), (block_header >> 1) & 0x3);
    var frame_state: SequenceFrameState = .{};
    const section = try parseLiteralsSection(encoded[block_offset + 3 ..][0..block_len], &frame_state);
    try std.testing.expectEqual(LiteralsKind.rle, section.kind);

    var into_buffer: [payload.len]u8 = undefined;
    const written = try decodeNativeFrameInto(encoded, &into_buffer);
    try std.testing.expectEqual(payload.len, written);
    try std.testing.expectEqualSlices(u8, payload, into_buffer[0..written]);
}

test "zstd native frame writer chooses smallest fallback mode" {
    const repeated = "zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz";
    const repeated_result = try encodeNativeFrameWithOptionsAlloc(std.testing.allocator, repeated, .{});
    defer std.testing.allocator.free(repeated_result.frame);
    try std.testing.expectEqual(NativeFrameMode.raw_or_rle, repeated_result.mode);
    const repeated_decoded = try decodeNativeFrameAlloc(std.testing.allocator, repeated_result.frame);
    defer std.testing.allocator.free(repeated_decoded);
    try std.testing.expectEqualSlices(u8, repeated, repeated_decoded);

    const literal_payload = "literal-only zstd payload";
    const auto_result = try encodeNativeFrameWithOptionsAlloc(std.testing.allocator, literal_payload, .{});
    defer std.testing.allocator.free(auto_result.frame);
    const forced_literal = try encodeNativeFrameWithOptionsAlloc(std.testing.allocator, literal_payload, .{ .selection = .literal_only });
    defer std.testing.allocator.free(forced_literal.frame);
    try std.testing.expect(auto_result.frame.len <= forced_literal.frame.len);
    try std.testing.expectEqual(NativeFrameMode.literal_only, forced_literal.mode);
    const literal_decoded = try decodeNativeFrameAlloc(std.testing.allocator, forced_literal.frame);
    defer std.testing.allocator.free(literal_decoded);
    try std.testing.expectEqualSlices(u8, literal_payload, literal_decoded);

    const forced_raw = try encodeNativeFrameWithOptionsAlloc(std.testing.allocator, literal_payload, .{ .selection = .raw_or_rle });
    defer std.testing.allocator.free(forced_raw.frame);
    try std.testing.expectEqual(NativeFrameMode.raw_or_rle, forced_raw.mode);

    const no_checksum = try encodeNativeFrameWithOptionsAlloc(std.testing.allocator, literal_payload, .{ .content_checksum = false, .selection = .literal_only });
    defer std.testing.allocator.free(no_checksum.frame);
    try std.testing.expectEqual(@as(u8, 0x20), no_checksum.frame[4]);
    const no_size = try encodeNativeFrameWithOptionsAlloc(std.testing.allocator, literal_payload, .{ .include_content_size = false, .selection = .literal_only });
    defer std.testing.allocator.free(no_size.frame);
    try std.testing.expectEqual(@as(u8, 0x04), no_size.frame[4]);
    const no_size_decoded = try decodeNativeFrameAlloc(std.testing.allocator, no_size.frame);
    defer std.testing.allocator.free(no_size_decoded);
    try std.testing.expectEqualSlices(u8, literal_payload, no_size_decoded);
}

test "zstd raw/RLE native decoder rejects corrupt frames" {
    const payload = "zstd raw/rle corrupt frame payload";
    const encoded = try encodeRawOrRleFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);

    var bad_size = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(bad_size);
    bad_size[5] = @intCast(payload.len + 1);
    try std.testing.expectError(error.SizeMismatch, decodeRawOrRleFrameAlloc(std.testing.allocator, bad_size));

    var bad_checksum = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(bad_checksum);
    bad_checksum[bad_checksum.len - 1] ^= 0x01;
    try std.testing.expectError(error.ChecksumMismatch, decodeRawOrRleFrameAlloc(std.testing.allocator, bad_checksum));

    var compressed_block = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(compressed_block);
    compressed_block[6] = (compressed_block[6] & ~@as(u8, 0x06)) | 0x04;
    try std.testing.expectError(error.TruncatedFrame, decodeRawOrRleFrameAlloc(std.testing.allocator, compressed_block));

    try std.testing.expectError(error.TruncatedFrame, decodeRawOrRleFrameAlloc(std.testing.allocator, encoded[0 .. encoded.len - 1]));
    try std.testing.expectError(error.InvalidMagic, decodeRawOrRleFrameAlloc(std.testing.allocator, "not-zstd"));
}

test "zstd native decoder rejects dictionary id frames without a dictionary" {
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    try frame.appendSlice(std.testing.allocator, &frame_magic);
    try frame.append(std.testing.allocator, 0x21); // 1-byte dictionary id, single-segment, 1-byte content size.
    try frame.append(std.testing.allocator, 7); // Dictionary_ID; native subset has no dictionary API yet.
    try frame.append(std.testing.allocator, 3);
    try emitRawBlock(std.testing.allocator, &frame, "abc", true);

    try std.testing.expectError(error.NeedDictionary, decodeNativeFrameAlloc(std.testing.allocator, frame.items));

    var output: [3]u8 = undefined;
    try std.testing.expectError(error.NeedDictionary, decodeNativeFrameInto(frame.items, &output));
    try std.testing.expectError(error.NeedDictionary, decodedRawOrRleFrameSize(frame.items));

    try std.testing.expectError(error.TruncatedFrame, decodeNativeFrameAlloc(std.testing.allocator, frame.items[0..5]));
}

test "zstd native raw/RLE decoder handles fallback frames and skippable frames" {
    const raw = "raw block payload";
    const raw_encoded = try encodeRawOrRleFrameAlloc(std.testing.allocator, raw);
    defer std.testing.allocator.free(raw_encoded);
    const raw_decoded = try decodeNativeFrameAlloc(std.testing.allocator, raw_encoded);
    defer std.testing.allocator.free(raw_decoded);
    try std.testing.expectEqualSlices(u8, raw, raw_decoded);

    const repeated = "yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy";
    const rle_encoded = try encodeRawOrRleFrameAlloc(std.testing.allocator, repeated);
    defer std.testing.allocator.free(rle_encoded);
    const rle_decoded = try decodeNativeFrameAlloc(std.testing.allocator, rle_encoded);
    defer std.testing.allocator.free(rle_decoded);
    try std.testing.expectEqualSlices(u8, repeated, rle_decoded);

    var concatenated: std.ArrayList(u8) = .empty;
    defer concatenated.deinit(std.testing.allocator);
    try concatenated.appendSlice(std.testing.allocator, raw_encoded);
    try concatenated.appendSlice(std.testing.allocator, &.{ 0x50, 0x2a, 0x4d, 0x18 });
    var skippable_len: [4]u8 = undefined;
    std.mem.writeInt(u32, &skippable_len, 3, .little);
    try concatenated.appendSlice(std.testing.allocator, &skippable_len);
    try concatenated.appendSlice(std.testing.allocator, "pad");
    try concatenated.appendSlice(std.testing.allocator, rle_encoded);
    const concatenated_decoded = try decodeNativeFrameAlloc(std.testing.allocator, concatenated.items);
    defer std.testing.allocator.free(concatenated_decoded);
    try std.testing.expectEqualSlices(u8, raw ++ repeated, concatenated_decoded);
}

test "zstd native decoder accepts simple libzstd predefined frame" {
    const payload = "zstd payload zstd payload zstd payload zstd payload";
    const encoded = try encodeFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);
    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);

    var into_buffer: [payload.len]u8 = undefined;
    const written = try decodeNativeFrameInto(encoded, &into_buffer);
    try std.testing.expectEqual(payload.len, written);
    try std.testing.expectEqualSlices(u8, payload, into_buffer[0..written]);
}
