const std = @import("std");
const format = @import("format.zig");

pub const Error = format.Error || std.mem.Allocator.Error;

pub const OpenOptions = struct {
    max_sectors: usize = 1 << 24,
    max_sector_size: usize = 64 * 1024 * 1024,
};

pub const Archive = struct {
    allocator: std.mem.Allocator,
    bytes: []const u8,
    header: format.Header,
    index_table: []u32,

    pub fn initAlloc(
        allocator: std.mem.Allocator,
        input: []const u8,
        options: OpenOptions,
    ) Error!Archive {
        if (input.len < format.header_size) return error.TruncatedFrame;
        if (!std.mem.eql(u8, input[0..4], format.magic0) or
            format.readU32Le(input, 4) != format.magic1)
            return error.InvalidMagic;
        const sector_size: usize = format.readU32Le(input, 8);
        if (sector_size < format.min_sector_size or
            sector_size >= format.format_max_sector_size)
            return error.InvalidWux;
        if (sector_size > options.max_sector_size)
            return error.OutputLimitExceeded;
        if (format.readU32Le(input, 12) != 0 or
            format.readU32Le(input, 28) != 0)
            return error.InvalidWux;
        const flags = format.readU32Le(input, 24);
        if (flags != 0) return error.UnsupportedWuxFeature;
        const logical_size = format.readU64Le(input, 16);
        const sector_count = try format.sectorCount(logical_size, sector_size);
        if (sector_count > options.max_sectors or
            sector_count > std.math.maxInt(u32))
            return error.OutputLimitExceeded;
        const data_offset = try format.dataOffset(sector_count, sector_size);
        if (data_offset > input.len) return error.TruncatedFrame;
        const table = try allocator.alloc(u32, sector_count);
        errdefer allocator.free(table);
        var unique_sector_count: usize = 0;
        for (table, 0..) |*entry, index| {
            entry.* = format.readU32Le(
                input,
                format.header_size + index * 4,
            );
            if (entry.* >= sector_count and sector_count != 0)
                return error.InvalidWux;
            const mapped_count = std.math.add(
                usize,
                @as(usize, entry.*),
                1,
            ) catch return error.IntegerOverflow;
            unique_sector_count = @max(
                unique_sector_count,
                mapped_count,
            );
        }
        if (sector_count == 0) unique_sector_count = 0;
        const data_size = std.math.mul(
            usize,
            unique_sector_count,
            sector_size,
        ) catch return error.IntegerOverflow;
        const expected_size = std.math.add(
            usize,
            data_offset,
            data_size,
        ) catch return error.IntegerOverflow;
        if (expected_size != input.len) return error.SizeMismatch;
        if (unique_sector_count != 0) {
            const seen = try allocator.alloc(bool, unique_sector_count);
            defer allocator.free(seen);
            @memset(seen, false);
            for (table) |entry| seen[entry] = true;
            for (seen) |present|
                if (!present) return error.InvalidWux;
        }
        return .{
            .allocator = allocator,
            .bytes = input,
            .header = .{
                .sector_size = sector_size,
                .logical_size = logical_size,
                .flags = flags,
                .sector_count = sector_count,
                .unique_sector_count = unique_sector_count,
                .data_offset = data_offset,
                .physical_size = input.len,
            },
            .index_table = table,
        };
    }

    pub fn deinit(self: *Archive) void {
        self.allocator.free(self.index_table);
        self.* = undefined;
    }

    pub fn decodeAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        max_output_len: usize,
    ) Error![]u8 {
        const size = std.math.cast(usize, self.header.logical_size) orelse
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
        if (end > self.header.logical_size) return error.RangeOutOfBounds;
        var position = offset;
        var written: usize = 0;
        while (written < output.len) {
            const logical_sector_u64 = position / self.header.sector_size;
            const logical_sector = std.math.cast(
                usize,
                logical_sector_u64,
            ) orelse return error.IntegerOverflow;
            if (logical_sector >= self.index_table.len)
                return error.RangeOutOfBounds;
            const sector_offset: usize = @intCast(
                position % self.header.sector_size,
            );
            const length = @min(
                output.len - written,
                self.header.sector_size - sector_offset,
            );
            const physical_sector = self.index_table[logical_sector];
            const source_offset = self.header.data_offset +
                @as(usize, physical_sector) * self.header.sector_size +
                sector_offset;
            @memcpy(
                output[written..][0..length],
                self.bytes[source_offset..][0..length],
            );
            position += length;
            written += length;
        }
    }
};
