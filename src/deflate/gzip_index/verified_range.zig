//! Verify each selected gzip member before publishing its plaintext intersection.
const count = @import("../../core.zig").stream_count;
const model = @import("types.zig");
const Cursor = @import("page.zig").Cursor;

pub fn scratchLen(index: anytype, offset: model.Count, length: usize) model.Error!usize {
    return scratchLenChecked(index, offset, try model.rangeEnd(index.decoded_size, offset, length));
}

fn scratchLenChecked(index: anytype, offset: model.Count, end: model.Count) model.Error!usize {
    var next = offset;
    var required: usize = 0;
    while (next < end) {
        const member = try memberForOffset(index, next);
        const stop = @min(member.decoded_end, end);
        required = @max(required, try count.toLocal(stop - next));
        next = stop;
    }
    return required;
}

pub fn decode(
    comptime Codec: type,
    index: anytype,
    offset: model.Count,
    output: []u8,
    workspace: model.Workspace,
    range_scratch: []u8,
) model.Outcome {
    var progress: model.Progress = .{ .next_decoded_offset = offset };
    decodeChecked(Codec, index, output, workspace, range_scratch, &progress) catch |err|
        return .{ .failed = .{ .err = err, .progress = progress } };
    return .{ .complete = progress };
}

fn decodeChecked(
    comptime Codec: type,
    index: anytype,
    output: []u8,
    workspace: model.Workspace,
    range_scratch: []u8,
    progress: *model.Progress,
) model.Error!void {
    const start = progress.next_decoded_offset;
    const end = try model.rangeEnd(index.decoded_size, start, output.len);
    if (output.len == 0) return;
    const needed = try scratchLenChecked(index, start, end);
    if (range_scratch.len < needed) return error.OutputTooSmall;
    const scratch = range_scratch[0..needed];
    try workspace.validate(Codec.RawDecoder.required_history_len);
    try model.validateDisjoint(&.{ output, scratch, workspace.history, workspace.input_page, workspace.discard, try model.entryBytes(index.entries), index.checkpoint_history });

    while (progress.next_decoded_offset < end) {
        const next = progress.next_decoded_offset;
        const member = try memberForOffset(index, next);
        const stop = @min(member.decoded_end, end);
        const stage = scratch[0..try count.toLocal(stop - next)];
        try verifyMember(Codec, index, member, next, stop, stage, workspace);
        @memcpy(output[progress.output_written..][0..stage.len], stage);
        progress.output_written += stage.len;
        progress.next_decoded_offset = stop;
    }
}

fn memberForOffset(index: anytype, offset: model.Count) model.Error!model.Entry {
    const nearest = try index.entryForOffset(offset);
    const member = if (nearest.boundary == .member) nearest else anchor: {
        // Every entry from a member has the same compressed_end; the first
        // one in that group is its header, regardless of checkpoint density.
        var lo: usize = 0;
        var hi = index.entries.len;
        while (lo < hi) {
            const mid = lo + (hi - lo) / 2;
            if (index.entries[mid].compressed_end < nearest.compressed_end) lo = mid + 1 else hi = mid;
        }
        if (lo == index.entries.len) return error.InvalidBlockPlan;
        const entry = index.entries[lo];
        if (entry.boundary != .member or entry.compressed_end != nearest.compressed_end or
            entry.decoded_end != nearest.decoded_end or entry.decodedOffset() > offset)
            return error.InvalidBlockPlan;
        break :anchor entry;
    };
    if (member.compressedOffset() >= member.compressed_end or member.compressed_end > index.source.len)
        return error.InvalidBlockPlan;
    return member;
}

fn verifyMember(
    comptime Codec: type,
    index: anytype,
    member: model.Entry,
    selected_start: model.Count,
    selected_end: model.Count,
    stage: []u8,
    workspace: model.Workspace,
) model.Error!void {
    const start = member.decodedOffset();
    const member_len = member.decoded_end - start;
    var reader = try Cursor.init(index.source, workspace.input_page, member.compressedOffset(), member.compressed_end);
    var decoder = try Codec.GzipDecoder.init(.{
        .max_output_len = member_len,
        .expected_output_len = member_len,
        .max_header_metadata_len = index.max_header_metadata_len,
    }, workspace.history);
    var decoded = start;
    while (true) {
        const input = try reader.current();
        const grant = if (decoded < selected_start)
            workspace.discard[0..count.bounded(selected_start - decoded, workspace.discard.len)]
        else if (decoded < selected_end)
            stage[try count.toLocal(decoded - selected_start)..]
        else
            workspace.discard;
        const step = try decoder.step(input, grant);
        try reader.advance(step.progress.input_read);
        decoded = try count.addLocal(decoded, step.progress.output_written);
        if (step.status == .done) {
            try decoder.finish();
            if (decoded != member.decoded_end or reader.offset != member.compressed_end)
                return error.SizeMismatch;
            return;
        }
        if (step.progress.input_read == 0 and step.progress.output_written == 0) {
            if (input.len == 0) return error.TruncatedFrame;
            return error.InvalidStreamState;
        }
    }
}
