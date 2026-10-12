const std = @import("std");
const core = @import("../core.zig");

pub const Error = core.Error || error{
    InvalidWbfs,
    UnsupportedWbfsFeature,
};

pub const magic = "WBFS";
pub const header_prefix_size: usize = 12;
pub const disc_header_size: usize = 0x100;
pub const wii_sector_shift: u8 = 15;
pub const wii_sector_size: u64 = 1 << wii_sector_shift;
pub const wii_sector_count: u64 = 143_432 * 2;
pub const logical_size: u64 = wii_sector_size * wii_sector_count;

pub const Header = struct {
    hd_sector_count: u32,
    hd_sector_shift: u8,
    wbfs_sector_shift: u8,
    hd_sector_size: usize,
    wbfs_sector_size: usize,
    wbfs_sector_count: usize,
    blocks_per_disc: usize,
    disc_info_size: usize,
    disc_slot: usize,
};

pub fn blocksPerDisc(wbfs_sector_size: usize) Error!usize {
    return std.math.cast(
        usize,
        std.math.divCeil(u64, logical_size, wbfs_sector_size) catch
            return error.IntegerOverflow,
    ) orelse return error.IntegerOverflow;
}

pub fn discInfoSize(
    blocks_per_disc: usize,
    hd_sector_size: usize,
) Error!usize {
    const table_bytes = std.math.mul(usize, blocks_per_disc, 2) catch
        return error.IntegerOverflow;
    const raw_size = std.math.add(
        usize,
        disc_header_size,
        table_bytes,
    ) catch return error.IntegerOverflow;
    return std.mem.alignForward(usize, raw_size, hd_sector_size);
}

pub fn readU16Be(input: []const u8, offset: usize) u16 {
    return std.mem.readInt(u16, input[offset..][0..2], .big);
}

pub fn readU32Be(input: []const u8, offset: usize) u32 {
    return std.mem.readInt(u32, input[offset..][0..4], .big);
}

pub fn writeU16Be(output: []u8, offset: usize, value: u16) void {
    std.mem.writeInt(u16, output[offset..][0..2], value, .big);
}

pub fn writeU32Be(output: []u8, offset: usize, value: u32) void {
    std.mem.writeInt(u32, output[offset..][0..4], value, .big);
}
