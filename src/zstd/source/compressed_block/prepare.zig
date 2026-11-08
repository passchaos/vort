//! Ordered metadata preparation for one source-backed compressed block.
const core = @import("../../../core.zig");
const source_frame = @import("../frame.zig");
const source_huffman = @import("../huffman.zig");
const source_input = @import("../input.zig");
const source_literals = @import("../literals.zig");
const source_sequences = @import("../sequences.zig");

pub const Error = core.Error || source_input.Error;

/// Keep this value at a stable address after `prepare` returns. The literal
/// and sequence cursors borrow pending tables stored inside it.
pub fn Prepared(comptime HuffmanCodec: type, comptime SequenceCodec: type) type {
    return struct {
        literals: source_literals.Layout,
        pending_huffman: ?source_huffman.Prepared(HuffmanCodec),
        pending_sequences: ?source_sequences.Prepared(SequenceCodec.Tables),
        last: bool,
    };
}

/// Parse in slice-decoder error-priority order: literal prefix, Huffman
/// preparation, literal layout finish, then sequence preparation.
pub fn prepare(
    comptime HuffmanCodec: type,
    comptime SequenceCodec: type,
    block: source_frame.BlockLayout,
    committed: anytype,
    scratch: []u8,
) Error!Prepared(HuffmanCodec, SequenceCodec) {
    // This rejection must precede every possible source callback.
    if (block.header.kind != .compressed) return error.CorruptFrame;
    if (block.header.wire_len != block.header.declared_len or
        block.payload.len != @as(u64, @intCast(block.header.wire_len)))
        return error.CorruptFrame;

    const prefix = try source_literals.parsePrefix(
        block.payload,
        committed.huffman != null,
    );
    const previous_huffman: ?*const HuffmanCodec.Table =
        if (committed.huffman) |*table| table else null;
    const pending_huffman = try source_huffman.prepare(
        HuffmanCodec,
        prefix,
        previous_huffman,
        scratch,
    );
    const literals = try source_literals.finishLayout(prefix);
    const previous_sequences: ?*const SequenceCodec.Tables =
        if (committed.sequence_tables) |*tables| tables else null;
    const pending_sequences = try source_sequences.prepare(
        SequenceCodec,
        literals,
        previous_sequences,
        scratch,
    );
    return .{
        .literals = literals,
        .pending_huffman = pending_huffman,
        .pending_sequences = pending_sequences,
        .last = block.header.last,
    };
}
