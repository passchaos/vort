const std = @import("std");
const archive_mod = @import("archive.zig");
const format = @import("format.zig");

pub const Error = archive_mod.Error || format.Error || std.mem.Allocator.Error;

pub const ImageType = enum {
    dynamic,
    fixed,
    differencing,
};

pub const EncodeOptions = struct {
    image_type: ImageType = .dynamic,
    block_size: u32 = 8 * format.mib,
    logical_sector_size: u32 = 512,
    physical_sector_size: u32 = 4096,
    /// Required for differencing output and ignored otherwise.
    parent: ?*const archive_mod.Archive = null,
    parent_path: []const u8 = "parent.vhdx",
    max_bat_entries: usize = 1 << 26,
};

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: EncodeOptions,
) Error![]u8 {
    try validateOptions(input, options);
    const virtual_size = std.mem.alignForward(
        usize,
        input.len,
        options.logical_sector_size,
    );
    const data_block_count = std.math.divCeil(
        usize,
        virtual_size,
        options.block_size,
    ) catch return error.IntegerOverflow;
    const chunk_ratio_u64 = format.maximum_sectors_per_block *
        options.logical_sector_size / options.block_size;
    const chunk_ratio: usize = @intCast(chunk_ratio_u64);
    const bitmap_block_count = std.math.divCeil(
        usize,
        data_block_count,
        chunk_ratio,
    ) catch return error.IntegerOverflow;
    const bat_entry_count = if (options.image_type == .differencing)
        std.math.mul(
            usize,
            bitmap_block_count,
            chunk_ratio + 1,
        ) catch return error.IntegerOverflow
    else if (data_block_count == 0)
        0
    else
        data_block_count + (data_block_count - 1) / chunk_ratio;
    if (bat_entry_count > options.max_bat_entries)
        return error.OutputLimitExceeded;
    const bat_bytes = std.math.mul(usize, bat_entry_count, 8) catch
        return error.IntegerOverflow;
    const bat_length = @max(format.mib, std.mem.alignForward(usize, bat_bytes, format.mib));
    if (bat_length > std.math.maxInt(u32)) return error.OutputLimitExceeded;
    const log_offset = format.header_section_size;
    const log_length = format.mib;
    const bat_offset = log_offset + log_length;
    const metadata_offset = std.math.add(usize, bat_offset, bat_length) catch
        return error.IntegerOverflow;
    const metadata_length = format.mib;
    const data_offset = metadata_offset + metadata_length;

    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    try output.appendNTimes(allocator, 0, data_offset);
    writeFileIdentifier(output.items[0 .. 64 * 1024]);
    const file_guid = makeGuid(input, options, 1);
    const data_guid = makeGuid(input, options, 2);
    writeHeader(
        output.items[format.header1_offset..][0..format.header_checksum_size],
        1,
        file_guid,
        data_guid,
        log_offset,
        log_length,
    );
    writeHeader(
        output.items[format.header2_offset..][0..format.header_checksum_size],
        2,
        file_guid,
        data_guid,
        log_offset,
        log_length,
    );
    var region_table = [_]u8{0} ** format.region_table_size;
    writeRegionTable(
        &region_table,
        bat_offset,
        bat_length,
        metadata_offset,
        metadata_length,
    );
    @memcpy(output.items[format.region1_offset..][0..format.region_table_size], &region_table);
    @memcpy(output.items[format.region2_offset..][0..format.region_table_size], &region_table);
    writeMetadata(
        output.items[metadata_offset..][0..metadata_length],
        virtual_size,
        options,
        makeGuid(input, options, 3),
    );

    if (options.image_type == .differencing) {
        try appendDifferencingBlocks(
            allocator,
            &output,
            input,
            virtual_size,
            data_block_count,
            chunk_ratio,
            bat_offset,
            options,
        );
    } else {
        const block = try allocator.alloc(u8, options.block_size);
        defer allocator.free(block);
        for (0..data_block_count) |block_index| {
            fillBlock(input, block_index, options.block_size, block);
            if (options.image_type == .dynamic and std.mem.allEqual(u8, block, 0))
                continue;
            try appendPayloadBlock(
                allocator,
                &output,
                block,
                bat_offset,
                block_index + block_index / chunk_ratio,
                .fully_present,
            );
        }
    }
    return output.toOwnedSlice(allocator);
}

fn validateOptions(input: []const u8, options: EncodeOptions) Error!void {
    if (options.block_size < format.mib or options.block_size > 256 * format.mib or
        options.block_size % format.mib != 0 or
        !std.math.isPowerOfTwo(options.block_size) or
        (options.logical_sector_size != 512 and options.logical_sector_size != 4096) or
        (options.physical_sector_size != 512 and options.physical_sector_size != 4096))
        return error.InvalidVhdx;
    const virtual_size = std.mem.alignForward(
        usize,
        input.len,
        options.logical_sector_size,
    );
    if (virtual_size > format.maximum_image_size)
        return error.OutputLimitExceeded;
    const chunk_ratio = format.maximum_sectors_per_block *
        options.logical_sector_size / options.block_size;
    if (chunk_ratio == 0 or !std.math.isPowerOfTwo(chunk_ratio))
        return error.InvalidVhdx;
    switch (options.image_type) {
        .dynamic, .fixed => if (options.parent != null) return error.InvalidVhdx,
        .differencing => {
            const parent = options.parent orelse return error.MissingVhdxParent;
            if (parent.metadata.virtual_disk_size != virtual_size or
                parent.metadata.logical_sector_size != options.logical_sector_size)
                return error.MissingVhdxParent;
            if (options.parent_path.len == 0 or options.parent_path.len > 4096)
                return error.InvalidVhdx;
            for (options.parent_path) |byte|
                if (byte == 0 or byte >= 0x80) return error.UnsupportedVhdxFeature;
        },
    }
}

fn appendDifferencingBlocks(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
    virtual_size: usize,
    data_block_count: usize,
    chunk_ratio: usize,
    bat_offset: usize,
    options: EncodeOptions,
) Error!void {
    const parent = options.parent.?;
    const block = try allocator.alloc(u8, options.block_size);
    defer allocator.free(block);
    const bitmap = try allocator.alloc(u8, format.mib);
    defer allocator.free(bitmap);
    const parent_sector = try allocator.alloc(u8, options.logical_sector_size);
    defer allocator.free(parent_sector);
    const sectors_per_block = options.block_size / options.logical_sector_size;
    const chunk_count = std.math.divCeil(
        usize,
        data_block_count,
        chunk_ratio,
    ) catch return error.IntegerOverflow;
    for (0..chunk_count) |chunk_index| {
        @memset(bitmap, 0);
        var has_partial = false;
        const first_block = chunk_index * chunk_ratio;
        const end_block = @min(data_block_count, first_block + chunk_ratio);
        for (first_block..end_block) |block_index| {
            fillBlock(input, block_index, options.block_size, block);
            const block_start = block_index * @as(usize, options.block_size);
            const logical_block_bytes = @min(
                @as(usize, options.block_size),
                virtual_size - block_start,
            );
            const sector_count = logical_block_bytes / options.logical_sector_size;
            var changed_sectors: usize = 0;
            for (0..sector_count) |sector| {
                const logical_offset = block_start + sector * options.logical_sector_size;
                try parent.readRangeInto(logical_offset, parent_sector);
                const child_sector = block[sector * options.logical_sector_size ..][0..options.logical_sector_size];
                if (!std.mem.eql(u8, child_sector, parent_sector)) {
                    setBitmapBit(
                        bitmap,
                        (block_index - first_block) * sectors_per_block + sector,
                    );
                    changed_sectors += 1;
                }
            }
            if (changed_sectors == 0) continue;
            const state: format.PayloadState = if (changed_sectors == sector_count)
                .fully_present
            else
                .partially_present;
            has_partial = has_partial or state == .partially_present;
            try appendPayloadBlock(
                allocator,
                output,
                block,
                bat_offset,
                archive_mod.payloadBatIndex(block_index, chunk_ratio),
                state,
            );
        }
        if (has_partial) {
            try appendPayloadBlock(
                allocator,
                output,
                bitmap,
                bat_offset,
                archive_mod.sectorBitmapBatIndex(chunk_index, chunk_ratio),
                .fully_present,
            );
        }
    }
}

fn appendPayloadBlock(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    block: []const u8,
    bat_offset: usize,
    bat_index: usize,
    state: format.PayloadState,
) Error!void {
    if (output.items.len % format.mib != 0) return error.InvalidVhdx;
    const file_offset: u64 = output.items.len;
    format.writeU64Le(
        output.items,
        bat_offset + bat_index * 8,
        file_offset | @intFromEnum(state),
    );
    try output.appendSlice(allocator, block);
}

fn setBitmapBit(bitmap: []u8, sector_index: usize) void {
    bitmap[sector_index / 8] |= @as(u8, 1) << @intCast(sector_index % 8);
}

fn writeFileIdentifier(output: []u8) void {
    @memset(output, 0);
    @memcpy(output[0..8], "vhdxfile");
    const creator = "Vort";
    for (creator, 0..) |byte, index| output[8 + index * 2] = byte;
}

fn writeHeader(
    output: []u8,
    sequence: u64,
    file_guid: format.Guid,
    data_guid: format.Guid,
    log_offset: usize,
    log_length: usize,
) void {
    @memset(output, 0);
    @memcpy(output[0..4], "head");
    format.writeU64Le(output, 8, sequence);
    @memcpy(output[16..32], &file_guid);
    @memcpy(output[32..48], &data_guid);
    format.writeU16Le(output, 64, 0);
    format.writeU16Le(output, 66, 1);
    format.writeU32Le(output, 68, @intCast(log_length));
    format.writeU64Le(output, 72, log_offset);
    format.writeU32Le(output, 4, format.crc32cZeroField(output, 4));
}

fn writeRegionTable(
    output: []u8,
    bat_offset: usize,
    bat_length: usize,
    metadata_offset: usize,
    metadata_length: usize,
) void {
    @memset(output, 0);
    @memcpy(output[0..4], "regi");
    format.writeU32Le(output, 8, 2);
    writeRegionEntry(
        output[16..48],
        format.bat_guid,
        bat_offset,
        bat_length,
    );
    writeRegionEntry(
        output[48..80],
        format.metadata_guid,
        metadata_offset,
        metadata_length,
    );
    format.writeU32Le(output, 4, format.crc32cZeroField(output, 4));
}

fn writeRegionEntry(
    output: []u8,
    id: format.Guid,
    offset: usize,
    length: usize,
) void {
    @memcpy(output[0..16], &id);
    format.writeU64Le(output, 16, offset);
    format.writeU32Le(output, 24, @intCast(length));
    format.writeU32Le(output, 28, 1);
}

fn writeMetadata(
    output: []u8,
    virtual_size: usize,
    options: EncodeOptions,
    page83_id: format.Guid,
) void {
    @memset(output, 0);
    @memcpy(output[0..8], "metadata");
    format.writeU16Le(
        output,
        10,
        if (options.image_type == .differencing) 6 else 5,
    );
    var item_offset: usize = format.metadata_table_area_size;
    writeMetadataEntry(output[32..64], format.file_parameters_guid, item_offset, 8, 4);
    format.writeU32Le(output, item_offset, options.block_size);
    format.writeU32Le(
        output,
        item_offset + 4,
        switch (options.image_type) {
            .dynamic => 0,
            .fixed => 1,
            .differencing => 2,
        },
    );
    item_offset += 8;
    writeMetadataEntry(output[64..96], format.virtual_disk_size_guid, item_offset, 8, 6);
    format.writeU64Le(output, item_offset, virtual_size);
    item_offset += 8;
    writeMetadataEntry(output[96..128], format.page83_guid, item_offset, 16, 6);
    @memcpy(output[item_offset..][0..16], &page83_id);
    item_offset += 16;
    writeMetadataEntry(output[128..160], format.logical_sector_size_guid, item_offset, 4, 6);
    format.writeU32Le(output, item_offset, options.logical_sector_size);
    item_offset += 4;
    writeMetadataEntry(output[160..192], format.physical_sector_size_guid, item_offset, 4, 6);
    format.writeU32Le(output, item_offset, options.physical_sector_size);
    item_offset += 4;
    if (options.image_type == .differencing) {
        const locator_length = writeParentLocator(
            output[item_offset..],
            options.parent.?.header.data_write_guid,
            options.parent_path,
        );
        writeMetadataEntry(
            output[192..224],
            format.parent_locator_guid,
            item_offset,
            locator_length,
            4,
        );
    }
}

fn writeMetadataEntry(
    output: []u8,
    id: format.Guid,
    offset: usize,
    length: usize,
    flags: u32,
) void {
    @memcpy(output[0..16], &id);
    format.writeU32Le(output, 16, @intCast(offset));
    format.writeU32Le(output, 20, @intCast(length));
    format.writeU32Le(output, 24, flags);
}

fn makeGuid(
    input: []const u8,
    options: EncodeOptions,
    salt: u8,
) format.Guid {
    var state = std.crypto.hash.sha2.Sha256.init(.{});
    state.update(input);
    state.update(&.{ salt, @intFromEnum(options.image_type) });
    if (options.parent) |parent| state.update(&parent.header.data_write_guid);
    var digest: [32]u8 = undefined;
    state.final(&digest);
    var result: format.Guid = digest[0..16].*;
    result[7] = (result[7] & 0x0f) | 0x40;
    result[8] = (result[8] & 0x3f) | 0x80;
    return result;
}

fn writeParentLocator(
    output: []u8,
    parent_guid: format.Guid,
    parent_path: []const u8,
) usize {
    const linkage_key = "parent_linkage";
    const path_key = "relative_path";
    var linkage_value: [38]u8 = undefined;
    formatGuidText(parent_guid, &linkage_value);
    const table_size: usize = 20 + 2 * 12;
    const linkage_key_offset = table_size;
    const linkage_value_offset = linkage_key_offset + linkage_key.len * 2;
    const path_key_offset = linkage_value_offset + linkage_value.len * 2;
    const path_value_offset = path_key_offset + path_key.len * 2;
    const total = path_value_offset + parent_path.len * 2;
    @memset(output[0..total], 0);
    @memcpy(output[0..16], &format.parent_vhdx_guid);
    format.writeU16Le(output, 18, 2);
    writeParentLocatorEntry(
        output[20..32],
        linkage_key_offset,
        linkage_value_offset,
        linkage_key.len * 2,
        linkage_value.len * 2,
    );
    writeParentLocatorEntry(
        output[32..44],
        path_key_offset,
        path_value_offset,
        path_key.len * 2,
        parent_path.len * 2,
    );
    writeUtf16Le(output[linkage_key_offset..], linkage_key);
    writeUtf16Le(output[linkage_value_offset..], &linkage_value);
    writeUtf16Le(output[path_key_offset..], path_key);
    writeUtf16Le(output[path_value_offset..], parent_path);
    return total;
}

fn writeParentLocatorEntry(
    output: []u8,
    key_offset: usize,
    value_offset: usize,
    key_length: usize,
    value_length: usize,
) void {
    format.writeU32Le(output, 0, @intCast(key_offset));
    format.writeU32Le(output, 4, @intCast(value_offset));
    format.writeU16Le(output, 8, @intCast(key_length));
    format.writeU16Le(output, 10, @intCast(value_length));
}

fn writeUtf16Le(output: []u8, input: []const u8) void {
    for (input, 0..) |byte, index| output[index * 2] = byte;
}

fn formatGuidText(raw: format.Guid, output: *[38]u8) void {
    const canonical = [_]u8{
        raw[3],  raw[2],  raw[1],  raw[0],
        raw[5],  raw[4],  raw[7],  raw[6],
        raw[8],  raw[9],  raw[10], raw[11],
        raw[12], raw[13], raw[14], raw[15],
    };
    output[0] = '{';
    output[37] = '}';
    var out_index: usize = 1;
    for (canonical, 0..) |byte, index| {
        if (index == 4 or index == 6 or index == 8 or index == 10) {
            output[out_index] = '-';
            out_index += 1;
        }
        output[out_index] = hexDigit(byte >> 4);
        output[out_index + 1] = hexDigit(byte & 0x0f);
        out_index += 2;
    }
}

fn hexDigit(value: u8) u8 {
    return if (value < 10) '0' + value else 'a' + value - 10;
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
