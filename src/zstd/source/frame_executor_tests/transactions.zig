const std = @import("std");
const common = @import("common.zig");
const frame_executor = common.frame_executor;
const history_workspace = common.history_workspace;

fn Runner(comptime Support: type) type {
    return common.Runner(Support);
}

fn Executor(comptime Support: type) type {
    return frame_executor.Executor(Support.HuffmanCodec, Support.SequenceCodec);
}

fn oracle(comptime Support: type, bytes: []const u8) ![]u8 {
    return Support.decodeFrameOracle(std.testing.allocator, bytes);
}

fn retryable(err: anyerror) bool {
    return err == error.SourceReadFailed or err == error.TruncatedFrame;
}

fn expectRetryAfterSourceFailure(
    comptime Support: type,
    mode: common.block_common.Mode,
    comptime encoded: []const u8,
) !void {
    const bytes = try common.decodeHex(encoded);
    defer std.testing.allocator.free(bytes);
    const expected = try oracle(Support, bytes);
    defer std.testing.allocator.free(expected);

    var found = false;
    var delta: usize = 1;
    while (delta < 256 and !found) : (delta += 1) {
        var runner: Runner(Support) = undefined;
        try runner.init(
            std.testing.allocator,
            bytes,
            Support.initialState(),
            &.{},
            0,
            .{},
            9,
            97,
        );
        defer runner.deinit();
        runner.source.mode = mode;
        runner.source.fault_call = runner.source.calls + delta;
        if (runner.run()) |_| {
            // The injected call lies past the frame's last source callback.
        } else |err| {
            try std.testing.expectEqual(common.block_common.expectedError(mode), err);
            try std.testing.expect(retryable(err));
            try std.testing.expect(!runner.executor.snapshot().failed);
            runner.source.clearFault();
            try runner.run();
            try std.testing.expectEqualSlices(u8, expected, runner.output.items);
            try std.testing.expectEqual(
                @as(u64, @intCast(expected.len)),
                @as(u64, @intCast(runner.state.frame_decoded)),
            );
            try runner.expectGuards();
            try runner.expectHistory(expected, 0);
            found = true;
        }
    }
    try std.testing.expect(found);
}

fn sourceFailures(comptime Support: type) !void {
    inline for (.{
        common.block_common.Mode.zero,
        common.block_common.Mode.excessive,
        common.block_common.Mode.fail,
    }) |mode| {
        try expectRetryAfterSourceFailure(Support, mode, common.numbered_json_hex);
        try expectRetryAfterSourceFailure(Support, mode, common.predefined_repeat_hex);
    }
}

fn truncatedInput(comptime Support: type) !void {
    var fixture: common.Fixture = .{};
    common.appendHeader(&fixture, 0x04, 0x00, 0, null);
    common.appendRawBlock(&fixture, "abc", false);
    common.appendRleBlock(&fixture, 'q', 2, false);
    common.appendRawBlock(&fixture, "de", true);
    common.appendChecksum(&fixture, "abcqqde");

    for (0..fixture.len) |len| {
        var runner: Runner(Support) = undefined;
        if (runner.init(
            std.testing.allocator,
            fixture.bytes()[0..len],
            Support.initialState(),
            &.{},
            0,
            .{},
            9,
            256,
        )) |_| {
            defer runner.deinit();
            try std.testing.expectError(error.TruncatedFrame, runner.run());
            try std.testing.expect(!runner.executor.snapshot().failed);
            try runner.expectGuards();
        } else |err| {
            try std.testing.expectEqual(error.TruncatedFrame, err);
            runner.deinit();
        }
    }
}

fn aliasFixture() !struct { fixture: common.Fixture, frame: common.source_frame.DataFrameLayout } {
    var fixture: common.Fixture = .{};
    common.appendHeader(&fixture, 0x00, 0x00, 0, null);
    common.appendRawBlock(&fixture, "abc", true);
    var source = common.TrackingSource{ .bytes = fixture.bytes() };
    const frame = try common.block_common.parseFrame(&source);
    return .{ .fixture = fixture, .frame = frame };
}

fn expectInitError(
    comptime Support: type,
    frame: common.source_frame.DataFrameLayout,
    state: *Support.State,
    history: *history_workspace.Binding,
    dictionary: []const u8,
    dictionary_id: u32,
    staging: []u8,
    literal_page: []u8,
    sequence_page: []u8,
    expected: anyerror,
) !void {
    try std.testing.expectError(
        expected,
        Executor(Support).init(
            frame,
            state,
            history,
            dictionary,
            dictionary_id,
            staging,
            literal_page,
            sequence_page,
            .{},
        ),
    );
}

fn workspaceValidation(comptime Support: type) !void {
    const fixture = try aliasFixture();
    const frame = fixture.frame;
    const window: usize = @intCast(frame.header.window_size);
    const block_max = frame.header.block_size_max;

    const shared = try std.testing.allocator.alloc(u8, @max(window, block_max));
    defer std.testing.allocator.free(shared);
    @memset(shared, 0);
    var state: Support.State = Support.initialState();
    var history = try history_workspace.Binding.init(shared);
    try history.beginFrame(frame.header.window_size, 0);
    var literal_page: [9]u8 = @splat(0);
    var sequence_page: [9]u8 = @splat(0);

    // Staging aliases history storage.
    try expectInitError(
        Support,
        frame,
        &state,
        &history,
        &.{},
        0,
        shared[0..block_max],
        &literal_page,
        &sequence_page,
        error.InvalidBlockPlan,
    );

    // The literal page aliases staging.
    const staging = try std.testing.allocator.alloc(u8, block_max);
    defer std.testing.allocator.free(staging);
    @memset(staging, 0);
    try expectInitError(
        Support,
        frame,
        &state,
        &history,
        &.{},
        0,
        staging,
        staging[0..9],
        &sequence_page,
        error.InvalidBlockPlan,
    );

    // Dictionary bytes alias staging.
    var dictionary_history = try history_workspace.Binding.init(
        try std.testing.allocator.alloc(u8, window + 4),
    );
    defer {
        std.testing.allocator.free(dictionary_history.storage);
        dictionary_history.clear();
    }
    try dictionary_history.beginFrame(frame.header.window_size, 4);
    try expectInitError(
        Support,
        frame,
        &state,
        &dictionary_history,
        staging[0..4],
        0,
        staging,
        &literal_page,
        &sequence_page,
        error.InvalidBlockPlan,
    );

    // A nonzero decoded counter is not a fresh frame.
    var decoded_state: Support.State = Support.initialState();
    decoded_state.frame_decoded = 1;
    try expectInitError(
        Support,
        frame,
        &decoded_state,
        &history,
        &.{},
        0,
        staging,
        &literal_page,
        &sequence_page,
        error.InvalidStreamState,
    );

    // Nonempty retained history is not a fresh frame.
    var dirty_history = try history_workspace.Binding.init(
        try std.testing.allocator.alloc(u8, window),
    );
    defer {
        std.testing.allocator.free(dirty_history.storage);
        dirty_history.clear();
    }
    try dirty_history.beginFrame(frame.header.window_size, 0);
    dirty_history.append("x");
    try expectInitError(
        Support,
        frame,
        &state,
        &dirty_history,
        &.{},
        0,
        staging,
        &literal_page,
        &sequence_page,
        error.InvalidStreamState,
    );

    // The binding window must match the frame header.
    var narrow_history = try history_workspace.Binding.init(
        try std.testing.allocator.alloc(u8, window),
    );
    defer {
        std.testing.allocator.free(narrow_history.storage);
        narrow_history.clear();
    }
    try narrow_history.beginFrame(frame.header.window_size / 2, 0);
    try expectInitError(
        Support,
        frame,
        &state,
        &narrow_history,
        &.{},
        0,
        staging,
        &literal_page,
        &sequence_page,
        error.InvalidStreamState,
    );

    // Inactive and undersized workspaces are rejected before any callback.
    var inactive: history_workspace.Binding = .{};
    try expectInitError(
        Support,
        frame,
        &state,
        &inactive,
        &.{},
        0,
        staging,
        &literal_page,
        &sequence_page,
        error.InvalidStreamState,
    );
    try expectInitError(
        Support,
        frame,
        &state,
        &history,
        &.{},
        0,
        staging[0 .. block_max - 1],
        &literal_page,
        &sequence_page,
        error.OutputTooSmall,
    );
    var short_page: [8]u8 = @splat(0);
    try expectInitError(
        Support,
        frame,
        &state,
        &history,
        &.{},
        0,
        staging,
        &short_page,
        &sequence_page,
        error.OutputTooSmall,
    );
}

fn drainContract(comptime Support: type) !void {
    var fixture: common.Fixture = .{};
    common.appendHeader(&fixture, 0x00, 0x00, 0, null);
    common.appendRawBlock(&fixture, "abc", false);
    common.appendRawBlock(&fixture, "de", true);

    var source = common.TrackingSource{ .bytes = fixture.bytes() };
    const frame = try common.block_common.parseFrame(&source);
    const window: usize = @intCast(frame.header.window_size);
    const block_max = frame.header.block_size_max;
    const history_storage = try std.testing.allocator.alloc(u8, window);
    defer std.testing.allocator.free(history_storage);
    @memset(history_storage, 0xa7);
    var history = try history_workspace.Binding.init(history_storage);
    try history.beginFrame(frame.header.window_size, 0);
    const staging = try std.testing.allocator.alloc(u8, block_max);
    defer std.testing.allocator.free(staging);
    @memset(staging, 0xd8);
    var literal_page: [9]u8 = @splat(0);
    var sequence_page: [9]u8 = @splat(0);
    var state: Support.State = Support.initialState();

    var executor = try Executor(Support).init(
        frame,
        &state,
        &history,
        &.{},
        0,
        staging,
        &literal_page,
        &sequence_page,
        .{},
    );

    try std.testing.expectError(error.InvalidStreamState, executor.committedBytes());
    try std.testing.expectError(error.InvalidStreamState, executor.drain(&.{}));
    try std.testing.expectError(error.InvalidStreamState, executor.frameEndOffset());

    try executor.execute();
    try std.testing.expectEqualStrings("abc", try executor.committedBytes());
    try std.testing.expectEqual(
        @as(u64, 3),
        @as(u64, @intCast(state.frame_decoded)),
    );
    try std.testing.expectError(error.InvalidStreamState, executor.execute());

    const empty = try executor.drain(&.{});
    try std.testing.expectEqual(@as(usize, 0), empty.written);
    try std.testing.expectEqual(
        frame_executor.DrainResult.Status.need_output,
        empty.status,
    );
    try std.testing.expectError(
        error.InvalidBlockPlan,
        executor.drain(staging[0..1]),
    );

    var output: [5]u8 = undefined;
    var written: usize = 0;
    const first = try executor.drain(output[0..1]);
    try std.testing.expectEqual(@as(usize, 1), first.written);
    try std.testing.expectEqual(
        frame_executor.DrainResult.Status.need_output,
        first.status,
    );
    written += first.written;
    const second = try executor.drain(output[1..4]);
    try std.testing.expectEqual(@as(usize, 2), second.written);
    try std.testing.expectEqual(
        frame_executor.DrainResult.Status.block_drained,
        second.status,
    );
    written += second.written;
    try std.testing.expectEqual(@as(usize, 3), written);
    try std.testing.expectEqualStrings("abc", output[0..3]);
    try std.testing.expectEqual(@as(usize, 0), executor.snapshot().staged_len);

    try executor.execute();
    try std.testing.expectEqualStrings("de", try executor.committedBytes());
    const tail = try executor.drain(output[3..5]);
    try std.testing.expectEqual(@as(usize, 2), tail.written);
    try std.testing.expectEqual(
        frame_executor.DrainResult.Status.block_drained,
        tail.status,
    );
    try std.testing.expectEqualStrings("abcde", output[0..5]);
    try std.testing.expectEqual(@as(u64, 5), state.frame_decoded);
    try std.testing.expectEqual(
        frame_executor.Phase.footer,
        executor.snapshot().phase,
    );
    try std.testing.expectError(error.InvalidStreamState, executor.frameEndOffset());

    try executor.execute();
    try std.testing.expectEqual(
        frame_executor.Phase.done,
        executor.snapshot().phase,
    );
    try std.testing.expectEqual(
        @as(u64, @intCast(fixture.len)),
        try executor.frameEndOffset(),
    );
    try std.testing.expectError(error.InvalidStreamState, executor.execute());
    try std.testing.expectError(error.InvalidStreamState, executor.drain(&.{}));
    try std.testing.expectError(error.InvalidStreamState, executor.committedBytes());

    // Retained history matches the published stream.
    const shadow_storage = try std.testing.allocator.alloc(u8, window);
    defer std.testing.allocator.free(shadow_storage);
    @memset(shadow_storage, 0xa7);
    var shadow = try history_workspace.Binding.init(shadow_storage);
    try shadow.beginFrame(frame.header.window_size, 0);
    shadow.append("abcde");
    try common.expectHistoryEqual(shadow, history);
}

fn dictionaryFrame(comptime Support: type) !void {
    var fixture = try Support.loadFullDictionaryFixture(std.testing.allocator);
    defer Support.freeFullDictionaryFixture(std.testing.allocator, &fixture);

    var source = common.TrackingSource{ .bytes = fixture.frame };
    const frame = try common.block_common.parseFrame(&source);
    const history_len = try history_workspace.requiredLen(
        frame.header.window_size,
        fixture.dictionary.len,
    );
    const history_storage = try std.testing.allocator.alloc(u8, history_len);
    defer std.testing.allocator.free(history_storage);
    @memset(history_storage, 0xa7);
    var history = try history_workspace.Binding.init(history_storage);
    try history.beginFrame(frame.header.window_size, fixture.dictionary.len);

    const staging = try std.testing.allocator.alloc(
        u8,
        frame.header.block_size_max,
    );
    defer std.testing.allocator.free(staging);
    @memset(staging, 0xd8);
    var literal_page: [17]u8 = @splat(0x73);
    var sequence_page: [17]u8 = @splat(0x94);
    var state = fixture.state;

    var executor = try Executor(Support).init(
        frame,
        &state,
        &history,
        fixture.dictionary,
        frame.header.dictionary_id,
        staging,
        &literal_page,
        &sequence_page,
        .{},
    );

    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(std.testing.allocator);
    while (executor.snapshot().phase != .done) {
        switch (executor.snapshot().phase) {
            .drain => {
                var buffer: [7]u8 = undefined;
                const result = try executor.drain(&buffer);
                try output.appendSlice(
                    std.testing.allocator,
                    buffer[0..result.written],
                );
            },
            else => try executor.execute(),
        }
    }
    try std.testing.expectEqualSlices(u8, fixture.expected, output.items);
    try std.testing.expectEqual(
        @as(u64, @intCast(fixture.expected.len)),
        @as(u64, @intCast(state.frame_decoded)),
    );
    try std.testing.expectEqual(
        @as(u64, @intCast(fixture.frame.len)),
        try executor.frameEndOffset(),
    );

    const shadow_storage = try std.testing.allocator.alloc(u8, history_len);
    defer std.testing.allocator.free(shadow_storage);
    @memset(shadow_storage, 0xa7);
    var shadow = try history_workspace.Binding.init(shadow_storage);
    try shadow.beginFrame(frame.header.window_size, fixture.dictionary.len);
    shadow.append(fixture.expected);
    try common.expectHistoryEqual(shadow, history);

    // A mismatched frame dictionary ID is rejected before any block.
    var wrong_state = fixture.state;
    var wrong_history = try history_workspace.Binding.init(history_storage);
    try wrong_history.beginFrame(frame.header.window_size, fixture.dictionary.len);
    try std.testing.expectError(
        error.DictionaryMismatch,
        Executor(Support).init(
            frame,
            &wrong_state,
            &wrong_history,
            fixture.dictionary,
            frame.header.dictionary_id +% 1,
            staging,
            &literal_page,
            &sequence_page,
            .{},
        ),
    );
}

pub fn contracts(comptime Support: type) !void {
    try sourceFailures(Support);
    try truncatedInput(Support);
    try workspaceValidation(Support);
    try drainContract(Support);
    try dictionaryFrame(Support);
}
