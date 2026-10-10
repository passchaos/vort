const std = @import("std");
const core = @import("../core.zig");
const lz4 = @import("../lz4.zig");
const format = @import("format.zig");
const tree = @import("writer_tree.zig");

pub const Error = core.Error || lz4.Error || tree.Error || error{InvalidErofs};

pub const Entry = tree.Entry;
pub const EntryKind = tree.EntryKind;

pub const Compression = enum {
    stored,
    lz4,
};

pub const Options = struct {
    compression: Compression = .stored,
    volume_name: []const u8 = "vort",
    epoch: u64 = 0,
    fixed_nsec: u32 = 0,
    build_time: u32 = 0,
};

const block_size: usize = 4096;
const block_bits: u8 = 12;
const metadata_start = format.super_offset + format.super_base_size;
const no_block = std.math.maxInt(u32);

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    entries: []const Entry,
    options: Options,
) Error![]u8 {
    if (options.volume_name.len > 16 or options.fixed_nsec >= 1_000_000_000)
        return error.InvalidErofs;

    var filesystem = try tree.build(allocator, entries);
    defer filesystem.deinit();
    try allocateDirectoryBuffers(&filesystem);
    const metadata_end = try planMetadata(allocator, &filesystem, options.compression);
    try fillDirectories(allocator, &filesystem);

    const first_data_block = try alignForward(metadata_end, block_size) / block_size;
    const block_count = try assignDataBlocks(&filesystem, first_data_block);
    const image_len = try checkedMul(block_count, block_size);
    const image = try allocator.alloc(u8, image_len);
    errdefer allocator.free(image);
    @memset(image, 0);

    var block_encoder: ?lz4.BlockEncoder = if (options.compression == .lz4)
        try lz4.BlockEncoder.init(allocator)
    else
        null;
    defer if (block_encoder) |*encoder| encoder.deinit();

    try writeNodes(image, &filesystem, if (block_encoder) |*encoder| encoder else null);
    try writeSuperblock(image, filesystem.nodes, block_count, options);
    return image;
}

fn allocateDirectoryBuffers(filesystem: *tree.Tree) Error!void {
    for (filesystem.nodes, 0..) |*node, node_index| {
        if (node.kind != .directory) continue;
        const size = try directorySize(filesystem.nodes, node_index);
        node.directory_data = try filesystem.allocator.alloc(u8, size);
        @memset(node.directory_data.?, 0);
    }
}

fn directorySize(nodes: []const tree.Node, directory_index: usize) Error!usize {
    var total: usize = 0;
    var used: usize = 0;
    try accountDirectoryEntry(&total, &used, 2);
    for (nodes, 0..) |node, node_index| {
        if (node_index == directory_index or node.parent != directory_index) continue;
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

fn planMetadata(
    allocator: std.mem.Allocator,
    filesystem: *tree.Tree,
    compression: Compression,
) Error!usize {
    var cursor: usize = metadata_start;
    for (filesystem.nodes) |*node| {
        if (node.content().len > std.math.maxInt(u32)) return error.InvalidErofs;
        const location = try alignForward(cursor, format.inode_slot_size);
        const inode_end = try checkedAdd(location, format.inode_slot_size);
        node.location = location;
        node.nid = location / format.inode_slot_size;
        node.start_block = no_block;

        if (compression == .lz4 and node.kind == .file and node.data.len != 0) {
            node.layout = @intFromEnum(format.Layout.compressed_full);
            const cluster_count = try blockCount(node.data.len);
            node.compressed_indexes = try allocator.alloc(tree.Node.CompressionIndex, cluster_count);
            @memset(node.compressed_indexes.?, .{ .kind = 0, .physical_block = 0 });
            cursor = try checkedAdd(inode_end, try checkedAdd(16, try checkedMul(cluster_count, 8)));
            continue;
        }

        const tail_len = node.content().len % block_size;
        const inline_end = try checkedAdd(inode_end, tail_len);
        if (tail_len != 0 and
            inode_end / block_size == (inline_end - 1) / block_size)
        {
            node.layout = @intFromEnum(format.Layout.flat_inline);
            cursor = inline_end;
        } else {
            node.layout = @intFromEnum(format.Layout.flat_plain);
            cursor = inode_end;
        }
    }
    const root_nid = filesystem.nodes[0].nid;
    if (filesystem.nodes[0].path.len != 0 or root_nid > std.math.maxInt(u16))
        return error.InvalidErofs;
    return cursor;
}

const DirectoryReference = struct {
    nid: u64,
    name: []const u8,
    file_type: format.FileType,
};

fn fillDirectories(allocator: std.mem.Allocator, filesystem: *tree.Tree) Error!void {
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
            if (node_index == directory_index or node.parent != directory_index) continue;
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
            if (reference.nid >> 63 != 0 or name_offset > std.math.maxInt(u16))
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

fn assignDataBlocks(filesystem: *tree.Tree, first_data_block: usize) Error!usize {
    var next_block = first_data_block;
    for (filesystem.nodes) |*node| {
        const content_len = node.content().len;
        const blocks = switch (std.enums.fromInt(format.Layout, node.layout) orelse
            return error.InvalidErofs) {
            .compressed_full => try blockCount(content_len),
            .flat_inline => content_len / block_size,
            .flat_plain => try blockCount(content_len),
            else => return error.InvalidErofs,
        };
        if (blocks == 0) continue;
        if (next_block > std.math.maxInt(u32)) return error.InvalidErofs;
        node.start_block = @intCast(next_block);
        if (node.compressed_indexes) |indexes| {
            if (indexes.len != blocks) return error.InvalidErofs;
            for (indexes, 0..) |*index, cluster_index| {
                const physical = try checkedAdd(next_block, cluster_index);
                if (physical > std.math.maxInt(u32)) return error.InvalidErofs;
                index.physical_block = @intCast(physical);
            }
        }
        next_block = try checkedAdd(next_block, blocks);
    }
    if (next_block == 0 or next_block > std.math.maxInt(u32))
        return error.InvalidErofs;
    return next_block;
}

fn writeNodes(
    image: []u8,
    filesystem: *tree.Tree,
    block_encoder: ?*lz4.BlockEncoder,
) Error!void {
    for (filesystem.nodes, 0..) |*node, node_index| {
        const layout = std.enums.fromInt(format.Layout, node.layout) orelse
            return error.InvalidErofs;
        if (layout == .compressed_full) {
            const encoder = block_encoder orelse return error.InvalidErofs;
            try writeCompressedData(image, node, encoder);
        } else {
            try writeFlatData(image, node, layout);
        }
        try writeInode(image, filesystem.nodes, node, node_index);
    }
}

fn writeFlatData(image: []u8, node: *const tree.Node, layout: format.Layout) Error!void {
    const content = node.content();
    const data_len = if (layout == .flat_inline)
        content.len / block_size * block_size
    else
        content.len;
    if (data_len != 0) {
        if (node.start_block == no_block) return error.InvalidErofs;
        const data_start = try checkedMul(node.start_block, block_size);
        const data_end = try checkedAdd(data_start, data_len);
        if (data_end > image.len) return error.InvalidErofs;
        @memcpy(image[data_start..data_end], content[0..data_len]);
    }
    if (layout == .flat_inline and data_len < content.len) {
        const inline_start = try checkedAdd(node.location, format.inode_slot_size);
        const inline_end = try checkedAdd(inline_start, content.len - data_len);
        if (inline_end > image.len or inline_start / block_size != (inline_end - 1) / block_size)
            return error.InvalidErofs;
        @memcpy(image[inline_start..inline_end], content[data_len..]);
    }
}

fn writeCompressedData(
    image: []u8,
    node: *tree.Node,
    encoder: *lz4.BlockEncoder,
) Error!void {
    const indexes = node.compressed_indexes orelse return error.InvalidErofs;
    for (indexes, 0..) |*index, cluster_index| {
        const logical_start = try checkedMul(cluster_index, block_size);
        const logical_end = @min(node.data.len, try checkedAdd(logical_start, block_size));
        const chunk = node.data[logical_start..logical_end];
        const physical_start = try checkedMul(index.physical_block, block_size);
        const physical_end = try checkedAdd(physical_start, block_size);
        if (physical_end > image.len) return error.InvalidErofs;
        const encoded = try encoder.encodeScratch(chunk);
        if (encoded.len < chunk.len) {
            index.kind = 1;
            const encoded_start = physical_end - encoded.len;
            @memcpy(image[encoded_start..physical_end], encoded);
        } else {
            index.kind = 0;
            @memcpy(image[physical_start..][0..chunk.len], chunk);
        }
    }
}

fn writeInode(
    image: []u8,
    nodes: []const tree.Node,
    node: *const tree.Node,
    node_index: usize,
) Error!void {
    const location = node.location;
    if (try checkedAdd(location, format.inode_slot_size) > image.len)
        return error.InvalidErofs;
    const layout = std.enums.fromInt(format.Layout, node.layout) orelse
        return error.InvalidErofs;
    const inode_format: u16 = (@as(u16, @intFromEnum(layout)) << 1) |
        (if (node.kind == .directory) @as(u16, 1 << 4) else 0);
    writeU16(image, location, inode_format);
    writeU16(image, location + 2, 0);
    writeU16(image, location + 4, mode(node.*));
    writeU16(image, location + 6, try linkCount(nodes, node_index));
    writeU32(image, location + 8, @intCast(node.content().len));
    writeU32(image, location + 12, node.modification_time);
    const data_value: u32 = if (layout == .compressed_full)
        @intCast(node.compressed_indexes.?.len)
    else
        node.start_block;
    writeU32(image, location + 16, data_value);
    if (node_index + 1 > std.math.maxInt(u32)) return error.InvalidErofs;
    writeU32(image, location + 20, @intCast(node_index + 1));
    writeU16(image, location + 24, 0);
    writeU16(image, location + 26, 0);
    writeU32(image, location + 28, 0);

    if (layout == .compressed_full) {
        const header_start = try alignForward(location + format.inode_slot_size, 8);
        const index_start = try checkedAdd(header_start, 16);
        if (try checkedAdd(index_start, try checkedMul(node.compressed_indexes.?.len, 8)) > image.len)
            return error.InvalidErofs;
        writeU16(image, header_start + 4, 0);
        image[header_start + 6] = @intFromEnum(format.Compression.lz4);
        image[header_start + 7] = 0;
        for (node.compressed_indexes.?, 0..) |index, cluster_index| {
            const offset = index_start + cluster_index * 8;
            writeU16(image, offset, index.kind);
            writeU16(image, offset + 2, 0);
            writeU32(image, offset + 4, index.physical_block);
        }
    }
}

fn writeSuperblock(
    image: []u8,
    nodes: []const tree.Node,
    block_count: usize,
    options: Options,
) Error!void {
    if (image.len < block_size or nodes.len == 0 or nodes.len > std.math.maxInt(u64) or
        block_count > std.math.maxInt(u32) or nodes[0].nid > std.math.maxInt(u16))
        return error.InvalidErofs;
    const base = format.super_offset;
    writeU32(image, base, format.magic);
    writeU32(image, base + 4, 0);
    writeU32(image, base + 8, 0x0000_0003);
    image[base + 12] = block_bits;
    image[base + 13] = 0;
    writeU16(image, base + 14, @intCast(nodes[0].nid));
    writeU64(image, base + 16, @intCast(nodes.len));
    writeU64(image, base + 24, options.epoch);
    writeU32(image, base + 32, options.fixed_nsec);
    writeU32(image, base + 36, @intCast(block_count));
    writeU32(image, base + 40, 0);
    writeU32(image, base + 44, 0);
    @memcpy(image[base + 64 ..][0..options.volume_name.len], options.volume_name);
    if (options.compression == .lz4) {
        writeU32(image, base + 80, 0x0000_0001);
        writeU16(image, base + 84, 0xffff);
    }
    writeU32(image, base + 108, options.build_time);
    writeU32(image, base + 4, format.computeSuperblockChecksum(image[base..block_size]));
}

fn linkCount(nodes: []const tree.Node, node_index: usize) Error!u16 {
    if (nodes[node_index].kind != .directory) return 1;
    var count: usize = 2;
    for (nodes, 0..) |node, index| {
        if (index != node_index and node.parent == node_index and node.kind == .directory)
            count = try checkedAdd(count, 1);
    }
    if (count > std.math.maxInt(u16)) return error.InvalidErofs;
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

fn fileType(kind: EntryKind) format.FileType {
    return switch (kind) {
        .file => .regular,
        .directory => .directory,
        .symlink => .symlink,
    };
}

fn blockCount(length: usize) Error!usize {
    if (length == 0) return 0;
    return try checkedAdd(length, block_size - 1) / block_size;
}

fn checkedAdd(left: usize, right: usize) Error!usize {
    return std.math.add(usize, left, right) catch return error.IntegerOverflow;
}

fn checkedMul(left: usize, right: usize) Error!usize {
    return std.math.mul(usize, left, right) catch return error.IntegerOverflow;
}

fn alignForward(value: usize, alignment: usize) Error!usize {
    if (alignment == 0 or !std.math.isPowerOfTwo(alignment)) return error.InvalidErofs;
    return (try checkedAdd(value, alignment - 1)) & ~(alignment - 1);
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

fn fillPseudoRandom(output: []u8) void {
    var state: u32 = 0x1234_5678;
    for (output) |*byte| {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        byte.* = @truncate(state);
    }
}

test "EROFS writer round trips stored trees deterministically" {
    const archive = @import("archive.zig");
    const allocator = std.testing.allocator;
    var random: [8193]u8 = undefined;
    fillPseudoRandom(&random);
    const repeated = "EROFS writer repeated payload 0123456789\n" ** 300;
    const entries = [_]Entry{
        .{ .path = "small.txt", .data = "small payload\n", .modification_time = 11 },
        .{ .path = "nested", .kind = .directory, .mode = 0o750 },
        .{ .path = "nested/large.bin", .data = repeated },
        .{ .path = "nested/random.bin", .data = &random },
        .{ .path = "nested/link", .kind = .symlink, .target = "../small.txt" },
        .{ .path = "empty", .kind = .directory },
    };
    const first = try encodeAlloc(allocator, &entries, .{ .volume_name = "stored-test" });
    defer allocator.free(first);
    const second = try encodeAlloc(allocator, &entries, .{ .volume_name = "stored-test" });
    defer allocator.free(second);
    try std.testing.expectEqualSlices(u8, first, second);

    const parsed = try archive.Archive.init(first);
    try std.testing.expectEqual(@as(usize, block_size), parsed.superblock.block_size);
    try std.testing.expectEqual(@as(u64, entries.len + 1), parsed.superblock.inode_count);
    var root = try parsed.readDirectoryAlloc(allocator, try parsed.rootInode(), block_size);
    defer root.deinit();
    try std.testing.expectEqual(@as(usize, 3), root.entries.len);
    try std.testing.expect(root.find("empty") != null);
    try std.testing.expect(root.find("nested") != null);
    try std.testing.expect(root.find("small.txt") != null);

    const small = try parsed.extractByPathAllocLimited(
        allocator,
        "small.txt",
        128,
        block_size,
    );
    defer allocator.free(small);
    try std.testing.expectEqualStrings("small payload\n", small);
    const small_inode = try parsed.lookup(allocator, "small.txt", 128, block_size);
    try std.testing.expectEqual(@as(u64, 11), small_inode.modification_time);

    const large = try parsed.extractByPathAllocLimited(
        allocator,
        "nested/large.bin",
        repeated.len,
        block_size,
    );
    defer allocator.free(large);
    try std.testing.expectEqualSlices(u8, repeated, large);
    const random_decoded = try parsed.extractByPathAllocLimited(
        allocator,
        "nested/random.bin",
        random.len,
        block_size,
    );
    defer allocator.free(random_decoded);
    try std.testing.expectEqualSlices(u8, &random, random_decoded);
    const link = try parsed.extractByPathAllocLimited(
        allocator,
        "nested/link",
        128,
        block_size,
    );
    defer allocator.free(link);
    try std.testing.expectEqualStrings("../small.txt", link);
}

test "EROFS LZ4 writer uses compressed and plain full indexes" {
    const archive = @import("archive.zig");
    const allocator = std.testing.allocator;
    var random: [8193]u8 = undefined;
    fillPseudoRandom(&random);
    const repeated = "compress this EROFS logical cluster\n" ** 400;
    const entries = [_]Entry{
        .{ .path = "repeat.bin", .data = repeated },
        .{ .path = "random.bin", .data = &random },
        .{ .path = "tiny.txt", .data = "tiny" },
    };
    const encoded = try encodeAlloc(allocator, &entries, .{
        .compression = .lz4,
        .volume_name = "lz4-test",
    });
    defer allocator.free(encoded);
    const parsed = try archive.Archive.init(encoded);
    try std.testing.expectEqual(@as(u32, 1), parsed.superblock.feature_incompat);

    const repeated_inode = try parsed.lookup(allocator, "repeat.bin", repeated.len, block_size);
    try std.testing.expectEqual(format.Layout.compressed_full, repeated_inode.layout);
    try std.testing.expectEqual(
        @as(u16, 1),
        format.readU16(encoded, repeated_inode.compressed_index_start) & 3,
    );
    const repeated_decoded = try parsed.extractByPathAllocLimited(
        allocator,
        "repeat.bin",
        repeated.len,
        block_size,
    );
    defer allocator.free(repeated_decoded);
    try std.testing.expectEqualSlices(u8, repeated, repeated_decoded);

    const random_inode = try parsed.lookup(allocator, "random.bin", random.len, block_size);
    try std.testing.expectEqual(format.Layout.compressed_full, random_inode.layout);
    try std.testing.expectEqual(
        @as(u16, 0),
        format.readU16(encoded, random_inode.compressed_index_start) & 3,
    );
    const random_decoded = try parsed.extractByPathAllocLimited(
        allocator,
        "random.bin",
        random.len,
        block_size,
    );
    defer allocator.free(random_decoded);
    try std.testing.expectEqualSlices(u8, &random, random_decoded);

    const tiny = try parsed.extractByPathAllocLimited(
        allocator,
        "tiny.txt",
        4,
        block_size,
    );
    defer allocator.free(tiny);
    try std.testing.expectEqualStrings("tiny", tiny);
}

test "EROFS writer rejects unsafe and duplicate paths" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(
        error.InvalidErofs,
        encodeAlloc(allocator, &.{.{ .path = "/absolute" }}, .{}),
    );
    try std.testing.expectError(
        error.InvalidErofs,
        encodeAlloc(allocator, &.{.{ .path = "a/../b" }}, .{}),
    );
    try std.testing.expectError(
        error.InvalidErofs,
        encodeAlloc(allocator, &.{ .{ .path = "same" }, .{ .path = "same" } }, .{}),
    );
    try std.testing.expectError(
        error.InvalidErofs,
        encodeAlloc(allocator, &.{ .{ .path = "parent" }, .{ .path = "parent/child" } }, .{}),
    );
}

test "EROFS writer emits an empty root filesystem" {
    const archive = @import("archive.zig");
    const allocator = std.testing.allocator;
    const encoded = try encodeAlloc(allocator, &.{}, .{});
    defer allocator.free(encoded);
    try std.testing.expectEqual(@as(usize, block_size), encoded.len);
    const parsed = try archive.Archive.init(encoded);
    var root = try parsed.readDirectoryAlloc(allocator, try parsed.rootInode(), block_size);
    defer root.deinit();
    try std.testing.expectEqual(@as(usize, 0), root.entries.len);
}

test "EROFS writer packs multi-block directories" {
    const archive = @import("archive.zig");
    const allocator = std.testing.allocator;
    var entries: std.ArrayList(Entry) = .empty;
    defer entries.deinit(allocator);
    var paths: std.ArrayList([]u8) = .empty;
    defer {
        for (paths.items) |path| allocator.free(path);
        paths.deinit(allocator);
    }
    for (0..400) |index| {
        const path = try std.fmt.allocPrint(allocator, "wide/item-{d:0>3}", .{index});
        try paths.append(allocator, path);
        try entries.append(allocator, .{ .path = path });
    }
    const encoded = try encodeAlloc(allocator, entries.items, .{});
    defer allocator.free(encoded);
    const parsed = try archive.Archive.init(encoded);
    const wide_inode = try parsed.lookup(allocator, "wide", 0, 16 * 1024);
    var wide = try parsed.readDirectoryAlloc(allocator, wide_inode, 16 * 1024);
    defer wide.deinit();
    try std.testing.expectEqual(@as(usize, 400), wide.entries.len);
    try std.testing.expectEqualStrings("item-000", wide.entries[0].name);
    try std.testing.expectEqualStrings("item-399", wide.entries[399].name);
    const last = try parsed.extractByPathAllocLimited(
        allocator,
        "wide/item-399",
        0,
        16 * 1024,
    );
    defer allocator.free(last);
    try std.testing.expectEqual(@as(usize, 0), last.len);
}
