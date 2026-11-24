//! Build an index only after validating every member with the gzip decoder.
const count = @import("../../core.zig").stream_count;
const model = @import("types.zig");
const Cursor = @import("page.zig").Cursor;

pub fn build(
    comptime Codec: type,
    comptime Index: type,
    source: model.Source,
    entries: []model.Entry,
    checkpoint_history: []u8,
    workspace: model.Workspace,
    options: model.Options,
) model.Error!Index {
    if (source.len == 0) return error.TruncatedFrame;
    try workspace.validate(Codec.RawDecoder.required_history_len);
    try model.validateDisjoint(&.{ try model.entryBytes(entries), checkpoint_history, workspace.history, workspace.input_page, workspace.discard });
    var cursor = try Cursor.init(source, workspace.input_page, 0, source.len);
    var decoder = try Codec.GzipDecoder.init(.{
        .allow_trailing_data = true,
        .max_output_len = options.max_output_len,
        .max_header_metadata_len = options.max_header_metadata_len,
    }, workspace.history);
    var entries_used: usize = 0;
    var history_used: usize = 0;
    var decoded: model.Count = 0;
    var members: model.Count = 0;
    while (cursor.offset < source.len) {
        if (members == options.max_members) return error.OutputLimitExceeded;
        if (members != 0) {
            decoder.options.max_output_len = options.max_output_len - decoded;
            decoder.reset();
        }
        const member_start: model.Count = cursor.offset;
        const first_entry = entries_used;
        var last_checkpoint = decoded;
        while (true) {
            const input = try cursor.current();
            const step = try decoder.stepToBlockBoundary(input, workspace.discard);
            try cursor.advance(step.progress.input_read);
            const absolute = try count.add(decoded, decoder.total_output);

            // An empty member is verified and counted but needs no range anchor.
            if (absolute != decoded and first_entry == entries_used) {
                if (entries_used == entries.len) return error.OutputTooSmall;
                entries[entries_used] = .{
                    .boundary = .{ .member = .{ .compressed_offset = member_start, .decoded_offset = decoded } },
                    .compressed_end = 0,
                    .decoded_end = 0,
                };
                entries_used += 1;
            }
            if (step.block_boundary and absolute > last_checkpoint and absolute - last_checkpoint >= options.checkpoint_spacing) {
                if (entries_used == entries.len) return error.OutputTooSmall;
                var saved = try decoder.captureBlockRestart(checkpoint_history[history_used..]);
                history_used += saved.history.len;
                saved.position.compressed_byte_offset = try count.add(member_start, saved.position.compressed_byte_offset);
                saved.position.decoded_offset = absolute;
                entries[entries_used] = .{ .boundary = .{ .block = saved }, .compressed_end = 0, .decoded_end = 0 };
                entries_used += 1;
                last_checkpoint = absolute;
            }
            if (step.status == .done) {
                try decoder.finish();
                const relative_end = decoder.memberEndOffset() orelse return error.InvalidStreamState;
                if (cursor.offset <= member_start or relative_end != cursor.offset - member_start)
                    return error.InvalidStreamState;
                for (entries[first_entry..entries_used]) |*entry| {
                    entry.compressed_end = cursor.offset;
                    entry.decoded_end = absolute;
                }
                decoded = absolute;
                members += 1;
                break;
            }
            if (!step.block_boundary and step.progress.input_read == 0 and step.progress.output_written == 0) {
                if (input.len == 0) return error.TruncatedFrame;
                return error.InvalidStreamState;
            }
        }
    }
    return .{
        .source = source,
        .entries = entries[0..entries_used],
        .checkpoint_history = checkpoint_history[0..history_used],
        .decoded_size = decoded,
        .members_verified = members,
        .max_header_metadata_len = options.max_header_metadata_len,
    };
}
