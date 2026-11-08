//! Transactional Huffman table preparation over a source literals layout.
//!
//! Tree descriptions are format-bounded to 128 bytes, so callers provide one
//! small scratch buffer for the complete description. Literal entropy streams
//! remain unread; their paged reverse execution belongs to the next stage.
const std = @import("std");
const core = @import("../../core.zig");
const tree_description = @import("../literals/tree_description.zig");
const source_input = @import("input.zig");
const source_literals = @import("literals.zig");

pub const Error = core.Error || source_input.Error;
pub const maximum_scratch_len: usize = tree_description.max_len;

pub const Origin = enum {
    new_tree,
    treeless_reuse,
};

pub fn Prepared(comptime Codec: type) type {
    return struct {
        table: Codec.Table,
        origin: Origin,
        description: ?source_input.Range,
        description_bytes: u64,
        /// Publish `table` only after the complete compressed block succeeds.
        /// Treeless blocks keep the already committed table unchanged.
        replace_on_block_success: bool,
    };
}

/// Prepare the Huffman tree and complete lookup needed by literal execution.
/// `committed` is immutable: success returns a pending value and every error
/// leaves the caller's frame state untouched.
pub fn prepare(
    comptime Codec: type,
    layout: source_literals.PrefixLayout,
    committed: ?*const Codec.Table,
    scratch: []u8,
) Error!?Prepared(Codec) {
    return switch (layout.kind) {
        .raw, .rle => {
            if (layout.tree_description != null or layout.stream_data != null)
                return error.CorruptFrame;
            return null;
        },
        .treeless => {
            if (layout.tree_description != null or layout.stream_data == null)
                return error.CorruptFrame;
            const previous = committed orelse return error.CorruptFrame;
            return .{
                .table = previous.*,
                .origin = .treeless_reuse,
                .description = null,
                .description_bytes = 0,
                .replace_on_block_success = false,
            };
        },
        .compressed => {
            if (layout.stream_data == null) return error.CorruptFrame;
            const description = layout.tree_description orelse
                return error.CorruptFrame;
            if (description.len == 0 or description.len > maximum_scratch_len)
                return error.CorruptFrame;
            const description_len = std.math.cast(usize, description.len) orelse
                return error.IntegerOverflow;
            if (scratch.len < description_len) return error.OutputTooSmall;
            try description.readExact(0, scratch[0..description_len]);
            const table = try Codec.decodeDescription(scratch[0..description_len]);
            return .{
                .table = table,
                .origin = .new_tree,
                .description = description,
                .description_bytes = description.len,
                .replace_on_block_success = true,
            };
        },
    };
}

comptime {
    std.debug.assert(maximum_scratch_len == 128);
}
