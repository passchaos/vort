const std = @import("std");
const deflate = @import("../deflate.zig");
const format = @import("format.zig");

pub const Error = format.Error || deflate.Error || std.mem.Allocator.Error;

pub const OpenOptions = struct {
    max_frames: usize = 1 << 20,
    max_nc_areas: usize = 1 << 20,
    max_compressed_frame_bytes: usize = std.math.maxInt(u16),
};

pub const Frame = struct {
    index: usize,
    offset: usize,
    stored_size: usize,
    raw: bool,
};

pub const Archive = struct {
    bytes: []const u8,
    header: format.Header,
    offsets_offset: usize,
    sizes_offset: usize,
    areas_offset: usize,
    data_start: usize,

    pub fn init(input: []const u8, options: OpenOptions) Error!Archive {
        const header = try format.parseHeader(input);
        if (header.frame_count > options.max_frames or
            header.nc_area_count > options.max_nc_areas)
            return error.OutputLimitExceeded;
        const offsets_bytes = std.math.mul(
            usize,
            header.frame_count,
            format.offset_entry_size,
        ) catch return error.IntegerOverflow;
        const sizes_bytes = std.math.mul(
            usize,
            header.frame_count,
            format.size_entry_size,
        ) catch return error.IntegerOverflow;
        const areas_bytes = std.math.mul(
            usize,
            header.nc_area_count,
            format.area_entry_size,
        ) catch return error.IntegerOverflow;
        const sizes_offset = std.math.add(
            usize,
            format.header_size,
            offsets_bytes,
        ) catch return error.IntegerOverflow;
        const areas_offset = std.math.add(
            usize,
            sizes_offset,
            sizes_bytes,
        ) catch return error.IntegerOverflow;
        const data_start = std.math.add(
            usize,
            areas_offset,
            areas_bytes,
        ) catch return error.IntegerOverflow;
        if (data_start > input.len) return error.TruncatedFrame;

        var previous_area_end: usize = 0;
        for (0..header.nc_area_count) |area_index| {
            const area = format.readArea(
                input,
                areas_offset + area_index * format.area_entry_size,
            );
            const area_end = try area.end();
            if (area.count == 0 or area.start < previous_area_end or
                area_end > header.frame_count)
                return error.InvalidDax;
            previous_area_end = area_end;
        }

        const archive: Archive = .{
            .bytes = input,
            .header = header,
            .offsets_offset = format.header_size,
            .sizes_offset = sizes_offset,
            .areas_offset = areas_offset,
            .data_start = data_start,
        };
        for (0..header.frame_count) |frame_index| {
            const frame_info = try archive.frame(frame_index);
            if (frame_info.stored_size == 0) return error.InvalidDax;
            if (frame_info.offset < data_start) return error.InvalidDax;
            const frame_end = std.math.add(
                usize,
                frame_info.offset,
                frame_info.stored_size,
            ) catch return error.IntegerOverflow;
            if (frame_end > input.len) return error.TruncatedFrame;
            if (frame_info.raw) {
                const logical_len = archive.logicalFrameLen(frame_index);
                if (frame_info.stored_size < logical_len or
                    frame_info.stored_size > format.frame_size)
                    return error.InvalidDax;
            } else if (frame_info.stored_size >
                options.max_compressed_frame_bytes)
                return error.OutputLimitExceeded;
        }
        return archive;
    }

    pub fn frame(self: Archive, frame_index: usize) Error!Frame {
        if (frame_index >= self.header.frame_count)
            return error.RangeOutOfBounds;
        return .{
            .index = frame_index,
            .offset = format.readU32Le(
                self.bytes,
                self.offsets_offset + frame_index * format.offset_entry_size,
            ),
            .stored_size = format.readU16Le(
                self.bytes,
                self.sizes_offset + frame_index * format.size_entry_size,
            ),
            .raw = self.isRawFrame(frame_index),
        };
    }

    pub fn nonCompressedArea(
        self: Archive,
        area_index: usize,
    ) Error!format.NonCompressedArea {
        if (area_index >= self.header.nc_area_count)
            return error.RangeOutOfBounds;
        return format.readArea(
            self.bytes,
            self.areas_offset + area_index * format.area_entry_size,
        );
    }

    pub fn decodeAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        max_output_len: usize,
    ) Error![]u8 {
        const size: usize = self.header.uncompressed_size;
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
        const end = std.math.add(usize, offset, output.len) catch
            return error.IntegerOverflow;
        if (end > self.header.uncompressed_size)
            return error.RangeOutOfBounds;
        if (output.len == 0) return;
        const scratch = try allocator.alloc(u8, format.frame_size);
        defer allocator.free(scratch);
        var position = offset;
        var written: usize = 0;
        while (written < output.len) {
            const frame_index = position / format.frame_size;
            const within_frame = position % format.frame_size;
            const logical_len = self.logicalFrameLen(frame_index);
            const copy_len = @min(
                output.len - written,
                logical_len - within_frame,
            );
            const frame_info = try self.frame(frame_index);
            const payload = self.bytes[frame_info.offset..][0..frame_info.stored_size];
            if (frame_info.raw) {
                @memcpy(scratch[0..logical_len], payload[0..logical_len]);
            } else {
                const decoded_len = try deflate.decodeZlib(payload, scratch);
                if (decoded_len != format.frame_size and
                    decoded_len != logical_len)
                    return error.SizeMismatch;
            }
            @memcpy(
                output[written..][0..copy_len],
                scratch[within_frame..][0..copy_len],
            );
            position += copy_len;
            written += copy_len;
        }
    }

    fn isRawFrame(self: Archive, frame_index: usize) bool {
        var low: usize = 0;
        var high = self.header.nc_area_count;
        while (low < high) {
            const mid = low + (high - low) / 2;
            const area = format.readArea(
                self.bytes,
                self.areas_offset + mid * format.area_entry_size,
            );
            if (frame_index < area.start) {
                high = mid;
            } else if (frame_index >= area.start + area.count) {
                low = mid + 1;
            } else {
                return true;
            }
        }
        return false;
    }

    fn logicalFrameLen(self: Archive, frame_index: usize) usize {
        const size: usize = self.header.uncompressed_size;
        const start = frame_index * format.frame_size;
        return @min(format.frame_size, size - start);
    }
};
