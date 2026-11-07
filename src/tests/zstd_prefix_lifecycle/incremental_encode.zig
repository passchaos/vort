const std = @import("std");
const core = @import("../../core.zig");
const h = @import("helpers.zig");
const a = h.a;

pub fn contracts(comptime Z: type) !void {
    try encoder(Z, false);
    try encoder(Z, true);
}

fn encoder(comptime Z: type, comptime parallel: bool) !void {
    const E = if (parallel) Z.NativeIncrementalParallelFrameEncoder else Z.NativeIncrementalFrameEncoder;
    const Options = if (parallel) E.Options else Z.NativeFrameOptions;
    const options: Options = if (parallel) .{
        .frame = .{ .selection = .literal_only, .block_size_max = 128, .window_log = 10 },
        .parallel = .{ .io = std.testing.io, .worker_count = 2, .job_size = 256, .max_inflight_jobs = 2, .max_inflight_bytes = 512 },
    } else .{ .selection = .literal_only, .block_size_max = 128, .window_log = 10 };
    var state = try E.initExactSizeWithPrefix(a, options, h.payload.len, h.prefix);
    defer state.deinit();
    try h.pending(state.prefixSnapshot(), 0, false);
    var output: [31]u8 = @splat(0xa5);
    const before = state.snapshot();
    try std.testing.expectError(error.InvalidStreamState, state.stepWithDirective(h.payload, &output, @enumFromInt(99)));
    try std.testing.expectEqual(before.input_read, state.snapshot().input_read);
    try std.testing.expectEqual(before.output_written, state.snapshot().output_written);
    try h.wire.untouched(&output);
    try h.pending(state.prefixSnapshot(), 0, false);
    state.resetSession();
    try h.pending(state.prefixSnapshot(), 0, false);
    _ = try state.stepWithDirective(&.{}, &.{}, .@"continue");
    try h.active(state.prefixSnapshot(), .frame);
    try std.testing.expectError(error.InvalidStreamState, state.setPrefix("replacement"));
    try std.testing.expectError(error.InvalidStreamState, state.clearDictionary());
    try std.testing.expectError(error.InvalidStreamState, state.resetParameters());
    const frame = try h.wire.encodeDrive(a, &state, h.payload);
    defer a.free(frame);
    try h.check(Z, frame, h.payload, .{ .dictionary = Z.NativeDictionary.initRawContent(h.prefix) });
    try h.cleared(state.prefixSnapshot());
    try std.testing.expect(state.prefixSnapshot().setter_eligible);
    state.resetSession();
    try state.setPrefix(h.prefix);
    _ = try state.stepWithDirective(&.{}, &.{}, .@"continue");
    state.resetSession();
    try h.cleared(state.prefixSnapshot());
    try state.setPrefix(h.prefix);
    try state.resetParameters();
    try h.cleared(state.prefixSnapshot());
    try state.setPrefix(h.prefix);
    state.resetAll();
    try h.cleared(state.prefixSnapshot());
    try state.setDictionary(Z.NativeDictionary.initRawContent(h.prefix));
    try state.setPrefix(&.{});
    try h.cleared(state.prefixSnapshot());

    // Explicit flush retains the prefix; end consumes it after all output drains.
    state.resetSession();
    try state.setPrefix(h.prefix);
    const directed = try directiveDrive(Z, &state, h.payload);
    defer a.free(directed);
    try h.check(Z, directed, h.payload, .{ .dictionary = Z.NativeDictionary.initRawContent(h.prefix) });
    try h.cleared(state.prefixSnapshot());
}

fn directiveDrive(comptime Z: type, state: anytype, input: []const u8) ![]u8 {
    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(a);
    var offset: usize = 0;
    var flushed = false;
    for (0..input.len * 32 + 16384) |_| {
        var output: [17]u8 = @splat(0xa5);
        const flush_now = !flushed and offset >= @min(input.len, 13);
        const directive: Z.FrameEncodeDirective = if (flush_now) .flush else if (offset == input.len) .end else .@"continue";
        const end = if (directive != .@"continue") offset else @min(if (flushed) input.len else @min(input.len, 13), offset + 13);
        const before = state.snapshot();
        const step = try state.stepWithDirective(input[offset..end], &output, directive);
        const after = state.snapshot();
        offset += step.progress.input_read;
        try std.testing.expectEqual(@as(core.StreamCount, step.progress.input_read), after.input_read - before.input_read);
        try std.testing.expectEqual(@as(core.StreamCount, step.progress.output_written), after.output_written - before.output_written);
        try h.wire.untouched(output[step.progress.output_written..]);
        try result.appendSlice(a, output[0..step.progress.output_written]);
        if (directive == .flush and step.status == .need_input) {
            flushed = true;
            try h.active(state.prefixSnapshot(), .frame);
        }
        if (step.status == .done) {
            try std.testing.expectEqual(input.len, offset);
            return result.toOwnedSlice(a);
        }
    }
    return error.TestUnexpectedResult;
}
