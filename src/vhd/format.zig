const std = @import("std");
const core = @import("../core.zig");

pub const Error = core.Error || error{
    InvalidVhd,
    UnsupportedVhdFeature,
    MissingVhdParent,
};

pub const sector_size: usize = 512;
pub const footer_size: usize = 512;
pub const dynamic_header_size: usize = 1024;
pub const footer_cookie = "conectix";
pub const dynamic_cookie = "cxsparse";
pub const version: u32 = 0x0001_0000;
pub const unallocated_bat_entry: u32 = 0xffff_ffff;
pub const maximum_sectors: u64 = 0xff00_0000;

pub const DiskType = enum(u32) {
    fixed = 2,
    dynamic = 3,
    differencing = 4,
};

pub const Geometry = struct {
    cylinders: u16,
    heads: u8,
    sectors_per_track: u8,
};

pub const Footer = struct {
    features: u32,
    data_offset: u64,
    timestamp: u32,
    creator_app: [4]u8,
    creator_version: u32,
    creator_os: [4]u8,
    original_size: u64,
    current_size: u64,
    geometry: Geometry,
    disk_type: DiskType,
    checksum: u32,
    unique_id: [16]u8,
    saved_state: bool,
};

pub const DynamicHeader = struct {
    table_offset: u64,
    max_table_entries: usize,
    block_size: u32,
    checksum: u32,
    parent_unique_id: [16]u8,
    parent_timestamp: u32,
    parent_name_utf16be: []const u8,

    pub fn sectorsPerBlock(self: DynamicHeader) usize {
        return self.block_size / sector_size;
    }

    pub fn bitmapSize(self: DynamicHeader) usize {
        const bitmap_bytes = std.math.divCeil(
            usize,
            self.sectorsPerBlock(),
            8,
        ) catch unreachable;
        return std.mem.alignForward(usize, bitmap_bytes, sector_size);
    }
};

pub fn parseFooter(input: []const u8) Error!Footer {
    if (input.len < footer_size) return error.TruncatedFrame;
    const offset = input.len - footer_size;
    return parseFooterAt(input, offset);
}

pub fn parseFooterAt(input: []const u8, offset: usize) Error!Footer {
    const end = std.math.add(usize, offset, footer_size) catch
        return error.IntegerOverflow;
    if (end > input.len) return error.TruncatedFrame;
    const bytes = input[offset..end];
    if (!std.mem.eql(u8, bytes[0..8], footer_cookie))
        return error.InvalidMagic;
    const expected_checksum = readU32Be(bytes, 64);
    if (footerChecksum(bytes) != expected_checksum)
        return error.ChecksumMismatch;
    if (readU32Be(bytes, 12) != version) return error.UnsupportedVersion;
    const disk_type = std.enums.fromInt(DiskType, readU32Be(bytes, 60)) orelse
        return error.UnsupportedVhdFeature;
    const current_size = readU64Be(bytes, 48);
    if (current_size % sector_size != 0) return error.InvalidVhd;
    if (current_size / sector_size > maximum_sectors)
        return error.OutputLimitExceeded;
    const data_offset = readU64Be(bytes, 16);
    switch (disk_type) {
        .fixed => if (data_offset != std.math.maxInt(u64)) return error.InvalidVhd,
        .dynamic, .differencing => if (data_offset > input.len - footer_size)
            return error.TruncatedFrame,
    }
    var creator_app: [4]u8 = undefined;
    var creator_os: [4]u8 = undefined;
    var unique_id: [16]u8 = undefined;
    @memcpy(&creator_app, bytes[28..32]);
    @memcpy(&creator_os, bytes[36..40]);
    @memcpy(&unique_id, bytes[68..84]);
    return .{
        .features = readU32Be(bytes, 8),
        .data_offset = data_offset,
        .timestamp = readU32Be(bytes, 24),
        .creator_app = creator_app,
        .creator_version = readU32Be(bytes, 32),
        .creator_os = creator_os,
        .original_size = readU64Be(bytes, 40),
        .current_size = current_size,
        .geometry = .{
            .cylinders = readU16Be(bytes, 56),
            .heads = bytes[58],
            .sectors_per_track = bytes[59],
        },
        .disk_type = disk_type,
        .checksum = expected_checksum,
        .unique_id = unique_id,
        .saved_state = bytes[84] != 0,
    };
}

pub fn parseDynamicHeader(
    input: []const u8,
    footer: Footer,
) Error!DynamicHeader {
    if (footer.disk_type == .fixed) return error.InvalidVhd;
    const offset = std.math.cast(usize, footer.data_offset) orelse
        return error.IntegerOverflow;
    const end = std.math.add(usize, offset, dynamic_header_size) catch
        return error.IntegerOverflow;
    if (end > input.len) return error.TruncatedFrame;
    const bytes = input[offset..end];
    if (!std.mem.eql(u8, bytes[0..8], dynamic_cookie))
        return error.InvalidMagic;
    if (readU64Be(bytes, 8) != std.math.maxInt(u64) or
        readU32Be(bytes, 24) != version)
        return error.UnsupportedVersion;
    const expected_checksum = readU32Be(bytes, 36);
    if (dynamicHeaderChecksum(bytes) != expected_checksum)
        return error.ChecksumMismatch;
    const block_size = readU32Be(bytes, 32);
    if (block_size < sector_size or !std.math.isPowerOfTwo(block_size) or
        block_size % sector_size != 0)
        return error.InvalidVhd;
    const max_table_entries: usize = readU32Be(bytes, 28);
    const represented_size = std.math.mul(
        u64,
        max_table_entries,
        block_size,
    ) catch return error.IntegerOverflow;
    if (represented_size < footer.current_size) return error.InvalidVhd;
    var parent_unique_id: [16]u8 = undefined;
    @memcpy(&parent_unique_id, bytes[40..56]);
    return .{
        .table_offset = readU64Be(bytes, 16),
        .max_table_entries = max_table_entries,
        .block_size = block_size,
        .checksum = expected_checksum,
        .parent_unique_id = parent_unique_id,
        .parent_timestamp = readU32Be(bytes, 56),
        .parent_name_utf16be = bytes[64..576],
    };
}

pub fn footerChecksum(bytes: []const u8) u32 {
    var sum: u32 = 0;
    for (bytes[0..footer_size], 0..) |byte, index| {
        if (index < 64 or index >= 68) sum +%= byte;
    }
    return ~sum;
}

pub fn dynamicHeaderChecksum(bytes: []const u8) u32 {
    var sum: u32 = 0;
    for (bytes[0..dynamic_header_size], 0..) |byte, index| {
        if (index < 36 or index >= 40) sum +%= byte;
    }
    return ~sum;
}

pub fn readU16Be(bytes: []const u8, offset: usize) u16 {
    return std.mem.readInt(u16, bytes[offset..][0..2], .big);
}

pub fn readU32Be(bytes: []const u8, offset: usize) u32 {
    return std.mem.readInt(u32, bytes[offset..][0..4], .big);
}

pub fn readU64Be(bytes: []const u8, offset: usize) u64 {
    return std.mem.readInt(u64, bytes[offset..][0..8], .big);
}

pub fn writeU16Be(bytes: []u8, offset: usize, value: u16) void {
    std.mem.writeInt(u16, bytes[offset..][0..2], value, .big);
}

pub fn writeU32Be(bytes: []u8, offset: usize, value: u32) void {
    std.mem.writeInt(u32, bytes[offset..][0..4], value, .big);
}

pub fn writeU64Be(bytes: []u8, offset: usize, value: u64) void {
    std.mem.writeInt(u64, bytes[offset..][0..8], value, .big);
}

test "VHD checksum excludes its checksum word" {
    var footer = [_]u8{0} ** footer_size;
    @memcpy(footer[0..8], footer_cookie);
    writeU32Be(&footer, 64, footerChecksum(&footer));
    try std.testing.expectEqual(readU32Be(&footer, 64), footerChecksum(&footer));
    footer[100] ^= 1;
    try std.testing.expect(readU32Be(&footer, 64) != footerChecksum(&footer));
}
