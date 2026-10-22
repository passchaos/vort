const context_module = @import("context.zig");
const types = @import("types.zig");
const sink_module = @import("../../io/sink.zig");
const flat = @import("flat.zig");
const chunks = @import("chunks.zig");
const compression = @import("compression.zig");
const extents = @import("extents.zig");

pub const Error = context_module.Error || extents.Error;

/// Emits the requested logical range; only the outer API commits final length.
pub fn emit(context: context_module.Context, inode: types.Inode, start: usize, size: usize, sink: sink_module.Sink, destination: u64) Error!void {
    if (try context_module.add(start, size) > inode.file_size) return error.InvalidErofs;
    return switch (inode.layout) {
        .flat_plain, .flat_inline => flat.emit(context, inode, start, size, sink, destination),
        .chunk_based => chunks.emit(context, inode, start, size, sink, destination),
        .compressed_full, .compressed_compact => if (inode.compressed_extent_record_size != 0) extents.emit(context, inode, start, size, sink, destination) else compression.emit(context, inode, start, size, sink, destination),
    };
}
