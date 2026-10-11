const std = @import("std");
const checksum = @import("../checksum.zig");
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
    compression_level: u8 = 9,
    block_size: u32 = 128 * 1024,
    sub_type: u32 = 0,
    minimum_savings: u32 = 10,
    max_blocks: usize = 1 << 24,
    max_block_size: usize = 64 * 1024 * 1024,
};

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: EncodeOptions,
) Error![]u8 {
    if (input.len == 0) return error.InvalidGcz;
    if (options.block_size < 512 or
        !std.math.isPowerOfTwo(options.block_size) or
        options.compression_level == 0 or options.compression_level > 9 or
        options.minimum_savings > options.block_size)
        return error.InvalidGcz;
    if (options.block_size > options.max_block_size)
        return error.OutputLimitExceeded;
    const block_count = std.math.divCeil(
        usize,
        input.len,
        options.block_size,
    ) catch return error.IntegerOverflow;
    if (block_count > options.max_blocks or block_count > std.math.maxInt(u32))
        return error.OutputLimitExceeded;
    const pointers_bytes = std.math.mul(
        usize,
        block_count,
        format.pointer_entry_size,
    ) catch return error.IntegerOverflow;
    const hashes_bytes = std.math.mul(
        usize,
        block_count,
        format.hash_entry_size,
    ) catch return error.IntegerOverflow;
    const hashes_offset = std.math.add(
        usize,
        format.header_size,
        pointers_bytes,
    ) catch return error.IntegerOverflow;
    const data_offset = std.math.add(
        usize,
        hashes_offset,
        hashes_bytes,
    ) catch return error.IntegerOverflow;

    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    try output.appendNTimes(allocator, 0, data_offset);
    const padded = try allocator.alloc(u8, options.block_size);
    defer allocator.free(padded);
    for (0..block_count) |block_index| {
        const source_start = block_index * @as(usize, options.block_size);
        const source_len = @min(
            input.len - source_start,
            @as(usize, options.block_size),
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
        const compressed_cost = if (compressed) |bytes|
            std.math.add(
                usize,
                bytes.len,
                options.minimum_savings,
            ) catch return error.IntegerOverflow
        else
            0;
        const raw = options.compression == .raw or
            (options.compression == .auto and compressed_cost > padded.len);
        const selected: []const u8 = if (raw) padded else compressed.?;
        const maximum_stored = std.math.add(
            usize,
            options.block_size,
            64,
        ) catch return error.IntegerOverflow;
        if (selected.len > maximum_stored) return error.OutputLimitExceeded;
        const relative_offset = output.items.len - data_offset;
        if (relative_offset > format.offset_mask)
            return error.OutputLimitExceeded;
        format.writeU64Le(
            output.items,
            format.header_size + block_index * format.pointer_entry_size,
            @as(u64, relative_offset) | if (raw) format.raw_flag else 0,
        );
        format.writeU32Le(
            output.items,
            hashes_offset + block_index * format.hash_entry_size,
            checksum.adler32(selected),
        );
        try output.appendSlice(allocator, selected);
    }
    const compressed_data_size = output.items.len - data_offset;
    if (compressed_data_size > format.offset_mask)
        return error.OutputLimitExceeded;
    format.writeU32Le(output.items, 0, format.magic);
    format.writeU32Le(output.items, 4, options.sub_type);
    format.writeU64Le(output.items, 8, compressed_data_size);
    format.writeU64Le(output.items, 16, input.len);
    format.writeU32Le(output.items, 24, options.block_size);
    format.writeU32Le(output.items, 28, @intCast(block_count));
    return output.toOwnedSlice(allocator);
}
