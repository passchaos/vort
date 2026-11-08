const std = @import("std");
const common = @import("common.zig");
const stream_cursor = common.stream_cursor;
const history_workspace = common.history_workspace;

const SkippableObservation = struct {
    id: u4,
    payload_len: u32,
    payload_offset: u64,
};

fn oracle(comptime Support: type, bytes: []const u8) ![]u8 {
    return Support.decodeFrameOracle(std.testing.allocator, bytes);
}

fn runStream(
    comptime Support: type,
    bytes: []const u8,
    format: stream_cursor.FrameFormat,
    forbidden: []const common.Span,
    page_len: usize,
    chunk: usize,
) ![]u8 {
    var source = common.TrackingSource{ .bytes = bytes, .forbidden = forbidden };
    const range = try common.streamRange(&source);
    var cursor = stream_cursor.Cursor.init(range, format);
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(std.testing.allocator);

    var skippables: std.ArrayList(SkippableObservation) = .empty;
    defer skippables.deinit(std.testing.allocator);

    while (try cursor.next()) |element| {
        switch (element) {
            .skippable => |frame| {
                try skippables.append(std.testing.allocator, .{
                    .id = frame.skippable_id,
                    .payload_len = @intCast(frame.payload.len),
                    .payload_offset = frame.payload.offset,
                });
                try std.testing.expectEqual(
                    frame.payload.offset + frame.payload.len,
                    cursor.offset(),
                );
            },
            .data => |frame| {
                const history_len = try history_workspace.requiredLen(
                    frame.header.window_size,
                    0,
                );
                const history_storage = try std.testing.allocator.alloc(
                    u8,
                    history_len,
                );
                defer std.testing.allocator.free(history_storage);
                @memset(history_storage, 0xa7);
                const end = try common.decodeDataFrame(
                    Support,
                    std.testing.allocator,
                    frame,
                    history_storage,
                    &output,
                    page_len,
                    chunk,
                );
                try cursor.finishData(end);
                try std.testing.expectEqual(end, cursor.offset());
            },
        }
    }
    try std.testing.expect(!cursor.pending());
    try std.testing.expect(!source.forbidden_read);
    return output.toOwnedSlice(std.testing.allocator);
}

fn expectStream(
    comptime Support: type,
    bytes: []const u8,
    format: stream_cursor.FrameFormat,
    forbidden: []const common.Span,
    expected: []const u8,
    page_len: usize,
    chunk: usize,
) !void {
    const actual = try runStream(
        Support,
        bytes,
        format,
        forbidden,
        page_len,
        chunk,
    );
    defer std.testing.allocator.free(actual);
    try std.testing.expectEqualSlices(u8, expected, actual);
}

fn standardConcatenation(comptime Support: type) !void {
    var fixture: common.Fixture = .{};
    common.appendDataHeader(&fixture, 0x00, 0x00, null);
    common.appendRawBlock(&fixture, "alpha", true);
    const skip_a = common.appendSkippable(&fixture, 0, "skip-0");
    common.appendDataHeader(&fixture, 0x04, 0x00, null);
    common.appendRleBlock(&fixture, 'b', 3, true);
    common.appendChecksum(&fixture, "bbb");
    const skip_b = common.appendSkippable(&fixture, 15, &.{});
    fixture.appendSlice(&common.zero_sequence_frame);

    const expected = try oracle(Support, fixture.bytes());
    defer std.testing.allocator.free(expected);
    try std.testing.expectEqualStrings("alphabbbzzzzz", expected);

    const forbidden = [_]common.Span{
        .{ .offset = skip_a + 8, .len = 6 },
        .{ .offset = skip_b + 8, .len = 0 },
    };
    inline for (.{ 9, 10, 17 }) |page_len|
        inline for (.{ 1, 7, 256 }) |chunk|
            try expectStream(
                Support,
                fixture.bytes(),
                .standard,
                &forbidden,
                expected,
                page_len,
                chunk,
            );
}

fn skippableOnly(comptime Support: type) !void {
    _ = Support;
    var fixture: common.Fixture = .{};
    _ = common.appendSkippable(&fixture, 3, "payload");
    _ = common.appendSkippable(&fixture, 12, &.{});

    var source = common.TrackingSource{ .bytes = fixture.bytes() };
    const range = try common.streamRange(&source);
    var cursor = stream_cursor.Cursor.init(range, .standard);

    const first = (try cursor.next()) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(u4, 3), first.skippable.skippable_id);
    try std.testing.expectEqual(@as(u64, 7), first.skippable.payload.len);
    try std.testing.expectEqual(@as(u64, 15), cursor.offset());

    const second = (try cursor.next()) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(u4, 12), second.skippable.skippable_id);
    try std.testing.expectEqual(@as(u64, 0), second.skippable.payload.len);
    try std.testing.expectEqual(@as(u64, 23), cursor.offset());

    try std.testing.expect((try cursor.next()) == null);
}

fn emptyStream(comptime Support: type) !void {
    _ = Support;
    var source = common.TrackingSource{ .bytes = &.{} };
    const range = try common.streamRange(&source);
    var cursor = stream_cursor.Cursor.init(range, .standard);
    try std.testing.expect((try cursor.next()) == null);
}

fn allSkippableIds(comptime Support: type) !void {
    _ = Support;
    for (0..16) |id| {
        var fixture: common.Fixture = .{};
        _ = common.appendSkippable(&fixture, @intCast(id), "x");
        var source = common.TrackingSource{ .bytes = fixture.bytes() };
        const range = try common.streamRange(&source);
        var cursor = stream_cursor.Cursor.init(range, .standard);
        const element = (try cursor.next()) orelse
            return error.TestUnexpectedResult;
        try std.testing.expectEqual(@as(u4, @intCast(id)), element.skippable.skippable_id);
        try std.testing.expectEqual(@as(u64, 1), element.skippable.payload.len);
        try std.testing.expect((try cursor.next()) == null);
    }
}

fn magiclessConcatenation(comptime Support: type) !void {
    var standard: common.Fixture = .{};
    common.appendDataHeader(&standard, 0x00, 0x00, null);
    common.appendRawBlock(&standard, "one", true);
    common.appendDataHeader(&standard, 0x00, 0x00, null);
    common.appendRleBlock(&standard, '2', 2, true);

    var fixture: common.Fixture = .{};
    common.appendMagiclessHeader(&fixture, 0x00, 0x00, null);
    common.appendRawBlock(&fixture, "one", true);
    common.appendMagiclessHeader(&fixture, 0x00, 0x00, null);
    common.appendRleBlock(&fixture, '2', 2, true);

    const expected = try oracle(Support, standard.bytes());
    defer std.testing.allocator.free(expected);
    try std.testing.expectEqualStrings("one22", expected);
    inline for (.{ 9, 17 }) |page_len|
        try expectStream(
            Support,
            fixture.bytes(),
            .magicless,
            &.{},
            expected,
            page_len,
            3,
        );
}

fn compressedFixtures(comptime Support: type) !void {
    inline for (.{
        common.all_fse_raw_hex,
        common.numbered_json_hex,
        common.predefined_repeat_hex,
    }) |encoded| {
        const bytes = try common.decodeHex(encoded);
        defer std.testing.allocator.free(bytes);
        const expected = try oracle(Support, bytes);
        defer std.testing.allocator.free(expected);
        try expectStream(Support, bytes, .standard, &.{}, expected, 9, 97);
    }

    const first = try common.decodeHex(common.numbered_json_hex);
    defer std.testing.allocator.free(first);
    const last = try common.decodeHex(common.predefined_repeat_hex);
    defer std.testing.allocator.free(last);

    var fixture: common.Fixture = .{};
    _ = common.appendFrame(&fixture, first);
    _ = common.appendSkippable(&fixture, 7, "between");
    _ = common.appendFrame(&fixture, last);
    _ = common.appendSkippable(&fixture, 1, &.{});

    const expected = try oracle(Support, fixture.bytes());
    defer std.testing.allocator.free(expected);
    try expectStream(Support, fixture.bytes(), .standard, &.{}, expected, 10, 64);
}

pub fn contracts(comptime Support: type) !void {
    try standardConcatenation(Support);
    try skippableOnly(Support);
    try emptyStream(Support);
    try allSkippableIds(Support);
    try magiclessConcatenation(Support);
    try compressedFixtures(Support);
}
