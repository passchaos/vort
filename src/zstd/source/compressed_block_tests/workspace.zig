const std = @import("std");
const common = @import("common.zig");
const compressed_block = common.compressed_block;
const source_frame = common.source_frame;

const AliasPair = enum {
    history_staging,
    history_literal,
    history_sequence,
    staging_literal,
    staging_sequence,
    literal_sequence,
};

fn pairwiseAliasesFailBeforeReads(comptime Support: type) !void {
    const bytes = try common.decodeHex(common.numbered_json_hex);
    defer std.testing.allocator.free(bytes);
    var source = common.TrackingSource{ .bytes = bytes };
    const frame = try common.parseFrame(&source);
    const block = try source_frame.parseFirstBlock(frame);
    var prepare_state: Support.State = Support.initialState();
    var scratch: [common.source_huffman.maximum_scratch_len]u8 = undefined;
    var prepared = try compressed_block.prepare(
        Support.HuffmanCodec,
        Support.SequenceCodec,
        block,
        &prepare_state,
        &scratch,
    );

    const window_len: usize = @intCast(frame.header.window_size);
    const history_storage = try std.testing.allocator.alloc(u8, window_len);
    defer std.testing.allocator.free(history_storage);
    const staging_storage = try std.testing.allocator.alloc(
        u8,
        frame.header.block_size_max,
    );
    defer std.testing.allocator.free(staging_storage);
    const literal_storage = try std.testing.allocator.alloc(u8, 17);
    defer std.testing.allocator.free(literal_storage);
    const sequence_storage = try std.testing.allocator.alloc(u8, 17);
    defer std.testing.allocator.free(sequence_storage);
    const shared_len = @max(@max(window_len, frame.header.block_size_max), 17);
    const shared = try std.testing.allocator.alloc(u8, shared_len);
    defer std.testing.allocator.free(shared);

    inline for (std.meta.tags(AliasPair)) |pair| {
        var history_slice = history_storage;
        var staging = staging_storage;
        var literal_page = literal_storage;
        var sequence_page = sequence_storage;
        switch (pair) {
            .history_staging => {
                history_slice = shared[0..window_len];
                staging = shared[0..frame.header.block_size_max];
            },
            .history_literal => {
                history_slice = shared[0..window_len];
                literal_page = shared[0..17];
            },
            .history_sequence => {
                history_slice = shared[0..window_len];
                sequence_page = shared[0..17];
            },
            .staging_literal => {
                staging = shared[0..frame.header.block_size_max];
                literal_page = shared[0..17];
            },
            .staging_sequence => {
                staging = shared[0..frame.header.block_size_max];
                sequence_page = shared[0..17];
            },
            .literal_sequence => {
                literal_page = shared[0..17];
                sequence_page = shared[0..17];
            },
        }
        var state: Support.State = Support.initialState();
        var history = try common.initHistory(history_slice, frame.header.window_size);
        const calls_before = source.calls;
        try std.testing.expectError(
            error.InvalidBlockPlan,
            compressed_block.Executor(
                Support.HuffmanCodec,
                Support.SequenceCodec,
            ).init(
                &prepared,
                &state,
                &history,
                staging,
                literal_page,
                sequence_page,
                common.limits(frame),
            ),
        );
        try std.testing.expectEqual(calls_before, source.calls);
    }
}

fn shortWorkspacesFailBeforeReads(comptime Support: type) !void {
    const bytes = try common.decodeHex(common.numbered_json_hex);
    defer std.testing.allocator.free(bytes);
    var source = common.TrackingSource{ .bytes = bytes };
    const frame = try common.parseFrame(&source);
    const block = try source_frame.parseFirstBlock(frame);
    var prepare_state: Support.State = Support.initialState();
    var scratch: [common.source_huffman.maximum_scratch_len]u8 = undefined;
    var prepared = try compressed_block.prepare(
        Support.HuffmanCodec,
        Support.SequenceCodec,
        block,
        &prepare_state,
        &scratch,
    );
    const window_len: usize = @intCast(frame.header.window_size);
    const history_storage = try std.testing.allocator.alloc(u8, window_len);
    defer std.testing.allocator.free(history_storage);
    const staging = try std.testing.allocator.alloc(u8, frame.header.block_size_max);
    defer std.testing.allocator.free(staging);
    var literal_page: [17]u8 = undefined;
    var sequence_page: [17]u8 = undefined;

    inline for (.{ 0, 1, 8 }) |short_len| {
        inline for (.{ true, false }) |short_literal| {
            var state: Support.State = Support.initialState();
            var history = try common.initHistory(history_storage, frame.header.window_size);
            const calls_before = source.calls;
            try std.testing.expectError(
                error.OutputTooSmall,
                compressed_block.Executor(
                    Support.HuffmanCodec,
                    Support.SequenceCodec,
                ).init(
                    &prepared,
                    &state,
                    &history,
                    staging,
                    if (short_literal) literal_page[0..short_len] else &literal_page,
                    if (short_literal) &sequence_page else sequence_page[0..short_len],
                    common.limits(frame),
                ),
            );
            try std.testing.expectEqual(calls_before, source.calls);
        }
    }

    var state: Support.State = Support.initialState();
    var history = try common.initHistory(history_storage, frame.header.window_size);
    const calls_before = source.calls;
    try std.testing.expectError(
        error.OutputTooSmall,
        compressed_block.Executor(
            Support.HuffmanCodec,
            Support.SequenceCodec,
        ).init(
            &prepared,
            &state,
            &history,
            staging[0 .. staging.len - 1],
            &literal_page,
            &sequence_page,
            common.limits(frame),
        ),
    );
    try std.testing.expectEqual(calls_before, source.calls);
}

fn outerNonCompressedRejectedWithoutPayloadReads(comptime Support: type) !void {
    const bytes = try common.decodeHex(common.numbered_json_hex);
    defer std.testing.allocator.free(bytes);
    var source = common.TrackingSource{ .bytes = bytes };
    const frame = try common.parseFrame(&source);
    const parsed = try source_frame.parseFirstBlock(frame);
    var state: Support.State = Support.initialState();
    var scratch: [common.source_huffman.maximum_scratch_len]u8 = undefined;
    inline for (.{ source_frame.BlockLayout{
        .header = .{
            .last = parsed.header.last,
            .kind = .raw,
            .declared_len = parsed.header.declared_len,
            .wire_len = parsed.header.wire_len,
        },
        .header_range = parsed.header_range,
        .payload = parsed.payload,
        .next_header_offset = parsed.next_header_offset,
    }, source_frame.BlockLayout{
        .header = .{
            .last = parsed.header.last,
            .kind = .rle,
            .declared_len = parsed.header.declared_len,
            .wire_len = parsed.header.wire_len,
        },
        .header_range = parsed.header_range,
        .payload = parsed.payload,
        .next_header_offset = parsed.next_header_offset,
    } }) |block| {
        const calls_before = source.calls;
        try std.testing.expectError(
            error.CorruptFrame,
            compressed_block.prepare(
                Support.HuffmanCodec,
                Support.SequenceCodec,
                block,
                &state,
                &scratch,
            ),
        );
        try std.testing.expectEqual(calls_before, source.calls);
    }
}

pub fn contracts(comptime Support: type) !void {
    try pairwiseAliasesFailBeforeReads(Support);
    try shortWorkspacesFailBeforeReads(Support);
    try outerNonCompressedRejectedWithoutPayloadReads(Support);
}
