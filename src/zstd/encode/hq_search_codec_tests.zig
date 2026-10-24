const std = @import("std");
const zstd = @import("../../zstd.zig");
const a = std.testing.allocator;
const payload = "prefix-abcdefgh-abcdefgh-abcdefghXabcdefghYabcdefgh-tail" ** 3;

fn options(profile: ?*zstd.EncoderControlProfile) zstd.NativeFrameOptions {
    return .{ .strategy = .btopt, .content_checksum = true, .block_size_max = 64, .control_profile = profile, .hq = .{ .search_depth = 8, .nice_len = 32, .parse_mode = .whole_block, .match_lengths = .complete } };
}

fn verify(frame: []const u8, plain: []const u8) !void {
    const decoded = try zstd.decodeNativeFrameAlloc(a, frame);
    defer a.free(decoded);
    try std.testing.expectEqualSlices(u8, plain, decoded);
}

test "Zstd HQ codec whole frame safeguard compares corresponding complete wires with two searches per block" {
    var profile: zstd.EncoderControlProfile = .{};
    const requested = options(&profile);
    var baseline = requested;
    baseline.control_profile = null;
    baseline.hq.?.parse_mode = .bounded;
    baseline.hq.?.match_lengths = .sampled;
    const reference = try zstd.encodeNativeFrameWithOptionsAlloc(a, payload, baseline);
    defer a.free(reference.frame);
    const actual = try zstd.encodeNativeFrameWithOptionsAlloc(a, payload, requested);
    defer a.free(actual.frame);
    try verify(actual.frame, payload);
    try std.testing.expect(actual.frame.len <= reference.frame.len);
    const block_count = (payload.len + requested.block_size_max - 1) / requested.block_size_max;
    try std.testing.expectEqual(@as(u64, block_count), profile.whole_block_passes);
    try std.testing.expectEqual(@as(u64, block_count), profile.bounded_passes);
    try std.testing.expectEqual(@as(u64, block_count), profile.baseline_searches);
    try std.testing.expectEqual(@as(u64, 1), profile.guarded_frames);
    try std.testing.expectEqual(@as(u64, 0), profile.baseline_selected_blocks);
    try std.testing.expectEqual(@as(u64, block_count), profile.raw_blocks + profile.rle_blocks + profile.compressed_blocks);
    try std.testing.expectEqual(@as(?zstd.HqParseMode, .whole_block), profile.effective_hq_parse_mode);
    try std.testing.expectEqual(@as(?zstd.HqMatchLengthPolicy, .complete), profile.effective_hq_match_lengths);
}

test "Zstd HQ codec options reach native level reusable append slice and dictionary entrypoints" {
    const native = options(null);
    const reference = try zstd.encodeNativeFrameWithOptionsAlloc(a, payload, native);
    defer a.free(reference.frame);
    var encoder = zstd.NativeFrameEncoder.init(a);
    defer encoder.deinit();
    const scratch = try encoder.encodeScratch(payload, native);
    try std.testing.expectEqualSlices(u8, reference.frame, scratch.frame);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(a);
    try out.appendSlice(a, "prefix:");
    _ = try encoder.encodeAppend(&out, payload, native);
    try std.testing.expectEqualSlices(u8, reference.frame, out.items[7..]);
    const destination = try a.alloc(u8, reference.frame.len);
    defer a.free(destination);
    const written = try encoder.encodeIntoSlice(payload, native, destination);
    try std.testing.expectEqual(reference.frame.len, written.written);
    try std.testing.expectEqualSlices(u8, reference.frame, destination);

    const frame_options: zstd.FrameOptions = .{ .strategy = .btopt, .content_checksum = true, .hq = native.hq };
    const frame = try zstd.encodeFrameWithLevelAndOptionsAlloc(a, payload, 3, frame_options);
    defer a.free(frame);
    var level = zstd.LevelFrameEncoder.init(a);
    defer level.deinit();
    try std.testing.expectEqualSlices(u8, frame, try level.encodeScratchWithOptions(payload, 3, frame_options));
    try verify(frame, payload);

    const dictionary = zstd.NativeDictionary.init(42, "prefix-abcdefgh-abcdefghXabcdefghYabcdefgh-tail");
    const dictionary_frame = try zstd.encodeNativeFrameWithDictionaryAlloc(a, payload, native, dictionary);
    defer a.free(dictionary_frame.frame);
    const set = try zstd.NativeDictionarySet.initChecked(&.{dictionary});
    const from_set = try zstd.encodeNativeFrameWithDictionarySetAlloc(a, payload, native, set, dictionary.id);
    defer a.free(from_set.frame);
    try std.testing.expectEqualSlices(u8, dictionary_frame.frame, from_set.frame);
    const decoded = try zstd.decodeNativeFrameAllocWithDictionary(a, dictionary_frame.frame, dictionary);
    defer a.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
}

test "Zstd HQ codec explicit cap uses one path and failed expanded requests never substitute baseline" {
    for ([_]bool{ false, true }) |expanded| {
        var profile: zstd.EncoderControlProfile = .{ .compressed_blocks = 7 };
        var selected = options(&profile);
        selected.hq.?.max_price_evaluations = 0;
        if (!expanded) {
            selected.hq.?.parse_mode = .bounded;
            selected.hq.?.match_lengths = .sampled;
        }
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(a);
        try out.appendSlice(a, "prefix:");
        try std.testing.expectError(error.SearchLimitExceeded, zstd.encodeNativeFrameAppend(a, &out, payload, selected));
        try std.testing.expectEqualSlices(u8, "prefix:", out.items);
        try std.testing.expectEqual(@as(u64, 7), profile.compressed_blocks);
        try std.testing.expectEqual(@as(u64, 0), profile.baseline_searches);
        try std.testing.expectEqual(@as(u64, @intFromBool(expanded)), profile.guarded_frames);
        try std.testing.expectEqual(@as(u64, 1), profile.price_limit_refusals);
    }
    var profile: zstd.EncoderControlProfile = .{};
    var cap_only = options(&profile);
    cap_only.hq.?.parse_mode = .bounded;
    cap_only.hq.?.match_lengths = .sampled;
    cap_only.hq.?.max_price_evaluations = std.math.maxInt(u64);
    const encoded = try zstd.encodeNativeFrameWithOptionsAlloc(a, payload, cap_only);
    defer a.free(encoded.frame);
    try verify(encoded.frame, payload);
    try std.testing.expectEqual(@as(u64, 0), profile.guarded_frames);
    try std.testing.expectEqual(@as(u64, 0), profile.baseline_searches);
    try std.testing.expectEqual(@as(u64, 0), profile.whole_block_passes);
}

test "Zstd HQ codec reusable search failure preserves previous scratch output and emitted state" {
    for ([_]bool{ false, true }) |expanded| {
        var profile: zstd.EncoderControlProfile = .{};
        var selected = options(&profile);
        if (!expanded) {
            selected.hq.?.parse_mode = .bounded;
            selected.hq.?.match_lengths = .sampled;
        }
        var encoder = zstd.NativeFrameEncoder.init(a);
        defer encoder.deinit();
        const completed = try encoder.encodeScratch(payload, selected);
        const expected = try a.dupe(u8, completed.frame);
        defer a.free(expected);
        selected.hq.?.max_price_evaluations = 0;
        const before = profile.emitted();
        try std.testing.expectError(error.SearchLimitExceeded, encoder.encodeScratch(payload, selected));
        try std.testing.expectEqualSlices(u8, expected, encoder.output_scratch.items);
        try std.testing.expectEqual(before, profile.emitted());
        selected.hq.?.max_price_evaluations = std.math.maxInt(u64);
        try std.testing.expectEqualSlices(u8, expected, (try encoder.encodeScratch(payload, selected)).frame);
    }
}

test "Zstd HQ codec seekable later search failure preserves all caller output and committed entries" {
    const first = "0123456789ABCDEFGHIJKLMNOPQRSTUV";
    const second = "abcdabcdabcdabcdabcdabcdabcdabcd";
    const mixed = first ++ second;
    for ([_]bool{ false, true }) |expanded| {
        var profile: zstd.EncoderControlProfile = .{};
        var frame_options = options(&profile);
        if (!expanded) {
            frame_options.hq.?.parse_mode = .bounded;
            frame_options.hq.?.match_lengths = .sampled;
        }
        var settings: zstd.NativeSeekableOptions = .{ .frame_size = first.len, .frame_options = frame_options, .seek_checksums = true };
        var encoder = zstd.NativeSeekableStreamEncoder.init(a);
        defer encoder.deinit();
        const initial = try encoder.encodeScratch(first ++ first, settings);
        const old_wire = try a.dupe(u8, initial);
        defer a.free(old_wire);
        const old_entries = try a.dupe(zstd.NativeSeekTableFrameSize, encoder.entries.items);
        defer a.free(old_entries);
        settings.frame_options.hq.?.max_price_evaluations = 0;
        const before = profile.emitted();
        var destination: [512]u8 = @splat(0xa5);
        try std.testing.expectError(error.SearchLimitExceeded, encoder.encodeIntoSlice(mixed, settings, &destination));
        for (destination) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
        try std.testing.expectEqualDeep(old_entries, encoder.entries.items);
        try std.testing.expectEqualSlices(u8, old_wire, encoder.output_scratch.items);
        try std.testing.expectEqual(before, profile.emitted());
        try std.testing.expect(profile.price_limit_refusals != 0);
        var appended: std.ArrayList(u8) = .empty;
        defer appended.deinit(a);
        try appended.appendSlice(a, "prefix:");
        const old_ptr = appended.items.ptr;
        const old_capacity = appended.capacity;
        try std.testing.expectError(error.SearchLimitExceeded, encoder.encodeAppend(&appended, mixed, settings));
        try std.testing.expectEqualSlices(u8, "prefix:", appended.items);
        try std.testing.expect(appended.items.ptr == old_ptr);
        try std.testing.expectEqual(old_capacity, appended.capacity);
        try std.testing.expectEqualDeep(old_entries, encoder.entries.items);
        try std.testing.expectError(error.SearchLimitExceeded, encoder.encodeScratch(mixed, settings));
        try std.testing.expectEqualSlices(u8, old_wire, encoder.output_scratch.items);
        try std.testing.expectEqualDeep(old_entries, encoder.entries.items);
    }
}
