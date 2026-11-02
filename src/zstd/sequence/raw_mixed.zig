const std = @import("std");
const predefined = @import("predefined.zig");
const field_group = @import("field_group.zig");

pub const Sequence = struct {
    literal_len: usize,
    match_len: usize,
    match_offset: usize,
};

/// Execute the admitted raw block using the shared literal/history helpers.
/// The caller's cursor records valid output even if a later sequence fails;
/// continuation tables and repcodes commit only after the complete block.
pub inline fn execute(
    block: []const u8,
    section: anytype,
    output: []u8,
    written: *usize,
    frame_output_start: usize,
    dictionary_history: []const u8,
    frame_state: anytype,
    continuation: anytype,
    state: anytype,
    comptime resolve_offset: anytype,
    comptime copy_literals: anytype,
    comptime copy_match: anytype,
    comptime table_snapshot: anytype,
) !void {
    var literal_offset: usize = 0;
    while (state.remaining != 0) {
        const sequence = try read(state, resolve_offset);
        try copy_literals(block, section, literal_offset, output, written, sequence.literal_len);
        literal_offset = std.math.add(usize, literal_offset, sequence.literal_len) catch return error.IntegerOverflow;
        try copy_match(output, written, frame_output_start, dictionary_history, sequence.match_offset, sequence.match_len);
    }
    if (literal_offset > section.regenerated_size) return error.CorruptFrame;
    try copy_literals(block, section, literal_offset, output, written, section.regenerated_size - literal_offset);
    if (continuation.retainsState()) {
        frame_state.previous_tables = table_snapshot(state.spec);
        frame_state.repeated_offsets = state.repeated_offsets;
    }
}

/// Read the fixed LL=predefined, OF=compressed, ML=predefined mode selected
/// once by the block executor. Every read commits the same cursor progress as
/// the generic reader, including when offset resolution rejects a repcode.
pub inline fn read(state: anytype, comptime resolve_offset: anytype) !Sequence {
    if (state.remaining == 0 or
        state.ll_state >= predefined.literal_symbols.len or
        state.ml_state >= predefined.match_symbols.len or
        state.of_state >= state.spec.offset_fse.len) return error.CorruptFrame;
    const ll = predefined.literal_symbols[state.ll_state];
    const of = state.spec.offset_fse.entries[state.of_state];
    const ml = predefined.match_symbols[state.ml_state];
    const transitions: u8 = if (state.remaining == 1) 0 else ll.state_bits + ml.state_bits + of.state_bits;
    const total_bits = of.additional_bits + ml.additional_bits + ll.additional_bits + transitions;
    var group: ?field_group.Group = if (total_bits <= 56 and state.reader.remaining_bits >= 64)
        field_group.Group.initProven(&state.reader)
    else
        null;
    const offset_extra = try readField(&state.reader, &group, of.additional_bits);
    const match_len = std.math.add(usize, ml.base, try readField(&state.reader, &group, ml.additional_bits)) catch return error.IntegerOverflow;
    const literal_len = std.math.add(usize, ll.base, try readField(&state.reader, &group, ll.additional_bits)) catch return error.IntegerOverflow;
    const match_offset = try resolve_offset(of.base, of.additional_bits, offset_extra, literal_len, &state.repeated_offsets);
    state.remaining -= 1;
    if (state.remaining != 0) {
        state.ll_state = ll.next_state + try readField(&state.reader, &group, ll.state_bits);
        state.ml_state = ml.next_state + try readField(&state.reader, &group, ml.state_bits);
        state.of_state = of.next_state + try readField(&state.reader, &group, of.state_bits);
    } else try state.reader.expectEnd();
    return .{ .literal_len = literal_len, .match_len = match_len, .match_offset = match_offset };
}

inline fn readField(reader: anytype, group: *?field_group.Group, width: u8) !usize {
    if (group.*) |*fields| {
        const value = fields.read(width);
        reader.remaining_bits -= width;
        return value;
    }
    return reader.read(width);
}
