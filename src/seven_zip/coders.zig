const std = @import("std");
const bzip2 = @import("../bzip2.zig");
const deflate = @import("../deflate.zig");
const lzma_encoder = @import("../lzma/encoder.zig");
const lzma2_writer = @import("../xz/lzma2_writer.zig");
const filters = @import("../xz/filters.zig");
const number = @import("number.zig");

pub const Error = bzip2.Error || lzma_encoder.Error || error{Invalid7zOptions};
pub const Filter = filters.Filter;

pub const Compression = enum {
    copy,
    deflate,
    bzip2,
    lzma,
    lzma2,
    lzma2_stored,
};

pub const Options = struct {
    compression: Compression = .copy,
    solid: bool = false,
    header_compression: ?Compression = null,
    external_names: ?Compression = null,
    bcj2: bool = false,
    bcj2_start_ip: u32 = 0,
    filters: []const Filter = &.{},
    deflate_level: u4 = 6,
    bzip2_block_size_100k: u4 = 9,
    lzma_properties: lzma_encoder.Properties = .{},
    lzma_dictionary_size: u32 = 32 * 1024,
};

pub fn validate(options: Options) Error!void {
    filters.validateChain(options.filters) catch return error.Invalid7zOptions;
    if (options.bcj2 and options.filters.len != 0) return error.Invalid7zOptions;
    if (!options.bcj2 and options.bcj2_start_ip != 0) return error.Invalid7zOptions;
    if (options.compression == .deflate and options.deflate_level > 9)
        return error.Invalid7zOptions;
    if (options.compression == .bzip2 and
        (options.bzip2_block_size_100k < 1 or options.bzip2_block_size_100k > 9))
        return error.Invalid7zOptions;
    if (options.compression == .lzma) {
        _ = lzma_encoder.propertyByte(options.lzma_properties) catch
            return error.Invalid7zOptions;
        if (options.lzma_dictionary_size < 4096 or
            options.lzma_dictionary_size > std.math.maxInt(u16))
            return error.Invalid7zOptions;
    }
}

pub fn coderCount(options: Options) usize {
    return if (options.bcj2) 2 else 1 + options.filters.len;
}

pub fn appendPayload(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
    options: Options,
) !usize {
    try validate(options);
    var filtered_storage: ?[]u8 = null;
    defer if (filtered_storage) |bytes| allocator.free(bytes);
    const payload = if (options.filters.len == 0)
        input
    else payload: {
        const bytes = try allocator.dupe(u8, input);
        filtered_storage = bytes;
        filters.encodeChain(bytes, options.filters);
        break :payload bytes;
    };

    return switch (options.compression) {
        .copy => appendCopy(allocator, output, payload),
        .deflate => deflate.encodeRawLevelAppend(allocator, output, payload, options.deflate_level),
        .bzip2 => bzip2.encodeAppend(allocator, output, payload, .{
            .block_size_100k = options.bzip2_block_size_100k,
        }),
        .lzma => lzma_encoder.encodeChunkAppend(allocator, output, payload, .{
            .properties = options.lzma_properties,
            .dictionary_size = options.lzma_dictionary_size,
        }),
        .lzma2 => lzma2_writer.appendCompressedPayload(allocator, output, payload),
        .lzma2_stored => lzma2_writer.appendStoredPayload(allocator, output, payload),
    };
}

pub fn writeFolder(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    options: Options,
) !void {
    try validate(options);
    if (options.bcj2) return writeBcj2Folder(allocator, output, options);
    const coder_count = coderCount(options);
    try number.append(allocator, output, coder_count);
    try writeCompressionCoder(allocator, output, options);

    var filter_index = options.filters.len;
    while (filter_index != 0) {
        filter_index -= 1;
        try writeFilterCoder(allocator, output, options.filters[filter_index]);
    }
    for (0..coder_count - 1) |output_index| {
        try number.append(allocator, output, output_index + 1);
        try number.append(allocator, output, output_index);
    }
}

fn writeBcj2Folder(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    options: Options,
) !void {
    try number.append(allocator, output, 2);
    try writeCompressionCoder(allocator, output, options);
    if (options.bcj2_start_ip == 0) {
        try output.appendSlice(allocator, &.{ 0x14, 0x03, 0x03, 0x01, 0x1b, 4, 1 });
    } else {
        try output.appendSlice(allocator, &.{ 0x34, 0x03, 0x03, 0x01, 0x1b, 4, 1, 4 });
        var property: [4]u8 = undefined;
        std.mem.writeInt(u32, &property, options.bcj2_start_ip, .little);
        try output.appendSlice(allocator, &property);
    }
    try number.append(allocator, output, 1);
    try number.append(allocator, output, 0);
    for ([_]u8{ 0, 2, 3, 4 }) |input_index|
        try number.append(allocator, output, input_index);
}

fn appendCopy(allocator: std.mem.Allocator, output: *std.ArrayList(u8), input: []const u8) !usize {
    try output.appendSlice(allocator, input);
    return input.len;
}

fn writeCompressionCoder(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    options: Options,
) !void {
    switch (options.compression) {
        .copy => try output.appendSlice(allocator, &.{ 1, 0 }),
        .deflate => try output.appendSlice(allocator, &.{ 3, 0x04, 0x01, 0x08 }),
        .bzip2 => try output.appendSlice(allocator, &.{ 3, 0x04, 0x02, 0x02 }),
        .lzma => {
            try output.appendSlice(allocator, &.{ 0x23, 0x03, 0x01, 0x01, 5 });
            var properties: [5]u8 = undefined;
            properties[0] = try lzma_encoder.propertyByte(options.lzma_properties);
            std.mem.writeInt(u32, properties[1..5], options.lzma_dictionary_size, .little);
            try output.appendSlice(allocator, &properties);
        },
        .lzma2, .lzma2_stored => try output.appendSlice(allocator, &.{ 0x21, 0x21, 1, lzma2_writer.dictionary_property }),
    }
}

fn writeFilterCoder(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    filter: Filter,
) !void {
    const method_id: []const u8 = switch (filter.kind) {
        .delta => &.{0x03},
        .x86 => &.{ 0x03, 0x03, 0x01, 0x03 },
        .powerpc => &.{ 0x03, 0x03, 0x02, 0x05 },
        .ia64 => &.{ 0x03, 0x03, 0x04, 0x01 },
        .arm => &.{ 0x03, 0x03, 0x05, 0x01 },
        .arm_thumb => &.{ 0x03, 0x03, 0x07, 0x01 },
        .sparc => &.{ 0x03, 0x03, 0x08, 0x05 },
    };
    const properties_len = filters.propertiesSize(filter);
    const properties_flag: usize = if (properties_len == 0) 0 else 0x20;
    const flags: u8 = @intCast(method_id.len | properties_flag);
    try output.append(allocator, flags);
    try output.appendSlice(allocator, method_id);
    if (properties_len != 0) {
        try number.append(allocator, output, properties_len);
        var properties: [4]u8 = undefined;
        filters.writeProperties(filter, properties[0..properties_len]);
        try output.appendSlice(allocator, properties[0..properties_len]);
    }
}

test "7z coder writer reverses encoding filters into decoder order" {
    const chain = [_]Filter{ Filter.x86(0), try Filter.delta(4) };
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    try writeFolder(std.testing.allocator, &encoded, .{
        .compression = .lzma2,
        .filters = &chain,
    });
    try std.testing.expectEqualSlices(u8, &.{
        3,
        0x21,
        0x21,
        1,
        0,
        0x21,
        0x03,
        1,
        3,
        0x04,
        0x03,
        0x03,
        0x01,
        0x03,
        1,
        0,
        2,
        1,
    }, encoded.items);
}

test "7z coder writer validates method-specific options" {
    try std.testing.expectError(error.Invalid7zOptions, validate(.{
        .compression = .deflate,
        .deflate_level = 10,
    }));
    try std.testing.expectError(error.Invalid7zOptions, validate(.{
        .compression = .bzip2,
        .bzip2_block_size_100k = 0,
    }));
    try std.testing.expectError(error.Invalid7zOptions, validate(.{
        .compression = .lzma,
        .lzma_dictionary_size = 1024,
    }));
    const filters_too_long = [_]Filter{
        Filter.x86(0),
        try Filter.delta(1),
        try Filter.delta(2),
        try Filter.delta(3),
    };
    try std.testing.expectError(error.Invalid7zOptions, validate(.{ .filters = &filters_too_long }));
    try std.testing.expectError(error.Invalid7zOptions, validate(.{
        .bcj2 = true,
        .filters = filters_too_long[0..1],
    }));
    try std.testing.expectError(error.Invalid7zOptions, validate(.{
        .bcj2_start_ip = 1,
    }));
}
