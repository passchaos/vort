const std = @import("std");
const bzip2 = @import("../bzip2.zig");
const deflate = @import("../deflate.zig");
const lzma2_writer = @import("../xz/lzma2_writer.zig");
const filters = @import("../xz/filters.zig");
const number = @import("number.zig");

pub const Error = bzip2.Error || error{Invalid7zOptions};
pub const Filter = filters.Filter;

pub const Compression = enum {
    copy,
    deflate,
    bzip2,
    lzma2,
};

pub const Options = struct {
    compression: Compression = .copy,
    filters: []const Filter = &.{},
    deflate_level: u4 = 6,
    bzip2_block_size_100k: u4 = 9,
};

pub fn validate(options: Options) Error!void {
    filters.validateChain(options.filters) catch return error.Invalid7zOptions;
    if (options.compression == .deflate and options.deflate_level > 9)
        return error.Invalid7zOptions;
    if (options.compression == .bzip2 and
        (options.bzip2_block_size_100k < 1 or options.bzip2_block_size_100k > 9))
        return error.Invalid7zOptions;
}

pub fn coderCount(options: Options) usize {
    return 1 + options.filters.len;
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
        .lzma2 => lzma2_writer.appendStoredPayload(allocator, output, payload),
    };
}

pub fn writeFolder(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    options: Options,
) !void {
    try validate(options);
    const coder_count = coderCount(options);
    try number.append(allocator, output, coder_count);
    try writeCompressionCoder(allocator, output, options.compression);

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

fn appendCopy(allocator: std.mem.Allocator, output: *std.ArrayList(u8), input: []const u8) !usize {
    try output.appendSlice(allocator, input);
    return input.len;
}

fn writeCompressionCoder(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    compression: Compression,
) !void {
    switch (compression) {
        .copy => try output.appendSlice(allocator, &.{ 1, 0 }),
        .deflate => try output.appendSlice(allocator, &.{ 3, 0x04, 0x01, 0x08 }),
        .bzip2 => try output.appendSlice(allocator, &.{ 3, 0x04, 0x02, 0x02 }),
        .lzma2 => try output.appendSlice(allocator, &.{ 0x21, 0x21, 1, 0 }),
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
    const filters_too_long = [_]Filter{
        Filter.x86(0),
        try Filter.delta(1),
        try Filter.delta(2),
        try Filter.delta(3),
    };
    try std.testing.expectError(error.Invalid7zOptions, validate(.{ .filters = &filters_too_long }));
}
