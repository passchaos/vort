const std = @import("std");
const shrink = @import("shrink.zig");

test "Shrink incremental encoder is byte exact through width growth and dictionary freeze" {
    const allocator = std.testing.allocator;
    const input = try allocator.alloc(u8, 32 * 1024);
    defer allocator.free(input);
    var state: u32 = 0x5a17_c9e3;
    for (input) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    const expected = try shrink.encodeAlloc(allocator, input);
    defer allocator.free(expected);
    var encoder = try shrink.IncrementalEncoder.initExactSize(
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
        const end = @min(input.len, offset + 3);
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
    try std.testing.expectEqual(@as(u4, 13), encoder.snapshot().code_bits);
    const decoded = try allocator.alloc(u8, input.len);
    defer allocator.free(decoded);
    try shrink.decodeInto(encoded.items, decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}

test "Shrink incremental encoder handles empty backpressure limits and reset" {
    const allocator = std.testing.allocator;
    var encoder = try shrink.IncrementalEncoder.init(allocator);
    defer encoder.deinit();
    const blocked = try encoder.step("payload", &.{});
    try std.testing.expectEqual(.need_output, blocked.status);
    try std.testing.expectEqual(@as(usize, 0), blocked.progress.input_read);
    encoder.finish();
    var scratch: [16]u8 = undefined;
    try std.testing.expectEqual(.done, (try encoder.step("", &scratch)).status);
    encoder.reset();

    var limited = try shrink.IncrementalEncoder.initWithOptions(allocator, .{
        .max_input_len = 3,
    });
    defer limited.deinit();
    _ = try limited.step("abc", &scratch);
    try std.testing.expectError(error.OutputLimitExceeded, limited.step("d", &scratch));

    var pledged = try shrink.IncrementalEncoder.initExactSize(allocator, .{}, 4);
    defer pledged.deinit();
    _ = try pledged.step("abc", &scratch);
    pledged.finish();
    try std.testing.expectError(error.SizeMismatch, pledged.step("", &scratch));
}
