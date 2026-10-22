const std = @import("std");
const tree = @import("tree.zig");

pub const Error = tree.Error;

pub fn prepare(
    allocator: std.mem.Allocator,
    filesystem: *tree.Tree,
) Error!void {
    for (filesystem.nodes) |*node| {
        if (node.hidden or node.hidden_role != .none or node.in_metabox)
            return error.InvalidErofs;
        node.in_metabox = true;
    }

    const path = try allocator.dupe(u8, "$vort-metabox");
    errdefer allocator.free(path);
    const old_len = filesystem.nodes.len;
    filesystem.nodes = try allocator.realloc(filesystem.nodes, old_len + 1);
    filesystem.nodes[old_len] = .{
        .path = path,
        .kind = .file,
        .mode = 0o644,
        .explicit = true,
        .hidden = true,
        .hidden_role = .metabox,
        .parent = 0,
    };
}

pub fn installData(
    allocator: std.mem.Allocator,
    nodes: []tree.Node,
    length: usize,
) Error![]u8 {
    const node = metaboxNodePtr(nodes) orelse return error.InvalidErofs;
    if (node.owned_data != null or node.data.len != 0 or length == 0)
        return error.InvalidErofs;
    const bytes = try allocator.alloc(u8, length);
    @memset(bytes, 0);
    node.data = bytes;
    node.owned_data = bytes;
    return bytes;
}

pub fn data(nodes: []const tree.Node) ?[]u8 {
    var result: ?[]u8 = null;
    for (nodes) |node| {
        if (node.hidden_role != .metabox) continue;
        if (result != null) return null;
        result = node.owned_data;
    }
    return result;
}

fn metaboxNodePtr(nodes: []tree.Node) ?*tree.Node {
    var result: ?*tree.Node = null;
    for (nodes) |*node| {
        if (node.hidden_role != .metabox) continue;
        if (result != null) return null;
        result = node;
    }
    return result;
}
