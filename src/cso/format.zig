const std = @import("std");
const core = @import("../core.zig");

pub const Error = core.Error || error{
    InvalidCso,
    UnsupportedCsoCodec,
};

pub const header_size: usize = 24;
pub const raw_flag: u32 = 0x8000_0000;
pub const offset_mask: u32 = 0x7fff_ffff;
pub const minimum_block_size: u32 = 2048;
pub const maximum_block_size: u32 = 256 * 1024;

pub const Format = enum {
    cso1,
    cso2,
    zso,

    pub fn magic(self: Format) *const [4]u8 {
        return switch (self) {
            .cso1, .cso2 => "CISO",
            .zso => "ZISO",
        };
    }

    pub fn version(self: Format) u8 {
        return switch (self) {
            .cso1, .zso => 1,
            .cso2 => 2,
        };
    }
};

pub const Codec = enum {
    raw,
    deflate,
    lz4,
};

pub const Header = struct {
    format: Format,
    header_bytes: usize,
    uncompressed_size: u64,
    block_size: u32,
    version: u8,
    index_shift: u8,
    block_count: usize,

    pub fn alignment(self: Header) u64 {
        return @as(u64, 1) << @intCast(self.index_shift);
    }
};

pub fn parseHeader(input: []const u8) Error!Header {
    if (input.len < header_size) return error.TruncatedFrame;
    const version = input[20];
    const image_format: Format = if (std.mem.eql(u8, input[0..4], "CISO"))
        switch (version) {
            0, 1 => .cso1,
            2 => .cso2,
            else => return error.UnsupportedVersion,
        }
    else if (std.mem.eql(u8, input[0..4], "ZISO"))
        if (version == 1) .zso else return error.UnsupportedVersion
    else
        return error.InvalidMagic;

    const declared_header_size = readU32Le(input, 4);
    // Early CISO v1 tools did not reliably initialize this field.  The wire
    // layout still places the index immediately after the fixed 24-byte header.
    const declared_header_bytes = switch (image_format) {
        .cso1 => header_size,
        .cso2, .zso => blk: {
            if (declared_header_size != header_size or
                input[22] != 0 or input[23] != 0)
                return error.InvalidCso;
            break :blk header_size;
        },
    };

    const block_size = readU32Le(input, 16);
    if (block_size < minimum_block_size or
        block_size > maximum_block_size or
        !std.math.isPowerOfTwo(block_size))
        return error.InvalidCso;
    const index_shift = input[21];
    if (index_shift > 32) return error.InvalidCso;
    const uncompressed_size = readU64Le(input, 8);
    const block_count_u64 = std.math.divCeil(
        u64,
        uncompressed_size,
        block_size,
    ) catch return error.IntegerOverflow;
    const block_count = std.math.cast(usize, block_count_u64) orelse
        return error.OutputLimitExceeded;
    return .{
        .format = image_format,
        .header_bytes = declared_header_bytes,
        .uncompressed_size = uncompressed_size,
        .block_size = block_size,
        .version = version,
        .index_shift = index_shift,
        .block_count = block_count,
    };
}

pub fn codecForIndex(
    image_format: Format,
    raw_index: u32,
    stored_span: u64,
    block_size: u32,
) Codec {
    return switch (image_format) {
        .cso1 => if (raw_index & raw_flag != 0) .raw else .deflate,
        .zso => if (raw_index & raw_flag != 0) .raw else .lz4,
        .cso2 => if (stored_span >= block_size)
            .raw
        else if (raw_index & raw_flag != 0)
            .lz4
        else
            .deflate,
    };
}

pub fn physicalOffset(raw_index: u32, index_shift: u8) Error!u64 {
    if (index_shift > 32) return error.InvalidCso;
    return @as(u64, raw_index & offset_mask) << @intCast(index_shift);
}

pub fn readU32Le(input: []const u8, offset: usize) u32 {
    return std.mem.readInt(u32, input[offset..][0..4], .little);
}

pub fn readU64Le(input: []const u8, offset: usize) u64 {
    return std.mem.readInt(u64, input[offset..][0..8], .little);
}

pub fn writeU32Le(output: []u8, offset: usize, value: u32) void {
    std.mem.writeInt(u32, output[offset..][0..4], value, .little);
}

pub fn writeU64Le(output: []u8, offset: usize, value: u64) void {
    std.mem.writeInt(u64, output[offset..][0..8], value, .little);
}

test "CSO parses CISO and ZISO headers" {
    var bytes = [_]u8{0} ** header_size;
    @memcpy(bytes[0..4], "CISO");
    writeU32Le(&bytes, 4, header_size);
    writeU64Le(&bytes, 8, 4097);
    writeU32Le(&bytes, 16, 2048);
    bytes[20] = 2;
    bytes[21] = 3;
    const cso = try parseHeader(&bytes);
    try std.testing.expectEqual(Format.cso2, cso.format);
    try std.testing.expectEqual(@as(usize, 3), cso.block_count);
    try std.testing.expectEqual(@as(u64, 8), cso.alignment());

    @memcpy(bytes[0..4], "ZISO");
    bytes[20] = 1;
    try std.testing.expectEqual(Format.zso, (try parseHeader(&bytes)).format);

    @memcpy(bytes[0..4], "CISO");
    writeU32Le(&bytes, 4, 0xdead_beef);
    bytes[20] = 0;
    try std.testing.expectEqual(Format.cso1, (try parseHeader(&bytes)).format);
}

test "CSO2 codec flag differs from CSO1 raw flag" {
    try std.testing.expectEqual(Codec.raw, codecForIndex(.cso1, raw_flag, 100, 2048));
    try std.testing.expectEqual(Codec.lz4, codecForIndex(.cso2, raw_flag, 100, 2048));
    try std.testing.expectEqual(Codec.raw, codecForIndex(.cso2, 0, 2048, 2048));
}
