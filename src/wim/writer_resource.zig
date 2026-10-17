const std = @import("std");
const core = @import("../core.zig");
const lzms_encoder = @import("../lzms/encoder.zig");
const lzx_encoder = @import("../cab/lzx/encoder.zig");
const xpress = @import("../xpress.zig");
const format = @import("format.zig");

pub const Error = core.Error || lzms_encoder.Error || lzx_encoder.Error || xpress.Error || std.mem.Allocator.Error || error{
    InvalidWimWriterOptions,
    WimResourceTooLarge,
};

pub const Compression = enum {
    stored,
    xpress,
    lzx,
    lzms,
};

pub fn validate(compression: Compression, chunk_size: usize) Error!void {
    switch (compression) {
        .stored => if (chunk_size != 0) return error.InvalidWimWriterOptions,
        .xpress => {
            format.validateChunkSize(.xpress, chunk_size) catch
                return error.InvalidWimWriterOptions;
            if (chunk_size > xpress.huffmanMaxBlockSize)
                return error.InvalidWimWriterOptions;
        },
        .lzx => format.validateChunkSize(.lzx, chunk_size) catch
            return error.InvalidWimWriterOptions,
        .lzms => format.validateChunkSize(.lzms, chunk_size) catch
            return error.InvalidWimWriterOptions,
    }
}

pub fn append(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
    compression: Compression,
    chunk_size: usize,
    base_flags: u8,
) Error!format.ResourceHeader {
    const offset = output.items.len;
    switch (compression) {
        .stored => try output.appendSlice(allocator, input),
        .xpress, .lzx, .lzms => try appendChunked(allocator, output, input, compression, chunk_size),
    }
    const stored_size = output.items.len - offset;
    if (stored_size >= @as(u64, 1) << 56)
        return error.WimResourceTooLarge;
    return .{
        .size_in_wim = stored_size,
        .flags = base_flags | if (compression != .stored) @as(u8, 0x04) else 0,
        .offset_in_wim = offset,
        .uncompressed_size = input.len,
    };
}

fn appendChunked(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
    compression: Compression,
    chunk_size: usize,
) Error!void {
    if (compression == .stored) return error.InvalidWimWriterOptions;
    try validate(compression, chunk_size);
    if (input.len == 0) return;
    const chunk_count = 1 + (input.len - 1) / chunk_size;
    const entry_size: usize = if (input.len <= std.math.maxInt(u32)) 4 else 8;
    const table_size = std.math.mul(usize, chunk_count - 1, entry_size) catch
        return error.IntegerOverflow;
    const table_offset = output.items.len;
    try output.appendNTimes(allocator, 0, table_size);
    const data_offset = output.items.len;

    var input_offset: usize = 0;
    var chunk_index: usize = 0;
    while (input_offset < input.len) : (chunk_index += 1) {
        const input_end = @min(input.len, input_offset + chunk_size);
        const chunk = input[input_offset..input_end];
        const encoded = switch (compression) {
            .stored => unreachable,
            .xpress => try xpress.encodeHuffmanAlloc(allocator, chunk, .{}),
            .lzx => try lzx_encoder.encodeWimChunkAlloc(
                allocator,
                chunk,
                @intCast(std.math.log2_int(usize, chunk_size)),
            ),
            .lzms => try lzms_encoder.encodeAlloc(allocator, chunk),
        };
        defer allocator.free(encoded);
        if (encoded.len < chunk.len) {
            try output.appendSlice(allocator, encoded);
        } else {
            try output.appendSlice(allocator, chunk);
        }
        if (chunk_index + 1 < chunk_count) {
            const relative = output.items.len - data_offset;
            const entry_offset = table_offset + chunk_index * entry_size;
            if (entry_size == 4) {
                if (relative > std.math.maxInt(u32))
                    return error.WimResourceTooLarge;
                std.mem.writeInt(
                    u32,
                    output.items[entry_offset..][0..4],
                    @intCast(relative),
                    .little,
                );
            } else {
                std.mem.writeInt(
                    u64,
                    output.items[entry_offset..][0..8],
                    relative,
                    .little,
                );
            }
        }
        input_offset = input_end;
    }
}

test "WIM XPRESS resource writes chunk offsets and raw fallback" {
    const allocator = std.testing.allocator;
    var input: [70_000]u8 = undefined;
    @memset(input[0..35_000], 'a');
    var prng = std.Random.DefaultPrng.init(0x5749_4d);
    prng.random().bytes(input[35_000..]);

    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    const resource = try append(
        allocator,
        &encoded,
        &input,
        .xpress,
        32 * 1024,
        0,
    );
    try std.testing.expect(resource.isCompressed());
    try std.testing.expect(resource.size_in_wim < input.len);
    try std.testing.expect(format.readU32(encoded.items, 0) > 0);
    try std.testing.expect(format.readU32(encoded.items, 4) > format.readU32(encoded.items, 0));
}

test "WIM LZX resource mixes compressed and raw chunks" {
    const allocator = std.testing.allocator;
    var input: [64 * 1024]u8 = undefined;
    const phrase = "WIM LZX reference encoder payload\n";
    for (input[0 .. 32 * 1024], 0..) |*byte, index|
        byte.* = phrase[index % phrase.len];
    var prng = std.Random.DefaultPrng.init(0x4c5a_5821);
    prng.random().bytes(input[32 * 1024 ..]);

    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    const resource = try append(
        allocator,
        &encoded,
        &input,
        .lzx,
        32 * 1024,
        0,
    );
    try std.testing.expect(resource.isCompressed());
    const first_end = format.readU32(encoded.items, 0);
    try std.testing.expect(first_end < 32 * 1024);
    try std.testing.expectEqual(
        @as(usize, 4) + first_end + 32 * 1024,
        encoded.items.len,
    );
}

test "WIM LZMS resource mixes compressed and raw chunks" {
    const allocator = std.testing.allocator;
    var input: [64 * 1024]u8 = undefined;
    const phrase = "WIM LZMS adaptive literal payload\n";
    for (input[0 .. 32 * 1024], 0..) |*byte, index|
        byte.* = phrase[index % phrase.len];
    var prng = std.Random.DefaultPrng.init(0x4c5a_4d53_21);
    prng.random().bytes(input[32 * 1024 ..]);

    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    const resource = try append(
        allocator,
        &encoded,
        &input,
        .lzms,
        32 * 1024,
        0,
    );
    try std.testing.expect(resource.isCompressed());
    const first_end = format.readU32(encoded.items, 0);
    try std.testing.expect(first_end < 32 * 1024);
    try std.testing.expectEqual(
        @as(usize, 4) + first_end + 32 * 1024,
        encoded.items.len,
    );
}
