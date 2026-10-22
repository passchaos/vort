const std = @import("std");
const core = @import("../core.zig");
const encoder = @import("encoder.zig");
const limited = @import("micro_limited_writer.zig");

pub const Error = core.Error || encoder.Error || std.mem.Allocator.Error;
pub const DestSizeResult = limited.Result;
pub const EncodedPrefix = limited.EncodedPrefix;
pub const min_destination_size = limited.min_destination_size;

pub const Options = struct {
    properties: encoder.Properties = .{},
    dictionary_size: u32 = 32 * 1024,
    mode: encoder.Mode = .greedy,
};

/// Encode a complete MicroLZMA stream. Its decoded size and dictionary size
/// belong to the enclosing format and must be supplied to the decoder.
pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: Options,
) Error![]u8 {
    const property = try validateOptions(options);
    var encoded: std.ArrayList(u8) = .empty;
    errdefer encoded.deinit(allocator);
    _ = try encoder.encodeChunkAppend(allocator, &encoded, input, .{
        .properties = options.properties,
        .dictionary_size = options.dictionary_size,
        .mode = options.mode,
        .end_marker = false,
    });
    // MicroLZMA replaces the ordinary raw LZMA range prefix (zero) with
    // the complemented properties byte. It has no header or end marker.
    std.debug.assert(encoded.items.len >= 5 and encoded.items[0] == 0);
    encoded.items[0] = ~property;
    return encoded.toOwnedSlice(allocator);
}

/// Append one complete stream, preserving the existing bytes on error.
pub fn encodeAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
    options: Options,
) Error!usize {
    const encoded = try encodeAlloc(allocator, input, options);
    defer allocator.free(encoded);
    try output.appendSlice(allocator, encoded);
    return encoded.len;
}

/// Encode a terminated input prefix that fits in `capacity` bytes. The
/// minimum capacity is six bytes, including for empty input.
pub fn encodeDestSizeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    capacity: usize,
    options: Options,
) Error!EncodedPrefix {
    _ = try validateOptions(options);
    return limited.encodeAlloc(allocator, input, capacity, .{
        .properties = options.properties,
        .dictionary_size = options.dictionary_size,
        .mode = options.mode,
        .end_marker = false,
    });
}

/// Write a terminated input prefix, preserving destination bytes on error.
/// `output[0..result.written]` represents `input[0..result.consumed]`.
pub fn encodeDestSizeInto(
    allocator: std.mem.Allocator,
    input: []const u8,
    output: []u8,
    options: Options,
) Error!DestSizeResult {
    var encoded = try encodeDestSizeAlloc(allocator, input, output.len, options);
    defer encoded.deinit(allocator);
    if (encoded.bytes.len > output.len) return error.OutputTooSmall;
    @memcpy(output[0..encoded.bytes.len], encoded.bytes);
    return .{ .written = encoded.bytes.len, .consumed = encoded.consumed };
}

/// Encode a bounded stream whose partial input consumption is a multiple
/// of `alignment`. A complete final input may have an unaligned length.
/// If no aligned prefix fits, return a valid empty stream and consumed = 0.
pub fn encodeAlignedDestSizeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    capacity: usize,
    alignment: usize,
    options: Options,
) Error!EncodedPrefix {
    _ = try validateOptions(options);
    return limited.encodeAlignedAlloc(allocator, input, capacity, alignment, .{
        .properties = options.properties,
        .dictionary_size = options.dictionary_size,
        .mode = options.mode,
        .end_marker = false,
    });
}

pub fn encodeAlignedDestSizeInto(
    allocator: std.mem.Allocator,
    input: []const u8,
    output: []u8,
    alignment: usize,
    options: Options,
) Error!DestSizeResult {
    var encoded = try encodeAlignedDestSizeAlloc(allocator, input, output.len, alignment, options);
    defer encoded.deinit(allocator);
    if (encoded.bytes.len > output.len) return error.OutputTooSmall;
    @memcpy(output[0..encoded.bytes.len], encoded.bytes);
    return .{ .written = encoded.bytes.len, .consumed = encoded.consumed };
}

fn validateOptions(options: Options) Error!u8 {
    const property = try encoder.propertyByte(options.properties);
    if (options.dictionary_size < 4096 or
        options.dictionary_size > encoder.max_dictionary_size)
        return error.InvalidLzmaOptions;
    return property;
}

/// Write one complete stream, preserving the destination on error.
pub fn encodeInto(
    allocator: std.mem.Allocator,
    input: []const u8,
    output: []u8,
    options: Options,
) Error!usize {
    const encoded = try encodeAlloc(allocator, input, options);
    defer allocator.free(encoded);
    if (encoded.len > output.len) return error.OutputTooSmall;
    @memcpy(output[0..encoded.len], encoded);
    return encoded.len;
}
