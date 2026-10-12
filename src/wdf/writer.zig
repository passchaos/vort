const std = @import("std");
const format = @import("format.zig");

pub const Error = format.Error || std.mem.Allocator.Error;

pub const EncodeOptions = struct {
    version: format.Version = .v2,
    sparse_zeroes: bool = true,
    min_hole_size: usize = 28,
    max_chunks: usize = 1 << 24,
    max_output_len: usize = std.math.maxInt(usize),
};

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: EncodeOptions,
) Error![]u8 {
    const padded_unaligned = std.math.add(usize, input.len, 3) catch
        return error.IntegerOverflow;
    const padded_size = padded_unaligned & ~@as(usize, 3);
    var chunks: std.ArrayList(format.Chunk) = .empty;
    defer chunks.deinit(allocator);
    if (!options.sparse_zeroes) {
        if (padded_size != 0)
            try appendChunk(allocator, &chunks, 0, padded_size, options.max_chunks);
    } else {
        const aligned_hole_size = std.math.add(
            usize,
            options.min_hole_size,
            3,
        ) catch return error.IntegerOverflow;
        const min_hole_size = @max(
            @as(usize, 4),
            aligned_hole_size & ~@as(usize, 3),
        );
        var chunk_start: usize = 0;
        var position: usize = 0;
        while (position < padded_size) {
            if (!zeroWord(input, position)) {
                position += 4;
                continue;
            }
            const zero_start = position;
            while (position < padded_size and zeroWord(input, position))
                position += 4;
            if (position - zero_start >= min_hole_size) {
                if (zero_start > chunk_start)
                    try appendChunk(
                        allocator,
                        &chunks,
                        chunk_start,
                        zero_start - chunk_start,
                        options.max_chunks,
                    );
                chunk_start = position;
            }
        }
        if (chunk_start < padded_size)
            try appendChunk(
                allocator,
                &chunks,
                chunk_start,
                padded_size - chunk_start,
                options.max_chunks,
            );
    }
    if (chunks.items.len == 0)
        try appendChunk(
            allocator,
            &chunks,
            input.len,
            0,
            options.max_chunks,
        );

    var data_size: usize = 0;
    for (chunks.items) |*chunk| {
        chunk.data_offset = format.header_size + data_size;
        data_size = std.math.add(
            usize,
            data_size,
            @as(usize, @intCast(chunk.data_size)),
        ) catch return error.IntegerOverflow;
    }
    const table_bytes = std.math.mul(
        usize,
        chunks.items.len,
        options.version.chunkSize(),
    ) catch return error.IntegerOverflow;
    const chunk_offset = std.math.add(
        usize,
        format.header_size,
        data_size,
    ) catch return error.IntegerOverflow;
    const table_size = std.math.add(
        usize,
        format.magic_size,
        table_bytes,
    ) catch return error.IntegerOverflow;
    const output_size = std.math.add(
        usize,
        chunk_offset,
        table_size,
    ) catch return error.IntegerOverflow;
    if (output_size > options.max_output_len) return error.OutputLimitExceeded;

    const output = try allocator.alloc(u8, output_size);
    errdefer allocator.free(output);
    @memset(output, 0);
    @memcpy(output[0..format.magic_size], format.magic);
    format.writeU32Be(output, 8, @intFromEnum(options.version));
    format.writeU32Be(output, 12, format.header_size);
    format.writeU32Be(output, 16, format.default_alignment);
    format.writeU32Be(output, 20, @intFromEnum(options.version));
    format.writeU64Be(output, 24, input.len);
    format.writeU64Be(output, 32, data_size);
    format.writeU32Be(output, 40, 0);
    format.writeU32Be(output, 44, @intCast(chunks.items.len));
    format.writeU64Be(output, 48, chunk_offset);

    for (chunks.items, 0..) |chunk, index| {
        const logical_start: usize = @intCast(chunk.file_pos);
        const logical_end = @min(
            input.len,
            logical_start + @as(usize, @intCast(chunk.data_size)),
        );
        if (logical_start < logical_end)
            @memcpy(
                output[@intCast(chunk.data_offset)..][0 .. logical_end - logical_start],
                input[logical_start..logical_end],
            );
        const table_offset = chunk_offset + format.magic_size +
            index * options.version.chunkSize();
        if (options.version == .v1) {
            format.writeU32Be(output, table_offset, 0);
            format.writeU64Be(output, table_offset + 4, chunk.file_pos);
            format.writeU64Be(output, table_offset + 12, chunk.data_offset);
            format.writeU64Be(output, table_offset + 20, chunk.data_size);
        } else {
            format.writeU64Be(output, table_offset, chunk.file_pos);
            format.writeU64Be(output, table_offset + 8, chunk.data_offset);
            format.writeU64Be(output, table_offset + 16, chunk.data_size);
        }
    }
    @memcpy(output[chunk_offset..][0..format.magic_size], format.magic);
    return output;
}

fn appendChunk(
    allocator: std.mem.Allocator,
    chunks: *std.ArrayList(format.Chunk),
    file_pos: usize,
    size: usize,
    max_chunks: usize,
) Error!void {
    if (chunks.items.len >= max_chunks or
        chunks.items.len >= std.math.maxInt(u32))
        return error.OutputLimitExceeded;
    try chunks.append(allocator, .{
        .file_pos = file_pos,
        .data_offset = 0,
        .data_size = size,
    });
}

fn zeroWord(input: []const u8, offset: usize) bool {
    const end = @min(input.len, offset + 4);
    return std.mem.allEqual(u8, input[offset..end], 0);
}
