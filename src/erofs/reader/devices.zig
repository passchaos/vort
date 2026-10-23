const std = @import("std");
const input_module = @import("input.zig");
const source_module = @import("../../io/source.zig");
const format = @import("../format.zig");
const types = @import("types.zig");

pub const Error = types.Error || input_module.Error || error{ErofsMissingDevice};
pub const DeviceInfo = types.DeviceInfo;
pub const Region = struct { input: input_module.Input, start: u64 };

pub const Access = union(enum) {
    sources: Devices(source_module.Source),
    slices: Devices([]const u8),

    pub fn resolve(self: Access, id: u16, block: u64, size: usize) Error!Region {
        return switch (self) {
            .sources => |devices| devices.resolve(id, block, size),
            .slices => |devices| devices.resolve(id, block, size),
        };
    }

    pub fn resolveAt(self: Access, id: u16, start: u64, size: usize) Error!Region {
        return switch (self) {
            .sources => |devices| devices.resolveAt(id, start, size),
            .slices => |devices| devices.resolveAt(id, start, size),
        };
    }
};

/// Device tables and unified/explicit addresses share identical rules for
/// borrowed slices and Sources. Device payloads are never retained here.
pub fn Devices(comptime Device: type) type {
    if (Device != []const u8 and Device != source_module.Source) @compileError("unsupported EROFS device input");
    return struct {
        const Self = @This();
        primary: input_module.Input,
        devices: []const Device,
        superblock: format.Superblock,

        fn input(device: Device) input_module.Input {
            return if (Device == source_module.Source) .{ .source = device } else .{ .slice = device };
        }

        pub fn info(self: Self, index: usize) Error!DeviceInfo {
            if (index >= self.superblock.extra_devices) return error.InvalidErofs;
            const table = std.math.mul(usize, self.superblock.device_slot_offset, 128) catch return error.IntegerOverflow;
            const relative = std.math.mul(usize, index, 128) catch return error.IntegerOverflow;
            const start = std.math.add(usize, table, relative) catch return error.IntegerOverflow;
            var slot: [128]u8 = undefined;
            try self.primary.read(start, &slot);
            const blocks_hi = format.readU16(&slot, 72);
            const unified_hi = format.readU16(&slot, 74);
            const wide = self.superblock.feature_incompat & format.feature_incompat_48bit != 0;
            if (!wide and (blocks_hi != 0 or unified_hi != 0)) return error.InvalidErofs;
            var tag: [64]u8 = undefined;
            @memcpy(&tag, slot[0..64]);
            return .{
                .blocks = @as(u64, format.readU32(&slot, 64)) | (if (wide) @as(u64, blocks_hi) << 32 else 0),
                .unified_start = @as(u64, format.readU32(&slot, 68)) | (if (wide) @as(u64, unified_hi) << 32 else 0),
                .tag = tag,
            };
        }

        pub fn validate(self: Self) Error!void {
            if (self.devices.len != 0 and self.devices.len != self.superblock.extra_devices) return error.InvalidErofs;
            var previous_end = self.superblock.block_count;
            for (0..self.superblock.extra_devices) |index| {
                const device = try self.info(index);
                if (device.unified_start != 0) {
                    if (device.unified_start < previous_end) return error.InvalidErofs;
                    previous_end = std.math.add(u64, device.unified_start, device.blocks) catch return error.IntegerOverflow;
                    _ = std.math.mul(u64, previous_end, self.superblock.block_size) catch return error.IntegerOverflow;
                }
                if (self.devices.len != 0) {
                    const required = std.math.mul(u64, device.blocks, self.superblock.block_size) catch return error.IntegerOverflow;
                    if (Device == []const u8) _ = std.math.cast(usize, required) orelse return error.IntegerOverflow;
                    if (input(self.devices[index]).len() < required) return error.TruncatedFrame;
                }
            }
        }

        pub fn resolve(self: Self, requested_id: u16, requested_block: u64, size: usize) Error!Region {
            var id = requested_id;
            var block = requested_block;
            var blocks = self.superblock.block_count;
            if (id == 0 and self.superblock.extra_devices != 0) {
                for (0..self.superblock.extra_devices) |index| {
                    const device = try self.info(index);
                    if (device.unified_start == 0) continue;
                    const end = std.math.add(u64, device.unified_start, device.blocks) catch return error.IntegerOverflow;
                    if (block >= device.unified_start and block < end) {
                        block -= device.unified_start;
                        id = @intCast(index + 1);
                        blocks = device.blocks;
                        break;
                    }
                }
            } else if (id != 0) {
                if (id > self.superblock.extra_devices) return error.InvalidErofs;
                blocks = (try self.info(id - 1)).blocks;
            }
            const needed = if (size == 0) 0 else (std.math.add(usize, size, self.superblock.block_size - 1) catch return error.IntegerOverflow) / self.superblock.block_size;
            const block_end = std.math.add(u64, block, needed) catch return error.IntegerOverflow;
            if (block_end > blocks) return error.InvalidErofs;
            const selected = if (id == 0) self.primary else blk: {
                if (self.devices.len == 0) return error.ErofsMissingDevice;
                if (id > self.devices.len) return error.InvalidErofs;
                break :blk input(self.devices[id - 1]);
            };
            if (Device == []const u8) _ = std.math.cast(usize, block) orelse return error.IntegerOverflow;
            const start = std.math.mul(u64, block, self.superblock.block_size) catch return error.IntegerOverflow;
            if (Device == []const u8) _ = std.math.cast(usize, start) orelse return error.IntegerOverflow;
            _ = try selected.endAt(start, size);
            return .{ .input = selected, .start = start };
        }

        /// Resolve a physical byte range, including unaligned compressed
        /// extents. The skipped bytes in its first block count toward bounds.
        pub fn resolveAt(self: Self, id: u16, start: u64, size: usize) Error!Region {
            if (id == 0 and self.superblock.extra_devices == 0) {
                const end = std.math.add(u64, start, size) catch return error.IntegerOverflow;
                if (end > try self.superblock.imageSize64()) return error.TruncatedFrame;
                _ = try self.primary.endAt(start, size);
                return .{ .input = self.primary, .start = start };
            }
            const block_size = self.superblock.block_size;
            if (block_size == 0) return error.InvalidErofs;
            _ = std.math.add(u64, start, size) catch return error.IntegerOverflow;
            const within: usize = @intCast(start % block_size);
            const covered = std.math.add(usize, within, size) catch return error.IntegerOverflow;
            var region = try self.resolve(id, start / block_size, covered);
            region.start = std.math.add(u64, region.start, within) catch return error.IntegerOverflow;
            return region;
        }

        pub fn read(self: Self, id: u16, block: u64, output: []u8) Error!void {
            const region = try self.resolve(id, block, output.len);
            try region.input.readAt(region.start, output);
        }
    };
}

pub fn idMask(extra_devices: u16) Error!u16 {
    var power: u32 = 1;
    const count = @as(u32, extra_devices) + 1;
    while (power < count) power = std.math.mul(u32, power, 2) catch return error.IntegerOverflow;
    return @intCast(power - 1);
}
