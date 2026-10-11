const std = @import("std");
const deflate = @import("../deflate.zig");
const format = @import("format.zig");

pub const Error = format.Error || deflate.Error || std.mem.Allocator.Error;

pub const Compression = enum {
    none,
    zlib,
};

pub const EncodeOptions = struct {
    compression: Compression = .zlib,
    grain_sectors: u32 = 128,
};

const descriptor_sectors: usize = 20;
const gtes_per_gt: usize = 512;

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: EncodeOptions,
) Error![]u8 {
    if (!isPowerOfTwo(options.grain_sectors) or
        options.grain_sectors < 8 or options.grain_sectors > 4096)
        return error.InvalidVmdk;
    const remainder = input.len % format.sector_size;
    const virtual_size = if (remainder == 0)
        input.len
    else
        std.math.add(
            usize,
            input.len,
            format.sector_size - remainder,
        ) catch return error.IntegerOverflow;
    const grain_size = std.math.mul(
        usize,
        options.grain_sectors,
        format.sector_size,
    ) catch return error.IntegerOverflow;
    const grain_count = std.math.divCeil(
        usize,
        virtual_size,
        grain_size,
    ) catch return error.IntegerOverflow;
    const gd_entries = std.math.divCeil(
        usize,
        grain_count,
        gtes_per_gt,
    ) catch return error.IntegerOverflow;

    const grain_table = try allocator.alloc(u32, grain_count);
    defer allocator.free(grain_table);
    @memset(grain_table, 0);
    return switch (options.compression) {
        .none => encodeSparse(
            allocator,
            input,
            virtual_size,
            grain_size,
            options.grain_sectors,
            gd_entries,
            grain_table,
        ),
        .zlib => encodeStreamOptimized(
            allocator,
            input,
            virtual_size,
            grain_size,
            options.grain_sectors,
            gd_entries,
            grain_table,
        ),
    };
}

fn encodeSparse(
    allocator: std.mem.Allocator,
    input: []const u8,
    virtual_size: usize,
    grain_size: usize,
    grain_sectors: u32,
    gd_entries: usize,
    grain_table: []u32,
) Error![]u8 {
    const gd_sectors = try tableSectors(gd_entries);
    const gt_sectors = try tableSectors(gtes_per_gt);
    const gd_offset: usize = if (gd_entries == 0)
        0
    else
        1 + descriptor_sectors;
    const gt_base = std.math.add(usize, gd_offset, gd_sectors) catch
        return error.IntegerOverflow;
    const all_gt_sectors = std.math.mul(usize, gd_entries, gt_sectors) catch
        return error.IntegerOverflow;
    const metadata_end = if (gd_entries == 0)
        1 + descriptor_sectors
    else
        std.math.add(usize, gt_base, all_gt_sectors) catch
            return error.IntegerOverflow;
    const overhead_sectors = alignForwardChecked(metadata_end, grain_sectors) catch
        return error.IntegerOverflow;
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    try output.appendNTimes(
        allocator,
        0,
        std.math.mul(usize, overhead_sectors, format.sector_size) catch
            return error.IntegerOverflow,
    );
    writeHeader(
        output.items[0..format.header_size],
        .sparse,
        virtual_size / format.sector_size,
        grain_sectors,
        gd_offset,
        overhead_sectors,
    );
    try writeDescriptor(
        allocator,
        output.items[format.sector_size .. (1 + descriptor_sectors) * format.sector_size],
        virtual_size / format.sector_size,
        .sparse,
    );

    for (0..gd_entries) |gd_index| {
        const gt_sector = std.math.add(
            usize,
            gt_base,
            std.math.mul(usize, gd_index, gt_sectors) catch
                return error.IntegerOverflow,
        ) catch return error.IntegerOverflow;
        writeU32AtSectorTable(output.items, gd_offset, gd_index, try castU32(gt_sector));
    }
    for (0..grain_table.len) |grain_index| {
        const cluster = try makeGrain(allocator, input, grain_index, grain_size);
        defer allocator.free(cluster);
        if (allZero(cluster)) {
            grain_table[grain_index] = 1;
            continue;
        }
        if (output.items.len % grain_size != 0) return error.InvalidVmdk;
        grain_table[grain_index] = try castU32(output.items.len / format.sector_size);
        try output.appendSlice(allocator, cluster);
    }
    for (grain_table, 0..) |entry, grain_index| {
        const gd_index = grain_index / gtes_per_gt;
        const gt_index = grain_index % gtes_per_gt;
        const gt_sector = gt_base + gd_index * gt_sectors;
        writeU32AtSectorTable(output.items, gt_sector, gt_index, entry);
    }
    return output.toOwnedSlice(allocator);
}

fn encodeStreamOptimized(
    allocator: std.mem.Allocator,
    input: []const u8,
    virtual_size: usize,
    grain_size: usize,
    grain_sectors: u32,
    gd_entries: usize,
    grain_table: []u32,
) Error![]u8 {
    const overhead_sectors = 1 + descriptor_sectors;
    const gt_sectors = try tableSectors(gtes_per_gt);
    const gd_sectors = try tableSectors(gd_entries);
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    try output.appendNTimes(
        allocator,
        0,
        overhead_sectors * format.sector_size,
    );
    writeHeader(
        output.items[0..format.header_size],
        .stream_optimized_initial,
        virtual_size / format.sector_size,
        grain_sectors,
        0,
        overhead_sectors,
    );
    try writeDescriptor(
        allocator,
        output.items[format.sector_size .. overhead_sectors * format.sector_size],
        virtual_size / format.sector_size,
        .stream_optimized,
    );

    for (0..grain_table.len) |grain_index| {
        const cluster = try makeGrain(allocator, input, grain_index, grain_size);
        defer allocator.free(cluster);
        if (allZero(cluster)) continue;
        const compressed = try deflate.encodeZlibBestAlloc(
            allocator,
            cluster,
            deflate.optionsForLevel(.default),
        );
        defer allocator.free(compressed);
        grain_table[grain_index] = try castU32(output.items.len / format.sector_size);
        const marker_start = output.items.len;
        try output.appendNTimes(allocator, 0, 12);
        format.writeU64Le(
            output.items,
            marker_start,
            std.math.mul(u64, grain_index, grain_sectors) catch
                return error.IntegerOverflow,
        );
        format.writeU32Le(
            output.items,
            marker_start + 8,
            try castU32(compressed.len),
        );
        try output.appendSlice(allocator, compressed);
        try padToSector(allocator, &output);
    }

    const gd_table = try allocator.alloc(u32, gd_entries);
    defer allocator.free(gd_table);
    @memset(gd_table, 0);
    for (0..gd_entries) |gd_index| {
        try appendMetadataMarker(allocator, &output, .grain_table, gt_sectors);
        const gt_sector = output.items.len / format.sector_size;
        gd_table[gd_index] = try castU32(gt_sector);
        const gt_start = output.items.len;
        try output.appendNTimes(allocator, 0, gt_sectors * format.sector_size);
        const first_grain = gd_index * gtes_per_gt;
        const entries = @min(gtes_per_gt, grain_table.len - first_grain);
        for (0..entries) |gt_index|
            format.writeU32Le(
                output.items,
                gt_start + gt_index * 4,
                grain_table[first_grain + gt_index],
            );
    }
    try appendMetadataMarker(allocator, &output, .grain_directory, gd_sectors);
    const gd_offset = output.items.len / format.sector_size;
    const gd_start = output.items.len;
    try output.appendNTimes(allocator, 0, gd_sectors * format.sector_size);
    for (gd_table, 0..) |entry, index|
        format.writeU32Le(output.items, gd_start + index * 4, entry);

    try appendMetadataMarker(allocator, &output, .footer, 1);
    const footer_start = output.items.len;
    try output.appendNTimes(allocator, 0, format.sector_size);
    writeHeader(
        output.items[footer_start..][0..format.header_size],
        .stream_optimized_footer,
        virtual_size / format.sector_size,
        grain_sectors,
        gd_offset,
        overhead_sectors,
    );
    try appendMetadataMarker(allocator, &output, .end_of_stream, 0);
    return output.toOwnedSlice(allocator);
}

const HeaderKind = enum {
    sparse,
    stream_optimized_initial,
    stream_optimized_footer,
};

fn writeHeader(
    output: []u8,
    kind: HeaderKind,
    capacity_sectors: usize,
    grain_sectors: u32,
    gd_offset: usize,
    overhead_sectors: usize,
) void {
    @memset(output, 0);
    const compressed = kind != .sparse;
    format.writeU32Le(output, 0, format.magic);
    format.writeU32Le(output, 4, if (compressed) 3 else 2);
    format.writeU32Le(
        output,
        8,
        format.flag_newline_detect |
            (if (compressed)
                format.flag_compressed | format.flag_embedded_lba
            else
                format.flag_zero_grain),
    );
    format.writeU64Le(output, 12, capacity_sectors);
    format.writeU64Le(output, 20, grain_sectors);
    format.writeU64Le(output, 28, 1);
    format.writeU64Le(output, 36, descriptor_sectors);
    format.writeU32Le(output, 44, gtes_per_gt);
    format.writeU64Le(
        output,
        56,
        if (kind == .stream_optimized_initial) format.gd_at_end else gd_offset,
    );
    format.writeU64Le(output, 64, overhead_sectors);
    @memcpy(output[73..77], "\n \r\n");
    format.writeU16Le(
        output,
        77,
        if (compressed) format.compression_deflate else format.compression_none,
    );
}

const DescriptorKind = enum { sparse, stream_optimized };

fn writeDescriptor(
    allocator: std.mem.Allocator,
    output: []u8,
    capacity_sectors: usize,
    kind: DescriptorKind,
) Error!void {
    const create_type = switch (kind) {
        .sparse => "monolithicSparse",
        .stream_optimized => "streamOptimized",
    };
    const descriptor = try std.fmt.allocPrint(
        allocator,
        "# Disk DescriptorFile\n" ++
            "version=1\n" ++
            "encoding=\"UTF-8\"\n" ++
            "CID=564f5254\n" ++
            "parentCID=ffffffff\n" ++
            "createType=\"{s}\"\n\n" ++
            "# Extent description\n" ++
            "RW {d} SPARSE \"disk.vmdk\"\n\n" ++
            "# The Disk Data Base\n" ++
            "#DDB\n\n" ++
            "ddb.adapterType = \"ide\"\n" ++
            "ddb.geometry.cylinders = \"0\"\n" ++
            "ddb.geometry.heads = \"16\"\n" ++
            "ddb.geometry.sectors = \"63\"\n",
        .{ create_type, capacity_sectors },
    );
    defer allocator.free(descriptor);
    if (descriptor.len > output.len) return error.OutputLimitExceeded;
    @memcpy(output[0..descriptor.len], descriptor);
}

fn makeGrain(
    allocator: std.mem.Allocator,
    input: []const u8,
    grain_index: usize,
    grain_size: usize,
) Error![]u8 {
    const grain = try allocator.alloc(u8, grain_size);
    errdefer allocator.free(grain);
    @memset(grain, 0);
    const start = std.math.mul(usize, grain_index, grain_size) catch
        return error.IntegerOverflow;
    if (start < input.len) {
        const grain_end = std.math.add(usize, start, grain_size) catch
            return error.IntegerOverflow;
        const end = @min(input.len, grain_end);
        @memcpy(grain[0 .. end - start], input[start..end]);
    }
    return grain;
}

fn appendMetadataMarker(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    kind: format.MarkerType,
    sectors: usize,
) Error!void {
    if (output.items.len % format.sector_size != 0) return error.InvalidVmdk;
    const start = output.items.len;
    try output.appendNTimes(allocator, 0, format.sector_size);
    format.writeU64Le(output.items, start, sectors);
    format.writeU32Le(output.items, start + 12, @intFromEnum(kind));
}

fn padToSector(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
) Error!void {
    const remainder = output.items.len % format.sector_size;
    if (remainder != 0)
        try output.appendNTimes(
            allocator,
            0,
            format.sector_size - remainder,
        );
}

fn writeU32AtSectorTable(
    output: []u8,
    sector: usize,
    index: usize,
    value: u32,
) void {
    format.writeU32Le(
        output,
        sector * format.sector_size + index * 4,
        value,
    );
}

fn tableSectors(entries: usize) Error!usize {
    const bytes = std.math.mul(usize, entries, 4) catch
        return error.IntegerOverflow;
    return std.math.divCeil(usize, bytes, format.sector_size) catch
        return error.IntegerOverflow;
}

fn alignForwardChecked(value: usize, alignment: usize) error{IntegerOverflow}!usize {
    const remainder = value % alignment;
    if (remainder == 0) return value;
    return std.math.add(usize, value, alignment - remainder) catch
        error.IntegerOverflow;
}

fn castU32(value: anytype) Error!u32 {
    return std.math.cast(u32, value) orelse error.OutputLimitExceeded;
}

fn isPowerOfTwo(value: anytype) bool {
    return value != 0 and value & (value - 1) == 0;
}

fn allZero(input: []const u8) bool {
    for (input) |byte| if (byte != 0) return false;
    return true;
}
