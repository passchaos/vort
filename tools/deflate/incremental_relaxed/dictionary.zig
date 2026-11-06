const std = @import("std");
const h = @import("driver.zig");
const ref = @import("reference.zig");
const dictionary = "external dictionary phrase abcdefghabcdefgh";
const payload = "external dictionary phrase abcdefghabcdefgh with member content\n" ** 4;

pub fn run(a: std.mem.Allocator, counts: *h.Counts) !void {
    const first = try ref.deflate(a, .zlib, h.payload, null);
    defer a.free(first);
    const second = try ref.deflate(a, .zlib, payload, dictionary);
    defer a.free(second);
    try h.require(second[1] & 0x20 != 0);
    try h.require(std.mem.readInt(u32, second[2..6], .big) == ref.adler(dictionary));
    try h.require(try ref.inflate(.zlib, second) == .dictionary);
    const wire = try std.mem.concat(a, u8, &.{ first, second });
    defer a.free(wire);
    for ([_]bool{ false, true }) |ignore_adler| {
        for ([_]usize{ 1, wire.len }) |quota| {
            var history: [32768]u8 = undefined;
            var output: [h.payload.len + payload.len]u8 = undefined;
            var decoder = try h.D.ZlibIncrementalDecoder.init(.{ .allow_concatenated = true, .allow_trailing_data = true, .ignore_adler = ignore_adler, .expected_output_len = output.len }, &history);
            var cursor: h.Cursor = .{};
            if (h.pump(&decoder, wire, &output, &cursor, wire.len, quota, counts)) |_| return error.ExpectedDictionaryRequest else |err| try h.require(err == error.NeedDictionary);
            try h.require(cursor.read == first.len + 6 and cursor.written == h.payload.len);
            try h.require(decoder.memberEndOffset() == first.len and decoder.requiredDictionaryId() == ref.adler(dictionary));
            try h.require(decoder.snapshot().last_error_stream_index == 1 and decoder.snapshot().last_error_stream_offset == first.len);
            if (decoder.finish()) |_| return error.ExpectedDictionaryRequest else |err| try h.require(err == error.NeedDictionary);
            try h.require(!decoder.input_finished);
            const before = decoder.snapshot();
            if (decoder.provideDictionary("wrong")) |_| return error.ExpectedDictionaryMismatch else |err| try h.require(err == error.DictionaryMismatch);
            try h.require(decoder.requiredDictionaryId() == ref.adler(dictionary));
            try h.require(decoder.snapshot().total_input == before.total_input and decoder.snapshot().total_output == before.total_output);
            if (h.step(&decoder, wire[cursor.read..], &.{}, counts)) |_| return error.ExpectedDictionaryRequest else |err| try h.require(err == error.NeedDictionary);
            try h.require(decoder.snapshot().last_step_progress.input_read == 0 and decoder.snapshot().last_step_progress.output_written == 0);
            try decoder.provideDictionary(dictionary);
            try h.require(decoder.requiredDictionaryId() == null);
            try h.pump(&decoder, wire, &output, &cursor, wire.len, quota, counts);
            try decoder.finish();
            try h.equal(h.payload ++ payload, output[0..cursor.written]);
            try h.require(cursor.read == wire.len and decoder.memberEndOffset() == wire.len and decoder.snapshot().stream_count == 2);
            try h.hash(.zlib, &decoder, payload);
            try h.sealed(&decoder, counts);
            counts.dictionaries += 1;
        }
    }
    // A valid recognized CMF/FLG followed by a partial DICTID is committed to
    // the next member, even with both relaxed options enabled.
    for (2..6) |received| {
        const partial = try std.mem.concat(a, u8, &.{ first, second[0..received] });
        defer a.free(partial);
        var history: [32768]u8 = undefined;
        var output: [h.payload.len]u8 = undefined;
        var decoder = try h.D.ZlibIncrementalDecoder.init(.{ .allow_concatenated = true, .allow_trailing_data = true, .ignore_adler = true }, &history);
        var cursor: h.Cursor = .{};
        try h.pump(&decoder, partial, &output, &cursor, partial.len, 1, counts);
        try h.require(decoder.snapshot().dictid_received == received - 2 and decoder.memberEndOffset() == first.len);
        if (decoder.finish()) |_| return error.ExpectedDictidTruncation else |err| try h.require(err == error.TruncatedFrame);
        try h.require(decoder.trailingPrefix().len == 0);
        try h.sealed(&decoder, counts);
        counts.dictionaries += 1;
    }
}
