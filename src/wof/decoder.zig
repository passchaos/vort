const std = @import("std");
const core = @import("../core.zig");
const xpress = @import("../xpress.zig");
const lzx = @import("../cab/lzx.zig");
const format = @import("format.zig");

pub const Error = core.Error || format.Error || xpress.Error || lzx.Error ||
    std.mem.Allocator.Error || error{InvalidWof};

pub fn decodeInto(
    allocator: std.mem.Allocator,
    backing: format.Backing,
    output: []u8,
) Error!void {
    if (output.len < backing.uncompressed_size) return error.OutputTooSmall;
    return decodeRangeInto(
        allocator,
        backing,
        0,
        output[0..backing.uncompressed_size],
    );
}

pub fn decodeAllocLimited(
    allocator: std.mem.Allocator,
    backing: format.Backing,
    max_output_len: usize,
) Error![]u8 {
    if (backing.uncompressed_size > max_output_len) return error.OutputLimitExceeded;
    const output = try allocator.alloc(u8, backing.uncompressed_size);
    errdefer allocator.free(output);
    try decodeInto(allocator, backing, output);
    return output;
}

pub fn decodeRangeInto(
    allocator: std.mem.Allocator,
    backing: format.Backing,
    offset: usize,
    output: []u8,
) Error!void {
    const range_end = std.math.add(usize, offset, output.len) catch
        return error.IntegerOverflow;
    if (range_end > backing.uncompressed_size) return error.RangeOutOfBounds;
    if (output.len == 0) return;
    const first_chunk = offset / backing.chunk_size;
    const last_chunk = (range_end - 1) / backing.chunk_size;
    const scratch = try allocator.alloc(u8, backing.chunk_size);
    defer allocator.free(scratch);
    var copied: usize = 0;
    for (first_chunk..last_chunk + 1) |chunk_index| {
        const chunk = try backing.chunk(chunk_index);
        const chunk_start = chunk_index * backing.chunk_size;
        const chunk_end = chunk_start + chunk.decoded_size;
        const copy_start = @max(offset, chunk_start);
        const copy_end = @min(range_end, chunk_end);
        const copy_len = copy_end - copy_start;
        if (chunk.isStored()) {
            @memcpy(
                output[copy_start - offset ..][0..copy_len],
                chunk.encoded[copy_start - chunk_start ..][0..copy_len],
            );
        } else {
            const decoded = scratch[0..chunk.decoded_size];
            try decodeChunkInto(allocator, backing.algorithm, chunk.encoded, decoded);
            @memcpy(
                output[copy_start - offset ..][0..copy_len],
                decoded[copy_start - chunk_start ..][0..copy_len],
            );
        }
        copied += copy_len;
    }
    if (copied != output.len) return error.InvalidWof;
}

pub fn decodeRangeAllocLimited(
    allocator: std.mem.Allocator,
    backing: format.Backing,
    offset: usize,
    length: usize,
    max_output_len: usize,
) Error![]u8 {
    if (length > max_output_len) return error.OutputLimitExceeded;
    const output = try allocator.alloc(u8, length);
    errdefer allocator.free(output);
    try decodeRangeInto(allocator, backing, offset, output);
    return output;
}

fn decodeChunkInto(
    allocator: std.mem.Allocator,
    algorithm: format.Algorithm,
    input: []const u8,
    output: []u8,
) Error!void {
    switch (algorithm) {
        .xpress4k, .xpress8k, .xpress16k => {
            _ = try xpress.decodeHuffmanInto(input, output);
        },
        .lzx => {
            const decoded = try lzx.decodeAllocWithFormat(
                allocator,
                input,
                output.len,
                15,
                .wim,
            );
            defer allocator.free(decoded);
            @memcpy(output, decoded);
        },
    }
}
