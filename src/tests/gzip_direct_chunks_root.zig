const std = @import("std");

pub fn contracts(comptime V: type) !void {
    const frame = [_]u8{ 0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x03, 0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00, 0x86, 0xa6, 0x10, 0x36, 0x05, 0x00, 0x00, 0x00 };
    const chunks = [_][]const u8{
        frame[0..1],
        frame[1..3],
        "",
        frame[3..10],
        frame[10 .. frame.len - 7],
        frame[frame.len - 7 .. frame.len - 3],
        "",
        frame[frame.len - 3 ..],
    };
    var output: [5]u8 = undefined;
    try std.testing.expectEqual(@as(usize, 5), try V.decodeGzipChunksInto(&chunks, &output));
    try std.testing.expectEqualStrings("hello", &output);

    var decoder = try V.GzipDecoder.initFromChunksExactSizeDirect(&chunks, &output, output.len);
    var drained: [5]u8 = undefined;
    const result = try decoder.step(&drained);
    try std.testing.expectEqual(@as(@TypeOf(result.status), .done), result.status);
    try std.testing.expectEqual(frame.len, result.progress.input_read);
    try std.testing.expectEqualStrings("hello", &drained);

    try decoder.resetFromChunksWithOptionsExactSizeDirect(&chunks, &output, .{}, output.len);
    try std.testing.expectError(error.SizeMismatch, decoder.resetFromChunksWithOptionsExactSizeDirect(&chunks, &output, .{}, output.len + 1));
}
