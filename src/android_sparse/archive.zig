const std = @import("std");
const checksum = @import("../checksum.zig");
const format = @import("format.zig");

pub const Error = format.Error || std.mem.Allocator.Error;

pub const OpenOptions = struct {
    max_chunks: usize = 1 << 24,
    max_block_size: usize = 64 * 1024 * 1024,
    verify_checksums: bool = true,
    max_checksum_bytes: u64 = 64 * 1024 * 1024 * 1024,
};

const ChecksumPoint = struct {
    logical_offset: u64,
    expected: u32,
};

pub const Archive = struct {
    allocator: std.mem.Allocator,
    bytes: []const u8,
    header: format.Header,
    chunks: []format.Chunk,

    pub fn initAlloc(
        allocator: std.mem.Allocator,
        input: []const u8,
        options: OpenOptions,
    ) Error!Archive {
        if (input.len < format.base_header_size) return error.TruncatedFrame;
        if (format.readU32Le(input, 0) != format.magic)
            return error.InvalidMagic;
        const major = format.readU16Le(input, 4);
        const minor = format.readU16Le(input, 6);
        if (major != format.major_version) return error.UnsupportedVersion;
        const file_header_size: usize = format.readU16Le(input, 8);
        const chunk_header_size: usize = format.readU16Le(input, 10);
        if (file_header_size < format.base_header_size or
            chunk_header_size < format.base_chunk_header_size)
            return error.InvalidAndroidSparse;
        if (file_header_size > input.len) return error.TruncatedFrame;
        const block_size: usize = format.readU32Le(input, 12);
        if (block_size == 0 or block_size % 4 != 0)
            return error.InvalidAndroidSparse;
        if (block_size > options.max_block_size)
            return error.OutputLimitExceeded;
        const total_blocks: usize = format.readU32Le(input, 16);
        const total_chunks: usize = format.readU32Le(input, 20);
        if (total_chunks > options.max_chunks)
            return error.OutputLimitExceeded;
        const logical_size = std.math.mul(
            u64,
            total_blocks,
            block_size,
        ) catch return error.IntegerOverflow;
        const image_checksum = format.readU32Le(input, 24);

        var chunks: std.ArrayList(format.Chunk) = .empty;
        errdefer chunks.deinit(allocator);
        var checksum_points: std.ArrayList(ChecksumPoint) = .empty;
        defer checksum_points.deinit(allocator);
        var input_offset = file_header_size;
        var current_block: usize = 0;
        for (0..total_chunks) |_| {
            if (input.len - input_offset < chunk_header_size)
                return error.TruncatedFrame;
            const header = input[input_offset..][0..chunk_header_size];
            const kind = std.enums.fromInt(
                format.ChunkType,
                format.readU16Le(header, 0),
            ) orelse return error.InvalidAndroidSparse;
            if (format.readU16Le(header, 2) != 0)
                return error.InvalidAndroidSparse;
            const block_count: usize = format.readU32Le(header, 4);
            const total_size: usize = format.readU32Le(header, 8);
            if (total_size < chunk_header_size)
                return error.InvalidAndroidSparse;
            const payload_size = total_size - chunk_header_size;
            const payload_offset = input_offset + chunk_header_size;
            if (payload_size > input.len - payload_offset)
                return error.TruncatedFrame;
            input_offset = std.math.add(usize, input_offset, total_size) catch
                return error.IntegerOverflow;

            if (kind == .crc32) {
                if (block_count != 0 or payload_size != 4)
                    return error.InvalidAndroidSparse;
                try checksum_points.append(allocator, .{
                    .logical_offset = @as(u64, current_block) * block_size,
                    .expected = format.readU32Le(input, payload_offset),
                });
                continue;
            }
            if (block_count == 0 or block_count > total_blocks -| current_block)
                return error.InvalidAndroidSparse;
            const chunk_logical_size = std.math.mul(
                u64,
                block_count,
                block_size,
            ) catch return error.IntegerOverflow;
            switch (kind) {
                .raw => if (payload_size != chunk_logical_size)
                    return error.InvalidAndroidSparse,
                .fill => if (payload_size != 4)
                    return error.InvalidAndroidSparse,
                .dont_care => if (payload_size != 0)
                    return error.InvalidAndroidSparse,
                .crc32 => unreachable,
            }
            try chunks.append(allocator, .{
                .kind = kind,
                .logical_offset = @as(u64, current_block) * block_size,
                .block_count = block_count,
                .logical_size = chunk_logical_size,
                .payload_offset = payload_offset,
                .fill_value = if (kind == .fill)
                    format.readU32Le(input, payload_offset)
                else
                    0,
            });
            current_block += block_count;
        }
        if (current_block != total_blocks)
            return error.SizeMismatch;
        if (input_offset != input.len) return error.TrailingData;
        if (options.verify_checksums and
            (image_checksum != 0 or checksum_points.items.len != 0))
        {
            if (logical_size > options.max_checksum_bytes)
                return error.OutputLimitExceeded;
            try verifyChecksums(
                allocator,
                input,
                chunks.items,
                checksum_points.items,
                image_checksum,
            );
        }
        return .{
            .allocator = allocator,
            .bytes = input,
            .header = .{
                .major = major,
                .minor = minor,
                .file_header_size = file_header_size,
                .chunk_header_size = chunk_header_size,
                .block_size = block_size,
                .total_blocks = total_blocks,
                .total_chunks = total_chunks,
                .image_checksum = image_checksum,
                .logical_size = logical_size,
                .physical_size = input.len,
            },
            .chunks = try chunks.toOwnedSlice(allocator),
        };
    }

    pub fn deinit(self: *Archive) void {
        self.allocator.free(self.chunks);
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
        var chunk_index = self.findChunk(position);
        while (written < output.len) : (chunk_index += 1) {
            if (chunk_index >= self.chunks.len)
                return error.InvalidAndroidSparse;
            const chunk = self.chunks[chunk_index];
            if (position < chunk.logical_offset or
                position >= chunk.logical_offset + chunk.logical_size)
                return error.InvalidAndroidSparse;
            const relative = position - chunk.logical_offset;
            const length: usize = @intCast(@min(
                output.len - written,
                chunk.logical_size - relative,
            ));
            const destination = output[written..][0..length];
            switch (chunk.kind) {
                .raw => {
                    const source = chunk.payload_offset + @as(usize, @intCast(relative));
                    @memcpy(destination, self.bytes[source..][0..length]);
                },
                .fill => fillBytes(destination, chunk.fill_value, relative),
                .dont_care => @memset(destination, 0),
                .crc32 => unreachable,
            }
            position += length;
            written += length;
        }
    }

    fn findChunk(self: Archive, offset: u64) usize {
        var low: usize = 0;
        var high = self.chunks.len;
        while (low < high) {
            const mid = low + (high - low) / 2;
            const chunk = self.chunks[mid];
            if (chunk.logical_offset + chunk.logical_size <= offset)
                low = mid + 1
            else
                high = mid;
        }
        return low;
    }
};

fn fillBytes(output: []u8, value: u32, relative_offset: u64) void {
    var pattern: [4]u8 = undefined;
    std.mem.writeInt(u32, &pattern, value, .little);
    for (output, 0..) |*byte, index|
        byte.* = pattern[@intCast((relative_offset + index) % 4)];
}

fn verifyChecksums(
    allocator: std.mem.Allocator,
    input: []const u8,
    chunks: []const format.Chunk,
    points: []const ChecksumPoint,
    image_checksum: u32,
) Error!void {
    const scratch = try allocator.alloc(u8, 64 * 1024);
    defer allocator.free(scratch);
    var crc = checksum.Crc32.init();
    var point_index: usize = 0;
    var logical_offset: u64 = 0;
    for (chunks) |chunk| {
        while (point_index < points.len and
            points[point_index].logical_offset == logical_offset)
        {
            if (points[point_index].expected != crc.digest())
                return error.ChecksumMismatch;
            point_index += 1;
        }
        switch (chunk.kind) {
            .raw => crc.update(
                input[chunk.payload_offset..][0..@intCast(chunk.logical_size)],
            ),
            .fill => {
                fillBytes(scratch, chunk.fill_value, 0);
                try updateRepeated(&crc, scratch, chunk.logical_size);
            },
            .dont_care => {
                @memset(scratch, 0);
                try updateRepeated(&crc, scratch, chunk.logical_size);
            },
            .crc32 => unreachable,
        }
        logical_offset += chunk.logical_size;
    }
    while (point_index < points.len and
        points[point_index].logical_offset == logical_offset)
    {
        if (points[point_index].expected != crc.digest())
            return error.ChecksumMismatch;
        point_index += 1;
    }
    if (point_index != points.len) return error.InvalidAndroidSparse;
    if (image_checksum != 0 and image_checksum != crc.digest())
        return error.ChecksumMismatch;
}

fn updateRepeated(
    crc: *checksum.Crc32,
    buffer: []const u8,
    length: u64,
) Error!void {
    var remaining = length;
    while (remaining != 0) {
        const count: usize = @intCast(@min(remaining, buffer.len));
        crc.update(buffer[0..count]);
        remaining -= count;
    }
}
