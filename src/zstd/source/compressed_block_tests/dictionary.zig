const std = @import("std");
const common = @import("common.zig");
const compressed_block = common.compressed_block;
const source_frame = common.source_frame;

fn executeFixture(
    comptime Support: type,
    fixture: *const Support.OwnedDictionaryFixture,
    full_dictionary: bool,
) !void {
    var source = common.TrackingSource{ .bytes = fixture.frame };
    const frame = try common.parseFrame(&source);
    const block = try source_frame.parseFirstBlock(frame);
    try common.expectCompressed(block);
    try std.testing.expect(block.header.last);
    try std.testing.expectEqual(
        @as(u32, if (full_dictionary) 0x7c06_9d4d else 0),
        frame.header.dictionary_id,
    );

    var state = fixture.state;
    const before = state;
    if (full_dictionary) {
        try std.testing.expect(before.huffman != null);
        try std.testing.expect(before.sequence_tables != null);
    }
    var scratch: [common.source_huffman.maximum_scratch_len]u8 = undefined;
    var prepared = try compressed_block.prepare(
        Support.HuffmanCodec,
        Support.SequenceCodec,
        block,
        &state,
        &scratch,
    );
    try Support.expectStateEqual(&before, &state);
    if (full_dictionary) {
        // The frozen witness carries raw literals but consumes all three
        // dictionary-seeded FSE tables in Repeat mode.
        try std.testing.expect(prepared.pending_huffman == null);
        const sequences = prepared.pending_sequences orelse
            return error.TestUnexpectedResult;
        try std.testing.expectEqual(@as(u3, 0b111), sequences.repeat_mask);
        try std.testing.expectEqual(.repeat, sequences.wire_modes.literal_length);
        try std.testing.expectEqual(.repeat, sequences.wire_modes.offset);
        try std.testing.expectEqual(.repeat, sequences.wire_modes.match_length);
    }

    const history_len = try common.history_workspace.requiredLen(
        frame.header.window_size,
        fixture.dictionary.len,
    );
    const history_storage = try std.testing.allocator.alloc(u8, history_len);
    defer std.testing.allocator.free(history_storage);
    const shadow_storage = try std.testing.allocator.alloc(u8, history_len);
    defer std.testing.allocator.free(shadow_storage);
    @memset(history_storage, 0x6d);
    @memset(shadow_storage, 0x6d);
    var history = try common.history_workspace.Binding.init(history_storage);
    try history.beginFrame(frame.header.window_size, fixture.dictionary.len);
    var shadow = try common.history_workspace.Binding.init(shadow_storage);
    try shadow.beginFrame(frame.header.window_size, fixture.dictionary.len);

    const staging = try std.testing.allocator.alloc(u8, frame.header.block_size_max);
    defer std.testing.allocator.free(staging);
    var literal_page: [9]u8 = undefined;
    var sequence_page: [9]u8 = undefined;
    var executor = try compressed_block.Executor(
        Support.HuffmanCodec,
        Support.SequenceCodec,
    ).init(
        &prepared,
        &state,
        &history,
        fixture.dictionary,
        staging,
        &literal_page,
        &sequence_page,
        common.limits(frame),
    );
    try executor.execute();
    try std.testing.expectEqualSlices(u8, fixture.expected, try executor.committedBytes());
    try common.expectEntropyCommit(Support, before, &prepared, &executor, state);
    shadow.append(fixture.expected);
    try common.expectHistoryEqual(shadow, history);
    if (full_dictionary) {
        try std.testing.expect(state.huffman != null);
        try Support.expectHuffmanEqual(&before.huffman.?, &state.huffman.?);
        try std.testing.expect(!std.meta.eql(
            Support.initialState().repeated_offsets,
            state.repeated_offsets,
        ));
    }
}

fn rawDictionaryIsExplicit(comptime Support: type) !void {
    var fixture = try Support.loadRawDictionaryBlockFixture(std.testing.allocator);
    defer Support.freeRawDictionaryBlockFixture(std.testing.allocator, &fixture);
    try executeFixture(Support, &fixture, false);

    var source = common.TrackingSource{ .bytes = fixture.frame };
    const frame = try common.parseFrame(&source);
    const block = try source_frame.parseFirstBlock(frame);
    var state = fixture.state;
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
    var history = try common.initHistory(history_storage, frame.header.window_size);
    const staging = try std.testing.allocator.alloc(u8, frame.header.block_size_max);
    defer std.testing.allocator.free(staging);
    var literal_page: [9]u8 = undefined;
    var sequence_page: [9]u8 = undefined;
    var executor = try compressed_block.Executor(
        Support.HuffmanCodec,
        Support.SequenceCodec,
    ).init(
        &prepared,
        &state,
        &history,
        &.{},
        staging,
        &literal_page,
        &sequence_page,
        common.limits(frame),
    );
    try std.testing.expectError(error.InvalidMatch, executor.execute());
    try Support.expectStateEqual(&before, &state);
    try std.testing.expectEqual(@as(usize, 0), history.len);
}

const Attempt = enum { before_prefix, found, past_end };

fn faultAttempt(
    comptime Support: type,
    fixture: *const Support.OwnedDictionaryFixture,
    mode: common.Mode,
    call_delta: usize,
) !Attempt {
    var source = common.TrackingSource{ .bytes = fixture.frame };
    const frame = try common.parseFrame(&source);
    const block = try source_frame.parseFirstBlock(frame);
    var state = fixture.state;
    const before = state;
    var scratch: [common.source_huffman.maximum_scratch_len]u8 = undefined;
    var prepared = try compressed_block.prepare(
        Support.HuffmanCodec,
        Support.SequenceCodec,
        block,
        &state,
        &scratch,
    );
    const history_len = try common.history_workspace.requiredLen(
        frame.header.window_size,
        fixture.dictionary.len,
    );
    const history_storage = try std.testing.allocator.alloc(u8, history_len);
    defer std.testing.allocator.free(history_storage);
    const shadow_storage = try std.testing.allocator.alloc(u8, history_len);
    defer std.testing.allocator.free(shadow_storage);
    @memset(history_storage, 0xa7);
    @memset(shadow_storage, 0xa7);
    var history = try common.history_workspace.Binding.init(history_storage);
    try history.beginFrame(frame.header.window_size, fixture.dictionary.len);
    var shadow = try common.history_workspace.Binding.init(shadow_storage);
    try shadow.beginFrame(frame.header.window_size, fixture.dictionary.len);
    const staging = try std.testing.allocator.alloc(u8, frame.header.block_size_max);
    defer std.testing.allocator.free(staging);
    var literal_page: [9]u8 = undefined;
    var sequence_page: [9]u8 = undefined;
    var executor = try compressed_block.Executor(
        Support.HuffmanCodec,
        Support.SequenceCodec,
    ).init(
        &prepared,
        &state,
        &history,
        fixture.dictionary,
        staging,
        &literal_page,
        &sequence_page,
        common.limits(frame),
    );
    source.mode = mode;
    source.fault_call = source.calls + call_delta;
    if (executor.execute()) |_| return .past_end else |err| try std.testing.expect(err == common.expectedError(mode));
    try Support.expectStateEqual(&before, &state);
    try common.expectHistoryEqual(shadow, history);
    try std.testing.expect(!executor.snapshot().committed);
    try std.testing.expect(!executor.snapshot().failed);
    if (executor.snapshot().staged_len == 0) return .before_prefix;

    source.clearFault();
    try executor.execute();
    try std.testing.expectEqualSlices(u8, fixture.expected, try executor.committedBytes());
    try common.expectEntropyCommit(Support, before, &prepared, &executor, state);
    shadow.append(fixture.expected);
    try common.expectHistoryEqual(shadow, history);
    return .found;
}

fn fullDictionaryFaultsRetry(comptime Support: type) !void {
    var fixture = try Support.loadFullDictionaryFixture(std.testing.allocator);
    defer Support.freeFullDictionaryFixture(std.testing.allocator, &fixture);
    inline for (.{ common.Mode.zero, .excessive, .fail }) |mode| {
        var found = false;
        for (1..512) |call_delta| switch (try faultAttempt(
            Support,
            &fixture,
            mode,
            call_delta,
        )) {
            .before_prefix => {},
            .found => {
                found = true;
                break;
            },
            .past_end => break,
        };
        try std.testing.expect(found);
    }
}

pub fn contracts(comptime Support: type) !void {
    try rawDictionaryIsExplicit(Support);
    var full = try Support.loadFullDictionaryFixture(std.testing.allocator);
    defer Support.freeFullDictionaryFixture(std.testing.allocator, &full);
    try executeFixture(Support, &full, true);
    try fullDictionaryFaultsRetry(Support);
}
