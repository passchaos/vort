const std = @import("std");
const tree = @import("tree.zig");
const writer_clusters = @import("clusters.zig");
const writer_wire = @import("wire.zig");
const write_plan = @import("plan.zig");
const options_module = @import("options.zig");
const layout = @import("layout.zig");
const math = @import("math.zig");
pub const Error = write_plan.Error || writer_wire.Error;
const Options = options_module.Options;
const block_size: usize = 4096;
const assignDataBlocks = layout.assignDataBlocks;
const assignNodeDataBlocks = layout.assignNodeDataBlocks;
const checkedMul = math.checkedMul;
const alignForward = math.alignForward;
pub const External = struct {
    image: []u8,
    device: []u8,
    pub fn deinit(self: *External, allocator: std.mem.Allocator) void {
        allocator.free(self.image);
        allocator.free(self.device);
    }
};
const Encoded = struct { image: []u8, device: ?[]u8 };

pub fn encodeAlloc(allocator: std.mem.Allocator, entries: []const tree.Entry, options: Options) Error![]u8 {
    return (try encode(allocator, entries, options, false)).image;
}

pub fn encodeExternalChunksAlloc(allocator: std.mem.Allocator, entries: []const tree.Entry, options: Options) Error!External {
    const output = try encode(allocator, entries, options, true);
    errdefer allocator.free(output.image);
    return .{ .image = output.image, .device = output.device orelse return error.InvalidErofs };
}

// Retained allocating orchestration supplies an independent byte-comparison path.
fn encode(allocator: std.mem.Allocator, entries: []const tree.Entry, options: Options, external_chunks: bool) Error!Encoded {
    var prepared = try write_plan.Plan.init(allocator, entries, options, external_chunks, false);
    defer prepared.deinit();
    const filesystem = &prepared.filesystem;

    if (prepared.grouped) {
        for (filesystem.nodes) |*node| {
            if (node.hidden_role == .metabox) continue;
            try writer_clusters.prepareNode(allocator, node, &prepared.encoder.?, options.compression_extent_size, options.max_pcluster_size);
        }
    }

    const first_data_block = try alignForward(prepared.metadata_end, block_size) / block_size;
    var block_count = try assignDataBlocks(filesystem, first_data_block, prepared.grouped and options.metabox);
    if (prepared.grouped and options.metabox) {
        try writer_wire.populateMetaboxMetadata(filesystem, options, if (prepared.xattrs) |*plan| plan else null);
        for (filesystem.nodes) |*node| {
            if (node.hidden_role != .metabox) continue;
            try writer_clusters.prepareNode(allocator, node, &prepared.encoder.?, options.compression_extent_size, options.max_pcluster_size);
            try assignNodeDataBlocks(node, &block_count);
        }
    }
    if (prepared.chunks) |*plan| block_count = try plan.assign(filesystem.nodes, block_count);
    const image_len = try checkedMul(block_count, block_size);
    const image = try allocator.alloc(u8, image_len);
    errdefer allocator.free(image);
    @memset(image, 0);

    try writer_wire.writeNodes(
        image,
        filesystem,
        options.compression,
        options.xattr_prefixes,
        if (prepared.encoder) |*encoder| encoder else null,
        if (prepared.xattrs) |*plan| plan else null,
        options.epoch,
        options.fixed_nsec,
    );
    if (prepared.chunks) |plan| try plan.writeLocal(image);
    try writer_wire.writeSuperblock(
        image,
        filesystem.nodes,
        block_count,
        options,
        if (prepared.chunks) |plan| plan else null,
        if (prepared.xattrs) |*plan| plan else null,
    );
    const device = if (external_chunks)
        if (prepared.chunks) |*plan| plan.takeData() else try allocator.alloc(u8, 0)
    else
        null;
    return .{ .image = image, .device = device };
}
