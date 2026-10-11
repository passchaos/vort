const std = @import("std");
const deflate = @import("../deflate.zig");
const format = @import("format.zig");

pub const Error = format.Error || deflate.Error || std.mem.Allocator.Error;

pub const OpenOptions = struct {
    /// Logical bytes of the parent disk, never an implicitly opened path.
    backing_file: ?[]const u8 = null,
    max_descriptor_bytes: usize = 1024 * 1024,
    max_grain_bytes: usize = 2 * 1024 * 1024,
    max_gd_entries: usize = 1 << 22,
    max_compressed_bytes: usize = 4 * 1024 * 1024,
};

const Mapping = union(enum) {
    unallocated,
    zero,
    data: u32,
};

pub const Archive = struct {
    bytes: []const u8,
    initial_header: format.Header,
    header: format.Header,
    descriptor: format.Descriptor,
    backing_file: ?[]const u8,
    grain_count: usize,
    gd_entries: usize,
    gt_sectors: usize,
    gd_sectors: usize,
    max_compressed_bytes: usize,

    pub fn init(input: []const u8, options: OpenOptions) Error!Archive {
        const initial_header = try format.parseHeader(input);
        const header = if (initial_header.gd_offset == format.gd_at_end)
            try format.parseFooter(input, initial_header)
        else
            initial_header;
        if (header.grain_size > options.max_grain_bytes)
            return error.OutputLimitExceeded;
        const input_sectors = input.len / format.sector_size;
        if (header.overhead_sectors > input_sectors)
            return error.TruncatedFrame;

        const descriptor_bytes_u64 = std.math.mul(
            u64,
            header.descriptor_sectors,
            format.sector_size,
        ) catch return error.IntegerOverflow;
        const descriptor_bytes = std.math.cast(usize, descriptor_bytes_u64) orelse
            return error.IntegerOverflow;
        if (descriptor_bytes > options.max_descriptor_bytes)
            return error.OutputLimitExceeded;
        const descriptor_offset = try sectorOffset(header.descriptor_offset);
        const descriptor_end = std.math.add(
            usize,
            descriptor_offset,
            descriptor_bytes,
        ) catch return error.IntegerOverflow;
        if (descriptor_end > input.len) return error.TruncatedFrame;
        const descriptor = if (descriptor_bytes == 0)
            format.Descriptor{}
        else
            try format.parseDescriptor(input[descriptor_offset..descriptor_end]);

        const grain_count_u64 = std.math.divCeil(
            u64,
            header.capacity_sectors,
            header.grain_sectors,
        ) catch return error.IntegerOverflow;
        const grain_count = std.math.cast(usize, grain_count_u64) orelse
            return error.IntegerOverflow;
        const gd_entries = std.math.divCeil(
            usize,
            grain_count,
            header.num_gtes_per_gt,
        ) catch return error.IntegerOverflow;
        if (gd_entries > options.max_gd_entries)
            return error.OutputLimitExceeded;
        if (gd_entries != 0 and (header.gd_offset == 0 or
            header.gd_offset == format.gd_at_end))
            return error.InvalidVmdk;
        const gt_bytes = std.math.mul(
            usize,
            header.num_gtes_per_gt,
            4,
        ) catch return error.IntegerOverflow;
        const gt_sectors = std.math.divCeil(
            usize,
            gt_bytes,
            format.sector_size,
        ) catch return error.IntegerOverflow;
        const gd_bytes = std.math.mul(usize, gd_entries, 4) catch
            return error.IntegerOverflow;
        const gd_sectors = std.math.divCeil(
            usize,
            gd_bytes,
            format.sector_size,
        ) catch return error.IntegerOverflow;
        if (gd_entries != 0) {
            const gd_offset = try sectorOffset(header.gd_offset);
            const gd_padded_bytes = std.math.mul(
                usize,
                gd_sectors,
                format.sector_size,
            ) catch return error.IntegerOverflow;
            const gd_end = std.math.add(usize, gd_offset, gd_padded_bytes) catch
                return error.IntegerOverflow;
            if (gd_end > input.len) return error.TruncatedFrame;
            if (header.hasMarkers() and header.from_footer)
                try validateMetadataMarker(
                    input,
                    header.gd_offset,
                    .grain_directory,
                    gd_sectors,
                );
        }
        return .{
            .bytes = input,
            .initial_header = initial_header,
            .header = header,
            .descriptor = descriptor,
            .backing_file = options.backing_file,
            .grain_count = grain_count,
            .gd_entries = gd_entries,
            .gt_sectors = gt_sectors,
            .gd_sectors = gd_sectors,
            .max_compressed_bytes = options.max_compressed_bytes,
        };
    }

    pub fn decodeAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        max_output_len: usize,
    ) Error![]u8 {
        const size = std.math.cast(usize, self.header.virtual_size) orelse
            return error.IntegerOverflow;
        if (size > max_output_len) return error.OutputLimitExceeded;
        const output = try allocator.alloc(u8, size);
        errdefer allocator.free(output);
        try self.readRangeInto(allocator, 0, output);
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
        try self.readRangeInto(allocator, offset, output);
        return output;
    }

    pub fn readRangeInto(
        self: Archive,
        allocator: std.mem.Allocator,
        offset: usize,
        output: []u8,
    ) Error!void {
        const range_end = std.math.add(usize, offset, output.len) catch
            return error.IntegerOverflow;
        if (range_end > self.header.virtual_size) return error.RangeOutOfBounds;
        var position = offset;
        var written: usize = 0;
        while (written < output.len) {
            const grain_index = position / self.header.grain_size;
            const grain_offset = position % self.header.grain_size;
            const length = @min(
                output.len - written,
                self.header.grain_size - grain_offset,
            );
            const mapping = try self.getMapping(grain_index);
            try self.readMappedRange(
                allocator,
                grain_index,
                grain_offset,
                output[written..][0..length],
                mapping,
            );
            position += length;
            written += length;
        }
    }

    fn getMapping(self: Archive, grain_index: usize) Error!Mapping {
        if (grain_index >= self.grain_count) return error.RangeOutOfBounds;
        const gd_index = grain_index / self.header.num_gtes_per_gt;
        if (gd_index >= self.gd_entries) return error.InvalidVmdk;
        const gd_offset = try sectorOffset(self.header.gd_offset);
        const gde = format.readU32Le(self.bytes, gd_offset + gd_index * 4);
        if (gde == 0) return .unallocated;
        if (self.header.hasZeroGrain() and gde == 1) return .zero;

        if (self.header.hasMarkers() and self.header.from_footer)
            try validateMetadataMarker(
                self.bytes,
                gde,
                .grain_table,
                self.gt_sectors,
            );
        const gt_offset = try sectorOffset(gde);
        const gt_bytes = std.math.mul(
            usize,
            self.gt_sectors,
            format.sector_size,
        ) catch return error.IntegerOverflow;
        const gt_end = std.math.add(usize, gt_offset, gt_bytes) catch
            return error.IntegerOverflow;
        if (gt_end > self.bytes.len) return error.TruncatedFrame;
        const gt_index = grain_index % self.header.num_gtes_per_gt;
        const gte = format.readU32Le(self.bytes, gt_offset + gt_index * 4);
        if (gte == 0) return .unallocated;
        if (self.header.hasZeroGrain() and gte == 1) return .zero;
        if (gte < self.header.overhead_sectors) return error.InvalidVmdk;
        if (!self.header.isCompressed() and gte % self.header.grain_sectors != 0)
            return error.InvalidVmdk;
        return .{ .data = gte };
    }

    fn readMappedRange(
        self: Archive,
        allocator: std.mem.Allocator,
        grain_index: usize,
        grain_offset: usize,
        output: []u8,
        mapping: Mapping,
    ) Error!void {
        switch (mapping) {
            .unallocated => try self.readUnallocated(
                grain_index * self.header.grain_size + grain_offset,
                output,
            ),
            .zero => @memset(output, 0),
            .data => |sector| {
                const data_offset = try sectorOffset(sector);
                if (!self.header.isCompressed()) {
                    const start = std.math.add(
                        usize,
                        data_offset,
                        grain_offset,
                    ) catch return error.IntegerOverflow;
                    const end = std.math.add(usize, start, output.len) catch
                        return error.IntegerOverflow;
                    if (end > self.bytes.len) return error.TruncatedFrame;
                    @memcpy(output, self.bytes[start..end]);
                    return;
                }
                const decoded = try self.decodeCompressedGrain(
                    allocator,
                    grain_index,
                    data_offset,
                );
                defer allocator.free(decoded);
                if (grain_offset + output.len > decoded.len)
                    return error.SizeMismatch;
                @memcpy(output, decoded[grain_offset..][0..output.len]);
            },
        }
    }

    fn readUnallocated(
        self: Archive,
        virtual_offset: usize,
        output: []u8,
    ) Error!void {
        const backing = self.backing_file orelse {
            if (self.descriptor.hasParent())
                return error.MissingVmdkBackingFile;
            @memset(output, 0);
            return;
        };
        if (virtual_offset >= backing.len) {
            @memset(output, 0);
            return;
        }
        const available = @min(output.len, backing.len - virtual_offset);
        @memcpy(output[0..available], backing[virtual_offset..][0..available]);
        @memset(output[available..], 0);
    }

    fn decodeCompressedGrain(
        self: Archive,
        allocator: std.mem.Allocator,
        grain_index: usize,
        data_offset: usize,
    ) Error![]u8 {
        const marker_end = std.math.add(usize, data_offset, 12) catch
            return error.IntegerOverflow;
        if (marker_end > self.bytes.len) return error.TruncatedFrame;
        const expected_lba = std.math.mul(
            u64,
            grain_index,
            self.header.grain_sectors,
        ) catch return error.IntegerOverflow;
        if (format.readU64Le(self.bytes, data_offset) != expected_lba)
            return error.InvalidVmdk;
        const compressed_size: usize = format.readU32Le(
            self.bytes,
            data_offset + 8,
        );
        if (compressed_size == 0) return error.InvalidVmdk;
        if (compressed_size > self.max_compressed_bytes)
            return error.OutputLimitExceeded;
        const compressed_end = std.math.add(
            usize,
            marker_end,
            compressed_size,
        ) catch return error.IntegerOverflow;
        if (compressed_end > self.bytes.len) return error.TruncatedFrame;
        const decoded = try deflate.decodeZlibAllocLimited(
            allocator,
            self.bytes[marker_end..compressed_end],
            self.header.grain_size,
        );
        errdefer allocator.free(decoded);
        const grain_start = std.math.mul(
            usize,
            grain_index,
            self.header.grain_size,
        ) catch return error.IntegerOverflow;
        const virtual_size = std.math.cast(usize, self.header.virtual_size) orelse
            return error.IntegerOverflow;
        const logical_size = @min(
            self.header.grain_size,
            virtual_size - grain_start,
        );
        if (decoded.len != self.header.grain_size and decoded.len != logical_size)
            return error.SizeMismatch;
        return decoded;
    }
};

fn validateMetadataMarker(
    input: []const u8,
    data_sector: u64,
    expected_kind: format.MarkerType,
    expected_sectors: usize,
) Error!void {
    if (data_sector == 0) return error.InvalidVmdk;
    const marker_offset = try sectorOffset(data_sector - 1);
    const marker = try format.parseMarker(input, marker_offset);
    if (marker.kind != expected_kind or marker.size != 0 or
        marker.sectors != expected_sectors)
        return error.InvalidVmdk;
}

fn sectorOffset(sector: anytype) Error!usize {
    const sector_u64 = std.math.cast(u64, sector) orelse
        return error.IntegerOverflow;
    const offset = std.math.mul(
        u64,
        sector_u64,
        format.sector_size,
    ) catch return error.IntegerOverflow;
    return std.math.cast(usize, offset) orelse error.IntegerOverflow;
}
