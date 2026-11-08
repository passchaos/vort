const std = @import("std");
const common = @import("common.zig");
const huffman_common = common.huffman_common;
const literal_stream = common.literal_stream;

fn happyTagsPagesAndCanaries(comptime Support: type) !void {
    inline for (.{ 9, 10, 17 }) |page_len| {
        const bytes = try huffman_common.decodeHex(huffman_common.numbered_hex);
        defer std.testing.allocator.free(bytes);
        var source = huffman_common.TrackingSource{ .bytes = bytes };
        const block = try huffman_common.blockAt(&source, 0);
        const decoded = try huffman_common.prepareBlock(Support, block, null);
        var oracle = Support.initSliceOracle();
        const expected = try huffman_common.expectedLiterals(
            Support,
            &oracle,
            huffman_common.blockBytes(&source, block),
            decoded.layout.regenerated_size,
        );
        defer std.testing.allocator.free(expected);
        var page_storage: [19]u8 = @splat(0x73);
        page_storage[0] = 0x39;
        page_storage[page_len + 1] = 0xc6;
        const output = try std.testing.allocator.alloc(u8, expected.len + 2);
        defer std.testing.allocator.free(output);
        @memset(output, 0xd8);
        output[0] = 0x51;
        output[output.len - 1] = 0xae;
        var stream = try literal_stream.init(
            Support.Codec,
            decoded.layout,
            &decoded.prepared,
            page_storage[1 .. page_len + 1],
        );
        try std.testing.expectEqual(literal_stream.Kind.huffman, std.meta.activeTag(stream));
        try std.testing.expectEqual(literal_stream.Kind.huffman, stream.snapshot().kind);
        try std.testing.expect(stream.snapshot().huffman != null);

        const before_empty = stream.snapshot();
        var empty_committed: usize = 99;
        try stream.copyNext(output[1..1], &empty_committed);
        try std.testing.expectEqual(@as(usize, 0), empty_committed);
        try std.testing.expectEqualDeep(before_empty, stream.snapshot());

        var offset: usize = 0;
        const chunks = [_]usize{ 1, 0, 2, 7, 3, 19, 5, 11 };
        while (offset != expected.len) {
            const requested = chunks[offset % chunks.len];
            const amount = @min(@max(requested, 1), expected.len - offset);
            var committed: usize = 99;
            try stream.copyNext(output[1 + offset ..][0..amount], &committed);
            try std.testing.expectEqual(amount, committed);
            offset += amount;
        }
        try stream.expectEnd();
        try stream.expectEnd();
        try std.testing.expect(stream.isFinished());
        try std.testing.expectEqualSlices(u8, expected, output[1 .. output.len - 1]);
        try huffman_common.expectPageCanaries(&page_storage, page_len);
        try huffman_common.expectOutputCanaries(output);
    }
}

fn refillFailuresReportExactPrefixAndRetry(comptime Support: type) !void {
    inline for (.{ huffman_common.Mode.zero, .excessive, .fail }) |mode| {
        const bytes = try huffman_common.decodeHex(huffman_common.numbered_hex);
        defer std.testing.allocator.free(bytes);
        var source = huffman_common.TrackingSource{ .bytes = bytes };
        const block = try huffman_common.blockAt(&source, 0);
        const decoded = try huffman_common.prepareBlock(Support, block, null);
        var oracle = Support.initSliceOracle();
        const expected = try huffman_common.expectedLiterals(
            Support,
            &oracle,
            huffman_common.blockBytes(&source, block),
            decoded.layout.regenerated_size,
        );
        defer std.testing.allocator.free(expected);
        const output = try std.testing.allocator.alloc(u8, expected.len + 2);
        defer std.testing.allocator.free(output);
        @memset(output, 0xcc);
        output[0] = 0x51;
        output[output.len - 1] = 0xae;
        var page_storage: [11]u8 = @splat(0x62);
        page_storage[0] = 0x39;
        page_storage[10] = 0xc6;

        source.reset();
        source.mode = mode;
        source.fault_call = 2;
        var stream = try literal_stream.init(
            Support.Codec,
            decoded.layout,
            &decoded.prepared,
            page_storage[1..10],
        );
        var committed: usize = 99;
        try std.testing.expectError(
            huffman_common.expectedError(mode),
            stream.copyNext(output[1 .. output.len - 1], &committed),
        );
        try std.testing.expect(committed != 0 and committed < expected.len);
        try std.testing.expectEqual(committed, stream.snapshot().decoded);
        try std.testing.expectEqualSlices(u8, expected[0..committed], output[1..][0..committed]);
        for (output[1 + committed .. output.len - 1]) |byte|
            try std.testing.expectEqual(@as(u8, 0xcc), byte);

        const prefix = committed;
        source.mode = .normal;
        source.fault_call = null;
        try stream.copyNext(output[1 + prefix .. output.len - 1], &committed);
        try std.testing.expectEqual(expected.len - prefix, committed);
        try std.testing.expectEqualSlices(u8, expected, output[1 .. output.len - 1]);
        try stream.expectEnd();
        try huffman_common.expectPageCanaries(&page_storage, 9);
        try huffman_common.expectOutputCanaries(output);
    }
}

fn terminalErrorCommitsCompleteOutput(comptime Support: type) !void {
    const bytes = try huffman_common.decodeHex(huffman_common.numbered_hex);
    defer std.testing.allocator.free(bytes);
    var source = huffman_common.TrackingSource{ .bytes = bytes };
    const block = try huffman_common.blockAt(&source, 0);
    var decoded = try huffman_common.prepareBlock(Support, block, null);
    var oracle = Support.initSliceOracle();
    const expected = try huffman_common.expectedLiterals(
        Support,
        &oracle,
        huffman_common.blockBytes(&source, block),
        decoded.layout.regenerated_size,
    );
    defer std.testing.allocator.free(expected);
    decoded.layout.regenerated_size -= 1;
    var page: [9]u8 = undefined;
    var stream = try literal_stream.init(
        Support.Codec,
        decoded.layout,
        &decoded.prepared,
        &page,
    );
    const output = try std.testing.allocator.alloc(u8, decoded.layout.regenerated_size);
    defer std.testing.allocator.free(output);
    var committed: usize = 99;
    try std.testing.expectError(error.CorruptFrame, stream.copyNext(output, &committed));
    try std.testing.expectEqual(output.len, committed);
    try std.testing.expectEqualSlices(u8, expected[0..output.len], output);
    try std.testing.expectEqual(@as(usize, 0), stream.remaining());
    try std.testing.expect(!stream.isFinished());
    try std.testing.expect(!stream.snapshot().finished);
    try std.testing.expectError(error.CorruptFrame, stream.expectEnd());
}

fn aliasAndInitPriority(comptime Support: type) !void {
    const bytes = try huffman_common.decodeHex(huffman_common.numbered_hex);
    defer std.testing.allocator.free(bytes);
    var source = huffman_common.TrackingSource{ .bytes = bytes };
    const block = try huffman_common.blockAt(&source, 0);
    const decoded = try huffman_common.prepareBlock(Support, block, null);
    var page: [9]u8 = undefined;
    try std.testing.expectError(
        error.OutputTooSmall,
        literal_stream.init(Support.Codec, decoded.layout, null, page[0..8]),
    );
    try std.testing.expectError(
        error.CorruptFrame,
        literal_stream.init(Support.Codec, decoded.layout, null, &page),
    );
    var stream = try literal_stream.init(
        Support.Codec,
        decoded.layout,
        &decoded.prepared,
        &page,
    );
    const before = stream.snapshot();
    var committed: usize = 99;
    try std.testing.expectError(
        error.InvalidStreamState,
        stream.copyNext(page[1..3], &committed),
    );
    try std.testing.expectEqual(@as(usize, 0), committed);
    try std.testing.expectEqualDeep(before, stream.snapshot());
}

pub fn contracts(comptime Support: type) !void {
    try happyTagsPagesAndCanaries(Support);
    try refillFailuresReportExactPrefixAndRetry(Support);
    try terminalErrorCommitsCompleteOutput(Support);
    try aliasAndInitPriority(Support);
}
