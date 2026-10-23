const std = @import("std");
const tree = @import("tree.zig");
const format = @import("../format.zig");
const writer_codec = @import("codec.zig");
const writer_xattrs = @import("xattrs.zig");
const writer_metabox = @import("metabox.zig");
const writer_inode = @import("inode.zig");
const writer_clusters = @import("clusters.zig");
const writer_wire = @import("wire.zig");
const compression_metadata = @import("compression_metadata.zig");
const writer_directories = @import("directories.zig");
const xattr = @import("../xattr.zig");
const options_module = @import("options.zig");
const math = @import("math.zig");
pub const Error = tree.Error || writer_codec.Error || writer_xattrs.Error || writer_metabox.Error || writer_inode.Error || writer_clusters.Error || compression_metadata.Error || xattr.Error || math.Error;
const Options = options_module.Options;
const Compression = options_module.Compression;
const TailPacking = options_module.TailPacking;
const block_size: usize = 4096;
const no_block = std.math.maxInt(u32);
const checkedAdd = math.checkedAdd;
const checkedMul = math.checkedMul;
const alignForward = math.alignForward;
const blockCount = math.blockCount;

pub fn planMetadata(
    allocator: std.mem.Allocator,
    filesystem: *tree.Tree,
    options: Options,
    block_encoder: ?*writer_codec.Encoder,
    external_chunks: bool,
    shared_xattr_plan: ?*writer_xattrs.Plan,
) Error!usize {
    const compression = options.compression;
    const xattr_prefixes = options.xattr_prefixes;
    const tail_packing = options.tail_packing;
    const index_format = options.compressed_index_format;
    const metabox = options.metabox;
    const inode_version = options.inode_version;
    const epoch = options.epoch;
    const fixed_nsec = options.fixed_nsec;
    try writer_inode.planVersions(filesystem, inode_version, epoch, fixed_nsec);
    const configuration_start = writer_wire.configurationStart(metabox);
    const configuration_end = try checkedAdd(
        configuration_start,
        writer_codec.configurationSizeForExtent(compression, .{ .decoded_size = options.compression_extent_size, .max_pcluster_size = options.max_pcluster_size }),
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
                index_format,
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
        // The hidden metabox file gains its final length only after visible
        // metadata has been planned. Re-evaluate automatic inode selection
        // before placing that hidden inode in the primary metadata space.
        try writer_inode.planVersions(filesystem, inode_version, epoch, fixed_nsec);
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
                index_format,
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
                index_format,
                block_encoder,
                shared_xattr_plan,
            );
        }
    }

    if (shared_xattr_plan) |plan|
        cursor = try plan.place(cursor, block_size);
    if (options.directory_metadata_zone)
        cursor = try writer_directories.placeMetadataData(filesystem, cursor);

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
    index_format: options_module.IndexFormat,
    block_encoder: ?*writer_codec.Encoder,
    shared_xattr_plan: ?*const writer_xattrs.Plan,
) Error!void {
    const location = try alignForward(cursor.*, format.inode_slot_size);
    const inode_end = try checkedAdd(location, node.inode_size);
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

    const content_size = node.contentSize();
    const compress_content = (node.kind == .file and content_size != 0) or
        (node.kind == .directory and node.fragment_size != 0 and
            node.fragment_size == content_size);
    if (compression != .stored and compress_content) {
        const whole_fragment = node.fragment_size != 0 and
            node.fragment_size == content_size;
        const compact = index_format != .full and !whole_fragment and
            (node.fragment_offset == null or node.fragment_offset.? <= std.math.maxInt(u32));
        node.layout = @intFromEnum(if (compact) format.Layout.compressed_compact else format.Layout.compressed_full);
        node.compressed_advise = if (compact and index_format == .compact) 1 else 0;
        const cluster_count = if (whole_fragment) 0 else try blockCount(content_size);
        node.compressed_indexes = try allocator.alloc(tree.Node.CompressionIndex, cluster_count);
        @memset(node.compressed_indexes.?, .{
            .kind = 0,
            .logical_offset = 0,
            .physical_block = 0,
        });
        if (node.fragment_size != 0 and !whole_fragment) {
            const fragment_offset = node.fragment_offset orelse return error.InvalidErofs;
            const fragment_start = content_size - node.fragment_size;
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
        const metadata_end = try compression_metadata.end(node);
        if (tail_packing == .compressed_inline and node.kind == .file and !node.hidden) {
            const encoder = block_encoder orelse return error.InvalidErofs;
            const tail_start = (content_size - 1) & ~(block_size - 1);
            var tail_storage: [block_size]u8 = undefined;
            const tail = tail_storage[0 .. content_size - tail_start];
            try node.readContent(tail_start, tail);
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

    const tail_len = node.contentSize() % block_size;
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

pub fn assignDataBlocks(filesystem: *tree.Tree, first_data_block: usize, skip_metabox: bool) Error!usize {
    var next_block = first_data_block;
    for (filesystem.nodes) |*node| {
        if (skip_metabox and node.hidden_role == .metabox) continue;
        try assignNodeDataBlocks(node, &next_block);
    }
    if (next_block == 0 or next_block > std.math.maxInt(u32))
        return error.InvalidErofs;
    return next_block;
}

pub fn assignNodeDataBlocks(node: *tree.Node, next_block: *usize) Error!void {
    if (node.directory_in_metadata_zone) return;
    const content_len = node.contentSize();
    const physical_content_len = try writer_clusters.prefixLength(node);
    const blocks = switch (std.enums.fromInt(format.Layout, node.layout) orelse
        return error.InvalidErofs) {
        .compressed_full, .compressed_compact => if (node.compressed_data) |bytes|
            bytes.len / block_size
        else
            try blockCount(physical_content_len),
        .flat_inline => content_len / block_size,
        .flat_plain => try blockCount(content_len),
        .chunk_based => 0,
    };
    node.compressed_block_count = if (node.compressed_indexes != null) blocks else 0;
    if (blocks == 0) return;
    if (next_block.* > std.math.maxInt(u32)) return error.InvalidErofs;
    node.start_block = @intCast(next_block.*);
    if (node.compressed_indexes) |indexes| {
        if (node.compressed_data != null) {
            const logical_count = try blockCount(physical_content_len);
            if (indexes.len < logical_count) return error.InvalidErofs;
            for (indexes[0..logical_count]) |*index| {
                if (index.kind == 2) continue;
                const physical = try checkedAdd(next_block.*, index.physical_block);
                if (physical > std.math.maxInt(u32)) return error.InvalidErofs;
                index.physical_block = @intCast(physical);
            }
        } else {
            if (indexes.len < blocks) return error.InvalidErofs;
            for (indexes[0..blocks], 0..) |*index, cluster_index| {
                const physical = try checkedAdd(next_block.*, cluster_index);
                if (physical > std.math.maxInt(u32)) return error.InvalidErofs;
                index.physical_block = @intCast(physical);
            }
        }
    }
    next_block.* = try checkedAdd(next_block.*, blocks);
    if (next_block.* > std.math.maxInt(u32)) return error.InvalidErofs;
}
