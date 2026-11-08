const std = @import("std");
const common = @import("common.zig");
const compressed_block = common.compressed_block;
const source_frame = common.source_frame;

fn exactCapacityAndShortRejection(comptime Support: type) !void {
    var fixture = try Support.loadRawDictionaryBlockFixture(std.testing.allocator);
    defer Support.freeRawDictionaryBlockFixture(std.testing.allocator, &fixture);
    var source = common.TrackingSource{ .bytes = fixture.frame };
    const frame = try common.parseFrame(&source);
    const block = try source_frame.parseFirstBlock(frame);
    var state = fixture.state;
    var scratch: [common.source_huffman.maximum_scratch_len]u8 = undefined;
    var prepared = try compressed_block.prepare(
        Support.HuffmanCodec,
        Support.SequenceCodec,
        block,
        &state,
        &scratch,
    );
    const required = try common.history_workspace.requiredLen(
        frame.header.window_size,
        fixture.dictionary.len,
    );
    try std.testing.expectEqual(
        @as(usize, @intCast(frame.header.window_size)) + fixture.dictionary.len,
        required,
    );
    const history_storage = try std.testing.allocator.alloc(u8, required);
    defer std.testing.allocator.free(history_storage);
    var history = try common.history_workspace.Binding.init(history_storage);
    try history.beginFrame(frame.header.window_size, fixture.dictionary.len);
    const staging = try std.testing.allocator.alloc(u8, frame.header.block_size_max);
    defer std.testing.allocator.free(staging);
    var literal_page: [9]u8 = undefined;
    var sequence_page: [9]u8 = undefined;
    _ = try compressed_block.Executor(
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

    history.storage = history.storage[0 .. history.storage.len - 1];
    const calls_before = source.calls;
    try std.testing.expectError(
        error.InvalidStreamState,
        compressed_block.Executor(
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
        ),
    );
    try std.testing.expectEqual(calls_before, source.calls);
}

fn visibilityAndCrossSegmentMatch() !void {
    const window: usize = 8;
    const dictionary = "XYZ";
    const Case = struct { position: usize, available: usize, oldest: u8 };
    const cases = [_]Case{
        .{ .position = window - 1, .available = 10, .oldest = 'X' },
        .{ .position = window, .available = 8, .oldest = 'X' },
        .{ .position = window + 1, .available = 8, .oldest = 'Y' },
        .{ .position = window + dictionary.len, .available = 8, .oldest = 'd' },
    };
    const produced = "abcdefghijk";
    for (cases) |case| {
        var storage: [window + dictionary.len]u8 = undefined;
        var history = try common.history_workspace.Binding.init(&storage);
        try history.beginFrame(window, dictionary.len);
        history.append(produced[0..case.position]);
        try std.testing.expectEqual(
            case.available,
            try history.availableLen(dictionary.len, case.position),
        );
        var byte: [1]u8 = undefined;
        var written: usize = 0;
        try history.copyMatch(
            dictionary,
            &byte,
            &written,
            0,
            case.position,
            case.available,
            1,
        );
        try std.testing.expectEqual(case.oldest, byte[0]);
    }

    var storage: [10]u8 = undefined;
    var history = try common.history_workspace.Binding.init(&storage);
    try history.beginFrame(8, 2);
    history.append("abc");
    var staging: [10]u8 = undefined;
    @memcpy(staging[0..2], "xy");
    var written: usize = 2;
    try std.testing.expectEqual(
        @as(usize, 7),
        try history.availableLenWithCurrent(2, 3, written),
    );
    try history.copyMatch("DE", &staging, &written, 0, 3, 7, 8);
    try std.testing.expectEqualStrings("xyDEabcxyD", &staging);
}

const AliasTarget = enum {
    history_storage,
    staging,
    literal_page,
    sequence_page,
    prepared,
    state,
    history_binding,
};

fn dictionaryAliasesFailBeforeReads(comptime Support: type) !void {
    var fixture = try Support.loadRawDictionaryBlockFixture(std.testing.allocator);
    defer Support.freeRawDictionaryBlockFixture(std.testing.allocator, &fixture);
    var source = common.TrackingSource{ .bytes = fixture.frame };
    const frame = try common.parseFrame(&source);
    const block = try source_frame.parseFirstBlock(frame);
    var prepare_state = fixture.state;
    var scratch: [common.source_huffman.maximum_scratch_len]u8 = undefined;
    var prepared = try compressed_block.prepare(
        Support.HuffmanCodec,
        Support.SequenceCodec,
        block,
        &prepare_state,
        &scratch,
    );
    const window: usize = @intCast(frame.header.window_size);
    const history_storage = try std.testing.allocator.alloc(u8, window + 1);
    defer std.testing.allocator.free(history_storage);
    const staging = try std.testing.allocator.alloc(u8, frame.header.block_size_max);
    defer std.testing.allocator.free(staging);
    var literal_page: [9]u8 = undefined;
    var sequence_page: [9]u8 = undefined;

    inline for (std.meta.tags(AliasTarget)) |target| {
        var state = fixture.state;
        var history = try common.history_workspace.Binding.init(history_storage);
        try history.beginFrame(frame.header.window_size, 1);
        const dictionary: []const u8 = switch (target) {
            .history_storage => history.storage[0..1],
            .staging => staging[0..1],
            .literal_page => literal_page[0..1],
            .sequence_page => sequence_page[0..1],
            .prepared => std.mem.asBytes(&prepared)[0..1],
            .state => std.mem.asBytes(&state)[0..1],
            .history_binding => std.mem.asBytes(&history)[0..1],
        };
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
                dictionary,
                staging,
                &literal_page,
                &sequence_page,
                common.limits(frame),
            ),
        );
        try std.testing.expectEqual(calls_before, source.calls);
    }
}

pub fn contracts(comptime Support: type) !void {
    try exactCapacityAndShortRejection(Support);
    try visibilityAndCrossSegmentMatch();
    try dictionaryAliasesFailBeforeReads(Support);
}
