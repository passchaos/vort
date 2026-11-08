const std = @import("std");
const common = @import("common.zig");
const source_sequence_cursor = common.source_sequence_cursor;

fn executeFixture(
    comptime Support: type,
    fixture: *const Support.OwnedFixture,
    oracle: *const Support.OwnedOracle,
    page_len: usize,
) !void {
    try std.testing.expectEqual(fixture.sequence_count, oracle.steps.len);
    var source = common.TrackingSource{ .bytes = fixture.bytes };
    const prepared = try common.prepareFixture(Support, fixture, &source, page_len);
    const prepared_before = prepared;
    const previous_before = fixture.previous_tables;
    var page_storage: [19]u8 = @splat(0x73);
    page_storage[0] = 0x39;
    page_storage[page_len + 1] = 0xc6;
    var cursor = try source_sequence_cursor.init(
        Support.Codec,
        &prepared,
        fixture.initial_repeated_offsets,
        page_storage[1 .. page_len + 1],
    );

    const initial = cursor.snapshot();
    try std.testing.expectEqual(@as(usize, 0), initial.decoded);
    try std.testing.expectEqual(fixture.sequence_count, initial.remaining);
    try std.testing.expect(!initial.finished);
    try std.testing.expectError(error.InvalidStreamState, cursor.finalRepeatedOffsets());

    for (oracle.steps, 0..) |step, index| {
        const value = (try cursor.next()) orelse return error.TestUnexpectedResult;
        try common.expectStep(
            step,
            value,
            cursor.snapshot(),
            index + 1,
            oracle.steps.len - index - 1,
        );
        if (index + 1 != oracle.steps.len)
            try std.testing.expectError(error.InvalidStreamState, cursor.finalRepeatedOffsets());
    }
    try std.testing.expect(cursor.isFinished());
    try std.testing.expectEqual(@as(usize, 0), cursor.remaining());
    try std.testing.expect((try cursor.next()) == null);
    try std.testing.expect((try cursor.next()) == null);
    try std.testing.expectEqual(
        oracle.final_repeated_offsets,
        try cursor.finalRepeatedOffsets(),
    );
    try std.testing.expectEqual(page_len, cursor.snapshot().reader.page_capacity);
    try std.testing.expect(source.max_requested <= page_len);
    try common.expectPageCanaries(&page_storage, page_len);

    // Preparation is a pending table candidate. Executing the cursor neither
    // mutates it nor commits it into the caller's cross-block state.
    try Support.expectTablesEqual(&prepared_before.tables, &prepared.tables);
    if (previous_before) |*expected| {
        try Support.expectTablesEqual(expected, &fixture.previous_tables.?);
    } else try std.testing.expect(fixture.previous_tables == null);
}

fn realCorpora(comptime Support: type) !void {
    const Case = struct {
        corpus: Support.Corpus,
        count: usize,
        wire_modes: [3]Support.Mode,
        resolved_modes: [3]Support.ResolvedMode,
    };
    const cases = [_]Case{
        .{
            .corpus = .libzstd_numbered_json_block0,
            .count = 39,
            .wire_modes = .{ .predefined, .compressed, .predefined },
            .resolved_modes = .{ .predefined, .compressed, .predefined },
        },
        .{
            .corpus = .decodecorpus_block0,
            .count = 26,
            .wire_modes = .{ .predefined, .predefined, .predefined },
            .resolved_modes = .{ .predefined, .predefined, .predefined },
        },
        .{
            .corpus = .decodecorpus_block1,
            .count = 3,
            .wire_modes = .{ .repeat, .compressed, .compressed },
            .resolved_modes = .{ .predefined, .compressed, .compressed },
        },
        .{
            .corpus = .decodecorpus_block2,
            .count = 16,
            .wire_modes = .{ .compressed, .compressed, .predefined },
            .resolved_modes = .{ .compressed, .compressed, .predefined },
        },
    };
    var observed_wire: u64 = 0;
    for (cases) |case| {
        var fixture = (try Support.loadSequenceFixture(
            std.testing.allocator,
            case.corpus,
        )) orelse return error.TestUnexpectedResult;
        defer Support.freeSequenceFixture(std.testing.allocator, &fixture);
        try std.testing.expectEqual(case.count, fixture.sequence_count);
        try std.testing.expectEqual(case.wire_modes, fixture.wire_modes);
        try std.testing.expectEqual(case.resolved_modes, fixture.resolved_modes);
        observed_wire |= @as(u64, 1) << common.wireTupleIndex(Support, fixture.wire_modes);
        var oracle = try Support.decodeSequenceSliceOracle(std.testing.allocator, &fixture);
        defer Support.freeSequenceSliceOracle(std.testing.allocator, &oracle);
        inline for (.{ 9, 10, 17 }) |page_len|
            try executeFixture(Support, &fixture, &oracle, page_len);
    }
    // This is the fixed real-corpus subset. The metadata suite separately
    // owns and preserves the complete 64-tuple wire mask.
    const expected_wire = (@as(u64, 1) << 0) |
        (@as(u64, 1) << 8) |
        (@as(u64, 1) << 40) |
        (@as(u64, 1) << 58);
    try std.testing.expectEqual(expected_wire, observed_wire);
}

fn concreteResolvedCoverage(comptime Support: type) !void {
    var mask: u32 = 0;
    for (0..3) |ll_index| {
        for (0..3) |of_index| {
            for (0..3) |ml_index| {
                const modes = [3]Support.ResolvedMode{
                    @enumFromInt(ll_index),
                    @enumFromInt(of_index),
                    @enumFromInt(ml_index),
                };
                var fixture = try Support.emitResolvedFixture(std.testing.allocator, modes);
                defer Support.freeSequenceFixture(std.testing.allocator, &fixture);
                try std.testing.expectEqual(modes, fixture.resolved_modes);
                try std.testing.expect(fixture.sequence_count >= 2);
                var oracle = try Support.decodeSequenceSliceOracle(std.testing.allocator, &fixture);
                defer Support.freeSequenceSliceOracle(std.testing.allocator, &oracle);
                try executeFixture(Support, &fixture, &oracle, 9);
                mask |= @as(u32, 1) << common.resolvedTupleIndex(Support, modes);
            }
        }
    }
    try std.testing.expectEqual(@as(u32, 0x07ff_ffff), mask);
}

fn optionalTrainedDictionaryRepeat(comptime Support: type) !void {
    const optional = try Support.loadSequenceFixture(
        std.testing.allocator,
        .trained_dictionary_repeat,
    );
    if (optional) |value| {
        var fixture = value;
        defer Support.freeSequenceFixture(std.testing.allocator, &fixture);
        var has_repeat = false;
        for (fixture.wire_modes) |mode| has_repeat = has_repeat or mode == .repeat;
        try std.testing.expect(has_repeat);
        var oracle = try Support.decodeSequenceSliceOracle(std.testing.allocator, &fixture);
        defer Support.freeSequenceSliceOracle(std.testing.allocator, &oracle);
        try executeFixture(Support, &fixture, &oracle, 9);
    }
}

pub fn contracts(comptime Support: type) !void {
    try realCorpora(Support);
    try concreteResolvedCoverage(Support);
    try optionalTrainedDictionaryRepeat(Support);
}
