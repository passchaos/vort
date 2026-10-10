const std = @import("std");
const core = @import("../core.zig");
const format = @import("format.zig");

pub const Error = core.Error || std.mem.Allocator.Error || error{InvalidSquashfs};

pub const EntryKind = enum {
    file,
    directory,
    symlink,
};

pub const Entry = struct {
    path: []const u8,
    kind: EntryKind = .file,
    data: []const u8 = &.{},
    target: []const u8 = &.{},
    mode: u16 = 0,
    modification_time: u32 = 0,
};

pub const Node = struct {
    path: []u8,
    kind: EntryKind,
    data: []const u8 = &.{},
    target: []const u8 = &.{},
    mode: u16 = 0,
    modification_time: u32 = 0,
    explicit: bool = false,
    parent: usize = 0,
    inode_number: u32 = 0,
    inode_logical_offset: usize = 0,
    directory_logical_offset: usize = 0,
    directory_size: usize = 0,
    data_start: usize = 0,
    fragment: u32 = format.invalid_fragment,
    fragment_offset: u32 = 0,
    block_sizes: ?[]u32 = null,

    pub fn name(self: Node) []const u8 {
        const slash = std.mem.lastIndexOfScalar(u8, self.path, '/') orelse
            return self.path;
        return self.path[slash + 1 ..];
    }

    pub fn inodeKind(self: Node) format.InodeKind {
        return switch (self.kind) {
            .file => .long_regular,
            .directory => .long_directory,
            .symlink => .symlink,
        };
    }

    pub fn encodedInodeSize(self: Node) Error!usize {
        return switch (self.kind) {
            .file => std.math.add(
                usize,
                56,
                std.math.mul(
                    usize,
                    if (self.block_sizes) |sizes| sizes.len else 0,
                    4,
                ) catch return error.IntegerOverflow,
            ) catch return error.IntegerOverflow,
            .directory => 40,
            .symlink => std.math.add(usize, 24, self.target.len) catch
                return error.IntegerOverflow,
        };
    }
};

pub const Tree = struct {
    allocator: std.mem.Allocator,
    nodes: []Node,

    pub fn deinit(self: *Tree) void {
        for (self.nodes) |node| {
            if (node.block_sizes) |sizes| self.allocator.free(sizes);
            self.allocator.free(node.path);
        }
        self.allocator.free(self.nodes);
        self.* = undefined;
    }
};

pub fn build(allocator: std.mem.Allocator, entries: []const Entry) Error!Tree {
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
    }) catch |err| {
        allocator.free(root_path);
        return err;
    };
    for (entries) |entry| {
        try validatePath(entry.path);
        try ensureParents(allocator, &nodes, entry.path);
        if (findNode(nodes.items, entry.path)) |index| {
            if (nodes.items[index].explicit) return error.InvalidSquashfs;
            if (entry.kind != .directory) return error.InvalidSquashfs;
            applyEntry(&nodes.items[index], entry);
        } else {
            const path = try allocator.dupe(u8, entry.path);
            errdefer allocator.free(path);
            var node = Node{ .path = path, .kind = entry.kind };
            applyEntry(&node, entry);
            try nodes.append(allocator, node);
        }
    }
    std.mem.sort(Node, nodes.items, {}, nodeLessThan);
    if (nodes.items.len > std.math.maxInt(u32)) return error.InvalidSquashfs;
    for (nodes.items, 0..) |*node, index| {
        node.inode_number = @intCast(index + 1);
        if (node.path.len == 0) {
            node.parent = index;
            continue;
        }
        const slash = std.mem.lastIndexOfScalar(u8, node.path, '/');
        const parent_path = if (slash) |position| node.path[0..position] else "";
        node.parent = findNode(nodes.items, parent_path) orelse
            return error.InvalidSquashfs;
        if (nodes.items[node.parent].kind != .directory) return error.InvalidSquashfs;
    }
    return .{
        .allocator = allocator,
        .nodes = try nodes.toOwnedSlice(allocator),
    };
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

fn nodeLessThan(_: void, left: Node, right: Node) bool {
    return std.mem.order(u8, left.path, right.path) == .lt;
}

fn validatePath(path: []const u8) Error!void {
    if (path.len == 0 or path[0] == '/' or path[path.len - 1] == '/')
        return error.InvalidSquashfs;
    var components = std.mem.splitScalar(u8, path, '/');
    while (components.next()) |component| {
        if (component.len == 0 or component.len > 256 or
            std.mem.eql(u8, component, ".") or std.mem.eql(u8, component, "..") or
            std.mem.indexOfScalar(u8, component, 0) != null)
            return error.InvalidSquashfs;
    }
}

test "SquashFS writer tree is deterministic and synthesizes parents" {
    var tree = try build(std.testing.allocator, &.{
        .{ .path = "z/file", .data = "z" },
        .{ .path = "a", .kind = .directory },
        .{ .path = "a/link", .kind = .symlink, .target = "../z/file" },
    });
    defer tree.deinit();
    try std.testing.expectEqual(@as(usize, 5), tree.nodes.len);
    try std.testing.expectEqualStrings("", tree.nodes[0].path);
    try std.testing.expectEqualStrings("a", tree.nodes[1].path);
    try std.testing.expectEqualStrings("a/link", tree.nodes[2].path);
    try std.testing.expectEqualStrings("z", tree.nodes[3].path);
    try std.testing.expectEqualStrings("z/file", tree.nodes[4].path);
}
