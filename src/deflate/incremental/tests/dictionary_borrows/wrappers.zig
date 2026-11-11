const std = @import("std");
const h = @import("helpers.zig");

fn overlappingProvision(comptime Decoder: type) !void {
    const window = h.Raw.required_history_len;
    for ([_]usize{ 11, 16, 21, 26 }) |source_start| {
        var backing: [window + 32]u8 = @splat(0xa5);
        const source = backing[source_start..][0..10];
        @memcpy(source, h.fixtures.dictionary);
        const before = backing;
        const frame = h.fixtures.frame(source, &h.fixtures.tail_match, h.fixtures.dictionary);
        var decoder = try Decoder.init(.{}, backing[16..][0..window]);
        try h.request(&decoder, frame.slice());
        const id = decoder.requiredDictionaryId();
        const raw_before = try std.testing.allocator.dupe(u8, std.mem.asBytes(&h.zlib(&decoder).raw));
        defer std.testing.allocator.free(raw_before);
        try std.testing.expectError(error.DictionaryMismatch, decoder.provideDictionary(backing[window - 10 .. window]));
        try std.testing.expectEqual(id, decoder.requiredDictionaryId());
        try std.testing.expectEqual(h.Zlib.Phase.dictid, h.zlib(&decoder).phase);
        try std.testing.expectEqualSlices(u8, raw_before, std.mem.asBytes(&h.zlib(&decoder).raw));
        try std.testing.expectEqualSlices(u8, &before, &backing);
        try decoder.provideDictionary(source);
        try std.testing.expectEqual(@as(?u32, null), decoder.requiredDictionaryId());
        var expected = before;
        @memcpy(expected[16..26], h.fixtures.dictionary);
        try std.testing.expectEqualSlices(u8, &expected, &backing);
        try std.testing.expectEqual(@as(usize, 10), h.zlib(&decoder).raw.history_len);
        try std.testing.expectEqual(@as(usize, 10), h.zlib(&decoder).raw.history_pos);
        var output: [10]u8 = undefined;
        try h.drain(&decoder, frame.slice()[6..], &output);
        try std.testing.expectEqualSlices(u8, h.fixtures.dictionary, &output);
    }
}

fn longProvision(comptime Decoder: type) !void {
    const window = h.Raw.required_history_len;
    for ([_]usize{ 0, 16, 48 }) |source_start| {
        var backing: [2 * window + 64]u8 = undefined;
        h.fill(&backing);
        const source = backing[source_start..][0 .. window + 16];
        const tail = source[source.len - 10 ..][0..10].*;
        const frame = h.fixtures.frame(source, &h.fixtures.tail_match, &tail);
        const before = backing;
        var decoder = try Decoder.init(.{}, backing[32..][0..window]);
        try h.request(&decoder, frame.slice());
        try std.testing.expectEqual(@as(?u32, h.checksum.Adler32.hash(source)), decoder.requiredDictionaryId());
        // DICTID always covers the full source, even when history retains only
        // its final window. A suffix-only retry must leave history untouched.
        try std.testing.expectError(error.DictionaryMismatch, decoder.provideDictionary(source[16..]));
        try std.testing.expectEqualSlices(u8, &before, &backing);
        try decoder.provideDictionary(source);
        var expected = before;
        for (0..window) |index| expected[32 + index] = before[source_start + 16 + index];
        try std.testing.expectEqualSlices(u8, &expected, &backing);
        try std.testing.expectEqual(window, h.zlib(&decoder).raw.history_len);
        try std.testing.expectEqual(@as(usize, 0), h.zlib(&decoder).raw.history_pos);
        var output: [10]u8 = undefined;
        try h.drain(&decoder, frame.slice()[6..], &output);
        try std.testing.expectEqualSlices(u8, &tail, &output);
    }
}

fn receiverAndEmpty(comptime Decoder: type) !void {
    var history: [32768]u8 = @splat(0xa5);
    const frame = h.fixtures.frame(h.fixtures.dictionary, &h.fixtures.tail_match, h.fixtures.dictionary);
    var decoder = try Decoder.init(.{}, &history);
    try h.request(&decoder, frame.slice());
    const table = std.mem.sliceAsBytes(h.zlib(&decoder).raw.dynamic_literal_lookup[0..]);
    @memcpy(table[0..10], h.fixtures.dictionary);
    try decoder.provideDictionary(table[0..10]);
    try std.testing.expectEqualSlices(u8, h.fixtures.dictionary, table[0..10]);
    try std.testing.expectEqualSlices(u8, h.fixtures.dictionary, history[0..10]);
    var output: [10]u8 = undefined;
    try h.drain(&decoder, frame.slice()[6..], &output);
    try std.testing.expectEqualSlices(u8, h.fixtures.dictionary, &output);

    decoder.reset();
    const empty = h.fixtures.frame("", &h.fixtures.empty_raw, "");
    try h.request(&decoder, empty.slice());
    const before = history;
    try decoder.provideDictionary(history[7..7]);
    try std.testing.expectEqual(@as(?u32, null), decoder.requiredDictionaryId());
    try std.testing.expectEqual(@as(usize, 0), h.zlib(&decoder).raw.history_len);
    try std.testing.expectEqual(@as(usize, 0), h.zlib(&decoder).raw.history_pos);
    try std.testing.expectEqualSlices(u8, &before, &history);
    try h.drain(&decoder, empty.slice()[6..], &.{});

    decoder.reset();
    const phase: h.Zlib.Phase = .dictid;
    const phase_bytes = std.mem.asBytes(&phase);
    const repeated: [10]u8 = @splat(phase_bytes[phase_bytes.len - 1]);
    const metadata_frame = h.fixtures.frame(phase_bytes, &h.fixtures.repeat_match, &repeated);
    try h.request(&decoder, metadata_frame.slice());
    // DICTID/hash and the seed copy consume the old phase bytes completely
    // before acceptDictionary publishes .raw, so this receiver source is safe.
    try decoder.provideDictionary(std.mem.asBytes(&h.zlib(&decoder).phase));
    try std.testing.expectEqual(h.Zlib.Phase.raw, h.zlib(&decoder).phase);
    try std.testing.expectEqualSlices(u8, phase_bytes, history[0..phase_bytes.len]);
    try h.drain(&decoder, metadata_frame.slice()[6..], &output);
    try std.testing.expectEqualSlices(u8, &repeated, &output);
}

fn releasedOverride(comptime Decoder: type) !void {
    var history: [32768]u8 = @splat(0xa5);
    var override = h.fixtures.dictionary.*;
    const frame = h.fixtures.frame(&override, &h.fixtures.tail_match, h.fixtures.dictionary);
    var decoder = try Decoder.init(.{}, &history);
    try h.request(&decoder, frame.slice());
    try decoder.provideDictionary(&override);
    @memset(&override, 0xcc);
    // Reuse the released source as the step output, proving no dictionary
    // reader still needs it after successful provision.
    try h.drain(&decoder, frame.slice()[6..], &override);
    try std.testing.expectEqualSlices(u8, h.fixtures.dictionary, &override);
    try std.testing.expectEqual(@as(usize, 0), h.zlib(&decoder).dictionary.len);
    decoder.reset();
    try h.request(&decoder, frame.slice());
    try std.testing.expectEqual(@as(?u32, h.checksum.Adler32.hash(h.fixtures.dictionary)), decoder.requiredDictionaryId());
    try decoder.provideDictionary(h.fixtures.dictionary);
    try h.drain(&decoder, frame.slice()[6..], &override);
    try std.testing.expectEqualSlices(u8, h.fixtures.dictionary, &override);
}

test "dictionary borrows zlib and auto provision snapshots overlaps and preserves mismatch retries" {
    inline for (.{ h.Zlib, h.Auto }) |Decoder| try overlappingProvision(Decoder);
}

test "dictionary borrows zlib and auto validate full IDs before clipping overlapping windows" {
    inline for (.{ h.Zlib, h.Auto }) |Decoder| try longProvision(Decoder);
}

test "dictionary borrows zlib and auto accept consumed receiver dictionaries and empty overrides" {
    inline for (.{ h.Zlib, h.Auto }) |Decoder| try receiverAndEmpty(Decoder);
}

test "dictionary borrows zlib and auto release overrides for output reuse and request again after reset" {
    inline for (.{ h.Zlib, h.Auto }) |Decoder| try releasedOverride(Decoder);
}

fn receiverDestination(comptime Decoder: type) !void {
    var history: [32768]u8 = @splat(0xa5);
    var decoder = try Decoder.init(.{}, &history);
    const frame = h.fixtures.frame(h.fixtures.dictionary, &h.fixtures.tail_match, h.fixtures.dictionary);
    try h.request(&decoder, frame.slice());
    const raw = &h.zlib(&decoder).raw;
    const original_history = raw.history;
    // Header/prefix bytes belong to the enclosing receiver but lie outside
    // the raw child. Its own destination check cannot see this collision.
    raw.history = if (Decoder == h.Zlib)
        std.mem.asBytes(&decoder.header)
    else
        std.mem.asBytes(&decoder.prefix);
    const state_before = try std.testing.allocator.dupe(u8, std.mem.asBytes(&decoder));
    defer std.testing.allocator.free(state_before);
    const history_before = history;
    try std.testing.expectError(error.InvalidBlockPlan, decoder.provideDictionary(h.fixtures.dictionary));
    try std.testing.expectEqualSlices(u8, state_before, std.mem.asBytes(&decoder));
    try std.testing.expectEqualSlices(u8, &history_before, &history);
    raw.history = original_history;
    try decoder.provideDictionary(h.fixtures.dictionary);
    var output: [10]u8 = undefined;
    try h.drain(&decoder, frame.slice()[6..], &output);
    try std.testing.expectEqualSlices(u8, h.fixtures.dictionary, &output);
}

test "dictionary borrows zlib and auto reject writes into the enclosing receiver atomically" {
    inline for (.{ h.Zlib, h.Auto }) |Decoder| try receiverDestination(Decoder);
}
