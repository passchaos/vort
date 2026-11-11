const std = @import("std");
const h = @import("helpers.zig");
const checksum = @import("../../../../checksum.zig");
const Entry = h.deflate.ZlibDictionaryEntry;
const Set = h.deflate.ZlibDictionarySet;
const configured = "configured dictionary bytes";

fn outputBorrow(set: bool, boundary: bool) !void {
    var history: [32768]u8 = @splat(0x5a);
    var dictionary = configured.*;
    const entries = [_]Entry{Set.entry(&dictionary)};
    var decoder = if (set)
        try h.Zlib.initWithDictionarySet(.{}, &history, Set.fromEntries(&entries))
    else
        try h.Zlib.initWithDictionary(.{}, &history, &dictionary);
    const wire = h.wrap(h.Zlib, &h.stored, "abcdef");
    try h.reject(&decoder, wire.slice(), dictionary[0..6], boundary);
    try std.testing.expectEqualSlices(u8, configured, &dictionary);
    var output: [6]u8 = undefined;
    try h.drain(&decoder, wire.slice(), &output);
    try std.testing.expectEqualSlices(u8, "abcdef", &output);
    // The configured bytes remain borrowed after seeding/decoding and reset.
    decoder.reset();
    try h.reject(&decoder, wire.slice(), dictionary[0..6], boundary);
}

fn entriesOutput(boundary: bool) !void {
    var history: [32768]u8 = @splat(0x5a);
    var entries = [_]Entry{ Set.entry("first dictionary"), Set.entry(configured) };
    const before = try h.allocator.dupe(u8, std.mem.sliceAsBytes(&entries));
    defer h.allocator.free(before);
    var decoder = try h.Zlib.initWithDictionarySet(.{}, &history, Set.fromEntries(&entries));
    const wire = h.wrap(h.Zlib, &h.stored, "abcdef");
    try h.reject(&decoder, wire.slice(), std.mem.sliceAsBytes(&entries)[0..6], boundary);
    try std.testing.expectEqualSlices(u8, before, std.mem.sliceAsBytes(&entries));
    var output: [6]u8 = undefined;
    try h.drain(&decoder, wire.slice(), &output);
    try std.testing.expectEqualSlices(u8, "abcdef", &output);
}

fn retainedHistory(set: bool, entries_in_history: bool, boundary: bool) !void {
    var history: [32768]u8 align(@alignOf(Entry)) = @splat(0x5a);
    const independent_entries = [_]Entry{Set.entry(configured)};
    var borrowed_entries = [_]Entry{Set.entry(configured)};
    var decoder = try h.init(h.Zlib, &history);
    if (entries_in_history) {
        const entries = std.mem.bytesAsSlice(Entry, @as([]align(@alignOf(Entry)) u8, history[0..@sizeOf(Entry)]));
        entries[0] = Set.entry(configured);
        decoder.dictionaries = Set.fromEntries(entries);
    } else {
        @memcpy(history[0..configured.len], configured);
        if (set) {
            borrowed_entries[0] = Set.entry(history[0..configured.len]);
            decoder.dictionaries = Set.fromEntries(&borrowed_entries);
        } else {
            decoder.dictionary = history[0..configured.len];
            decoder.dictionary_available = true;
        }
    }
    const wire = h.wrap(h.Zlib, &h.stored, "abcdef");
    var output: [6]u8 = @splat(0x81);
    try h.reject(&decoder, wire.slice(), &output, boundary);
    // Replace the conflicting retained borrow before retrying. Changing only
    // the step buffers cannot repair configuration stored in active history.
    if (set or entries_in_history)
        decoder.dictionaries = Set.fromEntries(&independent_entries)
    else
        decoder.dictionary = configured;
    try h.drain(&decoder, wire.slice(), &output);
    try std.testing.expectEqualSlices(u8, "abcdef", &output);
}

test "zlib incremental step borrows protect configured dictionary bytes and set entries" {
    inline for (.{ false, true }) |boundary| {
        try outputBorrow(false, boundary);
        try outputBorrow(true, boundary);
        try entriesOutput(boundary);
        try retainedHistory(false, false, boundary);
        try retainedHistory(true, false, boundary);
        try retainedHistory(true, true, boundary);
    }
}

test "zlib incremental step borrows protect dictionary readers inside decoder storage" {
    var history: [32768]u8 = @splat(0x5a);
    var decoder = try h.init(h.Zlib, &history);
    const dictionary = std.mem.sliceAsBytes(decoder.raw.dynamic_literal_lookup[0..])[0..configured.len];
    @memcpy(dictionary, configured);
    decoder.dictionary = dictionary;
    decoder.dictionary_available = true;
    const wire = h.wrap(h.Zlib, &h.stored, "abcdef");
    var output: [6]u8 = @splat(0x81);
    try h.reject(&decoder, wire.slice(), &output, false);
    decoder.dictionary = configured;
    try h.drain(&decoder, wire.slice(), &output);
    try std.testing.expectEqualSlices(u8, "abcdef", &output);
}

fn dictionaryFrame(dictionary: []const u8) h.Wire {
    var wire = h.Wire{ .len = 6 + h.fixed.len + 4, .prefix = 6 };
    @memcpy(wire.bytes[0..2], &[_]u8{ 0x78, 0x20 });
    std.mem.writeInt(u32, wire.bytes[2..6], checksum.Adler32.hash(dictionary), .big);
    @memcpy(wire.bytes[6..][0..h.fixed.len], &h.fixed);
    std.mem.writeInt(u32, wire.bytes[6 + h.fixed.len ..][0..4], checksum.Adler32.hash("aaaaaa"), .big);
    return wire;
}

test "zlib incremental step borrows release provideDictionary override after return" {
    var history: [32768]u8 = @splat(0x5a);
    var decoder = try h.init(h.Zlib, &history);
    var override = configured.*;
    const wire = dictionaryFrame(&override);
    try std.testing.expectError(error.NeedDictionary, decoder.step(wire.slice(), &.{}));
    const consumed = decoder.last_step_progress.input_read;
    try std.testing.expectEqual(@as(usize, 6), consumed);
    try decoder.provideDictionary(&override);
    try std.testing.expectEqual(@as(usize, 0), decoder.dictionary.len);
    try std.testing.expect(decoder.dictionaries == null);
    // This call writes into the released override while its copied history
    // provides all LZ match bytes; no borrow of override survives provision.
    try h.drain(&decoder, wire.slice()[consumed..], override[0..6]);
    try std.testing.expectEqualSlices(u8, "aaaaaa", override[0..6]);
    decoder.reset();
    try std.testing.expectError(error.NeedDictionary, decoder.step(wire.slice(), &.{}));
    try std.testing.expectEqual(@as(usize, 6), decoder.last_step_progress.input_read);
}
