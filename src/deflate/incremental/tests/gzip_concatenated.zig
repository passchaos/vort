const std = @import("std");
const deflate = @import("../../../deflate.zig");

test "gzip incremental concatenation streams mixed members cumulatively" {
    const first_payload = "dynamic gzip member alpha beta gamma " ** 32;
    const second_payload = "stored second member";
    const first = try deflate.encodeGzipDynamicWithOptionsAlloc(std.testing.allocator, first_payload, deflate.optionsForLevel(.default));
    defer std.testing.allocator.free(first);
    const first_header = try deflate.parseGzipHeaderInfo(first);
    try std.testing.expectEqual(
        deflate.RawDeflateBlockType.dynamic,
        (try deflate.parseRawDeflateHeaderInfo(first[first_header.data_offset..])).block_type,
    );
    const second = try deflate.encodeGzipStoredWithHeaderAlloc(std.testing.allocator, second_payload, .{
        .extra = "xy",
        .filename = "second.txt",
        .comment = "stored",
        .header_crc = true,
    });
    defer std.testing.allocator.free(second);

    var stream: std.ArrayList(u8) = .empty;
    defer stream.deinit(std.testing.allocator);
    try stream.appendSlice(std.testing.allocator, first);
    try stream.appendSlice(std.testing.allocator, second);

    const expected = first_payload ++ second_payload;
    var history: [32 * 1024]u8 = undefined;
    var decoder = try deflate.GzipIncrementalDecoder.init(.{
        .allow_concatenated = true,
        .expected_output_len = expected.len,
    }, &history);
    var output: [expected.len]u8 = undefined;
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (input_offset < stream.items.len) {
        const result = try decoder.step(
            stream.items[input_offset .. input_offset + 1],
            output[output_offset..][0..@min(2, output.len - output_offset)],
        );
        input_offset += result.progress.input_read;
        output_offset += result.progress.output_written;
    }
    while (output_offset < output.len) {
        const result = try decoder.step("", output[output_offset..][0..1]);
        output_offset += result.progress.output_written;
    }
    try decoder.finish();

    try std.testing.expectEqualSlices(u8, expected, &output);
    const snapshot = decoder.snapshot();
    try std.testing.expectEqual(@as(usize, 2), snapshot.member_count);
    try std.testing.expectEqual(@as(usize, 1), snapshot.member_index);
    try std.testing.expectEqual(first.len, snapshot.member_offset);
    try std.testing.expectEqual(second.len, snapshot.member_input);
    try std.testing.expectEqual(stream.items.len, snapshot.total_input);
    try std.testing.expectEqual(expected.len, snapshot.total_output);
    try std.testing.expect(snapshot.done);
}

test "gzip incremental concatenation keeps strict default and cumulative limits" {
    const first = try deflate.encodeGzipFixedAlloc(std.testing.allocator, "first");
    defer std.testing.allocator.free(first);
    const second = try deflate.encodeGzipFixedAlloc(std.testing.allocator, "second");
    defer std.testing.allocator.free(second);
    var stream: std.ArrayList(u8) = .empty;
    defer stream.deinit(std.testing.allocator);
    try stream.appendSlice(std.testing.allocator, first);
    try stream.appendSlice(std.testing.allocator, second);

    var history: [32 * 1024]u8 = undefined;
    var output: [32]u8 = undefined;
    var strict = try deflate.GzipIncrementalDecoder.init(.{}, &history);
    try std.testing.expectError(error.TrailingData, strict.step(stream.items, &output));

    var limited = try deflate.GzipIncrementalDecoder.init(.{
        .allow_concatenated = true,
        .max_output_len = "firstsecon".len,
    }, &history);
    try std.testing.expectError(error.OutputLimitExceeded, limited.step(stream.items, &output));
    try std.testing.expectEqual(@as(usize, 1), limited.snapshot().member_count);

    var too_long = try deflate.GzipIncrementalDecoder.init(.{
        .allow_concatenated = true,
        .expected_output_len = "firstsecond!".len,
    }, &history);
    _ = try too_long.step(stream.items, &output);
    try std.testing.expectError(error.SizeMismatch, too_long.finish());

    var too_short = try deflate.GzipIncrementalDecoder.init(.{
        .allow_concatenated = true,
        .expected_output_len = "firstsecon".len,
    }, &history);
    try std.testing.expectError(error.SizeMismatch, too_short.step(stream.items, &output));
}

test "gzip incremental concatenation diagnoses corrupt and truncated later members" {
    const first = try deflate.encodeGzipFixedAlloc(std.testing.allocator, "first");
    defer std.testing.allocator.free(first);
    const second = try deflate.encodeGzipStoredWithHeaderAlloc(std.testing.allocator, "second", .{ .filename = "two" });
    defer std.testing.allocator.free(second);
    var stream: std.ArrayList(u8) = .empty;
    defer stream.deinit(std.testing.allocator);
    try stream.appendSlice(std.testing.allocator, first);
    const second_offset = stream.items.len;
    try stream.appendSlice(std.testing.allocator, second);

    var history: [32 * 1024]u8 = undefined;
    var output: [32]u8 = undefined;
    var corrupt = try deflate.GzipIncrementalDecoder.init(.{ .allow_concatenated = true }, &history);
    stream.items[stream.items.len - 8] ^= 1;
    try std.testing.expectError(error.ChecksumMismatch, corrupt.step(stream.items, &output));
    const corrupt_snapshot = corrupt.snapshot();
    try std.testing.expectEqual(@as(usize, 1), corrupt_snapshot.member_count);
    try std.testing.expectEqual(@as(usize, 1), corrupt_snapshot.member_index);
    try std.testing.expectEqual(second_offset, corrupt_snapshot.member_offset);
    try std.testing.expectEqual(@as(?usize, 1), corrupt_snapshot.last_error_member_index);
    try std.testing.expectEqual(@as(?usize, second_offset), corrupt_snapshot.last_error_member_offset);
    try std.testing.expectEqual(@as(?usize, stream.items.len), corrupt_snapshot.last_error_input_offset);
    try std.testing.expectEqual(@as(?deflate.GzipIncrementalDecoder.Phase, .footer), corrupt_snapshot.last_error_phase);
    stream.items[stream.items.len - 8] ^= 1;

    var bad_header = try deflate.GzipIncrementalDecoder.init(.{ .allow_concatenated = true }, &history);
    stream.items[second_offset] ^= 1;
    try std.testing.expectError(error.BadGzipHeader, bad_header.step(stream.items, &output));
    const bad_header_snapshot = bad_header.snapshot();
    try std.testing.expectEqual(@as(?usize, 1), bad_header_snapshot.last_error_member_index);
    try std.testing.expectEqual(@as(?usize, second_offset), bad_header_snapshot.last_error_member_offset);
    try std.testing.expectEqual(@as(?usize, second_offset + 10), bad_header_snapshot.last_error_input_offset);
    try std.testing.expectEqual(@as(?deflate.GzipIncrementalDecoder.Phase, .header), bad_header_snapshot.last_error_phase);
    stream.items[second_offset] ^= 1;

    var short_header = try deflate.GzipIncrementalDecoder.init(.{ .allow_concatenated = true }, &history);
    _ = try short_header.step(stream.items[0 .. second_offset + 4], &output);
    try std.testing.expectError(error.TruncatedFrame, short_header.finish());
    const short_header_snapshot = short_header.snapshot();
    try std.testing.expectEqual(@as(usize, 1), short_header_snapshot.member_count);
    try std.testing.expectEqual(@as(?usize, 1), short_header_snapshot.last_error_member_index);
    try std.testing.expectEqual(@as(?usize, second_offset), short_header_snapshot.last_error_member_offset);
    try std.testing.expectEqual(@as(?usize, second_offset + 4), short_header_snapshot.last_error_input_offset);
    try std.testing.expectEqual(@as(?deflate.GzipIncrementalDecoder.Phase, .header), short_header_snapshot.last_error_phase);

    var short_footer = try deflate.GzipIncrementalDecoder.init(.{ .allow_concatenated = true }, &history);
    _ = try short_footer.step(stream.items[0 .. stream.items.len - 1], &output);
    try std.testing.expectError(error.TruncatedFrame, short_footer.finish());
    const short_footer_snapshot = short_footer.snapshot();
    try std.testing.expectEqual(@as(usize, 1), short_footer_snapshot.member_count);
    try std.testing.expectEqual(@as(?usize, 1), short_footer_snapshot.last_error_member_index);
    try std.testing.expectEqual(@as(?usize, second_offset), short_footer_snapshot.last_error_member_offset);
    try std.testing.expectEqual(@as(?usize, stream.items.len - 1), short_footer_snapshot.last_error_input_offset);
    try std.testing.expectEqual(@as(?deflate.GzipIncrementalDecoder.Phase, .footer), short_footer_snapshot.last_error_phase);
}

test "gzip incremental concatenation snapshots member boundaries and reset" {
    const first = try deflate.encodeGzipFixedAlloc(std.testing.allocator, "one");
    defer std.testing.allocator.free(first);
    const second = try deflate.encodeGzipFixedAlloc(std.testing.allocator, "two");
    defer std.testing.allocator.free(second);

    var history: [32 * 1024]u8 = undefined;
    var output: [8]u8 = undefined;
    var decoder = try deflate.GzipIncrementalDecoder.init(.{ .allow_concatenated = true }, &history);
    const boundary_result = try decoder.step(first, &output);
    try std.testing.expectEqual(.need_input, boundary_result.status);
    const boundary = decoder.snapshot();
    try std.testing.expectEqual(deflate.GzipIncrementalDecoder.Phase.between_members, boundary.phase);
    try std.testing.expectEqual(@as(usize, 1), boundary.member_count);
    try std.testing.expectEqual(@as(usize, 0), boundary.member_index);
    try std.testing.expectEqual(@as(usize, 0), boundary.member_offset);
    try std.testing.expectEqual(first.len, boundary.member_input);

    _ = try decoder.step(second[0..1], &output);
    const next = decoder.snapshot();
    try std.testing.expectEqual(deflate.GzipIncrementalDecoder.Phase.header, next.phase);
    try std.testing.expectEqual(@as(usize, 1), next.member_index);
    try std.testing.expectEqual(first.len, next.member_offset);
    try std.testing.expectEqual(@as(usize, 1), next.member_input);

    decoder.reset();
    const reset = decoder.snapshot();
    try std.testing.expectEqual(deflate.GzipIncrementalDecoder.Phase.header, reset.phase);
    try std.testing.expectEqual(@as(usize, 0), reset.member_index);
    try std.testing.expectEqual(@as(usize, 0), reset.member_offset);
    try std.testing.expectEqual(@as(usize, 0), reset.member_input);
    try std.testing.expectEqual(@as(?usize, null), reset.last_error_member_index);
}
