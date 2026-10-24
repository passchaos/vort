const std = @import("std");
const tree = @import("tree.zig");
const chunks = @import("chunks.zig");
const byte_sink = @import("../../io/sink.zig");

pub const Error = tree.Error || byte_sink.Error;
const block_size = 4096;

pub fn prepare(allocator: std.mem.Allocator, filesystem: *tree.Tree, chunk_size: usize, external: bool) Error!chunks.Plan {
    if (chunk_size < block_size or !std.math.isPowerOfTwo(chunk_size) or chunk_size % block_size != 0)
        return error.InvalidErofs;
    const bits: u8 = @intCast(@ctz(chunk_size));
    if (bits < 12 or bits - 12 > 0x1f) return error.InvalidErofs;
    var unique: std.ArrayList(chunks.Plan.UniqueSource) = .empty;
    errdefer unique.deinit(allocator);
    var has_chunks = false;
    for (filesystem.nodes, 0..) |*node, node_index| {
        const length = node.contentSize();
        if (node.kind != .file or node.hidden or length == 0) continue;
        has_chunks = true;
        const count = (std.math.add(usize, length, chunk_size - 1) catch return error.IntegerOverflow) / chunk_size;
        node.chunk_indexes = try allocator.alloc(tree.Node.ChunkIndex, count);
        node.chunk_format = @as(u16, bits - 12) | (if (external) @as(u16, 0x20) else 0);
        for (node.chunk_indexes.?, 0..) |*index, chunk_index| {
            const offset = std.math.mul(usize, chunk_index, chunk_size) catch return error.IntegerOverflow;
            const size = @min(chunk_size, length - offset);
            if (try allZero(node, offset, size)) {
                index.* = .{ .unique_index = null };
                continue;
            }
            var found: ?u32 = null;
            for (unique.items, 0..) |candidate, candidate_index| {
                if (try equalPadded(&filesystem.nodes[candidate.node], candidate.offset, candidate.len, node, offset, size)) {
                    found = @intCast(candidate_index);
                    break;
                }
            }
            if (found == null) {
                if (unique.items.len > std.math.maxInt(u32)) return error.InvalidErofs;
                found = @intCast(unique.items.len);
                try unique.append(allocator, .{ .node = node_index, .offset = offset, .len = size });
            }
            index.* = .{ .unique_index = found };
        }
    }
    return .{ .allocator = allocator, .data = &.{}, .chunk_size = chunk_size, .external = external, .has_chunks = has_chunks, .unique_sources = try unique.toOwnedSlice(allocator) };
}

fn allZero(node: *const tree.Node, offset: usize, length: usize) Error!bool {
    var buffer: [block_size]u8 = undefined;
    var position: usize = 0;
    while (position < length) {
        const size = @min(buffer.len, length - position);
        try node.readContent(offset + position, buffer[0..size]);
        for (buffer[0..size]) |byte| if (byte != 0) return false;
        position += size;
    }
    return true;
}

fn equalPadded(a: *const tree.Node, a_offset: usize, a_len: usize, b: *const tree.Node, b_offset: usize, b_len: usize) Error!bool {
    var first: [block_size]u8 = undefined;
    var second: [block_size]u8 = undefined;
    var position: usize = 0;
    const length = @max(a_len, b_len);
    while (position < length) {
        const size = @min(block_size, length - position);
        @memset(first[0..size], 0);
        @memset(second[0..size], 0);
        if (position < a_len) try a.readContent(a_offset + position, first[0..@min(size, a_len - position)]);
        if (position < b_len) try b.readContent(b_offset + position, second[0..@min(size, b_len - position)]);
        if (!std.mem.eql(u8, first[0..size], second[0..size])) return false;
        position += size;
    }
    return true;
}

pub fn emit(plan: chunks.Plan, nodes: []const tree.Node, sink: byte_sink.Sink, start: u64) Error!void {
    const sources = plan.unique_sources orelse return error.InvalidErofs;
    var buffer: [block_size]u8 = undefined;
    for (sources, 0..) |source, index| {
        const relative = std.math.mul(u64, index, plan.chunk_size) catch return error.IntegerOverflow;
        const destination = std.math.add(u64, start, relative) catch return error.IntegerOverflow;
        var position: usize = 0;
        while (position < plan.chunk_size) {
            const size = @min(buffer.len, plan.chunk_size - position);
            @memset(buffer[0..size], 0);
            if (position < source.len) try nodes[source.node].readContent(source.offset + position, buffer[0..@min(size, source.len - position)]);
            try sink.writeExact(std.math.add(u64, destination, position) catch return error.IntegerOverflow, buffer[0..size]);
            position += size;
        }
    }
}
