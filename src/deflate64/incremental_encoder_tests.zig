const std = @import("std");
const deflate64 = @import("../deflate64.zig");

test "Deflate64 incremental stored encoder is split independent" {
    const allocator = std.testing.allocator;
    const input = try allocator.alloc(u8, std.math.maxInt(u16) + 17);
    defer allocator.free(input);
    for (input, 0..) |*byte, index| byte.* = @truncate(index *% 73 +% index / 251);

    const expected = try deflate64.encodeStoredAlloc(allocator, input);
    defer allocator.free(expected);
    var encoder = deflate64.IncrementalStoredEncoder.initExactSize(
        allocator,
        .{},
        input.len,
    );
    defer encoder.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    var scratch: [7]u8 = undefined;
    var offset: usize = 0;
    while (offset < input.len) {
        const end = @min(input.len, offset + 13);
        const stepped = try encoder.step(input[offset..end], &scratch);
        offset += stepped.progress.input_read;
        try encoded.appendSlice(allocator, scratch[0..stepped.progress.output_written]);
    }
    encoder.finish();
    while (true) {
        const stepped = try encoder.step("", &scratch);
        try encoded.appendSlice(allocator, scratch[0..stepped.progress.output_written]);
        if (stepped.status == .done) break;
    }
    try std.testing.expectEqualSlices(u8, expected, encoded.items);
    const decoded = try deflate64.decodeAlloc(allocator, encoded.items);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}

test "Deflate64 incremental stored encoder handles empty backpressure and limits" {
    const allocator = std.testing.allocator;
    var encoder = deflate64.IncrementalStoredEncoder.init(allocator);
    defer encoder.deinit();
    encoder.finish();
    const blocked = try encoder.step("", &.{});
    try std.testing.expectEqual(.need_output, blocked.status);
    var output: [5]u8 = undefined;
    const drained = try encoder.step("", &output);
    try std.testing.expectEqual(.need_output, drained.status);
    try std.testing.expectEqualSlices(u8, &.{ 1, 0, 0, 0xff, 0xff }, &output);
    const done = try encoder.step("", &.{});
    try std.testing.expectEqual(.done, done.status);

    var limited = deflate64.IncrementalStoredEncoder.initWithOptions(allocator, .{
        .max_input_len = 3,
    });
    defer limited.deinit();
    var scratch: [16]u8 = undefined;
    try std.testing.expectError(error.OutputLimitExceeded, limited.step("four", &scratch));

    var pledged = deflate64.IncrementalStoredEncoder.initExactSize(allocator, .{}, 4);
    defer pledged.deinit();
    _ = try pledged.step("abc", &scratch);
    pledged.finish();
    try std.testing.expectError(error.SizeMismatch, pledged.step("", &scratch));
}
