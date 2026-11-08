//! Callback-free validation of compressed-block caller workspaces.
const std = @import("std");
const core = @import("../../../core.zig");
const history_workspace = @import("../../decode/history_workspace.zig");
const stable_output = @import("../../decode/stable_output.zig");
const source_input = @import("../input.zig");

const Count = core.StreamCount;
const count = core.stream_count;

pub const Error = core.Error || source_input.Error;

pub fn validatePrepared(prepared: anytype, block_decoded_max: usize) Error!void {
    if (prepared.literals.regenerated_size > block_decoded_max)
        return error.CorruptFrame;
    if ((prepared.literals.sequence_count == 0) !=
        (prepared.pending_sequences == null))
        return error.CorruptFrame;
    if (prepared.pending_sequences) |pending|
        if (pending.sequence_count != prepared.literals.sequence_count)
            return error.CorruptFrame;
}

pub fn validateInitialFrameLimits(
    frame_decoded: Count,
    frame_decoded_max: Count,
    expected_frame_size: ?Count,
) Error!void {
    if (frame_decoded > frame_decoded_max)
        return error.OutputLimitExceeded;
    if (expected_frame_size) |expected|
        if (frame_decoded > expected) return error.SizeMismatch;
}

pub fn validateHistory(
    history: history_workspace.Binding,
    frame_decoded: Count,
    dictionary_len: usize,
    block_decoded_max: usize,
) Error!void {
    if (!history.active()) return error.InvalidStreamState;
    const expected_limit = try history_workspace.requiredLen(
        count.fromLocal(history.window),
        dictionary_len,
    );
    if (history.limit != expected_limit or
        history.limit > history.storage.len or
        history.len > history.limit or
        block_decoded_max > history.window or
        (history.limit == 0 and history.head != 0) or
        (history.limit != 0 and history.head >= history.limit))
        return error.InvalidStreamState;
    if (history.len != count.bounded(frame_decoded, history.limit))
        return error.InvalidStreamState;

    // history_workspace.append uses ordinary additions after its branch. A
    // conservative one-block proof keeps final publication infallible.
    _ = std.math.add(usize, history.head, block_decoded_max) catch
        return error.IntegerOverflow;
    _ = std.math.add(usize, history.len, block_decoded_max) catch
        return error.IntegerOverflow;
    _ = std.math.add(usize, history.limit, history.limit) catch
        return error.IntegerOverflow;
}

pub fn validateAliases(
    prepared: anytype,
    committed: anytype,
    history: *history_workspace.Binding,
    dictionary_history: []const u8,
    staging: []const u8,
    literal_page: []const u8,
    sequence_page: []const u8,
) Error!void {
    const regions = [_][]const u8{
        history.storage,
        dictionary_history,
        staging,
        literal_page,
        sequence_page,
        std.mem.asBytes(prepared),
        std.mem.asBytes(committed),
        std.mem.asBytes(history),
    };
    for (regions, 0..) |first, first_index|
        for (regions[first_index + 1 ..]) |second|
            if (stable_output.overlaps(first, second))
                return error.InvalidBlockPlan;
}
