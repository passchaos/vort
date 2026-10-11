const std = @import("std");
const core = @import("../core.zig");

pub const Error = core.Error || error{
    InvalidChd,
    InvalidChdMap,
    InvalidChdMetadata,
    UnsupportedChdCodec,
    MissingChdParent,
};

pub const signature = "MComprHD";
pub const version: u32 = 5;
pub const header_size: usize = 124;
pub const compressed_map_header_size: usize = 16;
pub const expanded_map_entry_size: usize = 12;
pub const metadata_header_size: usize = 16;
pub const metadata_checksum_flag: u8 = 0x01;
pub const maximum_hunk_bytes: u32 = 512 * 1024;

pub const Codec = enum(u32) {
    none = 0,
    zlib = tag("zlib"),
    lzma = tag("lzma"),
    huffman = tag("huff"),
    flac = tag("flac"),
    zstd = tag("zstd"),
    cd_zlib = tag("cdzl"),
    cd_lzma = tag("cdlz"),
    cd_flac = tag("cdfl"),
    cd_zstd = tag("cdzs"),
    av_huffman = tag("avhu"),

    pub fn name(self: Codec) []const u8 {
        return switch (self) {
            .none => "none",
            .zlib => "zlib",
            .lzma => "lzma",
            .huffman => "huff",
            .flac => "flac",
            .zstd => "zstd",
            .cd_zlib => "cdzl",
            .cd_lzma => "cdlz",
            .cd_flac => "cdfl",
            .cd_zstd => "cdzs",
            .av_huffman => "avhu",
        };
    }
};

pub const MapType = enum(u8) {
    codec_0 = 0,
    codec_1 = 1,
    codec_2 = 2,
    codec_3 = 3,
    uncompressed = 4,
    self = 5,
    parent = 6,

    // These values only occur in the entropy-coded map. They are converted
    // to one of the seven materialized types while the map is expanded.
    rle_small = 7,
    rle_large = 8,
    self_0 = 9,
    self_1 = 10,
    parent_self = 11,
    parent_0 = 12,
    parent_1 = 13,
};

pub const Header = struct {
    compressors: [4]u32,
    logical_bytes: u64,
    map_offset: u64,
    metadata_offset: u64,
    hunk_bytes: u32,
    unit_bytes: u32,
    raw_sha1: [20]u8,
    combined_sha1: [20]u8,
    parent_sha1: [20]u8,
    hunk_count: usize,
    unit_count: u64,

    pub fn isCompressed(self: Header) bool {
        return self.compressors[0] != 0;
    }

    pub fn hasParent(self: Header) bool {
        return !std.mem.allEqual(u8, &self.parent_sha1, 0);
    }

    pub fn codec(self: Header, slot: usize) Error!Codec {
        if (slot >= self.compressors.len) return error.InvalidChdMap;
        return std.enums.fromInt(Codec, self.compressors[slot]) orelse
            return error.UnsupportedChdCodec;
    }
};

pub const CompressedMapHeader = struct {
    encoded_bytes: usize,
    first_data_offset: u64,
    expanded_crc16: u16,
    length_bits: u8,
    self_bits: u8,
    parent_unit_bits: u8,
};

pub const MapEntry = struct {
    kind: MapType,
    length: u32,
    offset: u64,
    crc16: u16,

    pub fn writeExpanded(self: MapEntry, output: *[expanded_map_entry_size]u8) void {
        output[0] = @intFromEnum(self.kind);
        writeU24Be(output, 1, self.length);
        writeU48Be(output, 4, self.offset);
        writeU16Be(output, 10, self.crc16);
    }
};

pub const Metadata = struct {
    tag: u32,
    flags: u8,
    data: []const u8,
    offset: usize,
    next_offset: u64,

    pub fn tagBytes(self: Metadata) [4]u8 {
        var bytes: [4]u8 = undefined;
        std.mem.writeInt(u32, &bytes, self.tag, .big);
        return bytes;
    }
};

pub fn parseHeader(input: []const u8) Error!Header {
    if (input.len < 16) return error.TruncatedFrame;
    if (!std.mem.eql(u8, input[0..8], signature)) return error.InvalidMagic;
    if (readU32Be(input, 8) != header_size) return error.InvalidChd;
    if (readU32Be(input, 12) != version) return error.UnsupportedVersion;
    if (input.len < header_size) return error.TruncatedFrame;

    const logical_bytes = readU64Be(input, 32);
    const map_offset = readU64Be(input, 40);
    const metadata_offset = readU64Be(input, 48);
    const hunk_bytes = readU32Be(input, 56);
    const unit_bytes = readU32Be(input, 60);
    if (hunk_bytes == 0 or hunk_bytes > maximum_hunk_bytes or
        unit_bytes == 0 or hunk_bytes % unit_bytes != 0)
        return error.InvalidChd;
    if (map_offset > input.len or metadata_offset > input.len)
        return error.TruncatedFrame;

    const hunk_count_u64 = std.math.divCeil(
        u64,
        logical_bytes,
        hunk_bytes,
    ) catch return error.IntegerOverflow;
    const hunk_count = std.math.cast(usize, hunk_count_u64) orelse
        return error.OutputLimitExceeded;
    const unit_count = std.math.divCeil(
        u64,
        logical_bytes,
        unit_bytes,
    ) catch return error.IntegerOverflow;

    var parsed: Header = .{
        .compressors = .{
            readU32Be(input, 16),
            readU32Be(input, 20),
            readU32Be(input, 24),
            readU32Be(input, 28),
        },
        .logical_bytes = logical_bytes,
        .map_offset = map_offset,
        .metadata_offset = metadata_offset,
        .hunk_bytes = hunk_bytes,
        .unit_bytes = unit_bytes,
        .raw_sha1 = undefined,
        .combined_sha1 = undefined,
        .parent_sha1 = undefined,
        .hunk_count = hunk_count,
        .unit_count = unit_count,
    };
    @memcpy(&parsed.raw_sha1, input[64..84]);
    @memcpy(&parsed.combined_sha1, input[84..104]);
    @memcpy(&parsed.parent_sha1, input[104..124]);

    if (!parsed.isCompressed()) {
        if (!std.mem.allEqual(u32, &parsed.compressors, 0))
            return error.InvalidChd;
    } else {
        for (parsed.compressors, 0..) |compressor, index| {
            if (compressor == 0) {
                for (parsed.compressors[index..]) |remaining|
                    if (remaining != 0) return error.InvalidChd;
                break;
            }
        }
    }
    return parsed;
}

pub fn parseCompressedMapHeader(input: []const u8, offset: usize) Error!CompressedMapHeader {
    const end = std.math.add(usize, offset, compressed_map_header_size) catch
        return error.IntegerOverflow;
    if (end > input.len) return error.TruncatedFrame;
    const bytes = input[offset..end];
    const encoded_bytes: usize = readU32Be(bytes, 0);
    const length_bits = bytes[12];
    const self_bits = bytes[13];
    const parent_unit_bits = bytes[14];
    if (length_bits > 24 or self_bits > 32 or parent_unit_bits > 32 or
        bytes[15] != 0)
        return error.InvalidChdMap;
    const payload_end = std.math.add(usize, end, encoded_bytes) catch
        return error.IntegerOverflow;
    if (payload_end > input.len) return error.TruncatedFrame;
    return .{
        .encoded_bytes = encoded_bytes,
        .first_data_offset = readU48Be(bytes, 4),
        .expanded_crc16 = readU16Be(bytes, 10),
        .length_bits = length_bits,
        .self_bits = self_bits,
        .parent_unit_bits = parent_unit_bits,
    };
}

pub fn parseExpandedMapEntry(bytes: []const u8) Error!MapEntry {
    if (bytes.len < expanded_map_entry_size) return error.TruncatedFrame;
    const kind = std.enums.fromInt(MapType, bytes[0]) orelse
        return error.InvalidChdMap;
    if (@intFromEnum(kind) > @intFromEnum(MapType.parent))
        return error.InvalidChdMap;
    return .{
        .kind = kind,
        .length = readU24Be(bytes, 1),
        .offset = readU48Be(bytes, 4),
        .crc16 = readU16Be(bytes, 10),
    };
}

pub fn parseMetadata(input: []const u8, offset: usize) Error!Metadata {
    const header_end = std.math.add(usize, offset, metadata_header_size) catch
        return error.IntegerOverflow;
    if (header_end > input.len) return error.TruncatedFrame;
    const length_and_flags = readU32Be(input, offset + 4);
    const length: usize = length_and_flags & 0x00ff_ffff;
    const data_end = std.math.add(usize, header_end, length) catch
        return error.IntegerOverflow;
    if (data_end > input.len) return error.TruncatedFrame;
    const next_offset = readU64Be(input, offset + 8);
    if (next_offset > input.len or next_offset == offset)
        return error.InvalidChdMetadata;
    return .{
        .tag = readU32Be(input, offset),
        .flags = @truncate(length_and_flags >> 24),
        .data = input[header_end..data_end],
        .offset = offset,
        .next_offset = next_offset,
    };
}

pub fn tag(comptime bytes: *const [4]u8) u32 {
    return (@as(u32, bytes[0]) << 24) |
        (@as(u32, bytes[1]) << 16) |
        (@as(u32, bytes[2]) << 8) |
        bytes[3];
}

pub fn crc16(input: []const u8) u16 {
    return crc16Update(0xffff, input);
}

pub fn crc16Update(initial: u16, input: []const u8) u16 {
    var crc = initial;
    for (input) |byte| {
        crc ^= @as(u16, byte) << 8;
        for (0..8) |_| {
            crc = if (crc & 0x8000 != 0)
                (crc << 1) ^ 0x1021
            else
                crc << 1;
        }
    }
    return crc;
}

/// Reproduce the LZMA SDK dictionary-size normalization used by CHD v5. The
/// raw hunk payload carries no properties, so encoder and decoder must derive
/// this value independently from the hunk size.
pub fn alignedLzmaDictionarySize(hunk_bytes: u32) u32 {
    const level: u5 = 6;
    var dictionary_size: u32 = @as(u32, 1) << (level + 20);
    if (dictionary_size > hunk_bytes)
        dictionary_size = @min(dictionary_size, @max(hunk_bytes, 1 << 12));
    if (dictionary_size >= 1 << 21) {
        const mask: u32 = (1 << 20) - 1;
        return (dictionary_size + mask) & ~mask;
    }
    var index: u8 = 22;
    while (true) : (index += 1) {
        const aligned = @as(u32, 2 + (index & 1)) << @as(u5, @intCast(index >> 1));
        if (aligned >= dictionary_size) return aligned;
    }
}

pub fn readU16Be(bytes: []const u8, offset: usize) u16 {
    return std.mem.readInt(u16, bytes[offset..][0..2], .big);
}

pub fn readU24Be(bytes: []const u8, offset: usize) u32 {
    return (@as(u32, bytes[offset]) << 16) |
        (@as(u32, bytes[offset + 1]) << 8) |
        bytes[offset + 2];
}

pub fn readU32Be(bytes: []const u8, offset: usize) u32 {
    return std.mem.readInt(u32, bytes[offset..][0..4], .big);
}

pub fn readU48Be(bytes: []const u8, offset: usize) u64 {
    return (@as(u64, readU16Be(bytes, offset)) << 32) |
        readU32Be(bytes, offset + 2);
}

pub fn readU64Be(bytes: []const u8, offset: usize) u64 {
    return std.mem.readInt(u64, bytes[offset..][0..8], .big);
}

pub fn writeU16Be(bytes: []u8, offset: usize, value: u16) void {
    std.mem.writeInt(u16, bytes[offset..][0..2], value, .big);
}

pub fn writeU24Be(bytes: []u8, offset: usize, value: u32) void {
    bytes[offset] = @truncate(value >> 16);
    bytes[offset + 1] = @truncate(value >> 8);
    bytes[offset + 2] = @truncate(value);
}

pub fn writeU32Be(bytes: []u8, offset: usize, value: u32) void {
    std.mem.writeInt(u32, bytes[offset..][0..4], value, .big);
}

pub fn writeU48Be(bytes: []u8, offset: usize, value: u64) void {
    writeU16Be(bytes, offset, @truncate(value >> 32));
    writeU32Be(bytes, offset + 2, @truncate(value));
}

pub fn writeU64Be(bytes: []u8, offset: usize, value: u64) void {
    std.mem.writeInt(u64, bytes[offset..][0..8], value, .big);
}

test "CHD CRC-16 matches CCITT false vector" {
    try std.testing.expectEqual(@as(u16, 0x29b1), crc16("123456789"));
}

test "CHD v5 header parses canonical fields" {
    var bytes = [_]u8{0} ** header_size;
    @memcpy(bytes[0..8], signature);
    writeU32Be(&bytes, 8, header_size);
    writeU32Be(&bytes, 12, version);
    writeU32Be(&bytes, 16, @intFromEnum(Codec.zlib));
    writeU64Be(&bytes, 32, 9000);
    writeU64Be(&bytes, 40, header_size);
    writeU32Be(&bytes, 56, 4096);
    writeU32Be(&bytes, 60, 512);
    const header = try parseHeader(&bytes);
    try std.testing.expectEqual(@as(usize, 3), header.hunk_count);
    try std.testing.expectEqual(@as(u64, 18), header.unit_count);
    try std.testing.expectEqual(Codec.zlib, try header.codec(0));
}

test "CHD LZMA dictionary alignment mirrors SDK properties" {
    try std.testing.expectEqual(@as(u32, 4096), alignedLzmaDictionarySize(1));
    try std.testing.expectEqual(@as(u32, 4096), alignedLzmaDictionarySize(4096));
    try std.testing.expectEqual(@as(u32, 6144), alignedLzmaDictionarySize(5000));
    try std.testing.expectEqual(@as(u32, 1 << 20), alignedLzmaDictionarySize(1 << 20));
}
