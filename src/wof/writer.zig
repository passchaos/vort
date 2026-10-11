const std = @import("std");
const core = @import("../core.zig");
const xpress = @import("../xpress.zig");
const format = @import("format.zig");

pub const Error = core.Error || xpress.Error || std.mem.Allocator.Error || error{
    InvalidWof,
};

pub fn encodedBound(input_len: usize, algorithm: format.Algorithm) Error!usize {
    if (input_len == 0) return 0;
    const chunk_size = algorithm.chunkSize();
    const chunk_count = (std.math.add(usize, input_len, chunk_size - 1) catch
        return error.IntegerOverflow) / chunk_size;
    const entry_size: usize = if (input_len <= std.math.maxInt(u32)) 4 else 8;
    const table_size = std.math.mul(usize, chunk_count - 1, entry_size) catch
        return error.IntegerOverflow;
    return std.math.add(usize, input_len, table_size) catch error.IntegerOverflow;
}

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    algorithm: format.Algorithm,
) Error![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    _ = try encodeAppend(allocator, &output, input, algorithm);
    return output.toOwnedSlice(allocator);
}

pub fn encodeAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
    algorithm: format.Algorithm,
) Error!usize {
    const start = output.items.len;
    errdefer output.shrinkRetainingCapacity(start);
    if (input.len == 0) return 0;
    const chunk_size = algorithm.chunkSize();
    const chunk_count = (input.len + chunk_size - 1) / chunk_size;
    const entry_size: usize = if (input.len <= std.math.maxInt(u32)) 4 else 8;
    const table_size = std.math.mul(usize, chunk_count - 1, entry_size) catch
        return error.IntegerOverflow;
    try output.appendNTimes(allocator, 0, table_size);
    var input_offset: usize = 0;
    var data_size: usize = 0;
    for (0..chunk_count) |chunk_index| {
        const decoded_len = @min(chunk_size, input.len - input_offset);
        const chunk = input[input_offset..][0..decoded_len];
        var encoded: ?[]u8 = null;
        defer if (encoded) |bytes| allocator.free(bytes);
        if (algorithm != .lzx)
            encoded = try xpress.encodeHuffmanAlloc(allocator, chunk, .{});
        const selected = if (encoded) |bytes|
            if (bytes.len < chunk.len) bytes else chunk
        else
            chunk;
        try output.appendSlice(allocator, selected);
        data_size = std.math.add(usize, data_size, selected.len) catch
            return error.IntegerOverflow;
        if (chunk_index + 1 < chunk_count) {
            const table_offset = start + chunk_index * entry_size;
            if (entry_size == 4) {
                if (data_size > std.math.maxInt(u32)) return error.IntegerOverflow;
                std.mem.writeInt(u32, output.items[table_offset..][0..4], @intCast(data_size), .little);
            } else {
                std.mem.writeInt(u64, output.items[table_offset..][0..8], data_size, .little);
            }
        }
        input_offset += decoded_len;
    }
    return output.items.len - start;
}

pub fn encodeInto(
    allocator: std.mem.Allocator,
    input: []const u8,
    output: []u8,
    algorithm: format.Algorithm,
) Error!usize {
    const encoded = try encodeAlloc(allocator, input, algorithm);
    defer allocator.free(encoded);
    if (encoded.len > output.len) return error.OutputTooSmall;
    @memcpy(output[0..encoded.len], encoded);
    return encoded.len;
}
