const std = @import("std");
const tree = @import("tree.zig");
const format = @import("../format.zig");
const codec = @import("codec.zig");
const indexes = @import("../compression_index.zig");
const compact = @import("compact_indexes.zig");
const clusters = @import("clusters.zig");
const math = @import("math.zig");

pub const Error = compact.Error || clusters.Error || math.Error;

pub fn isCompressed(layout: format.Layout) bool {
    return layout == .compressed_full or layout == .compressed_compact;
}

fn headerStart(node: *const tree.Node) Error!usize {
    return math.alignForward(try math.checkedAdd(try math.checkedAdd(node.location, node.inode_size), node.xattr_size), 8);
}

fn advise(node: *const tree.Node) u16 {
    return node.compressed_advise | (if (node.layout == @intFromEnum(format.Layout.compressed_compact) and node.compressed_advise & 2 != 0) @as(u16, 4) else 0);
}

fn view(node: *const tree.Node) Error!indexes.View {
    return .{ .index_start = try math.checkedAdd(try headerStart(node), 8), .cluster_bits = 12, .advise = advise(node), .block_size = 4096 };
}

pub fn end(node: *const tree.Node) Error!usize {
    const records = node.compressed_indexes orelse return error.InvalidErofs;
    if (node.layout == @intFromEnum(format.Layout.compressed_compact))
        return indexes.compactIndexEnd(try view(node), records.len);
    if (node.layout != @intFromEnum(format.Layout.compressed_full)) return error.InvalidErofs;
    return math.checkedAdd(try math.checkedAdd(try headerStart(node), 16), try math.checkedMul(records.len, 8));
}

pub fn write(metadata: []u8, node: *const tree.Node, compression: codec.Compression) Error!void {
    const start = try headerStart(node);
    const index_end = try end(node);
    if (index_end > metadata.len) return error.InvalidErofs;
    const records = node.compressed_indexes.?;
    const full = node.layout == @intFromEnum(format.Layout.compressed_full);
    const header_size: usize = if (full) 16 else 8;
    @memset(metadata[start..][0..header_size], 0);
    if (node.fragment_size != 0 and node.fragment_size == node.contentSize()) {
        const offset = node.fragment_offset orelse return error.InvalidErofs;
        if (!full or offset >> 63 != 0 or records.len != 0) return error.InvalidErofs;
        std.mem.writeInt(u64, metadata[start..][0..8], offset | (@as(u64, 1) << 63), .little);
        return;
    }
    const fragment = node.fragment_offset;
    const inline_data = node.compressed_inline_data;
    if (fragment != null and inline_data != null) return error.InvalidErofs;
    var flags = advise(node);
    if (inline_data) |bytes| {
        if (bytes.len == 0 or bytes.len > std.math.maxInt(u16)) return error.InvalidErofs;
        std.mem.writeInt(u16, metadata[start + 2 ..][0..2], @intCast(bytes.len), .little);
        flags |= 0x08;
    } else if (fragment) |offset| {
        if (!full and offset > std.math.maxInt(u32)) return error.InvalidErofs;
        std.mem.writeInt(u32, metadata[start..][0..4], @truncate(offset), .little);
        flags |= 0x20;
    }
    std.mem.writeInt(u16, metadata[start + 4 ..][0..2], flags, .little);
    metadata[start + 6] = @intFromEnum(codec.algorithm(compression) orelse return error.InvalidErofs);
    if (full) {
        for (records, 0..) |record, index| {
            const position = start + 16 + index * 8;
            std.mem.writeInt(u16, metadata[position..][0..2], record.kind, .little);
            std.mem.writeInt(u16, metadata[position + 2 ..][0..2], record.logical_offset, .little);
            std.mem.writeInt(u32, metadata[position + 4 ..][0..4], record.physical_block, .little);
        }
    } else {
        const tail: ?usize = if (fragment != null or inline_data != null) (try clusters.prefixLength(node)) / 4096 else null;
        const first = if (node.start_block == std.math.maxInt(u32)) 1 else node.start_block;
        try compact.write(metadata, try view(node), records, first, tail);
    }
    if (inline_data) |bytes| {
        const inline_end = try math.checkedAdd(index_end, bytes.len);
        if (inline_end > metadata.len or index_end / 4096 != (inline_end - 1) / 4096) return error.InvalidErofs;
        @memcpy(metadata[index_end..inline_end], bytes);
    }
}
