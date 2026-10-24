const std = @import("std");
const core = @import("../core.zig");
const format = @import("format.zig");
const device_reader = @import("reader/devices.zig");

pub const Error = device_reader.Error || core.Error || format.Error || std.mem.Allocator.Error || error{
    InvalidErofs,
    ErofsMissingDevice,
};

pub const DeviceInfo = device_reader.DeviceInfo;

pub const InodeView = struct {
    file_size: usize,
    chunk_format: u16,
    chunk_bits: u8,
    index_start: usize,
    index_size: u8,
};

pub fn validateDevices(image: []const u8, devices: []const []const u8, superblock: format.Superblock) Error!void {
    return (device_reader.Devices([]const u8){ .primary = .{ .slice = image }, .devices = devices, .superblock = superblock }).validate();
}

pub fn deviceInfo(image: []const u8, superblock: format.Superblock, index: usize) Error!DeviceInfo {
    return (device_reader.Devices([]const u8){ .primary = .{ .slice = image }, .devices = &.{}, .superblock = superblock }).info(index);
}

pub fn readAllocLimited(
    allocator: std.mem.Allocator,
    image: []const u8,
    metadata: []const u8,
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
            const start_hi = format.readU16(metadata, entry_start);
            const index_48bit = inode.chunk_format & 0x0040 != 0;
            if (index_48bit and
                superblock.feature_incompat & format.feature_incompat_48bit == 0)
                return error.InvalidErofs;
            if (!index_48bit and start_hi != 0) return error.InvalidErofs;
            device_id = format.readU16(metadata, entry_start + 2) & device_mask;
            start_block = @as(u64, format.readU32(metadata, entry_start + 4)) |
                (if (index_48bit) @as(u64, start_hi) << 32 else 0);
        } else if (inode.index_size == 4) {
            start_block = format.readU32(metadata, entry_start);
        } else {
            return error.InvalidErofs;
        }
        const address_mask: u64 = if (inode.chunk_format & 0x0040 != 0)
            (@as(u64, 1) << 48) - 1
        else
            std.math.maxInt(u32);
        if (start_block == address_mask) continue;
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
    return (device_reader.Devices([]const u8){ .primary = .{ .slice = image }, .devices = devices, .superblock = superblock }).read(requested_device_id, requested_block, output);
}

fn deviceIdMask(extra_devices: u16) Error!u16 {
    return device_reader.idMask(extra_devices);
}
