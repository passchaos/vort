const std = @import("std");
const h = @import("helpers.zig");
const f = @import("fixtures.zig");

pub fn contracts(comptime Z: type) !void {
    try inputAliases(Z);
    try dictionaryAliases(Z);
    try publishedInputAlias(Z);
    try selectedCatalogAlias(Z);
    try earlyAliasProgress(Z);
    try unusedAndPriorFrames(Z);
}

fn earlyAliasProgress(comptime Z: type) !void {
    const plain = "published first byte";
    const frame = try f.rawBlocks(plain, true, false, 37);
    defer h.a.free(frame);
    var buffer: [64]u8 = @splat(0xa5);
    var decoder = Z.NativeIncrementalFrameDecoder.init(h.a);
    defer decoder.deinit();
    try decoder.bindStableOutput(&buffer);
    var count: usize = 0;
    const first = try h.stepLimited(&decoder, frame, &buffer, &count, plain, 1);
    try std.testing.expectEqual(@as(usize, 1), first.progress.output_written);
    try std.testing.expectEqual(@as(usize, 1), decoder.snapshot().last_step_progress.output_written);
    const unchanged = try h.refused(&decoder, buffer[0..1], &buffer, count, error.InvalidBlockPlan);
    try std.testing.expectEqual(count, unchanged);
    const progress = decoder.snapshot().last_step_progress;
    try std.testing.expectEqualDeep(@as(@TypeOf(progress), .{}), progress);
    try std.testing.expectEqual(@as(u8, plain[0]), buffer[0]);
}

fn publishedInputAlias(comptime Z: type) !void {
    const second = try f.rawBlocks("readonly encoded input already published in this buffer", true, false, 37);
    defer h.a.free(second);
    const first = try f.rawBlocks(second, true, false, 37);
    defer h.a.free(first);
    const buffer = try h.a.alloc(u8, second.len + 128);
    defer h.a.free(buffer);
    var decoder = Z.NativeIncrementalFrameDecoder.init(h.a);
    defer decoder.deinit();
    try decoder.bindStableOutput(buffer);
    var count: usize = 0;
    _ = try h.drive(&decoder, first, buffer, &count, second, 7);
    // This input is disjoint from the remaining destination but aliases the
    // published part of the full binding; it must still be refused.
    _ = try h.refused(&decoder, buffer[0..second.len], buffer, count, error.InvalidBlockPlan);
}

fn selectedCatalogAlias(comptime Z: type) !void {
    var buffer: [64]u8 = @splat(0xa5);
    @memcpy(buffer[60..64], f.crossing_dictionary);
    const entries = [_]Z.NativeDictionary{
        Z.NativeDictionary.init(7, f.crossing_dictionary),
        Z.NativeDictionary.init(42, buffer[60..64]),
    };
    const catalog = Z.NativeDictionarySet.init(&entries);
    const first = try f.crossing(true, false, true, 7);
    defer h.a.free(first);
    const aliased = try f.crossing(true, false, true, 42);
    defer h.a.free(aliased);
    var decoder = Z.NativeIncrementalFrameDecoder.initWithDictionarySet(h.a, catalog);
    defer decoder.deinit();
    try decoder.bindStableOutput(&buffer);
    var count: usize = 0;
    _ = try h.drive(&decoder, first, &buffer, &count, f.crossing_plain, 3);
    // The first frame selected external dictionary 7. Only the second frame
    // selects dictionary 42 whose bytes overlap the unused binding suffix.
    _ = try h.refused(&decoder, aliased, &buffer, count, error.InvalidBlockPlan);
}

fn inputAliases(comptime Z: type) !void {
    const plain = "input aliases are rejected across the entire binding";
    const frame = try f.rawBlocks(plain, true, false, 19);
    defer h.a.free(frame);
    inline for (.{ .block_stream, .prevalidated_frame }) |policy| {
        for ([_]usize{ 0, 3, 64 }) |offset| {
            const buffer = try h.a.alloc(u8, frame.len + 64);
            defer h.a.free(buffer);
            @memset(buffer, 0xa5);
            @memcpy(buffer[offset..][0..frame.len], frame);
            const old = try h.a.dupe(u8, buffer);
            defer h.a.free(old);
            var tracker = h.memory.Tracker.init(h.a);
            var decoder = Z.NativeIncrementalFrameDecoder.initWithOptions(tracker.allocator(), .{ .input_policy = policy });
            defer decoder.deinit();
            try decoder.bindStableOutput(buffer);
            _ = try h.refused(&decoder, buffer[offset..][0..frame.len], buffer, 0, error.InvalidBlockPlan);
            try std.testing.expectEqualSlices(u8, old, buffer);
            try std.testing.expectEqual(@as(usize, 0), tracker.attempts);
            try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().input_received);
        }
    }
}

fn dictionaryAliases(comptime Z: type) !void {
    var buffer: [128]u8 = @splat(0xa5);
    @memcpy(buffer[112..116], f.crossing_dictionary);
    const dictionary = Z.NativeDictionary.initRawContent(buffer[112..116]);
    var direct = Z.NativeIncrementalFrameDecoder.initWithDictionary(h.a, dictionary);
    defer direct.deinit();
    try std.testing.expectError(error.InvalidBlockPlan, direct.bindStableOutput(&buffer));
    var prefix = Z.NativeIncrementalFrameDecoder.initWithPrefix(h.a, buffer[112..116]);
    defer prefix.deinit();
    try std.testing.expectError(error.InvalidBlockPlan, prefix.bindStableOutput(&buffer));

    const original = try h.memory.hexAlloc(@embedFile("../../zstd/testdata/libzstd-trained-repeat.dict.hex"));
    defer h.a.free(original);
    const backing = try h.a.dupe(u8, original);
    defer h.a.free(backing);
    const parsed = try Z.NativeDictionary.initFromStandardDictionary(backing);
    // The output aliases only entropy metadata at the beginning of the encoded
    // dictionary. Its content bytes are outside this 32-byte binding.
    try std.testing.expect(@intFromPtr(parsed.dictionary.content.ptr) >= @intFromPtr(backing.ptr) + 32);
    var full = Z.NativeIncrementalFrameDecoder.initWithDictionary(h.a, parsed.dictionary);
    defer full.deinit();
    try std.testing.expectError(error.InvalidBlockPlan, full.bindStableOutput(backing[0..32]));
    try std.testing.expectEqualSlices(u8, original, backing);
}

fn unusedAndPriorFrames(comptime Z: type) !void {
    const dependent = try f.crossing(true, false, false, 0);
    defer h.a.free(dependent);
    const first = try f.rawBlocks(f.crossing_dictionary, true, false, 4);
    defer h.a.free(first);
    inline for (.{ .block_stream, .prevalidated_frame }) |policy| {
        var buffer: [64]u8 = @splat('x');
        var unused = Z.NativeIncrementalFrameDecoder.initWithOptions(h.a, .{ .input_policy = policy });
        defer unused.deinit();
        try unused.bindStableOutput(&buffer);
        _ = try h.refused(&unused, dependent, &buffer, 0, error.InvalidMatch);
        var previous = Z.NativeIncrementalFrameDecoder.initWithOptions(h.a, .{ .input_policy = policy });
        defer previous.deinit();
        try previous.bindStableOutput(&buffer);
        var count: usize = 0;
        _ = try h.drive(&previous, first, &buffer, &count, f.crossing_dictionary, first.len);
        try std.testing.expectEqual(@as(usize, 4), count);
        _ = try h.refused(&previous, dependent, &buffer, count, error.InvalidMatch);
    }
}
