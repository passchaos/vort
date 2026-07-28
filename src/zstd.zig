const std = @import("std");
const core = @import("core.zig");

pub const Error = core.Error || std.mem.Allocator.Error;

pub const default_compression_level: c_int = 1;

const frame_magic = [_]u8{ 0x28, 0xb5, 0x2f, 0xfd };
const min_rle_split_len = 12;

extern fn ZSTD_compressBound(srcSize: usize) usize;
extern fn ZSTD_compress(dst: *anyopaque, dstCapacity: usize, src: *const anyopaque, srcSize: usize, compressionLevel: c_int) usize;
extern fn ZSTD_getFrameContentSize(src: *const anyopaque, srcSize: usize) c_ulonglong;
extern fn ZSTD_decompress(dst: *anyopaque, dstCapacity: usize, src: *const anyopaque, compressedSize: usize) usize;
extern fn ZSTD_isError(code: usize) c_uint;

const zstd_content_size_unknown = std.math.maxInt(c_ulonglong);
const zstd_content_size_error = std.math.maxInt(c_ulonglong) - 1;

/// Decode a Zstandard frame. Prefer libzstd's one-shot decoder when the
/// content size is present, because MCAP chunks always advertise their decoded
/// size and the one-shot path avoids streaming allocator overhead. Frames with
/// unknown content size still fall back to Zig std's streaming decoder.
pub fn decodeFrameAlloc(allocator: std.mem.Allocator, frame: []const u8) Error![]u8 {
    const content_size = ZSTD_getFrameContentSize(@ptrCast(frame.ptr), frame.len);
    if (content_size == zstd_content_size_error) return error.CorruptFrame;
    if (content_size != zstd_content_size_unknown) {
        const decoded_len = try checkedU64ToUsize(content_size);
        const out = try allocator.alloc(u8, decoded_len);
        errdefer allocator.free(out);
        const written = ZSTD_decompress(@ptrCast(out.ptr), out.len, @ptrCast(frame.ptr), frame.len);
        if (ZSTD_isError(written) != 0) return error.CorruptFrame;
        if (written != decoded_len) return error.SizeMismatch;
        return out;
    }

    var input: std.Io.Reader = .fixed(frame);
    var zstd_stream: std.compress.zstd.Decompress = .init(&input, &.{}, .{});
    var output: std.Io.Writer.Allocating = .init(allocator);
    errdefer output.deinit();
    _ = zstd_stream.reader.streamRemaining(&output.writer) catch return error.CorruptFrame;
    if (zstd_stream.err) |_| return error.CorruptFrame;
    return output.toOwnedSlice() catch |err| switch (err) {
        error.OutOfMemory => error.OutOfMemory,
    };
}

/// Compress a complete Zstandard frame using the reference-compatible libzstd
/// encoder linked by Vort's build. Keeping this call surface in Vort centralizes
/// compression ownership for downstream formats such as MCAP while leaving room
/// to replace the backend with a pure Zig implementation ported from
/// `~/Work/zstd` internals later.
pub fn encodeFrameAlloc(allocator: std.mem.Allocator, input: []const u8) Error![]u8 {
    return try encodeFrameWithLevelAlloc(allocator, input, default_compression_level);
}

pub fn encodeFrameWithLevelAlloc(allocator: std.mem.Allocator, input: []const u8, level: c_int) Error![]u8 {
    const bound = ZSTD_compressBound(input.len);
    if (ZSTD_isError(bound) != 0) return error.CorruptFrame;
    var out = try allocator.alloc(u8, bound);
    errdefer allocator.free(out);

    const written = ZSTD_compress(@ptrCast(out.ptr), out.len, @ptrCast(input.ptr), input.len, level);
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
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try out.appendSlice(allocator, &frame_magic);
    try out.append(allocator, 0xe4); // fcs=8 bytes, single segment, content checksum
    var content_size: [8]u8 = undefined;
    std.mem.writeInt(u64, &content_size, try checkedUsizeToU64(input.len), .little);
    try out.appendSlice(allocator, &content_size);
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
    var checksum: [4]u8 = undefined;
    std.mem.writeInt(u32, &checksum, @truncate(std.hash.XxHash64.hash(0, input)), .little);
    try out.appendSlice(allocator, &checksum);
    return out.toOwnedSlice(allocator);
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

test "zstd raw/RLE frame writer round trips through std decompressor" {
    const payload = "zstd raw block payload zstd raw block payload";
    const encoded = try encodeRawOrRleFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);
    const decoded = try decodeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    try std.testing.expectEqual(@as(u8, 0xe4), encoded[4]);
    try std.testing.expectEqual(@as(u64, payload.len), std.mem.readInt(u64, encoded[5..][0..8], .little));

    const repeated = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
    const rle_encoded = try encodeRawOrRleFrameAlloc(std.testing.allocator, repeated);
    defer std.testing.allocator.free(rle_encoded);
    try std.testing.expect(rle_encoded.len < repeated.len);
    const first_block_header = std.mem.readInt(u24, rle_encoded[13..][0..3], .little);
    try std.testing.expectEqual(@as(u24, 1), (first_block_header >> 1) & 0x3);
    const rle_decoded = try decodeFrameAlloc(std.testing.allocator, rle_encoded);
    defer std.testing.allocator.free(rle_decoded);
    try std.testing.expectEqualSlices(u8, repeated, rle_decoded);
}
