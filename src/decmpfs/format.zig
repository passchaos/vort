const std = @import("std");
const core = @import("../core.zig");

pub const Error = core.Error || error{
    InvalidDecmpfs,
    UnsupportedDecmpfsType,
    MissingDecmpfsResourceFork,
};

pub const magic: u32 = 0x636d_7066;
pub const header_size: usize = 16;
pub const block_size: usize = 64 * 1024;

pub const CompressionType = enum(u32) {
    uncompressed_inline = 1,
    zlib_inline = 3,
    zlib_resource = 4,
    dataless = 5,
    lzvn_inline = 7,
    lzvn_resource = 8,
    raw_inline = 9,
    raw_resource = 10,
    lzfse_inline = 11,
    lzfse_resource = 12,

    pub fn isResource(self: CompressionType) bool {
        return switch (self) {
            .zlib_resource, .lzvn_resource, .raw_resource, .lzfse_resource => true,
            else => false,
        };
    }
};

pub const Header = struct {
    compression_type: CompressionType,
    uncompressed_size: u64,
    inline_payload: []const u8,
};

pub fn parseHeader(xattr: []const u8) Error!Header {
    if (xattr.len < header_size) return error.TruncatedFrame;
    if (readU32Le(xattr, 0) != magic) return error.InvalidMagic;
    const compression_type = std.enums.fromInt(
        CompressionType,
        readU32Le(xattr, 4),
    ) orelse return error.UnsupportedDecmpfsType;
    if (compression_type.isResource() and xattr.len != header_size)
        return error.InvalidDecmpfs;
    return .{
        .compression_type = compression_type,
        .uncompressed_size = readU64Le(xattr, 8),
        .inline_payload = xattr[header_size..],
    };
}

pub const ResourceLayout = enum {
    zlib_descriptors,
    offset_table,
};

pub const ResourceChunk = struct {
    index: usize,
    encoded: []const u8,
    decoded_size: usize,
};

pub const ResourceFork = struct {
    bytes: []const u8,
    compression_type: CompressionType,
    uncompressed_size: usize,
    chunk_count: usize,
    layout: ResourceLayout,
    table_offset: usize,
    data_base: usize,

    pub fn init(
        bytes: []const u8,
        compression_type: CompressionType,
        uncompressed_size_u64: u64,
    ) Error!ResourceFork {
        if (!compression_type.isResource()) return error.InvalidDecmpfs;
        if (compression_type == .raw_resource) return error.UnsupportedDecmpfsType;
        const uncompressed_size = std.math.cast(usize, uncompressed_size_u64) orelse
            return error.IntegerOverflow;
        const chunk_count = if (uncompressed_size == 0)
            0
        else
            (std.math.add(usize, uncompressed_size, block_size - 1) catch
                return error.IntegerOverflow) / block_size;
        return switch (compression_type) {
            .zlib_resource => initZlib(
                bytes,
                compression_type,
                uncompressed_size,
                chunk_count,
            ),
            .lzvn_resource, .lzfse_resource => initOffsets(
                bytes,
                compression_type,
                uncompressed_size,
                chunk_count,
            ),
            else => unreachable,
        };
    }

    pub fn chunk(self: ResourceFork, index: usize) Error!ResourceChunk {
        if (index >= self.chunk_count) return error.RangeOutOfBounds;
        const decoded_size = @min(
            block_size,
            self.uncompressed_size - index * block_size,
        );
        const range = switch (self.layout) {
            .zlib_descriptors => blk: {
                const descriptor = self.table_offset + index * 8;
                const relative = readU32Le(self.bytes, descriptor);
                const length: usize = readU32Le(self.bytes, descriptor + 4);
                const start = std.math.add(
                    usize,
                    self.data_base,
                    relative,
                ) catch return error.IntegerOverflow;
                const end = std.math.add(usize, start, length) catch
                    return error.IntegerOverflow;
                break :blk .{ start, end };
            },
            .offset_table => blk: {
                const start_relative: usize = readU32Le(
                    self.bytes,
                    self.table_offset + index * 4,
                );
                const end_relative: usize = readU32Le(
                    self.bytes,
                    self.table_offset + (index + 1) * 4,
                );
                break :blk .{
                    self.data_base + start_relative,
                    self.data_base + end_relative,
                };
            },
        };
        return .{
            .index = index,
            .encoded = self.bytes[range[0]..range[1]],
            .decoded_size = decoded_size,
        };
    }
};

fn initZlib(
    bytes: []const u8,
    compression_type: CompressionType,
    uncompressed_size: usize,
    chunk_count: usize,
) Error!ResourceFork {
    if (bytes.len < 16) return error.TruncatedFrame;
    const data_offset: usize = readU32Be(bytes, 0);
    const map_offset: usize = readU32Be(bytes, 4);
    const data_size: usize = readU32Be(bytes, 8);
    const map_size: usize = readU32Be(bytes, 12);
    if (data_offset < 16 or data_offset > map_offset or
        data_size != map_offset - data_offset or map_size != 50 or
        map_offset > bytes.len or map_size != bytes.len - map_offset)
        return error.InvalidDecmpfs;
    const resource_map = bytes[map_offset..];
    if (readU16Be(resource_map, 24) != 28 or
        readU16Be(resource_map, 26) != 50 or
        readU16Be(resource_map, 28) != 0 or
        readU32Be(resource_map, 30) != 0x636d_7066 or
        readU16Be(resource_map, 34) != 0 or
        readU16Be(resource_map, 36) != 10 or
        readU16Be(resource_map, 38) != 1 or
        readU16Be(resource_map, 40) != 0xffff or
        readU32Be(resource_map, 42) & 0x00ff_ffff != 0)
        return error.InvalidDecmpfs;
    if (data_size < 8 or bytes.len - data_offset < 8)
        return error.InvalidDecmpfs;
    const data_payload_size: usize = readU32Be(bytes, data_offset);
    if (data_payload_size + 4 != data_size) return error.InvalidDecmpfs;
    const stored_count: usize = readU32Le(bytes, data_offset + 4);
    if (stored_count != chunk_count) return error.InvalidDecmpfs;
    const table_offset = data_offset + 8;
    const table_size = std.math.mul(usize, chunk_count, 8) catch
        return error.IntegerOverflow;
    if (table_size > data_size - 8) return error.InvalidDecmpfs;
    const data_base = data_offset + 4;
    var previous = 4 + table_size;
    for (0..chunk_count) |index| {
        const descriptor = table_offset + index * 8;
        const offset: usize = readU32Le(bytes, descriptor);
        const length: usize = readU32Le(bytes, descriptor + 4);
        const decoded_size = @min(
            block_size,
            uncompressed_size - index * block_size,
        );
        if (offset != previous or length == 0 or length > decoded_size + 1 or
            offset > data_payload_size or length > data_payload_size - offset)
            return error.InvalidDecmpfs;
        previous += length;
    }
    if (previous != data_payload_size) return error.InvalidDecmpfs;
    return .{
        .bytes = bytes,
        .compression_type = compression_type,
        .uncompressed_size = uncompressed_size,
        .chunk_count = chunk_count,
        .layout = .zlib_descriptors,
        .table_offset = table_offset,
        .data_base = data_base,
    };
}

fn initOffsets(
    bytes: []const u8,
    compression_type: CompressionType,
    uncompressed_size: usize,
    chunk_count: usize,
) Error!ResourceFork {
    const offset_count = std.math.add(usize, chunk_count, 1) catch
        return error.IntegerOverflow;
    const table_bytes = std.math.mul(usize, offset_count, 4) catch
        return error.IntegerOverflow;
    var data_base: usize = 0;
    var table_offset: usize = 0;
    if (bytes.len >= table_bytes and readU32Le(bytes, 0) == table_bytes) {
        // Apple's current representation starts the cumulative offset table
        // at byte zero. Check it first because a 16,383-chunk table starts
        // with bytes that also resemble the legacy big-endian 0x100 header.
    } else if (bytes.len >= 0x104 and
        readU32Be(bytes, 0) == 0x100)
    {
        const data_size: usize = readU32Be(bytes, 8);
        const data_end = std.math.add(usize, 0x100, data_size) catch
            return error.IntegerOverflow;
        if (readU32Be(bytes, 4) != data_end or
            readU32Be(bytes, 12) != 0 or data_end != bytes.len or
            readU32Le(bytes, 0x100) != chunk_count)
            return error.InvalidDecmpfs;
        data_base = 0x100;
        table_offset = 0x104;
    } else {
        return error.InvalidDecmpfs;
    }
    if (bytes.len -| table_offset < table_bytes) return error.InvalidDecmpfs;
    const first: usize = readU32Le(bytes, table_offset);
    if (first != (if (data_base == 0) table_bytes else 4 + table_bytes))
        return error.InvalidDecmpfs;
    var previous = first;
    for (0..chunk_count) |index| {
        const next: usize = readU32Le(bytes, table_offset + (index + 1) * 4);
        const decoded_size = @min(
            block_size,
            uncompressed_size - index * block_size,
        );
        if (next <= previous or next > bytes.len - data_base or
            (compression_type == .lzvn_resource and
                next - previous > decoded_size + 1))
            return error.InvalidDecmpfs;
        previous = next;
    }
    if (previous != bytes.len - data_base) return error.InvalidDecmpfs;
    return .{
        .bytes = bytes,
        .compression_type = compression_type,
        .uncompressed_size = uncompressed_size,
        .chunk_count = chunk_count,
        .layout = .offset_table,
        .table_offset = table_offset,
        .data_base = data_base,
    };
}

fn readU32Le(bytes: []const u8, offset: usize) u32 {
    return std.mem.readInt(u32, bytes[offset..][0..4], .little);
}

fn readU64Le(bytes: []const u8, offset: usize) u64 {
    return std.mem.readInt(u64, bytes[offset..][0..8], .little);
}

fn readU32Be(bytes: []const u8, offset: usize) u32 {
    return std.mem.readInt(u32, bytes[offset..][0..4], .big);
}

fn readU16Be(bytes: []const u8, offset: usize) u16 {
    return std.mem.readInt(u16, bytes[offset..][0..2], .big);
}
