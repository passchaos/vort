const std = @import("std");
const format = @import("format.zig");

pub const Error = format.Error || std.mem.Allocator.Error;

pub const OpenOptions = struct {
    max_chunks: usize = 1 << 24,
    max_parts: usize = 100,
    max_alignment: u32 = format.max_alignment,
};

const Part = struct {
    bytes: []const u8,
    base: u64,
};

const Extent = struct {
    start: u64,
    end: u64,
};

pub const Archive = struct {
    allocator: std.mem.Allocator,
    parts: []Part,
    header: format.Header,
    chunks: []format.Chunk,

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
            if (bytes.len == 0) return error.InvalidWdf;
            part.* = .{ .bytes = bytes, .base = physical_size };
            physical_size = std.math.add(u64, physical_size, bytes.len) catch
                return error.IntegerOverflow;
        }
        if (physical_size < format.header_size) return error.TruncatedFrame;
        var header_bytes: [format.header_size]u8 = undefined;
        try readPhysical(parts, physical_size, 0, &header_bytes);
        if (!std.mem.eql(u8, header_bytes[0..format.magic_size], format.magic))
            return error.InvalidMagic;
        const version = std.enums.fromInt(
            format.Version,
            format.readU32Be(&header_bytes, 8),
        ) orelse return error.UnsupportedVersion;
        var head_size = format.readU32Be(&header_bytes, 12);
        var alignment = format.readU32Be(&header_bytes, 16);
        const compatible_version = format.readU32Be(&header_bytes, 20);
        if (version == .v1 and head_size != format.header_size) {
            head_size = format.header_size;
            alignment = 0;
        }
        if (head_size != format.header_size or compatible_version == 0 or
            compatible_version > @intFromEnum(version))
            return error.InvalidWdf;
        if (alignment > options.max_alignment)
            return error.OutputLimitExceeded;
        if (alignment != 0 and !std.math.isPowerOfTwo(alignment))
            return error.InvalidWdf;
        if (format.readU32Be(&header_bytes, 40) != 0)
            return error.InvalidWdf;
        const chunk_count: usize = format.readU32Be(&header_bytes, 44);
        if (chunk_count > options.max_chunks)
            return error.OutputLimitExceeded;
        const chunk_offset = format.readU64Be(&header_bytes, 48);
        const chunk_bytes = std.math.mul(
            usize,
            chunk_count,
            version.chunkSize(),
        ) catch return error.IntegerOverflow;
        const table_size = std.math.add(
            usize,
            format.magic_size,
            chunk_bytes,
        ) catch return error.IntegerOverflow;
        try validateExtent(physical_size, chunk_offset, table_size);
        const table_end = std.math.add(u64, chunk_offset, table_size) catch
            return error.IntegerOverflow;
        if (table_end != physical_size) return error.TrailingData;
        var table_magic: [format.magic_size]u8 = undefined;
        try readPhysical(parts, physical_size, chunk_offset, &table_magic);
        if (!std.mem.eql(u8, &table_magic, format.magic))
            return error.InvalidWdf;
        const raw_table = try allocator.alloc(u8, chunk_bytes);
        defer allocator.free(raw_table);
        try readPhysical(
            parts,
            physical_size,
            chunk_offset + format.magic_size,
            raw_table,
        );
        const chunks = try allocator.alloc(format.Chunk, chunk_count);
        errdefer allocator.free(chunks);
        var extents: std.ArrayList(Extent) = .empty;
        defer extents.deinit(allocator);
        var previous_logical_end: u64 = 0;
        var stored_size: u64 = 0;
        const logical_size = format.readU64Be(&header_bytes, 24);
        const logical_limit = try alignedLimit(logical_size, alignment);
        for (chunks, 0..) |*chunk, index| {
            const offset = index * version.chunkSize();
            const field_offset: usize = if (version == .v1) 4 else 0;
            chunk.* = .{
                .file_pos = format.readU64Be(raw_table, offset + field_offset),
                .data_offset = format.readU64Be(raw_table, offset + field_offset + 8),
                .data_size = format.readU64Be(raw_table, offset + field_offset + 16),
            };
            const logical_end = try chunk.logicalEnd();
            const physical_end = try chunk.physicalEnd();
            if (index != 0 and chunk.file_pos < previous_logical_end)
                return error.InvalidWdf;
            if (logical_end > logical_limit or
                chunk.data_offset < head_size or physical_end > physical_size)
                return error.InvalidWdf;
            if (rangesOverlap(
                chunk.data_offset,
                physical_end,
                chunk_offset,
                table_end,
            )) return error.InvalidWdf;
            if (chunk.data_size != 0)
                try extents.append(allocator, .{
                    .start = chunk.data_offset,
                    .end = physical_end,
                });
            stored_size = std.math.add(u64, stored_size, chunk.data_size) catch
                return error.IntegerOverflow;
            previous_logical_end = logical_end;
        }
        if (stored_size != format.readU64Be(&header_bytes, 32))
            return error.SizeMismatch;
        std.mem.sort(Extent, extents.items, {}, extentLessThan);
        var previous_physical_end: u64 = head_size;
        for (extents.items) |extent| {
            if (extent.start < previous_physical_end) return error.InvalidWdf;
            previous_physical_end = extent.end;
        }
        return .{
            .allocator = allocator,
            .parts = parts,
            .header = .{
                .version = version,
                .head_size = head_size,
                .align_factor = alignment,
                .compatible_version = compatible_version,
                .logical_size = logical_size,
                .data_size = stored_size,
                .chunk_count = chunk_count,
                .chunk_offset = chunk_offset,
                .physical_size = physical_size,
            },
            .chunks = chunks,
        };
    }

    pub fn deinit(self: *Archive) void {
        self.allocator.free(self.chunks);
        self.allocator.free(self.parts);
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
            const index = self.findChunk(position);
            if (index >= self.chunks.len) {
                @memset(output[written..], 0);
                break;
            }
            const chunk = self.chunks[index];
            if (position < chunk.file_pos) {
                const length: usize = @intCast(@min(
                    output.len - written,
                    chunk.file_pos - position,
                ));
                @memset(output[written..][0..length], 0);
                position += length;
                written += length;
                continue;
            }
            const relative = position - chunk.file_pos;
            const length: usize = @intCast(@min(
                output.len - written,
                chunk.data_size - relative,
            ));
            try readPhysical(
                self.parts,
                self.header.physical_size,
                chunk.data_offset + relative,
                output[written..][0..length],
            );
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
            if (chunk.file_pos + chunk.data_size <= offset)
                low = mid + 1
            else
                high = mid;
        }
        return low;
    }
};

fn alignedLimit(size: u64, alignment: u32) Error!u64 {
    if (alignment <= 1) return size;
    const added = std.math.add(u64, size, alignment - 1) catch
        return error.IntegerOverflow;
    return added & ~(@as(u64, alignment) - 1);
}

fn validateExtent(total: u64, offset: u64, size: usize) Error!void {
    const end = std.math.add(u64, offset, size) catch
        return error.IntegerOverflow;
    if (end > total) return error.TruncatedFrame;
}

fn rangesOverlap(a_start: u64, a_end: u64, b_start: u64, b_end: u64) bool {
    return a_start < b_end and b_start < a_end;
}

fn extentLessThan(_: void, lhs: Extent, rhs: Extent) bool {
    return lhs.start < rhs.start;
}

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
    while (part_index + 1 < parts.len and position >= parts[part_index + 1].base)
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
