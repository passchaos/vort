const std = @import("std");
const core = @import("core.zig");

pub const Error = core.Error || std.mem.Allocator.Error;

const frame_magic = [_]u8{ 0x28, 0xb5, 0x2f, 0xfd };

/// Decode a Zstandard frame using Zig std's standards-compliant decoder.
pub fn decodeFrameAlloc(allocator: std.mem.Allocator, frame: []const u8) Error![]u8 {
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

/// Emit a valid Zstandard frame composed of raw and RLE blocks.
///
/// This keeps the encoder dependency-free while producing interoperable frames
/// with content size and checksum. General entropy-coded sequence compression
/// belongs behind this API in Vort and can be implemented from the reference
/// material in ~/Work/zstd without changing MCAP callers.
pub fn encodeRawOrRleFrameAlloc(allocator: std.mem.Allocator, input: []const u8) Error![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try out.appendSlice(allocator, &frame_magic);
    try out.append(allocator, 0xe4); // fcs=8 bytes, single segment, content checksum
    var content_size: [8]u8 = undefined;
    std.mem.writeInt(u64, &content_size, try checkedUsizeToU64(input.len), .little);
    try out.appendSlice(allocator, &content_size);
    var offset: usize = 0;
    while (offset < input.len or input.len == 0) {
        const remaining = input.len - offset;
        const block_len = @min(remaining, std.compress.zstd.block_size_max);
        const last = offset + block_len == input.len;
        const block = input[offset..][0..block_len];
        const rle_byte = rleByte(block);
        const block_type: u32 = if (rle_byte == null) 0 else 1;
        const header_value: u32 = (@as(u32, @intCast(block_len)) << 3) |
            (block_type << 1) |
            @as(u32, if (last) 1 else 0);
        var header: [3]u8 = .{
            @truncate(header_value),
            @truncate(header_value >> 8),
            @truncate(header_value >> 16),
        };
        try out.appendSlice(allocator, &header);
        if (rle_byte) |byte| {
            try out.append(allocator, byte);
        } else {
            try out.appendSlice(allocator, block);
        }
        offset += block_len;
        if (last) break;
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

fn checkedUsizeToU64(value: usize) Error!u64 {
    return std.math.cast(u64, value) orelse error.IntegerOverflow;
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
