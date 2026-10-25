const std = @import("std");
const allocator_dispatch = @import("../allocator_dispatch.zig");
const window_format = @import("window_format.zig");
const metadata_header = @import("metadata_header.zig");

const ChunksInfo = struct {
    input_len: usize,
    last_non_empty: ?usize,
};

pub fn encodeChunksWithOptionsAlloc(
    comptime Encoder: type,
    comptime max_block_len: usize,
    allocator: std.mem.Allocator,
    chunks: []const []const u8,
    options: Encoder.Options,
) Encoder.Error![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try encodeChunksWithOptionsAppend(
        Encoder,
        max_block_len,
        allocator,
        &out,
        chunks,
        options,
    );
    return out.toOwnedSlice(allocator);
}

pub fn encodeChunksWithOptionsAppend(
    comptime Encoder: type,
    comptime max_block_len: usize,
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    chunks: []const []const u8,
    options: Encoder.Options,
) Encoder.Error!void {
    var encoder = Encoder.init(allocator);
    defer encoder.deinit();
    return encodeChunksWithOptionsAppendReuse(
        Encoder,
        max_block_len,
        &encoder,
        allocator,
        out,
        chunks,
        options,
    );
}

pub fn encodeChunksWithOptionsAppendReuse(
    comptime Encoder: type,
    comptime max_block_len: usize,
    encoder: *Encoder,
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    chunks: []const []const u8,
    options: Encoder.Options,
) Encoder.Error!void {
    const info = try preflightChunks(Encoder, max_block_len, chunks, options);
    const start = out.items.len;
    errdefer out.shrinkRetainingCapacity(start);
    encoder.reset();
    encoder.options = options;
    var scratch: [4096]u8 = undefined;
    for (chunks, 0..) |chunk, chunk_index| {
        if (chunk.len == 0) continue;
        try feed(Encoder, encoder, out, allocator, chunk, &scratch);
        if (chunk_index != info.last_non_empty.?) {
            encoder.flush();
            try drainFlush(Encoder, encoder, out, allocator, &scratch);
        }
    }
    try encoder.finish();
    try drainFinish(Encoder, encoder, out, allocator, &scratch);
}

pub fn encodeChunksWithOptionsInto(
    comptime Encoder: type,
    comptime max_block_len: usize,
    chunks: []const []const u8,
    output: []u8,
    options: Encoder.Options,
) Encoder.Error!usize {
    const encoded = try encodeChunksWithOptionsAlloc(
        Encoder,
        max_block_len,
        allocator_dispatch.singleton,
        chunks,
        options,
    );
    defer allocator_dispatch.singleton.free(encoded);
    if (output.len < encoded.len) return error.OutOfMemory;
    @memcpy(output[0..encoded.len], encoded);
    return encoded.len;
}

/// Complete format and input admission before a caller clears reusable output
/// or snapshots aliases. Metadata validation reads only its borrowed length.
pub fn validateChunks(
    comptime Encoder: type,
    comptime max_block_len: usize,
    chunks: []const []const u8,
    options: Encoder.Options,
) Encoder.Error!void {
    _ = try preflightChunks(Encoder, max_block_len, chunks, options);
}

fn preflightChunks(
    comptime Encoder: type,
    comptime max_block_len: usize,
    chunks: []const []const u8,
    options: Encoder.Options,
) Encoder.Error!ChunksInfo {
    if (options.block_len == 0 or options.block_len > max_block_len)
        return error.InvalidBlockPlan;
    try window_format.validate(options.stream.window_bits, options.stream.large_window);
    _ = try metadata_header.plan(options.stream.metadata.len);
    var info: ChunksInfo = .{ .input_len = 0, .last_non_empty = null };
    for (chunks, 0..) |chunk, index| {
        info.input_len = std.math.add(usize, info.input_len, chunk.len) catch
            return error.IntegerOverflow;
        if (chunk.len != 0) info.last_non_empty = index;
    }
    if (info.input_len > options.max_input_len) return error.OutputLimitExceeded;
    return info;
}

fn feed(
    comptime Encoder: type,
    encoder: *Encoder,
    out: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    input: []const u8,
    scratch: []u8,
) Encoder.Error!void {
    var offset: usize = 0;
    while (offset < input.len) {
        const result = try encoder.step(input[offset..], scratch);
        if (result.progress.input_read == 0 and result.progress.output_written == 0)
            return error.InvalidBlockPlan;
        offset += result.progress.input_read;
        try out.appendSlice(allocator, scratch[0..result.progress.output_written]);
    }
}

fn drainFlush(
    comptime Encoder: type,
    encoder: *Encoder,
    out: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    scratch: []u8,
) Encoder.Error!void {
    while (true) {
        const result = try encoder.step("", scratch);
        try out.appendSlice(allocator, scratch[0..result.progress.output_written]);
        switch (result.status) {
            .need_input => return,
            .need_output => if (result.progress.output_written == 0)
                return error.InvalidBlockPlan,
            .done => return error.InvalidBlockPlan,
        }
    }
}

fn drainFinish(
    comptime Encoder: type,
    encoder: *Encoder,
    out: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    scratch: []u8,
) Encoder.Error!void {
    while (true) {
        const result = try encoder.step("", scratch);
        try out.appendSlice(allocator, scratch[0..result.progress.output_written]);
        switch (result.status) {
            .done => return,
            .need_output => if (result.progress.output_written == 0)
                return error.InvalidBlockPlan,
            .need_input => return error.InvalidBlockPlan,
        }
    }
}
