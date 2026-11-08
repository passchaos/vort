const std = @import("std");
const common = @import("common.zig");
const literal_stream = common.literal_stream;

fn happyPagesAndShortReads() !void {
    var bytes: [43]u8 = undefined;
    for (&bytes, 0..) |*byte, index| byte.* = @truncate(index * 29 + 7);

    inline for (.{ 9, 10, 17 }) |page_len| {
        var source = common.TrackingSource{ .bytes = &bytes, .max_chunk = 2 };
        const decoded = try common.layout(&source, .raw, bytes.len);
        var page_storage: [19]u8 = @splat(0x73);
        page_storage[0] = 0x39;
        page_storage[page_len + 1] = 0xc6;
        var output_storage: [45]u8 = @splat(0xd8);
        output_storage[0] = 0x51;
        output_storage[output_storage.len - 1] = 0xae;
        const output = output_storage[1 .. output_storage.len - 1];
        var stream = try literal_stream.init(
            common.DummyCodec,
            decoded,
            null,
            page_storage[1 .. page_len + 1],
        );
        try std.testing.expectEqual(literal_stream.Kind.raw, std.meta.activeTag(stream));
        try std.testing.expectEqual(literal_stream.Kind.raw, stream.snapshot().kind);
        try std.testing.expect(stream.snapshot().huffman == null);

        var offset: usize = 0;
        const chunks = [_]usize{ 1, 0, 7, 3, 11, 2, 19 };
        for (chunks) |requested| {
            if (offset == output.len) break;
            const amount = @min(requested, output.len - offset);
            var committed: usize = 99;
            try stream.copyNext(output[offset..][0..amount], &committed);
            try std.testing.expectEqual(amount, committed);
            offset += amount;
        }
        if (offset != output.len) {
            var committed: usize = 99;
            try stream.copyNext(output[offset..], &committed);
            try std.testing.expectEqual(output.len - offset, committed);
        }
        try stream.expectEnd();
        try stream.expectEnd();
        try std.testing.expect(stream.isFinished());
        try std.testing.expectEqual(bytes.len, stream.snapshot().decoded);
        try std.testing.expectEqual(@as(usize, 0), stream.remaining());
        try std.testing.expectEqualSlices(u8, &bytes, output);
        try std.testing.expect(source.max_requested <= page_len);
        try common.expectPageCanaries(&page_storage, page_len);
        try common.expectOutputCanaries(&output_storage);
    }
}

fn refillFailuresPublishOnlyCompletePages() !void {
    var bytes: [29]u8 = undefined;
    for (&bytes, 0..) |*byte, index| byte.* = @truncate(index * 17 + 3);

    inline for (.{ common.Mode.zero, .excessive, .fail }) |mode| {
        var source = common.TrackingSource{
            .bytes = &bytes,
            .max_chunk = 3,
            .mode = mode,
            .fault_call = 5,
        };
        const decoded = try common.layout(&source, .raw, bytes.len);
        var page_storage: [11]u8 = @splat(0x42);
        page_storage[0] = 0x39;
        page_storage[10] = 0xc6;
        var output_storage: [31]u8 = @splat(0xcc);
        output_storage[0] = 0x51;
        output_storage[output_storage.len - 1] = 0xae;
        const output = output_storage[1 .. output_storage.len - 1];
        var stream = try literal_stream.init(
            common.DummyCodec,
            decoded,
            null,
            page_storage[1..10],
        );

        var committed: usize = 99;
        try std.testing.expectError(
            common.expectedError(mode),
            stream.copyNext(output, &committed),
        );
        try std.testing.expectEqual(@as(usize, 9), committed);
        try std.testing.expectEqual(@as(usize, 9), stream.snapshot().decoded);
        try std.testing.expectEqualSlices(u8, bytes[0..9], output[0..9]);
        for (output[9..]) |byte| try std.testing.expectEqual(@as(u8, 0xcc), byte);
        try common.expectPageCanaries(&page_storage, 9);
        try common.expectOutputCanaries(&output_storage);

        source.clearFault();
        try stream.copyNext(output[committed..], &committed);
        try std.testing.expectEqual(@as(usize, 20), committed);
        try std.testing.expectEqualSlices(u8, &bytes, output);
        try stream.expectEnd();
        try common.expectPageCanaries(&page_storage, 9);
        try common.expectOutputCanaries(&output_storage);
    }
}

fn cachedTailCommitsBeforeNextPageFailure() !void {
    const bytes = "0123456789abcdefghij";
    var source = common.TrackingSource{ .bytes = bytes, .max_chunk = 3 };
    const decoded = try common.layout(&source, .raw, bytes.len);
    var page: [9]u8 = undefined;
    var stream = try literal_stream.init(common.DummyCodec, decoded, null, &page);
    var prefix: [4]u8 = undefined;
    var committed: usize = 99;
    try stream.copyNext(&prefix, &committed);
    try std.testing.expectEqual(@as(usize, 4), committed);
    try std.testing.expectEqualStrings(bytes[0..4], &prefix);

    source.mode = .fail;
    source.fault_call = source.calls + 1;
    var suffix: [bytes.len - prefix.len]u8 = @splat(0xa5);
    try std.testing.expectError(error.SourceReadFailed, stream.copyNext(&suffix, &committed));
    try std.testing.expectEqual(@as(usize, 5), committed);
    try std.testing.expectEqualStrings(bytes[4..9], suffix[0..5]);
    for (suffix[5..]) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
    try std.testing.expectEqual(@as(usize, 9), stream.snapshot().decoded);

    source.clearFault();
    try stream.copyNext(suffix[5..], &committed);
    try std.testing.expectEqual(suffix.len - 5, committed);
    try std.testing.expectEqualStrings(bytes[4..], &suffix);
}

fn wideOffsetsAliasAndTerminalCalls() !void {
    const base = @as(u64, std.math.maxInt(u32)) + 0x12_345;
    const bytes = "literal bytes beyond four gibibytes";
    var source = common.TrackingSource{ .bytes = bytes, .base_offset = base };
    const decoded = try common.layout(&source, .raw, bytes.len);
    var page_storage: [19]u8 = @splat(0x55);
    page_storage[0] = 0x39;
    page_storage[18] = 0xc6;
    var stream = try literal_stream.init(
        common.DummyCodec,
        decoded,
        null,
        page_storage[1..18],
    );

    const before = stream.snapshot();
    var committed: usize = 99;
    try std.testing.expectError(
        error.InvalidStreamState,
        stream.copyNext(page_storage[2..7], &committed),
    );
    try std.testing.expectEqual(@as(usize, 0), committed);
    try std.testing.expectEqualDeep(before, stream.snapshot());
    try std.testing.expectEqual(@as(usize, 0), source.calls);
    try std.testing.expectError(error.CorruptFrame, stream.expectEnd());
    try std.testing.expectEqualDeep(before, stream.snapshot());

    var output: [bytes.len]u8 = undefined;
    try stream.copyNext(&output, &committed);
    try std.testing.expectEqual(bytes.len, committed);
    try std.testing.expectEqualStrings(bytes, &output);
    try std.testing.expect(source.min_offset.? >= base);
    try stream.expectEnd();
    try common.expectPageCanaries(&page_storage, 17);

    var extra: [1]u8 = .{0xa5};
    try std.testing.expectError(error.CorruptFrame, stream.copyNext(&extra, &committed));
    try std.testing.expectEqual(@as(usize, 0), committed);
    try std.testing.expectEqual(@as(u8, 0xa5), extra[0]);
}

fn initCombinationAndMinimumPageContracts() !void {
    var source = common.TrackingSource{ .bytes = "raw" };
    var decoded = try common.layout(&source, .raw, source.bytes.len);
    var page: [9]u8 = undefined;
    try std.testing.expectError(
        error.OutputTooSmall,
        literal_stream.init(common.DummyCodec, decoded, null, page[0..8]),
    );
    try std.testing.expectEqual(@as(usize, 0), source.calls);

    const pending = common.source_huffman.Prepared(common.DummyCodec){
        .table = 0,
        .origin = .new_tree,
        .description = null,
        .description_bytes = 0,
        .replace_on_block_success = true,
    };
    try std.testing.expectError(
        error.CorruptFrame,
        literal_stream.init(common.DummyCodec, decoded, &pending, &page),
    );
    decoded.streams = .{ .one = decoded.literal_payload };
    try std.testing.expectError(
        error.CorruptFrame,
        literal_stream.init(common.DummyCodec, decoded, null, &page),
    );
    try std.testing.expectEqual(@as(usize, 0), source.calls);
}

fn emptyAndProgressAliasContracts() !void {
    var empty_source = common.TrackingSource{ .bytes = "" };
    const empty_layout = try common.layout(&empty_source, .raw, 0);
    var empty_page: [9]u8 = undefined;
    var empty = try literal_stream.init(common.DummyCodec, empty_layout, null, &empty_page);
    try std.testing.expectEqual(@as(usize, 0), empty.remaining());
    try std.testing.expect(!empty.isFinished());
    var committed: usize = 99;
    try empty.copyNext(empty_page[0..0], &committed);
    try std.testing.expectEqual(@as(usize, 0), committed);
    try std.testing.expect(empty.isFinished());

    var source = common.TrackingSource{ .bytes = "progress aliases" };
    const decoded = try common.layout(&source, .raw, source.bytes.len);
    var page: [16]u8 align(@alignOf(usize)) = @splat(0x5a);
    var stream = try literal_stream.init(common.DummyCodec, decoded, null, page[0..9]);
    var output: [16]u8 align(@alignOf(usize)) = @splat(0xa5);
    const before = stream.snapshot();

    const dest_progress: *usize = @ptrCast(&output);
    dest_progress.* = 0x1122;
    try std.testing.expectError(
        error.InvalidStreamState,
        stream.copyNext(output[0..1], dest_progress),
    );
    try std.testing.expectEqual(@as(usize, 0x1122), dest_progress.*);
    try std.testing.expectEqualDeep(before, stream.snapshot());

    const page_progress: *usize = @ptrCast(&page);
    page_progress.* = 0x3344;
    try std.testing.expectError(
        error.InvalidStreamState,
        stream.copyNext(output[8..9], page_progress),
    );
    try std.testing.expectEqual(@as(usize, 0x3344), page_progress.*);
    try std.testing.expectEqualDeep(before, stream.snapshot());

    var stream_committed: usize = 99;
    const stream_dest = std.mem.asBytes(&stream)[0..1];
    try std.testing.expectError(
        error.InvalidStreamState,
        stream.copyNext(stream_dest, &stream_committed),
    );
    try std.testing.expectEqual(@as(usize, 0), stream_committed);
    try std.testing.expectEqualDeep(before, stream.snapshot());

    const stream_progress: *usize = @ptrCast(@alignCast(std.mem.asBytes(&stream)));
    try std.testing.expectError(
        error.InvalidStreamState,
        stream.copyNext(output[8..9], stream_progress),
    );
    try std.testing.expectEqualDeep(before, stream.snapshot());
    try std.testing.expectEqual(@as(usize, 0), source.calls);
}

pub fn contracts() !void {
    try happyPagesAndShortReads();
    try refillFailuresPublishOnlyCompletePages();
    try cachedTailCommitsBeforeNextPageFailure();
    try wideOffsetsAliasAndTerminalCalls();
    try initCombinationAndMinimumPageContracts();
    try emptyAndProgressAliasContracts();
}
