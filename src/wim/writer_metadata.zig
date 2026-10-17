const std = @import("std");
const core = @import("../core.zig");
const metadata = @import("metadata.zig");
const tree_mod = @import("writer_tree.zig");

pub const Error = core.Error || tree_mod.Error || std.mem.Allocator.Error || error{
    InvalidWimEntry,
};

const security_data_size: usize = 8;
const list_terminator_size: usize = 8;

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    tree: *tree_mod.Tree,
) Error![]u8 {
    if (tree.nodes.len == 0 or tree.nodes[0].path.len != 0 or
        tree.nodes[0].kind != .directory)
        return error.InvalidWimEntry;

    const root_len = try dentryLength(tree.nodes[0]);
    var cursor = try checkedAdd(security_data_size, root_len);
    cursor = try checkedAdd(cursor, list_terminator_size);

    for (tree.nodes, 0..) |*directory, directory_index| {
        if (directory.kind != .directory) continue;
        var child_count: usize = 0;
        var list_size: usize = list_terminator_size;
        for (tree.nodes, 0..) |child, child_index| {
            if (child_index == directory_index or child.parent != directory_index)
                continue;
            child_count += 1;
            list_size = try checkedAdd(list_size, try dentryLength(child));
        }
        if (child_count == 0) {
            directory.subdir_offset = 0;
            continue;
        }
        directory.subdir_offset = cursor;
        cursor = try checkedAdd(cursor, list_size);
    }

    const output = try allocator.alloc(u8, cursor);
    errdefer allocator.free(output);
    @memset(output, 0);
    var output_offset = security_data_size;
    output_offset = try writeDentry(output, output_offset, tree.nodes[0]);
    output_offset = try checkedAdd(output_offset, list_terminator_size);

    for (tree.nodes, 0..) |directory, directory_index| {
        if (directory.kind != .directory or directory.subdir_offset == 0)
            continue;
        if (output_offset != directory.subdir_offset)
            return error.InvalidWimEntry;
        for (tree.nodes, 0..) |child, child_index| {
            if (child_index == directory_index or child.parent != directory_index)
                continue;
            output_offset = try writeDentry(output, output_offset, child);
        }
        output_offset = try checkedAdd(output_offset, list_terminator_size);
    }
    if (output_offset != output.len) return error.InvalidWimEntry;
    return output;
}

fn dentryLength(node: tree_mod.Node) Error!usize {
    const name_bytes = std.math.mul(usize, node.name_utf16le.len, 2) catch
        return error.IntegerOverflow;
    var length = try checkedAdd(metadata.dentry_fixed_size, name_bytes);
    if (name_bytes != 0) length = try checkedAdd(length, 2);
    return align8(length);
}

fn writeDentry(
    output: []u8,
    offset: usize,
    node: tree_mod.Node,
) Error!usize {
    if (offset & 7 != 0) return error.InvalidWimEntry;
    const length = try dentryLength(node);
    const end = try checkedAdd(offset, length);
    if (end > output.len) return error.InvalidWimEntry;
    const name_bytes = std.math.mul(usize, node.name_utf16le.len, 2) catch
        return error.IntegerOverflow;
    if (name_bytes > std.math.maxInt(u16)) return error.InvalidWimEntry;

    writeU64(output, offset, length);
    writeU32(output, offset + 8, node.attributes);
    writeU32(output, offset + 12, std.math.maxInt(u32));
    writeU64(output, offset + 16, node.subdir_offset);
    writeU64(output, offset + 40, node.creation_time);
    writeU64(output, offset + 48, node.last_access_time);
    writeU64(output, offset + 56, node.last_write_time);
    @memcpy(output[offset + 64 .. offset + 84], &node.sha1);
    writeU16(output, offset + 96, 0);
    writeU16(output, offset + 98, 0);
    writeU16(output, offset + 100, @intCast(name_bytes));
    for (node.name_utf16le, 0..) |unit, index|
        writeU16(output, offset + metadata.dentry_fixed_size + index * 2, unit);
    return end;
}

fn align8(value: usize) Error!usize {
    const with_padding = std.math.add(usize, value, 7) catch
        return error.IntegerOverflow;
    return with_padding & ~@as(usize, 7);
}

fn checkedAdd(left: usize, right: usize) Error!usize {
    return std.math.add(usize, left, right) catch error.IntegerOverflow;
}

fn writeU16(output: []u8, offset: usize, value: u16) void {
    std.mem.writeInt(u16, output[offset..][0..2], value, .little);
}

fn writeU32(output: []u8, offset: usize, value: u32) void {
    std.mem.writeInt(u32, output[offset..][0..4], value, .little);
}

fn writeU64(output: []u8, offset: usize, value: anytype) void {
    std.mem.writeInt(u64, output[offset..][0..8], @intCast(value), .little);
}

test "WIM writer metadata encodes a real deterministic directory tree" {
    const allocator = std.testing.allocator;
    const entries = [_]tree_mod.Entry{
        .{ .path = "nested/文件.txt", .data = "payload" },
        .{ .path = "empty.bin", .data = "" },
    };
    var tree = try tree_mod.build(allocator, &entries, .{});
    defer tree.deinit();
    const bytes = try encodeAlloc(allocator, &tree);
    var image = try metadata.ImageMetadata.fromOwnedBytes(allocator, bytes);
    defer image.deinit();
    try std.testing.expect(image.root.subdir_offset != 0);
    const nested = try image.lookup(allocator, "/nested/文件.txt", 8, 8);
    var expected_hash: [20]u8 = undefined;
    std.crypto.hash.Sha1.hash("payload", &expected_hash, .{});
    try std.testing.expectEqual(expected_hash, (try nested.defaultDataSha1()).?);
    const empty = try image.lookup(allocator, "empty.bin", 8, 8);
    try std.testing.expect(std.mem.allEqual(u8, &(try empty.defaultDataSha1()).?, 0));
}
