const std = @import("std");
const helpers = @import("gzip_helpers.zig");

pub fn contracts(comptime D: type) !void {
    try tails(D);
    try splitMagic(D);
    try committedMembers(D);
}

fn tails(comptime D: type) !void {
    const first = try D.encodeGzipFixedAlloc(std.testing.allocator, "one");
    defer std.testing.allocator.free(first);
    const empty = try D.encodeGzipFixedAlloc(std.testing.allocator, "");
    defer std.testing.allocator.free(empty);
    const second = try D.encodeGzipStoredWithHeaderAlloc(std.testing.allocator, "two", .{ .header_crc = true });
    defer std.testing.allocator.free(second);
    const members = try helpers.join(&.{ first, empty, second });
    defer std.testing.allocator.free(members);
    var history: [32 * 1024]u8 = undefined;
    var output: [8]u8 = undefined;
    for ([_][]const u8{ "tail bytes remain", &.{ 0x1f, 0x00, 0x77 } }) |tail| {
        const joined = try helpers.join(&.{ members, tail });
        defer std.testing.allocator.free(joined);
        var decoder = try D.GzipIncrementalDecoder.init(.{
            .allow_concatenated = true,
            .allow_trailing_data = true,
            .expected_output_len = 6,
        }, &history);
        const completed = try helpers.step(&decoder, joined, &output);
        try std.testing.expectEqual(.done, completed.status);
        try std.testing.expectEqual(members.len, completed.progress.input_read);
        try std.testing.expectEqualSlices(u8, "onetwo", output[0..completed.progress.output_written]);
        try std.testing.expectEqualSlices(u8, tail, joined[completed.progress.input_read..]);
        try std.testing.expectEqual(@as(usize, 3), decoder.snapshot().member_count);
        try std.testing.expectEqual(first.len + empty.len, decoder.snapshot().member_offset);
        try std.testing.expectEqual(second.len, decoder.snapshot().member_input);
        try std.testing.expectEqual(@as(?usize, members.len), decoder.memberEndOffset());
        try std.testing.expectEqual(@as(usize, 0), decoder.trailingPrefix().len);
        try decoder.finish();
    }
    var split = try D.GzipIncrementalDecoder.init(.{ .allow_concatenated = true, .allow_trailing_data = true }, &history);
    _ = try helpers.step(&split, members, &output);
    const stopped = try helpers.step(&split, "suffix", &.{});
    try std.testing.expectEqual(.done, stopped.status);
    try std.testing.expectEqual(@as(usize, 0), stopped.progress.input_read);
    try std.testing.expectEqual(members.len, split.snapshot().total_input);

    const with_tail = try helpers.join(&.{ members, "strict tail is corrupt" });
    defer std.testing.allocator.free(with_tail);
    var strict = try D.GzipIncrementalDecoder.init(.{ .allow_concatenated = true }, &history);
    try helpers.stepError(error.BadGzipHeader, &strict, with_tail, &output);
    var one = try D.GzipIncrementalDecoder.init(.{ .allow_trailing_data = true }, &history);
    const stopped_first = try helpers.step(&one, members, &output);
    try std.testing.expectEqual(first.len, stopped_first.progress.input_read);
    try std.testing.expectEqual(@as(usize, 1), one.snapshot().member_count);
}

fn splitMagic(comptime D: type) !void {
    const first = try D.encodeGzipFixedAlloc(std.testing.allocator, "one");
    defer std.testing.allocator.free(first);
    const second = try D.encodeGzipStoredWithHeaderAlloc(std.testing.allocator, "two", .{ .header_crc = true });
    defer std.testing.allocator.free(second);
    const candidate = try helpers.join(&.{ first, &.{0x1f} });
    defer std.testing.allocator.free(candidate);
    var history: [32 * 1024]u8 = undefined;
    var output: [8]u8 = undefined;
    var decoder = try D.GzipIncrementalDecoder.init(.{ .allow_concatenated = true, .allow_trailing_data = true }, &history);
    const partial = try helpers.step(&decoder, candidate, &output);
    try std.testing.expectEqual(.need_input, partial.status);
    try std.testing.expectEqual(candidate.len, partial.progress.input_read);
    try std.testing.expectEqual(D.GzipIncrementalDecoder.Phase.between_members, decoder.snapshot().phase);
    try std.testing.expectEqual(@as(usize, 1), decoder.snapshot().trailing_prefix_len);
    try std.testing.expectEqual(@as(usize, 0), decoder.trailingPrefix().len);
    try std.testing.expectEqual(first.len, decoder.snapshot().member_input);
    try std.testing.expectEqual(@as(?usize, first.len), decoder.memberEndOffset());
    const suffix = [_]u8{ 0x00, 0x55, 0x66 };
    const stopped = try helpers.step(&decoder, &suffix, &.{});
    try std.testing.expectEqual(.done, stopped.status);
    try std.testing.expectEqual(@as(usize, 0), stopped.progress.input_read);
    const restored = try helpers.join(&.{ decoder.trailingPrefix(), suffix[stopped.progress.input_read..] });
    defer std.testing.allocator.free(restored);
    try std.testing.expectEqualSlices(u8, &.{ 0x1f, 0x00, 0x55, 0x66 }, restored);
    try std.testing.expectEqual(first.len, decoder.snapshot().member_input);
    try std.testing.expectEqual(candidate.len, decoder.snapshot().total_input);
    try decoder.finish();
    try helpers.stepError(error.TrailingData, &decoder, &suffix, &.{});

    var eof = try D.GzipIncrementalDecoder.init(.{ .allow_concatenated = true, .allow_trailing_data = true }, &history);
    _ = try helpers.step(&eof, candidate, &output);
    try eof.finish();
    try std.testing.expectEqualSlices(u8, &.{0x1f}, eof.trailingPrefix());
    try std.testing.expectEqual(first.len, eof.snapshot().member_input);
    try std.testing.expectEqual(.done, (try helpers.step(&eof, "", &.{})).status);
    eof.reset();
    try std.testing.expectEqual(@as(?usize, null), eof.memberEndOffset());
    try std.testing.expectEqual(@as(usize, 0), eof.snapshot().trailing_prefix_len);
    try std.testing.expectEqual(@as(usize, 0), eof.trailingPrefix().len);

    // A two-byte match split over calls commits to the member and includes
    // both bytes in its compressed offset and FHCRC calculation.
    var valid = try D.GzipIncrementalDecoder.init(.{ .allow_concatenated = true, .allow_trailing_data = true }, &history);
    _ = try helpers.step(&valid, candidate, &output);
    _ = try helpers.step(&valid, second[1..], output[3..]);
    try valid.finish();
    try std.testing.expectEqualSlices(u8, "onetwo", output[0..6]);
    try std.testing.expectEqual(@as(usize, 2), valid.snapshot().member_count);
    try std.testing.expectEqual(first.len, valid.snapshot().member_offset);
    try std.testing.expectEqual(second.len, valid.snapshot().member_input);
    try std.testing.expectEqual(@as(?usize, first.len + second.len), valid.memberEndOffset());
    try std.testing.expectEqual(@as(usize, 0), valid.trailingPrefix().len);

    var exact = try D.GzipIncrementalDecoder.init(.{
        .allow_concatenated = true,
        .allow_trailing_data = true,
        .expected_output_len = 4,
    }, &history);
    _ = try helpers.step(&exact, candidate, &output);
    try std.testing.expectError(error.SizeMismatch, exact.finish());
    var exact_tail = try D.GzipIncrementalDecoder.init(.{
        .allow_concatenated = true,
        .allow_trailing_data = true,
        .expected_output_len = 4,
    }, &history);
    _ = try helpers.step(&exact_tail, first, &output);
    try helpers.stepError(error.SizeMismatch, &exact_tail, "tail", &.{});
}

fn committedMembers(comptime D: type) !void {
    const first = try D.encodeGzipFixedAlloc(std.testing.allocator, "");
    defer std.testing.allocator.free(first);
    const second = try D.encodeGzipStoredWithHeaderAlloc(std.testing.allocator, "two", .{
        .filename = "second",
        .header_crc = true,
    });
    defer std.testing.allocator.free(second);
    const info = try D.parseGzipHeaderInfo(second);
    var history: [32 * 1024]u8 = undefined;
    var output: [8]u8 = undefined;
    for ([_]usize{ 2, 3, info.data_offset - 2, second.len - 8, second.len - 4 }) |index| {
        const original = second[index];
        second[index] = if (index == 2) 0 else if (index == 3) 0x80 else original ^ 1;
        defer second[index] = original;
        const joined = try helpers.join(&.{ first, second });
        defer std.testing.allocator.free(joined);
        var decoder = try D.GzipIncrementalDecoder.init(.{ .allow_concatenated = true, .allow_trailing_data = true }, &history);
        const err: anyerror = if (index < info.data_offset)
            error.BadGzipHeader
        else if (index == second.len - 8)
            error.ChecksumMismatch
        else
            error.SizeMismatch;
        try helpers.stepError(err, &decoder, joined, &output);
        try std.testing.expectEqual(@as(usize, 1), decoder.snapshot().member_count);
        try std.testing.expectEqual(@as(?usize, 1), decoder.snapshot().last_error_member_index);
        try std.testing.expectEqual(@as(?usize, first.len), decoder.snapshot().last_error_member_offset);
        try std.testing.expectEqual(@as(?usize, first.len), decoder.memberEndOffset());
        try std.testing.expectEqual(@as(usize, 0), decoder.trailingPrefix().len);
    }
    // Once the magic matches, even an incomplete fixed header is a strict
    // truncation, including when its first byte came from an earlier call.
    for (2..info.data_offset) |received| {
        var decoder = try D.GzipIncrementalDecoder.init(.{ .allow_concatenated = true, .allow_trailing_data = true }, &history);
        _ = try helpers.step(&decoder, first, &output);
        _ = try helpers.step(&decoder, second[0..1], &output);
        _ = try helpers.step(&decoder, second[1..received], &output);
        if (received < 10) try std.testing.expectEqual(D.GzipIncrementalDecoder.Phase.header, decoder.snapshot().phase);
        try std.testing.expectEqual(@min(received, 10), decoder.snapshot().header_received);
        try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().trailing_prefix_len);
        try std.testing.expectError(error.TruncatedFrame, decoder.finish());
        try std.testing.expectEqual(@as(?usize, 1), decoder.snapshot().last_error_member_index);
        try std.testing.expectEqual(@as(?usize, first.len + received), decoder.snapshot().last_error_input_offset);
    }
}
