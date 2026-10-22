const std = @import("std");
const tree = @import("writer_tree.zig");

pub const Error = tree.Error;

pub const Plan = struct {
    allocator: std.mem.Allocator,
    data: []u8,
    chunk_size: usize,
    external: bool,
    has_chunks: bool,
    local_start_block: usize = 0,
    data_taken: bool = false,

    pub fn deinit(self: *Plan) void {
        if (!self.data_taken) self.allocator.free(self.data);
        self.* = undefined;
    }

    pub fn active(self: Plan) bool {
        return self.has_chunks or self.external;
    }

    pub fn assign(self: *Plan, nodes: []tree.Node, first_block: usize) Error!usize {
        const chunk_blocks = self.chunk_size / 4096;
        self.local_start_block = first_block;
        for (nodes) |*node| {
            const indexes = node.chunk_indexes orelse continue;
            for (indexes) |*index| {
                const unique_index = index.unique_index orelse {
                    index.start_block = std.math.maxInt(u32);
                    continue;
                };
                const relative = std.math.mul(
                    usize,
                    unique_index,
                    chunk_blocks,
                ) catch return error.IntegerOverflow;
                const block = if (self.external)
                    relative
                else
                    std.math.add(usize, first_block, relative) catch
                        return error.IntegerOverflow;
                if (block > std.math.maxInt(u32)) return error.InvalidErofs;
                index.start_block = @intCast(block);
                index.device_id = if (self.external) 1 else 0;
            }
        }
        if (self.external) return first_block;
        const data_blocks = self.data.len / 4096;
        return std.math.add(usize, first_block, data_blocks) catch
            return error.IntegerOverflow;
    }

    pub fn writeLocal(self: Plan, image: []u8) Error!void {
        if (self.external or self.data.len == 0) return;
        const start = std.math.mul(usize, self.local_start_block, 4096) catch
            return error.IntegerOverflow;
        const end = std.math.add(usize, start, self.data.len) catch
            return error.IntegerOverflow;
        if (end > image.len) return error.InvalidErofs;
        @memcpy(image[start..end], self.data);
    }

    pub fn takeData(self: *Plan) []u8 {
        self.data_taken = true;
        return self.data;
    }
};

pub fn prepare(
    allocator: std.mem.Allocator,
    filesystem: *tree.Tree,
    chunk_size: usize,
    external: bool,
) Error!Plan {
    if (chunk_size < 4096 or !std.math.isPowerOfTwo(chunk_size) or
        chunk_size % 4096 != 0)
        return error.InvalidErofs;
    const chunk_bits: u8 = @intCast(@ctz(chunk_size));
    if (chunk_bits < 12 or chunk_bits - 12 > 0x1f) return error.InvalidErofs;
    var unique_data: std.ArrayList(u8) = .empty;
    defer unique_data.deinit(allocator);
    var has_chunks = false;

    for (filesystem.nodes) |*node| {
        if (node.kind != .file or node.hidden or node.data.len == 0) continue;
        has_chunks = true;
        const count = (std.math.add(usize, node.data.len, chunk_size - 1) catch
            return error.IntegerOverflow) / chunk_size;
        node.chunk_indexes = try allocator.alloc(tree.Node.ChunkIndex, count);
        node.chunk_format = @as(u16, chunk_bits - 12) |
            (if (external) @as(u16, 0x20) else 0);
        for (node.chunk_indexes.?, 0..) |*index, chunk_index| {
            const start = std.math.mul(usize, chunk_index, chunk_size) catch
                return error.IntegerOverflow;
            const end = @min(node.data.len, std.math.add(usize, start, chunk_size) catch
                return error.IntegerOverflow);
            const bytes = node.data[start..end];
            if (allZero(bytes)) {
                index.* = .{ .unique_index = null };
                continue;
            }
            const unique_count = unique_data.items.len / chunk_size;
            var found: ?u32 = null;
            for (0..unique_count) |candidate_index| {
                const candidate_start = candidate_index * chunk_size;
                const candidate = unique_data.items[candidate_start..][0..chunk_size];
                if (std.mem.eql(u8, candidate[0..bytes.len], bytes) and
                    allZero(candidate[bytes.len..]))
                {
                    found = @intCast(candidate_index);
                    break;
                }
            }
            if (found == null) {
                if (unique_count > std.math.maxInt(u32)) return error.InvalidErofs;
                found = @intCast(unique_count);
                try unique_data.appendSlice(allocator, bytes);
                try unique_data.appendNTimes(allocator, 0, chunk_size - bytes.len);
            }
            index.* = .{ .unique_index = found };
        }
    }
    return .{
        .allocator = allocator,
        .data = try unique_data.toOwnedSlice(allocator),
        .chunk_size = chunk_size,
        .external = external,
        .has_chunks = has_chunks,
    };
}

fn allZero(bytes: []const u8) bool {
    for (bytes) |byte| if (byte != 0) return false;
    return true;
}
