const std = @import("std");
const common = @import("stream_cursor_tests/common.zig");

const allocator = std.testing.allocator;
const Count = common.core.StreamCount;
const Format = common.source_frame.FrameFormat;
const wide_window = 1152;
const dictionary_id = 7;
const dictionary_content = "dict";
const wide_payload = "large";
const narrow_payload = "one";
const canary = '!';
const block_header_len = 3;
// A compressed block with five RLE 'z' literals and zero sequences.
const compressed_payload = &[_]u8{ 0x29, 'z', 0x00 };

const Storage = struct {
    history: [wide_window + dictionary_content.len]u8 = @splat(0xa7),
    staging: [wide_window]u8 = @splat(0xb8),
    literal_page: [17]u8 = @splat(0xc9),
    sequence_page: [17]u8 = @splat(0xda),

    fn workspace(self: *Storage, comptime Support: type) Support.Workspace {
        return .{
            .history = &self.history,
            .staging = &self.staging,
            .literal_page = &self.literal_page,
            .sequence_page = &self.sequence_page,
        };
    }
};

fn span(start: usize, len: usize) common.Span {
    return .{ .offset = @intCast(start), .len = @intCast(len) };
}

// The window descriptor advertises 1024 + 1024/8 bytes. The descriptor
// declares a one-byte dictionary ID but no content size.
fn appendWideFrame(fixture: *common.Fixture, format: Format) usize {
    switch (format) {
        .standard => common.appendDataHeader(fixture, 0x01, 0x01, null),
        .magicless => common.appendMagiclessHeader(fixture, 0x01, 0x01, null),
    }
    fixture.appendByte(dictionary_id);
    const blocks_start = fixture.len;
    common.appendRawBlock(fixture, wide_payload, true);
    return blocks_start;
}

fn frameAndStreamWindowAdmission(comptime Support: type) !void {
    try std.testing.expectEqual(std.math.maxInt(Count), (Support.Options{}).max_window_size);
    try std.testing.expectEqual(std.math.maxInt(Count), (Support.StreamOptions{}).max_window_size);
    for ([_]Format{ .standard, .magicless }) |format| {
        var fixture: common.Fixture = .{};
        const header_end = appendWideFrame(&fixture, format);
        const forbidden = [_]common.Span{span(header_end, fixture.len - header_end)};
        var source = common.TrackingSource{ .bytes = fixture.bytes(), .forbidden = &forbidden };
        const view = source.source();
        const frame_options: Support.Options = .{ .format = format, .max_window_size = wide_window - 1 };
        const stream_options: Support.StreamOptions = .{ .format = format, .max_window_size = wide_window - 1 };
        var storage: Storage = .{};
        const before = storage;
        const workspace = storage.workspace(Support);
        var output: [wide_payload.len]u8 = @splat(canary);
        var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0, .resize_fail_index = 0 });
        const no_alloc = failing.allocator();
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(allocator);
        try out.ensureTotalCapacityPrecise(allocator, "seed".len + 1);
        out.appendSliceAssumeCapacity("seed");
        @memset(out.unusedCapacitySlice(), canary);
        const old_ptr = out.items.ptr;
        const old_capacity = out.capacity;

        // An absent dictionary and an unreadable block header must not mask
        // the window limit. No decoder scratch, output or allocator is needed.
        try std.testing.expectError(error.OutputLimitExceeded, Support.inspect(view, frame_options));
        try std.testing.expectError(error.OutputLimitExceeded, Support.decodedSize(view, frame_options));
        try std.testing.expectError(error.OutputLimitExceeded, Support.decodeInto(view, &output, workspace, frame_options));
        try std.testing.expectError(error.OutputLimitExceeded, Support.decodeAppend(no_alloc, view, workspace, &out, frame_options));
        try std.testing.expectError(error.OutputLimitExceeded, Support.decodeAlloc(no_alloc, view, workspace, frame_options));
        try std.testing.expectError(error.OutputLimitExceeded, Support.inspectStream(view, stream_options));
        try std.testing.expectError(error.OutputLimitExceeded, Support.decodeStreamInto(view, &output, workspace, stream_options));
        try std.testing.expectError(error.OutputLimitExceeded, Support.decodeStreamAppend(no_alloc, view, workspace, &out, stream_options));
        try std.testing.expectError(error.OutputLimitExceeded, Support.decodeStreamAlloc(no_alloc, view, workspace, stream_options));
        try std.testing.expect(!source.forbidden_read);
        try std.testing.expect(!failing.has_induced_failure);
        try std.testing.expectEqualDeep(before, storage);
        try std.testing.expect(std.mem.allEqual(u8, &output, canary));
        try std.testing.expectEqual(old_ptr, out.items.ptr);
        try std.testing.expectEqual(old_capacity, out.capacity);
        try std.testing.expectEqualStrings("seed", out.items);
        try std.testing.expect(std.mem.allEqual(u8, out.unusedCapacitySlice(), canary));

        // The last header byte (dictionary ID) is read before window admission.
        const last_header_byte = [_]common.Span{span(header_end - 1, 1)};
        source.forbidden = &last_header_byte;
        try std.testing.expectError(error.SourceReadFailed, Support.inspect(view, frame_options));
        try std.testing.expect(source.forbidden_read);
        source.forbidden = &forbidden;
        source.forbidden_read = false;
        try std.testing.expectError(error.NeedDictionary, Support.inspect(view, .{ .format = format, .max_window_size = wide_window }));
        try std.testing.expect(!source.forbidden_read);

        source.forbidden = &.{};
        const dictionary = Support.DecodeDictionary.init(dictionary_id, dictionary_content);
        const info = try Support.inspect(view, .{ .format = format, .dictionary = dictionary });
        try std.testing.expectEqual(@as(u64, wide_window), info.window_size);
        try std.testing.expectEqual(@as(?Count, wide_payload.len), info.decoded_size);
        const result = try Support.decodeInto(view, &output, workspace, .{
            .format = format,
            .dictionary = dictionary,
            .max_window_size = wide_window,
        });
        try std.testing.expectEqual(@as(Count, wide_payload.len), result.decoded_len);
        try std.testing.expectEqualStrings(wide_payload, &output);
        @memset(&output, canary);
        const stream_result = try Support.decodeStreamInto(view, &output, workspace, .{
            .format = format,
            .dictionary = dictionary,
        });
        try std.testing.expectEqual(@as(usize, 1), stream_result.data_frames);
        try std.testing.expectEqualStrings(wide_payload, &output);
    }
}

const TwoMembers = struct {
    fixture: common.Fixture,
    skip_offset: usize,
    wide_offset: usize,
    wide_blocks: usize,

    fn init() TwoMembers {
        var fixture: common.Fixture = .{};
        common.appendDataHeader(&fixture, 0x20, null, narrow_payload.len);
        common.appendRawBlock(&fixture, narrow_payload, true);
        const skip_offset = common.appendSkippable(&fixture, 3, "skip");
        const wide_offset = fixture.len;
        const wide_blocks = appendWideFrame(&fixture, .standard);
        return .{ .fixture = fixture, .skip_offset = skip_offset, .wide_offset = wide_offset, .wide_blocks = wide_blocks };
    }

    fn forbidden(self: *const TwoMembers) [2]common.Span {
        return .{
            span(self.skip_offset + 8, "skip".len),
            span(self.wide_blocks, self.fixture.len - self.wide_blocks),
        };
    }
};

fn windowAfterValidMember(comptime Support: type) !void {
    const members = TwoMembers.init();
    const forbidden = members.forbidden();
    var source = common.TrackingSource{ .bytes = members.fixture.bytes(), .forbidden = &forbidden };
    const view = source.source();
    var storage: Storage = .{};
    const workspace = storage.workspace(Support);
    const options: Support.StreamOptions = .{ .max_window_size = narrow_payload.len };
    var output: [narrow_payload.len + wide_payload.len]u8 = @splat(canary);

    try std.testing.expectError(error.OutputLimitExceeded, Support.inspectStream(view, options));
    try std.testing.expectError(error.OutputLimitExceeded, Support.decodeStreamInto(view, &output, workspace, options));
    try std.testing.expectEqualStrings(narrow_payload, output[0..narrow_payload.len]);
    try std.testing.expect(std.mem.allEqual(u8, output[narrow_payload.len..], canary));

    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try out.ensureTotalCapacityPrecise(allocator, "seed".len + narrow_payload.len);
    out.appendSliceAssumeCapacity("seed");
    var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0, .resize_fail_index = 0 });
    try std.testing.expectError(error.OutputLimitExceeded, Support.decodeStreamAppend(failing.allocator(), view, workspace, &out, options));
    try std.testing.expectEqualStrings("seed" ++ narrow_payload, out.items);
    try std.testing.expect(!failing.has_induced_failure);
    // Alloc is allowed to allocate for the first member, but must release the
    // committed prefix on error (checked by the testing allocator).
    try std.testing.expectError(error.OutputLimitExceeded, Support.decodeStreamAlloc(allocator, view, workspace, options));
    try std.testing.expect(!source.forbidden_read);
}

fn expectPending(cursor: anytype, offset: usize) !void {
    try std.testing.expect(cursor.pending());
    try std.testing.expectEqual(@as(u64, @intCast(offset)), cursor.offset());
    try std.testing.expectEqual(@as(Count, narrow_payload.len), cursor.totalDecoded());
}

fn cursorWindowAdmission(comptime Support: type) !void {
    const members = TwoMembers.init();
    const forbidden = members.forbidden();
    const payloads = [_]common.Span{ forbidden[0], span(members.wide_blocks + block_header_len, wide_payload.len) };
    const dictionary = Support.DecodeDictionary.init(dictionary_id, dictionary_content);
    inline for (.{ .decode, .inspect, .skip }) |action| {
        var source = common.TrackingSource{ .bytes = members.fixture.bytes(), .forbidden = &forbidden };
        var cursor = try Support.StreamCursor.init(source.source(), .standard);
        var storage: Storage = .{};
        const workspace = storage.workspace(Support);
        _ = (try cursor.next()) orelse return error.TestUnexpectedResult;
        var prefix: [narrow_payload.len]u8 = undefined;
        _ = try cursor.decodeInto(&prefix, workspace, .{ .max_window_size = narrow_payload.len });
        try std.testing.expectEqualStrings(narrow_payload, &prefix);
        const skipped = (try cursor.next()) orelse return error.TestUnexpectedResult;
        try std.testing.expectEqual(@as(u4, 3), skipped.skippable.skippable_id);
        const pending = (try cursor.next()) orelse return error.TestUnexpectedResult;
        try std.testing.expectEqual(@as(u64, wide_window), pending.data.window_size);
        try std.testing.expectEqual(@as(u32, dictionary_id), pending.data.dictionary_id);
        try expectPending(&cursor, members.wide_offset);

        const before = storage;
        var output: [wide_payload.len]u8 = @splat(canary);
        const capped: Support.StreamOptions = .{ .max_window_size = wide_window - 1 };
        const calls = source.calls;
        try std.testing.expectError(error.OutputLimitExceeded, cursor.inspectPending(capped));
        try expectPending(&cursor, members.wide_offset);
        try std.testing.expectError(error.OutputLimitExceeded, cursor.decodeInto(&output, workspace, capped));
        try expectPending(&cursor, members.wide_offset);
        try std.testing.expectEqual(calls, source.calls);
        try std.testing.expect(!source.forbidden_read);
        try std.testing.expectEqualDeep(before, storage);
        try std.testing.expect(std.mem.allEqual(u8, &output, canary));

        const exact: Support.StreamOptions = .{ .max_window_size = wide_window, .dictionary = dictionary };
        source.forbidden = &payloads;
        switch (action) {
            .decode => {
                source.forbidden = payloads[0..1];
                const result = try cursor.decodeInto(&output, workspace, exact);
                try std.testing.expectEqual(@as(Count, wide_payload.len), result.decoded_len);
                try std.testing.expectEqualStrings(wide_payload, &output);
            },
            .inspect => {
                const info = try cursor.inspectPending(exact);
                try std.testing.expectEqual(@as(?Count, wide_payload.len), info.decoded_size);
            },
            .skip => {
                const info = try cursor.skipData(.{ .max_window_size = 0, .frame_decoded_max = 0, .total_decoded_max = 0 });
                try std.testing.expectEqual(@as(u32, dictionary_id), info.dictionary_id);
            },
            else => unreachable,
        }
        try std.testing.expect(!source.forbidden_read);
        try std.testing.expect(!cursor.pending());
        try std.testing.expectEqual(@as(u64, @intCast(members.fixture.len)), cursor.offset());
        try std.testing.expectEqual(@as(Count, narrow_payload.len + if (action == .decode) wide_payload.len else 0), cursor.totalDecoded());
        try std.testing.expect((try cursor.next()) == null);
    }
}

fn appendCompressed(fixture: *common.Fixture, last: bool) void {
    common.appendBlockHeader(fixture, 2, compressed_payload.len, last);
    fixture.appendSlice(compressed_payload);
}

fn streamLowerBoundAcrossUnknown(comptime Support: type) !void {
    var fixture: common.Fixture = .{};
    common.appendDataHeader(&fixture, 0x20, null, 3);
    const raw = span(fixture.len + block_header_len, 3);
    common.appendRawBlock(&fixture, "abc", true);
    common.appendDataHeader(&fixture, 0, 0, null);
    const compressed = span(fixture.len + block_header_len, compressed_payload.len);
    appendCompressed(&fixture, true);
    common.appendDataHeader(&fixture, 0, 0, null);
    const rle = span(fixture.len + block_header_len, 1);
    common.appendRleBlock(&fixture, 'r', 4, true);

    var source = common.TrackingSource{ .bytes = fixture.bytes(), .forbidden = &.{ raw, compressed, rle } };
    const view = source.source();
    // The unknown-sized member contributes zero here, but must not zero or
    // disable accumulation of the exact sizes before and after it.
    try std.testing.expectError(error.OutputLimitExceeded, Support.inspectStream(view, .{ .frame_decoded_max = 4, .total_decoded_max = 6 }));
    const info = try Support.inspectStream(view, .{ .frame_decoded_max = 4, .total_decoded_max = 7 });
    try std.testing.expectEqual(@as(?Count, null), info.total_decoded);
    try std.testing.expectEqual(@as(usize, 3), info.data_frames);
    try std.testing.expectEqual(@as(u64, @intCast(fixture.len)), info.stream_end_offset);
    try std.testing.expect(!source.forbidden_read);
}

fn appendMixedBlocks(fixture: *common.Fixture) [3]common.Span {
    const raw = span(fixture.len + block_header_len, 3);
    common.appendRawBlock(fixture, "abc", false);
    const compressed = span(fixture.len + block_header_len, compressed_payload.len);
    appendCompressed(fixture, false);
    const rle = span(fixture.len + block_header_len, 1);
    common.appendRleBlock(fixture, 'r', 4, true);
    return .{ raw, compressed, rle };
}

fn mixedFrameLowerBound(comptime Support: type) !void {
    var fixture: common.Fixture = .{};
    common.appendDataHeader(&fixture, 0, 0, null);
    const first_payloads = appendMixedBlocks(&fixture);
    const first_end = fixture.len;
    common.appendDataHeader(&fixture, 0, 0, null);
    const second_payloads = appendMixedBlocks(&fixture);
    const payloads = first_payloads ++ second_payloads;

    var single = common.TrackingSource{ .bytes = fixture.bytes()[0..first_end], .forbidden = &first_payloads };
    try std.testing.expectError(error.OutputLimitExceeded, Support.inspect(single.source(), .{ .frame_decoded_max = 6 }));
    const frame = try Support.inspect(single.source(), .{ .frame_decoded_max = 7 });
    try std.testing.expectEqual(@as(?Count, null), frame.decoded_size);
    try std.testing.expectEqual(@as(u64, @intCast(first_end)), frame.frame_end_offset);
    try std.testing.expect(!single.forbidden_read);

    var source = common.TrackingSource{ .bytes = fixture.bytes(), .forbidden = &payloads };
    const view = source.source();
    try std.testing.expectError(error.OutputLimitExceeded, Support.inspectStream(view, .{ .frame_decoded_max = 6 }));
    try std.testing.expectError(error.OutputLimitExceeded, Support.inspectStream(view, .{ .frame_decoded_max = 7, .total_decoded_max = 13 }));
    const stream = try Support.inspectStream(view, .{ .frame_decoded_max = 7, .total_decoded_max = 14 });
    try std.testing.expectEqual(@as(?Count, null), stream.total_decoded);
    try std.testing.expectEqual(@as(usize, 2), stream.data_frames);
    try std.testing.expectEqual(@as(u64, @intCast(fixture.len)), stream.stream_end_offset);
    try std.testing.expect(!source.forbidden_read);

    // All individual block lengths fit, but the sum of the raw and RLE
    // decoded lengths alone is greater than the declared content size.
    fixture.len = 0;
    common.appendDataHeader(&fixture, 0x20, null, 6);
    const mismatch_payloads = appendMixedBlocks(&fixture);
    var mismatch = common.TrackingSource{ .bytes = fixture.bytes(), .forbidden = &mismatch_payloads };
    try std.testing.expectError(error.SizeMismatch, Support.inspect(mismatch.source(), .{}));
    try std.testing.expectError(error.SizeMismatch, Support.inspectStream(mismatch.source(), .{}));
    try std.testing.expect(!mismatch.forbidden_read);
}

fn frameCountWirePrecedence(comptime Support: type) !void {
    const cases: []const struct { format: Format, bytes: []const u8, err: anyerror } = &.{
        .{ .format = .standard, .bytes = "not zstd", .err = error.InvalidMagic },
        .{ .format = .standard, .bytes = "\x28\xb5\x2f", .err = error.TruncatedFrame },
        .{ .format = .standard, .bytes = "\x28\xb5\x2f\xfd\x08", .err = error.CorruptFrame },
        .{ .format = .standard, .bytes = "\x28\xb5\x2f\xfd\x20", .err = error.TruncatedFrame },
        .{ .format = .magicless, .bytes = "\x08", .err = error.CorruptFrame },
        .{ .format = .magicless, .bytes = "\x20", .err = error.TruncatedFrame },
        .{ .format = .standard, .bytes = "\x50\x2a\x4d\x18\x03\x00\x00", .err = error.TruncatedFrame },
        .{ .format = .standard, .bytes = "\x50\x2a\x4d\x18\x03\x00\x00\x00", .err = error.OutputLimitExceeded },
    };
    for (cases) |case| {
        var source = common.TrackingSource{ .bytes = case.bytes };
        const range = try common.streamRange(&source);
        var cursor = common.stream_cursor.Cursor.initWithFrameLimit(range, case.format, 0);
        try std.testing.expectError(case.err, cursor.next());
        try std.testing.expectEqual(@as(u64, 0), cursor.offset());
        try std.testing.expect(!cursor.pending());
        try std.testing.expectError(case.err, Support.inspectStream(source.source(), .{
            .format = case.format,
            .max_frames = 0,
        }));
    }
    // The unlimited parser still checks the advertised skippable payload range.
    var truncated = common.TrackingSource{ .bytes = cases[cases.len - 1].bytes };
    try std.testing.expectError(error.TruncatedFrame, common.source_frame.parseStreamElementHeader(
        try common.streamRange(&truncated),
        .standard,
    ));
    var empty = common.TrackingSource{ .bytes = "" };
    const info = try Support.inspectStream(empty.source(), .{ .max_frames = 0 });
    try std.testing.expectEqual(@as(u64, 0), info.stream_end_offset);
    try std.testing.expectEqual(@as(usize, 0), empty.calls);
}

fn streamFrameCountAdmission(comptime Support: type) !void {
    try std.testing.expectEqual(std.math.maxInt(Count), (Support.StreamOptions{}).max_frames);
    var fixture: common.Fixture = .{};
    common.appendDataHeader(&fixture, 0x20, null, narrow_payload.len);
    common.appendRawBlock(&fixture, narrow_payload, true);
    const skip_offset = common.appendSkippable(&fixture, 3, "skip");
    const empty_skip = common.appendSkippable(&fixture, 4, "");
    const empty_data = fixture.len;
    common.appendDataHeader(&fixture, 0x20, null, 0);
    common.appendRawBlock(&fixture, "", true);
    const wide_start = fixture.len;
    const wide_blocks = appendWideFrame(&fixture, .standard);
    const forbidden = [_]common.Span{
        span(skip_offset + 8, "skip".len),
        span(wide_blocks, fixture.len - wide_blocks),
    };
    var source = common.TrackingSource{ .bytes = fixture.bytes(), .forbidden = &forbidden };
    // Empty skippable and data frames each need a slot. The limited traversal
    // refuses at their headers, not after their payload or block is handled.
    var cursor = try Support.StreamCursor.initWithFrameLimit(source.source(), .standard, 2);
    _ = try cursor.next();
    _ = try cursor.skipData(.{ .max_frames = 0 });
    _ = try cursor.next();
    try std.testing.expectError(error.OutputLimitExceeded, cursor.next());
    try std.testing.expectEqual(@as(u64, @intCast(empty_skip)), cursor.offset());
    cursor = try Support.StreamCursor.initWithFrameLimit(source.source(), .standard, 3);
    _ = try cursor.next();
    _ = try cursor.skipData(.{ .max_frames = 0 });
    _ = try cursor.next();
    _ = try cursor.next();
    try std.testing.expectError(error.OutputLimitExceeded, cursor.next());
    try std.testing.expectEqual(@as(u64, @intCast(empty_data)), cursor.offset());

    const options: Support.StreamOptions = .{ .max_frames = 4 };
    var prefix_source = common.TrackingSource{ .bytes = fixture.bytes()[0..wide_start], .forbidden = forbidden[0..1] };
    const info = try Support.inspectStream(prefix_source.source(), options);
    try std.testing.expectEqual(@as(usize, 2), info.data_frames);
    try std.testing.expectEqual(@as(usize, 2), info.skippable_frames);
    try std.testing.expectEqual(@as(?Count, narrow_payload.len), info.total_decoded);
    try std.testing.expectEqual(@as(u64, @intCast(wide_start)), info.stream_end_offset);
    try std.testing.expect(!prefix_source.forbidden_read);

    // A valid header advertising an unavailable dictionary must be refused
    // before either dictionary lookup or any read in the rejected frame body.
    const view = source.source();
    var storage: Storage = .{};
    const workspace = storage.workspace(Support);
    var output: [narrow_payload.len + wide_payload.len]u8 = @splat(canary);
    try std.testing.expectError(error.OutputLimitExceeded, Support.inspectStream(view, options));
    try std.testing.expectError(error.OutputLimitExceeded, Support.decodeStreamInto(view, &output, workspace, options));
    try std.testing.expectEqualStrings(narrow_payload, output[0..narrow_payload.len]);
    try std.testing.expect(std.mem.allEqual(u8, output[narrow_payload.len..], canary));

    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try out.ensureTotalCapacityPrecise(allocator, "seed".len + narrow_payload.len);
    out.appendSliceAssumeCapacity("seed");
    var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0, .resize_fail_index = 0 });
    try std.testing.expectError(error.OutputLimitExceeded, Support.decodeStreamAppend(failing.allocator(), view, workspace, &out, options));
    try std.testing.expectEqualStrings("seed" ++ narrow_payload, out.items);
    try std.testing.expect(!failing.has_induced_failure);
    try std.testing.expectError(error.OutputLimitExceeded, Support.decodeStreamAlloc(allocator, view, workspace, options));
    try std.testing.expect(!source.forbidden_read);
}

fn magiclessCursorFrameCount(comptime Support: type) !void {
    var fixture: common.Fixture = .{};
    common.appendMagiclessHeader(&fixture, 0x20, null, narrow_payload.len);
    common.appendRawBlock(&fixture, narrow_payload, true);
    const wide_start = fixture.len;
    const wide_blocks = appendWideFrame(&fixture, .magicless);
    const forbidden = [_]common.Span{span(wide_blocks, fixture.len - wide_blocks)};
    var source = common.TrackingSource{ .bytes = fixture.bytes(), .forbidden = &forbidden };
    const view = source.source();
    try std.testing.expectError(error.OutputLimitExceeded, Support.inspectStream(view, .{ .format = .magicless, .max_frames = 1 }));

    inline for (.{ .decode, .inspect, .skip }) |action| {
        var cursor = try Support.StreamCursor.initWithFrameLimit(view, .magicless, 1);
        try std.testing.expectEqual(@as(?u64, narrow_payload.len), (try cursor.next()).?.data.content_size);
        try std.testing.expectError(error.InvalidStreamState, cursor.next());
        // A failed pending action leaves the frame pending and retryable.
        try std.testing.expectError(error.OutputLimitExceeded, cursor.inspectPending(.{ .frame_decoded_max = 0 }));
        try std.testing.expect(cursor.pending());
        switch (action) {
            .decode => {
                var storage: Storage = .{};
                var output: [narrow_payload.len]u8 = undefined;
                _ = try cursor.decodeInto(&output, storage.workspace(Support), .{ .max_frames = 0 });
                try std.testing.expectEqualStrings(narrow_payload, &output);
            },
            .inspect => _ = try cursor.inspectPending(.{ .max_frames = 0 }),
            .skip => _ = try cursor.skipData(.{ .max_frames = 0 }),
            else => unreachable,
        }
        for (0..2) |_| {
            try std.testing.expectError(error.OutputLimitExceeded, cursor.next());
            try std.testing.expectEqual(@as(u64, @intCast(wide_start)), cursor.offset());
            try std.testing.expect(!cursor.pending());
            try std.testing.expectEqual(@as(Count, if (action == .decode) narrow_payload.len else 0), cursor.totalDecoded());
        }
    }
    try std.testing.expect(!source.forbidden_read);
}

pub fn contracts(comptime Support: type) !void {
    try frameAndStreamWindowAdmission(Support);
    try windowAfterValidMember(Support);
    try cursorWindowAdmission(Support);
    try streamLowerBoundAcrossUnknown(Support);
    try mixedFrameLowerBound(Support);
    try frameCountWirePrecedence(Support);
    try streamFrameCountAdmission(Support);
    try magiclessCursorFrameCount(Support);
}
