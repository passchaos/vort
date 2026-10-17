const std = @import("std");
const core = @import("../core.zig");

pub const Error = core.Error || error{
    InvalidWim,
    UnsupportedWimVersion,
    UnsupportedWimCompression,
    UnsupportedWimFeature,
};

pub const magic = [_]u8{ 'M', 'S', 'W', 'I', 'M', 0, 0, 0 };
pub const pipable_magic = [_]u8{ 'W', 'L', 'P', 'W', 'M', 0, 0, 0 };
pub const header_size: usize = 208;
pub const default_version: u32 = 0x0001_0d00;
pub const solid_version: u32 = 0x0000_0e00;
pub const lookup_entry_size: usize = 50;

pub const Compression = enum {
    none,
    xpress,
    lzx,
    lzms,
};

pub const ResourceHeader = struct {
    size_in_wim: u64,
    flags: u8,
    offset_in_wim: u64,
    uncompressed_size: u64,

    pub fn isCompressed(self: ResourceHeader) bool {
        return self.flags & 0x04 != 0;
    }

    pub fn isMetadata(self: ResourceHeader) bool {
        return self.flags & 0x02 != 0;
    }

    pub fn isSolid(self: ResourceHeader) bool {
        return self.flags & 0x10 != 0;
    }

    pub fn isSpanned(self: ResourceHeader) bool {
        return self.flags & 0x08 != 0;
    }

    pub fn isZero(self: ResourceHeader) bool {
        return self.size_in_wim == 0 and self.flags == 0 and
            self.offset_in_wim == 0 and self.uncompressed_size == 0;
    }
};

pub const Header = struct {
    pipable: bool,
    version: u32,
    flags: u32,
    chunk_size: usize,
    guid: [16]u8,
    part_number: u16,
    total_parts: u16,
    image_count: u32,
    compression: Compression,
    lookup_table: ResourceHeader,
    xml_data: ResourceHeader,
    boot_metadata: ResourceHeader,
    boot_index: u32,
    integrity_table: ResourceHeader,
};

pub fn parseHeader(input: []const u8) Error!Header {
    if (input.len < header_size) return error.TruncatedFrame;
    if (std.mem.eql(u8, input[0..8], &magic)) {
        const header = try parseHeaderFields(input[0..header_size], false);
        try validateHeaderResources(header, input.len);
        return header;
    }
    if (!std.mem.eql(u8, input[0..8], &pipable_magic)) return error.InvalidMagic;
    if (input.len < 2 * header_size) return error.TruncatedFrame;

    const leading = try parseHeaderFields(input[0..header_size], true);
    if (!leading.lookup_table.isZero() or !leading.xml_data.isZero() or
        !leading.boot_metadata.isZero() or !leading.integrity_table.isZero())
        return error.InvalidWim;
    const trailing_offset = input.len - header_size;
    const trailing_bytes = input[trailing_offset..];
    if (!std.mem.eql(u8, trailing_bytes[0..8], &pipable_magic))
        return error.InvalidWim;
    const trailing = try parseHeaderFields(trailing_bytes, true);
    if (!headersDescribeSameArchive(leading, trailing)) return error.InvalidWim;
    try validateHeaderResources(trailing, trailing_offset);
    return trailing;
}

fn parseHeaderFields(input: []const u8, pipable: bool) Error!Header {
    if (input.len < header_size) return error.TruncatedFrame;
    const expected_magic = if (pipable) pipable_magic else magic;
    if (!std.mem.eql(u8, input[0..8], &expected_magic)) return error.InvalidMagic;
    if (readU32(input, 8) != header_size) return error.InvalidWim;
    const version = readU32(input, 12);
    if (version != default_version and version != solid_version)
        return error.UnsupportedWimVersion;
    const flags = readU32(input, 16);
    const compression = try compressionFromFlags(flags);
    const chunk_size: usize = readU32(input, 20);
    try validateChunkSize(compression, chunk_size);
    const part_number = readU16(input, 40);
    const total_parts = readU16(input, 42);
    if (part_number == 0 or total_parts == 0 or part_number > total_parts)
        return error.InvalidWim;
    const image_count = readU32(input, 44);
    if (image_count > 65_535) return error.InvalidWim;
    const boot_index = readU32(input, 120);
    if (boot_index > image_count) return error.InvalidWim;
    var guid: [16]u8 = undefined;
    @memcpy(&guid, input[24..40]);
    return .{
        .pipable = pipable,
        .version = version,
        .flags = flags,
        .chunk_size = chunk_size,
        .guid = guid,
        .part_number = part_number,
        .total_parts = total_parts,
        .image_count = image_count,
        .compression = compression,
        .lookup_table = try parseResourceHeader(input, 48),
        .xml_data = try parseResourceHeader(input, 72),
        .boot_metadata = try parseResourceHeader(input, 96),
        .boot_index = boot_index,
        .integrity_table = try parseResourceHeader(input, 124),
    };
}

fn headersDescribeSameArchive(leading: Header, trailing: Header) bool {
    return leading.pipable == trailing.pipable and
        leading.version == trailing.version and
        leading.flags == trailing.flags and
        leading.chunk_size == trailing.chunk_size and
        std.mem.eql(u8, &leading.guid, &trailing.guid) and
        leading.part_number == trailing.part_number and
        leading.total_parts == trailing.total_parts and
        leading.image_count == trailing.image_count and
        leading.compression == trailing.compression and
        leading.boot_index == trailing.boot_index;
}

fn validateHeaderResources(header: Header, resource_limit: usize) Error!void {
    try validateHeaderResource(header.lookup_table, resource_limit);
    try validateHeaderResource(header.xml_data, resource_limit);
    try validateHeaderResource(header.boot_metadata, resource_limit);
    try validateHeaderResource(header.integrity_table, resource_limit);
}

pub fn parseResourceHeader(input: []const u8, offset: usize) Error!ResourceHeader {
    if (input.len -| offset < 24) return error.TruncatedFrame;
    var size_in_wim: u64 = 0;
    for (0..7) |index|
        size_in_wim |= @as(u64, input[offset + index]) << @intCast(index * 8);
    const flags = input[offset + 7];
    if (flags & ~@as(u8, 0x1f) != 0) return error.InvalidWim;
    return .{
        .size_in_wim = size_in_wim,
        .flags = flags,
        .offset_in_wim = readU64(input, offset + 8),
        .uncompressed_size = readU64(input, offset + 16),
    };
}

fn compressionFromFlags(flags: u32) Error!Compression {
    const compression_enabled = flags & 0x0000_0002 != 0;
    const xpress = flags & (0x0002_0000 | 0x0020_0000) != 0;
    const lzx = flags & 0x0004_0000 != 0;
    const lzms = flags & 0x0008_0000 != 0;
    const count = @as(u2, @intFromBool(xpress)) + @intFromBool(lzx) + @intFromBool(lzms);
    if (!compression_enabled) {
        if (count != 0) return error.InvalidWim;
        return .none;
    }
    if (count != 1) return error.UnsupportedWimCompression;
    if (xpress) return .xpress;
    if (lzx) return .lzx;
    return .lzms;
}

pub fn validateChunkSize(compression: Compression, size: usize) Error!void {
    if (compression == .none) {
        if (size != 0) return error.InvalidWim;
        return;
    }
    if (!std.math.isPowerOfTwo(size)) return error.InvalidWim;
    const bounds: struct { min: usize, max: usize } = switch (compression) {
        .none => unreachable,
        .xpress => .{ .min = 4096, .max = 65_536 },
        .lzx => .{ .min = 32 * 1024, .max = 2 * 1024 * 1024 },
        .lzms => .{ .min = 32 * 1024, .max = 1024 * 1024 * 1024 },
    };
    if (size < bounds.min or size > bounds.max) return error.InvalidWim;
}

fn validateHeaderResource(resource: ResourceHeader, image_len: usize) Error!void {
    if (resource.isZero()) return;
    const start = std.math.cast(usize, resource.offset_in_wim) orelse
        return error.IntegerOverflow;
    const size = std.math.cast(usize, resource.size_in_wim) orelse
        return error.IntegerOverflow;
    const end = std.math.add(usize, start, size) catch return error.IntegerOverflow;
    if (start < header_size or end > image_len) return error.InvalidWim;
}

pub fn readU16(input: []const u8, offset: usize) u16 {
    return std.mem.readInt(u16, input[offset..][0..2], .little);
}

pub fn readU32(input: []const u8, offset: usize) u32 {
    return std.mem.readInt(u32, input[offset..][0..4], .little);
}

pub fn readU64(input: []const u8, offset: usize) u64 {
    return std.mem.readInt(u64, input[offset..][0..8], .little);
}

test "WIM header rejects bad geometry and compression flags" {
    var bytes: [header_size]u8 = @splat(0);
    @memcpy(bytes[0..8], &magic);
    std.mem.writeInt(u32, bytes[8..12], header_size, .little);
    std.mem.writeInt(u32, bytes[12..16], default_version, .little);
    std.mem.writeInt(u16, bytes[40..42], 1, .little);
    std.mem.writeInt(u16, bytes[42..44], 1, .little);
    _ = try parseHeader(&bytes);
    std.mem.writeInt(u32, bytes[16..20], 0x0000_0002 | 0x0002_0000, .little);
    std.mem.writeInt(u32, bytes[20..24], 32 * 1024, .little);
    try std.testing.expectEqual(Compression.xpress, (try parseHeader(&bytes)).compression);
    std.mem.writeInt(u32, bytes[16..20], 0x0000_0002 | 0x0002_0000 | 0x0004_0000, .little);
    try std.testing.expectError(error.UnsupportedWimCompression, parseHeader(&bytes));
    bytes[0] = 'x';
    try std.testing.expectError(error.InvalidMagic, parseHeader(&bytes));
}

test "pipable WIM uses matching trailing header" {
    var bytes: [2 * header_size]u8 = @splat(0);
    for ([_]usize{ 0, header_size }) |offset| {
        @memcpy(bytes[offset..][0..8], &pipable_magic);
        std.mem.writeInt(u32, bytes[offset + 8 ..][0..4], header_size, .little);
        std.mem.writeInt(u32, bytes[offset + 12 ..][0..4], default_version, .little);
        std.mem.writeInt(u16, bytes[offset + 40 ..][0..2], 1, .little);
        std.mem.writeInt(u16, bytes[offset + 42 ..][0..2], 1, .little);
    }
    const header = try parseHeader(&bytes);
    try std.testing.expect(header.pipable);

    bytes[48] = 1;
    try std.testing.expectError(error.InvalidWim, parseHeader(&bytes));
    bytes[48] = 0;
    bytes[header_size + 48] = 1;
    std.mem.writeInt(
        u64,
        bytes[header_size + 56 ..][0..8],
        header_size,
        .little,
    );
    std.mem.writeInt(u64, bytes[header_size + 64 ..][0..8], 1, .little);
    try std.testing.expectError(error.InvalidWim, parseHeader(&bytes));
    @memset(bytes[header_size + 48 .. header_size + 72], 0);

    bytes[header_size + 24] = 1;
    try std.testing.expectError(error.InvalidWim, parseHeader(&bytes));
    bytes[header_size + 24] = 0;
    bytes[header_size] = 'x';
    try std.testing.expectError(error.InvalidWim, parseHeader(&bytes));
}
