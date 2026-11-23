const std = @import("std");
const core = @import("../../core.zig");
const t = std.testing;
const allocator = t.allocator;
const sentinel: u8 = 0xa5;

// RFC 1952 rich member from incremental/decoder/gzip_header_event_tests.zig.
// The three metadata lengths are 6, 6 (with NUL), and 3 (with NUL).
const rich_header = "\x1f\x8b\x08\x1f\x04\x03\x02\x01\x02\x03" ++
    "\x06\x00VX\x02\x00\x00\xff" ++ "a.txt\x00hi\x00\xc3\xc9";
const rich = rich_header ++ "\x73\x04\x00\x8b\x9e\xd9\xd3\x01\x00\x00\x00"; // A
const magic_method = "\x1f\x8b\x08";
const fixed_suffix = "\x00\x00\x00\x00\x00\xff";
const plain_header = magic_method ++ "\x00" ++ fixed_suffix;
const extra_header = magic_method ++ "\x06" ++ fixed_suffix;
const name_header = magic_method ++ "\x08" ++ fixed_suffix;
const comment_header = magic_method ++ "\x10" ++ fixed_suffix;
const b_body = "\x73\x02\x00\x31\xcf\xd0\x4a\x01\x00\x00\x00";
const plain = plain_header ++ b_body; // B
const zlib_a = "\x78\x9c\x73\x04\x00\x00\x42\x00\x42";

pub fn contracts(comptime D: type) !void {
    try fieldBoundaries(D);
    try largeHeaderDefault(D);
    try singleRoutes(D);
    try incrementalProgress(D);
    try autoWrapper(D);
    try concatenated(D);
}

fn byteChunks(bytes: []const u8, scratch: [][]const u8) []const []const u8 {
    scratch[0] = "";
    for (bytes, 0..) |_, i| {
        scratch[2 * i + 1] = bytes[i..][0..1];
        scratch[2 * i + 2] = "";
    }
    return scratch[0 .. 2 * bytes.len + 1];
}

fn fieldBoundaries(comptime D: type) !void {
    var bad_crc = rich.*;
    bad_crc[rich_header.len - 1] ^= 1;
    var bad_fixed = rich.*;
    bad_fixed[3] |= 0x20;
    const empty_extra_with_crc = extra_header ++ "\x00\x00\xaa\x0b" ++ b_body;
    const cases = [_]struct { wire: []const u8, cap: usize, result: D.Error!u8 }{
        .{ .wire = rich, .cap = 6, .result = 'A' },
        .{ .wire = rich, .cap = 5, .result = error.OutputLimitExceeded },
        .{ .wire = plain, .cap = 0, .result = 'B' },
        .{ .wire = empty_extra_with_crc, .cap = 0, .result = 'B' },
        .{ .wire = name_header ++ "\x00" ++ b_body, .cap = 0, .result = error.OutputLimitExceeded },
        .{ .wire = comment_header ++ "\x00" ++ b_body, .cap = 0, .result = error.OutputLimitExceeded },
        .{ .wire = name_header ++ "\x00" ++ b_body, .cap = 1, .result = 'B' },
        .{ .wire = comment_header ++ "\x00" ++ b_body, .cap = 1, .result = 'B' },
        // A complete XLEN is decisive even if the body has not arrived.
        .{ .wire = rich[0..11], .cap = 5, .result = error.TruncatedFrame },
        .{ .wire = rich[0..12], .cap = 5, .result = error.OutputLimitExceeded },
        .{ .wire = rich[0..17], .cap = 6, .result = error.TruncatedFrame },
        .{ .wire = name_header ++ "a.txt\x00" ++ b_body, .cap = 5, .result = error.OutputLimitExceeded },
        .{ .wire = comment_header ++ "hi\x00" ++ b_body, .cap = 2, .result = error.OutputLimitExceeded },
        .{ .wire = comment_header ++ "hi\x00" ++ b_body, .cap = 3, .result = 'B' },
        // At EOF, having spent the cap is not by itself a limit violation.
        .{ .wire = name_header ++ "a.txt", .cap = 5, .result = error.TruncatedFrame },
        .{ .wire = name_header ++ "a.txt!", .cap = 5, .result = error.OutputLimitExceeded },
        .{ .wire = comment_header ++ "hi", .cap = 2, .result = error.TruncatedFrame },
        .{ .wire = comment_header ++ "hi!", .cap = 2, .result = error.OutputLimitExceeded },
        .{ .wire = bad_fixed[0..9], .cap = 0, .result = error.TruncatedFrame },
        .{ .wire = &bad_fixed, .cap = 0, .result = error.BadGzipHeader },
        .{ .wire = rich[0 .. rich_header.len - 1], .cap = 6, .result = error.TruncatedFrame },
        .{ .wire = &bad_crc, .cap = 6, .result = error.BadGzipHeader },
    };
    const Route = enum { contiguous, direct, coalesced };
    for (cases) |case| {
        var chunk_scratch: [2 * rich.len + 1][]const u8 = undefined;
        const chunks = byteChunks(case.wire, &chunk_scratch);
        var compressed_scratch: [rich.len]u8 = undefined;
        // Payload CRC relaxation must not relax FHCRC validation.
        const options: D.GzipDecodeOptions = .{ .max_header_metadata_len = case.cap, .ignore_crc32 = true };
        for ([_]Route{ .contiguous, .direct, .coalesced }) |route| {
            var output = [_]u8{sentinel};
            const result = switch (route) {
                .contiguous => D.decodeGzipWithOptions(case.wire, &output, options),
                .direct => D.decodeGzipChunksIntoWithOptions(chunks, &output, options),
                .coalesced => D.decodeGzipChunksWithOptions(chunks, &compressed_scratch, &output, options),
            };
            if (case.result) |byte| {
                try t.expectEqual(@as(usize, 1), try result);
                try t.expectEqual(byte, output[0]);
            } else |err| {
                try t.expectError(err, result);
                try t.expectEqual(sentinel, output[0]);
            }
        }
    }
}

fn largeHeaderDefault(comptime D: type) !void {
    const filename_len = (1 << 20) + 1;
    const terminator = name_header.len + filename_len;
    const wire = try allocator.alloc(u8, terminator + 1 + b_body.len);
    defer allocator.free(wire);
    @memcpy(wire[0..name_header.len], name_header);
    @memset(wire[name_header.len..terminator], 'x');
    wire[terminator] = 0;
    @memcpy(wire[terminator + 1 ..], b_body);

    var output = [_]u8{sentinel};
    try t.expectEqual(@as(usize, 1), try D.decodeGzipWithOptions(wire, &output, .{}));
    try t.expectEqualStrings("B", &output);
    output[0] = sentinel;
    const chunks: []const []const u8 = &.{ wire[0..terminator], wire[terminator..] };
    try t.expectError(error.OutputLimitExceeded, D.decodeGzipChunksIntoWithOptions(chunks, &output, .{ .max_header_metadata_len = filename_len }));
    try t.expectEqual(sentinel, output[0]);
    try t.expectEqual(@as(usize, 1), try D.decodeGzipChunksIntoWithOptions(chunks, &output, .{ .max_header_metadata_len = filename_len + 1 }));
    try t.expectEqualStrings("B", &output);
}

fn expectProbeLimit(probe: anytype) !void {
    try t.expect(!probe.ok);
    try t.expectEqualStrings("OutputLimitExceeded", probe.error_name);
}

fn singleRoutes(comptime D: type) !void {
    const rejected: D.GzipDecodeOptions = .{ .max_header_metadata_len = 5 };
    const admitted: D.GzipDecodeOptions = .{ .max_header_metadata_len = 6 };
    var chunk_scratch: [2 * rich.len + 1][]const u8 = undefined;
    const chunks = byteChunks(rich, &chunk_scratch);
    var compressed_scratch: [rich.len]u8 = undefined;
    var output = [_]u8{sentinel};

    try t.expectEqual(std.math.maxInt(usize), (D.GzipDecodeOptions{}).max_header_metadata_len);
    try t.expectEqual(@as(usize, 1), try D.decodeGzip(rich, &output));
    try t.expectEqualStrings("A", &output);
    output[0] = sentinel;
    try t.expectError(error.OutputLimitExceeded, D.decodedGzipSizeWithOptions(rich, &output, rejected));
    try t.expectError(error.OutputLimitExceeded, D.decodedGzipChunksSizeWithOptions(chunks, &compressed_scratch, &output, rejected));
    try expectProbeLimit(D.probeGzipWithOptions(rich, &output, rejected));
    try expectProbeLimit(D.probeGzipWithOptionsExactSize(rich, &output, rejected, 1));
    try expectProbeLimit(D.probeGzipChunksWithOptions(chunks, &compressed_scratch, &output, rejected));
    try expectProbeLimit(D.probeGzipChunksWithOptionsExactSize(chunks, &compressed_scratch, &output, rejected, 1));
    try t.expectError(error.OutputLimitExceeded, D.GzipDecoder.initFromChunksWithOptionsExactSizeDirect(chunks, &output, rejected, 1));
    try t.expectEqual(sentinel, output[0]);
    try t.expectEqual(@as(usize, 1), try D.decodedGzipChunksSizeWithOptions(chunks, &compressed_scratch, &output, admitted));

    // The single-member APIs already parse the header before allocating output.
    var denied = t.FailingAllocator.init(allocator, .{ .fail_index = 0, .resize_fail_index = 0 });
    const no_alloc = denied.allocator();
    try t.expectError(error.OutputLimitExceeded, D.decodeGzipAllocWithOptions(no_alloc, rich, rejected));
    try t.expectError(error.OutputLimitExceeded, D.decodeGzipAllocWithOptionsLimited(no_alloc, rich, rejected, 1));
    try t.expectError(error.OutputLimitExceeded, D.decodeGzipAllocWithOptionsExactSize(no_alloc, rich, rejected, 1));
    try t.expectError(error.OutputLimitExceeded, D.decodeGzipChunksAllocWithOptions(no_alloc, chunks, &compressed_scratch, rejected));
    try t.expectError(error.OutputLimitExceeded, D.decodeGzipChunksAllocWithOptionsLimited(no_alloc, chunks, &compressed_scratch, rejected, 1));
    try t.expectError(error.OutputLimitExceeded, D.decodeGzipChunksAllocWithOptionsExactSize(no_alloc, chunks, &compressed_scratch, rejected, 1));
    const owned = try D.decodeGzipAllocWithOptionsExactSize(allocator, rich, admitted, 1);
    defer allocator.free(owned);
    try t.expectEqualStrings("A", owned);

    try t.expect(!denied.has_induced_failure);
    var append_denied = t.FailingAllocator.init(allocator, .{ .fail_index = 1, .resize_fail_index = 0 });
    const append_allocator = append_denied.allocator();
    var out = try std.ArrayList(u8).initCapacity(append_allocator, 2);
    defer out.deinit(append_allocator);
    out.appendAssumeCapacity('p');
    out.allocatedSlice()[1] = sentinel;
    try t.expectError(error.OutputLimitExceeded, D.decodeGzipAppendWithOptions(append_allocator, &out, rich, rejected));
    try t.expectError(error.OutputLimitExceeded, D.decodeGzipAppendWithOptionsLimited(append_allocator, &out, rich, rejected, 1));
    try t.expectError(error.OutputLimitExceeded, D.decodeGzipAppendWithOptionsExactSize(append_allocator, &out, rich, rejected, 1));
    try t.expectError(error.OutputLimitExceeded, D.decodeGzipChunksAppendWithOptions(append_allocator, &out, chunks, &compressed_scratch, rejected));
    try t.expectError(error.OutputLimitExceeded, D.decodeGzipChunksAppendWithOptionsLimited(append_allocator, &out, chunks, &compressed_scratch, rejected, 1));
    try t.expectError(error.OutputLimitExceeded, D.decodeGzipChunksAppendWithOptionsExactSize(append_allocator, &out, chunks, &compressed_scratch, rejected, 1));
    try t.expectEqualStrings("p", out.items);
    try t.expectEqual(sentinel, out.allocatedSlice()[1]);
    try t.expect(!append_denied.has_induced_failure);
}

fn incrementalProgress(comptime D: type) !void {
    const Decoder = D.GzipIncrementalDecoder;
    const Count = core.StreamCount;
    var history: [32 * 1024]u8 = undefined;
    var output = [_]u8{sentinel};
    var decoder = try Decoder.init(.{ .max_header_metadata_len = 6 }, &history);
    for (0..rich_header.len) |i| {
        const step = try decoder.step(rich[i..][0..1], &output);
        try t.expectEqual(.need_input, step.status);
        try t.expectEqual(core.Progress{ .input_read = 1 }, step.progress);
        const snap = decoder.snapshot();
        try t.expectEqual(@as(Count, i + 1), snap.total_input);
        try t.expectEqual(@as(Count, 0), snap.total_output);
        if (i + 2 == rich_header.len) try t.expectEqual(Decoder.Phase.header_crc, snap.phase);
        if (i + 1 == rich_header.len) try t.expectEqual(Decoder.Phase.raw, snap.phase);
        try t.expectEqual(sentinel, output[0]);
    }
    const done = try decoder.step(rich[rich_header.len..], &output);
    try t.expectEqual(.done, done.status);
    try t.expectEqual(core.Progress{ .input_read = rich.len - rich_header.len, .output_written = 1 }, done.progress);
    try decoder.finish();
    try t.expectEqualStrings("A", &output);

    const cases = [_]struct { wire: []const u8, cap: usize, cutoff: usize, phase: Decoder.Phase }{
        .{ .wire = rich, .cap = 5, .cutoff = 12, .phase = .extra_len },
        .{ .wire = name_header ++ "a.txt\x00" ++ b_body, .cap = 5, .cutoff = 16, .phase = .filename },
        .{ .wire = comment_header ++ "hi!\x00" ++ b_body, .cap = 2, .cutoff = 13, .phase = .comment },
    };
    for (cases) |case| {
        decoder = try Decoder.init(.{ .max_header_metadata_len = case.cap }, &history);
        output[0] = sentinel;
        const before = case.cutoff - 1;
        for (0..before) |i| {
            const step = try decoder.step(case.wire[i..][0..1], &output);
            try t.expectEqual(.need_input, step.status);
            try t.expectEqual(core.Progress{ .input_read = 1 }, step.progress);
        }
        try t.expectEqual(case.phase, decoder.snapshot().phase);
        try t.expectEqual(@as(Count, before), decoder.snapshot().total_input);
        try t.expectEqual(@as(Count, 0), decoder.snapshot().total_output);
        // Include the payload on the failing call: it must not be read or written.
        try t.expectError(error.OutputLimitExceeded, decoder.step(case.wire[before..], &output));
        const failed = decoder.snapshot();
        try t.expectEqual(@as(Count, case.cutoff), failed.total_input);
        try t.expectEqual(@as(Count, 0), failed.total_output);
        try t.expectEqual(@as(?Count, case.cutoff), failed.last_error_input_offset);
        try t.expectEqual(@as(?Decoder.Phase, case.phase), failed.last_error_phase);
        try t.expectEqual(core.Progress{ .input_read = 1 }, failed.last_step_progress);
        try t.expectEqual(sentinel, output[0]);

        decoder.reset();
        const truncated = try decoder.step(case.wire[0..before], &output);
        try t.expectEqual(.need_input, truncated.status);
        try t.expectEqual(core.Progress{ .input_read = before }, truncated.progress);
        try t.expectError(error.TruncatedFrame, decoder.finish());
        try t.expectEqual(sentinel, output[0]);
    }
}

fn autoWrapper(comptime D: type) !void {
    const rejected: D.ZlibOrGzipDecodeOptions = .{ .gzip = .{ .max_header_metadata_len = 0 } };
    const admitted: D.ZlibOrGzipDecodeOptions = .{ .gzip = .{ .max_header_metadata_len = 6 } };
    var output = [_]u8{sentinel};
    try t.expectError(error.OutputLimitExceeded, D.decodeZlibOrGzipWithOptions(rich, &output, rejected));
    try t.expectError(error.OutputLimitExceeded, D.decodeZlibOrGzipPrefixWithOptions(rich ++ "tail", &output, rejected));
    try t.expectEqual(sentinel, output[0]);

    var denied = t.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    try t.expectError(error.OutputLimitExceeded, D.decodeZlibOrGzipAllocWithOptions(denied.allocator(), rich, rejected));
    try t.expectError(error.OutputLimitExceeded, D.decodeZlibOrGzipPrefixAllocWithOptionsLimited(denied.allocator(), rich ++ "tail", rejected, 1));
    try t.expectError(error.OutputLimitExceeded, D.decodeZlibOrGzipPrefixAllocWithOptionsExactSize(denied.allocator(), rich ++ "tail", rejected, 1));
    try t.expect(!denied.has_induced_failure);
    const prefix = try D.decodeZlibOrGzipPrefixAllocWithOptions(allocator, rich ++ "tail", admitted);
    defer prefix.deinit(allocator);
    try t.expectEqual(.gzip, prefix.format);
    try t.expectEqual(rich.len, prefix.input_read);
    try t.expectEqualStrings("A", prefix.bytes);

    const zlib = try D.decodeZlibOrGzipPrefixWithOptions(zlib_a ++ "tail", &output, rejected);
    try t.expectEqual(.zlib, zlib.format);
    try t.expectEqual(zlib_a.len, zlib.input_read);
    try t.expectEqual(@as(usize, 1), zlib.output_written);
    try t.expectEqualStrings("A", &output);

    var history: [65_536]u8 = undefined;
    var decoder = try D.ZlibOrGzipIncrementalDecoder.init(.{ .max_gzip_header_metadata_len = 0 }, &history);
    output[0] = sentinel;
    const first = try decoder.step(rich[0..1], &output);
    try t.expectEqual(.need_input, first.status);
    try t.expectError(error.OutputLimitExceeded, decoder.step(rich[1..], &output));
    const failed = decoder.snapshot();
    try t.expectEqual(@as(?D.ZlibOrGzipFormat, .gzip), failed.format);
    try t.expectEqual(@as(core.StreamCount, 12), failed.total_input);
    try t.expectEqual(@as(core.StreamCount, 0), failed.total_output);
    try t.expectEqual(sentinel, output[0]);
    decoder.reset();
    try t.expectEqual(.done, (try decoder.step(zlib_a, &output)).status);
    try decoder.finish();
    try t.expectEqual(@as(?D.ZlibOrGzipFormat, .zlib), decoder.selectedFormat());
    try t.expectEqualStrings("A", &output);
}

fn expectNoRefusedMember(output: []const u8) !void {
    // Legacy concatenated routes may publish the first member before refusing
    // the second. They must never publish the refused member (A).
    try t.expect(output[0] == 'B' or output[0] == sentinel);
    try t.expectEqual(sentinel, output[1]);
}

fn concatenated(comptime D: type) !void {
    const wire = plain ++ rich;
    const tail = "\x1fnot-a-member";
    const rejected: D.GzipDecodeOptions = .{ .max_header_metadata_len = 5, .allow_trailing_data = true };
    const admitted: D.GzipDecodeOptions = .{ .max_header_metadata_len = 6, .allow_trailing_data = true };
    var chunk_scratch: [2 * wire.len + 1][]const u8 = undefined;
    const chunks = byteChunks(wire, &chunk_scratch);
    var compressed_scratch: [wire.len]u8 = undefined;
    var output: [2]u8 = @splat(sentinel);

    // Same suffix is ignored in single-member mode, but not once full gzip
    // magic commits a second member in concatenated mode.
    try t.expectEqual(@as(usize, 1), try D.decodeGzipWithOptions(wire, &output, rejected));
    try t.expectEqualSlices(u8, &.{ 'B', sentinel }, &output);
    try t.expectError(error.TrailingData, D.decodeGzipWithOptions(wire, &output, .{ .max_header_metadata_len = 5 }));
    try t.expectEqual(@as(usize, 1), try D.decodeGzipConcatenatedWithOptions(plain ++ tail, &output, rejected));
    try t.expectError(error.BadGzipHeader, D.decodeGzipConcatenatedWithOptions(plain ++ tail, &output, .{ .max_header_metadata_len = 5 }));
    try t.expectError(error.TruncatedFrame, D.decodeGzipConcatenatedWithOptions(plain ++ "\x1f\x8b", &output, rejected));
    try t.expectEqual(@as(usize, 2), try D.decodeGzipConcatenatedWithOptions(wire ++ tail, &output, admitted));
    try t.expectEqualStrings("BA", &output);
    try t.expectEqual(@as(usize, 2), try D.decodeGzipConcatenatedChunksWithOptions(chunks, &compressed_scratch, &output, admitted));
    try t.expectEqualStrings("BA", &output);

    output = @splat(sentinel);
    try t.expectError(error.OutputLimitExceeded, D.decodeGzipConcatenatedWithOptions(wire, &output, rejected));
    try expectNoRefusedMember(&output);
    output = @splat(sentinel);
    try t.expectError(error.OutputLimitExceeded, D.decodeGzipConcatenatedChunksWithOptions(chunks, &compressed_scratch, &output, rejected));
    try expectNoRefusedMember(&output);
    output = @splat(sentinel);
    try t.expectError(error.OutputLimitExceeded, D.decodedGzipConcatenatedSizeWithOptions(wire, &output, rejected));
    try expectNoRefusedMember(&output);
    output = @splat(sentinel);
    try t.expectError(error.OutputLimitExceeded, D.decodedGzipConcatenatedChunksSizeWithOptions(chunks, &compressed_scratch, &output, rejected));
    try expectNoRefusedMember(&output);

    // Probe diagnostics must also honor the cap when locating the failure.
    output = @splat(sentinel);
    const probe = D.probeGzipConcatenatedWithOptions(wire, &output, rejected);
    try expectProbeLimit(probe);
    try t.expectEqual(@as(?usize, 1), probe.member_index);
    try t.expectEqual(@as(?usize, plain.len), probe.member_offset);
    try expectNoRefusedMember(&output);
    output = @splat(sentinel);
    const chunk_probe = D.probeGzipConcatenatedChunksWithOptionsExactSize(chunks, &compressed_scratch, &output, rejected, 2);
    try expectProbeLimit(chunk_probe);
    try t.expectEqual(@as(?usize, 1), chunk_probe.member_index);
    try t.expectEqual(@as(?usize, plain.len), chunk_probe.member_offset);
    try expectNoRefusedMember(&output);

    try t.expectError(error.OutputLimitExceeded, D.decodeGzipConcatenatedAllocWithOptions(allocator, wire, rejected));
    try t.expectError(error.OutputLimitExceeded, D.decodeGzipConcatenatedAllocWithOptionsExactSize(allocator, wire, rejected, 2));
    try t.expectError(error.OutputLimitExceeded, D.decodeGzipConcatenatedChunksAllocWithOptionsLimited(allocator, chunks, &compressed_scratch, rejected, 2));
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try out.appendSlice(allocator, "prefix");
    try t.expectError(error.OutputLimitExceeded, D.decodeGzipConcatenatedAppendWithOptionsLimited(allocator, &out, wire, rejected, 2));
    try t.expectEqualStrings("prefix", out.items);
    try t.expectError(error.OutputLimitExceeded, D.decodeGzipConcatenatedChunksAppendWithOptions(allocator, &out, chunks, &compressed_scratch, rejected));
    try t.expectEqualStrings("prefix", out.items);
    try t.expectError(error.OutputLimitExceeded, D.decodeGzipConcatenatedChunksAppendWithOptionsExactSize(allocator, &out, chunks, &compressed_scratch, rejected, 2));
    try t.expectEqualStrings("prefix", out.items);
}
