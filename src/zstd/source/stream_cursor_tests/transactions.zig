const std = @import("std");
const common = @import("common.zig");
const stream_cursor = common.stream_cursor;
const history_workspace = common.history_workspace;

fn retryable(err: anyerror) bool {
    return err == error.SourceReadFailed or err == error.TruncatedFrame;
}

fn twoDataFrames() common.Fixture {
    var fixture: common.Fixture = .{};
    common.appendDataHeader(&fixture, 0x00, 0x00, null);
    common.appendRawBlock(&fixture, "first", true);
    common.appendDataHeader(&fixture, 0x00, 0x00, null);
    common.appendRawBlock(&fixture, "second", true);
    return fixture;
}

fn pendingContract(comptime Support: type) !void {
    _ = Support;
    const fixture = twoDataFrames();
    var source = common.TrackingSource{ .bytes = fixture.bytes() };
    const range = try common.streamRange(&source);
    var cursor = stream_cursor.Cursor.init(range, .standard);

    const first = (try cursor.next()) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(
        std.meta.activeTag(first),
        stream_cursor.Element.data,
    );
    try std.testing.expect(cursor.pending());
    try std.testing.expectEqual(@as(u64, 0), cursor.offset());
    try std.testing.expectError(error.InvalidStreamState, cursor.next());

    try std.testing.expectError(
        error.CorruptFrame,
        cursor.finishData(@as(u64, @intCast(fixture.len)) + 1),
    );
    try std.testing.expect(cursor.pending());

    const first_end = first.data.available.offset +
        first.data.header_range.len + 3 + "first".len;
    try cursor.finishData(first_end);
    try std.testing.expect(!cursor.pending());
    try std.testing.expectEqual(first_end, cursor.offset());

    const second = (try cursor.next()) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(
        std.meta.activeTag(second),
        stream_cursor.Element.data,
    );
    try std.testing.expectEqual(first_end, second.data.available.offset);
    try std.testing.expectError(
        error.CorruptFrame,
        cursor.finishData(second.data.available.offset - 1),
    );
    try std.testing.expect(cursor.pending());
    const second_end = second.data.available.offset +
        second.data.header_range.len + 3 + "second".len;
    try cursor.finishData(second_end);
    try std.testing.expect((try cursor.next()) == null);
}

fn finishWithoutData(comptime Support: type) !void {
    _ = Support;
    var source = common.TrackingSource{ .bytes = &.{} };
    const range = try common.streamRange(&source);
    var cursor = stream_cursor.Cursor.init(range, .standard);
    try std.testing.expectError(error.InvalidStreamState, cursor.finishData(0));
}

fn truncatedSkippable(comptime Support: type) !void {
    _ = Support;
    var fixture: common.Fixture = .{};
    _ = common.appendSkippable(&fixture, 5, "abcde");
    for (1..fixture.len) |len| {
        var source = common.TrackingSource{ .bytes = fixture.bytes()[0..len] };
        const range = try common.streamRange(&source);
        var cursor = stream_cursor.Cursor.init(range, .standard);
        try std.testing.expectError(error.TruncatedFrame, cursor.next());
        try std.testing.expectEqual(@as(u64, 0), cursor.offset());
        try std.testing.expect(!cursor.pending());
    }

    var source = common.TrackingSource{ .bytes = fixture.bytes() };
    const range = try common.streamRange(&source);
    var cursor = stream_cursor.Cursor.init(range, .standard);
    const element = (try cursor.next()) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(u4, 5), element.skippable.skippable_id);
    try std.testing.expectEqual(@as(u64, 5), element.skippable.payload.len);
    try std.testing.expect((try cursor.next()) == null);
}

fn truncatedData(comptime Support: type) !void {
    var fixture: common.Fixture = .{};
    common.appendDataHeader(&fixture, 0x00, 0x00, null);
    common.appendRawBlock(&fixture, "payload", true);

    // Truncation inside the frame header is an element parse failure.
    const header_len = 6;
    for (1..header_len) |len| {
        var source = common.TrackingSource{ .bytes = fixture.bytes()[0..len] };
        const range = try common.streamRange(&source);
        var cursor = stream_cursor.Cursor.init(range, .standard);
        try std.testing.expectError(error.TruncatedFrame, cursor.next());
        try std.testing.expectEqual(@as(u64, 0), cursor.offset());
    }

    // A complete header with a short body remains a pending data element.
    const source_bytes = fixture.bytes();
    for (header_len..fixture.len) |len| {
        var source = common.TrackingSource{ .bytes = source_bytes[0..len] };
        const range = try common.streamRange(&source);
        var cursor = stream_cursor.Cursor.init(range, .standard);
        const element = (try cursor.next()) orelse
            return error.TestUnexpectedResult;
        switch (element) {
            .data => {},
            .skippable => return error.TestUnexpectedResult,
        }
        try std.testing.expect(cursor.pending());
        try std.testing.expectError(error.InvalidStreamState, cursor.next());

        const history_len = try history_workspace.requiredLen(
            element.data.header.window_size,
            0,
        );
        const history_storage = try std.testing.allocator.alloc(
            u8,
            history_len,
        );
        defer std.testing.allocator.free(history_storage);
        var output: std.ArrayList(u8) = .empty;
        defer output.deinit(std.testing.allocator);
        try std.testing.expectError(
            error.TruncatedFrame,
            common.decodeDataFrame(
                Support,
                std.testing.allocator,
                element.data,
                history_storage,
                &output,
                9,
                256,
            ),
        );
        try std.testing.expectEqual(@as(usize, 0), output.items.len);
        try std.testing.expect(cursor.pending());
    }
}

fn faultStream(comptime Support: type, mode: common.Mode) !void {
    var fixture: common.Fixture = .{};
    _ = common.appendSkippable(&fixture, 2, "skip");
    common.appendDataHeader(&fixture, 0x00, 0x00, null);
    common.appendRawBlock(&fixture, "first", true);
    _ = common.appendSkippable(&fixture, 4, &.{});
    common.appendDataHeader(&fixture, 0x00, 0x00, null);
    common.appendRawBlock(&fixture, "second", true);

    var found = false;
    var delta: usize = 1;
    while (delta < 128 and !found) : (delta += 1) {
        var source = common.TrackingSource{ .bytes = fixture.bytes() };
        const range = try common.streamRange(&source);
        var cursor = stream_cursor.Cursor.init(range, .standard);
        var output: std.ArrayList(u8) = .empty;
        defer output.deinit(std.testing.allocator);
        source.mode = mode;
        source.fault_call = source.calls + delta;

        var faulted = false;
        while (true) {
            const next = cursor.next() catch |err| {
                if (!retryable(err)) return err;
                faulted = true;
                source.clearFault();
                continue;
            };
            const element = next orelse break;
            switch (element) {
                .skippable => {},
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
                    var end: u64 = undefined;
                    while (true) {
                        end = common.decodeDataFrame(
                            Support,
                            std.testing.allocator,
                            frame,
                            history_storage,
                            &output,
                            9,
                            256,
                        ) catch |err| {
                            if (!retryable(err)) return err;
                            faulted = true;
                            source.clearFault();
                            continue;
                        };
                        break;
                    }
                    try cursor.finishData(end);
                },
            }
        }
        try std.testing.expectEqualStrings("firstsecond", output.items);
        if (faulted) {
            found = true;
        }
    }
    try std.testing.expect(found);
}

fn sourceFailures(comptime Support: type) !void {
    inline for (.{ common.Mode.zero, common.Mode.excessive, common.Mode.fail }) |mode|
        try faultStream(Support, mode);
}

pub fn contracts(comptime Support: type) !void {
    try pendingContract(Support);
    try finishWithoutData(Support);
    try truncatedSkippable(Support);
    try truncatedData(Support);
    try sourceFailures(Support);
}
