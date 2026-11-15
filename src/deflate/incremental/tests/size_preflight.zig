const std = @import("std");
const deflate = @import("../../../deflate.zig");

// The one-shot size-preflight entrypoints (decodedGzipSize and the chunks
// variant) previously had no direct tests. They must report the same length a
// full decode produces, and the chunks variant must be insensitive to where the
// compressed input is split.
test "Gzip size preflight matches the decoded output length" {
    const a = std.testing.allocator;
    const payload = "gzip size preflight payload. " ** 128;
    const encoded = try deflate.encodeGzipBestAlloc(a, payload, deflate.optionsForLevel(.default));
    defer a.free(encoded);

    const decoded = try deflate.decodeGzipAlloc(a, encoded);
    defer a.free(decoded);

    const scratch = try a.alloc(u8, @max(encoded.len, payload.len) + 64);
    defer a.free(scratch);

    const size = try deflate.decodedGzipSize(encoded, scratch);
    try std.testing.expectEqual(payload.len, size);
    try std.testing.expectEqual(decoded.len, size);
}

test "Gzip chunks size preflight is split-insensitive" {
    const a = std.testing.allocator;
    const payload = "gzip chunked size preflight payload. " ** 96;
    const encoded = try deflate.encodeGzipFixedAlloc(a, payload);
    defer a.free(encoded);

    const compressed_scratch = try a.alloc(u8, encoded.len);
    defer a.free(compressed_scratch);
    const output_scratch = try a.alloc(u8, payload.len + 64);
    defer a.free(output_scratch);

    const cuts = [_]usize{ 1, 9, encoded.len / 2, encoded.len - 1 };
    for (cuts) |cut| {
        const clamped = @min(cut, encoded.len - 1);
        const chunks = [_][]const u8{ encoded[0..clamped], encoded[clamped..] };
        const size = try deflate.decodedGzipChunksSize(&chunks, compressed_scratch, output_scratch);
        try std.testing.expectEqual(payload.len, size);
    }
}
