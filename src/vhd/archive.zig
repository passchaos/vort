const std = @import("std");
const format = @import("format.zig");

pub const Error = format.Error || std.mem.Allocator.Error;

pub const OpenOptions = struct {
    /// Parent ownership remains with the caller and must outlive this archive.
    parent: ?*const Archive = null,
    max_table_entries: usize = 1 << 24,
    max_block_size: usize = 256 * 1024 * 1024,
};

pub const Archive = struct {
    bytes: []const u8,
    footer: format.Footer,
    dynamic_header: ?format.DynamicHeader,
    parent: ?*const Archive,
    bat_offset: usize,

    pub fn init(input: []const u8, options: OpenOptions) Error!Archive {
        const footer = try format.parseFooter(input);
        if (footer.current_size > std.math.maxInt(usize))
            return error.OutputLimitExceeded;
        if (footer.disk_type == .fixed) {
            const required = std.math.add(
                u64,
                footer.current_size,
                format.footer_size,
            ) catch return error.IntegerOverflow;
            if (required > input.len) return error.TruncatedFrame;
            return .{
                .bytes = input,
                .footer = footer,
                .dynamic_header = null,
                .parent = null,
                .bat_offset = 0,
            };
        }

        const header = try format.parseDynamicHeader(input, footer);
        if (header.max_table_entries > options.max_table_entries or
            header.block_size > options.max_block_size)
            return error.OutputLimitExceeded;
        const bat_offset = std.math.cast(usize, header.table_offset) orelse
            return error.IntegerOverflow;
        if (bat_offset % format.sector_size != 0 or
            bat_offset < format.footer_size + format.dynamic_header_size)
            return error.InvalidVhd;
        const bat_bytes = std.math.mul(
            usize,
            header.max_table_entries,
            4,
        ) catch return error.IntegerOverflow;
        const bat_end = std.math.add(usize, bat_offset, bat_bytes) catch
            return error.IntegerOverflow;
        if (bat_end > input.len - format.footer_size)
            return error.TruncatedFrame;
        const first_data_offset = std.mem.alignForward(
            usize,
            bat_end,
            format.sector_size,
        );
        for (0..header.max_table_entries) |index| {
            const entry = format.readU32Be(input, bat_offset + index * 4);
            if (entry == format.unallocated_bat_entry) continue;
            const block_offset_u64 = std.math.mul(
                u64,
                entry,
                format.sector_size,
            ) catch return error.IntegerOverflow;
            const block_offset = std.math.cast(usize, block_offset_u64) orelse
                return error.IntegerOverflow;
            const block_end = std.math.add(
                usize,
                block_offset,
                header.bitmapSize() + header.block_size,
            ) catch return error.IntegerOverflow;
            if (block_offset < first_data_offset or
                block_end > input.len - format.footer_size)
                return error.TruncatedFrame;
        }

        var parent: ?*const Archive = null;
        if (footer.disk_type == .differencing) {
            parent = options.parent orelse return error.MissingVhdParent;
            if (!std.mem.eql(
                u8,
                &header.parent_unique_id,
                &parent.?.footer.unique_id,
            ) or parent.?.footer.current_size != footer.current_size)
                return error.MissingVhdParent;
        }
        return .{
            .bytes = input,
            .footer = footer,
            .dynamic_header = header,
            .parent = parent,
            .bat_offset = bat_offset,
        };
    }

    pub fn decodeAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        max_output_len: usize,
    ) Error![]u8 {
        const size = std.math.cast(usize, self.footer.current_size) orelse
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
        offset: usize,
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
        offset: usize,
        output: []u8,
    ) Error!void {
        const end = std.math.add(usize, offset, output.len) catch
            return error.IntegerOverflow;
        if (end > self.footer.current_size) return error.RangeOutOfBounds;
        if (self.footer.disk_type == .fixed) {
            @memcpy(output, self.bytes[offset..end]);
            return;
        }
        const header = self.dynamic_header orelse return error.InvalidVhd;
        var position = offset;
        var written: usize = 0;
        while (written < output.len) {
            const block_index = position / header.block_size;
            if (block_index >= header.max_table_entries)
                return error.InvalidVhd;
            const within_block = position % header.block_size;
            const sector_in_block = within_block / format.sector_size;
            const within_sector = within_block % format.sector_size;
            const length = @min(
                output.len - written,
                format.sector_size - within_sector,
            );
            const destination = output[written..][0..length];
            const bat_entry = format.readU32Be(
                self.bytes,
                self.bat_offset + block_index * 4,
            );
            if (bat_entry == format.unallocated_bat_entry) {
                try self.readParentOrZero(position, destination);
            } else {
                const block_offset_u64 = std.math.mul(
                    u64,
                    bat_entry,
                    format.sector_size,
                ) catch return error.IntegerOverflow;
                const block_offset = std.math.cast(usize, block_offset_u64) orelse
                    return error.IntegerOverflow;
                if (!bitmapBit(
                    self.bytes[block_offset..][0..header.bitmapSize()],
                    sector_in_block,
                )) {
                    try self.readParentOrZero(position, destination);
                } else {
                    const data_start = std.math.add(
                        usize,
                        block_offset + header.bitmapSize(),
                        within_block,
                    ) catch return error.IntegerOverflow;
                    @memcpy(destination, self.bytes[data_start..][0..length]);
                }
            }
            position += length;
            written += length;
        }
    }

    fn readParentOrZero(
        self: Archive,
        position: usize,
        output: []u8,
    ) Error!void {
        if (self.parent) |parent|
            try parent.readRangeInto(position, output)
        else
            @memset(output, 0);
    }
};

pub fn bitmapBit(bitmap: []const u8, sector_index: usize) bool {
    if (sector_index / 8 >= bitmap.len) return false;
    const mask = @as(u8, 1) << @intCast(7 - sector_index % 8);
    return bitmap[sector_index / 8] & mask != 0;
}

test "VHD bitmap uses most-significant bit first" {
    const bitmap = [_]u8{0b1000_0001};
    try std.testing.expect(bitmapBit(&bitmap, 0));
    try std.testing.expect(!bitmapBit(&bitmap, 1));
    try std.testing.expect(bitmapBit(&bitmap, 7));
}
