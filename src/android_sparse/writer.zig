const std = @import("std");
const checksum = @import("../checksum.zig");
const format = @import("format.zig");

pub const Error = format.Error || std.mem.Allocator.Error;

pub const EncodeOptions = struct {
    block_size: u32 = 4096,
    sparse_zero_blocks: bool = true,
    use_fill_chunks: bool = true,
    emit_crc32_chunk: bool = false,
    write_image_checksum: bool = false,
    max_chunks: usize = 1 << 24,
    max_block_size: usize = 64 * 1024 * 1024,
    max_output_len: usize = std.math.maxInt(usize),
};

const Plan = struct {
    kind: format.ChunkType,
    first_block: usize,
    block_count: usize,
    fill_value: u32 = 0,
};

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: EncodeOptions,
) Error![]u8 {
    const block_size: usize = options.block_size;
    if (block_size == 0 or block_size % 4 != 0 or
        input.len % block_size != 0)
        return error.InvalidAndroidSparse;
    if (block_size > options.max_block_size)
        return error.OutputLimitExceeded;
    const total_blocks = input.len / block_size;
    if (total_blocks > std.math.maxInt(u32))
        return error.OutputLimitExceeded;
    var plans: std.ArrayList(Plan) = .empty;
    defer plans.deinit(allocator);
    var block_index: usize = 0;
    while (block_index < total_blocks) {
        const block = input[block_index * block_size ..][0..block_size];
        const fill = blockFillValue(block);
        const kind = classifyBlock(fill, options);
        const fill_value = fill orelse 0;
        const max_plan_blocks = if (kind == .raw)
            maxRawBlocks(block_size)
        else
            std.math.maxInt(u32);
        var end = block_index + 1;
        while (end < total_blocks and end - block_index < max_plan_blocks) : (end += 1) {
            const next = input[end * block_size ..][0..block_size];
            const next_fill = blockFillValue(next);
            const next_kind = classifyBlock(next_fill, options);
            if (next_kind != kind or
                kind == .fill and next_fill.? != fill_value)
                break;
        }
        if (plans.items.len >= options.max_chunks or
            plans.items.len >= std.math.maxInt(u32))
            return error.OutputLimitExceeded;
        try plans.append(allocator, .{
            .kind = kind,
            .first_block = block_index,
            .block_count = end - block_index,
            .fill_value = fill_value,
        });
        block_index = end;
    }
    const total_chunks = std.math.add(
        usize,
        plans.items.len,
        @intFromBool(options.emit_crc32_chunk),
    ) catch return error.IntegerOverflow;
    if (total_chunks > options.max_chunks or total_chunks > std.math.maxInt(u32))
        return error.OutputLimitExceeded;
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    if (format.base_header_size > options.max_output_len)
        return error.OutputLimitExceeded;
    try output.appendNTimes(allocator, 0, format.base_header_size);
    for (plans.items) |plan| {
        const logical_size = plan.block_count * block_size;
        const payload_size: usize = switch (plan.kind) {
            .raw => logical_size,
            .fill => 4,
            .dont_care => 0,
            .crc32 => unreachable,
        };
        const total_size = std.math.add(
            usize,
            format.base_chunk_header_size,
            payload_size,
        ) catch return error.IntegerOverflow;
        if (plan.block_count > std.math.maxInt(u32) or
            total_size > std.math.maxInt(u32))
            return error.OutputLimitExceeded;
        try ensureOutputLimit(output.items.len, total_size, options.max_output_len);
        const header_offset = output.items.len;
        try output.appendNTimes(allocator, 0, format.base_chunk_header_size);
        format.writeU16Le(output.items, header_offset, @intFromEnum(plan.kind));
        format.writeU32Le(output.items, header_offset + 4, @intCast(plan.block_count));
        format.writeU32Le(output.items, header_offset + 8, @intCast(total_size));
        switch (plan.kind) {
            .raw => try output.appendSlice(
                allocator,
                input[plan.first_block * block_size ..][0..logical_size],
            ),
            .fill => {
                var value: [4]u8 = undefined;
                std.mem.writeInt(u32, &value, plan.fill_value, .little);
                try output.appendSlice(allocator, &value);
            },
            .dont_care => {},
            .crc32 => unreachable,
        }
    }
    const image_crc = if (options.emit_crc32_chunk or options.write_image_checksum)
        checksum.crc32(input)
    else
        0;
    if (options.emit_crc32_chunk) {
        try ensureOutputLimit(
            output.items.len,
            format.base_chunk_header_size + 4,
            options.max_output_len,
        );
        const header_offset = output.items.len;
        try output.appendNTimes(allocator, 0, format.base_chunk_header_size);
        format.writeU16Le(output.items, header_offset, @intFromEnum(format.ChunkType.crc32));
        format.writeU32Le(
            output.items,
            header_offset + 8,
            format.base_chunk_header_size + 4,
        );
        var crc_bytes: [4]u8 = undefined;
        std.mem.writeInt(u32, &crc_bytes, image_crc, .little);
        try output.appendSlice(allocator, &crc_bytes);
    }
    format.writeU32Le(output.items, 0, format.magic);
    format.writeU16Le(output.items, 4, format.major_version);
    format.writeU16Le(output.items, 6, 0);
    format.writeU16Le(output.items, 8, format.base_header_size);
    format.writeU16Le(output.items, 10, format.base_chunk_header_size);
    format.writeU32Le(output.items, 12, options.block_size);
    format.writeU32Le(output.items, 16, @intCast(total_blocks));
    format.writeU32Le(output.items, 20, @intCast(total_chunks));
    format.writeU32Le(
        output.items,
        24,
        if (options.write_image_checksum) image_crc else 0,
    );
    return output.toOwnedSlice(allocator);
}

fn classifyBlock(
    fill: ?u32,
    options: EncodeOptions,
) format.ChunkType {
    if (fill == 0 and options.sparse_zero_blocks) return .dont_care;
    if (fill != null and options.use_fill_chunks) return .fill;
    return .raw;
}

fn maxRawBlocks(block_size: usize) usize {
    return (std.math.maxInt(u32) - format.base_chunk_header_size) / block_size;
}

fn blockFillValue(block: []const u8) ?u32 {
    const value = std.mem.readInt(u32, block[0..4], .little);
    var offset: usize = 4;
    while (offset < block.len) : (offset += 4)
        if (std.mem.readInt(u32, block[offset..][0..4], .little) != value)
            return null;
    return value;
}

fn ensureOutputLimit(current: usize, additional: usize, limit: usize) Error!void {
    const end = std.math.add(usize, current, additional) catch
        return error.IntegerOverflow;
    if (end > limit) return error.OutputLimitExceeded;
}

test "Android sparse raw chunks stay within the 32-bit physical size field" {
    try std.testing.expectEqual(@as(usize, 1_048_575), maxRawBlocks(4096));
    try std.testing.expectEqual(@as(usize, 63), maxRawBlocks(64 * 1024 * 1024));
}
