const std = @import("std");
const core = @import("../core.zig");

pub const Error = core.Error || error{
    InvalidDax,
};

pub const magic = "DAX\x00";
pub const header_size: usize = 32;
pub const frame_size: usize = 8192;
pub const offset_entry_size: usize = 4;
pub const size_entry_size: usize = 2;
pub const area_entry_size: usize = 8;

pub const Header = struct {
    uncompressed_size: u32,
    version: u32,
    nc_area_count: usize,
    frame_count: usize,
};

pub const NonCompressedArea = struct {
    start: usize,
    count: usize,

    pub fn end(self: NonCompressedArea) Error!usize {
        return std.math.add(usize, self.start, self.count) catch
            return error.IntegerOverflow;
    }
};

pub fn parseHeader(input: []const u8) Error!Header {
    if (input.len < header_size) return error.TruncatedFrame;
    if (!std.mem.eql(u8, input[0..4], magic)) return error.InvalidMagic;
    const version = readU32Le(input, 8);
    if (version > 1) return error.UnsupportedVersion;
    const uncompressed_size = readU32Le(input, 4);
    const frame_count = std.math.divCeil(
        usize,
        uncompressed_size,
        frame_size,
    ) catch return error.IntegerOverflow;
    return .{
        .uncompressed_size = uncompressed_size,
        .version = version,
        // Version 0 readers historically ignore this field, so do the same
        // for compatibility with headers that did not initialize it.
        .nc_area_count = if (version == 1) readU32Le(input, 12) else 0,
        .frame_count = frame_count,
    };
}

pub fn readArea(input: []const u8, offset: usize) NonCompressedArea {
    return .{
        .start = readU32Le(input, offset),
        .count = readU32Le(input, offset + 4),
    };
}

pub fn readU16Le(input: []const u8, offset: usize) u16 {
    return std.mem.readInt(u16, input[offset..][0..2], .little);
}

pub fn readU32Le(input: []const u8, offset: usize) u32 {
    return std.mem.readInt(u32, input[offset..][0..4], .little);
}

pub fn writeU16Le(output: []u8, offset: usize, value: u16) void {
    std.mem.writeInt(u16, output[offset..][0..2], value, .little);
}

pub fn writeU32Le(output: []u8, offset: usize, value: u32) void {
    std.mem.writeInt(u32, output[offset..][0..4], value, .little);
}

test "DAX header versions expose fixed frame geometry" {
    var bytes = [_]u8{0} ** header_size;
    @memcpy(bytes[0..4], magic);
    writeU32Le(&bytes, 4, frame_size * 2 + 1);
    writeU32Le(&bytes, 8, 1);
    writeU32Le(&bytes, 12, 3);
    const header = try parseHeader(&bytes);
    try std.testing.expectEqual(@as(usize, 3), header.frame_count);
    try std.testing.expectEqual(@as(usize, 3), header.nc_area_count);

    writeU32Le(&bytes, 8, 0);
    try std.testing.expectEqual(
        @as(usize, 0),
        (try parseHeader(&bytes)).nc_area_count,
    );
}
