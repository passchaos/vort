const std = @import("std");
const stream_common = @import("stream_cursor_tests/common.zig");
const history_workspace = @import("../decode/history_workspace.zig");
const core = @import("../../core.zig");

fn WorkspaceOwner(comptime Support: type) type {
    return struct {
        history: []u8,
        staging: []u8,
        literal_page: []u8,
        sequence_page: []u8,

        pub fn init(
            allocator: std.mem.Allocator,
            window_size: u64,
            block_size_max: usize,
            dictionary_len: usize,
            page_len: usize,
        ) !@This() {
            const history_len = try history_workspace.requiredLen(
                window_size,
                dictionary_len,
            );
            const history = try allocator.alloc(u8, history_len);
            errdefer allocator.free(history);
            const staging = try allocator.alloc(u8, block_size_max);
            errdefer allocator.free(staging);
            const literal_page = try allocator.alloc(u8, page_len);
            errdefer allocator.free(literal_page);
            const sequence_page = try allocator.alloc(u8, page_len);
            return .{
                .history = history,
                .staging = staging,
                .literal_page = literal_page,
                .sequence_page = sequence_page,
            };
        }

        pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
            allocator.free(self.history);
            allocator.free(self.staging);
            allocator.free(self.literal_page);
            allocator.free(self.sequence_page);
            self.* = undefined;
        }

        pub fn view(self: @This()) Support.Workspace {
            return .{
                .history = self.history,
                .staging = self.staging,
                .literal_page = self.literal_page,
                .sequence_page = self.sequence_page,
            };
        }
    };
}

fn oracle(comptime Support: type, bytes: []const u8) ![]u8 {
    return Support.decodeFrameOracle(std.testing.allocator, bytes);
}

fn rawRleFrame(comptime Support: type) !void {
    var fixture: stream_common.Fixture = .{};
    stream_common.appendDataHeader(&fixture, 0x04, 0x00, null);
    stream_common.appendRawBlock(&fixture, "alpha", false);
    stream_common.appendRleBlock(&fixture, 'b', 3, true);
    stream_common.appendChecksum(&fixture, "alphabbb");

    var source = stream_common.TrackingSource{ .bytes = fixture.bytes() };
    const view = source.source();
    const info = try Support.inspect(view, .{});
    try std.testing.expectEqual(@as(u64, 8), @as(u64, @intCast(info.decoded_size.?)));
    try std.testing.expectEqual(
        @as(u64, @intCast(fixture.len)),
        info.frame_end_offset,
    );
    try std.testing.expect(info.has_checksum);
    try std.testing.expectEqual(@as(u32, 0), info.dictionary_id);
    try std.testing.expectEqual(
        @as(u64, 8),
        @as(u64, @intCast((try Support.decodedSize(view, .{})).?)),
    );

    var workspace = try WorkspaceOwner(Support).init(
        std.testing.allocator,
        info.window_size,
        info.block_size_max,
        0,
        9,
    );
    defer workspace.deinit(std.testing.allocator);

    var output: [8]u8 = undefined;
    const result = try Support.decodeInto(view, &output, workspace.view(), .{});
    try std.testing.expectEqual(
        @as(u64, 8),
        @as(u64, @intCast(result.decoded_len)),
    );
    try std.testing.expectEqual(info.frame_end_offset, result.frame_end_offset);
    try std.testing.expectEqualStrings("alphabbb", &output);

    const allocated = try Support.decodeAlloc(
        std.testing.allocator,
        view,
        workspace.view(),
        .{},
    );
    defer std.testing.allocator.free(allocated);
    try std.testing.expectEqualStrings("alphabbb", allocated);
}

fn compressedFixtures(comptime Support: type) !void {
    inline for (.{
        stream_common.all_fse_raw_hex,
        stream_common.numbered_json_hex,
        stream_common.predefined_repeat_hex,
    }) |encoded| {
        const bytes = try stream_common.decodeHex(encoded);
        defer std.testing.allocator.free(bytes);
        const expected = try oracle(Support, bytes);
        defer std.testing.allocator.free(expected);

        var source = stream_common.TrackingSource{ .bytes = bytes };
        const view = source.source();
        const info = try Support.inspect(view, .{});
        try std.testing.expectEqual(
            @as(u64, @intCast(expected.len)),
            @as(u64, @intCast(info.decoded_size.?)),
        );
        try std.testing.expectEqual(
            @as(u64, @intCast(bytes.len)),
            info.frame_end_offset,
        );

        inline for (.{ 9, 10, 17 }) |page_len| {
            var workspace = try WorkspaceOwner(Support).init(
                std.testing.allocator,
                info.window_size,
                info.block_size_max,
                0,
                page_len,
            );
            defer workspace.deinit(std.testing.allocator);
            const allocated = try Support.decodeAlloc(
                std.testing.allocator,
                view,
                workspace.view(),
                .{},
            );
            defer std.testing.allocator.free(allocated);
            try std.testing.expectEqualSlices(u8, expected, allocated);
        }
    }
}

fn dictionaryFrame(comptime Support: type) !void {
    var fixture = try Support.loadFullDictionaryFixture(std.testing.allocator);
    defer Support.freeFullDictionaryFixture(std.testing.allocator, &fixture);

    const dictionary_bytes = try stream_common.decodeHex(
        @embedFile("../testdata/libzstd-trained-repeat.dict.hex"),
    );
    defer std.testing.allocator.free(dictionary_bytes);
    const standard = try Support.DecodeDictionary.initFromStandardDictionary(
        dictionary_bytes,
    );
    const dictionary = standard.dictionary;

    var source = stream_common.TrackingSource{ .bytes = fixture.frame };
    const view = source.source();
    const info = try Support.inspect(view, .{ .dictionary = dictionary });
    try std.testing.expectEqual(
        @as(u64, @intCast(fixture.expected.len)),
        @as(u64, @intCast(info.decoded_size.?)),
    );
    try std.testing.expectEqual(
        @as(u64, @intCast(fixture.frame.len)),
        info.frame_end_offset,
    );

    var workspace = try WorkspaceOwner(Support).init(
        std.testing.allocator,
        info.window_size,
        info.block_size_max,
        dictionary.content.len,
        17,
    );
    defer workspace.deinit(std.testing.allocator);

    const allocated = try Support.decodeAlloc(
        std.testing.allocator,
        view,
        workspace.view(),
        .{ .dictionary = dictionary },
    );
    defer std.testing.allocator.free(allocated);
    try std.testing.expectEqualSlices(u8, fixture.expected, allocated);

    try std.testing.expectError(
        error.NeedDictionary,
        Support.inspect(view, .{}),
    );
    var wrong = dictionary;
    wrong.id +%= 1;
    if (wrong.id == 0) wrong.id = 2;
    try std.testing.expectError(
        error.DictionaryMismatch,
        Support.inspect(view, .{ .dictionary = wrong }),
    );
}

fn destinationTooSmall(comptime Support: type) !void {
    var fixture: stream_common.Fixture = .{};
    stream_common.appendDataHeader(&fixture, 0x00, 0x00, null);
    stream_common.appendRawBlock(&fixture, "alphabbb", true);

    var source = stream_common.TrackingSource{ .bytes = fixture.bytes() };
    const view = source.source();
    const info = try Support.inspect(view, .{});
    var workspace = try WorkspaceOwner(Support).init(
        std.testing.allocator,
        info.window_size,
        info.block_size_max,
        0,
        9,
    );
    defer workspace.deinit(std.testing.allocator);

    var output: [7]u8 = undefined;
    try std.testing.expectError(
        error.OutputTooSmall,
        Support.decodeInto(view, &output, workspace.view(), .{}),
    );
    try std.testing.expectEqualStrings("alphabb", &output);
}

fn workspaceTooSmall(comptime Support: type) !void {
    var fixture: stream_common.Fixture = .{};
    stream_common.appendDataHeader(&fixture, 0x00, 0x00, null);
    stream_common.appendRawBlock(&fixture, "abc", true);

    var source = stream_common.TrackingSource{ .bytes = fixture.bytes() };
    const view = source.source();
    const info = try Support.inspect(view, .{});

    var history = try WorkspaceOwner(Support).init(
        std.testing.allocator,
        info.window_size,
        info.block_size_max,
        0,
        9,
    );
    defer history.deinit(std.testing.allocator);
    var output: [3]u8 = undefined;
    var short_history = history.view();
    short_history.history = short_history.history[0 .. short_history.history.len - 1];
    try std.testing.expectError(
        error.OutputTooSmall,
        Support.decodeInto(view, &output, short_history, .{}),
    );

    var short_staging = history.view();
    short_staging.staging = short_staging.staging[0 .. short_staging.staging.len - 1];
    try std.testing.expectError(
        error.OutputTooSmall,
        Support.decodeInto(view, &output, short_staging, .{}),
    );

    var short_page = history.view();
    short_page.literal_page = short_page.literal_page[0..8];
    try std.testing.expectError(
        error.OutputTooSmall,
        Support.decodeInto(view, &output, short_page, .{}),
    );
}

fn checksumMismatch(comptime Support: type) !void {
    var fixture: stream_common.Fixture = .{};
    stream_common.appendDataHeader(&fixture, 0x04, 0x00, null);
    stream_common.appendRawBlock(&fixture, "abc", true);
    stream_common.appendChecksum(&fixture, "abc");
    const bytes = try std.testing.allocator.dupe(u8, fixture.bytes());
    defer std.testing.allocator.free(bytes);
    bytes[bytes.len - 1] ^= 0xff;

    var source = stream_common.TrackingSource{ .bytes = bytes };
    const view = source.source();
    const info = try Support.inspect(view, .{});
    var workspace = try WorkspaceOwner(Support).init(
        std.testing.allocator,
        info.window_size,
        info.block_size_max,
        0,
        9,
    );
    defer workspace.deinit(std.testing.allocator);

    var output: [3]u8 = undefined;
    try std.testing.expectError(
        error.ChecksumMismatch,
        Support.decodeInto(view, &output, workspace.view(), .{}),
    );
    try std.testing.expectEqualStrings("abc", &output);
    _ = try Support.decodeInto(
        view,
        &output,
        workspace.view(),
        .{ .ignore_checksum = true },
    );
}

fn truncatedSource(comptime Support: type) !void {
    var fixture: stream_common.Fixture = .{};
    stream_common.appendDataHeader(&fixture, 0x04, 0x00, null);
    stream_common.appendRawBlock(&fixture, "abc", true);
    stream_common.appendChecksum(&fixture, "abc");

    for (0..fixture.len) |len| {
        var source = stream_common.TrackingSource{ .bytes = fixture.bytes()[0..len] };
        const view = source.source();
        try std.testing.expectError(error.TruncatedFrame, Support.inspect(view, .{}));
    }
}

fn trailingSuffix(comptime Support: type) !void {
    var fixture: stream_common.Fixture = .{};
    stream_common.appendDataHeader(&fixture, 0x04, 0x00, null);
    stream_common.appendRawBlock(&fixture, "abc", true);
    stream_common.appendChecksum(&fixture, "abc");
    const frame_len = fixture.len;
    fixture.appendSlice("TRAILING");

    var source = stream_common.TrackingSource{ .bytes = fixture.bytes() };
    const view = source.source();
    const info = try Support.inspect(view, .{});
    try std.testing.expectEqual(
        @as(u64, @intCast(frame_len)),
        info.frame_end_offset,
    );
    var workspace = try WorkspaceOwner(Support).init(
        std.testing.allocator,
        info.window_size,
        info.block_size_max,
        0,
        9,
    );
    defer workspace.deinit(std.testing.allocator);
    const allocated = try Support.decodeAlloc(
        std.testing.allocator,
        view,
        workspace.view(),
        .{},
    );
    defer std.testing.allocator.free(allocated);
    try std.testing.expectEqualStrings("abc", allocated);
}

fn magiclessFrame(comptime Support: type) !void {
    var standard: stream_common.Fixture = .{};
    stream_common.appendDataHeader(&standard, 0x00, 0x00, null);
    stream_common.appendRawBlock(&standard, "one", false);
    stream_common.appendRleBlock(&standard, '2', 2, true);

    var fixture: stream_common.Fixture = .{};
    stream_common.appendMagiclessHeader(&fixture, 0x00, 0x00, null);
    stream_common.appendRawBlock(&fixture, "one", false);
    stream_common.appendRleBlock(&fixture, '2', 2, true);

    const expected = try oracle(Support, standard.bytes());
    defer std.testing.allocator.free(expected);
    var source = stream_common.TrackingSource{ .bytes = fixture.bytes() };
    const view = source.source();
    const info = try Support.inspect(view, .{ .format = .magicless });
    try std.testing.expectEqual(
        @as(u64, @intCast(expected.len)),
        @as(u64, @intCast(info.decoded_size.?)),
    );
    try std.testing.expectEqual(
        @as(u64, @intCast(fixture.len)),
        info.frame_end_offset,
    );
    var workspace = try WorkspaceOwner(Support).init(
        std.testing.allocator,
        info.window_size,
        info.block_size_max,
        0,
        9,
    );
    defer workspace.deinit(std.testing.allocator);
    const allocated = try Support.decodeAlloc(
        std.testing.allocator,
        view,
        workspace.view(),
        .{ .format = .magicless },
    );
    defer std.testing.allocator.free(allocated);
    try std.testing.expectEqualSlices(u8, expected, allocated);
}

fn sizeLimit(comptime Support: type) !void {
    var fixture: stream_common.Fixture = .{};
    stream_common.appendDataHeader(&fixture, 0x00, 0x00, null);
    stream_common.appendRawBlock(&fixture, "abc", false);
    stream_common.appendRawBlock(&fixture, "de", true);

    var source = stream_common.TrackingSource{ .bytes = fixture.bytes() };
    const view = source.source();
    try std.testing.expectError(
        error.OutputLimitExceeded,
        Support.inspect(view, .{ .frame_decoded_max = 4 }),
    );
    const info = try Support.inspect(view, .{});
    var workspace = try WorkspaceOwner(Support).init(
        std.testing.allocator,
        info.window_size,
        info.block_size_max,
        0,
        9,
    );
    defer workspace.deinit(std.testing.allocator);
    var output: [5]u8 = undefined;
    try std.testing.expectError(
        error.OutputLimitExceeded,
        Support.decodeInto(
            view,
            &output,
            workspace.view(),
            .{ .frame_decoded_max = 4 },
        ),
    );
}

fn contentSizeMismatch(comptime Support: type) !void {
    var fixture: stream_common.Fixture = .{};
    stream_common.appendDataHeader(&fixture, 0x20, null, 9);
    stream_common.appendRawBlock(&fixture, "abc", true);

    var source = stream_common.TrackingSource{ .bytes = fixture.bytes() };
    const view = source.source();
    try std.testing.expectError(
        error.SizeMismatch,
        Support.inspect(view, .{}),
    );
}

fn inspectReadsHeadersOnly(comptime Support: type) !void {
    var fixture: stream_common.Fixture = .{};
    stream_common.appendDataHeader(&fixture, 0x00, 0x00, null);
    stream_common.appendRawBlock(&fixture, "payload", true);
    const payload_offset: u64 = 6 + 3;
    const forbidden = [_]stream_common.Span{
        .{ .offset = payload_offset, .len = "payload".len },
    };
    var source = stream_common.TrackingSource{
        .bytes = fixture.bytes(),
        .forbidden = &forbidden,
    };
    const view = source.source();
    const info = try Support.inspect(view, .{});
    try std.testing.expectEqual(
        @as(u64, "payload".len),
        @as(u64, @intCast(info.decoded_size.?)),
    );
    try std.testing.expect(!source.forbidden_read);
}

fn sourceFailureRetry(comptime Support: type) !void {
    var fixture: stream_common.Fixture = .{};
    stream_common.appendDataHeader(&fixture, 0x00, 0x00, null);
    stream_common.appendRawBlock(&fixture, "retry", true);

    var found = false;
    var delta: usize = 1;
    while (delta < 64 and !found) : (delta += 1) {
        var source = stream_common.TrackingSource{ .bytes = fixture.bytes() };
        const view = source.source();
        const info = try Support.inspect(view, .{});
        var workspace = try WorkspaceOwner(Support).init(
            std.testing.allocator,
            info.window_size,
            info.block_size_max,
            0,
            9,
        );
        defer workspace.deinit(std.testing.allocator);
        var output: [5]u8 = undefined;

        source.mode = .fail;
        source.fault_call = source.calls + delta;
        if (Support.decodeInto(view, &output, workspace.view(), .{})) |_| {
            // The injected call lies past the frame's last source callback.
        } else |err| {
            try std.testing.expectEqual(error.SourceReadFailed, err);
            source.clearFault();
            const result = try Support.decodeInto(
                view,
                &output,
                workspace.view(),
                .{},
            );
            try std.testing.expectEqual(@as(u64, 5), @as(u64, @intCast(result.decoded_len)));
            try std.testing.expectEqualStrings("retry", &output);
            found = true;
        }
    }
    try std.testing.expect(found);
}

fn streamConcatenation(comptime Support: type) !void {
    var fixture: stream_common.Fixture = .{};
    stream_common.appendDataHeader(&fixture, 0x00, 0x00, null);
    stream_common.appendRawBlock(&fixture, "one", true);
    const skip_a = stream_common.appendSkippable(&fixture, 3, "skip");
    stream_common.appendDataHeader(&fixture, 0x00, 0x00, null);
    stream_common.appendRleBlock(&fixture, '2', 2, true);
    _ = stream_common.appendSkippable(&fixture, 9, &.{});
    fixture.appendSlice(&stream_common.zero_sequence_frame);

    const forbidden = [_]stream_common.Span{
        .{ .offset = skip_a + 8, .len = 4 },
    };
    var source = stream_common.TrackingSource{
        .bytes = fixture.bytes(),
        .forbidden = &forbidden,
    };
    const view = source.source();
    const info = try Support.inspectStream(view, .{});
    try std.testing.expectEqual(
        @as(?u64, 10),
        if (info.total_decoded) |size| @as(u64, @intCast(size)) else null,
    );
    try std.testing.expectEqual(@as(usize, 3), info.data_frames);
    try std.testing.expectEqual(@as(usize, 2), info.skippable_frames);
    try std.testing.expectEqual(
        @as(u64, @intCast(fixture.len)),
        info.stream_end_offset,
    );

    var workspace = try WorkspaceOwner(Support).init(
        std.testing.allocator,
        1024,
        1024,
        0,
        9,
    );
    defer workspace.deinit(std.testing.allocator);

    var output: [10]u8 = undefined;
    const result = try Support.decodeStreamInto(
        view,
        &output,
        workspace.view(),
        .{},
    );
    try std.testing.expectEqual(
        @as(u64, 10),
        @as(u64, @intCast(result.decoded_len)),
    );
    try std.testing.expectEqual(@as(usize, 3), result.data_frames);
    try std.testing.expectEqual(@as(usize, 2), result.skippable_frames);
    try std.testing.expectEqual(
        @as(u64, @intCast(fixture.len)),
        result.stream_end_offset,
    );
    try std.testing.expectEqualStrings("one22zzzzz", &output);
    try std.testing.expect(!source.forbidden_read);

    const allocated = try Support.decodeStreamAlloc(
        std.testing.allocator,
        view,
        workspace.view(),
        .{},
    );
    defer std.testing.allocator.free(allocated);
    try std.testing.expectEqualStrings("one22zzzzz", allocated);
}

fn streamDictionarySet(comptime Support: type) !void {
    var fixture = try Support.loadFullDictionaryFixture(std.testing.allocator);
    defer Support.freeFullDictionaryFixture(std.testing.allocator, &fixture);

    const dictionary_bytes = try stream_common.decodeHex(
        @embedFile("../testdata/libzstd-trained-repeat.dict.hex"),
    );
    defer std.testing.allocator.free(dictionary_bytes);
    const standard = try Support.DecodeDictionary.initFromStandardDictionary(
        dictionary_bytes,
    );
    const dictionaries = [_]Support.DecodeDictionary{standard.dictionary};
    const set = Support.DecodeDictionarySet.init(&dictionaries);

    var stream: stream_common.Fixture = .{};
    _ = stream_common.appendFrame(&stream, fixture.frame);
    _ = stream_common.appendSkippable(&stream, 1, "x");
    stream_common.appendDataHeader(&stream, 0x00, 0x00, null);
    stream_common.appendRawBlock(&stream, "tail", true);

    var source = stream_common.TrackingSource{ .bytes = stream.bytes() };
    const view = source.source();
    const info = try Support.inspectStream(view, .{ .dictionary_set = set });
    try std.testing.expectEqual(
        @as(u64, @intCast(fixture.expected.len + 4)),
        @as(u64, @intCast(info.total_decoded.?)),
    );
    try std.testing.expectEqual(@as(usize, 2), info.data_frames);
    try std.testing.expectEqual(@as(usize, 1), info.skippable_frames);
    try std.testing.expectEqual(
        @as(u64, @intCast(stream.len)),
        info.stream_end_offset,
    );

    var workspace = try WorkspaceOwner(Support).init(
        std.testing.allocator,
        2304,
        2304,
        standard.dictionary.content.len,
        17,
    );
    defer workspace.deinit(std.testing.allocator);
    const allocated = try Support.decodeStreamAlloc(
        std.testing.allocator,
        view,
        workspace.view(),
        .{ .dictionary_set = set },
    );
    defer std.testing.allocator.free(allocated);
    try std.testing.expectEqualSlices(
        u8,
        fixture.expected,
        allocated[0..fixture.expected.len],
    );
    try std.testing.expectEqualStrings(
        "tail",
        allocated[fixture.expected.len..],
    );
}

fn streamBounds(comptime Support: type) !void {
    var fixture: stream_common.Fixture = .{};
    stream_common.appendDataHeader(&fixture, 0x00, 0x00, null);
    stream_common.appendRawBlock(&fixture, "abc", true);
    stream_common.appendDataHeader(&fixture, 0x00, 0x00, null);
    stream_common.appendRawBlock(&fixture, "de", true);

    var source = stream_common.TrackingSource{ .bytes = fixture.bytes() };
    const view = source.source();
    try std.testing.expectError(
        error.OutputLimitExceeded,
        Support.inspectStream(view, .{ .total_decoded_max = 4 }),
    );
    const info = try Support.inspectStream(view, .{});
    try std.testing.expectEqual(
        @as(?u64, 5),
        if (info.total_decoded) |size| @as(u64, @intCast(size)) else null,
    );

    var workspace = try WorkspaceOwner(Support).init(
        std.testing.allocator,
        1024,
        1024,
        0,
        9,
    );
    defer workspace.deinit(std.testing.allocator);

    var short: [4]u8 = undefined;
    try std.testing.expectError(
        error.OutputTooSmall,
        Support.decodeStreamInto(view, &short, workspace.view(), .{}),
    );
    try std.testing.expectEqualStrings("abcd", &short);

    var output: [5]u8 = undefined;
    try std.testing.expectError(
        error.OutputLimitExceeded,
        Support.decodeStreamInto(
            view,
            &output,
            workspace.view(),
            .{ .total_decoded_max = 4 },
        ),
    );
    try std.testing.expectEqualStrings("abc", output[0..3]);
}

fn streamSkippableOnly(comptime Support: type) !void {
    var fixture: stream_common.Fixture = .{};
    _ = stream_common.appendSkippable(&fixture, 2, "abc");
    _ = stream_common.appendSkippable(&fixture, 5, &.{});

    var source = stream_common.TrackingSource{ .bytes = fixture.bytes() };
    const view = source.source();
    const info = try Support.inspectStream(view, .{});
    try std.testing.expectEqual(
        @as(?u64, 0),
        if (info.total_decoded) |size| @as(u64, @intCast(size)) else null,
    );
    try std.testing.expectEqual(@as(usize, 0), info.data_frames);
    try std.testing.expectEqual(@as(usize, 2), info.skippable_frames);
    try std.testing.expectEqual(
        @as(u64, @intCast(fixture.len)),
        info.stream_end_offset,
    );

    var workspace = try WorkspaceOwner(Support).init(
        std.testing.allocator,
        1024,
        1024,
        0,
        9,
    );
    defer workspace.deinit(std.testing.allocator);
    const result = try Support.decodeStreamInto(
        view,
        &.{},
        workspace.view(),
        .{},
    );
    try std.testing.expectEqual(
        @as(u64, 0),
        @as(u64, @intCast(result.decoded_len)),
    );
    try std.testing.expectEqual(@as(usize, 2), result.skippable_frames);
}

fn streamEmpty(comptime Support: type) !void {
    var source = stream_common.TrackingSource{ .bytes = &.{} };
    const view = source.source();
    const info = try Support.inspectStream(view, .{});
    try std.testing.expectEqual(
        @as(?u64, 0),
        if (info.total_decoded) |size| @as(u64, @intCast(size)) else null,
    );
    try std.testing.expectEqual(@as(u64, 0), info.stream_end_offset);
    try std.testing.expectEqual(@as(usize, 0), info.data_frames);
    try std.testing.expectEqual(@as(usize, 0), info.skippable_frames);
}

fn streamMagicless(comptime Support: type) !void {
    var standard: stream_common.Fixture = .{};
    stream_common.appendDataHeader(&standard, 0x00, 0x00, null);
    stream_common.appendRawBlock(&standard, "one", true);
    stream_common.appendDataHeader(&standard, 0x00, 0x00, null);
    stream_common.appendRleBlock(&standard, '2', 2, true);

    var fixture: stream_common.Fixture = .{};
    stream_common.appendMagiclessHeader(&fixture, 0x00, 0x00, null);
    stream_common.appendRawBlock(&fixture, "one", true);
    stream_common.appendMagiclessHeader(&fixture, 0x00, 0x00, null);
    stream_common.appendRleBlock(&fixture, '2', 2, true);

    const expected = try oracle(Support, standard.bytes());
    defer std.testing.allocator.free(expected);
    var source = stream_common.TrackingSource{ .bytes = fixture.bytes() };
    const view = source.source();
    const info = try Support.inspectStream(view, .{ .format = .magicless });
    try std.testing.expectEqual(
        @as(u64, @intCast(expected.len)),
        @as(u64, @intCast(info.total_decoded.?)),
    );
    try std.testing.expectEqual(@as(usize, 2), info.data_frames);

    var workspace = try WorkspaceOwner(Support).init(
        std.testing.allocator,
        1024,
        1024,
        0,
        9,
    );
    defer workspace.deinit(std.testing.allocator);
    const allocated = try Support.decodeStreamAlloc(
        std.testing.allocator,
        view,
        workspace.view(),
        .{ .format = .magicless },
    );
    defer std.testing.allocator.free(allocated);
    try std.testing.expectEqualSlices(u8, expected, allocated);
}

fn streamTruncated(comptime Support: type) !void {
    var fixture: stream_common.Fixture = .{};
    stream_common.appendDataHeader(&fixture, 0x00, 0x00, null);
    stream_common.appendRawBlock(&fixture, "abc", true);
    _ = stream_common.appendSkippable(&fixture, 4, "skip");

    // The data frame ends at byte 12; that prefix is a complete shorter stream.
    const data_end = 12;
    for (1..fixture.len) |len| {
        var source = stream_common.TrackingSource{ .bytes = fixture.bytes()[0..len] };
        const view = source.source();
        if (len == data_end) {
            const info = try Support.inspectStream(view, .{});
            try std.testing.expectEqual(@as(usize, 1), info.data_frames);
            try std.testing.expectEqual(@as(usize, 0), info.skippable_frames);
            continue;
        }
        try std.testing.expectError(
            error.TruncatedFrame,
            Support.inspectStream(view, .{}),
        );
    }
}

fn streamCursorTraversal(comptime Support: type) !void {
    var fixture: stream_common.Fixture = .{};
    stream_common.appendDataHeader(&fixture, 0x00, 0x00, null);
    stream_common.appendRawBlock(&fixture, "one", true);
    const skip_a = stream_common.appendSkippable(&fixture, 3, "skip");
    stream_common.appendDataHeader(&fixture, 0x04, 0x00, null);
    stream_common.appendRleBlock(&fixture, '2', 2, true);
    stream_common.appendChecksum(&fixture, "22");
    const skip_b = stream_common.appendSkippable(&fixture, 9, &.{});

    const forbidden = [_]stream_common.Span{
        .{ .offset = skip_a + 8, .len = 4 },
        .{ .offset = skip_b + 8, .len = 0 },
    };
    var source = stream_common.TrackingSource{
        .bytes = fixture.bytes(),
        .forbidden = &forbidden,
    };
    const view = source.source();

    var workspace = try WorkspaceOwner(Support).init(
        std.testing.allocator,
        1024,
        1024,
        0,
        9,
    );
    defer workspace.deinit(std.testing.allocator);

    var cursor = try Support.StreamCursor.init(view, .standard);
    const first = (try cursor.next()) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(u64, 0), first.data.offset);
    try std.testing.expectEqual(@as(u32, 0), first.data.dictionary_id);
    try std.testing.expectEqual(@as(?u64, null), first.data.content_size);
    try std.testing.expect(!first.data.has_checksum);
    try std.testing.expect(cursor.pending());
    try std.testing.expectEqual(@as(u64, 0), cursor.offset());

    const first_info = try cursor.inspectPending(.{});
    try std.testing.expectEqual(
        @as(u64, 3),
        @as(u64, @intCast(first_info.decoded_size.?)),
    );
    try std.testing.expectEqual(@as(u64, 12), first_info.frame_end_offset);
    try std.testing.expectEqual(@as(u64, 12), cursor.offset());
    try std.testing.expect(!cursor.pending());

    const second = (try cursor.next()) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(u64, 12), second.skippable.offset);
    try std.testing.expectEqual(@as(u4, 3), second.skippable.skippable_id);
    try std.testing.expectEqual(@as(u64, 20), second.skippable.payload_offset);
    try std.testing.expectEqual(@as(u64, 4), second.skippable.payload_len);
    try std.testing.expectEqual(@as(u64, 24), second.skippable.next_offset);

    const third = (try cursor.next()) orelse return error.TestUnexpectedResult;
    try std.testing.expect(third.data.has_checksum);
    try std.testing.expectEqual(@as(?u64, null), third.data.content_size);
    var output: [2]u8 = undefined;
    const result = try cursor.decodeInto(&output, workspace.view(), .{});
    try std.testing.expectEqualStrings("22", &output);
    try std.testing.expectEqual(@as(u64, 38), result.frame_end_offset);
    try std.testing.expectEqual(
        @as(u64, 2),
        @as(u64, @intCast(cursor.totalDecoded())),
    );
    try std.testing.expect(!cursor.pending());

    const fourth = (try cursor.next()) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(u64, 38), fourth.skippable.offset);
    try std.testing.expectEqual(@as(u4, 9), fourth.skippable.skippable_id);
    try std.testing.expectEqual(@as(u64, 0), fourth.skippable.payload_len);
    try std.testing.expectEqual(@as(u64, 46), fourth.skippable.next_offset);
    try std.testing.expect((try cursor.next()) == null);
    try std.testing.expectEqual(@as(u64, 46), cursor.offset());
    try std.testing.expect(!source.forbidden_read);
}

fn streamCursorSkipDictionaryFrame(comptime Support: type) !void {
    var fixture = try Support.loadFullDictionaryFixture(std.testing.allocator);
    defer Support.freeFullDictionaryFixture(std.testing.allocator, &fixture);

    var source = stream_common.TrackingSource{ .bytes = fixture.frame };
    var cursor = try Support.StreamCursor.init(source.source(), .standard);
    const element = (try cursor.next()) orelse return error.TestUnexpectedResult;
    try std.testing.expect(element.data.dictionary_id != 0);
    try std.testing.expect(fixture.expected.len > 1);
    // Skipping does not require the dictionary or a decoded-output budget.
    const info = try cursor.skipData(.{ .frame_decoded_max = 1 });
    try std.testing.expectEqual(
        @as(u64, @intCast(fixture.frame.len)),
        info.frame_end_offset,
    );
    try std.testing.expect((try cursor.next()) == null);

    const dictionary_bytes = try stream_common.decodeHex(
        @embedFile("../testdata/libzstd-trained-repeat.dict.hex"),
    );
    defer std.testing.allocator.free(dictionary_bytes);
    const standard = try Support.DecodeDictionary.initFromStandardDictionary(
        dictionary_bytes,
    );
    var workspace = try WorkspaceOwner(Support).init(
        std.testing.allocator,
        2304,
        2304,
        standard.dictionary.content.len,
        17,
    );
    defer workspace.deinit(std.testing.allocator);

    var decode_source = stream_common.TrackingSource{ .bytes = fixture.frame };
    var decode_cursor = try Support.StreamCursor.init(
        decode_source.source(),
        .standard,
    );
    _ = (try decode_cursor.next()) orelse return error.TestUnexpectedResult;
    const output = try std.testing.allocator.alloc(u8, fixture.expected.len);
    defer std.testing.allocator.free(output);
    const result = try decode_cursor.decodeInto(
        output,
        workspace.view(),
        .{ .dictionary = standard.dictionary },
    );
    try std.testing.expectEqualSlices(u8, fixture.expected, output);
    try std.testing.expectEqual(
        @as(u64, @intCast(fixture.expected.len)),
        @as(u64, @intCast(result.decoded_len)),
    );
}

fn streamCursorBounds(comptime Support: type) !void {
    var fixture: stream_common.Fixture = .{};
    stream_common.appendDataHeader(&fixture, 0x00, 0x00, null);
    stream_common.appendRawBlock(&fixture, "abc", true);
    stream_common.appendDataHeader(&fixture, 0x00, 0x00, null);
    stream_common.appendRawBlock(&fixture, "de", true);

    var source = stream_common.TrackingSource{ .bytes = fixture.bytes() };
    const view = source.source();
    var workspace = try WorkspaceOwner(Support).init(
        std.testing.allocator,
        1024,
        1024,
        0,
        9,
    );
    defer workspace.deinit(std.testing.allocator);

    var cursor = try Support.StreamCursor.init(view, .standard);
    try std.testing.expectError(
        error.InvalidStreamState,
        cursor.decodeInto(&.{}, workspace.view(), .{}),
    );
    try std.testing.expectError(
        error.InvalidStreamState,
        cursor.skipData(.{}),
    );
    _ = (try cursor.next()) orelse return error.TestUnexpectedResult;
    try std.testing.expectError(error.InvalidStreamState, cursor.next());

    var short: [2]u8 = undefined;
    try std.testing.expectError(
        error.OutputTooSmall,
        cursor.decodeInto(&short, workspace.view(), .{}),
    );
    try std.testing.expect(cursor.pending());
    try std.testing.expectEqual(@as(u64, 0), cursor.offset());

    var output: [5]u8 = undefined;
    const first = try cursor.decodeInto(output[0..3], workspace.view(), .{});
    try std.testing.expectEqual(
        @as(u64, 3),
        @as(u64, @intCast(first.decoded_len)),
    );
    try std.testing.expectEqualStrings("abc", output[0..3]);
    try std.testing.expect(!cursor.pending());

    _ = (try cursor.next()) orelse return error.TestUnexpectedResult;
    try std.testing.expectError(
        error.OutputLimitExceeded,
        cursor.decodeInto(
            output[3..5],
            workspace.view(),
            .{ .total_decoded_max = 4 },
        ),
    );
    try std.testing.expect(cursor.pending());
    const second = try cursor.decodeInto(
        output[3..5],
        workspace.view(),
        .{ .total_decoded_max = 5 },
    );
    try std.testing.expectEqual(
        @as(u64, 2),
        @as(u64, @intCast(second.decoded_len)),
    );
    try std.testing.expectEqualStrings("abcde", &output);
    try std.testing.expectEqual(
        @as(u64, 5),
        @as(u64, @intCast(cursor.totalDecoded())),
    );
}

fn streamCursorMagicless(comptime Support: type) !void {
    var fixture: stream_common.Fixture = .{};
    stream_common.appendMagiclessHeader(&fixture, 0x00, 0x00, null);
    stream_common.appendRawBlock(&fixture, "one", true);
    stream_common.appendMagiclessHeader(&fixture, 0x00, 0x00, null);
    stream_common.appendRleBlock(&fixture, '2', 2, true);

    var source = stream_common.TrackingSource{ .bytes = fixture.bytes() };
    var workspace = try WorkspaceOwner(Support).init(
        std.testing.allocator,
        1024,
        1024,
        0,
        9,
    );
    defer workspace.deinit(std.testing.allocator);

    var cursor = try Support.StreamCursor.init(source.source(), .magicless);
    var output: [5]u8 = undefined;
    var written: usize = 0;
    while (try cursor.next()) |element| {
        switch (element) {
            .skippable => return error.TestUnexpectedResult,
            .data => {
                const result = try cursor.decodeInto(
                    output[written..],
                    workspace.view(),
                    .{},
                );
                written += try core.stream_count.toLocal(result.decoded_len);
            },
        }
    }
    try std.testing.expectEqualStrings("one22", output[0..written]);
    try std.testing.expectEqual(
        @as(u64, @intCast(fixture.len)),
        cursor.offset(),
    );
}

pub fn contracts(comptime Support: type) !void {
    try rawRleFrame(Support);
    try compressedFixtures(Support);
    try dictionaryFrame(Support);
    try destinationTooSmall(Support);
    try workspaceTooSmall(Support);
    try checksumMismatch(Support);
    try truncatedSource(Support);
    try trailingSuffix(Support);
    try magiclessFrame(Support);
    try sizeLimit(Support);
    try contentSizeMismatch(Support);
    try inspectReadsHeadersOnly(Support);
    try sourceFailureRetry(Support);
    try streamConcatenation(Support);
    try streamDictionarySet(Support);
    try streamBounds(Support);
    try streamSkippableOnly(Support);
    try streamEmpty(Support);
    try streamMagicless(Support);
    try streamTruncated(Support);
    try streamCursorTraversal(Support);
    try streamCursorSkipDictionaryFrame(Support);
    try streamCursorBounds(Support);
    try streamCursorMagicless(Support);
}
