const std = @import("std");
const core = @import("../core.zig");
const format = @import("format.zig");

pub const Error = core.Error || format.Error || std.mem.Allocator.Error || error{
    InvalidErofs,
    ErofsMissingDevice,
};

pub const DeviceInfo = struct {
    blocks: u64,
    unified_start: u64,
    tag: [64]u8,
};

pub const InodeView = struct {
    file_size: usize,
    chunk_bits: u8,
    index_start: usize,
    index_size: u8,
};

pub fn validateDevices(
    image: []const u8,
    devices: []const []const u8,
    superblock: format.Superblock,
) Error!void {
    if (devices.len != 0 and devices.len != superblock.extra_devices)
        return error.InvalidErofs;
    var previous_end: u64 = superblock.block_count;
    for (0..superblock.extra_devices) |index| {
        const info = try deviceInfo(image, superblock, index);
        if (info.unified_start < previous_end) return error.InvalidErofs;
        previous_end = std.math.add(u64, info.unified_start, info.blocks) catch
            return error.IntegerOverflow;
        if (devices.len != 0) {
            const required = std.math.mul(
                usize,
                std.math.cast(usize, info.blocks) orelse return error.IntegerOverflow,
                superblock.block_size,
            ) catch return error.IntegerOverflow;
            if (devices[index].len < required) return error.TruncatedFrame;
        }
    }
}

pub fn deviceInfo(
    image: []const u8,
    superblock: format.Superblock,
    index: usize,
) Error!DeviceInfo {
    if (index >= superblock.extra_devices) return error.InvalidErofs;
    const table_start = std.math.mul(
        usize,
        superblock.device_slot_offset,
        128,
    ) catch return error.IntegerOverflow;
    const slot_start = std.math.add(
        usize,
        table_start,
        std.math.mul(usize, index, 128) catch return error.IntegerOverflow,
    ) catch return error.IntegerOverflow;
    const slot_end = try checkedEnd(slot_start, 128, image.len);
    const slot = image[slot_start..slot_end];
    if (format.readU16(slot, 72) != 0 or format.readU16(slot, 74) != 0)
        return error.UnsupportedErofsFeature;
    var tag: [64]u8 = undefined;
    @memcpy(&tag, slot[0..64]);
    return .{
        .blocks = format.readU32(slot, 64),
        .unified_start = format.readU32(slot, 68),
        .tag = tag,
    };
}

pub fn readAllocLimited(
    allocator: std.mem.Allocator,
    image: []const u8,
    devices: []const []const u8,
    superblock: format.Superblock,
    inode: InodeView,
    max_output_len: usize,
) Error![]u8 {
    if (inode.file_size > max_output_len) return error.OutputLimitExceeded;
    const output = try allocator.alloc(u8, inode.file_size);
    errdefer allocator.free(output);
    @memset(output, 0);
    if (output.len == 0) return output;
    const chunk_size: usize = @as(usize, 1) << @intCast(inode.chunk_bits);
    const chunk_count = (std.math.add(usize, output.len, chunk_size - 1) catch
        return error.IntegerOverflow) / chunk_size;
    const device_mask = try deviceIdMask(superblock.extra_devices);
    for (0..chunk_count) |chunk_index| {
        const entry_start = std.math.add(
            usize,
            inode.index_start,
            std.math.mul(usize, chunk_index, inode.index_size) catch
                return error.IntegerOverflow,
        ) catch return error.IntegerOverflow;
        var device_id: u16 = 0;
        var start_block: u64 = undefined;
        if (inode.index_size == 8) {
            if (format.readU16(image, entry_start) != 0)
                return error.UnsupportedErofsFeature;
            device_id = format.readU16(image, entry_start + 2) & device_mask;
            start_block = format.readU32(image, entry_start + 4);
        } else if (inode.index_size == 4) {
            start_block = format.readU32(image, entry_start);
        } else {
            return error.InvalidErofs;
        }
        if (start_block == std.math.maxInt(u32)) continue;
        const logical_start = std.math.mul(usize, chunk_index, chunk_size) catch
            return error.IntegerOverflow;
        const logical_end = @min(output.len, std.math.add(
            usize,
            logical_start,
            chunk_size,
        ) catch return error.IntegerOverflow);
        try readDeviceBlocks(
            image,
            devices,
            superblock,
            device_id,
            start_block,
            output[logical_start..logical_end],
        );
    }
    return output;
}

fn readDeviceBlocks(
    image: []const u8,
    devices: []const []const u8,
    superblock: format.Superblock,
    requested_device_id: u16,
    requested_block: u64,
    output: []u8,
) Error!void {
    var device_id = requested_device_id;
    var block = requested_block;
    var device_blocks = superblock.block_count;
    if (device_id == 0 and superblock.extra_devices != 0) {
        for (0..superblock.extra_devices) |index| {
            const info = try deviceInfo(image, superblock, index);
            const device_end = std.math.add(u64, info.unified_start, info.blocks) catch
                return error.IntegerOverflow;
            if (block >= info.unified_start and block < device_end) {
                block -= info.unified_start;
                device_id = @intCast(index + 1);
                device_blocks = info.blocks;
                break;
            }
        }
    } else if (device_id != 0) {
        if (device_id > superblock.extra_devices) return error.InvalidErofs;
        const info = try deviceInfo(image, superblock, device_id - 1);
        device_blocks = info.blocks;
    }
    const blocks_needed = if (output.len == 0) 0 else (std.math.add(usize, output.len, superblock.block_size - 1) catch
        return error.IntegerOverflow) / superblock.block_size;
    const block_end = std.math.add(
        u64,
        block,
        @intCast(blocks_needed),
    ) catch return error.IntegerOverflow;
    if (block_end > device_blocks) return error.InvalidErofs;
    const source = if (device_id == 0)
        image
    else blk: {
        if (devices.len == 0) return error.ErofsMissingDevice;
        if (device_id > devices.len) return error.InvalidErofs;
        break :blk devices[device_id - 1];
    };
    const source_start = std.math.mul(
        usize,
        std.math.cast(usize, block) orelse return error.IntegerOverflow,
        superblock.block_size,
    ) catch return error.IntegerOverflow;
    const source_end = try checkedEnd(source_start, output.len, source.len);
    @memcpy(output, source[source_start..source_end]);
}

fn deviceIdMask(extra_devices: u16) Error!u16 {
    var power: u32 = 1;
    const count = @as(u32, extra_devices) + 1;
    while (power < count) power = std.math.mul(u32, power, 2) catch
        return error.IntegerOverflow;
    return @intCast(power - 1);
}

fn checkedEnd(start: usize, length: usize, limit: usize) Error!usize {
    const end = std.math.add(usize, start, length) catch return error.IntegerOverflow;
    if (end > limit) return error.TruncatedFrame;
    return end;
}
