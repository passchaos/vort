const std = @import("std");
const deflate = @import("../deflate.zig");
const format = @import("format.zig");

pub const Error = format.Error || deflate.Error || std.mem.Allocator.Error;

pub const Compression = enum {
    raw,
    zlib,
    auto,
};

pub const EncodeOptions = struct {
    compression: Compression = .auto,
    compression_level: u8 = 6,
    max_frames: usize = 1 << 20,
    max_nc_areas: usize = 1 << 20,
};

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: EncodeOptions,
) Error![]u8 {
    if (input.len > std.math.maxInt(u32)) return error.OutputLimitExceeded;
    if (options.compression_level == 0 or options.compression_level > 9)
        return error.InvalidDax;
    const frame_count = std.math.divCeil(
        usize,
        input.len,
        format.frame_size,
    ) catch return error.IntegerOverflow;
    if (frame_count > options.max_frames) return error.OutputLimitExceeded;

    const relative_offsets = try allocator.alloc(usize, frame_count);
    defer allocator.free(relative_offsets);
    const sizes = try allocator.alloc(u16, frame_count);
    defer allocator.free(sizes);
    const raw_frames = try allocator.alloc(bool, frame_count);
    defer allocator.free(raw_frames);
    const padded = try allocator.alloc(u8, format.frame_size);
    defer allocator.free(padded);
    var data: std.ArrayList(u8) = .empty;
    defer data.deinit(allocator);

    for (0..frame_count) |frame_index| {
        const source_start = frame_index * format.frame_size;
        const source_len = @min(
            input.len - source_start,
            format.frame_size,
        );
        @memset(padded, 0);
        @memcpy(padded[0..source_len], input[source_start..][0..source_len]);
        const compressed = if (options.compression == .raw)
            null
        else
            try deflate.encodeZlibLevelAlloc(
                allocator,
                padded,
                @intCast(options.compression_level),
            );
        defer if (compressed) |bytes| allocator.free(bytes);
        const raw = options.compression == .raw or
            (options.compression == .auto and compressed.?.len >= padded.len);
        const selected: []const u8 = if (raw) padded else compressed.?;
        if (selected.len > std.math.maxInt(u16))
            return error.OutputLimitExceeded;
        relative_offsets[frame_index] = data.items.len;
        sizes[frame_index] = @intCast(selected.len);
        raw_frames[frame_index] = raw;
        try data.appendSlice(allocator, selected);
    }

    var areas: std.ArrayList(format.NonCompressedArea) = .empty;
    defer areas.deinit(allocator);
    var frame_index: usize = 0;
    while (frame_index < frame_count) {
        if (!raw_frames[frame_index]) {
            frame_index += 1;
            continue;
        }
        const start = frame_index;
        while (frame_index < frame_count and raw_frames[frame_index])
            frame_index += 1;
        try areas.append(allocator, .{
            .start = start,
            .count = frame_index - start,
        });
    }
    if (areas.items.len > options.max_nc_areas or
        areas.items.len > std.math.maxInt(u32))
        return error.OutputLimitExceeded;

    const table_entry_bytes = std.math.add(
        usize,
        format.offset_entry_size,
        format.size_entry_size,
    ) catch return error.IntegerOverflow;
    const tables_bytes = std.math.mul(
        usize,
        frame_count,
        table_entry_bytes,
    ) catch return error.IntegerOverflow;
    const areas_bytes = std.math.mul(
        usize,
        areas.items.len,
        format.area_entry_size,
    ) catch return error.IntegerOverflow;
    const data_start = std.math.add(
        usize,
        format.header_size + tables_bytes,
        areas_bytes,
    ) catch return error.IntegerOverflow;
    const output_size = std.math.add(
        usize,
        data_start,
        data.items.len,
    ) catch return error.IntegerOverflow;
    if (output_size > std.math.maxInt(u32))
        return error.OutputLimitExceeded;
    const output = try allocator.alloc(u8, output_size);
    errdefer allocator.free(output);
    @memset(output[0..data_start], 0);
    @memcpy(output[data_start..], data.items);

    @memcpy(output[0..4], format.magic);
    format.writeU32Le(output, 4, @intCast(input.len));
    format.writeU32Le(output, 8, if (areas.items.len == 0) 0 else 1);
    format.writeU32Le(output, 12, @intCast(areas.items.len));
    const sizes_offset = format.header_size +
        frame_count * format.offset_entry_size;
    const areas_offset = sizes_offset +
        frame_count * format.size_entry_size;
    for (0..frame_count) |index| {
        const absolute_offset = std.math.add(
            usize,
            data_start,
            relative_offsets[index],
        ) catch return error.IntegerOverflow;
        format.writeU32Le(
            output,
            format.header_size + index * format.offset_entry_size,
            @intCast(absolute_offset),
        );
        format.writeU16Le(
            output,
            sizes_offset + index * format.size_entry_size,
            sizes[index],
        );
    }
    for (areas.items, 0..) |area, index| {
        const offset = areas_offset + index * format.area_entry_size;
        format.writeU32Le(output, offset, @intCast(area.start));
        format.writeU32Le(output, offset + 4, @intCast(area.count));
    }
    return output;
}
