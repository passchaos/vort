const std = @import("std");

pub const Error = std.mem.Allocator.Error || error{
    InvalidWiiDisc,
    UnsupportedWiiDisc,
    MissingWiiCommonKey,
    OutputLimitExceeded,
    IntegerOverflow,
    TruncatedFrame,
};

pub const wii_magic: u32 = 0x5d1c9ea3;
pub const partition_groups_offset: usize = 0x40000;
pub const partition_group_count: usize = 4;
pub const ticket_size: usize = 0x2a4;
pub const ticket_title_key_offset: usize = 0x1bf;
pub const ticket_title_id_offset: usize = 0x1dc;
pub const ticket_common_key_index_offset: usize = 0x1f1;
pub const partition_data_offset_field: usize = 0x2b8;
pub const partition_data_size_field: usize = 0x2bc;
pub const wii_block_size: usize = 0x8000;

pub const CommonKey = struct {
    index: u8,
    key: [16]u8,
};

pub const Partition = struct {
    partition_offset: u64,
    partition_type: u32,
    title_id: u64,
    common_key_index: u8,
    title_key: [16]u8,
    data_offset: u64,
    data_size: u64,
};

pub const DiscoverOptions = struct {
    max_partitions: usize = 1024,
};

pub const Layout = struct {
    allocator: std.mem.Allocator,
    partitions: []Partition,

    pub fn deinit(self: *Layout) void {
        for (self.partitions) |*partition|
            std.crypto.secureZero(u8, &partition.title_key);
        self.allocator.free(self.partitions);
        self.* = undefined;
    }
};

pub fn discoverAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    common_keys: []const CommonKey,
    options: DiscoverOptions,
) Error!Layout {
    if (input.len < partition_groups_offset + partition_group_count * 8)
        return error.TruncatedFrame;
    if (readU32Be(input, 0x18) != wii_magic) return error.InvalidWiiDisc;
    if (input[0x60] != 0 or input[0x61] != 0)
        return error.UnsupportedWiiDisc;

    var partitions: std.ArrayList(Partition) = .empty;
    errdefer {
        for (partitions.items) |*partition|
            std.crypto.secureZero(u8, &partition.title_key);
        partitions.deinit(allocator);
    }
    for (0..partition_group_count) |group_index| {
        const descriptor = partition_groups_offset + group_index * 8;
        const count: usize = readU32Be(input, descriptor);
        if (count > options.max_partitions -| partitions.items.len)
            return error.OutputLimitExceeded;
        if (count == 0) continue;
        const table_offset = try shiftedOffset(readU32Be(input, descriptor + 4));
        const table_size = std.math.mul(usize, count, 8) catch
            return error.IntegerOverflow;
        try validateExtent(input.len, table_offset, table_size);
        for (0..count) |partition_index| {
            const entry_offset = table_offset + partition_index * 8;
            const partition_offset = try shiftedOffset(
                readU32Be(input, entry_offset),
            );
            const partition_type = readU32Be(input, entry_offset + 4);
            try validateExtent(
                input.len,
                partition_offset,
                partition_data_size_field + 4,
            );
            if (readU32Be(input, partition_offset) != 0x0001_0001)
                return error.InvalidWiiDisc;

            const data_relative = try shiftedOffset(readU32Be(
                input,
                partition_offset + partition_data_offset_field,
            ));
            const data_size = try shiftedSize(readU32Be(
                input,
                partition_offset + partition_data_size_field,
            ));
            const data_offset = std.math.add(
                usize,
                partition_offset,
                data_relative,
            ) catch return error.IntegerOverflow;
            if (data_size < wii_block_size or
                data_offset % wii_block_size != 0 or
                data_size % wii_block_size != 0)
                return error.InvalidWiiDisc;
            try validateExtent(input.len, data_offset, data_size);

            const common_key_index = input[
                partition_offset + ticket_common_key_index_offset
            ];
            const common_key = findCommonKey(
                common_keys,
                common_key_index,
            ) orelse return error.MissingWiiCommonKey;
            var encrypted_title_key: [16]u8 = undefined;
            @memcpy(
                &encrypted_title_key,
                input[partition_offset + ticket_title_key_offset ..][0..16],
            );
            var title_id_bytes: [8]u8 = undefined;
            @memcpy(
                &title_id_bytes,
                input[partition_offset + ticket_title_id_offset ..][0..8],
            );
            try partitions.append(allocator, .{
                .partition_offset = partition_offset,
                .partition_type = partition_type,
                .title_id = std.mem.readInt(u64, &title_id_bytes, .big),
                .common_key_index = common_key_index,
                .title_key = decryptTitleKey(
                    &encrypted_title_key,
                    &title_id_bytes,
                    &common_key.key,
                ),
                .data_offset = data_offset,
                .data_size = data_size,
            });
        }
    }
    if (partitions.items.len == 0) return error.InvalidWiiDisc;
    std.mem.sort(Partition, partitions.items, {}, partitionLessThan);
    var previous_end: u64 = 0;
    for (partitions.items) |partition| {
        if (partition.data_offset < previous_end) return error.InvalidWiiDisc;
        previous_end = std.math.add(
            u64,
            partition.data_offset,
            partition.data_size,
        ) catch return error.IntegerOverflow;
    }
    return .{
        .allocator = allocator,
        .partitions = try partitions.toOwnedSlice(allocator),
    };
}

fn findCommonKey(keys: []const CommonKey, index: u8) ?*const CommonKey {
    for (keys) |*key|
        if (key.index == index) return key;
    return null;
}

fn decryptTitleKey(
    encrypted: *const [16]u8,
    title_id: *const [8]u8,
    common_key: *const [16]u8,
) [16]u8 {
    var context = std.crypto.core.aes.Aes128.initDec(common_key.*);
    defer std.crypto.secureZero(@TypeOf(context), (&context)[0..1]);
    var output: [16]u8 = undefined;
    context.decrypt(&output, encrypted);
    for (output[0..8], title_id.*) |*byte, iv_byte| byte.* ^= iv_byte;
    return output;
}

fn shiftedOffset(value: u32) Error!usize {
    return std.math.cast(usize, @as(u64, value) << 2) orelse
        error.IntegerOverflow;
}

fn shiftedSize(value: u32) Error!usize {
    return shiftedOffset(value);
}

fn validateExtent(total: usize, offset: usize, size: usize) Error!void {
    const end = std.math.add(usize, offset, size) catch
        return error.IntegerOverflow;
    if (end > total) return error.TruncatedFrame;
}

fn readU32Be(input: []const u8, offset: usize) u32 {
    return std.mem.readInt(u32, input[offset..][0..4], .big);
}

fn partitionLessThan(_: void, lhs: Partition, rhs: Partition) bool {
    return lhs.data_offset < rhs.data_offset;
}
