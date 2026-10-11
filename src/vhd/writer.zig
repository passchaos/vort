const std = @import("std");
const archive_mod = @import("archive.zig");
const format = @import("format.zig");

pub const Error = archive_mod.Error || format.Error || std.mem.Allocator.Error;

pub const EncodeOptions = struct {
    disk_type: format.DiskType = .dynamic,
    block_size: u32 = 2 * 1024 * 1024,
    /// Required for differencing output and ignored otherwise.
    parent: ?*const archive_mod.Archive = null,
    max_table_entries: usize = 1 << 24,
};

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: EncodeOptions,
) Error![]u8 {
    try validateOptions(input, options);
    return switch (options.disk_type) {
        .fixed => encodeFixedAlloc(allocator, input, options),
        .dynamic, .differencing => encodeSparseAlloc(allocator, input, options),
    };
}

fn validateOptions(input: []const u8, options: EncodeOptions) Error!void {
    if (options.block_size < format.sector_size or
        !std.math.isPowerOfTwo(options.block_size) or
        options.block_size % format.sector_size != 0)
        return error.InvalidVhd;
    const media_size = std.mem.alignForward(usize, input.len, format.sector_size);
    if (media_size / format.sector_size > format.maximum_sectors)
        return error.OutputLimitExceeded;
    const table_entries = std.math.divCeil(
        usize,
        media_size,
        options.block_size,
    ) catch return error.IntegerOverflow;
    if (table_entries > options.max_table_entries or
        table_entries > std.math.maxInt(u32))
        return error.OutputLimitExceeded;
    switch (options.disk_type) {
        .fixed, .dynamic => if (options.parent != null) return error.InvalidVhd,
        .differencing => {
            const parent = options.parent orelse return error.MissingVhdParent;
            if (parent.footer.current_size != media_size)
                return error.MissingVhdParent;
        },
    }
}

fn encodeFixedAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: EncodeOptions,
) Error![]u8 {
    const media_size = std.mem.alignForward(usize, input.len, format.sector_size);
    const output_size = std.math.add(
        usize,
        media_size,
        format.footer_size,
    ) catch return error.IntegerOverflow;
    const output = try allocator.alloc(u8, output_size);
    errdefer allocator.free(output);
    @memset(output, 0);
    @memcpy(output[0..input.len], input);
    const footer = makeFooter(input, media_size, options);
    @memcpy(output[media_size..], &footer);
    return output;
}

fn encodeSparseAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: EncodeOptions,
) Error![]u8 {
    const media_size = std.mem.alignForward(usize, input.len, format.sector_size);
    const table_entries = std.math.divCeil(
        usize,
        media_size,
        options.block_size,
    ) catch return error.IntegerOverflow;
    const bat_bytes = std.math.mul(usize, table_entries, 4) catch
        return error.IntegerOverflow;
    const bat_padded = std.mem.alignForward(usize, bat_bytes, format.sector_size);
    const data_start = std.math.add(
        usize,
        format.footer_size + format.dynamic_header_size,
        bat_padded,
    ) catch return error.IntegerOverflow;
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    try output.appendNTimes(allocator, 0, data_start);
    const footer = makeFooter(input, media_size, options);
    @memcpy(output.items[0..format.footer_size], &footer);
    const dynamic_header = makeDynamicHeader(
        table_entries,
        options,
    );
    @memcpy(
        output.items[format.footer_size..][0..format.dynamic_header_size],
        &dynamic_header,
    );
    @memset(
        output.items[format.footer_size + format.dynamic_header_size .. data_start],
        0xff,
    );

    const block = try allocator.alloc(u8, options.block_size);
    defer allocator.free(block);
    const bitmap_size = bitmapSize(options.block_size);
    const bitmap = try allocator.alloc(u8, bitmap_size);
    defer allocator.free(bitmap);
    var parent_sector: [format.sector_size]u8 = undefined;
    for (0..table_entries) |block_index| {
        fillBlock(input, block_index, options.block_size, block);
        @memset(bitmap, if (options.disk_type == .dynamic) 0xff else 0);
        var allocated = options.disk_type == .dynamic and
            !std.mem.allEqual(u8, block, 0);
        if (options.disk_type == .differencing) {
            const parent = options.parent.?;
            const block_start = block_index * @as(usize, options.block_size);
            const sectors = options.block_size / format.sector_size;
            for (0..sectors) |sector| {
                const logical_offset = block_start + sector * format.sector_size;
                if (logical_offset >= media_size) break;
                try parent.readRangeInto(logical_offset, &parent_sector);
                const child_sector = block[sector * format.sector_size ..][0..format.sector_size];
                if (!std.mem.eql(u8, child_sector, &parent_sector)) {
                    setBitmapBit(bitmap, sector);
                    allocated = true;
                }
            }
        }
        if (!allocated) continue;
        if (output.items.len % format.sector_size != 0)
            return error.InvalidVhd;
        const bat_sector = output.items.len / format.sector_size;
        if (bat_sector >= format.unallocated_bat_entry)
            return error.OutputLimitExceeded;
        format.writeU32Be(
            output.items,
            format.footer_size + format.dynamic_header_size + block_index * 4,
            @intCast(bat_sector),
        );
        try output.appendSlice(allocator, bitmap);
        try output.appendSlice(allocator, block);
    }
    try output.appendSlice(allocator, &footer);
    return output.toOwnedSlice(allocator);
}

fn makeFooter(
    input: []const u8,
    media_size: usize,
    options: EncodeOptions,
) [format.footer_size]u8 {
    var footer = [_]u8{0} ** format.footer_size;
    @memcpy(footer[0..8], format.footer_cookie);
    format.writeU32Be(&footer, 8, 2);
    format.writeU32Be(&footer, 12, format.version);
    format.writeU64Be(
        &footer,
        16,
        if (options.disk_type == .fixed)
            std.math.maxInt(u64)
        else
            format.footer_size,
    );
    @memcpy(footer[28..32], "qem2");
    format.writeU32Be(&footer, 32, 0x0001_0000);
    @memcpy(footer[36..40], "Wi2k");
    format.writeU64Be(&footer, 40, media_size);
    format.writeU64Be(&footer, 48, media_size);
    const geometry = calculateGeometry(media_size / format.sector_size);
    format.writeU16Be(&footer, 56, geometry.cylinders);
    footer[58] = geometry.heads;
    footer[59] = geometry.sectors_per_track;
    format.writeU32Be(&footer, 60, @intFromEnum(options.disk_type));
    const unique_id = makeUniqueId(input, options);
    @memcpy(footer[68..84], &unique_id);
    format.writeU32Be(&footer, 64, format.footerChecksum(&footer));
    return footer;
}

fn makeDynamicHeader(
    table_entries: usize,
    options: EncodeOptions,
) [format.dynamic_header_size]u8 {
    var header = [_]u8{0} ** format.dynamic_header_size;
    @memcpy(header[0..8], format.dynamic_cookie);
    format.writeU64Be(&header, 8, std.math.maxInt(u64));
    format.writeU64Be(
        &header,
        16,
        format.footer_size + format.dynamic_header_size,
    );
    format.writeU32Be(&header, 24, format.version);
    format.writeU32Be(&header, 28, @intCast(table_entries));
    format.writeU32Be(&header, 32, options.block_size);
    if (options.parent) |parent| {
        @memcpy(header[40..56], &parent.footer.unique_id);
        writeUtf16Be(header[64..576], "parent.vhd");
    }
    format.writeU32Be(&header, 36, format.dynamicHeaderChecksum(&header));
    return header;
}

fn makeUniqueId(input: []const u8, options: EncodeOptions) [16]u8 {
    var state = std.crypto.hash.sha2.Sha256.init(.{});
    state.update(input);
    var type_bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &type_bytes, @intFromEnum(options.disk_type), .big);
    state.update(&type_bytes);
    if (options.parent) |parent| state.update(&parent.footer.unique_id);
    var digest: [32]u8 = undefined;
    state.final(&digest);
    var result: [16]u8 = digest[0..16].*;
    result[6] = (result[6] & 0x0f) | 0x40;
    result[8] = (result[8] & 0x3f) | 0x80;
    return result;
}

fn calculateGeometry(total_sectors_input: usize) format.Geometry {
    const maximum_geometry: usize = 65535 * 16 * 255;
    const total_sectors = @min(total_sectors_input, maximum_geometry);
    var heads: usize = undefined;
    var sectors_per_track: usize = undefined;
    var cylinders_times_heads: usize = undefined;
    if (total_sectors >= 65535 * 16 * 63) {
        sectors_per_track = 255;
        heads = 16;
        cylinders_times_heads = total_sectors / sectors_per_track;
    } else {
        sectors_per_track = 17;
        cylinders_times_heads = total_sectors / sectors_per_track;
        heads = std.math.divCeil(usize, cylinders_times_heads, 1024) catch
            unreachable;
        heads = @max(heads, 4);
        if (cylinders_times_heads >= heads * 1024 or heads > 16) {
            sectors_per_track = 31;
            heads = 16;
            cylinders_times_heads = total_sectors / sectors_per_track;
        }
        if (cylinders_times_heads >= heads * 1024) {
            sectors_per_track = 63;
            heads = 16;
            cylinders_times_heads = total_sectors / sectors_per_track;
        }
    }
    return .{
        .cylinders = @intCast(if (heads == 0) 0 else cylinders_times_heads / heads),
        .heads = @intCast(heads),
        .sectors_per_track = @intCast(sectors_per_track),
    };
}

fn bitmapSize(block_size: usize) usize {
    const sectors = block_size / format.sector_size;
    const bytes = std.math.divCeil(usize, sectors, 8) catch unreachable;
    return std.mem.alignForward(usize, bytes, format.sector_size);
}

fn setBitmapBit(bitmap: []u8, sector_index: usize) void {
    bitmap[sector_index / 8] |= @as(u8, 1) << @intCast(7 - sector_index % 8);
}

fn fillBlock(
    input: []const u8,
    block_index: usize,
    block_size: usize,
    output: []u8,
) void {
    @memset(output, 0);
    const start = block_index * block_size;
    if (start >= input.len) return;
    const end = @min(input.len, start + block_size);
    @memcpy(output[0 .. end - start], input[start..end]);
}

fn writeUtf16Be(output: []u8, text: []const u8) void {
    @memset(output, 0);
    for (text[0..@min(text.len, output.len / 2)], 0..) |byte, index|
        output[index * 2 + 1] = byte;
}
