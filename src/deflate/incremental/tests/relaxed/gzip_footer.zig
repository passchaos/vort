const Count = @import("../../../../core.zig").StreamCount;
const std = @import("std");
const checksum = @import("../../../../checksum.zig");
const helpers = @import("gzip_helpers.zig");

pub fn contracts(comptime D: type) !void {
    try footerSplits(D);
    try strictHeaders(D);
    try outputLimits(D);
}

fn footerSplits(comptime D: type) !void {
    const payload = "footer contract payload";
    const encoded = try D.encodeGzipStoredAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);
    const footer_offset = encoded.len - 8;
    var history: [32 * 1024]u8 = undefined;
    var output: [payload.len]u8 = undefined;
    // Exercise the strict policy and each independent relaxed combination
    // against valid, CRC-only, ISIZE-only, and doubly corrupted footers.
    for (0..4) |ignored| {
        for (0..4) |corrupt| {
            encoded[footer_offset] ^= @intFromBool((corrupt & 1) != 0);
            encoded[footer_offset + 4] ^= @intFromBool((corrupt & 2) != 0);
            defer {
                encoded[footer_offset] ^= @intFromBool((corrupt & 1) != 0);
                encoded[footer_offset + 4] ^= @intFromBool((corrupt & 2) != 0);
            }
            for (0..9) |split| {
                var decoder = try D.GzipIncrementalDecoder.init(.{
                    .ignore_crc32 = (ignored & 1) != 0,
                    .ignore_isize = (ignored & 2) != 0,
                }, &history);
                _ = try helpers.step(&decoder, encoded[0..footer_offset], &output);
                try std.testing.expectEqualSlices(u8, payload, &output);
                try std.testing.expectEqual(checksum.Crc32.hash(payload), decoder.crc.digest());
                const expected_error: ?anyerror = if ((corrupt & 1) != 0 and (ignored & 1) == 0)
                    error.ChecksumMismatch
                else if ((corrupt & 2) != 0 and (ignored & 2) == 0)
                    error.SizeMismatch
                else
                    null;
                if (split == 8 and expected_error != null) {
                    try helpers.stepError(expected_error.?, &decoder, encoded[footer_offset..], &.{});
                } else {
                    const partial = try helpers.step(&decoder, encoded[footer_offset .. footer_offset + split], &.{});
                    if (split < 8) {
                        try std.testing.expectEqual(.need_input, partial.status);
                        try std.testing.expectEqual(split, decoder.snapshot().footer_received);
                        try std.testing.expectEqual(@as(?Count, null), decoder.memberEndOffset());
                        if (expected_error) |err| {
                            try helpers.stepError(err, &decoder, encoded[footer_offset + split ..], &.{});
                        } else {
                            const completed = try helpers.step(&decoder, encoded[footer_offset + split ..], &.{});
                            try std.testing.expectEqual(.done, completed.status);
                        }
                    }
                }
                try std.testing.expectEqual(@as(usize, 8), decoder.snapshot().footer_received);
                try std.testing.expectEqual(encoded.len, decoder.snapshot().total_input);
                try std.testing.expectEqual(@as(usize, @intFromBool(expected_error == null)), decoder.snapshot().member_count);
                if (expected_error == null) {
                    try decoder.finish();
                    try std.testing.expectEqual(@as(?Count, encoded.len), decoder.memberEndOffset());
                }
            }
            // Relaxation must still require every footer byte at EOF.
            for (0..8) |received| {
                var short = try D.GzipIncrementalDecoder.init(.{
                    .ignore_crc32 = (ignored & 1) != 0,
                    .ignore_isize = (ignored & 2) != 0,
                }, &history);
                _ = try helpers.step(&short, encoded[0 .. footer_offset + received], &output);
                try std.testing.expectError(error.TruncatedFrame, short.finish());
                try std.testing.expectEqual(received, short.snapshot().footer_received);
                try std.testing.expectEqual(@as(usize, 0), short.snapshot().member_count);
                try std.testing.expectEqual(@as(?Count, null), short.memberEndOffset());
                try helpers.stepError(error.TrailingData, &short, encoded[footer_offset + received ..], &.{});
            }
        }
    }
}

fn strictHeaders(comptime D: type) !void {
    const encoded = try D.encodeGzipStoredWithHeaderAlloc(std.testing.allocator, "header", .{
        .extra = "xyz",
        .filename = "file",
        .comment = "note",
        .header_crc = true,
    });
    defer std.testing.allocator.free(encoded);
    const info = try D.parseGzipHeaderInfo(encoded);
    encoded[info.data_offset - 2] ^= 1;
    var history: [32 * 1024]u8 = undefined;
    var output: [16]u8 = undefined;
    var bad_crc = try D.GzipIncrementalDecoder.init(.{ .ignore_crc32 = true, .ignore_isize = true }, &history);
    try helpers.stepError(error.BadGzipHeader, &bad_crc, encoded, &output);
    try std.testing.expectEqual(D.GzipIncrementalDecoder.Phase.header_crc, bad_crc.snapshot().last_error_phase.?);
    encoded[info.data_offset - 2] ^= 1;
    var limited = try D.GzipIncrementalDecoder.init(.{
        .ignore_crc32 = true,
        .ignore_isize = true,
        .max_header_metadata_len = 2,
    }, &history);
    try helpers.stepError(error.OutputLimitExceeded, &limited, encoded, &output);
    try std.testing.expectEqual(D.GzipIncrementalDecoder.Phase.extra_len, limited.snapshot().last_error_phase.?);
    for ([_]D.GzipHeaderOptions{ .{ .filename = "name" }, .{ .comment = "note" } }) |options| {
        const metadata = try D.encodeGzipStoredWithHeaderAlloc(std.testing.allocator, "header", options);
        defer std.testing.allocator.free(metadata);
        var text_limit = try D.GzipIncrementalDecoder.init(.{
            .ignore_crc32 = true,
            .ignore_isize = true,
            .max_header_metadata_len = 2,
        }, &history);
        try helpers.stepError(error.OutputLimitExceeded, &text_limit, metadata, &output);
        const phase: D.GzipIncrementalDecoder.Phase = if (options.filename != null) .filename else .comment;
        try std.testing.expectEqual(phase, text_limit.snapshot().last_error_phase.?);
    }
}

fn outputLimits(comptime D: type) !void {
    const encoded = try D.encodeGzipFixedAlloc(std.testing.allocator, "abcdef");
    defer std.testing.allocator.free(encoded);
    encoded[encoded.len - 8] ^= 1;
    encoded[encoded.len - 4] ^= 1;
    const empty = try D.encodeGzipFixedAlloc(std.testing.allocator, "");
    defer std.testing.allocator.free(empty);
    const joined = try helpers.join(&.{ empty, encoded });
    defer std.testing.allocator.free(joined);
    var history: [32 * 1024]u8 = undefined;
    var output: [16]u8 = undefined;
    for ([_]bool{ false, true }) |concatenated| {
        const input = if (concatenated) joined else encoded;
        var limited = try D.GzipIncrementalDecoder.init(.{
            .ignore_crc32 = true,
            .ignore_isize = true,
            .allow_concatenated = concatenated,
            .max_output_len = 3,
        }, &history);
        try helpers.stepError(error.OutputLimitExceeded, &limited, input, &output);
        var short = try D.GzipIncrementalDecoder.init(.{
            .ignore_crc32 = true,
            .ignore_isize = true,
            .allow_concatenated = concatenated,
            .expected_output_len = 3,
        }, &history);
        try helpers.stepError(error.SizeMismatch, &short, input, &output);
        var long = try D.GzipIncrementalDecoder.init(.{
            .ignore_crc32 = true,
            .ignore_isize = true,
            .allow_concatenated = concatenated,
            .expected_output_len = 7,
        }, &history);
        if (concatenated) {
            _ = try helpers.step(&long, input, &output);
            try std.testing.expectError(error.SizeMismatch, long.finish());
        } else {
            try helpers.stepError(error.SizeMismatch, &long, input, &output);
        }
    }
    var zero = try D.GzipIncrementalDecoder.init(.{ .max_output_len = 0, .expected_output_len = 0 }, &history);
    try std.testing.expectEqual(.done, (try helpers.step(&zero, empty, &.{})).status);
    try zero.finish();
    var valid_concat = try D.GzipIncrementalDecoder.init(.{
        .ignore_crc32 = true,
        .ignore_isize = true,
        .allow_concatenated = true,
        .expected_output_len = 6,
        .max_output_len = 6,
    }, &history);
    _ = try helpers.step(&valid_concat, joined, &output);
    try valid_concat.finish();
    try std.testing.expectEqual(@as(usize, 2), valid_concat.snapshot().member_count);
    try std.testing.expectEqual(@as(usize, 6), valid_concat.snapshot().member_output);
    try std.testing.expectEqual(checksum.Crc32.hash("abcdef"), valid_concat.crc.digest());
}
