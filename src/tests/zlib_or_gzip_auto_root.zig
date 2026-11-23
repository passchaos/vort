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

    const Auto = V.ZlibOrGzipIncrementalDecoder;
    const Observe = struct {
        start_count: usize = 0,
        payload_offset: ?V.StreamCount = null,

        fn onEvent(context: ?*anyopaque, event: Auto.HeaderEvent) void {
            const state: *@This() = @ptrCast(@alignCast(context.?));
            switch (event) {
                .start => state.start_count += 1,
                .field => {},
                .complete => |header| state.payload_offset = header.header_end_offset,
            }
        }
    };
    var history: [65_536]u8 = undefined;
    var decoder = try Auto.init(.{ .expected_output_len = plain.len }, &history);
    var observed: Observe = .{};
    const result = try decoder.stepWithHeaderEvents(gzip, &output, .{ .context = &observed, .on_event = Observe.onEvent });
    try std.testing.expectEqual(@as(@TypeOf(result.status), .done), result.status);
    try std.testing.expectEqual(V.ZlibOrGzipFormat.gzip, decoder.selectedFormat().?);
    try std.testing.expectEqual(@as(usize, 1), observed.start_count);
    try std.testing.expectEqual(@as(?V.StreamCount, 10), observed.payload_offset);
    try std.testing.expectEqualStrings(plain, &output);
}
