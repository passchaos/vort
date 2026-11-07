const std = @import("std");
const h = @import("helpers.zig");
const f = @import("fixtures.zig");

pub fn contracts(comptime Z: type) !void {
    inline for (.{ .block_stream, .prevalidated_frame }) |policy| try stoppedMembers(Z, policy);
    try bindingState(Z);
    try dictionaryRequest(Z);
    try singleUsePrefix(Z);
}

fn stoppedMembers(comptime Z: type, policy: anytype) !void {
    const one = "first member bytes";
    const two = "second member appended after validated frame";
    const first = try f.rawBlocks(one, true, false, 7);
    defer h.a.free(first);
    const second = try f.rawBlocks(two, false, false, 13);
    defer h.a.free(second);
    const joined = try std.mem.concat(h.a, u8, &.{ first, second });
    defer h.a.free(joined);
    const expected = one ++ two;
    var buffer: [expected.len + 17]u8 = @splat(0xa5);
    var decoder = Z.NativeIncrementalFrameDecoder.initWithOptions(h.a, .{ .input_policy = policy, .stop_after_first_frame = true, .max_output_len = expected.len });
    defer decoder.deinit();
    try decoder.bindStableOutput(&buffer);
    try std.testing.expectError(error.InvalidStreamState, decoder.nextStream());
    var count: usize = 0;
    const read = try h.drive(&decoder, joined, &buffer, &count, expected, joined.len);
    try std.testing.expectEqual(one.len, count);
    try std.testing.expectEqual(second.len, decoder.trailingInput().len + joined.len - read);
    const idle = try h.step(&decoder, "", &buffer, &count, expected);
    try std.testing.expectEqual(@as(usize, 0), idle.progress.output_written);
    try decoder.nextStream();
    _ = try h.drive(&decoder, joined[read..], &buffer, &count, expected, 5);
    try std.testing.expectEqual(expected.len, count);
    try std.testing.expectEqual(@as(usize, 2), decoder.snapshot().data_frame_count);
    decoder.reset();
    try decoder.bindStableOutput(&buffer);
    count = 0;
    _ = try h.drive(&decoder, first, &buffer, &count, one, 1);
    try std.testing.expectEqual(one.len, count);
}

fn bindingState(comptime Z: type) !void {
    const plain = "binding remains fixed while a frame is active";
    const frame = try f.rawBlocks(plain, true, false, 11);
    defer h.a.free(frame);
    var buffer: [plain.len + 17]u8 = undefined;
    var replacement: [plain.len + 17]u8 = undefined;
    var decoder = Z.NativeIncrementalFrameDecoder.init(h.a);
    defer decoder.deinit();
    try std.testing.expectError(error.InvalidStreamState, decoder.stepStable(frame));
    decoder.reset();
    try decoder.bindStableOutput(&buffer);
    var count: usize = 0;
    _ = try h.step(&decoder, frame[0..1], &buffer, &count, plain);
    try std.testing.expectError(error.InvalidStreamState, decoder.bindStableOutput(&replacement));
    _ = try h.drive(&decoder, frame[1..], &buffer, &count, plain, 1);
    try decoder.resetWithOptions(.{ .format = .magicless });
    try decoder.bindStableOutput(&replacement);
    count = 0;
    _ = try h.drive(&decoder, frame[4..], &replacement, &count, plain, 7);
}

fn dictionaryRequest(comptime Z: type) !void {
    const earlier = "READY";
    const first = try f.rawBlocks(earlier, true, false, 5);
    defer h.a.free(first);
    const frame = try f.crossing(true, false, true, 42);
    defer h.a.free(frame);
    const joined = try std.mem.concat(h.a, u8, &.{ first, frame });
    defer h.a.free(joined);
    var buffer: [64]u8 = @splat(0xa5);
    var decoder = Z.NativeIncrementalFrameDecoder.init(h.a);
    defer decoder.deinit();
    try decoder.bindStableOutput(&buffer);
    var count = try h.refused(&decoder, joined, &buffer, 0, error.NeedDictionary);
    try std.testing.expectEqual(earlier.len, count);
    try std.testing.expectEqualStrings(earlier, buffer[0..count]);
    try std.testing.expectEqual(@as(?u32, 42), decoder.requiredDictionaryId());
    const accepted: usize = @intCast(decoder.snapshot().input_received);
    try decoder.provideDictionary(Z.NativeDictionary.init(42, f.crossing_dictionary));
    _ = try h.drive(&decoder, joined[accepted..], &buffer, &count, earlier ++ f.crossing_plain, 1);
    try std.testing.expectEqual(earlier.len + f.crossing_plain.len, count);
}

fn singleUsePrefix(comptime Z: type) !void {
    const frame = try f.crossing(true, false, true, 0);
    defer h.a.free(frame);
    var buffer: [64]u8 = @splat(0xa5);
    var decoder = Z.NativeIncrementalFrameDecoder.initWithPrefix(h.a, f.crossing_dictionary);
    defer decoder.deinit();
    try decoder.bindStableOutput(&buffer);
    try std.testing.expect(decoder.prefixSnapshot().pending);
    var count: usize = 0;
    _ = try h.step(&decoder, frame[0..1], &buffer, &count, f.crossing_plain);
    try std.testing.expect(decoder.prefixSnapshot().pending);
    _ = try h.drive(&decoder, frame[1..], &buffer, &count, f.crossing_plain, 1);
    try std.testing.expect(!decoder.prefixSnapshot().pending and !decoder.prefixSnapshot().active);
    _ = try h.refused(&decoder, frame, &buffer, count, error.InvalidMatch);
}
