const std = @import("std");
const core = @import("../core.zig");
const archive_mod = @import("archive.zig");
const format = @import("format.zig");
const tree_mod = @import("writer_tree.zig");
const writer_codec = @import("writer_codec.zig");

pub const Error = core.Error || writer_codec.Error || tree_mod.Error ||
    std.mem.Allocator.Error || error{InvalidSquashfs};

pub const Entry = tree_mod.Entry;
pub const EntryKind = tree_mod.EntryKind;

pub const Mode = writer_codec.Mode;

pub const Options = struct {
    mode: Mode = .gzip,
    block_size: usize = 128 * 1024,
    modification_time: u32 = 0,
    pad_to: usize = 4096,
};

const Fragment = struct {
    start: usize,
    size_field: u32,
};

const MetadataEncoding = struct {
    block_offsets: []usize,

    fn deinit(self: MetadataEncoding, allocator: std.mem.Allocator) void {
        allocator.free(self.block_offsets);
    }
};

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    entries: []const Entry,
    options: Options,
) Error![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    _ = try encodeAppend(allocator, &output, entries, options);
    return output.toOwnedSlice(allocator);
}

pub fn encodeAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    entries: []const Entry,
    options: Options,
) Error!usize {
    if (options.block_size < 4096 or options.block_size > 1024 * 1024 or
        !std.math.isPowerOfTwo(options.block_size) or
        (options.pad_to != 0 and !std.math.isPowerOfTwo(options.pad_to)))
        return error.InvalidSquashfs;
    const start = output.items.len;
    errdefer output.items.len = start;
    var tree = try tree_mod.build(allocator, entries);
    defer tree.deinit();
    try output.appendNTimes(allocator, 0, format.superblock_size);
    if (writer_codec.compressorOptions(options.mode)) |compressor_options| {
        if (compressor_options.len > 0x7fff) return error.InvalidSquashfs;
        try appendU16(allocator, output, 0x8000 | @as(u16, @intCast(compressor_options.len)));
        try output.appendSlice(allocator, compressor_options);
    }

    var fragments: std.ArrayList(Fragment) = .empty;
    defer fragments.deinit(allocator);
    var fragment_buffer: std.ArrayList(u8) = .empty;
    defer fragment_buffer.deinit(allocator);

    for (tree.nodes) |*node| {
        if (node.kind != .file) continue;
        const full_blocks = node.data.len / options.block_size;
        const sizes = try allocator.alloc(u32, full_blocks);
        node.block_sizes = sizes;
        node.data_start = if (full_blocks == 0) 0 else output.items.len - start;
        for (0..full_blocks) |block_index| {
            const block = node.data[block_index * options.block_size ..][0..options.block_size];
            sizes[block_index] = try appendDataBlock(
                allocator,
                output,
                block,
                options,
            );
        }
        const tail = node.data[full_blocks * options.block_size ..];
        if (tail.len != 0) {
            if (fragment_buffer.items.len + tail.len > options.block_size)
                try flushFragment(
                    allocator,
                    output,
                    &fragment_buffer,
                    &fragments,
                    options,
                    start,
                );
            node.fragment = @intCast(fragments.items.len);
            node.fragment_offset = @intCast(fragment_buffer.items.len);
            try fragment_buffer.appendSlice(allocator, tail);
        }
    }
    if (fragment_buffer.items.len != 0)
        try flushFragment(
            allocator,
            output,
            &fragment_buffer,
            &fragments,
            options,
            start,
        );

    var inode_logical_size: usize = 0;
    for (tree.nodes) |*node| {
        node.inode_logical_offset = inode_logical_size;
        inode_logical_size = std.math.add(
            usize,
            inode_logical_size,
            try node.encodedInodeSize(),
        ) catch return error.IntegerOverflow;
    }
    if (metadataBlock(inode_logical_size) > std.math.maxInt(u32))
        return error.InvalidSquashfs;

    var directory_bytes: std.ArrayList(u8) = .empty;
    defer directory_bytes.deinit(allocator);
    var child_indexes: std.ArrayList(usize) = .empty;
    defer child_indexes.deinit(allocator);
    for (tree.nodes, 0..) |*node, node_index| {
        if (node.kind != .directory) continue;
        child_indexes.clearRetainingCapacity();
        for (tree.nodes, 0..) |child, child_index| {
            if (child_index != node_index and child.parent == node_index)
                try child_indexes.append(allocator, child_index);
        }
        node.directory_logical_offset = directory_bytes.items.len;
        try appendDirectory(allocator, &directory_bytes, tree.nodes, child_indexes.items);
        node.directory_size = directory_bytes.items.len - node.directory_logical_offset + 3;
        if (node.directory_size > std.math.maxInt(u32)) return error.InvalidSquashfs;
    }
    if (metadataBlock(directory_bytes.items.len) > std.math.maxInt(u32))
        return error.InvalidSquashfs;

    var inode_bytes: std.ArrayList(u8) = .empty;
    defer inode_bytes.deinit(allocator);
    for (tree.nodes, 0..) |node, node_index| {
        if (inode_bytes.items.len != node.inode_logical_offset)
            return error.InvalidSquashfs;
        try appendBaseInode(allocator, &inode_bytes, node);
        switch (node.kind) {
            .file => try appendRegularInode(allocator, &inode_bytes, node),
            .directory => try appendDirectoryInode(
                allocator,
                &inode_bytes,
                node,
                tree.nodes[node.parent].inode_number,
                directoryLinkCount(tree.nodes, node_index),
            ),
            .symlink => try appendSymlinkInode(allocator, &inode_bytes, node),
        }
    }

    const inode_table_start = output.items.len - start;
    const inode_encoding = try appendMetadataTable(
        allocator,
        output,
        inode_bytes.items,
        start,
    );
    defer inode_encoding.deinit(allocator);
    const directory_table_start = output.items.len - start;
    const directory_encoding = try appendMetadataTable(
        allocator,
        output,
        directory_bytes.items,
        start,
    );
    defer directory_encoding.deinit(allocator);

    var fragment_table_start: u64 = format.invalid_table;
    if (fragments.items.len != 0) {
        var fragment_bytes: std.ArrayList(u8) = .empty;
        defer fragment_bytes.deinit(allocator);
        for (fragments.items) |fragment| {
            try appendU64(allocator, &fragment_bytes, @intCast(fragment.start));
            try appendU32(allocator, &fragment_bytes, fragment.size_field);
            try appendU32(allocator, &fragment_bytes, 0);
        }
        const fragment_encoding = try appendMetadataTable(
            allocator,
            output,
            fragment_bytes.items,
            start,
        );
        defer fragment_encoding.deinit(allocator);
        fragment_table_start = output.items.len - start;
        for (fragment_encoding.block_offsets) |position|
            try appendU64(allocator, output, @intCast(position));
    }

    var id_bytes: std.ArrayList(u8) = .empty;
    defer id_bytes.deinit(allocator);
    try appendU32(allocator, &id_bytes, 0);
    const id_encoding = try appendMetadataTable(allocator, output, id_bytes.items, start);
    defer id_encoding.deinit(allocator);
    const id_table_start = output.items.len - start;
    for (id_encoding.block_offsets) |position|
        try appendU64(allocator, output, @intCast(position));

    const bytes_used = output.items.len - start;
    const root = tree.nodes[0];
    const root_inode = metadataReference(root.inode_logical_offset);
    writeSuperblock(
        output.items[start..][0..format.superblock_size],
        tree.nodes.len,
        options,
        fragments.items.len,
        root_inode,
        bytes_used,
        id_table_start,
        inode_table_start,
        directory_table_start,
        fragment_table_start,
    );
    if (options.pad_to != 0) {
        const remainder = (output.items.len - start) & (options.pad_to - 1);
        if (remainder != 0)
            try output.appendNTimes(allocator, 0, options.pad_to - remainder);
    }
    return output.items.len - start;
}

fn appendDataBlock(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
    options: Options,
) Error!u32 {
    const encoded = try writer_codec.compressAlloc(
        allocator,
        input,
        options.mode,
        options.block_size,
    );
    defer if (encoded) |bytes| allocator.free(bytes);
    if (encoded) |bytes| {
        if (bytes.len < input.len) {
            try output.appendSlice(allocator, bytes);
            return std.math.cast(u32, bytes.len) orelse error.IntegerOverflow;
        }
    }
    try output.appendSlice(allocator, input);
    const size = std.math.cast(u32, input.len) orelse return error.IntegerOverflow;
    return 0x0100_0000 | size;
}

fn flushFragment(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    buffer: *std.ArrayList(u8),
    fragments: *std.ArrayList(Fragment),
    options: Options,
    filesystem_start: usize,
) Error!void {
    const start = output.items.len - filesystem_start;
    const size_field = try appendDataBlock(allocator, output, buffer.items, options);
    try fragments.append(allocator, .{ .start = start, .size_field = size_field });
    buffer.clearRetainingCapacity();
}

fn appendDirectory(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    nodes: []const tree_mod.Node,
    children: []const usize,
) Error!void {
    var position: usize = 0;
    while (position < children.len) {
        const first = nodes[children[position]];
        const block = metadataBlock(first.inode_logical_offset);
        const base_inode = first.inode_number;
        var count: usize = 1;
        while (position + count < children.len and count < 256) : (count += 1) {
            const child = nodes[children[position + count]];
            const delta = @as(i64, child.inode_number) - base_inode;
            if (metadataBlock(child.inode_logical_offset) != block or
                delta < std.math.minInt(i16) or delta > std.math.maxInt(i16))
                break;
        }
        try appendU32(allocator, output, @intCast(count - 1));
        try appendU32(allocator, output, std.math.cast(u32, block) orelse
            return error.IntegerOverflow);
        try appendU32(allocator, output, base_inode);
        for (children[position..][0..count]) |child_index| {
            const child = nodes[child_index];
            const name = child.name();
            try appendU16(allocator, output, @intCast(metadataOffset(child.inode_logical_offset)));
            try appendI16(
                allocator,
                output,
                @intCast(@as(i64, child.inode_number) - base_inode),
            );
            const directory_kind: format.InodeKind = switch (child.kind) {
                .file => .regular,
                .directory => .directory,
                .symlink => .symlink,
            };
            try appendU16(allocator, output, @intFromEnum(directory_kind));
            try appendU16(allocator, output, @intCast(name.len - 1));
            try output.appendSlice(allocator, name);
        }
        position += count;
    }
}

fn appendBaseInode(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    node: tree_mod.Node,
) Error!void {
    try appendU16(allocator, output, @intFromEnum(node.inodeKind()));
    try appendU16(allocator, output, node.mode & 0x0fff);
    try appendU16(allocator, output, 0);
    try appendU16(allocator, output, 0);
    try appendU32(allocator, output, node.modification_time);
    try appendU32(allocator, output, node.inode_number);
}

fn appendRegularInode(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    node: tree_mod.Node,
) Error!void {
    try appendU64(allocator, output, @intCast(node.data_start));
    try appendU64(allocator, output, @intCast(node.data.len));
    try appendU64(allocator, output, 0);
    try appendU32(allocator, output, 1);
    try appendU32(allocator, output, node.fragment);
    try appendU32(allocator, output, node.fragment_offset);
    try appendU32(allocator, output, 0xffff_ffff);
    if (node.block_sizes) |sizes|
        for (sizes) |size| try appendU32(allocator, output, size);
}

fn appendDirectoryInode(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    node: tree_mod.Node,
    parent_inode: u32,
    link_count: u32,
) Error!void {
    try appendU32(allocator, output, link_count);
    try appendU32(allocator, output, @intCast(node.directory_size));
    try appendU32(
        allocator,
        output,
        std.math.cast(u32, metadataBlock(node.directory_logical_offset)) orelse
            return error.IntegerOverflow,
    );
    try appendU32(allocator, output, parent_inode);
    try appendU16(allocator, output, 0);
    try appendU16(allocator, output, @intCast(metadataOffset(node.directory_logical_offset)));
    try appendU32(allocator, output, 0xffff_ffff);
}

fn appendSymlinkInode(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    node: tree_mod.Node,
) Error!void {
    if (node.target.len == 0 or node.target.len > 65_535 or
        std.mem.indexOfScalar(u8, node.target, 0) != null)
        return error.InvalidSquashfs;
    try appendU32(allocator, output, 1);
    try appendU32(allocator, output, @intCast(node.target.len));
    try output.appendSlice(allocator, node.target);
}

fn directoryLinkCount(nodes: []const tree_mod.Node, directory: usize) u32 {
    var count: u32 = 2;
    for (nodes, 0..) |node, index| {
        if (index != directory and node.parent == directory and node.kind == .directory) {
            count += 1;
        }
    }
    return count;
}

fn appendMetadataTable(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    bytes: []const u8,
    filesystem_start: usize,
) Error!MetadataEncoding {
    const block_count = if (bytes.len == 0) 0 else (bytes.len + format.metadata_size - 1) /
        format.metadata_size;
    const offsets = try allocator.alloc(usize, block_count);
    errdefer allocator.free(offsets);
    var offset: usize = 0;
    var index: usize = 0;
    while (offset < bytes.len) : (index += 1) {
        offsets[index] = output.items.len - filesystem_start;
        const length = @min(format.metadata_size, bytes.len - offset);
        try appendU16(allocator, output, 0x8000 | @as(u16, @intCast(length)));
        try output.appendSlice(allocator, bytes[offset..][0..length]);
        offset += length;
    }
    return .{ .block_offsets = offsets };
}

fn writeSuperblock(
    output: []u8,
    inode_count: usize,
    options: Options,
    fragment_count: usize,
    root_inode: u64,
    bytes_used: usize,
    id_table_start: usize,
    inode_table_start: usize,
    directory_table_start: usize,
    fragment_table_start: u64,
) void {
    @memset(output, 0);
    std.mem.writeInt(u32, output[0..4], format.magic, .little);
    std.mem.writeInt(u32, output[4..8], @intCast(inode_count), .little);
    std.mem.writeInt(u32, output[8..12], options.modification_time, .little);
    std.mem.writeInt(u32, output[12..16], @intCast(options.block_size), .little);
    std.mem.writeInt(u32, output[16..20], @intCast(fragment_count), .little);
    std.mem.writeInt(
        u16,
        output[20..22],
        @intFromEnum(writer_codec.compression(options.mode)),
        .little,
    );
    std.mem.writeInt(
        u16,
        output[22..24],
        @intCast(std.math.log2_int(usize, options.block_size)),
        .little,
    );
    var flags: u16 = (1 << 0) | (1 << 9) | (1 << 11);
    if (options.mode == .stored) flags |= (1 << 1) | (1 << 3);
    if (writer_codec.compressorOptions(options.mode) != null) flags |= 1 << 10;
    if (fragment_count == 0) flags |= 1 << 4;
    std.mem.writeInt(u16, output[24..26], flags, .little);
    std.mem.writeInt(u16, output[26..28], 1, .little);
    std.mem.writeInt(u16, output[28..30], 4, .little);
    std.mem.writeInt(u16, output[30..32], 0, .little);
    std.mem.writeInt(u64, output[32..40], root_inode, .little);
    std.mem.writeInt(u64, output[40..48], bytes_used, .little);
    std.mem.writeInt(u64, output[48..56], id_table_start, .little);
    std.mem.writeInt(u64, output[56..64], format.invalid_table, .little);
    std.mem.writeInt(u64, output[64..72], inode_table_start, .little);
    std.mem.writeInt(u64, output[72..80], directory_table_start, .little);
    std.mem.writeInt(u64, output[80..88], fragment_table_start, .little);
    std.mem.writeInt(u64, output[88..96], format.invalid_table, .little);
}

fn metadataReference(logical_offset: usize) u64 {
    return format.inodeReference(
        @intCast(metadataBlock(logical_offset)),
        @intCast(metadataOffset(logical_offset)),
    );
}

fn metadataBlock(logical_offset: usize) usize {
    return logical_offset / format.metadata_size * (format.metadata_size + 2);
}

fn metadataOffset(logical_offset: usize) usize {
    return logical_offset % format.metadata_size;
}

fn appendU16(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: u16) !void {
    var bytes: [2]u8 = undefined;
    std.mem.writeInt(u16, &bytes, value, .little);
    try output.appendSlice(allocator, &bytes);
}

fn appendI16(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: i16) !void {
    return appendU16(allocator, output, @bitCast(value));
}

fn appendU32(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: u32) !void {
    var bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &bytes, value, .little);
    try output.appendSlice(allocator, &bytes);
}

fn appendU64(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: u64) !void {
    var bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, &bytes, value, .little);
    try output.appendSlice(allocator, &bytes);
}

test {
    _ = tree_mod;
}

test "SquashFS writer round trips every codec mode" {
    const allocator = std.testing.allocator;
    var random: [8193]u8 = undefined;
    var prng = std.Random.DefaultPrng.init(0x5351_4653_5752_4954);
    prng.random().bytes(&random);
    const large = "SquashFS writer multi-block payload 0123456789\n" ** 8192;
    const entries = [_]Entry{
        .{ .path = "etc", .kind = .directory },
        .{ .path = "etc/config", .data = "configuration\n" },
        .{ .path = "large.bin", .data = large },
        .{ .path = "random.bin", .data = &random },
        .{ .path = "small", .data = "fragment" },
        .{ .path = "link", .kind = .symlink, .target = "etc/config" },
    };
    inline for (.{
        Mode.stored,
        .gzip,
        .lzma,
        .lzo,
        .xz,
        .lz4,
        .zstandard,
    }) |mode| {
        const encoded = try encodeAlloc(allocator, &entries, .{
            .mode = mode,
            .block_size = 4096,
            .pad_to = 0,
        });
        defer allocator.free(encoded);
        const archive = try archive_mod.Archive.init(encoded);
        try std.testing.expectEqual(
            writer_codec.compression(mode),
            archive.superblock.compression,
        );
        try std.testing.expectEqual(
            mode == .lz4,
            archive.superblock.flags.compressorOptions(),
        );
        const config = try archive.extractByPathAllocLimited(
            allocator,
            "etc/config",
            1024,
            1024 * 1024,
        );
        defer allocator.free(config);
        try std.testing.expectEqualSlices(u8, "configuration\n", config);
        const decoded_large = try archive.extractByPathAllocLimited(
            allocator,
            "large.bin",
            large.len,
            1024 * 1024,
        );
        defer allocator.free(decoded_large);
        try std.testing.expectEqualSlices(u8, large, decoded_large);
        const decoded_random = try archive.extractByPathAllocLimited(
            allocator,
            "random.bin",
            random.len,
            1024 * 1024,
        );
        defer allocator.free(decoded_random);
        try std.testing.expectEqualSlices(u8, &random, decoded_random);
        const small = try archive.extractByPathAllocLimited(
            allocator,
            "small",
            64,
            1024 * 1024,
        );
        defer allocator.free(small);
        try std.testing.expectEqualSlices(u8, "fragment", small);
        const link = try archive.extractByPathAllocLimited(
            allocator,
            "link",
            64,
            1024 * 1024,
        );
        defer allocator.free(link);
        try std.testing.expectEqualSlices(u8, "etc/config", link);
    }

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(allocator);
    try appended.appendSlice(allocator, "prefix");
    const written = try encodeAppend(allocator, &appended, &entries, .{
        .mode = .gzip,
        .block_size = 4096,
        .pad_to = 0,
    });
    try std.testing.expectEqual(appended.items.len - "prefix".len, written);
    const appended_archive = try archive_mod.Archive.init(appended.items["prefix".len..]);
    const appended_config = try appended_archive.extractByPathAllocLimited(
        allocator,
        "etc/config",
        1024,
        1024 * 1024,
    );
    defer allocator.free(appended_config);
    try std.testing.expectEqualSlices(u8, "configuration\n", appended_config);
}

test "SquashFS writer rejects unsafe trees and invalid block sizes" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(
        error.InvalidSquashfs,
        encodeAlloc(allocator, &.{.{ .path = "../escape", .data = "x" }}, .{}),
    );
    try std.testing.expectError(
        error.InvalidSquashfs,
        encodeAlloc(allocator, &.{
            .{ .path = "duplicate", .data = "a" },
            .{ .path = "duplicate", .data = "b" },
        }, .{}),
    );
    try std.testing.expectError(
        error.InvalidSquashfs,
        encodeAlloc(allocator, &.{.{ .path = "file", .data = "x" }}, .{
            .block_size = 12345,
        }),
    );
}
