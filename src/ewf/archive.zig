const std = @import("std");
const checksum = @import("../checksum.zig");
const deflate = @import("../deflate.zig");
const format = @import("format.zig");

pub const Error = format.Error || deflate.Error || std.mem.Allocator.Error;

pub const OpenOptions = struct {
    verify_checksums: bool = true,
    max_sections_per_segment: usize = 1 << 16,
    max_chunks: usize = 1 << 24,
    max_chunk_bytes: usize = 16 * 1024 * 1024,
};

pub const Chunk = struct {
    encoded: []const u8,
    decoded_size: usize,
    compressed: bool,
    segment_number: u16,
};

pub const Archive = struct {
    allocator: std.mem.Allocator,
    geometry: format.Geometry,
    chunks: []Chunk,
    segment_count: usize,
    expected_md5: ?[16]u8,
    verify_checksums: bool,

    pub fn initAlloc(
        allocator: std.mem.Allocator,
        segments: []const []const u8,
        options: OpenOptions,
    ) Error!Archive {
        if (segments.len == 0 or segments.len > std.math.maxInt(u16))
            return error.InvalidEwf;
        var chunks: std.ArrayList(Chunk) = .empty;
        errdefer chunks.deinit(allocator);
        var geometry: ?format.Geometry = null;
        var expected_md5: ?[16]u8 = null;

        for (segments, 0..) |segment, segment_index| {
            const file_header = try format.parseFileHeader(segment);
            if (file_header.segment_number != segment_index + 1)
                return error.InvalidEwf;
            var offset: usize = format.file_header_size;
            var section_count: usize = 0;
            var last_sectors: ?format.Section = null;
            var terminal_kind: ?[]const u8 = null;
            while (offset < segment.len) {
                section_count += 1;
                if (section_count > options.max_sections_per_segment)
                    return error.OutputLimitExceeded;
                const section = try format.parseSection(
                    segment,
                    offset,
                    options.verify_checksums,
                );
                if (std.mem.eql(u8, section.kind, "volume") or
                    std.mem.eql(u8, section.kind, "disk"))
                {
                    const parsed = try format.parseGeometry(
                        section.data,
                        options.verify_checksums,
                    );
                    if (geometry) |existing| {
                        try expectSameGeometry(existing, parsed);
                    } else {
                        if (parsed.chunk_count > options.max_chunks or
                            parsed.chunk_size > options.max_chunk_bytes)
                            return error.OutputLimitExceeded;
                        geometry = parsed;
                    }
                } else if (std.mem.eql(u8, section.kind, "data")) {
                    if (section.data.len >= 94) {
                        const parsed = try format.parseGeometry(
                            section.data,
                            options.verify_checksums,
                        );
                        if (geometry) |existing|
                            try expectSameGeometry(existing, parsed)
                        else
                            geometry = parsed;
                    }
                } else if (std.mem.eql(u8, section.kind, "sectors")) {
                    last_sectors = section;
                } else if (std.mem.eql(u8, section.kind, "table")) {
                    const media_geometry = geometry orelse
                        return error.InvalidEwf;
                    try appendTableChunks(
                        allocator,
                        &chunks,
                        segment,
                        file_header.segment_number,
                        section,
                        last_sectors,
                        media_geometry,
                        options,
                    );
                } else if (std.mem.eql(u8, section.kind, "hash")) {
                    if (section.data.len < 36) return error.TruncatedFrame;
                    if (options.verify_checksums and
                        format.readU32Le(section.data, 32) !=
                            checksum.adler32(section.data[0..32]))
                        return error.ChecksumMismatch;
                    var digest: [16]u8 = undefined;
                    @memcpy(&digest, section.data[0..16]);
                    if (expected_md5) |existing| {
                        if (!std.mem.eql(u8, &existing, &digest))
                            return error.InvalidEwf;
                    } else {
                        expected_md5 = digest;
                    }
                }

                if (section.isTerminal()) {
                    terminal_kind = section.kind;
                    break;
                }
                offset = section.next_offset;
            }
            const terminal = terminal_kind orelse return error.IncompleteEwf;
            const is_last = segment_index + 1 == segments.len;
            if (std.mem.eql(u8, terminal, "incomplete"))
                return error.IncompleteEwf;
            if (is_last != std.mem.eql(u8, terminal, "done"))
                return error.InvalidEwf;
            if (!is_last and !std.mem.eql(u8, terminal, "next"))
                return error.InvalidEwf;
        }
        const final_geometry = geometry orelse return error.InvalidEwf;
        if (chunks.items.len != final_geometry.chunk_count)
            return error.SizeMismatch;
        return .{
            .allocator = allocator,
            .geometry = final_geometry,
            .chunks = try chunks.toOwnedSlice(allocator),
            .segment_count = segments.len,
            .expected_md5 = expected_md5,
            .verify_checksums = options.verify_checksums,
        };
    }

    pub fn initOneAlloc(
        allocator: std.mem.Allocator,
        input: []const u8,
        options: OpenOptions,
    ) Error!Archive {
        const segments = [_][]const u8{input};
        return initAlloc(allocator, &segments, options);
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
        const size = std.math.cast(usize, self.geometry.media_size) orelse
            return error.IntegerOverflow;
        if (size > max_output_len) return error.OutputLimitExceeded;
        const output = try allocator.alloc(u8, size);
        errdefer allocator.free(output);
        try self.readRangeInto(allocator, 0, output);
        if (self.verify_checksums) {
            if (self.expected_md5) |expected| {
                var actual: [16]u8 = undefined;
                std.crypto.hash.Md5.hash(output, &actual, .{});
                if (!std.mem.eql(u8, &expected, &actual))
                    return error.ChecksumMismatch;
            }
        }
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
        if (range_end > self.geometry.media_size) return error.RangeOutOfBounds;
        var position = offset;
        var written: usize = 0;
        while (written < output.len) {
            const chunk_index = position / self.geometry.chunk_size;
            const chunk_offset = position % self.geometry.chunk_size;
            if (chunk_index >= self.chunks.len) return error.InvalidEwf;
            const chunk = self.chunks[chunk_index];
            const length = @min(
                output.len - written,
                chunk.decoded_size - chunk_offset,
            );
            const destination = output[written..][0..length];
            if (chunk.compressed) {
                const decoded = try deflate.decodeZlibAllocWithOptionsExactSize(
                    allocator,
                    chunk.encoded,
                    .{ .allow_trailing_data = true },
                    chunk.decoded_size,
                );
                defer allocator.free(decoded);
                @memcpy(destination, decoded[chunk_offset..][0..length]);
            } else {
                if (chunk.encoded.len != chunk.decoded_size + 4)
                    return error.SizeMismatch;
                if (self.verify_checksums and
                    format.readU32Le(chunk.encoded, chunk.decoded_size) !=
                        checksum.adler32(chunk.encoded[0..chunk.decoded_size]))
                    return error.ChecksumMismatch;
                @memcpy(destination, chunk.encoded[chunk_offset..][0..length]);
            }
            position += length;
            written += length;
        }
    }
};

fn appendTableChunks(
    allocator: std.mem.Allocator,
    chunks: *std.ArrayList(Chunk),
    segment: []const u8,
    segment_number: u16,
    section: format.Section,
    last_sectors: ?format.Section,
    geometry: format.Geometry,
    options: OpenOptions,
) Error!void {
    const header = try format.parseTableHeader(
        section.data,
        options.verify_checksums,
    );
    if (header.entry_count == 0) return error.InvalidEwf;
    const resulting_chunks = std.math.add(
        usize,
        chunks.items.len,
        header.entry_count,
    ) catch return error.IntegerOverflow;
    if (resulting_chunks > options.max_chunks or
        resulting_chunks > geometry.chunk_count)
        return error.OutputLimitExceeded;
    const entries_bytes = std.math.mul(
        usize,
        header.entry_count,
        format.table_entry_size,
    ) catch return error.IntegerOverflow;
    const footer_offset = std.math.add(
        usize,
        format.table_header_size,
        entries_bytes,
    ) catch return error.IntegerOverflow;
    const table_end = std.math.add(
        usize,
        footer_offset,
        format.table_footer_size,
    ) catch return error.IntegerOverflow;
    if (table_end > section.data.len) return error.TruncatedFrame;
    const entries = section.data[format.table_header_size .. format.table_header_size + entries_bytes];
    if (options.verify_checksums and
        format.readU32Le(section.data, footer_offset) != checksum.adler32(entries))
        return error.ChecksumMismatch;

    const offsets = try allocator.alloc(usize, header.entry_count);
    defer allocator.free(offsets);
    const compressed = try allocator.alloc(bool, header.entry_count);
    defer allocator.free(compressed);
    for (0..header.entry_count) |index| {
        const raw = format.readU32Le(entries, index * 4);
        const relative = raw & format.offset_mask;
        const absolute_u64 = std.math.add(
            u64,
            header.base_offset,
            relative,
        ) catch return error.IntegerOverflow;
        offsets[index] = std.math.cast(usize, absolute_u64) orelse
            return error.IntegerOverflow;
        compressed[index] = raw & format.compressed_offset_flag != 0;
        if (offsets[index] >= segment.len or
            (index != 0 and offsets[index] <= offsets[index - 1]))
            return error.InvalidEwf;
    }

    var data_end = section.next_offset;
    if (last_sectors) |sectors| {
        const sectors_data_start = sectors.offset + format.section_descriptor_size;
        if (offsets[0] >= sectors_data_start and offsets[0] < sectors.next_offset)
            data_end = sectors.next_offset;
    }
    if (data_end > segment.len or offsets[offsets.len - 1] >= data_end)
        return error.InvalidEwf;

    for (0..header.entry_count) |index| {
        const end = if (index + 1 < offsets.len) offsets[index + 1] else data_end;
        if (end <= offsets[index]) return error.InvalidEwf;
        const chunk_index = chunks.items.len;
        const chunk_start = std.math.mul(
            u64,
            chunk_index,
            geometry.chunk_size,
        ) catch return error.IntegerOverflow;
        if (chunk_start >= geometry.media_size) return error.SizeMismatch;
        const decoded_size_u64 = @min(
            @as(u64, @intCast(geometry.chunk_size)),
            geometry.media_size - chunk_start,
        );
        const decoded_size = std.math.cast(usize, decoded_size_u64) orelse
            return error.IntegerOverflow;
        const encoded = segment[offsets[index]..end];
        const max_encoded_bytes = std.math.add(
            usize,
            options.max_chunk_bytes,
            4,
        ) catch return error.IntegerOverflow;
        if (encoded.len > max_encoded_bytes)
            return error.OutputLimitExceeded;
        if (!compressed[index] and encoded.len != decoded_size + 4)
            return error.SizeMismatch;
        try chunks.append(allocator, .{
            .encoded = encoded,
            .decoded_size = decoded_size,
            .compressed = compressed[index],
            .segment_number = segment_number,
        });
    }
}

fn expectSameGeometry(a: format.Geometry, b: format.Geometry) Error!void {
    if (a.chunk_count != b.chunk_count or
        a.sectors_per_chunk != b.sectors_per_chunk or
        a.bytes_per_sector != b.bytes_per_sector or
        a.sector_count != b.sector_count or
        a.chunk_size != b.chunk_size or
        a.media_size != b.media_size)
        return error.InvalidEwf;
}
