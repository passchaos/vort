const std = @import("std");
const core = @import("../core.zig");

pub const Error = core.Error || error{
    InvalidWia,
    UnsupportedWiaFeature,
    UnsupportedWiaCodec,
};

pub const header1_size: usize = 0x48;
pub const header2_size: usize = 0xdc;
pub const header2_min_size: usize = 0xd5;
pub const partition_entry_size: usize = 0x30;
pub const raw_entry_size: usize = 0x18;
pub const wia_group_entry_size: usize = 0x08;
pub const rvz_group_entry_size: usize = 0x0c;
pub const disc_header_size: usize = 0x80;
pub const wii_block_size: usize = 0x8000;
pub const wii_group_size: usize = 0x20_0000;
pub const wia_magic: u32 = 0x0141_4957;
pub const rvz_magic: u32 = 0x015a_5652;
pub const current_version: u32 = 0x0100_0000;
pub const wia_read_compatible: u32 = 0x0008_0000;
pub const rvz_read_compatible: u32 = 0x0003_0000;
pub const rvz_write_compatible: u32 = 0x0003_0000;

pub const Container = enum {
    wia,
    rvz,

    pub fn magic(self: Container) u32 {
        return switch (self) {
            .wia => wia_magic,
            .rvz => rvz_magic,
        };
    }

    pub fn groupEntrySize(self: Container) usize {
        return switch (self) {
            .wia => wia_group_entry_size,
            .rvz => rvz_group_entry_size,
        };
    }
};

pub const Compression = enum(u32) {
    none = 0,
    purge = 1,
    bzip2 = 2,
    lzma = 3,
    lzma2 = 4,
    zstd = 5,
};

pub const Header1 = struct {
    container: Container,
    version: u32,
    compatible_version: u32,
    header2_bytes: usize,
    logical_size: u64,
    file_size: u64,
};

pub const Header2 = struct {
    disc_type: u32,
    compression: Compression,
    compression_level: i32,
    chunk_size: u32,
    disc_header: [disc_header_size]u8,
    partition_count: usize,
    partition_bytes: usize,
    partition_offset: u64,
    partition_hash: [20]u8,
    raw_count: usize,
    raw_offset: u64,
    raw_bytes: usize,
    group_count: usize,
    group_offset: u64,
    group_bytes: usize,
    compressor_data: [7]u8,
    compressor_data_len: u8,
};

pub const RawEntry = struct {
    data_offset: u64,
    data_size: u64,
    group_index: usize,
    group_count: usize,
};

pub const GroupEntry = struct {
    data_offset: u64,
    stored_size: usize,
    compressed: bool,
    rvz_packed_size: usize,
};

pub fn parseHeader1(input: []const u8) Error!Header1 {
    if (input.len < header1_size) return error.TruncatedFrame;
    const raw_magic = readU32Le(input, 0);
    const container: Container = if (raw_magic == wia_magic)
        .wia
    else if (raw_magic == rvz_magic)
        .rvz
    else
        return error.InvalidMagic;
    const version = readU32Be(input, 4);
    const compatible = readU32Be(input, 8);
    const minimum_read = if (container == .wia)
        wia_read_compatible
    else
        rvz_read_compatible;
    if (current_version < compatible or minimum_read > version)
        return error.UnsupportedVersion;
    const header2_bytes: usize = readU32Be(input, 12);
    if (header2_bytes < header2_min_size)
        return error.InvalidWia;
    var actual_hash: [20]u8 = undefined;
    std.crypto.hash.Sha1.hash(input[0..0x34], &actual_hash, .{});
    if (!std.mem.eql(u8, &actual_hash, input[0x34..0x48]))
        return error.ChecksumMismatch;
    const file_size = readU64Be(input, 0x2c);
    if (file_size != input.len) return error.SizeMismatch;
    return .{
        .container = container,
        .version = version,
        .compatible_version = compatible,
        .header2_bytes = header2_bytes,
        .logical_size = readU64Be(input, 0x24),
        .file_size = file_size,
    };
}

pub fn parseHeader2(input: []const u8, header1: Header1) Error!Header2 {
    const end = std.math.add(usize, header1_size, header1.header2_bytes) catch
        return error.IntegerOverflow;
    if (end > input.len) return error.TruncatedFrame;
    var actual_hash: [20]u8 = undefined;
    std.crypto.hash.Sha1.hash(input[header1_size..end], &actual_hash, .{});
    if (!std.mem.eql(u8, &actual_hash, input[0x10..0x24]))
        return error.ChecksumMismatch;
    const bytes = input[header1_size..end];
    const compression = std.enums.fromInt(
        Compression,
        readU32Be(bytes, 4),
    ) orelse return error.UnsupportedWiaCodec;
    if (header1.container == .wia and compression == .zstd or
        header1.container == .rvz and compression == .purge)
        return error.UnsupportedWiaCodec;
    const chunk_size = readU32Be(bytes, 12);
    if (!validChunkSize(header1.container, chunk_size))
        return error.InvalidWia;
    const compressor_data_len = bytes[212];
    if (compressor_data_len > 7 or
        header1.header2_bytes < header2_min_size + compressor_data_len)
        return error.InvalidWia;
    switch (compression) {
        .lzma => if (compressor_data_len != 5)
            return error.InvalidWia,
        .lzma2 => if (compressor_data_len != 1 or bytes[213] > 40)
            return error.InvalidWia,
        .none, .purge, .bzip2, .zstd => if (compressor_data_len != 0)
            return error.InvalidWia,
    }
    var disc_header: [disc_header_size]u8 = undefined;
    @memcpy(&disc_header, bytes[16..144]);
    var partition_hash: [20]u8 = undefined;
    @memcpy(&partition_hash, bytes[160..180]);
    var compressor_data = [_]u8{0} ** 7;
    const available_compressor_bytes = @min(
        @as(usize, 7),
        header1.header2_bytes - header2_min_size,
    );
    @memcpy(
        compressor_data[0..available_compressor_bytes],
        bytes[213..][0..available_compressor_bytes],
    );
    return .{
        .disc_type = readU32Be(bytes, 0),
        .compression = compression,
        .compression_level = @bitCast(readU32Be(bytes, 8)),
        .chunk_size = chunk_size,
        .disc_header = disc_header,
        .partition_count = readU32Be(bytes, 144),
        .partition_bytes = readU32Be(bytes, 148),
        .partition_offset = readU64Be(bytes, 152),
        .partition_hash = partition_hash,
        .raw_count = readU32Be(bytes, 180),
        .raw_offset = readU64Be(bytes, 184),
        .raw_bytes = readU32Be(bytes, 192),
        .group_count = readU32Be(bytes, 196),
        .group_offset = readU64Be(bytes, 200),
        .group_bytes = readU32Be(bytes, 208),
        .compressor_data = compressor_data,
        .compressor_data_len = compressor_data_len,
    };
}

pub fn parseRawEntry(bytes: []const u8) Error!RawEntry {
    if (bytes.len < raw_entry_size) return error.TruncatedFrame;
    return .{
        .data_offset = readU64Be(bytes, 0),
        .data_size = readU64Be(bytes, 8),
        .group_index = readU32Be(bytes, 16),
        .group_count = readU32Be(bytes, 20),
    };
}

pub fn parseGroupEntry(
    container: Container,
    bytes: []const u8,
) Error!GroupEntry {
    if (bytes.len < container.groupEntrySize()) return error.TruncatedFrame;
    const data_size = readU32Be(bytes, 4);
    return .{
        .data_offset = @as(u64, readU32Be(bytes, 0)) << 2,
        .stored_size = if (container == .rvz)
            data_size & 0x7fff_ffff
        else
            data_size,
        .compressed = container == .wia or data_size & 0x8000_0000 != 0,
        .rvz_packed_size = if (container == .rvz) readU32Be(bytes, 8) else 0,
    };
}

pub fn validChunkSize(container: Container, chunk_size: u32) bool {
    if (chunk_size == 0) return false;
    if (container == .wia) return chunk_size % wii_group_size == 0;
    if (chunk_size >= wii_block_size and std.math.isPowerOfTwo(chunk_size))
        return true;
    return chunk_size % wii_group_size == 0;
}

pub fn readU32Le(input: []const u8, offset: usize) u32 {
    return std.mem.readInt(u32, input[offset..][0..4], .little);
}

pub fn readU32Be(input: []const u8, offset: usize) u32 {
    return std.mem.readInt(u32, input[offset..][0..4], .big);
}

pub fn readU64Be(input: []const u8, offset: usize) u64 {
    return std.mem.readInt(u64, input[offset..][0..8], .big);
}

pub fn writeU32Le(output: []u8, offset: usize, value: u32) void {
    std.mem.writeInt(u32, output[offset..][0..4], value, .little);
}

pub fn writeU32Be(output: []u8, offset: usize, value: u32) void {
    std.mem.writeInt(u32, output[offset..][0..4], value, .big);
}

pub fn writeU64Be(output: []u8, offset: usize, value: u64) void {
    std.mem.writeInt(u64, output[offset..][0..8], value, .big);
}
