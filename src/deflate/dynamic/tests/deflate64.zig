const std = @import("std");
const deflate64 = @import("../../../deflate64.zig");
const w = @import("wire.zig");
const real = @import("real_samples.zig");
const incremental = @import("incremental.zig");
const t = std.testing;

pub fn contracts() !void {
    const invalid = [_][]const u8{&real.raw_bad};
    for (invalid) |raw| {
        var output: [4097]u8 = @splat(0xa5);
        try t.expectError(error.InvalidHuffmanCode, deflate64.decodeInto(raw, &output));
        try t.expectError(error.InvalidHuffmanCode, deflate64.decodeAlloc(t.allocator, raw));
        for (output) |byte| try t.expectEqual(@as(u8, 0xa5), byte);
        var history: [65536]u8 = @splat(0xa5);
        var decoder = try deflate64.IncrementalDecoder.initWithHistory(.{}, &history);
        try incremental.reject(&decoder, raw, true);
        for (history) |byte| try t.expectEqual(@as(u8, 0xa5), byte);
    }
    inline for (.{ w.Kind.complete, w.Kind.empty_distance, w.Kind.singleton_literal, w.Kind.singleton_distance, w.Kind.deflate64_distance32 }) |kind| {
        const raw = try w.make(kind);
        defer t.allocator.free(raw);
        const expected: []const u8 = if (kind == .singleton_literal) "" else "A";
        const output = try deflate64.decodeAlloc(t.allocator, raw);
        defer t.allocator.free(output);
        try t.expectEqualSlices(u8, expected, output);
        var history: [65536]u8 = @splat(0xa5);
        var decoder = try deflate64.IncrementalDecoder.initWithHistory(.{}, &history);
        try incremental.drain(&decoder, raw, expected);
    }
}
