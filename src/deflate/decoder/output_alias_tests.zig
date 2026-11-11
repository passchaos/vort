//! Public caller-output borrow contracts, including corruption across blocks.
const std = @import("std");
const testing = std.testing;

const Mode = enum { auto, dictionary, fixed, stored, sync };
const Fixture = struct {
    raw: []const u8,
    plain: []const u8,
    dictionary: []const u8 = "",
};

const stored = Fixture{
    .raw = &.{ 0x01, 0x04, 0x00, 0xfb, 0xff, 'a', 'b', 'c', 'd' },
    .plain = "abcd",
};
const fixed = Fixture{
    .raw = &.{ 0x4b, 0x4c, 0x4a, 0x4e, 0x49, 0x4d, 0x03, 0x00 },
    .plain = "abcdef",
};
const dynamic = Fixture{
    .raw = &.{
        0x3d, 0xc6, 0x39, 0x11, 0x00, 0x00, 0x0c, 0x02,
        0x30, 0x2b, 0xb5, 0x52, 0x1e, 0xff, 0x96, 0x38,
        0x16, 0x96, 0x5c, 0x1e, 0x94, 0xcb, 0x6d, 0x01,
    },
    .plain = "ABCDEABCD ABCDEABCD",
};
const with_dictionary = Fixture{
    .raw = &.{ 0x8b, 0x48, 0x44, 0x13, 0x00, 0x00 },
    .plain = "Xabcdefghijklmnop",
    .dictionary = "abcdefghijklmnop",
};
const synced = Fixture{
    .raw = "broken:\x00\x00\xff\xff" ++ stored.raw,
    .plain = stored.plain,
};

fn decode(
    comptime D: type,
    comptime mode: Mode,
    input: []const u8,
    dictionary: []const u8,
    output: []u8,
) !D.DecodeResult {
    return switch (mode) {
        .auto => D.decodeRawAuto(input, output),
        .dictionary => D.decodeRawAutoWithDictionary(input, dictionary, output),
        .fixed => D.decodeRawFixed(input, output),
        .stored => D.decodeRawStored(input, output),
        .sync => blk: {
            const result = try D.decodeRawDeflateAfterSync(input, output);
            break :blk .{ .input_read = result.input_read, .output_written = result.output_written };
        },
    };
}

fn expectDecoded(fixture: Fixture, result: anytype, output: []const u8) !void {
    try testing.expectEqual(fixture.raw.len, result.input_read);
    try testing.expectEqual(fixture.plain.len, result.output_written);
    try testing.expectEqualSlices(u8, fixture.plain, output[0..result.output_written]);
}

fn inputOverlapMatrix(comptime D: type, comptime mode: Mode, fixture: Fixture) !void {
    const input_start = 64;
    const input_end = input_start + fixture.raw.len;
    const Range = struct { start: usize, len: usize };
    const ranges = [_]Range{
        .{ .start = input_start, .len = fixture.raw.len }, // Exact range.
        .{ .start = input_start - 2, .len = 4 }, // Overlap input prefix.
        .{ .start = input_end - 2, .len = 4 }, // Overlap input suffix.
        .{ .start = input_start + 1, .len = 1 }, // Input contains output.
        .{ .start = input_start - 1, .len = fixture.raw.len + 2 }, // Output contains input.
        // Every byte that decoding would write is disjoint; unused output tail overlaps.
        .{ .start = input_start - fixture.plain.len - 1, .len = fixture.plain.len + 2 },
    };
    for (ranges) |range| {
        var backing: [160]u8 = @splat(0xa5);
        @memcpy(backing[input_start..input_end], fixture.raw);
        const before = backing;
        try testing.expectError(error.InvalidBlockPlan, decode(
            D,
            mode,
            backing[input_start..input_end],
            fixture.dictionary,
            backing[range.start..][0..range.len],
        ));
        try testing.expectEqualSlices(u8, &before, &backing);

        // The rejected borrow leaves the same input available for independent retry.
        var independent: [160]u8 = @splat(0xa5);
        const result = try decode(D, mode, backing[input_start..input_end], fixture.dictionary, &independent);
        try expectDecoded(fixture, result, &independent);
        try testing.expectEqualSlices(u8, &before, &backing);
        for (independent[result.output_written..]) |byte| try testing.expectEqual(@as(u8, 0xa5), byte);
    }

    // Half-open ranges that meet at either endpoint are valid borrows.
    for ([_]usize{ input_start - fixture.plain.len, input_end }) |output_start| {
        var backing: [160]u8 = @splat(0xa5);
        @memcpy(backing[input_start..input_end], fixture.raw);
        const output = backing[output_start..][0..fixture.plain.len];
        const result = try decode(D, mode, backing[input_start..input_end], fixture.dictionary, output);
        try expectDecoded(fixture, result, output);
        try testing.expectEqualSlices(u8, fixture.raw, backing[input_start..input_end]);
    }

    // The caller lends the entire input, including bytes beyond the first stream.
    var backing: [160]u8 = @splat(0xa5);
    @memcpy(backing[input_start..input_end], fixture.raw);
    const before = backing;
    const input = backing[input_start .. input_end + fixture.plain.len];
    try testing.expectError(error.InvalidBlockPlan, decode(D, mode, input, fixture.dictionary, backing[input_end..][0..fixture.plain.len]));
    try testing.expectEqualSlices(u8, &before, &backing);
    var independent: [160]u8 = undefined;
    const result = try decode(D, mode, input, fixture.dictionary, &independent);
    try expectDecoded(fixture, result, &independent);
}

fn dictionaryOverlapMatrix(comptime D: type) !void {
    const dictionary_start = 64;
    const dictionary_end = dictionary_start + with_dictionary.dictionary.len;
    const Range = struct { start: usize, len: usize };
    const ranges = [_]Range{
        .{ .start = dictionary_start, .len = with_dictionary.plain.len },
        .{ .start = dictionary_start, .len = with_dictionary.dictionary.len },
        .{ .start = dictionary_start - with_dictionary.plain.len + 1, .len = with_dictionary.plain.len },
        .{ .start = dictionary_end - 1, .len = with_dictionary.plain.len },
        .{ .start = dictionary_start + 1, .len = 1 },
        .{ .start = dictionary_start - 1, .len = with_dictionary.dictionary.len + 2 },
        .{ .start = dictionary_start - with_dictionary.plain.len - 1, .len = with_dictionary.plain.len + 2 },
    };
    for (ranges) |range| {
        var backing: [160]u8 = @splat(0xa5);
        @memcpy(backing[dictionary_start..dictionary_end], with_dictionary.dictionary);
        const before = backing;
        const dictionary = backing[dictionary_start..dictionary_end];
        try testing.expectError(error.InvalidBlockPlan, D.decodeRawAutoWithDictionary(
            with_dictionary.raw,
            dictionary,
            backing[range.start..][0..range.len],
        ));
        try testing.expectEqualSlices(u8, &before, &backing);
        var independent: [17]u8 = undefined;
        const result = try D.decodeRawAutoWithDictionary(with_dictionary.raw, dictionary, &independent);
        try expectDecoded(with_dictionary, result, &independent);
        try testing.expectEqualSlices(u8, &before, &backing);
    }
    for ([_]usize{ dictionary_start - with_dictionary.plain.len, dictionary_end }) |output_start| {
        var backing: [160]u8 = @splat(0xa5);
        @memcpy(backing[dictionary_start..dictionary_end], with_dictionary.dictionary);
        const output = backing[output_start..][0..with_dictionary.plain.len];
        const result = try D.decodeRawAutoWithDictionary(with_dictionary.raw, backing[dictionary_start..dictionary_end], output);
        try expectDecoded(with_dictionary, result, output);
        try testing.expectEqualSlices(u8, with_dictionary.dictionary, backing[dictionary_start..dictionary_end]);
    }
}

fn sharedReadBorrows(comptime D: type) !void {
    // Compressed input and dictionary are both read borrows and may share storage.
    inline for (.{ stored, fixed, dynamic }) |fixture| {
        var backing: [64]u8 = @splat(0xa5);
        @memcpy(backing[8..][0..fixture.raw.len], fixture.raw);
        const before = backing;
        const input = backing[8..][0..fixture.raw.len];
        for ([_][]const u8{ input, backing[0..16], backing[9..][0..fixture.raw.len] }) |dictionary| {
            var output: [64]u8 = undefined;
            const result = try D.decodeRawAutoWithDictionary(input, dictionary, &output);
            try expectDecoded(fixture, result, &output);
            try testing.expectEqualSlices(u8, &before, &backing);
        }
    }

    // A match actually consumes dictionary bytes that also contain compressed input.
    var shared: [18]u8 = undefined;
    @memcpy(shared[0..12], "abcdefghijkl");
    @memcpy(shared[12..18], with_dictionary.raw);
    const before = shared;
    var output: [17]u8 = undefined;
    const result = try D.decodeRawAutoWithDictionary(shared[12..18], shared[0..16], &output);
    try testing.expectEqual(@as(usize, 6), result.input_read);
    try testing.expectEqual(@as(usize, 17), result.output_written);
    try testing.expectEqualSlices(u8, "Xabcdefghijkl\x8b\x48\x44\x13", &output);
    try testing.expectEqualSlices(u8, &before, &shared);

    // Empty dictionary slices impose no borrow even when their pointer is in output.
    const empty_dictionary = output[1..1];
    const fixed_result = try D.decodeRawAutoWithDictionary(fixed.raw, empty_dictionary, &output);
    try expectDecoded(fixed, fixed_result, &output);
}

fn zeroOutput(comptime D: type, comptime mode: Mode, fixture: Fixture) !void {
    var backing: [64]u8 = @splat(0xa5);
    @memcpy(backing[0..fixture.raw.len], fixture.raw);
    const before = backing;
    try testing.expectError(error.OutputTooSmall, decode(D, mode, backing[0..fixture.raw.len], fixture.dictionary, backing[1..1]));
    try testing.expectEqualSlices(u8, &before, &backing);
}

fn emptyStreams(comptime D: type) !void {
    const empty_fixed = Fixture{ .raw = &.{ 0x03, 0x00 }, .plain = "" };
    const empty_stored = Fixture{ .raw = &.{ 0x01, 0x00, 0x00, 0xff, 0xff }, .plain = "" };
    const empty_synced = Fixture{ .raw = "broken:\x00\x00\xff\xff\x03\x00", .plain = "" };
    inline for (.{ Mode.auto, Mode.dictionary, Mode.fixed, Mode.stored, Mode.sync }) |mode| {
        const fixture = switch (mode) {
            .stored => empty_stored,
            .sync => empty_synced,
            else => empty_fixed,
        };
        var backing: [32]u8 = @splat(0xa5);
        @memcpy(backing[0..fixture.raw.len], fixture.raw);
        const before = backing;
        const result = try decode(D, mode, backing[0..fixture.raw.len], backing[0..fixture.raw.len], backing[1..1]);
        try expectDecoded(fixture, result, backing[1..1]);
        try testing.expectEqualSlices(u8, &before, &backing);
        const expected_error = if (mode == .sync) error.DeflateSyncPointNotFound else error.TruncatedFrame;
        try testing.expectError(expected_error, decode(D, mode, backing[0..0], backing[0..fixture.raw.len], backing[1..1]));
        try testing.expectEqualSlices(u8, &before, &backing);
    }
    // A zero-output dictionary match fixture must keep OutputTooSmall as well.
    var dictionary: [16]u8 = undefined;
    @memcpy(&dictionary, with_dictionary.dictionary);
    const before = dictionary;
    try testing.expectError(error.OutputTooSmall, D.decodeRawAutoWithDictionary(with_dictionary.raw, &dictionary, dictionary[0..0]));
    try testing.expectEqualSlices(u8, &before, &dictionary);
}

fn futureStoredPayload(comptime D: type) !void {
    const fixture = Fixture{
        .raw = &.{ 0x00, 0x03, 0x00, 0xfc, 0xff, 'a', 'b', 'c', 0x01, 0x03, 0x00, 0xfc, 0xff, 'd', 'e', 'f' },
        .plain = "abcdef",
    };
    inline for (.{ Mode.auto, Mode.dictionary, Mode.stored }) |mode| {
        var backing: [19]u8 = @splat(0xa5);
        @memcpy(backing[0..16], fixture.raw);
        const before = backing;
        // Both individual copies would be disjoint, but the first overwrites a future payload.
        try testing.expectError(error.InvalidBlockPlan, decode(D, mode, backing[0..16], "", backing[13..19]));
        try testing.expectEqualSlices(u8, &before, &backing);
        var independent: [6]u8 = undefined;
        const result = try decode(D, mode, backing[0..16], "", &independent);
        try expectDecoded(fixture, result, &independent);
    }
}

fn syncPrefix(comptime D: type) !void {
    var backing: [32]u8 = @splat(0xa5);
    @memcpy(backing[0..synced.raw.len], synced.raw);
    const before = backing;
    // These output bytes precede resume_offset and never overlap the resumed raw slice.
    try testing.expectError(error.InvalidBlockPlan, D.decodeRawDeflateAfterSync(backing[0..synced.raw.len], backing[0..4]));
    try testing.expectEqualSlices(u8, &before, &backing);
    var independent: [4]u8 = undefined;
    const result = try D.decodeRawDeflateAfterSync(backing[0..synced.raw.len], &independent);
    try expectDecoded(synced, result, &independent);
    try testing.expectEqual(@as(usize, 7), result.sync_point.marker_offset);
    try testing.expectEqual(@as(usize, 11), result.sync_point.resume_offset);
    try testing.expectEqualSlices(u8, &before, &backing);

    // Sync-point discovery keeps its established error when no marker exists.
    var no_marker = [_]u8{ 'a', 'b', 'c', 'd' };
    const no_marker_before = no_marker;
    try testing.expectError(error.DeflateSyncPointNotFound, D.decodeRawDeflateAfterSync(&no_marker, &no_marker));
    try testing.expectEqualSlices(u8, &no_marker_before, &no_marker);
}

fn trailingDataControls(comptime D: type) !void {
    inline for (.{ stored, fixed, dynamic }) |fixture| {
        var input: [64]u8 = @splat(0xa5);
        @memcpy(input[0..fixture.raw.len], fixture.raw);
        @memcpy(input[fixture.raw.len..][0..4], "TAIL");
        const borrowed = input[0 .. fixture.raw.len + 4];
        const before = input;
        inline for (.{ Mode.auto, Mode.dictionary }) |mode| {
            var output: [64]u8 = undefined;
            const result = try decode(D, mode, borrowed, "", &output);
            try expectDecoded(fixture, result, &output);
        }
        try testing.expectError(error.TrailingData, D.decodeRawAutoAlloc(testing.allocator, borrowed));
        try testing.expectError(error.TrailingData, D.decodeRawAutoAllocWithDictionary(testing.allocator, borrowed, ""));
        if (fixture.raw[0] & 6 == 0) {
            var output: [64]u8 = undefined;
            try expectDecoded(fixture, try D.decodeRawStored(borrowed, &output), &output);
            try testing.expectError(error.TrailingData, D.decodeRawStoredAlloc(testing.allocator, borrowed));
        } else if (fixture.raw[0] & 6 == 2) {
            var output: [64]u8 = undefined;
            try expectDecoded(fixture, try D.decodeRawFixed(borrowed, &output), &output);
            try testing.expectError(error.TrailingData, D.decodeRawFixedAllocStrict(testing.allocator, borrowed));
        }
        try testing.expectEqualSlices(u8, &before, &input);
    }
}

pub fn contracts(comptime D: type) !void {
    inline for (.{ Mode.auto, Mode.dictionary }) |mode| {
        inline for (.{ stored, fixed, dynamic }) |fixture| {
            try inputOverlapMatrix(D, mode, fixture);
            try zeroOutput(D, mode, fixture);
        }
    }
    try inputOverlapMatrix(D, .dictionary, with_dictionary);
    try inputOverlapMatrix(D, .fixed, fixed);
    try inputOverlapMatrix(D, .stored, stored);
    try inputOverlapMatrix(D, .sync, synced);
    try zeroOutput(D, .dictionary, with_dictionary);
    try zeroOutput(D, .fixed, fixed);
    try zeroOutput(D, .stored, stored);
    try zeroOutput(D, .sync, synced);
    try dictionaryOverlapMatrix(D);
    try sharedReadBorrows(D);
    try emptyStreams(D);
    try futureStoredPayload(D);
    try syncPrefix(D);
    try trailingDataControls(D);
}
