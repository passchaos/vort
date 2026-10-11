const std = @import("std");
const codec = @import("codec.zig");
const format = @import("format.zig");

pub const Error = format.Error || codec.Error || std.mem.Allocator.Error;

pub const EncodeOptions = struct {
    container: format.Container = .rvz,
    compression: format.Compression = .zstd,
    compression_level: i32 = 5,
    chunk_size: u32 = 128 * 1024,
    disc_type: u32 = 0,
    max_groups: usize = 1 << 24,
    max_chunk_size: usize = 64 * 1024 * 1024,
};

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
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
    const data_size = input.len - format.disc_header_size;
    const raw_count: usize = if (data_size == 0) 0 else 1;
    const group_count = if (data_size == 0)
        0
    else
        std.math.divCeil(usize, input.len, options.chunk_size) catch
            return error.IntegerOverflow;
    if (group_count > options.max_groups or group_count > std.math.maxInt(u32))
        return error.OutputLimitExceeded;

    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    try output.appendNTimes(
        allocator,
        0,
        format.header1_size + format.header2_size,
    );
    const groups = try allocator.alloc(format.GroupEntry, group_count);
    defer allocator.free(groups);
    for (groups, 0..) |*group, group_index| {
        const start = group_index * @as(usize, options.chunk_size);
        const plain = input[start..@min(input.len, start + options.chunk_size)];
        if (std.mem.allEqual(u8, plain, 0)) {
            group.* = .{
                .data_offset = 0,
                .stored_size = 0,
                .compressed = options.container == .wia,
                .rvz_packed_size = 0,
            };
            continue;
        }
        const encoded = try codec.encodeAlloc(
            allocator,
            plain,
            options.compression,
            options.compression_level,
        );
        defer allocator.free(encoded);
        const use_compressed = options.container == .wia or
            options.compression == .none or encoded.len < plain.len;
        const selected = if (use_compressed) encoded else plain;
        try appendAlignment(allocator, &output, 4);
        if (output.items.len / 4 > std.math.maxInt(u32))
            return error.OutputLimitExceeded;
        group.* = .{
            .data_offset = output.items.len,
            .stored_size = selected.len,
            .compressed = use_compressed and options.compression != .none,
            .rvz_packed_size = 0,
        };
        try output.appendSlice(allocator, selected);
    }

    var raw_table: [format.raw_entry_size]u8 = @splat(0);
    if (raw_count != 0) {
        format.writeU64Be(&raw_table, 0, format.disc_header_size);
        format.writeU64Be(&raw_table, 8, data_size);
        format.writeU32Be(&raw_table, 16, 0);
        format.writeU32Be(&raw_table, 20, @intCast(group_count));
    }
    const group_entry_size = options.container.groupEntrySize();
    const group_table_size = std.math.mul(
        usize,
        group_count,
        group_entry_size,
    ) catch return error.IntegerOverflow;
    const group_table = try allocator.alloc(u8, group_table_size);
    defer allocator.free(group_table);
    @memset(group_table, 0);
    for (groups, 0..) |group, index| {
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
        raw_table[0 .. raw_count * format.raw_entry_size],
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
        raw_count,
        group_count,
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
    format.writeU32Be(header2, 144, 0);
    format.writeU32Be(header2, 148, format.partition_entry_size);
    format.writeU64Be(
        header2,
        152,
        format.header1_size + format.header2_size,
    );
    var empty_hash: [20]u8 = undefined;
    std.crypto.hash.Sha1.hash("", &empty_hash, .{});
    @memcpy(header2[160..180], &empty_hash);
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

fn appendAlignment(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    alignment: usize,
) Error!void {
    const remainder = output.items.len % alignment;
    if (remainder != 0)
        try output.appendNTimes(allocator, 0, alignment - remainder);
}
