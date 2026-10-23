const std = @import("std");
const core = @import("../core.zig");
const deflate = @import("../deflate.zig");
const lzma = @import("../lzma.zig");
const zstd = @import("../zstd.zig");
const format = @import("format.zig");
const lz4_codec = @import("codec/lz4.zig");
const prefix_codec = @import("codec/prefix.zig");

pub const Error = core.Error || deflate.Error || lzma.Error || zstd.Error ||
    std.mem.Allocator.Error || error{
    InvalidErofs,
    UnsupportedErofsCompression,
};

test {
    _ = @import("codec/tests.zig");
}

pub fn decodeExtentAlloc(
    allocator: std.mem.Allocator,
    algorithm: format.Compression,
    input: []const u8,
    expected_size: usize,
    zero_padding: bool,
) Error![]u8 {
    const payload = try payloadInput(input, algorithm, zero_padding);
    return switch (algorithm) {
        .lz4 => blk: {
            const output = try allocator.alloc(u8, expected_size);
            errdefer allocator.free(output);
            _ = try decodeLz4Into(payload, output, false);
            break :blk output;
        },
        .deflate => blk: {
            const result = try deflate.decodeRawAutoAllocPartialLimited(
                allocator,
                payload,
                expected_size,
            );
            errdefer result.deinit(allocator);
            if (result.bytes.len != expected_size) return error.SizeMismatch;
            break :blk result.bytes;
        },
        .zstandard => blk: {
            var iterator = try zstd.NativeFrameBlockIterator.init(payload);
            while (try iterator.next()) |_| {}
            const output = try zstd.decodeFrameAllocExactSize(
                allocator,
                payload[0..iterator.next_header_offset],
                expected_size,
            );
            break :blk output;
        },
        .lzma => lzma.decodeMicroAllocLimited(
            allocator,
            payload,
            expected_size,
            8 * 1024 * 1024,
            expected_size,
        ),
    };
}

pub fn decodeLz4Into(input: []const u8, output: []u8, zero_padding: bool) Error!usize {
    return lz4_codec.decode(input, output, zero_padding, false);
}

pub fn decodePrefixExtentAlloc(allocator: std.mem.Allocator, algorithm: format.Compression, input: []const u8, size: usize, zero_padding: bool) Error![]u8 {
    if (size == 0) return allocator.alloc(u8, 0);
    return prefix_codec.decodeAlloc(allocator, algorithm, try payloadInput(input, algorithm, zero_padding), size);
}

fn payloadInput(input: []const u8, algorithm: format.Compression, zero_padding: bool) Error![]const u8 {
    var offset: usize = 0;
    if (zero_padding or algorithm != .lz4)
        while (offset < input.len and input[offset] == 0) : (offset += 1) {};
    if (offset == input.len) return error.InvalidErofs;
    return input[offset..];
}

test "EROFS decodes zero-padded MicroLZMA extents" {
    const allocator = std.testing.allocator;
    const encoded_text = @embedFile("../lzma/testdata/microlzma-small.bin.b64");
    const base64 = std.base64.standard.decoderWithIgnore(" \r\n\t");
    const encoded_bound = base64.calcSizeUpperBound(encoded_text.len);
    const padded = try allocator.alloc(u8, encoded_bound + 3);
    defer allocator.free(padded);
    @memset(padded[0..3], 0);
    const encoded_len = try base64.decode(padded[3..], encoded_text);
    const expected = @embedFile("../lzms/testdata/lzms-small.txt");
    const decoded = try decodeExtentAlloc(
        allocator,
        .lzma,
        padded[0 .. encoded_len + 3],
        expected.len,
        false,
    );
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings(expected, decoded);
}
