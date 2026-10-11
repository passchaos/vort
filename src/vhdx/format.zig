const std = @import("std");
const checksum = @import("../checksum.zig");
const core = @import("../core.zig");

pub const Error = core.Error || error{
    InvalidVhdx,
    UnsupportedVhdxFeature,
    MissingVhdxParent,
};

pub const Guid = [16]u8;
pub const mib: usize = 1024 * 1024;
pub const file_identifier_offset: usize = 0;
pub const header1_offset: usize = 64 * 1024;
pub const header2_offset: usize = 128 * 1024;
pub const region1_offset: usize = 192 * 1024;
pub const region2_offset: usize = 256 * 1024;
pub const header_section_size: usize = mib;
pub const header_checksum_size: usize = 4096;
pub const region_table_size: usize = 64 * 1024;
pub const metadata_table_area_size: usize = 64 * 1024;
pub const maximum_image_size: u64 = 64 * 1024 * 1024 * 1024 * 1024;
pub const maximum_sectors_per_block: u64 = 1 << 23;
pub const bat_file_offset_mask: u64 = 0xffff_ffff_fff0_0000;

pub const bat_guid: Guid = .{ 0x66, 0x77, 0xc2, 0x2d, 0x23, 0xf6, 0x00, 0x42, 0x9d, 0x64, 0x11, 0x5e, 0x9b, 0xfd, 0x4a, 0x08 };
pub const metadata_guid: Guid = .{ 0x06, 0xa2, 0x7c, 0x8b, 0x90, 0x47, 0x9a, 0x4b, 0xb8, 0xfe, 0x57, 0x5f, 0x05, 0x0f, 0x88, 0x6e };
pub const file_parameters_guid: Guid = .{ 0x37, 0x67, 0xa1, 0xca, 0x36, 0xfa, 0x43, 0x4d, 0xb3, 0xb6, 0x33, 0xf0, 0xaa, 0x44, 0xe7, 0x6b };
pub const virtual_disk_size_guid: Guid = .{ 0x24, 0x42, 0xa5, 0x2f, 0x1b, 0xcd, 0x76, 0x48, 0xb2, 0x11, 0x5d, 0xbe, 0xd8, 0x3b, 0xf4, 0xb8 };
pub const page83_guid: Guid = .{ 0xab, 0x12, 0xca, 0xbe, 0xe6, 0xb2, 0x23, 0x45, 0x93, 0xef, 0xc3, 0x09, 0xe0, 0x00, 0xc7, 0x46 };
pub const logical_sector_size_guid: Guid = .{ 0x1d, 0xbf, 0x41, 0x81, 0x6f, 0xa9, 0x09, 0x47, 0xba, 0x47, 0xf2, 0x33, 0xa8, 0xfa, 0xab, 0x5f };
pub const physical_sector_size_guid: Guid = .{ 0xc7, 0x48, 0xa3, 0xcd, 0x5d, 0x44, 0x71, 0x44, 0x9c, 0xc9, 0xe9, 0x88, 0x52, 0x51, 0xc5, 0x56 };
pub const parent_locator_guid: Guid = .{ 0x2d, 0x5f, 0xd3, 0xa8, 0x0b, 0xb3, 0x4d, 0x45, 0xab, 0xf7, 0xd3, 0xd8, 0x48, 0x34, 0xab, 0x0c };
pub const parent_vhdx_guid: Guid = .{ 0xb7, 0xef, 0x4a, 0xb0, 0x9e, 0xd1, 0x81, 0x4a, 0xb7, 0x89, 0x25, 0xb8, 0xe9, 0x44, 0x59, 0x13 };

pub const PayloadState = enum(u3) {
    not_present = 0,
    undefined = 1,
    zero = 2,
    unmapped = 3,
    unmapped_v095 = 5,
    fully_present = 6,
    partially_present = 7,
};

pub const Header = struct {
    sequence_number: u64,
    file_write_guid: Guid,
    data_write_guid: Guid,
    log_guid: Guid,
    log_length: u32,
    log_offset: u64,
};

pub const Region = struct {
    offset: usize,
    length: usize,
};

pub const Regions = struct {
    bat: Region,
    metadata: Region,
};

pub const Metadata = struct {
    block_size: u32,
    virtual_disk_size: u64,
    logical_sector_size: u32,
    physical_sector_size: u32,
    page83_id: Guid,
    leave_blocks_allocated: bool,
    has_parent: bool,
    parent_linkage: ?Guid,
    data_block_count: usize,
    chunk_ratio: usize,
    bat_entry_count: usize,
};

pub fn parseHeader(input: []const u8, offset: usize) Error!Header {
    const end = std.math.add(usize, offset, header_checksum_size) catch
        return error.IntegerOverflow;
    if (end > input.len) return error.TruncatedFrame;
    const bytes = input[offset..end];
    if (!std.mem.eql(u8, bytes[0..4], "head")) return error.InvalidMagic;
    if (readU32Le(bytes, 4) != crc32cZeroField(bytes, 4))
        return error.ChecksumMismatch;
    if (readU16Le(bytes, 64) != 0 or readU16Le(bytes, 66) != 1)
        return error.UnsupportedVersion;
    var result: Header = .{
        .sequence_number = readU64Le(bytes, 8),
        .file_write_guid = undefined,
        .data_write_guid = undefined,
        .log_guid = undefined,
        .log_length = readU32Le(bytes, 68),
        .log_offset = readU64Le(bytes, 72),
    };
    @memcpy(&result.file_write_guid, bytes[16..32]);
    @memcpy(&result.data_write_guid, bytes[32..48]);
    @memcpy(&result.log_guid, bytes[48..64]);
    if (!std.mem.allEqual(u8, &result.log_guid, 0))
        return error.UnsupportedVhdxFeature;
    if (result.log_length != 0 and
        (result.log_length < mib or result.log_length % mib != 0 or
            result.log_offset % mib != 0))
        return error.InvalidVhdx;
    return result;
}

pub fn parseRegions(input: []const u8, offset: usize) Error!Regions {
    const end = std.math.add(usize, offset, region_table_size) catch
        return error.IntegerOverflow;
    if (end > input.len) return error.TruncatedFrame;
    const bytes = input[offset..end];
    if (!std.mem.eql(u8, bytes[0..4], "regi")) return error.InvalidMagic;
    if (readU32Le(bytes, 4) != crc32cZeroField(bytes, 4))
        return error.ChecksumMismatch;
    const entry_count: usize = readU32Le(bytes, 8);
    if (entry_count > 2047) return error.InvalidVhdx;
    const entries_end = 16 + entry_count * 32;
    if (entries_end > bytes.len) return error.InvalidVhdx;
    var bat: ?Region = null;
    var metadata: ?Region = null;
    for (0..entry_count) |index| {
        const entry = bytes[16 + index * 32 ..][0..32];
        var id: Guid = undefined;
        @memcpy(&id, entry[0..16]);
        const region_offset_u64 = readU64Le(entry, 16);
        const region_offset = std.math.cast(usize, region_offset_u64) orelse
            return error.IntegerOverflow;
        const region_length: usize = readU32Le(entry, 24);
        const flags = readU32Le(entry, 28);
        if (region_offset % mib != 0 or region_length == 0 or
            region_length % mib != 0)
            return error.InvalidVhdx;
        const region_end = std.math.add(usize, region_offset, region_length) catch
            return error.IntegerOverflow;
        if (region_end > input.len) return error.TruncatedFrame;
        const value = Region{ .offset = region_offset, .length = region_length };
        if (std.mem.eql(u8, &id, &bat_guid)) {
            if (bat != null) return error.InvalidVhdx;
            bat = value;
        } else if (std.mem.eql(u8, &id, &metadata_guid)) {
            if (metadata != null) return error.InvalidVhdx;
            metadata = value;
        } else if (flags & 1 != 0) {
            return error.UnsupportedVhdxFeature;
        }
    }
    return .{
        .bat = bat orelse return error.InvalidVhdx,
        .metadata = metadata orelse return error.InvalidVhdx,
    };
}

pub fn parseMetadata(input: []const u8, region: Region) Error!Metadata {
    const bytes = input[region.offset..][0..region.length];
    if (bytes.len < metadata_table_area_size or
        !std.mem.eql(u8, bytes[0..8], "metadata"))
        return error.InvalidMagic;
    const entry_count: usize = readU16Le(bytes, 10);
    if (entry_count > 2047 or 32 + entry_count * 32 > metadata_table_area_size)
        return error.InvalidVhdx;
    const Item = struct { offset: usize, length: usize };
    var params: ?Item = null;
    var virtual_size: ?Item = null;
    var page83: ?Item = null;
    var logical_sector: ?Item = null;
    var physical_sector: ?Item = null;
    var parent_locator: ?Item = null;
    for (0..entry_count) |index| {
        const entry = bytes[32 + index * 32 ..][0..32];
        var id: Guid = undefined;
        @memcpy(&id, entry[0..16]);
        const item = Item{
            .offset = readU32Le(entry, 16),
            .length = readU32Le(entry, 20),
        };
        const flags = readU32Le(entry, 24);
        if (flags & ~@as(u32, 7) != 0)
            return error.InvalidVhdx;
        if (item.length == 0) {
            if (item.offset != 0) return error.InvalidVhdx;
        } else {
            if (item.offset < metadata_table_area_size) return error.InvalidVhdx;
            const item_end = std.math.add(usize, item.offset, item.length) catch
                return error.IntegerOverflow;
            if (item_end > bytes.len) return error.TruncatedFrame;
        }
        if (std.mem.eql(u8, &id, &file_parameters_guid)) {
            if (params != null) return error.InvalidVhdx;
            params = item;
        } else if (std.mem.eql(u8, &id, &virtual_disk_size_guid)) {
            if (virtual_size != null) return error.InvalidVhdx;
            virtual_size = item;
        } else if (std.mem.eql(u8, &id, &page83_guid)) {
            if (page83 != null) return error.InvalidVhdx;
            page83 = item;
        } else if (std.mem.eql(u8, &id, &logical_sector_size_guid)) {
            if (logical_sector != null) return error.InvalidVhdx;
            logical_sector = item;
        } else if (std.mem.eql(u8, &id, &physical_sector_size_guid)) {
            if (physical_sector != null) return error.InvalidVhdx;
            physical_sector = item;
        } else if (std.mem.eql(u8, &id, &parent_locator_guid)) {
            if (parent_locator != null) return error.InvalidVhdx;
            parent_locator = item;
        } else if (flags & 4 != 0) {
            return error.UnsupportedVhdxFeature;
        }
    }
    const params_item = params orelse return error.UnsupportedVhdxFeature;
    const virtual_item = virtual_size orelse return error.UnsupportedVhdxFeature;
    const page83_item = page83 orelse return error.UnsupportedVhdxFeature;
    const logical_item = logical_sector orelse return error.UnsupportedVhdxFeature;
    const physical_item = physical_sector orelse return error.UnsupportedVhdxFeature;
    if (params_item.length != 8 or virtual_item.length != 8 or
        page83_item.length != 16 or logical_item.length != 4 or
        physical_item.length != 4)
        return error.InvalidVhdx;
    const block_size = readU32Le(bytes, params_item.offset);
    const parameter_flags = readU32Le(bytes, params_item.offset + 4);
    if (parameter_flags & ~@as(u32, 3) != 0)
        return error.InvalidVhdx;
    const has_parent = parameter_flags & 2 != 0;
    const parent_linkage = if (has_parent)
        try parseParentLocator(
            bytes,
            parent_locator orelse return error.InvalidVhdx,
        )
    else blk: {
        if (parent_locator != null) return error.InvalidVhdx;
        break :blk null;
    };
    if (block_size < mib or block_size > 256 * mib or
        !std.math.isPowerOfTwo(block_size))
        return error.InvalidVhdx;
    const disk_size = readU64Le(bytes, virtual_item.offset);
    const logical_size = readU32Le(bytes, logical_item.offset);
    const physical_size = readU32Le(bytes, physical_item.offset);
    if (disk_size > maximum_image_size or
        (logical_size != 512 and logical_size != 4096) or
        (physical_size != 512 and physical_size != 4096) or
        disk_size % logical_size != 0)
        return error.InvalidVhdx;
    const chunk_ratio_u64 = maximum_sectors_per_block * logical_size / block_size;
    const chunk_ratio = std.math.cast(usize, chunk_ratio_u64) orelse
        return error.IntegerOverflow;
    if (chunk_ratio == 0 or !std.math.isPowerOfTwo(chunk_ratio))
        return error.InvalidVhdx;
    const data_blocks = std.math.divCeil(u64, disk_size, block_size) catch
        return error.IntegerOverflow;
    const data_block_count = std.math.cast(usize, data_blocks) orelse
        return error.OutputLimitExceeded;
    const bitmap_block_count = std.math.divCeil(
        usize,
        data_block_count,
        chunk_ratio,
    ) catch return error.IntegerOverflow;
    const bat_entry_count = if (has_parent)
        std.math.mul(
            usize,
            bitmap_block_count,
            chunk_ratio + 1,
        ) catch return error.IntegerOverflow
    else if (data_block_count == 0)
        0
    else
        data_block_count + (data_block_count - 1) / chunk_ratio;
    var page83_id: Guid = undefined;
    @memcpy(&page83_id, bytes[page83_item.offset..][0..16]);
    return .{
        .block_size = block_size,
        .virtual_disk_size = disk_size,
        .logical_sector_size = logical_size,
        .physical_sector_size = physical_size,
        .page83_id = page83_id,
        .leave_blocks_allocated = parameter_flags & 1 != 0,
        .has_parent = has_parent,
        .parent_linkage = parent_linkage,
        .data_block_count = data_block_count,
        .chunk_ratio = chunk_ratio,
        .bat_entry_count = bat_entry_count,
    };
}

fn parseParentLocator(bytes: []const u8, item: anytype) Error!Guid {
    if (item.length < 20) return error.InvalidVhdx;
    const locator = bytes[item.offset..][0..item.length];
    if (!std.mem.eql(u8, locator[0..16], &parent_vhdx_guid))
        return error.UnsupportedVhdxFeature;
    const count: usize = readU16Le(locator, 18);
    const table_end = 20 + count * 12;
    if (count == 0 or table_end > locator.len) return error.InvalidVhdx;
    var linkage: ?Guid = null;
    var has_path = false;
    for (0..count) |index| {
        const entry = locator[20 + index * 12 ..][0..12];
        const key_offset: usize = readU32Le(entry, 0);
        const value_offset: usize = readU32Le(entry, 4);
        const key_length: usize = readU16Le(entry, 8);
        const value_length: usize = readU16Le(entry, 10);
        if (key_length == 0 or value_length == 0 or
            key_length % 2 != 0 or value_length % 2 != 0 or
            key_offset + key_length > locator.len or
            value_offset + value_length > locator.len)
            return error.InvalidVhdx;
        const key = locator[key_offset..][0..key_length];
        const value = locator[value_offset..][0..value_length];
        if (utf16LeEqualsAscii(key, "parent_linkage")) {
            if (linkage != null) return error.InvalidVhdx;
            linkage = try parseGuidText(value);
        } else if (utf16LeEqualsAscii(key, "parent_linkage2")) {
            return error.UnsupportedVhdxFeature;
        } else if (utf16LeEqualsAscii(key, "relative_path") or
            utf16LeEqualsAscii(key, "volume_path") or
            utf16LeEqualsAscii(key, "absolute_win32_path"))
        {
            has_path = true;
        }
    }
    if (!has_path) return error.InvalidVhdx;
    return linkage orelse error.InvalidVhdx;
}

fn utf16LeEqualsAscii(input: []const u8, expected: []const u8) bool {
    if (input.len != expected.len * 2) return false;
    for (expected, 0..) |byte, index|
        if (input[index * 2] != byte or input[index * 2 + 1] != 0) return false;
    return true;
}

fn parseGuidText(input: []const u8) Error!Guid {
    const code_units = input.len / 2;
    const start: usize = if (code_units == 38 and input[0] == '{' and input[1] == 0)
        1
    else if (code_units == 36)
        0
    else
        return error.InvalidVhdx;
    if (start == 1 and (input[74] != '}' or input[75] != 0))
        return error.InvalidVhdx;
    var compact: [32]u8 = undefined;
    var compact_len: usize = 0;
    for (start..start + 36) |unit| {
        const low = input[unit * 2];
        if (input[unit * 2 + 1] != 0) return error.InvalidVhdx;
        if (low == '-') continue;
        if (compact_len >= compact.len) return error.InvalidVhdx;
        compact[compact_len] = low;
        compact_len += 1;
    }
    if (compact_len != compact.len) return error.InvalidVhdx;
    var canonical: [16]u8 = undefined;
    _ = std.fmt.hexToBytes(&canonical, &compact) catch
        return error.InvalidVhdx;
    return .{
        canonical[3],  canonical[2],  canonical[1],  canonical[0],
        canonical[5],  canonical[4],  canonical[7],  canonical[6],
        canonical[8],  canonical[9],  canonical[10], canonical[11],
        canonical[12], canonical[13], canonical[14], canonical[15],
    };
}

pub fn crc32cZeroField(bytes: []const u8, field_offset: usize) u32 {
    var state = checksum.Crc32C.init();
    state.update(bytes[0..field_offset]);
    state.update(&.{ 0, 0, 0, 0 });
    state.update(bytes[field_offset + 4 ..]);
    return state.digest();
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
