const std = @import("std");
const core = @import("../core.zig");

pub const Error = core.Error || error{
    InvalidGcz,
};

pub const magic: u32 = 0xb10b_c001;
pub const header_size: usize = 32;
pub const pointer_entry_size: usize = 8;
pub const hash_entry_size: usize = 4;
pub const raw_flag: u64 = @as(u64, 1) << 63;
pub const offset_mask: u64 = ~raw_flag;

pub const Header = struct {
    sub_type: u32,
    compressed_data_size: u64,
    logical_size: u64,
    block_size: u32,
    block_count: usize,
};

pub fn parseHeader(input: []const u8) Error!Header {
    if (input.len < header_size) return error.TruncatedFrame;
    if (readU32Le(input, 0) != magic) return error.InvalidMagic;
    const block_size = readU32Le(input, 24);
    if (block_size == 0 or !std.math.isPowerOfTwo(block_size))
        return error.InvalidGcz;
    const logical_size = readU64Le(input, 16);
    const declared_blocks = readU32Le(input, 28);
    if (logical_size == 0 or declared_blocks == 0)
        return error.InvalidGcz;
    const expected_blocks = std.math.divCeil(
        u64,
        logical_size,
        block_size,
    ) catch return error.IntegerOverflow;
    if (expected_blocks != declared_blocks) return error.InvalidGcz;
    const block_count = std.math.cast(usize, expected_blocks) orelse
        return error.OutputLimitExceeded;
    const compressed_data_size = readU64Le(input, 8);
    if (compressed_data_size > offset_mask) return error.InvalidGcz;
    return .{
        .sub_type = readU32Le(input, 4),
        .compressed_data_size = compressed_data_size,
        .logical_size = logical_size,
        .block_size = block_size,
        .block_count = block_count,
    };
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

test "GCZ header parses exact block geometry" {
    var bytes = [_]u8{0} ** header_size;
    writeU32Le(&bytes, 0, magic);
    writeU32Le(&bytes, 4, 7);
    writeU64Le(&bytes, 8, 1234);
    writeU64Le(&bytes, 16, 2 * 4096 + 1);
    writeU32Le(&bytes, 24, 4096);
    writeU32Le(&bytes, 28, 3);
    const header = try parseHeader(&bytes);
    try std.testing.expectEqual(@as(u32, 7), header.sub_type);
    try std.testing.expectEqual(@as(usize, 3), header.block_count);
}
