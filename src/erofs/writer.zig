const std = @import("std");
const core = @import("../core.zig");
const format = @import("format.zig");
const tree = @import("writer_tree.zig");
const writer_codec = @import("writer_codec.zig");
const writer_chunks = @import("writer_chunks.zig");
const writer_fragments = @import("writer_fragments.zig");
const writer_metabox = @import("writer_metabox.zig");
const writer_xattrs = @import("writer_xattrs.zig");
const xattr = @import("xattr.zig");

pub const Error = core.Error || writer_codec.Error || writer_chunks.Error ||
    writer_fragments.Error || writer_metabox.Error || writer_xattrs.Error ||
    tree.Error || xattr.Error || error{InvalidErofs};

pub const Entry = tree.Entry;
pub const EntryKind = tree.EntryKind;
pub const Xattr = tree.Xattr;

pub const Compression = writer_codec.Compression;
pub const TailPacking = enum { none, fragments, compressed_inline };

pub const Options = struct {
    compression: Compression = .stored,
    volume_name: []const u8 = "vort",
    epoch: u64 = 0,
    fixed_nsec: u32 = 0,
    build_time: u32 = 0,
    root_xattrs: []const Xattr = &.{},
    xattr_prefixes: []const []const u8 = &.{},
    tail_packing: TailPacking = .none,
    chunk_size: ?usize = null,
    force_48bit: bool = false,
    /// Store visible inode metadata in a standard MZi metabox inode.
    metabox: bool = false,
    /// Deduplicate repeated name/value pairs into the shared-xattr region.
    shared_xattrs: bool = false,
    /// Store nontrivial directory streams as whole fragments in the packed inode.
    compress_directories: bool = false,
};

pub const EncodedExternalChunks = struct {
    image: []u8,
    device: []u8,

    pub fn deinit(self: *EncodedExternalChunks, allocator: std.mem.Allocator) void {
        allocator.free(self.image);
        allocator.free(self.device);
        self.* = undefined;
    }
};

const block_size: usize = 4096;
const block_bits: u8 = 12;
const no_block = std.math.maxInt(u32);

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    entries: []const Entry,
    options: Options,
) Error![]u8 {
    const encoded = try encodeInternal(allocator, entries, options, false);
    if (encoded.device) |device| {
        allocator.free(encoded.image);
        allocator.free(device);
        return error.InvalidErofs;
    }
    return encoded.image;
}

pub fn encodeExternalChunksAlloc(
    allocator: std.mem.Allocator,
    entries: []const Entry,
    options: Options,
) Error!EncodedExternalChunks {
    if (options.chunk_size == null) return error.InvalidErofs;
    const encoded = try encodeInternal(allocator, entries, options, true);
    errdefer allocator.free(encoded.image);
    const device = encoded.device orelse return error.InvalidErofs;
    return .{
        .image = encoded.image,
        .device = device,
    };
}

const InternalEncoded = struct {
    image: []u8,
    device: ?[]u8,
};

fn encodeInternal(
    allocator: std.mem.Allocator,
    entries: []const Entry,
    options: Options,
    external_chunks: bool,
) Error!InternalEncoded {
    if (options.volume_name.len > 16 or options.fixed_nsec >= 1_000_000_000)
        return error.InvalidErofs;
    if (options.tail_packing != .none and options.compression == .stored)
        return error.InvalidErofs;
    if (options.compress_directories and options.compression == .stored)
        return error.InvalidErofs;
    if (options.chunk_size != null and
        (options.compression != .stored or options.tail_packing != .none or
            options.compress_directories))
        return error.InvalidErofs;
    if (options.metabox and
        (options.tail_packing != .none or options.chunk_size != null or external_chunks))
        return error.InvalidErofs;
    if (external_chunks and options.chunk_size == null) return error.InvalidErofs;

    var filesystem = try tree.build(allocator, entries, options.root_xattrs);
    defer filesystem.deinit();
    if (options.metabox)
        try writer_metabox.prepare(allocator, &filesystem);
    try allocateDirectoryBuffers(&filesystem);
    if (options.tail_packing == .fragments or options.compress_directories)
        try writer_fragments.prepare(allocator, &filesystem, block_size, .{
            .file_tails = options.tail_packing == .fragments,
            .directories = options.compress_directories,
        });
    var chunk_plan: ?writer_chunks.Plan = if (options.chunk_size) |chunk_size|
        try writer_chunks.prepare(allocator, &filesystem, chunk_size, external_chunks)
    else
        null;
    defer if (chunk_plan) |*plan| plan.deinit();
    var shared_xattr_plan: ?writer_xattrs.Plan = if (options.shared_xattrs)
        try writer_xattrs.prepare(allocator, filesystem.nodes, options.xattr_prefixes)
    else
        null;
    defer if (shared_xattr_plan) |*plan| plan.deinit();
    var block_encoder: ?writer_codec.Encoder = if (options.compression != .stored)
        try writer_codec.Encoder.init(allocator, options.compression)
    else
        null;
    defer if (block_encoder) |*encoder| encoder.deinit();
    const metadata_end = try planMetadata(
        allocator,
        &filesystem,
        options.compression,
        options.xattr_prefixes,
        options.tail_packing,
        if (block_encoder) |*encoder| encoder else null,
        chunk_plan != null and external_chunks and chunk_plan.?.active(),
        options.metabox,
        if (shared_xattr_plan) |*plan| plan else null,
    );
    try fillDirectories(allocator, &filesystem);
    try writer_fragments.syncDirectories(&filesystem);

    const first_data_block = try alignForward(metadata_end, block_size) / block_size;
    var block_count = try assignDataBlocks(&filesystem, first_data_block);
    if (chunk_plan) |*plan| block_count = try plan.assign(filesystem.nodes, block_count);
    const image_len = try checkedMul(block_count, block_size);
    const image = try allocator.alloc(u8, image_len);
    errdefer allocator.free(image);
    @memset(image, 0);

    try writeNodes(
        image,
        &filesystem,
        options.compression,
        options.xattr_prefixes,
        if (block_encoder) |*encoder| encoder else null,
        if (shared_xattr_plan) |*plan| plan else null,
    );
    if (chunk_plan) |plan| try plan.writeLocal(image);
    try writeSuperblock(
        image,
        filesystem.nodes,
        block_count,
        options,
        if (chunk_plan) |plan| plan else null,
        if (shared_xattr_plan) |*plan| plan else null,
    );
    const device = if (external_chunks)
        if (chunk_plan) |*plan| plan.takeData() else try allocator.alloc(u8, 0)
    else
        null;
    return .{ .image = image, .device = device };
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

fn planMetadata(
    allocator: std.mem.Allocator,
    filesystem: *tree.Tree,
    compression: Compression,
    xattr_prefixes: []const []const u8,
    tail_packing: TailPacking,
    block_encoder: ?*writer_codec.Encoder,
    external_chunks: bool,
    metabox: bool,
    shared_xattr_plan: ?*writer_xattrs.Plan,
) Error!usize {
    const configuration_start = configurationStart(metabox);
    const configuration_end = try checkedAdd(
        configuration_start,
        if (writer_codec.configuration(compression)) |bytes| bytes.len else 0,
    );
    const prefix_start = try alignForward(configuration_end, 4);
    const prefix_end = try checkedAdd(prefix_start, try xattr.prefixTableSize(xattr_prefixes));
    var cursor = if (external_chunks)
        try checkedAdd(try alignForward(prefix_end, 128), 128)
    else
        prefix_end;

    if (metabox) {
        var metabox_cursor: usize = 0;
        for (filesystem.nodes, 0..) |*node, node_index| {
            if (!node.in_metabox) continue;
            try planNodeMetadata(
                allocator,
                node,
                node_index,
                &metabox_cursor,
                compression,
                xattr_prefixes,
                tail_packing,
                block_encoder,
                shared_xattr_plan,
            );
        }
        const metabox_len = try alignForward(metabox_cursor, block_size);
        _ = try writer_metabox.installData(
            allocator,
            filesystem.nodes,
            metabox_len,
        );
        for (filesystem.nodes, 0..) |*node, node_index| {
            if (node.in_metabox) continue;
            try planNodeMetadata(
                allocator,
                node,
                node_index,
                &cursor,
                compression,
                xattr_prefixes,
                tail_packing,
                block_encoder,
                shared_xattr_plan,
            );
        }
    } else {
        for (filesystem.nodes, 0..) |*node, node_index| {
            try planNodeMetadata(
                allocator,
                node,
                node_index,
                &cursor,
                compression,
                xattr_prefixes,
                tail_packing,
                block_encoder,
                shared_xattr_plan,
            );
        }
    }

    if (shared_xattr_plan) |plan|
        cursor = try plan.place(cursor, block_size);

    const root_nid = filesystem.nodes[0].nid;
    if (filesystem.nodes[0].path.len != 0 or
        (metabox and root_nid >> 63 == 0) or
        (!metabox and root_nid > std.math.maxInt(u16)))
        return error.InvalidErofs;
    return cursor;
}

fn planNodeMetadata(
    allocator: std.mem.Allocator,
    node: *tree.Node,
    node_index: usize,
    cursor: *usize,
    compression: Compression,
    xattr_prefixes: []const []const u8,
    tail_packing: TailPacking,
    block_encoder: ?*writer_codec.Encoder,
    shared_xattr_plan: ?*const writer_xattrs.Plan,
) Error!void {
    if (node.content().len > std.math.maxInt(u32)) return error.InvalidErofs;
    const location = try alignForward(cursor.*, format.inode_slot_size);
    const inode_end = try checkedAdd(location, format.inode_slot_size);
    node.xattr_size = if (shared_xattr_plan) |plan|
        try plan.encodedIbodySize(node_index, node.xattrs, xattr_prefixes)
    else
        try xattr.encodedSize(node.xattrs, xattr_prefixes);
    const xattr_end = try checkedAdd(inode_end, node.xattr_size);
    const slot_nid = location / format.inode_slot_size;
    const slot_nid_u64 = std.math.cast(u64, slot_nid) orelse return error.InvalidErofs;
    if (slot_nid_u64 >> 63 != 0) return error.InvalidErofs;
    node.location = location;
    node.nid = slot_nid_u64 |
        (if (node.in_metabox) @as(u64, 1) << 63 else 0);
    node.start_block = no_block;

    if (node.chunk_indexes) |indexes| {
        node.layout = @intFromEnum(format.Layout.chunk_based);
        const index_size: usize = if (node.chunk_format & 0x20 != 0) 8 else 4;
        const index_start = try alignForward(xattr_end, index_size);
        cursor.* = try checkedAdd(
            index_start,
            try checkedMul(indexes.len, index_size),
        );
        return;
    }

    const content = node.content();
    const compress_content = (node.kind == .file and content.len != 0) or
        (node.kind == .directory and node.fragment_size != 0 and
            node.fragment_size == content.len);
    if (compression != .stored and compress_content) {
        node.layout = @intFromEnum(format.Layout.compressed_full);
        const whole_fragment = node.fragment_size != 0 and
            node.fragment_size == content.len;
        const cluster_count = if (whole_fragment) 0 else try blockCount(content.len);
        node.compressed_indexes = try allocator.alloc(tree.Node.CompressionIndex, cluster_count);
        @memset(node.compressed_indexes.?, .{
            .kind = 0,
            .logical_offset = 0,
            .physical_block = 0,
        });
        if (node.fragment_size != 0 and !whole_fragment) {
            const fragment_offset = node.fragment_offset orelse return error.InvalidErofs;
            const fragment_start = content.len - node.fragment_size;
            if (node.fragment_size > block_size or fragment_start % block_size != 0)
                return error.InvalidErofs;
            const fragment_index = fragment_start / block_size;
            if (fragment_index >= node.compressed_indexes.?.len)
                return error.InvalidErofs;
            node.compressed_indexes.?[fragment_index] = .{
                .kind = 1,
                .logical_offset = 0,
                .physical_block = @intCast(fragment_offset >> 32),
            };
        }
        const header_start = try alignForward(xattr_end, 8);
        const metadata_end = try checkedAdd(
            header_start,
            try checkedAdd(16, try checkedMul(cluster_count, 8)),
        );
        if (tail_packing == .compressed_inline and node.kind == .file and !node.hidden) {
            const encoder = block_encoder orelse return error.InvalidErofs;
            const tail_start = (content.len - 1) & ~(block_size - 1);
            const tail = content[tail_start..];
            const encoded = try encoder.encodeScratch(tail);
            const use_compressed = encoded.len < tail.len;
            const candidate = if (use_compressed) encoded else tail;
            const inline_end = try checkedAdd(metadata_end, candidate.len);
            if (candidate.len <= std.math.maxInt(u16) and
                metadata_end / block_size == (inline_end - 1) / block_size)
            {
                node.compressed_inline_data = try allocator.dupe(u8, candidate);
                node.compressed_inline_tail_size = tail.len;
                node.compressed_inline_kind = if (use_compressed) 1 else 0;
                const tail_index = tail_start / block_size;
                if (tail_index >= node.compressed_indexes.?.len)
                    return error.InvalidErofs;
                node.compressed_indexes.?[tail_index] = .{
                    .kind = node.compressed_inline_kind,
                    .logical_offset = 0,
                    .physical_block = 0,
                };
                cursor.* = inline_end;
                return;
            }
        }
        cursor.* = metadata_end;
        return;
    }

    const tail_len = node.content().len % block_size;
    const inline_end = try checkedAdd(xattr_end, tail_len);
    if (tail_len != 0 and
        xattr_end / block_size == (inline_end - 1) / block_size)
    {
        node.layout = @intFromEnum(format.Layout.flat_inline);
        cursor.* = inline_end;
    } else {
        node.layout = @intFromEnum(format.Layout.flat_plain);
        cursor.* = xattr_end;
    }
}

fn configurationStart(metabox: bool) usize {
    return format.super_offset + format.super_base_size +
        (if (metabox) @as(usize, 16) else 0);
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

fn assignDataBlocks(filesystem: *tree.Tree, first_data_block: usize) Error!usize {
    var next_block = first_data_block;
    for (filesystem.nodes) |*node| {
        const content_len = node.content().len;
        if ((node.fragment_size != 0 and node.compressed_inline_tail_size != 0) or
            node.fragment_size > content_len or
            node.compressed_inline_tail_size > content_len - node.fragment_size)
            return error.InvalidErofs;
        const physical_content_len = content_len - node.fragment_size -
            node.compressed_inline_tail_size;
        const blocks = switch (std.enums.fromInt(format.Layout, node.layout) orelse
            return error.InvalidErofs) {
            .compressed_full => try blockCount(physical_content_len),
            .flat_inline => content_len / block_size,
            .flat_plain => try blockCount(content_len),
            .chunk_based => 0,
            else => return error.InvalidErofs,
        };
        node.compressed_block_count = if (node.compressed_indexes != null) blocks else 0;
        if (blocks == 0) continue;
        if (next_block > std.math.maxInt(u32)) return error.InvalidErofs;
        node.start_block = @intCast(next_block);
        if (node.compressed_indexes) |indexes| {
            if (indexes.len < blocks) return error.InvalidErofs;
            for (indexes[0..blocks], 0..) |*index, cluster_index| {
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
    compression: Compression,
    xattr_prefixes: []const []const u8,
    block_encoder: ?*writer_codec.Encoder,
    shared_xattr_plan: ?*const writer_xattrs.Plan,
) Error!void {
    const metabox_data = writer_metabox.data(filesystem.nodes);
    for (filesystem.nodes, 0..) |*node, node_index| {
        const metadata = if (node.in_metabox)
            metabox_data orelse return error.InvalidErofs
        else
            image;
        const layout = std.enums.fromInt(format.Layout, node.layout) orelse
            return error.InvalidErofs;
        if (layout == .compressed_full) {
            const encoder = block_encoder orelse return error.InvalidErofs;
            try writeCompressedData(image, node, encoder);
        } else if (layout == .chunk_based) {
            // Chunk payloads are emitted by writer_chunks.Plan.
        } else {
            try writeFlatData(image, metadata, node, layout);
        }
        try writeInode(
            metadata,
            filesystem.nodes,
            node,
            node_index,
            compression,
            xattr_prefixes,
            shared_xattr_plan,
        );
    }
}

fn writeFlatData(
    image: []u8,
    metadata: []u8,
    node: *const tree.Node,
    layout: format.Layout,
) Error!void {
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
        const inline_start = try checkedAdd(
            try checkedAdd(node.location, format.inode_slot_size),
            node.xattr_size,
        );
        const inline_end = try checkedAdd(inline_start, content.len - data_len);
        if (inline_end > metadata.len or
            inline_start / block_size != (inline_end - 1) / block_size)
            return error.InvalidErofs;
        @memcpy(metadata[inline_start..inline_end], content[data_len..]);
    }
}

fn writeCompressedData(
    image: []u8,
    node: *tree.Node,
    encoder: *writer_codec.Encoder,
) Error!void {
    const indexes = node.compressed_indexes orelse return error.InvalidErofs;
    if (node.compressed_block_count > indexes.len) return error.InvalidErofs;
    const content = node.content();
    const physical_content_len = content.len - node.fragment_size -
        node.compressed_inline_tail_size;
    for (indexes[0..node.compressed_block_count], 0..) |*index, cluster_index| {
        const logical_start = try checkedMul(cluster_index, block_size);
        const logical_end = @min(
            physical_content_len,
            try checkedAdd(logical_start, block_size),
        );
        const chunk = content[logical_start..logical_end];
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
    metadata: []u8,
    nodes: []const tree.Node,
    node: *const tree.Node,
    node_index: usize,
    compression: Compression,
    xattr_prefixes: []const []const u8,
    shared_xattr_plan: ?*const writer_xattrs.Plan,
) Error!void {
    const location = node.location;
    if (try checkedAdd(location, format.inode_slot_size) > metadata.len)
        return error.InvalidErofs;
    const layout = std.enums.fromInt(format.Layout, node.layout) orelse
        return error.InvalidErofs;
    const inode_format: u16 = (@as(u16, @intFromEnum(layout)) << 1) |
        (if (node.kind == .directory) @as(u16, 1 << 4) else 0);
    writeU16(metadata, location, inode_format);
    writeU16(metadata, location + 2, try xattr.ibodyIcount(node.xattr_size));
    writeU16(metadata, location + 4, mode(node.*));
    writeU16(metadata, location + 6, try linkCount(nodes, node_index));
    writeU32(metadata, location + 8, @intCast(node.content().len));
    writeU32(metadata, location + 12, node.modification_time);
    const data_value: u32 = if (layout == .compressed_full)
        @intCast(node.compressed_block_count)
    else if (layout == .chunk_based)
        0
    else
        node.start_block;
    writeU32(metadata, location + 16, data_value);
    if (node_index + 1 > std.math.maxInt(u32)) return error.InvalidErofs;
    writeU32(metadata, location + 20, @intCast(node_index + 1));
    writeU16(metadata, location + 24, 0);
    writeU16(metadata, location + 26, 0);
    writeU32(metadata, location + 28, 0);

    const xattr_start = try checkedAdd(location, format.inode_slot_size);
    const xattr_end = try checkedAdd(xattr_start, node.xattr_size);
    if (xattr_end > metadata.len) return error.InvalidErofs;
    if (shared_xattr_plan) |plan|
        try plan.writeIbody(
            metadata[xattr_start..xattr_end],
            node_index,
            node.xattrs,
            xattr_prefixes,
        )
    else
        try xattr.writeIbody(
            metadata[xattr_start..xattr_end],
            node.xattrs,
            xattr_prefixes,
        );

    if (layout == .chunk_based) {
        const indexes = node.chunk_indexes orelse return error.InvalidErofs;
        writeU16(metadata, location + 16, node.chunk_format);
        writeU16(metadata, location + 18, 0);
        const index_size: usize = if (node.chunk_format & 0x20 != 0) 8 else 4;
        const index_start = try alignForward(xattr_end, index_size);
        const index_end = try checkedAdd(index_start, try checkedMul(indexes.len, index_size));
        if (index_end > metadata.len) return error.InvalidErofs;
        for (indexes, 0..) |index, chunk_index| {
            const offset = index_start + chunk_index * index_size;
            if (index_size == 4) {
                if (index.device_id != 0) return error.InvalidErofs;
                writeU32(metadata, offset, index.start_block);
            } else {
                writeU16(metadata, offset, 0);
                writeU16(metadata, offset + 2, index.device_id);
                writeU32(metadata, offset + 4, index.start_block);
            }
        }
        return;
    }

    if (layout == .compressed_full) {
        const header_start = try alignForward(xattr_end, 8);
        const index_start = try checkedAdd(header_start, 16);
        if (try checkedAdd(index_start, try checkedMul(node.compressed_indexes.?.len, 8)) > metadata.len)
            return error.InvalidErofs;
        if (node.fragment_size == node.content().len and node.fragment_size != 0) {
            const fragment_offset = node.fragment_offset orelse return error.InvalidErofs;
            if (fragment_offset >> 63 != 0 or node.compressed_indexes.?.len != 0)
                return error.InvalidErofs;
            writeU64(metadata, header_start, fragment_offset | (@as(u64, 1) << 63));
            return;
        }
        const fragment_offset = node.fragment_offset;
        const inline_data = node.compressed_inline_data;
        if (fragment_offset != null and inline_data != null) return error.InvalidErofs;
        if (inline_data) |bytes| {
            if (bytes.len == 0 or bytes.len > std.math.maxInt(u16))
                return error.InvalidErofs;
            writeU16(metadata, header_start + 2, @intCast(bytes.len));
            writeU16(metadata, header_start + 4, 0x08);
        } else {
            writeU32(
                metadata,
                header_start,
                if (fragment_offset) |offset| @truncate(offset) else 0,
            );
            writeU16(metadata, header_start + 4, if (fragment_offset != null) 0x20 else 0);
        }
        metadata[header_start + 6] = @intFromEnum(
            writer_codec.algorithm(compression) orelse return error.InvalidErofs,
        );
        metadata[header_start + 7] = 0;
        for (node.compressed_indexes.?, 0..) |index, cluster_index| {
            const offset = index_start + cluster_index * 8;
            writeU16(metadata, offset, index.kind);
            writeU16(metadata, offset + 2, index.logical_offset);
            writeU32(metadata, offset + 4, index.physical_block);
        }
        if (inline_data) |bytes| {
            const inline_start = try checkedAdd(
                index_start,
                try checkedMul(node.compressed_indexes.?.len, 8),
            );
            const inline_end = try checkedAdd(inline_start, bytes.len);
            if (inline_end > metadata.len or
                inline_start / block_size != (inline_end - 1) / block_size)
                return error.InvalidErofs;
            @memcpy(metadata[inline_start..inline_end], bytes);
        }
    }
}

fn writeSuperblock(
    image: []u8,
    nodes: []const tree.Node,
    block_count: usize,
    options: Options,
    chunk_plan: ?writer_chunks.Plan,
    shared_xattr_plan: ?*const writer_xattrs.Plan,
) Error!void {
    if (image.len < block_size or nodes.len == 0 or nodes.len > std.math.maxInt(u64) or
        block_count > std.math.maxInt(u32))
        return error.InvalidErofs;
    const base = format.super_offset;
    const prefix_count = options.xattr_prefixes.len;
    const configuration_start = configurationStart(options.metabox);
    const configuration_end = try checkedAdd(
        configuration_start,
        if (writer_codec.configuration(options.compression)) |bytes| bytes.len else 0,
    );
    const prefix_start = try alignForward(configuration_end, 4);
    const prefix_end = try checkedAdd(
        prefix_start,
        try xattr.prefixTableSize(options.xattr_prefixes),
    );
    var has_chunks = false;
    for (nodes) |node| if (node.chunk_indexes != null) {
        has_chunks = true;
    };
    const has_external_chunks = if (chunk_plan) |plan|
        plan.external and plan.active()
    else
        false;
    const device_table_start = if (has_external_chunks)
        try alignForward(prefix_end, 128)
    else
        0;
    var packed_nid: u64 = 0;
    var metabox_nid: u64 = 0;
    var has_compressed_inline = false;
    for (nodes) |node| {
        if (node.hidden != (node.hidden_role != .none)) return error.InvalidErofs;
        switch (node.hidden_role) {
            .none => {
                if (node.compressed_inline_data != null)
                    has_compressed_inline = true;
            },
            .packed_file => {
                if (packed_nid != 0 or node.in_metabox) return error.InvalidErofs;
                packed_nid = node.nid;
            },
            .metabox => {
                if (metabox_nid != 0 or node.in_metabox or node.nid >> 63 != 0)
                    return error.InvalidErofs;
                metabox_nid = node.nid;
            },
        }
    }
    const has_fragments = packed_nid != 0;
    const has_metabox = metabox_nid != 0;
    if (has_metabox != options.metabox or
        (has_metabox and nodes[0].nid >> 63 == 0) or
        (!has_metabox and nodes[0].nid > std.math.maxInt(u16)))
        return error.InvalidErofs;
    if (prefix_end > image.len or prefix_start / 4 > std.math.maxInt(u32))
        return error.InvalidErofs;
    writeU32(image, base, format.magic);
    writeU32(image, base + 4, 0);
    writeU32(
        image,
        base + 8,
        0x0000_0003 | (if (prefix_count == 0)
            @as(u32, 0)
        else
            format.feature_compat_plain_xattr_prefixes),
    );
    image[base + 12] = block_bits;
    image[base + 13] = if (has_metabox) 1 else 0;
    if (has_metabox) {
        writeU16(image, base + 14, 0);
        writeU64(image, base + 112, nodes[0].nid);
        writeU64(image, base + 128, metabox_nid);
    } else {
        writeU16(image, base + 14, @intCast(nodes[0].nid));
    }
    writeU64(image, base + 16, @intCast(nodes.len));
    writeU64(image, base + 24, options.epoch);
    writeU32(image, base + 32, options.fixed_nsec);
    writeU32(image, base + 36, @intCast(block_count));
    writeU32(image, base + 40, 0);
    writeU32(
        image,
        base + 44,
        if (shared_xattr_plan) |plan|
            if (plan.hasShared()) plan.xattr_block else 0
        else
            0,
    );
    @memcpy(image[base + 64 ..][0..options.volume_name.len], options.volume_name);
    writeU32(
        image,
        base + 80,
        writer_codec.featureIncompat(options.compression) |
            (if (options.force_48bit or has_metabox)
                format.feature_incompat_48bit
            else
                @as(u32, 0)) |
            (if (has_chunks)
                format.feature_incompat_chunked_file
            else
                @as(u32, 0)) |
            (if (has_external_chunks)
                format.feature_incompat_device_table
            else
                @as(u32, 0)) |
            (if (has_fragments)
                format.feature_incompat_fragments
            else
                @as(u32, 0)) |
            (if (has_compressed_inline)
                format.feature_incompat_ztailpacking
            else
                @as(u32, 0)) |
            (if (prefix_count == 0)
                @as(u32, 0)
            else
                format.feature_incompat_xattr_prefixes) |
            (if (has_metabox)
                format.feature_incompat_metabox
            else
                @as(u32, 0)),
    );
    writeU16(image, base + 84, writer_codec.compressionField(options.compression));
    if (has_external_chunks) {
        if (device_table_start / 128 > std.math.maxInt(u16))
            return error.InvalidErofs;
        writeU16(image, base + 86, 1);
        writeU16(image, base + 88, @intCast(device_table_start / 128));
    }
    image[base + 91] = @intCast(prefix_count);
    if (prefix_count != 0)
        writeU32(image, base + 92, @intCast(prefix_start / 4));
    writeU64(image, base + 96, packed_nid);
    if (writer_codec.configuration(options.compression)) |configuration| {
        const end = try checkedAdd(configuration_start, configuration.len);
        if (end > image.len) return error.InvalidErofs;
        @memcpy(image[configuration_start..end], configuration);
    }
    try xattr.writePrefixTable(
        image[prefix_start..prefix_end],
        options.xattr_prefixes,
    );
    if (shared_xattr_plan) |plan|
        try plan.writeRegion(image, options.xattr_prefixes);
    if (has_external_chunks) {
        const plan = chunk_plan.?;
        const table_end = try checkedAdd(device_table_start, 128);
        if (table_end > image.len or plan.data.len % block_size != 0)
            return error.InvalidErofs;
        const device_blocks = plan.data.len / block_size;
        if (device_blocks > std.math.maxInt(u32)) return error.InvalidErofs;
        writeU32(image, device_table_start + 64, @intCast(device_blocks));
        writeU32(image, device_table_start + 68, @intCast(block_count));
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

test "EROFS writer codecs use compressed and plain full indexes" {
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
    inline for (.{ Compression.lz4, .deflate, .zstandard }) |compression| {
        const encoded = try encodeAlloc(allocator, &entries, .{
            .compression = compression,
            .volume_name = "codec-test",
        });
        defer allocator.free(encoded);
        const parsed = try archive.Archive.init(encoded);
        try std.testing.expectEqual(
            writer_codec.featureIncompat(compression),
            parsed.superblock.feature_incompat,
        );
        try std.testing.expectEqual(
            writer_codec.compressionField(compression),
            parsed.superblock.available_compression_algorithms,
        );

        const repeated_inode = try parsed.lookup(allocator, "repeat.bin", repeated.len, block_size);
        try std.testing.expectEqual(format.Layout.compressed_full, repeated_inode.layout);
        try std.testing.expectEqual(writer_codec.algorithm(compression).?, repeated_inode.compressed_algorithms[0].?);
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

test "EROFS writer round trips root file directory and symlink xattrs" {
    const archive = @import("archive.zig");
    const allocator = std.testing.allocator;
    const file_xattrs = [_]Xattr{
        .{ .name = "user.author", .value = "vort" },
        .{ .name = "user.empty", .value = &.{} },
        .{ .name = "security.selinux", .value = "u:object_r:system_file:s0" },
        .{ .name = "trusted.vort", .value = "trusted" },
        .{ .name = "lustre.vort", .value = "lustre" },
        .{ .name = "system.posix_acl_access", .value = &.{ 1, 2 } },
        .{ .name = "system.posix_acl_default", .value = &.{ 3, 4 } },
        .{ .name = "system.vort", .value = &.{ 0, 1, 2, 3 } },
    };
    const root_xattrs = [_]Xattr{.{ .name = "user.root", .value = "root-value" }};
    const entries = [_]Entry{
        .{ .path = "small", .data = "inline payload", .xattrs = &file_xattrs },
        .{ .path = "dir", .kind = .directory, .xattrs = &.{.{ .name = "user.dir", .value = "d" }} },
        .{ .path = "link", .kind = .symlink, .target = "small", .xattrs = &.{.{ .name = "user.link", .value = "l" }} },
    };

    inline for (.{ Compression.stored, .lz4, .deflate, .zstandard }) |compression| {
        const encoded = try encodeAlloc(allocator, &entries, .{
            .compression = compression,
            .root_xattrs = &root_xattrs,
        });
        defer allocator.free(encoded);
        const parsed = try archive.Archive.init(encoded);

        const root_inode = try parsed.rootInode();
        var root_attributes = try parsed.readXattrsAllocLimited(allocator, root_inode, 4, 128);
        defer root_attributes.deinit();
        try std.testing.expectEqualStrings(
            "root-value",
            root_attributes.find("user.root").?.value,
        );

        const small_inode = try parsed.lookup(allocator, "small", 32, block_size);
        var small_attributes = try parsed.readXattrsAllocLimited(allocator, small_inode, 8, 512);
        defer small_attributes.deinit();
        try std.testing.expectEqual(@as(usize, 8), small_attributes.entries.len);
        try std.testing.expectEqualStrings("vort", small_attributes.find("user.author").?.value);
        try std.testing.expectEqual(@as(usize, 0), small_attributes.find("user.empty").?.value.len);
        try std.testing.expectEqualStrings(
            "u:object_r:system_file:s0",
            small_attributes.find("security.selinux").?.value,
        );
        try std.testing.expectEqualStrings("trusted", small_attributes.find("trusted.vort").?.value);
        try std.testing.expectEqualStrings("lustre", small_attributes.find("lustre.vort").?.value);
        try std.testing.expectEqualSlices(
            u8,
            &.{ 1, 2 },
            small_attributes.find("system.posix_acl_access").?.value,
        );
        try std.testing.expectEqualSlices(
            u8,
            &.{ 3, 4 },
            small_attributes.find("system.posix_acl_default").?.value,
        );
        try std.testing.expectEqualSlices(
            u8,
            &.{ 0, 1, 2, 3 },
            small_attributes.find("system.vort").?.value,
        );
        const decoded = try parsed.readFlatAllocLimited(allocator, small_inode, 32);
        defer allocator.free(decoded);
        try std.testing.expectEqualStrings("inline payload", decoded);

        const directory_inode = try parsed.lookup(allocator, "dir", 0, block_size);
        var directory_attributes = try parsed.readXattrsAllocLimited(allocator, directory_inode, 1, 32);
        defer directory_attributes.deinit();
        try std.testing.expectEqualStrings("d", directory_attributes.find("user.dir").?.value);

        const link_inode = try parsed.lookup(allocator, "link", 32, block_size);
        var link_attributes = try parsed.readXattrsAllocLimited(allocator, link_inode, 1, 32);
        defer link_attributes.deinit();
        try std.testing.expectEqualStrings("l", link_attributes.find("user.link").?.value);
    }
}

test "EROFS writer rejects invalid duplicate and oversized xattrs" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(
        error.InvalidErofs,
        encodeAlloc(allocator, &.{.{
            .path = "empty-name",
            .xattrs = &.{.{ .name = "", .value = "x" }},
        }}, .{}),
    );
    try std.testing.expectError(
        error.InvalidErofs,
        encodeAlloc(allocator, &.{.{
            .path = "duplicate",
            .xattrs = &.{
                .{ .name = "user.same", .value = "a" },
                .{ .name = "user.same", .value = "b" },
            },
        }}, .{}),
    );
    try std.testing.expectError(
        error.InvalidErofs,
        encodeAlloc(allocator, &.{.{
            .path = "empty-suffix",
            .xattrs = &.{.{ .name = "user.", .value = "x" }},
        }}, .{}),
    );
    var oversized: [std.math.maxInt(u16) + 1]u8 = @splat(0);
    try std.testing.expectError(
        error.InvalidErofs,
        encodeAlloc(allocator, &.{.{
            .path = "oversized",
            .xattrs = &.{.{ .name = "user.large", .value = &oversized }},
        }}, .{}),
    );

    const duplicate_prefixes = [_][]const u8{ "user.vort.", "user.vort." };
    try std.testing.expectError(
        error.InvalidErofs,
        encodeAlloc(allocator, &.{}, .{ .xattr_prefixes = &duplicate_prefixes }),
    );
    const nul_prefixes = [_][]const u8{"user.vort\x00bad"};
    try std.testing.expectError(
        error.InvalidErofs,
        encodeAlloc(allocator, &.{}, .{ .xattr_prefixes = &nul_prefixes }),
    );
    var oversized_prefix: [format.name_max + 1]u8 = @splat('a');
    try std.testing.expectError(
        error.InvalidErofs,
        encodeAlloc(allocator, &.{}, .{ .xattr_prefixes = &.{&oversized_prefix} }),
    );
    const too_many_prefixes: [0x81][]const u8 = @splat("user.vort.");
    try std.testing.expectError(
        error.InvalidErofs,
        encodeAlloc(allocator, &.{}, .{ .xattr_prefixes = &too_many_prefixes }),
    );
}

test "EROFS writer emits plain long xattr prefix tables for every codec" {
    const archive = @import("archive.zig");
    const allocator = std.testing.allocator;
    const prefixes = [_][]const u8{
        "user.vort.long.",
        "security.vort.",
        "system.vort.",
    };
    const attributes = [_]Xattr{
        .{ .name = "user.vort.long.alpha", .value = "alpha-value" },
        .{ .name = "security.vort.label", .value = "security-value" },
        .{ .name = "system.vort.hidden", .value = "generic-value" },
        .{ .name = "user.short", .value = "short-value" },
    };
    const entries = [_]Entry{.{
        .path = "file",
        .data = "long-prefix payload",
        .xattrs = &attributes,
    }};

    inline for (.{ Compression.stored, .lz4, .deflate, .zstandard }) |compression| {
        const encoded = try encodeAlloc(allocator, &entries, .{
            .compression = compression,
            .xattr_prefixes = &prefixes,
        });
        defer allocator.free(encoded);
        const parsed = try archive.Archive.init(encoded);
        try std.testing.expectEqual(@as(u8, prefixes.len), parsed.superblock.xattr_prefix_count);
        try std.testing.expect(
            parsed.superblock.feature_compat & format.feature_compat_plain_xattr_prefixes != 0,
        );
        try std.testing.expect(
            parsed.superblock.feature_incompat & format.feature_incompat_xattr_prefixes != 0,
        );

        const inode_value = try parsed.lookup(allocator, "file", 64, block_size);
        const ibody_start = inode_value.location + inode_value.inode_size;
        try std.testing.expectEqual(@as(u8, 0x80), encoded[ibody_start + 13]);
        var decoded = try parsed.readXattrsAllocLimited(allocator, inode_value, 4, 512);
        defer decoded.deinit();
        try std.testing.expectEqualStrings(
            "alpha-value",
            decoded.find("user.vort.long.alpha").?.value,
        );
        try std.testing.expectEqualStrings(
            "security-value",
            decoded.find("security.vort.label").?.value,
        );
        try std.testing.expectEqualStrings(
            "generic-value",
            decoded.find("system.vort.hidden").?.value,
        );
        try std.testing.expectEqualStrings(
            "short-value",
            decoded.find("user.short").?.value,
        );
        const payload = try parsed.readFlatAllocLimited(allocator, inode_value, 64);
        defer allocator.free(payload);
        try std.testing.expectEqualStrings("long-prefix payload", payload);
    }
}

test "EROFS xattr writer releases every allocation failure" {
    const allocator = std.testing.allocator;
    const Test = struct {
        fn run(failing_allocator: std.mem.Allocator) !void {
            const encoded = try encodeAlloc(failing_allocator, &.{.{
                .path = "file",
                .data = "payload",
                .xattrs = &.{.{ .name = "user.test", .value = "value" }},
            }}, .{
                .root_xattrs = &.{.{ .name = "user.root", .value = "root" }},
                .xattr_prefixes = &.{"user."},
            });
            defer failing_allocator.free(encoded);
            const parsed = try @import("archive.zig").Archive.init(encoded);
            const inode_value = try parsed.lookup(failing_allocator, "file", 32, block_size);
            var attributes = try parsed.readXattrsAllocLimited(
                failing_allocator,
                inode_value,
                4,
                64,
            );
            defer attributes.deinit();
            try std.testing.expectEqualStrings("value", attributes.find("user.test").?.value);
        }
    };
    try std.testing.checkAllAllocationFailures(allocator, Test.run, .{});
}
