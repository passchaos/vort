const std = @import("std");
const format = @import("format.zig");

pub const Error = format.Error || std.mem.Allocator.Error;

pub const OpenOptions = struct {
    max_bat_entries: usize = 1 << 26,
    max_block_size: usize = 256 * format.mib,
};

pub const Archive = struct {
    bytes: []const u8,
    header: format.Header,
    regions: format.Regions,
    metadata: format.Metadata,

    pub fn init(input: []const u8, options: OpenOptions) Error!Archive {
        if (input.len < format.header_section_size or
            !std.mem.eql(u8, input[0..8], "vhdxfile"))
            return error.InvalidMagic;
        const header1 = format.parseHeader(input, format.header1_offset) catch null;
        const header2 = format.parseHeader(input, format.header2_offset) catch null;
        const header = chooseHeader(input, header1, header2) orelse
            return error.InvalidVhdx;
        const regions = format.parseRegions(input, format.region1_offset) catch
            format.parseRegions(input, format.region2_offset) catch
            return error.InvalidVhdx;
        const metadata = try format.parseMetadata(input, regions.metadata);
        if (metadata.bat_entry_count > options.max_bat_entries or
            metadata.block_size > options.max_block_size)
            return error.OutputLimitExceeded;
        const bat_bytes = std.math.mul(
            usize,
            metadata.bat_entry_count,
            8,
        ) catch return error.IntegerOverflow;
        if (bat_bytes > regions.bat.length) return error.InvalidVhdx;
        try validateStructuralRanges(input.len, header, regions);

        for (0..metadata.data_block_count) |block_index| {
            const bat_index = payloadBatIndex(block_index, metadata.chunk_ratio);
            if (bat_index >= metadata.bat_entry_count) return error.InvalidVhdx;
            const entry = format.readU64Le(
                input,
                regions.bat.offset + bat_index * 8,
            );
            const state = std.enums.fromInt(
                format.PayloadState,
                @as(u3, @truncate(entry)),
            ) orelse return error.InvalidVhdx;
            switch (state) {
                .not_present, .undefined, .zero, .unmapped, .unmapped_v095 => {},
                .fully_present => {
                    const file_offset = entry & format.bat_file_offset_mask;
                    if (file_offset == 0 or file_offset % format.mib != 0)
                        return error.InvalidVhdx;
                    const block_start = std.math.mul(
                        u64,
                        block_index,
                        metadata.block_size,
                    ) catch return error.IntegerOverflow;
                    const length = @min(
                        @as(u64, metadata.block_size),
                        metadata.virtual_disk_size - block_start,
                    );
                    const file_end = std.math.add(u64, file_offset, length) catch
                        return error.IntegerOverflow;
                    if (file_end > input.len or
                        overlapsKnownRegion(file_offset, length, header, regions))
                        return error.TruncatedFrame;
                },
                .partially_present => return error.UnsupportedVhdxFeature,
            }
        }
        return .{
            .bytes = input,
            .header = header,
            .regions = regions,
            .metadata = metadata,
        };
    }

    pub fn decodeAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        max_output_len: usize,
    ) Error![]u8 {
        const size = std.math.cast(usize, self.metadata.virtual_disk_size) orelse
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
        if (end > self.metadata.virtual_disk_size) return error.RangeOutOfBounds;
        var position = offset;
        var written: usize = 0;
        while (written < output.len) {
            const block_index = position / self.metadata.block_size;
            const within_block = position % self.metadata.block_size;
            const length = @min(
                output.len - written,
                self.metadata.block_size - within_block,
            );
            const destination = output[written..][0..length];
            const bat_index = payloadBatIndex(block_index, self.metadata.chunk_ratio);
            const entry = format.readU64Le(
                self.bytes,
                self.regions.bat.offset + bat_index * 8,
            );
            const state: format.PayloadState = @enumFromInt(@as(u3, @truncate(entry)));
            switch (state) {
                .not_present, .undefined, .zero, .unmapped, .unmapped_v095 => @memset(destination, 0),
                .fully_present => {
                    const file_offset: usize = @intCast(entry & format.bat_file_offset_mask);
                    @memcpy(destination, self.bytes[file_offset + within_block ..][0..length]);
                },
                .partially_present => return error.UnsupportedVhdxFeature,
            }
            position += length;
            written += length;
        }
    }
};

pub fn payloadBatIndex(block_index: usize, chunk_ratio: usize) usize {
    return block_index + block_index / chunk_ratio;
}

fn chooseHeader(
    input: []const u8,
    first: ?format.Header,
    second: ?format.Header,
) ?format.Header {
    if (first == null) return second;
    if (second == null) return first;
    if (first.?.sequence_number > second.?.sequence_number) return first;
    if (second.?.sequence_number > first.?.sequence_number) return second;
    const a = input[format.header1_offset..][0..80];
    const b = input[format.header2_offset..][0..80];
    return if (std.mem.eql(u8, a, b)) first else null;
}

fn validateStructuralRanges(
    file_size: usize,
    header: format.Header,
    regions: format.Regions,
) Error!void {
    const bat_end = std.math.add(usize, regions.bat.offset, regions.bat.length) catch
        return error.IntegerOverflow;
    const metadata_end = std.math.add(
        usize,
        regions.metadata.offset,
        regions.metadata.length,
    ) catch return error.IntegerOverflow;
    if (bat_end > file_size or metadata_end > file_size or
        rangesOverlap(regions.bat.offset, bat_end, regions.metadata.offset, metadata_end))
        return error.InvalidVhdx;
    if (header.log_length != 0) {
        const log_offset = std.math.cast(usize, header.log_offset) orelse
            return error.IntegerOverflow;
        const log_end = std.math.add(usize, log_offset, header.log_length) catch
            return error.IntegerOverflow;
        if (log_end > file_size or
            rangesOverlap(log_offset, log_end, regions.bat.offset, bat_end) or
            rangesOverlap(log_offset, log_end, regions.metadata.offset, metadata_end))
            return error.InvalidVhdx;
    }
}

fn overlapsKnownRegion(
    offset: u64,
    length: u64,
    header: format.Header,
    regions: format.Regions,
) bool {
    const end = offset + length;
    if (offset < format.header_section_size) return true;
    if (rangesOverlapU64(offset, end, regions.bat.offset, regions.bat.offset + regions.bat.length) or
        rangesOverlapU64(offset, end, regions.metadata.offset, regions.metadata.offset + regions.metadata.length))
        return true;
    if (header.log_length != 0 and
        rangesOverlapU64(offset, end, header.log_offset, header.log_offset + header.log_length))
        return true;
    return false;
}

fn rangesOverlap(first_start: usize, first_end: usize, second_start: usize, second_end: usize) bool {
    return first_start < second_end and second_start < first_end;
}

fn rangesOverlapU64(first_start: u64, first_end: u64, second_start: u64, second_end: u64) bool {
    return first_start < second_end and second_start < first_end;
}
