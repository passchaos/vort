const std = @import("std");
const context_module = @import("context.zig");
const types = @import("types.zig");
const format = @import("../format.zig");
const sink_module = @import("../../io/sink.zig");

pub const Error = context_module.Error;

pub fn emit(context: context_module.Context, inode: types.Inode, start: usize, size: usize, sink: sink_module.Sink, destination: u64) Error!void {
    const end = try context_module.add(start, size);
    if (end > inode.file_size) return error.InvalidErofs;
    const block_size = context.reader.superblock.block_size;
    const full_bytes = if (inode.layout == .flat_inline) inode.file_size / block_size * block_size else inode.file_size;
    const data_end = @min(end, full_bytes);
    if (start < data_end) {
        const null_block: u64 = if (context.reader.superblock.feature_incompat & format.feature_incompat_48bit != 0) (@as(u64, 1) << 48) - 1 else std.math.maxInt(u32);
        if (inode.data_block == null_block) {
            try context.zeros(data_end - start, sink, destination);
        } else {
            const base = std.math.mul(u64, inode.data_block, block_size) catch return error.IntegerOverflow;
            // Validate the full physical prefix even for a range extraction.
            _ = try context.reader.primary.endAt(base, full_bytes);
            try context.copy(context.reader.primary, try context_module.offset(base, start), data_end - start, sink, destination);
        }
    }
    if (end > full_bytes) {
        if (inode.layout != .flat_inline) return error.InvalidErofs;
        const metadata = try context.reader.metadataInput(inode);
        const inline_start = try context_module.add(inode.location, try context_module.add(inode.inode_size, inode.xattr_size));
        const tail_size = inode.file_size - full_bytes;
        const inline_end = try metadata.end(inline_start, tail_size);
        if (tail_size != 0 and inline_start / block_size != (inline_end - 1) / block_size) return error.InvalidErofs;
        const read_start = @max(start, full_bytes);
        try context.copy(metadata, try context_module.offset(inline_start, read_start - full_bytes), end - read_start, sink, try context_module.offset(destination, read_start - start));
    }
}
