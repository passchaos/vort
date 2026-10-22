const std = @import("std");
const context_module = @import("context.zig");
const types = @import("types.zig");
const format = @import("../format.zig");
const flat = @import("flat.zig");
const extents = @import("extents.zig");
const sink_module = @import("../../io/sink.zig");

pub const Error = context_module.Error;
const Context = context_module.Context;
const Head = struct { logical_start: usize, physical_block: u32, kind: u2, blocks: ?u32 };

pub fn emit(context: Context, inode: types.Inode, start: usize, size: usize, sink: sink_module.Sink, destination: u64) Error!void {
    const end = try context_module.add(start, size);
    if (end > inode.file_size) return error.InvalidErofs;
    if (size == 0) return;
    if (inode.fragment_offset != null and inode.compressed_inline_size != 0) return error.InvalidErofs;
    const prefix_end = if (inode.compressed_inline_size != 0) inode.compressed_inline_logical_start else if (inode.fragment_offset != null) inode.fragment_logical_start else inode.file_size;
    if (prefix_end > inode.file_size) return error.InvalidErofs;
    const prefix_range_end = @min(end, prefix_end);
    if (start < prefix_range_end) try emitPrefix(context, inode, start, prefix_range_end - start, sink, destination);
    if (end <= prefix_end) return;
    const tail_start = @max(start, prefix_end);
    const tail_destination = try context_module.offset(destination, tail_start - start);
    if (inode.compressed_inline_size != 0) {
        try emitInline(context, inode, tail_start - prefix_end, end - tail_start, sink, tail_destination);
    } else if (inode.fragment_offset) |fragment| {
        if (context.reader.superblock.feature_incompat & format.feature_incompat_fragments == 0 or context.reader.superblock.packed_nid == 0 or inode.nid == context.reader.superblock.packed_nid) return error.InvalidErofs;
        const offset = std.math.cast(usize, fragment) orelse return error.IntegerOverflow;
        try emitPacked(context, try context_module.add(offset, tail_start - prefix_end), end - tail_start, sink, tail_destination);
    }
}

fn emitInline(context: Context, inode: types.Inode, start: usize, size: usize, sink: sink_module.Sink, destination: u64) Error!void {
    const metadata = try context.reader.metadataInput(inode);
    const tail_size = inode.file_size - inode.compressed_inline_logical_start;
    _ = try metadata.end(inode.compressed_inline_start, inode.compressed_inline_size);
    if (inode.compressed_inline_kind == 0) {
        if (tail_size != inode.compressed_inline_size) return error.InvalidErofs;
        try context.copy(metadata, try context_module.offset(inode.compressed_inline_start, start), size, sink, destination);
        return;
    }
    if (inode.compressed_inline_kind != 1 and inode.compressed_inline_kind != 3) return error.InvalidErofs;
    const algorithm = inode.compressed_algorithms[if (inode.compressed_inline_kind == 3) 1 else 0] orelse return error.InvalidErofs;
    const decoded = try context.decode(algorithm, metadata, inode.compressed_inline_start, inode.compressed_inline_size, tail_size);
    defer context.allocator.free(decoded);
    try sink.writeExact(destination, decoded[start..][0..size]);
}

fn emitPacked(context: Context, start: usize, size: usize, sink: sink_module.Sink, destination: u64) Error!void {
    const packed_inode = try context.reader.inode(context.reader.superblock.packed_nid);
    if (try packed_inode.fileType() != .regular or packed_inode.fragment_offset != null or try context_module.add(start, size) > packed_inode.file_size) return error.InvalidErofs;
    if (packed_inode.layout == .flat_plain or packed_inode.layout == .flat_inline) return flat.emit(context, packed_inode, start, size, sink, destination);
    if (packed_inode.layout != .compressed_full and packed_inode.layout != .compressed_compact) return error.UnsupportedErofsLayout;
    var bounded = context;
    bounded.limits.max_decoded_extent_size = @min(context.limits.max_decoded_extent_size, context.limits.max_packed_extent_size);
    if (packed_inode.compressed_extent_record_size != 0) return extents.emit(bounded, packed_inode, start, size, sink, destination);
    try emit(bounded, packed_inode, start, size, sink, destination);
}

fn emitPrefix(context: Context, inode: types.Inode, start: usize, size: usize, sink: sink_module.Sink, destination: u64) Error!void {
    _ = inode.compressed_algorithms[0] orelse return error.InvalidErofs;
    if (inode.compressed_cluster_bits >= @bitSizeOf(usize)) return error.UnsupportedErofsFeature;
    const cluster_size: usize = @as(usize, 1) << @intCast(inode.compressed_cluster_bits);
    const count = (try context_module.add(inode.file_size, cluster_size - 1)) / cluster_size;
    const end = try context_module.add(start, size);
    var previous: ?Head = null;
    for (0..count) |index| {
        const record = if (inode.layout == .compressed_full) try context.reader.readFullIndex(inode, index) else try context.reader.readCompactIndex(inode, index, count);
        if (record.kind == 2) continue;
        if (record.logical_offset >= cluster_size) return error.InvalidErofs;
        const base = std.math.mul(usize, index, cluster_size) catch return error.IntegerOverflow;
        const logical = try context_module.add(base, record.logical_offset);
        const head = Head{ .logical_start = logical, .physical_block = record.physical_block, .kind = record.kind, .blocks = try context.reader.compressedBlockCount(inode, index, count, logical, record.kind) };
        if (previous) |prior| {
            if (head.logical_start <= prior.logical_start) return error.InvalidErofs;
            try emitHead(context, inode, prior, head, start, size, sink, destination);
        } else if (start < @min(end, logical)) {
            // The slice reference initializes uncovered leading bytes to zero.
            try context.zeros(@min(end, logical) - start, sink, destination);
        }
        previous = head;
    }
    try emitHead(context, inode, previous orelse return error.InvalidErofs, null, start, size, sink, destination);
}

fn emitHead(context: Context, inode: types.Inode, head: Head, next: ?Head, start: usize, size: usize, sink: sink_module.Sink, destination: u64) Error!void {
    if (head.logical_start >= inode.file_size) return;
    const logical_end = @min(inode.file_size, if (next) |value| value.logical_start else inode.file_size);
    if (logical_end <= head.logical_start) return error.InvalidErofs;
    const overlap_start = @max(head.logical_start, start);
    const overlap_end = @min(logical_end, try context_module.add(start, size));
    if (overlap_start >= overlap_end) return;
    const block_size = context.reader.superblock.block_size;
    const physical_start = std.math.mul(u64, head.physical_block, block_size) catch return error.IntegerOverflow;
    const blocks: usize = if (head.blocks) |value| value else if (next) |value| if (inode.fragment_offset != null and value.logical_start == inode.fragment_logical_start) 1 else if (value.physical_block > head.physical_block) value.physical_block - head.physical_block else 1 else 1;
    const physical_size = std.math.mul(usize, blocks, block_size) catch return error.IntegerOverflow;
    _ = try context.reader.primary.endAt(physical_start, physical_size);
    const extent_size = logical_end - head.logical_start;
    const extent_offset = overlap_start - head.logical_start;
    const output = try context_module.offset(destination, overlap_start - start);
    if (head.kind == 0) {
        if (inode.compressed_advise & 0x10 != 0) {
            if (extent_size > block_size or physical_size < block_size) return error.InvalidErofs;
            const rotation = head.logical_start % block_size;
            var position: usize = 0;
            while (position < overlap_end - overlap_start) {
                const offset = (rotation + extent_offset + position) % block_size;
                const count = @min(block_size - offset, overlap_end - overlap_start - position);
                try context.copy(context.reader.primary, try context_module.offset(physical_start, offset), count, sink, try context_module.offset(output, position));
                position += count;
            }
        } else {
            if (try context_module.add(extent_offset, overlap_end - overlap_start) > physical_size) return error.InvalidErofs;
            try context.copy(context.reader.primary, try context_module.offset(physical_start, extent_offset), overlap_end - overlap_start, sink, output);
        }
    } else if (head.kind == 1 or head.kind == 3) {
        const algorithm = inode.compressed_algorithms[if (head.kind == 3) 1 else 0] orelse return error.InvalidErofs;
        const decoded = try context.decode(algorithm, context.reader.primary, physical_start, physical_size, extent_size);
        defer context.allocator.free(decoded);
        try sink.writeExact(output, decoded[extent_offset..][0 .. overlap_end - overlap_start]);
    } else return error.UnsupportedErofsFeature;
}
