const std = @import("std");
const h = @import("helpers.zig");
const decode_h = @import("../wide_decode/helpers.zig");

fn digest(encoder: anytype, comptime gzip: bool) u32 {
    return if (gzip) encoder.crc.digest() else encoder.adler.digest();
}

fn crossing(comptime D: type, comptime Encoder: type, comptime gzip: bool) !void {
    try h.commonTypes(Encoder);
    inline for (.{ "stream_input", "stream_output" }) |field|
        try std.testing.expectEqual(h.Count, @FieldType(Encoder, field));
    try std.testing.expectEqual(h.Count, @FieldType(Encoder, if (gzip) "member_count" else "stream_count"));
    inline for (if (gzip) .{ "member_input", "member_output", "member_count", "member_index", "params_change_count" } else .{ "stream_input", "stream_output", "stream_count", "stream_index", "params_change_count" }) |field|
        try std.testing.expectEqual(h.Count, @FieldType(Encoder.Snapshot, field));

    const options = Encoder.Options{ .raw = .{ .block_len = 64, .max_input_len = h.boundary + 64 } };
    const prefix_bytes = h.boundary - h.prefix.len;
    const blocks = prefix_bytes / h.prefix.len;
    const suffix = "wrapper-wide-tail-xxxxxxxx";
    var encoder = Encoder.initExactSize(h.allocator, options, prefix_bytes + suffix.len);
    defer encoder.deinit();
    var first_wire: std.ArrayList(u8) = .empty;
    defer first_wire.deinit(h.allocator);
    try h.fullPrefix(&encoder, &first_wire);
    const header_len = first_wire.items.len - try h.counts.toLocal(encoder.raw.total_output);
    const raw_prefix_len = encoder.raw.total_output;

    // Physically replay the same full-flush prefix and verify checksum math
    // and every byte of its raw wire before summarizing the large prefix.
    var small = Encoder.initWithOptions(h.allocator, options);
    defer small.deinit();
    var small_wire: std.ArrayList(u8) = .empty;
    defer small_wire.deinit(h.allocator);
    for (0..19) |n| {
        const start = small_wire.items.len;
        try h.fullPrefix(&small, &small_wire);
        try std.testing.expectEqualSlices(u8, first_wire.items[if (n == 0) 0 else header_len..], small_wire.items[start..]);
        const length: h.Count = (n + 1) * h.prefix.len;
        try std.testing.expectEqual(length, small.total_input);
        try std.testing.expectEqual(if (gzip) h.repeatedCrc('x', length) else h.repeatedAdler('x', length), digest(&small, gzip));
    }

    encoder.raw.total_input = prefix_bytes;
    encoder.raw.total_output = blocks * raw_prefix_len;
    encoder.total_input = prefix_bytes;
    encoder.stream_input = prefix_bytes;
    encoder.total_output = header_len + blocks * raw_prefix_len;
    encoder.stream_output = encoder.total_output;
    if (gzip) encoder.crc.value = ~h.repeatedCrc('x', prefix_bytes) else {
        const adler = h.repeatedAdler('x', prefix_bytes);
        encoder.adler = .{ .a = adler & 0xffff, .b = adler >> 16 };
    }
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(h.allocator);
    try h.feed(&encoder, suffix, &wire, 3, 1);
    encoder.partialFlush();
    try h.drain(&encoder, &wire, 3, false);
    try h.finish(&encoder, &wire, 2);
    const expected_digest = if (gzip)
        h.checksum.crc32Combine(h.repeatedCrc('x', prefix_bytes), h.checksum.Crc32.hash(suffix), suffix.len)
    else
        h.checksum.adler32Combine(h.repeatedAdler('x', prefix_bytes), h.checksum.Adler32.hash(suffix), suffix.len);
    try std.testing.expectEqual(expected_digest, digest(&encoder, gzip));
    const footer_len: usize = if (gzip) 8 else 4;
    const footer = wire.items[wire.items.len - footer_len ..];
    try std.testing.expectEqual(expected_digest, std.mem.readInt(u32, footer[0..4], if (gzip) .little else .big));
    if (gzip)
        try std.testing.expectEqual(@as(u32, @truncate(prefix_bytes + suffix.len)), std.mem.readInt(u32, footer[4..8], .little));

    const history = try h.allocator.alloc(u8, 32 * 1024);
    defer h.allocator.free(history);
    const Decoder = if (gzip) D.GzipIncrementalDecoder else D.ZlibIncrementalDecoder;
    var decoder = try Decoder.init(.{}, history);
    try decode_h.drain(&decoder, first_wire.items, h.prefix, first_wire.items.len, h.prefix.len);
    decoder.total_input = header_len + blocks * raw_prefix_len;
    decoder.total_output = prefix_bytes;
    decoder.raw.total_input = blocks * raw_prefix_len;
    decoder.raw.total_output = prefix_bytes;
    decoder.raw.history_len = history.len;
    decoder.raw.history_pos = h.counts.ringIndex(prefix_bytes, history.len);
    @memset(history, 'x');
    if (gzip) {
        decoder.member_output = prefix_bytes;
        decoder.crc.value = ~h.repeatedCrc('x', prefix_bytes);
    } else {
        decoder.stream_output = prefix_bytes;
        const adler = h.repeatedAdler('x', prefix_bytes);
        decoder.adler = .{ .a = adler & 0xffff, .b = adler >> 16 };
    }
    try decode_h.drain(&decoder, wire.items, suffix, 1, 2);
    try std.testing.expectEqual(prefix_bytes + suffix.len, decoder.total_output);

    const previous_input = encoder.stream_input;
    const previous_output = encoder.stream_output;
    if (gzip) try encoder.nextMemberExactSize(.{}, 3) else try encoder.nextStreamExactSize(options, "", 3);
    try std.testing.expectEqual(previous_input, encoder.stream_input);
    try std.testing.expectEqual(previous_output, encoder.stream_output);
    try std.testing.expectEqual(@as(h.Count, 0), encoder.total_input);
    wire.clearRetainingCapacity();
    try h.feed(&encoder, "new", &wire, 1, 1);
    try h.finish(&encoder, &wire, 1);
    try std.testing.expectEqual(previous_input + 3, encoder.stream_input);
    try std.testing.expectEqual(previous_output + wire.items.len, encoder.stream_output);
    try std.testing.expectEqual(@as(h.Count, 2), if (gzip) encoder.member_count else encoder.stream_count);
    var output: [3]u8 = undefined;
    const decoded = if (gzip) try D.decodeGzip(wire.items, &output) else try D.decodeZlib(wire.items, &output);
    try std.testing.expectEqual(@as(usize, 3), decoded);
    try std.testing.expectEqualSlices(u8, "new", &output);

    if (gzip) {
        try encoder.nextMemberExactSizeWithOptions(options, h.boundary + 32);
    } else {
        try encoder.nextStreamExactSize(options, "dictionary", h.boundary + 32);
        try std.testing.expectEqualSlices(u8, "dictionary", encoder.raw.dictionary);
    }
    try std.testing.expectEqual(@as(?h.Count, h.boundary + 32), encoder.raw.expected_input_len);
    encoder.reset();
    try std.testing.expectEqual(@as(h.Count, 0), encoder.stream_input);
    try std.testing.expectEqual(@as(h.Count, 0), encoder.stream_output);
    try std.testing.expectEqual(@as(?h.Count, h.boundary + 32), encoder.raw.expected_input_len);
}

pub fn contracts(comptime D: type) !void {
    inline for (.{ D.ZlibIncrementalFixedEncoder, D.ZlibIncrementalBestEncoder }) |Encoder|
        try crossing(D, Encoder, false);
    inline for (.{ D.GzipIncrementalFixedEncoder, D.GzipIncrementalBestEncoder }) |Encoder|
        try crossing(D, Encoder, true);
}
