const std = @import("std");
const br = @import("../../../br.zig");
const a = std.testing.allocator;

const Case = enum { empty, buffered, full_block, pending_output, pending_prefix };

fn payload(case: Case) []const u8 {
    return switch (case) {
        .empty, .pending_prefix => "",
        .buffered, .pending_output => "ABCDEF",
        .full_block => "ABCDEFGH",
    };
}

fn feed(encoder: anytype, plain: []const u8, encoded: *std.ArrayList(u8), stride: usize) !void {
    var output: [3]u8 = undefined;
    var offset: usize = 0;
    while (offset != plain.len) {
        const step = try encoder.step(plain[offset..], output[0..stride]);
        offset += step.progress.input_read;
        try encoded.appendSlice(a, output[0..step.progress.output_written]);
        try std.testing.expect(step.progress.input_read != 0 or step.progress.output_written != 0);
    }
}

fn prepare(encoder: anytype, case: Case, encoded: *std.ArrayList(u8), stride: usize) !void {
    if (case == .pending_prefix) {
        const step = try encoder.step("", &.{});
        try std.testing.expect(step.status == .need_output);
        try std.testing.expect(encoder.snapshot().pending_output != 0);
        return;
    }
    try feed(encoder, payload(case), encoded, stride);
    if (case == .pending_output) {
        encoder.endChunk();
        const step = try encoder.step("", &.{});
        try std.testing.expect(step.status == .need_output);
        try std.testing.expect(encoder.snapshot().pending_output != 0);
    }
    if (case == .buffered)
        try std.testing.expectEqual(payload(case).len, encoder.snapshot().buffered_input);
}

fn drain(encoder: anytype, encoded: *std.ArrayList(u8), stride: usize, finishing: bool) !void {
    var output: [3]u8 = undefined;
    for (0..512) |_| {
        const step = try encoder.step("", output[0..stride]);
        try encoded.appendSlice(a, output[0..step.progress.output_written]);
        if (finishing) {
            if (step.status == .done) return;
            try std.testing.expect(step.status == .need_output);
        } else if (step.status == .need_input) return;
        try std.testing.expect(step.progress.output_written != 0);
    }
    return error.TestUnexpectedResult;
}

fn check(comptime Encoder: type) !void {
    for (std.enums.values(Case)) |case| {
        for ([_]usize{ 1, 3 }) |stride| {
            for ([_][]const u8{ "M", "" }) |metadata| {
                const options: Encoder.Options = .{
                    .stream = .{ .metadata = if (case == .pending_prefix) "P" else "" },
                    .block_len = 8,
                };
                var immediate = Encoder.initWithOptions(a, options);
                defer immediate.deinit();
                var ordinary = Encoder.initWithOptions(a, options);
                defer ordinary.deinit();
                var actual: std.ArrayList(u8) = .empty;
                defer actual.deinit(a);
                var expected: std.ArrayList(u8) = .empty;
                defer expected.deinit(a);
                try prepare(&immediate, case, &actual, stride);
                try prepare(&ordinary, case, &expected, stride);
                try immediate.writeMetadata(metadata);
                try ordinary.writeMetadata(metadata);
                try std.testing.expect(immediate.snapshot().metadata_pending);
                try immediate.finish();
                try std.testing.expect(immediate.snapshot().finishing);
                try std.testing.expect(immediate.snapshot().metadata_pending);
                // Exercise an empty-output retry before either backpressure stride.
                const blocked = try immediate.step("", &.{});
                try std.testing.expect(blocked.status == .need_output);
                try std.testing.expectEqual(@as(usize, 0), blocked.progress.output_written);
                try drain(&immediate, &actual, stride, true);
                try drain(&ordinary, &expected, stride, false);
                try ordinary.finish();
                try drain(&ordinary, &expected, stride, true);
                try std.testing.expectEqualSlices(u8, expected.items, actual.items);
                const snapshot = immediate.snapshot();
                try std.testing.expect(snapshot.done);
                try std.testing.expect(!snapshot.metadata_pending);
                try std.testing.expectEqual(@as(usize, 0), snapshot.metadata_bytes);
                try std.testing.expect(!snapshot.flush_requested);
                try std.testing.expectEqual(@as(usize, 0), snapshot.pending_output);
                try std.testing.expectEqual(@as(usize, 0), snapshot.buffered_input);
                try std.testing.expectEqual(@as(Encoder.Counter, 1), snapshot.stream_count);
                const summary = try br.summarizeStream(actual.items);
                try std.testing.expectEqual(@as(br.Counter, if (case == .pending_prefix) 2 else 1), summary.metadata_meta_block_count);
                try std.testing.expectEqual(@as(br.Counter, metadata.len + @as(usize, @intFromBool(case == .pending_prefix))), summary.metadata_bytes);
                const decoded = try br.decodeStreamAllocExactSize(a, actual.items, payload(case).len);
                defer a.free(decoded);
                try std.testing.expectEqualSlices(u8, payload(case), decoded);
            }
        }
    }
}

test "Brotli encoder finish pending metadata stored keeps accepted metadata" {
    try check(br.IncrementalStoredStreamEncoder);
}

test "Brotli encoder finish pending metadata planned keeps accepted metadata" {
    try check(br.IncrementalPlannedStreamEncoder);
}

test "Brotli encoder finish pending metadata static dictionary keeps accepted metadata" {
    try check(br.IncrementalStaticDictionaryStreamEncoder);
}

fn checkNoMetadata(comptime Encoder: type, fixtures: []const []const u8) !void {
    const plains = [_][]const u8{ "", "ABCDEF", "ABCDEFGH", "ABCDEFGHABCDEF", "time time time time" };
    for (plains, 0..) |plain, index| {
        for ([_]usize{ 1, 3 }) |stride| {
            for ([_]bool{ false, true }) |flush_first| {
                var encoder = Encoder.initWithOptions(a, .{ .block_len = 8 });
                defer encoder.deinit();
                var encoded: std.ArrayList(u8) = .empty;
                defer encoded.deinit(a);
                try feed(&encoder, plain, &encoded, stride);
                if (flush_first) encoder.flush();
                try encoder.finish();
                try drain(&encoder, &encoded, stride, true);
                var expected: [128]u8 = undefined;
                const frozen = try std.fmt.hexToBytes(&expected, fixtures[index]);
                try std.testing.expectEqualSlices(u8, frozen, encoded.items);
                try std.testing.expect(!encoder.snapshot().metadata_pending);
            }
        }
    }
}

fn checkFlush(comptime Encoder: type, options: Encoder.Options, expected_padding: usize, explicit_metadata: bool) !void {
    const first = ("The quick brown fox jumps over the lazy dog. " ** 3)[0..121];
    const second = "A continuation in the same Brotli stream.";
    var encoder = Encoder.initWithOptions(a, options);
    defer encoder.deinit();
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(a);
    try feed(&encoder, first, &wire, 1);
    encoder.flush();
    if (explicit_metadata) try encoder.writeMetadata("M");
    const blocked = try encoder.step("", &.{});
    try std.testing.expectEqual(.need_output, blocked.status);
    try std.testing.expectEqual(@as(usize, 0), blocked.progress.output_written);
    try std.testing.expect(encoder.snapshot().flush_requested);
    try std.testing.expectError(error.TrailingData, encoder.step(second, &.{}));
    try drain(&encoder, &wire, 1, false);
    try std.testing.expectEqual(@as(u3, 0), encoder.codec_state.bit_index);
    try std.testing.expect(!encoder.snapshot().flush_requested);

    // No final marker and no later input are available to the decoder. A
    // non-final complete prefix still publishes every accepted plaintext byte.
    var history: [first.len]u8 = undefined;
    var captured: [1]u8 = undefined;
    var metadata_lengths: [2]usize = @splat(1);
    var decoder = br.IncrementalCopyStreamDecoder.initWithOptions(&history, .{ .metadata_output = &captured, .metadata_block_lengths = &metadata_lengths });
    var decoded: [first.len + 1]u8 = @splat(0xa5);
    const prefix = try decoder.step(wire.items, &decoded);
    try std.testing.expectEqual(.need_input, prefix.status);
    try std.testing.expectEqual(wire.items.len, prefix.progress.input_read);
    try std.testing.expectEqual(first.len, prefix.progress.output_written);
    try std.testing.expectEqualSlices(u8, first, decoded[0..first.len]);
    try std.testing.expectEqual(@as(u8, 0xa5), decoded[first.len]);
    const metadata_count = expected_padding + @as(usize, @intFromBool(explicit_metadata));
    try std.testing.expectEqual(@as(br.Counter, metadata_count), decoder.snapshot().metadata_block_count);
    if (expected_padding != 0) try std.testing.expectEqual(@as(usize, 0), metadata_lengths[0]);
    if (explicit_metadata) {
        try std.testing.expectEqual(@as(usize, 1), metadata_lengths[expected_padding]);
        try std.testing.expectEqualSlices(u8, "M", &captured);
    }

    encoder.flush();
    const again = try encoder.step("", &.{});
    try std.testing.expectEqual(.need_input, again.status);
    try std.testing.expectEqual(@as(usize, 0), again.progress.output_written);
    try std.testing.expectEqual(@as(Encoder.Counter, wire.items.len), encoder.snapshot().output_written);

    try feed(&encoder, second, &wire, 1);
    try encoder.finish();
    try drain(&encoder, &wire, 1, true);
    const complete = try br.decodeStreamAllocExactSize(a, wire.items, first.len + second.len);
    defer a.free(complete);
    try std.testing.expectEqualSlices(u8, first, complete[0..first.len]);
    try std.testing.expectEqualSlices(u8, second, complete[first.len..]);
    const summary = try br.summarizeStream(wire.items);
    try std.testing.expectEqual(@as(br.Counter, metadata_count), summary.metadata_meta_block_count);
    try std.testing.expectEqual(@as(br.Counter, @intFromBool(explicit_metadata)), summary.metadata_bytes);
}

test "Brotli flush exposes all plaintext with empty and one-byte output" {
    try checkFlush(br.IncrementalStoredStreamEncoder, .{ .block_len = 256 }, 0, false);
    try checkFlush(br.IncrementalPlannedStreamEncoder, .{ .block_len = 256, .stream = .{ .quality = 4 } }, 1, false);
    try checkFlush(br.IncrementalStaticDictionaryStreamEncoder, .{ .block_len = 256 }, 1, false);
}

test "Brotli flush uses accepted metadata for alignment without an empty block" {
    try checkFlush(br.IncrementalPlannedStreamEncoder, .{ .block_len = 256, .stream = .{ .quality = 4 } }, 0, true);
}

test "Brotli encoder finish pending metadata preserves frozen no metadata wire controls" {
    // Captured from the untouched isolated source before the finalization fix.
    try checkNoMetadata(br.IncrementalStoredStreamEncoder, &.{
        "06",
        "50001041424344454603",
        "700010414243444546474803",
        "700010414243444546474828000841424344454603",
        "70001074696d652074696d380008652074696d652074100008696d6503",
    });
    try checkNoMetadata(br.IncrementalPlannedStreamEncoder, &.{
        "06",
        "50001041424344454603",
        "700010414243444546474803",
        "70001041424344454647482800001e02200889cb",
        "70001074696d652074696d3800001e02200c090a040002696d6503",
    });
    try checkNoMetadata(br.IncrementalStaticDictionaryStreamEncoder, &.{
        "06",
        "a200003cc0068ced6d40c01200e98e",
        "e200003c00038e313713b8040028a73b",
        "7000003c00038e313713b8040028a77b14008007d880b1bd0d08580220dd11",
        "7000003c545a5b150249e0c896e200007808ba120491b8e93f4300003c64595a5b60128006",
    });
}
