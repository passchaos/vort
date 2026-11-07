const std = @import("std");

pub fn contracts(comptime V: type) !void {
    const first = [_]u8{ 0x40, 0x00, 0x10, 'h', 'e', 'l', 'l', 'o', 0x03 };
    const second = [_]u8{0x06};
    const joined = first ++ second ++ [_]u8{0xff};
    var output: [5]u8 = undefined;
    const result: V.BrotliDecodePrefixResult = try V.brDecodeStreamPrefixInto(&joined, &output);
    try std.testing.expectEqual(first.len, result.input_read);
    try std.testing.expectEqual(output.len, result.output_written);
    try std.testing.expectEqualStrings("hello", &output);
    try std.testing.expectError(error.TrailingData, V.brDecodeStreamInto(&joined, &output));

    const size: V.BrotliDecodedPrefixSize = try V.brDecodedStreamPrefixSize(&joined);
    try std.testing.expectEqual(first.len, size.input_read);
    try std.testing.expectEqual(@as(V.StreamCount, output.len), size.decoded_bytes);

    const owned: V.BrotliDecodedPrefix = try V.brDecodeStreamPrefixAlloc(std.testing.allocator, &joined);
    defer owned.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("hello", owned.bytes);

    const chunks = [_][]const u8{ joined[0..1], "", joined[1..first.len], joined[first.len..] };
    var scratch: [joined.len]u8 = undefined;
    const chunk_result = try V.brDecodeStreamPrefixChunksInto(&chunks, &scratch, &output);
    try std.testing.expectEqual(first.len, chunk_result.input_read);
}
