const std = @import("std");
const lz4 = @import("../lz4.zig");
const h = @import("lz4_fast_controls_helpers.zig");
const a = std.testing.allocator;

test {
    _ = @import("lz4_fast_controls_aliases.zig");
}

test "LZ4 fast controls Into capacity failures leave caller output untouched and reusable state recovers" {
    const options: lz4.BlockEncodeOptions = .{ .acceleration = 8 };
    const expected = try lz4.encodeBlockWithOptionsAlloc(a, h.plain, options);
    defer a.free(expected);
    var output: [2048]u8 = @splat(0xa5);
    try std.testing.expectError(error.OutputTooSmall, lz4.encodeBlockIntoSliceWithOptions(a, h.plain, output[0 .. expected.len - 1], options));
    try h.untouched(&output);
    const size = try lz4.encodeBlockIntoSliceWithOptions(a, h.plain, &output, options);
    try std.testing.expectEqualSlices(u8, expected, output[0..size]);
    try h.untouched(output[size..]);
    const prefix = try lz4.encodeBlockWithPrefixAndOptionsAlloc(a, h.plain, h.prefix, options);
    defer a.free(prefix);
    @memset(&output, 0xa5);
    try std.testing.expectError(error.OutputTooSmall, lz4.encodeBlockWithPrefixIntoSliceAndOptions(a, h.plain, h.prefix, output[0 .. prefix.len - 1], options));
    try h.untouched(&output);
    var reusable = try lz4.BlockEncoder.init(a);
    defer reusable.deinit();
    const reused = try reusable.encodeWithPrefixIntoSliceAndOptions(h.plain, h.prefix, &output, options);
    try std.testing.expectEqualSlices(u8, prefix, output[0..reused]);
    const frame_options: lz4.NativeFrameOptions = .{ .acceleration = 8 };
    const frame = try lz4.encodePureFrameWithOptionsAlloc(a, h.plain, frame_options);
    defer a.free(frame);
    @memset(&output, 0xa5);
    try std.testing.expectError(error.OutputTooSmall, lz4.encodeNativeFrameIntoSlice(a, h.plain, frame_options, output[0 .. frame.len - 1]));
    try h.untouched(&output);
    const frame_size = try lz4.encodeNativeFrameIntoSlice(a, h.plain, frame_options, &output);
    try std.testing.expectEqualSlices(u8, frame, output[0..frame_size]);
    const dictionary: lz4.NativeDictionary = .{ .id = 42, .content = h.prefix };
    const dictionary_wire = try lz4.encodeNativeFrameWithDictionaryAlloc(a, h.plain, frame_options, dictionary);
    defer a.free(dictionary_wire);
    const dictionary_size = try lz4.encodeNativeFrameIntoSliceWithDictionary(a, h.plain, frame_options, dictionary, &output);
    try std.testing.expectEqualSlices(u8, dictionary_wire, output[0..dictionary_size]);
}

test "LZ4 fast controls raw append allocation refusal preserves caller prefix and records only attempted work" {
    var tracked = h.TrackingAllocator.init(a);
    tracked.force_copy_reallocation = true;
    const backing = tracked.allocator();
    var encoder = try lz4.BlockEncoder.init(backing);
    defer encoder.deinit();
    var output = std.ArrayList(u8).fromOwnedSlice(try backing.dupe(u8, "existing caller prefix"));
    defer output.deinit(backing);
    var profile: lz4.FastEncodeProfile = .{};
    const options: lz4.BlockEncodeOptions = .{ .acceleration = 8, .profile = &profile };
    tracked.fail_alloc_after = tracked.alloc_attempts;
    try std.testing.expectError(error.OutOfMemory, encoder.appendWithOptions(&output, h.plain, options));
    try std.testing.expectEqualSlices(u8, "existing caller prefix", output.items);
    tracked.clearFailures();
    const encoded_len = try encoder.appendWithOptions(&output, h.plain, options);
    try std.testing.expectEqualSlices(u8, "existing caller prefix", output.items[0.."existing caller prefix".len]);
    const decoded = try lz4.decodeBlockAlloc(a, output.items[output.items.len - encoded_len ..], h.plain.len);
    defer a.free(decoded);
    try std.testing.expectEqualSlices(u8, h.plain, decoded);
    try std.testing.expect(profile.blocks_attempted > 0);
    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(a);
    try appended.appendSlice(a, "prefix");
    const one_shot = try lz4.encodeBlockWithOptionsAppend(a, &appended, h.plain, options);
    try std.testing.expectEqualSlices(u8, "prefix", appended.items[0..6]);
    const raw = try lz4.encodeBlockWithOptionsAlloc(a, h.plain, options);
    defer a.free(raw);
    try std.testing.expectEqualSlices(u8, raw, appended.items[appended.items.len - one_shot ..]);
    appended.shrinkRetainingCapacity(6);
    const with_prefix = try lz4.encodeBlockWithPrefixAndOptionsAppend(a, &appended, h.plain, h.prefix, options);
    const expected = try lz4.encodeBlockWithPrefixAndOptionsAlloc(a, h.plain, h.prefix, options);
    defer a.free(expected);
    try std.testing.expectEqualSlices(u8, expected, appended.items[appended.items.len - with_prefix ..]);
}

test "LZ4 fast controls incremental allocation retry and next frame reset preserve controls and counters" {
    var tracked = h.TrackingAllocator.init(a);
    tracked.force_copy_reallocation = true;
    var profile: lz4.FastEncodeProfile = .{};
    var options: lz4.NativeFrameOptions = .{ .acceleration = 8, .profile = &profile };
    var encoder = try lz4.NativeIncrementalFrameEncoder.initExactSize(tracked.allocator(), options, h.plain.len);
    defer encoder.deinit();
    var prefix: [64]u8 = undefined;
    const header = try encoder.step("", &prefix);
    try std.testing.expect(header.progress.output_written > 0);
    const accepted = try encoder.step(h.plain, &.{});
    try std.testing.expectEqual(h.plain.len, accepted.progress.input_read);
    encoder.finish();
    const before = encoder.snapshot();
    const pending = try a.dupe(u8, encoder.pending.items);
    defer a.free(pending);
    tracked.fail_alloc_after = tracked.alloc_attempts;
    var output: [128]u8 = @splat(0xa5);
    try std.testing.expectError(error.OutOfMemory, encoder.step("", &output));
    try h.untouched(&output);
    try std.testing.expectEqual(before.frame_input, encoder.snapshot().frame_input);
    try std.testing.expectEqual(before.frame_output, encoder.snapshot().frame_output);
    try std.testing.expectEqual(before.buffered_input, encoder.snapshot().buffered_input);
    try std.testing.expectEqualSlices(u8, pending, encoder.pending.items);
    tracked.clearFailures();
    const tail = try h.drive(a, &encoder, h.plain, 1, 1);
    defer a.free(tail);
    const first = try std.mem.concat(a, u8, &.{ prefix[0..header.progress.output_written], tail });
    defer a.free(first);
    const decoded = try lz4.decodeFrameAlloc(a, first);
    defer a.free(decoded);
    try std.testing.expectEqualSlices(u8, h.plain, decoded);
    const count = encoder.snapshot().frame_count;
    const attempted = profile.blocks_attempted;
    options.acceleration = 1;
    try encoder.nextFrameExactSize(options, h.plain.len);
    const second = try h.drive(a, &encoder, h.plain, 31, 17);
    defer a.free(second);
    try std.testing.expectEqual(count + 1, encoder.snapshot().frame_count);
    try std.testing.expectEqual(@as(u32, 1), profile.resolved_acceleration);
    try std.testing.expect(profile.blocks_attempted > attempted);
    encoder.reset();
    const empty = encoder.snapshot();
    try std.testing.expectEqual(@as(usize, 0), empty.input_read);
    try std.testing.expectEqual(@as(usize, 0), empty.output_written);
    try std.testing.expectEqual(@as(usize, 0), empty.frame_count);
    const repeated = try h.drive(a, &encoder, h.plain, 1, 1);
    defer a.free(repeated);
    try std.testing.expectEqualSlices(u8, second, repeated);
}
