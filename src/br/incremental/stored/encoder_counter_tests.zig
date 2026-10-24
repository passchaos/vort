const std = @import("std");
const incremental = @import("encoder.zig");
const Codec = @import("encoder_tests.zig").TransactionCodec;
const Encoder = incremental.Encoder(Codec);
const Counter = Encoder.Counter;

test "Brotli HQ generic counters cross 4 GiB and continue streams without large buffers" {
    try std.testing.expectEqual(if (@bitSizeOf(usize) < 64) u64 else usize, Counter);
    try std.testing.expectEqual(std.math.maxInt(Counter), (Encoder.Options{}).max_input_len);
    const base: Counter = (@as(Counter, 1) << 32) - 1;
    var encoder = Encoder.init(std.testing.allocator);
    defer encoder.deinit();
    encoder.total_input = base;
    encoder.stream_input = base;
    encoder.total_output = base;
    encoder.stream_output = base;
    const accepted = try encoder.step("ab", &.{});
    try std.testing.expectEqual(@as(usize, 2), accepted.progress.input_read);
    try std.testing.expectEqual(base + 2, encoder.snapshot().input_read);
    try std.testing.expectEqual(base + 2, encoder.snapshot().stream_input);
    try encoder.finish();
    var output: [8]u8 = undefined;
    const first = try encoder.step(&.{}, &output);
    try std.testing.expectEqual(.done, first.status);
    try std.testing.expectEqual(@as(usize, 4), first.progress.output_written);
    try std.testing.expectEqual(base + 4, encoder.snapshot().output_written);
    try std.testing.expectEqual(base + 4, encoder.snapshot().stream_output);
    try encoder.nextStream(.{});
    try std.testing.expectEqual(base + 2, encoder.snapshot().input_read);
    try std.testing.expectEqual(@as(Counter, 0), encoder.snapshot().stream_input);
    try std.testing.expectEqual(base + 4, encoder.snapshot().output_written);
    try std.testing.expectEqual(@as(Counter, 0), encoder.snapshot().stream_output);
    _ = try encoder.step("cd", &.{});
    try encoder.finish();
    const second = try encoder.step(&.{}, &output);
    try std.testing.expectEqual(.done, second.status);
    try std.testing.expectEqual(base + 4, encoder.snapshot().input_read);
    try std.testing.expectEqual(@as(Counter, 2), encoder.snapshot().stream_input);
    try std.testing.expectEqual(base + 8, encoder.snapshot().output_written);
    try std.testing.expectEqual(@as(Counter, 4), encoder.snapshot().stream_output);
    try std.testing.expectEqual(@as(usize, 2), encoder.snapshot().stream_count);
    try std.testing.expectEqual(@as(usize, 1), encoder.snapshot().stream_index);
}

test "Brotli HQ generic counters reject offered input overflow before changing state" {
    for ([_]bool{ false, true }) |cumulative| {
        var encoder = Encoder.init(std.testing.allocator);
        defer encoder.deinit();
        if (cumulative) encoder.stream_input = std.math.maxInt(Counter) else encoder.total_input = std.math.maxInt(Counter);
        const before = encoder.snapshot();
        var output: [1]u8 = .{0xaa};
        try std.testing.expectError(error.IntegerOverflow, encoder.step("x", &output));
        try std.testing.expectEqual(before, encoder.snapshot());
        try std.testing.expect(!encoder.prefix_written);
        try std.testing.expectEqual(@as(usize, 0), encoder.pending.items.len);
        try std.testing.expectEqualSlices(u8, &.{0xaa}, &output);
    }
    const base: Counter = (@as(Counter, 1) << 32) - 1;
    var limited = Encoder.initWithOptions(std.testing.allocator, .{ .max_input_len = base + 1 });
    defer limited.deinit();
    limited.total_input = base;
    limited.stream_input = base;
    const before = limited.snapshot();
    try std.testing.expectError(error.OutputLimitExceeded, limited.step("xy", &.{}));
    try std.testing.expectEqual(before, limited.snapshot());
    try std.testing.expectEqual(@as(usize, 1), (try limited.step("x", &.{})).progress.input_read);
    try std.testing.expectEqual(base + 1, limited.snapshot().input_read);
}

test "Brotli HQ generic counters reject output overflow before copying or advancing offsets" {
    for ([_]bool{ false, true }) |cumulative| {
        var encoder = Encoder.init(std.testing.allocator);
        defer encoder.deinit();
        encoder.prefix_written = true;
        try encoder.pending.append(std.testing.allocator, 0x45);
        if (cumulative) encoder.stream_output = std.math.maxInt(Counter) else encoder.total_output = std.math.maxInt(Counter);
        const before = encoder.snapshot();
        var output: [1]u8 = .{0xaa};
        try std.testing.expectError(error.IntegerOverflow, encoder.step(&.{}, &output));
        try std.testing.expectEqual(before, encoder.snapshot());
        try std.testing.expectEqual(@as(usize, 0), encoder.pending_offset);
        try std.testing.expectEqualSlices(u8, &.{0x45}, encoder.pending.items);
        try std.testing.expectEqualSlices(u8, &.{0xaa}, &output);
        if (cumulative) encoder.stream_output -= 1 else encoder.total_output -= 1;
        try std.testing.expectEqual(@as(usize, 1), (try encoder.step(&.{}, &output)).progress.output_written);
        try std.testing.expectEqual(std.math.maxInt(Counter), if (cumulative) encoder.stream_output else encoder.total_output);
        try std.testing.expectEqualSlices(u8, &.{0x45}, &output);
    }
}

test "Brotli HQ generic counters retain accepted input and prior output on later overflow" {
    var encoder = Encoder.initWithOptions(std.testing.allocator, .{ .stream = .{ .deferred = false } });
    defer encoder.deinit();
    encoder.prefix_written = true;
    encoder.codec_state.bit_index = 1;
    try encoder.pending.appendSlice(std.testing.allocator, &.{ 0x77, 0x01 });
    encoder.total_output = std.math.maxInt(Counter) - 1;
    encoder.stream_output = std.math.maxInt(Counter) - 1;
    var output: [3]u8 = @splat(0xaa);
    try std.testing.expectError(error.IntegerOverflow, encoder.step("abcd", &output));
    try std.testing.expectEqual(std.math.maxInt(Counter), encoder.snapshot().output_written);
    try std.testing.expectEqual(std.math.maxInt(Counter), encoder.snapshot().stream_output);
    try std.testing.expectEqualSlices(u8, &.{ 0x77, 0xaa, 0xaa }, &output);
    try std.testing.expectEqual(@as(Counter, 4), encoder.snapshot().input_read);
    try std.testing.expectEqual(@as(Counter, 4), encoder.snapshot().stream_input);
    try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().buffered_input);
    try std.testing.expectEqual(@as(usize, 5), encoder.snapshot().pending_output);
    try std.testing.expectEqual(@as(usize, 1), encoder.codec_state.blocks);
    try std.testing.expectEqualSlices(u8, "abcd", encoder.codec_state.history[0..encoder.codec_state.history_len]);
    try std.testing.expectEqual(@as(usize, 1), encoder.pending_offset);
    try std.testing.expectEqualSlices(u8, &.{ 0x21, 'a', 'b', 'c', 'd', 0x01 }, encoder.pending.items[encoder.pending_offset..]);
}

test "Brotli HQ generic counters check stream completion overflow" {
    var encoder = Encoder.init(std.testing.allocator);
    defer encoder.deinit();
    encoder.prefix_written = true;
    encoder.final_written = true;
    encoder.finishing = true;
    encoder.stream_count = std.math.maxInt(Counter);
    const before = encoder.snapshot();
    try std.testing.expectError(error.IntegerOverflow, encoder.step(&.{}, &.{}));
    try std.testing.expectEqual(before, encoder.snapshot());
    encoder.stream_count -= 1;
    try std.testing.expectEqual(.done, (try encoder.step(&.{}, &.{})).status);
    try std.testing.expectEqual(std.math.maxInt(Counter), encoder.snapshot().stream_count);
    try std.testing.expectEqual(std.math.maxInt(Counter) - 1, encoder.snapshot().stream_index);
}
