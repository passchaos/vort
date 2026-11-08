const std = @import("std");
const common = @import("common.zig");
const source_sequence_cursor = common.source_sequence_cursor;

fn loadNumbered(comptime Support: type) !Support.OwnedFixture {
    return (try Support.loadSequenceFixture(
        std.testing.allocator,
        .libzstd_numbered_json_block0,
    )) orelse error.TestUnexpectedResult;
}

fn pageAndCountContracts(comptime Support: type) !void {
    var fixture = try loadNumbered(Support);
    defer Support.freeSequenceFixture(std.testing.allocator, &fixture);
    var source = common.TrackingSource{ .bytes = fixture.bytes };
    var prepared = try common.prepareFixture(Support, &fixture, &source, 9);
    var short_page: [8]u8 = undefined;
    const calls_before = source.calls;
    try std.testing.expectError(
        error.OutputTooSmall,
        source_sequence_cursor.init(
            Support.Codec,
            &prepared,
            fixture.initial_repeated_offsets,
            &short_page,
        ),
    );
    try std.testing.expectEqual(calls_before, source.calls);

    prepared.sequence_count = 0;
    var page: [9]u8 = undefined;
    try std.testing.expectError(
        error.CorruptFrame,
        source_sequence_cursor.init(
            Support.Codec,
            &prepared,
            fixture.initial_repeated_offsets,
            &page,
        ),
    );
    try std.testing.expectEqual(calls_before, source.calls);
}

fn zeroMarker(comptime Support: type) !void {
    var fixture = try loadNumbered(Support);
    defer Support.freeSequenceFixture(std.testing.allocator, &fixture);
    const bytes = try std.testing.allocator.dupe(u8, fixture.bytes);
    defer std.testing.allocator.free(bytes);
    bytes[bytes.len - 1] = 0;
    var damaged = fixture;
    damaged.bytes = bytes;
    var source = common.TrackingSource{ .bytes = bytes };
    const prepared = try common.prepareFixture(Support, &damaged, &source, 9);
    var page: [9]u8 = undefined;
    try std.testing.expectError(
        error.CorruptFrame,
        source_sequence_cursor.init(
            Support.Codec,
            &prepared,
            damaged.initial_repeated_offsets,
            &page,
        ),
    );
}

fn extraBitsAtExactEnd(comptime Support: type) !void {
    var fixture = try loadNumbered(Support);
    defer Support.freeSequenceFixture(std.testing.allocator, &fixture);
    var oracle = try Support.decodeSequenceSliceOracle(std.testing.allocator, &fixture);
    defer Support.freeSequenceSliceOracle(std.testing.allocator, &oracle);

    var original_source = common.TrackingSource{ .bytes = fixture.bytes };
    const original = try common.prepareFixture(Support, &fixture, &original_source, 9);
    const bitstream_offset: usize = @intCast(original.tables_end);
    const bytes = try std.testing.allocator.alloc(u8, fixture.bytes.len + 1);
    defer std.testing.allocator.free(bytes);
    @memcpy(bytes[0..bitstream_offset], fixture.bytes[0..bitstream_offset]);
    bytes[bitstream_offset] = 0x5a;
    @memcpy(bytes[bitstream_offset + 1 ..], fixture.bytes[bitstream_offset..]);
    var damaged = fixture;
    damaged.bytes = bytes;
    var source = common.TrackingSource{ .bytes = bytes };
    const prepared = try common.prepareFixture(Support, &damaged, &source, 9);
    var page: [9]u8 = undefined;
    var cursor = try source_sequence_cursor.init(
        Support.Codec,
        &prepared,
        damaged.initial_repeated_offsets,
        &page,
    );
    for (oracle.steps[0 .. oracle.steps.len - 1], 0..) |step, index| {
        const value = (try cursor.next()) orelse return error.TestUnexpectedResult;
        try common.expectSequenceEqual(step.sequence, value);
        const snapshot = cursor.snapshot();
        try std.testing.expectEqual(step.ll_state, snapshot.ll_state);
        try std.testing.expectEqual(step.of_state, snapshot.of_state);
        try std.testing.expectEqual(step.ml_state, snapshot.ml_state);
        try std.testing.expectEqual(step.repeated_offsets, snapshot.repeated_offsets);
        try std.testing.expectEqual(step.remaining_bits + 8, snapshot.reader_remaining_bits);
        try std.testing.expectEqual(index + 1, snapshot.decoded);
    }
    const before = cursor.snapshot();
    try std.testing.expectError(error.CorruptFrame, cursor.next());
    try common.expectSemanticSnapshotEqual(before, cursor.snapshot());
    try std.testing.expectError(error.CorruptFrame, cursor.next());
    try common.expectSemanticSnapshotEqual(before, cursor.snapshot());
    try std.testing.expectError(error.InvalidStreamState, cursor.finalRepeatedOffsets());
}

fn truncatedDescendingStream(comptime Support: type) !void {
    var fixture = try loadNumbered(Support);
    defer Support.freeSequenceFixture(std.testing.allocator, &fixture);
    var oracle = try Support.decodeSequenceSliceOracle(std.testing.allocator, &fixture);
    defer Support.freeSequenceSliceOracle(std.testing.allocator, &oracle);

    var original_source = common.TrackingSource{ .bytes = fixture.bytes };
    const original = try common.prepareFixture(Support, &fixture, &original_source, 9);
    const bitstream_offset: usize = @intCast(original.tables_end);
    try std.testing.expect(fixture.bytes.len - bitstream_offset > 1);
    const bytes = try std.testing.allocator.alloc(u8, fixture.bytes.len - 1);
    defer std.testing.allocator.free(bytes);
    @memcpy(bytes[0..bitstream_offset], fixture.bytes[0..bitstream_offset]);
    @memcpy(bytes[bitstream_offset..], fixture.bytes[bitstream_offset + 1 ..]);
    var damaged = fixture;
    damaged.bytes = bytes;
    var source = common.TrackingSource{ .bytes = bytes };
    const prepared = try common.prepareFixture(Support, &damaged, &source, 9);
    var page: [9]u8 = undefined;
    var cursor = try source_sequence_cursor.init(
        Support.Codec,
        &prepared,
        damaged.initial_repeated_offsets,
        &page,
    );
    var index: usize = 0;
    var observed = false;
    while (index != oracle.steps.len) {
        const before = cursor.snapshot();
        const result = cursor.next();
        if (result) |optional| {
            const value = optional orelse return error.TestUnexpectedResult;
            try common.expectSequenceEqual(oracle.steps[index].sequence, value);
            const snapshot = cursor.snapshot();
            try std.testing.expectEqual(oracle.steps[index].ll_state, snapshot.ll_state);
            try std.testing.expectEqual(oracle.steps[index].of_state, snapshot.of_state);
            try std.testing.expectEqual(oracle.steps[index].ml_state, snapshot.ml_state);
            try std.testing.expectEqual(
                oracle.steps[index].repeated_offsets,
                snapshot.repeated_offsets,
            );
            index += 1;
        } else |actual_error| {
            try std.testing.expect(actual_error == error.TruncatedFrame);
            try common.expectSemanticSnapshotEqual(before, cursor.snapshot());
            observed = true;
            break;
        }
    }
    try std.testing.expect(observed);
    try std.testing.expectError(error.InvalidStreamState, cursor.finalRepeatedOffsets());
}

pub fn contracts(comptime Support: type) !void {
    try pageAndCountContracts(Support);
    try zeroMarker(Support);
    try extraBitsAtExactEnd(Support);
    try truncatedDescendingStream(Support);
}
