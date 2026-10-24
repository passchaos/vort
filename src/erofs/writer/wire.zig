const std = @import("std");
const core = @import("../../core.zig");
const format = @import("../format.zig");
const tree = @import("tree.zig");
const writer_codec = @import("codec.zig");
const writer_chunks = @import("chunks.zig");
const writer_metabox = @import("metabox.zig");
const writer_xattrs = @import("xattrs.zig");
const writer_inode = @import("inode.zig");
const writer_clusters = @import("clusters.zig");
const writer_options = @import("options.zig");
const compression_metadata = @import("compression_metadata.zig");
const xattr = @import("../xattr.zig");

pub const Error = core.Error || format.Error || tree.Error || writer_codec.Error ||
    writer_chunks.Error || writer_metabox.Error || writer_xattrs.Error ||
    writer_inode.Error || writer_clusters.Error || compression_metadata.Error || xattr.Error;
const Compression = writer_options.Compression;
const Options = writer_options.Options;
const block_size: usize = 4096;
const block_bits: u8 = 12;
const no_block = std.math.maxInt(u32);

pub fn configurationStart(metabox: bool) usize {
    return format.super_offset + format.super_base_size +
        (if (metabox) @as(usize, 16) else 0);
}

pub fn populateMetaboxMetadata(filesystem: *tree.Tree, options: Options, shared_xattr_plan: ?*const writer_xattrs.Plan) Error!void {
    const metadata = writer_metabox.data(filesystem.nodes) orelse return error.InvalidErofs;
    for (filesystem.nodes, 0..) |*node, index| {
        if (!node.in_metabox) continue;
        const layout = std.enums.fromInt(format.Layout, node.layout) orelse return error.InvalidErofs;
        try writeFlatInlineData(metadata, node, layout);
        try writeInode(metadata, node, index, options.compression, options.xattr_prefixes, shared_xattr_plan, options.epoch, options.fixed_nsec);
    }
}

pub fn writeNodeMetadata(primary: []u8, filesystem: *tree.Tree, index: usize, options: Options, shared_xattr_plan: ?*const writer_xattrs.Plan) Error!void {
    const node = &filesystem.nodes[index];
    const metadata = if (node.in_metabox)
        writer_metabox.data(filesystem.nodes) orelse return error.InvalidErofs
    else
        primary;
    const layout = std.enums.fromInt(format.Layout, node.layout) orelse return error.InvalidErofs;
    if (node.directory_in_metadata_zone) {
        const size = if (layout == .flat_inline) node.contentSize() / block_size * block_size else node.contentSize();
        if (size != 0) {
            const start = try checkedMul(node.start_block, block_size);
            const end = try checkedAdd(start, size);
            if (end > primary.len) return error.InvalidErofs;
            try node.readContent(0, primary[start..end]);
        }
    }
    try writeFlatInlineData(metadata, node, layout);
    try writeInode(metadata, node, index, options.compression, options.xattr_prefixes, shared_xattr_plan, options.epoch, options.fixed_nsec);
}

pub fn writeNodes(
    image: []u8,
    filesystem: *tree.Tree,
    compression: Compression,
    xattr_prefixes: []const []const u8,
    block_encoder: ?*writer_codec.Encoder,
    shared_xattr_plan: ?*const writer_xattrs.Plan,
    epoch: u64,
    fixed_nsec: u32,
) Error!void {
    const metabox_data = writer_metabox.data(filesystem.nodes);
    for ([_]bool{ false, true }) |metabox_pass| for (filesystem.nodes, 0..) |*node, node_index| {
        if ((node.hidden_role == .metabox) != metabox_pass) continue;
        const metadata = if (node.in_metabox)
            metabox_data orelse return error.InvalidErofs
        else
            image;
        const layout = std.enums.fromInt(format.Layout, node.layout) orelse
            return error.InvalidErofs;
        if (compression_metadata.isCompressed(layout)) {
            const encoder = block_encoder orelse return error.InvalidErofs;
            try writeCompressedData(image, node, encoder);
        } else if (layout == .chunk_based) {
            // Chunk payloads are emitted by writer_chunks.Plan.
        } else {
            try writeFlatData(image, metadata, node, layout);
        }
        try writeInode(
            metadata,
            node,
            node_index,
            compression,
            xattr_prefixes,
            shared_xattr_plan,
            epoch,
            fixed_nsec,
        );
    };
}

fn writeFlatData(
    image: []u8,
    metadata: []u8,
    node: *const tree.Node,
    layout: format.Layout,
) Error!void {
    const content_size = node.contentSize();
    const data_len = if (layout == .flat_inline)
        content_size / block_size * block_size
    else
        content_size;
    if (data_len != 0) {
        if (node.start_block == no_block) return error.InvalidErofs;
        const data_start = try checkedMul(node.start_block, block_size);
        const data_end = try checkedAdd(data_start, data_len);
        if (data_end > image.len) return error.InvalidErofs;
        try node.readContent(0, image[data_start..data_end]);
    }
    try writeFlatInlineData(metadata, node, layout);
}

fn writeFlatInlineData(metadata: []u8, node: *const tree.Node, layout: format.Layout) Error!void {
    const content_size = node.contentSize();
    const data_len = content_size / block_size * block_size;
    if (layout == .flat_inline and data_len < content_size) {
        const inline_start = try checkedAdd(
            try checkedAdd(node.location, node.inode_size),
            node.xattr_size,
        );
        const inline_end = try checkedAdd(inline_start, content_size - data_len);
        if (inline_end > metadata.len or
            inline_start / block_size != (inline_end - 1) / block_size)
            return error.InvalidErofs;
        try node.readContent(data_len, metadata[inline_start..inline_end]);
    }
}

fn writeCompressedData(
    image: []u8,
    node: *tree.Node,
    encoder: *writer_codec.Encoder,
) Error!void {
    if (node.compressed_data != null)
        return writer_clusters.writePrepared(image, node);
    const indexes = node.compressed_indexes orelse return error.InvalidErofs;
    if (node.compressed_block_count > indexes.len) return error.InvalidErofs;
    const physical_content_len = try writer_clusters.prefixLength(node);
    var chunk_storage: [block_size]u8 = undefined;
    for (indexes[0..node.compressed_block_count], 0..) |*index, cluster_index| {
        const logical_start = try checkedMul(cluster_index, block_size);
        const logical_end = @min(
            physical_content_len,
            try checkedAdd(logical_start, block_size),
        );
        const chunk = chunk_storage[0 .. logical_end - logical_start];
        try node.readContent(logical_start, chunk);
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
    node: *const tree.Node,
    node_index: usize,
    compression: Compression,
    xattr_prefixes: []const []const u8,
    shared_xattr_plan: ?*const writer_xattrs.Plan,
    epoch: u64,
    fixed_nsec: u32,
) Error!void {
    try writer_inode.writeHeader(metadata, node, node_index, epoch, fixed_nsec);
    const location = node.location;
    const layout = std.enums.fromInt(format.Layout, node.layout) orelse
        return error.InvalidErofs;
    const xattr_start = try checkedAdd(location, node.inode_size);
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

    if (compression_metadata.isCompressed(layout))
        try compression_metadata.write(metadata, node, compression);
}

pub fn writeSuperblock(
    image: []u8,
    nodes: []const tree.Node,
    block_count: usize,
    options: Options,
    chunk_plan: ?writer_chunks.Plan,
    shared_xattr_plan: ?*const writer_xattrs.Plan,
) Error!void {
    const extent = writer_codec.ExtentOptions{
        .decoded_size = options.compression_extent_size,
        .max_pcluster_size = options.max_pcluster_size,
    };
    if (image.len < block_size or nodes.len == 0 or nodes.len > std.math.maxInt(u64) or
        block_count > std.math.maxInt(u32))
        return error.InvalidErofs;
    const base = format.super_offset;
    const prefix_count = options.xattr_prefixes.len;
    const configuration_start = configurationStart(options.metabox);
    const configuration_end = try checkedAdd(
        configuration_start,
        writer_codec.configurationSizeForExtent(options.compression, extent),
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
        writer_codec.featureIncompatForExtent(options.compression, extent) |
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
    writeU16(image, base + 84, writer_codec.compressionFieldForExtent(options.compression, extent));
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
    const configuration_size = writer_codec.configurationSizeForExtent(options.compression, extent);
    if (configuration_size != 0) {
        const end = try checkedAdd(configuration_start, configuration_size);
        if (end > image.len) return error.InvalidErofs;
        try writer_codec.writeConfigurationForExtent(image[configuration_start..end], options.compression, extent);
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
        const device_size = try plan.dataSize();
        if (table_end > image.len or device_size % block_size != 0)
            return error.InvalidErofs;
        const device_blocks = device_size / block_size;
        if (device_blocks > std.math.maxInt(u32)) return error.InvalidErofs;
        writeU32(image, device_table_start + 64, @intCast(device_blocks));
        writeU32(image, device_table_start + 68, @intCast(block_count));
    }
    writeU32(image, base + 108, options.build_time);
    writeU32(image, base + 4, format.computeSuperblockChecksum(image[base..block_size]));
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
