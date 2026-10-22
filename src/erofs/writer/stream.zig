const std = @import("std");
const tree = @import("tree.zig");
const format = @import("../format.zig");
const codec = @import("codec.zig");
const clusters = @import("clusters.zig");
const chunks = @import("chunks.zig");
const chunk_stream = @import("chunk_stream.zig");
const xattrs = @import("xattrs.zig");
const wire = @import("wire.zig");
const options_module = @import("options.zig");
const byte_sink = @import("../../io/sink.zig");

pub const Error = tree.Error || codec.Error || clusters.Error || chunk_stream.Error || wire.Error || byte_sink.Error;
pub const Result = struct { image_size: u64, device_size: u64 = 0 };
const block_size: usize = 4096;
const no_block = std.math.maxInt(u32);

const Output = struct {
    sink: byte_sink.Sink,
    offset: u64,
    fn append(raw: *anyopaque, bytes: []const u8) (std.mem.Allocator.Error || byte_sink.Error)!void {
        const self: *Output = @ptrCast(@alignCast(raw));
        const next = std.math.add(u64, self.offset, bytes.len) catch return error.IntegerOverflow;
        try self.sink.writeExact(self.offset, bytes);
        self.offset = next;
    }
};

fn finalizeIndexes(node: *tree.Node) Error!void {
    const indexes = node.compressed_indexes orelse return;
    const count = try clusters.blocksFor(try clusters.prefixLength(node));
    if (indexes.len < count) return error.InvalidErofs;
    for (indexes[0..count]) |*index| {
        if (index.kind == 2) continue;
        index.physical_block = std.math.add(u32, node.start_block, index.physical_block) catch return error.IntegerOverflow;
    }
}

fn emitNode(allocator: std.mem.Allocator, node: *tree.Node, options: options_module.Options, encoder: ?*codec.Encoder, output: *Output) Error!usize {
    var emitter = clusters.Emitter{ .context = output, .append_fn = Output.append };
    const layout = std.enums.fromInt(format.Layout, node.layout) orelse return error.InvalidErofs;
    if (layout == .compressed_full) {
        try clusters.emitNode(allocator, node, encoder orelse return error.InvalidErofs, options.compression_extent_size, options.max_pcluster_size, &emitter);
        if (emitter.written != 0) try finalizeIndexes(node);
    } else if (layout != .chunk_based) {
        const content_size = node.contentSize();
        const physical_size = if (layout == .flat_inline) content_size / block_size * block_size else content_size;
        var buffer: [64 * 1024]u8 = undefined;
        var position: usize = 0;
        while (position < physical_size) {
            const size = @min(buffer.len, physical_size - position);
            try node.readContent(position, buffer[0..size]);
            try emitter.append(buffer[0..size]);
            position += size;
        }
        const padded = std.math.mul(usize, try clusters.blocksFor(physical_size), block_size) catch return error.IntegerOverflow;
        try emitter.zeros(padded - physical_size);
    }
    if (emitter.written % block_size != 0) return error.InvalidErofs;
    return emitter.written / block_size;
}

pub fn emit(
    allocator: std.mem.Allocator,
    filesystem: *tree.Tree,
    options: options_module.Options,
    encoder: ?*codec.Encoder,
    chunk_plan: ?*chunks.Plan,
    shared_xattrs: ?*const xattrs.Plan,
    metadata_end: usize,
    fixed_block_count: ?usize,
    sink: byte_sink.Sink,
    device: ?byte_sink.Sink,
) Error!Result {
    const metadata_size = std.math.mul(usize, try clusters.blocksFor(metadata_end), block_size) catch return error.IntegerOverflow;
    const metadata = try allocator.alloc(u8, metadata_size);
    defer allocator.free(metadata);
    @memset(metadata, 0);
    var cursor: u64 = metadata_size;
    if (fixed_block_count) |_| {
        for (filesystem.nodes, 0..) |*node, index| {
            const expected = node.compressed_block_count;
            var output = Output{ .sink = sink, .offset = if (node.start_block == no_block) cursor else @as(u64, node.start_block) * block_size };
            _ = try emitNode(allocator, node, options, encoder, &output);
            if (node.compressed_indexes != null and node.compressed_block_count != expected) return error.InvalidErofs;
            try wire.writeNodeMetadata(metadata, filesystem, index, options, shared_xattrs);
        }
        cursor = std.math.mul(u64, fixed_block_count.?, block_size) catch return error.IntegerOverflow;
    } else {
        for (filesystem.nodes, 0..) |*node, index| {
            if (node.hidden_role == .metabox) continue;
            if (cursor / block_size > std.math.maxInt(u32)) return error.InvalidErofs;
            node.start_block = @intCast(cursor / block_size);
            var output = Output{ .sink = sink, .offset = cursor };
            const count = try emitNode(allocator, node, options, encoder, &output);
            if (count == 0) node.start_block = no_block;
            cursor = output.offset;
            try wire.writeNodeMetadata(metadata, filesystem, index, options, shared_xattrs);
        }
        for (filesystem.nodes, 0..) |*node, index| {
            if (node.hidden_role != .metabox) continue;
            try wire.populateMetaboxMetadata(filesystem, options, shared_xattrs);
            if (cursor / block_size > std.math.maxInt(u32)) return error.InvalidErofs;
            node.start_block = @intCast(cursor / block_size);
            var output = Output{ .sink = sink, .offset = cursor };
            _ = try emitNode(allocator, node, options, encoder, &output);
            cursor = output.offset;
            try wire.writeNodeMetadata(metadata, filesystem, index, options, shared_xattrs);
        }
    }
    if (cursor % block_size != 0 or cursor / block_size > std.math.maxInt(u32)) return error.InvalidErofs;
    var device_size: u64 = 0;
    if (chunk_plan) |plan| {
        if (plan.external) {
            const destination = device orelse return error.InvalidErofs;
            try chunk_stream.emit(plan.*, filesystem.nodes, destination, 0);
            device_size = try plan.dataSize();
        } else {
            try chunk_stream.emit(plan.*, filesystem.nodes, sink, @as(u64, plan.local_start_block) * block_size);
        }
    }
    try wire.writeSuperblock(metadata, filesystem.nodes, @intCast(cursor / block_size), options, if (chunk_plan) |plan| plan.* else null, shared_xattrs);
    try sink.writeExact(0, metadata);
    if (device) |destination| try destination.finish(device_size);
    try sink.finish(cursor);
    return .{ .image_size = cursor, .device_size = device_size };
}
