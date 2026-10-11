const std = @import("std");
const checksum = @import("../checksum.zig");
const core = @import("../core.zig");

pub const Error = core.Error || error{
    InvalidEwf,
    UnsupportedEwfFeature,
    UnsupportedEwfCompression,
    IncompleteEwf,
};

pub const file_header_size: usize = 13;
pub const section_descriptor_size: usize = 76;
pub const table_header_size: usize = 24;
pub const table_entry_size: usize = 4;
pub const table_footer_size: usize = 4;
pub const ewf1_signature = "EVF\x09\x0d\x0a\xff\x00";
pub const compressed_offset_flag: u32 = 1 << 31;
pub const offset_mask: u32 = compressed_offset_flag - 1;

pub const FileHeader = struct {
    segment_number: u16,
};

pub const Section = struct {
    kind: []const u8,
    offset: usize,
    next_offset: usize,
    size: u64,
    data: []const u8,

    pub fn isTerminal(self: Section) bool {
        return std.mem.eql(u8, self.kind, "done") or
            std.mem.eql(u8, self.kind, "next") or
            std.mem.eql(u8, self.kind, "incomplete");
    }
};

pub const Geometry = struct {
    chunk_count: usize,
    sectors_per_chunk: usize,
    bytes_per_sector: usize,
    sector_count: u64,
    chunk_size: usize,
    media_size: u64,
    compression_level: u8,
};

pub const TableHeader = struct {
    entry_count: usize,
    base_offset: u64,
};

pub fn parseFileHeader(input: []const u8) Error!FileHeader {
    if (input.len < file_header_size) return error.TruncatedFrame;
    if (!std.mem.eql(u8, input[0..8], ewf1_signature))
        return error.InvalidMagic;
    if (input[8] != 1 or input[11] != 0 or input[12] != 0)
        return error.InvalidEwf;
    const segment_number = readU16Le(input, 9);
    if (segment_number == 0) return error.InvalidEwf;
    return .{ .segment_number = segment_number };
}

pub fn parseSection(
    input: []const u8,
    offset: usize,
    verify_checksum: bool,
) Error!Section {
    const descriptor_end = std.math.add(
        usize,
        offset,
        section_descriptor_size,
    ) catch return error.IntegerOverflow;
    if (descriptor_end > input.len) return error.TruncatedFrame;
    const descriptor = input[offset..descriptor_end];
    if (verify_checksum and
        readU32Le(descriptor, 72) != checksum.adler32(descriptor[0..72]))
        return error.ChecksumMismatch;
    const kind_end = std.mem.indexOfScalar(u8, descriptor[0..16], 0) orelse 16;
    if (kind_end == 0) return error.InvalidEwf;
    const kind = descriptor[0..kind_end];
    for (kind) |byte|
        if (byte < 0x20 or byte > 0x7e) return error.InvalidEwf;
    const next_offset_u64 = readU64Le(descriptor, 16);
    const next_offset = std.math.cast(usize, next_offset_u64) orelse
        return error.IntegerOverflow;
    const size = readU64Le(descriptor, 24);
    const terminal = std.mem.eql(u8, kind, "done") or
        std.mem.eql(u8, kind, "next") or
        std.mem.eql(u8, kind, "incomplete");
    if (terminal) {
        if (next_offset != offset) return error.InvalidEwf;
        if (size != 0 and size != section_descriptor_size)
            return error.InvalidEwf;
        return .{
            .kind = kind,
            .offset = offset,
            .next_offset = next_offset,
            .size = size,
            .data = "",
        };
    }
    if (next_offset < descriptor_end or next_offset > input.len)
        return error.TruncatedFrame;
    if (size != 0 and size != next_offset_u64 - offset)
        return error.InvalidEwf;
    return .{
        .kind = kind,
        .offset = offset,
        .next_offset = next_offset,
        .size = size,
        .data = input[descriptor_end..next_offset],
    };
}

pub fn parseGeometry(data: []const u8, verify_checksum: bool) Error!Geometry {
    var chunk_count: u64 = undefined;
    var sectors_per_chunk: u64 = undefined;
    var bytes_per_sector: u64 = undefined;
    var sector_count: u64 = undefined;
    var compression_level: u8 = 0;
    if (data.len >= 1052) {
        if (verify_checksum and
            readU32Le(data, 1048) != checksum.adler32(data[0..1048]))
            return error.ChecksumMismatch;
        chunk_count = readU32Le(data, 4);
        sectors_per_chunk = readU32Le(data, 8);
        bytes_per_sector = readU32Le(data, 12);
        sector_count = readU64Le(data, 16);
        compression_level = data[52];
    } else if (data.len >= 94) {
        if (verify_checksum and
            readU32Le(data, 90) != checksum.adler32(data[0..90]))
            return error.ChecksumMismatch;
        chunk_count = readU32Le(data, 4);
        sectors_per_chunk = readU32Le(data, 8);
        bytes_per_sector = readU32Le(data, 12);
        sector_count = readU32Le(data, 16);
    } else {
        return error.TruncatedFrame;
    }
    if (sectors_per_chunk == 0 or bytes_per_sector == 0)
        return error.InvalidEwf;
    if (bytes_per_sector > 64 * 1024 or sectors_per_chunk > 32768)
        return error.UnsupportedEwfFeature;
    const chunk_size_u64 = std.math.mul(
        u64,
        sectors_per_chunk,
        bytes_per_sector,
    ) catch return error.IntegerOverflow;
    const media_size = std.math.mul(
        u64,
        sector_count,
        bytes_per_sector,
    ) catch return error.IntegerOverflow;
    const expected_chunks = std.math.divCeil(
        u64,
        media_size,
        chunk_size_u64,
    ) catch return error.IntegerOverflow;
    if (expected_chunks != chunk_count) return error.InvalidEwf;
    return .{
        .chunk_count = std.math.cast(usize, chunk_count) orelse
            return error.IntegerOverflow,
        .sectors_per_chunk = std.math.cast(usize, sectors_per_chunk) orelse
            return error.IntegerOverflow,
        .bytes_per_sector = std.math.cast(usize, bytes_per_sector) orelse
            return error.IntegerOverflow,
        .sector_count = sector_count,
        .chunk_size = std.math.cast(usize, chunk_size_u64) orelse
            return error.IntegerOverflow,
        .media_size = media_size,
        .compression_level = compression_level,
    };
}

pub fn parseTableHeader(
    data: []const u8,
    verify_checksum: bool,
) Error!TableHeader {
    if (data.len < table_header_size) return error.TruncatedFrame;
    if (verify_checksum and
        readU32Le(data, 20) != checksum.adler32(data[0..20]))
        return error.ChecksumMismatch;
    return .{
        .entry_count = readU32Le(data, 0),
        .base_offset = readU64Le(data, 8),
    };
}

pub fn readU16Le(bytes: []const u8, offset: usize) u16 {
    return std.mem.readInt(u16, bytes[offset..][0..2], .little);
}

pub fn readU32Le(bytes: []const u8, offset: usize) u32 {
    return std.mem.readInt(u32, bytes[offset..][0..4], .little);
}

pub fn readU64Le(bytes: []const u8, offset: usize) u64 {
    return std.mem.readInt(u64, bytes[offset..][0..8], .little);
}

pub fn writeU16Le(bytes: []u8, offset: usize, value: u16) void {
    std.mem.writeInt(u16, bytes[offset..][0..2], value, .little);
}

pub fn writeU32Le(bytes: []u8, offset: usize, value: u32) void {
    std.mem.writeInt(u32, bytes[offset..][0..4], value, .little);
}

pub fn writeU64Le(bytes: []u8, offset: usize, value: u64) void {
    std.mem.writeInt(u64, bytes[offset..][0..8], value, .little);
}
