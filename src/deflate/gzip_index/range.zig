//! Decode a requested plaintext interval from the nearest indexed boundary.
const count = @import("../../core.zig").stream_count;
const model = @import("types.zig");
const Cursor = @import("../../io/source_page.zig").Cursor;

pub fn decode(
    comptime Codec: type,
    index: anytype,
    offset: model.Count,
    output: []u8,
    workspace: model.Workspace,
) model.Outcome {
    var progress: model.Progress = .{ .next_decoded_offset = offset };
    decodeChecked(Codec, index, output, workspace, &progress) catch |err|
        return .{ .failed = .{ .err = err, .progress = progress } };
    return .{ .complete = progress };
}

fn decodeChecked(
    comptime Codec: type,
    index: anytype,
    output: []u8,
    workspace: model.Workspace,
    progress: *model.Progress,
) model.Error!void {
    const end = try model.rangeEnd(index.decoded_size, progress.next_decoded_offset, output.len);
    if (output.len == 0) return;
    try workspace.validate(Codec.RawDecoder.required_history_len);
    try model.validateDisjoint(&.{ output, workspace.history, workspace.input_page, workspace.discard, try model.entryBytes(index.entries), index.checkpoint_history });

    while (progress.next_decoded_offset < end) {
        const entry = try index.entryForOffset(progress.next_decoded_offset);
        const segment_end = @min(end, entry.decoded_end);
        const initial_decoded = entry.decodedOffset();
        switch (entry.boundary) {
            .member => |start| {
                var reader = try Cursor.init(index.source, workspace.input_page, start.compressed_offset, entry.compressed_end);
                var decoder = try Codec.GzipDecoder.init(.{
                    .max_output_len = entry.decoded_end - initial_decoded,
                    .max_header_metadata_len = index.max_header_metadata_len,
                }, workspace.history);
                try drive(&reader, &decoder, initial_decoded, segment_end, output, workspace.discard, progress);
            },
            .block => |saved| {
                if (entry.compressed_end < 8 or entry.compressed_end > index.source.len)
                    return error.InvalidBlockPlan;
                const payload_end = entry.compressed_end - 8;
                const at = saved.position.compressed_byte_offset;
                if (at >= payload_end) return error.InvalidBlockPlan;
                var byte: [1]u8 = undefined;
                const initial_byte = if (saved.position.compressed_bit_offset == 0) null else fragmented: {
                    try index.source.readExact(at, &byte);
                    break :fragmented byte[0];
                };
                var decoder = try Codec.RawDecoder.initWithHistory(.{}, workspace.history);
                const next = try decoder.restartAtBlockBoundary(saved, initial_byte, .{
                    .max_output_len = segment_end,
                    .stop_at_output_limit = true,
                });
                var reader = try Cursor.init(index.source, workspace.input_page, next, payload_end);
                try drive(&reader, &decoder, initial_decoded, segment_end, output, workspace.discard, progress);
            },
        }
    }
}

fn drive(
    reader: *Cursor,
    decoder: anytype,
    start: model.Count,
    end: model.Count,
    output: []u8,
    discard: []u8,
    progress: *model.Progress,
) model.Error!void {
    var decoded = start;
    const wanted = progress.next_decoded_offset;
    while (decoded < end) {
        const pending = try reader.current();
        const publish = decoded >= wanted;
        const grant = if (publish)
            output[progress.output_written..][0..count.bounded(end - decoded, output.len - progress.output_written)]
        else
            discard[0..count.bounded(wanted - decoded, discard.len)];
        const before = decoder.total_output;
        const step = decoder.step(pending, grant) catch |err| {
            if (publish) advance(progress, try count.toLocal(decoder.total_output - before));
            return err;
        };
        if (publish) advance(progress, step.progress.output_written);
        decoded += step.progress.output_written;
        try reader.advance(step.progress.input_read);
        if (decoded == end) return;
        if (step.status == .done) return error.SizeMismatch;
        if (step.progress.input_read == 0 and step.progress.output_written == 0) {
            if (pending.len == 0) return error.TruncatedFrame;
            return error.InvalidStreamState;
        }
    }
}

fn advance(progress: *model.Progress, amount: usize) void {
    progress.output_written += amount;
    progress.next_decoded_offset += amount;
}
