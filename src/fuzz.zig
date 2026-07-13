const std = @import("std");
const store = @import("store.zig");
const deflate = @import("deflate.zig");
const bitstream = @import("bitstream.zig");
const huffman = @import("huffman.zig");

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

    return stats;
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

    const oversubscribed = try oversubscribedCodeLengthDynamicHeaderAlloc(allocator);
    defer allocator.free(oversubscribed);
    try expectMalformedDeflate(allocator, &stats, oversubscribed);

    const missing_eob = try missingEndOfBlockDynamicHeaderAlloc(allocator);
    defer allocator.free(missing_eob);
    try expectMalformedDeflate(allocator, &stats, missing_eob);

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

fn writeMinimalDynamicHeader(allocator: std.mem.Allocator, writer: *bitstream.BitWriter) !void {
    try writer.writeBits(allocator, 1, 1);
    try writer.writeBits(allocator, 0b10, 2);
    try writer.writeBits(allocator, 0, 5);
    try writer.writeBits(allocator, 0, 5);
    try writer.writeBits(allocator, 0, 4);
}

test "store smoke corpus covers malformed and valid frames" {
    const stats = try runStoreSmokeCorpus(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 11), stats.cases);
    try std.testing.expectEqual(@as(usize, 4), stats.valid_frames);
    try std.testing.expectEqual(@as(usize, 7), stats.expected_errors);
}

test "deflate smoke corpus covers valid and malformed raw streams" {
    const stats = try runDeflateSmokeCorpus(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 12), stats.cases);
    try std.testing.expectEqual(@as(usize, 3), stats.valid_frames);
    try std.testing.expectEqual(@as(usize, 9), stats.expected_errors);
}
