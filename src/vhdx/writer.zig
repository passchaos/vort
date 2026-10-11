const std = @import("std");
const format = @import("format.zig");

pub const Error = format.Error || std.mem.Allocator.Error;

pub const ImageType = enum {
    dynamic,
    fixed,
};

pub const EncodeOptions = struct {
    image_type: ImageType = .dynamic,
    block_size: u32 = 8 * format.mib,
    logical_sector_size: u32 = 512,
    physical_sector_size: u32 = 4096,
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
    const bat_entry_count = if (data_block_count == 0)
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

    const block = try allocator.alloc(u8, options.block_size);
    defer allocator.free(block);
    for (0..data_block_count) |block_index| {
        fillBlock(input, block_index, options.block_size, block);
        if (options.image_type == .dynamic and std.mem.allEqual(u8, block, 0))
            continue;
        if (output.items.len % format.mib != 0) return error.InvalidVhdx;
        const file_offset: u64 = output.items.len;
        const bat_index = block_index + block_index / chunk_ratio;
        format.writeU64Le(
            output.items,
            bat_offset + bat_index * 8,
            file_offset | @intFromEnum(format.PayloadState.fully_present),
        );
        try output.appendSlice(allocator, block);
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
    format.writeU16Le(output, 10, 5);
    var item_offset: usize = format.metadata_table_area_size;
    writeMetadataEntry(output[32..64], format.file_parameters_guid, item_offset, 8, 4);
    format.writeU32Le(output, item_offset, options.block_size);
    format.writeU32Le(
        output,
        item_offset + 4,
        if (options.image_type == .fixed) 1 else 0,
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
    var digest: [32]u8 = undefined;
    state.final(&digest);
    var result: format.Guid = digest[0..16].*;
    result[7] = (result[7] & 0x0f) | 0x40;
    result[8] = (result[8] & 0x3f) | 0x80;
    return result;
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
