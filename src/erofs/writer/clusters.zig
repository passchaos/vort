const std = @import("std");
const core = @import("../../core.zig");
const tree = @import("tree.zig");
const writer_codec = @import("codec.zig");

pub const Error = core.Error || writer_codec.Error || std.mem.Allocator.Error;
pub const block_size: usize = 4096;
pub const max_extent_size: usize = 1024 * 1024;

pub fn prefixLength(node: *const tree.Node) Error!usize {
    const length = node.content().len;
    if ((node.fragment_size != 0 and node.compressed_inline_tail_size != 0) or
        node.fragment_size > length or
        node.compressed_inline_tail_size > length - node.fragment_size)
        return error.InvalidErofs;
    return length - node.fragment_size - node.compressed_inline_tail_size;
}

/// Plan complete, block-aligned logical groups. Compressed groups retain
/// one HEAD and standard NONHEAD/CBLKCNT records; stored groups use one
/// PLAIN record per logical block. Payload bytes are owned by the tree.
pub fn prepareNode(
    allocator: std.mem.Allocator,
    node: *tree.Node,
    encoder: *writer_codec.Encoder,
    extent_size: usize,
) Error!void {
    const indexes = node.compressed_indexes orelse return;
    if (extent_size < block_size or extent_size > max_extent_size or
        !std.math.isPowerOfTwo(extent_size) or node.compressed_data != null)
        return error.InvalidErofs;
    const length = try prefixLength(node);
    const input = node.content()[0..length];
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    node.compressed_advise = 2;
    var position: usize = 0;
    while (position < input.len) {
        const end = position + @min(extent_size, input.len - position);
        const chunk = input[position..end];
        const logical_count = try blocksFor(chunk.len);
        const first_index = position / block_size;
        if (first_index > indexes.len or logical_count > indexes.len - first_index)
            return error.InvalidErofs;
        const encoded = try encoder.encodeScratch(chunk);
        if (encoded.len < chunk.len) {
            const physical_count = try blocksFor(encoded.len);
            if (physical_count == 0 or physical_count > 256)
                return error.InvalidErofs;
            const first_block = output.items.len / block_size;
            const added_bytes = std.math.mul(usize, physical_count, block_size) catch
                return error.IntegerOverflow;
            const output_end = std.math.add(usize, output.items.len, added_bytes) catch
                return error.IntegerOverflow;
            const previous_len = output.items.len;
            try output.resize(allocator, output_end);
            @memset(output.items[previous_len..], 0);
            @memcpy(output.items[output_end - encoded.len .. output_end], encoded);
            if (first_block > std.math.maxInt(u32)) return error.InvalidErofs;
            indexes[first_index] = .{ .kind = 1, .physical_block = @intCast(first_block) };
            for (1..logical_count) |offset| {
                const delta0: u32 = if (offset == 1)
                    0x800 | @as(u32, @intCast(physical_count))
                else
                    @intCast(offset);
                const delta1: u32 = @intCast(logical_count - offset);
                indexes[first_index + offset] = .{ .kind = 2, .physical_block = delta0 | (delta1 << 16) };
            }
        } else {
            var raw_position = position;
            while (raw_position < end) {
                const raw_end = raw_position + @min(block_size, end - raw_position);
                const first_block = output.items.len / block_size;
                if (first_block > std.math.maxInt(u32)) return error.InvalidErofs;
                indexes[raw_position / block_size] = .{ .kind = 0, .physical_block = @intCast(first_block) };
                const previous_len = output.items.len;
                const output_end = std.math.add(usize, previous_len, block_size) catch
                    return error.IntegerOverflow;
                try output.resize(allocator, output_end);
                @memset(output.items[previous_len..], 0);
                @memcpy(output.items[previous_len..][0 .. raw_end - raw_position], input[raw_position..raw_end]);
                raw_position = raw_end;
            }
        }
        position = end;
    }
    node.compressed_data = try output.toOwnedSlice(allocator);
    node.compressed_block_count = node.compressed_data.?.len / block_size;
}

pub fn writePrepared(image: []u8, node: *const tree.Node) Error!void {
    const data = node.compressed_data orelse return error.InvalidErofs;
    if (data.len % block_size != 0 or data.len / block_size != node.compressed_block_count)
        return error.InvalidErofs;
    if (data.len == 0) return;
    const start = std.math.mul(usize, node.start_block, block_size) catch
        return error.IntegerOverflow;
    const end = std.math.add(usize, start, data.len) catch
        return error.IntegerOverflow;
    if (end > image.len) return error.InvalidErofs;
    @memcpy(image[start..end], data);
}

pub fn blocksFor(length: usize) Error!usize {
    if (length == 0) return 0;
    return (std.math.add(usize, length, block_size - 1) catch return error.IntegerOverflow) / block_size;
}
