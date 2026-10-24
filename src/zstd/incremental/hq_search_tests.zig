//! Public incremental HQ search refusal, retry and frame-transition contracts.
const std = @import("std");
const zstd = @import("../../zstd.zig");
const core = @import("../../core.zig");
const allocator = std.testing.allocator;
const Encoder = zstd.NativeIncrementalFrameEncoder;
const Count = core.StreamCount;
const first = "abcdefgh-abcdefgh-abcdefgh";
const second = "abcdefghXabcdefghYabcdefgh";
const limit = std.math.maxInt(u64);

const requests = [_]zstd.HqOptions{
    .{ .search_depth = 8, .nice_len = 32, .parse_mode = .whole_block, .max_price_evaluations = 0 },
    .{ .search_depth = 8, .nice_len = 32, .match_lengths = .complete, .max_price_evaluations = 0 },
    .{ .search_depth = 8, .nice_len = 32, .parse_mode = .whole_block, .match_lengths = .complete, .max_price_evaluations = 0 },
};

fn options(hq: zstd.HqOptions, profile: ?*zstd.EncoderControlProfile) zstd.NativeFrameOptions {
    return .{ .strategy = .btopt, .block_size_max = 64, .content_checksum = true, .hq = hq, .control_profile = profile };
}

fn drain(encoder: *Encoder, wire: *std.ArrayList(u8), done: bool) !void {
    var output: [3]u8 = undefined;
    var calls: usize = 0;
    while (true) : (calls += 1) {
        try std.testing.expect(calls < 1024);
        const before = encoder.snapshot();
        const result = try encoder.step("", &output);
        const after = encoder.snapshot();
        try std.testing.expectEqual(@as(usize, 0), result.progress.input_read);
        try std.testing.expect(result.progress.output_written <= output.len);
        try std.testing.expectEqual(before.input_read, after.input_read);
        try std.testing.expectEqual(try core.stream_count.addLocal(before.output_written, result.progress.output_written), after.output_written);
        try wire.appendSlice(allocator, output[0..result.progress.output_written]);
        if (result.status == (if (done) core.StepResult.Status.done else .need_input)) return;
        try std.testing.expectEqual(core.StepResult.Status.need_output, result.status);
    }
}

fn accept(encoder: *Encoder, input: []const u8) !void {
    const step = try encoder.step(input, &.{});
    try std.testing.expectEqual(input.len, step.progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), step.progress.output_written);
    try std.testing.expectEqual(core.StepResult.Status.need_input, step.status);
}

fn completedWire(config: zstd.NativeFrameOptions, flush_second: bool) ![]u8 {
    var encoder = try Encoder.initExactSize(allocator, config, first.len + second.len);
    defer encoder.deinit();
    var wire: std.ArrayList(u8) = .empty;
    errdefer wire.deinit(allocator);
    try drain(&encoder, &wire, false);
    try accept(&encoder, first);
    encoder.flush();
    try drain(&encoder, &wire, false);
    try accept(&encoder, second);
    if (flush_second) {
        encoder.flush();
        try drain(&encoder, &wire, false);
    }
    encoder.finish();
    try drain(&encoder, &wire, true);
    return wire.toOwnedSlice(allocator);
}

fn expectPlain(wire: []const u8, input: []const u8) !void {
    const decoded = try zstd.decodeNativeFrameAlloc(allocator, wire);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}

test "Zstd incremental HQ search zero cap preserves warm block transaction and empty-input retry" {
    for (requests) |request| {
        for ([_]bool{ false, true }) |flush_second| {
            var profile: zstd.EncoderControlProfile = .{};
            var successful = request;
            successful.max_price_evaluations = limit;
            var encoder = try Encoder.initExactSize(allocator, options(successful, &profile), first.len + second.len);
            defer encoder.deinit();
            var wire: std.ArrayList(u8) = .empty;
            defer wire.deinit(allocator);
            try drain(&encoder, &wire, false);
            try std.testing.expect(encoder.header_written);
            try accept(&encoder, first);
            encoder.flush();
            try drain(&encoder, &wire, false);
            try std.testing.expectEqualSlices(u8, first, encoder.history.view().bytes);
            try std.testing.expect(encoder.codec_state.sequence_state_initialized);
            // Only the price cap changes between accepted blocks.
            encoder.options.hq.?.max_price_evaluations = 0;
            try accept(&encoder, second);
            if (flush_second) encoder.flush() else encoder.finish();
            const before = encoder.snapshot();
            const state = encoder.codec_state;
            const hash = encoder.hasher;
            const history_start = encoder.history.absolute_start;
            const history_end = encoder.history.absolute_end;
            const emitted = profile.emitted();
            const refusals = profile.price_limit_refusals;
            const work = profile.tree_nodes;
            var output: [3]u8 = @splat(0xa5);
            try std.testing.expectError(error.SearchLimitExceeded, encoder.step("", &output));
            try std.testing.expectEqualDeep(before, encoder.snapshot());
            try std.testing.expectEqualDeep(state, encoder.codec_state);
            try std.testing.expectEqualDeep(hash, encoder.hasher);
            try std.testing.expectEqual(history_start, encoder.history.absolute_start);
            try std.testing.expectEqual(history_end, encoder.history.absolute_end);
            try std.testing.expectEqualSlices(u8, first, encoder.history.view().bytes);
            try std.testing.expectEqualSlices(u8, second, encoder.block.items);
            try std.testing.expectEqual(@as(usize, 0), encoder.pending.items.len);
            try std.testing.expect(!encoder.final_written);
            try std.testing.expectEqual(flush_second, encoder.flush_requested);
            try std.testing.expectEqual(!flush_second, encoder.finishing);
            try std.testing.expectEqualDeep(emitted, profile.emitted());
            try std.testing.expect(profile.price_limit_refusals > refusals);
            try std.testing.expect(profile.tree_nodes > work);
            try std.testing.expectEqualSlices(u8, &([_]u8{0xa5} ** 3), &output);
            var raised = encoder.options;
            raised.hq.?.max_price_evaluations = limit;
            encoder.options.hq.?.max_price_evaluations = limit;
            try std.testing.expectEqualDeep(raised, encoder.options);
            if (flush_second) {
                try drain(&encoder, &wire, false);
                encoder.finish();
            }
            try drain(&encoder, &wire, true);
            var reference = raised;
            reference.control_profile = null;
            const expected = try completedWire(reference, flush_second);
            defer allocator.free(expected);
            try std.testing.expectEqualSlices(u8, expected, wire.items);
            try expectPlain(wire.items, first ++ second);
            try std.testing.expectEqual(@as(Count, first.len + second.len), encoder.snapshot().input_read);
            try std.testing.expectEqual(@as(Count, 1), encoder.snapshot().frame_count);
            try std.testing.expectEqual(@as(u64, if (flush_second) 3 else 2), profile.raw_blocks + profile.rle_blocks + profile.compressed_blocks);
            try std.testing.expect(profile.price_limit_refusals > refusals);
        }
    }
}

fn freshWire(config: zstd.NativeFrameOptions) ![]u8 {
    var encoder = try Encoder.initExactSize(allocator, config, second.len);
    defer encoder.deinit();
    var wire: std.ArrayList(u8) = .empty;
    errdefer wire.deinit(allocator);
    try drain(&encoder, &wire, false);
    try accept(&encoder, second);
    encoder.finish();
    try drain(&encoder, &wire, true);
    return wire.toOwnedSlice(allocator);
}

fn refuseAndRetry(encoder: *Encoder, expected: []const u8) !void {
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(allocator);
    try drain(encoder, &wire, false);
    try accept(encoder, second);
    encoder.finish();
    const before = encoder.snapshot();
    const state = encoder.codec_state;
    const hash = encoder.hasher;
    var output: [3]u8 = @splat(0xa5);
    try std.testing.expectError(error.SearchLimitExceeded, encoder.step("", &output));
    try std.testing.expectEqualDeep(before, encoder.snapshot());
    try std.testing.expectEqualDeep(state, encoder.codec_state);
    try std.testing.expectEqualDeep(hash, encoder.hasher);
    try std.testing.expectEqualSlices(u8, second, encoder.block.items);
    try std.testing.expectEqualSlices(u8, &([_]u8{0xa5} ** 3), &output);
    encoder.options.hq.?.max_price_evaluations = limit;
    try drain(encoder, &wire, true);
    try std.testing.expectEqualSlices(u8, expected, wire.items);
    try expectPlain(wire.items, second);
}

test "Zstd incremental HQ search null profile enforces cap across nextFrame and reset" {
    const request = requests[2];
    var successful = request;
    successful.max_price_evaluations = limit;
    const expected = try freshWire(options(successful, null));
    defer allocator.free(expected);
    var encoder = try Encoder.initExactSize(allocator, options(successful, null), second.len);
    defer encoder.deinit();
    var first_wire: std.ArrayList(u8) = .empty;
    defer first_wire.deinit(allocator);
    try drain(&encoder, &first_wire, false);
    try accept(&encoder, second);
    encoder.finish();
    try drain(&encoder, &first_wire, true);
    try std.testing.expectEqualSlices(u8, expected, first_wire.items);
    const completed = encoder.snapshot();
    const refused_options = options(request, null);
    try encoder.nextFrameExactSize(refused_options, second.len);
    try std.testing.expectEqualDeep(refused_options, encoder.options);
    try std.testing.expectEqual(completed.input_read, encoder.snapshot().input_read);
    try std.testing.expectEqual(completed.output_written, encoder.snapshot().output_written);
    try std.testing.expectEqual(completed.frame_count, encoder.snapshot().frame_count);
    try std.testing.expectEqual(@as(Count, 0), encoder.history.absolute_start);
    try std.testing.expectEqual(@as(Count, 0), encoder.history.absolute_end);
    try std.testing.expectEqual(@as(usize, 0), encoder.history.bytes.items.len);
    try std.testing.expect(!encoder.codec_state.sequence_state_initialized);
    try std.testing.expect(encoder.codec_state.sequence_state.previous_tables == null);
    try std.testing.expect(encoder.codec_state.previous_huffman_plan == null);
    try std.testing.expect(encoder.codec_state.hq_entropy == null);
    try refuseAndRetry(&encoder, expected);
    try std.testing.expectEqual(@as(Count, 2), encoder.snapshot().frame_count);
    encoder.options.hq.?.max_price_evaluations = 0;
    const reset_options = encoder.options;
    encoder.reset();
    try std.testing.expectEqualDeep(reset_options, encoder.options);
    try std.testing.expectEqual(@as(?Count, second.len), encoder.expected_input_len);
    try std.testing.expectEqual(@as(Count, 0), encoder.snapshot().input_read);
    try std.testing.expectEqual(@as(Count, 0), encoder.snapshot().output_written);
    try std.testing.expectEqual(@as(Count, 0), encoder.snapshot().frame_count);
    try std.testing.expectEqual(@as(usize, 0), encoder.history.bytes.items.len);
    try std.testing.expect(!encoder.codec_state.sequence_state_initialized);
    try std.testing.expect(encoder.codec_state.hq_entropy == null);
    try refuseAndRetry(&encoder, expected);
    try std.testing.expectEqual(@as(Count, 1), encoder.snapshot().frame_count);
}
