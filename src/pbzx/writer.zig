const std = @import("std");
const core = @import("../core.zig");
const lzma = @import("../lzma.zig");
const xz = @import("../xz.zig");
const format = @import("format.zig");

pub const Error = core.Error || format.Error || lzma.Error || xz.Error ||
    std.mem.Allocator.Error;

pub const Compression = enum {
    auto,
    xz,
    stored,
};

pub const EncodeOptions = struct {
    chunk_size: usize = 16 * 1024 * 1024,
    compression: Compression = .auto,
    xz_options: xz.EncodeOptions = .{},
    end_marker: bool = false,
};

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: EncodeOptions,
) Error![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    _ = try encodeAppend(allocator, &output, input, options);
    return output.toOwnedSlice(allocator);
}

pub fn encodeAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
    options: EncodeOptions,
) Error!usize {
    const start = output.items.len;
    errdefer output.shrinkRetainingCapacity(start);
    if (options.chunk_size == 0) return error.InvalidPbzx;
    try output.appendSlice(allocator, format.magic);
    try appendU64(allocator, output, options.chunk_size);
    var position: usize = 0;
    while (position < input.len) {
        const length = @min(options.chunk_size, input.len - position);
        const chunk = input[position..][0..length];
        var encoded: ?[]u8 = null;
        defer if (encoded) |bytes| allocator.free(bytes);
        const selected: []const u8 = switch (options.compression) {
            .stored => chunk,
            .xz, .auto => blk: {
                encoded = try xz.encodeAlloc(allocator, chunk, options.xz_options);
                if (options.compression == .auto and encoded.?.len >= chunk.len)
                    break :blk chunk;
                break :blk encoded.?;
            },
        };
        try appendU64(allocator, output, length);
        try appendU64(allocator, output, selected.len);
        try output.appendSlice(allocator, selected);
        position += length;
    }
    if (options.end_marker) {
        try appendU64(allocator, output, 0);
        try appendU64(allocator, output, 0);
    }
    return output.items.len - start;
}

pub fn encodeInto(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: EncodeOptions,
    output: []u8,
) Error!usize {
    const encoded = try encodeAlloc(allocator, input, options);
    defer allocator.free(encoded);
    if (encoded.len > output.len) return error.OutputTooSmall;
    @memcpy(output[0..encoded.len], encoded);
    return encoded.len;
}

fn appendU64(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    value: anytype,
) Error!void {
    const slot = try output.addManyAsSlice(allocator, 8);
    std.mem.writeInt(u64, slot[0..8], std.math.cast(u64, value) orelse
        return error.IntegerOverflow, .big);
}
