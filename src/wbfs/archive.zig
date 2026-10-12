const std = @import("std");
const format = @import("format.zig");

pub const Error = format.Error || std.mem.Allocator.Error;

pub const OpenOptions = struct {
    disc_slot: usize = 0,
    max_hd_sector_size: usize = 64 * 1024,
    max_wbfs_sector_size: usize = 64 * 1024 * 1024,
    max_parts: usize = 10,
};

const Part = struct {
    bytes: []const u8,
    base: u64,
};

pub const Archive = struct {
    allocator: std.mem.Allocator,
    parts: []Part,
    physical_size: u64,
    header: format.Header,
    disc_header: [format.disc_header_size]u8,
    wlba_table: []u16,

    pub fn initAlloc(
        allocator: std.mem.Allocator,
        input: []const u8,
        options: OpenOptions,
    ) Error!Archive {
        return initPartsAlloc(allocator, &.{input}, options);
    }

    pub fn initPartsAlloc(
        allocator: std.mem.Allocator,
        inputs: []const []const u8,
        options: OpenOptions,
    ) Error!Archive {
        if (inputs.len == 0) return error.TruncatedFrame;
        if (inputs.len > options.max_parts) return error.OutputLimitExceeded;
        const parts = try allocator.alloc(Part, inputs.len);
        errdefer allocator.free(parts);
        var physical_size: u64 = 0;
        for (parts, inputs) |*part, bytes| {
            if (bytes.len == 0) return error.InvalidWbfs;
            part.* = .{ .bytes = bytes, .base = physical_size };
            physical_size = std.math.add(u64, physical_size, bytes.len) catch
                return error.IntegerOverflow;
        }
        if (physical_size < format.header_prefix_size)
            return error.TruncatedFrame;

        var prefix: [format.header_prefix_size]u8 = undefined;
        try readPhysical(parts, physical_size, 0, &prefix);
        if (!std.mem.eql(u8, prefix[0..4], format.magic))
            return error.InvalidMagic;
        const hd_sector_shift = prefix[8];
        const wbfs_sector_shift = prefix[9];
        if (hd_sector_shift < 9 or hd_sector_shift >= @bitSizeOf(usize) or
            wbfs_sector_shift < format.wii_sector_shift or
            wbfs_sector_shift >= @bitSizeOf(usize) or
            wbfs_sector_shift < hd_sector_shift)
            return error.InvalidWbfs;
        const hd_sector_size = @as(usize, 1) << @intCast(hd_sector_shift);
        const wbfs_sector_size = @as(usize, 1) << @intCast(wbfs_sector_shift);
        if (hd_sector_size > options.max_hd_sector_size or
            wbfs_sector_size > options.max_wbfs_sector_size)
            return error.OutputLimitExceeded;
        const hd_sector_count = format.readU32Be(&prefix, 4);
        const expected_size = std.math.mul(
            u64,
            hd_sector_count,
            hd_sector_size,
        ) catch return error.IntegerOverflow;
        if (expected_size != physical_size) return error.SizeMismatch;
        if (physical_size % wbfs_sector_size != 0)
            return error.InvalidWbfs;
        const wbfs_sector_count = std.math.cast(
            usize,
            physical_size / wbfs_sector_size,
        ) orelse return error.IntegerOverflow;
        if (wbfs_sector_count == 0 or wbfs_sector_count > std.math.maxInt(u16))
            return error.InvalidWbfs;

        if (options.disc_slot >= hd_sector_size - format.header_prefix_size)
            return error.RangeOutOfBounds;
        var slot_value: [1]u8 = undefined;
        try readPhysical(
            parts,
            physical_size,
            format.header_prefix_size + options.disc_slot,
            &slot_value,
        );
        if (slot_value[0] == 0) return error.InvalidWbfs;

        const blocks_per_disc = try format.blocksPerDisc(wbfs_sector_size);
        const disc_info_size = try format.discInfoSize(
            blocks_per_disc,
            hd_sector_size,
        );
        const slot_offset = std.math.mul(
            usize,
            options.disc_slot,
            disc_info_size,
        ) catch return error.IntegerOverflow;
        const disc_info_offset = std.math.add(
            usize,
            hd_sector_size,
            slot_offset,
        ) catch return error.IntegerOverflow;
        const disc_info_end = std.math.add(
            usize,
            disc_info_offset,
            disc_info_size,
        ) catch return error.IntegerOverflow;
        if (disc_info_end > wbfs_sector_size or
            disc_info_end > physical_size)
            return error.InvalidWbfs;

        var disc_header: [format.disc_header_size]u8 = undefined;
        try readPhysical(
            parts,
            physical_size,
            disc_info_offset,
            &disc_header,
        );
        const table = try allocator.alloc(u16, blocks_per_disc);
        errdefer allocator.free(table);
        const table_bytes = try allocator.alloc(u8, blocks_per_disc * 2);
        defer allocator.free(table_bytes);
        try readPhysical(
            parts,
            physical_size,
            disc_info_offset + format.disc_header_size,
            table_bytes,
        );
        for (table, 0..) |*entry, index| {
            entry.* = format.readU16Be(table_bytes, index * 2);
            if (entry.* >= wbfs_sector_count) return error.InvalidWbfs;
        }
        if (table[0] == 0) return error.InvalidWbfs;
        return .{
            .allocator = allocator,
            .parts = parts,
            .physical_size = physical_size,
            .header = .{
                .hd_sector_count = hd_sector_count,
                .hd_sector_shift = hd_sector_shift,
                .wbfs_sector_shift = wbfs_sector_shift,
                .hd_sector_size = hd_sector_size,
                .wbfs_sector_size = wbfs_sector_size,
                .wbfs_sector_count = wbfs_sector_count,
                .blocks_per_disc = blocks_per_disc,
                .disc_info_size = disc_info_size,
                .disc_slot = options.disc_slot,
            },
            .disc_header = disc_header,
            .wlba_table = table,
        };
    }

    pub fn deinit(self: *Archive) void {
        self.allocator.free(self.wlba_table);
        self.allocator.free(self.parts);
        self.* = undefined;
    }

    pub fn decodeAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        max_output_len: usize,
    ) Error![]u8 {
        const size = std.math.cast(usize, format.logical_size) orelse
            return error.OutputLimitExceeded;
        if (size > max_output_len) return error.OutputLimitExceeded;
        const output = try allocator.alloc(u8, size);
        errdefer allocator.free(output);
        try self.readRangeInto(0, output);
        return output;
    }

    pub fn readRangeAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        offset: u64,
        length: usize,
        max_output_len: usize,
    ) Error![]u8 {
        if (length > max_output_len) return error.OutputLimitExceeded;
        const output = try allocator.alloc(u8, length);
        errdefer allocator.free(output);
        try self.readRangeInto(offset, output);
        return output;
    }

    pub fn readRangeInto(
        self: Archive,
        offset: u64,
        output: []u8,
    ) Error!void {
        const end = std.math.add(u64, offset, output.len) catch
            return error.IntegerOverflow;
        if (end > format.logical_size) return error.RangeOutOfBounds;
        var logical_offset = offset;
        var written: usize = 0;
        while (written < output.len) {
            const logical_cluster = logical_offset / self.header.wbfs_sector_size;
            const cluster_index = std.math.cast(usize, logical_cluster) orelse
                return error.IntegerOverflow;
            if (cluster_index >= self.wlba_table.len)
                return error.RangeOutOfBounds;
            const within_cluster: usize = @intCast(
                logical_offset % self.header.wbfs_sector_size,
            );
            const length = @min(
                output.len - written,
                self.header.wbfs_sector_size - within_cluster,
            );
            const physical_cluster = self.wlba_table[cluster_index];
            if (physical_cluster == 0) {
                @memset(output[written..][0..length], 0);
            } else {
                const physical_offset = std.math.add(
                    u64,
                    std.math.mul(
                        u64,
                        physical_cluster,
                        self.header.wbfs_sector_size,
                    ) catch return error.IntegerOverflow,
                    within_cluster,
                ) catch return error.IntegerOverflow;
                try readPhysical(
                    self.parts,
                    self.physical_size,
                    physical_offset,
                    output[written..][0..length],
                );
            }
            logical_offset += length;
            written += length;
        }
    }
};

fn readPhysical(
    parts: []const Part,
    total_size: u64,
    offset: u64,
    output: []u8,
) Error!void {
    const end = std.math.add(u64, offset, output.len) catch
        return error.IntegerOverflow;
    if (end > total_size) return error.TruncatedFrame;
    var position = offset;
    var written: usize = 0;
    var part_index: usize = 0;
    while (part_index + 1 < parts.len and
        position >= parts[part_index + 1].base)
        part_index += 1;
    while (written < output.len) : (part_index += 1) {
        if (part_index >= parts.len) return error.TruncatedFrame;
        const part = parts[part_index];
        const local_offset = std.math.cast(
            usize,
            position - part.base,
        ) orelse return error.IntegerOverflow;
        const length = @min(output.len - written, part.bytes.len - local_offset);
        if (length == 0) return error.TruncatedFrame;
        @memcpy(output[written..][0..length], part.bytes[local_offset..][0..length]);
        position += length;
        written += length;
    }
}
