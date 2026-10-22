const std = @import("std");
const core = @import("../core.zig");
const codec = @import("codec.zig");
const format = @import("format.zig");
const input_module = @import("reader/input.zig");

pub const Error = core.Error || codec.Error || format.Error || input_module.Error || std.mem.Allocator.Error ||
    error{InvalidErofs};

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
};

pub fn readAllocLimited(
    allocator: std.mem.Allocator,
    image: []const u8,
    metadata: []const u8,
    superblock: format.Superblock,
    view: View,
    max_output_len: usize,
) Error![]u8 {
    if (view.file_size > max_output_len) return error.OutputLimitExceeded;
    const output = try allocator.alloc(u8, view.file_size);
    errdefer allocator.free(output);
    @memset(output, 0);
    if (output.len == 0) return output;

    var cumulative_physical: u64 = 0;
    if (view.record_size == 4) {
        if (metadata.len -| view.record_start < 8) return error.TruncatedFrame;
        cumulative_physical = format.readU64(metadata, view.record_start);
    }
    var previous: ?Record = null;
    for (0..view.record_count) |index| {
        const record = try readRecord(metadata, view, index, &cumulative_physical);
        if (previous) |prior| {
            if (record.logical_start <= prior.logical_start) return error.InvalidErofs;
            try decodeRecord(
                allocator,
                image,
                superblock,
                view.advise,
                prior,
                record.logical_start,
                output,
            );
        }
        previous = record;
    }
    const final = previous orelse return error.InvalidErofs;
    try decodeRecord(
        allocator,
        image,
        superblock,
        view.advise,
        final,
        view.file_size,
        output,
    );
    return output;
}

fn readRecord(
    image: []const u8,
    view: View,
    index: usize,
    cumulative_physical: *u64,
) Error!Record {
    return readRecordInput(.{ .slice = image }, view, index, cumulative_physical);
}

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
    if (encoded & (@as(u32, 1) << 27) != 0) return error.UnsupportedErofsFeature;
    const encoded_len: usize = encoded & 0x001f_ffff;
    if (encoded_len == 0) return error.InvalidErofs;
    const format_code: u4 = @truncate(encoded >> 28);
    if (format_code > 4) return error.UnsupportedErofsCompression;

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
    const physical_start: u64 = if (view.record_size == 4) blk: {
        const result = cumulative_physical.*;
        cumulative_physical.* = std.math.add(u64, result, encoded_len) catch
            return error.IntegerOverflow;
        break :blk result;
    } else @as(u64, format.readU32(bytes, 4)) |
        (if (view.record_size >= 16)
            @as(u64, format.readU32(bytes, 8)) << 32
        else
            0);
    return .{
        .logical_start = logical_start,
        .physical_start = physical_start,
        .encoded_len = encoded_len,
        .format_code = format_code,
    };
}

fn decodeRecord(
    allocator: std.mem.Allocator,
    image: []const u8,
    superblock: format.Superblock,
    advise: u16,
    record: Record,
    logical_end: usize,
    output: []u8,
) Error!void {
    if (logical_end <= record.logical_start or logical_end > output.len)
        return error.InvalidErofs;
    const decoded = output[record.logical_start..logical_end];
    const physical_start = std.math.cast(usize, record.physical_start) orelse
        return error.IntegerOverflow;
    const physical_end = try checkedEnd(physical_start, record.encoded_len, image.len);
    const physical = image[physical_start..physical_end];
    if (record.format_code == 0) {
        if (decoded.len > physical.len) return error.InvalidErofs;
        if (advise & 0x10 != 0 and
            record.physical_start % superblock.block_size == 0 and
            record.encoded_len % superblock.block_size == 0)
        {
            if (decoded.len > superblock.block_size) return error.InvalidErofs;
            const rotation = record.logical_start % superblock.block_size;
            for (decoded, 0..) |*byte, index|
                byte.* = physical[(rotation + index) % superblock.block_size];
        } else {
            @memcpy(decoded, physical[0..decoded.len]);
        }
        return;
    }
    const algorithm = std.enums.fromInt(
        format.Compression,
        @as(u8, record.format_code - 1),
    ) orelse return error.UnsupportedErofsCompression;
    const extent = try codec.decodeExtentAlloc(
        allocator,
        algorithm,
        physical,
        decoded.len,
        superblock.feature_incompat & 1 != 0,
    );
    defer allocator.free(extent);
    @memcpy(decoded, extent);
}

fn checkedEnd(start: usize, length: usize, limit: usize) Error!usize {
    const end = std.math.add(usize, start, length) catch return error.IntegerOverflow;
    if (end > limit) return error.TruncatedFrame;
    return end;
}

test "EROFS 48-bit extent records decode 8 16 and 32 byte layouts" {
    const allocator = std.testing.allocator;
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
        const decoded = try readAllocLimited(
            allocator,
            &image,
            &image,
            superblock,
            .{
                .file_size = 1024,
                .advise = 0,
                .cluster_bits = 9,
                .record_start = 0,
                .record_size = record_size,
                .record_count = 2,
            },
            1024,
        );
        defer allocator.free(decoded);
        for (decoded[0..512]) |byte| try std.testing.expectEqual(@as(u8, 'A'), byte);
        for (decoded[512..]) |byte| try std.testing.expectEqual(@as(u8, 'B'), byte);
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
