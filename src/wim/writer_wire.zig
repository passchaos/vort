const std = @import("std");
const core = @import("../core.zig");
const format = @import("format.zig");
const resource_writer = @import("writer_resource.zig");

pub const Error = core.Error || std.mem.Allocator.Error || error{
    InvalidWimWriterOptions,
    WimResourceTooLarge,
};

const integrity_chunk_size: usize = 10 * 1024 * 1024;

pub fn appendLookupEntry(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    resource: format.ResourceHeader,
    part_number: u16,
    reference_count: u32,
    sha1: *const [std.crypto.hash.Sha1.digest_length]u8,
) Error!void {
    const offset = output.items.len;
    try output.appendNTimes(allocator, 0, format.lookup_entry_size);
    writeResourceHeader(output.items, offset, resource);
    writeU16(output.items, offset + 24, part_number);
    writeU32(output.items, offset + 26, reference_count);
    @memcpy(output.items[offset + 30 .. offset + 50], sha1);
}

pub fn appendIntegrity(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    lookup_end: usize,
) Error!format.ResourceHeader {
    if (lookup_end < format.header_size or lookup_end > output.items.len)
        return error.InvalidWimWriterOptions;
    const checked_len = lookup_end - format.header_size;
    const entry_count = if (checked_len == 0)
        0
    else
        1 + (checked_len - 1) / integrity_chunk_size;
    if (entry_count > std.math.maxInt(u32)) return error.WimResourceTooLarge;
    const table_len = try checkedAdd(
        12,
        std.math.mul(usize, entry_count, std.crypto.hash.Sha1.digest_length) catch
            return error.IntegerOverflow,
    );
    const offset = output.items.len;
    try output.appendNTimes(allocator, 0, table_len);
    writeU32(output.items, offset, @as(u32, @intCast(table_len)));
    writeU32(output.items, offset + 4, @as(u32, @intCast(entry_count)));
    writeU32(output.items, offset + 8, integrity_chunk_size);
    for (0..entry_count) |index| {
        const start = format.header_size + index * integrity_chunk_size;
        const end = @min(lookup_end, start + integrity_chunk_size);
        std.crypto.hash.Sha1.hash(
            output.items[start..end],
            output.items[offset + 12 + index * 20 ..][0..20],
            .{},
        );
    }
    return resourceHeader(offset, table_len, table_len, 0);
}

pub fn resourceHeader(
    offset: usize,
    stored_size: usize,
    uncompressed_size: usize,
    flags: u8,
) Error!format.ResourceHeader {
    if (stored_size >= @as(u64, 1) << 56)
        return error.WimResourceTooLarge;
    return .{
        .size_in_wim = stored_size,
        .flags = flags,
        .offset_in_wim = offset,
        .uncompressed_size = uncompressed_size,
    };
}

pub fn zeroResource() format.ResourceHeader {
    return .{
        .size_in_wim = 0,
        .flags = 0,
        .offset_in_wim = 0,
        .uncompressed_size = 0,
    };
}

pub fn writeHeader(
    header: []u8,
    version: u32,
    compression: resource_writer.Compression,
    chunk_size: usize,
    guid: *const [16]u8,
    image_count: u32,
    lookup_resource: format.ResourceHeader,
    xml_resource: format.ResourceHeader,
    boot_metadata: format.ResourceHeader,
    boot_index: u32,
    integrity_resource: format.ResourceHeader,
) void {
    writeHeaderWithFlags(
        header,
        version,
        compressionFlags(compression),
        chunk_size,
        guid,
        image_count,
        lookup_resource,
        xml_resource,
        boot_metadata,
        boot_index,
        integrity_resource,
    );
}

pub fn writeHeaderWithFlags(
    header: []u8,
    version: u32,
    flags: u32,
    chunk_size: usize,
    guid: *const [16]u8,
    image_count: u32,
    lookup_resource: format.ResourceHeader,
    xml_resource: format.ResourceHeader,
    boot_metadata: format.ResourceHeader,
    boot_index: u32,
    integrity_resource: format.ResourceHeader,
) void {
    @memset(header, 0);
    @memcpy(header[0..8], &format.magic);
    writeU32(header, 8, format.header_size);
    writeU32(header, 12, version);
    writeU32(header, 16, flags);
    writeU32(header, 20, @as(u32, @intCast(chunk_size)));
    @memcpy(header[24..40], guid);
    writeU16(header, 40, 1);
    writeU16(header, 42, 1);
    writeU32(header, 44, image_count);
    writeResourceHeader(header, 48, lookup_resource);
    writeResourceHeader(header, 72, xml_resource);
    writeResourceHeader(header, 96, boot_metadata);
    writeU32(header, 120, boot_index);
    writeResourceHeader(header, 124, integrity_resource);
}

fn compressionFlags(compression: resource_writer.Compression) u32 {
    return switch (compression) {
        .stored => 0,
        .xpress => 0x0000_0002 | 0x0002_0000,
        .lzx => 0x0000_0002 | 0x0004_0000,
        .lzms => 0x0000_0002 | 0x0008_0000,
    };
}

fn writeResourceHeader(
    output: []u8,
    offset: usize,
    resource: format.ResourceHeader,
) void {
    for (0..7) |index|
        output[offset + index] = @truncate(resource.size_in_wim >> @intCast(index * 8));
    output[offset + 7] = resource.flags;
    writeU64(output, offset + 8, resource.offset_in_wim);
    writeU64(output, offset + 16, resource.uncompressed_size);
}

fn checkedAdd(left: usize, right: usize) Error!usize {
    return std.math.add(usize, left, right) catch error.IntegerOverflow;
}

fn writeU16(output: []u8, offset: usize, value: u16) void {
    std.mem.writeInt(u16, output[offset..][0..2], value, .little);
}

fn writeU32(output: []u8, offset: usize, value: u32) void {
    std.mem.writeInt(u32, output[offset..][0..4], value, .little);
}

fn writeU64(output: []u8, offset: usize, value: u64) void {
    std.mem.writeInt(u64, output[offset..][0..8], value, .little);
}
