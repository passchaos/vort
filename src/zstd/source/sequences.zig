//! Source-backed preparation of Zstandard sequence-mode metadata.
//!
//! This layer consumes only the forward mode byte and RLE/FSE descriptions. It
//! returns a checked absolute range for the reverse sequence bitstream without
//! reading its marker or mutating the caller's committed table snapshot.
const std = @import("std");
const core = @import("../../core.zig");
const normalized_counts = @import("../sequence/normalized_counts.zig");
const forward = @import("forward_cursor.zig");
const source_input = @import("input.zig");
const source_literals = @import("literals.zig");

pub const Error = core.Error || source_input.Error;

pub const Mode = enum(u2) { predefined, rle, compressed, repeat };
pub const Field = enum { literal_length, offset, match_length };

pub const WireModes = struct {
    literal_length: Mode,
    offset: Mode,
    match_length: Mode,
};

pub fn Prepared(comptime Tables: type) type {
    return struct {
        sequence_count: usize,
        mode_byte: u8,
        wire_modes: WireModes,
        repeat_mask: u3,
        tables: Tables,
        mode_range: source_input.Range,
        descriptions: [3]?source_input.Range,
        table_descriptions: source_input.Range,
        bitstream: source_input.Range,
        tables_end: u64,
        source_reads: u64,
        source_bytes: u64,
        max_request: usize,
    };
}

pub fn prepare(
    comptime Codec: type,
    layout: source_literals.Layout,
    previous_tables: ?*const Codec.Tables,
    scratch: []u8,
) Error!?Prepared(Codec.Tables) {
    if (layout.sequence_count == 0) {
        if (layout.sequence_payload.len != 0) return error.CorruptFrame;
        return null;
    }

    var cursor = try forward.Cursor.init(layout.sequence_payload, scratch);
    const mode_byte = try cursor.byte();
    if ((mode_byte & 0x03) != 0) return error.CorruptFrame;
    const wire_modes = WireModes{
        .literal_length = @enumFromInt(mode_byte >> 6),
        .offset = @enumFromInt((mode_byte >> 4) & 0x03),
        .match_length = @enumFromInt((mode_byte >> 2) & 0x03),
    };
    const modes = [3]Mode{
        wire_modes.literal_length,
        wire_modes.offset,
        wire_modes.match_length,
    };
    var spec = Codec.initSpec(modes);
    var description_ranges: [3]?source_input.Range = @splat(null);
    var repeat_mask: u3 = 0;

    inline for (.{ Field.literal_length, Field.offset, Field.match_length }, 0..) |field, index| {
        const start = cursor.relativeOffset();
        switch (modes[index]) {
            .predefined => {},
            .repeat => repeat_mask |= @as(u3, 1) << @intCast(index),
            .rle => try Codec.setRle(&spec, field, try cursor.byte()),
            .compressed => {
                var values: [256]u16 = undefined;
                var bits = forward.BitReader{ .cursor = &cursor };
                const limits = Codec.limits(field);
                const decoded = try normalized_counts.parseReader(
                    forward.Error,
                    &bits,
                    limits.symbol_count,
                    limits.max_accuracy_log,
                    &values,
                );
                bits.alignToByte();
                try Codec.buildFse(
                    &spec,
                    field,
                    values[0..decoded.value_count],
                    decoded.table_len,
                );
            },
        }
        const end = cursor.relativeOffset();
        if (end != start)
            description_ranges[index] = try layout.sequence_payload.subrange(start, end - start);
    }

    if (cursor.remaining() == 0) return error.TruncatedFrame;
    const tables = try Codec.resolve(spec, previous_tables);
    const bitstream = try cursor.remainingRange();
    const mode_range = try layout.sequence_payload.subrange(0, 1);
    const descriptions = try layout.sequence_payload.subrange(1, cursor.relativeOffset() - 1);
    const snapshot = cursor.snapshot();
    return .{
        .sequence_count = layout.sequence_count,
        .mode_byte = mode_byte,
        .wire_modes = wire_modes,
        .repeat_mask = repeat_mask,
        .tables = tables,
        .mode_range = mode_range,
        .descriptions = description_ranges,
        .table_descriptions = descriptions,
        .bitstream = bitstream,
        .tables_end = try cursor.absoluteOffset(),
        .source_reads = snapshot.read_calls,
        .source_bytes = snapshot.bytes_loaded,
        .max_request = snapshot.max_request,
    };
}
