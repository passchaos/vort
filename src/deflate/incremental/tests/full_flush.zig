const std = @import("std");
const deflate = @import("../../../deflate.zig");

fn feed(encoder: anytype, input: []const u8, encoded: *std.ArrayList(u8), scratch: []u8) !void {
    var offset: usize = 0;
    while (offset < input.len) {
        const result = try encoder.step(input[offset..], scratch);
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        offset += result.progress.input_read;
        if (result.progress.input_read == 0 and result.progress.output_written == 0)
            return error.TestUnexpectedResult;
    }
}

fn drainFlush(encoder: anytype, encoded: *std.ArrayList(u8), scratch: []u8) !void {
    while (true) {
        const result = try encoder.step("", scratch);
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .need_input) return;
        if (result.status == .done) return error.TestUnexpectedResult;
    }
}

fn finish(encoder: anytype, encoded: *std.ArrayList(u8), scratch: []u8) !void {
    encoder.finish();
    while (true) {
        const result = try encoder.step("", scratch);
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .done) return;
    }
}

fn expectRawFullFlush(comptime Encoder: type) !void {
    const first = "full flush retained history prefix 0123456789 abcdefghijklmnopqrstuvwxyz\n" ** 32;
    const second = "full flush retained history prefix 0123456789 abcdefghijklmnopqrstuvwxyz\n" ** 24;
    var encoder = Encoder.initWithOptions(std.testing.allocator, .{ .block_len = 257 });
    defer encoder.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var scratch: [11]u8 = undefined;

    try feed(&encoder, first, &encoded, &scratch);
    encoder.fullFlush();
    try drainFlush(&encoder, &encoded, &scratch);
    const suffix_offset = encoded.items.len;
    try std.testing.expect(suffix_offset != 0);

    try feed(&encoder, second, &encoded, &scratch);
    try finish(&encoder, &encoded, &scratch);

    const complete = try deflate.decodeRawAutoAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(complete);
    try std.testing.expectEqualSlices(u8, first ++ second, complete);

    // Z_FULL_FLUSH resets the compressor history and ends on a byte boundary,
    // so the following raw segment is a valid independent DEFLATE stream.
    const suffix = try deflate.decodeRawAutoAlloc(std.testing.allocator, encoded.items[suffix_offset..]);
    defer std.testing.allocator.free(suffix);
    try std.testing.expectEqualSlices(u8, second, suffix);
}

test "raw fixed and best full flush create independently decodable suffixes" {
    try expectRawFullFlush(deflate.RawDeflateIncrementalFixedEncoder);
    try expectRawFullFlush(deflate.RawDeflateIncrementalBestEncoder);
}

test "raw stored full flush exposes the same stream boundary API" {
    const first = "stored full flush first";
    const second = "stored full flush second";
    var encoder = deflate.RawDeflateIncrementalStoredEncoder.initWithOptions(std.testing.allocator, .{ .block_len = 7 });
    defer encoder.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var scratch: [5]u8 = undefined;

    try feed(&encoder, first, &encoded, &scratch);
    encoder.fullFlush();
    try drainFlush(&encoder, &encoded, &scratch);
    const suffix_offset = encoded.items.len;
    try feed(&encoder, second, &encoded, &scratch);
    try finish(&encoder, &encoded, &scratch);

    const suffix = try deflate.decodeRawAutoAlloc(std.testing.allocator, encoded.items[suffix_offset..]);
    defer std.testing.allocator.free(suffix);
    try std.testing.expectEqualSlices(u8, second, suffix);
}

test "raw full flush drops a preset dictionary for the following segment" {
    const dictionary = "caller supplied preset phrase alpha beta gamma delta epsilon";
    const first = "caller supplied preset phrase alpha beta gamma delta epsilon first";
    const second = "caller supplied preset phrase alpha beta gamma delta epsilon second" ** 12;
    var encoder = deflate.RawDeflateIncrementalFixedEncoder.initWithDictionary(std.testing.allocator, .{ .block_len = 113 }, dictionary);
    defer encoder.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var scratch: [7]u8 = undefined;

    try feed(&encoder, first, &encoded, &scratch);
    encoder.fullFlush();
    try drainFlush(&encoder, &encoded, &scratch);
    const suffix_offset = encoded.items.len;
    try feed(&encoder, second, &encoded, &scratch);
    try finish(&encoder, &encoded, &scratch);

    const complete = try deflate.decodeRawAutoAllocWithDictionary(std.testing.allocator, encoded.items, dictionary);
    defer std.testing.allocator.free(complete);
    try std.testing.expectEqualSlices(u8, first ++ second, complete);
    const suffix = try deflate.decodeRawAutoAlloc(std.testing.allocator, encoded.items[suffix_offset..]);
    defer std.testing.allocator.free(suffix);
    try std.testing.expectEqualSlices(u8, second, suffix);
}

test "full flush is idempotent and upgrades a completed sync boundary" {
    const first = "sync boundary upgraded to full without another marker\n" ** 32;
    const second = "sync boundary upgraded to full without another marker\n" ** 20;
    var encoder = deflate.RawDeflateIncrementalBestEncoder.initWithOptions(std.testing.allocator, .{
        .block_len = 193,
    });
    defer encoder.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var scratch: [7]u8 = undefined;

    try feed(&encoder, first, &encoded, &scratch);
    encoder.flush();
    try drainFlush(&encoder, &encoded, &scratch);
    const suffix_offset = encoded.items.len;

    encoder.flush();
    var result = try encoder.step("", &scratch);
    try std.testing.expectEqual(.need_input, result.status);
    try std.testing.expectEqual(@as(usize, 0), result.progress.output_written);

    encoder.fullFlush();
    try std.testing.expectEqual(@as(usize, 0), encoder.matchFinderSnapshot().absolute_position);
    result = try encoder.step("", &scratch);
    try std.testing.expectEqual(.need_input, result.status);
    try std.testing.expectEqual(@as(usize, 0), result.progress.output_written);
    try std.testing.expectEqual(suffix_offset, encoded.items.len);

    try feed(&encoder, second, &encoded, &scratch);
    try finish(&encoder, &encoded, &scratch);
    const suffix = try deflate.decodeRawAutoAlloc(std.testing.allocator, encoded.items[suffix_offset..]);
    defer std.testing.allocator.free(suffix);
    try std.testing.expectEqualSlices(u8, second, suffix);
}

test "finish preserves a pending full flush history reset" {
    const payload = "finish must honor the requested full flush boundary\n" ** 48;
    var encoder = deflate.RawDeflateIncrementalBestEncoder.initWithOptions(std.testing.allocator, .{
        .block_len = 211,
    });
    defer encoder.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var scratch: [5]u8 = undefined;

    try feed(&encoder, payload, &encoded, &scratch);
    try std.testing.expect(encoder.matchFinderSnapshot().absolute_position != 0);
    encoder.fullFlush();
    encoder.finish();
    while (true) {
        const result = try encoder.step("", &scratch);
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .done) break;
    }
    try std.testing.expectEqual(@as(usize, 0), encoder.matchFinderSnapshot().absolute_position);
    const decoded = try deflate.decodeRawAutoAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
}

test "zlib and gzip full flush preserve wrapper checksums" {
    const first = "wrapped full flush first segment\n" ** 19;
    const second = "wrapped full flush second segment\n" ** 23;

    var zlib_encoder = deflate.ZlibIncrementalBestEncoder.initExactSize(std.testing.allocator, .{
        .raw = .{ .block_len = 127 },
    }, first.len + second.len);
    defer zlib_encoder.deinit();
    var zlib_encoded: std.ArrayList(u8) = .empty;
    defer zlib_encoded.deinit(std.testing.allocator);
    var zlib_scratch: [9]u8 = undefined;
    try feed(&zlib_encoder, first, &zlib_encoded, &zlib_scratch);
    zlib_encoder.fullFlush();
    try drainFlush(&zlib_encoder, &zlib_encoded, &zlib_scratch);
    try feed(&zlib_encoder, second, &zlib_encoded, &zlib_scratch);
    try finish(&zlib_encoder, &zlib_encoded, &zlib_scratch);
    const zlib_decoded = try deflate.decodeZlibAlloc(std.testing.allocator, zlib_encoded.items);
    defer std.testing.allocator.free(zlib_decoded);
    try std.testing.expectEqualSlices(u8, first ++ second, zlib_decoded);

    var gzip_encoder = deflate.GzipIncrementalBestEncoder.initExactSize(std.testing.allocator, .{
        .raw = .{ .block_len = 131 },
        .header = .{ .filename = "full-flush.txt", .header_crc = true },
    }, first.len + second.len);
    defer gzip_encoder.deinit();
    var gzip_encoded: std.ArrayList(u8) = .empty;
    defer gzip_encoded.deinit(std.testing.allocator);
    var gzip_scratch: [13]u8 = undefined;
    try feed(&gzip_encoder, first, &gzip_encoded, &gzip_scratch);
    gzip_encoder.fullFlush();
    try drainFlush(&gzip_encoder, &gzip_encoded, &gzip_scratch);
    try feed(&gzip_encoder, second, &gzip_encoded, &gzip_scratch);
    try finish(&gzip_encoder, &gzip_encoded, &gzip_scratch);
    const gzip_decoded = try deflate.decodeGzipAlloc(std.testing.allocator, gzip_encoded.items);
    defer std.testing.allocator.free(gzip_decoded);
    try std.testing.expectEqualSlices(u8, first ++ second, gzip_decoded);
}
