const std = @import("std");
const core = @import("../core.zig");
const format = @import("format.zig");
const tree = @import("writer/tree.zig");
const writer_codec = @import("writer/codec.zig");
const writer_chunks = @import("writer/chunks.zig");
const writer_fragments = @import("writer/fragments.zig");
const writer_metabox = @import("writer/metabox.zig");
const writer_xattrs = @import("writer/xattrs.zig");
const writer_inode = @import("writer/inode.zig");
const writer_clusters = @import("writer/clusters.zig");
const xattr = @import("xattr.zig");
const writer_options = @import("writer/options.zig");
const writer_wire = @import("writer/wire.zig");

pub const Error = core.Error || writer_codec.Error || writer_chunks.Error ||
    writer_fragments.Error || writer_metabox.Error || writer_xattrs.Error ||
    tree.Error || xattr.Error || writer_wire.Error || error{InvalidErofs};

pub const Entry = tree.Entry;
pub const EntryKind = tree.EntryKind;
pub const Xattr = tree.Xattr;
pub const Source = tree.Source;

pub const Compression = writer_options.Compression;
pub const TailPacking = writer_options.TailPacking;
pub const InodeVersion = writer_options.InodeVersion;
pub const Options = writer_options.Options;

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
    if (options.compression_extent_size < block_size or
        options.compression_extent_size > writer_clusters.max_extent_size or
        !std.math.isPowerOfTwo(options.compression_extent_size) or
        (options.compression == .stored and options.compression_extent_size != block_size))
        return error.InvalidErofs;
    if (options.max_pcluster_size) |capacity| {
        if (capacity < block_size or capacity > writer_clusters.max_extent_size or
            capacity % block_size != 0 or options.compression == .stored)
            return error.InvalidErofs;
    }
    const grouped = options.compression_extent_size > block_size or options.max_pcluster_size != null;
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
    filesystem.nodes[0].mode = options.root_mode;
    filesystem.nodes[0].uid = options.root_uid;
    filesystem.nodes[0].gid = options.root_gid;
    filesystem.nodes[0].modification_time = options.root_modification_time;
    filesystem.nodes[0].modification_nsec = options.root_modification_nsec;
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
    if (grouped and options.compression == .zstandard)
        block_encoder.?.zstandard_window_log = 15;
    const metadata_end = try planMetadata(
        allocator,
        &filesystem,
        options,
        if (block_encoder) |*encoder| encoder else null,
        chunk_plan != null and external_chunks and chunk_plan.?.active(),
        if (shared_xattr_plan) |*plan| plan else null,
    );
    try fillDirectories(allocator, &filesystem);
    try writer_fragments.syncDirectories(&filesystem);

    if (grouped) {
        for (filesystem.nodes) |*node| {
            if (node.hidden_role == .metabox) continue;
            try writer_clusters.prepareNode(allocator, node, &block_encoder.?, options.compression_extent_size, options.max_pcluster_size);
        }
    }

    const first_data_block = try alignForward(metadata_end, block_size) / block_size;
    var block_count = try assignDataBlocks(&filesystem, first_data_block, grouped and options.metabox);
    if (grouped and options.metabox) {
        try writer_wire.populateMetaboxMetadata(&filesystem, options, if (shared_xattr_plan) |*plan| plan else null);
        for (filesystem.nodes) |*node| {
            if (node.hidden_role != .metabox) continue;
            try writer_clusters.prepareNode(allocator, node, &block_encoder.?, options.compression_extent_size, options.max_pcluster_size);
            try assignNodeDataBlocks(node, &block_count);
        }
    }
    if (chunk_plan) |*plan| block_count = try plan.assign(filesystem.nodes, block_count);
    const image_len = try checkedMul(block_count, block_size);
    const image = try allocator.alloc(u8, image_len);
    errdefer allocator.free(image);
    @memset(image, 0);

    try writer_wire.writeNodes(
        image,
        &filesystem,
        options.compression,
        options.xattr_prefixes,
        if (block_encoder) |*encoder| encoder else null,
        if (shared_xattr_plan) |*plan| plan else null,
        options.epoch,
        options.fixed_nsec,
    );
    if (chunk_plan) |plan| try plan.writeLocal(image);
    try writer_wire.writeSuperblock(
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
    options: Options,
    block_encoder: ?*writer_codec.Encoder,
    external_chunks: bool,
    shared_xattr_plan: ?*writer_xattrs.Plan,
) Error!usize {
    const compression = options.compression;
    const xattr_prefixes = options.xattr_prefixes;
    const tail_packing = options.tail_packing;
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
        node.layout = @intFromEnum(format.Layout.compressed_full);
        const whole_fragment = node.fragment_size != 0 and
            node.fragment_size == content_size;
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
        const header_start = try alignForward(xattr_end, 8);
        const metadata_end = try checkedAdd(
            header_start,
            try checkedAdd(16, try checkedMul(cluster_count, 8)),
        );
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

fn assignDataBlocks(filesystem: *tree.Tree, first_data_block: usize, skip_metabox: bool) Error!usize {
    var next_block = first_data_block;
    for (filesystem.nodes) |*node| {
        if (skip_metabox and node.hidden_role == .metabox) continue;
        try assignNodeDataBlocks(node, &next_block);
    }
    if (next_block == 0 or next_block > std.math.maxInt(u32))
        return error.InvalidErofs;
    return next_block;
}

fn assignNodeDataBlocks(node: *tree.Node, next_block: *usize) Error!void {
    const content_len = node.contentSize();
    const physical_content_len = try writer_clusters.prefixLength(node);
    const blocks = switch (std.enums.fromInt(format.Layout, node.layout) orelse
        return error.InvalidErofs) {
        .compressed_full => if (node.compressed_data) |bytes|
            bytes.len / block_size
        else
            try blockCount(physical_content_len),
        .flat_inline => content_len / block_size,
        .flat_plain => try blockCount(content_len),
        .chunk_based => 0,
        else => return error.InvalidErofs,
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

fn writeU64(output: []u8, offset: usize, value: u64) void {
    std.mem.writeInt(u64, output[offset..][0..8], value, .little);
}

fn writeU16(output: []u8, offset: usize, value: u16) void {
    std.mem.writeInt(u16, output[offset..][0..2], value, .little);
}
