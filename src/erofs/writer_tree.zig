const std = @import("std");
const core = @import("../core.zig");
const xattr = @import("xattr.zig");

pub const Error = core.Error || xattr.Error || std.mem.Allocator.Error || error{InvalidErofs};

pub const EntryKind = enum { file, directory, symlink };
pub const Xattr = xattr.Attribute;

pub const Entry = struct {
    path: []const u8,
    kind: EntryKind = .file,
    data: []const u8 = &.{},
    target: []const u8 = &.{},
    mode: u16 = 0,
    modification_time: u32 = 0,
    xattrs: []const Xattr = &.{},
};

pub const Node = struct {
    path: []u8,
    kind: EntryKind,
    data: []const u8 = &.{},
    target: []const u8 = &.{},
    mode: u16,
    modification_time: u32 = 0,
    xattrs: []const Xattr = &.{},
    xattr_size: usize = 0,
    explicit: bool = false,
    parent: usize = 0,
    nid: u64 = 0,
    location: usize = 0,
    layout: u3 = 0,
    start_block: u32 = std.math.maxInt(u32),
    directory_data: ?[]u8 = null,
    compressed_indexes: ?[]CompressionIndex = null,

    pub const CompressionIndex = struct {
        kind: u2,
        physical_block: u32,
    };

    pub fn name(self: Node) []const u8 {
        const slash = std.mem.lastIndexOfScalar(u8, self.path, '/') orelse
            return self.path;
        return self.path[slash + 1 ..];
    }

    pub fn content(self: Node) []const u8 {
        return switch (self.kind) {
            .file => self.data,
            .directory => self.directory_data orelse &.{},
            .symlink => self.target,
        };
    }
};

pub const Tree = struct {
    allocator: std.mem.Allocator,
    nodes: []Node,

    pub fn deinit(self: *Tree) void {
        for (self.nodes) |node| {
            if (node.directory_data) |bytes| self.allocator.free(bytes);
            if (node.compressed_indexes) |indexes| self.allocator.free(indexes);
            self.allocator.free(node.path);
        }
        self.allocator.free(self.nodes);
        self.* = undefined;
    }
};

pub fn build(
    allocator: std.mem.Allocator,
    entries: []const Entry,
    root_xattrs: []const Xattr,
) Error!Tree {
    var nodes: std.ArrayList(Node) = .empty;
    errdefer {
        for (nodes.items) |node| allocator.free(node.path);
        nodes.deinit(allocator);
    }
    const root_path = try allocator.dupe(u8, "");
    nodes.append(allocator, .{
        .path = root_path,
        .kind = .directory,
        .mode = 0o755,
        .explicit = true,
        .xattrs = root_xattrs,
    }) catch |err| {
        allocator.free(root_path);
        return err;
    };
    for (entries) |entry| {
        try validatePath(entry.path);
        try ensureParents(allocator, &nodes, entry.path);
        if (findNode(nodes.items, entry.path)) |index| {
            if (nodes.items[index].explicit or entry.kind != .directory)
                return error.InvalidErofs;
            applyEntry(&nodes.items[index], entry);
        } else {
            const path = try allocator.dupe(u8, entry.path);
            errdefer allocator.free(path);
            var node = Node{
                .path = path,
                .kind = entry.kind,
                .mode = 0,
            };
            applyEntry(&node, entry);
            try nodes.append(allocator, node);
        }
    }
    std.mem.sort(Node, nodes.items, {}, lessThan);
    for (nodes.items, 0..) |*node, index| {
        if (node.path.len == 0) {
            node.parent = index;
            continue;
        }
        const slash = std.mem.lastIndexOfScalar(u8, node.path, '/');
        const parent_path = if (slash) |position| node.path[0..position] else "";
        node.parent = findNode(nodes.items, parent_path) orelse return error.InvalidErofs;
        if (nodes.items[node.parent].kind != .directory) return error.InvalidErofs;
    }
    return .{ .allocator = allocator, .nodes = try nodes.toOwnedSlice(allocator) };
}

fn applyEntry(node: *Node, entry: Entry) void {
    node.kind = entry.kind;
    node.data = entry.data;
    node.target = entry.target;
    node.mode = if (entry.mode != 0) entry.mode else switch (entry.kind) {
        .file => 0o644,
        .directory => 0o755,
        .symlink => 0o777,
    };
    node.modification_time = entry.modification_time;
    node.xattrs = entry.xattrs;
    node.explicit = true;
}

fn ensureParents(
    allocator: std.mem.Allocator,
    nodes: *std.ArrayList(Node),
    path: []const u8,
) Error!void {
    const slash = std.mem.lastIndexOfScalar(u8, path, '/') orelse return;
    const parent_path = path[0..slash];
    if (findNode(nodes.items, parent_path) != null) return;
    try ensureParents(allocator, nodes, parent_path);
    const owned = try allocator.dupe(u8, parent_path);
    errdefer allocator.free(owned);
    try nodes.append(allocator, .{
        .path = owned,
        .kind = .directory,
        .mode = 0o755,
    });
}

fn findNode(nodes: []const Node, path: []const u8) ?usize {
    for (nodes, 0..) |node, index|
        if (std.mem.eql(u8, node.path, path)) return index;
    return null;
}

fn lessThan(_: void, left: Node, right: Node) bool {
    return std.mem.order(u8, left.path, right.path) == .lt;
}

fn validatePath(path: []const u8) Error!void {
    if (path.len == 0 or path[0] == '/' or path[path.len - 1] == '/')
        return error.InvalidErofs;
    var components = std.mem.splitScalar(u8, path, '/');
    while (components.next()) |component| {
        if (component.len == 0 or component.len > 255 or
            std.mem.eql(u8, component, ".") or std.mem.eql(u8, component, "..") or
            std.mem.indexOfScalar(u8, component, 0) != null)
            return error.InvalidErofs;
    }
}
