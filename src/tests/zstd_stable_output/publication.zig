const std = @import("std");
const h = @import("helpers.zig");
const f = @import("fixtures.zig");

pub fn contracts(comptime Z: type) !void {
    for ([_]Z.FrameFormat{ .standard, .magicless }) |format| {
        inline for (.{ .block_stream, .prevalidated_frame }) |policy| {
            try checksumFailure(Z, format, policy);
            try footerCompleteness(Z, format, policy);
            try limits(Z, format, policy);
        }
    }
}

fn feed(decoder: anytype, input: []const u8, buffer: []u8, count: *usize, expected: []const u8) !void {
    var read: usize = 0;
    var calls: usize = 0;
    while (read != input.len) : (calls += 1) {
        try std.testing.expect(calls < input.len * 4 + 1024);
        const result = try h.step(decoder, input[read..@min(input.len, read + 7)], buffer, count, expected);
        read += result.progress.input_read;
    }
}

fn checksumFailure(comptime Z: type, format: Z.FrameFormat, policy: anytype) !void {
    const guard = "SAFE";
    const plain = "checksum errors preserve bytes published by earlier returns";
    const first = try f.rawBlocks(guard, true, format == .magicless, 37);
    defer h.a.free(first);
    const broken = try f.rawBlocks(plain, true, format == .magicless, 37);
    defer h.a.free(broken);
    broken[broken.len - 1] ^= 1;
    const expected = guard ++ plain;
    var buffer: [expected.len + 17]u8 = @splat(0xa5);
    var decoder = Z.NativeIncrementalFrameDecoder.initWithOptions(h.a, .{ .format = format, .input_policy = policy });
    defer decoder.deinit();
    try decoder.bindStableOutput(&buffer);
    var count: usize = 0;
    _ = try h.drive(&decoder, first, &buffer, &count, expected, 3);
    try feed(&decoder, broken[0 .. broken.len - 4], &buffer, &count, expected);
    count = try h.refused(&decoder, broken[broken.len - 4 ..], &buffer, count, error.ChecksumMismatch);
    try std.testing.expectEqualStrings(guard, buffer[0..guard.len]);
    count = try h.refused(&decoder, "", &buffer, count, error.ChecksumMismatch);
    decoder.reset();
    try decoder.bindStableOutput(&buffer);
    count = 0;
    _ = try h.drive(&decoder, first, &buffer, &count, guard, 1);
}

fn footerCompleteness(comptime Z: type, format: Z.FrameFormat, policy: anytype) !void {
    const plain = "a checksum opt-out still requires four actual footer bytes";
    const frame = try f.rawBlocks(plain, true, format == .magicless, 19);
    defer h.a.free(frame);
    frame[frame.len - 1] ^= 0x80;
    var buffer: [plain.len + 17]u8 = @splat(0xa5);
    var ignored = Z.NativeIncrementalFrameDecoder.initWithOptions(h.a, .{ .format = format, .input_policy = policy, .ignore_content_checksum = true });
    defer ignored.deinit();
    try ignored.bindStableOutput(&buffer);
    var count: usize = 0;
    _ = try h.drive(&ignored, frame, &buffer, &count, plain, 1);
    try std.testing.expectEqual(plain.len, count);
    for (1..5) |missing| {
        var decoder = Z.NativeIncrementalFrameDecoder.initWithOptions(h.a, .{ .format = format, .input_policy = policy, .ignore_content_checksum = true });
        defer decoder.deinit();
        try decoder.bindStableOutput(&buffer);
        count = 0;
        try feed(&decoder, frame[0 .. frame.len - missing], &buffer, &count, plain);
        const saved = try h.a.dupe(u8, buffer[0..count]);
        defer h.a.free(saved);
        try std.testing.expectError(error.TruncatedFrame, decoder.finish());
        try std.testing.expectEqualSlices(u8, saved, buffer[0..count]);
        try h.published(&decoder, &buffer, count);
    }
}

fn limits(comptime Z: type, format: Z.FrameFormat, policy: anytype) !void {
    const plain = "stable output caps stay independent of bound capacity";
    inline for (.{ false, true }) |known| {
        const frame = try f.rawBlocks(plain, known, format == .magicless, 13);
        defer h.a.free(frame);
        var buffer: [plain.len + 17]u8 = @splat(0xa5);
        for ([_]Z.NativeIncrementalFrameDecoder.Options{
            .{ .format = format, .input_policy = policy, .max_output_len = plain.len - 1 },
            .{ .format = format, .input_policy = policy, .max_decoded_buffer_len = plain.len - 1 },
        }) |options| {
            var decoder = Z.NativeIncrementalFrameDecoder.initWithOptions(h.a, options);
            defer decoder.deinit();
            try decoder.bindStableOutput(&buffer);
            _ = try h.refused(&decoder, frame, &buffer, 0, error.OutputLimitExceeded);
        }
        var exact = Z.NativeIncrementalFrameDecoder.initWithOptions(h.a, .{ .format = format, .input_policy = policy, .expected_output_len = plain.len - 1 });
        defer exact.deinit();
        try exact.bindStableOutput(&buffer);
        _ = try h.refused(&exact, frame, &buffer, 0, error.SizeMismatch);
    }
}
