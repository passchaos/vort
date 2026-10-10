const std = @import("std");
const core = @import("../core.zig");
const deflate = @import("../deflate.zig");
const lz4 = @import("../lz4.zig");
const lzma = @import("../lzma.zig");
const lzo1x = @import("../lzo1x.zig");
const xz = @import("../xz.zig");
const zstd = @import("../zstd.zig");
const format = @import("format.zig");

pub const Error = core.Error || deflate.Error || lz4.Error || lzma.Error ||
    lzo1x.Error || xz.Error || zstd.Error || std.mem.Allocator.Error ||
    error{InvalidSquashfs};

pub fn decodeAllocExact(
    allocator: std.mem.Allocator,
    compression: format.Compression,
    input: []const u8,
    expected_size: usize,
) Error![]u8 {
    const decoded = try decodeAllocLimited(allocator, compression, input, expected_size);
    errdefer allocator.free(decoded);
    if (decoded.len != expected_size) return error.SizeMismatch;
    return decoded;
}

pub fn decodeAllocLimited(
    allocator: std.mem.Allocator,
    compression: format.Compression,
    input: []const u8,
    max_output_size: usize,
) Error![]u8 {
    const decoded = switch (compression) {
        .gzip => try deflate.decodeZlibAllocLimited(allocator, input, max_output_size),
        .lzma => try lzma.decodeAllocLimited(allocator, input, max_output_size),
        .lzo => blk: {
            const output = try allocator.alloc(u8, max_output_size);
            errdefer allocator.free(output);
            const written = try lzo1x.decodeInto(input, output);
            break :blk try allocator.realloc(output, written);
        },
        .xz => try xz.decodeAllocLimited(allocator, input, max_output_size),
        .lz4 => blk: {
            const decoded_size = try lz4.decodedBlockSizeLimited(input, max_output_size);
            const output = try allocator.alloc(u8, decoded_size);
            errdefer allocator.free(output);
            const written = try lz4.decodeBlockIntoSlice(input, output, decoded_size);
            if (written != decoded_size) return error.SizeMismatch;
            break :blk output;
        },
        .zstandard => try zstd.decodeFrameAllocLimited(allocator, input, max_output_size),
    };
    return decoded;
}
