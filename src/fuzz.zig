const std = @import("std");
const store = @import("store.zig");
const deflate = @import("deflate.zig");
const dictionary = @import("dictionary.zig");
const bitstream = @import("bitstream.zig");
const huffman = @import("huffman.zig");
const lz77 = @import("lz77.zig");

pub const lzms_raw_fixture_base64 = @embedFile("lzms/testdata/lzms-small.bin.b64");
pub const lzms_raw_fixture_decoded_size = @embedFile("lzms/testdata/lzms-small.txt").len;
pub const wim_lzms_fixture_base64 = @embedFile("wim/testdata/lzms-small.esd.b64");
pub const microlzma_fixture_base64 = @embedFile("lzma/testdata/microlzma-small.bin.b64");
pub const microlzma_fixture_decoded_size = @embedFile("lzms/testdata/lzms-small.txt").len;

pub const CorpusStats = struct {
    cases: usize = 0,
    valid_frames: usize = 0,
    expected_errors: usize = 0,
};

/// Deterministic malformed-input smoke harness for early frame parsers.
/// This is intentionally small and fast enough to run in `zig build test` while
/// preserving concrete regression cases that future fuzzing can extend.
pub fn runStoreSmokeCorpus(allocator: std.mem.Allocator) !CorpusStats {
    var stats = CorpusStats{};

    const malformed = [_][]const u8{
        "",
        "V",
        "VOR",
        "VORT",
        "xxxx____________________________",
        "VORT\x01\x00\x00\x00________________________",
        "VORT\x00\x01\x00\x00________________________",
    };
    for (malformed) |case| {
        stats.cases += 1;
        if (store.parseHeader(case)) |_| {
            return error.UnexpectedValidFrame;
        } else |err| switch (err) {
            error.TruncatedFrame,
            error.InvalidMagic,
            error.UnsupportedVersion,
            error.CorruptFrame,
            => stats.expected_errors += 1,
            else => return err,
        }
    }

    const payloads = [_][]const u8{ "", "a", "aaaaabbbbbccccc", "0123456789" ** 8 };
    for (payloads) |payload| {
        stats.cases += 1;
        var encoded: [256]u8 = undefined;
        const encoded_len = try store.encode(payload, &encoded);
        const decoded = try store.decodeAlloc(allocator, encoded[0..encoded_len]);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, payload, decoded);
        stats.valid_frames += 1;
    }

    try runEmbeddedDictionarySmokeCorpus(allocator, &stats);
    try runConcatenatedDictionarySmokeCorpus(allocator, &stats);

    return stats;
}

fn runEmbeddedDictionarySmokeCorpus(allocator: std.mem.Allocator, stats: *CorpusStats) !void {
    const dict = "alpha beta gamma";
    const valid = try embeddedDictionarySkippableAlloc(allocator, dict);
    defer allocator.free(valid);
    try expectEmbeddedDictionaryView(allocator, stats, valid, dict);

    const plain = try store.encodeAlloc(allocator, "plain");
    defer allocator.free(plain);
    try expectMalformedEmbeddedDictionary(stats, plain, error.InvalidMagic);

    const payload = try embeddedDictionaryPayloadAlloc(allocator, dict);
    defer allocator.free(payload);

    const reserved_payload = try allocator.dupe(u8, payload);
    defer allocator.free(reserved_payload);
    reserved_payload[16] = 1;
    const reserved = try store.encodeSkippableAlloc(allocator, reserved_payload);
    defer allocator.free(reserved);
    try expectMalformedEmbeddedDictionary(stats, reserved, error.CorruptFrame);

    const bad_id_payload = try allocator.dupe(u8, payload);
    defer allocator.free(bad_id_payload);
    bad_id_payload[4] ^= 1;
    const bad_id = try store.encodeSkippableAlloc(allocator, bad_id_payload);
    defer allocator.free(bad_id);
    try expectMalformedEmbeddedDictionary(stats, bad_id, error.ChecksumMismatch);

    const bad_len_payload = try allocator.dupe(u8, payload);
    defer allocator.free(bad_len_payload);
    std.mem.writeInt(u32, bad_len_payload[12..16], @intCast(dict.len + 1), .little);
    const bad_len = try store.encodeSkippableAlloc(allocator, bad_len_payload);
    defer allocator.free(bad_len);
    try expectMalformedEmbeddedDictionary(stats, bad_len, error.TruncatedFrame);
}

fn embeddedDictionarySkippableAlloc(allocator: std.mem.Allocator, dict: []const u8) ![]u8 {
    const payload = try embeddedDictionaryPayloadAlloc(allocator, dict);
    defer allocator.free(payload);
    return store.encodeSkippableAlloc(allocator, payload);
}

fn embeddedDictionaryPayloadAlloc(allocator: std.mem.Allocator, dict: []const u8) ![]u8 {
    const header_len = 20;
    const out = try allocator.alloc(u8, header_len + dict.len);
    errdefer allocator.free(out);
    @memcpy(out[0..4], "VDIC");
    const id = dictionary.DictionaryId.fromBytes(dict);
    std.mem.writeInt(u64, out[4..12], id.asInt(), .little);
    std.mem.writeInt(u32, out[12..16], @intCast(dict.len), .little);
    std.mem.writeInt(u32, out[16..20], 0, .little);
    @memcpy(out[header_len..], dict);
    return out;
}

fn expectEmbeddedDictionaryView(allocator: std.mem.Allocator, stats: *CorpusStats, input: []const u8, expected_dict: []const u8) !void {
    stats.cases += 1;
    const view = try store.viewEmbeddedDictionary(input);
    try std.testing.expectEqualSlices(u8, expected_dict, view.bytes);
    const owned = try store.parseEmbeddedDictionaryAlloc(allocator, input);
    defer allocator.free(owned);
    try std.testing.expectEqualSlices(u8, expected_dict, owned);
    stats.valid_frames += 1;
}

fn expectMalformedEmbeddedDictionary(stats: *CorpusStats, input: []const u8, expected_error: anyerror) !void {
    stats.cases += 1;
    if (store.viewEmbeddedDictionary(input)) |_| {
        return error.UnexpectedValidFrame;
    } else |err| {
        if (err != expected_error) return err;
        stats.expected_errors += 1;
    }
}

fn runConcatenatedDictionarySmokeCorpus(allocator: std.mem.Allocator, stats: *CorpusStats) !void {
    const dict = "alpha beta gamma";
    const first = "zz alpha beta yy gamma";
    const second = "alpha beta";
    const expected = first ++ second;

    const dict_frame = try embeddedDictionarySkippableAlloc(allocator, dict);
    defer allocator.free(dict_frame);
    const first_frame = try store.encodeDictionaryPatchAlloc(allocator, dict, first, 5);
    defer allocator.free(first_frame);
    const second_frame = try store.encodeDictionaryDeflateAlloc(allocator, dict, second, 5);
    defer allocator.free(second_frame);

    var stream = std.ArrayList(u8).empty;
    defer stream.deinit(allocator);
    try stream.appendSlice(allocator, dict_frame);
    try stream.appendSlice(allocator, first_frame);
    try stream.appendSlice(allocator, second_frame);

    stats.cases += 1;
    var out: [expected.len]u8 = undefined;
    const result = try store.decodeConcatenatedAutoInto(allocator, stream.items, &out);
    try std.testing.expectEqual(expected.len, result.output_written);
    try std.testing.expectEqual(@as(usize, 2), result.frame_count);
    try std.testing.expectEqualSlices(u8, expected, &out);
    stats.valid_frames += 1;

    stats.cases += 1;
    if (store.decodeConcatenatedInto(allocator, stream.items, &out)) |_| {
        return error.UnexpectedValidFrame;
    } else |err| switch (err) {
        error.InvalidDictionaryTraining => stats.expected_errors += 1,
        else => return err,
    }

    stats.cases += 1;
    var short: [expected.len - 1]u8 = undefined;
    if (store.decodeConcatenatedAutoInto(allocator, stream.items, &short)) |_| {
        return error.UnexpectedValidFrame;
    } else |err| switch (err) {
        error.OutputTooSmall => stats.expected_errors += 1,
        else => return err,
    }
}

pub fn runDeflateSmokeCorpus(allocator: std.mem.Allocator) !CorpusStats {
    var stats = CorpusStats{};

    const stored = try deflate.encodeRawStoredAlloc(allocator, "stored");
    defer allocator.free(stored);
    try expectDeflateRoundTrip(allocator, &stats, stored, "stored");

    const fixed = try deflate.encodeRawFixedAlloc(allocator, "fixed fixed fixed");
    defer allocator.free(fixed);
    try expectDeflateRoundTrip(allocator, &stats, fixed, "fixed fixed fixed");

    const dynamic = try deflate.encodeRawDynamicLiteralAlloc(allocator, "dynamic");
    defer allocator.free(dynamic);
    try expectDeflateRoundTrip(allocator, &stats, dynamic, "dynamic");

    try expectMalformedDeflate(allocator, &stats, &.{ 0x00, 0x01, 0x00, 0xfe, 0xff, 'x' });
    try expectMalformedDeflate(allocator, &stats, &.{ 0x4a, 0x04, 0x00 });
    try expectMalformedDeflate(allocator, &stats, &.{ 0x4b, 0x04, 0x3e, 0x00 });
    try expectMalformedDeflate(allocator, &stats, &.{ 0x1b, 0x03 });
    try expectMalformedDeflate(allocator, &stats, &.{ 0xcb, 0x40, 0x27, 0x01 });

    const non_final_dynamic = try allocator.dupe(u8, dynamic);
    defer allocator.free(non_final_dynamic);
    non_final_dynamic[0] &= 0xfe;
    try expectMalformedDeflate(allocator, &stats, non_final_dynamic);

    const malformed_repeat = try malformedRepeat16DynamicHeaderAlloc(allocator);
    defer allocator.free(malformed_repeat);
    try expectMalformedDeflate(allocator, &stats, malformed_repeat);

    const repeat_overrun = try malformedRepeat18OverrunDynamicHeaderAlloc(allocator);
    defer allocator.free(repeat_overrun);
    try expectMalformedDeflate(allocator, &stats, repeat_overrun);

    const zero_repeat_overrun = try malformedRepeat17OverrunDynamicHeaderAlloc(allocator);
    defer allocator.free(zero_repeat_overrun);
    try expectMalformedDeflate(allocator, &stats, zero_repeat_overrun);

    const oversubscribed = try oversubscribedCodeLengthDynamicHeaderAlloc(allocator);
    defer allocator.free(oversubscribed);
    try expectMalformedDeflate(allocator, &stats, oversubscribed);

    const missing_eob = try missingEndOfBlockDynamicHeaderAlloc(allocator);
    defer allocator.free(missing_eob);
    try expectMalformedDeflate(allocator, &stats, missing_eob);

    const missing_distance = try malformedMissingDistanceDynamicAlloc(allocator);
    defer allocator.free(missing_distance);
    try expectMalformedDeflate(allocator, &stats, missing_distance);

    const dynamic_invalid_match = try malformedDynamicInvalidMatchAlloc(allocator);
    defer allocator.free(dynamic_invalid_match);
    try expectMalformedDeflate(allocator, &stats, dynamic_invalid_match);

    return stats;
}

fn expectDeflateRoundTrip(allocator: std.mem.Allocator, stats: *CorpusStats, encoded: []const u8, plain: []const u8) !void {
    stats.cases += 1;
    const decoded = try deflate.decodeRawAutoAlloc(allocator, encoded);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, plain, decoded);
    stats.valid_frames += 1;
}

fn expectMalformedDeflate(allocator: std.mem.Allocator, stats: *CorpusStats, encoded: []const u8) !void {
    stats.cases += 1;
    if (deflate.decodeRawAutoAlloc(allocator, encoded)) |decoded| {
        defer allocator.free(decoded);
        return error.UnexpectedValidFrame;
    } else |err| switch (err) {
        error.TruncatedFrame,
        error.InvalidDynamicBlockHeader,
        error.InvalidHuffmanCode,
        error.InvalidMatch,
        => stats.expected_errors += 1,
        else => return err,
    }
}

fn malformedRepeat16DynamicHeaderAlloc(allocator: std.mem.Allocator) ![]u8 {
    var lengths: [19]u4 = @splat(0);
    lengths[0] = 1;
    lengths[16] = 1;
    const encoder = try huffman.CodeLengthTable.Encoder.init(&lengths);
    var writer = bitstream.BitWriter{};
    errdefer writer.deinit(allocator);
    try writeMinimalDynamicHeader(allocator, &writer);
    try writer.writeBits(allocator, 1, 3);
    try writer.writeBits(allocator, 0, 3);
    try writer.writeBits(allocator, 0, 3);
    try writer.writeBits(allocator, 1, 3);
    try encoder.writeSymbol(&writer, allocator, 16);
    return writer.toOwnedSlice(allocator);
}

fn malformedRepeat18OverrunDynamicHeaderAlloc(allocator: std.mem.Allocator) ![]u8 {
    var lengths: [19]u4 = @splat(0);
    lengths[18] = 1;
    const encoder = try huffman.CodeLengthTable.Encoder.init(&lengths);

    var writer = bitstream.BitWriter{};
    errdefer writer.deinit(allocator);
    try writeMinimalDynamicHeader(allocator, &writer);
    try writer.writeBits(allocator, 0, 3);
    try writer.writeBits(allocator, 0, 3);
    try writer.writeBits(allocator, 1, 3);
    try writer.writeBits(allocator, 0, 3);
    try encoder.writeSymbol(&writer, allocator, 18);
    try writer.writeBits(allocator, 127, 7);
    try encoder.writeSymbol(&writer, allocator, 18);
    try writer.writeBits(allocator, 127, 7);
    return writer.toOwnedSlice(allocator);
}

fn malformedRepeat17OverrunDynamicHeaderAlloc(allocator: std.mem.Allocator) ![]u8 {
    var lengths: [19]u4 = @splat(0);
    lengths[17] = 1;
    const encoder = try huffman.CodeLengthTable.Encoder.init(&lengths);

    var writer = bitstream.BitWriter{};
    errdefer writer.deinit(allocator);
    try writeMinimalDynamicHeader(allocator, &writer);
    try writer.writeBits(allocator, 0, 3);
    try writer.writeBits(allocator, 1, 3);
    try writer.writeBits(allocator, 0, 3);
    try writer.writeBits(allocator, 0, 3);
    // Repeat-17 can encode only 3..10 zeros at a time. Fill the expected
    // HLIT+HDIST length vector exactly with 86 three-zero repeats, then emit
    // one more repeat so parseDynamicLengthsBody must reject the overrun.
    var repeats: usize = 0;
    while (repeats < 87) : (repeats += 1) {
        try encoder.writeSymbol(&writer, allocator, 17);
        try writer.writeBits(allocator, 0, 3);
    }
    return writer.toOwnedSlice(allocator);
}

fn oversubscribedCodeLengthDynamicHeaderAlloc(allocator: std.mem.Allocator) ![]u8 {
    var writer = bitstream.BitWriter{};
    errdefer writer.deinit(allocator);
    try writeMinimalDynamicHeader(allocator, &writer);
    try writer.writeBits(allocator, 1, 3);
    try writer.writeBits(allocator, 1, 3);
    try writer.writeBits(allocator, 1, 3);
    try writer.writeBits(allocator, 0, 3);
    return writer.toOwnedSlice(allocator);
}

fn missingEndOfBlockDynamicHeaderAlloc(allocator: std.mem.Allocator) ![]u8 {
    var code_len_lengths: [19]u4 = @splat(0);
    code_len_lengths[0] = 1;
    code_len_lengths[1] = 1;
    const code_len_encoder = try huffman.CodeLengthTable.Encoder.init(&code_len_lengths);

    var writer = bitstream.BitWriter{};
    errdefer writer.deinit(allocator);
    try writer.writeBits(allocator, 1, 1);
    try writer.writeBits(allocator, 0b10, 2);
    try writer.writeBits(allocator, 0, 5);
    try writer.writeBits(allocator, 0, 5);
    try writer.writeBits(allocator, 14, 4);
    for (huffman.code_length_order[0..18]) |symbol| {
        try writer.writeBits(allocator, code_len_lengths[symbol], 3);
    }
    for (0..257) |symbol| {
        try code_len_encoder.writeSymbol(&writer, allocator, if (symbol == 'a') 1 else 0);
    }
    try code_len_encoder.writeSymbol(&writer, allocator, 0);
    return writer.toOwnedSlice(allocator);
}

fn malformedMissingDistanceDynamicAlloc(allocator: std.mem.Allocator) ![]u8 {
    var lit_lengths: [258]u4 = @splat(0);
    lit_lengths['a'] = 2;
    lit_lengths[256] = 2;
    lit_lengths[257] = 2;
    var code_len_lengths: [19]u4 = @splat(0);
    code_len_lengths[0] = 1;
    code_len_lengths[2] = 1;
    const code_len_encoder = try huffman.CodeLengthTable.Encoder.init(&code_len_lengths);
    const lit_encoder = try huffman.HuffmanTable(258).Encoder.init(&lit_lengths);

    var writer = bitstream.BitWriter{};
    errdefer writer.deinit(allocator);
    try writer.writeBits(allocator, 1, 1);
    try writer.writeBits(allocator, 0b10, 2);
    try writer.writeBits(allocator, 1, 5);
    try writer.writeBits(allocator, 0, 5);
    try writer.writeBits(allocator, 12, 4);
    for (huffman.code_length_order[0..16]) |symbol| {
        try writer.writeBits(allocator, code_len_lengths[symbol], 3);
    }
    for (&lit_lengths) |len| try code_len_encoder.writeSymbol(&writer, allocator, len);
    try code_len_encoder.writeSymbol(&writer, allocator, 0);
    try lit_encoder.writeSymbol(&writer, allocator, 'a');
    try lit_encoder.writeSymbol(&writer, allocator, 257);
    // Ensure the empty distance alphabet fails as InvalidHuffmanCode rather
    // than ending prematurely with TruncatedFrame.
    try writer.writeBits(allocator, 0, 15);
    return writer.toOwnedSlice(allocator);
}

fn malformedDynamicInvalidMatchAlloc(allocator: std.mem.Allocator) ![]u8 {
    const tokens = [_]lz77.Token{
        .{ .match = .{ .length = 3, .distance = 1 } },
    };
    return deflate.encodeRawDynamicTokensAlloc(allocator, &tokens);
}

fn writeMinimalDynamicHeader(allocator: std.mem.Allocator, writer: *bitstream.BitWriter) !void {
    try writer.writeBits(allocator, 1, 1);
    try writer.writeBits(allocator, 0b10, 2);
    try writer.writeBits(allocator, 0, 5);
    try writer.writeBits(allocator, 0, 5);
    try writer.writeBits(allocator, 0, 4);
}

test "store smoke corpus covers malformed and valid frames" {
    const stats = try runStoreSmokeCorpus(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 19), stats.cases);
    try std.testing.expectEqual(@as(usize, 6), stats.valid_frames);
    try std.testing.expectEqual(@as(usize, 13), stats.expected_errors);
}

test "deflate smoke corpus covers valid and malformed raw streams" {
    const stats = try runDeflateSmokeCorpus(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 16), stats.cases);
    try std.testing.expectEqual(@as(usize, 3), stats.valid_frames);
    try std.testing.expectEqual(@as(usize, 13), stats.expected_errors);
}
