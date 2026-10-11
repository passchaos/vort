const std = @import("std");
const core = @import("../core.zig");

pub const Error = core.Error || error{
    InvalidDmg,
    InvalidDmgPlist,
    UnsupportedDmgFeature,
    UnsupportedDmgMetadata,
    UnsupportedDmgChunk,
    UnsupportedDmgChecksum,
    EncryptedDmg,
};

pub const sector_size: usize = 512;
pub const trailer_size: usize = 512;
pub const mish_header_size: usize = 0xcc;
pub const block_record_size: usize = 40;
pub const koly_magic: u32 = 0x6b6f_6c79;
pub const mish_magic: u32 = 0x6d69_7368;

pub const ChunkKind = enum(u32) {
    zero = 0,
    copy = 1,
    zero_no_checksum = 2,
    adc = 0x8000_0004,
    zlib = 0x8000_0005,
    bzip2 = 0x8000_0006,
    lzfse = 0x8000_0007,
    xz = 0x8000_0008,
    comment = 0x7fff_fffe,
    end = 0xffff_ffff,

    pub fn isZero(self: ChunkKind) bool {
        return self == .zero or self == .zero_no_checksum;
    }

    pub fn isCompressed(self: ChunkKind) bool {
        return switch (self) {
            .adc, .zlib, .bzip2, .lzfse, .xz => true,
            else => false,
        };
    }
};

pub const Fork = struct {
    offset: u64,
    length: u64,

    pub fn end(self: Fork) Error!u64 {
        return std.math.add(u64, self.offset, self.length) catch
            error.IntegerOverflow;
    }

    pub fn slice(self: Fork, bytes: []const u8) Error![]const u8 {
        const start = std.math.cast(usize, self.offset) orelse
            return error.IntegerOverflow;
        const length = std.math.cast(usize, self.length) orelse
            return error.IntegerOverflow;
        const end_offset = std.math.add(usize, start, length) catch
            return error.IntegerOverflow;
        if (end_offset > bytes.len) return error.TruncatedFrame;
        return bytes[start..end_offset];
    }
};

pub const Checksum = struct {
    kind: u32,
    bits: u32,
    data: [128]u8,

    pub fn parse(bytes: []const u8, offset: usize) Checksum {
        var data: [128]u8 = undefined;
        @memcpy(&data, bytes[offset + 8 ..][0..128]);
        return .{
            .kind = readU32Be(bytes, offset),
            .bits = readU32Be(bytes, offset + 4),
            .data = data,
        };
    }

    pub fn validateSupported(self: Checksum) Error!void {
        if (self.bits == 0 and self.kind == 0) return;
        if (self.kind == 2 and self.bits == 32) return;
        return error.UnsupportedDmgChecksum;
    }

    pub fn crc32(self: Checksum) ?u32 {
        if (self.kind != 2 or self.bits != 32) return null;
        return std.mem.readInt(u32, self.data[0..4], .big);
    }
};

pub const Trailer = struct {
    header_offset: usize,
    at_front: bool,
    flags: u32,
    running_data_fork_offset: u64,
    data_fork: Fork,
    resource_fork: Fork,
    segment_number: u32,
    segment_count: u32,
    segment_id: [16]u8,
    data_fork_checksum: Checksum,
    xml: Fork,
    code_signature: Fork,
    master_checksum: Checksum,
    image_variant: u32,
    sector_count: u64,

    pub fn logicalSize(self: Trailer) Error!u64 {
        return std.math.mul(u64, self.sector_count, sector_size) catch
            error.IntegerOverflow;
    }
};

pub fn parseTrailer(bytes: []const u8) Error!Trailer {
    if (bytes.len >= 8 and std.mem.eql(u8, bytes[0..8], "encrcdsa"))
        return error.EncryptedDmg;
    if (bytes.len < trailer_size) return error.TruncatedFrame;
    const end_offset = bytes.len - trailer_size;
    const header_offset = if (isKoly(bytes[end_offset..]))
        end_offset
    else if (isKoly(bytes[0..trailer_size]))
        0
    else
        return error.InvalidMagic;
    const at_front = header_offset == 0;
    const header = bytes[header_offset..][0..trailer_size];
    const data_fork = parseFork(header, 0x18);
    const resource_fork = parseFork(header, 0x28);
    const xml = parseFork(header, 0xd8);
    const raw_code_signature = parseFork(header, 0x128);
    const fork_limit: u64 = if (at_front) bytes.len else header_offset;
    // Older images are observed with garbage in this optional field. Match
    // Apple's readers and 7-Zip by ignoring only an out-of-range code blob;
    // required data/XML/resource forks remain strict below.
    const code_signature = if (forkIsValid(raw_code_signature, fork_limit, at_front))
        raw_code_signature
    else
        Fork{ .offset = 0, .length = 0 };
    const trailer = Trailer{
        .header_offset = header_offset,
        .at_front = at_front,
        .flags = readU32Be(header, 0x0c),
        .running_data_fork_offset = readU64Be(header, 0x10),
        .data_fork = data_fork,
        .resource_fork = resource_fork,
        .segment_number = readU32Be(header, 0x38),
        .segment_count = readU32Be(header, 0x3c),
        .segment_id = header[0x40..0x50].*,
        .data_fork_checksum = Checksum.parse(header, 0x50),
        .xml = xml,
        .code_signature = code_signature,
        .master_checksum = Checksum.parse(header, 0x160),
        .image_variant = readU32Be(header, 0x1e8),
        .sector_count = readU64Be(header, 0x1ec),
    };
    if (trailer.segment_count > 1) return error.UnsupportedDmgFeature;
    try trailer.data_fork_checksum.validateSupported();
    try trailer.master_checksum.validateSupported();
    try validateFork(data_fork, fork_limit, at_front);
    try validateFork(resource_fork, fork_limit, at_front);
    try validateFork(xml, fork_limit, at_front);
    _ = try trailer.logicalSize();
    return trailer;
}

fn forkIsValid(fork: Fork, limit: u64, at_front: bool) bool {
    const end_offset = std.math.add(u64, fork.offset, fork.length) catch
        return false;
    if (end_offset > limit) return false;
    if (at_front and fork.length != 0 and fork.offset < trailer_size) return false;
    return true;
}

fn isKoly(header: []const u8) bool {
    return header.len >= trailer_size and
        readU32Be(header, 0) == koly_magic and
        readU32Be(header, 4) == 4 and
        readU32Be(header, 8) == trailer_size;
}

fn parseFork(header: []const u8, offset: usize) Fork {
    return .{
        .offset = readU64Be(header, offset),
        .length = readU64Be(header, offset + 8),
    };
}

fn validateFork(fork: Fork, limit: u64, at_front: bool) Error!void {
    const end_offset = try fork.end();
    if (end_offset > limit) return error.InvalidDmg;
    if (at_front and fork.length != 0 and fork.offset < trailer_size)
        return error.InvalidDmg;
}

pub fn readU32Be(bytes: []const u8, offset: usize) u32 {
    return std.mem.readInt(u32, bytes[offset..][0..4], .big);
}

pub fn readU64Be(bytes: []const u8, offset: usize) u64 {
    return std.mem.readInt(u64, bytes[offset..][0..8], .big);
}

pub fn writeU32Be(bytes: []u8, offset: usize, value: u32) void {
    std.mem.writeInt(u32, bytes[offset..][0..4], value, .big);
}

pub fn writeU64Be(bytes: []u8, offset: usize, value: u64) void {
    std.mem.writeInt(u64, bytes[offset..][0..8], value, .big);
}
