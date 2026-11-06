const std = @import("std");
const checksum = @import("../../checksum.zig");
const h = @import("helpers.zig");
const a = h.a;

pub fn contracts(comptime Z: type) !void {
    for ([_]Z.NativeDictionary{
        Z.NativeDictionary.initRawContent(h.plain),
        Z.NativeDictionary.init(42, h.plain),
    }) |dictionary| {
        for ([_]Z.FrameFormat{ .standard, .magicless }) |format| {
            const encoded = try Z.encodeNativeFrameWithDictionaryAlloc(a, h.plain ** 2, .{ .format = format, .content_checksum = true, .strategy = .fast }, dictionary);
            defer a.free(encoded.frame);
            try boundary(Z, encoded.frame, h.plain ** 2, .{ .format = format, .dictionary = dictionary });
            if (dictionary.id != 0) {
                const entries = [_]Z.NativeDictionary{dictionary};
                try boundary(Z, encoded.frame, h.plain ** 2, .{ .format = format, .dictionary_set = Z.NativeDictionarySet.init(&entries) });
            }
        }
    }

    const dictionary_bytes = try h.hexAlloc(@embedFile("../../zstd/testdata/libzstd-trained-repeat.dict.hex"));
    defer a.free(dictionary_bytes);
    const frame = try h.hexAlloc(@embedFile("../../zstd/testdata/libzstd-trained-repeat.frame.hex"));
    defer a.free(frame);
    const standard = try Z.NativeDictionary.initFromStandardDictionary(dictionary_bytes);
    const payload = try Z.decodeFrameAllocWithOptions(a, frame, .{ .dictionary = standard.dictionary });
    defer a.free(payload);
    // The expected reference corpus output is pinned independently of quota.
    try std.testing.expectEqual(@as(usize, 2304), payload.len);
    try std.testing.expectEqual(@as(u32, 1_658_167_111), checksum.crc32(payload));
    var prepared = try Z.PreparedDecodeDictionary.init(standard.dictionary);
    for ([_]Z.NativeDictionary{ standard.dictionary, prepared.handle() }) |dictionary| {
        try boundary(Z, frame, payload, .{ .dictionary = dictionary });
        try boundary(Z, frame[4..], payload, .{ .format = .magicless, .dictionary = dictionary });
        const entries = [_]Z.NativeDictionary{dictionary};
        try boundary(Z, frame, payload, .{ .dictionary_set = Z.NativeDictionarySet.init(&entries) });
    }
    try std.testing.expectEqualSlices(u8, dictionary_bytes, standard.dictionary.standard_bytes.?);
}

fn boundary(comptime Z: type, frame: []const u8, payload: []const u8, base: Z.FrameDecodeOptions) !void {
    var denied = std.testing.FailingAllocator.init(a, .{ .fail_index = 0 });
    var size_profile: Z.DecodeMemoryProfile = .{};
    var size_options = base;
    size_options.max_total_working_memory = 0;
    size_options.memory_profile = &size_profile;
    var size_decoder = Z.NativeFrameDecoder.initWithOptions(denied.allocator(), size_options);
    defer size_decoder.deinit();
    try std.testing.expectEqual(payload.len, try Z.decodedFrameSizeWithOptions(frame, size_options));
    try std.testing.expectEqual(payload.len, try size_decoder.decodedSize(frame));
    try std.testing.expectEqual(@as(usize, 0), denied.alloc_index);
    try std.testing.expect(!size_profile.available);

    var tracker = h.Tracker.init(a);
    const heap = tracker.allocator();
    var profile: Z.DecodeMemoryProfile = .{};
    var options = base;
    options.memory_profile = &profile;
    const decoded = try Z.decodeFrameAllocWithOptions(heap, frame, options);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    try h.profileMatches(profile, &tracker, 0);
    const peak = tracker.peak;
    heap.free(decoded);
    try std.testing.expectEqual(@as(usize, 0), tracker.live);
    const output = try a.alloc(u8, payload.len);
    defer a.free(output);
    var decoder = Z.NativeFrameDecoder.initWithOptions(heap, options);
    defer decoder.deinit();
    @memset(output, 0xa5);
    options.max_total_working_memory = peak - 1;
    profile.reset();
    tracker.begin();
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, Z.decodeFrameAllocWithOptions(heap, frame, options));
    try std.testing.expectEqual(@as(usize, 0), tracker.live);
    options.max_total_working_memory = peak;
    profile.reset();
    tracker.begin();
    const exact = try Z.decodeFrameAllocWithOptions(heap, frame, options);
    try std.testing.expectEqualSlices(u8, payload, exact);
    try h.profileMatches(profile, &tracker, 0);
    heap.free(exact);
    // A reusable dictionary decoder has its own retained owner; measure it
    // independently rather than assuming one-shot and reusable peaks agree.
    decoder.options.max_total_working_memory = null;
    profile.reset();
    tracker.begin();
    try std.testing.expectEqual(payload.len, try decoder.decodeIntoSlice(frame, output));
    try std.testing.expectEqualSlices(u8, payload, output);
    try h.profileMatches(profile, &tracker, tracker.live);
    try std.testing.expectEqual(tracker.live, decoder.memorySnapshot().live_requested_bytes);
    @memset(output, 0xa5);
    decoder.options.max_total_working_memory = tracker.live - 1;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, decoder.decodeIntoSliceWithDictionary(frame, output, base.dictionary orelse base.dictionary_set.?.dictionaries[0]));
    try h.untouched(output);
    decoder.options.max_total_working_memory = null;
    try std.testing.expectEqual(payload.len, try decoder.decodeIntoSlice(frame, output));
    try std.testing.expectEqualSlices(u8, payload, output);
}
