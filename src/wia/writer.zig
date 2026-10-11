const std = @import("std");
const codec = @import("codec.zig");
const format = @import("format.zig");
const group_writer = @import("group_writer.zig");
const partition_writer = @import("partition_writer.zig");
const wii_disc = @import("wii_disc.zig");

pub const Error = format.Error || codec.Error || group_writer.Error ||
    partition_writer.Error || wii_disc.Error || std.mem.Allocator.Error;

pub const EncodeOptions = struct {
    container: format.Container = .rvz,
    compression: format.Compression = .zstd,
    compression_level: i32 = 5,
    chunk_size: u32 = 128 * 1024,
    disc_type: u32 = 0,
    max_groups: usize = 1 << 24,
    max_partitions: usize = 1 << 20,
    max_raw_entries: usize = 1 << 20,
    max_chunk_size: usize = 64 * 1024 * 1024,
};

pub const PartitionData = struct {
    /// Byte offset and length of encrypted 0x8000-byte Wii sectors in `input`.
    offset: u64,
    size: u64,
};

pub const Partition = struct {
    /// AES-128 title key used by the encrypted sectors.
    key: [16]u8,
    /// The optional second range must directly follow the first and start on a
    /// 2 MiB Wii hash-group boundary relative to it.
    data: [2]PartitionData,
};

const PartitionRange = struct {
    start: usize,
    end: usize,
    partition_index: usize,
    data_index: usize,
};

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: EncodeOptions,
) Error![]u8 {
    return encodeWithPartitionsAlloc(allocator, input, &.{}, options);
}

pub fn encodeDiscAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    common_keys: []const wii_disc.CommonKey,
    options: EncodeOptions,
) Error![]u8 {
    var layout = try wii_disc.discoverAlloc(
        allocator,
        input,
        common_keys,
        .{ .max_partitions = options.max_partitions },
    );
    defer layout.deinit();
    const partitions = try allocator.alloc(Partition, layout.partitions.len);
    defer {
        for (partitions) |*partition|
            std.crypto.secureZero(u8, &partition.key);
        allocator.free(partitions);
    }
    for (partitions, layout.partitions) |*destination, source| {
        destination.* = .{
            .key = source.title_key,
            .data = .{
                .{ .offset = source.data_offset, .size = source.data_size },
                .{ .offset = 0, .size = 0 },
            },
        };
    }
    return encodeWithPartitionsAlloc(allocator, input, partitions, options);
}

pub fn encodeWithPartitionsAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    partitions: []const Partition,
    options: EncodeOptions,
) Error![]u8 {
    if (input.len < format.disc_header_size or
        !format.validChunkSize(options.container, options.chunk_size) or
        options.chunk_size > options.max_chunk_size)
        return error.InvalidWia;
    if (options.container == .wia and options.compression == .zstd or
        options.container == .rvz and options.compression == .purge)
        return error.UnsupportedWiaCodec;
    switch (options.compression) {
        .bzip2, .lzma, .lzma2 => if (options.compression_level < 1 or
            options.compression_level > 9)
            return error.InvalidWia,
        .none, .purge, .zstd => {},
    }
    if (partitions.len > options.max_partitions or
        partitions.len > std.math.maxInt(u32))
        return error.OutputLimitExceeded;

    const partition_entries = try allocator.alloc(
        format.PartitionEntry,
        partitions.len,
    );
    defer allocator.free(partition_entries);
    var ranges: std.ArrayList(PartitionRange) = .empty;
    defer ranges.deinit(allocator);
    for (partitions, 0..) |partition, partition_index| {
        partition_entries[partition_index] = .{
            .key = partition.key,
            .data = @splat(.{
                .first_sector = 0,
                .sector_count = 0,
                .group_index = 0,
                .group_count = 0,
            }),
        };
        if (partition.data[0].size == 0) return error.InvalidWia;
        var previous_end: usize = 0;
        var partition_start: usize = 0;
        for (partition.data, 0..) |data, data_index| {
            if (data.size == 0) continue;
            const start = std.math.cast(usize, data.offset) orelse
                return error.IntegerOverflow;
            const size = std.math.cast(usize, data.size) orelse
                return error.IntegerOverflow;
            const end = std.math.add(usize, start, size) catch
                return error.IntegerOverflow;
            if (start < format.disc_header_size or end > input.len or
                start % format.wii_block_size != 0 or
                size % format.wii_block_size != 0)
                return error.InvalidWia;
            if (data_index == 0) {
                partition_start = start;
            } else if (start != previous_end or
                (start - partition_start) % format.wii_group_size != 0)
            {
                return error.InvalidWia;
            }
            const first_sector = start / format.wii_block_size;
            const sector_count = size / format.wii_block_size;
            if (first_sector > std.math.maxInt(u32) or
                sector_count > std.math.maxInt(u32))
                return error.OutputLimitExceeded;
            partition_entries[partition_index].data[data_index] = .{
                .first_sector = @intCast(first_sector),
                .sector_count = @intCast(sector_count),
                .group_index = 0,
                .group_count = 0,
            };
            try ranges.append(allocator, .{
                .start = start,
                .end = end,
                .partition_index = partition_index,
                .data_index = data_index,
            });
            previous_end = end;
        }
    }
    std.mem.sort(PartitionRange, ranges.items, {}, partitionRangeLessThan);
    var previous_end = format.disc_header_size;
    for (ranges.items) |range| {
        if (range.start < previous_end) return error.InvalidWia;
        previous_end = range.end;
    }

    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    try output.appendNTimes(
        allocator,
        0,
        format.header1_size + format.header2_size,
    );
    var groups: std.ArrayList(format.GroupEntry) = .empty;
    defer groups.deinit(allocator);
    var raw_entries: std.ArrayList(format.RawEntry) = .empty;
    defer raw_entries.deinit(allocator);
    const settings = group_writer.Settings{
        .container = options.container,
        .compression = options.compression,
        .compression_level = options.compression_level,
        .max_groups = options.max_groups,
    };
    var cursor = format.disc_header_size;
    for (ranges.items) |range| {
        if (range.start > cursor)
            try appendRawRange(
                allocator,
                &output,
                &groups,
                &raw_entries,
                input,
                cursor,
                range.start - cursor,
                options.chunk_size,
                options.max_raw_entries,
                settings,
            );
        const first_group = groups.items.len;
        try partition_writer.appendGroups(
            allocator,
            &output,
            &groups,
            input[range.start..range.end],
            &partitions[range.partition_index].key,
            options.chunk_size,
            settings,
        );
        const group_count = groups.items.len - first_group;
        partition_entries[range.partition_index].data[range.data_index].group_index =
            first_group;
        partition_entries[range.partition_index].data[range.data_index].group_count =
            group_count;
        cursor = range.end;
    }
    if (cursor < input.len)
        try appendRawRange(
            allocator,
            &output,
            &groups,
            &raw_entries,
            input,
            cursor,
            input.len - cursor,
            options.chunk_size,
            options.max_raw_entries,
            settings,
        );

    const partition_table = try serializePartitionsAlloc(
        allocator,
        partition_entries,
    );
    defer allocator.free(partition_table);
    const raw_table = try serializeRawEntriesAlloc(allocator, raw_entries.items);
    defer allocator.free(raw_table);
    const group_entry_size = options.container.groupEntrySize();
    const group_table_size = std.math.mul(
        usize,
        groups.items.len,
        group_entry_size,
    ) catch return error.IntegerOverflow;
    const group_table = try allocator.alloc(u8, group_table_size);
    defer allocator.free(group_table);
    @memset(group_table, 0);
    for (groups.items, 0..) |group, index| {
        const offset = index * group_entry_size;
        if (group.data_offset / 4 > std.math.maxInt(u32) or
            group.stored_size > 0x7fff_ffff)
            return error.OutputLimitExceeded;
        format.writeU32Be(
            group_table,
            offset,
            @intCast(group.data_offset / 4),
        );
        const size_field: u32 = @intCast(group.stored_size);
        format.writeU32Be(
            group_table,
            offset + 4,
            if (options.container == .rvz and group.compressed)
                size_field | 0x8000_0000
            else
                size_field,
        );
        if (options.container == .rvz)
            format.writeU32Be(
                group_table,
                offset + 8,
                @intCast(group.rvz_packed_size),
            );
    }

    const raw_encoded = try codec.encodeAlloc(
        allocator,
        raw_table,
        options.compression,
        options.compression_level,
    );
    defer allocator.free(raw_encoded);
    const groups_encoded = try codec.encodeAlloc(
        allocator,
        group_table,
        options.compression,
        options.compression_level,
    );
    defer allocator.free(groups_encoded);
    try appendAlignment(allocator, &output, 4);
    const partition_offset = if (partition_table.len == 0)
        format.header1_size + format.header2_size
    else
        output.items.len;
    try output.appendSlice(allocator, partition_table);
    try appendAlignment(allocator, &output, 4);
    const raw_offset = output.items.len;
    try output.appendSlice(allocator, raw_encoded);
    try appendAlignment(allocator, &output, 4);
    const groups_offset = output.items.len;
    try output.appendSlice(allocator, groups_encoded);
    try appendAlignment(allocator, &output, 4);

    if (raw_encoded.len > std.math.maxInt(u32) or
        groups_encoded.len > std.math.maxInt(u32))
        return error.OutputLimitExceeded;
    writeHeaders(
        output.items,
        input,
        options,
        partition_entries.len,
        partition_offset,
        partition_table,
        raw_entries.items.len,
        groups.items.len,
        raw_offset,
        raw_encoded.len,
        groups_offset,
        groups_encoded.len,
    );
    return output.toOwnedSlice(allocator);
}

fn writeHeaders(
    output: []u8,
    input: []const u8,
    options: EncodeOptions,
    partition_count: usize,
    partition_offset: usize,
    partition_table: []const u8,
    raw_count: usize,
    group_count: usize,
    raw_offset: usize,
    raw_size: usize,
    groups_offset: usize,
    groups_size: usize,
) void {
    const header2 = output[format.header1_size..][0..format.header2_size];
    @memset(output[0 .. format.header1_size + format.header2_size], 0);
    format.writeU32Be(header2, 0, options.disc_type);
    format.writeU32Be(header2, 4, @intFromEnum(options.compression));
    format.writeU32Be(header2, 8, @bitCast(options.compression_level));
    format.writeU32Be(header2, 12, options.chunk_size);
    @memcpy(header2[16..144], input[0..format.disc_header_size]);
    format.writeU32Be(header2, 144, @intCast(partition_count));
    format.writeU32Be(header2, 148, format.partition_entry_size);
    format.writeU64Be(header2, 152, partition_offset);
    var partition_hash: [20]u8 = undefined;
    std.crypto.hash.Sha1.hash(partition_table, &partition_hash, .{});
    @memcpy(header2[160..180], &partition_hash);
    format.writeU32Be(header2, 180, @intCast(raw_count));
    format.writeU64Be(header2, 184, raw_offset);
    format.writeU32Be(header2, 192, @intCast(raw_size));
    format.writeU32Be(header2, 196, @intCast(group_count));
    format.writeU64Be(header2, 200, groups_offset);
    format.writeU32Be(header2, 208, @intCast(groups_size));
    const codec_metadata = codec.metadata(options.compression);
    header2[212] = codec_metadata.len;
    @memcpy(header2[213..220], &codec_metadata.bytes);

    var header2_hash: [20]u8 = undefined;
    std.crypto.hash.Sha1.hash(header2, &header2_hash, .{});
    const header1 = output[0..format.header1_size];
    format.writeU32Le(header1, 0, options.container.magic());
    format.writeU32Be(header1, 4, format.current_version);
    format.writeU32Be(
        header1,
        8,
        if (options.container == .wia)
            format.current_version
        else
            format.rvz_write_compatible,
    );
    format.writeU32Be(header1, 12, format.header2_size);
    @memcpy(header1[16..36], &header2_hash);
    format.writeU64Be(header1, 36, input.len);
    format.writeU64Be(header1, 44, output.len);
    var header1_hash: [20]u8 = undefined;
    std.crypto.hash.Sha1.hash(header1[0..52], &header1_hash, .{});
    @memcpy(header1[52..72], &header1_hash);
}

fn appendRawRange(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    groups: *std.ArrayList(format.GroupEntry),
    raw_entries: *std.ArrayList(format.RawEntry),
    input: []const u8,
    start: usize,
    size: usize,
    chunk_size: usize,
    max_raw_entries: usize,
    settings: group_writer.Settings,
) Error!void {
    if (size == 0) return;
    if (raw_entries.items.len >= max_raw_entries or
        raw_entries.items.len >= std.math.maxInt(u32))
        return error.OutputLimitExceeded;
    const skipped = start % format.wii_block_size;
    const adjusted_start = start - skipped;
    const adjusted_size = std.math.add(usize, size, skipped) catch
        return error.IntegerOverflow;
    const adjusted_end = std.math.add(
        usize,
        adjusted_start,
        adjusted_size,
    ) catch return error.IntegerOverflow;
    if (adjusted_end > input.len) return error.InvalidWia;
    const first_group = groups.items.len;
    var offset: usize = 0;
    while (offset < adjusted_size) {
        const end = offset + @min(chunk_size, adjusted_size - offset);
        try group_writer.appendRaw(
            allocator,
            output,
            groups,
            input[adjusted_start + offset .. adjusted_start + end],
            settings,
        );
        offset = end;
    }
    try raw_entries.append(allocator, .{
        .data_offset = start,
        .data_size = size,
        .group_index = first_group,
        .group_count = groups.items.len - first_group,
    });
}

fn serializePartitionsAlloc(
    allocator: std.mem.Allocator,
    partitions: []const format.PartitionEntry,
) Error![]u8 {
    const size = std.math.mul(
        usize,
        partitions.len,
        format.partition_entry_size,
    ) catch return error.IntegerOverflow;
    const output = try allocator.alloc(u8, size);
    @memset(output, 0);
    for (partitions, 0..) |partition, index| {
        const offset = index * format.partition_entry_size;
        @memcpy(output[offset..][0..16], &partition.key);
        for (partition.data, 0..) |data, data_index| {
            const data_offset = offset + 16 + data_index * 16;
            format.writeU32Be(output, data_offset, data.first_sector);
            format.writeU32Be(output, data_offset + 4, data.sector_count);
            format.writeU32Be(
                output,
                data_offset + 8,
                @intCast(data.group_index),
            );
            format.writeU32Be(
                output,
                data_offset + 12,
                @intCast(data.group_count),
            );
        }
    }
    return output;
}

fn serializeRawEntriesAlloc(
    allocator: std.mem.Allocator,
    entries: []const format.RawEntry,
) Error![]u8 {
    const size = std.math.mul(
        usize,
        entries.len,
        format.raw_entry_size,
    ) catch return error.IntegerOverflow;
    const output = try allocator.alloc(u8, size);
    @memset(output, 0);
    for (entries, 0..) |entry, index| {
        const offset = index * format.raw_entry_size;
        format.writeU64Be(output, offset, entry.data_offset);
        format.writeU64Be(output, offset + 8, entry.data_size);
        format.writeU32Be(output, offset + 16, @intCast(entry.group_index));
        format.writeU32Be(output, offset + 20, @intCast(entry.group_count));
    }
    return output;
}

fn partitionRangeLessThan(_: void, lhs: PartitionRange, rhs: PartitionRange) bool {
    return lhs.start < rhs.start;
}

fn appendAlignment(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    alignment: usize,
) Error!void {
    const remainder = output.items.len % alignment;
    if (remainder != 0)
        try output.appendNTimes(allocator, 0, alignment - remainder);
}
