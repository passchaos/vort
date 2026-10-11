const std = @import("std");
const format = @import("format.zig");
const group_writer = @import("group_writer.zig");
const wii = @import("wii_partition.zig");

pub const Error = format.Error || group_writer.Error || wii.Error ||
    std.mem.Allocator.Error;

pub fn appendGroups(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    groups: *std.ArrayList(format.GroupEntry),
    encrypted: []const u8,
    key: *const [16]u8,
    chunk_size: usize,
    settings: group_writer.Settings,
) Error!void {
    if (encrypted.len == 0 or encrypted.len % format.wii_block_size != 0 or
        chunk_size < format.wii_block_size or
        chunk_size % format.wii_block_size != 0)
        return error.InvalidWia;
    if (chunk_size >= format.wii_group_size)
        return appendLargeChunks(
            allocator,
            output,
            groups,
            encrypted,
            key,
            chunk_size,
            settings,
        );
    return appendSmallChunks(
        allocator,
        output,
        groups,
        encrypted,
        key,
        chunk_size,
        settings,
    );
}

fn appendLargeChunks(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    groups: *std.ArrayList(format.GroupEntry),
    encrypted: []const u8,
    key: *const [16]u8,
    chunk_size: usize,
    settings: group_writer.Settings,
) Error!void {
    const lists_per_chunk = chunk_size / format.wii_group_size;
    var chunk_offset: usize = 0;
    while (chunk_offset < encrypted.len) {
        const chunk_end = chunk_offset + @min(
            chunk_size,
            encrypted.len - chunk_offset,
        );
        var exception_lists: std.ArrayList(u8) = .empty;
        defer exception_lists.deinit(allocator);
        var main_data: std.ArrayList(u8) = .empty;
        defer main_data.deinit(allocator);

        for (0..lists_per_chunk) |list_index| {
            const relative_group_offset = list_index * format.wii_group_size;
            if (relative_group_offset >= chunk_end - chunk_offset) {
                try appendExceptionList(
                    allocator,
                    &exception_lists,
                    &.{},
                    0,
                    0,
                );
                continue;
            }
            const group_offset = chunk_offset + relative_group_offset;
            const group_end = group_offset + @min(
                format.wii_group_size,
                chunk_end - group_offset,
            );
            var extracted = try wii.extractEncryptedGroupAlloc(
                allocator,
                encrypted[group_offset..group_end],
                key,
            );
            defer extracted.deinit();
            try appendExceptionList(
                allocator,
                &exception_lists,
                extracted.exceptions,
                0,
                wii.blocks_per_group,
            );
            try main_data.appendSlice(allocator, extracted.data);
        }
        try group_writer.appendPartition(
            allocator,
            output,
            groups,
            exception_lists.items,
            main_data.items,
            settings,
        );
        chunk_offset = chunk_end;
    }
}

fn appendSmallChunks(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    groups: *std.ArrayList(format.GroupEntry),
    encrypted: []const u8,
    key: *const [16]u8,
    chunk_size: usize,
    settings: group_writer.Settings,
) Error!void {
    const blocks_per_chunk = chunk_size / format.wii_block_size;
    var group_offset: usize = 0;
    while (group_offset < encrypted.len) {
        const group_end = group_offset + @min(
            format.wii_group_size,
            encrypted.len - group_offset,
        );
        var extracted = try wii.extractEncryptedGroupAlloc(
            allocator,
            encrypted[group_offset..group_end],
            key,
        );
        defer extracted.deinit();
        const block_count = (group_end - group_offset) / format.wii_block_size;
        var first_block: usize = 0;
        while (first_block < block_count) : (first_block += blocks_per_chunk) {
            const chunk_blocks = @min(blocks_per_chunk, block_count - first_block);
            var exception_list: std.ArrayList(u8) = .empty;
            defer exception_list.deinit(allocator);
            try appendExceptionList(
                allocator,
                &exception_list,
                extracted.exceptions,
                first_block,
                chunk_blocks,
            );
            const data_offset = first_block * wii.block_data_size;
            const data_len = chunk_blocks * wii.block_data_size;
            try group_writer.appendPartition(
                allocator,
                output,
                groups,
                exception_list.items,
                extracted.data[data_offset..][0..data_len],
                settings,
            );
        }
        group_offset = group_end;
    }
}

fn appendExceptionList(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    exceptions: []const format.HashException,
    first_block: usize,
    block_count: usize,
) Error!void {
    const start = first_block * wii.block_header_size;
    const end = start + block_count * wii.block_header_size;
    var count: usize = 0;
    for (exceptions) |exception| {
        if (exception.offset >= start and exception.offset < end) {
            count += 1;
        }
    }
    if (count > std.math.maxInt(u16)) return error.OutputLimitExceeded;
    var count_bytes: [2]u8 = undefined;
    std.mem.writeInt(u16, &count_bytes, @intCast(count), .big);
    try output.appendSlice(allocator, &count_bytes);
    for (exceptions) |exception| {
        if (exception.offset < start or exception.offset >= end) continue;
        const local_offset = exception.offset - start;
        var offset_bytes: [2]u8 = undefined;
        std.mem.writeInt(u16, &offset_bytes, @intCast(local_offset), .big);
        try output.appendSlice(allocator, &offset_bytes);
        try output.appendSlice(allocator, &exception.hash);
    }
}
