const std = @import("std");
const common = @import("common.zig");
const source_huffman_literals = common.source_huffman_literals;

fn initFailuresRetry(comptime Support: type) !void {
    inline for (.{ common.Mode.zero, .excessive, .fail }) |mode| {
        const bytes = try common.decodeHex(common.numbered_hex);
        defer std.testing.allocator.free(bytes);
        var source = common.TrackingSource{ .bytes = bytes };
        const block = try common.blockAt(&source, 0);
        const decoded = try common.prepareBlock(Support, block, null);
        const prepared_before = decoded.prepared;
        var oracle = Support.initSliceOracle();
        const expected = try common.expectedLiterals(
            Support,
            &oracle,
            common.blockBytes(&source, block),
            decoded.layout.regenerated_size,
        );
        defer std.testing.allocator.free(expected);
        var page_storage: [11]u8 = @splat(0x91);
        page_storage[0] = 0x39;
        page_storage[10] = 0xc6;

        source.reset();
        source.mode = mode;
        source.fault_call = 1;
        try std.testing.expectError(
            common.expectedError(mode),
            source_huffman_literals.init(
                Support.Codec,
                decoded.layout,
                &decoded.prepared,
                page_storage[1..10],
            ),
        );
        try std.testing.expectEqual(@as(usize, 1), source.calls);
        try common.expectPageCanaries(&page_storage, 9);
        try std.testing.expectEqualDeep(prepared_before, decoded.prepared);

        source.reset();
        var cursor = try source_huffman_literals.init(
            Support.Codec,
            decoded.layout,
            &decoded.prepared,
            page_storage[1..10],
        );
        const output = try std.testing.allocator.alloc(u8, expected.len);
        defer std.testing.allocator.free(output);
        try cursor.copyNext(output);
        try std.testing.expectEqualSlices(u8, expected, output);
        try common.expectPageCanaries(&page_storage, 9);
    }
}

fn refillFailuresRetryExactPrefix(comptime Support: type) !void {
    inline for (.{ common.Mode.zero, .excessive, .fail }) |mode| {
        const bytes = try common.decodeHex(common.numbered_hex);
        defer std.testing.allocator.free(bytes);
        var source = common.TrackingSource{ .bytes = bytes };
        const block = try common.blockAt(&source, 0);
        const decoded = try common.prepareBlock(Support, block, null);
        const prepared_before = decoded.prepared;
        var oracle = Support.initSliceOracle();
        const expected = try common.expectedLiterals(
            Support,
            &oracle,
            common.blockBytes(&source, block),
            decoded.layout.regenerated_size,
        );
        defer std.testing.allocator.free(expected);
        var page_storage: [11]u8 = @splat(0x42);
        page_storage[0] = 0x39;
        page_storage[10] = 0xc6;
        const output = try std.testing.allocator.alloc(u8, expected.len + 2);
        defer std.testing.allocator.free(output);
        @memset(output, 0xd8);
        output[0] = 0x51;
        output[output.len - 1] = 0xae;

        source.reset();
        source.mode = mode;
        source.fault_call = 2;
        var cursor = try source_huffman_literals.init(
            Support.Codec,
            decoded.layout,
            &decoded.prepared,
            page_storage[1..10],
        );
        try std.testing.expectError(
            common.expectedError(mode),
            cursor.copyNext(output[1 .. output.len - 1]),
        );
        const prefix_len = cursor.snapshot().decoded;
        try std.testing.expect(prefix_len != 0 and prefix_len < expected.len);
        try std.testing.expectEqualSlices(u8, expected[0..prefix_len], output[1..][0..prefix_len]);
        for (output[1 + prefix_len .. output.len - 1]) |byte|
            try std.testing.expectEqual(@as(u8, 0xd8), byte);
        try std.testing.expectEqualDeep(prepared_before, decoded.prepared);
        try common.expectOutputCanaries(output);
        try common.expectPageCanaries(&page_storage, 9);

        source.mode = .normal;
        source.fault_call = null;
        try cursor.copyNext(output[1 + prefix_len .. output.len - 1]);
        try std.testing.expectEqualSlices(u8, expected, output[1 .. output.len - 1]);
        try cursor.expectEnd();
        try common.expectOutputCanaries(output);
        try common.expectPageCanaries(&page_storage, 9);
    }
}

fn nextStreamInitFailuresRetry(comptime Support: type) !void {
    inline for (.{ common.Mode.zero, .excessive, .fail }) |mode| {
        const bytes = try common.decodeHex(common.repeat_hex);
        defer std.testing.allocator.free(bytes);
        var source = common.TrackingSource{ .bytes = bytes };
        const block = try common.blockAt(&source, 0);
        const decoded = try common.prepareBlock(Support, block, null);
        const prepared_before = decoded.prepared;
        var oracle = Support.initSliceOracle();
        const expected = try common.expectedLiterals(
            Support,
            &oracle,
            common.blockBytes(&source, block),
            decoded.layout.regenerated_size,
        );
        defer std.testing.allocator.free(expected);
        const segment_len = (expected.len + 3) / 4;
        const ranges = try common.streamRanges(decoded.layout);
        var page_storage: [11]u8 = @splat(0x62);
        page_storage[0] = 0x39;
        page_storage[10] = 0xc6;
        const output = try std.testing.allocator.alloc(u8, expected.len + 2);
        defer std.testing.allocator.free(output);
        @memset(output, 0xcc);
        output[0] = 0x51;
        output[output.len - 1] = 0xae;
        var cursor = try source_huffman_literals.init(
            Support.Codec,
            decoded.layout,
            &decoded.prepared,
            page_storage[1..10],
        );
        source.reset();
        source.mode = mode;
        source.fault_span = common.relativeSpan(&source, ranges[1]);
        try std.testing.expectError(
            common.expectedError(mode),
            cursor.copyNext(output[1..][0..segment_len]),
        );
        try std.testing.expectEqualSlices(u8, expected[0..segment_len], output[1..][0..segment_len]);
        try std.testing.expectEqual(segment_len, cursor.snapshot().decoded);
        try std.testing.expectEqual(@as(u2, 0), cursor.snapshot().stream_index);
        try std.testing.expect(source.calls != 0);

        source.mode = .normal;
        source.fault_span = null;
        output[1 + segment_len] = try cursor.readSymbol();
        try cursor.copyNext(output[1 + segment_len + 1 .. output.len - 1]);
        try std.testing.expectEqualSlices(u8, expected, output[1 .. output.len - 1]);
        try std.testing.expectEqualDeep(prepared_before, decoded.prepared);
        try common.expectOutputCanaries(output);
        try common.expectPageCanaries(&page_storage, 9);
    }
}

pub fn contracts(comptime Support: type) !void {
    try initFailuresRetry(Support);
    try refillFailuresRetryExactPrefix(Support);
    try nextStreamInitFailuresRetry(Support);
}
