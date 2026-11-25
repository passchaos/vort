const std = @import("std");
const w = @import("wire.zig");
const real = @import("real_samples.zig");
const t = std.testing;

fn guard(bytes: []const u8) !void {
    for (bytes) |byte| try t.expectEqual(@as(u8, 0xa5), byte);
}

pub fn rejectRaw(comptime D: type, raw: []const u8, expected: anyerror) !void {
    var caller: [4097 + 32]u8 = @splat(0xa5);
    const output = caller[16..][0..4097];
    try t.expectError(expected, D.decodeRawAuto(raw, output));
    try guard(&caller);
    try t.expectError(expected, D.decodeRawAutoWithDictionary(raw, "A", output));
    try guard(&caller);
    try t.expectError(expected, D.decodeRawDynamicAllocStrict(t.allocator, raw));
    try t.expectError(expected, D.decodeRawAutoAlloc(t.allocator, raw));
    try t.expectError(expected, D.parseRawDeflateHeaderInfo(raw));
    try t.expectError(expected, D.profileFirstDynamicDeflateBlock(raw));
    var joined: [1024]u8 = @splat(0x5a);
    const chunks = [_][]const u8{ raw[0..1], raw[1 .. raw.len / 2], raw[raw.len / 2 ..] };
    try t.expectError(expected, D.decodeRawChunks(&chunks, &joined, output));
    try guard(&caller);
    try t.expectError(expected, D.RawDeflateDecoder.init(raw, output));
    try guard(&caller);

    const dictionary_frame = try w.wrap(.zlib, raw, "A", "A");
    defer t.allocator.free(dictionary_frame);
    const dictionary_chunks = [_][]const u8{ dictionary_frame[0..6], dictionary_frame[6..] };
    try t.expectError(expected, D.decodeZlibWithDictionary(dictionary_frame, output, "A"));
    try t.expectError(expected, D.decodeZlibChunksIntoWithDictionary(&dictionary_chunks, output, "A"));
    try guard(&caller);

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(t.allocator);
    try appended.appendSlice(t.allocator, "committed-prefix");
    try t.expectError(expected, D.decodeRawAutoAppend(t.allocator, &appended, raw));
    try t.expectEqualSlices(u8, "committed-prefix", appended.items);
    inline for (.{ w.Wrapper.zlib, w.Wrapper.gzip }) |wrapper| {
        const frame = try w.wrap(wrapper, raw, "A", "");
        defer t.allocator.free(frame);
        const split = [_][]const u8{ frame[0..2], frame[2..11], frame[11..] };
        if (wrapper == .zlib) {
            try t.expectError(expected, D.decodeZlib(frame, output));
            try t.expectError(expected, D.decodeZlibChunksInto(&split, output));
            try t.expectError(expected, D.ZlibDecoder.initFromChunksDirect(&split, output));
        } else {
            try t.expectError(expected, D.decodeGzip(frame, output));
            try t.expectError(expected, D.decodeGzipChunksInto(&split, output));
            try t.expectError(expected, D.GzipDecoder.initFromChunksDirect(&split, output));
        }
        try guard(&caller);
    }
}

fn controls(comptime D: type) !void {
    inline for (.{ w.Kind.complete, w.Kind.empty_distance, w.Kind.singleton_distance, w.Kind.singleton_literal }) |kind| {
        const raw = try w.make(kind);
        defer t.allocator.free(raw);
        const expected: []const u8 = if (kind == .singleton_literal) "" else "A";
        var output: [8]u8 = @splat(0xa5);
        const decoded = try D.decodeRawAuto(raw, &output);
        try t.expectEqual(expected.len, decoded.output_written);
        try t.expectEqualSlices(u8, expected, output[0..decoded.output_written]);
        const allocated = try D.decodeRawAutoAlloc(t.allocator, raw);
        defer t.allocator.free(allocated);
        try t.expectEqualSlices(u8, expected, allocated);
        inline for (.{ w.Wrapper.zlib, w.Wrapper.gzip }) |wrapper| {
            const frame = try w.wrap(wrapper, raw, expected, "");
            defer t.allocator.free(frame);
            const split = [_][]const u8{ frame[0..1], frame[1..13], frame[13..] };
            const count = if (wrapper == .zlib) try D.decodeZlibChunksInto(&split, &output) else try D.decodeGzipChunksInto(&split, &output);
            try t.expectEqual(expected.len, count);
            try t.expectEqualSlices(u8, expected, output[0..count]);
        }
    }
    const dictionary_raw = try w.make(.dictionary_match);
    defer t.allocator.free(dictionary_raw);
    var output: [3]u8 = undefined;
    const decoded = try D.decodeRawAutoWithDictionary(dictionary_raw, "A", &output);
    try t.expectEqual(@as(usize, 3), decoded.output_written);
    try t.expectEqualSlices(u8, "AAA", &output);

    // Empty DIST is admitted for literals, but actual distance use retains
    // its InvalidHuffmanCode symbol error rather than a shape/header error.
    const no_distance = try w.make(.empty_distance_match);
    defer t.allocator.free(no_distance);
    var protected: [8]u8 = @splat(0xa5);
    try t.expectError(error.InvalidHuffmanCode, D.decodeRawAutoWithDictionary(no_distance, "A", &protected));
    try guard(&protected);
    const zlib = try w.wrap(.zlib, dictionary_raw, "AAA", "A");
    defer t.allocator.free(zlib);
    const chunks = [_][]const u8{ zlib[0..4], zlib[4..] };
    try t.expectEqual(@as(usize, 3), try D.decodeZlibChunksIntoWithDictionary(&chunks, &output, "A"));
    try t.expectEqualSlices(u8, "AAA", &output);

    const raw = try w.make(.complete);
    defer t.allocator.free(raw);
    try t.expectError(error.OutputTooSmall, D.decodeRawAuto(raw, &.{}));
    try t.expectError(error.OutputLimitExceeded, D.decodeRawAutoAllocLimited(t.allocator, raw, 0));
    try t.expectError(error.OutOfMemory, D.decodeRawAutoAlloc(t.failing_allocator, raw));
    try t.expectError(error.SizeMismatch, D.decodeRawAutoAllocExactSize(t.allocator, raw, 2));
}

fn realCases(comptime D: type) !void {
    try rejectRaw(D, &real.raw_bad, error.InvalidHuffmanCode);
    var caller: [82021 + 32]u8 = @splat(0xa5);
    const output = caller[16..][0..82021];
    try t.expectError(error.InvalidHuffmanCode, D.decodeGzip(&real.gzip_bad, output));
    const chunks = [_][]const u8{ real.gzip_bad[0..1], real.gzip_bad[1..29], real.gzip_bad[29..] };
    try t.expectError(error.InvalidHuffmanCode, D.decodeGzipChunksInto(&chunks, output));
    try t.expectError(error.InvalidHuffmanCode, D.GzipDecoder.initFromChunksDirect(&chunks, output));
    try guard(&caller);
    const raw = try D.decodeRawAutoAlloc(t.allocator, &real.raw_original);
    defer t.allocator.free(raw);
    try t.expectEqualSlices(u8, &real.raw_plain, raw);
    const gzip = try D.decodeGzipAlloc(t.allocator, &real.gzip_original);
    defer t.allocator.free(gzip);
    try t.expectEqualSlices(u8, &real.gzip_plain, gzip);
}

pub fn contracts(comptime D: type) !void {
    try realCases(D);
    inline for (.{
        w.Kind.incomplete_codes,       w.Kind.incomplete_literal,      w.Kind.long_literal_singleton,
        w.Kind.incomplete_distance,    w.Kind.long_distance_singleton, w.Kind.oversubscribed_codes,
        w.Kind.oversubscribed_literal, w.Kind.oversubscribed_distance,
    }) |kind| {
        const raw = try w.make(kind);
        defer t.allocator.free(raw);
        try rejectRaw(D, raw, error.InvalidHuffmanCode);
    }
    const no_eob = try w.make(.missing_eob);
    defer t.allocator.free(no_eob);
    try rejectRaw(D, no_eob, error.InvalidDynamicBlockHeader);
    try controls(D);
}
