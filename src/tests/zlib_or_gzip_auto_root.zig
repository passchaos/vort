const std = @import("std");

pub fn contracts(comptime V: type) !void {
    const plain = "root auto wrapper";
    const zlib = try V.encodeZlibFixedAlloc(std.testing.allocator, plain);
    defer std.testing.allocator.free(zlib);
    const gzip = try V.encodeGzipFixedAlloc(std.testing.allocator, plain);
    defer std.testing.allocator.free(gzip);
    var output: [plain.len]u8 = undefined;
    inline for (.{ V.ZlibOrGzipFormat.zlib, V.ZlibOrGzipFormat.gzip }) |format| {
        const wire = if (format == .zlib) zlib else gzip;
        const joined = try std.mem.concat(std.testing.allocator, u8, &.{ wire, "tail" });
        defer std.testing.allocator.free(joined);
        const result: V.ZlibOrGzipDecodeResult = try V.decodeZlibOrGzipPrefix(joined, &output);
        try std.testing.expectEqual(format, result.format);
        try std.testing.expectEqual(wire.len, result.input_read);
        try std.testing.expectEqualStrings(plain, &output);
        const owned: V.DecodedZlibOrGzip = try V.decodeZlibOrGzipPrefixAllocExactSize(std.testing.allocator, joined, plain.len);
        defer owned.deinit(std.testing.allocator);
        try std.testing.expectEqualStrings(plain, owned.bytes);
    }

    var history: [65_536]u8 = undefined;
    var decoder = try V.ZlibOrGzipIncrementalDecoder.init(.{ .expected_output_len = plain.len }, &history);
    const result = try decoder.step(gzip, &output);
    try std.testing.expectEqual(@as(@TypeOf(result.status), .done), result.status);
    try std.testing.expectEqual(V.ZlibOrGzipFormat.gzip, decoder.selectedFormat().?);
}
