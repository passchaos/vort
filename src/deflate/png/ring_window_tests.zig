const std = @import("std");
const deflate = @import("../../deflate.zig");
const png = @import("../../png.zig");
const ring = @import("ring_sink.zig");

test "ring window fixed and stored blocks reconstruct all rows after repeated laps" {
    const allocator = std.testing.allocator;
    const info = try png.pngImageInfo(511, 640, 8, .grayscale);
    const filtered = try allocator.alloc(u8, info.zlib_payload_len);
    defer allocator.free(filtered);
    const output = try allocator.alloc(u8, try png.pngImageOutputLen(info));
    defer allocator.free(output);
    const scratch = try allocator.alloc(u8, ring.ring_len);
    defer allocator.free(scratch);
    var row: [512]u8 = undefined;
    for (filtered, 0..) |*byte, i| byte.* = if (i % 512 == 0) 0 else @truncate(i * 37 + i / 7);
    for ([_]bool{ false, true }) |fixed| {
        // Decode a fixed stream independently authored by zlib. Generating it
        // with the encoder under test can conflate decoder coverage with a
        // platform-specific match-finder failure.
        const encoded = if (fixed) @embedFile("testdata/ring-fixed.zlib") else try deflate.encodeZlibStoredAlloc(allocator, filtered);
        defer if (!fixed) allocator.free(encoded);
        for ([_]deflate.ZlibDecodeOptions{ .{}, .{ .ignore_adler = true } }) |options| {
            try deflate.decodePngRingZlibImageWithOptions(encoded, scratch, &row, info, options, output);
            for (0..info.height) |y|
                try std.testing.expectEqualSlices(u8, filtered[y * 512 + 1 ..][0..511], output[y * 511 ..][0..511]);
        }
    }
}
