const std = @import("std");
const core = @import("../core.zig");

pub const Error = core.Error || error{
    InvalidWux,
    UnsupportedWuxFeature,
};

pub const magic0 = "WUX0";
pub const magic1: u32 = 0x1099_d02e;
pub const header_size: usize = 32;
pub const default_sector_size: u32 = 0x8000;
pub const min_sector_size: u32 = 0x100;
pub const format_max_sector_size: u32 = 0x1000_0000;
pub const standard_wud_size: u64 = 25_025_314_816;

pub const Header = struct {
    sector_size: usize,
    logical_size: u64,
    flags: u32,
    sector_count: usize,
    unique_sector_count: usize,
    data_offset: usize,
    physical_size: usize,
};

pub fn sectorCount(logical_size: u64, sector_size: usize) Error!usize {
    return std.math.cast(
        usize,
        std.math.divCeil(u64, logical_size, sector_size) catch
            return error.IntegerOverflow,
    ) orelse return error.IntegerOverflow;
}

pub fn dataOffset(sector_count: usize, sector_size: usize) Error!usize {
    const table_size = std.math.mul(usize, sector_count, 4) catch
        return error.IntegerOverflow;
    const metadata_size = std.math.add(
        usize,
        header_size,
        table_size,
    ) catch return error.IntegerOverflow;
    const sectors = std.math.divCeil(usize, metadata_size, sector_size) catch
        return error.IntegerOverflow;
    return std.math.mul(usize, sectors, sector_size) catch
        return error.IntegerOverflow;
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
