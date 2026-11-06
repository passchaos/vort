//! Relaxed validation and member checkpoint contracts for incremental zlib.
const Count = @import("../../../../core.zig").StreamCount;
const std = @import("std");
const checksum = @import("../../../../checksum.zig");
const core = @import("../../../../core.zig");
const dictionary_contracts = @import("zlib_dictionary_contracts.zig");
const allocator = std.testing.allocator;

pub fn contracts(comptime D: type) !void {
    try footerValidation(D);
    try tinyBuffers(D);
    try singleMemberTail(D);
    try concatenatedFooters(D);
    try trailingProbe(D);
    try incompletePrefix(D);
    try dictionary_contracts.contracts(D);
    try cumulativeLimitsAndReset(D);
    try blockBoundary(D);
}

fn expectProgress(decoder: anytype, before: anytype, stepped: core.StepResult) !void {
    const after = decoder.snapshot();
    try std.testing.expectEqual(after.total_input - before.total_input, stepped.progress.input_read);
    try std.testing.expectEqual(after.total_output - before.total_output, stepped.progress.output_written);
    try std.testing.expectEqualDeep(stepped.progress, after.last_step_progress);
    try std.testing.expectEqualDeep(after.last_step_progress, decoder.diagnostics().last_step_progress.?);
}

fn expectErrorProgress(decoder: anytype, before: anytype) !void {
    const after = decoder.snapshot();
    try std.testing.expectEqual(after.total_input - before.total_input, after.last_step_progress.input_read);
    try std.testing.expectEqual(after.total_output - before.total_output, after.last_step_progress.output_written);
    try std.testing.expectEqual(@as(?@TypeOf(after.total_input), after.total_input), after.last_error_input_offset);
    try std.testing.expectEqual(@as(?@TypeOf(after.total_output), after.total_output), after.last_error_output_offset);
    try std.testing.expectEqualDeep(after.last_step_progress, decoder.diagnostics().last_step_progress.?);
}

fn footerValidation(comptime D: type) !void {
    const payload = "footer validation remains independent of trailing data";
    const encoded = try D.encodeZlibFixedAlloc(allocator, payload);
    defer allocator.free(encoded);
    const corrupt = try allocator.dupe(u8, encoded);
    defer allocator.free(corrupt);
    corrupt[corrupt.len - 1] ^= 1;
    var output: [payload.len]u8 = undefined;
    var history: [32768]u8 = undefined;
    for ([_]bool{ false, true }) |allow_trailing| {
        var strict = try D.ZlibIncrementalDecoder.init(.{ .allow_trailing_data = allow_trailing }, &history);
        const before = strict.snapshot();
        try std.testing.expectError(error.ChecksumMismatch, strict.step(corrupt, &output));
        try expectErrorProgress(&strict, before);
        try std.testing.expectEqual(@as(?Count, null), strict.memberEndOffset());
        try std.testing.expectEqual(@as(usize, 0), strict.snapshot().stream_count);

        var relaxed = try D.ZlibIncrementalDecoder.init(.{
            .ignore_adler = true,
            .allow_trailing_data = allow_trailing,
        }, &history);
        const done = try relaxed.step(corrupt, &output);
        try std.testing.expectEqual(.done, done.status);
        try std.testing.expectEqualSlices(u8, payload, &output);
        try std.testing.expectEqual(checksum.Adler32.hash(payload), relaxed.adler.digest());
        try std.testing.expectEqual(@as(?Count, encoded.len), relaxed.memberEndOffset());
        try std.testing.expectEqual(payload.len, relaxed.total_output);
        try relaxed.finish();
    }
    for (0..4) |footer_bytes| {
        var relaxed = try D.ZlibIncrementalDecoder.init(.{ .ignore_adler = true }, &history);
        const partial = try relaxed.step(corrupt[0 .. corrupt.len - 4 + footer_bytes], &output);
        try std.testing.expectEqual(.need_input, partial.status);
        try std.testing.expectEqual(.footer, relaxed.phase);
        try std.testing.expectEqual(footer_bytes, relaxed.snapshot().footer_received);
        try std.testing.expectEqual(@as(?Count, null), relaxed.memberEndOffset());
        try std.testing.expectError(error.TruncatedFrame, relaxed.finish());
    }
}

fn tinyBuffers(comptime D: type) !void {
    const payload = "tiny zlib output buffers must still drain a final EOB" ** 4;
    const encoded = try D.encodeZlibFixedAlloc(allocator, payload);
    defer allocator.free(encoded);
    var history: [32768]u8 = undefined;
    var decoder = try D.ZlibIncrementalDecoder.init(.{
        .ignore_adler = true,
        .expected_output_len = payload.len,
    }, &history);
    var output: [payload.len]u8 = undefined;
    var consumed: usize = 0;
    var written: usize = 0;
    var calls: usize = 0;
    while (decoder.phase != .done) : (calls += 1) {
        try std.testing.expect(calls < 8 * (encoded.len + payload.len));
        const before = decoder.snapshot();
        const destination = output[written..][0..@min(if (calls % 3 == 0) @as(usize, 0) else 1, output.len - written)];
        const stepped = try decoder.step(encoded[consumed..][0..@min(1, encoded.len - consumed)], destination);
        try expectProgress(&decoder, before, stepped);
        consumed += stepped.progress.input_read;
        written += stepped.progress.output_written;
    }
    try std.testing.expectEqual(encoded.len, consumed);
    try std.testing.expectEqualSlices(u8, payload, &output);
    try decoder.finish();

    // Supplying exactly enough output must still consume a footer with no
    // additional output capacity, including a buffered end-of-block symbol.
    decoder.reset();
    const before_footer = try decoder.step(encoded[0 .. encoded.len - 4], &output);
    try std.testing.expectEqual(payload.len, before_footer.progress.output_written);
    try std.testing.expectEqual(.footer, decoder.phase);
    for (0..4) |i| {
        const before = decoder.snapshot();
        const stepped = try decoder.step(encoded[encoded.len - 4 + i ..][0..1], &.{});
        try expectProgress(&decoder, before, stepped);
        try std.testing.expectEqual(@as(usize, 1), stepped.progress.input_read);
        try std.testing.expectEqual(@as(usize, 0), stepped.progress.output_written);
        try std.testing.expectEqual(if (i == 3) core.StepResult.Status.done else .need_input, stepped.status);
    }
}

fn singleMemberTail(comptime D: type) !void {
    const payload = "one zlib member";
    const encoded = try D.encodeZlibStoredAlloc(allocator, payload);
    defer allocator.free(encoded);
    const joined = try std.mem.concat(allocator, u8, &.{ encoded, "suffix" });
    defer allocator.free(joined);
    var history: [32768]u8 = undefined;
    var output: [payload.len]u8 = undefined;
    var decoder = try D.ZlibIncrementalDecoder.init(.{ .allow_trailing_data = true }, &history);
    const before = decoder.snapshot();
    const done = try decoder.step(joined, &output);
    try expectProgress(&decoder, before, done);
    try std.testing.expectEqual(.done, done.status);
    try std.testing.expectEqual(encoded.len, done.progress.input_read);
    try std.testing.expectEqualStrings("suffix", joined[done.progress.input_read..]);
    try std.testing.expectEqual(@as(usize, 0), decoder.trailingPrefix().len);
    try std.testing.expectEqual(@as(?Count, encoded.len), decoder.snapshot().member_end_offset);
    const repeat = try decoder.step("suffix", &.{});
    try std.testing.expectEqual(.done, repeat.status);
    try std.testing.expectEqual(@as(usize, 0), repeat.progress.input_read);
    try decoder.finish();
    try std.testing.expectError(error.TrailingData, decoder.step("suffix", &.{}));
    try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().last_step_progress.input_read);
}

fn concatenatedFooters(comptime D: type) !void {
    const first_payload = "first";
    const second_payload = "second member payload";
    const first = try D.encodeZlibStoredAlloc(allocator, first_payload);
    defer allocator.free(first);
    const second = try D.encodeZlibFixedAlloc(allocator, second_payload);
    defer allocator.free(second);
    const joined = try std.mem.concat(allocator, u8, &.{ first, second });
    defer allocator.free(joined);
    var history: [32768]u8 = undefined;
    var output: [first_payload.len + second_payload.len]u8 = undefined;
    for ([_]usize{ first.len - 1, joined.len - 1 }) |corrupt_offset| {
        joined[corrupt_offset] ^= 1;
        var strict = try D.ZlibIncrementalDecoder.init(.{
            .allow_concatenated = true,
            .allow_trailing_data = true,
        }, &history);
        const before = strict.snapshot();
        try std.testing.expectError(error.ChecksumMismatch, strict.step(joined, &output));
        try expectErrorProgress(&strict, before);
        try std.testing.expectEqual(if (corrupt_offset < first.len) @as(?Count, null) else first.len, strict.memberEndOffset());
        var relaxed = try D.ZlibIncrementalDecoder.init(.{
            .allow_concatenated = true,
            .allow_trailing_data = true,
            .ignore_adler = true,
        }, &history);
        const stepped = try relaxed.step(joined, &output);
        try std.testing.expectEqual(.need_input, stepped.status);
        try std.testing.expectEqual(@as(usize, 2), relaxed.snapshot().stream_count);
        try std.testing.expectEqual(second.len, relaxed.snapshot().stream_input);
        try std.testing.expectEqual(first.len, relaxed.snapshot().stream_offset);
        try std.testing.expectEqual(@as(?Count, joined.len), relaxed.memberEndOffset());
        try std.testing.expectEqualSlices(u8, first_payload ++ second_payload, &output);
        try relaxed.finish();
        joined[corrupt_offset] ^= 1;
    }
}

fn trailingProbe(comptime D: type) !void {
    const encoded = try D.encodeZlibStoredAlloc(allocator, "");
    defer allocator.free(encoded);
    var history: [32768]u8 = undefined;
    for ([_][]const u8{ "tail", &.{ 0x78, 0xff, 0x55 }, &.{0x88} }) |tail| {
        const joined = try std.mem.concat(allocator, u8, &.{ encoded, tail });
        defer allocator.free(joined);
        var decoder = try D.ZlibIncrementalDecoder.init(.{
            .allow_concatenated = true,
            .allow_trailing_data = true,
        }, &history);
        const before = decoder.snapshot();
        const done = try decoder.step(joined, &.{});
        try expectProgress(&decoder, before, done);
        try std.testing.expectEqual(.done, done.status);
        try std.testing.expectEqual(encoded.len, done.progress.input_read);
        try std.testing.expectEqualSlices(u8, tail, joined[done.progress.input_read..]);
        try std.testing.expectEqual(@as(usize, 0), decoder.snapshot().trailing_prefix_len);
        try decoder.finish();
    }
    var decoder = try D.ZlibIncrementalDecoder.init(.{
        .allow_concatenated = true,
        .allow_trailing_data = true,
    }, &history);
    _ = try decoder.step(encoded, &.{});
    const prefix = try decoder.step(&.{0x78}, &.{});
    try std.testing.expectEqual(.need_input, prefix.status);
    try std.testing.expectEqual(@as(usize, 1), prefix.progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), decoder.trailingPrefix().len);
    try std.testing.expectEqual(encoded.len, decoder.snapshot().stream_input);
    const before = decoder.snapshot();
    const done = try decoder.step(&.{ 0xff, 0x55 }, &.{});
    try expectProgress(&decoder, before, done);
    try std.testing.expectEqual(.done, done.status);
    try std.testing.expectEqual(@as(usize, 0), done.progress.input_read);
    try std.testing.expectEqualSlices(u8, &.{0x78}, decoder.trailingPrefix());
    try std.testing.expectEqual(@as(usize, 1), decoder.snapshot().trailing_prefix_len);
    try std.testing.expectEqual(encoded.len + 1, decoder.total_input);
    try std.testing.expectEqual(encoded.len, decoder.snapshot().stream_input);
    try std.testing.expectEqual(@as(?Count, encoded.len), decoder.memberEndOffset());
    const recovered = try std.mem.concat(allocator, u8, &.{ decoder.trailingPrefix(), &.{ 0xff, 0x55 } });
    defer allocator.free(recovered);
    try std.testing.expectEqualSlices(u8, &.{ 0x78, 0xff, 0x55 }, recovered);
}

fn incompletePrefix(comptime D: type) !void {
    const encoded = try D.encodeZlibStoredAlloc(allocator, "");
    defer allocator.free(encoded);
    var history: [32768]u8 = undefined;
    for ([_][]const u8{ "", &.{0x78} }) |suffix| {
        var decoder = try D.ZlibIncrementalDecoder.init(.{
            .allow_concatenated = true,
            .allow_trailing_data = true,
        }, &history);
        _ = try decoder.step(encoded, &.{});
        _ = try decoder.step(suffix, &.{});
        try std.testing.expectEqual(@as(usize, 0), decoder.trailingPrefix().len);
        try decoder.finish();
        try std.testing.expectEqualSlices(u8, suffix, decoder.trailingPrefix());
        try std.testing.expectEqual(suffix.len, decoder.snapshot().trailing_prefix_len);
        try std.testing.expectEqual(encoded.len, decoder.snapshot().stream_input);
        try std.testing.expectEqual(encoded.len + suffix.len, decoder.total_input);
        const done = try decoder.step("", &.{});
        try std.testing.expectEqual(.done, done.status);
    }
    var strict = try D.ZlibIncrementalDecoder.init(.{ .allow_concatenated = true }, &history);
    _ = try strict.step(encoded, &.{});
    _ = try strict.step(&.{0x78}, &.{});
    try std.testing.expectError(error.TruncatedFrame, strict.finish());
}

fn cumulativeLimitsAndReset(comptime D: type) !void {
    const first = try D.encodeZlibStoredAlloc(allocator, "abc");
    defer allocator.free(first);
    const second = try D.encodeZlibFixedAlloc(allocator, "def");
    defer allocator.free(second);
    const empty = try D.encodeZlibStoredAlloc(allocator, "");
    defer allocator.free(empty);
    const joined = try std.mem.concat(allocator, u8, &.{ first, second, empty, &.{0x78} });
    defer allocator.free(joined);
    var history: [32768]u8 = undefined;
    var output: [6]u8 = undefined;
    var exact = try D.ZlibIncrementalDecoder.init(.{
        .allow_concatenated = true,
        .allow_trailing_data = true,
        .expected_output_len = 6,
        .max_output_len = 6,
    }, &history);
    const stepped = try exact.step(joined, &output);
    try std.testing.expectEqual(joined.len, stepped.progress.input_read);
    try std.testing.expectEqualSlices(u8, "abcdef", &output);
    try std.testing.expectEqual(@as(usize, 3), exact.snapshot().stream_count);
    try std.testing.expectEqual(@as(?Count, joined.len - 1), exact.memberEndOffset());
    try exact.finish();
    try std.testing.expectEqualSlices(u8, &.{0x78}, exact.trailingPrefix());
    exact.reset();
    try std.testing.expectEqual(@as(?Count, null), exact.memberEndOffset());
    try std.testing.expectEqual(@as(?Count, null), exact.snapshot().member_end_offset);
    try std.testing.expectEqual(@as(usize, 0), exact.snapshot().trailing_prefix_len);
    try std.testing.expectEqual(@as(usize, 0), exact.snapshot().stream_input);
    try std.testing.expectEqual(@as(usize, 0), exact.total_input);
    try std.testing.expectEqual(@as(usize, 0), exact.total_output);
    try std.testing.expectEqualDeep(core.Progress{}, exact.snapshot().last_step_progress);
    const repeated = try exact.step(joined, &output);
    try std.testing.expectEqualDeep(stepped, repeated);
    try exact.finish();

    for ([_]bool{ false, true }) |pledged| {
        var limited = try D.ZlibIncrementalDecoder.init(.{
            .allow_concatenated = true,
            .allow_trailing_data = true,
            .max_output_len = if (pledged) 6 else 5,
            .expected_output_len = if (pledged) 5 else null,
        }, &history);
        const before = limited.snapshot();
        try std.testing.expectError(if (pledged) error.SizeMismatch else error.OutputLimitExceeded, limited.step(joined, &output));
        try expectErrorProgress(&limited, before);
        try std.testing.expectEqual(@as(usize, 5), limited.total_output);
        try std.testing.expectEqual(@as(?Count, first.len), limited.memberEndOffset());
        try std.testing.expectEqual(@as(usize, 1), limited.snapshot().last_error_stream_index.?);
    }
    var too_long = try D.ZlibIncrementalDecoder.init(.{
        .allow_concatenated = true,
        .allow_trailing_data = true,
        .expected_output_len = 7,
    }, &history);
    _ = try too_long.step(joined, &output);
    try std.testing.expectError(error.SizeMismatch, too_long.finish());
}

fn blockBoundary(comptime D: type) !void {
    // Two stored blocks under one zlib header, followed by a nonmember tail.
    var encoded = [_]u8{
        0x78, 0x01,
        0x00, 0x03,
        0x00, 0xfc,
        0xff, 'a',
        'b',  'c',
        0x01, 0x03,
        0x00, 0xfc,
        0xff, 'd',
        'e',  'f',
        0,    0,
        0,    0,
        0x78, 0xff,
    };
    std.mem.writeInt(u32, encoded[18..22], checksum.Adler32.hash("abcdef"), .big);
    var history: [32768]u8 = undefined;
    var output: [6]u8 = undefined;
    var decoder = try D.ZlibIncrementalDecoder.init(.{
        .allow_concatenated = true,
        .allow_trailing_data = true,
        .expected_output_len = output.len,
    }, &history);
    const before = decoder.snapshot();
    const paused = try decoder.stepToBlockBoundary(&encoded, &output);
    try expectProgress(&decoder, before, paused);
    try std.testing.expect(paused.block_boundary);
    try std.testing.expect(decoder.atBlockBoundary());
    try std.testing.expectEqual(@as(usize, 3), paused.progress.output_written);
    const resumed_before = decoder.snapshot();
    const done = try decoder.stepToBlockBoundary(encoded[paused.progress.input_read..], output[3..]);
    try expectProgress(&decoder, resumed_before, done);
    try std.testing.expectEqual(.done, done.status);
    try std.testing.expectEqualSlices(u8, "abcdef", &output);
    try std.testing.expectEqual(@as(usize, 22), decoder.total_input);
    try std.testing.expectEqual(@as(?Count, 22), decoder.memberEndOffset());
    try std.testing.expectEqual(@as(usize, 0), decoder.trailingPrefix().len);
    try decoder.finish();
}
