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
