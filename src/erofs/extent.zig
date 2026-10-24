const std = @import("std");
const core = @import("../core.zig");
const format = @import("format.zig");
const input_module = @import("reader/input.zig");

pub const Error = core.Error || format.Error || input_module.Error ||
    error{ InvalidErofs, UnsupportedErofsCompression };

pub const View = struct {
    file_size: usize,
    advise: u16,
    cluster_bits: u8,
    record_start: usize,
    record_size: u8,
    record_count: usize,
};

pub const Record = struct {
    logical_start: usize,
    physical_start: u64,
    encoded_len: usize,
    format_code: u4,
    partial: bool = false,
    fragment_offset: ?u64 = null,
};

pub fn readRecordInput(input: input_module.Input, view: View, index: usize, cumulative_physical: *u64) Error!Record {
    if (view.record_size != 4 and view.record_size != 8 and view.record_size != 16 and view.record_size != 32) return error.InvalidErofs;
    if (view.cluster_bits >= @bitSizeOf(usize)) return error.UnsupportedErofsFeature;
    const records_base = std.math.add(usize, view.record_start, if (view.record_size == 4) @as(usize, 8) else 0) catch return error.IntegerOverflow;
    const start = std.math.add(
        usize,
        records_base,
        std.math.mul(usize, index, view.record_size) catch return error.IntegerOverflow,
    ) catch return error.IntegerOverflow;
    var buffer: [32]u8 = undefined;
    const bytes = buffer[0..view.record_size];
    try input.read(start, bytes);
    const encoded = format.readU32(bytes, 0);
    const encoded_len: usize = encoded & 0x001f_ffff;
    const format_code: u4 = @truncate(encoded >> 28);

    const cluster_size: usize = @as(usize, 1) << @intCast(view.cluster_bits);
    const logical_start = if (view.record_size >= 16)
        std.math.cast(
            usize,
            @as(u64, format.readU32(bytes, 12)) |
                (if (view.record_size >= 32)
                    @as(u64, format.readU32(bytes, 16)) << 32
                else
                    0),
        ) orelse return error.IntegerOverflow
    else
        std.math.mul(usize, index, cluster_size) catch return error.IntegerOverflow;
    const fragment = view.advise & 0x20 != 0 and index + 1 == view.record_count;
    const physical_start: u64 = if (view.record_size == 4) blk: {
        const result = cumulative_physical.*;
        if (!fragment) cumulative_physical.* = std.math.add(u64, result, encoded_len) catch
            return error.IntegerOverflow;
        break :blk result;
    } else @as(u64, format.readU32(bytes, 4)) |
        (if (view.record_size >= 16)
            @as(u64, format.readU32(bytes, 8)) << 32
        else
            0);
    if (fragment) return .{ .logical_start = logical_start, .physical_start = 0, .encoded_len = 0, .format_code = 0, .fragment_offset = @as(u64, encoded) | (if (view.record_size >= 8) @as(u64, format.readU32(bytes, 4)) << 32 else 0) };
    if (encoded_len != 0 and format_code > 4) return error.UnsupportedErofsCompression;
    return .{
        .logical_start = logical_start,
        .physical_start = physical_start,
        .encoded_len = encoded_len,
        .format_code = if (encoded_len == 0) 0 else format_code,
        .partial = encoded & (@as(u32, 1) << 27) != 0,
    };
}

test "EROFS 48-bit extent records parse 8 16 and 32 byte layouts" {
    var image: [2048]u8 = @splat(0);
    @memset(image[1024..1536], 'A');
    @memset(image[1536..2048], 'B');
    const superblock = format.Superblock{
        .checksum = 0,
        .feature_compat = 0,
        .feature_incompat = format.feature_incompat_48bit,
        .block_bits = 9,
        .block_size = 512,
        .super_size = 128,
        .root_nid = 1,
        .inode_count = 1,
        .epoch = 0,
        .fixed_nsec = 0,
        .block_count = 4,
        .meta_block = 0,
        .xattr_block = 0,
        .xattr_prefix_count = 0,
        .xattr_prefix_start = 0,
        .packed_nid = 0,
        .metabox_nid = 0,
        .extra_devices = 0,
        .device_slot_offset = 0,
        .available_compression_algorithms = 0,
        .build_time = 0,
    };

    inline for (.{ @as(u8, 8), @as(u8, 16), @as(u8, 32) }) |record_size| {
        @memset(image[0..64], 0);
        writeRawRecord(&image, 0, record_size, 512, 1024, 0);
        writeRawRecord(&image, record_size, record_size, 512, 1536, 512);
        var cumulative: u64 = 0;
        const view = View{ .file_size = 1024, .advise = 0, .cluster_bits = superblock.block_bits, .record_start = 0, .record_size = record_size, .record_count = 2 };
        const first = try readRecordInput(.{ .slice = &image }, view, 0, &cumulative);
        const second = try readRecordInput(.{ .slice = &image }, view, 1, &cumulative);
        try std.testing.expectEqual(@as(u64, 1024), first.physical_start);
        try std.testing.expectEqual(@as(u64, 1536), second.physical_start);
        try std.testing.expectEqual(@as(usize, 512), second.logical_start);
        try std.testing.expectEqual(@as(usize, 512), first.encoded_len);
        try std.testing.expect(!first.partial and first.fragment_offset == null);
    }
}

fn writeRawRecord(
    image: []u8,
    start: usize,
    record_size: u8,
    encoded_len: u32,
    physical_start: u64,
    logical_start: u64,
) void {
    std.mem.writeInt(u32, image[start..][0..4], encoded_len, .little);
    std.mem.writeInt(u32, image[start + 4 ..][0..4], @truncate(physical_start), .little);
    if (record_size >= 16) {
        std.mem.writeInt(u32, image[start + 8 ..][0..4], @truncate(physical_start >> 32), .little);
        std.mem.writeInt(u32, image[start + 12 ..][0..4], @truncate(logical_start), .little);
    }
    if (record_size >= 32)
        std.mem.writeInt(u32, image[start + 16 ..][0..4], @truncate(logical_start >> 32), .little);
}
