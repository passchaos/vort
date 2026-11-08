const std = @import("std");
const common = @import("common.zig");
const compressed_block = common.compressed_block;
const source_frame = common.source_frame;

fn uncompressedSuffixLen(
    frame: source_frame.DataFrameLayout,
    first: source_frame.BlockLayout,
) !usize {
    var total: usize = 0;
    var block = first;
    while (true) {
        if (block.header.kind == .compressed) return error.TestUnexpectedResult;
        total = std.math.add(usize, total, block.header.declared_len) catch
            return error.TestUnexpectedResult;
        if (block.header.last) return total;
        block = try source_frame.parseBlock(frame, block.next_header_offset);
    }
}

fn runFramePage(
    comptime Support: type,
    bytes: []const u8,
    comptime page_len: usize,
    compressed_prefix_only: bool,
    require_joint_entropy: bool,
) !void {
    const expected = try Support.decodeFrameOracle(std.testing.allocator, bytes);
    defer std.testing.allocator.free(expected);

    var source = common.TrackingSource{ .bytes = bytes };
    const frame = try common.parseFrame(&source);
    const window_len = std.math.cast(usize, frame.header.window_size) orelse
        return error.TestUnexpectedResult;
    const history_guard = try std.testing.allocator.alloc(u8, window_len + 2);
    defer std.testing.allocator.free(history_guard);
    const shadow_storage = try std.testing.allocator.alloc(u8, window_len);
    defer std.testing.allocator.free(shadow_storage);
    @memset(history_guard, 0xb4);
    @memset(shadow_storage, 0xb4);
    history_guard[0] = 0x31;
    history_guard[history_guard.len - 1] = 0xe7;
    var history = try common.initHistory(
        history_guard[1 .. history_guard.len - 1],
        frame.header.window_size,
    );
    var shadow = try common.initHistory(shadow_storage, frame.header.window_size);

    const staging_guard = try std.testing.allocator.alloc(
        u8,
        frame.header.block_size_max + 2,
    );
    defer std.testing.allocator.free(staging_guard);
    const literal_guard = try std.testing.allocator.alloc(u8, page_len + 2);
    defer std.testing.allocator.free(literal_guard);
    const sequence_guard = try std.testing.allocator.alloc(u8, page_len + 2);
    defer std.testing.allocator.free(sequence_guard);

    var state: Support.State = Support.initialState();
    var expected_offset: usize = 0;
    var block = try source_frame.parseFirstBlock(frame);
    var block_count: usize = 0;
    var reached_last = false;
    var saw_treeless = false;
    var saw_joint_entropy = false;
    var saw_joint_repcodes_change = false;
    var expected_prefix_len: ?usize = null;
    while (true) {
        try common.expectCompressed(block);
        var scratch: [common.source_huffman.maximum_scratch_len]u8 = undefined;
        const before = state;
        var prepared = try compressed_block.prepare(
            Support.HuffmanCodec,
            Support.SequenceCodec,
            block,
            &state,
            &scratch,
        );
        if (prepared.pending_huffman) |pending|
            saw_treeless = saw_treeless or pending.origin == .treeless_reuse;
        const joint_entropy = if (prepared.pending_huffman) |pending|
            pending.replace_on_block_success and prepared.pending_sequences != null
        else
            false;
        saw_joint_entropy = saw_joint_entropy or joint_entropy;
        try Support.expectStateEqual(&before, &state);

        @memset(staging_guard, 0xd8);
        @memset(literal_guard, 0x73);
        @memset(sequence_guard, 0x94);
        staging_guard[0] = 0x51;
        staging_guard[staging_guard.len - 1] = 0xae;
        literal_guard[0] = 0x39;
        literal_guard[literal_guard.len - 1] = 0xc6;
        sequence_guard[0] = 0x2a;
        sequence_guard[sequence_guard.len - 1] = 0xd5;
        var executor = try compressed_block.Executor(
            Support.HuffmanCodec,
            Support.SequenceCodec,
        ).init(
            &prepared,
            &state,
            &history,
            staging_guard[1 .. staging_guard.len - 1],
            literal_guard[1 .. literal_guard.len - 1],
            sequence_guard[1 .. sequence_guard.len - 1],
            common.limits(frame),
        );
        try std.testing.expectError(error.InvalidStreamState, executor.committedBytes());
        try std.testing.expectError(error.InvalidStreamState, executor.drain(&.{}));
        try Support.expectStateEqual(&before, &state);

        try executor.execute();
        const snapshot = executor.snapshot();
        try std.testing.expect(snapshot.committed);
        try std.testing.expect(!snapshot.failed);
        const committed = try executor.committedBytes();
        if (committed.len > expected.len - expected_offset)
            return error.TestUnexpectedResult;
        const expected_block = expected[expected_offset..][0..committed.len];
        try std.testing.expectEqualSlices(u8, expected_block, committed);
        expected_offset += committed.len;
        try std.testing.expectEqual(
            @as(u64, @intCast(expected_offset)),
            state.frame_decoded,
        );
        try common.expectEntropyCommit(
            Support,
            before,
            &prepared,
            &executor,
            state,
        );
        if (joint_entropy)
            saw_joint_repcodes_change = saw_joint_repcodes_change or
                !std.meta.eql(before.repeated_offsets, state.repeated_offsets);

        shadow.append(expected_block);
        try common.expectHistoryEqual(shadow, history);
        const committed_state = state;
        try common.drainExpected(
            Support,
            &executor,
            expected_block,
            &committed_state,
            &state,
            shadow,
            &history,
        );
        try Support.expectStateEqual(&committed_state, &state);
        try common.expectHistoryEqual(shadow, history);
        try common.expectGuard(staging_guard, 0x51, 0xae);
        try common.expectGuard(literal_guard, 0x39, 0xc6);
        try common.expectGuard(sequence_guard, 0x2a, 0xd5);
        try std.testing.expectEqual(.drained, executor.snapshot().phase);
        try std.testing.expectError(error.InvalidStreamState, executor.committedBytes());

        block_count += 1;
        if (block.header.last) {
            reached_last = true;
            break;
        }
        const next = try source_frame.parseBlock(frame, block.next_header_offset);
        if (next.header.kind != .compressed and compressed_prefix_only) {
            const suffix_len = try uncompressedSuffixLen(frame, next);
            if (suffix_len > expected.len) return error.TestUnexpectedResult;
            expected_prefix_len = expected.len - suffix_len;
            break;
        }
        block = next;
    }
    try std.testing.expect(block_count != 0);
    if (compressed_prefix_only) {
        try std.testing.expect(block_count >= 3);
        try std.testing.expect(saw_treeless);
        try std.testing.expect(!reached_last);
        try std.testing.expectEqual(expected_prefix_len.?, expected_offset);
    } else {
        try std.testing.expect(reached_last);
        try std.testing.expectEqual(expected.len, expected_offset);
    }
    if (require_joint_entropy) {
        try std.testing.expect(saw_joint_entropy);
        try std.testing.expect(saw_joint_repcodes_change);
    }
    try std.testing.expectEqual(@as(u64, @intCast(expected_offset)), state.frame_decoded);
    try common.expectGuard(history_guard, 0x31, 0xe7);
}

fn runHexPages(
    comptime Support: type,
    comptime encoded: []const u8,
    compressed_prefix_only: bool,
    require_joint_entropy: bool,
) !void {
    const bytes = try common.decodeHex(encoded);
    defer std.testing.allocator.free(bytes);
    inline for (.{ 9, 10, 17 }) |page_len|
        try runFramePage(
            Support,
            bytes,
            page_len,
            compressed_prefix_only,
            require_joint_entropy,
        );
}

fn runBytesPages(comptime Support: type, bytes: []const u8) !void {
    inline for (.{ 9, 10, 17 }) |page_len|
        try runFramePage(Support, bytes, page_len, false, false);
}

pub fn contracts(comptime Support: type) !void {
    try runHexPages(Support, common.all_fse_raw_hex, false, false);
    try runHexPages(Support, common.numbered_json_hex, false, true);
    try runHexPages(Support, common.predefined_repeat_hex, true, false);
    try runBytesPages(Support, &common.rle_literals_frame);
    try runBytesPages(Support, &common.zero_sequence_frame);
}
