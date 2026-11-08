const std = @import("std");
const common = @import("common.zig");
const source_huffman_literals = common.source_huffman_literals;

fn copyChunked(
    comptime Support: type,
    cursor: *source_huffman_literals.Cursor(Support.Codec),
    output: []u8,
    expected: []const u8,
) !void {
    var offset: usize = 0;
    try cursor.copyNext(output[0..0]);
    try std.testing.expectEqual(@as(usize, 0), cursor.snapshot().decoded);
    const chunks = [_]usize{ 1, 0, 2, 7, 3, 19, 5, 11 };
    var iteration: usize = 0;
    while (offset != output.len) : (iteration += 1) {
        const requested = chunks[iteration % chunks.len];
        const len = @min(output.len - offset, requested);
        try cursor.copyNext(output[offset..][0..len]);
        offset += len;
        try std.testing.expectEqualSlices(u8, expected[0..offset], output[0..offset]);
        try std.testing.expectEqual(offset, cursor.snapshot().decoded);
        if (len == 0 and output.len != 0) {
            const forced = @min(@as(usize, 1 + iteration % 13), output.len - offset);
            try cursor.copyNext(output[offset..][0..forced]);
            offset += forced;
        }
    }
}

fn decodeBlock(
    comptime Support: type,
    source: *common.TrackingSource,
    oracle: *Support.SliceOracle,
    committed: *?Support.Codec.Table,
    block_index: usize,
    page_len: usize,
    expected_stream_count: usize,
) !void {
    const block = try common.blockAt(source, block_index);
    try std.testing.expectEqual(.compressed, block.header.kind);
    const decoded = try common.prepareBlock(
        Support,
        block,
        if (committed.*) |*table| table else null,
    );
    const stream_count: usize = switch (decoded.layout.streams) {
        .one => 1,
        .four => 4,
        .none => 0,
    };
    try std.testing.expectEqual(expected_stream_count, stream_count);
    const expected = try common.expectedLiterals(
        Support,
        oracle,
        common.blockBytes(source, block),
        decoded.layout.regenerated_size,
    );
    defer std.testing.allocator.free(expected);

    const prepared_before = decoded.prepared;
    const committed_before = committed.*;
    var page_storage: [19]u8 = @splat(0x73);
    page_storage[0] = 0x39;
    page_storage[page_len + 1] = 0xc6;
    const output_storage = try std.testing.allocator.alloc(u8, expected.len + 2);
    defer std.testing.allocator.free(output_storage);
    @memset(output_storage, 0xdd);
    output_storage[0] = 0x51;
    output_storage[output_storage.len - 1] = 0xae;

    var cursor = try source_huffman_literals.init(
        Support.Codec,
        decoded.layout,
        &decoded.prepared,
        page_storage[1 .. page_len + 1],
    );
    try copyChunked(Support, &cursor, output_storage[1 .. output_storage.len - 1], expected);
    try cursor.expectEnd();
    try cursor.expectEnd();
    try cursor.copyNext(output_storage[1..1]);
    try std.testing.expectError(error.CorruptFrame, cursor.readSymbol());
    try std.testing.expect(cursor.isFinished());
    try std.testing.expectEqual(@as(usize, 0), cursor.remaining());
    try std.testing.expectEqual(page_len, cursor.snapshot().reader.page_capacity);
    try std.testing.expectEqualDeep(prepared_before, decoded.prepared);
    try std.testing.expectEqualDeep(committed_before, committed.*);
    try common.expectPageCanaries(&page_storage, page_len);
    try common.expectOutputCanaries(output_storage);
    try std.testing.expectEqualSlices(u8, expected, output_storage[1 .. output_storage.len - 1]);
    common.commitIfSuccessful(Support, &decoded.prepared, committed);
}

fn realFixtures(comptime Support: type) !void {
    inline for (.{ 9, 10, 17 }) |page_len| {
        {
            const bytes = try common.decodeHex(common.numbered_hex);
            defer std.testing.allocator.free(bytes);
            var source = common.TrackingSource{ .bytes = bytes };
            var oracle = Support.initSliceOracle();
            var committed: ?Support.Codec.Table = null;
            try decodeBlock(Support, &source, &oracle, &committed, 0, page_len, 1);
            try std.testing.expect(committed != null);
        }
        {
            const bytes = try common.decodeHex(common.repeat_hex);
            defer std.testing.allocator.free(bytes);
            var source = common.TrackingSource{ .bytes = bytes };
            var oracle = Support.initSliceOracle();
            var committed: ?Support.Codec.Table = null;
            try decodeBlock(Support, &source, &oracle, &committed, 0, page_len, 4);
            try decodeBlock(Support, &source, &oracle, &committed, 1, page_len, 4);
            const before_treeless = committed.?;
            try decodeBlock(Support, &source, &oracle, &committed, 2, page_len, 4);
            try std.testing.expectEqualDeep(before_treeless, committed.?);
        }
    }
}

fn exactFourStreamEnds(comptime Support: type) !void {
    const bytes = try common.decodeHex(common.repeat_hex);
    defer std.testing.allocator.free(bytes);
    var source = common.TrackingSource{ .bytes = bytes };
    const block = try common.blockAt(&source, 0);
    const decoded = try common.prepareBlock(Support, block, null);
    var oracle = Support.initSliceOracle();
    const expected = try common.expectedLiterals(
        Support,
        &oracle,
        common.blockBytes(&source, block),
        decoded.layout.regenerated_size,
    );
    defer std.testing.allocator.free(expected);
    const segment_len = (expected.len + 3) / 4;
    const output = try std.testing.allocator.alloc(u8, expected.len);
    defer std.testing.allocator.free(output);
    var page: [10]u8 = undefined;
    var cursor = try source_huffman_literals.init(
        Support.Codec,
        decoded.layout,
        &decoded.prepared,
        &page,
    );
    var offset: usize = 0;
    for (0..4) |stream_index| {
        const end = if (stream_index == 3) expected.len else segment_len * (stream_index + 1);
        try cursor.copyNext(output[offset..end]);
        try std.testing.expectEqualSlices(u8, expected[offset..end], output[offset..end]);
        const snapshot = cursor.snapshot();
        const expected_index: u2 = @intCast(if (stream_index == 3) 3 else stream_index + 1);
        const expected_end = if (stream_index >= 2)
            expected.len
        else
            segment_len * (stream_index + 2);
        try std.testing.expectEqual(expected_index, snapshot.stream_index);
        try std.testing.expectEqual(expected_end, snapshot.segment_end);
        try std.testing.expectEqual(stream_index == 3, snapshot.finished);
        try cursor.copyNext(output[end..end]);
        offset = end;
    }
    try std.testing.expect(cursor.snapshot().finished);

    // One non-empty output request deliberately crosses from stream 0 into
    // stream 1; transition/refill is part of that same copy transaction.
    var crossing_page: [10]u8 = undefined;
    var crossing = try source_huffman_literals.init(
        Support.Codec,
        decoded.layout,
        &decoded.prepared,
        &crossing_page,
    );
    const crossing_output = try std.testing.allocator.alloc(u8, expected.len);
    defer std.testing.allocator.free(crossing_output);
    try crossing.copyNext(crossing_output[0 .. segment_len + 2]);
    try std.testing.expectEqual(@as(u2, 1), crossing.snapshot().stream_index);
    try crossing.copyNext(crossing_output[segment_len + 2 ..]);
    try std.testing.expectEqualSlices(u8, expected, crossing_output);
}

fn wideBaseAndSequenceIsolation(comptime Support: type) !void {
    const bytes = try common.decodeHex(common.numbered_hex);
    defer std.testing.allocator.free(bytes);
    const base = @as(u64, std.math.maxInt(u32)) + 0x12_345;
    var source = common.TrackingSource{ .bytes = bytes, .base_offset = base };
    const block = try common.blockAt(&source, 0);
    const decoded = try common.prepareBlock(Support, block, null);
    var oracle = Support.initSliceOracle();
    const expected = try common.expectedLiterals(
        Support,
        &oracle,
        common.blockBytes(&source, block),
        decoded.layout.regenerated_size,
    );
    defer std.testing.allocator.free(expected);
    const forbidden = [_]common.Span{
        common.relativeSpan(&source, decoded.layout.sequence_count_range),
        common.relativeSpan(&source, decoded.layout.sequence_payload),
    };
    source.reset();
    source.forbidden = &forbidden;
    var page: [9]u8 = undefined;
    const output = try std.testing.allocator.alloc(u8, expected.len);
    defer std.testing.allocator.free(output);
    var cursor = try source_huffman_literals.init(
        Support.Codec,
        decoded.layout,
        &decoded.prepared,
        &page,
    );
    try cursor.copyNext(output);
    try std.testing.expectEqualSlices(u8, expected, output);
    try std.testing.expect(!source.forbidden_read);
    try std.testing.expect(source.min_observed_offset.? > std.math.maxInt(u32));
}

fn fastAndColdPaths(comptime Support: type) !void {
    const bytes = try common.decodeHex(common.numbered_hex);
    defer std.testing.allocator.free(bytes);
    var source = common.TrackingSource{ .bytes = bytes };
    const block = try common.blockAt(&source, 0);
    const decoded = try common.prepareBlock(Support, block, null);
    var page: [9]u8 = undefined;
    var cursor = try source_huffman_literals.init(
        Support.Codec,
        decoded.layout,
        &decoded.prepared,
        &page,
    );
    var fast: usize = 0;
    var cold: usize = 0;
    while (cursor.remaining() != 0) {
        if (cursor.reader.available() >= decoded.prepared.table.tree.max_bit_count)
            fast += 1
        else
            cold += 1;
        _ = try cursor.readSymbol();
    }
    try cursor.expectEnd();
    try std.testing.expect(fast != 0);
    try std.testing.expect(cold != 0);
}

pub fn contracts(comptime Support: type) !void {
    try realFixtures(Support);
    try exactFourStreamEnds(Support);
    try wideBaseAndSequenceIsolation(Support);
    try fastAndColdPaths(Support);
}
