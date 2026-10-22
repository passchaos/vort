const std = @import("std");
const tree = @import("tree.zig");

pub const Error = tree.Error;
const full_index_metadata_size: usize = 16;

pub const Options = struct {
    file_tails: bool = false,
    directories: bool = false,
};

pub fn prepare(
    allocator: std.mem.Allocator,
    filesystem: *tree.Tree,
    block_size: usize,
    options: Options,
) Error!void {
    if (block_size == 0 or !std.math.isPowerOfTwo(block_size))
        return error.InvalidErofs;
    var packed_data: std.ArrayList(u8) = .empty;
    defer packed_data.deinit(allocator);

    const visible_count = filesystem.nodes.len;
    for (filesystem.nodes[0..visible_count]) |*node| {
        if (node.hidden) continue;
        const content = node.content();
        const fragment = switch (node.kind) {
            .file => blk: {
                if (!options.file_tails or content.len == 0) continue;
                const tail_start = if (content.len <= block_size)
                    0
                else
                    (content.len - 1) & ~(block_size - 1);
                break :blk content[tail_start..];
            },
            .directory => blk: {
                if (!options.directories or content.len < full_index_metadata_size) continue;
                break :blk content;
            },
            .symlink => continue,
        };
        const next_len = std.math.add(usize, packed_data.items.len, fragment.len) catch
            return error.IntegerOverflow;
        if (next_len > std.math.maxInt(u32)) return error.InvalidErofs;
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
        .hidden_role = .packed_file,
        .parent = 0,
    };
}

pub fn syncDirectories(filesystem: *tree.Tree) Error!void {
    const packed_node = packedNodePtr(filesystem.nodes) orelse {
        for (filesystem.nodes) |node|
            if (node.kind == .directory and node.fragment_size != 0)
                return error.InvalidErofs;
        return;
    };
    const output = packed_node.owned_data orelse return error.InvalidErofs;
    for (filesystem.nodes) |node| {
        if (node.kind != .directory or node.fragment_size == 0) continue;
        const content = node.content();
        const offset = node.fragment_offset orelse return error.InvalidErofs;
        if (node.fragment_size != content.len)
            return error.InvalidErofs;
        const start = std.math.cast(usize, offset) orelse return error.InvalidErofs;
        const end = std.math.add(usize, start, content.len) catch
            return error.IntegerOverflow;
        if (end > output.len) return error.InvalidErofs;
        @memcpy(output[start..end], content);
    }
}

pub fn packedNode(nodes: []const tree.Node) ?tree.Node {
    for (nodes) |node| if (node.hidden_role == .packed_file) return node;
    return null;
}

fn packedNodePtr(nodes: []tree.Node) ?*tree.Node {
    var result: ?*tree.Node = null;
    for (nodes) |*node| {
        if (node.hidden_role != .packed_file) continue;
        if (result != null) return null;
        result = node;
    }
    return result;
}
