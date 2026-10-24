const std = @import("std");
const checksum = @import("../checksum.zig");
const deflate = @import("../deflate.zig");
const format = @import("format.zig");

pub const Error = format.Error || deflate.Error || std.mem.Allocator.Error || error{
    InvalidEwfSegmentSize,
};

pub const Compression = enum {
    none,
    zlib,
    auto,
};

pub const EncodeOptions = struct {
    compression: Compression = .auto,
    sectors_per_chunk: u32 = 64,
    max_table_entries: u32 = 16375,
};

pub const EncodedSegments = struct {
    allocator: std.mem.Allocator,
    segments: [][]u8,

    pub fn deinit(self: *EncodedSegments) void {
        for (self.segments) |segment| self.allocator.free(segment);
        self.allocator.free(self.segments);
        self.* = undefined;
    }
};

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: EncodeOptions,
) Error![]u8 {
    const layout = try prepareLayout(input.len, options);

    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    try appendFileHeader(allocator, &output, 1);

    const volume = try makeVolumeData(
        allocator,
        layout.chunk_count,
        options.sectors_per_chunk,
        layout.media_size / 512,
        options.compression,
    );
    defer allocator.free(volume);
    try appendSection(allocator, &output, "volume", volume);

    var md5 = std.crypto.hash.Md5.init(.{});
    var first_chunk: usize = 0;
    while (first_chunk < layout.chunk_count) {
        const entry_count = @min(
            layout.entries_per_group,
            layout.chunk_count - first_chunk,
        );
        try appendChunkGroup(
            allocator,
            &output,
            input,
            layout,
            options,
            first_chunk,
            entry_count,
            &md5,
        );
        first_chunk += entry_count;
    }

    try appendSection(allocator, &output, "data", volume);
    try appendHashSection(allocator, &output, &md5);
    try appendTerminal(allocator, &output, "done");
    return output.toOwnedSlice(allocator);
}

pub fn encodeSegmentsAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: EncodeOptions,
    max_segment_size: usize,
) Error!EncodedSegments {
    if (max_segment_size == 0) return error.InvalidEwfSegmentSize;
    const layout = try prepareLayout(input.len, options);
    if (try singleSegmentBound(layout) <= max_segment_size) {
        const encoded = try encodeAlloc(allocator, input, options);
        errdefer allocator.free(encoded);
        if (encoded.len > max_segment_size) return error.InvalidEwfSegmentSize;
        const segments = try allocator.alloc([]u8, 1);
        segments[0] = encoded;
        return .{ .allocator = allocator, .segments = segments };
    }
    if (layout.chunk_count == 0) return error.InvalidEwfSegmentSize;

    const volume = try makeVolumeData(
        allocator,
        layout.chunk_count,
        options.sectors_per_chunk,
        layout.media_size / 512,
        options.compression,
    );
    defer allocator.free(volume);

    var segments: std.ArrayList([]u8) = .empty;
    errdefer {
        for (segments.items) |segment| allocator.free(segment);
        segments.deinit(allocator);
    }
    var current: std.ArrayList(u8) = .empty;
    defer current.deinit(allocator);
    var md5 = std.crypto.hash.Md5.init(.{});
    var segment_number: u16 = 1;
    var first_chunk: usize = 0;
    var groups_in_segment: usize = 0;
    try startSegment(allocator, &current, segment_number, volume, true);

    while (first_chunk < layout.chunk_count) {
        const reserved_tail = hash_section_size + format.section_descriptor_size;
        const available = if (current.items.len < max_segment_size and
            reserved_tail <= max_segment_size - current.items.len)
            max_segment_size - current.items.len - reserved_tail
        else
            0;
        const fitting_entries = maxGroupEntries(layout, available);
        if (fitting_entries == 0) {
            if (groups_in_segment == 0) return error.InvalidEwfSegmentSize;
            try appendTerminal(allocator, &current, "next");
            if (current.items.len > max_segment_size)
                return error.InvalidEwfSegmentSize;
            try appendOwnedSegment(allocator, &segments, &current);
            segment_number = std.math.add(u16, segment_number, 1) catch
                return error.OutputLimitExceeded;
            try startSegment(
                allocator,
                &current,
                segment_number,
                volume,
                false,
            );
            groups_in_segment = 0;
            continue;
        }
        const entry_count = @min(
            fitting_entries,
            @min(
                layout.entries_per_group,
                layout.chunk_count - first_chunk,
            ),
        );
        try appendChunkGroup(
            allocator,
            &current,
            input,
            layout,
            options,
            first_chunk,
            entry_count,
            &md5,
        );
        first_chunk += entry_count;
        groups_in_segment += 1;
    }

    try appendHashSection(allocator, &current, &md5);
    try appendTerminal(allocator, &current, "done");
    if (current.items.len > max_segment_size)
        return error.InvalidEwfSegmentSize;
    try appendOwnedSegment(allocator, &segments, &current);
    return .{
        .allocator = allocator,
        .segments = try segments.toOwnedSlice(allocator),
    };
}

const Layout = struct {
    media_size: usize,
    chunk_size: usize,
    chunk_count: usize,
    chunk_bound: usize,
    entries_per_group: usize,
};

const volume_section_size = format.section_descriptor_size + 1052;
const hash_section_size = format.section_descriptor_size + 36;
const table_section_fixed_size = format.section_descriptor_size +
    format.table_header_size + format.table_footer_size;
const group_fixed_size = format.section_descriptor_size +
    2 * table_section_fixed_size;

fn prepareLayout(input_len: usize, options: EncodeOptions) Error!Layout {
    if (options.sectors_per_chunk == 0 or
        options.sectors_per_chunk > 32768 or
        options.max_table_entries == 0 or
        options.max_table_entries > 65534)
        return error.InvalidEwf;
    const sector_remainder = input_len % 512;
    const media_size = if (sector_remainder == 0)
        input_len
    else
        std.math.add(usize, input_len, 512 - sector_remainder) catch
            return error.IntegerOverflow;
    const chunk_size = std.math.mul(
        usize,
        options.sectors_per_chunk,
        512,
    ) catch return error.IntegerOverflow;
    const chunk_count = std.math.divCeil(
        usize,
        media_size,
        chunk_size,
    ) catch return error.IntegerOverflow;
    if (chunk_count > std.math.maxInt(u32)) return error.OutputLimitExceeded;
    const chunk_bound = if (options.compression == .zlib)
        std.math.add(
            usize,
            std.math.mul(usize, chunk_size, 2) catch
                return error.IntegerOverflow,
            4,
        ) catch return error.IntegerOverflow
    else
        std.math.add(usize, chunk_size, 4) catch
            return error.IntegerOverflow;
    const entries_by_offset = @max(
        @as(usize, 1),
        (format.offset_mask - format.section_descriptor_size) / chunk_bound,
    );
    return .{
        .media_size = media_size,
        .chunk_size = chunk_size,
        .chunk_count = chunk_count,
        .chunk_bound = chunk_bound,
        .entries_per_group = @min(
            @as(usize, options.max_table_entries),
            entries_by_offset,
        ),
    };
}

fn singleSegmentBound(layout: Layout) Error!usize {
    var size = format.file_header_size + 2 * volume_section_size +
        hash_section_size + format.section_descriptor_size;
    var remaining = layout.chunk_count;
    while (remaining != 0) {
        const entries = @min(layout.entries_per_group, remaining);
        const entry_bytes = std.math.mul(
            usize,
            entries,
            std.math.add(usize, layout.chunk_bound, 8) catch
                return error.IntegerOverflow,
        ) catch return error.IntegerOverflow;
        size = std.math.add(
            usize,
            size,
            std.math.add(usize, group_fixed_size, entry_bytes) catch
                return error.IntegerOverflow,
        ) catch return error.IntegerOverflow;
        remaining -= entries;
    }
    return size;
}

fn maxGroupEntries(layout: Layout, available: usize) usize {
    if (available <= group_fixed_size) return 0;
    return (available - group_fixed_size) / (layout.chunk_bound + 8);
}

fn appendOwnedSegment(
    allocator: std.mem.Allocator,
    segments: *std.ArrayList([]u8),
    current: *std.ArrayList(u8),
) Error!void {
    const owned = try current.toOwnedSlice(allocator);
    segments.append(allocator, owned) catch |err| {
        allocator.free(owned);
        return err;
    };
}

fn startSegment(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    segment_number: u16,
    volume: []const u8,
    first: bool,
) Error!void {
    try appendFileHeader(allocator, output, segment_number);
    try appendSection(
        allocator,
        output,
        if (first) "volume" else "data",
        volume,
    );
}

fn appendFileHeader(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    segment_number: u16,
) Error!void {
    try output.appendSlice(allocator, format.ewf1_signature);
    try output.append(allocator, 1);
    var segment_bytes: [2]u8 = undefined;
    std.mem.writeInt(u16, &segment_bytes, segment_number, .little);
    try output.appendSlice(allocator, &segment_bytes);
    try output.appendNTimes(allocator, 0, 2);
}

fn appendChunkGroup(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
    layout: Layout,
    options: EncodeOptions,
    first_chunk: usize,
    entry_count: usize,
    md5: *std.crypto.hash.Md5,
) Error!void {
    const sectors_offset = output.items.len;
    try output.appendNTimes(allocator, 0, format.section_descriptor_size);
    const table_entries = try allocator.alloc(u32, entry_count);
    defer allocator.free(table_entries);

    for (0..entry_count) |local_index| {
        const chunk_index = first_chunk + local_index;
        const relative_offset = output.items.len - sectors_offset;
        if (relative_offset > format.offset_mask)
            return error.OutputLimitExceeded;
        const chunk = try makeChunk(
            allocator,
            input,
            layout.media_size,
            chunk_index,
            layout.chunk_size,
        );
        defer allocator.free(chunk);
        md5.update(chunk);
        const compressed = if (options.compression == .none)
            null
        else
            try deflate.encodeZlibBestAlloc(
                allocator,
                chunk,
                deflate.optionsForLevel(.default),
            );
        defer if (compressed) |bytes| allocator.free(bytes);
        const use_compressed = if (compressed) |bytes|
            options.compression == .zlib or bytes.len < chunk.len + 4
        else
            false;
        table_entries[local_index] = @as(u32, @intCast(relative_offset)) |
            (if (use_compressed) format.compressed_offset_flag else 0);
        if (use_compressed) {
            try output.appendSlice(allocator, compressed.?);
        } else {
            try output.appendSlice(allocator, chunk);
            var digest: [4]u8 = undefined;
            std.mem.writeInt(u32, &digest, checksum.adler32(chunk), .little);
            try output.appendSlice(allocator, &digest);
        }
    }
    finishSection(output.items, sectors_offset, "sectors", output.items.len, false);

    const table_data = try makeTableData(
        allocator,
        sectors_offset,
        table_entries,
    );
    defer allocator.free(table_data);
    try appendSection(allocator, output, "table", table_data);
    try appendSection(allocator, output, "table2", table_data);
}

fn appendHashSection(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    md5: *std.crypto.hash.Md5,
) Error!void {
    var md5_digest: [std.crypto.hash.Md5.digest_length]u8 = undefined;
    md5.final(&md5_digest);
    var hash_data = [_]u8{0} ** 36;
    @memcpy(hash_data[0..16], &md5_digest);
    format.writeU32Le(&hash_data, 32, checksum.adler32(hash_data[0..32]));
    try appendSection(allocator, output, "hash", &hash_data);
}

fn appendTerminal(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    kind: []const u8,
) Error!void {
    const offset = output.items.len;
    try output.appendNTimes(allocator, 0, format.section_descriptor_size);
    finishSection(output.items, offset, kind, offset, true);
}

fn makeVolumeData(
    allocator: std.mem.Allocator,
    chunk_count: usize,
    sectors_per_chunk: u32,
    sector_count: usize,
    compression: Compression,
) Error![]u8 {
    const data = try allocator.alloc(u8, 1052);
    @memset(data, 0);
    data[0] = 1;
    format.writeU32Le(data, 4, @intCast(chunk_count));
    format.writeU32Le(data, 8, sectors_per_chunk);
    format.writeU32Le(data, 12, 512);
    format.writeU64Le(data, 16, sector_count);
    data[36] = 1;
    data[52] = if (compression == .none) 0 else 1;
    format.writeU32Le(data, 56, sectors_per_chunk);
    @memcpy(data[64..80], "VORT-EWF1-000001");
    format.writeU32Le(data, 1048, checksum.adler32(data[0..1048]));
    return data;
}

fn makeTableData(
    allocator: std.mem.Allocator,
    base_offset: usize,
    entries: []const u32,
) Error![]u8 {
    const entries_bytes = std.math.mul(usize, entries.len, 4) catch
        return error.IntegerOverflow;
    const size = std.math.add(
        usize,
        format.table_header_size + format.table_footer_size,
        entries_bytes,
    ) catch return error.IntegerOverflow;
    const data = try allocator.alloc(u8, size);
    @memset(data, 0);
    format.writeU32Le(data, 0, @intCast(entries.len));
    format.writeU64Le(data, 8, base_offset);
    format.writeU32Le(data, 20, checksum.adler32(data[0..20]));
    for (entries, 0..) |entry, index|
        format.writeU32Le(data, format.table_header_size + index * 4, entry);
    const entries_slice = data[format.table_header_size .. format.table_header_size + entries_bytes];
    format.writeU32Le(
        data,
        format.table_header_size + entries_bytes,
        checksum.adler32(entries_slice),
    );
    return data;
}

fn makeChunk(
    allocator: std.mem.Allocator,
    input: []const u8,
    media_size: usize,
    chunk_index: usize,
    chunk_size: usize,
) Error![]u8 {
    const start = std.math.mul(usize, chunk_index, chunk_size) catch
        return error.IntegerOverflow;
    const decoded_size = @min(chunk_size, media_size - start);
    const chunk = try allocator.alloc(u8, decoded_size);
    @memset(chunk, 0);
    if (start < input.len) {
        const end = @min(input.len, start + decoded_size);
        @memcpy(chunk[0 .. end - start], input[start..end]);
    }
    return chunk;
}

fn appendSection(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    kind: []const u8,
    data: []const u8,
) Error!void {
    const offset = output.items.len;
    try output.appendNTimes(allocator, 0, format.section_descriptor_size);
    try output.appendSlice(allocator, data);
    finishSection(output.items, offset, kind, output.items.len, false);
}

fn finishSection(
    output: []u8,
    offset: usize,
    kind: []const u8,
    next_offset: usize,
    terminal: bool,
) void {
    const descriptor = output[offset..][0..format.section_descriptor_size];
    @memset(descriptor, 0);
    @memcpy(descriptor[0..kind.len], kind);
    format.writeU64Le(descriptor, 16, if (terminal) offset else next_offset);
    format.writeU64Le(
        descriptor,
        24,
        if (terminal) 0 else next_offset - offset,
    );
    format.writeU32Le(descriptor, 72, checksum.adler32(descriptor[0..72]));
}
