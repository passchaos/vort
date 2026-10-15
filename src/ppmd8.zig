const std = @import("std");
const decoder = @import("ppmd8/decoder.zig");
const encoder = @import("ppmd8/encoder.zig");
const incremental_decoder = @import("ppmd8/incremental_decoder.zig");
const incremental_tests = @import("ppmd8/incremental_tests.zig");
const model = @import("ppmd8/model.zig");

pub const Error = decoder.Error || error{
    InvalidPpmdProperties,
    OutputLimitExceeded,
};

pub const RestoreMethod = model.RestoreMethod;
pub const IncrementalDecoder = incremental_decoder.Decoder;

pub const ZipProperties = struct {
    order: u8 = 8,
    memory_size: u32 = 16 * 1024 * 1024,
    restore_method: RestoreMethod = .restart,
};

const mib: u32 = 1024 * 1024;
pub const zip_min_memory_size: u32 = mib;
pub const zip_max_memory_size: u32 = 256 * mib;

pub fn validateZipProperties(properties: ZipProperties) Error!void {
    if (properties.order < model.min_order or properties.order > model.max_order or
        properties.memory_size < zip_min_memory_size or
        properties.memory_size > zip_max_memory_size or
        properties.memory_size % mib != 0)
        return error.InvalidPpmdProperties;
}

pub fn parseZipProperties(encoded: []const u8) Error!ZipProperties {
    if (encoded.len < 2) return error.TruncatedPpmdInput;
    const value = std.mem.readInt(u16, encoded[0..2], .little);
    const restore_raw = value >> 12;
    if (restore_raw > 1) return error.InvalidPpmdProperties;
    const result = ZipProperties{
        .order = @intCast((value & 0x0f) + 1),
        .memory_size = (@as(u32, (value >> 4) & 0xff) + 1) * mib,
        .restore_method = @enumFromInt(restore_raw),
    };
    try validateZipProperties(result);
    return result;
}

fn propertyValue(properties: ZipProperties) Error!u16 {
    try validateZipProperties(properties);
    const memory_mib = properties.memory_size / mib;
    return @as(u16, properties.order - 1) |
        (@as(u16, @intCast(memory_mib - 1)) << 4) |
        (@as(u16, @intFromEnum(properties.restore_method)) << 12);
}

pub fn decodeZipInto(
    allocator: std.mem.Allocator,
    input: []const u8,
    output: []u8,
    max_memory_size: usize,
) Error!void {
    const properties = try parseZipProperties(input);
    if (properties.memory_size > max_memory_size) return error.OutputLimitExceeded;
    try decoder.decodeInto(
        allocator,
        input[2..],
        output,
        properties.order,
        properties.memory_size,
        properties.restore_method,
    );
}

pub fn encodeZipAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
    properties: ZipProperties,
) Error!usize {
    const start = output.items.len;
    errdefer output.items.len = start;
    var encoded_properties: [2]u8 = undefined;
    std.mem.writeInt(u16, &encoded_properties, try propertyValue(properties), .little);
    try output.appendSlice(allocator, &encoded_properties);
    _ = try encoder.encodeAppend(
        allocator,
        output,
        input,
        properties.order,
        properties.memory_size,
        properties.restore_method,
    );
    return output.items.len - start;
}

pub fn encodeZipAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    properties: ZipProperties,
) Error![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    _ = try encodeZipAppend(allocator, &output, input, properties);
    return output.toOwnedSlice(allocator);
}

test "ZIP PPMd properties parse restart and cut-off modes" {
    const restart = try parseZipProperties(&.{ 0x07, 0x00 });
    try std.testing.expectEqual(@as(u8, 8), restart.order);
    try std.testing.expectEqual(@as(u32, mib), restart.memory_size);
    try std.testing.expectEqual(RestoreMethod.restart, restart.restore_method);
    const cut_off = try parseZipProperties(&.{ 0x0b, 0x10 });
    try std.testing.expectEqual(@as(u8, 12), cut_off.order);
    try std.testing.expectEqual(RestoreMethod.cut_off, cut_off.restore_method);
    try std.testing.expectError(error.InvalidPpmdProperties, parseZipProperties(&.{ 0x07, 0x20 }));
}

test "ZIP PPMd wrapper round trips and enforces model memory" {
    const input = "ZIP method 98 PPMd payload\n" ** 128;
    const properties = ZipProperties{ .memory_size = mib };
    const encoded = try encodeZipAlloc(std.testing.allocator, input, properties);
    defer std.testing.allocator.free(encoded);
    const output = try std.testing.allocator.alloc(u8, input.len);
    defer std.testing.allocator.free(output);
    try decodeZipInto(std.testing.allocator, encoded, output, mib);
    try std.testing.expectEqualSlices(u8, input, output);
    try std.testing.expectError(
        error.OutputLimitExceeded,
        decodeZipInto(std.testing.allocator, encoded, output, mib - 1),
    );

    var trailing = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(trailing);
    trailing = try std.testing.allocator.realloc(trailing, trailing.len + 1);
    trailing[trailing.len - 1] = 0;
    try std.testing.expectError(
        error.PpmdTrailingData,
        decodeZipInto(std.testing.allocator, trailing, output, mib),
    );
    if (decodeZipInto(std.testing.allocator, encoded[0 .. encoded.len - 1], output, mib)) |_| {
        return error.TestUnexpectedResult;
    } else |err| {
        try std.testing.expect(err == error.TruncatedPpmdInput or err == error.InvalidPpmdData);
    }
}

test {
    _ = decoder;
    _ = encoder;
    _ = incremental_decoder;
    _ = incremental_tests;
    _ = model;
}
