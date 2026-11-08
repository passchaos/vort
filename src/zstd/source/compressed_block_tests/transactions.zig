const std = @import("std");
const common = @import("common.zig");
const compressed_block = common.compressed_block;
const source_frame = common.source_frame;

const Attempt = enum { before_prefix, found, past_end };

fn faultAttempt(
    comptime Support: type,
    bytes: []const u8,
    expected: []const u8,
    mode: common.Mode,
    call_delta: usize,
) !Attempt {
    var source = common.TrackingSource{ .bytes = bytes };
    const frame = try common.parseFrame(&source);
    const block = try source_frame.parseFirstBlock(frame);
    var state: Support.State = Support.initialState();
    const before = state;
    var scratch: [common.source_huffman.maximum_scratch_len]u8 = undefined;
    var prepared = try compressed_block.prepare(
        Support.HuffmanCodec,
        Support.SequenceCodec,
        block,
        &state,
        &scratch,
    );

    const window_len: usize = @intCast(frame.header.window_size);
    const history_storage = try std.testing.allocator.alloc(u8, window_len);
    defer std.testing.allocator.free(history_storage);
    const shadow_storage = try std.testing.allocator.alloc(u8, window_len);
    defer std.testing.allocator.free(shadow_storage);
    @memset(history_storage, 0xa7);
    @memset(shadow_storage, 0xa7);
    var history = try common.initHistory(history_storage, frame.header.window_size);
    var shadow = try common.initHistory(shadow_storage, frame.header.window_size);

    const staging_guard = try std.testing.allocator.alloc(
        u8,
        frame.header.block_size_max + 2,
    );
    defer std.testing.allocator.free(staging_guard);
    @memset(staging_guard, 0xd8);
    staging_guard[0] = 0x51;
    staging_guard[staging_guard.len - 1] = 0xae;
    var literal_guard: [11]u8 = @splat(0x73);
    var sequence_guard: [11]u8 = @splat(0x94);
    literal_guard[0] = 0x39;
    literal_guard[10] = 0xc6;
    sequence_guard[0] = 0x2a;
    sequence_guard[10] = 0xd5;
    var executor = try compressed_block.Executor(
        Support.HuffmanCodec,
        Support.SequenceCodec,
    ).init(
        &prepared,
        &state,
        &history,
        staging_guard[1 .. staging_guard.len - 1],
        literal_guard[1..10],
        sequence_guard[1..10],
        common.limits(frame),
    );

    const first_execute_call = source.calls + 1;
    source.mode = mode;
    source.fault_call = first_execute_call + call_delta - 1;
    if (executor.execute()) |_| return .past_end else |err| {
        try std.testing.expect(err == common.expectedError(mode));
    }
    try Support.expectStateEqual(&before, &state);
    try common.expectHistoryEqual(shadow, history);
    try std.testing.expect(!executor.snapshot().committed);
    try std.testing.expect(!executor.snapshot().failed);
    try std.testing.expectError(error.InvalidStreamState, executor.committedBytes());
    try std.testing.expectError(error.InvalidStreamState, executor.drain(&.{}));
    try common.expectGuard(staging_guard, 0x51, 0xae);
    try common.expectGuard(&literal_guard, 0x39, 0xc6);
    try common.expectGuard(&sequence_guard, 0x2a, 0xd5);
    if (executor.snapshot().staged_len == 0) return .before_prefix;

    source.clearFault();
    try executor.execute();
    try std.testing.expectEqualSlices(u8, expected, try executor.committedBytes());
    try common.expectEntropyCommit(Support, before, &prepared, &executor, state);
    shadow.append(expected);
    try common.expectHistoryEqual(shadow, history);
    const after = state;
    try common.drainExpected(
        Support,
        &executor,
        expected,
        &after,
        &state,
        shadow,
        &history,
    );
    try Support.expectStateEqual(&after, &state);
    try common.expectHistoryEqual(shadow, history);
    return .found;
}

fn sourceFailuresRetryAfterStagedPrefix(comptime Support: type) !void {
    const bytes = try common.decodeHex(common.numbered_json_hex);
    defer std.testing.allocator.free(bytes);
    const expected = try Support.decodeFrameOracle(std.testing.allocator, bytes);
    defer std.testing.allocator.free(expected);

    inline for (.{ common.Mode.zero, .excessive, .fail }) |mode| {
        var found = false;
        for (1..512) |call_delta| {
            switch (try faultAttempt(
                Support,
                bytes,
                expected,
                mode,
                call_delta,
            )) {
                .before_prefix => {},
                .found => {
                    found = true;
                    break;
                },
                .past_end => break,
            }
        }
        try std.testing.expect(found);
    }
}

fn expectLimitFailureNoCommit(
    comptime Support: type,
    expected_error: anyerror,
    restrict_block: bool,
    expected_size_delta: usize,
) !void {
    const bytes = &common.rle_literals_frame;
    const expected = try Support.decodeFrameOracle(std.testing.allocator, bytes);
    defer std.testing.allocator.free(expected);
    var source = common.TrackingSource{ .bytes = bytes };
    const frame = try common.parseFrame(&source);
    const block = try source_frame.parseFirstBlock(frame);
    var state: Support.State = Support.initialState();
    const before = state;
    var scratch: [common.source_huffman.maximum_scratch_len]u8 = undefined;
    var prepared = try compressed_block.prepare(
        Support.HuffmanCodec,
        Support.SequenceCodec,
        block,
        &state,
        &scratch,
    );

    const window_len: usize = @intCast(frame.header.window_size);
    const history_storage = try std.testing.allocator.alloc(u8, window_len);
    defer std.testing.allocator.free(history_storage);
    const shadow_storage = try std.testing.allocator.alloc(u8, window_len);
    defer std.testing.allocator.free(shadow_storage);
    @memset(history_storage, 0xa7);
    @memset(shadow_storage, 0xa7);
    var history = try common.initHistory(history_storage, frame.header.window_size);
    const shadow = try common.initHistory(shadow_storage, frame.header.window_size);
    const staging_guard = try std.testing.allocator.alloc(
        u8,
        frame.header.block_size_max + 2,
    );
    defer std.testing.allocator.free(staging_guard);
    @memset(staging_guard, 0xd8);
    staging_guard[0] = 0x51;
    staging_guard[staging_guard.len - 1] = 0xae;
    var literal_page: [9]u8 = undefined;
    var sequence_page: [9]u8 = undefined;
    var selected_limits = common.limits(frame);
    if (restrict_block) selected_limits.block_decoded_max = expected.len - 1;
    if (expected_size_delta != 0) {
        selected_limits.expected_frame_size = @as(u64, @intCast(expected.len)) +
            expected_size_delta;
    }
    var executor = try compressed_block.Executor(
        Support.HuffmanCodec,
        Support.SequenceCodec,
    ).init(
        &prepared,
        &state,
        &history,
        staging_guard[1 .. staging_guard.len - 1],
        &literal_page,
        &sequence_page,
        selected_limits,
    );
    try std.testing.expectError(expected_error, executor.execute());
    try Support.expectStateEqual(&before, &state);
    try common.expectHistoryEqual(shadow, history);
    try std.testing.expect(!executor.snapshot().committed);
    try std.testing.expect(executor.snapshot().failed);
    try std.testing.expectError(error.InvalidStreamState, executor.committedBytes());
    try std.testing.expectError(error.InvalidStreamState, executor.drain(&.{}));
    try common.expectGuard(staging_guard, 0x51, 0xae);
    if (expected_size_delta != 0)
        try std.testing.expectEqual(expected.len, executor.snapshot().staged_len);
}

fn lateValidationNeverCommits(comptime Support: type) !void {
    try expectLimitFailureNoCommit(
        Support,
        error.CorruptFrame,
        true,
        0,
    );
    try expectLimitFailureNoCommit(Support, error.SizeMismatch, false, 1);
}

pub fn contracts(comptime Support: type) !void {
    try sourceFailuresRetryAfterStagedPrefix(Support);
    try lateValidationNeverCommits(Support);
}
