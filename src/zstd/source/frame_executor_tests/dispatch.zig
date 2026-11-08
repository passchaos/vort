const std = @import("std");
const common = @import("common.zig");
const frame_executor = common.frame_executor;

fn Runner(comptime Support: type) type {
    return common.Runner(Support);
}

fn expectDecode(
    comptime Support: type,
    bytes: []const u8,
    initial_state: Support.State,
    dictionary: []const u8,
    dictionary_id: u32,
    exec_limits: frame_executor.Limits,
    expected: []const u8,
    page_len: usize,
    chunk: usize,
) !void {
    var runner: Runner(Support) = undefined;
    try runner.init(
        std.testing.allocator,
        bytes,
        initial_state,
        dictionary,
        dictionary_id,
        exec_limits,
        page_len,
        chunk,
    );
    defer runner.deinit();
    try runner.run();
    try std.testing.expectEqualSlices(u8, expected, runner.output.items);
    try std.testing.expectEqual(
        @as(u64, @intCast(expected.len)),
        @as(u64, @intCast(runner.state.frame_decoded)),
    );
    try std.testing.expectEqual(
        @as(u64, @intCast(bytes.len)),
        try runner.executor.frameEndOffset(),
    );
    try runner.expectGuards();
    try runner.expectHistory(expected, dictionary.len);
    try std.testing.expect(!runner.executor.snapshot().failed);
}

fn oracle(comptime Support: type, bytes: []const u8) ![]u8 {
    return Support.decodeFrameOracle(std.testing.allocator, bytes);
}

fn mixedRawRle(comptime Support: type) !void {
    var fixture: common.Fixture = .{};
    common.appendHeader(&fixture, 0x00, 0x00, 0, null);
    common.appendRawBlock(&fixture, "abc", false);
    common.appendRleBlock(&fixture, 'x', 4, false);
    common.appendRawBlock(&fixture, "de", true);

    const expected = try oracle(Support, fixture.bytes());
    defer std.testing.allocator.free(expected);
    try std.testing.expectEqualStrings("abcxxxxde", expected);

    inline for (.{ 9, 10, 17 }) |page_len|
        inline for (.{ 1, 2, 256 }) |chunk|
            try expectDecode(
                Support,
                fixture.bytes(),
                Support.initialState(),
                &.{},
                0,
                .{},
                expected,
                page_len,
                chunk,
            );
}

fn emptyLastRle(comptime Support: type) !void {
    var fixture: common.Fixture = .{};
    common.appendHeader(&fixture, 0x00, 0x00, 0, null);
    common.appendRleBlock(&fixture, 0x7a, 0, true);

    const expected = try oracle(Support, fixture.bytes());
    defer std.testing.allocator.free(expected);
    try std.testing.expectEqual(@as(usize, 0), expected.len);

    var runner: Runner(Support) = undefined;
    try runner.init(
        std.testing.allocator,
        fixture.bytes(),
        Support.initialState(),
        &.{},
        0,
        .{},
        9,
        4,
    );
    defer runner.deinit();
    try runner.run();
    try std.testing.expectEqual(@as(usize, 0), runner.output.items.len);
    try std.testing.expectEqual(@as(usize, 1), runner.executor.snapshot().block_index);
    try std.testing.expectEqual(
        @as(u64, @intCast(fixture.len)),
        try runner.executor.frameEndOffset(),
    );
    try runner.expectGuards();
}

fn checksumFooter(comptime Support: type) !void {
    var fixture: common.Fixture = .{};
    common.appendHeader(&fixture, 0x04, 0x00, 0, null);
    common.appendRawBlock(&fixture, "abc", false);
    common.appendRleBlock(&fixture, 'z', 3, true);
    common.appendChecksum(&fixture, "abczzz");

    const expected = try oracle(Support, fixture.bytes());
    defer std.testing.allocator.free(expected);
    try std.testing.expectEqualStrings("abczzz", expected);

    try expectDecode(
        Support,
        fixture.bytes(),
        Support.initialState(),
        &.{},
        0,
        .{},
        expected,
        9,
        2,
    );

    // A corrupt footer must be reported after the already-committed output.
    const corrupt = try std.testing.allocator.dupe(u8, fixture.bytes());
    defer std.testing.allocator.free(corrupt);
    corrupt[corrupt.len - 1] ^= 0xff;
    var runner: Runner(Support) = undefined;
    try runner.init(
        std.testing.allocator,
        corrupt,
        Support.initialState(),
        &.{},
        0,
        .{},
        9,
        256,
    );
    defer runner.deinit();
    try std.testing.expectError(error.ChecksumMismatch, runner.run());
    try std.testing.expectEqualSlices(u8, "abczzz", runner.output.items);
    try std.testing.expect(runner.executor.snapshot().failed);
    try std.testing.expectError(
        error.InvalidStreamState,
        runner.executor.execute(),
    );

    // Ignoring the checksum still consumes the footer and frame boundary.
    try expectDecode(
        Support,
        corrupt,
        Support.initialState(),
        &.{},
        0,
        .{ .ignore_checksum = true },
        expected,
        9,
        3,
    );
}

fn contentSizeChecks(comptime Support: type) !void {
    var fixture: common.Fixture = .{};
    common.appendHeader(&fixture, 0x20, null, 0, 9);
    common.appendRawBlock(&fixture, "abc", false);
    common.appendRleBlock(&fixture, 'x', 4, false);
    common.appendRawBlock(&fixture, "de", true);

    const expected = try oracle(Support, fixture.bytes());
    defer std.testing.allocator.free(expected);
    try std.testing.expectEqualStrings("abcxxxxde", expected);
    try expectDecode(
        Support,
        fixture.bytes(),
        Support.initialState(),
        &.{},
        0,
        .{},
        expected,
        9,
        5,
    );

    // A single-block mismatch publishes nothing.
    var mismatch: common.Fixture = .{};
    common.appendHeader(&mismatch, 0x20, null, 0, 5);
    common.appendRawBlock(&mismatch, "abc", true);
    var runner: Runner(Support) = undefined;
    try runner.init(
        std.testing.allocator,
        mismatch.bytes(),
        Support.initialState(),
        &.{},
        0,
        .{},
        9,
        256,
    );
    defer runner.deinit();
    try std.testing.expectError(error.SizeMismatch, runner.run());
    try std.testing.expectEqual(@as(usize, 0), runner.output.items.len);
    try std.testing.expectEqual(
        @as(u64, 0),
        @as(u64, @intCast(runner.state.frame_decoded)),
    );
    try std.testing.expect(runner.executor.snapshot().failed);
    try runner.expectGuards();

    // A whole-frame cap rejects an undeclared-size block before publication.
    var uncapped: common.Fixture = .{};
    common.appendHeader(&uncapped, 0x00, 0x00, 0, null);
    common.appendRawBlock(&uncapped, "abc", false);
    common.appendRleBlock(&uncapped, 'x', 4, false);
    common.appendRawBlock(&uncapped, "de", true);
    var capped: Runner(Support) = undefined;
    try capped.init(
        std.testing.allocator,
        uncapped.bytes(),
        Support.initialState(),
        &.{},
        0,
        .{ .frame_decoded_max = 8 },
        9,
        256,
    );
    defer capped.deinit();
    try std.testing.expectError(error.OutputLimitExceeded, capped.run());
    try std.testing.expectEqualStrings("abcxxxx", capped.output.items);
    try std.testing.expectEqual(
        @as(u64, 7),
        @as(u64, @intCast(capped.state.frame_decoded)),
    );
    try std.testing.expect(capped.executor.snapshot().failed);

    // A declared size above the cap fails during admission.
    var admitted: Runner(Support) = undefined;
    try std.testing.expectError(
        error.OutputLimitExceeded,
        admitted.init(
            std.testing.allocator,
            fixture.bytes(),
            Support.initialState(),
            &.{},
            0,
            .{ .frame_decoded_max = 8 },
            9,
            256,
        ),
    );
    admitted.deinit();
}

fn dictionaryIdPolicy(comptime Support: type) !void {
    var fixture: common.Fixture = .{};
    common.appendHeader(&fixture, 0x01, 0x00, 7, null);
    common.appendRawBlock(&fixture, "hi", true);

    // The slice oracle requires a full dictionary for a nonzero ID; this
    // fixture exercises ID admission only.
    const expected = "hi";

    var missing: Runner(Support) = undefined;
    try std.testing.expectError(
        error.NeedDictionary,
        missing.init(
            std.testing.allocator,
            fixture.bytes(),
            Support.initialState(),
            &.{},
            0,
            .{},
            9,
            256,
        ),
    );
    missing.deinit();

    var wrong: Runner(Support) = undefined;
    try std.testing.expectError(
        error.DictionaryMismatch,
        wrong.init(
            std.testing.allocator,
            fixture.bytes(),
            Support.initialState(),
            &.{},
            8,
            .{},
            9,
            256,
        ),
    );
    wrong.deinit();

    try expectDecode(
        Support,
        fixture.bytes(),
        Support.initialState(),
        &.{},
        7,
        .{},
        expected,
        9,
        1,
    );
}

fn trailingSuffix(comptime Support: type) !void {
    var fixture: common.Fixture = .{};
    common.appendHeader(&fixture, 0x04, 0x00, 0, null);
    common.appendRawBlock(&fixture, "abc", false);
    common.appendRawBlock(&fixture, "de", true);
    common.appendChecksum(&fixture, "abcde");
    const frame_len = fixture.len;
    fixture.appendSlice("NEXT-FRAME");

    var runner: Runner(Support) = undefined;
    try runner.init(
        std.testing.allocator,
        fixture.bytes(),
        Support.initialState(),
        &.{},
        0,
        .{},
        9,
        2,
    );
    defer runner.deinit();
    try runner.run();
    try std.testing.expectEqualStrings("abcde", runner.output.items);
    try std.testing.expectEqual(frame_len, try runner.executor.frameEndOffset());
    try runner.expectGuards();
    try runner.expectHistory("abcde", 0);
}

fn magiclessFrame(comptime Support: type) !void {
    var fixture: common.Fixture = .{};
    common.appendHeader(&fixture, 0x04, 0x00, 0, null);
    common.appendRawBlock(&fixture, "abc", false);
    common.appendRleBlock(&fixture, 'm', 2, true);
    common.appendChecksum(&fixture, "abcmm");

    const expected = try oracle(Support, fixture.bytes());
    defer std.testing.allocator.free(expected);
    try std.testing.expectEqualStrings("abcmm", expected);

    const bytes = fixture.bytes()[4..];
    var runner: Runner(Support) = undefined;
    try runner.initWithFormat(
        .magicless,
        std.testing.allocator,
        bytes,
        Support.initialState(),
        &.{},
        0,
        .{},
        9,
        2,
    );
    defer runner.deinit();
    try runner.run();
    try std.testing.expectEqualSlices(u8, expected, runner.output.items);
    try std.testing.expectEqual(
        @as(u64, @intCast(bytes.len)),
        try runner.executor.frameEndOffset(),
    );
    try runner.expectGuards();
    try runner.expectHistory(expected, 0);
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
        inline for (.{ 9, 10, 17 }) |page_len|
            try expectDecode(
                Support,
                bytes,
                Support.initialState(),
                &.{},
                0,
                .{},
                expected,
                page_len,
                97,
            );
    }
}

pub fn contracts(comptime Support: type) !void {
    try mixedRawRle(Support);
    try emptyLastRle(Support);
    try checksumFooter(Support);
    try contentSizeChecks(Support);
    try dictionaryIdPolicy(Support);
    try trailingSuffix(Support);
    try magiclessFrame(Support);
    try compressedFixtures(Support);
}
