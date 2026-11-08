const std = @import("std");
const common = @import("common.zig");
const compressed_block = common.compressed_block;
const source_frame = common.source_frame;

fn zeroSequencesKeepCommittedEntropy(comptime Support: type) !void {
    const seed_bytes = try common.decodeHex(common.numbered_json_hex);
    defer std.testing.allocator.free(seed_bytes);
    var seed_source = common.TrackingSource{ .bytes = seed_bytes };
    const seed_frame = try common.parseFrame(&seed_source);
    const seed_block = try source_frame.parseFirstBlock(seed_frame);
    var state: Support.State = Support.initialState();
    var seed_scratch: [common.source_huffman.maximum_scratch_len]u8 = undefined;
    const seed = try compressed_block.prepare(
        Support.HuffmanCodec,
        Support.SequenceCodec,
        seed_block,
        &state,
        &seed_scratch,
    );
    const pending_huffman = seed.pending_huffman orelse
        return error.TestUnexpectedResult;
    const pending_sequences = seed.pending_sequences orelse
        return error.TestUnexpectedResult;
    state.huffman = pending_huffman.table;
    state.sequence_tables = pending_sequences.tables;
    state.repeated_offsets = .{ 17, 29, 43 };

    const expected = try Support.decodeFrameOracle(
        std.testing.allocator,
        &common.zero_sequence_frame,
    );
    defer std.testing.allocator.free(expected);
    var source = common.TrackingSource{ .bytes = &common.zero_sequence_frame };
    const frame = try common.parseFrame(&source);
    const block = try source_frame.parseFirstBlock(frame);
    try common.expectCompressed(block);
    var scratch: [common.source_huffman.maximum_scratch_len]u8 = undefined;
    var prepared = try compressed_block.prepare(
        Support.HuffmanCodec,
        Support.SequenceCodec,
        block,
        &state,
        &scratch,
    );
    try std.testing.expectEqual(@as(usize, 0), prepared.literals.sequence_count);
    try std.testing.expect(prepared.pending_huffman == null);
    try std.testing.expect(prepared.pending_sequences == null);

    var history_storage: [5]u8 = @splat(0x5a);
    var shadow_storage: [5]u8 = @splat(0x5a);
    var history = try common.initHistory(&history_storage, frame.header.window_size);
    var shadow = try common.initHistory(&shadow_storage, frame.header.window_size);
    var staging: [5]u8 = undefined;
    var literal_page: [9]u8 = undefined;
    var sequence_page: [9]u8 = undefined;
    const before = state;
    var executor = try compressed_block.Executor(
        Support.HuffmanCodec,
        Support.SequenceCodec,
    ).init(
        &prepared,
        &state,
        &history,
        &.{},
        &staging,
        &literal_page,
        &sequence_page,
        common.limits(frame),
    );
    try executor.execute();
    try std.testing.expectEqualSlices(u8, expected, try executor.committedBytes());
    try std.testing.expectEqual(@as(u64, expected.len), state.frame_decoded);
    try std.testing.expectEqual(before.repeated_offsets, state.repeated_offsets);
    try std.testing.expect(state.huffman != null);
    try Support.expectHuffmanEqual(&before.huffman.?, &state.huffman.?);
    try std.testing.expect(state.sequence_tables != null);
    try Support.expectSequenceTablesEqual(
        &before.sequence_tables.?,
        &state.sequence_tables.?,
    );
    shadow.append(expected);
    const committed_state = state;
    try common.drainExpected(
        Support,
        &executor,
        expected,
        &committed_state,
        &state,
        shadow,
        &history,
    );
}

pub fn contracts(comptime Support: type) !void {
    try zeroSequencesKeepCommittedEntropy(Support);
}
