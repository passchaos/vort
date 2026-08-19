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
    try std.testing.expectEqual(@as(usize, 1), corrupt.snapshot().member_count);
    stream.items[stream.items.len - 8] ^= 1;

    var short_header = try deflate.GzipIncrementalDecoder.init(.{ .allow_concatenated = true }, &history);
    _ = try short_header.step(stream.items[0 .. second_offset + 4], &output);
    try std.testing.expectError(error.TruncatedFrame, short_header.finish());
    try std.testing.expectEqual(@as(usize, 1), short_header.snapshot().member_count);

    var short_footer = try deflate.GzipIncrementalDecoder.init(.{ .allow_concatenated = true }, &history);
    _ = try short_footer.step(stream.items[0 .. stream.items.len - 1], &output);
    try std.testing.expectError(error.TruncatedFrame, short_footer.finish());
    try std.testing.expectEqual(@as(usize, 1), short_footer.snapshot().member_count);
}
