const std = @import("std");
const core = @import("../../core.zig");
const h = @import("helpers.zig");
const a = h.a;

pub fn contracts(comptime Z: type) !void {
    const dictionary = Z.NativeDictionary.init(h.id, h.plain);
    var tracker = h.memory.Tracker.init(a);
    const heap = tracker.allocator();
    var profile: Z.EncodeMemoryProfile = .{};
    var options: Z.NativeFrameOptions = .{ .include_dictionary_id = false, .selection = .literal_only, .memory_profile = &profile };
    const encoded = try Z.encodeNativeFrameWithDictionaryAlloc(heap, h.plain, options, dictionary);
    try std.testing.expect(profile.available);
    try std.testing.expectEqual(tracker.peak, profile.peak_requested_bytes);
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    const peak = tracker.peak;
    heap.free(encoded.frame);
    try std.testing.expectEqual(@as(usize, 0), tracker.live);
    tracker.begin();
    profile.reset();
    options.max_total_working_memory = peak;
    const exact = try Z.encodeNativeFrameWithDictionaryAlloc(heap, h.plain, options, dictionary);
    defer heap.free(exact.frame);
    try std.testing.expectEqual(peak, tracker.peak);
    try h.check(Z, exact.frame, h.plain, .standard, dictionary);

    const output = try a.alloc(u8, exact.frame.len + 17);
    defer a.free(output);
    @memset(output, 0xa5);
    options.max_total_working_memory = 0;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, Z.encodeNativeFrameIntoSliceWithDictionary(a, h.plain, options, dictionary, output));
    try h.wire.untouched(output);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(a);
    try out.appendSlice(a, "prefix");
    const pointer = out.items.ptr;
    const capacity = out.capacity;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, Z.encodeNativeFrameAppendWithDictionary(a, &out, h.plain, options, dictionary));
    try std.testing.expectEqualStrings("prefix", out.items);
    try std.testing.expectEqual(pointer, out.items.ptr);
    try std.testing.expectEqual(capacity, out.capacity);
    options.max_total_working_memory = null;
    try std.testing.expectError(error.OutputTooSmall, Z.encodeNativeFrameIntoSliceWithDictionary(a, h.plain, options, dictionary, output[0 .. exact.frame.len - 1]));
    try h.wire.untouched(output);

    var denied = std.testing.FailingAllocator.init(a, .{ .fail_index = 0 });
    const entries = [_]Z.NativeDictionary{dictionary};
    const set = Z.NativeDictionarySet.init(&entries);
    const omitted: Z.NativeFrameOptions = .{ .include_dictionary_id = false };
    try std.testing.expectError(error.NeedDictionary, Z.encodeNativeFrameWithDictionarySetAlloc(denied.allocator(), h.plain, omitted, set, 0));
    try std.testing.expectEqual(@as(usize, 0), denied.alloc_index);
    try std.testing.expectError(error.NeedDictionary, Z.encodeNativeFrameWithDictionarySetAlloc(denied.allocator(), h.plain, omitted, set, h.id + 1));
    try std.testing.expectEqual(@as(usize, 0), denied.alloc_index);
    try std.testing.expectError(error.IntegerOverflow, Z.encodedNativeFrameBoundWithDictionary(std.math.maxInt(usize), omitted, dictionary));
    try wideCount(Z, dictionary);
}

fn wideCount(comptime Z: type, dictionary: Z.NativeDictionary) !void {
    const expected: core.StreamCount = @as(core.StreamCount, std.math.maxInt(u32)) + 1;
    const options: Z.NativeFrameOptions = .{ .dictionary_id = dictionary.id, .include_dictionary_id = false, .include_content_size = true, .selection = .raw_or_rle, .window_log = 10, .block_size_max = 128 };
    var encoder = try Z.NativeIncrementalFrameEncoder.initExactSizeWithDictionary(a, options, expected, dictionary.id);
    defer encoder.deinit();
    try std.testing.expectEqual(dictionary.id, encoder.options.dictionary_id);
    try std.testing.expectEqual(@as(?u32, dictionary.id), encoder.dictionary_id);
    var output: [64]u8 = @splat(0xa5);
    const step = try encoder.step(&.{}, &output);
    try std.testing.expectEqual(@as(usize, 0), step.progress.input_read);
    const header = try h.wire.header(output[0..step.progress.output_written], false);
    try std.testing.expectEqual(@as(u32, 0), header.dictionary_id);
    try std.testing.expectEqual(@as(?u64, expected), header.content_size);
    try std.testing.expectEqual(@as(usize, 8), header.content_width);
    try h.wire.untouched(output[step.progress.output_written..]);
}
