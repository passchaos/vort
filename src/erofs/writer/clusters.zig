const std = @import("std");
const core = @import("../../core.zig");
const tree = @import("tree.zig");
const writer_codec = @import("codec.zig");
const byte_sink = @import("../../io/sink.zig");

pub const Error = core.Error || writer_codec.Error || tree.ContentError || byte_sink.Error || std.mem.Allocator.Error;
pub const block_size: usize = 4096;
pub const max_extent_size: usize = 1024 * 1024;

pub const Emitter = struct {
    context: *anyopaque,
    append_fn: *const fn (*anyopaque, []const u8) (std.mem.Allocator.Error || byte_sink.Error)!void,
    written: usize = 0,

    pub fn append(self: *Emitter, bytes: []const u8) Error!void {
        const next = std.math.add(usize, self.written, bytes.len) catch return error.IntegerOverflow;
        try self.append_fn(self.context, bytes);
        self.written = next;
    }

    pub fn zeros(self: *Emitter, length: usize) Error!void {
        const zeroes = [_]u8{0} ** block_size;
        var remaining = length;
        while (remaining != 0) {
            const count = @min(remaining, zeroes.len);
            try self.append(zeroes[0..count]);
            remaining -= count;
        }
    }
};

const BufferContext = struct {
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    fn append(raw: *anyopaque, bytes: []const u8) (std.mem.Allocator.Error || byte_sink.Error)!void {
        const self: *BufferContext = @ptrCast(@alignCast(raw));
        try self.output.appendSlice(self.allocator, bytes);
    }
};

pub fn prefixLength(node: *const tree.Node) Error!usize {
    const length = node.contentSize();
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
    max_pcluster_size: ?usize,
) Error!void {
    if (node.compressed_indexes == null) return;
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    var context = BufferContext{ .allocator = allocator, .output = &output };
    var emitter = Emitter{ .context = &context, .append_fn = BufferContext.append };
    try emitNode(allocator, node, encoder, extent_size, max_pcluster_size, &emitter);
    node.compressed_data = try output.toOwnedSlice(allocator);
}

pub fn emitNode(
    allocator: std.mem.Allocator,
    node: *tree.Node,
    encoder: *writer_codec.Encoder,
    extent_size: usize,
    max_pcluster_size: ?usize,
    emitter: *Emitter,
) Error!void {
    const indexes = node.compressed_indexes orelse return;
    if (extent_size < block_size or extent_size > max_extent_size or
        !std.math.isPowerOfTwo(extent_size) or node.compressed_data != null or emitter.written != 0)
        return error.InvalidErofs;
    const length = try prefixLength(node);
    const scratch = if (node.source != null and length != 0)
        try allocator.alloc(u8, @min(extent_size, length))
    else
        null;
    defer if (scratch) |bytes| allocator.free(bytes);
    node.compressed_advise = (node.compressed_advise & 1) | (if (extent_size > block_size or max_pcluster_size != null) @as(u16, 2) else 0);
    var position: usize = 0;
    while (position < length) {
        const window_end = position + @min(extent_size, length - position);
        const window = if (scratch) |bytes| blk: {
            const part = bytes[0 .. window_end - position];
            try node.readContent(position, part);
            break :blk part;
        } else node.content()[position..window_end];
        const selected = if (max_pcluster_size) |capacity|
            try encoder.encodePrefixScratch(window, capacity, block_size)
        else
            @import("prefix.zig").Result{ .bytes = try encoder.encodeScratch(window), .consumed = window.len };
        if (selected.consumed > window.len or
            (selected.consumed != window.len and selected.consumed % block_size != 0))
            return error.InvalidErofs;
        const use_compressed = selected.consumed != 0 and selected.bytes.len != 0 and selected.bytes.len < selected.consumed;
        const end = if (use_compressed)
            position + selected.consumed
        else if (max_pcluster_size != null)
            position + @min(block_size, length - position)
        else
            window_end;
        const chunk = window[0 .. end - position];
        const logical_count = try blocksFor(chunk.len);
        const first_index = position / block_size;
        if (first_index > indexes.len or logical_count > indexes.len - first_index)
            return error.InvalidErofs;
        const encoded = selected.bytes;
        if (use_compressed) {
            if (max_pcluster_size) |capacity|
                if (encoded.len > capacity) return error.InvalidErofs;
            const physical_count = try blocksFor(encoded.len);
            if (physical_count == 0 or physical_count > 256)
                return error.InvalidErofs;
            const first_block = emitter.written / block_size;
            const added_bytes = std.math.mul(usize, physical_count, block_size) catch
                return error.IntegerOverflow;
            try emitter.zeros(added_bytes - encoded.len);
            try emitter.append(encoded);
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
                const first_block = emitter.written / block_size;
                if (first_block > std.math.maxInt(u32)) return error.InvalidErofs;
                indexes[raw_position / block_size] = .{ .kind = 0, .physical_block = @intCast(first_block) };
                try emitter.append(window[raw_position - position .. raw_end - position]);
                try emitter.zeros(block_size - (raw_end - raw_position));
                raw_position = raw_end;
            }
        }
        position = end;
    }
    node.compressed_block_count = emitter.written / block_size;
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
