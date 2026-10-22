const std = @import("std");
const tree = @import("writer_tree.zig");

pub const Error = tree.Error;

pub fn prepare(
    allocator: std.mem.Allocator,
    filesystem: *tree.Tree,
    block_size: usize,
) Error!void {
    if (block_size == 0 or !std.math.isPowerOfTwo(block_size))
        return error.InvalidErofs;
    var packed_data: std.ArrayList(u8) = .empty;
    defer packed_data.deinit(allocator);

    const visible_count = filesystem.nodes.len;
    for (filesystem.nodes[0..visible_count]) |*node| {
        if (node.kind != .file or node.data.len == 0 or node.hidden) continue;
        const tail_start = if (node.data.len <= block_size)
            0
        else
            (node.data.len - 1) & ~(block_size - 1);
        const fragment = node.data[tail_start..];
        if (packed_data.items.len >> 63 != 0) return error.InvalidErofs;
        node.fragment_offset = @intCast(packed_data.items.len);
        node.fragment_size = fragment.len;
        try packed_data.appendSlice(allocator, fragment);
    }
    if (packed_data.items.len == 0) return;
    if (packed_data.items.len > std.math.maxInt(u32)) return error.InvalidErofs;

    const owned_data = try packed_data.toOwnedSlice(allocator);
    errdefer allocator.free(owned_data);
    const path = try allocator.dupe(u8, "$vort-packed");
    errdefer allocator.free(path);
    const old_len = filesystem.nodes.len;
    filesystem.nodes = try allocator.realloc(filesystem.nodes, old_len + 1);
    filesystem.nodes[old_len] = .{
        .path = path,
        .kind = .file,
        .data = owned_data,
        .owned_data = owned_data,
        .mode = 0o644,
        .explicit = true,
        .hidden = true,
        .parent = 0,
    };
}

pub fn packedNode(nodes: []const tree.Node) ?tree.Node {
    for (nodes) |node| if (node.hidden) return node;
    return null;
}
