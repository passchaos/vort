const std = @import("std");
const deflate = @import("../../../deflate.zig");

test "raw deflate incremental hash encoder persists index across blocks and reset" {
    const phrase = "persistent-hash-chain-across-incremental-blocks-0123456789";
    const payload = (phrase ** 10) ++ ("separator" ** 5) ++ (phrase ** 10);
    var compression = deflate.optionsForLevel(.fastest);
    compression.block_selection = .stored_fixed_dynamic;
    var encoder = deflate.RawDeflateIncrementalBestEncoder.initWithOptions(std.testing.allocator, .{
        .block_len = phrase.len * 4,
        .compression = compression,
    });
    defer encoder.deinit();

    const encoded = try encodeStream(&encoder, payload);
    defer std.testing.allocator.free(encoded);
    const decoded = try deflate.decodeRawAutoAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);

    const used = encoder.matchFinderSnapshot();
    try std.testing.expect(used.initialized);
    try std.testing.expectEqual(payload.len, used.absolute_position);
    try std.testing.expect(used.indexed_positions > 0);
    try std.testing.expectEqual(@as(usize, 3 * 32 * 1024), used.table_entries);

    encoder.reset();
    const reset = encoder.matchFinderSnapshot();
    try std.testing.expect(!reset.initialized);
    try std.testing.expectEqual(@as(usize, 0), reset.absolute_position);
    try std.testing.expectEqual(@as(usize, 0), reset.indexed_positions);
    // Reset advances an epoch and retains caller-paid table capacity rather
    // than clearing/reallocating the persistent index.
    try std.testing.expectEqual(used.table_entries, reset.table_entries);

    const encoded_again = try encodeStream(&encoder, payload);
    defer std.testing.allocator.free(encoded_again);
    try std.testing.expectEqualSlices(u8, encoded, encoded_again);
}

test "raw deflate incremental hash encoder retains preset dictionary index" {
    const dictionary = "dictionary-prefix: persistent rolling hash phrase and shared suffix";
    const payload = "persistent rolling hash phrase and shared suffix plus payload";
    var compression = deflate.optionsForLevel(.fast);
    compression.block_selection = .stored_fixed_dynamic;
    var encoder = deflate.RawDeflateIncrementalBestEncoder.initWithDictionary(std.testing.allocator, .{
        .block_len = 13,
        .compression = compression,
    }, dictionary);
    defer encoder.deinit();

    const encoded = try encodeStream(&encoder, payload);
    defer std.testing.allocator.free(encoded);
    const decoded = try deflate.decodeRawAutoAllocWithDictionary(std.testing.allocator, encoded, dictionary);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    try std.testing.expectEqual(payload.len + dictionary.len, encoder.matchFinderSnapshot().absolute_position);
}

test "raw deflate incremental hash beats rebuilding split reference index" {
    const dictionary = "reference-dictionary-prefix-abcdefghijklmnopqrstuvwxyz";
    const payload = ("abcdefghijklmnopqrstuvwxyz-reference-payload-" ** 9) ++ "tail";
    const options = deflate.optionsForLevel(.fastest);
    const block_len: usize = 47;

    var encoder = deflate.RawDeflateIncrementalFixedEncoder.initWithDictionary(std.testing.allocator, .{
        .block_len = block_len,
        .compression = options,
    }, dictionary);
    defer encoder.deinit();
    const incremental = try encodeFixedStream(&encoder, payload);
    defer std.testing.allocator.free(incremental);
    const reference = try deflate.encodeRawFixedSplitWithDictionaryAlloc(
        std.testing.allocator,
        payload,
        dictionary,
        block_len,
        options,
    );
    defer std.testing.allocator.free(reference);
    // The one-shot split reference rebuilds its dictionary hash table for each
    // block. Persistent heads can retain more useful recent candidates and
    // therefore intentionally produce a different, no-larger stream.
    try std.testing.expect(incremental.len <= reference.len);
    const decoded = try deflate.decodeRawAutoAllocWithDictionary(std.testing.allocator, incremental, dictionary);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
}

fn encodeStream(encoder: *deflate.RawDeflateIncrementalBestEncoder, payload: []const u8) ![]u8 {
    var encoded: std.ArrayList(u8) = .empty;
    errdefer encoded.deinit(std.testing.allocator);
    var scratch: [11]u8 = undefined;
    var offset: usize = 0;
    while (offset < payload.len) {
        const end = @min(payload.len, offset + 7);
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
    return encoded.toOwnedSlice(std.testing.allocator);
}

fn encodeFixedStream(encoder: *deflate.RawDeflateIncrementalFixedEncoder, payload: []const u8) ![]u8 {
    var encoded: std.ArrayList(u8) = .empty;
    errdefer encoded.deinit(std.testing.allocator);
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
    return encoded.toOwnedSlice(std.testing.allocator);
}
