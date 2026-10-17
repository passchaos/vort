const std = @import("std");
const core = @import("../core.zig");
const metadata = @import("metadata.zig");

pub const Error = core.Error || std.mem.Allocator.Error || error{
    InvalidWimEntry,
};

pub const EntryKind = enum {
    file,
    directory,
};

/// A borrowed entry description.  The writer never takes ownership of `path`
/// or `data`; both only need to remain valid for the duration of encode*().
pub const Entry = struct {
    path: []const u8,
    kind: EntryKind = .file,
    data: []const u8 = &.{},
    attributes: u32 = 0,
    creation_time: u64 = 0,
    last_access_time: u64 = 0,
    last_write_time: u64 = 0,
};

pub const RootInfo = struct {
    creation_time: u64 = 0,
    last_access_time: u64 = 0,
    last_write_time: u64 = 0,
};

pub const Node = struct {
    path: []u8,
    name_utf16le: []u16,
    kind: EntryKind,
    data: []const u8 = &.{},
    attributes: u32,
    creation_time: u64 = 0,
    last_access_time: u64 = 0,
    last_write_time: u64 = 0,
    explicit: bool = false,
    parent: usize = 0,
    subdir_offset: usize = 0,
    sha1: [std.crypto.hash.Sha1.digest_length]u8 = @splat(0),

    pub fn name(self: Node) []const u8 {
        const slash = std.mem.lastIndexOfScalar(u8, self.path, '/') orelse
            return self.path;
        return self.path[slash + 1 ..];
    }
};

pub const Tree = struct {
    allocator: std.mem.Allocator,
    nodes: []Node,

    pub fn deinit(self: *Tree) void {
        for (self.nodes) |node| {
            self.allocator.free(node.name_utf16le);
            self.allocator.free(node.path);
        }
        self.allocator.free(self.nodes);
        self.* = undefined;
    }

    pub fn directoryCount(self: Tree) usize {
        var count: usize = 0;
        for (self.nodes) |node| count += @intFromBool(node.kind == .directory);
        return count;
    }

    pub fn fileCount(self: Tree) usize {
        return self.nodes.len - self.directoryCount();
    }

    pub fn totalFileBytes(self: Tree) Error!u64 {
        var total: u64 = 0;
        for (self.nodes) |node| {
            if (node.kind != .file) continue;
            total = std.math.add(u64, total, node.data.len) catch
                return error.IntegerOverflow;
        }
        return total;
    }
};

pub fn build(
    allocator: std.mem.Allocator,
    entries: []const Entry,
    root_info: RootInfo,
) Error!Tree {
    var nodes: std.ArrayList(Node) = .empty;
    errdefer deinitNodes(allocator, &nodes);

    try appendNode(allocator, &nodes, "", .directory, true);
    nodes.items[0].attributes = metadata.file_attribute_directory;
    nodes.items[0].creation_time = root_info.creation_time;
    nodes.items[0].last_access_time = root_info.last_access_time;
    nodes.items[0].last_write_time = root_info.last_write_time;

    for (entries) |entry| {
        try validateEntry(entry);
        try ensureParents(allocator, &nodes, entry.path);
        if (findNode(nodes.items, entry.path)) |index| {
            if (nodes.items[index].explicit or entry.kind != .directory)
                return error.InvalidWimEntry;
            applyEntry(&nodes.items[index], entry);
        } else {
            try appendNode(allocator, &nodes, entry.path, entry.kind, true);
            applyEntry(&nodes.items[nodes.items.len - 1], entry);
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
        node.parent = findNode(nodes.items, parent_path) orelse
            return error.InvalidWimEntry;
        if (nodes.items[node.parent].kind != .directory)
            return error.InvalidWimEntry;
    }
    try rejectAsciiCaseAliases(nodes.items);

    return .{
        .allocator = allocator,
        .nodes = try nodes.toOwnedSlice(allocator),
    };
}

fn deinitNodes(allocator: std.mem.Allocator, nodes: *std.ArrayList(Node)) void {
    for (nodes.items) |node| {
        allocator.free(node.name_utf16le);
        allocator.free(node.path);
    }
    nodes.deinit(allocator);
}

fn appendNode(
    allocator: std.mem.Allocator,
    nodes: *std.ArrayList(Node),
    path: []const u8,
    kind: EntryKind,
    explicit: bool,
) Error!void {
    const owned_path = try allocator.dupe(u8, path);
    errdefer allocator.free(owned_path);
    const slash = std.mem.lastIndexOfScalar(u8, path, '/');
    const name = if (slash) |position| path[position + 1 ..] else path;
    const name_utf16le = std.unicode.utf8ToUtf16LeAlloc(allocator, name) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.InvalidUtf8 => return error.InvalidWimEntry,
    };
    errdefer allocator.free(name_utf16le);
    if (name_utf16le.len > std.math.maxInt(u16) / 2)
        return error.InvalidWimEntry;
    try nodes.append(allocator, .{
        .path = owned_path,
        .name_utf16le = name_utf16le,
        .kind = kind,
        .attributes = defaultAttributes(kind),
        .explicit = explicit,
    });
}

fn applyEntry(node: *Node, entry: Entry) void {
    node.kind = entry.kind;
    node.data = entry.data;
    node.attributes = entry.attributes | defaultAttributes(entry.kind);
    node.creation_time = entry.creation_time;
    node.last_access_time = entry.last_access_time;
    node.last_write_time = entry.last_write_time;
    node.explicit = true;
    node.sha1 = @splat(0);
    if (entry.kind == .file and entry.data.len != 0)
        std.crypto.hash.Sha1.hash(entry.data, &node.sha1, .{});
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
    try appendNode(allocator, nodes, parent_path, .directory, false);
}

fn findNode(nodes: []const Node, path: []const u8) ?usize {
    for (nodes, 0..) |node, index|
        if (std.mem.eql(u8, node.path, path)) return index;
    return null;
}

fn rejectAsciiCaseAliases(nodes: []const Node) Error!void {
    for (nodes, 0..) |left, left_index| {
        if (left_index == 0) continue;
        for (nodes[left_index + 1 ..]) |right| {
            if (left.parent == right.parent and
                std.ascii.eqlIgnoreCase(left.name(), right.name()))
                return error.InvalidWimEntry;
        }
    }
}

fn lessThan(_: void, left: Node, right: Node) bool {
    return std.mem.order(u8, left.path, right.path) == .lt;
}

fn defaultAttributes(kind: EntryKind) u32 {
    return switch (kind) {
        .file => 0x0000_0080,
        .directory => metadata.file_attribute_directory,
    };
}

fn validateEntry(entry: Entry) Error!void {
    if (entry.path.len == 0 or entry.path[0] == '/' or
        entry.path[entry.path.len - 1] == '/' or
        !std.unicode.utf8ValidateSlice(entry.path))
        return error.InvalidWimEntry;
    if (entry.kind == .directory and entry.data.len != 0)
        return error.InvalidWimEntry;
    if (entry.kind == .file and
        entry.attributes & metadata.file_attribute_directory != 0)
        return error.InvalidWimEntry;
    if (entry.attributes &
        (metadata.file_attribute_reparse_point | metadata.file_attribute_encrypted) != 0)
        return error.InvalidWimEntry;
    var components = std.mem.splitScalar(u8, entry.path, '/');
    while (components.next()) |component| {
        if (component.len == 0 or std.mem.eql(u8, component, ".") or
            std.mem.eql(u8, component, "..") or
            std.mem.indexOfAny(u8, component, "\\\x00") != null)
            return error.InvalidWimEntry;
    }
}

test "WIM writer tree inserts and sorts implicit directories" {
    const entries = [_]Entry{
        .{ .path = "z.txt", .data = "z" },
        .{ .path = "a/nested.txt", .data = "a" },
        .{ .path = "a", .kind = .directory, .last_write_time = 9 },
    };
    var tree = try build(std.testing.allocator, &entries, .{});
    defer tree.deinit();
    try std.testing.expectEqual(@as(usize, 4), tree.nodes.len);
    try std.testing.expectEqualStrings("", tree.nodes[0].path);
    try std.testing.expectEqualStrings("a", tree.nodes[1].path);
    try std.testing.expectEqualStrings("a/nested.txt", tree.nodes[2].path);
    try std.testing.expectEqualStrings("z.txt", tree.nodes[3].path);
    try std.testing.expectEqual(@as(u64, 9), tree.nodes[1].last_write_time);
    try std.testing.expectEqual(@as(usize, 1), tree.nodes[2].parent);
}

test "WIM writer tree rejects ambiguous paths" {
    const duplicate = [_]Entry{
        .{ .path = "same" },
        .{ .path = "same" },
    };
    try std.testing.expectError(
        error.InvalidWimEntry,
        build(std.testing.allocator, &duplicate, .{}),
    );
    const aliases = [_]Entry{
        .{ .path = "A" },
        .{ .path = "a" },
    };
    try std.testing.expectError(
        error.InvalidWimEntry,
        build(std.testing.allocator, &aliases, .{}),
    );
}
