const std = @import("std");
const D = @import("../../deflate.zig");
const t = std.testing;
const allocator = t.allocator;

// The stored A, fixed-Huffman B, and stored empty fixtures also used by the
// incremental gzip padding tests. They exercise distinct one-shot paths.
const header = "\x1f\x8b\x08\x00\x00\x00\x00\x00\x00\xff";
const stored = header ++ "\x01\x01\x00\xfe\xffA\x8b\x9e\xd9\xd3\x01\x00\x00\x00";
const fixed = header ++ "\x73\x02\x00\x31\xcf\xd0\x4a\x01\x00\x00\x00";
const empty = header ++ "\x01\x00\x00\xff\xff\x00\x00\x00\x00\x00\x00\x00\x00";
const padding = "\x00" ** 17;
const padded: D.GzipDecodeOptions = .{ .allow_trailing_zero_padding = true };
const conflicting: D.GzipDecodeOptions = .{ .allow_trailing_zero_padding = true, .allow_trailing_data = true };

test "Gzip zero padding facades remain strict by default and validate members first" {
    const default_padding: bool = (D.GzipDecodeOptions{}).allow_trailing_zero_padding;
    try t.expect(!default_padding);

    var output: [2]u8 = undefined;
    try t.expectError(error.TrailingData, D.decodeGzip(stored ++ padding, &output));
    try t.expectError(error.BadGzipHeader, D.decodeGzipConcatenated(stored ++ fixed ++ padding, &output));

    try t.expectEqual(@as(usize, 1), try D.decodeGzipWithOptions(stored ++ padding, &output, padded));
    try t.expectEqualStrings("A", output[0..1]);
    try t.expectEqual(output.len, try D.decodeGzipConcatenatedWithOptions(stored ++ fixed ++ padding, &output, .{
        .allow_trailing_zero_padding = true,
        .max_members = 2,
    }));
    try t.expectEqualStrings("AB", &output);

    try t.expectError(error.TrailingData, D.decodeGzipWithOptions(stored ++ padding ++ "!", &output, padded));
    try t.expectError(error.TrailingData, D.decodeGzipWithOptions(stored ++ fixed, &output, padded));
    try t.expectError(error.TrailingData, D.decodeGzipConcatenatedWithOptions(stored ++ fixed ++ padding ++ "!", &output, padded));
    try t.expectError(error.TrailingData, D.decodeGzipConcatenatedWithOptions(stored ++ padding ++ fixed, &output, padded));
    try t.expectError(error.BadGzipHeader, D.decodeGzipWithOptions(padding, &output, padded));

    var corrupt = (stored ++ fixed ++ padding).*;
    corrupt[stored.len + fixed.len - 8] ^= 1;
    try t.expectError(error.ChecksumMismatch, D.decodeGzipConcatenatedWithOptions(&corrupt, &output, padded));
    var bad_size = (stored ++ padding ++ "!").*;
    bad_size[stored.len - 4] ^= 1;
    try t.expectError(error.SizeMismatch, D.decodeGzipAllocWithOptions(allocator, &bad_size, padded));
}

test "Gzip zero padding facades cover one-shot alloc, exact-size and append paths" {
    inline for (.{
        .{ .member = stored, .plain = "A", .concat = false },
        .{ .member = fixed, .plain = "B", .concat = false },
        .{ .member = stored ++ empty, .plain = "A", .concat = true },
        .{ .member = stored ++ fixed, .plain = "AB", .concat = true },
    }) |case| {
        const alloc = if (case.concat) D.decodeGzipConcatenatedAllocWithOptions else D.decodeGzipAllocWithOptions;
        const exact = if (case.concat) D.decodeGzipConcatenatedAllocWithOptionsExactSize else D.decodeGzipAllocWithOptionsExactSize;
        const append = if (case.concat) D.decodeGzipConcatenatedAppendWithOptions else D.decodeGzipAppendWithOptions;
        const append_exact = if (case.concat) D.decodeGzipConcatenatedAppendWithOptionsExactSize else D.decodeGzipAppendWithOptionsExactSize;
        const wire = case.member ++ padding;
        const bad = wire ++ "!\x00";

        const decoded = try alloc(allocator, wire, padded);
        defer allocator.free(decoded);
        try t.expectEqualStrings(case.plain, decoded);
        const exact_decoded = try exact(allocator, wire, padded, case.plain.len);
        defer allocator.free(exact_decoded);
        try t.expectEqualStrings(case.plain, exact_decoded);
        try t.expectError(error.TrailingData, alloc(allocator, bad, padded));
        try t.expectError(error.TrailingData, exact(allocator, bad, padded, case.plain.len));

        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(allocator);
        try out.appendSlice(allocator, "prefix:");
        try t.expectError(error.TrailingData, append(allocator, &out, bad, padded));
        try t.expectEqualStrings("prefix:", out.items);
        try t.expectError(error.TrailingData, append_exact(allocator, &out, bad, padded, case.plain.len));
        try t.expectEqualStrings("prefix:", out.items);
        try t.expectEqual(case.plain.len, try append(allocator, &out, wire, padded));
        try t.expectEqual(case.plain.len, try append_exact(allocator, &out, wire, padded, case.plain.len));
        try t.expectEqualStrings("prefix:" ++ case.plain ++ case.plain, out.items);
    }
}

test "Gzip zero padding facades respect output limits and stored preflight" {
    const decoded = try D.decodeGzipAllocWithOptionsLimited(allocator, fixed ++ "\x00", padded, 1);
    defer allocator.free(decoded);
    try t.expectEqualStrings("B", decoded);
    try t.expectError(error.OutputLimitExceeded, D.decodeGzipAllocWithOptionsLimited(allocator, fixed ++ "\x00", padded, 0));
    const no_output = try D.decodeGzipConcatenatedAllocWithOptionsLimited(allocator, empty ++ empty ++ padding, padded, 0);
    defer allocator.free(no_output);
    try t.expectEqual(@as(usize, 0), no_output.len);

    var failing = t.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    try t.expectError(error.OutputLimitExceeded, D.decodeGzipConcatenatedAllocWithOptionsLimited(failing.allocator(), stored ++ empty ++ padding, padded, 0));
    try t.expectError(error.TrailingData, D.decodeGzipConcatenatedAllocWithOptionsExactSize(failing.allocator(), stored ++ empty ++ padding ++ "!", padded, 1));
    try t.expect(!failing.has_induced_failure);
}

test "Gzip zero padding facades read direct chunks across footer and padding boundaries" {
    const wire = fixed ++ padding;
    var scratch: [1]u8 = undefined;
    var output: [1]u8 = undefined;
    for (fixed.len - 8..fixed.len + 3) |cut| {
        var chunks = [_][]const u8{ wire[0..cut], "", wire[cut .. fixed.len + 2], "", wire[fixed.len + 2 ..], "" };
        try t.expectError(error.TrailingData, D.decodeGzipChunksInto(&chunks, &output));
        try t.expectEqual(output.len, try D.decodeGzipChunksIntoWithOptions(&chunks, &output, padded));
        try t.expectEqualStrings("B", &output);

        var decoder = try D.GzipDecoder.initFromChunksWithOptionsExactSizeDirect(&chunks, &scratch, padded, output.len);
        const step = try decoder.step(&output);
        try t.expectEqual(.done, step.status);
        try t.expectEqual(wire.len, step.progress.input_read);
        try t.expectEqual(output.len, step.progress.output_written);
        try t.expectEqualStrings("B", &output);

        chunks[chunks.len - 1] = "!\x00";
        try t.expectError(error.TrailingData, D.decodeGzipChunksIntoWithOptions(&chunks, &output, padded));
    }
}

test "Gzip zero padding facades cover joined concatenated chunks and probe progress" {
    const members = stored ++ fixed;
    const wire = members ++ padding;
    var chunks = [_][]const u8{
        wire[0 .. stored.len - 3],
        wire[stored.len - 3 .. stored.len + 1],
        "",
        wire[stored.len + 1 .. members.len + 2],
        wire[members.len + 2 ..],
        "",
    };
    var compressed: [wire.len + 1]u8 = undefined;
    var output: [2]u8 = undefined;
    try t.expectError(error.BadGzipHeader, D.decodeGzipConcatenatedChunks(&chunks, &compressed, &output));
    try t.expectEqual(output.len, try D.decodeGzipConcatenatedChunksWithOptions(&chunks, &compressed, &output, padded));
    try t.expectEqualStrings("AB", &output);

    const decoded = try D.decodeGzipConcatenatedChunksAllocWithOptionsExactSize(allocator, &chunks, &compressed, padded, output.len);
    defer allocator.free(decoded);
    try t.expectEqualStrings("AB", decoded);

    const probe = D.probeGzipConcatenatedChunksWithOptionsExactSize(&chunks, &compressed, &output, padded, output.len);
    try t.expect(probe.ok);
    try t.expectEqual(@as(?usize, output.len), probe.decoded_bytes);
    try t.expectEqual(@as(?usize, 2), probe.member_count);
    try t.expectEqual(@as(?usize, wire.len), probe.stream_input_bytes);
    try t.expectEqual(@as(?usize, stored.len), probe.last_member_offset);

    chunks[chunks.len - 1] = "!";
    try t.expectError(error.TrailingData, D.decodeGzipConcatenatedChunksWithOptions(&chunks, &compressed, &output, padded));
    const bad_probe = D.probeGzipConcatenatedChunksWithOptions(&chunks, &compressed, &output, padded);
    try t.expect(!bad_probe.ok);
    try t.expectEqualStrings("TrailingData", bad_probe.error_name);
    try t.expectEqual(@as(?usize, null), bad_probe.member_index);
}

test "Gzip zero padding facades reject conflicting trailing policies" {
    var output: [1]u8 = undefined;
    try t.expectError(error.InvalidBlockPlan, D.decodeGzipWithOptions(stored, &output, conflicting));
    try t.expectError(error.InvalidBlockPlan, D.decodeGzipConcatenatedWithOptions(stored, &output, conflicting));
    try t.expectError(error.InvalidBlockPlan, D.decodeGzipAllocWithOptionsExactSize(allocator, stored, conflicting, output.len));
    try t.expectError(error.InvalidBlockPlan, D.decodeGzipChunksIntoWithOptions(&.{ stored[0..9], stored[9..] }, &output, conflicting));
    try t.expectError(error.InvalidBlockPlan, D.decodeZlibOrGzipPrefixWithOptions(stored, &output, .{ .gzip = conflicting }));
    try t.expectError(error.InvalidBlockPlan, D.decodeZlibOrGzipPrefixAllocWithOptions(allocator, stored, .{ .gzip = conflicting }));
}

test "Gzip zero padding facades keep autodetect prefix progress at the member end" {
    const options: D.ZlibOrGzipDecodeOptions = .{ .gzip = padded };
    var output: [1]u8 = undefined;
    try t.expectError(error.TrailingData, D.decodeZlibOrGzip(fixed ++ padding, &output));
    try t.expectEqual(output.len, try D.decodeZlibOrGzipWithOptions(fixed ++ padding, &output, options));
    try t.expectEqualStrings("B", &output);
    try t.expectError(error.TrailingData, D.decodeZlibOrGzipWithOptions(fixed ++ padding ++ "!", &output, options));

    for ([_][]const u8{ fixed ++ padding, fixed ++ padding ++ "!" }) |wire| {
        const prefix = try D.decodeZlibOrGzipPrefixWithOptions(wire, &output, options);
        try t.expectEqual(.gzip, prefix.format);
        try t.expectEqual(fixed.len, prefix.input_read);
        try t.expectEqual(output.len, prefix.output_written);
        try t.expectEqualStrings("B", &output);

        const owned = try D.decodeZlibOrGzipPrefixAllocWithOptions(allocator, wire, options);
        defer owned.deinit(allocator);
        try expectOwnedPrefix(owned);
        const exact = try D.decodeZlibOrGzipPrefixAllocWithOptionsExactSize(allocator, wire, options, output.len);
        defer exact.deinit(allocator);
        try expectOwnedPrefix(exact);
    }
}

fn expectOwnedPrefix(prefix: D.DecodedZlibOrGzip) !void {
    try t.expectEqual(.gzip, prefix.format);
    try t.expectEqual(fixed.len, prefix.input_read);
    try t.expectEqual(@as(usize, 1), prefix.output_written);
    try t.expectEqualStrings("B", prefix.bytes);
}
