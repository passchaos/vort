const std = @import("std");
const tree = @import("tree.zig");
const format = @import("../format.zig");
const math = @import("math.zig");
pub const Error = tree.Error || math.Error;
const EntryKind = tree.EntryKind;
const block_size: usize = 4096;
const checkedAdd = math.checkedAdd;
const checkedMul = math.checkedMul;
const alignForward = math.alignForward;

pub fn allocateDirectoryBuffers(filesystem: *tree.Tree) Error!void {
    for (filesystem.nodes, 0..) |*node, node_index| {
        if (node.kind != .directory) continue;
        const size = try directorySize(filesystem.nodes, node_index);
        node.directory_data = try filesystem.allocator.alloc(u8, size);
        @memset(node.directory_data.?, 0);
    }
}

/// Reserve directory blocks in primary metadata storage. Inline tails stay
/// adjacent to their inode in its primary/metabox metadata address space.
pub fn placeMetadataData(filesystem: *tree.Tree, start: usize) Error!usize {
    var cursor = start;
    for (filesystem.nodes) |*node| {
        if (node.kind != .directory) continue;
        const layout = std.enums.fromInt(format.Layout, node.layout) orelse return error.InvalidErofs;
        if (layout != .flat_plain and layout != .flat_inline) return error.InvalidErofs;
        const size = if (layout == .flat_inline) node.contentSize() / block_size * block_size else node.contentSize();
        node.directory_in_metadata_zone = true;
        if (size == 0) continue;
        cursor = try alignForward(cursor, block_size);
        node.start_block = std.math.cast(u32, cursor / block_size) orelse return error.InvalidErofs;
        cursor = try checkedAdd(cursor, try alignForward(size, block_size));
    }
    return cursor;
}

fn directorySize(nodes: []const tree.Node, directory_index: usize) Error!usize {
    var total: usize = 0;
    var used: usize = 0;
    try accountDirectoryEntry(&total, &used, 2);
    for (nodes, 0..) |node, node_index| {
        if (node.hidden or node_index == directory_index or node.parent != directory_index)
            continue;
        try accountDirectoryEntry(&total, &used, node.name().len);
    }
    return total;
}

fn accountDirectoryEntry(total: *usize, used: *usize, name_len: usize) Error!void {
    const item_size = try checkedAdd(12, name_len);
    if (item_size > block_size) return error.InvalidErofs;
    if (used.* != 0 and try checkedAdd(used.*, item_size) > block_size) {
        total.* = try alignForward(total.*, block_size);
        used.* = 0;
    }
    total.* = try checkedAdd(total.*, item_size);
    used.* = try checkedAdd(used.*, item_size);
}

const DirectoryReference = struct {
    nid: u64,
    name: []const u8,
    file_type: format.FileType,
};

pub fn fillDirectories(allocator: std.mem.Allocator, filesystem: *tree.Tree) Error!void {
    for (filesystem.nodes, 0..) |*directory, directory_index| {
        if (directory.kind != .directory) continue;
        var references: std.ArrayList(DirectoryReference) = .empty;
        defer references.deinit(allocator);
        try references.append(allocator, .{
            .nid = filesystem.nodes[directory.parent].nid,
            .name = "..",
            .file_type = .directory,
        });
        for (filesystem.nodes, 0..) |node, node_index| {
            if (node.hidden or node_index == directory_index or node.parent != directory_index)
                continue;
            try references.append(allocator, .{
                .nid = node.nid,
                .name = node.name(),
                .file_type = fileType(node.kind),
            });
        }
        try fillDirectory(directory.directory_data.?, references.items);
    }
}

fn fillDirectory(output: []u8, references: []const DirectoryReference) Error!void {
    var entry_index: usize = 0;
    var block_start: usize = 0;
    while (entry_index < references.len) {
        const group_start = entry_index;
        var group_size: usize = 0;
        while (entry_index < references.len) {
            const item_size = try checkedAdd(12, references[entry_index].name.len);
            if (group_size != 0 and try checkedAdd(group_size, item_size) > block_size)
                break;
            group_size = try checkedAdd(group_size, item_size);
            entry_index += 1;
        }
        const entry_count = entry_index - group_start;
        var name_offset = try checkedMul(entry_count, 12);
        for (references[group_start..entry_index], 0..) |reference, index| {
            if (name_offset > std.math.maxInt(u16))
                return error.InvalidErofs;
            const entry_offset = try checkedAdd(block_start, try checkedMul(index, 12));
            writeU64(output, entry_offset, reference.nid);
            writeU16(output, entry_offset + 8, @intCast(name_offset));
            output[entry_offset + 10] = @intFromEnum(reference.file_type);
            const name_start = try checkedAdd(block_start, name_offset);
            const name_end = try checkedAdd(name_start, reference.name.len);
            if (name_end > output.len) return error.InvalidErofs;
            @memcpy(output[name_start..name_end], reference.name);
            name_offset = try checkedAdd(name_offset, reference.name.len);
        }
        if (entry_index == references.len) {
            if (try checkedAdd(block_start, group_size) != output.len)
                return error.InvalidErofs;
        } else {
            block_start = try checkedAdd(block_start, block_size);
            if (block_start >= output.len) return error.InvalidErofs;
        }
    }
}

fn fileType(kind: EntryKind) format.FileType {
    return switch (kind) {
        .file => .regular,
        .directory => .directory,
        .symlink => .symlink,
    };
}

fn writeU64(output: []u8, offset: usize, value: u64) void {
    std.mem.writeInt(u64, output[offset..][0..8], value, .little);
}

fn writeU16(output: []u8, offset: usize, value: u16) void {
    std.mem.writeInt(u16, output[offset..][0..2], value, .little);
}
