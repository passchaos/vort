const std = @import("std");
const deflate = @import("../../../deflate.zig");
const checksum = @import("../../../checksum.zig");
const core = @import("../../../core.zig");
const allocator = std.testing.allocator;
const dictionary_bytes = "dictionary phrase shared by zlib payload bytes";
const payload_bytes = "dictionary phrase shared by zlib payload bytes repeated\n" ** 32;

fn frameAlloc(input: []const u8, dictionary: []const u8) ![]u8 {
    return deflate.encodeZlibFixedWithDictionaryAlloc(allocator, input, dictionary, .{});
}

fn drain(decoder: *deflate.ZlibIncrementalDecoder, input: []const u8, output: []u8) !void {
    var offset: usize = 0;
    var written: usize = 0;
    var calls: usize = 0;
    while (true) : (calls += 1) {
        try std.testing.expect(calls < input.len * 4 + output.len * 4 + 32);
        const provided = input[offset..][0..@min(1, input.len - offset)];
        const destination = output[written..][0..@min(if (calls % 4 == 0) @as(usize, 0) else 3, output.len - written)];
        const before = decoder.snapshot();
        const stepped = try decoder.step(provided, destination);
        offset += stepped.progress.input_read;
        written += stepped.progress.output_written;
        const after = decoder.snapshot();
        try std.testing.expectEqual(after.total_input - before.total_input, stepped.progress.input_read);
        try std.testing.expectEqual(after.total_output - before.total_output, stepped.progress.output_written);
        try std.testing.expectEqualDeep(stepped.progress, after.last_step_progress);
        if (stepped.status == .done or (decoder.options.allow_concatenated and decoder.phase == .between_streams and offset == input.len)) break;
    }
    try std.testing.expectEqual(input.len, offset);
    try std.testing.expectEqual(output.len, written);
    try decoder.finish();
}

fn expectFailureProgress(decoder: *const deflate.ZlibIncrementalDecoder, input: usize, output: usize) !void {
    const snapshot = decoder.snapshot();
    const diagnostic = decoder.diagnostics();
    try std.testing.expectEqual(input, snapshot.last_step_progress.input_read);
    try std.testing.expectEqual(output, snapshot.last_step_progress.output_written);
    try std.testing.expectEqualDeep(snapshot.last_step_progress, diagnostic.last_step_progress.?);
    try std.testing.expectEqual(@as(?usize, snapshot.total_input), snapshot.last_error_input_offset);
    try std.testing.expectEqual(@as(?usize, snapshot.total_output), snapshot.last_error_output_offset);
    try std.testing.expectEqual(snapshot.last_error_input_offset, diagnostic.error_input_offset);
    try std.testing.expectEqual(snapshot.last_error_output_offset, diagnostic.error_output_offset);
}

test "zlib incremental dictionary request waits for complete DICTID and resumes in place" {
    const dictionary = "zlib requested dictionary phrase";
    const input = "zlib requested dictionary phrase repeated payload" ** 8;
    const encoded = try deflate.encodeZlibFixedWithDictionaryAlloc(std.testing.allocator, input, dictionary, .{});
    defer std.testing.allocator.free(encoded);
    var history: [32768]u8 = undefined;
    var decoder = try deflate.ZlibIncrementalDecoder.init(.{}, &history);
    for (0..5) |offset| {
        const step = try decoder.step(encoded[offset..][0..1], &.{});
        try std.testing.expectEqual(@as(usize, 1), step.progress.input_read);
        try std.testing.expectEqual(@as(?u32, null), decoder.requiredDictionaryId());
    }
    try std.testing.expectError(error.NeedDictionary, decoder.step(encoded[5..][0..1], &.{}));
    try std.testing.expectEqual(@as(?u32, checksum.Adler32.hash(dictionary)), decoder.requiredDictionaryId());
    try std.testing.expectEqual(@as(usize, 1), decoder.snapshot().last_step_progress.input_read);
    try std.testing.expectError(error.DictionaryMismatch, decoder.provideDictionary("wrong"));
    try decoder.provideDictionary(dictionary);
    try std.testing.expectEqual(@as(?u32, null), decoder.requiredDictionaryId());
    var output: [input.len]u8 = undefined;
    const done = try decoder.step(encoded[6..], &output);
    try std.testing.expectEqual(@as(usize, input.len), done.progress.output_written);
    try std.testing.expectEqualSlices(u8, input, &output);
    try decoder.finish();
}

test "zlib incremental dictionary whole input request exposes a safe unconsumed suffix" {
    const encoded = try frameAlloc(payload_bytes, dictionary_bytes);
    defer allocator.free(encoded);
    var history: [32768]u8 = undefined;
    var decoder = try deflate.ZlibIncrementalDecoder.init(.{}, &history);
    var output: [payload_bytes.len]u8 = @splat(0xa5);
    try std.testing.expectError(error.NeedDictionary, decoder.step(encoded, &output));
    try expectFailureProgress(&decoder, 6, 0);
    try std.testing.expectEqual(@as(?u32, checksum.Adler32.hash(dictionary_bytes)), decoder.requiredDictionaryId());
    try std.testing.expectEqual(@as(usize, 0), decoder.raw.history_len);
    const consumed = decoder.snapshot().last_step_progress.input_read;
    for ([_][]const u8{ "", "incorrect dictionary", dictionary_bytes[0 .. dictionary_bytes.len - 1] }) |wrong| {
        try std.testing.expectError(error.DictionaryMismatch, decoder.provideDictionary(wrong));
        try std.testing.expectEqual(@as(usize, 6), decoder.total_input);
        try std.testing.expectEqual(@as(usize, 0), decoder.total_output);
        try std.testing.expectEqual(@as(usize, 0), decoder.raw.history_len);
        try std.testing.expectEqualStrings("retry_with_dictionary", decoder.diagnostics().recoverability_hint_name);
    }
    try std.testing.expectError(error.NeedDictionary, decoder.step(encoded[consumed..], &output));
    try expectFailureProgress(&decoder, 0, 0);
    try decoder.provideDictionary(dictionary_bytes);
    try std.testing.expectEqual(@as(?u32, null), decoder.requiredDictionaryId());
    try std.testing.expectEqualStrings("", decoder.snapshot().last_error_name);
    try std.testing.expectEqual(@as(?usize, null), decoder.diagnostics().error_output_offset);
    try std.testing.expectEqualStrings("none", decoder.diagnostics().recoverability_hint_name);
    try drain(&decoder, encoded[consumed..], &output);
    try std.testing.expectEqualSlices(u8, payload_bytes, &output);
}

test "zlib incremental dictionary provision requires a full unresolved FDICT request" {
    const encoded = try frameAlloc(payload_bytes, dictionary_bytes);
    defer allocator.free(encoded);
    var history: [32768]u8 = undefined;
    var decoder = try deflate.ZlibIncrementalDecoder.init(.{}, &history);
    const initial = decoder.snapshot();
    try std.testing.expectError(error.InvalidStreamState, decoder.provideDictionary(dictionary_bytes));
    try std.testing.expectEqualDeep(initial, decoder.snapshot());
    _ = try decoder.step(encoded[0..5], &.{});
    const partial = decoder.snapshot();
    try std.testing.expectEqual(@as(?u32, null), decoder.requiredDictionaryId());
    try std.testing.expectError(error.InvalidStreamState, decoder.provideDictionary(dictionary_bytes));
    try std.testing.expectEqualDeep(partial, decoder.snapshot());
    try std.testing.expectError(error.NeedDictionary, decoder.step(encoded[5..6], &.{}));
    try decoder.provideDictionary(dictionary_bytes);
    const seeded = decoder.snapshot();
    try std.testing.expectError(error.InvalidStreamState, decoder.provideDictionary(dictionary_bytes));
    try std.testing.expectEqualDeep(seeded, decoder.snapshot());
    var output: [payload_bytes.len]u8 = undefined;
    try drain(&decoder, encoded[6..], &output);
    const complete = decoder.snapshot();
    try std.testing.expectError(error.InvalidStreamState, decoder.provideDictionary(dictionary_bytes));
    try std.testing.expectEqualDeep(complete, decoder.snapshot());
}

test "zlib incremental dictionary set miss and invalid entry allow an explicit current member override" {
    const encoded = try frameAlloc(payload_bytes, dictionary_bytes);
    defer allocator.free(encoded);
    const bad_entry = [_]deflate.ZlibDictionaryEntry{.{ .id = checksum.Adler32.hash(dictionary_bytes), .bytes = "wrong content with claimed ID" }};
    for ([_]deflate.ZlibDictionarySet{
        deflate.ZlibDictionarySet.fromEntries(&.{}),
        deflate.ZlibDictionarySet.fromEntries(&bad_entry),
    }) |set| {
        var history: [32768]u8 = undefined;
        var decoder = try deflate.ZlibIncrementalDecoder.initWithDictionarySet(.{}, &history, set);
        try std.testing.expectError(error.NeedDictionary, decoder.step(encoded, &.{}));
        try expectFailureProgress(&decoder, 6, 0);
        try decoder.provideDictionary(dictionary_bytes);
        var output: [payload_bytes.len]u8 = undefined;
        try drain(&decoder, encoded[6..], &output);
        try std.testing.expectEqualSlices(u8, payload_bytes, &output);
        decoder.reset();
        try std.testing.expectEqual(@as(?u32, null), decoder.requiredDictionaryId());
        try std.testing.expectError(error.NeedDictionary, decoder.step(encoded, &.{}));
        try expectFailureProgress(&decoder, 6, 0);
    }
}

test "zlib incremental dictionary provided bytes need only survive the call and full ID covers the long dictionary" {
    const dictionary = try allocator.alloc(u8, 50000);
    defer allocator.free(dictionary);
    for (dictionary, 0..) |*byte, index| byte.* = @truncate(index * 73 + index / 11);
    const input = dictionary[dictionary.len - 512 ..];
    const encoded = try frameAlloc(input, dictionary);
    defer allocator.free(encoded);
    var history: [32768]u8 = undefined;
    var decoder = try deflate.ZlibIncrementalDecoder.init(.{}, &history);
    try std.testing.expectError(error.NeedDictionary, decoder.step(encoded, &.{}));
    try std.testing.expectEqual(@as(?u32, checksum.Adler32.hash(dictionary)), decoder.requiredDictionaryId());
    try std.testing.expectError(error.DictionaryMismatch, decoder.provideDictionary(dictionary[dictionary.len - 32768 ..]));
    const supplied = try allocator.dupe(u8, dictionary);
    try decoder.provideDictionary(supplied);
    @memset(supplied, 0);
    allocator.free(supplied);
    try std.testing.expectEqual(@as(usize, 32768), decoder.raw.history_len);
    var output: [512]u8 = undefined;
    try drain(&decoder, encoded[6..], &output);
    try std.testing.expectEqualSlices(u8, input, &output);
    decoder.reset();
    try std.testing.expectError(error.NeedDictionary, decoder.step(encoded, &.{}));
}

test "zlib incremental dictionary configured storage is revalidated on reset and ignores streams without FDICT" {
    const encoded = try frameAlloc(payload_bytes, dictionary_bytes);
    defer allocator.free(encoded);
    var history: [32768]u8 = undefined;
    var decoder = try deflate.ZlibIncrementalDecoder.initWithDictionary(.{}, &history, dictionary_bytes);
    try std.testing.expectEqual(@as(usize, 0), decoder.raw.history_len);
    var output: [payload_bytes.len]u8 = undefined;
    try drain(&decoder, encoded, &output);
    try std.testing.expectEqualSlices(u8, payload_bytes, &output);
    decoder.reset();
    try drain(&decoder, encoded, &output);
    try std.testing.expectEqualSlices(u8, payload_bytes, &output);
    const plain = try deflate.encodeZlibFixedAlloc(allocator, "plain");
    defer allocator.free(plain);
    decoder.reset();
    _ = try decoder.step(plain[0..2], &.{});
    try std.testing.expectEqual(@as(?u32, null), decoder.requiredDictionaryId());
    try std.testing.expectEqual(@as(usize, 0), decoder.raw.history_len);
    try std.testing.expectError(error.InvalidStreamState, decoder.provideDictionary(dictionary_bytes));
    var plain_output: [5]u8 = undefined;
    try drain(&decoder, plain[2..], &plain_output);
    try std.testing.expectEqualStrings("plain", &plain_output);
}

test "zlib incremental dictionary empty dictionary ID one can be explicitly provided" {
    const encoded = [_]u8{ 0x78, 0x20, 0, 0, 0, 1, 0x03, 0x00, 0, 0, 0, 1 };
    var history: [32768]u8 = undefined;
    var decoder = try deflate.ZlibIncrementalDecoder.init(.{}, &history);
    try std.testing.expectError(error.NeedDictionary, decoder.step(&encoded, &.{}));
    try std.testing.expectEqual(@as(?u32, 1), decoder.requiredDictionaryId());
    try decoder.provideDictionary("");
    try drain(&decoder, encoded[6..], &.{});
    try std.testing.expectEqual(@as(usize, 0), decoder.total_output);
    try std.testing.expectEqual(@as(?u32, null), decoder.requiredDictionaryId());
}

test "zlib incremental dictionary no FDICT cannot reference externally configured bytes" {
    // Fixed final block: length 3 / distance 1 followed by EOB, with no literal.
    const raw = [_]u8{ 0x03, 0x02, 0x00 };
    var history: [32768]u8 = undefined;
    var raw_decoder = try deflate.RawDeflateIncrementalFixedLiteralDecoder.initWithDictionary(.{}, &history, "A");
    var output: [4]u8 = undefined;
    const raw_done = try raw_decoder.step(&raw, &output);
    try std.testing.expectEqual(core.StepResult.Status.done, raw_done.status);
    try std.testing.expectEqualStrings("AAA", output[0..raw_done.progress.output_written]);
    const stream = [_]u8{ 0x78, 0x01, 0x03, 0x02, 0x00, 0x01, 0x89, 0x00, 0xc4 };
    var decoder = try deflate.ZlibIncrementalDecoder.initWithDictionary(.{}, &history, "A");
    try std.testing.expectError(error.InvalidMatch, decoder.step(&stream, &output));
    try std.testing.expectEqual(@as(usize, 0), decoder.total_output);
    try std.testing.expectEqual(@as(?u32, null), decoder.requiredDictionaryId());
}

test "zlib incremental dictionary waiting finish defers EOF and preserves suffix recovery" {
    const encoded = try frameAlloc(payload_bytes, dictionary_bytes);
    defer allocator.free(encoded);
    var history: [32768]u8 = undefined;
    var decoder = try deflate.ZlibIncrementalDecoder.init(.{}, &history);
    try std.testing.expectError(error.NeedDictionary, decoder.step(encoded, &.{}));
    try std.testing.expectError(error.NeedDictionary, decoder.finish());
    try std.testing.expect(!decoder.input_finished);
    try std.testing.expectEqual(@as(?u32, checksum.Adler32.hash(dictionary_bytes)), decoder.requiredDictionaryId());
    try std.testing.expectError(error.DictionaryMismatch, decoder.provideDictionary("wrong"));
    try std.testing.expectError(error.NeedDictionary, decoder.finish());
    try decoder.provideDictionary(dictionary_bytes);
    var output: [payload_bytes.len]u8 = undefined;
    try drain(&decoder, encoded[6..], &output);
    try std.testing.expect(decoder.input_finished);
    try std.testing.expectError(error.TrailingData, decoder.step("additional input", &.{}));
    try expectFailureProgress(&decoder, 0, 0);
    decoder.reset();
    _ = try decoder.step(encoded[0..5], &.{});
    try std.testing.expectError(error.TruncatedFrame, decoder.finish());
    try std.testing.expect(decoder.input_finished);
    try std.testing.expectEqual(@as(?u32, null), decoder.requiredDictionaryId());
    try std.testing.expectError(error.InvalidStreamState, decoder.provideDictionary(dictionary_bytes));
    try std.testing.expectError(error.TruncatedFrame, decoder.step("", &.{}));
}

test "zlib incremental dictionary concat request reports the prior member output and current header" {
    const first_payload = "already published first member\n";
    const first = try deflate.encodeZlibFixedAlloc(allocator, first_payload);
    defer allocator.free(first);
    const second = try frameAlloc(payload_bytes, dictionary_bytes);
    defer allocator.free(second);
    var joined: std.ArrayList(u8) = .empty;
    defer joined.deinit(allocator);
    try joined.appendSlice(allocator, first);
    try joined.appendSlice(allocator, second);
    var history: [32768]u8 = undefined;
    var decoder = try deflate.ZlibIncrementalDecoder.init(.{ .allow_concatenated = true, .expected_output_len = first_payload.len + payload_bytes.len }, &history);
    var output: [first_payload.len + payload_bytes.len]u8 = undefined;
    try std.testing.expectError(error.NeedDictionary, decoder.step(joined.items, &output));
    try expectFailureProgress(&decoder, first.len + 6, first_payload.len);
    try std.testing.expectEqualSlices(u8, first_payload, output[0..first_payload.len]);
    try std.testing.expectEqual(@as(?usize, 1), decoder.snapshot().last_error_stream_index);
    try std.testing.expectEqual(@as(?usize, first.len), decoder.snapshot().last_error_stream_offset);
    const consumed = decoder.snapshot().last_step_progress.input_read;
    try decoder.provideDictionary(dictionary_bytes);
    try drain(&decoder, joined.items[consumed..], output[first_payload.len..]);
    try std.testing.expectEqualSlices(u8, payload_bytes, output[first_payload.len..]);
    try std.testing.expectEqual(@as(usize, 2), decoder.stream_count);
    try std.testing.expectEqual(joined.items.len, decoder.total_input);
}

test "zlib incremental dictionary new member clears old request and uses its own DICTID" {
    const second_dictionary = "a separate dictionary for the second member";
    const first = try frameAlloc("first", dictionary_bytes);
    defer allocator.free(first);
    const second = try frameAlloc("second", second_dictionary);
    defer allocator.free(second);
    var history: [32768]u8 = undefined;
    var decoder = try deflate.ZlibIncrementalDecoder.initWithDictionary(.{ .allow_concatenated = true }, &history, dictionary_bytes);
    var output: [5]u8 = undefined;
    _ = try decoder.step(first, &output);
    try std.testing.expectEqualStrings("first", &output);
    _ = try decoder.step(second[0..5], &.{});
    try std.testing.expectEqual(@as(?u32, null), decoder.requiredDictionaryId());
    try std.testing.expectEqual(@as(usize, 0), decoder.raw.history_len);
    try std.testing.expectError(error.NeedDictionary, decoder.step(second[5..6], &.{}));
    try std.testing.expectEqual(@as(?u32, checksum.Adler32.hash(second_dictionary)), decoder.requiredDictionaryId());
    try expectFailureProgress(&decoder, 1, 0);
    try std.testing.expectError(error.DictionaryMismatch, decoder.provideDictionary(dictionary_bytes));
    try decoder.provideDictionary(second_dictionary);
    var second_output: [6]u8 = undefined;
    try drain(&decoder, second[6..], &second_output);
    try std.testing.expectEqualStrings("second", &second_output);
}

test "zlib incremental dictionary recovery retains cumulative quotas and reset restores operation allowance" {
    const first_payload = "prior member quota";
    const first = try deflate.encodeZlibStoredAlloc(allocator, first_payload);
    defer allocator.free(first);
    const second = try deflate.encodeZlibStoredWithDictionaryAlloc(allocator, "second", dictionary_bytes);
    defer allocator.free(second);
    var joined: std.ArrayList(u8) = .empty;
    defer joined.deinit(allocator);
    try joined.appendSlice(allocator, first);
    try joined.appendSlice(allocator, second);
    var history: [32768]u8 = undefined;
    var decoder = try deflate.ZlibIncrementalDecoder.init(.{ .allow_concatenated = true, .max_output_len = first_payload.len + 5 }, &history);
    var output: [64]u8 = undefined;
    try std.testing.expectError(error.NeedDictionary, decoder.step(joined.items, &output));
    const consumed = decoder.snapshot().last_step_progress.input_read;
    try std.testing.expectEqual(first_payload.len, decoder.total_output);
    try decoder.provideDictionary(dictionary_bytes);
    try std.testing.expectError(error.OutputLimitExceeded, decoder.step(joined.items[consumed..], &output));
    try std.testing.expectEqual(first_payload.len, decoder.total_output);
    try expectFailureProgress(&decoder, 5, 0);
    decoder.reset();
    try std.testing.expectEqual(@as(usize, 0), decoder.total_input);
    try std.testing.expectEqual(@as(usize, 0), decoder.total_output);
    try std.testing.expectEqual(@as(usize, 0), decoder.stream_count);
    try std.testing.expectEqual(@as(?u32, null), decoder.requiredDictionaryId());
    _ = try decoder.step(first, &output);
    try decoder.finish();
    try std.testing.expectEqualStrings(first_payload, output[0..first_payload.len]);
}

test "zlib incremental dictionary diagnostics count raw error input output and Adler prefix exactly" {
    const prefix = "raw bytes before an invalid block";
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    try encoded.appendSlice(allocator, &.{ 0x78, 0x01, 0 }); // Valid wrapper, non-final stored block.
    var lengths: [4]u8 = undefined;
    std.mem.writeInt(u16, lengths[0..2], prefix.len, .little);
    std.mem.writeInt(u16, lengths[2..4], ~@as(u16, prefix.len), .little);
    try encoded.appendSlice(allocator, &lengths);
    try encoded.appendSlice(allocator, prefix);
    try encoded.append(allocator, 7); // Final, reserved BTYPE=3.
    for ([_]bool{ false, true }) |split_output| {
        var history: [32768]u8 = undefined;
        var decoder = try deflate.ZlibIncrementalDecoder.init(.{}, &history);
        var output: [prefix.len]u8 = undefined;
        var offset: usize = 0;
        var written: usize = 0;
        if (split_output) {
            const first = try decoder.step(encoded.items, output[0..2]);
            offset = first.progress.input_read;
            written = first.progress.output_written;
            try std.testing.expectEqual(@as(usize, 2), written);
        }
        try std.testing.expectError(error.InvalidDeflateBlockType, decoder.step(encoded.items[offset..], output[written..]));
        try expectFailureProgress(&decoder, encoded.items.len - offset, prefix.len - written);
        try std.testing.expectEqual(encoded.items.len, decoder.total_input);
        try std.testing.expectEqual(prefix.len, decoder.total_output);
        try std.testing.expectEqualSlices(u8, prefix, &output);
        try std.testing.expectEqual(checksum.Adler32.hash(prefix), decoder.adler.digest());
        try std.testing.expectEqual(@as(?u32, null), decoder.requiredDictionaryId());
        try std.testing.expectEqual(deflate.ZlibIncrementalDecoder.Phase.raw, decoder.snapshot().last_error_phase.?);
    }
}
