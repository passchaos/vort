const std = @import("std");
const common = @import("common.zig");
const source_huffman_literals = common.source_huffman_literals;

fn emptyAndZeroMarker(comptime Support: type) !void {
    const bytes = try common.decodeHex(common.numbered_hex);
    defer std.testing.allocator.free(bytes);
    var source = common.TrackingSource{ .bytes = bytes };
    const block = try common.blockAt(&source, 0);
    const decoded = try common.prepareBlock(Support, block, null);
    const one = try common.oneRange(decoded.layout);
    const prepared_before = decoded.prepared;
    var page_storage: [11]u8 = @splat(0x77);
    page_storage[0] = 0x39;
    page_storage[10] = 0xc6;

    var empty = decoded.layout;
    empty.streams = .{ .one = try one.subrange(0, 0) };
    try std.testing.expectError(
        error.TruncatedFrame,
        source_huffman_literals.init(
            Support.Codec,
            empty,
            &decoded.prepared,
            page_storage[1..10],
        ),
    );
    try std.testing.expectEqualDeep(prepared_before, decoded.prepared);
    try common.expectPageCanaries(&page_storage, 9);

    const marker_index: usize = @intCast(try one.end() - source.base_offset - 1);
    bytes[marker_index] = 0;
    var zero_source = common.TrackingSource{ .bytes = bytes };
    const zero_block = try common.blockAt(&zero_source, 0);
    const zero_decoded = try common.prepareBlock(Support, zero_block, null);
    try std.testing.expectError(
        error.CorruptFrame,
        source_huffman_literals.init(
            Support.Codec,
            zero_decoded.layout,
            &zero_decoded.prepared,
            page_storage[1..10],
        ),
    );
    try common.expectPageCanaries(&page_storage, 9);
}

fn earlyEndAndExtraBits(comptime Support: type) !void {
    const bytes = try common.decodeHex(common.numbered_hex);
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
    const prepared_before = decoded.prepared;

    var marker_only_bytes = [_]u8{1};
    var marker_only_source = common.byte_source.SliceSource{ .bytes = &marker_only_bytes };
    var early = decoded.layout;
    early.streams = .{ .one = try common.source_input.Range.init(
        marker_only_source.source(),
        0,
        marker_only_bytes.len,
    ) };
    var page: [9]u8 = undefined;
    var early_cursor = try source_huffman_literals.init(
        Support.Codec,
        early,
        &decoded.prepared,
        &page,
    );
    var early_output: [1]u8 = .{0xa5};
    try std.testing.expectError(error.CorruptFrame, early_cursor.copyNext(&early_output));
    try std.testing.expectEqual(@as(usize, 0), early_cursor.snapshot().decoded);
    try std.testing.expectEqual(@as(u8, 0xa5), early_output[0]);

    var extra = decoded.layout;
    extra.regenerated_size -= 1;
    const output = try std.testing.allocator.alloc(u8, extra.regenerated_size + 2);
    defer std.testing.allocator.free(output);
    @memset(output, 0xee);
    output[0] = 0x51;
    output[output.len - 1] = 0xae;
    var extra_cursor = try source_huffman_literals.init(
        Support.Codec,
        extra,
        &decoded.prepared,
        &page,
    );
    try std.testing.expectError(
        error.CorruptFrame,
        extra_cursor.copyNext(output[1 .. output.len - 1]),
    );
    try std.testing.expectEqual(extra.regenerated_size, extra_cursor.snapshot().decoded);
    try std.testing.expectEqualSlices(
        u8,
        expected[0..extra.regenerated_size],
        output[1 .. output.len - 1],
    );
    try common.expectOutputCanaries(output);
    try std.testing.expectEqualDeep(prepared_before, decoded.prepared);
}

fn fourStreamMarkerFailures(comptime Support: type) !void {
    for (0..4) |bad_stream| {
        const bytes = try common.decodeHex(common.repeat_hex);
        defer std.testing.allocator.free(bytes);
        var original_source = common.TrackingSource{ .bytes = bytes };
        const original_block = try common.blockAt(&original_source, 0);
        const original = try common.prepareBlock(Support, original_block, null);
        var oracle = Support.initSliceOracle();
        const expected = try common.expectedLiterals(
            Support,
            &oracle,
            common.blockBytes(&original_source, original_block),
            original.layout.regenerated_size,
        );
        defer std.testing.allocator.free(expected);
        const ranges = try common.streamRanges(original.layout);
        const marker_index: usize = @intCast(try ranges[bad_stream].end() - 1);
        bytes[marker_index] = 0;

        var source = common.TrackingSource{ .bytes = bytes };
        const block = try common.blockAt(&source, 0);
        const decoded = try common.prepareBlock(Support, block, null);
        const prepared_before = decoded.prepared;
        var page_storage: [11]u8 = @splat(0x83);
        page_storage[0] = 0x39;
        page_storage[10] = 0xc6;
        if (bad_stream == 0) {
            try std.testing.expectError(
                error.CorruptFrame,
                source_huffman_literals.init(
                    Support.Codec,
                    decoded.layout,
                    &decoded.prepared,
                    page_storage[1..10],
                ),
            );
        } else {
            const output = try std.testing.allocator.alloc(u8, expected.len + 2);
            defer std.testing.allocator.free(output);
            @memset(output, 0xdc);
            output[0] = 0x51;
            output[output.len - 1] = 0xae;
            var cursor = try source_huffman_literals.init(
                Support.Codec,
                decoded.layout,
                &decoded.prepared,
                page_storage[1..10],
            );
            try std.testing.expectError(
                error.CorruptFrame,
                cursor.copyNext(output[1 .. output.len - 1]),
            );
            const segment_len = (expected.len + 3) / 4;
            const prefix_len = segment_len * bad_stream;
            try std.testing.expectEqual(prefix_len, cursor.snapshot().decoded);
            try std.testing.expectEqualSlices(
                u8,
                expected[0..prefix_len],
                output[1..][0..prefix_len],
            );
            for (output[1 + prefix_len .. output.len - 1]) |byte|
                try std.testing.expectEqual(@as(u8, 0xdc), byte);
            try common.expectOutputCanaries(output);
        }
        try common.expectPageCanaries(&page_storage, 9);
        try std.testing.expectEqualDeep(prepared_before, decoded.prepared);
    }
}

fn invalidCallsPreserveState(comptime Support: type) !void {
    const bytes = try common.decodeHex(common.numbered_hex);
    defer std.testing.allocator.free(bytes);
    var source = common.TrackingSource{ .bytes = bytes };
    const block = try common.blockAt(&source, 0);
    const decoded = try common.prepareBlock(Support, block, null);
    var page: [9]u8 = undefined;
    try std.testing.expectError(
        error.OutputTooSmall,
        source_huffman_literals.init(
            Support.Codec,
            decoded.layout,
            &decoded.prepared,
            page[0..8],
        ),
    );
    var cursor = try source_huffman_literals.init(
        Support.Codec,
        decoded.layout,
        &decoded.prepared,
        &page,
    );
    const before = cursor.snapshot();
    try std.testing.expectError(error.InvalidStreamState, cursor.copyNext(page[0..1]));
    try std.testing.expectEqualDeep(before, cursor.snapshot());
    const too_large = try std.testing.allocator.alloc(u8, decoded.layout.regenerated_size + 1);
    defer std.testing.allocator.free(too_large);
    @memset(too_large, 0xa7);
    try std.testing.expectError(error.CorruptFrame, cursor.copyNext(too_large));
    try std.testing.expectEqualDeep(before, cursor.snapshot());
    for (too_large) |byte| try std.testing.expectEqual(@as(u8, 0xa7), byte);
    try std.testing.expectError(error.CorruptFrame, cursor.expectEnd());
    try std.testing.expectEqualDeep(before, cursor.snapshot());
}

pub fn contracts(comptime Support: type) !void {
    try emptyAndZeroMarker(Support);
    try earlyEndAndExtraBits(Support);
    try fourStreamMarkerFailures(Support);
    try invalidCallsPreserveState(Support);
}
