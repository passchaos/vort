const std = @import("std");
const decoder = @import("ppmd7/decoder.zig");
const encoder = @import("ppmd7/encoder.zig");
const model = @import("ppmd7/model.zig");

pub const Error = decoder.Error || error{
    InvalidPpmdProperties,
    OutputLimitExceeded,
};

pub const Properties = struct {
    order: u8,
    memory_size: u32,
};

pub const IncrementalDecoder = decoder.IncrementalDecoder;
pub const IncrementalEncoder = encoder.IncrementalEncoder;

pub fn validateProperties(properties: Properties) Error!void {
    if (properties.order < model.min_order or properties.order > model.max_order or
        properties.memory_size < model.min_memory_size or properties.memory_size > model.max_memory_size)
        return error.InvalidPpmdProperties;
}

pub fn parseProperties(encoded: []const u8) Error!Properties {
    if (encoded.len != 5) return error.InvalidPpmdProperties;
    const result = Properties{
        .order = encoded[0],
        .memory_size = std.mem.readInt(u32, encoded[1..5], .little),
    };
    try validateProperties(result);
    return result;
}

pub fn decodeAllocLimited(
    allocator: std.mem.Allocator,
    input: []const u8,
    encoded_properties: []const u8,
    expected_size: usize,
    max_memory_size: usize,
) Error![]u8 {
    const properties = try parseProperties(encoded_properties);
    if (properties.memory_size > max_memory_size) return error.OutputLimitExceeded;
    const output = try allocator.alloc(u8, expected_size);
    errdefer allocator.free(output);
    try decoder.decodeInto(
        allocator,
        input,
        output,
        properties.order,
        properties.memory_size,
    );
    return output;
}

pub fn encodeAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
    properties: Properties,
) Error!usize {
    try validateProperties(properties);
    return encoder.encodeAppend(
        allocator,
        output,
        input,
        properties.order,
        properties.memory_size,
    );
}

test "PPMd7 properties enforce wire and resource limits" {
    const encoded = [_]u8{ 6, 0, 0, 1, 0 };
    const properties = try parseProperties(&encoded);
    try std.testing.expectEqual(@as(u8, 6), properties.order);
    try std.testing.expectEqual(@as(u32, 64 * 1024), properties.memory_size);
    try std.testing.expectError(error.InvalidPpmdProperties, parseProperties(&.{}));

    var bad_order = encoded;
    bad_order[0] = 1;
    try std.testing.expectError(error.InvalidPpmdProperties, parseProperties(&bad_order));
    var bad_memory = encoded;
    std.mem.writeInt(u32, bad_memory[1..5], model.min_memory_size - 1, .little);
    try std.testing.expectError(error.InvalidPpmdProperties, parseProperties(&bad_memory));

    try std.testing.expectError(
        error.OutputLimitExceeded,
        decodeAllocLimited(std.testing.allocator, &.{ 0, 0, 0, 0, 0 }, &encoded, 0, 32 * 1024),
    );
}

test {
    _ = decoder;
    _ = encoder;
    _ = model;
}
