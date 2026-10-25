//! XZ Block Header construction shared by sized and legacy Blocks. The legacy
//! path retains the original ArrayList growth and append order.
const std = @import("std");
const filters = @import("../filters.zig");

pub const Sizes = struct {
    compressed_size: u64,
    uncompressed_size: u64,
};

const max_vli: u64 = (@as(u64, 1) << 63) - 1;

pub fn append(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    filter_chain: []const filters.Filter,
    dictionary_property: u8,
    sizes: ?Sizes,
) !usize {
    if (sizes) |declared|
        if (declared.compressed_size == 0) return error.InvalidBlockPlan;
    var header: std.ArrayList(u8) = .empty;
    defer header.deinit(allocator);
    try header.append(allocator, 0);
    const size_flags: u8 = if (sizes != null) 0xc0 else 0;
    try header.append(allocator, size_flags | @as(u8, @intCast(filter_chain.len)));
    if (sizes) |declared| {
        try appendVli(allocator, &header, declared.compressed_size);
        try appendVli(allocator, &header, declared.uncompressed_size);
    }
    for (filter_chain) |filter| {
        try appendVli(allocator, &header, filters.id(filter));
        const properties_len = filters.propertiesSize(filter);
        try appendVli(allocator, &header, properties_len);
        if (properties_len != 0) {
            var properties: [4]u8 = undefined;
            filters.writeProperties(filter, properties[0..properties_len]);
            try header.appendSlice(allocator, properties[0..properties_len]);
        }
    }
    try appendVli(allocator, &header, 0x21);
    try appendVli(allocator, &header, 1);
    try header.append(allocator, dictionary_property);
    while (header.items.len % 4 != 0) try header.append(allocator, 0);
    if (header.items.len / 4 > std.math.maxInt(u8)) return error.IntegerOverflow;
    header.items[0] = @intCast(header.items.len / 4);
    try output.appendSlice(allocator, header.items);
    var crc: [4]u8 = undefined;
    std.mem.writeInt(u32, &crc, std.hash.Crc32.hash(header.items), .little);
    try output.appendSlice(allocator, &crc);
    return header.items.len + 4;
}

fn appendVli(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value_arg: u64) !void {
    if (value_arg > max_vli) return error.IntegerOverflow;
    var value = value_arg;
    while (value >= 0x80) {
        try output.append(allocator, @as(u8, @truncate(value)) | 0x80);
        value >>= 7;
    }
    try output.append(allocator, @truncate(value));
}
