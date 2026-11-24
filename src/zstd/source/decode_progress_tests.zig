//! Public source-stream publication and frame-boundary replay contracts.
const std = @import("std");
const common = @import("stream_cursor_tests/common.zig");
const t = std.testing;

fn span(start: usize, len: usize) common.Span {
    return .{ .offset = @intCast(start), .len = @intCast(len) };
}

fn expectFailure(
    comptime Z: type,
    outcome: anytype,
    expected_error: anyerror,
    expected_progress: Z.SourceStreamProgress,
) !?Z.SourceStreamDataFrameInfo {
    try t.expect(outcome == .failed);
    try t.expectEqual(expected_error, outcome.failed.err);
    try t.expectEqualDeep(expected_progress, outcome.failed.progress);
    return outcome.failed.frame;
}

pub fn contracts(comptime Z: type) !void {
    const first = "old";
    const early = "new";
    const late = "data";
    const second = early ++ late;
    const decoded = first ++ second;
    const skippable = "skipped payload";
    const sentinel: u8 = 0xcd;

    var fixture: common.Fixture = .{};
    common.appendDataHeader(&fixture, 0x20, null, first.len);
    common.appendRawBlock(&fixture, first, true);
    _ = common.appendSkippable(&fixture, 7, skippable);
    const restart = fixture.len;
    const skipped_payload = span(restart - skippable.len, skippable.len);
    common.appendDataHeader(&fixture, 0x24, null, second.len);
    const first_block = fixture.len;
    common.appendRawBlock(&fixture, early, false);
    common.appendBlockHeader(&fixture, 0, late.len, true);
    const late_payload = span(fixture.len, late.len);
    fixture.appendSlice(late);
    const footer = span(fixture.len, 4);
    common.appendChecksum(&fixture, second);

    const saved: Z.SourceStreamCheckpoint = .{
        .compressed_offset = @intCast(restart),
        .decoded_len = first.len,
        .data_frames = 1,
        .skippable_frames = 1,
        .format = .standard,
    };
    const end: Z.SourceStreamCheckpoint = .{
        .compressed_offset = @intCast(fixture.len),
        .decoded_len = decoded.len,
        .data_frames = 2,
        .skippable_frames = 1,
        .format = .standard,
    };
    const expected_frame: Z.SourceStreamDataFrameInfo = .{
        .offset = saved.compressed_offset,
        .dictionary_id = 0,
        .window_size = second.len,
        .content_size = second.len,
        .has_checksum = true,
        .single_segment = true,
        .block_size_max = second.len,
    };

    var history: [second.len]u8 = undefined;
    var staging: [second.len]u8 = undefined;
    var literal: [17]u8 = undefined;
    var sequence: [17]u8 = undefined;
    const workspace: Z.SourceFrameWorkspace = .{
        .history = &history,
        .staging = &staging,
        .literal_page = &literal,
        .sequence_page = &sequence,
    };
    const options: Z.SourceStreamDecodeOptions = .{ .max_frames = 3, .total_decoded_max = decoded.len };
    const completed_elements = [_]common.Span{span(0, restart)};
    const cap_guard = [_]common.Span{ completed_elements[0], span(first_block, fixture.len - first_block) };

    // Failing the second block's payload leaves just the first block of that
    // frame published; failing the checksum read leaves both blocks published.
    for ([_]common.Span{ late_payload, footer }, [_]usize{ first.len + early.len, decoded.len }) |fault, published| {
        const forbidden = [_]common.Span{ skipped_payload, fault };
        var source: common.TrackingSource = .{ .bytes = fixture.bytes(), .forbidden = &forbidden };
        var output: [decoded.len + 3]u8 = @splat(sentinel);
        const outcome = Z.decodeSourceStreamIntoWithProgress(source.source(), &output, workspace, options, null);
        const frame = try expectFailure(Z, outcome, error.SourceReadFailed, .{
            .checkpoint = saved,
            .output_written = published,
            .complete_output_written = first.len,
        });
        try t.expect(source.forbidden_read);
        try t.expectEqualDeep(expected_frame, frame orelse return error.TestUnexpectedResult);
        try t.expectEqualSlices(u8, decoded[0..published], output[0..published]);
        try t.expect(std.mem.allEqual(u8, output[published..], sentinel));

        const progress = outcome.failed.progress;
        const retry = output[progress.complete_output_written..];
        const before_caps = output;
        // Both caps still count completed elements on replay. The frame cap
        // includes the preceding skippable element. Neither needs block I/O.
        source.forbidden = &cap_guard;
        source.forbidden_read = false;
        for ([_]Z.SourceStreamDecodeOptions{
            .{ .max_frames = 2, .total_decoded_max = decoded.len },
            .{ .max_frames = 3, .total_decoded_max = decoded.len - 1 },
        }) |limited| {
            const limited_outcome = Z.decodeSourceStreamIntoWithProgress(source.source(), retry, workspace, limited, progress.checkpoint);
            _ = try expectFailure(Z, limited_outcome, error.OutputLimitExceeded, .{ .checkpoint = saved });
            try t.expect(!source.forbidden_read);
            try t.expectEqualSlices(u8, &before_caps, &output);
        }

        // Keep the same full source but forbid all reads of completed elements.
        // Poison just the failed frame's bytes so successful replay must replace them.
        source.forbidden = &completed_elements;
        @memset(output[progress.complete_output_written..progress.output_written], sentinel);
        const resumed = Z.decodeSourceStreamIntoWithProgress(source.source(), retry, workspace, options, progress.checkpoint);
        try t.expect(resumed == .complete);
        try t.expect(!source.forbidden_read);
        try t.expectEqualDeep(Z.SourceStreamProgress{
            .checkpoint = end,
            .output_written = second.len,
            .complete_output_written = second.len,
        }, resumed.complete);
        try t.expectEqualSlices(u8, decoded, output[0..decoded.len]);
        try t.expect(std.mem.allEqual(u8, output[decoded.len..], sentinel));

        const calls = source.calls;
        const eof = Z.decodeSourceStreamIntoWithProgress(source.source(), output[decoded.len..], workspace, options, resumed.complete.checkpoint);
        try t.expect(eof == .complete);
        try t.expectEqualDeep(Z.SourceStreamProgress{ .checkpoint = end }, eof.complete);
        try t.expectEqual(calls, source.calls);
        try t.expect(std.mem.allEqual(u8, output[decoded.len..], sentinel));
    }

    var source: common.TrackingSource = .{ .bytes = fixture.bytes(), .forbidden = &.{skipped_payload} };
    var small: [first.len + 1]u8 = undefined;
    _ = try expectFailure(Z, Z.decodeSourceStreamIntoWithProgress(source.source(), &small, workspace, options, null), error.OutputTooSmall, .{
        .checkpoint = saved,
        .output_written = small.len,
        .complete_output_written = first.len,
    });
    try t.expectEqualSlices(u8, decoded[0..small.len], &small);

    {
        const checksum_byte: usize = @intCast(footer.offset);
        fixture.storage[checksum_byte] ^= 1;
        defer fixture.storage[checksum_byte] ^= 1;
        var output: [decoded.len]u8 = undefined;
        _ = try expectFailure(Z, Z.decodeSourceStreamIntoWithProgress(source.source(), &output, workspace, options, null), error.ChecksumMismatch, .{
            .checkpoint = saved,
            .output_written = decoded.len,
            .complete_output_written = first.len,
        });
        try t.expectEqualSlices(u8, decoded, &output);
    }

    try wideCheckpoint(Z, fixture.bytes()[restart..], second, workspace);
}

const WideSource = struct {
    const base: u64 = (1 << 32) + 16;
    bytes: []const u8,

    fn readAt(raw: *anyopaque, offset: u64, output: []u8) error{SourceReadFailed}!usize {
        const self: *WideSource = @ptrCast(@alignCast(raw));
        if (offset < base or offset - base > self.bytes.len) return error.SourceReadFailed;
        const start: usize = @intCast(offset - base);
        if (output.len > self.bytes.len - start) return error.SourceReadFailed;
        @memcpy(output, self.bytes[start..][0..output.len]);
        return output.len;
    }
};

fn wideCheckpoint(comptime Z: type, tail: []const u8, expected: []const u8, workspace: Z.SourceFrameWorkspace) !void {
    // Only the tail is backed by memory. Model earlier completed elements at
    // wide offsets to keep this an actual decode test on 32-bit targets.
    var sparse: WideSource = .{ .bytes = tail };
    const source: Z.ByteSource = .{ .context = &sparse, .len = WideSource.base + tail.len, .read_at = WideSource.readAt };
    const start: Z.SourceStreamCheckpoint = .{
        .compressed_offset = WideSource.base,
        .decoded_len = WideSource.base + 5,
        .data_frames = WideSource.base - 1,
        .skippable_frames = 1,
    };
    var storage: [32]u8 = undefined;
    const output = storage[0..expected.len];
    const outcome = Z.decodeSourceStreamIntoWithProgress(source, output, workspace, .{
        .total_decoded_max = start.decoded_len + expected.len,
        .max_frames = WideSource.base + 1,
    }, start);
    try t.expect(outcome == .complete);
    try t.expectEqualDeep(Z.SourceStreamProgress{
        .checkpoint = .{
            .compressed_offset = source.len,
            .decoded_len = start.decoded_len + expected.len,
            .data_frames = WideSource.base,
            .skippable_frames = 1,
        },
        .output_written = expected.len,
        .complete_output_written = expected.len,
    }, outcome.complete);
    try t.expectEqualSlices(u8, expected, output);
}
