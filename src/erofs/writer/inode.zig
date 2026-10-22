const std = @import("std");
const format = @import("../format.zig");
const tree = @import("tree.zig");
const xattr = @import("../xattr.zig");

pub const Error = format.Error || tree.Error || xattr.Error;
pub const Version = enum { compact, extended, automatic };

pub fn planVersions(
    filesystem: *tree.Tree,
    policy: Version,
    epoch: u64,
    fixed_nsec: u32,
) Error!void {
    for (filesystem.nodes, 0..) |*node, node_index| {
        const effective_nsec = node.modification_nsec orelse fixed_nsec;
        if (effective_nsec >= 1_000_000_000) return error.InvalidErofs;
        _ = std.math.add(u64, epoch, node.modification_time) catch
            return error.InvalidErofs;
        node.link_count = try linkCount(filesystem.nodes, node_index);
        const compact_ok = node.contentSize() <= std.math.maxInt(u32) and
            node.uid <= std.math.maxInt(u16) and
            node.gid <= std.math.maxInt(u16) and
            node.modification_time <= std.math.maxInt(u32) and
            effective_nsec == fixed_nsec and
            node.link_count <= std.math.maxInt(u16);
        node.inode_size = switch (policy) {
            .compact => if (compact_ok)
                format.inode_slot_size
            else
                return error.InvalidErofs,
            .extended => format.inode_slot_size * 2,
            .automatic => if (compact_ok)
                format.inode_slot_size
            else
                format.inode_slot_size * 2,
        };
    }
}

pub fn writeHeader(
    metadata: []u8,
    node: *const tree.Node,
    node_index: usize,
    epoch: u64,
    fixed_nsec: u32,
) Error!void {
    const location = node.location;
    if (try checkedAdd(location, node.inode_size) > metadata.len)
        return error.InvalidErofs;
    const layout = std.enums.fromInt(format.Layout, node.layout) orelse
        return error.InvalidErofs;
    const extended = node.inode_size == format.inode_slot_size * 2;
    if (!extended and node.inode_size != format.inode_slot_size)
        return error.InvalidErofs;
    const inode_format: u16 = (if (extended) @as(u16, 1) else 0) |
        (@as(u16, @intFromEnum(layout)) << 1) |
        (if (node.kind == .directory) @as(u16, 1 << 4) else 0);
    writeU16(metadata, location, inode_format);
    writeU16(metadata, location + 2, try xattr.ibodyIcount(node.xattr_size));
    writeU16(metadata, location + 4, mode(node.*));
    const data_value: u32 = if (layout == .compressed_full)
        @intCast(node.compressed_block_count)
    else if (layout == .chunk_based)
        0
    else
        node.start_block;
    if (node_index + 1 > std.math.maxInt(u32)) return error.InvalidErofs;
    if (extended) {
        writeU16(metadata, location + 6, 0);
        writeU64(metadata, location + 8, @intCast(node.contentSize()));
        writeU32(metadata, location + 16, data_value);
        writeU32(metadata, location + 20, @intCast(node_index + 1));
        writeU32(metadata, location + 24, node.uid);
        writeU32(metadata, location + 28, node.gid);
        writeU64(
            metadata,
            location + 32,
            std.math.add(u64, epoch, node.modification_time) catch
                return error.InvalidErofs,
        );
        writeU32(metadata, location + 40, node.modification_nsec orelse fixed_nsec);
        writeU32(metadata, location + 44, node.link_count);
        @memset(metadata[location + 48 .. location + 64], 0);
    } else {
        if (node.link_count > std.math.maxInt(u16) or
            node.contentSize() > std.math.maxInt(u32) or
            node.modification_time > std.math.maxInt(u32) or
            node.uid > std.math.maxInt(u16) or node.gid > std.math.maxInt(u16))
            return error.InvalidErofs;
        writeU16(metadata, location + 6, @intCast(node.link_count));
        writeU32(metadata, location + 8, @intCast(node.contentSize()));
        writeU32(metadata, location + 12, @intCast(node.modification_time));
        writeU32(metadata, location + 16, data_value);
        writeU32(metadata, location + 20, @intCast(node_index + 1));
        writeU16(metadata, location + 24, @intCast(node.uid));
        writeU16(metadata, location + 26, @intCast(node.gid));
        writeU32(metadata, location + 28, 0);
    }
}

fn linkCount(nodes: []const tree.Node, node_index: usize) Error!u32 {
    if (nodes[node_index].kind != .directory) return 1;
    var count: usize = 2;
    for (nodes, 0..) |node, index| {
        if (index != node_index and node.parent == node_index and node.kind == .directory)
            count = try checkedAdd(count, 1);
    }
    if (count > std.math.maxInt(u32)) return error.InvalidErofs;
    return @intCast(count);
}

fn mode(node: tree.Node) u16 {
    const file_mode: u16 = switch (node.kind) {
        .file => 0x8000,
        .directory => 0x4000,
        .symlink => 0xa000,
    };
    return file_mode | (node.mode & 0x0fff);
}

fn checkedAdd(left: usize, right: usize) Error!usize {
    return std.math.add(usize, left, right) catch return error.IntegerOverflow;
}

fn writeU16(output: []u8, offset: usize, value: u16) void {
    std.mem.writeInt(u16, output[offset..][0..2], value, .little);
}

fn writeU32(output: []u8, offset: usize, value: u32) void {
    std.mem.writeInt(u32, output[offset..][0..4], value, .little);
}

fn writeU64(output: []u8, offset: usize, value: u64) void {
    std.mem.writeInt(u64, output[offset..][0..8], value, .little);
}
