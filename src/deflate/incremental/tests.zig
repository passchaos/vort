const std = @import("std");
const core = @import("../../core.zig");
const deflate = @import("../../deflate.zig");

test "raw deflate incremental stored encoder splits flushes and resumes" {
    const first = "first raw deflate stored segment";
    const second = "second segment after flush";
    var encoder = deflate.RawDeflateIncrementalStoredEncoder.initWithOptions(std.testing.allocator, .{ .block_len = 17 });
    defer encoder.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var scratch: [7]u8 = undefined;
    var result: core.StepResult = undefined;

    var offset: usize = 0;
    while (offset < first.len) {
        result = try encoder.step(first[offset..], &scratch);
        offset += result.progress.input_read;
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
    }
    encoder.flush();
    while (true) {
        result = try encoder.step("", &scratch);
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .need_input) break;
    }
    const flushed_len = encoded.items.len;
    encoder.flush();
    result = try encoder.step("", &scratch);
    try std.testing.expectEqual(.need_input, result.status);
    try std.testing.expectEqual(flushed_len, encoded.items.len);

    offset = 0;
    while (offset < second.len) {
        result = try encoder.step(second[offset..], &scratch);
        offset += result.progress.input_read;
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
    }
    encoder.finish();
    while (true) {
        result = try encoder.step("", &scratch);
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .done) break;
    }
    const decoded = try deflate.decodeRawStoredAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, first ++ second, decoded);
    encoder.reset();
    try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().input_read);
}

test "raw deflate incremental stored encoder enforces sizes and plan" {
    var limited = deflate.RawDeflateIncrementalStoredEncoder.initWithOptions(std.testing.allocator, .{ .max_input_len = 3 });
    defer limited.deinit();
    try std.testing.expectError(error.OutputLimitExceeded, limited.step("four", &.{}));

    var exact = deflate.RawDeflateIncrementalStoredEncoder.initExactSize(std.testing.allocator, .{}, 4);
    defer exact.deinit();
    var scratch: [8]u8 = undefined;
    _ = try exact.step("abc", &scratch);
    exact.finish();
    try std.testing.expectError(error.SizeMismatch, exact.step("", &scratch));

    var invalid = deflate.RawDeflateIncrementalStoredEncoder.initWithOptions(std.testing.allocator, .{ .block_len = 0 });
    defer invalid.deinit();
    try std.testing.expectError(error.InvalidBlockPlan, invalid.step("", &.{}));
}

test "raw deflate incremental fixed encoder retains history and sync flushes" {
    const first = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
    const second = "prefix-0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-tail";
    var encoder = deflate.RawDeflateIncrementalFixedEncoder.initWithOptions(std.testing.allocator, .{
        .block_len = first.len,
    });
    defer encoder.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var scratch: [9]u8 = undefined;
    var result: core.StepResult = undefined;

    var offset: usize = 0;
    while (offset < first.len) {
        result = try encoder.step(first[offset..], &scratch);
        offset += result.progress.input_read;
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
    }
    encoder.flush();
    while (true) {
        result = try encoder.step("", &scratch);
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .need_input) break;
    }
    offset = 0;
    while (offset < second.len) {
        result = try encoder.step(second[offset..], &scratch);
        offset += result.progress.input_read;
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
    }
    encoder.finish();
    while (true) {
        result = try encoder.step("", &scratch);
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .done) break;
    }
    const decoded = try deflate.decodeRawAutoAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, first ++ second, decoded);

    const stored = try deflate.encodeRawStoredAlloc(std.testing.allocator, first ++ second);
    defer std.testing.allocator.free(stored);
    try std.testing.expect(encoded.items.len < stored.len);
}

test "raw deflate incremental fixed encoder handles empty and exact streams" {
    var empty = deflate.RawDeflateIncrementalFixedEncoder.init(std.testing.allocator);
    defer empty.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var scratch: [3]u8 = undefined;
    empty.finish();
    while (true) {
        const result = try empty.step("", &scratch);
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .done) break;
    }
    const decoded = try deflate.decodeRawAutoAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqual(@as(usize, 0), decoded.len);

    var exact = deflate.RawDeflateIncrementalFixedEncoder.initExactSize(std.testing.allocator, .{}, 4);
    defer exact.deinit();
    _ = try exact.step("abc", &scratch);
    exact.finish();
    try std.testing.expectError(error.SizeMismatch, exact.step("", &scratch));
}

test "zlib incremental fixed encoder wraps checksum flush and exact size" {
    const first = "incremental zlib fixed first segment";
    const second = " second segment with segment repetition";
    var encoder = deflate.ZlibIncrementalFixedEncoder.initExactSize(std.testing.allocator, .{
        .raw = .{ .block_len = 19 },
    }, first.len + second.len);
    defer encoder.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var scratch: [7]u8 = undefined;
    var result: core.StepResult = undefined;
    var offset: usize = 0;
    while (offset < first.len) {
        result = try encoder.step(first[offset..], &scratch);
        offset += result.progress.input_read;
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
    }
    encoder.flush();
    while (true) {
        result = try encoder.step("", &scratch);
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .need_input) break;
    }
    offset = 0;
    while (offset < second.len) {
        result = try encoder.step(second[offset..], &scratch);
        offset += result.progress.input_read;
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
    }
    encoder.finish();
    while (true) {
        result = try encoder.step("", &scratch);
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .done) break;
    }
    const decoded = try deflate.decodeZlibAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, first ++ second, decoded);
    try std.testing.expectEqual(@as(u8, 0x78), encoded.items[0]);
    try std.testing.expectEqual(@as(u8, 0x01), encoded.items[1]);
}

test "zlib incremental fixed encoder supports preset dictionary" {
    const dictionary = "shared zlib preset dictionary phrase";
    const payload = "shared zlib preset dictionary phrase payload";
    var encoder = deflate.ZlibIncrementalFixedEncoder.initWithDictionary(std.testing.allocator, .{}, dictionary);
    defer encoder.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var scratch: [11]u8 = undefined;
    var offset: usize = 0;
    while (offset < payload.len) {
        const result = try encoder.step(payload[offset..], &scratch);
        offset += result.progress.input_read;
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
    }
    encoder.finish();
    while (true) {
        const result = try encoder.step("", &scratch);
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .done) break;
    }
    try std.testing.expect((encoded.items[1] & 0x20) != 0);
    const decoded = try deflate.decodeZlibAllocWithDictionary(std.testing.allocator, encoded.items, dictionary);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    try std.testing.expectError(error.NeedDictionary, deflate.decodeZlibAlloc(std.testing.allocator, encoded.items));
}

test "gzip incremental fixed encoder wraps crc isize and sync flush" {
    const first = "incremental gzip fixed first segment";
    const second = " second gzip segment after sync flush";
    var encoder = deflate.GzipIncrementalFixedEncoder.initExactSize(std.testing.allocator, .{
        .raw = .{ .block_len = 21 },
    }, first.len + second.len);
    defer encoder.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var scratch: [7]u8 = undefined;
    var result: core.StepResult = undefined;
    var offset: usize = 0;
    while (offset < first.len) {
        result = try encoder.step(first[offset..], &scratch);
        offset += result.progress.input_read;
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
    }
    encoder.flush();
    while (true) {
        result = try encoder.step("", &scratch);
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .need_input) break;
    }
    offset = 0;
    while (offset < second.len) {
        result = try encoder.step(second[offset..], &scratch);
        offset += result.progress.input_read;
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
    }
    encoder.finish();
    while (true) {
        result = try encoder.step("", &scratch);
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .done) break;
    }
    const decoded = try deflate.decodeGzipAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, first ++ second, decoded);
    try std.testing.expectEqualSlices(u8, &.{ 0x1f, 0x8b, 0x08 }, encoded.items[0..3]);
}

test "gzip incremental fixed encoder emits metadata header" {
    const payload = "metadata-rich incremental gzip";
    var encoder = deflate.GzipIncrementalFixedEncoder.initWithOptions(std.testing.allocator, .{
        .header = .{
            .text = true,
            .mtime = 0x1234_5678,
            .extra = "xy",
            .filename = "payload.txt",
            .comment = "vort",
            .header_crc = true,
        },
    });
    defer encoder.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var scratch: [13]u8 = undefined;
    var offset: usize = 0;
    while (offset < payload.len) {
        const result = try encoder.step(payload[offset..], &scratch);
        offset += result.progress.input_read;
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
    }
    encoder.finish();
    while (true) {
        const result = try encoder.step("", &scratch);
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .done) break;
    }
    const header = try deflate.parseGzipHeaderInfo(encoded.items);
    try std.testing.expect(header.text);
    try std.testing.expectEqual(@as(u32, 0x1234_5678), header.mtime);
    try std.testing.expectEqualSlices(u8, "payload.txt", header.filename.?);
    const decoded = try deflate.decodeGzipAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
}

test "raw deflate incremental best encoder selects dynamic blocks" {
    const payload = ("dynamic huffman incremental best selection alpha beta gamma delta\n" ** 400);
    var encoder = deflate.RawDeflateIncrementalBestEncoder.initWithOptions(std.testing.allocator, .{
        .block_len = payload.len,
        .compression = .{ .block_selection = .stored_fixed_dynamic },
    });
    defer encoder.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var scratch: [17]u8 = undefined;
    var offset: usize = 0;
    while (offset < payload.len) {
        const end = @min(payload.len, offset + 211);
        const result = try encoder.step(payload[offset..end], &scratch);
        offset += result.progress.input_read;
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
    }
    encoder.finish();
    while (true) {
        const result = try encoder.step("", &scratch);
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .done) break;
    }
    const info = try deflate.parseRawDeflateHeaderInfo(encoded.items);
    try std.testing.expectEqual(deflate.RawDeflateBlockType.dynamic, info.block_type);
    const decoded = try deflate.decodeRawAutoAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
}

test "raw deflate incremental best encoder falls back to stored and sync flushes" {
    var payload: [4096]u8 = undefined;
    var random = std.Random.DefaultPrng.init(0x1234_5678);
    random.random().bytes(&payload);
    var encoder = deflate.RawDeflateIncrementalBestEncoder.initWithOptions(std.testing.allocator, .{
        .block_len = payload.len,
        .compression = .{ .block_selection = .stored_fixed_dynamic },
    });
    defer encoder.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var scratch: [31]u8 = undefined;
    var offset: usize = 0;
    while (offset < payload.len) {
        const result = try encoder.step(payload[offset..], &scratch);
        offset += result.progress.input_read;
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
    }
    encoder.flush();
    while (true) {
        const result = try encoder.step("", &scratch);
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .need_input) break;
    }
    encoder.finish();
    while (true) {
        const result = try encoder.step("", &scratch);
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .done) break;
    }
    const info = try deflate.parseRawDeflateHeaderInfo(encoded.items);
    try std.testing.expectEqual(deflate.RawDeflateBlockType.stored, info.block_type);
    const decoded = try deflate.decodeRawAutoAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &payload, decoded);
}

test "zlib incremental best encoder selects dynamic blocks by level" {
    const payload = ("zlib best dynamic wrapper payload alpha beta gamma delta\n" ** 300);
    var options = try deflate.zlibIncrementalBestOptionsForLevel(6);
    options.raw.block_len = payload.len;
    var encoder = deflate.ZlibIncrementalBestEncoder.initWithOptions(std.testing.allocator, options);
    defer encoder.deinit();
    const encoded = try encodeZlibBestTestStream(&encoder, payload);
    defer std.testing.allocator.free(encoded);
    const header = try deflate.parseZlibHeaderInfo(encoded);
    const raw_info = try deflate.parseRawDeflateHeaderInfo(encoded[header.data_offset..]);
    try std.testing.expectEqual(deflate.RawDeflateBlockType.dynamic, raw_info.block_type);
    const decoded = try deflate.decodeZlibAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
}

test "gzip incremental best encoder selects stored and preserves metadata" {
    var payload: [2048]u8 = undefined;
    var random = std.Random.DefaultPrng.init(0xfeed_beef);
    random.random().bytes(&payload);
    var options = try deflate.gzipIncrementalBestOptionsForLevel(6, .{ .filename = "random.bin", .header_crc = true });
    options.raw.block_len = payload.len;
    var encoder = deflate.GzipIncrementalBestEncoder.initWithOptions(std.testing.allocator, options);
    defer encoder.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var scratch: [23]u8 = undefined;
    var offset: usize = 0;
    while (offset < payload.len) {
        const result = try encoder.step(payload[offset..], &scratch);
        offset += result.progress.input_read;
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
    }
    encoder.finish();
    while (true) {
        const result = try encoder.step("", &scratch);
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .done) break;
    }
    const header = try deflate.parseGzipHeaderInfo(encoded.items);
    try std.testing.expectEqualSlices(u8, "random.bin", header.filename.?);
    const raw_info = try deflate.parseRawDeflateHeaderInfo(encoded.items[header.data_offset..]);
    try std.testing.expectEqual(deflate.RawDeflateBlockType.stored, raw_info.block_type);
    const decoded = try deflate.decodeGzipAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &payload, decoded);
}

fn encodeZlibBestTestStream(encoder: *deflate.ZlibIncrementalBestEncoder, payload: []const u8) ![]u8 {
    var encoded: std.ArrayList(u8) = .empty;
    errdefer encoded.deinit(std.testing.allocator);
    var scratch: [19]u8 = undefined;
    var offset: usize = 0;
    while (offset < payload.len) {
        const end = @min(payload.len, offset + 137);
        const result = try encoder.step(payload[offset..end], &scratch);
        offset += result.progress.input_read;
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
    }
    encoder.finish();
    while (true) {
        const result = try encoder.step("", &scratch);
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .done) break;
    }
    return try encoded.toOwnedSlice(std.testing.allocator);
}

test "raw deflate incremental best encoder adapts block boundaries" {
    const payload = ("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ** 512) ++
        ("structured-json-field:value,structured-json-field:value\n" ** 512);
    var compression = deflate.optionsForLevel(.default);
    compression.split_options = .{
        .min_block_len = 8 * 1024,
        .max_block_len = 32 * 1024,
        .sample_len = 2048,
        .search_step = 8 * 1024,
    };
    var adaptive = deflate.RawDeflateIncrementalBestEncoder.initWithOptions(std.testing.allocator, .{
        .adaptive_blocks = true,
        .compression = compression,
    });
    defer adaptive.deinit();
    const encoded = try encodeRawBestTestStream(&adaptive, payload);
    defer std.testing.allocator.free(encoded);
    const decoded = try deflate.decodeRawAutoAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);

    var fixed_boundary = deflate.RawDeflateIncrementalBestEncoder.initWithOptions(std.testing.allocator, .{
        .block_len = 32 * 1024,
        .compression = compression,
    });
    defer fixed_boundary.deinit();
    const fixed_encoded = try encodeRawBestTestStream(&fixed_boundary, payload);
    defer std.testing.allocator.free(fixed_encoded);
    try std.testing.expect(encoded.len <= fixed_encoded.len);
}

test "raw deflate incremental adaptive plan validates bounds" {
    var encoder = deflate.RawDeflateIncrementalBestEncoder.initWithOptions(std.testing.allocator, .{
        .adaptive_blocks = true,
        .compression = .{ .split_options = .{ .min_block_len = 0, .max_block_len = 1024 } },
    });
    defer encoder.deinit();
    try std.testing.expectError(error.InvalidBlockPlan, encoder.step("x", &.{}));
}

fn encodeRawBestTestStream(encoder: *deflate.RawDeflateIncrementalBestEncoder, payload: []const u8) ![]u8 {
    var encoded: std.ArrayList(u8) = .empty;
    errdefer encoded.deinit(std.testing.allocator);
    var scratch: [29]u8 = undefined;
    var offset: usize = 0;
    while (offset < payload.len) {
        const end = @min(payload.len, offset + 777);
        const result = try encoder.step(payload[offset..end], &scratch);
        offset += result.progress.input_read;
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
    }
    encoder.finish();
    while (true) {
        const result = try encoder.step("", &scratch);
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .done) break;
    }
    return try encoded.toOwnedSlice(std.testing.allocator);
}

test "raw deflate incremental lookahead preserves boundary matches" {
    const phrase = "cross-boundary-match-abcdefghijklmnopqrstuvwxyz";
    const first = ("history-padding-" ** 20) ++ phrase;
    const second = phrase ++ "-tail";
    const payload = first ++ second;
    const target = first.len + 8;
    var compression = deflate.optionsForLevel(.default);
    compression.block_selection = .stored_fixed_dynamic;

    var lookahead = deflate.RawDeflateIncrementalBestEncoder.initWithOptions(std.testing.allocator, .{
        .block_len = target + 64,
        .lookahead_len = 64,
        .compression = compression,
    });
    defer lookahead.deinit();
    const lookahead_encoded = try encodeRawBestTestStream(&lookahead, payload);
    defer std.testing.allocator.free(lookahead_encoded);
    const decoded = try deflate.decodeRawAutoAlloc(std.testing.allocator, lookahead_encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);

    var hard = deflate.RawDeflateIncrementalBestEncoder.initWithOptions(std.testing.allocator, .{
        .block_len = target,
        .compression = compression,
    });
    defer hard.deinit();
    const hard_encoded = try encodeRawBestTestStream(&hard, payload);
    defer std.testing.allocator.free(hard_encoded);
    try std.testing.expect(lookahead_encoded.len <= hard_encoded.len);
}

test "raw deflate incremental lookahead validates capacity" {
    var encoder = deflate.RawDeflateIncrementalBestEncoder.initWithOptions(std.testing.allocator, .{
        .block_len = 16,
        .lookahead_len = 16,
    });
    defer encoder.deinit();
    try std.testing.expectError(error.InvalidBlockPlan, encoder.step("x", &.{}));
}

test "raw deflate incremental stored decoder streams split input and tiny output" {
    const payload = "byte progressive raw deflate stored payload" ** 32;
    const encoded = try deflate.encodeRawStoredAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);
    var decoder = deflate.RawDeflateIncrementalStoredDecoder.initWithOptions(.{
        .expected_output_len = payload.len,
    });
    var output: [payload.len]u8 = undefined;
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (input_offset < encoded.len) {
        const output_end = @min(output.len, output_offset + 3);
        const result = try decoder.step(encoded[input_offset .. input_offset + 1], output[output_offset..output_end]);
        input_offset += result.progress.input_read;
        output_offset += result.progress.output_written;
    }
    while (decoder.snapshot().phase != .done) {
        const output_end = @min(output.len, output_offset + 3);
        const result = try decoder.step("", output[output_offset..output_end]);
        output_offset += result.progress.output_written;
    }
    try decoder.finish();
    try std.testing.expectEqualSlices(u8, payload, &output);
    decoder.reset();
    try std.testing.expectEqual(deflate.RawDeflateIncrementalStoredDecoder.Phase.header, decoder.snapshot().phase);
}

test "raw deflate incremental stored decoder validates hostile streams" {
    var reserved = deflate.RawDeflateIncrementalStoredDecoder.init();
    try std.testing.expectError(error.InvalidDeflateBlockType, reserved.step(&.{ 0x03, 0, 0, 0xff, 0xff }, &.{}));

    var lengths = deflate.RawDeflateIncrementalStoredDecoder.init();
    try std.testing.expectError(error.StoredLengthMismatch, lengths.step(&.{ 0x01, 1, 0, 0xff, 0xff }, &.{}));

    const encoded = try deflate.encodeRawStoredAlloc(std.testing.allocator, "limit");
    defer std.testing.allocator.free(encoded);
    var limited = deflate.RawDeflateIncrementalStoredDecoder.initWithOptions(.{ .max_output_len = 4 });
    try std.testing.expectError(error.OutputLimitExceeded, limited.step(encoded, &.{}));

    var truncated = deflate.RawDeflateIncrementalStoredDecoder.init();
    _ = try truncated.step(encoded[0 .. encoded.len - 1], &.{});
    try std.testing.expectError(error.TruncatedFrame, truncated.finish());
    try std.testing.expectEqualStrings("truncated_input", truncated.diagnostics().recoverability_hint_name);
}

test "raw deflate incremental fixed literal decoder streams bit splits" {
    const payload = "fixed literal only progressive decode" ** 16;
    const encoded = try deflate.encodeRawFixedWithOptionsAlloc(std.testing.allocator, payload, .{ .strategy = .huffman_only });
    defer std.testing.allocator.free(encoded);
    var decoder = deflate.RawDeflateIncrementalFixedLiteralDecoder.initWithOptions(.{ .expected_output_len = payload.len });
    var output: [payload.len]u8 = undefined;
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (input_offset < encoded.len) {
        const end = @min(encoded.len, input_offset + 1);
        const output_end = @min(output.len, output_offset + 2);
        const result = try decoder.step(encoded[input_offset..end], output[output_offset..output_end]);
        input_offset += result.progress.input_read;
        output_offset += result.progress.output_written;
    }
    while (output_offset < output.len) {
        const end = @min(output.len, output_offset + 2);
        const result = try decoder.step("", output[output_offset..end]);
        output_offset += result.progress.output_written;
    }
    try decoder.finish();
    try std.testing.expectEqualSlices(u8, payload, &output);
}

test "raw deflate incremental fixed literal decoder rejects matches and truncation" {
    const matched = try deflate.encodeRawFixedAlloc(std.testing.allocator, "repeat repeat repeat repeat repeat");
    defer std.testing.allocator.free(matched);
    var unsupported = deflate.RawDeflateIncrementalFixedLiteralDecoder.init();
    var output: [64]u8 = undefined;
    try std.testing.expectError(error.UnsupportedDeflateFeature, unsupported.step(matched, &output));

    const literal = try deflate.encodeRawFixedWithOptionsAlloc(std.testing.allocator, "truncated literals", .{ .strategy = .huffman_only });
    defer std.testing.allocator.free(literal);
    var truncated = deflate.RawDeflateIncrementalFixedLiteralDecoder.init();
    _ = try truncated.step(literal[0 .. literal.len - 1], &output);
    try std.testing.expectError(error.TruncatedFrame, truncated.finish());
}
