//! Empty serialized transforms follow libbrotli's absolute-distance boundary.
const std = @import("std");
const fixture = @import("progress_fixture.zig");

pub fn contracts(comptime Codec: type) !void {
    const parsed = try Codec.parseSerializedSharedDictionary(&fixture.dictionary);
    var transformed: [32]u8 = @splat(0xa5);
    try std.testing.expectEqual(@as(usize, 0), (try parsed.resolve(0, 4, 0, &transformed)).bytes.len);
    try std.testing.expectEqual(@as(usize, 0), (try parsed.resolve(0, 4, 120, &transformed)).bytes.len);
    const options: Codec.DecodeOptions = .{ .shared_dictionary = .{ .serialized = &parsed } };
    inline for (.{ .stalled, .stalled_distance_120, .command_bits, .block_remaining, .output }) |kind| {
        const wire = try fixture.create(std.testing.allocator, kind);
        defer std.testing.allocator.free(wire);
        try golden(wire, kind);
        try malformed(Codec, wire, options, error.CorruptFrame);
        try resetAfterRejection(Codec, wire, options, kind);
    }
    inline for (.{ .distant_command_bits, .distant_block_remaining, .distant_output }) |kind| {
        const wire = try fixture.create(std.testing.allocator, kind);
        defer std.testing.allocator.free(wire);
        try golden(wire, kind);
        try valid(Codec, wire, options, kind);
    }
    const truncated = try fixture.create(std.testing.allocator, .distance_bits_truncated);
    defer std.testing.allocator.free(truncated);
    try golden(truncated, .distance_bits_truncated);
    try malformed(Codec, truncated, options, error.TruncatedFrame);
}

fn golden(wire: []const u8, kind: fixture.Kind) !void {
    // These exact artifacts were independently consumed by libbrotli 1.2.0
    // built with BROTLI_EXPERIMENTAL. The low-distance cases returned FORMAT_
    // TRANSFORM; distant complete cases returned SUCCESS, and truncated extras
    // returned NEEDS_MORE_INPUT. See the handoff's /tmp reference artifacts.
    const hex = switch (kind) {
        .stalled => "02000004045e081210",
        .stalled_distance_120 => "0200003f045e08128700",
        .command_bits => "02000004045e0982484004",
        .block_remaining => "02004044014240e0852081484000",
        .output => "22000008045e281211",
        .distant_command_bits => "02000000045e0982486478",
        .distant_block_remaining => "02004044010240e085208148649c03",
        .distant_output => "22000000045e28121907",
        .distance_bits_truncated => "02000000045e081219e71c",
    };
    var bytes: [15]u8 = undefined;
    _ = try std.fmt.hexToBytes(bytes[0 .. hex.len / 2], hex);
    try std.testing.expectEqualSlices(u8, bytes[0 .. hex.len / 2], wire);
}

fn malformed(comptime Codec: type, wire: []const u8, options: Codec.DecodeOptions, comptime expected_error: anyerror) !void {
    var diagnostics: Codec.StreamSummaryDiagnostics = undefined;
    var history: [8]u8 = undefined;
    const chunks = [_][]const u8{ "", wire[0..1], wire[1 .. wire.len - 1], "", wire[wire.len - 1 ..] };
    var scratch: [32]u8 = undefined;
    const a = std.testing.allocator;
    try std.testing.expectError(expected_error, Codec.decodedStreamSizeWithOptions(wire, options));
    try std.testing.expectError(expected_error, Codec.decodedStreamSizeLimitedWithOptions(wire, 2, options));
    try std.testing.expectError(expected_error, Codec.decodedStreamChunksSizeWithOptions(&chunks, &scratch, options));
    try std.testing.expectError(expected_error, Codec.summarizeStreamWithOptions(wire, options));
    try std.testing.expectError(expected_error, Codec.summarizeStreamWithHistoryAndOptions(wire, &history, options));
    try std.testing.expectError(expected_error, Codec.summarizeStreamAllocWithOptions(std.testing.failing_allocator, wire, options));
    try std.testing.expectError(expected_error, Codec.summarizeStreamLimitedWithOptionsAndDiagnostics(wire, 2, options, &diagnostics));
    try std.testing.expectEqual(Codec.StreamSummaryErrorPhase.compressed_meta_block, diagnostics.phase);
    try std.testing.expectEqual(@as(Codec.Counter, 0), diagnostics.meta_block_index);
    try std.testing.expectError(expected_error, Codec.summarizeStreamChunksWithOptions(&chunks, &scratch, options));
    try std.testing.expectError(expected_error, Codec.summarizeStreamChunksWithHistoryAndOptions(&chunks, &scratch, &history, options));
    const probe = Codec.probeStreamWithOptions(wire, options);
    try std.testing.expect(!probe.ok);
    try std.testing.expectEqualStrings(@errorName(expected_error), probe.error_name);

    var output: [2]u8 = @splat(0xa5);
    try std.testing.expectError(expected_error, Codec.decodeStreamIntoWithOptions(wire, &output, options));
    try std.testing.expectError(expected_error, Codec.decodeStreamIntoLimitedWithOptions(wire, &output, 2, options));
    try std.testing.expectError(expected_error, Codec.decodeStreamIntoExactSizeWithOptions(wire, &output, 2, options));
    try std.testing.expectError(expected_error, Codec.decodeStreamAllocWithOptions(a, wire, options));
    try std.testing.expectError(expected_error, Codec.decodeStreamAllocLimitedWithOptions(a, wire, 2, options));
    try std.testing.expectError(expected_error, Codec.decodeStreamAllocExactSizeWithOptions(a, wire, 2, options));
    try std.testing.expectError(expected_error, Codec.decodeStreamChunksAllocWithOptions(a, &chunks, &scratch, options));
    try std.testing.expectError(expected_error, Codec.decodeStreamChunksIntoWithOptions(&chunks, &scratch, &output, options));
    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(a);
    try appended.appendSlice(a, "prefix:");
    try std.testing.expectError(expected_error, Codec.decodeStreamAppendWithOptions(a, &appended, wire, options));
    try std.testing.expectEqualStrings("prefix:", appended.items);
    try std.testing.expectError(expected_error, Codec.decodeStreamChunksAppendWithOptions(a, &appended, &chunks, &scratch, options));
    try std.testing.expectEqualStrings("prefix:", appended.items);
}

fn valid(comptime Codec: type, wire: []const u8, options: Codec.DecodeOptions, kind: fixture.Kind) !void {
    const expected = fixture.expected(kind);
    const empty_count: Codec.Counter = if (kind == .distant_block_remaining) 2 else 1;
    const commands: Codec.Counter = empty_count + 1;
    const a = std.testing.allocator;
    var history: [8]u8 = undefined;
    const summary = try Codec.summarizeStreamWithHistoryAndOptions(wire, &history, options);
    try std.testing.expectEqual(@as(Codec.Counter, expected.len), summary.decoded_bytes);
    try std.testing.expectEqual(commands, summary.command_count);
    try std.testing.expect(summary.uses_shared_dictionary);
    try std.testing.expectEqual(empty_count, summary.shared_dictionary_copy_count);
    try std.testing.expectEqual(@as(Codec.Counter, 0), summary.shared_dictionary_bytes);
    try std.testing.expectEqual(empty_count, summary.regular_distance_copy_count);
    try std.testing.expectEqual(@as(Codec.Counter, 0), summary.lz77_copy_count);
    try std.testing.expectEqualDeep(summary, try Codec.summarizeStreamAllocWithOptions(std.testing.failing_allocator, wire, options));
    try std.testing.expectEqual(summary.decoded_bytes, try Codec.decodedStreamSizeWithOptions(wire, options));
    const chunks = [_][]const u8{ wire[0..1], "", wire[1..] };
    var scratch: [32]u8 = undefined;
    try std.testing.expectEqualDeep(summary, try Codec.summarizeStreamChunksWithHistoryAndOptions(&chunks, &scratch, &history, options));
    const decoded = try Codec.decodeStreamAllocExactSizeWithOptions(a, wire, expected.len, options);
    defer a.free(decoded);
    try std.testing.expectEqualSlices(u8, expected, decoded);
    var output: [2]u8 = undefined;
    try std.testing.expectEqual(expected.len, try Codec.decodeStreamIntoWithOptions(wire, output[0..expected.len], options));
    try std.testing.expectEqualSlices(u8, expected, output[0..expected.len]);
    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(a);
    try appended.appendSlice(a, "prefix:");
    try std.testing.expectEqual(expected.len, try Codec.decodeStreamAppendWithOptions(a, &appended, wire, options));
    try std.testing.expectEqualSlices(u8, expected, appended.items["prefix:".len..]);

    var progressive = Codec.IncrementalCopyStreamDecoder.initWithOptions(&history, .{ .decode = options, .expected_output_len = expected.len, .max_output_len = expected.len });
    try drive(&progressive, wire, expected);
    var owned = Codec.IncrementalStreamDecoder.initWithOptions(a, .{ .decode = options, .expected_compressed_len = wire.len, .expected_output_len = expected.len, .max_output_len = expected.len });
    defer owned.deinit();
    try drive(&owned, wire, expected);
}

fn resetAfterRejection(comptime Codec: type, wire: []const u8, options: Codec.DecodeOptions, kind: fixture.Kind) !void {
    const recovery_kind: fixture.Kind = if (kind == .output) .distant_output else .distant_command_bits;
    const recovery = try fixture.create(std.testing.allocator, recovery_kind);
    defer std.testing.allocator.free(recovery);
    const expected = fixture.expected(recovery_kind);
    var history: [8]u8 = undefined;
    var output: [2]u8 = @splat(0xa5);
    var progressive = Codec.IncrementalCopyStreamDecoder.initWithOptions(&history, .{ .decode = options, .expected_output_len = expected.len });
    try std.testing.expectError(error.CorruptFrame, progressive.step(wire, &output));
    progressive.reset();
    try drive(&progressive, recovery, expected);
    var owned = Codec.IncrementalStreamDecoder.initWithOptions(std.testing.allocator, .{ .decode = options, .expected_output_len = expected.len });
    defer owned.deinit();
    try std.testing.expectError(error.CorruptFrame, owned.step(wire, &output));
    owned.reset();
    try drive(&owned, recovery, expected);
}

fn drive(decoder: anytype, wire: []const u8, expected: []const u8) !void {
    var output: [2]u8 = @splat(0xa5);
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    var attempts: usize = 0;
    while (decoder.snapshot().phase != .done) : (attempts += 1) {
        try std.testing.expect(attempts < 100);
        const result = try decoder.step(wire[input_offset..@min(wire.len, input_offset + 1)], output[output_offset..@min(expected.len, output_offset + 1)]);
        input_offset += result.progress.input_read;
        output_offset += result.progress.output_written;
        if (result.status == .need_input) try std.testing.expect(input_offset < wire.len);
        if (result.status == .need_output) try std.testing.expect(output_offset < expected.len);
    }
    try decoder.finish();
    try std.testing.expectEqual(wire.len, input_offset);
    try std.testing.expectEqual(expected.len, output_offset);
    try std.testing.expectEqualSlices(u8, expected, output[0..output_offset]);
}
