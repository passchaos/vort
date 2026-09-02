const std = @import("std");
const deflate = @import("../../../deflate.zig");

test "gzip incremental best encoder emits concatenated members" {
    const first = "first incremental gzip member alpha beta gamma" ** 64;
    const second = "second independent gzip member delta epsilon" ** 48;
    var options = try deflate.gzipIncrementalBestOptionsForLevel(6, .{ .filename = "first.txt" });
    options.raw.block_len = 1024;
    var encoder = deflate.GzipIncrementalBestEncoder.initExactSize(std.testing.allocator, options, first.len);
    defer encoder.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    try appendGzipBestMember(&encoder, &encoded, first);
    try std.testing.expectEqual(@as(usize, 1), encoder.snapshot().member_count);
    try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().member_index);
    try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().pending_output);
    try std.testing.expectEqual(first.len, encoder.snapshot().input_read);
    try encoder.nextMemberExactSize(.{ .filename = "second.txt", .header_crc = true }, second.len);
    try std.testing.expectEqual(@as(usize, 1), encoder.snapshot().member_count);
    try std.testing.expectEqual(@as(usize, 1), encoder.snapshot().member_index);
    try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().member_input);
    try appendGzipBestMember(&encoder, &encoded, second);
    try std.testing.expectEqual(@as(usize, 2), encoder.snapshot().member_count);
    try std.testing.expectEqual(@as(usize, 1), encoder.snapshot().member_index);
    try std.testing.expectEqual(first.len + second.len, encoder.snapshot().input_read);

    const expected = try deflate.encodeGzipBestAlloc(std.testing.allocator, first, options.raw.compression);
    defer std.testing.allocator.free(expected);
    try std.testing.expect(encoded.items.len > expected.len);
    var history: [32 * 1024]u8 = undefined;
    var decoder = try deflate.GzipIncrementalDecoder.init(.{
        .allow_concatenated = true,
        .expected_output_len = first.len + second.len,
    }, &history);
    const decoded = try decodeGzipMembersTest(&decoder, encoded.items, first.len + second.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, first ++ second, decoded);
    try std.testing.expectEqual(@as(usize, 2), decoder.snapshot().member_count);
}

test "gzip incremental fixed encoder emits concatenated members" {
    const first = "fixed member one payload" ** 16;
    const second = "fixed member two payload" ** 12;
    var encoder = deflate.GzipIncrementalFixedEncoder.initWithOptions(std.testing.allocator, .{
        .raw = .{ .block_len = 128 },
        .header = .{ .filename = "one.txt" },
    });
    defer encoder.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    try appendGzipFixedMember(&encoder, &encoded, first);
    const second_offset = encoded.items.len;
    try encoder.nextMember(.{ .filename = "two.txt", .comment = "second" });
    try appendGzipFixedMember(&encoder, &encoded, second);

    const first_header = try deflate.parseGzipHeaderInfo(encoded.items);
    try std.testing.expectEqualSlices(u8, "one.txt", first_header.filename.?);
    const second_header = try deflate.parseGzipHeaderInfo(encoded.items[second_offset..]);
    try std.testing.expectEqualSlices(u8, "two.txt", second_header.filename.?);
    var history: [32 * 1024]u8 = undefined;
    var decoder = try deflate.GzipIncrementalDecoder.init(.{
        .allow_concatenated = true,
        .expected_output_len = first.len + second.len,
    }, &history);
    const decoded = try decodeGzipMembersTest(&decoder, encoded.items, first.len + second.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, first ++ second, decoded);
}

test "gzip incremental encoder rejects member transition before drain" {
    var encoder = deflate.GzipIncrementalBestEncoder.init(std.testing.allocator);
    defer encoder.deinit();
    try std.testing.expectError(error.InvalidBlockPlan, encoder.nextMember(.{}));
    var scratch: [16]u8 = undefined;
    _ = try encoder.step("payload", &scratch);
    encoder.finish();
    try std.testing.expectError(error.InvalidBlockPlan, encoder.nextMember(.{}));
}

test "gzip incremental encoder snapshot reports pending member output" {
    var encoder = deflate.GzipIncrementalBestEncoder.init(std.testing.allocator);
    defer encoder.deinit();
    var one: [1]u8 = undefined;
    const first = try encoder.step("payload", &one);
    try std.testing.expectEqual(@as(usize, 1), first.progress.output_written);
    try std.testing.expect(encoder.snapshot().pending_output != 0);
    try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().member_index);
    try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().member_count);
}

test "gzip incremental next member enforces its pledged size" {
    const first = "first";
    var encoder = deflate.GzipIncrementalBestEncoder.initExactSize(std.testing.allocator, .{}, first.len);
    defer encoder.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    try appendGzipBestMember(&encoder, &encoded, first);
    try encoder.nextMemberExactSize(.{}, 4);
    var scratch: [64]u8 = undefined;
    _ = try encoder.step("abc", &scratch);
    encoder.finish();
    try std.testing.expectError(error.SizeMismatch, encoder.step("", &scratch));
}

test "gzip incremental members switch compression options" {
    const first = "dynamic member content alpha beta gamma delta\n" ** 256;
    var second: [16 * 1024]u8 = undefined;
    var random = std.Random.DefaultPrng.init(0xa62f_401d_9bc3_75e8);
    random.random().bytes(&second);

    var first_options = try deflate.gzipIncrementalBestOptionsForLevel(6, .{ .filename = "dynamic.txt" });
    first_options.raw.block_len = 32 * 1024;
    var encoder = deflate.GzipIncrementalBestEncoder.initExactSize(std.testing.allocator, first_options, first.len);
    defer encoder.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    try appendGzipBestMember(&encoder, &encoded, first);
    const second_offset = encoded.items.len;

    var second_options = try deflate.gzipIncrementalBestOptionsForLevel(1, .{ .filename = "random.bin" });
    second_options.raw.block_len = 32 * 1024;
    try encoder.nextMemberExactSizeWithOptions(second_options, second.len);
    try appendGzipBestMember(&encoder, &encoded, &second);

    const first_header = try deflate.parseGzipHeaderInfo(encoded.items);
    const first_raw = try deflate.parseRawDeflateHeaderInfo(encoded.items[first_header.data_offset..]);
    try std.testing.expectEqual(deflate.RawDeflateBlockType.dynamic, first_raw.block_type);
    const second_header = try deflate.parseGzipHeaderInfo(encoded.items[second_offset..]);
    try std.testing.expectEqualSlices(u8, "random.bin", second_header.filename.?);
    const second_raw = try deflate.parseRawDeflateHeaderInfo(encoded.items[second_offset + second_header.data_offset ..]);
    try std.testing.expectEqual(deflate.RawDeflateBlockType.stored, second_raw.block_type);

    var history: [32 * 1024]u8 = undefined;
    var decoder = try deflate.GzipIncrementalDecoder.init(.{
        .allow_concatenated = true,
        .expected_output_len = first.len + second.len,
    }, &history);
    const decoded = try decodeGzipMembersTest(&decoder, encoded.items, first.len + second.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, first, decoded[0..first.len]);
    try std.testing.expectEqualSlices(u8, &second, decoded[first.len..]);
}

fn appendGzipBestMember(encoder: *deflate.GzipIncrementalBestEncoder, encoded: *std.ArrayList(u8), payload: []const u8) !void {
    var scratch: [31]u8 = undefined;
    var offset: usize = 0;
    while (offset < payload.len) {
        const result = try encoder.step(payload[offset..], &scratch);
        if (result.progress.input_read == 0 and result.progress.output_written == 0) return error.InvalidBlockPlan;
        offset += result.progress.input_read;
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
    }
    encoder.finish();
    while (true) {
        const result = try encoder.step("", &scratch);
        if (result.progress.input_read == 0 and result.progress.output_written == 0 and result.status != .done) return error.InvalidBlockPlan;
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .done) break;
    }
}

fn appendGzipFixedMember(encoder: *deflate.GzipIncrementalFixedEncoder, encoded: *std.ArrayList(u8), payload: []const u8) !void {
    var scratch: [17]u8 = undefined;
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
}

fn decodeGzipMembersTest(decoder: *deflate.GzipIncrementalDecoder, encoded: []const u8, expected_len: usize) ![]u8 {
    const decoded = try std.testing.allocator.alloc(u8, expected_len);
    errdefer std.testing.allocator.free(decoded);
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (input_offset < encoded.len) {
        const result = try decoder.step(encoded[input_offset..], decoded[output_offset..]);
        if (result.progress.input_read == 0 and result.progress.output_written == 0) return error.InvalidBlockPlan;
        input_offset += result.progress.input_read;
        output_offset += result.progress.output_written;
    }
    // Concatenated gzip has no in-band end marker after the last member. The
    // decoder intentionally remains between_members until the caller declares
    // EOF, so spinning step("") here can never make progress.
    try decoder.finish();
    try std.testing.expectEqual(expected_len, output_offset);
    return decoded;
}

test "zlib incremental best encoder emits concatenated streams" {
    const dictionary = "zlib member dictionary phrase";
    const first = "first zlib member alpha beta gamma" ** 32;
    const second = "zlib member dictionary phrase and payload" ** 24;
    var first_options = try deflate.zlibIncrementalBestOptionsForLevel(6);
    first_options.raw.block_len = 1024;
    var encoder = deflate.ZlibIncrementalBestEncoder.initExactSize(std.testing.allocator, first_options, first.len);
    defer encoder.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    try appendZlibBestStream(&encoder, &encoded, first);
    try std.testing.expectEqual(@as(usize, 1), encoder.snapshot().stream_count);
    try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().stream_index);
    try std.testing.expectEqual(first.len, encoder.snapshot().input_read);
    try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().pending_output);
    const second_offset = encoded.items.len;

    var second_options = try deflate.zlibIncrementalBestOptionsForLevel(1);
    second_options.raw.block_len = 512;
    try encoder.nextStreamExactSize(second_options, dictionary, second.len);
    try std.testing.expectEqual(@as(usize, 1), encoder.snapshot().stream_index);
    try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().stream_input);
    try appendZlibBestStream(&encoder, &encoded, second);
    try std.testing.expectEqual(@as(usize, 2), encoder.snapshot().stream_count);
    try std.testing.expectEqual(@as(usize, 1), encoder.snapshot().stream_index);
    try std.testing.expectEqual(first.len + second.len, encoder.snapshot().input_read);
    const second_header = try deflate.parseZlibHeaderInfo(encoded.items[second_offset..]);
    try std.testing.expect(second_header.dictionary_id != null);

    const decoded = try deflate.decodeZlibConcatenatedAllocWithDictionaryExactSize(
        std.testing.allocator,
        encoded.items,
        dictionary,
        first.len + second.len,
    );
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, first ++ second, decoded);
}

test "zlib incremental encoder rejects early stream transition" {
    var encoder = deflate.ZlibIncrementalBestEncoder.init(std.testing.allocator);
    defer encoder.deinit();
    try std.testing.expectError(error.InvalidBlockPlan, encoder.nextStream(.{}, ""));
}

test "zlib incremental encoder snapshot reports pending output" {
    var encoder = deflate.ZlibIncrementalBestEncoder.init(std.testing.allocator);
    defer encoder.deinit();
    var one: [1]u8 = undefined;
    _ = try encoder.step("payload", &one);
    try std.testing.expect(encoder.snapshot().pending_output != 0);
    try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().stream_count);
    try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().stream_index);
}

test "zlib concatenated dictionary set resolves each stream DICTID" {
    const first_dictionary = "first zlib dictionary phrase";
    const second_dictionary = "second zlib dictionary phrase";
    const first = "first zlib dictionary phrase payload" ** 12;
    const second = "second zlib dictionary phrase payload" ** 10;
    var options = try deflate.zlibIncrementalBestOptionsForLevel(6);
    var encoder = deflate.ZlibIncrementalBestEncoder.initExactSizeWithDictionary(
        std.testing.allocator,
        options,
        first.len,
        first_dictionary,
    );
    defer encoder.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    try appendZlibBestStream(&encoder, &encoded, first);
    options.raw.compression = deflate.optionsForLevel(.fast);
    try encoder.nextStreamExactSize(options, second_dictionary, second.len);
    try appendZlibBestStream(&encoder, &encoded, second);

    const entries = [_]deflate.ZlibDictionaryEntry{
        deflate.ZlibDictionarySet.entry(first_dictionary),
        deflate.ZlibDictionarySet.entry(second_dictionary),
    };
    const set = deflate.ZlibDictionarySet.fromEntries(&entries);
    const decoded = try deflate.decodeZlibConcatenatedAllocWithDictionarySetExactSize(
        std.testing.allocator,
        encoded.items,
        set,
        first.len + second.len,
    );
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, first ++ second, decoded);

    const missing = deflate.ZlibDictionarySet.fromEntries(entries[0..1]);
    var output: [first.len + second.len]u8 = undefined;
    try std.testing.expectError(error.NeedDictionary, deflate.decodeZlibConcatenatedWithDictionarySet(encoded.items, &output, missing));
}

test "zlib incremental decoder streams concatenated dictionary-set streams" {
    const first_dictionary = "incremental first zlib dictionary";
    const second_dictionary = "incremental second zlib dictionary";
    const first = "incremental first zlib dictionary payload" ** 8;
    const second = "incremental second zlib dictionary payload" ** 7;
    var encoder = deflate.ZlibIncrementalBestEncoder.initExactSizeWithDictionary(
        std.testing.allocator,
        .{},
        first.len,
        first_dictionary,
    );
    defer encoder.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    try appendZlibBestStream(&encoder, &encoded, first);
    const second_offset = encoded.items.len;
    try encoder.nextStreamExactSize(.{}, second_dictionary, second.len);
    try appendZlibBestStream(&encoder, &encoded, second);

    const entries = [_]deflate.ZlibDictionaryEntry{
        deflate.ZlibDictionarySet.entry(first_dictionary),
        deflate.ZlibDictionarySet.entry(second_dictionary),
    };
    var history: [32 * 1024]u8 = undefined;
    var decoder = try deflate.ZlibIncrementalDecoder.initWithDictionarySet(.{
        .allow_concatenated = true,
        .expected_output_len = first.len + second.len,
    }, &history, deflate.ZlibDictionarySet.fromEntries(&entries));
    var output: [first.len + second.len]u8 = undefined;
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (input_offset < encoded.items.len) {
        const result = try decoder.step(encoded.items[input_offset .. input_offset + 1], output[output_offset..][0..@min(3, output.len - output_offset)]);
        input_offset += result.progress.input_read;
        output_offset += result.progress.output_written;
        if (input_offset == second_offset) {
            const boundary = decoder.snapshot();
            try std.testing.expectEqual(deflate.ZlibIncrementalDecoder.Phase.between_streams, boundary.phase);
            try std.testing.expectEqual(@as(usize, 1), boundary.stream_count);
        }
    }
    try decoder.finish();
    try std.testing.expectEqualSlices(u8, first ++ second, &output);
    try std.testing.expectEqual(@as(usize, 2), decoder.snapshot().stream_count);
    try std.testing.expectEqual(@as(usize, 1), decoder.snapshot().stream_index);
    try std.testing.expectEqual(second_offset, decoder.snapshot().stream_offset);
}

test "zlib incremental concatenation diagnoses corrupt later stream" {
    const first = try deflate.encodeZlibFixedAlloc(std.testing.allocator, "first");
    defer std.testing.allocator.free(first);
    var second = try deflate.encodeZlibFixedAlloc(std.testing.allocator, "second");
    defer std.testing.allocator.free(second);
    second[second.len - 1] ^= 1;
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    try encoded.appendSlice(std.testing.allocator, first);
    try encoded.appendSlice(std.testing.allocator, second);
    var history: [32 * 1024]u8 = undefined;
    var decoder = try deflate.ZlibIncrementalDecoder.init(.{ .allow_concatenated = true }, &history);
    var output: [32]u8 = undefined;
    try std.testing.expectError(error.ChecksumMismatch, decoder.step(encoded.items, &output));
    try std.testing.expectEqual(@as(usize, 1), decoder.snapshot().stream_count);
    try std.testing.expectEqual(@as(usize, 1), decoder.snapshot().stream_index);
    try std.testing.expectEqual(@as(?usize, 1), decoder.snapshot().last_error_stream_index);
    try std.testing.expectEqual(@as(?usize, first.len), decoder.snapshot().last_error_stream_offset);
}

test "zlib incremental concatenation enforces cumulative sizes and reset" {
    const first_payload = "first-size";
    const second_payload = "second-size";
    const first = try deflate.encodeZlibFixedAlloc(std.testing.allocator, first_payload);
    defer std.testing.allocator.free(first);
    const second = try deflate.encodeZlibFixedAlloc(std.testing.allocator, second_payload);
    defer std.testing.allocator.free(second);
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    try encoded.appendSlice(std.testing.allocator, first);
    try encoded.appendSlice(std.testing.allocator, second);
    var history: [32 * 1024]u8 = undefined;
    var output: [64]u8 = undefined;

    var limited = try deflate.ZlibIncrementalDecoder.init(.{
        .allow_concatenated = true,
        .max_output_len = first_payload.len + second_payload.len - 1,
    }, &history);
    try std.testing.expectError(error.OutputLimitExceeded, limited.step(encoded.items, &output));

    var too_short = try deflate.ZlibIncrementalDecoder.init(.{
        .allow_concatenated = true,
        .expected_output_len = first_payload.len + second_payload.len - 1,
    }, &history);
    try std.testing.expectError(error.SizeMismatch, too_short.step(encoded.items, &output));

    var too_long = try deflate.ZlibIncrementalDecoder.init(.{
        .allow_concatenated = true,
        .expected_output_len = first_payload.len + second_payload.len + 1,
    }, &history);
    _ = try too_long.step(encoded.items, &output);
    try std.testing.expectError(error.SizeMismatch, too_long.finish());
    too_long.reset();
    try std.testing.expectEqual(deflate.ZlibIncrementalDecoder.Phase.header, too_long.snapshot().phase);
    try std.testing.expectEqual(@as(usize, 0), too_long.snapshot().stream_count);
    try std.testing.expectEqual(@as(?usize, null), too_long.snapshot().last_error_stream_index);
}

fn appendZlibBestStream(encoder: *deflate.ZlibIncrementalBestEncoder, encoded: *std.ArrayList(u8), payload: []const u8) !void {
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
}
