const std = @import("std");
const core = @import("../../core.zig");
const xattr = @import("../xattr.zig");
const byte_source = @import("../../io/source.zig");

pub const Error = core.Error || xattr.Error || byte_source.Error || std.mem.Allocator.Error || error{InvalidErofs};
pub const Source = byte_source.Source;
pub const ContentError = byte_source.Error;

pub const EntryKind = enum { file, directory, symlink };
pub const Xattr = xattr.Attribute;

pub const HiddenRole = enum {
    none,
    packed_file,
    metabox,
};

pub const Entry = struct {
    path: []const u8,
    kind: EntryKind = .file,
    data: []const u8 = &.{},
    /// Regular-file bytes may instead be borrowed from a stable data source.
    source: ?Source = null,
    target: []const u8 = &.{},
    mode: u16 = 0,
    uid: u32 = 0,
    gid: u32 = 0,
    /// Seconds relative to WriterOptions.epoch.
    modification_time: u64 = 0,
    modification_nsec: ?u32 = null,
    xattrs: []const Xattr = &.{},
};

pub const Node = struct {
    path: []u8,
    kind: EntryKind,
    data: []const u8 = &.{},
    source: ?Source = null,
    target: []const u8 = &.{},
    mode: u16,
    uid: u32 = 0,
    gid: u32 = 0,
    modification_time: u64 = 0,
    modification_nsec: ?u32 = null,
    xattrs: []const Xattr = &.{},
    xattr_size: usize = 0,
    explicit: bool = false,
    hidden: bool = false,
    hidden_role: HiddenRole = .none,
    in_metabox: bool = false,
    directory_in_metadata_zone: bool = false,
    parent: usize = 0,
    nid: u64 = 0,
    location: usize = 0,
    inode_size: usize = 32,
    link_count: u32 = 1,
    layout: u3 = 0,
    start_block: u32 = std.math.maxInt(u32),
    directory_data: ?[]u8 = null,
    owned_data: ?[]u8 = null,
    compressed_inline_data: ?[]u8 = null,
    compressed_inline_tail_size: usize = 0,
    compressed_inline_kind: u2 = 0,
    fragment_offset: ?u64 = null,
    fragment_size: usize = 0,
    compressed_block_count: usize = 0,
    compressed_advise: u16 = 0,
    compressed_data: ?[]u8 = null,
    compressed_indexes: ?[]CompressionIndex = null,
    chunk_format: u16 = 0,
    chunk_indexes: ?[]ChunkIndex = null,

    pub const CompressionIndex = struct {
        kind: u2,
        logical_offset: u16 = 0,
        physical_block: u32,
    };

    pub const ChunkIndex = struct {
        unique_index: ?u32,
        start_block: u32 = std.math.maxInt(u32),
        device_id: u16 = 0,
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

    pub fn contentSize(self: Node) usize {
        if (self.source) |input| return @intCast(input.len);
        return self.content().len;
    }

    pub fn readContent(self: Node, offset: usize, output: []u8) ContentError!void {
        if (self.source) |input| return input.readExact(@intCast(offset), output);
        const bytes = self.content();
        if (offset > bytes.len or output.len > bytes.len - offset)
            return error.TruncatedFrame;
        @memcpy(output, bytes[offset..][0..output.len]);
    }
};

pub const Tree = struct {
    allocator: std.mem.Allocator,
    nodes: []Node,

    pub fn deinit(self: *Tree) void {
        for (self.nodes) |node| {
            if (node.directory_data) |bytes| self.allocator.free(bytes);
            if (node.owned_data) |bytes| self.allocator.free(bytes);
            if (node.compressed_inline_data) |bytes| self.allocator.free(bytes);
            if (node.compressed_indexes) |indexes| self.allocator.free(indexes);
            if (node.compressed_data) |bytes| self.allocator.free(bytes);
            if (node.chunk_indexes) |indexes| self.allocator.free(indexes);
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
        if (entry.source) |input| {
            if (entry.kind != .file or entry.data.len != 0 or input.max_read_size == 0)
                return error.InvalidErofs;
            _ = std.math.cast(usize, input.len) orelse return error.IntegerOverflow;
        }
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
    node.source = entry.source;
    node.target = entry.target;
    node.mode = if (entry.mode != 0) entry.mode else switch (entry.kind) {
        .file => 0o644,
        .directory => 0o755,
        .symlink => 0o777,
    };
    node.uid = entry.uid;
    node.gid = entry.gid;
    node.modification_time = entry.modification_time;
    node.modification_nsec = entry.modification_nsec;
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
