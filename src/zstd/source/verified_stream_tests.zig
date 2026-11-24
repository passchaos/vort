//! Frame-atomic publication and retry contracts for verified source streams.
const std = @import("std");
const common = @import("stream_cursor_tests/common.zig");
const t = std.testing;
const sentinel: u8 = 0xcd;

fn span(offset: usize, len: usize) common.Span {
    return .{ .offset = @intCast(offset), .len = @intCast(len) };
}

fn expectFailure(
    comptime Z: type,
    outcome: Z.SourceStreamOutcome,
    err: anyerror,
    checkpoint: Z.SourceStreamCheckpoint,
    published: usize,
) !void {
    try t.expect(outcome == .failed);
    try t.expectEqual(err, outcome.failed.err);
    try t.expectEqualDeep(Z.SourceStreamProgress{
        .checkpoint = checkpoint,
        .output_written = published,
        .complete_output_written = published,
    }, outcome.failed.progress);
}

pub fn contracts(comptime Z: type) !void {
    var history: [1024]u8 = @splat(sentinel);
    var staging: [1024]u8 = @splat(sentinel);
    var literal: [17]u8 = @splat(sentinel);
    var sequence: [17]u8 = @splat(sentinel);
    const workspace: Z.SourceFrameWorkspace = .{
        .history = &history,
        .staging = &staging,
        .literal_page = &literal,
        .sequence_page = &sequence,
    };
    try preflight(Z, workspace);
    try emptyFrame(Z, workspace);
    for ([_]bool{ true, false }) |declared| try replay(Z, workspace, declared);
}

fn emptyFrame(comptime Z: type, workspace: Z.SourceFrameWorkspace) !void {
    var fixture: common.Fixture = .{};
    common.appendDataHeader(&fixture, 0x24, null, 0);
    common.appendRawBlock(&fixture, "", true);
    common.appendChecksum(&fixture, "");
    var source: common.TrackingSource = .{ .bytes = fixture.bytes() };
    const outcome = Z.decodeVerifiedSourceStreamIntoWithProgress(source.source(), &.{}, workspace, &.{}, .{
        .frame_decoded_max = 0,
        .total_decoded_max = 0,
    }, null);
    try t.expect(outcome == .complete);
    try t.expectEqualDeep(Z.SourceStreamProgress{
        .checkpoint = .{ .compressed_offset = @intCast(fixture.len), .data_frames = 1 },
    }, outcome.complete);
}

fn replay(comptime Z: type, workspace: Z.SourceFrameWorkspace, declared: bool) !void {
    const first = "old";
    const second = "newdata";
    const decoded = first ++ second;
    var fixture: common.Fixture = .{};
    common.appendDataHeader(&fixture, 0x20, null, first.len);
    common.appendRawBlock(&fixture, first, true);
    const skipped = "unread skippable payload";
    _ = common.appendSkippable(&fixture, 7, skipped);
    const restart = fixture.len;
    const skipped_payload = span(restart - skipped.len, skipped.len);
    common.appendDataHeader(&fixture, if (declared) 0x24 else 0x04, if (declared) null else 0, if (declared) second.len else null);
    const payload = fixture.len + 3;
    common.appendRawBlock(&fixture, second[0..3], false);
    common.appendRawBlock(&fixture, second[3..], true);
    const footer = fixture.len;
    common.appendChecksum(&fixture, second);

    const saved: Z.SourceStreamCheckpoint = .{
        .compressed_offset = @intCast(restart),
        .decoded_len = first.len,
        .data_frames = 1,
        .skippable_frames = 1,
    };
    const options: Z.SourceStreamDecodeOptions = .{ .max_frames = 3, .total_decoded_max = decoded.len };
    var source: common.TrackingSource = .{ .bytes = fixture.bytes() };
    var scratch: [second.len]u8 = undefined;
    var output: [decoded.len + 3]u8 = undefined;

    // Declared sizes need no payload reads to establish that either buffer is
    // short. The unknown-size frame is too large only after its first block.
    const short_guard = [_]common.Span{ skipped_payload, span(payload, fixture.len - payload) };
    source.forbidden = short_guard[0..if (declared) 2 else 1];
    const short = second.len - 1;
    for ([_]usize{ output.len, first.len + short }, [_]usize{ short, scratch.len }) |out_len, scratch_len| {
        @memset(&output, sentinel);
        const outcome = Z.decodeVerifiedSourceStreamIntoWithProgress(source.source(), output[0..out_len], workspace, scratch[0..scratch_len], options, null);
        try expectFailure(Z, outcome, error.OutputTooSmall, saved, first.len);
        try t.expect(!source.forbidden_read);
        try t.expectEqualSlices(u8, first, output[0..first.len]);
        try t.expect(std.mem.allEqual(u8, output[first.len..], sentinel));
    }

    {
        fixture.storage[footer] ^= 1;
        defer fixture.storage[footer] ^= 1;
        source.forbidden = &.{skipped_payload};
        @memset(&output, sentinel);
        const outcome = Z.decodeVerifiedSourceStreamIntoWithProgress(source.source(), &output, workspace, &scratch, options, null);
        try expectFailure(Z, outcome, error.ChecksumMismatch, saved, first.len);
        const frame = outcome.failed.frame orelse return error.TestUnexpectedResult;
        try t.expectEqual(saved.compressed_offset, frame.offset);
        try t.expectEqual(@as(?u64, if (declared) second.len else null), frame.content_size);
        try t.expectEqualSlices(u8, first, output[0..first.len]);
        try t.expect(std.mem.allEqual(u8, output[first.len..], sentinel));
    }

    // Exercise replay without changing source bytes between the two calls.
    const late_fault = [_]common.Span{ skipped_payload, span(footer, 4) };
    source.forbidden = &late_fault;
    @memset(&output, sentinel);
    const failed = Z.decodeVerifiedSourceStreamIntoWithProgress(source.source(), &output, workspace, &scratch, options, null);
    try expectFailure(Z, failed, error.SourceReadFailed, saved, first.len);
    try t.expect(source.forbidden_read);
    try t.expectEqualSlices(u8, first, output[0..first.len]);
    try t.expect(std.mem.allEqual(u8, output[first.len..], sentinel));

    const completed = [_]common.Span{span(0, restart)};
    source.forbidden = &completed;
    source.forbidden_read = false;
    const progress = failed.failed.progress;
    const resumed = Z.decodeVerifiedSourceStreamIntoWithProgress(source.source(), output[progress.complete_output_written..], workspace, &scratch, options, progress.checkpoint);
    try t.expect(resumed == .complete);
    try t.expect(!source.forbidden_read);
    try t.expectEqualDeep(Z.SourceStreamProgress{
        .checkpoint = .{ .compressed_offset = @intCast(fixture.len), .decoded_len = decoded.len, .data_frames = 2, .skippable_frames = 1 },
        .output_written = second.len,
        .complete_output_written = second.len,
    }, resumed.complete);
    try t.expectEqualSlices(u8, decoded, output[0..decoded.len]);
    try t.expect(std.mem.allEqual(u8, output[decoded.len..], sentinel));
}

fn preflight(comptime Z: type, workspace: Z.SourceFrameWorkspace) !void {
    var fixture: common.Fixture = .{};
    common.appendDataHeader(&fixture, 0x20, null, 3);
    common.appendRawBlock(&fixture, "abc", true);
    var source: common.TrackingSource = .{ .bytes = fixture.bytes(), .mode = .fail };
    var output: [8]u8 = @splat(sentinel);
    var scratch: [8]u8 = @splat(sentinel);
    const dictionary = Z.NativeDictionary.init(77, &scratch);
    var entries = [_]Z.NativeDictionary{dictionary};
    const set = Z.NativeDictionarySet.init(&entries);
    const Case = struct {
        scratch: []u8,
        options: Z.SourceStreamDecodeOptions = .{},
    };
    for ([_]Case{
        .{ .scratch = &scratch, .options = .{ .ignore_checksum = true } },
        .{ .scratch = output[7..] }, // Only the unused destination tail overlaps.
        .{ .scratch = workspace.history[1..] },
        .{ .scratch = workspace.staging[1..] },
        .{ .scratch = workspace.literal_page[1..] },
        .{ .scratch = workspace.sequence_page[1..] },
        .{ .scratch = scratch[1..], .options = .{ .dictionary = dictionary } },
        .{ .scratch = scratch[1..], .options = .{ .dictionary_set = set } },
        .{ .scratch = std.mem.asBytes(&entries), .options = .{ .dictionary_set = set } },
    }) |case| {
        const outcome = Z.decodeVerifiedSourceStreamIntoWithProgress(source.source(), &output, workspace, case.scratch, case.options, null);
        try expectFailure(Z, outcome, error.InvalidBlockPlan, .{}, 0);
        try t.expect(outcome.failed.frame == null);
    }
    try t.expectEqual(@as(usize, 0), source.calls);
    try t.expectEqualDeep([_]Z.NativeDictionary{dictionary}, entries);
    for ([_][]const u8{ &output, &scratch, workspace.history, workspace.staging, workspace.literal_page, workspace.sequence_page }) |region| {
        try t.expect(std.mem.allEqual(u8, region, sentinel));
    }
}
