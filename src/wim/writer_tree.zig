const std = @import("std");
const core = @import("../core.zig");
const metadata = @import("metadata.zig");
const streams = @import("writer_streams.zig");
const tagged = @import("tagged.zig");

pub const Error = core.Error || std.mem.Allocator.Error || error{
    InvalidWimEntry,
};

pub const EntryKind = enum {
    file,
    directory,
};

pub const NamedStream = streams.NamedStream;
pub const ReparseData = streams.ReparseData;

pub const TaggedItem = tagged.Item;

/// A borrowed entry description.  The writer never takes ownership of `path`
/// or `data`; both only need to remain valid for the duration of encode*().
pub const Entry = struct {
    path: []const u8,
    kind: EntryKind = .file,
    data: []const u8 = &.{},
    named_streams: []const NamedStream = &.{},
    reparse: ?ReparseData = null,
    encrypted_raw: ?[]const u8 = null,
    security_descriptor: ?[]const u8 = null,
    short_name: ?[]const u8 = null,
    tagged_items: []const TaggedItem = &.{},
    hard_link_id: u64 = 0,
    attributes: u32 = 0,
    creation_time: u64 = 0,
    last_access_time: u64 = 0,
    last_write_time: u64 = 0,
};

pub const RootInfo = struct {
    creation_time: u64 = 0,
    last_access_time: u64 = 0,
    last_write_time: u64 = 0,
    security_descriptor: ?[]const u8 = null,
    tagged_items: []const TaggedItem = &.{},
};

pub const Node = struct {
    path: []u8,
    name_utf16le: []u16,
    kind: EntryKind,
    data: []const u8 = &.{},
    named_streams: []const NamedStream = &.{},
    reparse: ?ReparseData = null,
    encrypted_raw: ?[]const u8 = null,
    security_descriptor: ?[]const u8 = null,
    short_name: ?[]const u8 = null,
    short_name_utf16le: ?[]u16 = null,
    tagged_items: []const TaggedItem = &.{},
    security_id: ?u32 = null,
    hard_link_id: u64 = 0,
    attributes: u32,
    creation_time: u64 = 0,
    last_access_time: u64 = 0,
    last_write_time: u64 = 0,
    explicit: bool = false,
    parent: usize = 0,
    subdir_offset: usize = 0,

    pub fn name(self: Node) []const u8 {
        const slash = std.mem.lastIndexOfScalar(u8, self.path, '/') orelse
            return self.path;
        return self.path[slash + 1 ..];
    }

    pub fn streamSet(self: Node) streams.Set {
        return .{
            .directory = self.kind == .directory,
            .default_data = self.data,
            .named = self.named_streams,
            .reparse = self.reparse,
            .encrypted_raw = self.encrypted_raw,
        };
    }
};

pub const Tree = struct {
    allocator: std.mem.Allocator,
    nodes: []Node,

    pub fn deinit(self: *Tree) void {
        for (self.nodes) |node| {
            if (node.short_name_utf16le) |short_name|
                self.allocator.free(short_name);
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

    pub fn totalStreamBytes(self: Tree) Error!u64 {
        var total: u64 = 0;
        for (self.nodes) |node| {
            total = std.math.add(u64, total, try node.streamSet().totalBytes()) catch
                return error.IntegerOverflow;
        }
        return total;
    }

    pub fn hardLinkBytes(self: Tree) Error!u64 {
        var total: u64 = 0;
        for (self.nodes, 0..) |node, index| {
            if (node.hard_link_id == 0) continue;
            var seen_before = false;
            for (self.nodes[0..index]) |prior| {
                if (prior.hard_link_id == node.hard_link_id) {
                    seen_before = true;
                    break;
                }
            }
            if (seen_before) continue;
            var count: usize = 0;
            for (self.nodes) |candidate|
                count += @intFromBool(candidate.hard_link_id == node.hard_link_id);
            const duplicate_count = count - 1;
            const stream_bytes = try node.streamSet().totalBytes();
            const duplicated = std.math.mul(u64, stream_bytes, duplicate_count) catch
                return error.IntegerOverflow;
            total = std.math.add(u64, total, duplicated) catch
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
    nodes.items[0].security_descriptor = root_info.security_descriptor;
    try validateTaggedItems(root_info.tagged_items);
    nodes.items[0].tagged_items = root_info.tagged_items;

    for (entries) |entry| {
        try validateEntry(entry);
        try ensureParents(allocator, &nodes, entry.path);
        if (findNode(nodes.items, entry.path)) |index| {
            if (nodes.items[index].explicit or entry.kind != .directory)
                return error.InvalidWimEntry;
            try applyEntry(allocator, &nodes.items[index], entry);
        } else {
            try appendNode(allocator, &nodes, entry.path, entry.kind, true);
            try applyEntry(allocator, &nodes.items[nodes.items.len - 1], entry);
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
    try rejectNameAliases(nodes.items);
    try validateHardLinkGroups(nodes.items);

    return .{
        .allocator = allocator,
        .nodes = try nodes.toOwnedSlice(allocator),
    };
}

fn deinitNodes(allocator: std.mem.Allocator, nodes: *std.ArrayList(Node)) void {
    for (nodes.items) |node| {
        if (node.short_name_utf16le) |short_name|
            allocator.free(short_name);
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

fn applyEntry(
    allocator: std.mem.Allocator,
    node: *Node,
    entry: Entry,
) Error!void {
    var short_name_utf16le: ?[]u16 = null;
    if (entry.short_name) |short_name| {
        if (short_name.len == 0 or std.mem.eql(u8, short_name, ".") or
            std.mem.eql(u8, short_name, "..") or
            std.mem.indexOfAny(u8, short_name, "/\\\x00") != null)
            return error.InvalidWimEntry;
        const units = std.unicode.utf8ToUtf16LeAlloc(allocator, short_name) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            error.InvalidUtf8 => return error.InvalidWimEntry,
        };
        errdefer allocator.free(units);
        if (units.len == 0 or units.len > 12)
            return error.InvalidWimEntry;
        short_name_utf16le = units;
    }
    node.kind = entry.kind;
    node.data = entry.data;
    node.named_streams = entry.named_streams;
    node.reparse = entry.reparse;
    node.encrypted_raw = entry.encrypted_raw;
    node.security_descriptor = entry.security_descriptor;
    node.short_name = entry.short_name;
    node.short_name_utf16le = short_name_utf16le;
    node.tagged_items = entry.tagged_items;
    node.hard_link_id = entry.hard_link_id;
    node.attributes = entry.attributes;
    if (entry.kind == .directory) {
        node.attributes |= metadata.file_attribute_directory;
    } else if (node.attributes == 0 and entry.reparse == null and
        entry.encrypted_raw == null)
    {
        node.attributes = 0x0000_0080;
    }
    if (entry.reparse != null)
        node.attributes |= metadata.file_attribute_reparse_point;
    if (entry.encrypted_raw != null)
        node.attributes |= metadata.file_attribute_encrypted;
    node.creation_time = entry.creation_time;
    node.last_access_time = entry.last_access_time;
    node.last_write_time = entry.last_write_time;
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
    try appendNode(allocator, nodes, parent_path, .directory, false);
}

fn findNode(nodes: []const Node, path: []const u8) ?usize {
    for (nodes, 0..) |node, index|
        if (std.mem.eql(u8, node.path, path)) return index;
    return null;
}

fn rejectNameAliases(nodes: []const Node) Error!void {
    for (nodes, 0..) |left, left_index| {
        if (left_index == 0) continue;
        for (nodes[left_index + 1 ..]) |right| {
            if (left.parent != right.parent) continue;
            if (std.ascii.eqlIgnoreCase(left.name(), right.name()) or
                optionalNameEqual(left.short_name, right.short_name) or
                optionalNameEquals(left.short_name, right.name()) or
                optionalNameEquals(right.short_name, left.name()))
                return error.InvalidWimEntry;
        }
    }
}

fn optionalNameEqual(left: ?[]const u8, right: ?[]const u8) bool {
    if (left == null or right == null) return false;
    return std.ascii.eqlIgnoreCase(left.?, right.?);
}

fn optionalNameEquals(left: ?[]const u8, right: []const u8) bool {
    return if (left) |name| std.ascii.eqlIgnoreCase(name, right) else false;
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
    if (entry.kind == .file and
        entry.attributes & metadata.file_attribute_directory != 0)
        return error.InvalidWimEntry;
    if (entry.attributes &
        (metadata.file_attribute_reparse_point | metadata.file_attribute_encrypted) != 0)
        return error.InvalidWimEntry;
    try validateTaggedItems(entry.tagged_items);
    try (streams.Set{
        .directory = entry.kind == .directory,
        .default_data = entry.data,
        .named = entry.named_streams,
        .reparse = entry.reparse,
        .encrypted_raw = entry.encrypted_raw,
    }).validate();
    if (entry.hard_link_id != 0 and
        (entry.kind != .file or entry.reparse != null or entry.encrypted_raw != null))
        return error.InvalidWimEntry;
    var components = std.mem.splitScalar(u8, entry.path, '/');
    while (components.next()) |component| {
        if (component.len == 0 or std.mem.eql(u8, component, ".") or
            std.mem.eql(u8, component, "..") or
            std.mem.indexOfAny(u8, component, "\\\x00") != null)
            return error.InvalidWimEntry;
    }
}

fn validateTaggedItems(items: []const TaggedItem) Error!void {
    for (items) |item|
        if (item.data.len > std.math.maxInt(u32))
            return error.InvalidWimEntry;
}

fn validateHardLinkGroups(nodes: []const Node) Error!void {
    for (nodes, 0..) |node, index| {
        if (node.hard_link_id == 0) continue;
        var seen_before = false;
        for (nodes[0..index]) |prior| {
            if (prior.hard_link_id == node.hard_link_id) {
                seen_before = true;
                break;
            }
        }
        if (seen_before) continue;

        var count: usize = 0;
        for (nodes[index..]) |candidate| {
            if (candidate.hard_link_id != node.hard_link_id) continue;
            count += 1;
            if (!sameInode(node, candidate)) return error.InvalidWimEntry;
        }
        if (count < 2) return error.InvalidWimEntry;
    }
}

fn sameInode(left: Node, right: Node) bool {
    if (left.kind != right.kind or left.attributes != right.attributes or
        left.creation_time != right.creation_time or
        left.last_access_time != right.last_access_time or
        left.last_write_time != right.last_write_time or
        !optionalBytesEqual(left.security_descriptor, right.security_descriptor) or
        !std.mem.eql(u8, left.data, right.data) or
        left.named_streams.len != right.named_streams.len or
        !taggedItemsEqual(left.tagged_items, right.tagged_items))
        return false;
    for (left.named_streams, right.named_streams) |left_stream, right_stream| {
        if (!std.mem.eql(u8, left_stream.name, right_stream.name) or
            !std.mem.eql(u8, left_stream.data, right_stream.data))
            return false;
    }
    return true;
}

fn taggedItemsEqual(left: []const TaggedItem, right: []const TaggedItem) bool {
    if (left.len != right.len) return false;
    for (left, right) |left_item, right_item|
        if (left_item.tag != right_item.tag or
            !std.mem.eql(u8, left_item.data, right_item.data))
            return false;
    return true;
}

fn optionalBytesEqual(left: ?[]const u8, right: ?[]const u8) bool {
    if (left == null or right == null) return left == null and right == null;
    return std.mem.eql(u8, left.?, right.?);
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
