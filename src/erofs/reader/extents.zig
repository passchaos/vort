const std = @import("std");
const extent = @import("../extent.zig");
const context_module = @import("context.zig");
const types = @import("types.zig");
const format = @import("../format.zig");
const sink_module = @import("../../io/sink.zig");

pub const Error = context_module.Error || extent.Error;

pub fn emit(context: context_module.Context, inode: types.Inode, start: usize, size: usize, sink: sink_module.Sink, destination: u64) Error!void {
    const end = try context_module.add(start, size);
    if (end > inode.file_size) return error.InvalidErofs;
    if (size == 0) return;
    const metadata = try context.reader.metadataInput(inode);
    const view = extent.View{ .file_size = inode.file_size, .advise = inode.compressed_advise, .cluster_bits = inode.compressed_cluster_bits, .record_start = inode.compressed_extent_start, .record_size = inode.compressed_extent_record_size, .record_count = inode.compressed_extent_count };
    var cumulative: u64 = if (view.record_size == 4) try metadata.integer(u64, view.record_start) else 0;
    var previous: ?extent.Record = null;
    for (0..view.record_count) |index| {
        const record = try extent.readRecordInput(metadata, view, index, &cumulative);
        if (previous) |prior| {
            if (record.logical_start <= prior.logical_start) return error.InvalidErofs;
            try emitRecord(context, inode, prior, record.logical_start, start, size, sink, destination);
        } else if (start < @min(end, record.logical_start)) {
            try context.zeros(@min(end, record.logical_start) - start, sink, destination);
        }
        previous = record;
    }
    try emitRecord(context, inode, previous orelse return error.InvalidErofs, inode.file_size, start, size, sink, destination);
}

fn emitRecord(context: context_module.Context, inode: types.Inode, record: extent.Record, logical_end: usize, start: usize, size: usize, sink: sink_module.Sink, destination: u64) Error!void {
    if (logical_end <= record.logical_start or logical_end > inode.file_size) return error.InvalidErofs;
    const overlap_start = @max(start, record.logical_start);
    const overlap_end = @min(logical_end, try context_module.add(start, size));
    if (overlap_start >= overlap_end) return;
    _ = try context.reader.primary.endAt(record.physical_start, record.encoded_len);
    const logical_size = logical_end - record.logical_start;
    const within = overlap_start - record.logical_start;
    const output = try context_module.offset(destination, overlap_start - start);
    if (record.format_code == 0) {
        if (logical_size > record.encoded_len) return error.InvalidErofs;
        const block_size = context.reader.superblock.block_size;
        if (inode.compressed_advise & 0x10 != 0 and record.physical_start % block_size == 0 and record.encoded_len % block_size == 0) {
            if (logical_size > block_size) return error.InvalidErofs;
            const rotation = record.logical_start % block_size;
            var position: usize = 0;
            while (position < overlap_end - overlap_start) {
                const offset = (rotation + within + position) % block_size;
                const count = @min(block_size - offset, overlap_end - overlap_start - position);
                try context.copy(context.reader.primary, try context_module.offset(record.physical_start, offset), count, sink, try context_module.offset(output, position));
                position += count;
            }
        } else {
            try context.copy(context.reader.primary, try context_module.offset(record.physical_start, within), overlap_end - overlap_start, sink, output);
        }
        return;
    }
    const algorithm = std.enums.fromInt(format.Compression, @as(u8, record.format_code - 1)) orelse return error.UnsupportedErofsCompression;
    const decoded = try context.decode(algorithm, context.reader.primary, record.physical_start, record.encoded_len, logical_size);
    defer context.allocator.free(decoded);
    try sink.writeExact(output, decoded[within..][0 .. overlap_end - overlap_start]);
}
