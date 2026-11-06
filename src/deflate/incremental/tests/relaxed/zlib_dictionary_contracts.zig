//! A recognized zlib member keeps dictionary and payload failures visible.
const Count = @import("../../../../core.zig").StreamCount;
const std = @import("std");
const checksum = @import("../../../../checksum.zig");
const allocator = std.testing.allocator;

pub fn contracts(comptime D: type) !void {
    try committedHeaderErrors(D);
    try dictionaryRecovery(D);
}

fn expectErrorProgress(decoder: anytype, before: anytype) !void {
    const after = decoder.snapshot();
    try std.testing.expectEqual(after.total_input - before.total_input, after.last_step_progress.input_read);
    try std.testing.expectEqual(after.total_output - before.total_output, after.last_step_progress.output_written);
    try std.testing.expectEqual(@as(?@TypeOf(after.total_input), after.total_input), after.last_error_input_offset);
    try std.testing.expectEqual(@as(?@TypeOf(after.total_output), after.total_output), after.last_error_output_offset);
    try std.testing.expectEqualDeep(after.last_step_progress, decoder.diagnostics().last_step_progress.?);
}

fn committedHeaderErrors(comptime D: type) !void {
    const first = try D.encodeZlibStoredAlloc(allocator, "");
    defer allocator.free(first);
    const dictionary = "zlib trailing header dictionary";
    const second = try D.encodeZlibFixedWithDictionaryAlloc(allocator, "payload", dictionary, .{});
    defer allocator.free(second);
    var history: [32768]u8 = undefined;
    for (2..6) |header_bytes| {
        const joined = try std.mem.concat(allocator, u8, &.{ first, second[0..header_bytes] });
        defer allocator.free(joined);
        var decoder = try D.ZlibIncrementalDecoder.init(.{
            .allow_concatenated = true,
            .allow_trailing_data = true,
        }, &history);
        const stepped = try decoder.step(joined, &.{});
        try std.testing.expectEqual(.need_input, stepped.status);
        try std.testing.expectEqual(.dictid, decoder.phase);
        try std.testing.expectEqual(header_bytes - 2, decoder.snapshot().dictid_received);
        try std.testing.expectEqual(first.len, decoder.snapshot().stream_offset);
        try std.testing.expectEqual(header_bytes, decoder.snapshot().stream_input);
        try std.testing.expectEqual(@as(?Count, first.len), decoder.memberEndOffset());
        try std.testing.expectError(error.TruncatedFrame, decoder.finish());
        try std.testing.expectEqual(@as(usize, 0), decoder.trailingPrefix().len);
    }
    for ([_][]const u8{ &.{ 0x78, 0x9c }, &.{ 0x78, 0x9c, 0x07 } }) |suffix| {
        var decoder = try D.ZlibIncrementalDecoder.init(.{
            .allow_concatenated = true,
            .allow_trailing_data = true,
        }, &history);
        _ = try decoder.step(first, &.{});
        if (suffix.len == 2) {
            _ = try decoder.step(suffix, &.{});
            try std.testing.expectError(error.TruncatedFrame, decoder.finish());
        } else {
            const before = decoder.snapshot();
            try std.testing.expectError(error.InvalidDeflateBlockType, decoder.step(suffix, &.{}));
            try expectErrorProgress(&decoder, before);
            try std.testing.expectEqual(.raw, decoder.phase);
        }
        try std.testing.expectEqual(@as(?Count, first.len), decoder.memberEndOffset());
    }
}

fn dictionaryRecovery(comptime D: type) !void {
    const first = try D.encodeZlibStoredAlloc(allocator, "");
    defer allocator.free(first);
    const dictionary = "recoverable dictionary phrase";
    const payload = "recoverable dictionary phrase with member content" ** 8;
    const second = try D.encodeZlibFixedWithDictionaryAlloc(allocator, payload, dictionary, .{});
    defer allocator.free(second);
    const joined = try std.mem.concat(allocator, u8, &.{ first, second });
    defer allocator.free(joined);
    var history: [32768]u8 = undefined;
    var output: [payload.len]u8 = undefined;
    var decoder = try D.ZlibIncrementalDecoder.init(.{
        .allow_concatenated = true,
        .allow_trailing_data = true,
    }, &history);
    // Split the two-byte probe so accepted prefix attribution is exercised.
    _ = try decoder.step(joined[0 .. first.len + 1], &.{});
    const before = decoder.snapshot();
    try std.testing.expectError(error.NeedDictionary, decoder.step(joined[first.len + 1 ..], &output));
    try expectErrorProgress(&decoder, before);
    try std.testing.expectEqual(@as(usize, 5), decoder.snapshot().last_step_progress.input_read);
    try std.testing.expectEqual(first.len, decoder.snapshot().stream_offset);
    try std.testing.expectEqual(@as(usize, 6), decoder.snapshot().stream_input);
    try std.testing.expectEqual(@as(?u32, checksum.Adler32.hash(dictionary)), decoder.requiredDictionaryId());
    try std.testing.expectError(error.NeedDictionary, decoder.finish());
    try std.testing.expect(!decoder.input_finished);
    try std.testing.expectError(error.DictionaryMismatch, decoder.provideDictionary("wrong"));
    try std.testing.expectEqual(@as(?u32, checksum.Adler32.hash(dictionary)), decoder.requiredDictionaryId());
    try decoder.provideDictionary(dictionary);
    try std.testing.expectEqual(@as(?u32, null), decoder.requiredDictionaryId());
    const resumed = try decoder.step(joined[first.len + 6 ..], &output);
    try std.testing.expectEqual(second.len - 6, resumed.progress.input_read);
    try std.testing.expectEqualSlices(u8, payload, &output);
    try std.testing.expectEqual(@as(usize, 2), decoder.snapshot().stream_count);
    try std.testing.expectEqual(@as(?Count, joined.len), decoder.memberEndOffset());
    try decoder.finish();
}
