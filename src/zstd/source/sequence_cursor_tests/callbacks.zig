const std = @import("std");
const common = @import("common.zig");
const source_input = common.source_input;
const source_sequence_cursor = common.source_sequence_cursor;

fn fixtureAndOracle(comptime Support: type) !struct {
    fixture: Support.OwnedFixture,
    oracle: Support.OwnedOracle,
} {
    var fixture = (try Support.loadSequenceFixture(
        std.testing.allocator,
        .libzstd_numbered_json_block0,
    )) orelse return error.TestUnexpectedResult;
    errdefer Support.freeSequenceFixture(std.testing.allocator, &fixture);
    const oracle = try Support.decodeSequenceSliceOracle(std.testing.allocator, &fixture);
    return .{ .fixture = fixture, .oracle = oracle };
}

fn initFailures(comptime Support: type) !void {
    inline for (.{ common.Mode.zero, common.Mode.excessive, common.Mode.fail }) |mode| {
        var pair = try fixtureAndOracle(Support);
        defer Support.freeSequenceSliceOracle(std.testing.allocator, &pair.oracle);
        defer Support.freeSequenceFixture(std.testing.allocator, &pair.fixture);
        var source = common.TrackingSource{ .bytes = pair.fixture.bytes };
        const prepared = try common.prepareFixture(Support, &pair.fixture, &source, 9);
        var page: [9]u8 = undefined;
        source.mode = mode;
        source.fault_call = source.calls + 1;
        try std.testing.expectError(
            common.expectedError(mode),
            source_sequence_cursor.init(
                Support.Codec,
                &prepared,
                pair.fixture.initial_repeated_offsets,
                &page,
            ),
        );
        source.clearFault();
        var retry = try source_sequence_cursor.init(
            Support.Codec,
            &prepared,
            pair.fixture.initial_repeated_offsets,
            &page,
        );
        const first = (try retry.next()) orelse return error.TestUnexpectedResult;
        try common.expectStep(
            pair.oracle.steps[0],
            first,
            retry.snapshot(),
            1,
            pair.fixture.sequence_count - 1,
        );
    }
}

fn descendingRefillTransactions(comptime Support: type) !void {
    inline for (.{ common.Mode.zero, common.Mode.excessive, common.Mode.fail }) |mode| {
        var pair = try fixtureAndOracle(Support);
        defer Support.freeSequenceSliceOracle(std.testing.allocator, &pair.oracle);
        defer Support.freeSequenceFixture(std.testing.allocator, &pair.fixture);
        var source = common.TrackingSource{ .bytes = pair.fixture.bytes };
        const prepared = try common.prepareFixture(Support, &pair.fixture, &source, 9);
        var page_storage: [11]u8 = @splat(0x73);
        page_storage[0] = 0x39;
        page_storage[10] = 0xc6;
        var cursor = try source_sequence_cursor.init(
            Support.Codec,
            &prepared,
            pair.fixture.initial_repeated_offsets,
            page_storage[1..10],
        );

        var index: usize = 0;
        var observed_failure = false;
        while (index != pair.oracle.steps.len) {
            const before = cursor.snapshot();
            source.mode = mode;
            source.fault_call = source.calls + 1;
            const result = cursor.next();
            if (result) |optional| {
                const value = optional orelse return error.TestUnexpectedResult;
                try common.expectStep(
                    pair.oracle.steps[index],
                    value,
                    cursor.snapshot(),
                    index + 1,
                    pair.oracle.steps.len - index - 1,
                );
                index += 1;
            } else |actual_error| {
                try std.testing.expect(actual_error == common.expectedError(mode));
                try common.expectSemanticSnapshotEqual(before, cursor.snapshot());
                source.clearFault();
                const retry = (try cursor.next()) orelse return error.TestUnexpectedResult;
                try common.expectStep(
                    pair.oracle.steps[index],
                    retry,
                    cursor.snapshot(),
                    index + 1,
                    pair.oracle.steps.len - index - 1,
                );
                index += 1;
                observed_failure = true;
                break;
            }
        }
        try std.testing.expect(observed_failure);
        source.clearFault();
        while (index != pair.oracle.steps.len) : (index += 1) {
            const value = (try cursor.next()) orelse return error.TestUnexpectedResult;
            try common.expectStep(
                pair.oracle.steps[index],
                value,
                cursor.snapshot(),
                index + 1,
                pair.oracle.steps.len - index - 1,
            );
        }
        try std.testing.expectEqual(
            pair.oracle.final_repeated_offsets,
            try cursor.finalRepeatedOffsets(),
        );
        try std.testing.expect(cursor.snapshot().reader.descending_loads != 0);
        try common.expectPageCanaries(&page_storage, 9);
    }
}

fn wideRangeIsolation(comptime Support: type) !void {
    var pair = try fixtureAndOracle(Support);
    defer Support.freeSequenceSliceOracle(std.testing.allocator, &pair.oracle);
    defer Support.freeSequenceFixture(std.testing.allocator, &pair.fixture);

    const backing = try std.testing.allocator.alloc(u8, pair.fixture.bytes.len + 4);
    defer std.testing.allocator.free(backing);
    @memset(backing, 0xa5);
    @memcpy(backing[2 .. backing.len - 2], pair.fixture.bytes);
    const base = @as(u64, std.math.maxInt(u32)) + 0x12_345;
    const forbidden = [_]common.Span{
        .{ .offset = 0, .len = 2 },
        .{ .offset = backing.len - 2, .len = 2 },
    };
    var source = common.TrackingSource{
        .bytes = backing,
        .base_offset = base,
        .forbidden = &forbidden,
    };
    const range = try source_input.Range.init(
        source.source(9),
        base + 2,
        @intCast(pair.fixture.bytes.len),
    );
    const prepared = try common.prepareRange(Support, &pair.fixture, range);
    var page_storage: [11]u8 = @splat(0x73);
    page_storage[0] = 0x39;
    page_storage[10] = 0xc6;
    var cursor = try source_sequence_cursor.init(
        Support.Codec,
        &prepared,
        pair.fixture.initial_repeated_offsets,
        page_storage[1..10],
    );
    for (pair.oracle.steps, 0..) |step, index| {
        const value = (try cursor.next()) orelse return error.TestUnexpectedResult;
        try common.expectStep(
            step,
            value,
            cursor.snapshot(),
            index + 1,
            pair.oracle.steps.len - index - 1,
        );
    }
    try std.testing.expect(!source.forbidden_read);
    try std.testing.expect(source.min_observed_offset.? > std.math.maxInt(u32));
    try std.testing.expect(source.max_requested <= 9);
    try common.expectPageCanaries(&page_storage, 9);
}

pub fn contracts(comptime Support: type) !void {
    try initFailures(Support);
    try descendingRefillTransactions(Support);
    try wideRangeIsolation(Support);
}
